# Gemma PyTorch implementation architecture

## Scope

The repository contains a PyTorch inference implementation of Gemma 3 and
Gemma 4. Gemma 4 E2B is the current multimodal alignment target; Gemma 3 is
kept as a text baseline with an older SigLIP image path. The latest source
state keeps the two model generations separate while preserving the upstream
layout where practical.

## Code organization

```text
gemma/
├── config.py, model.py, tokenizer.py       # Gemma 3 shared text path
├── gemma3_model.py, gemma3_preprocessor.py # Gemma 3 multimodal composition
├── gemma3/checkpoint.py                    # Gemma 3 checkpoint mapping
├── gemma4/                                 # Gemma 4 implementation package
│   ├── gemma4_config.py, gemma4_model.py   # text + composition
│   ├── gemma4_vision.py, gemma4_audio.py   # modality towers
│   ├── gemma4_processor.py, gemma4_tokenizer.py
│   └── checkpoint.py                       # checkpoint mapping
├── checkpoint_utils.py                     # shared public safetensors helpers
├── checkpoint.py                           # compatibility loader exports
└── siglip_vision/, model_xla.py            # Gemma 3 vision and XLA paths
tests/
├── test_manifest.py, test_alignment.py    # resources and contracts
├── test_checkpoint_loading.py              # loader mapping contracts
├── test_runtime_alignment.py               # local checkpoint smoke paths
├── test_gemma4_reference_alignment.py      # Transformers numerical contract
└── alignment_report.py, run_alignment.py   # profiled JSON/Markdown reporting
```

`scripts/` contains text, multimodal, and XLA entry points. `models/` is a
repository-local symlink to downloaded checkpoints and is never committed.

## Model architecture

## Gemma 3

`gemma3_model.py` combines the shared Gemma text decoder in `model.py` with a
SigLIP vision tower. Text embeddings are scaled, image placeholder tokens are
replaced with projected SigLIP features, and the decoder uses alternating
global/sliding attention, RoPE, KV cache, RMSNorm, and gated MLP blocks. The
generation path builds causal, image-bidirectional, and local-window masks.

The image path is:

```text
PIL image -> pan-and-scan preprocessing -> SigLIP patch/Transformer encoder
           -> 4x4 average pool -> RMSNorm -> projection -> image placeholders
```

## Gemma 4

`gemma4/gemma4_model.py` contains the text backbone and multimodal composition. The
text model has a main token embedding plus Context-PLE and Token-PLE. The two
per-layer inputs are combined and injected into every decoder layer. Layers
alternate sliding/full attention, use Q/K/V RMSNorm and type-specific RoPE,
and can reuse K/V according to the configured sharing pattern. Final RMSNorm,
tied embedding projection, and logit softcap produce logits.

The modality paths are independent towers whose projected outputs replace
special tokens before text decoding:

```text
image patches -> Gemma4VisionModel -> padding-aware spatial pool -> projection
audio log-mel  -> Conv2D subsampling -> relative-position audio layers
               -> output projection -> multimodal projection
```

The vision tower uses patch projection, 2-D position ids, multidimensional
RoPE, RMSNorm/attention/MLP layers, and reference-order BF16 pooling. The
audio tower uses chunked relative-position attention, local context masks,
light depthwise convolution, residual feed-forward blocks, and attention
softcap. `gemma4/gemma4_processor.py` prepares image patches and 16 kHz log-mel
features. `Gemma4ForConditionalGeneration` combines these projected modality
tokens with the language model; text-only calls bypass the towers.

### Gemma 4 image and audio call flows

The processor prepares modality inputs; the caller constructs `input_ids` and
the matching boolean token mask. There is no separate image/audio cross-
attention path in this implementation: each modality tower produces vectors
that replace the embeddings at its placeholder positions before the shared
text decoder runs.

Image path:

```text
PIL/tensor image
  -> Gemma4ImageProcessor.__call__
     -> _target_size -> _patchify
     -> pixel_values [B, patches, 3*patch_size^2], pixel_position_ids [B, patches, 2]
  -> Gemma4ForConditionalGeneration.forward
     -> Gemma4VisionModel.forward
        -> Gemma4VisionPatchEmbedder.forward
        -> Gemma4VisionLayer.forward (each layer calls Gemma4VisionAttention.forward)
        -> padding-aware spatial pooling
     -> Gemma4MultimodalEmbedder.forward (RMSNorm + linear projection)
     -> replace image_token_mask positions in token embeddings
```

The image processor returns `num_soft_tokens`; the number of `True` values in
`image_token_mask` must match the pooled vision output count. `Gemma4VisionModel`
uses the supplied 2-D patch positions to pool neighboring patches spatially,
and masks padded patch positions.

Audio path:

```text
16 kHz waveform
  -> Gemma4AudioProcessor.__call__
     -> log-mel features [B, frames, 128]
  -> Gemma4ForConditionalGeneration.forward
     -> Gemma4AudioModel.forward
        -> Gemma4AudioSubsample.forward
           -> Gemma4AudioSubsampleLayer.forward (twice; stride-2 Conv2D)
        -> Gemma4AudioLayer.forward (each layer runs audio attention, LightConv, FFNs)
        -> output_proj
     -> Gemma4MultimodalEmbedder.forward (RMSNorm + linear projection)
     -> replace audio_token_mask positions in token embeddings
```

