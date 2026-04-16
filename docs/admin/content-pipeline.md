---
title: Content Pipeline (Crawl + Curation)
---

# Content Pipeline (Crawl + Curation)

The content pipeline is how curated Lens and Shape content gets into the Catalog at scale. It has two admin-facing stages:

1. **Crawl** (`/app/admin/crawl`) -- fetch raw prompt source material from external sites.
2. **Curation** (`/app/admin/curation`) -- review crawled material, promote it to draft Lenses, and publish.

Output lands in `priv/data/lsd/` as a staging tree. On application boot, `Conflab.Catalog.Bootstrap.run/1` loads the staging tree into the Catalog DB. This produces the bulk of the launch-time Catalog and seeds ongoing content production.

## Runtime Gates

Two seeded settings control the pipeline:

| Key                     | Default | Purpose                                                                |
| ----------------------- | ------- | ---------------------------------------------------------------------- |
| `catalog_crawl_enabled` | `off`   | Whether scheduled crawler jobs run.                                    |
| `lensify_enabled`       | `off`   | Whether the Lensify admin tool (promote crawled -> Lens) is available. |

Both default off. Flip them on from [Runtime Settings](/app/help/admin/settings) when the pipeline is actively in use.

## Crawl

The Crawl page lists **crawl sources** -- URLs or patterns for external sites that host prompts worth pulling in. Examples: public prompt libraries, curated GitHub repositories, blog posts from credible authors.

For each source you can:

- **Trigger** a run (ad-hoc fetch).
- **Enable / disable** scheduled runs.
- **View runs** at `/app/admin/crawl/:slug` to see the history and what each run produced.

Crawl output goes into `priv/data/crawl/`. Each source maintains its own subtree. Crawl preserves attribution metadata (author, original URL, licence if stated).

Crawling is single-operator and local-only: it runs on the admin's machine, not in production, and produces files that are then committed and reviewed. It is not a background service that fills the Catalog without human approval.

## Curation

The Curation page (`/app/admin/curation`) is where crawled material becomes draft Lenses.

Workflow:

1. Pick a crawled item.
2. Review the raw content.
3. Promote it via **Lensify** -- the admin tool that converts a crawled prompt into a `.lensmd` draft with inferred frontmatter (title, tags, category, suggested Shape).
4. Review the `.lensmd` in the editor.
5. Publish when ready. The draft lands in `priv/data/lsd/<category>/entries/<slug>.lensmd` with `visibility: public` and `moderation_status: pending`.
6. [Moderation](/app/help/admin/moderation) approves the entry so it appears on the public Catalog.

Lensify is single-operator, local-only, and has no rate limits or session counters. It runs against `priv/data/crawl` and writes to `priv/data/lsd`.

## Bootstrap at Boot

On application startup, `Conflab.Catalog.Bootstrap.run/1` walks `priv/data/lsd/` and hydrates the Catalog DB. The walk happens in two passes:

1. **Prompts.** Files under `<category>/prompts/<source_slug>/<entry_id>.json` become entries with `kind: prompt`. A prompt index is built keyed by `"<source_slug>/<entry_id>"`.
2. **Lenses.** Files under `<category>/entries/<slug>.lensmd` become entries with `kind: lens`. A Lens whose frontmatter carries `forked_from_prompt_id: "<source>/<id>"` gets its `forked_from_id` resolved via the prompt index from Pass 1.

Idempotency is governed by a SHA-256 hash of the raw file bytes, stored on `Entry.content_hash`. Unchanged files are skipped; changed files trigger an update.

The `priv/data/lsd/` tree is a **bootstrap staging area**, not a runtime destination. User-authored content at runtime flows through the ST0067 DB path, not through `priv/data/lsd/`.

## Directory Layout

```
priv/data/
  crawl/
    <source_slug>/
      <crawled_item>.json
      ...
  lsd/
    <category>/
      prompts/
        <source_slug>/
          <entry_id>.json     # pass 1: prompts
      entries/
        <slug>.lensmd          # pass 2: lenses (may fork from prompts)
```

Each `<category>` maps to a slug in the taxonomy returned by `Conflab.Catalog.Categories.list/0`. Categories are set-membership only; an entry belongs to at most one category.

## Relationship to User Content

| Source           | Landing path                         | Journey to Catalog                                             |
| ---------------- | ------------------------------------ | -------------------------------------------------------------- |
| User authoring   | `~/.conflab/prompts/*.lensmd`        | `conflab lens save` -> Catalog DB direct.                      |
| Crawled material | `priv/data/crawl/**`                 | Curation + Lensify -> `priv/data/lsd/**` -> Bootstrap at boot. |
| Forks            | Web UI or `conflab lens fork <slug>` | Catalog DB direct, with provenance link.                       |

The pipeline covers the second row. User-authoring is the first row and does not touch `priv/data/lsd/`.

## Publication Gate

This doc describes internal admin workflow. Whether it appears publicly at `/app/help/admin/content-pipeline` or stays admin-only is a separate call. Move the manifest entry to an admin-only gate if the exposed detail (crawl sources, Lensify internals) is not appropriate for every signed-in user.

## Related

- [Moderation](/app/help/admin/moderation) -- what happens to published entries after the pipeline promotes them.
- [The Catalog](/app/help/concepts/catalog) -- architectural view.
- [Runtime Settings](/app/help/admin/settings) -- the `catalog_crawl_enabled` and `lensify_enabled` toggles.
