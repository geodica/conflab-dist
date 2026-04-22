# conflab v0.3.1

_Released 2026-04-22_

Patch release built on top of v0.3.0. Headline is **ST0096 — Lens Launcher**: a Shortcuts-style macOS menubar runner for the user's Lens library, with shape-aware result rendering, Favourites + pinning, a Flab-it! destination, and a catalog-first starter-pack installer that ships 11 Lenses, 7 Shapes, and 4 themes. Also ships **ST0091** — the daemon-internal `Workflow → LensRunner + Run` rename that cleans up the naming split between the execution subsystem and the public artefact — plus a unified Circle view with per-row relationship badges, a new Feed tab as the default on `/app/circle`, the Instaflag admin tool, a fix for a latent polymorphic-aggregate bug on `Catalog.Entry.flag_count`, hardened registration-mode enforcement, and assorted local-dev polish.

## Added

### Lens Launcher (ST0096)

A Shortcuts-style runner for the user's Lens library, living in the macOS menubar. Two tabs — Favourites (user-pinned, reorderable) and All Lenses (alphabetical, searchable). Global hotkey `⌥⌘R` (recorder + Carbon registration via `sindresorhus/KeyboardShortcuts`, no Accessibility permission needed).

**Run dispatch.** `LensLibraryService.runLens(path:variables:attachmentPaths:modelConfig:shape:)` calls the daemon's existing `run` mutation and decodes the full execution result (id, status, shape, llmResponse, tokens, timings, errors). Attachments use a per-variable `<name>_files` convention (newline-joined absolute paths), so Lua reads local paths without a schema change or upload step.

**Shape-aware result rendering.** Four client-side Swift renderers route on the Lens's declared shape:

- `MeetingSummary` — four-section card; parser tolerates `##` / `**bold**` / case variants.
- `ActionItems` — checklist with assignee + due-date pills; parses `- [x]`, `Alice:`, `@alice`, `(by Friday)`.
- `JsonSchemaGeneric` — ordered key/value table; strips JSON markdown fences.
- `MarkdownFallback` — SwiftUI AttributedString with a "Shape validation failed" banner when a known-shape parse fails.

**Favourites + pinning.** `LauncherPreferences` wraps `UserDefaults` with `pin / unpin / togglePin / move / reorder`. `@Published pinnedIds` drives SwiftUI reactivity. The Favourites tab renders a vertical `List` with `.onMove` drag-reorder + empty-state CTA. Lens tiles grow a pin overlay on hover, plus a Pin/Unpin menu item.

**Run form generated from the Lens variable schema.** Every Lens variable becomes a typed input: number fields with min/max, text inputs (CodeMirror for multiline with INSTRUCTIONS preview), file attachments via a compact `+files` affordance with flowing attachment pills, and booleans. Model picker in a top-right cog menu is wired to real daemon models (was a hardcoded stub).

**Destinations.**

- **Copy** — NSPasteboard.
- **Save...** — `NSSavePanel.beginSheetModal(for: NSApp.keyWindow)` so the dialog attaches to the Run window (on top, blocks underlying clicks, no stacking). Default filename `<Lens Title>.md`.
- **Flab it!** — new FlabPickerView sheet (searchable, alphabetised list, loading/loaded/failed states). `LensLibraryService.listFlabs()` + `postToFlab(slug:body:)` via the daemon's new `listFlabs` query + `postToFlab` mutation on the management GraphQL schema.

**Result pane polish.** Status line formats sub-second runs as "<1s"; form collapses to chips on completion with an "Edit inputs" re-expand; "Run again" button in the result header; "View in history" deep-link via `LauncherCrossLink.open(path: "/app/lenses", queryItems: [{run, <id>}])`.

**Catalog-first starter pack.** Four themes (`starter-working-with-documents`, `starter-working-with-code`, `starter-working-with-products`, `starter-other-useful-lenses-and-shapes`) covering 11 hand-tuned Lenses + 7 curated output Shapes across meeting notes, coaching, achievements, reading lists, news summarisation, profile summaries, and structured critique. `conflab lens install / shape install / theme install <slug>` fetches from conflabc's GraphQL and writes to `~/.conflab/db/{lenses,shapes}/<theme-slug>/`.

### Daemon rename: Workflow → LensRunner + Run (ST0091)

Daemon-internal rename split along two semantic axes:

