# conflab v0.5.6

_Released 2026-05-18_

Hotfix release closing eight defects in the install / onboarding / agent-identity pipeline surfaced by chris.perfect@gmail.com's v0.5.5 cold-smoke. A returning user with an existing agent who reinstalls on a wiped machine now lands on their existing handle in one pass instead of looping through hostname-default -> quota_exceeded with no in-wizard recovery.

All eight WPs of ST0118 land in this patch. No wire-protocol changes; no behavioural changes for first-install users on a fresh account.

## Fixed (ST0118)

### WP-01 -- Setup wizard pre-fills handle from server-side agents

The macOS Setup wizard now calls `listOwnedAgents` against conflab.space after sign-in and uses the result to drive the Agent step. Zero owned agents preserves the existing hostname-derived suggestion. One owned agent pre-fills the field with that handle and shows a "Re-using your existing agent" note. Two or more owned agents render a radio picker plus a "Register new" option. Also fixes a latent bug where the wizard skipped the `.agent` step entirely after sign-in (jumping straight to `.models`) -- the Agent step was unreachable in the v0.5.5 wizard regardless of what the user wanted.

- New `OwnedAgent` model + `APIClient.fetchOwnedAgents(serverURL:apiKey:)` mirroring the existing `verifyAuth` cloud-target pattern.
- `AgentStepView` refactored to a 0/1/N rendering switch driven by `[OwnedAgent]` + optional `suggestedHandle`. Public accessor (`currentHandle`) is the single contract regardless of mode -- AgentHandleDefault sanitisation everywhere.
- `SetupWizardWindowController.handleAuthSuccess` now renders `.agent` (the bug fix) plus dispatches a best-effort `fetchOwnedAgents` Task; failure falls through to the fresh-install hostname-derived path.

### WP-02 -- Quota-exceeded fallback with existing-handle picker

`cycle_daemon_token_live`'s `:quota_exceeded` branch now lists the owner's existing handles inline in the user-facing detail AND threads them through a new `existing_handles=A,B,C` URL param on the loopback redirect. The Rust loopback parser captures the list in `LoopbackOutcome::CycleError`. `daemon_cmd` appends a machine-readable `[conflab-error: quota_exceeded; existing_handles=...]` tag to the CLI's Err return. The macOS wizard's `showFailure` parses this tag and routes the user back to the `.agent` step (with the picker pre-populated from the merged server + CLI handle list) instead of dumping them at `.connect` and forcing a re-auth.

- New `DaemonConnect.loopback_error_url/5` accepts `opts` with `:existing_handles`.
- `Conflab.Accounts.list_my_agents` already exposed; the LV now loads `:agent` and surfaces `display_name` per handle.
- `nonisolated static` `parseQuotaTag` + `mergeHandles` helpers on `SetupWizardWindowController` keep the Swift parser unit-testable.

### WP-03 -- Daemon identity error names both recovery paths

