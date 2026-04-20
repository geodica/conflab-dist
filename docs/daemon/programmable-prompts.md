---
title: Programmable Prompts
---

# Programmable Prompts

Programmable prompts are `.lensmd` templates that contain Lua code blocks. The Lua code runs before interpolation, allowing templates to compute variables dynamically, process JSON data, read the clipboard, and apply conditional logic.

## When to Use Programmable Prompts

Use a regular template when you just need variable substitution. Use a programmable prompt when you need to:

- Compute a variable value from other variables
- Read data from the clipboard and transform it
- Conditionally set variables based on logic
- Process or generate JSON data

## Execution Pipeline

When a programmable prompt is executed, the pipeline is:

1. **Validate** -- check required variables and type constraints
2. **Execute Lua** -- run all `conflab-exec` blocks in order
3. **Merge variables** -- Lua-set variables override input values
4. **Interpolate** -- substitute `{{variables}}` in the body
5. **Return result** -- Lua blocks are stripped from the output

Templates without Lua blocks skip steps 2-3 and go straight to interpolation.

## Lua Block Syntax

Lua code is embedded in fenced code blocks with the `lua` language identifier and `conflab-exec` info string:

````markdown
```lua conflab-exec
bridge.set_variable("greeting", "hello world")
```
````

Regular `lua` code blocks (without `conflab-exec`) are treated as normal Markdown and included in the output.

### Multiple Blocks

A template can contain multiple Lua blocks. All blocks share the same Lua state, so later blocks can read variables set by earlier ones:

````markdown
```lua conflab-exec
-- Block 1: compute a value
bridge.set_variable("x", "10")
```

Some text between blocks.

```lua conflab-exec
-- Block 2: read the value from block 1
local x = bridge.get_variable("x")
bridge.set_variable("y", "x=" .. x)
```
````

### Output Stripping

All `conflab-exec` blocks are stripped from the final output. Only the surrounding Markdown body (with interpolated variables) is returned.

## Bridge API Reference

The `bridge` global table provides the interface between Lua code and the Conflab runtime.

### Always Available

These functions are available in all programmable prompts regardless of declared capabilities.

| Function       | Signature                          | Return            | Description                                   |
| -------------- | ---------------------------------- | ----------------- | --------------------------------------------- |
| `set_variable` | `bridge.set_variable(name, value)` | --                | Set or override a template variable           |
| `get_variable` | `bridge.get_variable(name)`        | `string` or `nil` | Read a variable value; returns `nil` if unset |
| `log`          | `bridge.log(message)`              | --                | Write a message to the daemon log             |
| `json_encode`  | `bridge.json_encode(value)`        | `string`          | Encode a Lua table/value as a JSON string     |
| `json_decode`  | `bridge.json_decode(text)`         | `table`/`value`   | Decode a JSON string into a Lua value         |

#### set_variable

Sets a variable that will be used during interpolation. Lua-set variables take precedence over input values.

```lua
bridge.set_variable("name", "Alice")
bridge.set_variable("count", "42")  -- all values are strings
```

#### get_variable

Reads a variable from the current execution context. Returns the input value if one was provided, or `nil` if unset.

```lua
local name = bridge.get_variable("name")
if name then
  bridge.set_variable("greeting", "Hello " .. name)
end
```

#### log

Writes a message to the conflabd log file. Useful for debugging.

```lua
bridge.log("Processing started")
```

#### json_encode / json_decode

Convert between Lua tables and JSON strings. Lua arrays (tables with sequential integer keys starting at 1) become JSON arrays; other tables become JSON objects.

```lua
-- Encode
local data = { name = "Alice", scores = {95, 87, 92} }
local json_str = bridge.json_encode(data)
-- -> '{"name":"Alice","scores":[95,87,92]}'

-- Decode
local parsed = bridge.json_decode('{"key": "value", "count": 42}')
bridge.set_variable("key", parsed.key)       -- "value"
bridge.set_variable("count", tostring(parsed.count))  -- "42"
```

### Clipboard (Capability: `clipboard`)

These functions require `clipboard` in the template's `capabilities` array. macOS only (uses `pbpaste`/`pbcopy`).

