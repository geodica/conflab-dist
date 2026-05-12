# conflab v0.5.3

_Released 2026-05-12_

Emergency patch on top of v0.5.2. The Launcher Run flow broke under real-user testing within minutes of the v0.5.2 ship; v0.5.3 closes seven distinct bugs across the Swift menubar app, the Rust daemon's template pipeline, the Rust daemon's agent loop, and the daemon's diagnostic logging.

End-to-end after v0.5.3: drop two `.md` transcripts onto the Transcript field, click Run, watch Haiku complete in two turns (221k input -> 2.2k output) and Opus complete in two turns (298k input -> 2.8k output), see real meeting-summary content in the structured output card. Plus a daemon log line per lifecycle stage.

## Fixed

### Launcher Run flow works end-to-end for shape-typed lenses with file attachments

Four-arm fix across Swift + Rust:

- **Swift Run button (Bug 36)** -- `texteditor+files` / `text+files` required variables now satisfied by EITHER typed text OR attached files (`RunFormView.canRun` was inspecting only the text component).
- **Daemon validator (Bug 40)** -- `template::interpolator::validate` accepts `<name>_files` sidecar paths alone as a valid "filled" state for file-accepting types (was rejecting `transcript=""` even when `transcript_files` was populated).
- **Daemon auto-hydration (Bug 41)** -- non-Lua lenses (the common case for the Launcher) now auto-load attached file contents into the named variable. Each attachment becomes `## File: <basename>\n\n<contents>`, concatenated with `---` separators, capped at 2 MB total. Failures (path missing, permission denied, non-UTF-8) surface as Err per IN-AG-NO-SILENT-001. Sidecar preserved so Lua lenses still see raw paths.
- **Launcher timeout (Bug 37)** -- run mutation now has a 300s per-call budget (was 5s). Transport-layer timeouts surface as "Run is taking longer than 5 minutes -- check the Runs tab" via a new `LensLibraryError.runTimedOut` case, not the misleading "daemon unreachable" copy. Global default for non-run calls bumped 5s -> 30s.

### Decision-B error names the model + suggests Opus / Sonnet over Haiku (Bug 39)

`agent_loop::LoopError::EnforceableShapeNotProduced` gained a `model: String` field populated from `trace.last().model.clone()`. The display string now reads:

> model `<name>` did not call `produce_output` with valid input across N loop turn(s); the lens system_prompt may need to be more emphatic, or try Opus / Sonnet -- Haiku is measurably less reliable at tool-use compliance for shape-typed lenses

### Daemon `max_input_tokens` default 100k -> 200k (Bug 43)

After Bug 41 hydration, real meeting transcripts pushed the loop past the 100k input-token cap (the user's first Opus run hit 147,603 tokens). 200k matches Claude 4's standard context window. Override paths unchanged: `daemon.toml [agent_loop]` for operator-wide, lens frontmatter `agent_loop: { max_input_tokens: N }` for per-lens. Menubar UI surfacing deferred to v0.5.4.

### Lens run lifecycle logging (Bug 44)

Three new INFO breadcrumbs so a daemon run reads as a lifecycle thread instead of a silent-then-done event:

```
INFO conflabd::mgmt::mutations: lens run dispatching template_path=matts/meeting-summary model_override=Some("claude-opus") variable_count=3
INFO conflabd::mgmt::helpers:   lens file attachments hydrated into text slot bytes_hydrated=587234
INFO conflabd::agent_loop:      agent loop starting has_enforceable_shape=true client_tools=1 max_iterations=10 max_input_tokens=200000
INFO conflabd::mgmt::helpers:   agent loop completed run_id=run-... model=claude-opus turns=2 input_tokens=298057 output_tokens=2839
```

Hydration line only fires when the text slot grew, so non-file lenses stay quiet.

### Bug 38 -- investigation closed (NOT a daemon bug)

Initial framing was "daemon may be enforcing template shapes incorrectly". Investigation confirmed the daemon is doing exactly what ST0106/WP-04 specified: template shapes with `{{placeholders}}` lift to JsonSchema enforcement. The lens author opted in by declaring `shape: matts/meeting-summary.shapemd`. The fault was Haiku ignoring the tool instruction, addressed by Bug 39's error-enrichment.

## Tests + verification

- Swift `xcodebuild test`: 278 tests passing.
- Rust daemon: 1109 tests passing; `cargo clippy -- -D warnings` clean.
- Rust CLI: 264 tests passing.
- Real-user verification: Meeting Summary lens with two `.md` transcripts dropped in, run on both Haiku 4.5 and Opus 4.7. Both completed in two turns; structured output rendered correctly via the Template shape.

## Standing landmines (unchanged from v0.5.2)

- `brew unlink conflab` after `brew update` if local CLI builds stop reflecting `cargo build`.
- `CONFLAB_DISABLE_KEYCHAIN=1` for any test harness spawning `conflabd` under tmpdir HOME.
- `~/.conflab/db` is a separate git repo; pristine commands operate on it via the same Intent CLI rules.

## Migration notes

- **No breaking changes** to CLI verbs, daemon API, on-disk layouts, or the wire protocol.
- **For shape-typed lenses** (lens declares a `shape:` field), prefer Opus or Sonnet.
- **For very large inputs** (more than 200k tokens of attached content), raise the cap via `daemon.toml [agent_loop]` or lens frontmatter.

## Install / Upgrade

```bash
open https://conflab.space/download/mac
brew install --cask geodica/conflab/conflab
brew install geodica/conflab/conflab
curl -fsSL https://conflab.space/install.sh | bash
```

Upgrading from v0.5.2:

```bash
brew upgrade --cask conflab
brew upgrade conflab
conflab daemon restart
```
