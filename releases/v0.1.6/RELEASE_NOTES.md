# conflab v0.1.6

_Released 2026-03-19_

Envoy workflow engine, security hardening, total codebase audit, and policy inspection CLI.

## Envoy Workflow Engine

conflabd now includes a multi-step workflow engine called Envoy. Workflows are defined as ordered sequences of steps, each with a type, parameters, and an error handling policy.

- **Step sequencing** — steps execute in order. Each step receives the output of the previous step as context.
- **Error handling policies** — each step declares one of three policies:
  - `abort` — stop the workflow immediately on failure (default)
  - `continue` — log the error and proceed to the next step
  - `retry` — retry the step up to the configured maximum attempts
- **Status persistence** — workflow state (pending, running, completed, failed) is tracked in SQLite. If the daemon restarts mid-workflow, status is preserved and queryable.
- **Step types** — the engine supports extensible step types. Initial types include LLM calls, tool invocations, and conditional branching.

Workflow definitions live alongside prompt templates and are executed via the management API.

## Security Hardening

Four work packages addressed security across the Rust and Lua layers:

### Lua sandbox hardening

- Tighter stdlib restrictions — only explicitly allowed modules are available inside the sandbox.
- Capability gating is now enforced at the Lua bridge level, not just the policy engine.
- All `unsafe` blocks in the Lua bridge carry `SAFETY` documentation comments explaining the invariant.

### MCP bridge security

- Stricter policy enforcement on tool access — tools are denied by default unless the policy engine explicitly grants them.
- Input validation tightened on all MCP tool parameters.

### Plugin manifest validation

- The previous fail-open risk classification (unknown plugins defaulted to "allowed") has been replaced with default-deny. Unrecognised plugins are rejected until explicitly approved.

### Daemon robustness

- Mutex poisoning in the Lua bridge now propagates errors to the caller instead of panicking the daemon.
- Clock anomaly handling prevents panics when the system clock jumps backward.
- Unknown workflow status values are logged as warnings instead of causing a crash.

## Total Codebase Audit

A polyglot audit (ST0055) swept the entire codebase across three ecosystems:

- **Elixir** — Highlander Rule violations (duplicate display name logic, slug generation, command execution), silent error swallowing, fragile text matching in tests. 638 tests pass.
- **Rust** — panic-prone unwraps in CLI path resolution, missing API response validation, UTF-8 unsafe key truncation, mutex poisoning crashes. 575 tests pass.
- **Swift** — 5 force unwraps eliminated, 12 silent `try?` sites converted to logged errors, template interpolation consolidated, about window extracted.

49 violations found and remediated across all three ecosystems. Zero regressions — all existing tests continue to pass.

Key refactors:

- `Conflab.DisplayName` — single module for display name resolution (was duplicated in 3 places)
- `Conflab.Slug` — single module for slug generation (was duplicated in 2 places)
- `CommandExecutor` — effect-tuple pattern extracted from FlabLive
- `util.rs` — shared CLI utility functions (was duplicated across subcommands)
- `run_api_call` — shared WebSocket API helper in chat.rs
- `TemplateService.substituteVariable` — consolidated Swift interpolation
- `AboutWindowController` — extracted from inline AppDelegate code
- 19 multi-head function refactors across the Elixir codebase

## Policy Inspection CLI

Three new `conflab plugin` subcommands for inspecting the policy engine and plugin system:

```bash
conflab plugin inspect <name>    # Show detailed policy and capability info for a plugin
conflab plugin list              # List all registered plugins and their status
conflab plugin validate <path>   # Validate a plugin manifest file
```

These commands are useful for debugging policy issues and verifying plugin configurations before deployment.

## AppleScript Bridge

conflabd now exposes scriptable actions for macOS automation:

- Actions are available via AppleScript and Automator workflows.
- The bridge enables integration with macOS system-level automation tools, Shortcuts, and third-party workflow apps.
- Scriptable actions mirror a subset of the MCP tool surface — sending messages, checking status, and querying flabs.

## Build Traceability

All built artifacts now embed the exact git commit hash alongside the version number:

- **CLI** — `conflab --version` shows `conflab 0.1.6 (abc1234)`
- **Daemon** — `conflabd --version` shows the same format
- **macOS app** — About window displays version and commit
- **Web footer** — conflabc web interface shows the build hash

This makes it straightforward to determine exactly which code is running in any environment.

## Prompt Test Framework

A new testing infrastructure for prompt templates:

- **Validation fixtures** — templates with known-good and known-bad frontmatter for parser testing
- **Lua execution fixtures** — templates that exercise the Lua runtime with expected outputs
- **Smoke test runner** — `scripts/smoke.sh` runs the full fixture suite against a running daemon, suitable for CI

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
