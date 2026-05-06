# conflab v0.4.1

_Released 2026-05-06_

Patch release on top of v0.4.0. Headline is **ST0111 -- Pristine Config**: a coherent recovery surface that closes the install-side asymmetry from ST0110. New `conflab pristine` verbs across four targets (tools / lenses / shapes / config) plus a top-level `--all` wrapper, with default-on backup safety to `~/.conflab/.backups/<rfc3339-compact>/<target>/`. Symmetric per-noun uninstall (`conflab tool|lens|shape uninstall`) closes the gap between bundled-install and bundled-remove on every noun, and `conflab tool delete <slug>` brings tools to per-slug parity with lens / shape delete. macOS users get a new **Reset** tab in Manage Conflab with two NSAlert-gated buttons (`Uninstall Conflab...` and `Reset to defaults...`) shelling out to the matching CLI verbs, so an Alice user can reach the destructive admin actions without opening a Terminal. Two new help pages (`/app/help/cli/uninstallation` and `/app/help/daemon/pristine`) cover the verb family end-to-end. No breaking changes; no Elixir migrations.

## Added

### ST0111 -- Pristine Config (entire ST, WP-01..09)

Nine WPs covering the recovery surface end-to-end. Default-on backup runs once per top-level invocation and threads `<root>/<target>/` sub-paths through every called verb.

- **WP-01 -- Backup snapshot primitive** (`b1e8bc67`). `native/cli/src/backup.rs` Highlander on timestamped backup roots and recursive snapshots: `timestamped_backup_root_now()` / `_at()`, `snapshot_directory(source, root)`, `snapshot_file(source, root)`. RFC-3339 compact form (`2026-05-06T143015`) for the directory name. Permissions and mtimes preserved (`cp -p` style); empty / missing sources skip cleanly without creating the root; symlinks copied as symlinks.
- **WP-02 -- `conflab tool pristine`** (`ef364b29`). Per-noun reset for bundled tools. Snapshot the tools tree to `<backup>/tools/`, then `run_sync_at(force=true)` to restore every bundled slug. `--no-backup` skips the snapshot for nuclear-from-known-good scenarios; `--dry-run` prints the would-be outcomes without writing.
- **WP-03 -- `conflab lens pristine`** (`018b3320`). Same shape as WP-02, with theme-aware output: `unchanged starter-pr-first-pass-review (starter-working-with-code)`. Eleven bundled lenses across four themes; output groups by registry order. User-authored collections (eg `matts/...`) are preserved.
- **WP-04 -- `conflab shape pristine`** (`8bf6ffc1`). Seven bundled shapes, all under `starter-working-with-documents`. Path resolution hardcoded to `.shapemd` per ST0110/WP-02.
- **Highlander lift** (`d3345120`). `native/cli/src/pristine.rs` lifts the shared `PristineSummary<S>` struct + `diff_against_bundle` helper across tool / lens / shape; per-noun output formatting stays in each `<noun>_cmd.rs` because theme annotation differs (tools flat, shapes one theme, lenses four themes). Documented in `intent/st/COMPLETED/ST0111/WP/04/impl.md`.
- **WP-08 -- Symmetric per-noun uninstall** (`e7747e25`). Closes the gap raised mid-ST: install verbs added in ST0110 had no matching remove verbs at per-noun granularity. `conflab tool|lens|shape uninstall [--no-backup] [--dry-run]` removes every bundled slug while preserving user-authored content; `conflab tool delete <slug>` brings tools to per-slug parity with lens / shape delete. Theme uninstall stayed manifest-only (cascade is a sharp edge for v1; user can compose per-noun verbs for the cascade case). `UninstallSummary` mirrors `PristineSummary` and lives in the same Highlander module.
- **WP-05 -- `conflab config pristine`** (`f4597c50`). Stops the daemon, snapshots `~/.conflab/config.toml` + `~/.config/conflab/{daemon,models}.toml`, clears them, runs `daemon init` to regenerate `daemon.toml` + `models.toml`, prints a "run `conflab daemon start` to resume" hint. Sequence reordered from the literal design.md path: `daemon_init` reads `config.toml` to derive a profile, so `config.toml` is removed _after_ daemon-init runs (not before). Test isolation via fn-pointer params on `run_pristine_at` (daemon-stop + daemon-init) so unit tests do not spawn real daemons. `pub(crate)` lift on `daemon_cmd::run_init` and `daemon_cmd::run_stop` to compose against `config_cmd`.
- **WP-06 -- Top-level `conflab pristine [--all|...]`** (`50e7a4a3`). Wraps the four per-noun verbs behind a single command. Resolves the backup root once, threads `<root>/<target>/` through each per-noun call, and accumulates a composed summary. Fixed dispatch order: tools -> lenses -> shapes -> config (config last so daemon stop happens once, after the catalog targets are restored). `PristineRunner` trait + `LivePristineRunner` impl + `RecordingRunner` test stub for unit-test coverage of dispatch / order / single-backup-root invariants.
- **WP-07 -- Help-system docs** (`577ea63f`). Two new pages registered via `priv/docs/manifest.json` (no LiveView changes; the help sidebar is manifest-driven):
  - `/app/help/cli/uninstallation` -- mirror of `installation.md` in the reverse direction. Layers-of-removal table covers per-slug delete, per-noun uninstall, pristine, full uninstall, and `--nuke-data`. Brew-cask path. Manual recovery from backup. Troubleshooting.
  - `/app/help/daemon/pristine` -- per-noun verbs table, top-level wrapper, backup mechanism (location / scope / retention), `--no-backup` and `--dry-run`, user-authored content preservation, manual recovery, when not to use.

  Plus cross-link sweeps in `priv/docs/cli/installation.md` (pointer to the new uninstall guide), `priv/docs/cli/commands.md` (extended tables for `lens` / `shape` / `config` plus a new `tool` section and top-level `pristine` / `uninstall` sections), `priv/docs/daemon/lsd-bundles.md` (drop "(once landed)" parentheticals), and `priv/docs/daemon/named-tools.md` (cross-link the new pages).

