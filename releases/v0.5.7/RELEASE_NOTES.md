# conflab v0.5.7

_Released 2026-05-20_

Feature release introducing one-touch daemon environment switching, fail-fast LaunchAgent behaviour for permanent configuration errors, a substantial internal refactor of the CLI's daemon command module (ST0119), and a clean `save` / `publish` split for Lenses and Shapes on the CLI (ST0120). No wire-protocol changes; no breaking changes for existing installs.

## Added (ST0119)

### WP-01 -- conflab daemon switch <env>

New one-touch environment-switch command. `conflab daemon switch <env>` resolves the unique agent profile that has credentials for `<env>`, stops the daemon, regenerates `daemon.toml` from the resolved profile, starts the daemon, and runs `daemon doctor`. If any post-switch check fails, the previous `daemon.toml` is restored automatically and the previous active profile is reinstated. The five-step `conflab config use ...; daemon stop; daemon init ...; daemon start; daemon doctor` recipe collapses to a single command with auto-rollback.

- `conflab daemon init` now refuses non-agent profiles before any filesystem write. A daemon initialised against a non-agent profile crashes in a LaunchAgent restart loop with an identity-mismatch error -- the guard surfaces a remediation hint (which agent profile to use) and fails cleanly instead.
- `conflab daemon doctor` adds a "Profile alignment" row that compares `daemon.toml`'s server URL against the active CLI profile's URL. A mismatch renders as a yellow warning (not a hard failure) with a "Run `conflab daemon switch <env>` to align" hint.

### WP-02 -- macOS Settings -> Flabs binding card + switch sheet

The macOS app's Settings -> Flabs tab now opens with a Connection card showing the active daemon binding (agent handle, server URL, connection state, connected flab count, daemon version). Below the card, a list of configured environments offers a Switch button on each non-active row. The button opens a confirmation sheet listing what will happen and what the user loses, then drives the WP-01 `conflab daemon switch` command behind a progress UI streaming the doctor's check-by-check output. Auto-rollback surfaces in the UI as a restored-binding indicator.

### WP-03 -- LaunchAgent fail-fast on permanent errors

The daemon now distinguishes permanent configuration errors (identity mismatch, missing handle, malformed config) from transient errors (conflabc unreachable, network drop). Permanent errors exit 0 with a `FATAL_NO_RETRY` marker in the log; transient errors exit 75 with `FATAL_RETRY`. The LaunchAgent plist now emits a conditional `KeepAlive` dict (`SuccessfulExit: false, Crashed: true`) so launchd respawns the daemon on crashes and non-zero exits but **not** on a clean zero exit. The five-dead-PIDs-in-fifty-seconds restart loop on identity mismatch is gone -- the failure surfaces once and stays surfaced.

- The installer's static plist at `scripts/macos.d/pkg/space.conflab.daemon.plist` is updated in lockstep so fresh installs carry the new policy from boot one. A Highlander test pins the contract.

## Added (ST0120)

### Lens / Shape save + publish CLI verbs

The CLI now mirrors the user mental model: **save** writes locally, **publish** pushes to the Catalog.

- `conflab lens save <path> --file <src>` and `conflab shape save <path> --file <src>` write a Lens / Shape to the local tree under `~/.conflab/db/{lenses,shapes}/`. Identical behaviour to the old `create` verb, which is retained as a deprecated alias.
- `conflab lens publish <path>` and `conflab shape publish <path>` push a locally-saved entry to the Catalog. The `--note <text>` flag records a changelog entry. Publishing requires a human profile (agent profiles are refused with a remediation hint); the entry lands `pending` moderation and is not publicly visible until approved.
- conflabc gains a `publishCatalogEntry` GraphQL mutation wrapping the existing `Conflab.Lsd.publish_entry/4` orchestration (Entry + EntryContent + Version in one transaction). No new database migrations.

This closes the install / publish symmetry gap: `install` pulls from the Catalog, `publish` now pushes to it from the CLI -- previously a web-UI-only action.

## Changed (internal)

### WP-04 -- daemon_cmd.rs module split

