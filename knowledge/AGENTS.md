# Knowledge Base Instructions

This directory is a general-purpose knowledge base inside the repository. Its content is for knowledge management and is intentionally separate from `utilssets` project documentation and source code.

## Organization

- Store knowledge documents under `docs/` and use `docs/README.md` as their index.
- Use `docs/concepts/` for explanations, `docs/howto/` for repeatable procedures, `docs/notes/` for dated learning notes, and `docs/references/` for concise reference material.
- Every new, renamed, or removed document under `knowledge/docs/` must update `knowledge/docs/README.md` in the same change.
- Use lowercase, hyphen-separated filenames and keep one primary document per topic.
- Keep temporary drafts and private material outside tracked knowledge documents.

## Classification Decision

Classify new knowledge in this order:

1. Does it directly describe `utilssets` source code, scripts, configuration, or project workflows?
   - Yes: store it under the project `docs/` tree, not under `knowledge/`.
2. Is it a rule that Codex must always follow in this repository?
   - Yes: store it in the applicable `AGENTS.md`.
3. Is it a repeatable workflow that Codex can execute?
   - Yes: store it in the applicable `.claude/skills/<name>/SKILL.md`.
4. Is it a general concept, principle, or mental model?
   - Yes: store it under `knowledge/docs/concepts/`.
5. Is it a general step-by-step procedure or practical method?
   - Yes: store it under `knowledge/docs/howto/`.
6. Is it a dated learning, investigation, or experience record?
   - Yes: store it under `knowledge/docs/notes/`.
7. Is it a command, parameter, term, or external reference summary?
   - Yes: store it under `knowledge/docs/references/`.

If more than one category applies, choose one primary location, explain the relationship in the document, and link to related material instead of duplicating it.

## Writing

- Put the conclusion near the beginning.
- Record verified knowledge and label assumptions or open questions.
- Include context, examples, limitations, and verification information where useful.
- Link related documents instead of copying the same content.
- Never store passwords, tokens, private keys, or other secrets.

## Maintenance

- Check for an existing document before creating a new one.
- Review links, examples, and outdated claims before committing.
- Mark replaced material as deprecated or superseded instead of leaving conflicting copies.
