# conflab v0.2.1

_Released 2026-04-XX_

Patch release bundling five steel threads on top of v0.2.0: provider-scoped API keys in `models.toml` with an automatic migration and a full Models configuration UI (ST0086), a session-gated daemon token cycle flow (ST0087), a first-class file/directory selector variable type for lens runs (ST0088), a Lua stdlib + user library that collapses the glob-expand boilerplate into one call (ST0089), and a unified "Manage Conflab" window that replaces the old Status + Settings pair with a single six-tab surface (ST0090). Also ships the queued v0.2.0 close-out polish from ST0085 and wires `Conflab.RuntimeConfig` into the admin rate limiter + flag thresholds so admin Settings edits take effect within five seconds without a daemon restart.

## Added

### Daemon token rotation (ST0087)

- **Menubar:** Manage Conflab → Auth → Cycle API Key.
- **CLI:** `conflab daemon token cycle`.

Both flows open your browser to confirm the rotation via an OAuth loopback. After confirmation the new key is written atomically to `~/.config/conflab/daemon.toml`. Follow with `conflab daemon restart` (or click Restart Daemon in the menubar success alert). See [Token Rotation](https://github.com/geodica/conflab/blob/main/priv/docs/daemon/token-rotation.md) for the full walkthrough.

Cycling requires an active account session, not just the current daemon token, to protect against an attacker with `daemon.toml` read access from rotating you out. Also new: `conflab daemon restart` as a top-level verb.

### Glob variable type for lens runs (ST0088)

Lenses can now declare `type: glob` variables that hold a path or glob pattern pointing at files on disk. Paired with the new `fs` capability, Lua `conflab-exec` PREPARE blocks can iterate matches via `bridge.list_files` and load contents via `bridge.read_file`. The run-form picker wires a Browse button to a new daemon `pickPath` GraphQL mutation that opens the platform's native folder chooser. Safety: matched paths must resolve under your home directory, per-file reads capped at 2 MiB, listings capped at 256 entries.

### Models configuration UI + CLI (ST0086)

The Manage Conflab window's Models tab now edits `models.toml` directly via Add / Edit / Remove actions. Six new CLI verbs back the same code path:

- `conflab daemon model list`
- `conflab daemon model add <name> --provider <p> --model <m>`
- `conflab daemon model rm <name>`
- `conflab daemon model set <name> --model <m>`
- `conflab daemon model route <name> --target <r>`
- `conflab daemon model policy <name> --binding <p>`

Both surfaces enforce name-uniqueness + known-provider validation.

### Admin runtime tuning (RuntimeConfig)

`Conflab.Admin.RateLimiter.limit_for/1` and `Conflab.Lsd.flag_threshold/1` now read from `Conflab.RuntimeConfig` with a 5-second persistent-term cache. Keys: `rate_limit.review`, `rate_limit.flag`, `rate_limit.publish`, `flag_threshold.entry`, `flag_threshold.review`. Admin Settings edits take effect within 5 seconds without restarting conflabc or conflabd.

### Reusable Lua for lens authors (ST0089)

A `conflab.*` Lua stdlib shipped inside the daemon:

- `conflab.expand_glob(var)` — collapses the whole glob-expand-read-concat dance into a single call.
- `conflab.each_file(pattern, fn)` — iterate matches, errors logged and skipped.
- `conflab.require_var(name)` — raises a clear error when a required variable is missing.
- `conflab.truncate(str, bytes)` — clamps a string with a visible trailing note.
- `conflab.log_table(tbl, label?)` — pretty-prints through the daemon log.

Alongside it, `~/.conflab/db/lua/*.lua` auto-loads into the `user.*` namespace (failure-isolated per file).

### Unified "Manage Conflab" window (ST0090)

The macOS menubar app's two-window split (Status + Settings) has merged into a single six-tab window: General / Flabs / Models / Auth / Trust / About. One menubar entry ("Manage...", shortcut `⌘,`). Every panel on NSStackView + Auto Layout.

## Changed

### `models.toml` schema (ST0086)

API keys live under a new `[providers.<name>]` section instead of on every `[models.<name>]` entry. The daemon migrates existing configs automatically on first load — no action required.

### Cycle flow follows the active CLI profile

`conflab daemon token cycle` and the menubar's Cycle API Key button now target the active CLI profile's server, not `daemon.toml`. On success, `daemon.toml` is updated with both the new API key and the new server URL.

### Admin GraphQL is Bearer-authed from the macOS app

Fixes the Models tab silently failing with "Invalid or expired API key" on every load.

## Removed

### Workflows and Plugins tabs (macOS only)

Redundant: the old Workflows tab duplicated the web Lenses LiveView Runs panel; Plugins had zero installed plugins. Daemon-side lens execution and the plugin subsystem remain intact.

## Fixed

- Cycle flow auto-registers the current machine on first use instead of hard-failing with "No matching host key".
- Manage window polish: Models-tab keychain access, schema reload, selection flicker, tab-bar overlap, default window size.
- Auth tab inline cycle URL with a copy-to-clipboard icon when the automatic browser-open needs manual intervention.
- Run abort handles pending-* IDs correctly; model selector wired via `phx-change`; Opus 4.7 is the new default.
- Daemon `pickPath` GraphQL result matches before the generic catch-all.

## Security

### Daemon API key rotation is session-gated (ST0087)

Rotating the daemon's API key requires an authenticated account session in the browser, not just the current bearer. An attacker who has stolen just the bearer cannot cycle you out of your own key.

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

Upgrading from v0.2.0: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading, restart the daemon so it migrates `models.toml`:

```bash
conflab daemon stop && conflab daemon start
```

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
