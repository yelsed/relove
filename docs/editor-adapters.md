# Editor adapters

[← Back to index](./index.md)

`relove` writes machine-readable state to `<project>/.relove/` so any editor or
external tool can react to reloads without screen-scraping. This is a stable,
versioned contract;
the VS Code and Neovim adapters shipped in the repo are just two consumers.

## The `.relove/` directory

| File | Format | Contents |
|------|--------|----------|
| `status.json` | one JSON object | the current state only (overwritten each event) |
| `events.log` | JSON lines | append-only history of every event |
| `errors.log` | JSON lines | append-only history of `error` / `restart_required` events only |

Use `status.json` for "what is the state now", and `events.log` for history. Files
are written to the project **source** directory (not LÖVE's save directory), so the
editor is looking where the game writes.

## Payload schema (`schemaVersion` 1)

```json
{
  "schemaVersion": 1,
  "status": "error",
  "file": "src/player.lua",
  "line": 12,
  "message": "src/player.lua:12: attempt to index a nil value",
  "stack": "src/player.lua:12: ...\nstack traceback:\n\tsrc/player.lua:12: in function 'update'",
  "usingLastGood": true,
  "updatedAt": 41.53
}
```

| Field | Type | Notes |
|-------|------|-------|
| `schemaVersion` | number | Contract version. Currently `1`. Adapters should check it. |
| `status` | string | One of the values below. |
| `file` | string | Source path relative to the project, or `relove` for lifecycle messages. On a runtime error it may be a callback label (e.g. `love.update`), so don't assume it's a file. |
| `message` | string | Human-readable detail. |
| `usingLastGood` | boolean | `true` when the game is still running the previous working code. |
| `updatedAt` | number | Seconds from `love.timer.getTime()` (monotonic, not wall clock). |
| `line` | number? | Present on some errors; 1-based source line. |
| `stack` | string? | Present on runtime errors; a full Lua traceback. |

## Status values

| `status` | Meaning | Suggested editor treatment |
|----------|---------|----------------------------|
| `info` | Lifecycle / watching messages. | Status line only. |
| `ok` | A module reloaded successfully. | Clear diagnostics; status line. |
| `error` | Reload or runtime error; last-good code kept. | Diagnostic at `file:line`; parse `stack` for clickable frames. |
| `restart_required` | `main.lua`/`conf.lua` changed; needs a restart. | Warning diagnostic. |
| `vetoed` | A module's `__accept` refused the reload; running code unchanged. | Status line (optionally an info diagnostic). |

## Shipped adapters

- **VS Code** (`editor/vscode-relove/`) — watches `status.json`, turns errors into
  diagnostics, and parses the `stack` into clickable related-information frames.
- **Neovim** (`editor/nvim-relove/`) — watches `status.json` and publishes
  `vim.diagnostic`. Safe to re-run `setup()` (config reload, plugin manager): it stops
  **and closes** its previous fs-watcher/timer, so it never leaks a handle.

Both are optional — hot reload works without them.

## Writing your own adapter

1. Watch the `.relove` **directory**, not the single file (editors save atomically via
   temp-file + rename, which breaks a watch bound to one inode).
2. Parse `status.json` as JSON; check `schemaVersion`.
3. On `error` / `restart_required`, publish a diagnostic at `file:line` when `file`
   resolves to a real path. Optionally parse `stack`
   (`([\w\-./]+\.lua):(\d+)`) into related locations.
4. On any other status, clear diagnostics and update a status indicator.

The full contract also lives in [`editor/PROTOCOL.md`](../editor/PROTOCOL.md).
