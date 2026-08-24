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

## Step 2 — Inspect changes

Run the following in parallel:
- `git status --short`
- `git diff HEAD`  (shows both staged and unstaged changes)

If there are no changes (clean working tree and no staged files), tell the user and stop.

## Step 3 — Stage all changes

```bash
git add -A
```

Then run `git diff --cached --stat` to confirm what will be committed.

## Step 4 — Generate commit message (Conventional Commits v1.0.0)

Analyze the staged diff and determine:

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
docs: add CLAUDE.md with project architecture notes
feat(ml)!: replace onnx export API — removes legacy kwargs
```

## Step 5 — Show and confirm

Print the full proposed commit message. Ask the user:
> "Commit with this message? (yes / edit / abort)"

- If **yes** → proceed to Step 6
- If **edit** → ask user for the corrected message, then proceed
- If **abort** → run `git reset HEAD` to unstage, stop

## Step 6 — Commit

```bash
git commit -m "$(cat <<'EOF'
<the commit message>
EOF
)"
```

## Step 7 — Push

Configure the remote to use the token for this push only (do not persist
credentials to disk):

```bash
REMOTE_URL=$(git remote get-url origin)
# inject token into URL for this push only
AUTH_URL=$(echo "$REMOTE_URL" | sed "s|https://|https://${GH_TOKEN}@|")
git push "$AUTH_URL" HEAD
```

If `origin` already uses SSH (`git@github.com:...`), push normally:
```bash
git push origin HEAD
```

After a successful push, print the remote URL and the commit hash.

## Error handling

- If `git push` fails with 403/401 → tell the user the saved `GH_TOKEN`
  may be missing, expired, or missing repo push permission
- If `git push` fails with rejected (non-fast-forward) → tell the user to pull/rebase first, do NOT force push
- Never use `--force` or `--no-verify`
