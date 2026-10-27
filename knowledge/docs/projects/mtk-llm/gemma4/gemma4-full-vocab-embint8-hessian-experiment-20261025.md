# Gemma4 Full-Vocabulary Embedding/PLE INT8 + Hessian Experiment (2026-10-25)

## Outcome and status

This experiment quantized the complete 262,144-token Gemma-4-E2B-it model with W4A16 decoder layers and INT8 Embedding/PLE LUTs, using Hessian weight optimization. PTQ, fix-shape, NP8/MT6899 compilation, extract-shared, and packaging completed. The packaged asset exists at `assets/assets_gemma4_full_embint8_hessian_np8_ctx4096_int8_20261025/`.

The device benchmark and FP32-versus-quantized quality comparison have not been run. The experiment record is `blocked` at the evaluation gate, with quality verdict `not-run`. An empty result directory exists at `verify_logs/device_full_embint8_hessian_np8_ctx4096_20261026/`; it contains no benchmark outputs.

## Configuration and calibration

- Run workspace: `work/gemma4_e2b_it_full_embint8_hessian_20261025/`.
- Model: Gemma-4-E2B-it, full vocabulary (`vocabSize=262144`), hidden size 1536, 35 decoder layers, tied embeddings.
- Precision config snapshot: `gemma4_precision_config.json` in the run workspace. Layers 0–34, tail, default, and residual use `sym4W_sym16A`; `embeddings=int8`, `logits=float`, and `cache=int8`. PTQ exported both `embedding_int8.bin` and `ple_int8.bin`.
- Calibration prompts: `open_prompt_500_20.jsonl` (20 prompts). The record says 40 calibration batches were generated; generator output is `calibration_datasets/gemma-4-E2B-it/`.
- The generated calibration dataset directory and the source checkpoint's `model.safetensors` are not present in the retained run workspace, so the raw calibration tensors and original model weight file cannot currently be recovered from this run directory.
- PTQ settings reported by the log: calibration method `Overall`, weight optimization `hessian`, weight granularity `Per-channel`, dynamic output format TFLite, and NP compatibility defaulting to converter 10.
- Toolchain from the PTQ log: `mtk_llm_sdk 4.0.1b2.post1.dev125+g10d6b0ede`, `mtk_converter 10.6.0`, `mlkits 10.4.9`.

The resolved configuration and settings are recorded, but the original full shell invocation was not retained. Do not reconstruct it as an exact command from the log summary.

## Preserved artifacts

- Calibration input: `work/gemma4_e2b_it_full_embint8_hessian_20261025/open_prompt_500_20.jsonl`.
- Calibration generator log: `work/gemma4_e2b_it_full_embint8_hessian_20261025/logs/20261025_134454_mtk_make_llm_ptq_calib_dataset.log`.
- Dynamic PTQ model and parameters: `work/gemma4_e2b_it_full_embint8_hessian_20261025/quantized_models/dynamic_shape/gemma-4-E2B-it_full_embint8_hessian_Overall/`; this retains per-layer TFLite/pickle files, `tmp_qparams_config.json`, config, and API log.
- PTQ log: `work/gemma4_e2b_it_full_embint8_hessian_20261025/logs/ptq_full_embint8_hessian_20261025.log`.
- Fixed-shape output: `work/gemma4_e2b_it_full_embint8_hessian_20261025/quantized_models/gemma-4-E2B-it_full_embint8_hessian_Overall/`, including the 1-token and 256-token graphs, `embedding_int8.bin`, and `ple_int8.bin`.
- Fix-shape log: `work/gemma4_e2b_it_full_embint8_hessian_20261025/logs/20261025_140701_mtk_fix_llm_shape.log`.
- MDLA compile/extract logs and SHA: `work/gemma4_e2b_it_full_embint8_hessian_20261025/mdla_build/{1t,256t,extract.log,gemma-4-E2B-it_sha.bin}`.
- Valid packaged assets: `assets/assets_gemma4_full_embint8_hessian_np8_ctx4096_int8_20261025/`. The LUT sizes are 402,653,184 B (Embedding) and 2,348,810,240 B (PLE); the PROM and GEN shared DLA sizes are 2,765,829 B and 880,121,415 B; the SHA is 295,789,568 B. This is the valid package; the similarly named directory without `_int8_` contains the mistakenly selected FP16 LUTs.
- Package manifest:

  | File | Size |
  |---|---:|
  | `BUILD_INFO.txt` | 2,481 B |
  | `embedding_int8.bin` | 402,653,184 B |
  | `ple_int8.bin` | 2,348,810,240 B |
  | `gemma-4-E2B-it_full_embint8_hessian_Overall_1t4096c_0_shared.dla` | 880,121,415 B |
  | `gemma-4-E2B-it_full_embint8_hessian_Overall_256t4096c_0_opt_sharedkv_shared.dla` | 2,765,829 B |
  | `gemma-4-E2B-it_sha_ctx4096.bin` | 295,789,568 B |
  | `gemma4_e2b_device.yaml` | 4,049 B |
  | `tokenizer_gemma4.model` | 4,689,016 B |
- A package named `assets/assets_gemma4_full_embint8_hessian_np8_ctx4096_20261025/` was also produced with FP16 LUTs by mistake and must not be used for this experiment.
- Per-run `artifacts.sha256` lists byte sizes and SHA-256 for 150 retained files: all dynamic/fixed quantized model files, MDLA build outputs, valid package files, the source and experiment precision configs, effective parameter snapshot, model config, and calibration prompts.

## Missing evaluation and reproducibility evidence

- Original calibration, PTQ, MDLA compile, extract-shared, and package shell invocations were not retained. The per-run `commands.sh` keeps the exact fix-shape invocation recoverable from its log and marks the other commands `not-found`; the stage logs preserve resolved arguments and versions but do not make a complete rerunnable pipeline.
- No device output files exist under `verify_logs/device_full_embint8_hessian_np8_ctx4096_20261026/`; device inference is `not-run`.
- No matched FP32 and quantized outputs, per-prompt comparison, or quality summary were found. FP32-versus-HuggingFace alignment and quantized quality verdict are `not-run` for this experiment.
- Because there is no evaluation, successful PTQ/build/package does not establish generation quality or deployment acceptance.

## Related records

- Current project state: `gemma4-current-state-20261025.md`, section “完整词表 Embedding/PLE INT8 + Hessian 部署链路”.
- Project execution record and supporting config, effective parameters, recovered commands, logs, comparison status, and hashes: `work/gemma4_e2b_it/quantization_experiments/20261025_full_embint8_hessian/`.
