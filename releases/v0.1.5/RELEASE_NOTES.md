# conflab v0.1.5

*Released 2026-03-02*

Native macOS app, prompt template engine, and programmable prompts with Lua.

## Conflab.app

A native macOS menubar application that puts conflabd at your fingertips. Built with pure AppKit and Swift 6.0 strict concurrency (no SwiftUI `MenuBarExtra` — it doesn't work reliably for `LSUIElement` apps).

- **Daemon control** — start, stop, and monitor conflabd from the menubar. Status is reflected in the icon.
- **Template browser** — browse `.cp.md` prompt templates from your templates directory with live preview.
- **Template compose** — fill in `{{variable}}` placeholders and delegate to your external editor for the final prompt.
- **MCP plugins** — view and manage registered MCP plugin servers.
- **Settings** — Auth tab for API key configuration.
- **About window** — version info with the Conflab logo.

The app is distributed as `Conflab.app.tar.gz` alongside the CLI and daemon binaries. The Homebrew formula installs it automatically to `/Applications`.

### CLI integration

New `conflab app` subcommands for managing the macOS app:

```bash
conflab app start     # launch Conflab.app
conflab app stop      # quit Conflab.app
conflab app status    # check if running
```

`conflab doctor` now includes a Conflab.app health check.

## Prompt Template Engine

A new `.cp.md` template format for reusable, parameterized prompts:

- **YAML frontmatter** — metadata (name, description, variables with defaults and descriptions)
- **`{{variable}}` interpolation** — Mustache-style placeholders replaced at compose time
- **Rust parser** — fast, streaming template parsing built into conflabd
- **Template directory** — templates are loaded from the user's configured templates path

### Template compose UX

The macOS app provides a graphical compose flow:

1. Browse available templates
2. Fill in variable values (with defaults pre-populated)
3. Preview the interpolated result
4. Delegate to an external editor for final editing and use

## Programmable Prompts (Lua)

Lua 5.4 is embedded in conflabd via mlua, enabling programmable prompt logic:

- **Sandboxed execution** — scripts run in a restricted environment with no filesystem or network access by default
- **Capability-gated** — the policy engine controls which Lua APIs are available to each script
- **Template integration** — Lua scripts can be invoked from templates for dynamic content generation

## Documentation

- User-facing template authoring guide covering the `.cp.md` format, frontmatter schema, and variable syntax
- Lua scripting reference documenting the sandbox environment, available APIs, and capability model

## CI and Distribution

- CI workflow builds Conflab.app as a `tar.gz` artifact alongside the CLI and daemon binaries
- Homebrew formula updated to include Conflab.app as a resource, installed to `/Applications`
- Three SHA256 hashes in the formula: CLI binary, daemon binary, and Conflab.app archive

## Upgrade

```bash
brew upgrade conflab
# or
curl -fsSL https://conflab.space/install.sh | bash
```
