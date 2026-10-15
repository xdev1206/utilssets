# Gemma PyTorch Alignment Test Plan

Alignment tests should separate deterministic preprocessing checks from
checkpoint-based numerical checks. The repository can run tokenizer,
configuration, pan-and-scan, image normalization, and batch-shape tests
without loading model weights. Checkpoint tests should use the repository's
`models/` link and record the model, prompt or image, device, dtype, generated
length, and tolerance.

The Gemma 3 1B instruction-tuned checkpoint now has a local
`model.safetensors` key adapter and is ready for runtime numerical alignment.
The Gemma 4 E2B checkpoint now has dense text, vision, audio, and tokenizer
adapters and an image processor. Audio processor integration and full runtime
multimodal numerical alignment remain pending. A fixed image+text CUDA
bfloat16 comparison now has matching top-1/top-5 tokens with mean absolute
logit error about 0.21. A CUDA bfloat16 text next-token baseline is recorded
for the fixed prompt; test data should retain this partial status instead of
treating multimodal support as complete.

The first runtime smoke baseline uses the Gemma 3 1B checkpoint on CUDA with
seed `12345`, prompt `The capital of Italy is`, and two generated tokens; the
recorded output is ` Rome.`. The command and baseline metadata live in
`tests/data/alignment_cases.json`.
