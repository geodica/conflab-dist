---
title: Downloads
---

# Downloads

Four install channels, all coexisting. Pick the one that fits.

## macOS Installer (Recommended for desktop users)

Signed, notarised, Gatekeeper-silent `.pkg` installer. Installs the menubar app, CLI, and daemon in one shot.

- [Download for macOS (Apple Silicon)](https://conflab.space/download/mac)

Double-click the `.pkg`, step through the installer, then complete the first-run setup wizard from the menubar app. The wizard signs you in, installs the Conflab Local CA for HTTPS to the daemon, and starts the daemon service.

## Homebrew Cask (Same pkg, via brew)

Wraps the notarised installer:

```bash
brew install --cask geodica/conflab/conflab
```

Upgrade path:

```bash
brew update && brew upgrade --cask conflab
```

## Homebrew Formula (CLI + daemon only)

For developers who want the CLI without the menubar app:

```bash
brew tap geodica/conflab
brew install conflab
```

Installs `conflab` and `conflabd` into Homebrew's prefix. No `.app`. If you later want the menubar app, install the cask too; they coexist.

## Shell Script (CLI only, cross-platform)

macOS and Linux. CLI only by default:

```bash
curl -fsSL https://conflab.space/install.sh | bash
```

On macOS arm64 you can also pipe in the signed installer path:

```bash
curl -fsSL https://conflab.space/install.sh | bash -s -- --with-app
```

This downloads and launches the `.pkg` for you (same as the direct download).

## Available Platforms

| Platform              | Installer (.pkg) | Brew Cask | Brew Formula | Shell Script | Manual Download                                                                                                                 |
| --------------------- | ---------------- | --------- | ------------ | ------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| macOS (Apple Silicon) | Yes              | Yes       | Yes          | Yes          | [Conflab-arm64.pkg](https://github.com/geodica/conflab-dist/releases/latest/download/Conflab-arm64.pkg) or loose binaries below |
| macOS (Intel)         | --               | --        | --           | Planned      | --                                                                                                                              |
| Linux (x86_64)        | --               | --        | --           | Planned      | --                                                                                                                              |
| Windows               | --               | --        | --           | Not planned  | --                                                                                                                              |

Loose binaries (for scripting, CI, or manual install) live on [GitHub Releases](https://github.com/geodica/conflab-dist/releases).

After installing, follow the [Installation](/app/help/cli/installation) guide to complete setup.
