# conflab v0.4.0

_Released 2026-05-04_

Minor release on top of v0.3.5. Headline is **schema-enforced shapes via Anthropic tool-use plus a multi-turn agent loop (ST0106)** and **a named-tool registry (ST0107)**: structured lens output now goes through the model's `produce_output` tool call, validated against the lens's shape, and rendered through the shape's body template -- ending the long-standing system_prompt-vs-shape conflict where shape rules competed with structural directives in free-text prose. The daemon now drives a real Anthropic agent loop: every turn dispatches `tool_choice: auto`, daemon-side tools fire as the model requests them, and the loop terminates on `end_turn` (with hard caps on iterations and input tokens, and three-level overrides per lens). Lenses can declare server-tools by symbolic slug (`tools: [web-fetch]`), with the daemon resolving slugs to the Anthropic API tool spec at runtime via a new file-backed registry (`~/.conflab/db/tools/<slug>.tool.json`). Plus an XSS hardening sweep across the web + macOS surfaces, a Daemon-panel regrouping into Status / Process / Network / Auth / Logging, and a critic-rust cleanup batch.

## Added

### ST0106 -- Schema-enforced shapes via Anthropic tool-use (WP-01..07)

Five-WP foundation that moves shapes from prose-appended-to-prompt into Anthropic tool-use `input_schema`, eliminating the system_prompt-vs-shape conflict surfaced during personal-lens curation in v0.3.5.

- **WP-01 -- `tool_choice` parameter and `ToolDef` plumbing.** The provider seam (`Provider::send_message`) now accepts a `tool_choice: ToolChoice` argument (`Auto` / `None` / `Tool { name }`) plus a `tools: &[ToolDef]` array. The Anthropic provider threads both through to the wire payload. The Ollama / mock / fake providers accept and ignore them. Test-fakes feature toggled on for unit tests; daemon re-exports `ToolDef` for downstream construction.
- **WP-02 -- `Shape::to_tool_def()` for `.shape.json`.** A `JsonSchema` shape (the richer of the two shape types) now compiles directly to an Anthropic `ToolDef` with `name = "produce_output"`, `description` from the shape's title, and `input_schema` set to the JSON-schema body verbatim. The model gets a tool whose schema IS the shape contract.
- **WP-03 -- `mgmt/helpers` branching to tool-use enforcement.** `execute_prompt_template` now resolves the lens's `shape:` reference, picks the enforceable subset (JsonSchema directly + Template-with-`{{name}}`-placeholders lifted via WP-04), and threads the resolved shape down to `send_to_llm` so the agent loop can route through `Shape::to_tool_def()` when applicable. Non-enforceable shapes (Template with no placeholders, Example, prose-blob) stay on the synth-prompt path.
- **WP-04 -- Implicit-lift for `.shapemd` placeholders.** When a `Template` shape's body contains `{{name}}` placeholders, the daemon synthesises a JSON schema by extracting the placeholder set into required string fields. So a Template shape with placeholders becomes structurally enforceable without the author having to write `.shape.json` by hand. Shape resolution surfaces a loud `ShapeNotFound` error on misspelled or stale references rather than silently degrading to free-text output (per `IN-AG-NO-SILENT-001`).
- **WP-05 -- Renderer for `.shapemd` body.** `render_shape(shape, produce_output_input, selectors)` walks the shape body with `{{name}}` placeholders substituted from the model's `produce_output` call, plus optional lens-variable selectors for cross-cutting context. Output goes back through the daemon's standard renderer pipeline.
- **WP-06 -- Lens migration to `{{name}}` placeholders.** Four mfs lenses (`coaching-notes-summary`, `linkedin-profile-summary`, `meeting-summary`, `reading-list-entry`) migrated from inline-string `shape:` references to file-path references; structural rules stripped from `system_prompt:` (now lived in shape templates); `reading-list-entry`'s code-fence-echo defect resolved as a side effect of the architectural move. Compact format deferred to WP-07.
- **WP-07 -- Compact-format renderer with conditional sections.** Two-pass `render_shape` with `{{#var=value}}...{{/var}}` conditional sections so a shape can carry both Block (dated, multi-line) and Compact (week-prefixed, single-line) presentations within one body, selected by lens-variable selectors. Standalone-tag whitespace rule. End-to-end verified via the Launcher and the web run form.

