---
title: The Catalog
---

# The Catalog

The Catalog is Conflab's shared directory of [Lenses](/app/help/concepts/lenses), [Shapes](/app/help/concepts/shapes), and Data. The acronym **LSD** stands for **Lenses, Shapes, Data**. It is the primary surface where users browse, publish, fork, and rate Conflab content.

## Three-Layer Architecture

The Catalog has three storage layers:

1. **Git-backed files** in `~/.conflab/db/` on the local machine. The daemon reads and writes files here, keeping the authorable artefacts in a git repository.
2. **SQLite index** local to the daemon. Used for fast lookups, full-text search, and offline browsing.
3. **Ash catalog DB** in Conflabc (PostgreSQL). Used for publishing, moderation, social interactions, and cross-user browsing.

The daemon writes to files first, then syncs the SQLite index. Publishing pushes to the Ash catalog DB over GraphQL. The file tree is the source of truth for local content; the DB is the source of truth for published content.

## Two Surfaces

The Catalog is reachable through two web surfaces:

| Surface        | Path       | Who sees it     | What they see                                                       |
| -------------- | ---------- | --------------- | ------------------------------------------------------------------- |
| Public Catalog | `/lsd`     | Anyone          | Public approved entries. Read-only. Gated body preview. Feed links. |
| Authenticated  | `/app/lsd` | Signed-in users | Everything available to the user: public + their library + private. |

The public surface exists to give search engines and casual visitors something discoverable without a sign-in wall. Anyone can browse, read titles and descriptions, and see a short body preview. Full content, publishing, forking, liking, and rating require a Conflab account.

## Entry Kinds

Entries in the Catalog belong to one of three kinds:

- **Lens.** A prompt template with a declared Transform Pattern. `.lensmd` files.
- **Shape.** An output contract. `.shapemd` or `.shape.json` files.
- **Data.** A reusable dataset, example set, or context bundle. Formats vary.

Lenses are the most common entry kind today. Shapes are used whenever a Lens declares a structured output. Data is less common and typically supports specific Lenses.

## Visibility and Moderation

Every Catalog entry has a visibility and a moderation status.

**Visibility** controls who can see the entry:

| Visibility | Who sees it                                          |
| ---------- | ---------------------------------------------------- |
| `public`   | Everyone, including anonymous visitors on `/lsd`.    |
| `private`  | Only the author and collaborators the author grants. |

**Moderation status** controls whether a public entry is surfaced publicly:

| Status     | What it means                                           |
| ---------- | ------------------------------------------------------- |
| `pending`  | Published but not yet reviewed. Not visible publicly.   |
| `approved` | Reviewed and published publicly.                        |
| `rejected` | Reviewed and not surfaced. Still visible to the author. |

The public browsing surface (`/lsd`) only shows entries that are both `public` and `approved`. See [Moderation](/app/help/admin/moderation) for the admin-side workflow.

## Social Primitives

Signed-in users can interact with entries in several ways:

- **Fork.** Create a derivative entry with a parent link to the original. Forks preserve provenance.
- **Like.** A low-cost signal that an entry is useful. Likes are counted but do not surface individual identities.
- **Rate.** A star rating with an optional review. Reviews are visible to other users.
- **Report.** Flag an entry for moderator attention.
- **Save to Library.** A personal reading list of entries to keep around.
- **Favourite.** A stronger signal that an entry is one the user returns to often. See [Favourites](/app/help/using-conflab/favourites).

All of these are task-oriented actions. The Catalog page explains how to use them; see [Using the Catalog](/app/help/using-conflab/catalog).

## Categories and Themes

Entries are organised by:

- **Categories.** A controlled taxonomy. Each entry belongs to at most one category. Example categories: `code-review`, `writing`, `research`.
- **Themes.** Looser groupings curated by admins. A theme is a collection of entries united by a common subject.
- **Tags.** Free-form text labels. An entry can have many tags.

Browsing surfaces reflect this hierarchy: the `/lsd` page has Browse / Categories / Themes tabs, and each category has its own landing page with a dedicated Atom feed.

## Feeds

Every Catalog browsing surface exposes an Atom feed. Use case: a reader subscribes to "latest Lenses" or "new entries in `code-review`" and gets updates through their feed reader. See [Feeds](/app/help/using-conflab/feeds).

## Content Sources

Entries reach the Catalog through three paths:

1. **User authoring.** A signed-in user writes a Lens or Shape locally, then publishes it.
2. **Forking.** A user forks an existing entry and edits their copy.
3. **Bootstrap curation.** Admins use the content pipeline to crawl and curate public sources; curated content lands in `priv/data/lsd/` and is loaded into the Catalog DB at boot. See [Content Pipeline](/app/help/admin/content-pipeline).

Bootstrap content is how the Catalog starts out populated. User authoring is how it grows over time.

## Related Concepts

- [Lenses](/app/help/concepts/lenses) are the atomic unit stored in the Catalog.
- [Shapes](/app/help/concepts/shapes) are the output contracts Lenses use.
- [Using the Catalog](/app/help/using-conflab/catalog) is the task-oriented guide.
- [Moderation](/app/help/admin/moderation) is the admin-side view.
