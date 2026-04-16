---
title: Filesystem Watcher
---

# Filesystem Watcher

conflabd watches `~/.conflab/` for changes to Lens and Shape files so the local SQLite index stays in sync with what is on disk. This is how local authoring works: edit a `.lensmd` file in your editor, save it, and the daemon picks up the change without you running a manual sync.

## What Is Watched

The watcher monitors:

- `~/.conflab/prompts/**/*.lensmd` -- [Lens](/app/help/concepts/lenses) files.
- `~/.conflab/shapes/**/*.shapemd` -- Markdown [Shape](/app/help/concepts/shapes) files.
- `~/.conflab/shapes/**/*.shape.json` -- JSON Schema Shapes.

Files outside these trees are ignored. Hidden directories (starting with `.`) are skipped entirely.

## What Happens on a Change

When the watcher sees a file created, modified, or deleted:

1. **Parse.** The daemon parses the file. Invalid YAML frontmatter or malformed content is logged; the entry is skipped rather than crashing the index.
2. **Index.** Valid entries are upserted into the daemon's SQLite index. Metadata (title, tags, variables, content hash) is extracted and stored.
3. **Notify.** MCP tools that list Lenses or Shapes immediately see the updated view.

Deletions remove the entry from the index.

## Write-Then-Sync Invariant

When conflabd itself writes a Lens or Shape (e.g. through `save_lens`), the sequence is:

1. Write the file to disk first.
2. Wait for the filesystem event.
3. Update the SQLite index from the reloaded file.

The file is always the source of truth. The index is a fast-read mirror. If they ever disagree, the index is wrong and re-sync fixes it.

## Manual Re-Sync

If the index falls out of sync (for example, after restoring `~/.conflab/` from backup):

```bash
conflab db sync            # incremental re-sync
conflab db sync --force    # full re-sync, ignores content hashes
```

Incremental re-sync compares content hashes and skips unchanged files. Force re-sync re-reads everything.

## Interaction with the Catalog

The filesystem watcher operates on your local files. Published Catalog entries live in the server-side Ash catalog DB. The two are distinct:

- Local edits update the SQLite index instantly.
- Publishing a Lens (`conflab lens save` followed by `lens publish`, or the web UI) pushes it to the Catalog DB.
- Browsing a Catalog entry does not touch your local files until you fork or download it.

See [The Catalog](/app/help/concepts/catalog) for the three-layer storage architecture.

## Logs and Debugging

Watcher activity logs at `info` level by default. Increase verbosity to see each file event:

```bash
conflab daemon log-level debug
conflab daemon logs -f
```

Look for lines tagged `fs_watcher:` or `lsd:sync:`.

If the watcher appears stuck (events not firing), check:

- Permissions on `~/.conflab/` (should be readable and writable by your user).
- Disk space (a full disk can block event delivery).
- macOS FSEvents state (rare, but a daemon restart clears it).

## Related

- [Daemon Overview](/app/help/daemon/overview) -- where the watcher fits in the daemon architecture.
- [Prompt Templates](/app/help/daemon/templates) -- the `.lensmd` format the watcher indexes.
- [The Catalog](/app/help/concepts/catalog) -- how local files relate to the published Catalog.
