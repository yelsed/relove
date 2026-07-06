# relove editor protocol

`relove` writes machine-readable state to `<project>/.relove/` so any editor or
agent can react without screen-scraping. This is a stable, versioned contract;
the VS Code and Neovim adapters in this repo are just two consumers.

## Files

| File | Format | Contents |
|------|--------|----------|
| `.relove/status.json` | one JSON object | the current state only (overwritten each event) |
| `.relove/events.log` | JSON lines | append-only history of every event |
| `.relove/errors.log` | JSON lines | append-only history of `error` and `restart_required` events only |

Prefer `status.json` for "what is the state now", and `events.log` for history.

## Payload schema (`schemaVersion` 1)

Every object carries these fields:

| Field | Type | Notes |
|-------|------|-------|
| `schemaVersion` | number | Contract version. Currently `1`. Adapters should check this. |
| `status` | string | One of the status values below. |
| `file` | string | Source path relative to the project (e.g. `src/player.lua`), or `relove` for lifecycle messages. For runtime errors it may be a callback label (e.g. `love.update`) rather than a path — do not assume it is a file. |
| `message` | string | Human-readable detail. |
| `usingLastGood` | boolean | `true` when the game is still running the previous working code. |
| `updatedAt` | number | Seconds from `love.timer.getTime()` (monotonic, not wall clock). |
| `line` | number? | Present on some errors; 1-based source line. |
| `stack` | string? | Present on runtime errors; a full Lua traceback (newline-separated frames). |

## Status values

| `status` | Meaning | Suggested editor treatment |
|----------|---------|----------------------------|
| `info` | Lifecycle / watching messages. | Status line only. |
| `ok` | A module reloaded successfully. | Clear diagnostics; status line. |
| `error` | Reload or runtime error; last-good code kept. | Diagnostic at `file:line`; parse `stack` for clickable frames. |
| `restart_required` | `main.lua`/`conf.lua` changed; needs a restart. | Warning diagnostic. |
| `vetoed` | A module's `__accept` refused the reload; running code unchanged. | Status line (optionally an info diagnostic). |

## Example

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

## Writing an adapter

1. Watch `.relove/status.json` (watch the directory, not the file — editors save
   atomically via rename).
2. Parse it as JSON; check `schemaVersion`.
3. On `error` / `restart_required`, publish a diagnostic at `file:line` when
   `file` resolves to a real path. Optionally parse `stack` (`([\w\-./]+\.lua):(\d+)`)
   into related locations.
4. On any other status, clear diagnostics and update a status indicator.
