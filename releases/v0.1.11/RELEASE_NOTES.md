# conflab v0.1.11

_Released 2026-04-07_

Daemon API authentication, three zero-friction auth surfaces, policy management UI, and CORS hardening.

## Added

- **Daemon API authentication** (ST0068) -- shared-secret auth on the conflabd management API. Password auto-generated on first start, stored in daemon.toml and macOS Keychain. All endpoints except health check require a Bearer token. CORS locked to conflab.space + localhost.
- **Three auth surfaces** -- zero-friction authentication for all users:
  - **Menubar app**: "Open Conflab" (Cmd+O) reads password from Keychain, authenticates with daemon, opens browser pre-authenticated.
  - **Browser redirect**: OAuth-style `/authorize` page on daemon. Click Approve, redirected back with token. Open-redirect protection.
  - **CLI**: `conflab daemon auth` prints a session token, `--copy` copies to clipboard. `conflab daemon password` shows the raw password.
- **MCP auto-auth** -- boot token written to `~/.config/conflab/mgmt_token` at startup. Claude Code authenticates automatically.
- **Password prompt UI** -- web app shows password prompt when daemon requires auth. "Authorize via daemon" link for browser redirect flow.
- **Daemon settings: policy management** (ST0066/WP-03) -- view and edit global + per-agent tool access policies from the web app Settings tab. `policyConfig` query, 3 new mutations.
- **Daemon settings: source editor** (ST0066/WP-02) -- raw TOML editing for daemon.toml and agents.toml. Log level editing with presets.
- **`daemon_graphql()` Highlander** -- single code path for all CLI-to-daemon GraphQL calls with automatic token injection.

## Security

- Management API no longer accepts unauthenticated requests (was: permissive CORS, no auth).
- CORS restricted to explicit origin allowlist (conflab.space, localhost:4000, localhost:4001).
- Open-redirect protection on `/authorize` endpoint.
- Brute-force protection: 1-second delay on failed auth attempts.
- 11 new daemon tests covering auth, CORS, and authorize flows.

## Changed

- CLI `conflab daemon stop` and `conflab run` authenticate via boot token.
- Daemon dashboard (`/`) is public (read-only status page).
- DaemonBridge JS hook sends Authorization header on all GraphQL requests.

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```

After upgrading, restart conflabd. A new management password will be auto-generated on first start:

```bash
conflab daemon stop && conflab daemon start
```
