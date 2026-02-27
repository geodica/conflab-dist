# conflab v0.1.2

*Released 2026-02-27*

Housekeeping release — test stability and repository cleanup.

## Changes

- Fixed a fragile test in the help sidebar that asserted on decorative display text instead of data values.
- Removed stale `schema.graphql` dump that was no longer being generated.
- Cleaned up `.backup/` directory artifacts and added `.backup`, `.DS_Store`, and `Icon?` to `.gitignore`.

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
