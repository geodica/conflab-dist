# conflab v0.3.2

_Released 2026-04-27_

Patch release built on top of v0.3.1. Headline is **Flab Errands end-to-end** -- the PAP-competent agent foundation (ST0094) and the deterministic tool-calling spine (ST0101) that emits announce / working / complete `errand_status` rows around every tool call. Also ships **Stable daemon auth across restart** (ST0100 -- persisted bearers + retired `mgmt_token` exhaust; `conflab daemon restart` no longer kicks Claude Code or the web app off), the **Notifications domain** (ST0103 -- bell + `/app/notifications` + `notify_lens_shared/3`), **Lenses on Circle** (ST0095 -- LSD Circle tab + Share-on-publish + `:lens_imported` Feed), the **Daemon API-key UX rework** (ST0102 -- Cycle relocated to DaemonPanel with plain-language alerts), the **Paginator Highlander cleanup** (ST0104 -- one pagination component across `/app/lsd`), and **ST0105/WP-01..03 daemon agent-auth model rewire** -- `daemon.toml [daemon] handle` is now load-bearing; the daemon refuses to boot if its `api_key` doesn't resolve to `agent+<handle>@conflab.space`. Plus the `:lens_shared` email follow-up, a bell-row avatar fix, and a plugin test reliability fix.

## Added

### Flab Errands end-to-end (ST0094 + ST0101)

The summoned in-flab agent is now genuinely useful when asked to do ordinary things ("^ORAC, summarise this thread", "^ORAC, draft an email to @billm").

**PAP-competent agent foundations (ST0094).** Three incisions across daemon system-prompt assembly + Flab UX:

- **System-prompt scaffolding** -- the daemon assembles a PAP rule recap, an "Available Lenses" section (capped, structured, starred-then-recent-then-alphabetical), and Errand-shaped response scaffolding ("I will do X; here's the plan; ack before acting on destructive ops") for every agent participant in a Flab.
- **`availableLensesForActor` GraphQL** -- new admin query the daemon calls during system-prompt assembly. N-cap (default 20) with deterministic ordering. The agent now knows the user's library exists.
- **Errand status UX** -- `ConflabWeb.Components.ErrandStatus` renders four phase rows in the Flab message stream: announce (agent states intent), working (mid-flight, progress dots), awaiting (destructive op gated; queued for a follow-on ST), complete (result payload, optional Run preview embed). `Message.send_message` accepts an `:event` payload; `FlabLive` dispatches `event["type"] == "errand_status"` messages to the badge component.

**Deterministic tool-calling spine (ST0101).** The emission half of the Errand UX:

- **Provider trait + Claude tool-use wiring** -- `provider::send_message` now formats `tools` request blocks for the Anthropic API and parses `tool_use` + `text` content blocks out of responses. The daemon's reasoning loop (formerly `&[]` empty tools at `main.rs:1029`) iterates: LLM -> if `tool_use`, dispatch to MCP tool registry, feed result back, iterate; bounded by 10 tool-call iterations and a 120s wall-clock deadline.
- **`run_lens` ships first.** Other tools layer in behind the same emission spine, each WP-sized as it lands. Agents can now call `run_lens` from their own reasoning loop and the user sees announce -> working -> complete rows in real time.
- **Server-side emission, LLM-supplied rationale.** The daemon emits `errand_status` deterministically; the rationale string is the LLM's assistant-message prose that preceded the tool call. Satisfies PAP Rule 2 ("Announce Before Acting") structurally rather than relying on the LLM to remember to emit the prose. One `errand_status` per tool call (D2 in the design). E2E coverage at `test/conflab_web/live/flab_live_errand_test.exs` posts a flab message, asserts the announce/working/complete rows + final prose response.

PAP Rule 4 (`:awaiting` gate for destructive ops) and Ollama tool-use support are deferred to follow-on STs.

### Stable daemon auth across restart (ST0100)

`conflab daemon restart` is now invisible to all auth clients -- Claude Code's MCP connection, the web-app "Daemon Authentication" page, the `conflab` CLI, and the macOS menubar app all survive the restart with their cached bearers intact. Re-auth happens only on explicit user rotation via `rotateBearers`.

