---
title: Prompt Templates
---

# Prompt Templates

Conflab Prompt templates (`.lensmd` files) are Markdown-based prompt templates with optional YAML frontmatter for metadata and `{{variable}}` interpolation. Simple templates are plain Markdown; structured templates add typed variable declarations via frontmatter. The legacy `.cp.md` extension is also supported.

## File Structure

A `.lensmd` file has two parts:

```
---
YAML frontmatter (optional)
---

Markdown body with {{variable}} interpolation
```

- **Encoding**: UTF-8, LF line endings
- **Frontmatter**: YAML between opening and closing `---` delimiters. The opening `---` must be the first line of the file.
- **Body**: Everything after the closing `---`. If no frontmatter is present, the entire file is the body.

If the YAML between delimiters fails to parse, the entire file is treated as body text. Malformed frontmatter never causes errors.

## Frontmatter Fields

All fields are optional. Unknown keys are ignored.

| Field          | Type             | Default | Description                                      |
| -------------- | ---------------- | ------- | ------------------------------------------------ |
| `title`        | string           | --      | Human-readable template name                     |
| `version`      | integer          | `1`     | Template format version                          |
| `description`  | string           | --      | What this template does                          |
| `author`       | string           | --      | Template author                                  |
| `tags`         | array of strings | `[]`    | Categorisation tags                              |
| `runtime`      | string (enum)    | `auto`  | Execution environment: `local`, `server`, `auto` |
| `capabilities` | array of strings | `[]`    | Required runtime capabilities (see below)        |
| `variables`    | map              | `{}`    | Variable declarations (see Variable Types)       |

### Title Derivation

If `title` is absent, it is derived from the filename:

1. Strip the `.lensmd` extension
2. Replace hyphens (`-`) and underscores (`_`) with spaces
3. Apply title case (capitalise first letter of each word)

Example: `code-review.lensmd` becomes "Code Review".

### Runtime

| Value    | Meaning                    |
| -------- | -------------------------- |
| `local`  | Execute on conflabd only   |
| `server` | Execute on conflabc only   |
| `auto`   | Executor decides (default) |

### Capabilities

Capabilities declare what runtime features a template requires.

| Capability    | Status      | Description                          |
| ------------- | ----------- | ------------------------------------ |
| `clipboard`   | Implemented | Read/write system clipboard          |
| `mcp`         | Stub        | MCP tool invocation via conflabd     |
| `llm`         | Stub        | LLM API calls                        |
| `applescript` | Stub        | macOS GUI automation via AppleScript |

Templates with no `capabilities` declared produce text output only.

## Variable Types

Variables are declared in the `variables` frontmatter map. Each key is a variable name mapping to a definition object.

### Naming Rules

Variable names must match: `[a-z][a-z0-9_]*`

- Start with a lowercase ASCII letter
- Followed by lowercase letters, digits, or underscores
- No uppercase, no hyphens, no dots

Valid: `code`, `language`, `focus_area`, `max_tokens`, `v2_prompt`
Invalid: `Code`, `my-var`, `2fast`, `_private`, `a.b`

### Types

| Type      | Description            | Value Type |
| --------- | ---------------------- | ---------- |
| `string`  | Single-line text input | string     |
| `text`    | Multi-line text area   | string     |
| `choice`  | Select from a list     | string     |
| `boolean` | True or false          | boolean    |
| `number`  | Integer or float       | number     |

If `type` is omitted, the default is `string`.

### Definition Fields

| Field         | Type             | Applies To    | Default  | Description                       |
| ------------- | ---------------- | ------------- | -------- | --------------------------------- |
| `type`        | string (enum)    | all           | `string` | Variable type                     |
| `description` | string           | all           | --       | Human-readable label              |
| `default`     | (varies)         | all           | --       | Pre-fill value, must match type   |
| `required`    | boolean          | all           | `false`  | Reject submission if empty        |
| `choices`     | array of strings | `choice` only | --       | List of valid options             |
| `multiline`   | boolean          | `text` only   | `true`   | Render as textarea (hint)         |
| `min`         | number           | `number` only | --       | Minimum allowed value (inclusive) |
| `max`         | number           | `number` only | --       | Maximum allowed value (inclusive) |

