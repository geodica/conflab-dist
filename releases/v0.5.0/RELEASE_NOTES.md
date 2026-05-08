# conflab v0.5.0

_Released 2026-05-08_

Minor release on top of v0.4.2. Headline is **ST0112 -- First-Run Identity Provisioning closes end-to-end**: WP-01 shipped server-side in v0.4.2; v0.5.0 lands the macOS-side bind step. The CLI's bundled install path now cycles a fresh API key for `^CONFLAB` between `daemon init` and `db init`, so an Alice completing the Setup wizard ends with a bound daemon and a real agent on conflab.space rather than a placeholder handle and a crash-loop. The wizard Done step surfaces `^CONFLAB` with a Copy button so users can address their newly-bound daemon without opening Terminal. Plus the round-2 cold gyges smoke fix batch (WP-05): Apple-compliant 395-day leaf certs with serverAuth EKU (Safari and Chrome both load `https://127.0.0.1:<port>/` without warnings), idempotent `install_trust` (single auth prompt, not two), SHA-1-by-hash keychain enumeration (no more "ambiguous, matches more than one certificate" loops), pipeline ordering that puts `daemon restart` last with `KeepAlive=true` for crash recovery, single-dialog Settings Uninstall, and a five-site string sweep correcting "system keychain" -> "login keychain" across CLI, doctor, advisory, and docs. Plus a server-side fix to the conflab.space layout footer so the build SHA renders correctly under prod (Fly Docker builds had no `.git` to read from, so the version line shipped as `v0.4.2 (unknown)`). Three bugs deferred to v0.5.x (agent UI Delete partial-destroy, wizard `Applying...` terminal-error path, ssh-spawned uninstall -60007).

## Added

### ST0112/WP-02 -- CLI bundled install binds daemon as `^CONFLAB`

Commit `bf473355`. Decouples the bundled daemon agent handle from the CLI profile name and makes `conflab install setup` cycle the daemon's host key for that agent in one shot. After WP-01 landed the conflab.space auto-provision branch in v0.4.2, this WP closes the wizard's half-flow: a fresh install ends with `daemon.toml [daemon] handle = "CONFLAB"` and an api_key whose subject is `agent+conflab@<owner-domain>`, with no manual cycle step.

- **`BUNDLED_DEFAULT_AGENT_HANDLE = "CONFLAB"`** constant in `daemon_cmd.rs` is the single source of truth.
- **`generate_daemon_toml`** takes `handle` as an explicit parameter; the old `profile_name.to_uppercase()` derivation is gone.
- **`run_init`** accepts `Option<String>` handle override (new `--handle <NAME>` clap flag on `daemon init`); thin wrapper `run_init_default()` preserves the existing fn-pointer test seam in `config_cmd.rs` and `pristine_cmd.rs`.
- **`run_token_cycle`** accepts `Option<String>` agent override (new `--agent <NAME>` clap flag on `daemon token cycle`); the bundled-install path passes it so cycle works even when `daemon.toml` is absent or stale.
- **`install_setup::apply_bundle`** invokes `daemon token cycle --agent CONFLAB` between `daemon init` and `db init`. Orchestration block extracted to `apply_full_pipeline` so the dispatch sequence can be unit-tested without stubbing the HTTP call inside `apply_profile`.
- **Test seam**: `ShellFn<'a> = &'a dyn Fn(&[&str]) -> Result<(), String>`. Production passes `&shell_self`; tests pass closures that record into a RefCell-buffered call log and assert the exact dispatch sequence.

Cycle error-mapping for HTTP 403 / 422 deferred (the LV redirect-on-error contract is a server-side follow-up; same surface as deferred Bug 8).

### ST0112/WP-03 -- macOS Setup wizard Done step surfaces `^CONFLAB`

Commit `ef87abc9`. Closes the wizard loop on the user-visible side. After WP-02 binds the daemon, Alice now leaves the Done step knowing how to address her newly-bound daemon: a labelled message naming `^CONFLAB` plus a Copy button that puts the literal `^CONFLAB` on the system pasteboard, ready to paste into a flab.

