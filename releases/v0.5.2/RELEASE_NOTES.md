# conflab v0.5.2

_Released 2026-05-12_

Patch release on top of v0.5.1. Headlines: **ST0113 -- Cold-install agent flab onboarding closes end-to-end**, with WP-01 landing daemon-side membership-change reactivity (the daemon picks up flab invites mid-run without restart) and WP-02 landing a corrected wizard / CLI "invite your agent" hint that replaces the misleading "Address it in any flab to summon it" Done-step prose. Plus a v0.5.2-only Tier 1 follow-up that closes two correctness gaps in the just-shipped WP-01 surface (eviction of removed flabs + granted_caps refresh). Bundle drift detection lands as a CLI test so the daemon can no longer ship lens / shape / theme bundles out-of-sync with `priv/data/lsd/`. Settings → Reset gains a `Repair Daemon…` recovery affordance for users with broken daemon configs. Four UX polish fixes: nav buttons now drop right-to-left on viewport shrink (Dashboard anchors), theme toggle is reachable on every viewport via the avatar menu (and the top-nav pill's fold relaxed from 2xl to xl), Settings → About content enlarged.

## Added

### ST0113 -- Cold-install agent flab onboarding (WP-01 + WP-01 follow-up + WP-02)

ST0113 closed end-to-end across three commits + one follow-up commit, plus its full design + as-built docs in `intent/st/COMPLETED/ST0113/`.

- **WP-01 -- daemon membership-change reactivity (`98d9e359`).** Today the daemon's `connected_flabs` / `flab_id_by_slug` / `participant_ids` caches were populated once at boot and never refreshed; the ws bridge subscribed to flab Phoenix channels at boot only. Cold-install gyges users invited their agent on conflab.space and got nothing -- the daemon ignored the new flab until restart. WP-01 lands a cache-merge pass in `mcp::check_messages` that diffs fresh `list_flabs()` against `DaemonState`, resolves the daemon's participant in each new flab via `list_participants`, and merges into the three RwLock-guarded caches. A new `flab_subscribe_tx: mpsc::Sender<FlabSubscribeReq>` channel lets the cache-merge forward the new flab_id to the ws task, which emits a Phoenix `phx_join` mid-run -- realtime `new_message` pushes start arriving without restart.

  **Mid-investigation design correction.** The original ST0113 design.md said `list_flabs()` was called once at boot. The implementation pass found it's already called fresh on every `check_messages` invocation. design.md D1 carries the correction; the shipped shape is cache-merge + dynamic ws subscribe, not a one-shot AtomicBool refresh.

- **WP-01 follow-up -- eviction + granted_caps refresh (`2a7475c2`).** Boy-scout closure on two real correctness gaps in the just-shipped WP-01:

  - **Eviction.** When a flab is removed from `list_flabs` (eg the daemon's agent was ejected), the caches stayed stale AND the ws bridge kept subscribed to the dead Phoenix topic. The server returned `phx_error`, tripping the ws `run()` loop's full disconnect+reconnect path on every poll until daemon restart. Fix: a second pass in `check_messages` identifies slugs in `connected_flabs` not in fresh `list_flabs`, evicts from all four caches + `unread_counts`, and sends a `phx_leave` via the same membership-change channel. Channel widens to `FlabSubscribeReq::{Subscribe, Unsubscribe}` (was `Sender<String>`).
  - **granted_caps refresh.** The boot loop populates `state.granted_capabilities` per-flab from `list_participants`. WP-01 didn't mirror it for mid-run discoveries, so the daemon wouldn't recognise granted authority until restart. Folded into the existing new-flab `Some(p)` arm; trivial extension.

  Tier 1c (`router.self_identifiers` refresh) deferred -- impact is vanishing post-v0.5.1 since the participant identifier always equals `agent_handle` across all flabs.

- **WP-02 -- wizard "invite your agent" hint (`0f163650`).** Pre-v0.5.2 the wizard's Done step said "Address it in any flab to summon it" -- misleading because the freshly-bound agent has zero flab memberships. Body text on both surfaces (Swift `DoneStepView` + CLI `install_setup.rs`'s "Setup complete." print) replaced with the design.md D4 wording:

  > Your daemon agent is ^GYGES.
  >
  > Invite ^GYGES to a flab on conflab.space to start a conversation, then address it in chat to summon it.
  >
  > You can re-run this wizard any time from Settings → General → Setup.

  Handle interpolation continues to use per-install `pasteboardPayload` / `agent_handle`. CLI hint gated on `bundle.profile.is_some()` so the providers-only path (Settings Save) stays silent.

### Bundle drift detection (`f7012e53`)

New registry-driven test in `lens_cmd::tests` walks `priv/data/lsd/` once into a `{filename: path}` map, then iterates `bundled_lenses()` / `bundled_shapes()` / `bundled_themes()` and asserts each bundled-bytes entry matches its publication source byte-for-byte. Mismatches accumulate into a Vec<String> for a single comprehensive panic message. Catches the case where a maintainer edits `priv/data/lsd/<theme>/entries/<slug>.lensmd` but forgets to mirror the change into `native/daemon/src/template/fixtures/` before publication. Tools exempt -- ST0109/WP-01 collapsed them to a single cross-crate `include_str!` source, so by construction the CLI bundle IS the daemon fixture.

`cargo test --bin conflab` now reports 264 / 264 (was 263 in v0.5.1).

### Settings → Reset → "Repair Daemon…" (`f0467210`)

Non-destructive recovery affordance as the first button on the Reset tab. Click hands off to `AppDelegate.presentSetupWizard(hydrateFromCurrent: true)` -- same path as the Daemon tab's HTTPS-row "Setup…" button, surfaced under a more discoverable label for the recovery scenario. Use case: users with a broken daemon.toml from pre-v0.4.1, users whose menubar dot stays red after a daemon-toml edit, anyone recovering from a broken config without wanting to uninstall+reinstall. Closes the "Existing-broken-install repair surface" carried thread.

## Fixed

### Nav buttons drop right-to-left on resize, not left-to-right (`f337e591`)

App-layout header previously hid `Dashboard` first as the page width shrank below `lg` (1024 px) -- the inverse of the desired behaviour. The other nav buttons (Flabs, Lenses, Shapes, Catalog) all shared `hidden sm:flex`, dropping together only at mobile widths. Reassign breakpoints so priority items survive longest. Drop order (first to drop → last to drop):

```
theme toggle (< xl,  < 1280px)   -- v0.5.2 relaxed from 2xl per UX feedback
Catalog       (< xl,  < 1280px)
Shapes        (< lg,  < 1024px)
Lenses        (< md,  <  768px)
Flabs         (< sm,  <  640px)
Dashboard     (always visible)
```

Help button + notification bell + daemon dot + user menu unchanged. brand_link still anchors left.

### Theme toggle reachable on every viewport (`68db86e7` + `9f64c594` + `3b9ef1c6`)

Pre-v0.5.2 the theme toggle was the rightmost nav-cluster element with no responsive class -- always visible until the viewport narrowed enough to hide it via the nav-cluster overflow. Three iterations land the final shape:

- **`68db86e7`.** Top-nav theme toggle fold relaxed from `hidden sm:flex` (always visible) to `hidden 2xl:flex` -- intent was "drop first as the viewport shrinks". Also added to the user_menu dropdown as an always-reachable secondary path.
- **Refinement after user feedback.** `hidden 2xl:flex` was too aggressive (1536px) -- the toggle hid on most laptops. The inline 3-button pill in the avatar menu was too heavyweight for a rare action. Refactored:
  - **`9f64c594`.** Top-nav fold to `hidden xl:flex` (1280px, same fold as Catalog). Avatar menu shape changed from the inline pill to a daisyUI nested `<details>` submenu: single "Theme" parent item with a chevron + three children (System / Light / Dark). All three use the existing `phx:set-theme` JS dispatch + `data-phx-theme` attribute.
  - **`3b9ef1c6`.** Default `<summary>` styling (`display: list-item`) was hiding the parent item's leading paint-brush icon. Added `list-none` + `[&::-webkit-details-marker]:hidden` and `shrink-0` on the icon.

### Settings → About content enlarged (`4c81f512`)

The About panel content was visually lost in the Settings window. Bumps: logo 96 → 160 pt, title 18 → 28 pt bold, body 13 → 18 pt, small text (copyright / created-by) 11 → 14 pt, version stamp 10 → 12 pt monospaced, text container 440×140 → 540×220, stack spacing 16 → 28 pt, line spacing 6 → 10 pt.

## Dependency bumps (routine)

`mix.lock` lifts five Elixir deps from their v0.5.1 pins. Full `mix test` (2220 / 0) and `mix compile --warnings-as-errors` green against the new lock:

- `decimal` 2.4.1 → 3.1.0 (major; postgrex + xema constraints already permit `~> 3.0`)
- `ex_ast` 0.11.1 → 0.11.2 (patch)
- `finch` 0.21.0 → 0.22.0 (minor)
- `postgrex` 0.22.1 → 0.22.2 (patch)
- `xema` 0.17.7 → 0.17.8 (patch)

## Tests + verification

- Elixir: full `mix test` green (2220 / 0) at every commit; HEEX compile green throughout the three Phoenix-side UX iterations.
- Rust daemon: 1091 / 1091 lib tests green; `cargo clippy -- -D warnings` clean; `cargo fmt --check` clean.
- Rust CLI: 264 / 264 tests green (was 263; +1 for the bundle-drift detector); `cargo clippy --bins --tests -- -D warnings` clean; `cargo fmt --check` clean.
- Swift: `xcodebuild` verification deferred to user-side cold-smoke -- the two macOS-side changes (WP-02 DoneStepView body text, Reset → Repair Daemon button) are structural mirrors of existing patterns and the existing Swift test suite doesn't depend on the touched surfaces (SetupWizardDoneTests focuses on pasteboard payload + copy-button title, not body text).

## Deferred to v0.5.3 / v0.6.x

- **JSON-schema validation for `produce_output`** (was Tier 2 v0.5.2 candidate). Closes a real correctness gap in the agent loop -- shape-typed tool outputs aren't validated against the lens's declared JSON Schema today, so a malformed model response can poison downstream steps. M-sized; needs careful Decision-A retry semantics (re-prompt model with the validator error rather than passing malformed JSON through). Deliberately deferred from v0.5.2 to avoid shipping rushed agent-loop work.
- **Tier 1c -- `router.self_identifiers` refresh on mid-run new flabs.** Vanishing impact post-v0.5.1 (identifier always equals `agent_handle`), but technically incomplete. Lift if a legacy install surfaces a real symptom.

## Standing landmines (unchanged from v0.5.1)

- `brew unlink conflab` after `brew update` if local CLI builds stop reflecting `cargo build`.
- `CONFLAB_DISABLE_KEYCHAIN=1` for any test harness spawning `conflabd` under tmpdir HOME.
- `~/.conflab/db` is a separate git repo; pristine commands operate on it via the same Intent CLI rules.
- v0.4.x certs auto-regenerate on first v0.5.0+ daemon boot via the `.policy_v2` marker. Browser warning until user runs `conflab daemon cert install` to re-trust.
