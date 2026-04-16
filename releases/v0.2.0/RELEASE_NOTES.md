# conflab v0.2.0

_Released 2026-04-15_

First minor release. Ships the public Lens/Shape/Prompt Directory, a curated launch catalog, public unauthenticated browse, Atom feeds, full daemon API coverage on CLI and MCP, Admin 2.0, Dashboard 2.0, UGC moderation, macOS first-run CA trust UX, a signed and notarised macOS installer with first-run wizard, the AGENT→MODEL terminology rename, and a complete documentation refresh.

## Added

### Catalog and content

- **Public Lens/Shape/Prompt Directory (LSD)** -- end-to-end catalog at `/app/lsd` and public `/lsd`: browse, detail pages, tags, categories, ratings, reviews, fork lineage, local↔catalog sync, and publish/import flows with provenance.
- **Launch content pipeline** -- pluggable crawler with five source adapters, Oban job + mix task entry points, classify/dedup/admit/elaborate stages. 40 hand-authored Lenses plus 1,700 attributed Prompt entries ship out of the box.
- **Attribution and compliance policy** -- canonical policy page at `/policy/attribution`. Crawlers honour robots.txt and per-site ToS.
- **Public unauthenticated LSD browse** -- catalog discovery without signing in. Entry bodies gated behind a "Sign in to view" CTA.
- **Per-category README tab** -- explains what each of the 12 lens categories is for.

### Feeds and discovery

- **Atom feeds** -- Atom 1.0 feeds at `/feeds/all.atom`, `/feeds/lenses.atom`, `/feeds/themes.atom`, `/feeds/prompts.atom`, and `/feeds/category/{slug}.atom`. `<link rel="alternate">` discovery in page heads. HTML index at `/feeds`.

### Daemon coverage

- **Full daemon API on CLI** -- 48 daemon GraphQL operations now reachable from `conflab`.
- **Full daemon API on MCP** -- 18 new MCP tools covering lens/shape/run/agent/category management.
- **Filesystem watcher** -- conflabd watches `~/.conflab/db/` and syncs external edits automatically.

### Admin and user surfaces

- **Admin 2.0** -- sectioned admin console: Overview, Users, Curation, Moderation, Settings, Crawl.
- **Dashboard 2.0** -- personal platform-wide dashboard at `/app` with next-best-action cards.
- **UGC moderation** -- Flag buttons on reviews and entries, auto-hide at threshold, admin moderation queue, published-lens pending state with trusted-author auto-approval, per-user rate limits.

### macOS app

- **First-run CA trust UX** -- menubar first-run dialog, dedicated CA Trust settings tab, `TrustInstallService` in Swift with 9 unit tests.
- **`conflab doctor --json`** -- machine-readable doctor output.
- **`conflab daemon cert install --plain`** -- tty-friendly CA install explainer.

### macOS installer

- **Signed + notarised `.pkg`** -- double-click `Conflab-arm64.pkg` installs Conflab.app, `conflab`, `conflabd`, and a per-user LaunchAgent. Gatekeeper-silent on a clean Mac. Download from [conflab.space/download/mac](https://conflab.space/download/mac).
- **First-run setup wizard** -- Conflab.app auto-launches after install. Walks the user through sign-in (verified against the server before saving), Conflab Local CA install, and daemon start. No terminal required.
- **`conflab install setup`** -- CLI command backing the wizard with `--bundle`, `--dump-current`, `--interactive` modes.
- **`conflab uninstall`** -- plan-then-execute uninstall with `--dry-run`, `--yes`, and `--nuke-data`. Quits the menubar app, unloads the LaunchAgent, removes binaries and `pkgutil` receipts; preserves `~/.conflab/` by default.
- **Homebrew cask** -- `brew install --cask geodica/conflab/conflab` wraps the signed installer. Coexists with the CLI-only formula; `/usr/local/bin` takes precedence on PATH.
- **Shell `install.sh --with-app`** -- downloads and launches the `.pkg` from the shell-script entry point for a single-command install.
- **Daemon-bridge health hysteresis** -- three consecutive health failures required before flipping the browser UI to "Daemon Unreachable"; one success flips back.

### Homepage and docs

- **Homepage refresh** -- covers all five pillars (Flabs, Programmable Prompts, Promptable Problems, LSD, Research).
- **Help landing page** -- `/app/help` renders a hero-icon landing page.
- **33 user-facing docs refreshed** across Concepts, Getting Started, Using Conflab, CLI, Daemon, and Admin.

## Changed

- **AGENT vs MODEL rename** -- the LLM-provider sense of "Agent" is now "Model". Vocabulary-breaking for external integrations. Conflab chat participants remain Agents.
- Swift codebase reformatted to 2-space indent.

## Fixed

- conflabd MCP auth: OAuth 2.0 discovery + PKCE flow.
- Classifier cache resilience during catalog crawls.
- Daemon `clear-stats` handler shadowed by a catch-all.
- Review owner attribution corrected.
- Stale help-index redirect test.

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

Upgrading from v0.1.x: `brew upgrade --cask conflab` (cask), `brew upgrade conflab` (formula), or re-run the installer / shell script. After upgrading, restart the daemon:

```bash
conflab daemon stop && conflab daemon start
```

The filesystem watcher will begin syncing external edits to `~/.conflab/db/` automatically. If you don't have an existing database, run:

```bash
conflab db init
conflab db sync
```

### Breaking change: Agent vs Model

The LLM-provider sense of "Agent" has been renamed to "Model" everywhere. If you have external scripts or integrations that referenced the old `Agent` configuration or API surface for LLM providers, update them to use `Model`. Conflab chat participants (`^ORAC`, `^NEXUS`, etc.) remain Agents.
