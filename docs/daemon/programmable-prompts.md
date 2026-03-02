---
title: Programmable Prompts
---

# Programmable Prompts

Programmable prompts are `.cp.md` templates that contain Lua code blocks. The Lua code runs before interpolation, allowing templates to compute variables dynamically, process JSON data, read the clipboard, and apply conditional logic.

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

### Future Capabilities (Stubs)

These capabilities are declared but not yet implemented. Calling them returns a "not yet implemented" error and adds a warning to the response.

| Capability    | Function                  | Description                      |
| ------------- | ------------------------- | -------------------------------- |
| `mcp`         | `bridge.mcp(...)`         | MCP tool invocation via conflabd |
| `llm`         | `bridge.llm(...)`         | LLM API calls                    |
| `applescript` | `bridge.applescript(...)` | macOS GUI automation             |

## Capabilities

Capabilities are declared in frontmatter to gate access to bridge functions:

```yaml
---
capabilities:
  - clipboard
---
```

If a template calls a capability-gated function without declaring it, the function is `nil` and Lua raises an error. Known capabilities: `clipboard`, `mcp`, `llm`, `applescript`. Unknown capability names cause a validation error.

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

## See Also

- [Prompt Templates](/app/help/daemon/templates) -- `.cp.md` format reference
- [Daemon Overview](/app/help/daemon/overview) -- Template management API endpoints
