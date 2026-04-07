# conflab v0.1.10

_Released 2026-04-07_

Notebook view, daemon settings UI, LensesLive modularization, and UI polish.

## Added

- **Notebook view (read-only)** -- new Notebook tab on Lens detail decomposes `.lensmd` files into typed cells (Context, Shape, Instructions, Code, Result). `Conflab.Lenses.CellParser` ports Lua block regex patterns from daemon `executor.rs`. `ConflabWeb.NotebookComponents` renders cells with type-dispatched visual chrome (cell_chrome wrapper, per-type renderers).
- **Daemon settings UI** (ST0066) -- Settings tab on `/app/daemon` page. Agent cards with model editing, default agent picker, flab routing table with add/remove. Changes persist to `agents.toml` via `toml::to_string_pretty` and hot-reload providers without daemon restart. `DaemonLive` rewritten with Daemon (iframe) + Settings tabs. New `DaemonLive.Queries` and `DaemonLive.Helpers` modules.
- **AgentsSnapshot** -- daemon state refactor: `agents`, `default_agent`, `flab_routing`, `system_prompts` replaced with single `Arc<RwLock<AgentsSnapshot>>`. 4 new GraphQL mutations: `updateAgent` (hot-reloads provider), `setDefaultAgent`, `setFlabRoute`, `removeFlabRoute`. New `agentConfig` query returns full agent details with `hasApiKey` flag. 11 read sites migrated across 6 files.
- **Browser collapse** -- chevron up/down toggle on Lens and Shape detail header rows. Collapses filter toolbar, tag row, directory tiles, and item tiles to maximize detail panel vertical space.
- **Error formatting** -- shared `error_alert` component in `RunComponents`. Parses raw API error messages (e.g., Anthropic 400 JSON) into readable summary + collapsible pretty-printed JSON detail. Replaces 4 raw error dump locations (Highlander).
- **Shapes auto-select** -- `auto_select_first_shape/2` picks first visible shape on page load via `TreeHelpers.flatten_leaves/2`, matching Lenses auto-browse behavior.
- **LensesLive modularization** (ST0064/WP-14) -- god module (2,447 lines, 111 functions) decomposed: `LensComponents` (630 lines), `RunComponents` (591), `ShapeComponents` (174), `LensesLive.Helpers` (422), `LensesLive.Queries` (59). LensesLive reduced to 902 lines. 36 audit violations fixed (missing `@impl true`, nested conditionals, `String.to_atom` on external input, `Jason.decode!` in HEEx, duplicated resets).
- **Delete mutations** -- `deleteTemplate` and `deleteShape` daemon mutations with full path validation (reject `..`, `/`, `\`; canonicalize after fs ops; verify path within root). 2-step confirm UI via "..." dropdown menu on both Lens and Shape detail panels.
- **26th MCP tool** -- `run_lens` registered in MCP tool registry.

## Changed

- **Shapes page layout** -- 3-column grid (was 4), description `line-clamp-2` (was 1), "Shapes" tab bar row for visual alignment with Lenses page.
- **Filter toolbar styling** -- wrapped in `bg-base-200/50 rounded-xl p-3` container matching directory/tile sections.
- **LiveView log suppression** -- `use Phoenix.LiveView, log: false` prevents telemetry logger from dumping full `handle_event` parameters (which include complete LLM responses from daemon bridge polling).
- **Shapes detail** -- added X close button for consistency with Lens detail. Button order: collapse toggle, "...", X (rightmost).

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```

After upgrading, restart conflabd to pick up the new binary:

```bash
conflab daemon stop && conflab daemon start
```
