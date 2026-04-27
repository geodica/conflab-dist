# conflab v0.3.3

_Released 2026-04-27_

Patch release built on top of v0.3.2. Headline is **Manage panel polish (ST0099)** -- the Models tab's **Test** button now validates the stored provider key on a hydrated row with empty input (instead of short-circuiting with "Enter a key first."), and the Daemon tab gets a new **Run doctor…** button that shells four CLI commands in parallel and renders the output in a unified scrollable sheet (no more dropping to Terminal when something looks off). Plus a CLI fix that makes `conflab app status` work correctly when shelled from inside Conflab.app's process tree, and a developer-only fix that re-enables `xcodebuild test` for the macOS xctest target.

## Added

### Test-on-stored provider keys (ST0099/WP-01)

The Models tab on **Manage Conflab > Models** has a **Test** button per provider row. Until this release, pressing Test with an empty input field on a hydrated row (i.e., the API key was already saved to `~/.config/conflab/models.toml`) returned "Enter a key first." -- which was unhelpful, because the key was already there, just not visible. The user wanted to verify the stored key, not retype it.

Now the Test button branches: when the field is empty AND the row is hydrated, the button asks the daemon to verify the key it has on disk; otherwise the existing typed-key path runs.

- **Daemon-side `provider/probe.rs`** (new module) -- pure probe with `verify_provider_key(provider, api_key) -> ProbeResult` covering Anthropic / OpenAI / Google. Mirrors the three request shapes from Swift's `ProviderKeyVerifier` (the daemon's `create_provider` registry only knows Anthropic + Ollama, so the daemon has to mirror Swift's request shapes for OpenAI + Google -- the contract being duplicated is the public LLM-provider APIs, not internal Conflab concerns). 15-second timeout per probe.
- **GraphQL mutation `verifyStoredProviderKey(provider) -> { ok, reason }`** -- resolves `[providers.<provider>].api_key` from `models.toml`, dispatches to the probe, returns `{ ok, reason }`. Plaintext never leaves the daemon. Reason variants: `"unknown provider"`, `"no key on disk"`, `"invalid key"`, `"rate limited"`, `"network error: ..."`, `"unexpected status: NNN"`.
- **Swift `APIClient.verifyStoredProviderKey(provider:)`** -- thin GraphQL client. Lower-cases + filters provider name to letters before embedding in the GraphQL string literal (defence in depth on top of the daemon's `is_known_provider` check).
- **`ModelsStepView.testTapped` branch** -- empty + hydrated + APIClient injected -> daemon path; otherwise existing logic. Wizard's first-time setup passes `apiClient: nil` because hydration is empty during first-run; this is correct -- the daemon path is only reached for empty-field-on-hydrated-row.
- **End-to-end verified live** -- daemon log emits `INFO conflabd::mgmt::mutations: verifyStoredProviderKey provider=anthropic ok=true`, UI renders `✓ Verified`.

### Doctor pane in Daemon tab (ST0099/WP-02)

The Daemon tab on **Manage Conflab > Daemon** carries a new **Diagnostics:** row at the bottom with a `Run doctor…` button. On press: four `conflab` subcommands shell in parallel and the results render in a sheet -- a unified scrollable text body with `--[ <label>  <badge>  <ms> ms ]------------------` divider lines between sections.

- **Commands shelled** -- `conflab --version`, `conflab doctor`, `conflab daemon doctor`, `conflab app status`. All run in parallel via `withTaskGroup`; each capped at 10 seconds via a watchdog Task that calls `process.terminate()` on overrun (output preserved up to the kill point).
- **`DoctorRunner` service** -- pure runner taking `[(label, args)]` pairs, returning `[(label, exitCode, stdout, stderr, durationMs, timedOut, launchError)]`. Reuses `DaemonCLIShell.defaultBinaryPath()` for binary resolution. Distinguishes natural-signal exits from watchdog kills via wall-clock + `terminationReason` correlation.
- **`DoctorReportSheet` UI** -- one NSScrollView wrapping one NSTextView with the full report concatenated, monospaced, selectable. Per-section dividers carry the label, exit-code badge (`✓` / `× exit N` / `× timed out` / `× <reason>`), and duration. **Copy Report** dumps a markdown-shaped concatenation (`## conflab --version\n<output>\n\n## conflab doctor\n...`) to the pasteboard for paste into a chat / PR / issue.
- **Why one big text view, not collapsible sections** -- the initial design used per-section scroll views inside the sheet's outer scroll; the inner views captured the wheel and the outer page wouldn't budge. The unified text body sidesteps the nested-scroll fight entirely. Display format and Copy format are deliberately different: monospace dividers for visual scan on screen, markdown headers for paste-friendly downstream rendering.

## Fixed

### `conflab app status` works from inside Conflab.app

`conflab app status` previously used `pgrep -f "Conflab.app/Contents/MacOS/Conflab"` to detect the running app. From a terminal this worked correctly; **from inside Conflab.app's process tree** (i.e., when the doctor sheet shells `conflab app status` via `Process`), pgrep returned no matches even when the app was clearly alive. Conflab.app uses the macOS hardened runtime; children of hardened-runtime apps hit a kernel process-table visibility filter that hides the parent. Symptom in the doctor sheet: `Conflab.app is not running` despite the doctor sheet itself being a Conflab.app feature.

Fix: `app_pid()` in `native/cli/src/util.rs` now uses `/usr/bin/lsappinfo info -only pid space.conflab.macos`. Launch Services queries are a system-wide IPC service that returns consistent results regardless of caller context. lsappinfo emits `"pid"=NNNNN` on stdout when the bundle is running and empty stdout when it is not.

### `xcodebuild test` for the macOS xctest target

A latent regression from v0.2.0's notarisation prep (commit `1fb1221a` on 2026-04-16) silently broke `xcodebuild test` for the Conflab macOS app. Conflab.app's `Conflab.entitlements` carried `com.apple.security.get-task-allow=false` (Apple notary rejects bundles that request the debug entitlement). Hardened runtime + that entitlement = lldb / debugserver attach denied = xctest cannot establish its IPC channel and times out with "test runner hung before establishing connection" / "Could not attach to pid". The regression went unnoticed for 11 days because the Rust + Elixir suites are the daily drivers; first xctest run after that period surfaced it.

Fix: split the entitlements into Debug (get-task-allow=true) and Release (get-task-allow=false), with `project.yml` overriding `CODE_SIGN_ENTITLEMENTS` per configuration. Xcode picks Debug for `xcodebuild test`; the build-pkg path picks Release for notarisation. Developer-only fix; ships in this release because the project.yml change is on `main` and `xcodegen generate` regenerates the pbxproj.

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

Upgrading from v0.3.2: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading, restart the daemon:

```bash
conflab daemon restart
```

No migrations and no breaking changes. The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
