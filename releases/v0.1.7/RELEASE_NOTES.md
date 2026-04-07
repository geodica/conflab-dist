# conflab v0.1.7

_Released 2026-03-19_

Version display consistency fix across all artifacts.

## Fixed

- **conflabd `--version`** now includes the git commit hash, matching the CLI output format (e.g. `conflabd 0.1.7 (abc1234)`).
- **Conflab.app About window** previously showed `v0.1.0` instead of the actual release version. Now correctly displays the release version from Info.plist.
- **Release script** (`scripts/release`) now bumps `CFBundleShortVersionString` in the macOS app's `Info.plist` alongside the CLI and daemon `Cargo.toml` files, ensuring all three artifacts stay in sync on every release.

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
