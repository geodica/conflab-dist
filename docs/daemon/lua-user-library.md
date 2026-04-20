---
title: Lua User Library
---

# Lua User Library

The user Lua library lets you ship your own helper functions to every lens on your machine without editing each lens individually. Drop a `.lua` file into `~/.conflab/db/lua/`, return a table from it, and every subsequent lens run sees the table at `user.<file-stem>.*`.

This sits alongside the Conflab-authored [Lua Stdlib](/app/help/daemon/lua-stdlib). Both are loaded fresh at the start of every lens execution.

## Directory Layout

```
~/.conflab/db/
├── lenses/      -- your .lensmd files
├── shapes/      -- your .shape.json files
└── lua/         -- your helper .lua files (ST0089)
```

The `lua/` directory is non-recursive -- only `*.lua` files in the top level are scanned. Sub-directories are currently ignored. Hidden files (dot-prefix) are skipped silently.

Because `~/.conflab/db/` is the same directory the daemon already watches for lenses and shapes, anything you commit to a git repo rooted there is shared across machines via the usual sync path.

## File Format

Each file must return a Lua table. The table is assigned to the `user` global under a key matching the file's stem (the filename without the `.lua` extension).

```lua
-- ~/.conflab/db/lua/formatting.lua

local M = {}

function M.clean(s)
  return (s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.wrap(s, width)
  width = width or 80
  local lines = {}
  local line = ""
  for word in s:gmatch("%S+") do
    if #line + #word + 1 > width then
      table.insert(lines, line)
      line = word
    elseif line == "" then
      line = word
    else
      line = line .. " " .. word
    end
  end
  if line ~= "" then table.insert(lines, line) end
  return table.concat(lines, "\n")
end

return M
```

From any lens:

```lua
local cleaned = user.formatting.clean(bridge.get_variable("raw"))
local wrapped = user.formatting.wrap(cleaned, 72)
bridge.set_variable("body", wrapped)
```

The file stem in the example above is `formatting`, so the returned table lives at `user.formatting`.

## Failure Isolation

User Lua files are loaded one at a time. If a file has a syntax error, raises an error during top-level evaluation, or returns something other than a table, it is logged and skipped -- other files continue loading.

| Failure mode                 | Behaviour                                         |
| ---------------------------- | ------------------------------------------------- |
| Syntax error                 | Logged via `tracing::warn!`, file skipped         |
| `error()` at top level       | Logged, file skipped                              |
| Returns `nil`                | Logged, stem absent from `user.*`                 |
| Returns a non-table value    | Logged, stem absent from `user.*`                 |
| File is unreadable           | Logged, file skipped                              |
| Missing `~/.conflab/db/lua/` | No-op, `user` is still initialised to empty table |

Check for broken helpers with:

```bash
conflab daemon logs -n 100 | grep "user lua"
```

Because the `user` global is always initialised -- even when the directory is missing -- lens code can guard with `if user.foo then ... end` without risk of an `attempt to index a nil value (global 'user')` error.

## Capability Inheritance

User helpers, like stdlib helpers, do not introduce new capability gates. A helper that calls `bridge.read_file` still requires the invoking lens to declare `capabilities: [fs]`. The capability check happens at the `bridge.*` call site, not at helper definition time.

This means you can freely share helpers that use capability-gated primitives; the lens author is responsible for declaring the capabilities they need.

## Calling the Stdlib From Your Helpers

User helpers load after the Conflab stdlib, so `conflab.*` is visible inside your helper bodies. This is useful for building on top of stdlib primitives:

```lua
-- ~/.conflab/db/lua/project.lua

local M = {}

function M.load_notes(var)
  conflab.expand_glob(var, { header_prefix = "# ", separator = "\n\n" })
end

return M
```

## Naming Conflicts

Each file's contents live under its own stem, so two files never collide by default. If you have `formatting.lua` and `shout.lua`, they show up as `user.formatting.*` and `user.shout.*` respectively.

The stem is the filename without `.lua`. A file named `string-utils.lua` is reachable as `user["string-utils"]` from Lua (dash isn't valid in identifiers, so you need subscript notation). Prefer underscore-separated names (`string_utils.lua` -> `user.string_utils.*`) or camelCase (`stringUtils.lua` -> `user.stringUtils.*`) for easier call sites.

## Lifecycle

- **Fresh state per lens run.** User library files are loaded on every invocation. Edits take effect immediately on the next run -- no daemon restart needed.
- **Load cost.** Five files of ~50 lines each add a few milliseconds per run. Negligible against a typical LLM call.
- **No cross-run state.** Each lens run gets a clean Lua state. Module-level variables in your helpers are not preserved across invocations.

## See Also

- [Lua Stdlib Reference](/app/help/daemon/lua-stdlib) -- the Conflab-authored `conflab.*` helpers
- [Programmable Prompts](/app/help/daemon/programmable-prompts) -- the underlying `bridge.*` API
- [Filesystem Watcher](/app/help/daemon/filesystem-watcher) -- how `~/.conflab/db/` is synced
