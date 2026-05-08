---
title: Uninstallation
---

# Uninstallation

This guide walks you through removing Conflab from your machine, from a single bundled slug all the way to a complete wipe. Three layers of removal are covered: per-slug surgical removal, per-noun bulk removal of the bundled set, and full app uninstall.

For factory-reset (keep the app installed but reset bundled content + config to their fresh-install state), see [Pristine](/app/help/daemon/pristine).

## Layers of removal

| What you want                                               | Command                                                                     | Effect                                                                                                 |
| ----------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Remove one Lens / Shape / Tool by slug                      | `conflab lens delete <path>` / `shape delete <path>` / `tool delete <slug>` | Removes a single file from `~/.conflab/db/`. Surgical.                                                 |
| Remove all the bundled Lenses / Shapes / Tools (keep yours) | `conflab lens uninstall` / `shape uninstall` / `tool uninstall`             | Snapshots and removes every bundled slug; your hand-authored files are preserved.                      |
| Reset bundled content + config to fresh-install state       | `conflab pristine --all`                                                    | See [Pristine](/app/help/daemon/pristine). The app stays installed; the disk state goes back to day 1. |
| Remove the app, daemon, and CLI from this machine           | `conflab uninstall`                                                         | Strips binaries / app / LaunchAgent / pkg receipt / CA trust. Keeps `~/.conflab/` by default.          |
| Wipe everything, including your data                        | `conflab uninstall --nuke-data`                                             | The `uninstall` path plus `~/.conflab/` and app caches / preferences.                                  |

## Step 1: Decide the scope

The default uninstall (`conflab uninstall`) preserves `~/.conflab/` -- your profiles, lens / shape / tool tree, run history, and any user-authored content. Reinstalling later picks up where you left off.

If you also want to wipe `~/.conflab/`, use `--nuke-data`. There is no recovery path for nuked data unless you copied it elsewhere first.

If you only want to reset the bundled content but keep the app installed, you do NOT want uninstall -- you want [`conflab pristine`](/app/help/daemon/pristine).

## Step 2: Preview the uninstall

```bash
conflab uninstall --dry-run
```

Prints the plan with no side effects. Useful to verify which paths will be touched before committing. The output enumerates each binary, plist, pkg receipt, and CA trust entry the tool would remove.

## Step 3: Run the uninstall

### macOS (signed `.pkg` or Homebrew Cask)

If you installed via the cask, prefer the brew path:

```bash
brew uninstall --cask conflab
```

Otherwise:

```bash
conflab uninstall              # Removes app, binaries, LaunchAgent. Keeps ~/.conflab.
conflab uninstall --yes        # Skip the interactive confirmation.
conflab uninstall --nuke-data  # Also remove ~/.conflab/ and app caches.
```

The CLI confirms before destructive action unless `--yes` is passed. The wipe walks the install paths in order: quit the menubar app, stop the daemon LaunchAgent, remove the LaunchAgent plist, remove the CA trust entry from your login keychain, remove `Conflab.app`, remove the `conflab` and `conflabd` binaries, drop the pkg receipt, and -- with `--nuke-data` -- remove `~/.conflab/` and `~/Library/Application Support/Conflab/`.

Privileged steps (anything writing under `/Applications/`, `/Library/`, `/usr/local/`, or `pkgutil --forget`) are bundled into a single macOS admin dialog (Touch ID or password). One prompt, regardless of how many `[admin]` rows are in the plan. This works the same way whether you run from Terminal or via the Settings panel's Reset button -- the dialog is mediated by the macOS WindowServer, not by your shell's TTY.

### Homebrew formula (CLI + daemon, no app)

```bash
brew uninstall conflab
```

Strips the formula's binaries. `~/.conflab/` is preserved. Manually remove if desired.

### Linux / shell-script CLI

The shell script does not register a package receipt. Manual removal:

```bash
conflab daemon stop
rm -f /usr/local/bin/conflab /usr/local/bin/conflabd
rm -f ~/.local/share/conflab/launchd.plist  # macOS only; not present on Linux
rm -rf ~/.conflab/                          # only if you want to wipe data too
```

## Per-noun bulk uninstall

If you want to remove the bundled Lens / Shape / Tool set but keep the app and your customisations, use the per-noun uninstall verbs:

```bash
conflab tool uninstall                 # remove all bundled tools (web-search, web-fetch)
conflab lens uninstall                 # remove all bundled lenses across all four starter themes
conflab shape uninstall                # remove all bundled shapes
conflab tool uninstall --dry-run       # preview without writing
conflab lens uninstall --no-backup     # remove without snapshotting first
```

