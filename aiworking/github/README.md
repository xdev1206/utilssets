# GitHub Local Auth

Store reusable GitHub auth data under `aiworking/github/local/`.

- `token.env`: untracked token file used by the `github-commit` skill
- `token.env.example`: tracked example format

Expected format:

```bash
export GH_TOKEN='github_pat_xxx'
```

`aiworking/github/local/` is git-ignored and intended for machine-local secrets.
