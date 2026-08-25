# conflab v0.6.1

_Released 2026-08-25_

A patch release by number and a substantial one in content. Its centre is a single user-visible defect -- **a valid provider API key reported as bad** -- which turned out to have three independent causes, and the deeper problem underneath it: a model identifier written down in four languages, so a provider retiring a model broke each surface separately and surfaced as "your key is bad". Model identifiers now resolve through symbols, key verification has one implementation, and a failed run says what actually happened. Alongside that: structured run errors end to end, an inline key-repair affordance in the macOS run pane, Launcher keyboard shortcuts and state restore, and a tooling and infrastructure move. No schema changes, no new migrations; the wire change is additive.

## Added

### Model symbols -- an identifier is written down once

A **symbol** names the role a model plays (`ANTHROPIC_OPUS_LATEST`, `GOOGLE_GEMINI_FLASH_LATEST`); a shipped seed binds that role to today's identifier, and everything else names only the role. Refreshing a generation is now one edit in one file instead of a hunt through Rust, Swift and Elixir for pinned strings.

Resolution has three layers:

1. **Seed** -- eight shipped symbols across `anthropic`, `openai` and `google`, checked in and maintained by us.
2. **Your `models.toml`** -- you win. A machine that pinned something deliberately keeps it, and the seed never overwrites a pin.
3. **The provider's live catalogue** -- compared against, never auto-adopted. An upstream change cannot silently rewrite your configuration.

The effective table is computed on every read and never stored, so a shipped default can never be written back into your `models.toml` as though you had chosen it. `conflab model list` and `conflab daemon doctor` now say where each binding came from, because a pin and a shipped default behave differently the next time the seed moves.

### Verify a candidate key before it replaces the stored one

```bash
conflab model verify-key anthropic --api-key <key>   # store it only if the provider accepts it
conflab model verify-key anthropic --api-key <key> --no-save   # probe it, write nothing
conflab model verify-key anthropic                   # probe the key already on disk
```

A key that fails to verify is not written, so a bad paste cannot destroy a working credential. Surrounding quotes and stray whitespace are stripped daemon-side, so a key copied with its quotes still works. The plaintext key never leaves the daemon.

The same verb is on all three surfaces: two new MCP tools, `verify_candidate_provider_key` and `verify_and_save_provider_key`, join the existing `verify_provider_key`.

### Repair a rejected key where the run failed

When a Lens run fails because the provider refused the credential, the macOS run pane now offers to replace that provider's key inline, rather than sending you to Settings to work out which model was involved. The offer is made on the structured error code alone -- not on the message text, the HTTP status, or the provider name -- so a run that fails for any other reason gets the failure and no misleading affordance.

### Structured run errors, end to end

A run result now carries `error { code provider model message operands }` across the daemon, the CLI and the macOS app, over a taxonomy of twelve codes (`PROVIDER_CREDENTIAL_REJECTED`, `PROVIDER_RATE_LIMITED`, `MODEL_NOT_FOUND`, `AGENT_QUOTA_EXCEEDED`, and so on). A provider-auth failure carries remediation naming the file that holds the key and the command that replaces it; every other failure reports what the daemon observed and prescribes nothing.

### Launcher keyboard shortcuts and state restore (macOS)

- **⌘1 to ⌘9** switch tabs, derived from the picker order so the shortcut and the layout cannot drift apart. **⌘F** focuses the search field, which is now visible rather than implied. Both are bound only while the grid is showing, so neither fires out from under a Run form you are filling in.
- The Launcher **remembers your tab, the Manage panel you were on, and your window frames** across launches. A stored id that no longer names anything falls back to the default rather than restoring you onto a tab that renders nothing.

## Changed

### Key verification stopped billing you to answer a yes/no question

All three provider probes moved from POSTing a completion against a pinned model to a GET against the provider's model-listing endpoint (`/v1/models`, `/v1/models`, `/v1beta/models`). The old probes named a specific model, which is a thing providers retire; a test now fails if any probe URL names a model at all.

### Only a refusal counts as a refusal

The probe used to map HTTP 400, 401 and 403 alike to "invalid key". Only **401 and 403** are a credential rejection now. Everything else is reported as inconclusive, in those words: _"could not verify: provider answered HTTP 429. This does not mean the key is bad."_ Remediation follows the same rule -- only a refused credential or an absent one gets told to replace the key. A rate limit used to say "replace your key".

### `conflab daemon doctor` reports measurement, not intent

- The conflabc URL check tests **reachability**, not presence. It printed a green tick against a dead `localhost:4000` for twenty-five days.
- **Every distinct provider credential is probed** -- one probe per provider, since the credential is shared by every model naming it. A daemon that could not execute a single Lens previously read as healthy.
- A daemon **bound to a different server than the active profile is a failure**, not an advisory that did not count toward the total.
- The **`warn` tier is gone**. Every non-verified provider status counts as a failure; a "might be broken, not counted" tier is how a real failure renders as skippable.
- The models count reports the **effective** table rather than the `[models]` section, which now reads 0 on a healthy pin-free config.

### `conflab daemon init` no longer pins a model

The generated `models.toml` carries what is genuinely yours -- your key under `[providers.<name>]` and the symbol you want as the default. It writes no identifier at all, so a cold install tracks the seed instead of freezing at whatever was current on install day. The key also moves out of `[models.<name>]`, the legacy placement the loader was migrating on every start.

### One implementation of provider-key verification

