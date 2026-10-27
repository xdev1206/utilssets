# LiteRT / LiteRT-LM Embedding and PLE INT4 Runtime

## Scope and Main Finding

INT4 is supported in two different lookup routes. The ordinary token embedding runs an embedder LiteRT model; its `TFL_EMBEDDING_LOOKUP` kernel or selected delegate handles the table. In LiteRT-LM's NPU decoder flow, the PLE host lookup path bypasses the PLE lookup graph: host CPU code reads packed table constants from the model and performs row lookup, INT4 unpacking, dequantization, and optional output quantization, then supplies the resulting PLE input to the NPU decoder. The PLE table lookup itself is not executed on the NPU in this path. Neither runtime path packs weights at inference time.

“Pack” here means the model/export pipeline stores two signed 4-bit values in each byte. The LiteRT-LM runtime code consumes that representation. It does not establish which upstream quantizer/export command produced a particular model's bytes; verify the exported tensor type and quantization metadata in that model.

## Packed INT4 Representation

For the signed two's-complement values `q ∈ [-8, 7]`, element `i` occupies the low nibble for even `i` and high nibble for odd `i`:

```text
byte = (q[2k] & 0x0f) | ((q[2k + 1] & 0x0f) << 4)
```

For example, `[-2, 5]` becomes `0x5e`: low nibble `0xe` is -2 and high nibble `0x5` is 5. The test helper `PackInt4` in `llm_litert_npu_embedder_test.cc` explicitly uses this order. LiteRT's `Unpack4Bit` uses the same order.

Both implementations sign-extend each nibble by moving it into the upper half of a signed byte. If `b` is the packed byte and `s` is the quantization scale, they compute `int8(b << 4) * (s / 16)` for the low nibble, then `int8(b & 0xf0) * (s / 16)` for the high nibble. Since the shifted signed byte is `q * 16`, the result is `q * s`. Thus `0x5e` yields `[-2s, 5s]`. For an odd number of elements, the final low nibble is used and its high nibble is ignored.

LiteRT tensor sizing stores `ceil(element_count / 2)` bytes for INT4. That tensor-wide size rule does not itself define row padding. The PLE fast path assumes an even embedding width and uses `row_bytes = embedding_dim / 2`; odd widths are not safe with this row addressing.

## LiteRT `EMBEDDING_LOOKUP` Kernel

`LiteRT/tflite/kernels/embedding_lookup.cc` accepts an INT32 index vector and a rank-2-or-higher value tensor. Runtime dispatch is based on quantization metadata and input/output types:

- Blockwise quantization selects `EvalBlockwise`. It accepts INT4/INT2 tables and FP32/FP16 output, requires a rank-2 table, and unpacks each quantization block with its FP16 scale.
- Otherwise, a quantized table with FP32/FP16 output selects `EvalHybrid`. It computes each selected row's flat element offset, chooses the tensor or row scale, unpacks sub-byte elements, and writes dequantized values.
- Same-type lookup selects `EvalSimple`, which copies the selected row's bytes as-is. For an INT4 output this is still packed data; this branch does not unpack it.

Per-axis affine quantization is constrained to axis 0 (rows), with one scale per row and one or row-count zero points. Hybrid INT4 dequantization is symmetric: it multiplies signed q4 by scale and does not subtract a zero point. `Prepare` explicitly checks zero point 0 for some FP32 affine cases, but consumers should treat zero-point-zero as a requirement for the hybrid path. Out-of-range indices are errors in this kernel.

## LiteRT-LM Ordinary Token Embedding

`EmbeddingLookupText::Initialize` compiles the embedding model (Android requests NPU and CPU; other platforms request CPU), creates the model input/output buffers, and requires one 4-byte token input and a Float32 output. `LookupInternal` writes one token ID, runs the compiled model, and copies its FP32 output. Prefill invokes lookup for each token; decode uses the same single-token lookup. A negative token uses a cached token-0 embedding. No LiteRT-LM host code reads or unpacks the ordinary token table directly: INT4 handling belongs to the LiteRT kernel or the delegate selected for that compiled model.