`Gemma4AudioProcessor.__call__` defaults to 16 kHz, 128 mel bins, a 320-sample
frame (20 ms), a 160-sample hop (10 ms), a 512-point FFT, and a `1e-3` mel
floor. It casts the waveform to float32 and flattens it, so callers should pass
mono audio; stereo input is not downmixed and does not produce valid mono
features. The implementation does not resample audio. `sampling_rate` is used
to map mel frequencies to FFT bins, so the waveform must already use the
configured rate (normally 16 kHz).

Framing zero-pads 160 samples on the left. The code makes sliding windows of
321 samples, drops each window's last sample, and uses a 160-sample hop, leaving
320 samples per frame. It applies the periodic Hann formula
`w[n] = 0.5 - 0.5*cos(2*pi*n/320)` for `n=0..319` (denominator `N`, not `N-1`),
then computes `abs(rfft(frame * window, n=512))`. This is an amplitude spectrum,
not power. A 128-channel triangular HTK mel bank spans 0–8 kHz; its frequency
points are mapped to the 257 one-sided FFT bins. The final feature is
`ln(spectrum @ mel_bank + 1e-3)`, returned as float32 `[1, frames, 128]`.
With the defaults, a one-second 16 kHz waveform produces 99 frames. The
processor does not perform waveform amplitude normalization.

The audio encoder returns one vector per subsampled time step, so the number of
`True` values in `audio_token_mask` must match that sequence length. For both
modalities, `Gemma4ForConditionalGeneration.forward` also substitutes PAD IDs
at placeholder positions when constructing Token-PLE inputs, then invokes
`Gemma4TextModel.forward`, which runs the `Gemma4DecoderLayer` stack. The
wrapper projects the resulting hidden states through the tied token embedding
matrix and applies final logit softcapping.

## Checkpoint and execution boundaries

Checkpoint mapping is version-specific: Gemma 3 uses
`gemma/gemma3/checkpoint.py`, Gemma 4 uses `gemma/gemma4/checkpoint.py`, and
both share the public helpers in `gemma/checkpoint_utils.py`. The root
`gemma/checkpoint.py` remains a compatibility export layer, so existing
imports do not need to change. Loaders resolve either a model directory or
`model.safetensors`, copy only declared parameters/buffers, and reject
incomplete mappings. Tokenizers are likewise version-specific: Gemma 3 uses
SentencePiece and Gemma 4 uses `gemma/gemma4/gemma4_tokenizer.py` with
`tokenizer.json` through `tokenizers`.

The Gemma 4 package `__init__.py` provides common model, configuration,
processor, and tokenizer exports; its internal modules use package-relative
imports to avoid coupling to Gemma 3's same-purpose modules.

The runtime flow is:

```text
model directory -> config/tokenizer/checkpoint loader
                 -> processor/token IDs + modality embeddings
                 -> Gemma text decoder -> tied LM head -> logits/generation
```

Missing model resources are reported with the corresponding Hugging Face URL,
expected `models/<model-id>/` layout, and missing filenames. Model-dependent
tests fail instead of silently skipping.

Alignment resources are resolved through the repository `models/` symlink. If a
model is missing, checks report its Hugging Face page and expected files:
Gemma 3 uses <https://huggingface.co/google/gemma-3-1b-it> with
`model.safetensors` and `tokenizer.model`; Gemma 4 uses
<https://huggingface.co/google/gemma-4-E2B-it> with `config.json`,
`model.safetensors`, and `tokenizer.json`.
Model-dependent checks fail rather than silently skipping, so a successful
alignment run always means the required checkpoint was actually loaded.

## Validation boundary

Separate deterministic preprocessing checks from checkpoint-dependent
numerical checks. Tokenizer, configuration, pan-and-scan, image normalization,
and batch-shape checks can run without model weights; checkpoint comparisons
must identify the model, prompt or image, device, dtype, generated length, and
tolerance. Keep these cases and their comparison metadata in
`tests/data/alignment_cases.json` rather than duplicating them in test code.

The formal Gemma 4 reference contract is BF16 with Transformers attention
explicitly forced to `eager`. Text logits, greedy text generation, vision
features, audio features, audio-text logits, and image-text logits are checked
independently. The alignment runner exposes `contract`, `runtime-smoke`,
`gemma4-reference`, and `all` profiles; runtime/reference profiles are strict
and fail on skips, while `all --strict` is the combined acceptance gate.
Reports include profile metadata, thresholds, and measured error metrics.
Prompts, backend, and thresholds are read from the manifest rather than
duplicated in test code. SDPA, other dtypes/devices, and Gemma 3 multimodal
numerical parity are not covered by the current acceptance boundary.

The recorded Gemma 3 CUDA smoke baseline uses seed `12345`, prompt
`The capital of Italy is`, and two generated tokens; expected output is
` Rome.`. Check the case manifest and report before using it as a current gate.