| Function        | Signature                    | Return   | Description                     |
| --------------- | ---------------------------- | -------- | ------------------------------- |
| `clipboard_get` | `bridge.clipboard_get()`     | `string` | Read current clipboard contents |
| `clipboard_set` | `bridge.clipboard_set(text)` | --       | Write text to the clipboard     |

```lua
local content = bridge.clipboard_get()
bridge.set_variable("clipboard_content", content)
```

### MCP Tools (Capability: `mcp`)

Invoke any MCP tool available to conflabd from Lua. Requires `mcp` in the template's `capabilities` array.

```lua
local result = bridge.mcp(tool_name, params)
```

- `tool_name` (string): the MCP tool name
- `params` (table): tool parameters (converted to JSON internally)
- Returns a Lua table/value converted from the tool's JSON result
- Raises a Lua error on failure (unknown tool, invalid params, tool error)

#### Available Tools

All 44 MCP tools exposed by the daemon are callable via `bridge.mcp(...)`. A few commonly used ones:

| Tool              | Parameters                           | Description                           |
| ----------------- | ------------------------------------ | ------------------------------------- |
| `list_flabs`      | `{}`                                 | List flabs the daemon can access.     |
| `read_messages`   | `{flab, count?}`                     | Recent messages from a flab.          |
| `check_messages`  | `{peek?}`                            | New messages addressed to this agent. |
| `send_message`    | `{flab, body}`                       | Send a message to a flab.             |
| `run_lens`        | `{path, variables?, model?, shape?}` | Execute a Lens.                       |
| `list_lenses`     | `{}`                                 | List all Lenses.                      |
| `list_shapes`     | `{}`                                 | List all Shapes.                      |
| `list_runs`       | `{status?, lens?, limit?}`           | List Run executions.                  |
| `list_models`     | `{}`                                 | List configured Models.               |
| `list_categories` | `{}`                                 | List all Lens/Shape categories.       |
| `memory_store`    | `{entry_type, content, ...}`         | Store a memory entry.                 |
| `memory_search`   | `{query, limit?, entry_type?}`       | Search local memory.                  |
| `needlecast`      | `{}`                                 | Sync local memory to the cloud.       |
| `resolve`         | `{url}`                              | Resolve a `flab://` URL.              |
| `daemon_logs`     | `{lines?, grep?}`                    | Read daemon log entries.              |

See [MCP Tools Reference](/app/help/daemon/mcp-tools) for the complete 44-tool catalogue with parameter tables and response shapes.

Plugin tools are also accessible using the `plugin_name.tool_name` convention.

#### Examples

Read messages and summarise:

```lua
local messages = bridge.mcp("read_messages", { flab = "dev-chat", count = 10 })
local summary = {}
for i, msg in ipairs(messages) do
  summary[#summary + 1] = msg.sender .. ": " .. msg.body
end
bridge.set_variable("recent_messages", table.concat(summary, "\n"))
```

Check for unread messages:

```lua
local inbox = bridge.mcp("check_messages", { peek = true })
bridge.set_variable("unread_count", tostring(#inbox))
```

Search memory and incorporate context:

```lua
local memories = bridge.mcp("memory_search", { query = "project goals", limit = 5 })
local context = {}
for i, mem in ipairs(memories) do
  context[#context + 1] = mem.content
end
bridge.set_variable("memory_context", table.concat(context, "\n---\n"))
```

#### Error Handling

MCP tool errors surface as Lua runtime errors. Use `pcall` to handle them gracefully:

```lua
local ok, result = pcall(bridge.mcp, "read_messages", { flab = "nonexistent" })
if not ok then
  bridge.log("MCP error: " .. tostring(result))
  bridge.set_variable("error", tostring(result))
end
```

### Filesystem (Capability: `fs`) (ST0088)

Read files and enumerate globs under the current user's home directory. Both primitives enforce a home-subtree check (canonicalised target must be within `$HOME`) and size caps internally.

| Function     | Signature                    | Return  | Description                                        |
| ------------ | ---------------------------- | ------- | -------------------------------------------------- |
| `read_file`  | `bridge.read_file(path)`     | `table` | Read a single file. Supports `~/` tilde expansion. |
| `list_files` | `bridge.list_files(pattern)` | `table` | Enumerate files matching a glob. Supports `~/`.    |