Behaviour:

- Iterates the bundled registry; for each bundled slug present on disk, snapshot to `~/.conflab/.backups/<ts>/<noun>/` then remove.
- User-authored files (slugs not in the bundled registry, eg `matts/my-personal.lensmd`) are NOT touched. They are counted in `preserved` and stay in place.
- Bundled-theme subdirectories that become empty after removal are swept too, so the live tree returns to its pre-install layout.
- Output mirrors `sync` and `pristine`: per-slug `removed` / `missing` lines + a roll-up + the backup location.

The output vocabulary:

| Status      | Meaning                                                               |
| ----------- | --------------------------------------------------------------------- |
| `removed`   | The bundled slug existed on disk and was removed.                     |
| `missing`   | The bundled slug was already absent before the uninstall ran.         |
| `preserved` | A user-authored file (not in the bundled registry) was left in place. |

## Per-slug surgical removal

For removing exactly one file:

```bash
conflab lens delete coding/review                  # remove ~/.conflab/db/lenses/coding/review.lensmd
conflab shape delete starter-working-with-documents/meeting-summary-shape
conflab tool delete web-fetch                      # remove ~/.conflab/db/tools/web-fetch.tool.json
```

There is no backup snapshot for `delete` -- it is a one-file operation, not a bulk reset. If you want the backup safety net, use `uninstall` (bulk) or `pristine` (factory reset) instead.

## Recovery from a backup

If a per-noun `uninstall` or `pristine` wiped something you wanted to keep, the backup is right there:

```bash
ls ~/.conflab/.backups/                                      # find the timestamp
cp -p ~/.conflab/.backups/2026-05-07T143015/lenses/<theme-slug>/<slug>.lensmd \
      ~/.conflab/db/lenses/<theme-slug>/<slug>.lensmd
```

Permissions and mtimes are preserved. The fs-watcher picks the restored file up automatically.

There is no `conflab backups list / restore` command in v1; manual `cp -p` is the recovery path.

## Reinstalling

To reinstall after `conflab uninstall` (without `--nuke-data`), follow [Installation](/app/help/cli/installation). Your `~/.conflab/config.toml`, profiles, and any user-authored Lenses / Shapes / Tools survive the round trip. The first-run wizard re-runs `conflab daemon init` and then `conflab daemon token cycle` against the same handle (`^CONFLAB`); the prior api_key is revoked at cycle time and a fresh one is minted. Your bound agent on conflab.space is preserved across the round trip.

`conflab uninstall` does not revoke the agent on the server -- only the local binaries, app, and LaunchAgent are removed. Re-installing on the same Mac picks up a fresh token automatically. If you want to delete the agent itself (eg before reinstalling on a different account), do so from the [Agents page](/app/agents) first.

To reinstall after `--nuke-data`, you start completely fresh. [Installation](/app/help/cli/installation) walks the full bootstrap.

## Troubleshooting

| Issue                                                    | Solution                                                                                                                                                                                                                                                                             |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `conflab uninstall` reports "not running" for the daemon | The daemon LaunchAgent is already unloaded. Uninstall continues -- the message is informational, not an error.                                                                                                                                                                       |
| Admin dialog appears mid-uninstall                       | Expected. The privileged-removals batch (anything under `/Applications/`, `/Library/`, `/usr/local/`, plus the pkg receipt) is run via one `osascript ... with administrator privileges` invocation. Cancel it and the elevated steps fail; the non-privileged steps still complete. |
| Settings panel "Uninstall Conflab..." silently no-ops    | Pre-v0.5.0 behaviour: bare `sudo` could not prompt without a TTY, so every privileged removal failed silently and the binaries survived. Resolved in v0.5.0 by routing privileged steps through `osascript`. Update to v0.5.0 or later.                                              |
| `command not found: conflab` post-uninstall              | Expected. The binary has been removed.                                                                                                                                                                                                                                               |
| `~/.conflab/.backups/` is large                          | User-managed; `rm -rf ~/.conflab/.backups/` is the prune. There is no auto-retention.                                                                                                                                                                                                |
| Reinstall complains about a stale pkg receipt            | `sudo pkgutil --forget space.conflab.pkg` then re-run the installer.                                                                                                                                                                                                                 |

## See Also

- [Installation](/app/help/cli/installation) -- the install side of the same surface.
- [Pristine](/app/help/daemon/pristine) -- factory reset without uninstalling the app.
- [Bundled LSD Content](/app/help/daemon/lsd-bundles) -- what the bundled lens / shape set is.
- [Named Tools](/app/help/daemon/named-tools) -- the bundled tool fixtures.
