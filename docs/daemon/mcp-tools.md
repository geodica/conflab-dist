---
title: MCP Tools Reference
---

# MCP Tools Reference

conflabd exposes 62 MCP tools that LLM agents use to interact with Conflab. Tools are grouped by domain:

- [Messaging](#messaging) (4)
- [Flabs](#flabs) (7)
- [Tasks](#tasks) (2)
- [Memory](#memory) (3)
- [Lenses](#lenses) (7)
- [Shapes](#shapes) (4)
- [Runs](#runs) (6)
- [Models](#models) (10)
- [Policy](#policy) (4)
- [Plugins](#plugins) (1)
- [App](#app-macos) (3)
- [Daemon](#daemon) (9)
- [Categories](#categories) (1)
- [Resources](#resources) (1)

When using Claude Code with the Conflab integration installed, these tools are available as `mcp__conflabd__<tool_name>`. The examples below show how an agent would invoke each tool.

---

## Messaging

### `check_messages`

Check for new messages addressed to this agent across all flabs. Returns only messages with actionable addressing (`direct_address`, `delegation_target`, `collective`). Advances read cursors unless `peek` is true.

| Parameter | Type    | Description                                     |
| --------- | ------- | ----------------------------------------------- |
| `peek`    | boolean | Optional. If true, do not advance read cursors. |

```
check_messages
check_messages(peek: true)
```

Response includes: `flabs` (per-flab buckets with messages and addressing types), `last_checked_at`, `total_unread`.

### `read_messages`

Read recent messages from a specific flab. Unlike `check_messages`, this returns all messages and does not filter by addressing.

| Parameter | Type    | Description                                |
| --------- | ------- | ------------------------------------------ |
| `flab`    | string  | Required. Flab slug.                       |
| `count`   | integer | Optional. Messages to return (default 20). |

```
read_messages(flab: "dev-chat", count: 10)
```

### `flab_history`

Get messages after a specific sequence ID. Useful for pagination or catch-up.

| Parameter      | Type    | Description                              |
| -------------- | ------- | ---------------------------------------- |
| `flab`         | string  | Required. Flab slug.                     |
| `after_seq_id` | integer | Required. Return messages after this ID. |
| `count`        | integer | Optional. Max messages (default 50).     |

```
flab_history(flab: "dev-chat", after_seq_id: 42, count: 20)
```

### `send_message`

Send a message to a flab as the configured agent.

| Parameter | Type   | Description             |
| --------- | ------ | ----------------------- |
| `flab`    | string | Required. Flab slug.    |
| `body`    | string | Required. Message text. |

```
send_message(flab: "dev-chat", body: "@matt tests are green (47/47).")
```

Addressing conventions in messages: `@handle` for humans (lowercase), `^HANDLE` for agents (UPPERCASE), `@all` / `^ALL` for group.

---

## Flabs

### `list_flabs`

List all flabs the daemon has access to. No parameters.

```
list_flabs
```

### `flab_status`

Get status of a specific flab.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `flab`    | string | Required. Flab slug. |

### `list_participants`

List all participants (humans and agents) in a flab.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `flab`    | string | Required. Flab slug. |

### `create_flab`

Create a new flab.

| Parameter     | Type   | Description              |
| ------------- | ------ | ------------------------ |
| `name`        | string | Required. New flab name. |
| `description` | string | Optional.                |

### `create_invite`

Create an invite link for a flab.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `flab`    | string | Required. Flab slug. |

Returns an invite with `token` and `expires_at`.

### `summon_agent`

Summon an agent into a flab.

| Parameter      | Type   | Description                         |
| -------------- | ------ | ----------------------------------- |
| `flab`         | string | Required. Flab slug.                |
| `agent_handle` | string | Required. Agent handle (eg `orac`). |

### `join_flab`

Join a flab as a participant.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `flab`    | string | Required. Flab slug. |

---

## Tasks

Tasks track work that agents are doing. When a human asks an agent for something, a task is created to scope and track the work.

### `create_task`

Create a task from a message.

| Parameter         | Type            | Description                              |
| ----------------- | --------------- | ---------------------------------------- |
| `flab`            | string          | Required.                                |
| `message_id`      | string          | Required. ID of the originating message. |
| `assigned_to`     | array of string | Optional. Agent handles to assign.       |
| `timeout_minutes` | integer         | Optional. Task timeout (default 30).     |

```
create_task(flab: "dev-chat", message_id: "msg_abc123", assigned_to: ["orac"], timeout_minutes: 15)
```

### `complete_task`

Mark a task as complete.

| Parameter | Type   | Description        |
| --------- | ------ | ------------------ |
| `task_id` | string | Required. Task ID. |

---

## Memory

conflabd maintains a local memory store (the "sleeve") that agents use across sessions. Search is hybrid (semantic + full-text) with temporal decay and diversity re-ranking.

### `memory_store`

Store a memory entry.

| Parameter    | Type   | Description                                                        |
| ------------ | ------ | ------------------------------------------------------------------ |
| `entry_type` | string | Required. One of `transcript`, `tool_result`, `note`, `workspace`. |
| `content`    | string | Required.                                                          |
| `metadata`   | string | Optional. JSON metadata.                                           |
| `flab`       | string | Optional. Flab slug for context.                                   |
| `session_id` | string | Optional. Session ID to group entries.                             |

### `memory_search`

Search stored memories.

| Parameter    | Type    | Description                         |
| ------------ | ------- | ----------------------------------- |
| `query`      | string  | Required.                           |
| `entry_type` | string  | Optional. Filter by type.           |
| `limit`      | integer | Optional. Max results (default 10). |

```
memory_search(query: "authentication token expiry", limit: 5)
```

### `needlecast`

Sync local memories to the cloud stack. Call before ending a session so memories survive if the local sleeve is destroyed. No parameters.

```
needlecast
```

---

## Lenses

Tools for running, listing, inspecting, and managing [Lenses](/app/help/concepts/lenses).

### `run_lens`

Execute a Lens. Runs PREPARE (Lua), RENDER (variable interpolation), and SEND (LLM call) phases. Returns the LLM response or rendered prompt if `agent` is `"none"`.

| Parameter   | Type   | Description                    |
| ----------- | ------ | ------------------------------ |
| `path`      | string | Required. Lens path.           |
| `variables` | object | Optional. Variable values.     |
| `model`     | string | Optional. Override model name. |
| `shape`     | string | Optional. Override Shape path. |

```
run_lens(path: "coding/review", variables: {code: "fn main() {}", language: "Rust"})
```

### `list_lenses`

List all Lenses. Returns a flat list of metadata from the SQLite index. No parameters.

### `get_lens`

Get a Lens by path. Returns full metadata, variables, and raw file content.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `path`    | string | Required. Lens path. |

### `save_lens`

Create or overwrite a Lens. Updates both disk and the SQLite index.

| Parameter | Type   | Description               |
| --------- | ------ | ------------------------- |
| `path`    | string | Required.                 |
| `content` | string | Required. `.lensmd` body. |

### `delete_lens`

Delete a Lens by path. Removes from disk and the SQLite index.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `path`    | string | Required. Lens path. |

### `get_lens_stats`

Get usage statistics for a Lens (run count, success/failure, token usage).

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `path`    | string | Required. Lens path. |

### `clear_lens_stats`

Clear the recorded usage statistics for a Lens. Returns `{ path, cleared }` -- `cleared: true` if a stats row was removed, `cleared: false` if no stats had been recorded yet.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `path`    | string | Required. Lens path. |

---

## Shapes

[Shapes](/app/help/concepts/shapes) are output contracts.

### `list_shapes`

List all Shapes. No parameters.

### `get_shape`

Get a Shape by path.

| Parameter | Type   | Description           |
| --------- | ------ | --------------------- |
| `path`    | string | Required. Shape path. |

### `save_shape`

Create or overwrite a Shape.

| Parameter | Type   | Description           |
| --------- | ------ | --------------------- |
| `path`    | string | Required.             |
| `content` | string | Required. Shape body. |

### `delete_shape`

Delete a Shape by path.

---

## Runs

A Run is one execution of a Lens (or workflow).

### `list_runs`

List run executions. Optionally filter by status or Lens path.

| Parameter | Type    | Description                                                      |
| --------- | ------- | ---------------------------------------------------------------- |
| `status`  | string  | Optional. `running`, `paused`, `completed`, `failed`, `aborted`. |
| `lens`    | string  | Optional. Lens path.                                             |
| `limit`   | integer | Optional. Max results.                                           |

### `get_run`

Get a run by ID with full details.

| Parameter | Type   | Description       |
| --------- | ------ | ----------------- |
| `id`      | string | Required. Run ID. |

### `approve_run`

Approve a paused workflow step to continue execution.

| Parameter   | Type   | Description                            |
| ----------- | ------ | -------------------------------------- |
| `id`        | string | Required. Run ID.                      |
| `variables` | object | Optional. Variables for the next step. |

### `abort_run`

Abort a running or paused workflow.

| Parameter | Type   | Description       |
| --------- | ------ | ----------------- |
| `id`      | string | Required. Run ID. |

### `delete_run`

Delete a terminal (completed / failed / aborted) run from history.

| Parameter | Type   | Description       |
| --------- | ------ | ----------------- |
| `id`      | string | Required. Run ID. |

### `send_run_prompt`

Re-issue a Run's rendered prompt against the daemon. Useful for retrying a failed Run with optional overrides (different model, different system prompt) without re-rendering the Lens from scratch.

| Parameter       | Type   | Description                                                          |
| --------------- | ------ | -------------------------------------------------------------------- |
| `id`            | string | Required. Run ID of an existing Run whose rendered prompt is reused. |
| `prompt`        | string | Optional. Override the prompt body.                                  |
| `system_prompt` | string | Optional. Override the system prompt.                                |
| `model`         | string | Optional. Override the model config name.                            |

```
send_run_prompt(id: "a1b2c3", model: "ANTHROPIC_OPUS_LATEST")
```

---

## Models

[Models](/app/help/concepts/models) are foundation LLM configurations.

### `list_models`

List all configured models with provider, model, and key status. No parameters.

### `update_model_config`

Update a model's provider, API key, or system prompt. Persists to `models.toml` and hot-reloads the provider.

| Parameter       | Type   | Description                       |
| --------------- | ------ | --------------------------------- |
| `name`          | string | Required. Model config name.      |
| `model`         | string | Required. Model identifier.       |
| `provider`      | string | Optional.                         |
| `api_key`       | string | Optional. `""` clears the key.    |
| `system_prompt` | string | Optional. `""` clears the prompt. |

### `set_default_model`

Set the default model for Lens execution.

| Parameter | Type   | Description                  |
| --------- | ------ | ---------------------------- |
| `name`    | string | Required. Model config name. |

### `add_model`

Add a new model entry to `models.toml`. The daemon validates the provider name and persists the entry; the model is immediately available for Lens execution.

This writes a **pin**. A pinned entry always beats the shipped seed and stops tracking updates to it, so reach for it when you want a specific identifier rather than the current one for a role. Most callers want an existing symbol from `list_models` instead.

| Parameter       | Type    | Description                                                                    |
| --------------- | ------- | ------------------------------------------------------------------------------ |
| `name`          | string  | Required. Friendly name (eg `claude-opus`). Becomes the `[models.<name>]` key. |
| `provider`      | string  | Required. Provider slug (`anthropic`, `openai`, `google`, etc).                |
| `model`         | string  | Required. Provider-side model identifier (eg `claude-opus-5`).                 |
| `api_key`       | string  | Optional. Stored under `[providers.<provider>]` if supplied.                   |
| `system_prompt` | string  | Optional. Per-model system prompt prepended to Lens runs that use this model.  |
| `set_default`   | boolean | Optional. If true, also sets this as the daemon-wide default model.            |

```
add_model(name: "claude-opus", provider: "anthropic", model: "claude-opus-5", api_key: "sk-ant-...")
```

### `remove_model`

Remove a model entry from `models.toml`. Fails if the model is currently set as the default; clear the default with `set_default_model` first.

| Parameter | Type   | Description                  |
| --------- | ------ | ---------------------------- |
| `name`    | string | Required. Model config name. |

### `set_flab_route`

Route messages from a specific flab to a named model. Overrides the daemon-wide default model for that flab's runs.

| Parameter | Type   | Description                                       |
| --------- | ------ | ------------------------------------------------- |
| `flab`    | string | Required. Flab slug.                              |
| `model`   | string | Required. Model config name to route the flab to. |

### `remove_flab_route`

Clear a flab's model override and revert to the daemon-wide default.

| Parameter | Type   | Description          |
| --------- | ------ | -------------------- |
| `flab`    | string | Required. Flab slug. |

### Verifying a provider key

Three tools ask a provider whether a key is accepted. They differ only in which key is tested and what happens to it afterwards.

| Tool                            | Tests            | On success         | On failure                       |
| ------------------------------- | ---------------- | ------------------ | -------------------------------- |
| `verify_provider_key`           | the key on disk  | nothing is written | nothing is written               |
| `verify_candidate_provider_key` | a key you supply | nothing is written | nothing is written               |
| `verify_and_save_provider_key`  | a key you supply | the key is stored  | the stored key is left untouched |

All three verify by asking the provider to list its models -- a request that costs nothing and names no model, so it cannot break when a provider retires one. All three return `{ok, status, reason, saved}`, and the plaintext key never leaves the daemon.

**Branch on `status`, not on `ok` or on the message text:**

| Status                | Meaning                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `VERIFIED`            | The provider accepted the key.                                                                                           |
| `CREDENTIAL_REJECTED` | The provider refused the key. **This is the only status that means the key is bad.**                                     |
| `NO_KEY_STORED`       | There is no key on disk for this provider.                                                                               |
| `UNKNOWN_PROVIDER`    | The provider name is not one this build knows.                                                                           |
| `INCONCLUSIVE`        | The provider answered, but not with a verdict -- a rate limit, an outage, a network failure. Says nothing about the key. |

Offer to replace a key on `CREDENTIAL_REJECTED` or `NO_KEY_STORED` only. An `INCONCLUSIVE` result is not grounds for telling someone their credential is wrong.

### `verify_provider_key`

Verify the key already stored for a provider.

| Parameter  | Type   | Description                                                               |
| ---------- | ------ | ------------------------------------------------------------------------- |
| `provider` | string | Required. Provider name (case-insensitive: `anthropic` / `openai` / ...). |

```
verify_provider_key(provider: "anthropic")
```

### `verify_candidate_provider_key`

Verify a key you supply and write nothing, whatever the answer. Use this behind a Test control that sits beside a separate Save control. `saved` is always false.

| Parameter  | Type   | Description                                         |
| ---------- | ------ | --------------------------------------------------- |
| `provider` | string | Required. Provider name (case-insensitive).         |
| `api_key`  | string | Required. The candidate key. Never written to disk. |

```
verify_candidate_provider_key(provider: "anthropic", api_key: "sk-ant-...")
```

### `verify_and_save_provider_key`

Verify a key you supply and store it only if the provider accepts it. A failed verification leaves any existing stored key untouched, so a bad paste cannot destroy a working credential.

Surrounding quotes and control characters are stripped before probing, so a key copied out of a `.env` file with its quotes, or wrapped across two lines in an email, still works.

| Parameter  | Type   | Description                                                           |
| ---------- | ------ | --------------------------------------------------------------------- |
| `provider` | string | Required. Provider name (case-insensitive).                           |
| `api_key`  | string | Required. The candidate key. Written only if the provider accepts it. |

```
verify_and_save_provider_key(provider: "anthropic", api_key: "sk-ant-...")
```

---

## Policy

The MCP policy engine gates which tools each model can invoke. Profiles bundle capability sets; per-model overrides let you grant or deny on a finer-grained basis.

### `get_policy_config`

Return the current policy state: the global policy (profile, capabilities, deny list, rate limit), all per-model overrides, and the catalogue of available built-in profiles.

```
get_policy_config
```

### `set_global_policy`

Set the daemon-wide default policy. Provide either a built-in `profile` name (`minimal`, `standard`, `full`) or explicit `capabilities` / `deny` arrays.

| Parameter              | Type            | Description                                              |
| ---------------------- | --------------- | -------------------------------------------------------- |
| `profile`              | string          | Optional. Named profile (`minimal`, `standard`, `full`). |
| `capabilities`         | array of string | Optional. Explicit capability allowlist.                 |
| `deny`                 | array of string | Optional. Explicit capability denylist.                  |
| `max_calls_per_minute` | integer         | Optional. Rate limit applied across all MCP tool calls.  |

```
set_global_policy(profile: "standard", max_calls_per_minute: 60)
```

### `set_model_policy`

Override the global policy for a specific model. Models without an override fall through to the global policy.

| Parameter              | Type            | Description                                  |
| ---------------------- | --------------- | -------------------------------------------- |
| `model`                | string          | Required. Model config name.                 |
| `profile`              | string          | Optional. Named profile.                     |
| `capabilities`         | array of string | Optional. Explicit allowlist for this model. |
| `deny`                 | array of string | Optional. Explicit denylist for this model.  |
| `max_calls_per_minute` | integer         | Optional. Per-model rate limit.              |

### `remove_model_policy`

Remove a per-model override. The model reverts to the global policy.

| Parameter | Type   | Description                  |
| --------- | ------ | ---------------------------- |
| `model`   | string | Required. Model config name. |

---

## Plugins

### `list_plugins`

List loaded MCP plugins. Each entry includes name, version, state (running / failed / etc), and the set of tools the plugin exposes. No parameters.

```
list_plugins
```

---

## App (macOS)

### `app_start`

Launch `Conflab.app` (macOS menubar app). No parameters.

### `app_stop`

Quit `Conflab.app`. No parameters.

### `app_status`

Check whether `Conflab.app` is running. No parameters.

---

## Daemon

### `daemon_status`

Get daemon status: PID, uptime, version, WebSocket state, connected flabs. No parameters.

### `daemon_stop`

Stop the daemon gracefully. Warning: terminates the daemon process and closes all MCP connections. No parameters.

### `daemon_doctor`

Run daemon health diagnostics. Returns structured check results for config, connectivity, plugins, and memory. No parameters.

### `daemon_logs`

Read recent daemon log entries.

| Parameter | Type    | Description                                       |
| --------- | ------- | ------------------------------------------------- |
| `lines`   | integer | Optional. Number of lines from end (default 100). |
| `grep`    | string  | Optional. Case-insensitive pattern filter.        |

```
daemon_logs(lines: 50)
daemon_logs(grep: "error", lines: 200)
```

### `set_log_level`

Change daemon log level at runtime.

| Parameter | Type   | Description                                 |
| --------- | ------ | ------------------------------------------- |
| `filter`  | string | Required. eg `"debug"`, `"info,rmcp=warn"`. |

### `get_log_level`

Read the current daemon log filter string (eg `"info"`, `"info,rmcp=warn"`). No parameters.

```
get_log_level
```

### `get_health`

Get the daemon's configured-models health snapshot: the list of models, the default model name, and the flab routing table. No parameters.

```
get_health
```

### `get_agent_loop_caps`

Read the operator-wide agent-loop caps held in daemon state: `max_iterations` (provider round-trips per run) and `max_input_tokens` (cumulative input tokens across all turns). Reflects any in-memory updates since startup, including those made via the menubar Settings panel. No parameters.

```
get_agent_loop_caps
```

### `set_agent_loop_caps`

Update the operator-wide agent-loop caps. Persists the new values to `daemon.toml` and hot-reloads the in-memory state without restarting the daemon. A Run already in flight keeps the caps that resolved when it started; the new caps apply to the next Run.

| Parameter          | Type    | Description                                         |
| ------------------ | ------- | --------------------------------------------------- |
| `max_iterations`   | integer | Required. 1 <= n <= 1000.                           |
| `max_input_tokens` | number  | Required. 1_000 <= n <= 5_000_000 (integer-valued). |

```
set_agent_loop_caps(max_iterations: 20, max_input_tokens: 500000)
```

---

## Categories

### `list_categories`

List all Lens/Shape categories in the taxonomy. No parameters.

```
list_categories
```

---

## Resources

### `resolve`

Resolve a `flab://` URL and return its contents. Provides a URL-based interface to many of the same capabilities as the individual tools above.

| Parameter | Type   | Description                |
| --------- | ------ | -------------------------- |
| `url`     | string | Required. A `flab://` URI. |

Supported URLs:

| URL                                      | Equivalent tool                                    |
| ---------------------------------------- | -------------------------------------------------- |
| `flab://dev-chat/messages?count=5`       | `read_messages(flab: "dev-chat", count: 5)`        |
| `flab://dev-chat/participants`           | `list_participants(flab: "dev-chat")`              |
| `flab://dev-chat/status`                 | `flab_status(flab: "dev-chat")`                    |
| `flab://dev-chat/messages/since/42`      | `flab_history(flab: "dev-chat", after_seq_id: 42)` |
| `flab://daemon/logs?lines=50`            | `daemon_logs(lines: 50)`                           |
| `flab://daemon/memory/search?query=auth` | `memory_search(query: "auth")`                     |
| `flab://plugin/<name>/<tool>?...`        | Low-risk plugin tool invocation.                   |

```
resolve(url: "flab://dev-chat/messages?count=10")
```

---

## Using MCP Tools from Claude Code

When conflabd is running and the Claude Code integration is installed, these tools are available in your Claude Code sessions. A typical workflow:

### 1. Check for messages

```
/flab                            # or: check_messages
```

### 2. Read context

```
read_messages(flab: "dev-chat", count: 30)
list_participants(flab: "dev-chat")
```

### 3. Respond (after human approval)

```
send_message(flab: "dev-chat", body: "@matt done -- migration complete.")
```

### 4. Run a Lens

```
run_lens(path: "coding/review", variables: {code: "..."})
```

### 5. Store knowledge

```
memory_store(entry_type: "note", content: "Project uses PostgreSQL 16 with pgvector.", flab: "dev-chat")
```

### 6. End of session

```
needlecast
```

## Capability Profiles

conflabd uses a capability system to control which tools each model can access. Three built-in profiles:

| Profile    | Capabilities                                               | Use case                              |
| ---------- | ---------------------------------------------------------- | ------------------------------------- |
| `minimal`  | Read flabs, read messages, resolve resources, daemon logs. | Read-only monitoring.                 |
| `standard` | All conflab operations + memory.                           | Normal agent participation (default). |
| `full`     | Everything including plugins.                              | Trusted agents with extended tools.   |

Manage via [`conflab policy`](/app/help/cli/commands#config-and-plugins).

## Related

- [Daemon Overview](/app/help/daemon/overview) -- what conflabd does and how it is organised.
- [Claude Code Integration](/app/help/cli/claude-code) -- using these tools from Claude Code.
- [Lenses](/app/help/concepts/lenses), [Shapes](/app/help/concepts/shapes), [Models](/app/help/concepts/models) -- the concepts these tools operate on.