Both return a table with `ok = true` on success or `ok = false, error = <code>, detail = <string>` on failure.

#### read_file

On success:

```lua
local r = bridge.read_file("~/Documents/notes.md")
-- r.ok         == true
-- r.path       == "/Users/you/Documents/notes.md"
-- r.name       == "notes.md"
-- r.content    == "..."
-- r.size_bytes == 1234
-- r.mime       == "text/markdown"   -- when inferrable from extension
```

Error codes: `path_outside_home`, `not_found`, `file_too_large`, `io_error`. Per-file cap defaults to 2 MiB.

#### list_files

On success:

```lua
local r = bridge.list_files("~/Documents/meetings/*.md")
-- r.ok      == true
-- r.entries == { {path=..., name=...}, {path=..., name=...}, ... }
```

Error codes: `glob_invalid`, `path_outside_home`, `listing_too_large`, `io_error`. Listing cap defaults to 256 entries.

#### Common Pattern: Iterate a `glob` Variable

Pair a `type: glob` variable with `fs` capability for "point the lens at files" flows:

```yaml
---
capabilities: [fs]
variables:
  transcripts:
    type: glob
    required: true
---
```

````markdown
```lua conflab-exec
local pattern = bridge.get_variable("transcripts")
local listing = bridge.list_files(pattern)
if not listing.ok then error("list_files failed: " .. listing.error) end

local parts = {}
for _, entry in ipairs(listing.entries) do
  local f = bridge.read_file(entry.path)
  if f.ok then table.insert(parts, "### " .. entry.name .. "\n\n" .. f.content) end
end
bridge.set_variable("transcripts", table.concat(parts, "\n\n---\n\n"))
```
````

### Future Capabilities (Stubs)

These capabilities are declared but not yet implemented. Calling them returns a "not yet implemented" error and adds a warning to the response.

| Capability    | Function                  | Description          |
| ------------- | ------------------------- | -------------------- |
| `llm`         | `bridge.llm(...)`         | LLM API calls        |
| `applescript` | `bridge.applescript(...)` | macOS GUI automation |

## Capabilities

Capabilities are declared in frontmatter to gate access to bridge functions:

```yaml
---
capabilities:
  - clipboard
---
```

If a template calls a capability-gated function without declaring it, the function is `nil` and Lua raises an error. Known capabilities: `clipboard`, `fs`, `mcp`, `llm`, `applescript`. Unknown capability names cause a validation error.

## Sandbox Limits

Lua code runs in a restricted sandbox to prevent templates from accessing the filesystem, network, or system resources.

### Allowed Standard Library

| Module      | Description                                               |
| ----------- | --------------------------------------------------------- |
| `table`     | Table manipulation (`table.concat`, `table.insert`, etc.) |
| `string`    | String operations (`string.upper`, `string.format`, etc.) |
| `math`      | Math functions (`math.floor`, `math.random`, etc.)        |
| `coroutine` | Coroutine support                                         |

### Blocked

| Module    | Reason                                   |
| --------- | ---------------------------------------- |
| `os`      | No process control or environment access |
| `io`      | No filesystem access                     |
| `debug`   | No runtime introspection                 |
| `package` | No module loading (`require` is blocked) |

### Resource Limits

| Limit   | Value | Description               |
| ------- | ----- | ------------------------- |
| Memory  | 64 MB | Maximum memory allocation |
| Timeout | 30 s  | Maximum execution time    |

The timeout is enforced via instruction-count hooks (checked every 10,000 instructions). If either limit is exceeded, execution fails with an error.

## Error Handling

### Syntax Errors

Invalid Lua syntax causes execution to fail. The error message includes the block number:

```
lua block 1: [string "lua-block-1"]:1: unexpected symbol near 'this'
```

### Runtime Errors

Lua `error()` calls and runtime failures propagate as execution errors:

```
lua block 1: [string "lua-block-1"]:1: intentional
```

### Capability Errors

Calling an undeclared capability function raises a nil error:

```
attempt to call a nil value (field 'clipboard_get')
```

Declare the capability in frontmatter to resolve:

```yaml
capabilities:
  - clipboard
```

### Timeout

Infinite loops or long-running computations trigger a timeout error:

