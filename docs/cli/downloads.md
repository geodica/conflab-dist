---
title: CLI Downloads
---

# CLI Downloads

## Homebrew (Recommended)

The easiest way to install the Conflab CLI and daemon on macOS:

```bash
brew tap geodica/conflab
brew install conflab
```

This installs both `conflab` and `conflabd`. To upgrade:

```bash
brew update && brew upgrade conflab
```

## Quick Install Script

Install the CLI with a single command (macOS and Linux):

```bash
curl -fsSL https://conflab.space/install.sh | bash
```

This detects your platform, downloads the correct binary, and installs it to `/usr/local/bin/conflab`.

## Available Platforms

| Platform              | Homebrew | Shell Script | Manual Download                                                                                                               |
| --------------------- | -------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| macOS (Apple Silicon) | Yes      | Yes          | [conflab-aarch64-apple-darwin](https://github.com/geodica/conflab-dist/releases/latest/download/conflab-aarch64-apple-darwin) |
| macOS (Intel)         | —        | Planned      | —                                                                                                                             |
| Linux (x86_64)        | —        | Planned      | —                                                                                                                             |

Manual downloads are from [GitHub Releases](https://github.com/geodica/conflab-dist/releases).

After installing, see the [Installation guide](/app/help/cli/installation) to set up your profile and authenticate.
