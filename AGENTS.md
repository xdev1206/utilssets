# AGENTS.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Documentation Sync

**After code changes, update docs in the same turn.**

- If you add, rename, or remove a file referenced in `README.md` or `AGENTS.md`, update the reference.
- If you add a new install script, update the "Adding a New Install Script" section or the structure overview.
- Keep docs minimal — one line per entry, match existing format.
- Skip doc updates for trivial or temporary changes.

## 6. Change Summary Output

**After each modification, output a structured summary in this order:**

1. **Modification summary** — Brief overview of what was changed
2. **Specific change points** — Show the actual modifications (diff or code snippets)
3. **Documentation update summary** — If docs were updated, list which files and what changed

This applies to all code changes, not just large refactors.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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

## Codex Config (aiworking/codex/)

`aiworking/codex/shared/` contains public Codex config files copied into `~/.codex/` during installation.
`aiworking/codex/local/` is reserved for untracked machine/account-specific files such as `auth.json`, `config.toml`, or future private extensions.
If `aiworking/codex/local/` is missing `auth.json` or `config.toml`, `install/common/setup_codex_cli.sh` generates demo placeholders there before syncing.
`install/common/setup_codex_cli.sh` only copies files into `~/.codex/` when the target path does not already exist.
