---
title: Feeds
---

# Feeds

Conflab publishes Atom feeds for every Catalog browsing surface. If you use an RSS or Atom reader, you can subscribe to keep up with new Lenses, new themes, and new entries in categories you care about.

## Available Feeds

| Feed           | Path                       | Contents                                           |
| -------------- | -------------------------- | -------------------------------------------------- |
| Latest entries | `/feeds/latest.atom`       | Newest approved public entries across the Catalog. |
| Category       | `/feeds/categories/<slug>` | Newest entries in a single category.               |
| Theme          | `/feeds/themes/<slug>`     | Newest entries in a curated theme.                 |
| Author         | `/feeds/authors/<handle>`  | Newest entries by a specific author.               |

All feeds are public; no sign-in required.

## Subscribing

### Copy the Feed URL

From a Catalog browsing page, look for the subscribe icon (RSS glyph) near the tab bar. Click it to open `/feeds` with the full list. Or copy the feed URL directly from any browsing page.

### In a Feed Reader

Paste the feed URL into your reader of choice:

- Feedbin, Feedly, NewsBlur, and most other web readers accept Atom URLs directly.
- Command-line readers such as Newsboat work the same way.
- Browsers with built-in subscription (Safari, some Firefox extensions) pick up the `<link rel="alternate">` tag automatically.

### Feed Discovery

Every Catalog page includes `<link rel="alternate">` tags in the page head pointing at relevant feeds. A reader that understands feed discovery finds them without you needing to copy URLs manually.

Example: on `/app/lsd?category=code-review`, the page head includes a link to `/feeds/categories/code-review`.

## What You Get

Each feed entry includes:

- Title, author, publication date.
- Short description and tags.
- A link back to the full entry on the Catalog.
- Category and theme information where applicable.

Feeds do not include the full body of a Lens or Shape. That stays on the Catalog so readers can see the always-current version.

## Caching

Feeds are cached to keep the server responsive:

- Responses carry ETag and Last-Modified headers.
- Conditional GETs return 304 without regenerating the feed if nothing changed.
- Cache max-age is short (a few minutes) so new entries surface quickly.

Most feed readers respect these headers and will not hammer the server.

## Related

- [Using the Catalog](/app/help/using-conflab/catalog) -- where the feeds originate.
- [The Catalog](/app/help/concepts/catalog) -- architectural view.
