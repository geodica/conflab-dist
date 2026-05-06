---
title: Bundled LSD Content
---

# Bundled LSD Content

Conflab ships a curated starter pack of Lenses, Shapes, and Themes inside the CLI binary. After `conflab setup`, your `~/.conflab/db/` is populated with content you can run, edit, and extend immediately -- no Catalog round-trip required.

The bundle covers the four `starter-*` themes and the eleven Lenses + seven Shapes they reference. Other curated content remains Catalog-only and is fetched on demand via `conflab lens install <slug>`, `conflab shape install <slug>`, or `conflab theme install <slug>`.

For the bundled tools layer (`web-search`, `web-fetch`), see [Named Tools](named-tools.md).

## Bundled themes

| Slug                                     | Title                                 | What it covers                                                                                                                                            |
| ---------------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `starter-working-with-code`              | Starter: Working with Code            | Engineering workflows: first-pass PR review, executive-level code explanation, tests-to-write brainstorm.                                                 |
| `starter-working-with-documents`         | Starter: Working with Documents       | Everyday document work: meeting summaries, action-item extraction, tone-adjusting emails, grammar pass, plus the curated output Shapes Lenses can target. |
| `starter-working-with-products`          | Starter: Working with Products        | Product work: cluster-and-label messy brainstorm output, turn a free-form problem statement into a user story with acceptance criteria.                   |
| `starter-other-useful-lenses-and-shapes` | Starter: Other Useful Lenses + Shapes | Lenses that don't fit a single role: translate a passage into a target language, turn a pile of research notes into a clean outline.                      |

## Bundled lenses

Eleven Lenses, organised by theme. Each lands at `~/.conflab/db/lenses/<theme-slug>/<slug>.lensmd`.

| Slug                                   | Theme                                    | Description                                                                                                |
| -------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `starter-pr-first-pass-review`         | `starter-working-with-code`              | First-pass review of a pull request diff. Correctness, risk, clarity, tests, and concrete suggestions.     |
| `starter-code-explain-executive`       | `starter-working-with-code`              | Rewrite a block of code as a short explanation a non-technical executive can understand.                   |
| `starter-tests-to-write`               | `starter-working-with-code`              | Brainstorm the tests worth writing for a piece of code, organised by type and priority.                    |
| `starter-meeting-summary`              | `starter-working-with-documents`         | Summarise a meeting transcript into a structured card with attendees, decisions, action items, and quotes. |
| `starter-meeting-action-items`         | `starter-working-with-documents`         | Extract a checklist of action items from a meeting transcript, with assignees and due dates.               |
| `starter-email-tone-adjust`            | `starter-working-with-documents`         | Rewrite an email draft in a different tone while preserving intent and facts.                              |
| `starter-grammar-and-clarity-pass`     | `starter-working-with-documents`         | Proofread a passage for grammar, punctuation, and clarity without changing the author's voice.             |
| `starter-brainstorm-cluster-and-label` | `starter-working-with-products`          | Cluster a messy brainstorm list into labelled groups and output as JSON for structured rendering.          |
| `starter-user-story-from-problem`      | `starter-working-with-products`          | Turn a free-form problem statement into a proper user story plus acceptance criteria and open questions.   |
| `starter-text-translate`               | `starter-other-useful-lenses-and-shapes` | Translate a passage into a target language, preserving register and formatting.                            |
| `starter-research-notes-outline`       | `starter-other-useful-lenses-and-shapes` | Turn a pile of research notes into a clean outline with headings, sub-points, and open questions.          |

List bundled slugs:

```bash
conflab lens list
```

## Bundled shapes

Seven Shapes, all under `starter-working-with-documents` since they back the Document-pack Lenses. Each lands at `~/.conflab/db/shapes/starter-working-with-documents/<slug>.shapemd`.

| Slug                       | Description                                                                         |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `meeting-summary-shape`    | Structured meeting summary with decisions, outcomes, and action items.              |
| `coaching-session-summary` | Long-form prose summary of a coaching session.                                      |
| `profile-summary`          | Long-form prose summary of a professional profile.                                  |
| `news-article-summary`     | Summarise a news article.                                                           |
| `reading-list-intro`       | Synthesis introduction for a curated reading list blog post.                        |
| `monthly-achievements`     | One-line summaries of monthly achievements from raw notes.                          |
| `structured-critique`      | Structured intellectual critique with assumptions, counterpoints, and alternatives. |

