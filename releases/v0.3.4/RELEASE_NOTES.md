# conflab v0.3.4

_Released 2026-04-28_

Patch release built on top of v0.3.3. Headline is **UI/UX Polish round (ST0099 WP-03..WP-09)** -- a themed seven-WP pass across the macOS Launcher, the Phoenix web Lens runner, the Flabs chat surface, and the Manage window. Notable user-facing changes: the **web Lens runner** now uses CodeMirror for `text` variables (was textareas; this also fixes a latent bug where text-editor variable values were silently lost on submit); **Lens tiles** wrap their titles instead of clipping; **Flabs chat** gains a textarea composer with Enter-send / Shift-Enter newlines / IME guard / auto-grow / caret-line-aware history navigation, plus a new **Clear flab messages** action under the kebab menu; the **Swift Launcher Run page** gets a `Running... / Done · 1.2s` status pill in the header and chevron-only disclosure (less chrome); a **⌥ (Option) key reveal** idiom now exposes tile shape ids, Run page shape names, the cog menu's Model picker and Rendered toggle, and the build stamp; the menubar gains a **Help** item; and twelve inline two-step destructive-confirm rows across the codebase now share a single canonical `<.confirm_action>` component with consistent labels (`Delete?` / `Delete` / `Cancel`) and `btn-error` styling.

## Added

### Web Lens runner: CodeMirror for `text` variables (ST0099/WP-03)

The Phoenix web Lens runner (`/app/lenses/...`) previously rendered `text` variable inputs as plain `<textarea>` elements. This release migrates them to CodeMirror via the existing `NotebookCellHook` -- the same wrapper the Workbench notebook cells use. One canonical CodeMirror hook, three modes:

- bare -> Workbench notebook cells (legacy, unchanged)
- `data-mirror-input="<id>"` -> Lens runner variable inputs (new, form-data flow)
- `data-readonly="true"` -> read-only preview surfaces (new, allocation-free)

A latent value-loss bug is fixed as a side effect: `texteditor` and `texteditor+files` Lens-runner variables previously had their values silently dropped on submit because the hooked div had no `name=` attribute and the form's `update-var` phx-change handler only saw form-serialised data. The new **hidden-input mirror pattern** puts a sibling `<input type="hidden" name={field}>` next to the editor; the hook updates its `.value` AND dispatches a bubbling `input` event so phx-change fires correctly.

The Swift Launcher Run page already used `CodeMirror_SwiftUI` for the same variable types; this WP brings the web side to parity.

### Lens tile title wrap (ST0099/WP-04)

Lens tiles in the Swift Launcher and across all three Phoenix web tile sites (`dir_tile`, `lens_tile`, `theme_tile`) now wrap their titles instead of clipping at two lines. Tile heights grow vertically as needed; the row aligns to the tallest tile (SwiftUI `LazyVGrid` default; Tailwind grid behaviour matches).

### Flabs chat overhaul + Clear flab messages (ST0099/WP-05)

The Flabs chat surface gets a bounded redesign pass plus a new domain action.

**Domain: `Conflab.Collaboration.clear_flab_messages/2`** -- a new `update :clear_messages` action on Flab that empties the message stream while keeping the flab, its participants, and its tasks intact. Implemented as an Ash `update` action with an `after_action` change running `Ash.bulk_destroy` against the flab's messages with `notify?: false` (suppresses the per-message broadcast firehose that would otherwise flood every connected tab). One consolidated `messages_cleared` PubSub event fires on `"flab:#{id}"` topic on success; cross-tab participants see their stream reset live. Authorisation: creator and owner/admin participants can clear; member participants and non-participants are forbidden; archived flabs cannot be cleared.

**UI: kebab menu gains Clear** between Details and Delete with a two-step confirm row matching its Delete sibling (red `btn-error` confirm + ghost cancel).

**Composer: textarea instead of single-line input.**

- Enter sends; Shift-Enter inserts a newline.
- IME composition (Japanese / Chinese / Korean input methods) does NOT submit on Enter -- guarded via `event.isComposing` AND `event.keyCode === 229` (belt-and-braces; modern browsers expose `isComposing`, legacy Safari paths only set `keyCode === 229`).
- Auto-grows up to 6 lines (`max-h-32`); collapses back to one line on submit.
- History up/down navigation (existing feature) is now caret-line-aware: only navigates when the caret is on the first line (ArrowUp) or last line (ArrowDown), so multi-line composition is not hijacked.
- Form `requestSubmit()` triggers the same submit-event lifecycle as a button click, so phx-submit fires correctly.

**Bubble density: `chat-bubble-sm` with inline `·`-separated timestamp** alongside the author name (was a separate footer line).

