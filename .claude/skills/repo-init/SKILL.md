---
name: repo-init
description: Initialize and synchronize this repository's repo workspace when the user requests repo setup or repair.
---

# Repo initialization

Use this skill for requests to initialize, repair, or synchronize the repo workspace under `src/repo`.

Run the repository entrypoint from the workspace root. The supported commands
are:

```bash
# Initialize and sync all repositories.
bash install/common/setup_repo.sh

# Sync all already-initialized repositories.
bash install/common/setup_repo.sh sync

# Sync only selected project paths.
bash install/common/setup_repo.sh sync ml/onnx/onnx
bash install/common/setup_repo.sh sync ml/onnx/onnx ml/arm/CMSIS-DSP

# List selectable project paths.
bash install/common/setup_repo.sh list

# Add a GitHub repository with an explicit path and revision.
bash install/common/setup_repo.sh add https://github.com/example/project.git ml/example/project main
```

`$repo-init` is equivalent to the first command. `$repo-init sync` without
paths means all repositories; paths after `sync` select specific projects.
`$repo-init add <github-url> <path> <revision>` adds a project to the local
`.repo/manifests/default.xml` and syncs the new project. Both `path` and
`revision` are required. When `path` is missing, suggest the repository name;
when `revision` is missing, suggest `main`. Use `$repo-init list`
before targeted sync when the user has not provided a manifest path. Do not
silently switch between all-project and targeted modes.

Only HTTPS GitHub URLs are accepted. Validate the URL and project path before
editing the manifest, reject duplicate project names or paths, and do not
commit generated files under `src/repo/.repo`. The manifest repository must be
committed separately if the addition should be shared with other workspaces.

The entrypoint handles the `repo` launcher, network detection, incomplete `.repo` metadata, GitHub authentication, and synchronization. Do not manually delete `src/repo` or `.repo` unless the user explicitly requests destructive cleanup.

Authentication:

- Prefer the existing environment or `aiworking/github/local/token.env`.
- The local file is ignored by Git and should contain `export GH_TOKEN='...'`; optionally set `GH_USERNAME`.
- Never print, commit, or put the token in a command-line URL. If credentials are absent or expired, tell the user to configure them locally without asking them to paste a token into chat.

Verification:

1. Require a zero exit status from `setup_repo.sh`.
2. In all-project mode, from `src/repo`, run `repo manifest -r` and confirm it
   succeeds. In targeted mode, verify each requested path exists and has a
   valid Git `HEAD`.
3. If synchronization fails because a manifest references a nonexistent upstream branch, report the project and actual remote branches. Fix the upstream manifest repository rather than committing generated files under `src/repo/.repo` to this repository.

Report the command result, the first concrete failure, and whether the workspace passed manifest verification. Do not claim success when only `repo init` succeeded without a successful sync.