`native/cli/src/daemon_cmd.rs` (3574 lines) was split into a `native/cli/src/daemon_cmd/` module directory of 11 focused submodules: `mod.rs`, `init.rs`, `switch.rs`, `alignment.rs`, `lifecycle.rs`, `doctor.rs`, `token_cycle.rs`, `api.rs`, `admin.rs`, `observability.rs`, `runtime.rs`. Zero behaviour change; all files under 600 lines; every external caller of `crate::daemon_cmd::*` continues to resolve unchanged via mod.rs's narrow re-export block. Critic-rust review on the split surfaced six Highlander / structural findings + two test-quality recommendations, all fixed inline before WP closure.

## Fixed (same-session finders-are-fixers hotfixes)

- **Doctor "Invalid API key" hint pointed at the wrong command.** `conflab daemon doctor`'s 401 path used to say "Run `conflab config new <name>` to re-authenticate", but `config new` refuses existing profiles. The hint now correctly points at `conflab auth`, which re-issues credentials for the active profile's owned agents.
- **`conflab config new <existing>` now offers a real remediation.** Previously printed a bare "Profile already exists" with no recovery path. Now formats a profile-type-aware error: agent profiles get "run `conflab auth` against the env's human profile"; human profiles get "run `conflab config use <name> && conflab auth`".
- **`conflab daemon switch` no longer writes the OS hostname into daemon.toml.** Mid-build cold-smoke found the new switch path was falling through to the OS hostname as the agent handle when it should have used the canonical handle derived from the agent profile name. Threaded the canonical handle through the switch plan explicitly, pinned with regression tests.

## Documentation

- `priv/docs/cli/commands.md`: new `daemon switch <env>` row; tweaked `daemon init` (agent-profile requirement) and `daemon doctor` (Profile-alignment) entries.
- `priv/docs/cli/authentication.md`: new "Switching Environments" section covering CLI + macOS Settings -> Flabs UI.
- `priv/docs/daemon/overview.md`: new "Lifecycle and LaunchAgent" subsection explaining the conditional KeepAlive + `FATAL_RETRY` vs `FATAL_NO_RETRY` split; new "Binding and Environment Switching" subsection.
- `priv/docs/getting-started/installation-guide.md`: corrected `KeepAlive` row in the install-path matrix; added three Troubleshooting rows for the new daemon-binding and `FATAL_NO_RETRY` surfaces.
- `priv/docs/cli/commands.md`: added `lens save` / `lens publish` / `shape save` / `shape publish` rows; marked `create` as a deprecated alias.
- Catalog / save-publish housekeeping (ST0120): docs that referenced `conflab lens save` / `conflab lens publish` as if they existed now point at the real verbs (`concepts/lenses.md`, `concepts/shapes.md`, `concepts/agents.md`, `admin/content-pipeline.md`, `daemon/filesystem-watcher.md`, `daemon/templates.md`, `using-conflab/catalog.md`, `getting-started/installation-guide.md`).
- Path-drift cleanup (ST0120): stale `~/.conflab/prompts/` and `~/.conflab/shapes/` references across eight pages now use the canonical `~/.conflab/db/lenses/` and `~/.conflab/db/shapes/` (the legacy paths still resolve via the daemon's fallback chain).
- `scripts/release --next-tag` now accepts the flag form (`--patch` / `--minor` / `--major`) consistently with the surrounding release flags, alongside the legacy bare level.

## Migration notes

- No schema changes. No new database migrations. No CLI / daemon / macOS-app wire-protocol changes.
- Existing v0.5.6 installs continue to function. The new `daemon switch` command is purely additive. The LaunchAgent plist changes apply on next `conflab daemon start` (or on installer overwrite for pkg upgrades).
- The new `daemon init` non-agent-profile guard is a behavioural change: scripts that previously ran `daemon init` against a human profile will now receive a clear error pointing at the right agent profile. This is the same crash signal the daemon would have produced at boot, but surfaced before any filesystem write.

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

Upgrading from v0.5.6:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary and the new LaunchAgent plist
```

No CA regeneration. No breaking client changes.
