---
title: Lenses
---

# Lenses

A **Lens** is the atomic unit of inference in Conflab. Every Lens follows the Transform Pattern:

> **Output = T(Context, Shape, Instructions)**

Where:

- **Context** is the input data the Lens acts on.
- **Shape** is the output contract the result must conform to.
- **Instructions** are the prompt body that tells the model what to do.
- **T** is the transformation performed by a [Model](/app/help/concepts/models).

A Lens is a reusable, shareable, composable unit. It is the smallest thing you can run, save, publish, fork, and like in Conflab.

## File Format

Lenses are stored as `.lensmd` files. They are Markdown with YAML frontmatter. The frontmatter declares metadata, required variables, and the Shape. The body is the prompt, with `{{variable}}` interpolation.

Minimal Lens:

```markdown
Summarise the following text in three sentences:

{{text}}
```

Structured Lens:

```yaml
---
title: Git Commit Message
tags: [coding, git]
shape: shapes/commit-message.shape.json
variables:
  summary:
    type: string
    description: "Brief change description"
    required: true
  breaking:
    type: boolean
    default: false
---
Write a conventional commit message for the following change.

Summary: {{summary}}
Breaking change: {{breaking}}
```

The full format reference lives in [Prompt Templates](/app/help/daemon/templates). The `.lensmd` format also supports Lua code blocks for computed variables; see [Programmable Prompts](/app/help/daemon/programmable-prompts).

## Where Lenses Live

There are two kinds of Lens locations:

- **Local Lenses** in `~/.conflab/prompts/`. Used by the daemon as prompt templates. Available to the owner. Not published to the Catalog.
- **Catalog Lenses** in the Conflab Catalog. Published, moderated, and browsable by others. Authored by users and crawled from public sources. See [The Catalog](/app/help/concepts/catalog).

A local Lens can be published to the Catalog via `conflab lens save`. A Catalog Lens can be forked and downloaded to the local tree for customisation.

## Running a Lens

A Lens is useless until it runs. Running a Lens produces a Run record and an Output.

Command-line execution:

```bash
conflab run my-lens --context "some input text"
conflab run coding/code-review --var code="$(cat file.py)" --var language=Python
```

Programmatic execution via MCP:

```
run_lens(path: "coding/code-review", variables: {code: "...", language: "Python"})
```

From a flab, executing `conflab run` with the flab context flag attributes the run to the current flab. This lets a Run participate in the conversation.

## Shapes

A Lens can declare a Shape, which is the output contract. If the Lens produces JSON, the Shape is a JSON Schema (`.shape.json`). If the Lens produces structured Markdown, the Shape is a Markdown template (`.shapemd`). Shapes let tooling validate and transform Lens outputs mechanically. See [Shapes](/app/help/concepts/shapes).

Lenses without a Shape produce free-form text output. Most Lenses do not need a Shape; add one when the output will be consumed by something other than a human.

## Versioning and Forks

Catalog Lenses are versioned. A Lens can be forked, which produces a child entry linked to its parent. Forking captures provenance: you can see the Lens a fork descended from and the changes made.

Versioning is automatic for most edits. Forking is explicit via the Catalog UI or `conflab lens fork <slug>`.

## Common Uses

Lenses work well for any task that fits the Transform Pattern:

- Summarisation (Context = long text, Output = short text).
- Extraction (Context = text, Shape = JSON, Output = structured data).
- Code review (Context = code, Shape = review Markdown, Output = review text).
- Classification (Context = item, Shape = choice from a list, Output = category).
- Refactoring (Context = code, Output = refactored code).

## Relationship to Flabs

A Lens execution can happen inside a flab (attributed to the flab, results visible to participants) or outside (attributed to the caller). Agents in a flab can run Lenses on behalf of participants. This is how Lenses become collaborative artefacts rather than private utilities.
