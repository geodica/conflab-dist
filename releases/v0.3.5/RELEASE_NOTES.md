# conflab v0.3.5

_Released 2026-04-30_

Patch release on top of v0.3.4. Headline is **daemon log lifecycle and shape-composition fixes**: the daemon now writes daily-rolling log files with retention (default 14 days), exposes a `clearLogs` GraphQL mutation, and the macOS Daemon panel gains a **Clear Logs...** button with two-step confirmation. Two regressions surfaced during personal-lens curation are fixed: `execute_prompt_template` now correctly composes lens body + shape (the shape was silently dropped whenever the body was non-empty), and a periodic 60-second full-resync backstops macOS FSEvents to recover from the kernel's coalescing of new-subdir events. The web Lens runner's file-upload pipeline gains a Highlander on file-upload variable types so `texteditor+files` variables now correctly wire their (+) attach control. Plus design-only commits laying out **ST0106 (schema-enforced shapes via tool-use)** and **ST0107 (named-tool registry)** for upcoming work.

## Added

### Daily-rolling daemon log file with retention (123b8171)

Replaces the never-rolled `conflabd.log` appender with `tracing-appender` daily rolling. Files become `conflabd.YYYY-MM-DD.log`; the appender retains the most recent `log.max_files` (default 14) and deletes older dated files automatically, so the log directory stops growing without bound.

New `LogConfig` under `[log]` in `daemon.toml`:

```toml
[log]
rotation  = "daily"  # or "never" to preserve legacy single-file behaviour
max_files = 14
```

`rotation = "never"` keeps the legacy single-file behaviour for operators who want it.

New `crate::log_files` module owns log-file naming. Highlander on:

- `current_log_file(dir)` -- latest dated file or legacy fallback
- `resolve_log_path(configured)` -- smart resolver used by readers
- `list_dated_log_files(dir)` -- enumeration for clear-logs UX
- `delete_log_files_before(dir, cutoff)` -- retention helper for the new `clearLogs` mutation

Readers updated to use `resolve_log_path`, which transparently picks the dated file (production with rolling) or the configured path (rolling disabled, or test fixtures using arbitrary tempfile names): MCP `daemon_logs` tool, the resource resolver `/logs` endpoint, and the CLI `conflab daemon logs` subcommand.

The manual session-separator write at startup is retired; the equivalent goes through the appender as a structured `info!` line including version + git hash, so it lands in the correct dated file with proper formatting.

### `clearLogs` GraphQL mutation (6acc955c)

UI-driven log cleanup. The daemon owns its log lifecycle; the menubar app (and any future surface) just sends the mutation.

```graphql
mutation {
  clearLogs {
    filesDeleted
    bytesFreed
  }
}
```

Behaviour:

- Deletes every dated log file (`conflabd.YYYY-MM-DD.log`) whose date is strictly before today (UTC -- matches the date the rolling appender uses to name its files).
- Today's file (the one the appender is currently writing to) is preserved.
- The legacy `conflabd.log` (no date) is left alone -- removing the pre-rolling artefact silently from a one-shot UI button would surprise an operator. A separate flow can address it later.
- Returns counts so the UI can confirm the operation concretely.

New `time_util::today_utc_iso()` Highlander owns date-as-cutoff formatting.

### Clear Logs button in macOS Daemon panel (dbdb1245)

The Daemon tab of Manage Conflab gains a **Logs:** row alongside Diagnostics, with a **Clear Logs...** button. Two-step confirmation: first warns and explains what will happen, second is a final commit-style check. On confirm, calls the daemon's `clearLogs` GraphQL mutation (daemon owns the lifecycle; this view is a thin coordinator). Shows a result alert with deleted-file count and bytes-freed in human-readable units.

Wires:

- `APIClient.clearDaemonLogs()` / `APIClientProtocol`
- `ClearLogsResult` / `ClearLogsMutationData` Codable models
- `MockAPIClient` mirror so tests stay green
- `DaemonPanelView` `clearLogsButton` + handler

## Fixed

### Shape silently dropped from lens body composition (919e7e69)

`execute_prompt_template` had an if/else that only handled the body-empty path; body-non-empty fell through to body-as-is, ignoring `shape:` completely. Surfaced during personal-lens curation when a lens with a non-empty body and a `shape:` field produced output that ignored the shape.

Replaced with an exhaustive 4-arm match over `(body-empty, shape-present)`, so body+shape now correctly appends the synthesised shape after the body. Two regression tests in `mgmt/tests.rs` cover both shape-only and body+shape paths.

This is a behavioural-correctness fix for any existing lens that pairs a non-empty body with a `shape:` field. Output structure now follows the shape contract; lens authors who had been duplicating shape rules into the body to compensate may want to remove those duplications -- which is exactly the architectural concern that ST0106 addresses below.

