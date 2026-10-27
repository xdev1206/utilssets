# Knowledge Base Instructions

This directory is the local-first source for general-purpose knowledge and content published to the Feishu knowledge base. It is intentionally separate from `utilssets` project documentation and source code.

## Organization

- Store knowledge documents under `docs/` and use `docs/README.md` as their index.
- For projects other than `utilssets`, write and review searched or reusable knowledge here first, then decide whether it needs to be copied, shortened, or converted into a project's `docs/`, `AGENTS.md`, or Skill.
- For `utilssets` itself, write project-specific knowledge directly to its `docs/`, `AGENTS.md`, or Skill; this global knowledge base is not required as an intermediate copy.
- For other projects, treat this local knowledge base as the source of truth; project documents and Skills are derived views for project execution.
- When a derived project view changes the underlying reusable knowledge, update the global source first and then refresh the derived view.
- Write and review Feishu-bound content here first, then convert or publish the reviewed local document to the corresponding Feishu page.
- Treat Feishu as the publication and collaboration copy; do not use it as the authoring source or overwrite local content from Feishu automatically.
- Put substantial knowledge about a named external project under `docs/projects/<project>/`, grouped by domain (for example `architecture/`, `runtime/`, `deployment/`, or `models/`). Keep cross-project concepts, procedures, plans, notes, and references in the shared categories; create category directories only when needed.
- Every new, renamed, or removed document under `knowledge/docs/` must update `knowledge/docs/README.md` in the same change.
- Keep one primary document per topic. Follow the directory-depth, filename, tag, conflict-handling, and verification rules in [`docs/conventions/knowledge-base.md`](../docs/conventions/knowledge-base.md).
- Keep temporary drafts and private material outside tracked knowledge documents.

## Classification Decision

Classify new knowledge in this order:

1. Does it directly describe `utilssets` source code, scripts, configuration, or project workflows?
   - Yes: write it directly under the project `docs/` tree. A duplicate in this knowledge base is not required.
2. Is it specific to another named project?
   - Yes: store it under `docs/projects/<project>/` and link related cross-project knowledge instead of copying it.
3. Is it a rule that Codex must always follow in this repository?
   - Yes: store it in the applicable `AGENTS.md`.
4. Is it a repeatable workflow that Codex can execute?
   - Yes: store it in the applicable `.claude/skills/<name>/SKILL.md`.
5. Is it a concept, principle, or mental model reusable across projects?
   - Yes: store it under `knowledge/docs/concepts/`.
6. Is it a step-by-step procedure or practical method reusable across projects?
   - Yes: store it under `knowledge/docs/howto/`.
7. Is it an active integration or implementation plan?
   - Yes: store it under `knowledge/docs/plans/`.
8. Is it a dated learning, investigation, or experience record?
   - Yes: store it under `knowledge/docs/notes/`.
9. Is it a command, parameter, term, or external reference summary?
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
- After publishing to Feishu, record the page URL and publication revision in the local document.
- Mark replaced material as deprecated or superseded instead of leaving conflicting copies.