- **`DoneStepView: NSView`** extracted alongside the existing per-step views (`ConnectDaemonStepView`, `ModelsStepView`) so the unit test can instantiate it directly and exercise the Copy button without presenting the wizard window.
- **`SetupWizardWindowController.renderDone()`** instantiates `DoneStepView()` via the existing content-stack helper. The previous "menubar will go green" copy is retired (it outlived the wizard -> daemon-bind flow it described).
- **Static `bundledDefaultAgentHandle = "CONFLAB"`** mirrors `BUNDLED_DEFAULT_AGENT_HANDLE` in `native/cli/src/daemon_cmd.rs`. No live cross-language constant sharing today; the constants move together.
- **Confirmation pattern**: AppKit-native button-title flip ("Copy ^CONFLAB" -> "Copied \u{2713}" for ~1.2s, button disabled during the flash). Chosen over lifting the SwiftUI Launcher toast capsule into shared scaffolding -- M-sized scope creep on an S WP for a one-shot confirmation.

### ST0112/WP-04 -- Docs sweep across installation / commands / uninstallation / pristine

Commit `f0f7ef32`. Brings the help system in sync with the Alice-Proof bind path landed in WP-02/03. After completing the wizard, Alice's daemon comes up bound as `^CONFLAB`; the docs now explain how that happens and the levers for deviating from the default.

- **`installation.md`**: new "After install: how your daemon gets bound" H2 between Step 1 and Step 2. Names `^CONFLAB`, explains the auto-provision branch on the conflab.space cycle endpoint, documents the idempotent re-run semantics, and describes the `conflab daemon init --handle <NAME>` + `conflab daemon token cycle --agent <NAME>` re-bind path with the upstream charset constraints.
- **`commands.md`**: `daemon init` row gains `--handle <NAME>`; `daemon token cycle` row gains `--agent <NAME>` plus the auto-provision-on-absence semantics.
- **`uninstallation.md`**: "Reinstalling" section explains the wizard re-cycles against the same `^CONFLAB` handle (revoking the prior api_key, minting a fresh one) and that `conflab uninstall` does not revoke the agent on the server -- if the user wants a clean break (eg before reinstalling on a different account) they must delete the agent from the Agents page first.
- **`pristine.md`**: "When not to use pristine" gains a swap-the-identity bullet, cross-linking `installation.md`.

## Fixed

### ST0112/WP-05 must-fix bug batch (round-2 cold gyges smoke)

Six bugs caught by the 2026-05-06 cold smoke against a wiped gyges Mac. All six are user-visible and gate the Alice-Proof end-to-end flow.

