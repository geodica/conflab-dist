---
title: Using the Catalog
---

# Using the Catalog

The Catalog is Conflab's shared directory of [Lenses](/app/help/concepts/lenses), [Shapes](/app/help/concepts/shapes), and Data. This page is the task-oriented guide: browse, publish, fork, rate.

For the architectural view, see [The Catalog](/app/help/concepts/catalog).

## Two Surfaces

The Catalog is reachable through two paths:

| Path       | Who sees it     | What they see                                                                  |
| ---------- | --------------- | ------------------------------------------------------------------------------ |
| `/lsd`     | Anyone          | Public approved entries. Read-only. Body preview gated behind sign-in.         |
| `/app/lsd` | Signed-in users | Everything available to you: public, your library, your private, plus actions. |

Most of this guide describes the authenticated surface. The public surface is a subset of the same content without the actions.

## Tabs

The authenticated Catalog page has several tabs:

| Tab        | What it shows                                                                                       |
| ---------- | --------------------------------------------------------------------------------------------------- |
| Browse     | All entries you can see, sorted by recency or popularity. The default.                              |
| Categories | The controlled taxonomy. Drill into a category to see entries within it.                            |
| Themes     | Curated admin groupings. A theme is a related set of entries.                                       |
| Library    | Entries you have saved for personal use.                                                            |
| Plans      | Longer-form entries describing a plan or workflow. (Labelled "Plans" in UI.)                        |
| Favourites | Entries you have marked as especially useful. See [Favourites](/app/help/using-conflab/favourites). |
| Reviews    | Entries you have reviewed or that you have open reviews on.                                         |

The public surface (`/lsd`) has only Browse, Categories, and Themes. Library, Plans, Favourites, and Reviews require sign-in.

## Filtering and Search

Every tab supports filtering:

- **Search box** matches title, description, and tags.
- **Tag filters** narrow to entries carrying specific tags.
- **Sort order** switches between newest, most popular, and best-rated.
- **Category filter** narrows to a single category.

Filter state is reflected in the URL, so filtered views are linkable.

## Viewing an Entry

Click an entry tile to open its detail page at `/app/lsd/entries/<slug>`. The detail page shows:

- Title, description, and author.
- Tags, category, license.
- Body (prompt text + frontmatter).
- Source preview in a CodeMirror viewer.
- Social actions: like, rate, review, fork, report.
- Version history.
- Related entries.

On the public surface (`/lsd/entries/<slug>`), the body is truncated to a preview. A **Sign in to see the full source** notice marks the cut-off. Social actions are replaced with a sign-in call to action.

## Publishing an Entry

To publish a local Lens or Shape to the Catalog:

1. Write your `.lensmd` or `.shapemd` / `.shape.json` file locally, typically under `~/.conflab/prompts/` or `~/.conflab/shapes/`.
2. Run:

   ```bash
   conflab lens save ~/work/my-lens.lensmd        # publish a Lens
   conflab shape save ~/work/my-shape.shapemd     # publish a Shape
   ```

3. The CLI confirms the entry has been uploaded to the Catalog. The new entry is `pending` moderation by default; it is not publicly visible until approved.

You can also publish through the web UI by creating an entry directly in the Catalog.

## Forking

Forking creates a derivative entry linked back to the original. Provenance is preserved; the Catalog shows the fork graph on the original entry.

From the web UI: click **Fork** on the entry detail page.

From the CLI:

```bash
conflab lens fork <slug>
```

The fork appears in your drafts. Edit it, then publish with `conflab lens save`.

## Liking and Rating

Signed-in users can:

- **Like** -- a low-cost signal that an entry is useful. Counts are visible to everyone; individual likers are not surfaced.
- **Rate** -- a star rating (1-5) with an optional review. Ratings and reviews are visible to other users.

A user can like an entry once and rate it once. Both can be changed later.

## Reviewing

A review is a rating plus a short written comment. Reviews help other users decide whether an entry is worth using. From the entry detail page, click **Rate** and add a comment when prompted.

Your open reviews appear on the Reviews tab.

## Saving to Library and Favourites

- **Save to Library** -- a personal reading list. Library holds entries you want to find again without surfacing them publicly.
- **Favourite** -- a stronger signal that you return to this entry often. Favourites appear on their own tab. See [Favourites](/app/help/using-conflab/favourites).

Both are private; other users do not see your library or favourites.

## Reporting

If an entry is inappropriate, spammy, or broken, click **Report** on the detail page. Reports go to admin moderators. See [Moderation](/app/help/admin/moderation) for the admin side.

## Feeds

Every browsing surface exposes an Atom feed. A reader can subscribe to:

- Latest entries across the Catalog.
- Entries within a specific category.
- Entries in a specific theme.

The feed discovery links appear on the page itself (subscribe icon in the tab bar) and in the page head (`<link rel="alternate">`). See [Feeds](/app/help/using-conflab/feeds).

## Related

- [The Catalog](/app/help/concepts/catalog) -- architecture and concepts.
- [Lenses](/app/help/concepts/lenses) and [Shapes](/app/help/concepts/shapes) -- what is in the Catalog.
- [Favourites](/app/help/using-conflab/favourites).
- [Feeds](/app/help/using-conflab/feeds).
- [Moderation](/app/help/admin/moderation) -- how publication is gated.
