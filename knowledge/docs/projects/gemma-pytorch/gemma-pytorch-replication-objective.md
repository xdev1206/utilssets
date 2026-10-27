# Gemma PyTorch Replication Objective

The project objective is to use the upstream [Google DeepMind Gemma
repository](https://github.com/google-deepmind/gemma) as the behavioral and
architectural reference, then reproduce its supported Gemma model and
inference capabilities in the local `gemma_pytorch` repository. The local
implementation is PyTorch-based and should preserve model outputs, tokenizer
behavior, preprocessing, device support, and checkpoint compatibility where
the upstream behavior is applicable.

Consistency validation uses a repository-local `models/` symbolic link to the
managed model directory, specifically:

- `gemma-3-1b-it`
- `gemma-4-E2B-it`

The symbolic link should be present before running validation. If it or either
required model is unavailable, the setup instructions should tell the user to
download the models before continuing. Validation records should identify
which model was used, together with the prompt or image, device, dtype, and
comparison tolerance.

The repository should prioritize parity of core model components first, then
text and multimodal inference, CPU/GPU execution, and PyTorch/XLA execution.
Validation should use fixed checkpoints, prompts, images, and tolerances so
results can be compared against the reference implementation. Changes should
document any intentional deviation caused by PyTorch APIs, hardware, or
checkpoint format differences.

## Upstream reference

The upstream [`google-deepmind/gemma`](https://github.com/google-deepmind/gemma)
repository is the behavioral and architectural reference; its layout and
contribution rules do not describe the local `gemma_pytorch` checkout. The
upstream snapshot previously reviewed used the `gemma/`, `scripts/`,
`tokenizer/`, and `docker/` directories, pinned dependencies in
`requirements.txt`, and `setup.py` for installation. Its README documented
Docker execution on CPU, CUDA, TPU, and XLA-GPU. That snapshot reported no
tracked test or lint configuration; verify the upstream tree before relying on
that status. Contributions use GitHub pull requests and the Google CLA.