A bundled Lens enlists a bundled Shape by slug (eg `shape: meeting-summary-shape` in a Lens's frontmatter); the daemon resolves the slug against the live shapes index regardless of which theme directory the file lives under.

Note: the `shape:` field has dual semantics. A kebab-case slug (`meeting-summary-shape`) resolves to a real `.shapemd` / `.shape.json` file and drives `produce_output` enforcement at the LLM seam. A snake_case slug (`meeting_summary`, `action_items`, `json_schema_generic`) is a renderer hint dispatched by the macOS Launcher to a dedicated SwiftUI renderer; it does not resolve against the shapes index. Several starter lenses use renderer-hint slugs to drive Launcher card rendering. See [Templates -- Shape Field](templates.md#shape-field) for the full contract.

## Bootstrap flow

You do not have to install bundled content manually. The seed runs as part of first-run setup so a fresh install is ready to use.

| Path                                                 | What happens                                                                                                                                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| macOS .pkg → app wizard → `conflab setup --bundle`   | Runs `daemon init` + `db init`. `db init` creates `~/.conflab/db/{lenses,shapes,tools}/` and seeds every bundled tool, lens, and shape.          |
| `conflab setup --interactive` (terminal users)       | Same as above. Wizard and terminal entry share `apply_bundle`.                                                                                   |
| `conflab db init` (advanced; called by setup itself) | Creates the LSD tree if missing; seeds bundled tools, lenses, shapes idempotently. Re-running is safe -- byte-matching files report `unchanged`. |

The seed phases dispatch in fixed order: tools first, then lenses, then shapes. The order matters for `conflab pristine --all` choreography (see [Pristine](pristine.md)): tools land first because they are slug-flat and quick; lenses + shapes follow because they are theme-grouped and may take longer in larger future bundles.

After a daemon update ships a new bundled lens, shape, or theme manifest, run:

```bash
conflab lens sync             # idempotent; refuses to overwrite hand-edits
conflab shape sync --force    # also clobbers hand-edited files with bundled bytes
```

`conflab lens sync` and `conflab shape sync` print per-pair outcomes (`installed`, `updated`, `unchanged`, `skipped`) annotated with the theme slug, and a roll-up summary line. Without `--force`, a hand-edited file is reported as `skipped` and the command exits non-zero so CI / scripts can detect divergence and prompt for `--force` interactively. With `--force`, the bundled bytes overwrite verbatim.

For surgical control over a single Catalog slug, the original install commands are still available and unaffected by this layer:

```bash
conflab lens install starter-meeting-summary           # Catalog fetch; idempotent
conflab shape install meeting-summary-shape            # Catalog fetch; idempotent
conflab theme install starter-working-with-documents   # Catalog fetch + per-entry install
```

The bundled-fixture path writes to `~/.conflab/db/lenses/<theme-slug>/<slug>.lensmd` (and the symmetric shape path); the filesystem watcher picks the file up automatically -- no daemon restart, no re-index.

## Editing bundled content

The on-disk LSD tree is yours to edit. The Highlander rule is: **the file beats the bundle**. If you've edited `starter-meeting-summary.lensmd`, your bytes win until you explicitly choose to take the bundle bytes back. The daemon's filesystem watcher indexes your edits; the file you edited is what runs.

When you do want the bundle bytes back, the recovery path is `--force`:

```bash
conflab lens sync --force      # clobber every hand-edited bundled lens
conflab lens install starter-meeting-summary --force   # surgical: one slug
```

`conflab lens install <slug>` (and `conflab shape install <slug>`) without `--force` refuses to overwrite a divergent file and exits non-zero. This is by design: the install command is a non-destructive primitive; the recovery primitive is `sync --force` (whole-bundle) or `install --force` (one slug).

For the nuclear "reset every customisation in this layer" path, see [Pristine](pristine.md): `conflab pristine --lenses` snapshots the live tree, force-syncs the bundle, and leaves your snapshot at `~/.conflab/.backups/<timestamp>/lenses/`.

## Source-of-truth split

The same byte sequence appears in two places in the repo:

- `priv/data/lsd/<category>/entries/<slug>.lensmd` -- the **Catalog publication source**. This is what gets shipped through the conflabc Catalog so anyone (not just Conflab users) can `lens install <slug>`.
- `native/daemon/src/template/fixtures/lenses/<slug>.lensmd` -- the **bundle source-of-truth**. This is what `include_str!` pulls into the CLI binary at compile time.

The two are byte-for-byte identical at any point in the release cycle. The duplication is intentional: the Catalog publication path and the bundle path are different machines with different audiences, and binding the bundle bytes at compile time keeps them stable across daemon restarts and Catalog churn. A future build-time drift check between the two trees is a follow-up; for v1, the duplication is acceptable because every bundled byte is pinned at compile time and any post-bundle Catalog edit goes through the publication pipeline, not the fixtures.

## See also

- [Named Tools](named-tools.md) -- the bundled tools layer (web-search, web-fetch).
- [First Run](first-run.md) -- the wizard and `conflab setup --bundle` flow.
- [Templates](templates.md) -- the `.lensmd` and `.shapemd` file formats.