- **`issued_bearers` SQLite table** -- new schema (id, token, name, created_at, expires_at NULL, revoked_at NULL). Every bearer issue site (`auth_handler`, `oauth_token`, `/authorize?redirect=`) writes a row. Daemon loads non-revoked, non-expired bearers into `active_tokens` on boot. Bearer validation logic unchanged (membership check against `active_tokens`).
- **CLI `/auth + password` migration** -- the `conflab` CLI now reads `[management].password` from `daemon.toml`, calls `/auth` to obtain a bearer, uses that bearer against the GraphQL API. Deletes `read_mgmt_token()` from the CLI, deletes `generate_mgmt_token()` from the daemon, deletes `~/.config/conflab/mgmt_token` file emission entirely. The mgmt_token boot-time exhaust file is retired -- it was a workaround for a problem the password-plus-`/auth` bearer flow already solves.
- **`rotateBearers` mutation + CLI** -- single mutation that invalidates all persisted bearers (sets `revoked_at = now()` on every row) and clears `active_tokens` in memory. CLI `conflab daemon rotate-bearers` is a thin client. Post-rotation, clients hit 401 and re-auth via their existing flow (PKCE for Claude Code, password+/auth for our tools).
- **Bearer TTL config-driven** -- `[management] bearer_ttl_seconds` in `daemon.toml`, `Option<u64>`. Absent / `None` -> infinite TTL (dev-friendly default). Positive value -> `expires_at = created_at + bearer_ttl_seconds` on every issue.
- **Bridge secret confirmed legitimate** -- WP-03 audit clarified that `~/.conflab/bridge.secret` is daemon-to-menubar IPC for Lua AppleScript dispatch + the OS file/folder picker. Not retired.

### Notifications domain (ST0103)

`Conflab.Notifications` lands as a first-class Ash domain. User-facing event records ("someone shared a Lens with you") have a home; the bell icon and `/app/notifications` LiveView surface them.

- **Resource + domain + migration** -- Ash resource `Notification` with `:kind` enum, `recipient_id`, `actor_id`, polymorphic `subject_type` + `subject_id`, open `:map` payload, `read_at :utc_datetime_usec` nullable. Per-recipient PubSub on topic `"notifications:user:#{recipient_id}"` for `:create` + `:update`.
- **Actions + code interfaces** -- `list_inbox` (paginated, recipient-scoped, newest-first), `unread_count` aggregate, `mark_read`, `mark_all_read` (both atomic).
- **Per-kind helpers** -- `notify_lens_shared/3` is the first; pattern documented in the domain moduledoc adjacent to each helper. Ash `:create` is not exposed as a code interface to consumers outside the domain module -- per-kind helpers are the only entry points. Self-notification short-circuit at the helper layer.
- **Bell + page** -- bell-icon component in the `/app` layout header with live-updating unread badge; `/app/notifications` LiveView with stream-based inbox, kind-specific row renderer, click-to-subject navigation, "Mark all read" affordance. Empty state. PubSub-backed live updates within one round-trip.
- **`bell-row avatar` fix** -- a stale-avatar regression on the notifications row when the actor's avatar URL was `nil` is fixed to fall back to the initials-based placeholder (commit `90ceb8ab`).

### Lenses on Circle (ST0095)

Three additive incisions surface what the actor's social graph is actually using inside the catalog:

- **WP-01 LSD Circle tab** -- new `/app/lsd?:tab=circle` lists catalog entries imported by active Friendships of the actor. Deduped, annotated with "N friends imported" plus an avatar strip. Reuses `EntryCard`. Backed by a new `:by_friendship_imports` read on `Catalog.UserLibraryEntry`.
- **WP-02 Share-in-Circle modal** -- on successful Lens publish, a multi-select friend picker dispatches `Conflab.Notifications.Notification` records with `kind: :lens_share` (calls `Notifications.notify_lens_shared/3`). Optional email via `RuntimeConfig.notification.lens_share.email`. 20/day rate limit.
- **WP-03 `:lens_imported` Feed event kind** -- fifth event kind on `/app/circle`. `Social.list_circle_feed/1` extended with a `UserLibraryEntry` aggregator branch; `FeedItem` verb mapping for "imported".
- **`:lens_shared` email follow-up** -- email channel for the `:lens_shared` notification (commit `86f2d3ad`). Renders with the actor's display name + entry title + direct link; respects per-user notification preferences once they exist.