`NpuEmbedder` routes ordinary text lookup through `EmbeddingLookupManager` in this mode and copies resulting embeddings into the decoder's embedding buffer. Other embedder configurations can run compiled prefill/decode signatures directly. In both cases the ordinary embedding is distinct from the manual PLE lookup below.

## Host-Side PLE Lookup for the NPU Decoder

In `NpuEmbedder::Create`, when PLE is present and `NpuConfig.use_hw_ple_for_npu` is enabled, LiteRT-LM scans the PLE model's main subgraph. For each `TFL_EMBEDDING_LOOKUP`, it retains the table weight-byte pointer, element type, embedding width, and per-tensor or per-channel scale metadata. It also captures a constant from a `MUL` op and the PLE output type; INT16 output additionally supplies a per-tensor output scale and zero point. The runtime does not invoke the `EMBEDDING_LOOKUP` kernel for those tables in this mode. `HWPerLayerEmbeddingLookup` is ordinary host C++ code; its Android ARM64 optimization uses CPU NEON instructions, not an NPU kernel.

For each token, `HWPerLayerEmbeddingLookup` selects the table row and dequantizes it:

1. Select row `token_id`; invalid IDs fall back to row 0. The current vocabulary bound is hard-coded as 262144.
2. Compute the row byte offset (`dim / 2` for INT4, `dim` for INT8).
3. Select scale 0 for per-tensor quantization or `scales[token_id]` for per-channel quantization, then multiply by the captured PLE `MUL` constant.
4. Unpack INT4 (`q * scale`) or dequantize INT8 into FP32. Android ARM64 uses a NEON loop for groups of 32 INT4 values and a scalar tail; other builds use the scalar loop.
5. For FP32 output, write the values directly. For INT16 output, compute `round(value / output_scale) + output_zero_point` and clamp to the INT16 range.

The resulting buffer is laid out `[token, table, embedding_dim]`; tables for each token are concatenated in model-op order. Prefill, decode, and verify call this helper when the host lookup path is active, then provide the produced PLE input to the NPU decoder. Otherwise LiteRT-LM compiles and runs the PLE embedder graph using CPU options, with negative prefill IDs normalized to row 0; that branch does not call `UnpackInt4Row` either.

## Assumptions and Gaps

- The manual path accepts INT4 or INT8 table elements, and its output writer accepts FP32 or INT16. A Float16 output tensor is not supported by `HWPerLayerEmbeddingLookup`, even though a separate generic PLE writer handles Float16.
- INT4 row stride uses integer division, so the manual route assumes even width. Gemma 4 PLE width 256 satisfies this.
- LiteRT's generic affine `EvalHybrid` also advances to a row with `(row_width * row_id) >> 1` and assumes the first value in that byte is the row's low nibble. With densely packed rows of odd width, later rows can begin in a high nibble; verify row alignment or pad rows before relying on odd widths there too. The blockwise route has the same sub-byte offset concern when block boundaries are not byte-aligned.
- Per-channel scales are indexed by token ID without validating `quantized_dimension`; correct metadata must mean one scale per vocabulary row.
- The manual dequantizer ignores table zero points and assumes symmetric quantization.
- Per-tensor scales are appended to a vector while pointers to vector elements are retained. Multiple such tables could invalidate earlier pointers if the vector reallocates; stable storage or stored indices would avoid this hazard.
- The host route trusts extracted tensor dimensions and buffer capacities. The hard-coded vocabulary and row-0 fallback differ from LiteRT's regular kernel, which reports out-of-range indices as errors.
- Existing tests synthesize packed rows and cover FP32/INT16, per-tensor/per-row scales, multiple tables, invalid IDs, and scalar/vectorized-sized rows. Non-Android tests exercise only the scalar implementation; they do not prove metadata extraction or numerical parity on an exported Gemma 4 model.

## Source Map

The paths below are relative to the workspace root `/workspace/xin.xu5/projs/litert`. Line numbers identify the current checkout and can shift as upstream changes.