- **Bug 5 (`e25cd27d`) -- Settings Uninstall single-dialog flow**. `cmd_uninstall::run` splits into Phase 1 (non-privileged inline) + Phase 2 (privileged osascript admin batch in one auth dialog). macOS shows ONE auth dialog regardless of how many `[admin]` rows are in the plan; mediated by NSWorkspace, not the controlling terminal, so it works from non-TTY callers (Settings panel via `DaemonCLIShell`). Drops `run_sudo` / `sudo_remove`; renames `[sudo]` plan marker to `[admin]`.
- **Bug 6 (`33e7c731`) -- SHA-1 enumeration replaces ambiguous CN-based delete**. `security delete-certificate -c "Conflab Local CA"` errors with "ambiguous, matches more than one certificate" when 2+ CAs share the CN -- exactly the case left behind by repeat installs. New `tls.rs` helpers (`list_login_keychain_ca_hashes`, `parse_find_certificate_hashes`, `delete_login_keychain_ca_by_hash`, `login_keychain_has_ca`) enumerate by SHA-1 and delete by hash. The CLI uninstall planner reuses the helpers via `conflabd::tls::*`.
- **Bug 9 (`661e0584`) -- pipeline restart-as-last + run_start error propagation + KeepAlive**. Daemon ended up stopped after the wizard reached "All set" despite `apply_full_pipeline` invoking `daemon restart`. Defensive batch: pipeline reorders so `daemon restart` is the FINAL step (init -> cycle -> db init -> cert generate -> cert install -> restart); `run_start` propagates health-check failure as `Err` instead of silently logging Ok (No-Silent-Errors); `generate_plist` ships `KeepAlive=true` so launchd respawns crashes; `run_restart` waits 500ms between stop and start to clear bind races.
- **Bug 11 (`67c2e182`) -- `install_trust` SHA-1 short-circuit + canonical probe**. Post-`167b5405` `install_trust` was destructive on second invocation: the wizard fired it twice (Swift CA-trust pane, then `apply_full_pipeline`'s cert-install step), each call scrubbing the freshly-added CA before re-adding it. Two macOS auth dialogs per install in the happy path; cancelling either left the keychain with zero CAs. Defensive fix: new `InstallTrustAction` enum + pure `install_trust_decision` factored for hermetic unit tests; `compute_pem_cert_sha1` parses the PEM body and matches `security find-certificate -Z` output. `install_trust` is now a thin coordinator. Single auth prompt regardless of how many call sites invoke it.
- **Bug 12 (`6d48758d`) -- 395-day leaf certs with serverAuth EKU + auto-regen marker**. Apple's TN3171 enforces ≤398 days for SSL leaf certs trusted by the Apple TLS stack (Safari, URLSession). The previous 10-year leaf and missing serverAuth EKU triggered "Not Private" warnings in Safari (Chrome's laxer localhost policy hid the issue). `LEAF_VALIDITY_DAYS = 395`; `ExtendedKeyUsagePurpose::ServerAuth` pushed onto leaf params. Sidecar `~/.config/conflab/tls/.policy_v2` marker stamped after every successful generation; daemon reads it on boot via `ensure_current_cert_policy()` and regenerates in place when missing or stale -- v0.4.x installs heal automatically on first v0.5.0 daemon boot. After regen the user must re-run `conflab daemon cert install` to re-trust the new CA.
- **Bug 13 (`f1fb4408`) -- "system keychain" -> "login keychain" string sweep**. `167b5405` moved `install_trust` from `/Library/Keychains/System.keychain` to `~/Library/Keychains/login.keychain-db` and updated `trust_explainer_text`, but five other user-visible strings stayed wrong. A user runs `conflab daemon cert install`, sees "installed in system keychain", opens Keychain Access against System keychain, finds nothing, and panics. Five sites fixed: post-install success line, post-cert-generate advisory, `conflab daemon doctor` row, CLI subcommand `--help` text, `remove_trust` doc comment.

Three bugs deferred to v0.5.x:

- **Bug 7 -- conflab.space agent UI Delete partial-destroy**. Recoverable via the Fly IEx prod cleanup snippet documented in `intent/st/ST0112/WP/05/info.md`.
- **Bug 8 -- wizard `Applying...` spinner has no terminal-error path**. Same architectural gap as the deferred WP-02 cycle-error-mapping; will bundle into a single `LoopbackOutcome::CycleError` follow-up.
- **Bug 14 -- ssh-spawned `conflab uninstall --yes` returns -60007**. Power-user only; documented workaround (use a screen-shared Terminal) preserves functionality.

### Pre-WP-05 cold-install regressions

Commit `167b5405`. Three independent bugs caught by the 2026-05-06 cold smoke before WP-05 elaborated the round-2 batch:

