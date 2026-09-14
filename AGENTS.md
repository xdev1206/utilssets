# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository. Codex reads it directly; Claude Code loads it through the root `CLAUDE.md`, which imports this file. Shared behavioral rules are not duplicated here — they come from the global instructions deployed by the standard environment (`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`).

## What This Repo Is

A personal collection of development utilities, installation scripts, shell configs, and code snippets for multi-platform (macOS / Linux / Android) environments. It is not a library with a build pipeline — it is a toolbox of scripts run directly.

## Installation

```bash
# Full setup (auto-detects OS, requires bash not sh)
bash install.sh

# macOS only
bash install/darwin/wizard_Darwin.sh

# Linux only
bash install/linux/wizard_Linux.sh

# Install Claude Code CLI + shared ~/.claude config
bash install/common/setup_claude_cli.sh

# Install Codex CLI + NVM + Node
bash install/common/setup_codex_cli.sh

# Install PyTorch (see file for CUDA version variants)
# install/common/setup_torch.sh is a reference file — copy the relevant pip command and run manually

# Setup pyenv
bash install/common/setup_pyenv.sh

# Configure locale (default: C.UTF-8)
bash install/common/setup_locale.sh [LOCALE]
```

After installation, reload your shell:
```bash
source ~/.zshrc   # or ~/.bashrc / ~/.bash_profile
```

## Environment Bootstrap

The core environment chain is:

1. Shell RC (`.zshrc`, `.bashrc`, or `.bash_profile`) exports `UTILSSETS_ROOT` and sources `config/shell/config.env`
2. `config/shell/config.env` iterates over `config/shell/*.conf` and sources each one
3. The `.conf` files define env vars (`env.conf`) and PATH entries (`path.conf`)

`install/common/env.sh` is the installer-side counterpart — it sets up the above chain and provides `export_env` / `complete_env_path` helpers used by all install scripts to persist variables into `config/shell/env.conf` and `config/shell/path.conf`.

Key env vars set after install:
- `UTILSSETS_ROOT` — repo root; used everywhere as a prefix
- `BIN_DIR` → `$UTILSSETS_ROOT/bin` (on PATH)
- `TOOLS_BIN_DIR` → `$UTILSSETS_ROOT/tools/bin` (on PATH)
- `LIB_PYTHON` → `$UTILSSETS_ROOT/lib/python` (on PYTHONPATH)
- `ANDROID_SDK_ROOT`, `ANDROID_NDK_HOME`, `PYENV_ROOT`, `NVM_DIR`

## Shell Utilities (lib/shell/common.sh)

Must be sourced before use. Provides:
- `log_info` / `log_warn` / `log_error` — colored output
- `error_exit <msg> [code]` — print error and exit
- `command_exists <cmd>` — boolean check
- `detect_os` — returns `Darwin` or `Linux`
- `get_script_dir` — bash/zsh-compatible `dirname`

Most installer entry scripts source `install/common/env.sh`, which in turn sources `lib/shell/common.sh` indirectly. Common installers under `install/common/` usually source their local `env.sh`.

## Python Library (lib/python/pyutils/)

Importable as `from pyutils.ml import torch_model_utils, onnx_model_utils` (requires `LIB_PYTHON` on `PYTHONPATH`).

```bash
pip install -r lib/python/requirements.txt
```

Sub-modules:
- `pyutils/ml/torch_model_utils.py` — PyTorch model helpers
- `pyutils/ml/onnx_model_utils.py` — ONNX export / quantization helpers
- `pyutils/ml/torch_env.py` — environment detection (CUDA, device)

`src/ml/quant_gptq.py` is a standalone GPTQ quantization script (not part of the library).

## Scripts

Scripts are organized by domain under `scripts/`:

| Directory | Purpose |
|---|---|
| `scripts/android/` | ADB utilities, APK analysis, CPU/memory monitoring on-device |
| `scripts/android/mtk/` | MediaTek-specific: NPU benchmarking, MDLA compilation, APU freq dump |
| `scripts/git/` | Git and Gerrit helpers |
| `scripts/docker/` | Docker container utilities |
| `scripts/system/darwin/` | macOS system scripts |
| `scripts/system/debian/` | Debian/Ubuntu system scripts |

