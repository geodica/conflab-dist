---
title: Lua Stdlib Reference
---

# Lua Stdlib Reference

The Conflab Lua stdlib is a small set of helper functions shipped inside the daemon binary and loaded into every fresh Lua state. Helpers sit on top of the low-level `bridge.*` primitives documented in [Programmable Prompts](/app/help/daemon/programmable-prompts) and exist so `.lensmd` authors don't re-write the same glob-expand / file-read / guard-clause patterns across lenses.

The stdlib is exposed on a single global table named `conflab`. Every helper is plain Lua (you can read the source at `native/daemon/src/lua/stdlib.lua`); they add no new capability gates and inherit the invoking lens's declared capabilities via the primitives they call.

## When to Use a Stdlib Helper

Reach for `conflab.*` before hand-rolling a PREPARE block. The motivating example is the meeting-summary glob dance that used to be ~20 lines of list/read/guard/concat — it's now one call.

If a helper you want doesn't exist, the lower layer is still fully available. The stdlib is additive, not a replacement.

## First Cohort

| Helper                            | Purpose                                                            | Capabilities |
| --------------------------------- | ------------------------------------------------------------------ | ------------ |
| `conflab.expand_glob(var, opts?)` | Resolve a glob variable to concatenated file contents, write back. | `fs`         |
| `conflab.each_file(pattern, fn)`  | Iterate files matching a glob, skip unreadable, log the skip.      | `fs`         |
| `conflab.require_var(name)`       | Return a variable value or raise a clear "missing required" error. | --           |
| `conflab.truncate(str, max)`      | Clamp a string to N bytes, appending a trim note when truncated.   | --           |
| `conflab.log_table(tbl, label?)`  | Pretty-print a Lua table through `bridge.log` for debugging.       | --           |

### conflab.expand_glob

```
conflab.expand_glob(var_name, opts?)
```

Reads the named variable (which must hold a glob pattern), enumerates matching files under `$HOME` via `bridge.list_files`, reads each match via `bridge.read_file`, concatenates the results with per-entry headers, and writes the joined string back to the same variable. Unreadable entries are logged via `bridge.log` and skipped.

Requires `capabilities: [fs]`.

**Options**

| Key             | Default         | Description                              |
| --------------- | --------------- | ---------------------------------------- |
| `header_prefix` | `"### "`        | Prefix applied to each entry's filename. |
| `separator`     | `"\n\n---\n\n"` | Joiner inserted between parts.           |

**Errors**

- `"missing required variable: <name>"` -- variable is unset or empty.
- `"list_files failed: <error> (<detail>)"` -- glob enumeration failed.
- `"no readable files matched: <pattern>"` -- zero files could be read.

**Example**

A lens that summarises meeting transcripts under `~/Documents/meetings/`:

```yaml
capabilities: [fs]
variables:
  transcripts:
    type: glob
    required: true
```

````markdown
```lua conflab-exec
conflab.expand_glob("transcripts")
```

Summarise the following:

{{transcripts}}
````

### conflab.each_file

```
conflab.each_file(pattern, fn) -> count
```

Lists files matching the glob pattern, reads each one, and invokes `fn(entry, content)` for every successful read. Entries that fail to read are logged via `bridge.log` and skipped. Returns the number of successful iterations.

Requires `capabilities: [fs]`.

**Example**

```lua
local total = 0
local count = conflab.each_file("~/logs/*.log", function(entry, content)
  total = total + #content
end)
bridge.set_variable("file_count", tostring(count))
bridge.set_variable("total_bytes", tostring(total))
```

### conflab.require_var

```
conflab.require_var(name) -> string
```

Returns the value of the named variable, or raises a Lua error with the message `"missing required variable: <name>"` when the variable is unset or empty. Use this at the top of a PREPARE block to surface a clear error instead of failing later with a `nil` dereference.

**Example**

```lua
local query = conflab.require_var("query")
local result = do_lookup(query)
bridge.set_variable("result", result)
```

### conflab.truncate

```
conflab.truncate(str, max_bytes) -> string
```

Returns the string unchanged when its length is at or below `max_bytes`. When it exceeds the limit, returns the first `max_bytes` bytes followed by `"\n\n... (truncated N chars)"`.

Raises a Lua error when `str` is not a string or when `max_bytes` is negative.

**Example**

```lua
local transcript = bridge.get_variable("transcript")
bridge.set_variable("transcript", conflab.truncate(transcript, 50000))
```

### conflab.log_table

```
conflab.log_table(tbl, label?)
```

Pretty-prints a Lua table as a single `bridge.log` line, sorted by key for deterministic output. Non-table values are logged as `tostring(value)`. An optional label is prepended.

**Example**

```lua
conflab.log_table({ count = 3, tag = "review" }, "summary")
-- daemon log: "summary = {count=3, tag=review}"
```

## Capability Inheritance

Stdlib helpers do not introduce new capability gates. If a helper relies on `bridge.read_file` (as `expand_glob` and `each_file` do), the invoking lens must declare `capabilities: [fs]`. The capability check happens when `bridge.read_file` is called, not at helper-definition time.

That means:

- A lens that calls `conflab.expand_glob` without `fs` in its capabilities list will fail with `attempt to call a nil value (field 'list_files')`.
- A lens that has `fs` declared sees the helper succeed.

This is deliberate: the capability contract is a property of the lens, not the helper.

## Reading the Source

The stdlib is plain Lua, embedded in the daemon binary via `include_str!`. You can read it as part of the daemon source tree:

- `native/daemon/src/lua/stdlib.lua`

All five helpers sit in under 100 lines of Lua. If you need one that isn't there, the lower `bridge.*` primitives (documented in [Programmable Prompts](/app/help/daemon/programmable-prompts)) are always available.

## Adding Your Own Helpers

The stdlib is the Conflab-authored layer. For helpers you want to share across your own lenses without waiting for the daemon to ship them, use the [Lua User Library](/app/help/daemon/lua-user-library): drop a `.lua` file into `~/.conflab/db/lua/` and reference it as `user.<stem>.*` from any lens.

## See Also

- [Programmable Prompts](/app/help/daemon/programmable-prompts) -- the underlying `bridge.*` API
- [Lua User Library](/app/help/daemon/lua-user-library) -- your own helpers at `user.*`
- [Prompt Templates](/app/help/daemon/templates) -- `.lensmd` format reference