The macOS app carried a complete second implementation -- its own URLSession, request builders and status-code mapping. Which one ran was decided by whether a text field happened to be empty, so the same key could fail and then pass seconds apart. The app's copy is deleted; all three surfaces call one probe.

### Favourites renders as a grid (macOS)

Favourites now draws through the same tile grid as the Library, rather than as a full-width list, so a pinned Lens looks like the same Lens. Drag-to-reorder went with the list and has not yet been replaced.

## Fixed

- **Google credentials reported as bad.** The app's probe named a model Google had retired, so a valid Google key came back rejected with "generate a new one from the provider's console" attached. The broken path was the first-use path: the field is only blank for a key already on disk, so every new key and every rotation got the stale implementation.
- **A failed retry kept part of the previous attempt.** The retry path cleared the previous attempt's failure and kept its result, so a failed retry served the new prompt beside the previous answer. The per-attempt model, trace and token counts are cleared with it. The run's composition fields are deliberately retained -- they are written only by the full-run path and still describe the run truthfully.
- **Every surface reports what dispatch uses.** Four dispatch sites and the reporting surfaces now read one effective table, so `conflab daemon doctor` and `conflab model list` cannot describe a configuration the router is not using.
- **GraphQL string escaping** escapes the whole grammar class rather than the byte that happened to be reported.
- **Three duplicated encodings collapsed** (macOS): one server-URL default, one GraphQL escape, one TOML unquote.
- **Seven hand-rolled polling loops replaced** by one observation primitive (macOS). `withObservationTracking` is one-shot, and each site re-armed it slightly differently.
- **The Launcher panel no longer paints over the Manage window** (macOS).
- **One editor asks for focus, and it is the one you are looking at** (macOS).
- **`BuildInfo` is stamped on every build**, not once.
- **Websockets on `fly.dev`.** `check_origin` is derived from `FLY_APP_NAME` rather than hardcoded, so the app name can move without refusing connections.

## Tooling & infrastructure

- **`bin/conflab` and `bin/cf` are devbin.** The hand-rolled launcher is gone. Every dev and ops verb is a devbin handler with its own help topic, and the pre-commit hook, CI, and the release pre-flight all delegate to the same `conflab check` / `conflab test` gates, so a rule fixed in one place is fixed for all three.
- **Toolchain pinned to what actually runs**: Erlang 29.0.5, Elixir 1.20.3-otp-29, including the deploy image.
- **Rust `fmt` and `clippy` gates run pre-commit**, not only in CI.
- **Seven dead Credo checks removed.** `credo_checks/` was never referenced from `.credo.exs`'s `checks:` and had never run; the directory and both `elixirc_paths` entries are gone.
- **Nine dead `mix.lock` entries dropped**; the dependency check goes green.
- **Production consolidated onto one app and one shared database cluster** (server-side, already live): the app is `conflab-app`, the database is `conflab_db` with a per-app user, on one 2GB machine. `conflab db doc` regenerates the measured half of the Fly runbook from the live estate rather than from memory.

## Documentation

The published docs are brought in line with this release. One of the corrections is worth calling out on its own:

- **Where your provider API keys actually live.** The docs said keys were held in "the daemon's secrets store, not in `models.toml`". That is not true and had not been true for some time: provider keys are stored in `models.toml` itself, in plaintext, under `[providers.<provider>]`, in a file written with your system's default permissions. The macOS Keychain holds the daemon's own management password, which is a different secret. The pages now say so plainly, so you can decide how to treat the file.

The rest:

- **Model symbols are documented**, with the eight shipped symbols, the seed / pin / catalogue precedence, and what you give up by pinning.
- **The `models.toml` examples show what `conflab daemon init` now writes** -- a provider key and a default symbol, no pinned identifier.
- **The two new key-verification MCP tools are documented**, with the five-value status taxonomy and the rule that only `CREDENTIAL_REJECTED` means the key is bad.
- **`model verify-key` and `verify_provider_key` are no longer described as a "1-token call"**, which they have stopped being.
- **The MCP tool count is corrected from 60 to 62.**
- **`claude-opus-4-7` no longer appears as a current identifier**, in six places across four pages, and the examples that named a model config name now name a symbol -- which is what a fresh install actually has.

## Migration notes

- **No schema changes and no new database migrations.**
- **The wire change is additive.** The run result gains an `error { ... }` object; clients reading `llmError` / `errorMessage` keep working unchanged.
- **`models.toml` is compatible in both directions.** Existing `[models.<name>]` pins keep winning over the seed, and keys still found under `[models.<name>]` are still migrated at load. Only new installs get the pin-free template.
- **`conflab daemon doctor` will report failures it previously reported as warnings or not at all** -- an unreachable server, a profile/binding mismatch, an unverified provider credential. This is a reporting change, not a regression: those states existed before and did not count.
- **The `[conflab-error]` process tag's content changed.** The frame is still spelled `[conflab-error]`, but it now carries the shared error JSON instead of a bespoke `reason; existing_handles=A,B` encoding. The CLI and app ship together, so this affects only anything third-party parsing that tag.
- Existing v0.6.0 installs upgrade cleanly.

## Install / Upgrade

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

Upgrading from v0.6.0:

```bash
brew upgrade --cask conflab    # cask
brew upgrade conflab           # formula
conflab daemon restart         # picks up the new daemon binary
conflab daemon doctor          # expect new failures it previously did not count
```

No CA regeneration. No breaking client changes.