- **Runner** is the internal subsystem. `native/daemon/src/workflow/` moved to `lens_runner/`; `WorkflowManager` renamed to `LensRunner`.
- **Run** is the public artefact. `WorkflowExecution` renamed to `Run`, `WorkflowStatus` to `RunStatus`. GraphQL fields `workflows` → `runs`, `approveWorkflow` → `approveRun`, etc.

SQL table `workflow_executions` renamed to `runs` under a new v15 migration (column-probe-guarded so existing user data is preserved). Elixir LiveView callers and CLI GraphQL clients updated in lockstep.

Deliberately preserved to avoid user-visible churn:

- `TemplateKind::Workflow` enum variant (orthogonal template-category tag — not the same concept as the execution subsystem).
- `conflab-workflow` Lua block syntax (user-authored content).
- macOS Automator `.workflow` bundle references.

### Circle unified + Feed tab

**Circle unified.** The v0.3.0 Circle / Following / Followers tab trio has collapsed into one paginated list on `/app/circle`. Each row carries a relationship badge — **Friend / Mutual / Following / Follower** — and the matching action (**Unfriend** / **Unfollow** / no action for follower-only). Backed by a new `Conflab.Social.list_my_people/2` that loads friendships + outgoing follows + incoming follows, deduplicates so Friendship wins over any corresponding Follow edges, derives `:mutual` where both-way Follow exists without a Friendship, and returns the sorted union. In-memory offset-pagination at 20 per page.

`ConflabWeb.Components.UserCard` variant `:circle` renamed to `:friend`; added `:mutual` and `:follower` variants with matching badges. `:discover` unchanged.

**Feed tab as the new default on `/app/circle`.** Newest-first activity timeline of friends + mutuals + outgoing follows. Follower-only users are excluded ("they follow me, but I don't see their activity"). Four event kinds in v0.3.1:

| Kind              | Source              | Verb               | Payload rendered           |
| ----------------- | ------------------- | ------------------ | -------------------------- |
| `:lens_published` | `Catalog.Entry`     | "published a Lens" | Entry title + link         |
| `:lens_reviewed`  | `Catalog.Review`    | "reviewed"         | Entry title + review title |
| `:lens_rated`     | `Catalog.Rating`    | "rated"            | Entry title + ★ score      |
| `:lens_liked`     | `Catalog.EntryLike` | "liked"            | Entry title                |

Each row carries the same relationship badge vocabulary as the Circle tab so a reader can tell at a glance which tie the author has to the viewer. `Social.list_feed/2` composes the four sources, filters the actor set via `list_my_people/2`, sorts newest-first, in-memory offset-paginates at 20 per page. New `ConflabWeb.Components.FeedItem` component with per-kind verb + payload (review title / star score), relative timestamps, link-to-entry on the Lens title.

PubSub reload covers Feed alongside Circle when social-graph edges change. A fifth `:run_shared` event kind is queued for v0.3.2 alongside ST0095.

**Final tab order:** Feed (default) · Circle · Discover · Pending.

### Instaflag admin tool

Admin-only one-click flag-and-hide workflow for catalog entries. Lands on the catalog entry action bar next to Report, visible only when the actor has `role in [:admin, :superadmin]`. Red-tinted button (`hero-shield-exclamation`) flashes + refreshes detail on success.

Backed by a new `:instaflag` action on `Conflab.Catalog.Entry`:

- Sets `moderation_status = :pending`.
- After-action change `Conflab.Catalog.Entry.Changes.RecordInstaflag` creates an audit `Flag` row with check-before-create so a prior Report-button flag does not trip the `[user_id, flaggable_id]` unique constraint.
- Policy: `forbid_if always()` (admin bypass at top covers the allowed path).
- Code interface: `Conflab.Catalog.instaflag_entry/2`.

**Admin moderation preview modal** at `/app/admin/moderation`. Entry-title click on Pending / Flagged tables opens an inline preview instead of routing to the (hidden) public entry page. Modal shows title / author / category / submitted date / moderation status badge / description / tags / full `EntryContent.body` preview; Approve + Reject + Cancel-reject + Close buttons inline; Reject expands a reason input within the modal; backdrop or X closes.

### Local-dev polish

- **Daemon-connected state.** `DaemonBridge.mount_assigns` default flipped to tri-state `nil` (unknown). `daemon_unreachable/1` replaced by a `daemon_bridge_status/1` dispatcher that renders nothing for `nil`/`true` and only shows the card on confirmed `false`. Client-side `daemon_bridge.js` got sessionStorage cache for `daemon_url` (skip re-probe on every LV remount, eager-verify at +100ms, invalidate on confirmed failure) and posts `connected: false` immediately on initial-discovery-all-fail (hysteresis is for mid-session flapping, not initial discovery).
- **Async mounts** on FlabsLive and CatalogLive so transitions feel instant.

