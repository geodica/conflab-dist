# conflab v0.1.1

*Released 2026-02-26*

Release tooling and Homebrew distribution.

## What's New

### Homebrew Distribution

conflab is now available via Homebrew:

```bash
brew tap geodica/conflab
brew install conflab
```

This installs both the `conflab` CLI and the `conflabd` daemon. The daemon can be managed as a Homebrew service:

```bash
brew services start conflab
brew services stop conflab
```

### Automated Release Workflow

New `scripts/release` tool automates the full release pipeline:

```bash
scripts/release --patch    # bump, tag, build, publish, update formula
scripts/release --minor
scripts/release --major
scripts/release v0.2.0     # explicit version
```

The workflow handles version bumping in Cargo.toml, git tagging, CI build, GitHub release creation (on both source and dist repos), and Homebrew formula updates.

### Documentation

- Added Homebrew installation instructions to all relevant docs
- New conflabd overview section in documentation
- Home page now includes Install and Documentation buttons

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
