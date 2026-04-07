# conflab v0.1.9

_Released 2026-04-03_

HTTPS browser bridge, MCP tool completeness, Prompts 2.0, and Lens architecture.

## Added

- **conflabd HTTPS** -- daemon serves dual HTTPS (port 46327) + HTTP (port 46329) when TLS certs exist. Fixes Safari mixed-content block from `https://conflab.space`. TLS certs generated via `rcgen` (pure Rust, no OpenSSL). CA trust installed via native macOS admin dialog (`osascript "with administrator privileges"`). Chrome trusts system keychain automatically; Safari requires one-time cert acceptance.
- **CLI cert management** -- `conflab daemon cert generate` creates CA + leaf cert in `~/.config/conflab/tls/`. `cert install` adds CA to system keychain. `cert status` reports state. `cert regenerate` replaces certs.
- **8 new MCP tools** (25 total) -- daemon lifecycle: `daemon_status`, `daemon_stop`, `daemon_doctor`, `set_log_level`. App lifecycle: `app_start`, `app_stop`, `app_status`. Flab: `join_flab`. All registered in policy engine with appropriate capabilities and risk levels.
- **MCP over HTTP fallback** -- `.mcp.json` uses HTTP on port 46329 since Claude Code's Node.js SDK doesn't trust macOS system keychain certs.
- **Startup status dump** -- daemon logs identity, server, flabs, agents, management config (host, port, TLS), all 25 MCP tool names, plugins, and storage paths as separate structured log lines on startup.
- **macOS app HTTPS setup** -- Settings > General shows HTTPS status row. "Setup..." button generates certs + installs CA trust + restarts daemon in one click.
- **Prompts 2.0** (ST0060) -- unified prompts page at `/app/prompts` with tabbed Prompts/Runs view, directory browser, prompt tile grid with expand/collapse, CodeMirror editor modal, implicit LLM call with inline active run display.
- **Lens architecture** -- architecture doc 12 (The Lens) and research paper 06 (Promptable Problems) defining Shape as first-class artifact, auto-prompt generation, three-view model (Form/Notebook/Source).
- **.lensmd migration** (ST0063) -- `.cp.md` files renamed to `.lensmd` across codebase and daemon scanner.

## Changed

- **rmcp 0.16 → 1.3** -- MCP server upgraded. `json_response: true` returns `application/json` instead of SSE. Accept header middleware normalizes `Accept: */*` to the required value. HTML fallback handler for `.well-known/oauth-protected-resource` 404s.
- **DaemonBridge protocol cascade** -- JS hook tries HTTPS (46327) → HTTP (46327) → HTTP fallback (46329). Queries arriving before protocol detection are queued and replayed on resolve (fixes empty prompts list on page load).
- **LiveDaemonStatus** -- server-side health check tries HTTPS first with `ssl: [{:verify, :verify_none}]`, falls back to HTTP.
- **DaemonLive** -- removed hardcoded `@daemon_url`. URL resolved dynamically by JS detection, passed back via `daemon-health` event.
- **CLI HTTPS-aware** -- `resolve_mgmt_url()` returns `https://` when certs exist. `http_client()` uses `danger_accept_invalid_certs(true)` for localhost. reqwest switched to `rustls-tls` backend.
- **macOS app HTTPS-aware** -- `ServerTarget.daemon()` detects scheme from `~/.config/conflab/tls/cert.pem` existence. `LocalhostTrustDelegate` (URLSessionDelegate) loads CA PEM, converts to DER, sets as trust anchor for 127.0.0.1 connections.
- **Policy engine** -- `daemon:lifecycle` capability added to standard profile. New tools registered with appropriate capabilities (`daemon:introspect`, `daemon:lifecycle`, `conflab:flab:manage`).
- **Log noise suppression** -- default log filter includes `rustls::msgs::handshake=error` to suppress harmless SNI-over-IP warnings.
- **tokio-rustls ring backend** -- switched from aws-lc-rs to ring crypto backend for Linux CI compatibility.
- **conflabd library dependency** -- CLI now depends on `conflabd` lib crate for shared TLS module (Highlander Rule).

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```

After upgrading, enable HTTPS for the browser bridge:

```bash
conflab daemon cert install    # generates certs + installs CA trust
conflab daemon stop && conflab daemon start
```