### ST0106 -- Multi-turn agent loop (WP-08)

The big architectural lift of this release. Replaces the v1 single-turn forced-tool-use path with a real Anthropic agent loop that drives `tool_choice: auto` every turn. Three locked design decisions:

- **Decision A**: `produce_output` is one tool among many. The model opts in. `tool_choice: auto` every turn -- never force a specific tool.
- **Decision B**: Loud `EnforceableShapeNotProduced` failure when `end_turn` arrives without a valid `produce_output`. No silent degradation. Concretises `IN-AG-NO-SILENT-001`.
- **Decision C**: Two hard caps (`max_iterations = 10`, `max_input_tokens = 100_000`) with three-level override: compiled <- daemon.toml `[agent_loop]` <- per-lens frontmatter `agent_loop:` map. Operators can raise caps for known-expensive lenses without touching the daemon binary.

Plus four addenda:

- `produce_output` schema-validation failure is recoverable; only Decision-B "no valid call ever" is fatal.
- Server-tool slug resolution moved to the loop boundary; per-turn provider calls reuse the same `Vec<Value>` payload.
- Total-token accumulation across loop turns into existing `total_input_tokens` / `total_output_tokens` (strict superset of v1 semantics).
- `agent_loop_trace` is daemon-side SQLite (migration v19 added `agent_loop_trace TEXT` to `runs`); surfaced over GraphQL for the conflabc LiveView "Loop trace" tab.

**Highlander cutover (mid-WP).** Three top-level execution surfaces -- GraphQL `MutationRoot::run`, MCP `run_lens`, and the agent `McpToolDispatcher` (via MCP) -- now thin-wrap a single canonical helper `mgmt::dispatch_lens_run`. Lua bridges (`bridge.run_template`, `bridge.llm`) intentionally remain on `call_llm_provider` per the design's non-loop primitive carve-out. v1 helpers `extract_tool_use_output` + `render_tool_use_through_shape` deleted -- the agent loop's finalize step replaces them.

Verified end-to-end via three smokes against `matts/reading-list-entry`:

- `run-d5db1d25-4df7-4a2e-992a-8e48cfa23e50` (CLI -> GraphQL).
- `run-ebf4701a-2682-4ad6-a3c8-cd110a10e4a5` (Swift app -> GraphQL).
- `run-268d3037-113c-4ea5-b92e-0d18f59fbdf4` (MCP `run_lens`).

All three: status=completed, agent_loop_trace persisted with 2 turns (tool_use -> end_turn), `produce_output` dispatched with `is_error=0`, `llm_response` populated.

### ST0106 -- Convention doc + lens output protocol (WP-09)

New `intent/docs/conventions/lens-output-protocol.md` codifies the canonical "Output protocol" stanza for any enforceable lens. With Decision A (model opts in) plus Decision B (loud failure when it never does), every enforceable lens MUST tell the model to call `produce_output`. The convention doc is the canonical reference; enforcement is runtime (Decision-B loud failure) plus PR review against the doc.

Three matts/\* lenses migrated in the LSD repo with the canonical stanza: `coaching-notes-summary`, `linkedin-profile-summary`, `meeting-summary`. Each smoke-tested live against claude-haiku and confirmed: 2-turn `tool_use -> end_turn`, `produce_output` dispatched with `is_error=0`, `llm_response` populated.

`reading-list-entry` got `tools: [web-fetch]` plus a fetch-when-URL-only instruction; sonnet smoke (`run-cbb0d706`) shows the canonical 3-turn loop `tool_use(web_fetch) -> tool_use(produce_output) -> end_turn` end-to-end against a real Anthropic-hosted server-tool. Real-world finding: claude-haiku declined to fetch the same URL across two attempts and confabulated a summary from training-data knowledge -- a model-quality observation about lens-prompt rigour, not a daemon defect; sonnet honoured the contract.

### ST0106 -- Integration tests against fake provider (WP-10)