Notable scripts:
- `scripts/android/cpu_mem_info.sh` — polls CPU/memory for a named process on Android (run via adb shell)
- `scripts/android/mtk/bench_npu_gemma3.py` — NPU benchmark for Gemma 3 on MTK hardware
- `bin/auto_codeformat.sh` — code formatter runner (clang-format, black, etc.)

## Adding a New Install Script

Follow the pattern used by existing scripts:
1. `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
2. `source "${SCRIPT_DIR}/env.sh"` (for `install/common/` scripts) or `source "${SCRIPT_DIR}/../common/env.sh"` (for platform-specific installers)
3. Use `export_env NAME value` to persist env vars to `config/shell/env.conf`
4. Use `complete_env_path PATH /some/path` to add to PATH in `config/shell/path.conf`
5. Update the `Installation` section above (and root `README.md` if user-facing) in the same change

## Repository Skills (.claude/skills/)

Repo-scoped Agent Skills live in `.claude/skills/<name>/SKILL.md` — the single source of truth, read natively by Claude Code.
`.codex/skills` is a relative symlink to `../.claude/skills` so Codex reads the same skills; never edit it or replace it with a real directory.
`.agents/` is intentionally unused: Claude Code does not scan it and Codex discovery of it is unreliable.

## Shared Skills (aiworking/shared/)

`aiworking/shared/skills/` holds tool-neutral shared Agent Skills (single source of truth).
Both `install/common/setup_claude_cli.sh` and `install/common/setup_codex_cli.sh` deploy them (copy-if-missing) into `~/.claude/skills/` and `~/.codex/skills/`; refresh deployed copies manually after content changes.

## Claude Config (aiworking/claude/)

`aiworking/claude/` is the standard Claude workspace in this repo.

Standard structure:
- `aiworking/claude/README.md` — Claude workspace overview and standard layout
- `aiworking/claude/shared/CLAUDE.md` — shared Claude instructions copied to `~/.claude/CLAUDE.md`
- `aiworking/claude/shared/settings.json.example` — tracked settings template without machine-local secrets
- `aiworking/claude/shared/.claude/` — shared Claude agents copied into `~/.claude/`
- `aiworking/claude/local/` — untracked machine-local Claude settings such as `settings.json`

As part of the standard environment used by `install/common/setup_claude_cli.sh`, generated projects should include a root `docs/README.md`.
Use that project-level `docs/README.md` as the index for documents under the project's `docs/` directory, and update it whenever a new document is added there.
`install/common/setup_claude_cli.sh` installs Claude Code and syncs the shared/local Claude files above into `~/.claude/`.
`aiworking/claude/shared/CLAUDE.md` and `aiworking/codex/shared/AGENTS.md` are paired shared instruction templates: when rules change, update both in the same change and refresh their deployed copies (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`), since the installers only copy when the target is missing.

## Codex Config (aiworking/codex/)

`aiworking/codex/shared/` contains public Codex config files copied into `~/.codex/` during installation.
`aiworking/codex/local/` is reserved for untracked machine/account-specific files such as `auth.json`, `config.toml`, or future private extensions.
If `aiworking/codex/local/` is missing `auth.json` or `config.toml`, `install/common/setup_codex_cli.sh` generates demo placeholders there before syncing.
For Codex 0.148+ custom providers, the generated `config.toml` includes `env_key = "CODEX_API_KEY"` so the provider sends an authorization header explicitly instead of relying on `auth.json` fallback behavior from older versions; users still need to export `CODEX_API_KEY` in their shell environment before launching Codex.
`install/common/setup_codex_cli.sh` only copies files into `~/.codex/` when the target path does not already exist.
Projects created from this standard environment should also include a root `docs/README.md`; every time a new file is added under that project's `docs/`, update `docs/README.md` to keep the document index current.
