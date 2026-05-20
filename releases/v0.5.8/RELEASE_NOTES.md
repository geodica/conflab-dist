# conflab v0.5.8

_Released 2026-05-20_

Housekeeping patch closing two ST0119 carry-forward items: a daemon Highlander fix and the triage/close of a long-standing filesystem-watcher issue. No wire-protocol changes; no behavioural change at steady state.

## Fixed

### Daemon: single `ModelsConfig` load in the event loop

`run_event_loop` loaded `models.toml` twice at startup -- once for the router (which consumed it) and again to build the provider map and the models snapshot. Two independent disk reads could diverge if `models.toml` changed between them, leaving the router and the snapshot on different configs. The daemon now loads the config once, clones it for the router, and reuses the in-memory copy for the providers and snapshot. One source of truth; zero behavioural change at steady state.

## Housekeeping

- **Issue 0001 (fsevents-resync-fragility) closed.** macOS FSEvents can drop events for newly-created subdirectories under a recursive watch. The v0.3.5 periodic-resync backstop (default 60s, tunable via `[watcher].resync_interval_secs`) is sufficient at current LSD scale; the permanent kqueue-based fix stays documented as a future option gated on the LSD growing to thousands of files.
- ST0120 as-built documentation completed; session tracking docs updated.

## Migration notes

- No schema changes. No new database migrations. No CLI / daemon / macOS-app wire-protocol changes.
- Existing v0.5.7 installs continue to function. The daemon binary changes (the single-load fix) but its observable behaviour is unchanged.

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

Upgrading from v0.5.7:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary
```

No CA regeneration. No breaking client changes.