**Header: participant count next to the flab name** with singular/plural agreement ("1 participant" / "2 participants").

### Swift Launcher Run page chrome trim (ST0099/WP-06)

The Run page header now carries a **`RunStatusPill`** -- a Capsule pill that displays:

- `idle` -> hidden (no clutter on a fresh form)
- `running` -> `Running...` (animated)
- `complete` -> `Done · 1.2s` (elapsed time)
- under ⌥ -> tokens count appended (technical detail; hidden by default)
- `error` -> `Error · <reason>`

The result-card footer keeps the canonical full-detail line (tokens-per-second, model, etc.); the header pill is the glance affordance.

The Lens-details disclosure used to read `Hide Lens details` / `Show Lens details` next to a chevron. This release drops the text label -- chevron alone in a 22x22 hit target with a `.help(...)` tooltip explaining the action. Less chrome; macOS-native idiom.

### ⌥ (Option) key reveal across the Launcher (ST0099/WP-07)

Holding **⌥ Option** on the macOS Launcher reveals power-user details that are hidden by default:

- **Tile shape ids** -- `json_schema_generic`, `markdown_chat_message`, etc.
- **Run page shape name** in the header next to the title.
- **Cog menu** -- the Model picker and the `Rendered` toggle (both gated on ⌥; `Open in Workbench` stays visible because Charlie's escape hatch is not power-user territory).
- **Build stamp** in the launcher's top-right corner.
- **`RunStatusPill` tokens count** (see above).

Implementation: one canonical `OptionKeyMonitor.shared` (Highlander) wrapping a single `NSEvent.addLocalMonitorForEvents(matching: .flagsChanged)` listener for the entire app. SwiftUI bodies that read `OptionKeyMonitor.shared.isPressed` re-render automatically via Observation. Adding a private listener for ⌥-gated behaviour anywhere is an explicit regression.

### Help menu item in the macOS menubar (ST0099/WP-08)

The Conflab.app menubar gains a **Conflab Help** item between `Open Conflab` and `Quit`. On click it opens `<server>/app/help` in the user's default browser. Server URL resolves via `ConflabConfig.resolvedServerBaseURL(fallback:)` (new Highlander; defaults to `https://conflab.space`, falls back to the active CLI profile's server URL if set). Both `openConflab` and `showHelp` consume from this one accessor -- no more inline `?? "http://localhost:4000"` fallbacks.

### Canonical `<.confirm_action>` component (ST0099/WP-09)

The Phoenix web layer had ten-plus drifting inline two-step destructive-confirm rows across Flabs, Lenses, Shapes, Catalog entries, Runs, Agent settings, Account settings, and the API key manager. Labels diverged ("Yes" / "No" / "Confirm" / "Are you sure?"), prompts came and went, and one site recently landed orange `btn-warning` instead of red `btn-error` for a Clear action.

This release extracts a single canonical component:

```heex
<.confirm_action :if={@confirm_delete}
  id={"confirm-delete-thing-#{thing.id}"}
  verb="Delete"
  on_confirm="delete_thing"
  on_cancel="cancel_delete"
  value_id={thing.id}
/>
```

Twelve sites migrated. The visual contract is now:

- prompt = `{verb}?` (e.g. `Delete?`, `Clear?`, `Revoke?`).
- confirm button = `{verb}` with `btn-error` styling.
- cancel button = `Cancel` with `btn-ghost` styling.
- size = xs by default; sm for danger-zone surfaces (Account / Agent delete).

Out of scope and left as-is: multi-field rejection-reason forms (admin moderation), full-page card-style confirmation dialogs (cycle daemon token), and browser-native `data-confirm="..."` attributes (Run Abort) -- different shapes, different WPs.

## Changed

### Oban 2.22.0 + migration v14

`mix.lock` bumps Oban from 2.21.1 to 2.22.0. The new version introduces migration v14; the app refuses to boot with `Oban migrations are outdated` until it is applied. After upgrading, run:

```bash
mix ash.migrate
MIX_ENV=test mix ash.migrate
```

(Always `mix ash.migrate` for Ash projects; never `mix ecto.migrate`.)

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

Upgrading from v0.3.3: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading:

```bash
mix ash.migrate          # apply the Oban v14 migration (Elixir users only)
conflab daemon restart   # pick up the daemon binary
```

No breaking changes. The ST0105 daemon agent-auth migration from v0.3.2 still applies to anyone upgrading from before v0.3.2 -- see v0.3.2 release notes for the recovery flow.

Full changelog: [CHANGELOG.md](https://github.com/geodica/conflab-dist/blob/main/CHANGELOG.md)