| Implementation point | Source location | What it establishes |
| --- | --- | --- |
| LiteRT affine validation and dispatch | `LiteRT/tflite/kernels/embedding_lookup.cc`: `Prepare` (66), `Eval` (367), `EvalSimple` (116) | Accepted ranks/types, per-axis constraints, and raw-copy versus dequantizing branch selection. |
| LiteRT INT4 unpack and dequantization | Same file: `Unpack4Bit` (143), `UnpackSubByteElements` (196), `EvalBlockwise` (210), `EvalHybrid` (293) | Low-nibble-first decode, block/per-row scale application, and FP32/FP16 outputs. |
| LiteRT packed byte count | `LiteRT/tflite/util.cc`: `BytesRequired` (243) | INT4 tensors occupy `ceil(element_count / 2)` bytes. |
| Generic runtime INT4 pack primitive | `LiteRT/tflite/kernels/cast.cc`: `castFloatToInt4` (333); `LiteRT/tflite/kernels/internal/portable_tensor_utils.cc`: `PackInt8IntoDenseInt` (166) | CAST clamps values to q4, then packs even elements into the low nibble and odd elements into the high nibble. This is a runtime CAST operator path, not evidence of the model exporter used for PLE constants. |
| LiteRT kernel tests | `LiteRT/tflite/kernels/embedding_lookup_test.cc`: INT4 blockwise tests (521 onward), affine per-axis tests (645 onward), sanitization tests (1149 onward) | Synthetic operator coverage; not proof of a particular Gemma export. |
| Ordinary embedding model execution | `LiteRT-LM/runtime/components/embedding_lookup/embedding_lookup_text.cc`: `LookupInternal` (59), `LookupDecode` (93/100), `LookupPrefill` (142/160), `Initialize` (285) | Token input, compiled-model invocation, FP32 output requirement, and per-token prefill/decode behavior. |
| Ordinary embedding manager dispatch | `LiteRT-LM/runtime/components/embedding_lookup/embedding_lookup_manager.cc`: `Create` (48), `Initialize` (286/320), `LookupDecode` (156), `LookupPrefill` (190/221) | Constructs `EmbeddingLookupText` and forwards regular text lookup calls to it. |
| LiteRT-LM route selection and PLE table extraction | `LiteRT-LM/runtime/executor/npu/llm_litert_npu_embedder.cc`: `NpuEmbedder::Create` (484; manager setup at 532, PLE extraction at 561) | Ordinary embedding manager setup and the `use_hw_ple_for_npu` branch that captures model weight pointers and quantization metadata. |
| Host INT4/INT8 row conversion | Same file: `UnpackInt4Row` (86 Android NEON, 159 scalar), `HWPerLayerEmbeddingLookup` (290), output conversion (324 onward) | Host-side row addressing, dequantization, optional INT16 requantization, and output layout. |
| Runtime PLE call sites | Same file: `LookupHwPle` (922), `RunPrefillPerLayer` (932), `RunDecodePerLayer` (970), `RunVerifyPerLayer` (996) | How prefill/decode/verify populate the decoder's PLE input buffer. |
| PLE params and declarations | `LiteRT-LM/runtime/executor/npu/llm_litert_npu_embedder.h`: `HWQuantizationParams` (121), `HWPleParams` (128), helper declaration (351) | Retained table pointers, scale metadata, output type and dimensions. |
| Test-only pack convention | `LiteRT-LM/runtime/executor/npu/llm_litert_npu_embedder_test.cc`: `PackInt4` (43), lookup tests (95 onward) | Synthetic even-index-low / odd-index-high packing and helper behavior. This is test code, not the production model exporter. |

No model-export packer for these PLE constants was identified in the runtime paths above: they consume already packed LiteRT weights. LiteRT does have a generic runtime CAST pack primitive, listed above, but that does not establish which upstream conversion/export step produced a particular model's bytes. The [external packed-LUT proposal](gemma4-embedding-int4-runtime-design-20261020.md) concerns a separate file-based format.
