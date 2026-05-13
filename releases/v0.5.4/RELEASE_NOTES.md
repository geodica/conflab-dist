# conflab v0.5.4

_Released 2026-05-13_

Planned release on top of v0.5.3's emergency patch. Three work-packages land together: a Menubar Settings UI for the agent-loop caps (so operators can raise `max_iterations` / `max_input_tokens` without hand-editing `daemon.toml`), full JSON-Schema validation of `produce_output` invocations with Decision-A retry (so type mismatches surface to the model and self-correct instead of silently coercing or poisoning downstream steps), and a 100% CLI / MCP / GraphQL parity audit closing every operator-facing gap across the conflabd management surface. The audit added 16 new MCP tools and 6 new CLI subcommands, retired a legacy REST handler in favour of GraphQL, and refactored four cross-cutting code paths through Highlander helpers so the three surfaces can never drift again.

100% surface parity + real-user cold-smoke are now release gates for every Conflab release going forward, paired with the durable rules captured in `memory/feedback_cli_mcp_graphql_parity.md` and `memory/feedback_real_user_cold_smoke.md`.

## Added

### Menubar Settings UI for agent_loop caps

The operator can now raise `max_iterations` and `max_input_tokens` from the macOS menubar (Manage → Daemon → Agent Loop) without editing `daemon.toml` by hand. The change persists to disk and hot-reloads the in-memory `state.agent_loop_caps` RwLock — a run already in flight keeps the caps that resolved when it started; the new caps apply to the next run.

- New `setAgentLoopCaps(maxIterations: Int!, maxInputTokens: Float!) -> AgentLoopCapsGql!` GraphQL mutation. Atomic replace, both fields required. Bounds: `1 ≤ max_iterations ≤ 1000`, `1_000 ≤ max_input_tokens ≤ 5_000_000`.
- New `agentLoopCaps: AgentLoopCapsGql!` GraphQL query for panel hydration on open.
- New `DaemonConfig::save_agent_loop_caps` writer (mirrors `save_log_level`): surgical `toml_edit` write to `[agent_loop]` preserving comments and adjacent-section formatting.
- macOS `DaemonPanelView.swift` gains an "Agent Loop" section: two `NSTextField`s with `NumberFormatter` bounds + a Save button. Hydrates current caps via `APIClient.getAgentLoopCaps()` in `panelDidAppear`.
- CLI parity: `conflab daemon caps [show | set]`. MCP parity: `get_agent_loop_caps`, `set_agent_loop_caps`.

### JSON-Schema validation for `produce_output` (Decision-A retry)

The duck-typed required-keys check in the agent loop's `produce_output` dispatcher is replaced with full JSON-Schema validation via the `jsonschema` crate. Type mismatches now surface as `tool_result { is_error: true }`, the model sees the validator's complaint in the next turn, and the existing Decision-A retry path lets it self-correct. Only `EnforceableShapeNotProduced` (no valid `produce_output` ever across the whole loop) remains fatal.

Behaviour change worth flagging: Template shapes now enforce declared types. Before v0.5.4 a model returning `{"title": 42}` against `Body {{title}}` slipped through and `render_shape` silently coerced it; the new validator rejects it with `at $.title: ... must be string` and the loop retries. The renderer's silent-coercion gap is closed by construction.

- `Dispatcher::new` is now fallible. Compiles a `jsonschema::Validator` once per run; per-turn dispatch is just a validation walk. A malformed `.shape.json` aborts the run with `LoopError::DispatcherInit` naming the offending shape — fail-fast, no silent fallback (IN-AG-NO-SILENT-001).
- Error format is prose, semicolon-separated, sorted by JSON pointer for cross-version stability: `produce_output input failed schema validation: at $.summary: ... must be string; at $.action_items[0]: missing required field "owner"`.
- Both `ShapeType::JsonSchema` (real `.shape.json` schemas) and `ShapeType::Template` (placeholder-derived synthesised schemas) route through the same validator.
- `instance_path_to_dollar` translates RFC-6901 JSON-Pointers to dollar-notation (`/foo/0/bar` → `$.foo[0].bar`; root → `$`). Unit-tested.

### CLI / MCP / GraphQL parity audit

100% parity across CLI subcommands, MCP tools, and GraphQL queries+mutations is now a release gate. Audit matrix at `intent/st/ST0114/WP/03/audit.md`. The audit landed in four clusters across this release window:

**Cluster 1 — read-only introspection.** Three new CLI subcommands (`plugin list`, `daemon config show daemon|agents`) and four new MCP tools (`get_health`, `get_log_level`, `list_plugins`, `get_policy_config`).

**Cluster 2 — model + policy admin.** One new CLI subcommand (`model verify-key <provider>` — issues a 1-token probe to confirm a stored API key is accepted; the plaintext key never leaves the daemon). Eight new MCP tools (`add_model`, `remove_model`, `set_flab_route`, `remove_flab_route`, `set_global_policy`, `set_model_policy`, `remove_model_policy`, `verify_provider_key`). All routed through eight new `apply_*` Highlander helpers in `mgmt/helpers.rs`.

