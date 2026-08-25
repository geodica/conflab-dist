# conflab v0.6.2

_Released 2026-08-25_

A small patch on the same day as v0.6.1, closing two things that release left behind: a status line describing a check it had just stopped performing, and a build step that wrote the builder's home directory into a checked-in file. No schema changes, no migrations, no wire-protocol changes. One line of user-visible text changes; nothing else about the running system does.

## Fixed

### A verified key no longer claims a probe that no longer happens

`conflab model verify-key` and `conflab daemon doctor` reported a good credential as **"verified with a 1-token probe"**. That stopped being true in v0.6.1, which moved all three provider probes off a POSTed completion and onto an authenticated GET against the provider's model-listing endpoint -- so the check costs nothing and names no model that a provider can retire.

The line now reads **"verified against the provider's model list"**, which is what actually happens.

This is wording, not behaviour. The check, its result, and every status it can return are unchanged from v0.6.1. It is worth a release because the sentence described a mechanism, and a mechanism claim that outlives its mechanism is the same defect in prose that a stale model identifier is in code -- v0.6.1's own subject.

**Two daemon doc comments still carry the same stale description** (`mgmt/mutations.rs:937`, `mgmt/types.rs:393`) and are deliberately not fixed here. They are internal doc comments rather than user-facing text, and editing the daemon crate runs into the same whole-file rule check described below, which the daemon has not been migrated past. One further mention, in `provider/probe.rs`, is left exactly as it is: it describes what the probe *used to* do, and remains accurate.

## Tooling

### `xcodegen` no longer bakes an absolute path into the Xcode project

`project.pbxproj` is checked in, and its BuildInfo build phase resolves `${PROJECT_ROOT}` from `${SRCROOT}` at build time. But xcodegen expands `${VAR}` in a build-phase script against **its own environment at generation time**, and both scripts that call it export `PROJECT_ROOT` -- so generating through them replaced the portable form with the generating machine's absolute path.

The failure is quiet and one-directional. On the machine that generated it the path is correct, so the build stays green and reports nothing. Anywhere else -- another developer, CI -- `git -C "/Users/<someone>/..."` fails and the phase falls through to its own defaults, stamping the app `VERSION=0.0.0` and `GIT_HASH=unknown`.

Both call sites now generate with `env -u PROJECT_ROOT`. `${SRCROOT}` was never affected, because it is not exported.

### The CLI crate moved off `Result<T, String>`

Every fallible function in the `conflab` binary now returns `anyhow::Result<T>` -- 284 signatures across 39 files, plus the error constructions that fed them.

**No error message changed.** The migration preserved every format string verbatim, so what you see when something fails is byte-identical to v0.6.1. This is a type change, not a behaviour change.

It is here because it was the price of the one-line fix above. The Rust rule library asks binaries to use `anyhow` and libraries `thiserror`, and its check scores whole files rather than diffs -- so a two-character edit to any CLI file inherited every pre-existing violation in that file and was refused. The crate was, in practice, uneditable. The daemon has the same debt in a different shape and keeps it for now.

## Migration notes

- No schema changes, no new database migrations, no CLI / daemon / macOS-app wire-protocol changes.
- The only user-visible difference from v0.6.1 is the wording of one status line.
- Existing v0.6.1 installs upgrade cleanly.

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

Upgrading from v0.6.1:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary
```

No CA regeneration. No breaking client changes.