### Validation

- **`choice`**: value must be one of the `choices` entries
- **`number`**: value must be within `min`/`max` range if specified
- **`required`**: variable must have a non-empty value; empty string counts as unset

## Interpolation

### Syntax

Variables are interpolated using double-brace syntax:

```
{{variable_name}}
```

### Whitespace Tolerance

Whitespace inside braces is trimmed. These are all equivalent:

```
{{name}}  {{ name }}  {{  name  }}
```

### Escape Sequence

To output a literal `{{`, prefix with a backslash:

```
\{{this is not a variable}}
```

Output: `{{this is not a variable}}`

### Unresolved Variables

Variables with no value provided are preserved as-is in the output:

```
Input:  Hello {{name}}, welcome to {{place}}.
Values: { "name": "Alice" }
Output: Hello Alice, welcome to {{place}}.
```

This enables partial interpolation and progressive template filling.

### Body-Only Variable Discovery

If the body contains `{{variable_name}}` patterns not declared in frontmatter, they are treated as implicit variables with type `string`, `required: false`, and no default. This allows templates with no frontmatter to still present a variable form.

Variables are discovered in order of first appearance, deduplicated.

## Directory Convention

### Root Directory

Templates live in `~/.conflab/prompts/`. The directory structure maps to menu hierarchy:

```
~/.conflab/prompts/
  coding/
    review.lensmd          -> Coding > Review
    refactor.lensmd        -> Coding > Refactor
  writing/
    blog-post.lensmd       -> Writing > Blog Post
    email/
      follow-up.lensmd     -> Writing > Email > Follow Up
  quick-question.lensmd    -> Quick Question
```

### Sort Order

1. Directories first, then files
2. Case-insensitive alphabetical within each group

### Hidden Directories

Directories starting with `.` are skipped entirely. Only `.lensmd` files are included; other file types are ignored. Empty directories (containing no `.lensmd` files) are excluded.

### Template ID

Each template has an ID derived from its path relative to the prompts root, without the `.lensmd` extension:

| File Path                                 | Template ID     |
| ----------------------------------------- | --------------- |
| `~/.conflab/prompts/quick.lensmd`         | `quick`         |
| `~/.conflab/prompts/coding/review.lensmd` | `coding/review` |

The template ID is used in API calls to reference a specific template.

## Examples

### Minimal (No Frontmatter)

```markdown
Explain {{concept}} in simple terms with examples.
```

This template has one implicit variable (`concept`, type `string`). The title is derived from the filename.

### Standard (Title + Variables)

```yaml
---
title: Git Commit Message
variables:
  summary:
    type: string
    description: "Brief change description"
    required: true
  breaking:
    type: boolean
    description: "Is this a breaking change?"
    default: false
---
Write a conventional commit message for the following change:

Summary: { { summary } }
Breaking change: { { breaking } }
```

### Full (All Types + Capabilities)

```yaml
---
title: Code Review
description: "Review code for quality, bugs, and improvements"
author: matts
tags: [coding, review]
runtime: auto
capabilities:
  - clipboard
variables:
  language:
    type: choice
    description: "Programming language"
    choices: [Elixir, Rust, Swift, Python, TypeScript]
    default: "Elixir"
  focus:
    type: choice
    description: "Review focus area"
    choices: [bugs, performance, readability, security, all]
    default: "all"
  code:
    type: text
    description: "Code to review"
    required: true
  verbose:
    type: boolean
    description: "Include detailed explanations"
    default: false
  max_issues:
    type: number
    description: "Maximum issues to report"
    default: 10
    min: 1
    max: 50
---
Review the following {{language}} code with a focus on {{focus}}.

{{code}}

Report up to {{max_issues}} issues.
```

## See Also

- [Programmable Prompts](/app/help/daemon/programmable-prompts) -- Lua-powered templates
- [Daemon Overview](/app/help/daemon/overview) -- Template management API endpoints
