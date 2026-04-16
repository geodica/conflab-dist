# conflab v0.1.12

_Released 2026-04-08_

SQLite lens/shape index, local usage tracking with stats UI, and several UX fixes.

## Added

- **SQLite lens/shape index** (ST0067/WP-02) -- conflabd indexes all lenses and shapes in SQLite on startup. `templates` and `shapes` GraphQL queries read from the index instead of scanning the filesystem. SHA-256 content hashing skips re-parsing unchanged files. Falls back to filesystem scan if no sync has run.
- **`conflab db` CLI commands** -- `conflab db init` creates `~/.conflab/db/` as a git-tracked content directory. `conflab db sync` parses .lensmd/.shapemd files and upserts into SQLite. `--force` rebuilds the entire index.
- **Local usage tracking** (ST0067/WP-04) -- every lens run records stats in SQLite: run count, success/failure, token totals, last run timestamp. Stats survive daemon restarts.
- **Lens tile stats badges** -- run count and "last run X ago" on lens tiles in the browser grid.
- **Stats tab** -- new tab in lens detail view with 6 stat cards: total runs, success rate, failures, input tokens, output tokens, total tokens.
- **`lensStats` query + `clearLensStats` mutation** -- GraphQL API for reading and clearing per-lens stats.
- **Stats auto-refresh** -- stats update immediately after a run completes.
- **Daemon auth on Lenses/Shapes pages** -- inline auth prompt when daemon requires authentication.

## Fixed

- Page flashing on Lenses/Shapes pages (health check firing events on every poll cycle).
- Template detail "not found" for lenses in subdirectories (tree builder was stripping directory prefix from IDs).
- Variable interpolation race condition when running lenses (form submit guarantees fresh values).
- CLI clippy warnings failing CI (collapsible_if, unit_arg).

## Changed

- `db.rs` and `db_sync.rs` moved to lib crate for CLI access.
- `TemplateNodeGql` includes `runCount` and `lastRunAt` fields.
- Backward-compat symlinks for legacy directory paths removed.

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```

After upgrading, restart conflabd. New SQLite tables are created automatically on startup:

```bash
conflab daemon stop && conflab daemon start
```