### Daemon API-key UX rework (ST0102)

Cycle API Key is now a daemon-lifecycle action where users expect it.

- **Relocated** -- moved from `AuthPanelView` (per-profile detail pane) to `DaemonPanelView` (alongside Restart / View Logs). The action is daemon-scoped (writes daemon.toml, requires daemon restart), not profile-scoped.
- **Plain-language alerts** -- the three alerts (confirm, success, failure) explain the active-CLI-profile -> daemon.toml -> running-daemon flow in plain language. Users now understand WHY a restart is needed (the daemon has the old token in memory). The success alert's "Restart Daemon" button is the default action.
- **Auth panel keeps Logout** -- profile-scoped Logout stays on the Auth panel; only the API-key cycle moves.
- **UI tests** -- regression coverage for the button's new home + new copy.

### Paginator Highlander cleanup (ST0104)

`/app/lsd`'s three paginated tabs -- Browse, Themes, Library -- now use the same `ConflabWeb.Components.Paginator` component as `CircleLive`, `NotificationsLive`, and `admin/InvitesLive`. The legacy `ConflabWeb.Components.CatalogComponents.pagination/1` (Prev / "Page N of M" / Next) is deleted. One pagination component in the web tree, used everywhere a list paginates.

- 5-page sliding window, no ellipsis, First / Prev / numbered / Next / Last + Go form with Enter commit.
- The Circle inner tab on CatalogLive (`@circle_cards`) is still a flat list; pagination there is deferred (separate concern).

## Changed

### ST0105/WP-01..03 -- Daemon agent-auth model rewire

`daemon.toml [daemon] handle` is now **load-bearing**. Before this release the field was cosmetic; nothing in the auth chain validated that the api_key resolved to the agent named by handle. The daemon authenticated as whoever owned the api_key. A test sandbox-escape on 2026-04-17 leaked `user_2@example.com` into the dev DB; subsequent Cycle API Key flows from rhadamanth.lan minted local-kind keys against the user_2 session in the user's browser, so the daemon thought it was ORAC but was actually authenticating as user_2 (in zero flabs -> `listFlabs { results }` returned `[]` -> doctor's "no flabs connected" check failed).

Three v0.3.2 incisions close the hijack window:

- **WP-01 Boot validation** (`native/daemon/src/main.rs:288-307`). After the daemon's `currentUser` query, the new `conflabd::identity::validate_handle_identity/2` helper compares the email's local-part to `agent+<handle>` (case-insensitive). Refusal-to-boot on mismatch with a `BootError::HandleIdentityMismatch` carrying the expected vs actual emails and a recommended `conflab daemon token cycle` command. Local-part-only validation (not full email): the daemon does not hardcode a domain -- `daemon.toml [server].url` already pins which conflabc the daemon talks to, and conflabc is the source of truth for which user owns the api_key, so trust the domain it returns. Empty handle (legacy daemon.toml) refuses to boot with a "missing handle" error pointing at `daemon init`.
- **WP-02 Cycle + init mint flows** (`lib/conflab_web/live/cycle_daemon_token_live.ex`, `native/cli/src/daemon_cmd.rs`). New `Conflab.Accounts.cycle_or_register_agent_key_for_owner/3` code interface, backed by the existing `Conflab.Accounts.AgentOwnership.Actions.ProvisionCliKey` primitive. Both `daemon init` (CLI) and `CycleDaemonTokenLive` (web) now resolve `handle` -> `agent+<handle>@<domain>` -> User row -> agent_id, verify the owner owns the agent (via `Conflab.Accounts.AgentOwnership`), and provision an api_key whose `user_id == agent.id` (not the owner's). Cycle URL contract is now `/app/daemon/token/cycle?state=<N>&port=<P>&hostname=<H>&handle=<H>`. Older clients that don't pass handle see an explicit error explaining the missing parameter. The legacy `cycle_or_register_host_token_for_user/2` is deleted (boy scout cleanup; pre-release; no third parties). `daemon init` no longer copies the CLI profile's api_key into daemon.toml -- that path was the original sin.
- **WP-03 Doctor identity check** (`native/cli/src/daemon_cmd.rs:1020-1050`). New "Daemon identity" check inserted between "API key" and "WebSocket". Resolves the daemon's api_key to a user via the daemon's mgmt API, compares email's local-part to `agent+<handle>`, passes on match with `✓ Daemon identity <email> (agent: <handle>)`, fails with a clear remediation hint on mismatch. The diagnosis surfaces FIRST -- before the downstream "Connected flabs" symptom that previously masked the auth-model bug as a content problem.

WP-04 (sandbox-escape audit -- the test path that wrote user_2 to the dev DB and the 19 orphan dev-tree conflabd processes that accumulated 2026-04-26) and WP-05 (one-shot generator-user cleanup) stay NOT-STARTED for v0.4.0+.

### Plugin test reliability

`plugin::process::tests::process_exit_detected_as_crash` flaked under heavy parallel test load (the 2s plugin init+handshake timeout was too tight under contention). Bumped to 5s. Boy scout fix; the test now passes consistently.

## Fixed

- Bell-row avatar regression when actor's avatar URL is `nil` (falls back to initials-based placeholder).
- `plugin::process::tests::process_exit_detected_as_crash` flake under parallel test load (timeout 2s -> 5s).
- Daemon's "no flabs connected" symptom on cycle hijack now surfaces as a clear identity-mismatch diagnostic at boot and at doctor (see ST0105/WP-01..03 above).

## Security

### Daemon agent-auth model (ST0105/WP-01..03)

- **Daemon refuses to boot if `api_key` doesn't resolve to `agent+<handle>@<domain>`.** Closes the hijack class where a leaked human-user api_key in `daemon.toml` granted the daemon that user's identity (a leaked test user `user_2@example.com` survived in the dev DB from 2026-04-17 onward and was hijacked into the daemon's identity by the Cycle flow throughout 2026-04-25/26).
- **Cycle API Key now mints for the agent, not the human in the LV session.** Ownership-verified via `Conflab.Accounts.AgentOwnership` -- the human in the LV session must be a registered owner of the agent named by `handle`, otherwise the cycle is refused with a clear diagnostic.
- **`daemon doctor` surfaces identity mismatch first.** Previously the auth-model bug hid behind the downstream "no flabs connected" symptom. The new check sits between "API key" and "WebSocket" so the diagnosis surfaces before the downstream consequences.

### Other

- **Persisted bearers (ST0100)** -- `issued_bearers` rows survive restart; `rotateBearers` is the single canonical revocation entry point.

## Install / Upgrade

Four channels, all coexisting:

```bash
# Signed macOS installer (menubar app + CLI + daemon, arm64)
open https://conflab.space/download/mac

# Homebrew cask (wraps the installer)
brew install --cask geodica/conflab/conflab

# Homebrew formula (CLI + daemon only)
brew install geodica/conflab/conflab

# Shell script (CLI; --with-app runs the pkg on macOS arm64)
curl -fsSL https://conflab.space/install.sh | bash
curl -fsSL https://conflab.space/install.sh | bash -s -- --with-app
```

Upgrading from v0.3.1: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading, restart the daemon:

```bash
conflab daemon restart
```

The daemon runs an SQLite migration on first start after upgrade for the `issued_bearers` table (ST0100/WP-01). Previously-issued bearers held only in memory are lost on the upgrade restart -- clients re-auth once via their existing flow (PKCE for Claude Code, password+/auth for the CLI, click-approve for the web tab); subsequent restarts are invisible.

**Daemon agent-auth migration (ST0105).** If your daemon has been authenticating with a human-user api_key in `daemon.toml [server].api_key`, the daemon under v0.3.2 will refuse to boot with a `HandleIdentityMismatch` error. Recovery: cycle a fresh agent key via the macOS app's "Cycle API Key" button (or `conflab daemon token cycle`). The cycle now mints a key for `agent+<handle>@<domain>`, not for your user. The cycle URL gained a required `handle=<H>` query-string param; older `daemon` CLIs that don't pass it see a clear error.

A new Ecto migration ships in v0.3.2 (Notifications domain, ST0103) -- ran via `mix ash.migrate` on the conflabc side; not user-facing.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