```
execution timeout
```

## Examples

### Conditional Variable

Set a variable based on another variable's value:

````markdown
---
title: Greeting
variables:
  name:
    type: string
    required: true
  formal:
    type: boolean
    default: false
---

```lua conflab-exec
local name = bridge.get_variable("name")
local formal = bridge.get_variable("formal")

if formal == "true" then
  bridge.set_variable("salutation", "Dear " .. name .. ",")
else
  bridge.set_variable("salutation", "Hey " .. name .. "!")
end
```

{{salutation}}

How can I help you today?
````

### JSON Processing

Parse JSON input and extract fields:

````markdown
---
title: JSON Summariser
variables:
  json_data:
    type: text
    description: "Paste JSON data"
    required: true
---

```lua conflab-exec
local data = bridge.json_decode(bridge.get_variable("json_data"))
local keys = {}
for k, _ in pairs(data) do
  keys[#keys + 1] = k
end
bridge.set_variable("key_list", table.concat(keys, ", "))
bridge.set_variable("key_count", tostring(#keys))
```

The JSON object has {{key_count}} keys: {{key_list}}.

Summarise the structure and purpose of this data:

{{json_data}}
````

### Clipboard Read

Read code from the clipboard for review:

````markdown
---
title: Review Clipboard
capabilities:
  - clipboard
variables:
  language:
    type: choice
    choices: [Elixir, Rust, Swift, Python]
    default: "Elixir"
---

```lua conflab-exec
local code = bridge.clipboard_get()
bridge.set_variable("code", code)
bridge.log("Read " .. #code .. " bytes from clipboard")
```

Review the following {{language}} code from my clipboard:

```
{{code}}
```

Focus on correctness, idiomatic style, and potential bugs.
````

### MCP-Powered Review

Read recent messages and summarise them with context from memory:

````markdown
---
title: Flab Summary
capabilities:
  - mcp
variables:
  flab:
    type: string
    required: true
    description: "Flab to summarise"
  count:
    type: string
    default: "10"
---

```lua conflab-exec
local flab = bridge.get_variable("flab")
local count = tonumber(bridge.get_variable("count")) or 10

-- Fetch recent messages
local messages = bridge.mcp("read_messages", { flab = flab, count = count })
local lines = {}
for i, msg in ipairs(messages) do
  lines[#lines + 1] = msg.sender .. ": " .. msg.body
end
bridge.set_variable("messages_text", table.concat(lines, "\n"))

-- Search memory for context about this flab
local ok, memories = pcall(bridge.mcp, "memory_search", {
  query = flab .. " context",
  limit = 3
})
if ok and #memories > 0 then
  local ctx = {}
  for i, mem in ipairs(memories) do
    ctx[#ctx + 1] = mem.content
  end
  bridge.set_variable("memory_context", table.concat(ctx, "\n"))
else
  bridge.set_variable("memory_context", "(no relevant memories)")
end
```

Summarise the recent conversation in **{{flab}}**:

{{messages_text}}

Context from memory:
{{memory_context}}

Provide a concise summary of the key topics, decisions, and action items.
````

## Higher-Level Helpers

The `bridge.*` API documented above is the low-level interface. For common patterns -- glob expansion, required-variable guards, string truncation -- a Conflab-authored stdlib lives on the `conflab.*` global. The 20-line glob/read/concat block in the filesystem example above collapses to a single `conflab.expand_glob("transcripts")` call. See the [Lua Stdlib Reference](/app/help/daemon/lua-stdlib) for the full list.

For helpers you want to share across your own lenses without waiting for the daemon to ship them, drop a `.lua` file into `~/.conflab/db/lua/` and reference it as `user.<stem>.*` from any lens. See the [Lua User Library](/app/help/daemon/lua-user-library) guide for the file-format contract, failure isolation, and capability rules.

## See Also

- [Lua Stdlib Reference](/app/help/daemon/lua-stdlib) -- Conflab-authored helpers on `conflab.*`
- [Lua User Library](/app/help/daemon/lua-user-library) -- your own helpers at `user.*`
- [Prompt Templates](/app/help/daemon/templates) -- `.lensmd` format reference
- [Daemon Overview](/app/help/daemon/overview) -- Template management API endpoints