- **`apply_bundle` did not restart the daemon after cycling the host key**. Cycle rewrites `daemon.toml` but the running conflabd kept the old config in memory; the macOS app then 401'd against the stale daemon while pgrep cheerfully reported it running.
- **`install_trust` accumulated stale "Conflab Local CA" entries in login keychain across installs**. Multiple CN-matching CAs confuse Safari's chain validation. Bounded loop of `security delete-certificate -c "Conflab Local CA"` until none remain (later superseded by Bug 6's hash-based enumeration).
- **`conflab uninstall` was probing System.keychain for the CA, but `install_trust` writes to login.keychain-db**. Probe always returned "not present", silently skipping the delete action. Re-pointed; `DeleteKeychainCert` no longer needs sudo (login keychain is per-user; sudo would resolve `$HOME` wrong and target the root account's empty login keychain).

### Server-side: footer git SHA correctly rendered

Commit `df60185d`. The conflab.space layout footer was rendering "v0.4.2 (unknown)" because `Conflab.BuildInfo` captured the git hash via `System.cmd("git", ...)` at compile time, and the Fly Docker build context does not include `.git`. Three-edit fix:

- **`lib/conflab/build_info.ex`** prefers a `GIT_SHA` env var (Docker / Fly builds via `--build-arg`), falling through to the existing git command (local dev), still landing on "unknown" only when neither resolves. Tuple-matched single case so the resolution stays one expression.
- **`Dockerfile`** declares `ARG GIT_SHA=unknown` + `ENV GIT_SHA=${GIT_SHA}` immediately before `mix compile` so deps and asset cache layers stay valid when only the SHA changes between deploys.
- **`scripts/deploy`** passes `--build-arg GIT_SHA=$(git rev-parse --short HEAD)` to `fly deploy`. The clean-tree gate already runs upstream so the SHA we capture matches the deployed commit.

## Changed

- **Canonical login-keychain CA probe (`conflabd::tls::login_keychain_has_ca`)**. Three previously-divergent sites collapsed onto it: `install_trust` (the original site), `uninstall.rs::keychain_has_cert` (was running its own `find-certificate` probe), and `install_setup.rs::is_ca_trusted` (was still probing System.keychain post-`167b5405`, a Bug 13 regression hiding in a probe). Surfaced by the critic-rust pass on the WP-05 batch. Locked decision D11.
- **`install_trust` is now a thin coordinator**. Read state, dispatch to pure `install_trust_decision`, scrub orphans, execute the one side-effecting branch. Old in-band `delete_existing_ca_entries` removed (Highlander -- the orphan scrub is part of the decision dispatch).
- **`compute_pem_cert_sha1` Highlander**. PEM body parsed and SHA-1 computed in one place; matches `security find-certificate -Z` format (uppercase hex, 40 chars, case-insensitive comparison via `eq_ignore_ascii_case`).
- **`daemon_cmd::run_start` propagates health-check failure as `Err`** instead of silently logging and returning `Ok` (No-Silent-Errors). Callers like `apply_full_pipeline` now see the actual reachability state.
- **`tls.rs` post-WP-05 rustfmt drift** (`c4b319ed`). Pure cosmetic `cargo fmt --check` repair.
- **New dep**: `sha1 = "0.10"` for the PEM-body SHA-1 round-trip in Bug 11's short-circuit.

## Migration notes

- **No breaking changes.** No Elixir migrations; no daemon-side schema migrations; no breaking changes to existing CLI / daemon / macOS verbs.
- **Server side requires a Fly deploy** to pick up the footer git-SHA fix (commit `df60185d`). `scripts/deploy` now injects the build-arg automatically; no operator action beyond running the script. Old deploys carrying "unknown" in the footer continue to function; the visible-only delta lands on the next deploy.
- **CA auto-regenerates on v0.4.x -> v0.5.0 daemon boot.** Bug 12's `.policy_v2` sidecar marker triggers a one-shot regeneration of the local TLS leaf and CA on first v0.5.0 daemon start. **You must re-run `conflab daemon cert install` to re-trust the new CA**, otherwise Safari shows "Not Private" on `https://127.0.0.1:<port>/`. The `daemon doctor` surface (Bug 13's strings) correctly points users at login keychain.
- **Setup wizard CA-trust prompt frequency**. v0.4.x cold installs prompted twice for macOS auth in the CA-trust step (Bug 11). v0.5.0 prompts once (idempotent SHA-1 short-circuit). If you cancel the prompt, the daemon will not be reachable -- re-run `conflab daemon cert install` to re-trigger.
- **Operators upgrading from before v0.4.2** also pick up WP-01's role-based agent quota change (default flipped from 10 to 1 for `:user`). See `release-notes/v0.4.2.md` "Operators who relied on the global agent-quota default of 10".

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

Upgrading from v0.4.2: recommended -- the WP-05 batch closes user-visible regressions in the install path. After upgrading:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary; .policy_v2 triggers cert regen
conflab daemon cert install    # re-trust the regenerated CA
```

The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
