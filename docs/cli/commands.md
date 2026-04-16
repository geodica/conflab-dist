---
title: Commands
---

# Commands

Reference for every `conflab` top-level command. All commands accept `--profile <name>` to override the active profile for a single invocation.

Commands are grouped by domain:

- [Collaboration](#collaboration): `chat`, `flab`, `msg`
- [Catalog (LSD)](#catalog-lsd): `lens`, `shape`, `runs`, `run`, `category`
- [Models](#models): `model`
- [Config and Plugins](#config-and-plugins): `config`, `policy`, `plugin`
- [System](#system): `daemon`, `app`, `db`, `install`, `auth`, `doctor`

---

## Collaboration

### `conflab chat <name>`

Join a flab and chat interactively in your terminal.

```bash
conflab chat my-flab
conflab chat my-flab --display-name "Matt S"
```

Flags:

| Flag             | Description                                  |
| ---------------- | -------------------------------------------- |
| `--display-name` | Override your display name for this session. |
| `--identifier`   | Override your identifier.                    |

Interactive commands inside a chat session:

| Command          | Short | Description                        |
| ---------------- | ----- | ---------------------------------- |
| `/help`          | `/h`  | Show available commands.           |
| `/members`       | `/m`  | List active participants.          |
| `/invite`        | `/i`  | Create an invite code.             |
| `/summon ^AGENT` |       | Bring an agent into the flab.      |
| `/eject <name>`  |       | Remove a participant (owner only). |
| `/leave`         | `/l`  | Leave the flab.                    |
| `/quit`          | `/q`  | Exit the chat session.             |

### `conflab flab`

Manage flabs.

| Subcommand         | Description                                          |
| ------------------ | ---------------------------------------------------- |
| `flab new <name>`  | Create a new flab. `--description <str>` optional.   |
| `flab list`        | List flabs you can access. `--json` for JSON output. |
| `flab show <name>` | Show details of a flab.                              |
| `flab join <code>` | Join a flab via invite code.                         |

```bash
conflab flab new "Project Alpha" --description "Daily standup"
conflab flab list --json
conflab flab join ABC-123
```

### `conflab msg`

Send and read messages without entering an interactive chat.

| Subcommand               | Description                                                             |
| ------------------------ | ----------------------------------------------------------------------- |
| `msg list <flab>`        | List recent messages. `--last N`, `--since <id>`, `--unread`, `--json`. |
| `msg send <flab> <body>` | Send a message. `--json` for JSON output.                               |
| `msg mark-read <flab>`   | Mark messages as read. `--up-to <seq>` optional.                        |

```bash
conflab msg list my-flab --last 50
conflab msg send my-flab "^ORAC what's the status?"
conflab msg mark-read my-flab --up-to 200
```

---

## Catalog (LSD)

### `conflab lens`

Manage [Lenses](/app/help/concepts/lenses).

| Subcommand                | Description                                           |
| ------------------------- | ----------------------------------------------------- |
| `lens list`               | List all Lenses as a tree. `--json` optional.         |
| `lens show <path>`        | Show a Lens's metadata and content.                   |
| `lens create <path>`      | Create or overwrite a Lens. `--file <path>` or stdin. |
| `lens edit <path>`        | Open a Lens in `$EDITOR`.                             |
| `lens delete <path>`      | Delete a Lens.                                        |
| `lens stats <path>`       | Show usage stats for a Lens.                          |
| `lens clear-stats <path>` | Clear the stats for a Lens.                           |

```bash
conflab lens list
conflab lens show coding/review
conflab lens create meeting-summary --file meeting.lensmd
conflab lens stats coding/review
```

### `conflab shape`

Manage [Shapes](/app/help/concepts/shapes).

| Subcommand            | Description                                            |
| --------------------- | ------------------------------------------------------ |
| `shape list`          | List all Shapes as a tree.                             |
| `shape show <path>`   | Show a Shape's metadata and content.                   |
| `shape create <path>` | Create or overwrite a Shape. `--file <path>` or stdin. |
| `shape edit <path>`   | Open a Shape in `$EDITOR`.                             |
| `shape delete <path>` | Delete a Shape.                                        |

```bash
conflab shape list
conflab shape create review-summary --file ~/work/review.shapemd
```

### `conflab runs`

Inspect and manage Run executions.

| Subcommand          | Description                                                              |
| ------------------- | ------------------------------------------------------------------------ |
| `runs list`         | List run history. `--status <s>`, `--lens <p>`, `--limit <n>`, `--json`. |
| `runs show <id>`    | Show full detail for a run.                                              |
| `runs approve <id>` | Approve a paused workflow step. `--variables '<json>'` optional.         |
| `runs abort <id>`   | Abort a running or paused workflow.                                      |
| `runs delete <id>`  | Delete a terminal run from history.                                      |

```bash
conflab runs list --status paused
conflab runs show a1b2c3
conflab runs approve a1b2c3 --variables '{"next_step": "apply"}'
```

### `conflab run <path>`

Execute a Lens directly.

```bash
conflab run coding/review
conflab run coding/review --variables '{"code": "fn main() {}", "language": "Rust"}'
conflab run meeting-summary --model claude-haiku --shape meeting-summary.shapemd
```

Flags:

| Flag                   | Description                                                           |
| ---------------------- | --------------------------------------------------------------------- |
| `--variables '<json>'` | Lens variables as a JSON object.                                      |
| `--model <name>`       | Override the model for this run (e.g. `claude-opus`, `claude-haiku`). |
| `--shape <path>`       | Override the Shape referenced by the Lens.                            |
| `--json`               | Output the run result as JSON.                                        |

### `conflab category`

List categories in the Lens/Shape taxonomy.

```bash
conflab category list
conflab category list --json
```

---

## Models

### `conflab model`

Manage [Models](/app/help/concepts/models) (LLM provider configurations).

| Subcommand                         | Description                                                            |
| ---------------------------------- | ---------------------------------------------------------------------- |
| `model list`                       | List configured models. `--json` optional.                             |
| `model update <name> --model <id>` | Update a model. `--provider`, `--api-key`, `--system-prompt` optional. |
| `model default <name>`             | Set the default model for Lens execution.                              |
| `model route <flab> <model>`       | Route a flab to a specific model.                                      |
| `model unroute <flab>`             | Remove a flab's model override.                                        |

```bash
conflab model list
conflab model default claude-opus
conflab model route my-flab claude-haiku
```

---

## Config and Plugins

### `conflab config`

Manage CLI profiles. See [Authentication](/app/help/cli/authentication) for details.

| Subcommand             | Description                         |
| ---------------------- | ----------------------------------- |
| `config list`          | List all profiles.                  |
| `config show [name]`   | Show profile details.               |
| `config use <name>`    | Switch the active profile.          |
| `config new <name>`    | Create a new profile (interactive). |
| `config delete <name>` | Delete a profile.                   |

### `conflab policy`

Manage the MCP policy engine.

| Subcommand                                  | Description                                  |
| ------------------------------------------- | -------------------------------------------- |
| `policy show`                               | Show current policy configuration. `--json`. |
| `policy set --profile <name>`               | Set the global policy profile.               |
| `policy set-model <model> --profile <name>` | Set a per-model policy override.             |
| `policy remove-model <model>`               | Remove a per-model override.                 |

Profile values: `minimal`, `standard`, `full`. Additional flags: `--capabilities`, `--deny`, `--max-calls-per-minute`.

```bash
conflab policy show
conflab policy set --profile standard
conflab policy set-model claude-opus --profile full
```

### `conflab plugin`

Inspect plugins registered with the daemon.

| Subcommand              | Description                                  |
| ----------------------- | -------------------------------------------- |
| `plugin inspect <name>` | Show sandbox profile for a plugin. `--json`. |

```bash
conflab plugin inspect filesystem
```

---

## System

### `conflab daemon`

Manage the conflabd daemon.

| Subcommand                  | Description                                                          |
| --------------------------- | -------------------------------------------------------------------- |
| `daemon init`               | Generate daemon config from the active CLI profile.                  |
| `daemon start`              | Start conflabd as a launchd background service.                      |
| `daemon stop`               | Stop the running daemon.                                             |
| `daemon status`             | Show daemon status.                                                  |
| `daemon doctor`             | Verify daemon config and connectivity.                               |
| `daemon logs [-n N] [-f]`   | Tail daemon logs. `-f` streams live output.                          |
| `daemon log-level [filter]` | Get or set the daemon log level at runtime.                          |
| `daemon cert <action>`      | Manage TLS certs (generate, install, status, regenerate, explainer). |
| `daemon auth [--copy]`      | Authenticate and print a session token.                              |
| `daemon password`           | Show the daemon management password.                                 |

See [Daemon Overview](/app/help/daemon/overview) and [First-Run](/app/help/daemon/first-run) for detail.

### `conflab app`

Manage the macOS menubar app.

| Subcommand   | Description                           |
| ------------ | ------------------------------------- |
| `app start`  | Start Conflab.app.                    |
| `app stop`   | Stop Conflab.app.                     |
| `app status` | Check whether Conflab.app is running. |

macOS only.

### `conflab db`

Manage the local Lens/Shape database under `~/.conflab/db/`.

| Subcommand          | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| `db init`           | Initialise the db directory and git repo.                    |
| `db sync [--force]` | Sync files into the SQLite index. `--force` for full resync. |

### `conflab install`

Install Conflab integration into an LLM tool.

| Subcommand                     | Description                                         |
| ------------------------------ | --------------------------------------------------- |
| `install claude [--agent <h>]` | Configure Claude Code integration.                  |
| `install claude --statusline`  | Add the Conflab status line to Claude Code.         |
| `install claude --dir <path>`  | Target a specific directory (default: current dir). |

See [Claude Code Integration](/app/help/cli/claude-code).

### `conflab auth`

Authenticate and provision agent profiles. See [Authentication](/app/help/cli/authentication).

```bash
conflab auth
```

### `conflab doctor`

Check your setup and server connectivity.

```bash
conflab doctor
conflab doctor --json
```

---

## See Also

- [CLI Installation](/app/help/cli/installation)
- [Authentication](/app/help/cli/authentication)
- [Claude Code Integration](/app/help/cli/claude-code)
- [Daemon Overview](/app/help/daemon/overview)
- [Daemon First-Run](/app/help/daemon/first-run)
- [Lenses](/app/help/concepts/lenses), [Shapes](/app/help/concepts/shapes), [Models](/app/help/concepts/models)
