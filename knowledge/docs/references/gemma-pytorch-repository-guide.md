# Gemma PyTorch Repository Reference

## Verified layout and workflows

The repository is a Python package named `gemma`. Core model, configuration,
tokenizer, preprocessing, and SigLIP vision code live under `gemma/`. The
`scripts/` directory contains executable examples: `run.py` for text
inference, `run_multimodal.py` for multimodal inference, and `run_xla.py` for
PyTorch/XLA. Model tokenizers are stored under `tokenizer/`; sample images are
under `scripts/images/`; container definitions are under `docker/`.

Dependencies are pinned in `requirements.txt` and installation metadata is in
`setup.py`. The README documents Docker-based CPU, CUDA, TPU, and XLA-GPU
execution. The repository currently has no tracked `tests/` directory, test
runner configuration, or formatter/linter configuration.

Recent commits use short imperative-style summaries, for example `Add
Gemma3` and `Run gemma3 on gpus`. Contributions require review through GitHub
pull requests and a Google Contributor License Agreement, as documented in
`CONTRIBUTING.md`.

## Limitations

Inference requires a compatible checkpoint supplied through `--ckpt`; large
models may require GPU, TPU, or substantial CPU memory. Treat generated model
outputs and downloaded checkpoints as runtime data rather than repository
assets.
