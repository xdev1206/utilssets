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

For HTTPS remotes, pass the token through a temporary askpass helper. Do not
put credentials in the remote URL or command arguments, and do not persist
credentials to Git config:

```bash
REMOTE_NAME=origin
REMOTE_URL=$(git -C "$REPO" remote get-url "$REMOTE_NAME")

# Resolve the destination branch explicitly. Do not push bare HEAD: a local
# branch such as `default` can otherwise create/update the wrong remote branch.
UPSTREAM_REF=$(git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name \
  '@{upstream}' 2>/dev/null || true)
if [[ "$UPSTREAM_REF" == "$REMOTE_NAME"/* ]]; then
  TARGET_BRANCH="${UPSTREAM_REF#${REMOTE_NAME}/}"
else
  REMOTE_HEAD=$(git -C "$REPO" symbolic-ref --short \
    "refs/remotes/${REMOTE_NAME}/HEAD" 2>/dev/null || true)
  TARGET_BRANCH="${REMOTE_HEAD#${REMOTE_NAME}/}"
fi
if [ -z "$TARGET_BRANCH" ]; then
  echo "error: cannot determine push target branch for $REPO" >&2
  exit 1
fi

if [[ "$REMOTE_URL" == https://* ]]; then
  # Drop any existing URL userinfo before passing the remote to Git.
  PUSH_URL=$(printf '%s\n' "$REMOTE_URL" | sed -E 's#^(https://)[^/@]+@#\1#')
  ASKPASS_SCRIPT=$(mktemp /tmp/github-askpass.XXXXXX)
  trap 'rm -f "$ASKPASS_SCRIPT"' EXIT
  cat > "$ASKPASS_SCRIPT" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*) printf '%s\n' 'x-access-token' ;;
  *Password*) printf '%s\n' "$GH_TOKEN" ;;
  *) exit 1 ;;
esac
EOF
  chmod 700 "$ASKPASS_SCRIPT"
  if GIT_ASKPASS="$ASKPASS_SCRIPT" GIT_TERMINAL_PROMPT=0 \
    git -C "$REPO" push "$PUSH_URL" "HEAD:${TARGET_BRANCH}"; then
    PUSH_STATUS=0
  else
    PUSH_STATUS=$?
  fi
  rm -f "$ASKPASS_SCRIPT"
  trap - EXIT
  if [ "$PUSH_STATUS" -ne 0 ]; then
    exit "$PUSH_STATUS"
  fi
else
  git -C "$REPO" push "$REMOTE_NAME" "HEAD:${TARGET_BRANCH}"
fi
```

The non-HTTPS branch above handles SSH remotes using the configured SSH
authentication.

Before pushing, report the resolved target branch. After each successful push,
print the repository path, target branch, and commit hash. Never print a remote
URL that may contain credentials.

## Error handling

- If `git push` fails with 403/401 → tell the user the saved `GH_TOKEN`
  may be missing, expired, or missing repo push permission
- If `git push` fails with rejected (non-fast-forward) → tell the user to pull/rebase first, do NOT force push
- Never use `--force` or `--no-verify`