**Cluster 3 — run lifecycle + log housekeeping.** Three new CLI subcommands (`daemon clear-logs`, `daemon config save daemon|agents`, `runs retry <id>`) and two new MCP tools (`clear_lens_stats`, `send_run_prompt`).

**Cluster 4 — cross-direction unifications.** Four Highlander refactors closing the last cross-surface drift:

- `apply_shutdown` helper: GraphQL `shutdown` mutation + MCP `daemon_stop` tool now route through the same daemon-state primitive.
- `conflab daemon stop`: tries GraphQL `shutdown` first with a 5s timeout, falls back to `launchctl unload` on any failure (unreachable, auth drift, refusal). The graceful path is always preferred; the launchctl path is the hard kill.
- `apply_memory_store` / `apply_memory_search` helpers: the MCP `memory_store` / `memory_search` tools now delegate to these, and two new GraphQL surfaces (`memoryStore` mutation + `memorySearch` query) hit the same helpers so the local sleeve has full CLI / MCP / GraphQL parity.
- `apply_plugin_sandbox_profile` helper + `pluginSandboxProfile(name)` GraphQL query: the legacy REST `/plugins/{name}/sandbox-profile` route + handler are retired. `conflab plugin inspect` is migrated to GraphQL. Closes a long-standing GraphQL-not-REST violation.

End state: 60 MCP tools, 20 GraphQL queries, 33 GraphQL mutations across the conflabd management surface, with every operator-facing capability reachable from at least two surfaces and most from all three. Six gaps were dropped as intentionally one-surface (admin-only bulk operations, interactive macOS file picker, security-sensitive bearer rotation).

### Test-isolation harness (issue 0003)

Catastrophic test gap discovered during cluster 2: the `mgmt` test harness did not isolate `models.toml` writes, so any happy-path mutation test that exercised `ModelsConfig::save()` wrote to the developer's real `~/.config/conflab/models.toml`. The duplicate-name test in cluster 2 surfaced this by stubbing out the user's three configured agents.

Resolution: new `test_support::with_tempdir_home()` returns a `TempHome` guard that redirects `$HOME` to a tempdir seeded with stub `daemon.toml` + `models.toml` files. Integration tests use `#[serial_test::file_serial(home)]` to mutex on the process-global $HOME across test binaries. Six happy-path integration tests in `tests/mutations_disk_writes.rs` exercise the cluster 2 + 3 disk-writing helpers under tempdir HOME. Issue 0003 closed.

## Documentation

Comprehensive doc audit refreshed both internal architecture docs (`docs/architecture/`) and user-facing help pages (`priv/docs/`) against the as-built state:

- MCP tool count corrected to 60 (was variously 13 / 26 / 44 across stale doc claims).
- 16 new MCP tool sections added to the Tools Reference page, with two new groups (Policy, Plugins).
- CLI commands reference updated with the new daemon, model, plugin, and runs subcommands.
- Agent-loop default `max_input_tokens` corrected from 100,000 to 200,000 (v0.5.3 bump).
- Architecture LoopError taxonomy extended with `DispatcherInit`.
- Roadmap document refreshed: current release v0.1.8 → v0.5.3 + v0.5.4 in flight, with a Subsequent Steel Threads section narrating ST0064 / 0066 / 0067 / 0068 / 0088 / 0099 / 0100 / 0106 / 0114.

## Tests + verification

- Rust daemon: `cargo test --features test-fakes` clean. 1141 lib tests + 7 agent-loop integration scenarios (added `i3b` for type-violation recovery via the new jsonschema validator) + 8 mutation parity + 6 disk-writes + smaller integration binaries.
- Rust CLI: `cargo build --manifest-path native/cli/Cargo.toml` clean at v0.5.4 (parity guards in `build.rs` pass).
- Live MCP smoke from within an active Claude Code session against the rebuilt daemon: confirmed `get_health`, `get_log_level`, `list_plugins`, `get_policy_config`, `get_agent_loop_caps`, `verify_provider_key`, `memory_store`, `memory_search`, `list_models`, `daemon_status` all responding with structured payloads against the new commit.
- Real-user cold-smoke: required pre-tag per the durable rule (`memory/feedback_real_user_cold_smoke.md`).

## Standing landmines (unchanged from v0.5.3)

- `brew unlink conflab` after `brew update` if local CLI builds stop reflecting `cargo build`.
- `CONFLAB_DISABLE_KEYCHAIN=1` for any test harness spawning `conflabd` under tmpdir HOME.
- `~/.conflab/db` is a separate git repo; pristine commands operate on it via the same Intent CLI rules.
- Tests that touch `~/.config/conflab/` MUST use the `TempHome` guard plus `#[serial_test::file_serial(home)]` (new in v0.5.4 — see `memory/feedback_conflabd_test_no_models_isolation.md`).

## Deferred to v0.5.5 / v0.6.x

- **Tier 1c — `router.self_identifiers` refresh on mid-run new flabs** (carried; vanishing impact post-v0.5.1).
- **ST0098 (Routines)** — v0.6.x.
- **ST0097 (Output Destinations)** — v0.6.x.
- **WhatsApp integration (ST0032)** — independent of the v0.5.x line.
