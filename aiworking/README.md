# aiworking/

AI configuration workspace. Each tool subdirectory holds the configuration for one AI tool and follows the same layout convention; the top-level `shared/` holds tool-neutral config deployed to every tool's home:

- `shared/` (or tracked top-level files): public config, synced into the tool's home directory by the installer.
- `local/`: untracked machine-local files (secrets, tokens), git-ignored via `aiworking/*/local/**`.

| Directory | Function | Deploy target | Installer |
|---|---|---|---|
| `shared/` | Tool-neutral shared config — currently `skills/` (Agent Skills for both tools) | `~/.claude/skills/` + `~/.codex/skills/` | both setup scripts below |
| `claude/` | Claude Code shared instructions (`CLAUDE.md`), settings template, agents and skills | `~/.claude/` | `install/common/setup_claude_cli.sh` |
| `codex/` | Codex CLI shared instructions (`AGENTS.md`) plus local `auth.json` / `config.toml` | `~/.codex/` | `install/common/setup_codex_cli.sh` |
| `github/` | `GH_TOKEN` persistence for the `github-commit` skill; consumed in place, not deployed | — | — |

## Scope of claude/ and codex/

Both directories are standard-environment templates: tracked content here is deployed to `~/.claude/` / `~/.codex/` on every machine that runs the installers, so any change affects **all projects**. Keep unrelated content out:

- `claude/shared/CLAUDE.md` and `codex/shared/AGENTS.md` hold generic behavioral rules only. Never add repo- or project-specific content (install steps, repo structure, task notes) here — repo guidance belongs in the root `AGENTS.md`, project guidance belongs in each project's own `CLAUDE.md` / `AGENTS.md`.
- Do not add or modify files under `claude/shared/`, `codex/shared/`, or any `local/` unless the change is about the standard environment itself.
- `*/local/` is for machine-private secrets only and must never be committed.
- Repo-scoped content (e.g., skills that only make sense when working inside this repository) does not belong under `aiworking/`; see the root `AGENTS.md` for repository layout.

Notes:

- Installers copy only when the target file is missing. After changing tracked templates, refresh the deployed copies (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) manually.
- `claude/shared/CLAUDE.md` and `codex/shared/AGENTS.md` are paired instruction templates: apply every rule change to both.
- Per-directory details: `claude/README.md`, `github/README.md`.
