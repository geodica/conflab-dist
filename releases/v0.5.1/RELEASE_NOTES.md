# conflab v0.5.1

_Released 2026-05-11_

Patch release on top of v0.5.0. Headlines: **ST0108 -- Fat LiveView remediation closes end-to-end** across four LiveViews; **Bug 8 -- wizard cycle-error fast-fail** lands in six parts (the deferred terminal-error path from v0.5.0's wizard `Applying...` spinner); **daemon-status indicator Highlander** unifies the cross-page red/green divergence that surfaced post-deploy (Dashboard going red while Lenses/Shapes stayed green); **wizard agent-name prompt** replaces the fixed `^CONFLAB` default with a hostname-derived suggestion per machine. Plus the deferred Bug 7 (agent UI Delete partial-destroys) closure, post-wizard menubar staleness fix (three parts: dynamic TLS scheme + daemon readiness gate + auth-config refresh), brand-link Highlander extraction across app + public layouts, BuildInfo recompile trigger fix so the footer hash updates on commit, Bug 14 (deferred ssh uninstall -60007) via sudo fallback, and Tier 2 -- daemon mgmt password persistence across `daemon init` reruns so browser tabs survive setup re-runs.

## Added

### ST0108 -- LV-slim across four LiveViews

ST0108 closed end-to-end across nine commits. The steel thread retires duplicated logic from `circle_live`, `admin/curation_live`, `catalog_live`, and `lenses_live` into named Highlanders. Outcome by LOC: `catalog_live` 1390 to 1368; `lenses_live` 1440 to 1287; `helpers.ex` 485 to `daemon_ops.ex` 389. 116 new spec-driven tests; full suite green.

- **WP-02 (circle_live reference, `e8b... a245e356`).** Establishes the per-LV split pattern; flat domain placement (anti-pattern: per-LV `Conflab.<Domain>.<LiveView>.Service` namespace); 5-line clause limit + multi-effect-sequence anti-pattern.
- **WP-03 (admin/curation_live, `5d7c0dd1`).** Four extracted Highlanders for the curation workflow.
- **WP-04 (catalog_live, three commits `14f8a549` + `4d2c40a9` + `d73c7921`).** Six simple `Lsd.*` return-handlers wrapped to surface failures; `import_theme` aggregates per-entry failures with railway `with`; `instaflag-entry` routed through `Lsd.instaflag_entry/2`; `saveShape` GraphQL query lifted to `LensesLive.Queries` Highlander; boy-scout closure of eight critic-elixir silent-failure findings.
- **WP-05 (lenses_live three-bucket split, four commits `0e963821` + `a22b0594` + `34c97f7a` + `5b354b59`).** New domain modules: `Conflab.Lenses.Run` (9 pure run-lifecycle helpers), `Conflab.Lenses.PublishParams` (4 pure form-shape helpers), `Lens.serialize_with_source/3` + `update_lens_prose/2` + `update_lens_code_block/3` extracted. New web-ops module: `ConflabWeb.LensesLive.PublishOps` (`publish_and_sync/4` + `apply_publish_result/3`). Rename: `ConflabWeb.LensesLive.Helpers` to `ConflabWeb.LensesLive.DaemonOps` (the residue is push-glue, not pure helpers).
- **WP-06 (verification + ST close-out, `02e75b48`).** critic-elixir clean across all four LVs; mix test green; intent_critic gate green; as-built LOC table in `intent/st/COMPLETED/ST0108/design.md`.

### Tier 2 -- daemon mgmt password persistence

Commit `2bbadcf1`. The mgmt password is auto-generated at daemon startup (`config::resolve_password` writes it back into `daemon.toml` on first use). `daemon init` always overwrites `daemon.toml` without including the password line, so the next daemon start minted a fresh password -- invalidating every bearer that was issued under the old one, including the daemon_tokens that browser tabs hold in localStorage. Browser tab open across a daemon restart returned 401 until the user closed + reopened via menubar.

- **`preserve_existing_mgmt_password/2`** in `daemon_cmd.rs` reads existing `daemon.toml` before write, lifts `[management].password` if present, injects into the freshly-generated content via `toml_edit`. Untouched user flow on first-ever init (no prior file, no password to lift). Idempotent across reruns.
- **Five tests** cover: no prior file (passthrough), prior without password (passthrough), prior with password (preserved + new server data overrides), empty password (ignored), management subsection with host/port preserved alongside lifted password.

### Wizard agent-name prompt (commits `de6f506a` + `f9221814`)

Pre-0.5.1 every wizard cold install bound the daemon to a fixed `^CONFLAB`. Two machines installing Conflab ended up with two daemons sharing one generic identifier -- confusing in flab membership and not aligned with the host-flavoured naming pattern many users were already adopting (`^ORAC` on rhadamanth, etc).

- **Phase A (`de6f506a`) -- hostname-derived default.** New `daemon_cmd::derive_default_agent_handle` takes the local hostname, drops the dotted suffix, uppercases, filters to A-Z 0-9, falls back to `CONFLAB` if hostname resolution fails. `SetupBundle` gains an `agent_handle: Option<String>` field; `apply_full_pipeline` uses the bundle value or derives one. `dump_current_state` reads the existing handle from `daemon.toml` so re-runs hydrate with what's bound, not the hostname.
- **Phase B (`f9221814`) -- macOS wizard UI.** New `AgentStepView` (NSStackView + Auto Layout) inserted between Connect and Models. Default text field shows the hostname-derived suggestion with a live `^<name>` preview line; Review step surfaces the chosen handle; `DoneStepView` displays the actual handle in the Copy button and pasteboard payload (was hardcoded `^CONFLAB`). 12 new Swift tests cover sanitisation + view behaviour.

## Fixed

### Bug 7 -- agent UI Delete partial-destroys

Closed in `6d7ff053` (queued on `main` post-v0.5.0). Agents page Delete row-action was leaving orphan records in two adjacent tables (host keys, api keys) because the destroy action ran a single resource delete without cascading. Switched to a multi-resource transactional destroy with explicit cascades. The Fly IEx prod cleanup snippet from v0.5.0 release notes is no longer needed.

### Bug 8 -- wizard cycle-error fast-fail end-to-end (six parts)

Wizard `Applying...` spinner had no terminal-error transition; when the apply step failed against a server-side cycle error (eg agent quota, handle conflict), the loopback listener waited the full 60-600s timeout instead of short-circuiting. Six commits land the fast-fail end-to-end.

- **Part 1 (`ef90c18e`) -- LV redirects cycle errors to loopback.** `loopback_error_url/4` in `daemon_connect.ex` builds `http://127.0.0.1:<port>/callback?state=<s>&error=<reason>&detail=<text>`. Six error sites in `cycle_daemon_token_live.ex` now redirect instead of silently swallowing the reason.
- **Part 2 (`0e07583b`) -- `LoopbackOutcome::CycleError`.** New variant on the Rust loopback enum carrying `{ reason, detail }`; `ParsedRequest::Error` extended with `detail`; `CYCLE_ERROR_HTML` template surfaces the reason in the browser tab; `run_token_cycle` propagates the detail as the CLI error message. +7 tests.
- **Part 3 (`27e41791`) -- `Lens.parse` fallback logging.** Five fallback `_ -> {:error, ...}` clauses in `lenses_live.ex` + `lenses_live/daemon_ops.ex` now `Logger.warning` before returning so silent parse rejections aren't invisible.
- **Part 4 (`ccc4e41a`) -- `total_pages/2` Highlander.** `circle_live.ex` + `admin/curation_live.ex` private `total_pages/1` duplicated `ConflabWeb.Components.Paginator.total_pages/2` (which `catalog_live.ex` already used). Cross-LV Highlander cleaned up.
- **Part 5 (`2bfda0f8`) -- `Accounts.agent_email_for_handle/1` + `find_agent_by_handle/1` + `verify_owner/2` Highlander.** `cycle_daemon_token_live.ex` carried inline helpers + `@agent_email_domain`. Lifted to `Conflab.Accounts` with explicit error tags.
- **Part 6 (`44eb7e67`) -- catalog page thematic state aggregators.** `catalog_live.ex` `handle_info(:load_catalog, ...)` was 33 lines of state aggregation; now 14 lines delegating to `Lsd.library_state/2`, `Lsd.discovery_state/3`, `Lsd.social_state/1`. Three thematic Highlanders.

### Bug 8 follow-up -- post-wizard menubar staleness (three parts)

Cold-smoke on gyges 2026-05-11 surfaced a chained Bug 8 sequel: after the wizard reached "All set", the menubar dot stayed red and required a manual `conflab app stop && conflab app start` to recover. Three independent root causes; user verdict on the half-fix attempt was direct.

- **Part 1 (`040b9649`) -- `AuthService.refresh()`.** AuthService loaded `config.toml` once at startup and never re-read it; post-wizard the freshly-cycled api_key was on disk but the menubar still held the pre-cycle bearer. New `refresh()` method calls `loadConfig()` + `verifyCurrentAuth()`; `SetupRunner.apply()` invokes it after the wizard's apply phase.
- **Part 2 (`32de9d68`) -- dynamic TLS scheme + `DaemonService.awaitReady()`.** APIClient's `defaultTarget` was a stored property captured at init time -- which was BEFORE the wizard generated `cert.pem`. `ServerTarget.daemon()` correctly checks cert.pem at evaluation time and picks `https` vs `http` accordingly, but APIClient was caching the early-init value forever. Made `defaultTarget` a computed property; bounded-retry `awaitReady(timeoutMs:pollIntervalMs:)` added to DaemonService so `SetupRunner.apply()` Phase 4 waits for the restarted daemon to bind its port before declaring success.
- **Part 3 (`d4d2ce43`) -- header brand spacing + /health timeout bump.** Brand cluster + nav butted against each other on narrow viewports (no explicit gap); the JS hook `/health` probe used `AbortSignal.timeout(2000)` which flagged the daemon red whenever Phoenix LV was busy mounting a route. Bumped to 5000ms; visible >=16px gap restored.

### Brand-link Highlander (two parts)

App layout's brand mark + wordmark and the public layout's were two divergent copies with subtly different flex rules. Stretched window viewports produced visible overdraw on the public homepage (brand image overlapping the right-side nav cluster).

- **Part 1 (`4e77dced`) -- extract `<.brand_link/>` Highlander.** New function component in `ConflabWeb.Layouts` carries the standard `flex items-center gap-2 flex-shrink-0 hover:opacity-80 transition-opacity`. Both `def app/1` and `public.html.heex` now render via the same component.
- **Part 2 (`dc860ed6`) -- public layout structural alignment.** First fix kept the public layout's outer `flex-1 min-w-0` wrapper around brand_link, which let the brand image overflow into the nav cluster. Final fix matched the app layout's `<div class="flex items-center justify-between gap-4 py-3">` exactly. No structural divergence between app and public layouts.

### BuildInfo recompile trigger (`eab712e9`)

Footer build-info captured the git hash via `@external_resource Path.expand("../../.git/HEAD")`, but `.git/HEAD` contains `ref: refs/heads/main` and doesn't change on commits to the same branch -- so the footer hash got stuck on the first commit after a `mix compile`. Added `.git/logs/HEAD` (the reflog) as a second `@external_resource`; that file mutates on every commit so the recompile trigger fires reliably. Future footer hashes update without manual server restart.

### Bug 14 -- ssh uninstall -60007 (`dc8dbd24`)

`conflab uninstall --yes` invoked over ssh returned -60007 (`errAuthorizationInteractionNotAllowed`) from osascript-with-administrator-privileges. Remote login contexts have no reachable WindowServer to mediate the auth dialog, so `osascript` cannot prompt for credentials.

- **`is_ssh_session()`** probes `SSH_CONNECTION`, `SSH_TTY`, `SSH_CLIENT`. Any of the three indicators is sufficient.
- **`run_admin_via_sudo()`** runs the same shell-script payload (rm / pkgutil / etc) via `sudo /bin/sh -c`. ssh always allocates a pty for interactive sessions, so sudo can prompt via the controlling terminal.
- **`run_admin_script()`** is now a thin coordinator: ssh-detect, route. Terminal.app and the macOS Settings Reset panel keep the osascript path (NSWorkspace-mediated dialog, works without a TTY).

## Changed

- **`Conflab.Lenses.Run`** new module houses the run lifecycle pure helpers (`build_pending_run/1`, `group_runs/1`, `seed_review_prompts/2`, `awaiting_llm_review?/1`, `display_step/1`, `progress_percent/1`, `current_step_prompt/1`, `run_to_json/1`, `template_name/1`). Previously inside `LensesLive.Helpers` but pure-data shape transforms with no socket dependency.
- **`Conflab.Lenses.PublishParams`** new module houses publish-flow pure helpers (`prefill/1`, `from_form/2`, `entry_type_from_detail/1`, `parse_tags/1`). Domain because publish is a domain concern not a socket concern.
- **`ConflabWeb.LensesLive.PublishOps`** new web-ops module houses `publish_and_sync/4` extracted from the `publish-submit` event handler (multi-effect sequence -- the design rule D3 anti-pattern that motivated ST0108).
- **`ConflabWeb.LensesLive.Helpers` to `ConflabWeb.LensesLive.DaemonOps`** rename: the residue after Bucket-2/3 move-outs is ~38 push-glue functions (push*\*, expand*\*, configure_uploads, auto_browse, etc) -- daemon push surfaces, not generic helpers. Module name now describes what it actually is.
- **`Lens.serialize_with_source/3`** new in `Conflab.Lenses.Lens` pins provenance during catalog publish. Was inlined in `apply_publish_success/3`.
- **`brand_link/1`** new function component in `ConflabWeb.Layouts`. Single source of truth for the Conflab brand mark + wordmark; both layouts render it.
- **mix.lock patch bumps** (`294a626f`) for `circular_buffer`, `ex_ast`, `oban_web`, `telemetry`. No Ash family bump; no codegen drift.

## Migration notes

- **No breaking changes.** No Elixir migrations; no daemon-side schema migrations; no breaking changes to existing CLI / daemon / macOS verbs.
- **Daemon mgmt password persistence (Tier 2) is forward-compatible.** v0.5.0 installs have an auto-generated password sitting in `daemon.toml` already; v0.5.1's `daemon init` preserves it. Browser tabs holding daemon_tokens minted under v0.5.0's password survive a v0.5.1 wizard re-run. No operator action required.
- **No CA regeneration.** v0.5.0 already shipped the 395-day leaf + serverAuth EKU regen on v0.4.x -> v0.5.0 boot. No further auto-regen this release.
- **Setup wizard cold-install flow.** v0.5.1's post-wizard staleness fix means the menubar dot turns green within ~1s of "All set" without a manual `conflab app stop && conflab app start`. The cold-smoke gyges install pass that surfaced the bug was the verification path.

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

Upgrading from v0.5.0: recommended -- this release closes the menubar staleness bug surfaced by the cold-smoke gyges install, plus the deferred Bug 7 / Bug 8 / Bug 14 from v0.5.0. After upgrading:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary
```

The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
