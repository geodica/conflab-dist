# conflab v0.4.2

_Released 2026-05-06_

Patch release on top of v0.4.1. Headline is **ST0112/WP-01 -- First-Run Identity Provisioning (server side)**: the cycle LiveView now auto-provisions a fresh agent when an Alice-style first install hits a never-seen handle, instead of erroring with "no agent ^X exists" and leaving the daemon crash-looping. Quota is now role-based and server-side -- `:admin` and `:superadmin` bypass entirely; `:user` is gated by a single `RuntimeConfig` integer (default 1, operator-tunable without a deploy). This release is staging-prep for the macOS-side bind step that ships next: WP-02 (CLI `apply_bundle` binds daemon as `^CONFLAB`), WP-03 (Setup wizard Done step surfaces the handle), and WP-04 (docs sweep) land together in the following release. **No CLI, daemon, or macOS app behaviour changes in v0.4.2.** The .pkg / brew artifacts re-cut with the new version stamp but are functionally identical to v0.4.1 -- upgrading the macOS app is not necessary for end users until the WP-02/03 release lands. No breaking changes; no Elixir migrations.

## Added

### ST0112/WP-01 -- conflab.space cycle endpoint auto-provisions on absent agent

Server-side foundation (commit `79cf9773`):

- **`Conflab.Accounts.auto_provision_eligible/2`** -- read-only eligibility helper. Reserved-handles list `~w(ADMIN ROOT SYSTEM DAEMON OWNER)`; role-based quota (see Changed); global handle availability via `get_by_email`. Charset enforced upstream by `ConflabWeb.DaemonConnect.validate_handle/1`; not duplicated.
- **`Conflab.Accounts.auto_provision_and_register_for_owner/3`** -- atomic helper. Composes `register_agent` + `create_ownership` + inline `create_api_key` (canonical `"macOS app, <hostname>, <iso-date>"` label) inside `Conflab.Repo.transaction`. `return_notifications?: true` threaded through every Ash call; notifications accumulated and dispatched after commit via `dispatch_provision_notifications/1`. Mirrors the existing `lsd.ex` Highlander pattern. Zero `:missed_notifications` warnings.
- **`@reserved_agent_handles`** and **`@agent_email_domain`** lifted to module top in `accounts.ex`.

LiveView side (commit `4e6449d3`):

- **`/app/daemon/token/cycle` LiveView mount-path** routes unknown handles through `Accounts.auto_provision_eligible/2`. New `:auto_provision` state with confirm card titled "Create agent ^X and bind it to this Mac?". Card body explains the side effects: registers `^<handle>` to the user's account, mints the first key for `<hostname>`, written to `~/.config/conflab/daemon.toml` automatically.
- **`confirm_cycle` event handler** is now pattern-matched on `state`. The `:auto_provision` head calls `auto_provision_and_register_for_owner/3` and 302s to the loopback URL with the freshly minted token. The existing rotation/register paths are unchanged.
- **Test coverage**: `test/conflab/accounts/auto_provision_test.exs` (eligibility matrix + atomic helper + role bypass) and `test/conflab_web/live/cycle_daemon_token_live_test.exs` (success render, success-then-confirm with token round-trip, reserved error, non-agent-impostor handle-taken corner case, `:user`-quota-exceeded, admin role bypass, regression on existing rotation flow).

## Changed

- **Agent quota is now role-based, server-side.** `Conflab.Accounts.check_under_quota/1` pattern-matches on user role: `:admin` and `:superadmin` bypass the quota entirely (unlimited); `:user` is gated by `Conflab.RuntimeConfig.get_integer("agent.quota_per_user", 1)`. Default flipped from 10 to 1; the `RuntimeConfig` knob remains the operator override (admin LV at `/admin/runtime-settings`, no deploy required). Per-user override deferred -- would land as a `User.agent_quota_override` attribute or `:user_group` taxonomy if a real case appears.

## Migration notes

- **No breaking changes.** No Elixir migrations; no daemon-side schema migrations; no behavioural changes to existing CLI / daemon / macOS verbs.
- **Server-side change only.** The .pkg / brew artifacts re-cut with the new version stamp but are functionally identical to v0.4.1. End users do not need to upgrade until the WP-02/03 release lands.
- **First-install flow on conflab.space changes**, but only matters for users who hit the cycle LiveView with a handle that does not yet exist for them. Old behaviour: `:error` state with "no agent ^X exists" copy. New behaviour: `:auto_provision` confirm card, click-through creates the agent + ownership + key in one atomic transaction.
- **Operators who relied on the global agent-quota default of 10** should explicitly set `agent.quota_per_user` via `/admin/runtime-settings` if they want to preserve that ceiling for `:user` accounts; the new default is 1.

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

Upgrading from v0.4.1: optional. The CLI / daemon / macOS app behaviour is unchanged. If you do upgrade:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # pick up the re-stamped daemon binary
```

The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
