---
title: Named Tools
---

# Named Tools

A **Named Tool** is a daemon-side primitive that lets a Lens enlist server-side capabilities at the LLM provider seam. Where a Lens packages instructions and a Shape packages output structure, a Tool packages a single API capability the model can use mid-run -- web search, web fetch, and (in time) other server-tools and MCP-bridged tools.

You enlist tools by name, in a Lens's frontmatter, using the slug. The daemon resolves the slug against a registry of tool files at `~/.conflab/db/tools/<slug>.tool.json` and threads the resolved wire payload into every provider call the Lens makes. The model decides when (and whether) to use each enlisted tool.

## Enlisting a tool in a Lens

Add a `tools:` field to your Lens's frontmatter, with a list of slugs:

```yaml
---
title: News Article Summary
shape: matts/news-summary.shapemd
tools:
  - web-fetch
---
Summarise the article at {{url}} in three paragraphs...
```

The daemon resolves each slug against the live tools index and threads the resolved payload into every model call this Lens makes during its run. The model sees the tool as one option among any others it has -- including `produce_output` for enforceable Lenses -- and chooses freely.

A few things to know:

- **Slugs are case-sensitive.** `web-fetch` and `Web-Fetch` are not the same; the daemon does not normalise.
- **Order is preserved.** The order you list tools is the order they appear in the wire payload. Most providers are insensitive to order, but the order is stable for any that aren't.
- **Typos fail loudly at run time.** A lens declaring `tools: [web-ftech]` (typo) is indexed normally, but the run fails with `unknown tool slug` before any model round-trip. This is by design -- you'd rather see the typo immediately than see a run that silently lacked the capability you asked for.

## Bundled tools

Conflab ships a curated set of bundled tool fixtures via the CLI. Today the bundle covers the canonical Anthropic Read-Only-Web pair:

| Slug         | Provider tool         | Description                                                                                                              |
| ------------ | --------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `web-search` | `web_search_20250305` | Anthropic-hosted web search. The model issues a query; Anthropic executes it and returns results.                        |
| `web-fetch`  | `web_fetch_20250910`  | Anthropic-hosted web fetch. Pulls the contents of a specific URL (HTML, PDF, etc) into context. Pairs with `web-search`. |

List bundled slugs:

```bash
conflab tool list
```

### Bootstrap flow

You do not have to install bundled tools manually. The seed runs as part of first-run setup so a fresh install is ready to use.

| Path                                                 | What happens                                                                                                                              |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| macOS .pkg → app wizard → `conflab setup --bundle`   | Runs `daemon init` + `db init`. `db init` creates `~/.conflab/db/{lenses,shapes,tools}/` and seeds every bundled tool. No second command. |
| `conflab setup --interactive` (terminal users)       | Same as above. The wizard and the terminal entry share `apply_bundle`.                                                                    |
| `conflab db init` (advanced; called by setup itself) | Creates the LSD tree if missing; seeds bundled tools idempotently. Re-running is safe -- byte-matching files report `unchanged`.          |

When a daemon update ships a new bundled tool, or when you want to land bundle changes on an existing tree, run:

```bash
conflab tool sync             # idempotent; refuses to overwrite hand-edits
conflab tool sync --force     # also clobbers hand-edited files with bundled bytes
```

`conflab tool sync` prints per-slug outcomes (`installed`, `updated`, `unchanged`, `skipped`) and a summary line. Without `--force`, a hand-edited file is reported as `skipped` and the command exits non-zero so CI / scripts can detect divergence and prompt for `--force` interactively. With `--force`, the bundled bytes overwrite verbatim.

For surgical control over a single slug, the original install command is still available:

```bash
conflab tool install web-fetch          # idempotent; refuses overwrite without --force
conflab tool install web-search --force # explicit clobber
```

The bundled-fixture path writes to `~/.conflab/db/tools/<slug>.tool.json`; the filesystem watcher picks the file up automatically -- no daemon restart, no re-index. The vocabulary mirrors `conflab shape install`: `installed` (new), `updated` (changed), `unchanged` (already current), `skipped` (file differs from bundle, no `--force`).

## Authoring your own tool

For tools not in the bundle -- a private vendor's MCP-bridged tool, an Anthropic API constant your binary predates, or a custom server-tool you've negotiated with your provider -- write a `.tool.json` file directly into `~/.conflab/db/tools/`:

```bash
cat > ~/.conflab/db/tools/my-search.tool.json <<'JSON'
{
  "slug": "my-search",
  "kind": "anthropic_server",
  "title": "My Search",
  "description": "Search a private corpus via Anthropic's web-search API constant.",
  "tags": ["search", "internal"],
  "api_spec": { "type": "web_search_20260101", "name": "web_search" },
  "defaults": { "max_uses": 3 }
}
JSON
```