- **WP-09 -- macOS Settings "Reset" tab** (`eb8e249d`). New `ResetPanelView.swift` panel in Manage Conflab between **Trust** and **About**. Two NSAlert-gated buttons:
  - **Reset to defaults...** -- shells out to `conflab pristine --all --no-backup` after a critical-style alert that lists the consequences (no backup, every bundled item restored, `~/.conflab/config.toml` cleared, daemon stopped).
  - **Uninstall Conflab...** -- shells out to `conflab uninstall --yes` after a critical-style alert. An inline checkbox in the alert toggles `--nuke-data` (also remove `~/.conflab/`); off by default to preserve user data.

  Both buttons route through `DaemonCLIShell.runCapturing` so binary resolution, lifecycle, and error mapping match existing CA-trust / token-cycle flows. Spinner + status label + read-only result panel show stdout/stderr inline. NSStackView + Auto Layout per the established AppKit conventions.

## Changed

- **`native/cli/src/pristine.rs` is the Highlander home for shared pristine + uninstall helpers.** `PristineSummary<S>` is generic over the per-noun status type; `diff_against_bundle(bundled_slugs, dir, slug_for_path)` is the shared registry-walk helper used across all four per-noun pristines and uninstalls. Per-noun `print_pristine` / `print_uninstall` formatters stay in each `<noun>_cmd.rs` because output annotation differs across nouns.
- **`daemon_cmd::run_init` and `daemon_cmd::run_stop` are now `pub(crate)`.** Lifted from private so `config_cmd::run_pristine_at` can compose them via fn-pointer parameters. No external callers; load-bearing for ST0111/WP-05.
- **`backup::snapshot_file`'s `#[allow(dead_code)]` removed.** WP-05 (`config pristine`) is its first caller.
- **mix.lock patch-level bumps** (`b522c79f`). phoenix 1.8.6 -> 1.8.7, zoi 0.18.1 -> 0.18.2. Verified green before commit.
- **`.claude/settings.local.json` allowlist update** (`f3de81a2`). Adds the prettier unwrap invocation used in WP-07 doc-sync passes.

## Migration notes

- **No breaking changes.** No Elixir migrations; no daemon-side schema migrations; no behavioural changes to existing `conflab` verbs.
- **Default-on backup is new but transparent.** Every `conflab pristine` and `conflab tool|lens|shape uninstall` invocation snapshots the affected directory under `~/.conflab/.backups/<rfc3339-compact>/<target>/` before mutating. Pass `--no-backup` to opt out for nuclear-from-known-good scenarios. Backups are user-managed; v1 has no auto-prune.
- **`config pristine` stops the daemon and leaves it stopped.** Re-run `conflab daemon start` (or `conflab setup`) to resume. The daemon is the only verb in the family that touches process state; per-noun pristines for tools / lenses / shapes leave the daemon untouched.
- **macOS users get a new Reset tab in Manage Conflab.** Existing tabs unchanged. The Reset tab is the menubar surface for the same CLI verbs; either path produces the same outcome.

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

Upgrading from v0.4.0: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading:

```bash
conflab daemon restart   # pick up the new daemon binary
```

The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