Six scripted-fixture scenarios (I1-I6) at `native/daemon/tests/agent_loop_integration.rs` prove the agent loop integrates correctly through both `mgmt::dispatch_lens_run` and the GraphQL `run` mutation against scripted `FakeProvider` sequences. Mirrors L2/L3/L4/L5/L7 from the loop's unit tests at integration scope; I6 adds cross-surface parity (helper-direct vs GraphQL -- proves the Highlander wrapper adds zero behaviour, covering MCP `run_lens` by transitivity).

Asserts on persisted `Run.status`, `agent_loop_trace` JSON shape (turn count, stop_reasons in order, dispatch is_error flags), summed token totals, and `RunGql` wire fields. Lens / shape fixtures live in a per-test-binary tempdir wired up via `OnceLock`-bound `CONFLAB_LENSES_DIR_OVERRIDE` + `CONFLAB_SHAPES_DIR_OVERRIDE` env-var escape hatches (mirrors the established `CONFLAB_DISABLE_KEYCHAIN` pattern).

### ST0107 -- Named-tool registry (entire ST, WP-01..12)

Structured ground for ST0106's tool-use plumbing. Replaces a rejected hardcoded-string design with a file-backed registry: `~/.conflab/db/tools/<slug>.tool.json` is a new file type joining lenses and shapes. Lenses, daemon config, and agent reasoning loops reference tools by symbolic slug; versioned API strings (eg `web_search_20250305`) live exclusively in tool files. Compile-time slug constants + startup validator make typos fail fast.

Twelve WPs covered the full stack:

- **WP-01..03** -- Tool-file parser + types, in-memory registry, SQLite index + sync flows.
- **WP-04..07** -- `fs_watcher` integration, lens frontmatter `tools[]` field with pure validation helper, persist + warn pass + resolver, `Provider::send_message` server_tools merge wired through `call_llm_provider`.
- **WP-08..09** -- Source-referenced slug constants + startup validator, GraphQL surface for the lens `tools` field.
- **WP-10..11** -- `conflab tool install` CLI bundling the daemon's seed `web-search.tool.json`, named-tools authoring guide (chapter 14 of the architecture docs).
- **WP-12** -- End-to-end smoke against `web_search_20250305`.

### XSS hardening sweep (web + macOS)

Three commits closing the LLM/lens/shape XSS surface that surfaced during the WP-07 audit, ahead of WP-08:

- **`fix(web): escape LLM/lens/shape content by default`** (`f22badbc`) -- any content authored by an LLM, a lens body, or a shape body now renders with default escaping. Removes Phoenix.HTML.raw paths that previously trusted the source.
- **`fix(web,macos): render LLM output as raw emitted text -- never as live DOM`** (`0e871f57`) -- LLM responses now render via CodeMirror raw text on both surfaces. Phoenix uses `phx-hook="SourcePreview"`; macOS uses the `ReadOnlyCodeMirror` SwiftUI view backed by `CodeView`. Never piped through a markdown renderer or Phoenix.HTML.raw again.
- **`fix(macos): MarkdownFallback uses CodeMirror for strict parity with web`** (`8c0bc8c7`) -- the macOS markdown-fallback path now also routes through CodeMirror so content rendering is hostile-by-default on both surfaces.

### Daemon panel regrouping in macOS Manage (612bde13)

The Daemon tab of Manage Conflab regroups its rows into five labelled sections: Status / Process / Network / Auth / Logging. Each section uses the standard NSStackView + Auto Layout idiom (per the established AppKit standards memory). No behaviour change; the rows are the same.

## Fixed