The filesystem watcher indexes the new file on the next event. Lenses can immediately enlist it via `tools: [my-search]`.

`~/.conflab/db/` is git-tracked, so commit the tool file alongside any Lenses that reference its slug. The tool, the Lens, and any Shape it uses travel together as one coherent change set.

## File format

Each `.tool.json` file is a JSON document with these fields. The slug is derived from the file path (so `web-search.tool.json` declares the `web-search` slug); the slug field inside the file must match.

| Field         | Required | What it carries                                                                                                                                  |
| ------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `slug`        | yes      | Stable identifier. Must match the path-derived slug.                                                                                             |
| `kind`        | yes      | `anthropic_server` today. Reserved for future client-tool and MCP-bridged kinds.                                                                 |
| `title`       | optional | Human-readable name for browse UIs.                                                                                                              |
| `description` | optional | One paragraph on what the tool does.                                                                                                             |
| `tags`        | optional | Free-form categorisation tags.                                                                                                                   |
| `category`    | optional | Single primary-category string.                                                                                                                  |
| `license`     | optional | SPDX-style identifier.                                                                                                                           |
| `api_spec`    | yes      | The provider's wire shape. For Anthropic server-tools: `{"type":"web_search_20250305","name":"web_search"}`. Threaded verbatim into the request. |
| `defaults`    | optional | Object whose keys merge into `api_spec` at resolution time. `api_spec` wins on key collision.                                                    |

The split between `api_spec` and `defaults` lets you carry author-tunable knobs (eg `max_uses`) separately from the load-bearing `type` and `name` fields. When a Lens runs the daemon shallow-merges `defaults` into `api_spec` and threads the result into the request body. The model never sees the slug; it sees the wire shape.

## Common pitfalls

- **fs-watcher latency.** A new tool file is usually indexed within a second or two. If you've just dropped one in and the run fails with `unknown tool slug`, give it a moment and retry; if it persists, check `daemon_logs` for an indexer error.
- **Hand-edited bundle files.** If you edited an installed bundle file and `conflab tool install` complains, the install command is doing its job (refusing to overwrite curated content). Pass `--force` if you want the bundle bytes back, or move your edited file aside. The nuclear "reset every customisation in this layer" path is `conflab tool pristine` (snapshots first; see [Pristine](pristine.md)). The bulk-remove path is `conflab tool uninstall`; per-slug surgical removal is `conflab tool delete <slug>`. See [Uninstallation](/app/help/cli/uninstallation).
- **Slug must match path.** A file at `~/.conflab/db/tools/foo.tool.json` whose body says `"slug": "bar"` is rejected at index time. The two must agree.
- **Tags vs category.** `tags` is multi-value and free-form; `category` is single-value. Most browse UIs surface tags for facet filters and category for primary placement.

## When to use

A Tool is the right primitive when you want the model to compose its work with an external capability mid-run -- "fetch this URL, then summarise" or "search the web, then synthesise". A Tool is NOT the right primitive when you want to fetch deterministically before the model runs (use a Lua programmable prompt instead, see [Programmable Prompts](/app/help/daemon/programmable-prompts)) or when you want the model to render structured output (use a Shape and the [Output Protocol](/app/help/daemon/output-protocol)).

The tool, the shape, and the system_prompt compose orthogonally. A Lens can declare a Shape (structural enforcement), a `tools:` list (mid-run capabilities), and a system_prompt (content rules) in one frontmatter block, and the daemon's multi-turn agent loop handles the interplay.

## See also

- [Lenses](/app/help/concepts/lenses) -- the concept behind `.lensmd` files.
- [Shapes](/app/help/concepts/shapes) -- the output-structure primitive.
- [Pristine](pristine.md) -- factory-reset bundled tools.
- [Uninstallation](/app/help/cli/uninstallation) -- per-slug, per-noun, and full app removal.
- [Output Protocol](/app/help/daemon/output-protocol) -- how enforceable Lenses tell the model to call `produce_output`.
- [Prompt Templates](/app/help/daemon/templates) -- the `.lensmd` format reference.
- [Programmable Prompts](/app/help/daemon/programmable-prompts) -- Lua-powered Lenses (an alternative to Named Tools for deterministic pre-fetch).
- [Bundled LSD Content](lsd-bundles.md) -- the bundled lenses, shapes, and themes that ship alongside `web-search` and `web-fetch`.