## Changed

### Launcher toast polish

The Launcher's Flab it! and Lens-run completion flashes used to render inline above the Run form, breaking the destination-button row's layout. Both now route through a single bottom-anchored `ToastPayload` overlay on the Run window with auto-dismiss (2.5s for success, 4s for failure). One slot, two consumers.

### Polymorphic `flag_count` aggregate (fix)

`has_many :flags` on `Conflab.Catalog.Entry` and `Conflab.Catalog.Review` had `no_attributes? true`, which disabled Ash's automatic `entry.id == flag.flaggable_id` join on the polymorphic `catalog_flags` table. The `flag_count` aggregate computed `SELECT count(*) FROM catalog_flags WHERE flaggable_type = :entry` per row — identical global count for every entry. Latent until the Instaflag sweep created 71 flags; at that point every entry's `flag_count` jumped to 72 and `HideFlagged`'s `flag_count < 5` filter emptied the catalog.

Fix: replaced `no_attributes? true` with `filter expr(flaggable_type == :entry)` on the relationship itself (and `:review` on `Review`). No migration needed. Regression coverage added: `test/conflab/catalog/polymorphic_flag_count_test.exs` with 5 invariants.

### Registration-mode enforcement hardened

`/register` was reachable via `<.link patch>` from the sign-in page even when `registration_mode = :invite_only`. The existing `ConflabWeb.Plugs.RegistrationGate` plug only caught fresh HTTP hits, and patch-level navigation stays inside the live_session.

New `ConflabWeb.LiveRegistrationGate` attaches a `:handle_params` hook that catches patch-level navigation when `live_action == :register` and `registration_mode != :open`, flashes a mode-specific message, and redirects to `/sign-in`. Flash styling upgraded from a full-width banner to a top-right toast. Admin Settings rationalised: the redundant `registration_enabled` toggle is hidden — the Registration mode radio is the single source of truth.

**`:closed` semantics finalised.** Per product intent:

| Mode           | Open `/register`           | Mint new invites | Redeem existing invites |
| -------------- | -------------------------- | ---------------- | ----------------------- |
| `:open`        | allowed                    | allowed          | allowed                 |
| `:invite_only` | blocked (flash + redirect) | allowed          | allowed                 |
| `:closed`      | blocked (flash + redirect) | **blocked**      | allowed                 |

New `InviteCreationAllowed` validation on `UserInvite.create_invite` rejects mint under `:closed`. `RegistrationAllowed` validation updated so `:closed` still permits invite-bypass registration. Coverage: new `test/conflab_web/live/registration_gate_live_test.exs`, plus invite-freeze tests in `user_invite_test.exs`.

### Legacy `registration_enabled` key removed

Per the v0.3.0 deprecation notice, the old `registration_enabled` boolean no longer shadows `registration_mode`. The Registration-mode radio is the single source of truth.

### RuntimeConfig cache disabled in tests

Cache TTL set to 0 in test env. Tests must set flags via `RuntimeConfig.set/2`, not `:persistent_term.put`. The cache leaks across async tests; disabling it in test env is the clean fix.

## Fixed

- Daemon-connected state no longer flashes the unreachable card on every LV navigation. `DaemonBridge` cache + eager verify at +100ms replace the per-navigation re-probe.
- `FlabsLive` and `CatalogLive` mount async; transitions no longer block on initial data load.
- Polymorphic `flag_count` aggregate now correctly per-row (see Changed).
- `/register` patch-navigation bypass closed (see Changed).
- Clippy `new_without_default` on `LensRunner` silenced with a `Default` impl.

## Security

- `/register` now refuses patch-level navigation when `registration_mode != :open`, matching the plug-level gate at the HTTP boundary.
- `:closed` registration mode blocks minting new invites at the domain layer (`InviteCreationAllowed` validation on `UserInvite.create_invite`). Previously-minted invites still redeem cleanly.

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

Upgrading from v0.3.0: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading, restart the daemon:

```bash
conflab daemon restart
```

The daemon runs a v15 SQLite migration on first start after upgrade that renames the `workflow_executions` table to `runs`. Column-probe-guarded so existing run rows are preserved. If you have local Lua blocks that use the `conflab-workflow` syntax, they continue to work unchanged — the user-facing syntax was deliberately preserved.

No Ecto migrations in v0.3.1 (the ST0091 rename lives in daemon-side SQLite, not Postgres).

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
