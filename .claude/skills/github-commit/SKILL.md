---
name: github-commit
description: Stage all changes, generate a Conventional Commits message from the diff, commit, and push to GitHub.
---

Follow these steps exactly. Do not skip steps or batch them unless noted.

## Step 1 — Load or save token

Use an existing `GH_TOKEN` environment variable if present.

Otherwise, load it from the untracked local file:

```bash
TOKEN_FILE="aiworking/github/local/token.env"
if [ -z "${GH_TOKEN:-}" ] && [ -f "$TOKEN_FILE" ]; then
  # shellcheck disable=SC1090
  . "$TOKEN_FILE"
fi
```

Expected file content:

```bash
export GH_TOKEN='github_pat_xxx'
```

If `GH_TOKEN` is still empty after this step:

1. Ask the user for a GitHub token
2. Save it to `aiworking/github/local/token.env`
3. Set file mode to `600`
4. Load it into the current shell

Use:

```bash
mkdir -p aiworking/github/local
cat > aiworking/github/local/token.env <<'EOF'
export GH_TOKEN='the_token_from_user'
EOF
chmod 600 aiworking/github/local/token.env
# shellcheck disable=SC1090
. aiworking/github/local/token.env
```

Do not print the token back to the user after saving it.

## Step 2 — Identify repositories and inspect changes

This workspace may contain more than one Git repository. Always inspect and
process these repositories independently:

```bash
MAIN_REPO="$(git rev-parse --show-toplevel)"
MANIFEST_REPO="${MAIN_REPO}/src/repo/.repo/manifests"
```

If `git rev-parse --show-toplevel` fails, stop and ask the user to run the
skill from the main repository. If `MANIFEST_REPO` is not a Git repository,
report it as unavailable and process only the main repository.

The manifests directory is a separate Git repository and must never be
included in the main repository's commit. For each repository that exists,
run the following in parallel within that repository:

- `git status --short`
- `git diff HEAD`  (shows both staged and unstaged changes)

If a repository has no changes (clean working tree and no staged files), report
it as clean and skip its commit. Continue inspecting the other repository.

## Step 3 — Stage changes independently

```bash
git -C "$MAIN_REPO" add -A
git -C "$MANIFEST_REPO" add -A
```

Run `git diff --cached --stat` separately in each repository. Confirm that
only that repository's files are staged.

## Step 4 — Generate separate commit messages (Conventional Commits v1.0.0)

For each repository with staged changes, analyze its staged diff and determine:

**Type** — choose one:
| Type | When to use |
|---|---|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, whitespace — no logic change |
| `refactor` | Code restructure with no behavior change |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system, dependencies |
| `ci` | CI/CD configuration |
| `chore` | Maintenance tasks, tooling, configs |
| `revert` | Reverts a prior commit |

**Scope** (optional) — the subsystem affected, e.g. `android`, `install`, `vim`, `ml`, `docker`. Use the top-level directory name where most changes live. Omit if changes span many unrelated areas.

**Breaking change** — append `!` after type/scope if any public API or behavior is removed/changed incompatibly.

**Format:**
```
<type>[(<scope>)][!]: <description>

[optional body — explain WHY, not what. wrap at 72 chars]

[optional footers]
[BREAKING CHANGE: <description>  ← required if ! was used]
```

Rules for `<description>`:
- Imperative mood, lowercase, no period at end
- ≤72 characters on the summary line
- English preferred; use Chinese only if the diff is entirely Chinese comments/docs

**Examples:**
```
feat(install): add setup_tmux script for color config
fix(android): handle missing pid in cpu_mem_info loop
chore(config): update vimrc plugin settings
docs: add CLAUDE.md/AGENTS.md with project architecture notes
feat(ml)!: replace onnx export API — removes legacy kwargs
```

## Step 5 — Show and confirm

Print each proposed commit message together with its repository path. Ask for
confirmation separately for each repository:
> "Commit with this message? (yes / edit / abort)"

- If **yes** → commit and push that repository, then continue to the next one
- If **edit** → ask user for the corrected message, then commit and push that
  repository
- If **abort** → run `git reset HEAD` in that repository and skip it; do not
  discard working-tree changes or alter the other repository

## Step 6 — Commit each repository independently

```bash
git -C "$REPO" commit -m "$(cat <<'EOF'
<the commit message>
EOF
)"
```

Run this once for each confirmed repository. A commit or push failure in one
repository must be reported with that repository's path and must not cause a
force push or destructive cleanup in the other repository.

## Step 7 — Push each repository independently

Configure the remote to use the token for this push only (do not persist
credentials to disk):

```bash
REMOTE_URL=$(git -C "$REPO" remote get-url origin)
# inject token into URL for this push only
AUTH_URL=$(echo "$REMOTE_URL" | sed "s|https://|https://${GH_TOKEN}@|")
git -C "$REPO" push "$AUTH_URL" HEAD
```

If `origin` already uses SSH (`git@github.com:...`), push normally:
```bash
git -C "$REPO" push origin HEAD
```

After each successful push, print that repository's remote URL and commit hash.

## Error handling

- If `git push` fails with 403/401 → tell the user the saved `GH_TOKEN`
  may be missing, expired, or missing repo push permission
- If `git push` fails with rejected (non-fast-forward) → tell the user to pull/rebase first, do NOT force push
- Never use `--force` or `--no-verify`