### macOS FSEvents periodic resync backstop (919e7e69, 90ffe918)

`fs_watcher` had no resync backstop. macOS FSEvents can drop or coalesce events for newly-created subdirectories under a recursive watch, leaving the SQLite index out of sync until daemon restart. The symptom was silent staleness: a new lens or shape created under `~/.conflab/db/` did not appear in the daemon's catalog until the daemon was restarted.

New `WatcherConfig.resync_interval_secs` (default 60s, 0 disables) drives a periodic `FullResync` so any missed event corrects within the window. Tests use `tokio::time::pause` + `advance` for deterministic timer assertions; `tokio` test-util is added as a dev-dep.

The chatty side-effect of running the resync every 60s -- "Full resync triggered by filesystem watcher overflow" + "Full resync complete... 0 inserted, 0 updated, 0 deleted, N skipped" emitted unconditionally -- is suppressed (commit 90ffe918). The entry log is dropped entirely (it was also misleading: said "overflow" but fired for every periodic backstop). The completion log (now reworded "Full resync detected changes") is gated on a positive change count. Errors still log via `warn!` as before.

Tracked at `intent/issues/OPEN/0001/0001-fsevents-resync-fragility.md`. Permanent fix (kqueue + manual recursion or polling) is deferred to a future watcher-hardening ST.

### Highlander on web Lens runner's file-upload variable types (f3c9fb61)

Both the upload-pipeline configuration and the field-to-upload lookup filtered on the literal `"text+files"` string, missing `texteditor+files` variables. The renderer (which already handles both via `DaemonComponents.prompt_field/1`) was happy; uploads were silently not wired for `texteditor+files` vars, so the (+) attach icon never appeared.

Single source of truth: `@file_var_types` module attribute in `LensesLive.Helpers`. `configure_uploads/2` and `upload_for_field/2` both read from it. `file_input_variables/1` is extracted as a pure helper so the filter is testable.

## Changed

- **llm_db 2026.4.7 -> 2026.4.8.** Routine dependency refresh from hex.
- **Intent v2.11.0 upgrade.** Developer-tooling upgrade for the AGENTS.md / CLAUDE.md / rule-library scaffolding. Not user-visible at runtime.

## Design (NOT-STARTED, design-only commits)

Two architectural threads have their design committed in this release; no implementation lands here.

### ST0106 -- Schema-enforced shapes via Anthropic tool-use (426e291d, 6af88820)

Today the synthesised shape arrives as prose appended to the user prompt and competes with structural directives in the lens's `system_prompt`. ST0106 moves shapes into tool-use `input_schema` with `tool_choice` forcing the call, so the model returns JSON the daemon can validate and render against the shape template. Resolves the `system_prompt`-vs-shape conflict that surfaced during personal-lens curation.

The refront commit (6af88820) re-roots the design in lens/shape orthogonality (lens = programmable prompt, shape = reusable output structure) and adds the 2026-04-29 audit of the four shape-bearing personal lenses (`meeting-summary`, `linkedin-profile-summary`, `coaching-notes-summary`, `reading-list-entry`), mapping each duplication finding into the corrected architecture. `reading-list-entry` has an active code-fence-echo defect that the architectural move eliminates as a side effect; WP-06 ordering migrates it first.

Sized L (8 WPs). Design at `intent/st/NOT-STARTED/ST0106/design.md`.

### ST0107 -- Named-tool registry for symbolic tool references (426e291d)

Replaces a rejected hardcoded `"web_search_20250305"` + `ToolsConfig.bool` design from earlier in the session. A new file type, `~/.conflab/db/tools/<slug>.tool.json`, joins lenses and shapes. Lenses, daemon config, and agent reasoning loops all reference tools by symbolic slug; versioned API strings live exclusively in tool files. Compile-time slug constants + startup validation make typos fail fast.

ST0106's tool-use plumbing benefits from ST0107's registry being in place, so ST0107 lands first.

Sized L (12 WPs). Design at `intent/st/NOT-STARTED/ST0107/design.md`.

### Issue 0001 -- FSEvents resync fragility (c345fe96)

Captures the macOS-FSEvents-drops-events-for-new-subdirs root cause that surfaced during personal-lens curation, the working hypothesis that FDA (Full Disk Access) was responsible (it isn't), the periodic-resync mitigation shipped in this release, and the permanent-fix options for when watcher hardening is scheduled.

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

Upgrading from v0.3.4: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading:

```bash
conflab daemon restart   # pick up the daemon binary (rolling logs + clearLogs mutation)
```

No Elixir migrations this release. No breaking changes. The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
