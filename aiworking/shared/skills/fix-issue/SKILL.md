---
name: fix-issue
description: Fix a GitHub issue; ask before committing or publishing changes
---
Fix the GitHub issue number or URL provided by the user. If none is provided, ask for it before proceeding.

Invoking this skill does not authorize committing, pushing, or creating a PR.

1. Use `gh issue view <issue-number-or-URL>` to get the issue details
2. Understand the problem described in the issue
3. Search the codebase for relevant files
4. Implement the necessary changes to fix the issue
5. Follow the repository's verification instructions; add or run tests only when the user or repository instructions require them
6. Run linting or type checks only when the user or repository instructions require them
7. Prepare a descriptive commit message and PR summary
8. Ask the user for explicit confirmation before committing, pushing, or creating the PR
9. Only after confirmation, commit, push, and create the PR. If the user declines, leave the changes uncommitted and do not publish them.
