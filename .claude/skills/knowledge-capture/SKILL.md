---
name: knowledge-capture
description: Search, verify, organize, and add general-purpose knowledge to this repository's knowledge base when the user asks to research or record a topic.
---

# Knowledge capture

Use this skill when the user asks to search for information and organize the result into the general-purpose knowledge base under `knowledge/`.

Do not use it for knowledge that directly describes `utilssets` source code, scripts, configuration, or project workflows. Put that material in the project `docs/` tree instead. Do not use it for a search-only request when the user did not ask to save the result.

## Workflow

1. Clarify the topic, intended audience, and desired depth when they materially affect the result. Otherwise make a narrow, explicit assumption.
2. Search authoritative and current sources. Prefer primary documentation, specifications, original papers, or official project sources. Do not treat a search-result snippet as evidence.
3. Record the source title, URL, publisher or author, publication/update date when available, and access date. Separate sourced facts, derived conclusions, and unresolved questions.
4. Search `knowledge/docs/` for an existing document on the topic before creating one. Extend the existing primary document when the new material belongs to the same topic; otherwise create a lowercase, hyphen-separated filename.
5. Route the result using this order:
   - General concept, principle, or mental model → `knowledge/docs/concepts/`
   - General step-by-step procedure or practical method → `knowledge/docs/howto/`
   - Dated learning, investigation, or experience record → `knowledge/docs/notes/`
   - Command, parameter, terminology, or external reference summary → `knowledge/docs/references/`
6. Write the conclusion near the beginning. Include context, key findings, evidence, limitations, and related topics. Use `knowledge/templates/note.md` for learning or investigation notes when appropriate.
7. Update `knowledge/docs/README.md` in the same change for every new, renamed, or removed document. Keep one primary document per topic and link related material instead of duplicating it.
8. Check source links, internal links, dates, claims, and sensitive information. Never write passwords, tokens, private keys, or private data into the knowledge base.
9. Run `git diff --check` from the repository root and report the changed files, sources, classification, and remaining uncertainty.

## Source and writing rules

- Prefer multiple independent sources for important or disputed claims.
- Preserve the distinction between a source's claim and the knowledge-base author's interpretation.
- Mark stale, version-specific, or uncertain information explicitly.
- Include an access date for web sources when the content may change.
- Do not silently convert an opinion, example, or forecast into a fact.
- Keep the document focused; split unrelated topics into separate documents.

## Side effects

This skill may create or update files under `knowledge/` and its index. It must not commit, push, delete unrelated files, or modify project documentation unless the user explicitly requests that additional action.

## Completion criteria

The task is complete only when:

- The researched content is stored in the correct `knowledge/docs/` category.
- Existing knowledge was checked for duplication.
- Sources and uncertainty are recorded.
- `knowledge/docs/README.md` is synchronized.
- No sensitive information was added.
- `git diff --check` passes.
