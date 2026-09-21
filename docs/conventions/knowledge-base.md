# Knowledge Base Organization and Maintenance

This document defines how reusable knowledge in this repository is organized, written, reviewed, and retired for Codex and other coding agents. Project documentation belongs under `docs/`; general-purpose knowledge that is not directly related to this project belongs under `knowledge/`.

## 1. Source Layers

Use the following division of responsibility:

| Location | Purpose | Do not use it for |
| --- | --- | --- |
| `AGENTS.md` | Rules that agents must follow while working in the repository | Long explanations, incident history, or full runbooks |
| `docs/` | Stable, reusable project knowledge | Machine-local secrets or temporary notes |
| `knowledge/` | General-purpose knowledge, learning notes, and reusable ideas unrelated to this project | Project implementation rules or machine-local secrets |
| `.claude/skills/<name>/SKILL.md` | Repeatable workflows with inputs, actions, and verification | General background knowledge |
| Source code and configuration | The current implementation and its actual defaults | Unverified design assumptions |

If the same topic appears in more than one layer, keep one primary source and link to it from the others. Do not copy the full content between files.

## 2. Directory Structure

Organize documentation by domain, not by file format:

```text
docs/
├── README.md
├── architecture/       # System structure and component relationships
├── conventions/        # Development and documentation conventions
├── decisions/          # Architecture and technology decisions
├── runbooks/            # Standard operational procedures
├── troubleshooting/     # Symptoms, causes, fixes, and verification
├── reference/           # Commands, parameters, and configuration reference
└── history/             # Historical information that remains useful
```

General-purpose knowledge uses a separate tree:

```text
knowledge/
├── AGENTS.md
├── README.md
├── docs/
│   ├── README.md
│   ├── concepts/
│   ├── howto/
│   ├── notes/
│   └── references/
└── templates/
    └── note.md
```

Keep directory nesting at three levels or fewer. Use lowercase, hyphen-separated filenames such as `manifest-management.md`. Do not use names such as `new.md`, `latest.md`, `temp.md`, `misc.md`, or `note1.md`.

Each document must have one primary topic. Split unrelated topics into separate documents and connect them with a `Related Files` section.

## 3. Classification Rules

First determine the scope:

1. Knowledge that directly describes `utilssets` source code, scripts, configuration, or project workflows belongs under the project `docs/` tree.
2. General knowledge that is not directly related to this project belongs under `knowledge/docs/`.
3. A rule that agents must always follow belongs in the applicable `AGENTS.md`.
4. A repeatable multi-step operation that an agent can execute belongs in the applicable Skill.

For project documentation, use these categories:

- System structure → `docs/architecture/`
- Architecture or technology decision → `docs/decisions/`
- Standard manual procedure → `docs/runbooks/`
- Error investigation and fix → `docs/troubleshooting/`
- Command, parameter, or configuration lookup → `docs/reference/`

For general-purpose knowledge, use these categories:

- Concept, principle, or mental model → `knowledge/docs/concepts/`
- Step-by-step procedure or practical method → `knowledge/docs/howto/`
- Dated learning, investigation, or experience record → `knowledge/docs/notes/`
- Command, parameter, terminology, or external reference → `knowledge/docs/references/`

If multiple classifications apply, choose one primary location, explain the relationship, and link to related documents instead of duplicating content.

## 4. Document Template

Formal documents should use the following structure where applicable:

```markdown
# Title

## Purpose

## Scope

## Prerequisites

## Procedure

## Verification

## Troubleshooting

## Security Notes

## Related Files
```

Document requirements:

- State the conclusion or purpose near the beginning.
- State the execution directory for every command.
- List prerequisites and required permissions.
- Define the expected successful result.
- Define when the agent must stop instead of guessing or continuing.
- Keep examples executable and consistent with the current code.
- Never include real tokens, passwords, private keys, or machine-local secrets.
- Mark assumptions and unverified information explicitly.

## 5. Index Rules

`docs/README.md` is the entry point for project documentation. `knowledge/docs/README.md` is the entry point for general-purpose knowledge.

- Add every new formal document to the index in the same change.
- Update the index when a document is renamed or removed.
- Keep links relative to `docs/README.md`.
- Group links by domain.
- Do not duplicate document content in the index.
- Do not list temporary drafts unless they are intentionally part of the knowledge base.
- Check for broken links after reorganizing documents.
- Apply the same index rules independently to `knowledge/docs/README.md`.

## 6. Maintenance Workflow

### Adding knowledge

1. Confirm that the solution has been reproduced or verified.
2. Identify the document category and check for an existing primary document.
3. Create or update the smallest document that fully explains the topic.
4. Update `docs/README.md`.
5. Update `AGENTS.md`, a Skill, or examples if the new knowledge changes an instruction or workflow.
6. Check commands, links, repository scope, and sensitive information.
7. Commit the documentation change with a focused Conventional Commit message.

### Changing code or configuration

When a change affects command arguments, file paths, environment variables, defaults, branches, error handling, security behavior, or user-visible workflow, check the related documentation and Skills in the same change.

### Recording a troubleshooting case

Use these sections:

```markdown
## Symptom
## Impact
## Root Cause
## Investigation
## Solution
## Verification
## Prevention
```

Do not record only that an issue was fixed. Record the observable symptom, the cause, the decisive command or evidence, and how the fix was verified.

### Recording a decision

Use a numbered file under `docs/decisions/`, for example `0001-markdown-knowledge-base.md`, with these sections:

```markdown
# ADR-0001: Title

## Status
Accepted

## Context
## Decision
## Alternatives
## Trade-offs
## Consequences
## Review Conditions
```

When a decision is replaced, retain the old document and mark it `Superseded by ADR-XXXX` rather than deleting it.

## 7. Document Lifecycle

Use one of these statuses when lifecycle tracking is useful:

- `Draft`: not authoritative and must not be the only source used by a Skill.
- `Active`: currently valid and checked against the implementation.
- `Deprecated`: still readable but scheduled for removal or replacement.
- `Superseded`: replaced by another document and linked to its successor.
- `Archived`: historical reference and excluded from the main index.

Before removing or archiving a document, search for references from `AGENTS.md`, Skills, READMEs, scripts, and other documents.

## 8. Review Checklist

Before committing a knowledge-base change, verify:

```text
[ ] The document has the correct category.
[ ] There is no duplicate primary document.
[ ] The filename and title describe the topic.
[ ] Commands specify their working directory.
[ ] Prerequisites and success criteria are present.
[ ] Failure and stop conditions are clear.
[ ] Examples match current code behavior.
[ ] No token, password, or private configuration is included.
[ ] docs/README.md is updated.
[ ] AGENTS.md and related Skills are synchronized.
[ ] Internal links resolve.
[ ] Main utilssets and independent manifests repositories are distinguished.
```

## 9. Commit Conventions

Use focused Conventional Commit messages, for example:

```text
docs: add repository initialization guide
docs: update GitHub push troubleshooting
docs: archive obsolete setup instructions
fix(skill): align GitHub branch handling with documentation
chore(docs): update documentation index
```

Keep unrelated code cleanup out of documentation commits. When code and documentation must change together, explain their relationship in the commit scope and body.

## 10. Repository Scope

Documentation must explicitly identify repository scope when an operation involves more than one Git repository. In particular, `src/repo/.repo/manifests` is an independent manifests repository and must not be described as part of the main `utilssets` repository's commit or push operation.