- **`fix(daemon,web): surface unresolved shape references; CodeMirror for JSON LLM responses`** (`35abd24c`) -- shape resolution now surfaces a loud error when a lens references a missing shape (instead of silently degrading to free-text output). JSON-typed LLM responses render through CodeMirror with JSON syntax highlighting.
- **`fix(daemon): resolve_shape handles extensionless shape_id references`** (`5cf4c86c`) -- LSD shape pickers and catalogue references store shape_ids without extensions (eg `matts/reading-list-entry`); `resolve_shape` now tries `.shape.json` then `.shapemd` as suffixes against `shapes_root` (`.shape.json` wins on collision since its richer schema is typically what an author meant to reference when both files exist).
- **`fix(web): shape detail body renders via CodeMirror; correct json-schema literal`** (`4afcfc82`) -- shape detail page renders the body through CodeMirror; the json-schema-vs-`json_schema` literal mismatch corrected.
- **`fix(web): SHAPE chip in lens editor truncates cleanly instead of wrapping mid-id`** (`0f8944cd`) -- shape-id chip handles overflow gracefully.
- **`fix(web): SHAPE chip badge no longer overlaps description`** (`2eb368cc`) -- companion to the wrap fix.

## Changed

- **Critic-rust cleanup batches.** Five refactor commits across the daemon: Highlander factor + serde-collapse + lock-poison handling (`b342bf5b`), silent-failure cleanup on DB columns / PID file / warn dedup (`e47b82ac`), thiserror enum sweep on shape + tool parsers (`a7371a91`), thin-coordinator extraction of `run_workflow_path` + `run_simple_path` (`1dc17416`), minor cleanup (shape scan warns + drop eager body clone -- `ef3ee5db`).
- **Critic-elixir cleanup batches.** Seven fix commits across the web layer: 7 `Ash.get/load` sites routed through domain interfaces (`98aaa8ab`); admin overview moved to `Conflab.Admin.Stats` (`33207f36`); `cycle_daemon_token_live` uses Accounts interfaces (`2eb368cc`); analytics actor on query, not terminal read (`7b7e282d`); `lua_sandbox.safe_inspect` logs failure instead of swallowing (`4f6d2046`); `public_catalog_live` uses Catalog domain interface (`14d328e7`); v2.11.3 critic findings cleared (`c41d36ed`).
- **Style sweeps.** `eg` enforced over `e.g.` across the tree (`9e8623c4`). Manually-wrapped `.md` files unwrapped via `prettier --prose-wrap never` (`8fad0bcb`).
- **Oban 2.22.1 dep bump** (`0e578df8`).
- **mix.lock dep bumps (rider on the WP-10 commit).** ash_phoenix 2.3.21->22, bandit 1.10.4->1.11.0, phoenix_live_view 1.1.28->29, req_llm 1.10->1.11, server_sent_events 0.2.1->1.0.0, spark 2.6.1->2.7.0. Patch-level drift only; no source changes.

## Migration notes

- **Lens authors with enforceable shapes**: any lens with a `shape:` reference now needs an `## Output protocol` H2 section in its `system_prompt`. The convention doc at `intent/docs/conventions/lens-output-protocol.md` carries the canonical stanza template. Lenses without it will fail loudly under the new agent loop with `EnforceableShapeNotProduced`. The four mfs lenses are already migrated; any third-party lens needs the same update.
- **`tools:` frontmatter is new**: lenses can now declare server-tools by symbolic slug (eg `tools: [web-fetch]` or `tools: [web-search]`). The daemon resolves slugs against the registry at run time. No action needed unless you want a lens to use a server-tool.
- **Daemon caps**: defaults are `max_iterations = 10`, `max_input_tokens = 100_000`. Operators can raise per-lens via the lens's `agent_loop:` frontmatter map, or globally via `daemon.toml [agent_loop]`. Most lenses won't hit either cap.
- **No Elixir migrations this release.** No breaking changes to the wire shape.

## Install / Upgrade

Four channels, all coexisting:

```bash
# Signed macOS installer (menubar app + CLI + daemon, arm64)
open https://conflab.space/download/mac

# Homebrew cask (wraps the installer)
brew install --cask geodica/conflab/conflab

# Homebrew formula (CLI + daemon only)
brew install geodica/conflab/conflab

# Shell script (CLI; --with-app runs the pkg on macOS arm64)
curl -fsSL https://conflab.space/install.sh | bash
curl -fsSL https://conflab.space/install.sh | bash -s -- --with-app
```

Upgrading from v0.3.5: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading:

```bash
conflab daemon restart   # pick up the new daemon binary (agent loop + named-tool registry)
```

The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