`native/daemon/src/identity.rs::validate_handle_identity` previously recommended `conflab daemon token cycle --agent <handle>` for any mismatch -- which, if `<handle>` was not yet registered server-side, would hit the auto-provision branch and could fail with quota_exceeded (chris's loop). The diagnostic now acknowledges both sub-cases: agent owned by a different user (token-cycle is correct) and agent not yet registered (Setup wizard / `conflab install setup --interactive`). Also points to `conflab agent list` for owner-side discovery.

### WP-04 -- Website agent-delete walks participant rows

The `/app/account/agents/<id>` Delete button used to fail with an Ecto FK constraint when the agent had any `participants` row (chris's CALCIFER had two), and the LiveView swallowed the underlying `Ash.Error.Unknown.UnknownError` into a generic "Failed to delete agent." flash with no detail (No-Silent-Errors violation, `IN-AG-NO-SILENT-001`).

- `Conflab.Accounts.destroy_agent` now sweeps every `Conflab.Collaboration.Participant` row referencing the agent user before deleting api_keys / ownership / user. The sweep is transactional and uses `authorize?: false` from within the already-verified-owner context.
- New `:destroy` action on Participant gated to admin/superadmin actors (regular users still use the `:leave` soft-delete).
- `ConflabWeb.AgentDetailLive.handle_event("delete_agent", ...)` surfaces the underlying reason in the flash + logs it, replacing the swallow-and-flash pattern.

### WP-05 -- Cold-smoke gate tightening for returning-user reinstall

`feedback_real_user_cold_smoke` memory updated with a new mandatory pre-tag scenario: a real prod test account with at least one owned agent must reinstall against the existing account (uninstall --nuke-data + reinstall) and complete the wizard without a quota error AND see the existing handle on the All-set step.

### WP-06 -- DoneStepView drops the hardcoded "CONFLAB" fallback

`DoneStepView` previously fell back silently to the literal string `"CONFLAB"` when the wizard's bundle had a nil/empty `agentHandle`. `^CONFLAB` happens to be a real registered agent (owned by hello+admin@matthewsinclair.com) so the bug was both invisible and dangerously plausible -- chris saw `^CONFLAB` on his All-set screen while the daemon was actually pinned to `^PROSPERO`.

- `DoneStepView.init(handle: String)` is now non-optional with a `precondition(!handle.isEmpty, ...)`. The "All set" view fails loud on a missing handle instead of substituting a wrong-but-plausible string.
- `SetupWizardWindowController.apply` re-reads `daemon.toml`'s `[daemon].handle` via `SetupRunner.dumpCurrent` after apply so the All-set step displays the handle the daemon actually pinned to, not the in-memory bundle copy.
- `renderDone` defensively surfaces a clear error (rather than a fake handle) on the unreachable nil/empty path.

### WP-07 -- daemon doctor "Connected flabs" is informational

A fresh install with zero flab memberships is the expected state, not an error -- the user has just installed and hasn't been invited to a flab yet. Pre-WP-07 the doctor rendered this as a red `✗ Connected flabs no flabs connected` and incremented the failure count, which inflated the failure total on every fresh install and misled chris into thinking something was broken. The zero-flabs case is now an `i` (informational) row that does not count toward `failures`. New `util::info` helper added for any future "expected empty" doctor rows.

### WP-08 -- Install-path parity audit (.pkg vs brew vs curl-shell)

New "Appendix A: Install-Path Parity Audit" section in `priv/docs/getting-started/installation-guide.md`. Three-column side-by-side matrix covers files written, bundles, LaunchAgent state, CA Trust handling, shell-rc changes, keychain entries, first-run behaviour. Plus the 3x3 cross-install upgrade matrix and a checklist of known gotchas (`brew unlink conflab`, pkg PATH order, `conflab uninstall` vs `brew uninstall` reach). The canonical end-state defines a single Highlander spec the three install paths conform to.

## Tests + verification

- Elixir: 2301 tests pass (full suite, +4 new -- agent-delete cascade reproducer, daemon_connect opts, cycle_daemon_token_live existing_handles).
- Rust CLI: 267 tests pass (+3 -- loopback existing_handles parse + dispatch tests).
- Rust daemon: 1130 tests pass (+1 -- identity error covers both recovery paths).
- Swift: 291 tests pass (+10 -- AgentStepView 0/1/N modes, SetupWizardQuotaTag parse + merge handlers, DoneStepView non-optional init).
- Critic-elixir / critic-rust / critic-swift: zero critical findings on the diff; warnings are coordinator-fatness in `SetupWizardWindowController.apply` and `showFailure` (defensible for a hotfix; see follow-ups below).

## Migration notes

No schema changes. No new database migrations. No conflab CLI / daemon / macOS-app wire-protocol changes. Existing daemon configurations on v0.5.5 continue to work; the wizard's new behaviour kicks in only on the next Setup-wizard re-run or fresh install.

## Standing landmines (unchanged from v0.5.5)

- `brew unlink conflab` after `brew update` if local CLI builds stop reflecting `cargo build`.
- `CONFLAB_DISABLE_KEYCHAIN=1` for any test harness spawning `conflabd` under tmpdir HOME.
- `~/.conflab/db` is a separate git repo.
- Tests that touch `~/.config/conflab/` MUST use the `TempHome` guard + `#[serial_test::file_serial(home)]`.
- `scripts/flysql` runs ONE statement per invocation; no BEGIN/COMMIT bundling.

## Deferred to v0.5.7+ / v0.6.x

- **Test fixture Highlander (`IN-EX-TEST-007`).** `agent + ownership` fixture is now copied across three test files plus `Harness.join_agent`. Extract `agent_with_ownership_for_owner/2` into `test/support/` in a follow-up PR.
- **`SetupWizardWindowController.apply` / `showFailure` extract** (`IN-AG-THIN-COORD-001`). Both methods accumulated multi-step orchestration during this hotfix. Hoist the apply-then-canonicalise sequence into `SetupRunner.applyAndCanonicalise(bundle:)`; extract the showFailure route decision into a small dispatch.
- **`[conflab-error: ...]` tag format Highlander** (`IN-AG-HIGHLANDER-001`). Producer in `daemon_cmd.rs:880`; parser in `SetupWizardWindowController.swift`. Extract a Rust constant or `format_cycle_error_tag` helper so the wire contract has one place to read.
- **Structured CLI errors** (`IN-RS-CODE-004`). `run_token_cycle` returns `Result<_, String>` with embedded discriminants. A `thiserror` `CycleError { reason, detail, existing_handles }` variant flattened to a String only at the final exit boundary would let consumers branch without substring parsing.
- **Messages.sender_participant_id cascade.** Hard-deleting a participant fails if any message references it. Chris's case had no messages so this didn't bite, but a real returning user with chat history will hit it. Either an `on_delete: :delete_all` migration for `messages.sender_participant_id` or a sweep in `destroy_agent_participants` for messages. Surface as actionable error meanwhile (already done via WP-04's surfaced reason).
