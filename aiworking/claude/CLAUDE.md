# CLAUDE.md

Shared Claude instructions for projects created from this repository.

## 1. Think Before Coding

- State assumptions explicitly before implementing.
- If multiple interpretations exist, call them out instead of picking one silently.
- If something is unclear, stop and say what is unclear.

## 2. Simplicity First

- Prefer the minimum code that solves the requested problem.
- Do not add abstractions, configuration, or features that were not requested.
- If a simpler implementation exists, use it.

## 3. Surgical Changes

- Touch only files and lines required for the task.
- Match the existing style of the project.
- Remove only the dead code created by your own changes.

## 4. Goal-Driven Execution

- Turn requests into verifiable checks when possible.
- For bug fixes, reproduce the bug first, then make the check pass.
- For non-trivial work, state a short step-by-step plan and verify each step.

## 5. Project Docs Index

- Keep a root `docs/README.md` as the index for documents under `docs/`.
- Every time a new file is added under `docs/`, update `docs/README.md` in the same change.
- Keep `docs/README.md` minimal: list each document and its purpose.
