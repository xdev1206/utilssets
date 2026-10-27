# Gemma4 Quantization Experiment Records

Each quantization experiment is a reproducible record, not just a PTQ output directory or a device benchmark. Keep the configuration, resolved parameters, commands, PTQ evidence, artifacts, and FP32-versus-quantized quality comparison under one stable experiment ID. Record incomplete or failed runs too; never make missing stages look complete.

## Record location

Use one directory per run:

```text
work/<model>/quantization_experiments/<YYYYMMDD_HHMMSS>_<short-name>/
```

Do not overwrite a run when its configuration, calibration data, PTQ options, or source model changes; create a new experiment ID and link it to the earlier run. Large TFLite, DLA, and LUT assets may remain in their pipeline output directories, but the experiment record must list their paths, sizes, and SHA-256 hashes.

## Required contents

- `record.md`: experiment ID, objective, model/checkpoint and revision, quantization scope, status, outcome, limitations, and links to the files below.
- `quant_config.json`: exact configuration file used, copied or content-addressed so later edits cannot change the record.
- `quant_params.json`: resolved PTQ parameters, including weight/activation precision, granularity, calibration method and dataset identity, Hessian/weight-optimization options, and relevant graph/runtime input types. If the tool emits no parameter file, record the resolved values in `record.md` and link the source log.
- `commands.sh`: exact commands for calibration, PTQ, fix-shape, graph changes, compilation, packaging, and evaluation. Preserve arguments and working directories; redact credentials and secrets.
- `logs/`: complete PTQ and later-stage stdout/stderr logs, or relative links to their preserved originals.
- `artifacts.sha256`: paths, sizes, and checksums for the PTQ model, LUTs, compiled assets, and packaged model; note any artifact not retained.
- `comparison/`: prompts and decode settings shared by both paths, FP32 outputs, quantized outputs, per-prompt comparison, and a machine-readable summary. Store the FP32/HuggingFace alignment record and link it here when applicable.

## Comparison requirements

Run FP32 and quantized models on the same prompts, tokenizer/chat template, and decoding parameters. Keep raw outputs so the comparison can be reviewed later. Record per-prompt and aggregate `first_mismatch_idx`, `token_match_ratio`, and `rouge_l`, plus semantic observations and a `PASS`, `边缘`, `FAIL`, or `not-run` verdict. Hardware execution success is a separate result from output quality.

For Gemma4 -it deployment experiments, satisfy the FP32-versus-HuggingFace alignment gate before PTQ or later deployment stages, following the project `AGENTS.md`. Link that alignment record; do not treat it as the quantized comparison.

## Status

Use `planned`, `running`, `blocked`, or `complete` for the experiment workflow, and record quality verdict separately. A PTQ-only run remains incomplete for model-quality evaluation. If a stage cannot run, record why, the missing artifact, and the next action. Do not infer PASS from a successful process exit code.

## Record template

```markdown
# <experiment-id>

- Status: planned | running | blocked | complete
- Quality verdict: not-run | PASS | 边缘 | FAIL
- Objective:
- Model/checkpoint/revision:
- Quantization scope and precision:
- Configuration: `quant_config.json` (SHA-256: ...)
- Resolved parameters: `quant_params.json` or PTQ log section ...
- Calibration dataset/method and identity:
- Toolchain versions:
- Commands: `commands.sh`
- PTQ log: `logs/...`
- PTQ/fixed/compiled/package artifacts: paths, sizes, SHA-256 in `artifacts.sha256`
- FP32/HF alignment record:
- FP32-versus-quantized prompts and decoding parameters:
- Comparison files and metrics:
- Outcome and limitations:
- Missing stages and next action:
```
