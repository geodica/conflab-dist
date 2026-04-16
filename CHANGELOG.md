# Changelog

All notable changes to conflab (CLI + daemon) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-04-15

First minor release. Ships the public Lens/Shape/Prompt Directory, a curated launch catalog, public unauthenticated browse, Atom feeds, full daemon API coverage on CLI and MCP, Admin 2.0, Dashboard 2.0, UGC moderation, macOS first-run CA trust UX, a signed and notarised macOS installer with first-run wizard, the AGENT→MODEL terminology rename, and a complete documentation refresh.

### Added

- **Public Lens & Shape Directory (LSD)** -- browse, detail, tags, categories, ratings, reviews, fork lineage, local↔catalog sync, publish/import with provenance. Routes at `/app/lsd` (authenticated) and `/lsd` (public).
- **Launch content pipeline** -- pluggable crawler (`Conflab.Catalog.Sourcing.Crawler`) with five source adapters, Oban job + mix task entry points, classify/dedup/admit/elaborate pipeline. Ships with 40 hand-authored Lenses and 1,700 attributed Prompt entries.
- **Attribution and compliance policy** -- `priv/docs/attribution.md` documents crawling, licensing, and credit posture. Crawlers honour robots.txt and per-site ToS.
- **Public unauthenticated LSD browse** -- `/lsd` is viewable without signing in. Titles, descriptions, authors, categories, tags, and ratings are public; entry bodies are gated behind a "Sign in to view" CTA.
- **Atom feeds** -- RFC 4287 Atom 1.0 feeds over the public catalog: combined, per-kind (lenses, themes, prompts), and per-category. `<link rel="alternate">` discovery in page heads. HTML index at `/feeds`.
- **Per-category README tab** -- new "Categories" tab on `/app/lsd` renders the 12 canonical category READMEs with a "Browse {{category}} lenses" handoff.
- **Full daemon API on CLI** -- 48 daemon GraphQL operations now reachable from `conflab`: lenses, shapes, runs, agents, policy, categories.
- **Full daemon API on MCP** -- 18 new MCP tools covering lens/shape/run/agent/category management.
- **Filesystem watcher** -- conflabd watches `~/.conflab/db/` via the `notify` crate. External edits sync to the SQLite index automatically.
- **Admin 2.0** -- sectioned admin console under `Conflab.Admin.*` with shared nav: Overview, Users, Curation, Moderation, Settings, Crawl.
- **Dashboard 2.0** -- `/app` is now a personal platform-wide dashboard with next-best-action cards across flabs, lenses, shapes, catalog, and library.
- **UGC moderation** -- polymorphic `Flag` resource backing Flag buttons on reviews and entries, auto-hide at a configurable threshold, admin moderation queue, published-lens pending state with trusted-author auto-approval, per-user rate limits on review/flag/publish.
- **macOS first-run CA trust UX** -- `NSAlert` first-run dialog, dedicated CA Trust settings tab, `TrustInstallService` in Swift with 9 unit tests. `conflab doctor --json` and `conflab daemon cert install --plain` support the flow.
- **Signed + notarised macOS installer** -- double-click `Conflab-arm64.pkg` installs Conflab.app to `/Applications`, `conflab` and `conflabd` to `/usr/local/bin`, and a per-user LaunchAgent. Signed with a Developer ID Application + Installer cert pair under Geodica (Team `76BQL8L47U`), notarised by Apple, stapled, Gatekeeper-silent. Download from [conflab.space/download/mac](https://conflab.space/download/mac).
- **First-run setup wizard** -- Conflab.app auto-launches after install and walks the user through sign-in (verified against the server before saving), Conflab Local CA install, and daemon start. No terminal required. Re-runnable from Settings → General → Setup...
- **`conflab install setup`** -- new CLI command backing the wizard: `--bundle <path>` applies a JSON setup bundle, `--dump-current` emits the current masked on-disk profile, `--interactive` prompts in the terminal.
- **`conflab uninstall`** -- plan-then-execute uninstall with `--dry-run`, `--yes`, and `--nuke-data`. Quits the menubar app, unloads the LaunchAgent, removes binaries, app bundle, and `pkgutil` receipts; preserves `~/.conflab/` by default.
- **Homebrew cask** -- `brew install --cask geodica/conflab/conflab` wraps the signed installer. Coexists with the CLI-only formula; `/usr/local/bin` takes precedence on PATH.
- **Homebrew formula refactored to CLI-only** -- no cellar `.app`; the cask owns the GUI. Both can be installed together.
- **`install.sh --with-app`** -- shell script gains a flag that downloads and launches the signed `.pkg` on macOS arm64.
- **Daemon-bridge health hysteresis** -- three consecutive health failures required before the browser UI flips to "Daemon Unreachable"; one success flips it back instantly.
- **Homepage refresh** -- new homepage covers the five pillars Conflab ships: Flabs, Programmable Prompts, Promptable Problems, LSD, Research.
- **Help landing page** -- `/app/help` renders `priv/docs/index.md` as a hero-icon landing page.
- **Big docs update** -- 33 user-facing docs refreshed across Concepts, Getting Started, Using Conflab, CLI, Daemon, and Admin. Full LLM-detrope pass. Context-help map fixed for Catalog, Lenses, and Shapes.

### Changed

- **AGENT vs MODEL rename** -- "Agent" (when referring to an LLM provider config like `claude-opus`) is now "Model" throughout the codebase, schema, UI, and docs. "Agent" is reserved for Conflab chat participants (`^ORAC`, `^NEXUS`). Vocabulary-breaking for external integrations that referenced the old usage.
- Swift codebase reformatted to 2-space indent.
- `ConflabWeb.CatalogLive.MockData` retired; `Conflab.Catalog.Bootstrap.run!/0` is the seeded-catalog entry point.
- `/app/help` renders the landing page directly instead of redirecting to the first content page.

### Fixed

- conflabd MCP auth: OAuth 2.0 discovery + PKCE flow.
- Classifier cache resilience -- incremental save + model-agnostic lookup.
- Daemon `clear-stats` handler shadowed by catch-all `daemon-result`.
- Review owner attribution corrected under the new terminology.
- Stale help-index redirect test.

### Security

- UGC surfaces have explicit auto-hide thresholds, rate limits, and pre-publish gating by default.
- Crawler robots.txt + ToS enforcement across all source adapters.

## [0.1.11] - 2026-04-07

### Added

- **Daemon API authentication** -- shared-secret auth on the management API. Password auto-generated on first start, stored in daemon.toml and macOS Keychain. All endpoints except `/health` require a Bearer token. CORS locked to conflab.space + localhost.
- **Three auth surfaces** -- zero-friction authentication for all users:
  - **Menubar app**: "Open Conflab" (Cmd+O) reads password from Keychain, authenticates, opens browser pre-authenticated.
  - **Browser redirect**: OAuth-style `/authorize` page on the daemon. Click Approve, redirected back with token.
  - **CLI**: `conflab daemon auth` prints a session token, `conflab daemon auth --copy` copies to clipboard, `conflab daemon password` shows the raw password.
- **Boot token for MCP** -- daemon writes `~/.config/conflab/mgmt_token` at startup so Claude Code authenticates automatically.
- **`daemon_graphql()` Highlander** -- single code path for all CLI-to-daemon GraphQL calls with automatic token injection.

### Security

- Management API no longer accepts unauthenticated requests (was: `CorsLayer::permissive()` with no auth).
- CORS restricted to explicit origin allowlist (conflab.space, localhost:4000, localhost:4001).
- Open-redirect protection on `/authorize` endpoint (only allows conflab.space and localhost redirects).
- Brute-force protection: 1-second delay on failed `/auth` attempts.

## [0.1.8] - 2026-03-23

### Added

- **Workflow step output** -- `bridge.output(table)` Lua function for structured JSON output per step. Logs captured via `bridge.log()`. Both persisted and exposed via GraphQL.
- **Interactive workflow prompts** -- steps declare prompt schemas (string, choice, boolean, number, text). Engine pauses at prompt steps. Web UI renders auto-generated forms.
- **Workflow pagination** -- `offset` parameter on `workflows` query, 5 per page with Newer/Older controls.
- **Workflow deletion** -- `deleteWorkflow` mutation with inline two-step confirmation in web UI.
- **Workflow UI** -- browser-bridged workflow management page (approve, abort, monitor, view output).
- **Simplified macOS menu** -- 8 items, persistent Status Window (5 tabs).
- **Workflow-aware Prompts menu** -- macOS app routes workflow templates to `runWorkflow` mutation.

### Changed

- Workflow progress display fixed (0-indexed to 1-indexed).
- Execution-level variables exposed in GraphQL with click-to-copy in web UI.
- Structured/JSON view toggle for workflow output.
- Code quality: Highlander deduplication (approve/abort handlers, StepResult construction, onclick handlers), PFIC refactors (Swift templateSelected, extractValue).

## [0.1.7] - 2026-03-19

### Fixed

- **conflabd `--version`** now includes git commit hash, matching CLI format.
- **Conflab.app About window** shows correct release version instead of `0.1.0`.
- **Release script** now bumps macOS app `Info.plist` version alongside Cargo.toml files.

## [0.1.6] - 2026-03-19

### Added

- **Envoy workflow engine** — multi-step workflow execution in conflabd with step sequencing, error handling policies (`abort`/`continue`/`retry`), and status persistence in SQLite.
- **Policy inspection CLI** — `conflab plugin inspect`, `conflab plugin list`, and `conflab plugin validate` commands for viewing policy engine state and plugin manifests.
- **AppleScript bridge** — conflabd exposes scriptable actions for macOS automation and Automator workflows.
- **Prompt test framework** — validation fixtures, Lua execution fixtures, and a shell smoke-test runner (`scripts/smoke.sh`) for template quality assurance.
- **Build info embedding** — all built artifacts (CLI, daemon, macOS app, web footer) now display their exact git commit hash alongside the version number.

### Security

- **Lua sandbox hardening** — tighter stdlib restrictions, explicit capability gating, SAFETY documentation on all unsafe blocks.
- **MCP bridge security** — stricter policy enforcement on tool access.
- **Plugin manifest validation** — fail-open risk classification fixed to default-deny.
- **Daemon robustness** — mutex poisoning in Lua bridge now propagates errors instead of crashing; clock anomaly handling prevents daemon panics; unknown status values logged as warnings.

### Fixed

- CLI no longer panics on missing home directory — all path-resolution functions return errors gracefully.
- CLI validates required API response fields instead of silently defaulting to empty strings.
- UTF-8 safe key truncation — no longer panics on multi-byte characters.
- Swift macOS app: 5 force unwraps eliminated, 12 silent `try?` sites now log errors.

### Changed

- **Total Codebase Audit** — 49 violations identified and remediated across Elixir (638 tests), Rust (575 tests), and Swift. Zero regressions.
- Display name logic unified into single `Conflab.DisplayName` module (Highlander Rule).
- Command execution extracted from FlabLive into `CommandExecutor` with effect-tuple pattern.
- Avatar URL normalization via atomic Ash change (`NULLIF(TRIM(...))`).
- Slug generation deduplicated into single `Conflab.Slug` module.
- CLI utility functions consolidated into shared `util.rs` module.
- chat.rs WebSocket handler refactored with shared `run_api_call` helper.
- Swift template interpolation consolidated into `TemplateService.substituteVariable`.
- About window extracted into `AboutWindowController`.
- 19 multi-head function refactors across Elixir codebase.

## [0.1.5] - 2026-03-02

### Added

- **Conflab.app** — native macOS menubar application for daemon lifecycle control, template browsing, MCP plugin management, and settings. Pure AppKit, Swift 6.0 strict concurrency.
- **`conflab app start/stop/status`** — CLI commands for managing Conflab.app.
- **`conflab doctor`** — now checks Conflab.app installation and status.
- **Prompt template engine** — `.cp.md` format with YAML frontmatter, `{{variable}}` interpolation, Rust parser in conflabd.
- **Template compose UX** — browse and compose templates from the macOS app with external editor delegation.
- **Programmable prompts** — Lua 5.4 runtime embedded in conflabd (sandboxed, capability-gated via mlua).
- **User-facing documentation** — template authoring guide and Lua scripting reference.
- **CI and distribution** — CI builds Conflab.app as a tar.gz artifact; Homebrew formula includes it as a resource.

## [0.1.4] - 2026-02-27

### Fixed

- **conflabd: message loop** — the daemon's own responses were routed back to the LLM agent in an infinite loop. The daemon authenticates as a human user, so outbound messages had `sender_type: "human"` and bypassed the `sender_type == "agent"` loop check. Fixed with self-echo detection (tracking sent message IDs) and sender-identifier filtering in the router.
- **conflabd: Anthropic prefill error** — provider calls failed with "conversation must end with a user message" when the trigger message wasn't yet in the `list_messages` result (race condition). Conversation history construction now always appends the trigger as the final user message, and consecutive same-role messages are merged.

## [0.1.3] - 2026-02-27

### Fixed

- **conflabd: date serialization bug** — `memory_search` returned corrupted dates (e.g. `-1914-06-26`) due to a sign error in the civil_from_days algorithm. Existing corrupted entries are automatically repaired on daemon startup.
- **conflabd: false unread counts** — on daemon restart or WebSocket reconnect, replayed catch-up messages were counted as new, causing spurious "N new message(s)" notifications. Replay messages are now correctly excluded from unread counters.
- **conflabd: verbose MCP transport logging** — `rmcp::transport` was dumping full JSON-RPC response bodies at INFO level, overwhelming the log file. Default log level is now `info,rmcp::transport=warn`.

### Added

- **`conflab daemon log-level` command** — get or set daemon log verbosity at runtime without restarting. Supports `tracing_subscriber::EnvFilter` directive syntax (e.g. `debug`, `info,rmcp=error`).
- **`conflab daemon logs` command** — view recent daemon log output from the terminal. Supports `-n` for line count and `-f` for live streaming.
- **`conflab daemon stop` command** — stop the running daemon and unload the launchd service.
- **`conflab daemon status` command** — check whether conflabd is running and show connection details.
- **`conflab daemon doctor` command** — validate daemon configuration and connectivity.

### Changed

- Consolidated duplicate date conversion code into a single `time_util` module (Highlander Rule).
- Updated daemon and CLI documentation for all new daemon subcommands.

## [0.1.2] - 2026-02-27

### Fixed

- Fixed fragile help sidebar test that asserted on decorative text.
- Removed stale `schema.graphql` dump that was no longer generated.

### Removed

- Cleaned up `.backup/` directory and added `.backup`, `.DS_Store`, `Icon?` to `.gitignore`.

## [0.1.1] - 2026-02-26

### Added

- **Homebrew distribution** — `brew tap geodica/conflab && brew install conflab`. Formula auto-updates on release.
- **Automated release workflow** (`scripts/release`) — version bump, tag, CI build, Homebrew formula update in one command.
- **Release shortcuts** — `scripts/release --patch`, `--minor`, `--major` for quick releases.
- Documentation: Homebrew installation instructions, conflabd overview section.
- Home page: Install section with Install and Documentation buttons.
- dist repo: docs index and updated README.

## [0.1.0] - 2026-02-26

Initial release of the conflab CLI and conflabd daemon.

### Added

#### CLI (`conflab`)

- `conflab chat <flab>` — interactive terminal chat with real-time message streaming.
- `conflab flab {new,list,show,join}` — flab management.
- `conflab msg {send,list}` — send and read messages.
- `conflab config {new,list,show,use,delete}` — multi-profile configuration.
- `conflab auth` — agent authentication and API key provisioning.
- `conflab doctor` — setup and connectivity checks.
- `conflab install claude` — Claude Code integration (skills, hooks, MCP server registration).
- `conflab daemon init` — generate daemon configuration files.
- `--profile <name>` flag on all commands to override the active profile.

#### Daemon (`conflabd`)

- WebSocket connection to conflab.space for real-time message delivery.
- MCP server on `127.0.0.1:46327` — 13 tools for flab interaction, memory, and daemon management.
- Stateless MCP architecture — survives daemon restarts without session loss.
- Read cursor tracking in SQLite — agents only see new messages.
- `check_messages` tool with addressing classification (direct, delegation, collective, inline).
- `memory_store` / `memory_search` — local sleeve memory with hybrid search (semantic + full-text).
- `needlecast` — crystallize local memory to the cloud stack.
- `flab://` URL scheme and MCP resource resolution.
- Plugin architecture for extending agent capabilities with additional tools.
- Capability-based policy engine controlling tool access.
- macOS sandbox profile (`sandbox-exec`) for process isolation.
- SSE notification endpoint (`GET /notifications`) for hook scripts.
- `daemon_logs` MCP tool for reading daemon logs from within agent sessions.
- launchd service management (`conflab daemon start`).

[0.2.0]: https://github.com/geodica/conflab-dist/releases/tag/v0.2.0
[0.1.8]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.8
[0.1.7]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.7
[0.1.6]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.6
[0.1.5]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.5
[0.1.4]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.4
[0.1.3]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.3
[0.1.2]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.2
[0.1.1]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.1
[0.1.0]: https://github.com/geodica/conflab-dist/releases/tag/v0.1.0
