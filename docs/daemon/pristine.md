---
title: Pristine
---

# Pristine

`conflab pristine` is the recovery tool for a drifted installation. It resets the bundled content (tools, lenses, shapes) and / or the configuration files (`config.toml`, `daemon.toml`, `models.toml`) to a fresh-install state, with default-on backup safety and a `--dry-run` preview. Use it when hand-edits accumulated past the point of "I'll fix this later", or before a clean test scenario, or when something has gone strange and you want a known-good baseline back.

For the lighter-touch case (refresh just the bundled bytes after a daemon update, leaving everything else alone), use [`conflab tool sync`](named-tools.md#bootstrap-flow), [`conflab lens sync`](lsd-bundles.md#bootstrap-flow), and [`conflab shape sync`](lsd-bundles.md#bootstrap-flow) instead. Those non-destructive primitives are the right tool for routine bundle updates; pristine is the nuclear option.

## What pristine does

For each target, pristine:

1. **Snapshots the live tree** to `~/.conflab/.backups/<rfc3339-compact>/<target>/` (eg `2026-05-07T143015/lenses/`). The full tree is captured -- bundled slugs and your hand-authored files alike -- so the backup is a complete pre-state restore point.
2. **Replaces the bundled slugs with bundled bytes** (for tools / lenses / shapes), or **clears the config files and re-runs `daemon init`** (for config). User-authored files (slugs not in the bundled registry) are NOT touched. The recovery is surgical for bundled content, paranoid-safe for everything else.
3. **Prints** a summary line per slug + a roll-up + the backup location. Vocabulary parity with `conflab tool sync`: `installed`, `updated`, `unchanged`, `skipped`, plus a backup roll-up line on top.

`--dry-run` short-circuits steps 1 and 2; the diff and the would-do summary still print. `--no-backup` skips step 1 entirely.

## Per-noun pristine

Each per-noun verb is a surgical reset against one slice of the live tree:

| Command                   | What it resets                                                                                                                                                                                                                                                          | Backup location                    |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| `conflab tool pristine`   | All bundled tool fixtures under `~/.conflab/db/tools/`.                                                                                                                                                                                                                 | `~/.conflab/.backups/<ts>/tools/`  |
| `conflab lens pristine`   | All bundled lenses under `~/.conflab/db/lenses/<theme>/`.                                                                                                                                                                                                               | `~/.conflab/.backups/<ts>/lenses/` |
| `conflab shape pristine`  | All bundled shapes under `~/.conflab/db/shapes/<theme>/`.                                                                                                                                                                                                               | `~/.conflab/.backups/<ts>/shapes/` |
| `conflab config pristine` | `~/.conflab/config.toml`, `~/.config/conflab/daemon.toml`, `~/.config/conflab/models.toml`. Stops the daemon, regenerates `daemon.toml` + `models.toml` via `daemon init`, leaves `config.toml` cleared so the user must re-run `conflab setup` to bootstrap a profile. | `~/.conflab/.backups/<ts>/config/` |

All four accept `--no-backup` and `--dry-run`.

```bash
conflab tool pristine                 # snapshot + reset bundled tools
conflab lens pristine --dry-run       # show what would happen, write nothing
conflab shape pristine --no-backup    # reset shapes without snapshotting first
conflab config pristine               # stop daemon, snapshot, clear, daemon init
```

## Top-level wrapper

`conflab pristine [--all|--config|--lenses|--shapes|--tools] [--no-backup] [--dry-run]` composes the per-noun verbs under a single backup root. One pristine invocation, one timestamped directory, all targets land underneath it:

```
~/.conflab/.backups/2026-05-07T143015/
  tools/
  lenses/
  shapes/
  config/
```

`--all` is shorthand for `--config --lenses --shapes --tools`. Specifying multiple flags explicitly composes the same way (`--lenses --tools` is equivalent to `--all` minus config and shapes).

Targets are dispatched in fixed order: **tools, then lenses, then shapes, then config**. The order matters: tools / lenses / shapes are db-tree resets that do not touch the daemon, so they go first while the daemon is still running and can pick up the file changes via the fs-watcher. Config is last so the daemon stop happens once at the end of an `--all` invocation -- the user is not stop-started multiple times.

Examples:

```bash
conflab pristine --all                          # nuclear reset, snapshot first
conflab pristine --all --no-backup              # nuclear reset, no snapshot
conflab pristine --all --dry-run                # show what would happen
conflab pristine --lenses --tools               # surgical: just lenses + tools
```

The `Daemon stopped. Run conflab daemon start or conflab setup to resume.` line is the expected exit state for any invocation that includes `--config` (or `--all`).

## Backup mechanism

| What                        | Detail                                                                                                                                                                  |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Location                    | `~/.conflab/.backups/<rfc3339-compact-timestamp>/<target>/` (eg `2026-05-07T143015/lenses/`).                                                                           |
| Scope                       | Full tree. Every file under the source directory is snapshotted, including user-authored files alongside bundled slugs.                                                 |
| Retention                   | User-managed. There is no auto-prune in v1. Old backups accumulate until you `rm -rf` them. A future `conflab backups list / prune` may land if disk pressure shows up. |
| Permissions / mtimes        | Preserved (cp -p style).                                                                                                                                                |
| Symlinks                    | Copied as symlinks; not followed.                                                                                                                                       |
| Top-level wrapper threading | One timestamped root per `conflab pristine` invocation, regardless of how many targets it hits. Per-target subdirs land underneath.                                     |

The location is co-located with the install root, persists across reboots, is easy to grep / `find`, and groups one pristine invocation's backups under one timestamp directory.

## Flags

`--no-backup` skips step 1 (snapshot). The replace phase runs normally. The right choice for nuclear-from-known-good-state scenarios (eg the macOS Settings "Reset" affordance after a confirmation modal), or for CI / test environments that do not want timestamped directories accumulating.

`--dry-run` skips steps 1 and 2 and prints what would happen instead. The diff phase still runs (read-only). Per-slug output uses `would install`, `would update`, `would skip` prefixes. The roll-up line ends with `(dry run)`.

## User-authored content

Pristine does not touch user-authored content in the live tree. A file at `~/.conflab/db/lenses/matts/my-personal.lensmd` (a slug not in the bundled registry) survives `conflab pristine --lenses` -- it stays in the live tree, and the backup captures a copy of it for paranoid recovery. The semantic is: bundled slugs are reset to bundled bytes; everything else is preserved.

This is identical to the sync semantics. The bundled set is a known list compiled into the CLI; anything outside that list is yours.

## Manual recovery from backup

If a pristine wiped something you wanted to keep, the backup is right there:

```bash
ls ~/.conflab/.backups/                                      # find the timestamp
cp -p ~/.conflab/.backups/2026-05-07T143015/lenses/<theme-slug>/<slug>.lensmd \
      ~/.conflab/db/lenses/<theme-slug>/<slug>.lensmd
```

Permissions and mtimes are preserved on the way in and out. The fs-watcher picks the file up automatically; no daemon restart, no re-index. There is no `conflab backups restore` command in v1; manual `cp -p` is the recovery path.

## When not to use pristine

- **You just want the latest bundled bytes after a daemon update.** Use `conflab tool sync` / `lens sync` / `shape sync`. Those are non-destructive and refuse to clobber hand-edits without `--force`. Pristine is the wrong tool here -- it forces the bundle bytes back even when the live file is fine.
- **You want to remove just one bundled slug.** Use `conflab lens delete <path>` / `shape delete <path>` / `tool delete <slug>`. See [Uninstallation](/app/help/cli/uninstallation).
- **You want to remove the entire app.** Use `conflab uninstall`. See [Uninstallation](/app/help/cli/uninstallation).
- **You want to swap the daemon's agent identity.** Use `conflab daemon init --handle <NAME>` followed by `conflab daemon token cycle --agent <NAME>` and then `conflab daemon restart`. Pristine clears the config but leaves the bound handle unchanged; the next `conflab setup` re-binds against the same `^CONFLAB` default. See [Installation](/app/help/cli/installation#after-install-how-your-daemon-gets-bound) for the bind flow.

## See also

- [Uninstallation](/app/help/cli/uninstallation) -- removing Conflab and its bundled content.
- [Bundled LSD Content](lsd-bundles.md) -- what gets reset by `lens pristine` / `shape pristine`.
- [Named Tools](named-tools.md) -- what gets reset by `tool pristine`.
- [Templates](templates.md) -- the `.lensmd` / `.shapemd` / `.tool.json` formats.
