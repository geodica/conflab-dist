# conflab v0.6.0

_Released 2026-07-10_

A milestone release that modernises the project's tooling and infrastructure and lands a set of correctness and hardening fixes. Highlights: a daemon-connect crash fix, redirect-validation hardening in the daemon, a full Elixir type-checker cleanup, and local multi-host dev support -- on top of an Intent 2.16 tooling upgrade, parallel CI, and a dependency refresh. No schema or wire-protocol changes; existing installs upgrade cleanly.

## Added

### Local multi-host dev support (`conflab.localhost`)

The daemon now accepts configured `*.localhost` dev origins in both its CORS allowlist and its OAuth redirect validation, sourced from the shared `priv/config/endpoints.json` `dev_origins`. Together with a dev-only endpoint host setting, this lets the web app run under a hostname qualifier such as `conflab.localhost:4000` -- with a working daemon connection and auth flow -- as well as under bare `localhost`. Dev-facing; no effect on production installs.

## Fixed

### Daemon-connect page crash on the browser daemon-health signal

The `/app/daemon/connect` and `/app/daemon/token/cycle` LiveViews crashed with a `FunctionClauseError` when the browser-side `DaemonBridge` hook reported daemon health. Their route session was missing the central `LiveDaemonStatus` handler that every other `/app/*` route already attaches to catch those events. The handler is now attached consistently, so the daemon-connect flow no longer crashes.

### Redirect-validation hardening in the daemon

`is_safe_redirect` matched allowed redirect origins by prefix, which permitted an allowed origin to be extended into a different, attacker-controlled host (eg `http://conflab.localhost:4000.evil.com` or `https://conflab.space.evil.com`). Every arm now enforces an origin boundary -- the match must be followed by `/`, `?`, `#`, or end-of-string -- and the localhost/loopback arms additionally guard the port digits.

### Elixir type-checker cleanup

Cleared every Elixir 1.19 type-checker finding surfaced by the dependency refresh -- dead `{:error}` branches where the callee only returns `{:ok, _}`, always-true `!= nil` comparisons, a dead `|| []`, and unused `require`s -- plus a `with`-railway conversion in the Slack user cache. The tree is clean under `--warnings-as-errors`.

## Tooling & infrastructure

- **Intent 2.11 -> 2.16.1.** Development-tooling upgrade, including the multi-node whiteboard coordination workflow.
- **`scripts/` -> `bin/`.** Release, deploy, and developer scripts relocated to `bin/`; all references swept.
- **Parallel CI.** The test workflow is split into three parallel jobs (`elixir` / `rust-cli` / `rust-daemon`), cutting wall-clock time.
- **Dependency refresh + memento fork-pin removal.** Dropped the dead `matthewsinclair/memento` fork pin (memento 0.6.0 shipped the Elixir 1.19 `record/0` fix to hex and nothing depends on it); `req_llm` stays on its `agentjido` git fork pending a post-1.12 hex release.

## Migration notes

- No schema changes, no new database migrations, no CLI / daemon / macOS-app wire-protocol changes.
- Existing v0.5.8 installs upgrade cleanly. The daemon binary changes (redirect-validation hardening + dev-origin CORS) with no change to steady-state behaviour.

## Install / Upgrade

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

Upgrading from v0.5.8:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary
```

No CA regeneration. No breaking client changes.
