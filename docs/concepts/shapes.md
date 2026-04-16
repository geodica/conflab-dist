---
title: Shapes
---

# Shapes

A **Shape** is an output contract for a [Lens](/app/help/concepts/lenses). It defines what the Lens's result must look like. If a Lens has a Shape, tooling can validate and transform the output mechanically. If a Lens has no Shape, the output is free-form text.

Shapes are optional. Use a Shape when the Lens's output will be consumed by machinery rather than read by a human.

## Two Forms

Shapes come in two forms, each matched to the output style:

| Form                  | File extension | Output style                  | When to use                                                                 |
| --------------------- | -------------- | ----------------------------- | --------------------------------------------------------------------------- |
| **Markdown Shape**    | `.shapemd`     | Structured Markdown           | Human-readable output with known section headings, tables, or bullet lists. |
| **JSON Schema Shape** | `.shape.json`  | JSON conforming to the schema | Machine-readable output for APIs, pipelines, or downstream Lenses.          |

A Lens references one Shape via its frontmatter:

```yaml
---
title: Code Review
shape: shapes/code-review.shapemd
---
```

Or for a JSON output:

```yaml
---
title: Entity Extractor
shape: shapes/entities.shape.json
---
```

## Markdown Shape (`.shapemd`)

A `.shapemd` file is a Markdown template. It declares the sections, headings, and shape of the output. Lens instructions point at the template; the Lens output fills in the template.

Example `.shapemd`:

```markdown
# Review Summary

## Strengths

- Bullet list

## Concerns

- Bullet list

## Recommended Changes

1. Ordered list of recommendations
```

The Lens instructions then say: "Produce a review following this Shape." The Shape is both a prompt aid and a target output format.

## JSON Schema Shape (`.shape.json`)

A `.shape.json` file is a standard JSON Schema document. It is the authoritative contract for the Lens's structured output. Tooling can validate every Run's output against the schema and reject non-conforming results.

Example `.shape.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["summary", "tags", "severity"],
  "properties": {
    "summary": { "type": "string" },
    "tags": { "type": "array", "items": { "type": "string" } },
    "severity": { "enum": ["low", "medium", "high"] }
  }
}
```

A Lens that references this Shape is expected to return valid JSON matching the schema.

## Where Shapes Live

Shapes live alongside Lenses:

- **Local Shapes** in `~/.conflab/shapes/`.
- **Catalog Shapes** in the Conflab Catalog, browsable on the Shapes tab of `/app/lsd` and publishable via `conflab shape save`.

A Lens can reference a local Shape by relative path, or a Catalog Shape by slug.

## When to Add a Shape

Use a Shape when:

- The Lens output feeds a downstream Lens, a workflow, or an API consumer.
- You want Runs to be comparable across executions (same structure, varying content).
- You want to validate results mechanically (JSON Schema form).
- You want the output consistent across re-runs for diffing.

Skip a Shape when:

- The Lens produces free-form prose for a human reader.
- The Lens output varies by design.
- The task is a one-off.

## Relationship to Lenses

Shapes are reusable across Lenses. A single Shape like `review-summary.shapemd` can be used by a Code Review Lens, a Design Review Lens, and a PR Review Lens. Keeping Shapes separate lets multiple Lenses agree on the same output contract.

This also lets the Catalog cross-reference Lenses by Shape: "show me every Lens that produces a `review-summary.shapemd` output" becomes a meaningful query.

## Relationship to the Catalog

Shapes are first-class Catalog entries alongside Lenses and Data. Every Shape in the Catalog has a slug, description, tags, and a license. Shapes can be forked like Lenses.

See [The Catalog](/app/help/concepts/catalog) for the three-layer architecture that stores Lenses, Shapes, and Data together.
