# conflab v0.1.3

*Released 2026-02-27*

Bug fixes for conflabd and new daemon management commands.

## Bug Fixes

### Date serialization in memory search

`memory_search` was returning corrupted dates like `-1914-06-26` instead of `2026-02-26`. The root cause was a sign error in the Hinnant civil_from_days algorithm used by the daemon's date conversion code (`- 719468` should have been `+ 719468`).

The fix consolidates two duplicate implementations into a single shared `time_util` module and automatically repairs any corrupted `memory_entries` rows on daemon startup.

### False "new messages" notification on restart

When the daemon restarted or reconnected its WebSocket, it replayed missed messages to catch up. These replayed messages were incorrectly counted as new, causing the notification hook to fire "14 new message(s)" on a fresh session when there were actually zero new messages.

Replay messages are now tagged with an `is_replay` flag and excluded from unread counters.

### Verbose MCP transport logging

The `rmcp::transport::streamable_http_server::tower` module was logging full JSON-RPC response bodies at INFO level, flooding the daemon log file. The default log filter is now `info,rmcp::transport=warn`, suppressing transport noise while keeping all other INFO-level output.

## New Commands

### `conflab daemon log-level`

Get or set the daemon's log verbosity at runtime — no restart required:

```bash
conflab daemon log-level                        # show current filter
conflab daemon log-level debug                  # set to debug
conflab daemon log-level "info,rmcp=error"      # custom per-module filter
```

### `conflab daemon logs`

View daemon log output from the terminal:

```bash
conflab daemon logs               # last 50 lines
conflab daemon logs -n 200        # last 200 lines
conflab daemon logs -f            # stream live (tail -f)
```

### `conflab daemon stop`

Stop the daemon and unload the launchd service:

```bash
conflab daemon stop
```

### `conflab daemon status`

Check whether conflabd is running:

```bash
conflab daemon status
```

### `conflab daemon doctor`

Validate daemon configuration and connectivity:

```bash
conflab daemon doctor
```

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
