# relove

`relove` is a small, drop-in hot-reload helper for [LÖVE](https://love2d.org/) games.

It is built for the development loop most LÖVE projects want:

```text
save Lua file -> running game reloads module -> errors are shown without killing the session
```

The goal is not to turn your game into a framework project. `relove` sits beside a normal LÖVE game and keeps the game code reloadable while you work.

## Status

Prototype / early development.

Runs on Linux, macOS, and Windows. File change detection and source reads use
`love.filesystem` and a pure-Lua hash, so the hot path needs no shell utilities.
Directory creation is the one remaining OS call and is handled per platform.

The core design is intentionally small and boring:

- no LuaRocks dependency
- no required scene system
- no required ECS
- no required editor plugin
- no original `livelove` code vendored
- optional VS Code adapter included

## Features

- Drop-in install command for an existing LÖVE project.
- Watches loaded Lua modules while the game runs.
- Reloads changed table-returning modules.
- Keeps the last working code active when reload fails.
- Shows an in-game status/error overlay.
- Writes machine-readable status for agents and editor tooling.
- Provides a project-local CLI.
- Includes an optional VS Code diagnostics adapter.

## What relove is not

`relove` is not a game framework.

It does not require you to use:

- a specific scene manager
- an entity-component-system
- a custom asset pipeline
- a custom editor
- an LSP server

Your game can still use plain LÖVE callbacks:

```lua
function love.load()
end

function love.update(dt)
end

function love.draw()
end
```

`relove` is development tooling around that.

## Prerequisites

`relove` runs on Linux, macOS, and Windows.

You need:

- LÖVE installed and runnable as `love`
- a standalone `lua` executable on `PATH`
- a shell to run a wrapper: POSIX `sh` uses `relove`; Windows `cmd` uses `relove.bat`

The installer copies runtime files in pure Lua (no `cp`/`cksum`/`cat`). The only
shell command still used is `mkdir` (POSIX `mkdir -p`, Windows `mkdir`), because
Lua cannot create a directory on its own. Run `relove doctor` to check your setup.

## Installation

Clone or copy this repository somewhere outside your game project:

```bash
git clone <your-relove-repo-url> relove
cd relove
```

Install `relove` into a LÖVE game project:

```bash
./relove init /path/to/your-love-game
```

Then run your game:

```bash
cd /path/to/your-love-game
love .
```

You can also run through the project-local command copied into the game:

```bash
./relove run .
```

## What `relove init` adds

`relove init` copies the runtime into your game and inserts one marked block at the top of `main.lua`:

```lua
-- relove dev hot reload start
if love.filesystem.getInfo("dev/relove/init.lua") then
    require("dev.relove").start()
end
-- relove dev hot reload end
```

It also creates:

```text
dev/relove.lua
dev/relove/
tools/relove.lua
relove
.relove/
main.lua.relove-backup
```

`relove init` is idempotent. Running it twice should not duplicate the `main.lua` block.

## Removing relove from a game

From inside the game project:

```bash
./relove remove .
```

That removes only the marked block from `main.lua`.

The runtime files, project-local CLI files, `.relove/`, and `main.lua.relove-backup` are left in place so you can inspect or delete them manually.

## CLI commands

From a game project where `relove` has been installed:

```bash
./relove init .
./relove remove .
./relove run .
./relove status .
./relove logs .
./relove doctor .
```

From this package repository:

```bash
./relove init /path/to/game
./relove run /path/to/game
./relove status /path/to/game
./relove logs /path/to/game
```

### `relove init`

Copies the runtime into a game project and patches `main.lua`.

### `relove remove`

Removes the marked `main.lua` integration block.

### `relove run`

Runs:

```bash
love .
```

inside the target project.

### `relove status`

Prints the current reload status from:

```text
.relove/status.json
```

### `relove logs`

Prints the event history from:

```text
.relove/events.log
```

This is useful for agents, editor integrations, and terminal-based helpers.

### `relove doctor`

Checks a game's setup and prints a pass/fail report:

- `love` runnable on `PATH`
- runtime present (`dev/relove/init.lua`)
- `main.lua` contains the relove block
- `.relove/` is writable

Useful right after `init`, and as a quick health check for agents.

## Runtime feedback files

Inside a game project, `relove` writes:

```text
.relove/status.json
.relove/events.log
.relove/errors.log
```

### `.relove/status.json`

Current state only.

Example:

```json
{
  "schemaVersion": 1,
  "status": "ok",
  "file": "src/settings.lua",
  "message": "reloaded src.settings",
  "usingLastGood": false,
  "updatedAt": 123.456
}
```

### `.relove/events.log`

Append-only JSON-lines event log.

Example:

```json
{"file":"relove","message":"watching saved Lua files","status":"info","updatedAt":0.13,"usingLastGood":false}
{"file":"src/settings.lua","message":"reloaded src.settings","status":"ok","updatedAt":4.21,"usingLastGood":false}
```

Agents and editor tools should prefer this file when they need history.

### `.relove/errors.log`

Append-only JSON-lines problem log.

Contains:

- `error`
- `restart_required`

This makes important failures easy to read without scanning all events.

## In-game overlay

`relove` draws a small overlay in the running game.

It can show:

```text
relove: info
relove: ok
relove: error
relove: restart_required
relove: vetoed
```

Below the current status, the overlay lists the last few reload events as history.

Press `F8` to toggle the overlay.

When reload fails, the overlay shows that the game is using last-good code.

## Configuration

Options can be passed inline to `start(...)`:

```lua
require("dev.relove").start({ interval = 0.1, overlayKey = "f9" })
```

Or placed in an optional `.relove.lua` file at the project root, which returns a
table:

```lua
-- .relove.lua
return {
    interval = 0.1,          -- poll interval in seconds (default 0.15)
    overlayKey = "f9",       -- overlay toggle key (default f8)
    overlay = true,          -- set false to disable the overlay entirely
    reloadMain = false,      -- opt-in main.lua re-run (see below); default false
    ignore = {               -- paths/globs to never watch or reload
        "vendor/",           -- trailing slash = directory prefix
        "*.min.lua",         -- * and ? glob the full path or basename
    },
}
```

Inline `start(options)` wins over `.relove.lua` for any key set in both. A broken
`.relove.lua` is ignored (with a printed warning) rather than blocking startup.

`ignore` applies to every watched file, so an over-broad glob like `*.lua` also
silences `main.lua`/`conf.lua` restart detection — keep ignore globs specific.

## Recommended module style

`relove` works best with modules that return tables.

Good:

```lua
local Player = {}

function Player.update(player, dt)
    player.x = player.x + player.speed * dt
end

return Player
```

Why this works well:

```lua
local Player = require("src.player")
```

When `src/player.lua` changes, `relove` reloads the module and patches the existing `Player` table in place. Existing references keep working.

Less ideal:

```lua
return function(dt)
    -- update something
end
```

Function-returning modules can be reloaded, but old local references may still point at the previous function.

## Per-module reload hooks

A table-returning module can define optional hooks that `relove` calls during a
reload. All are optional; a module that defines none reloads normally.

```lua
local Scene = {}

-- Called just before the reload, on the OLD module. Return false to veto a
-- reload the module can't safely take right now (e.g. a suspended coroutine or
-- an in-flight transaction). The new chunk is not executed on a veto, so it has
-- no side effects. A re-save re-attempts. An optional second return is shown as
-- the reason.
function Scene.__accept(old)
    if old.transition and old.transition:isRunning() then
        return false, "mid-transition"
    end
end

-- Called on the OLD module right before its table is patched, so it can release
-- resources it owns (timers, threads, canvases).
function Scene.__dispose(old)
    if old.canvas then old.canvas:release() end
end

-- Called on the patched module after the reload, with the freshly loaded table,
-- so it can migrate or re-derive state.
function Scene.__hotreload(current, incoming)
    current.version = (current.version or 0) + 1
end

return Scene
```

When `__accept` vetoes, `relove` keeps the running code and reports status
`vetoed` (the file changed on disk but was not applied).

## Asset hot reload (opt-in)

`relove` can hot-reload images, shaders, and audio, but only for assets you load
through its accessors instead of the raw LÖVE loaders:

```lua
local relove = require("dev.relove")

local hero   = relove.image("assets/hero.png")
local blur   = relove.shader("assets/blur.glsl")
local hit    = relove.audio("assets/hit.wav")          -- "static" by default
local music  = relove.audio("assets/song.ogg", "stream")
```

`relove` interns each asset by path, watches the file, and reloads on change.
Assets loaded with the raw `love.graphics.newImage` / `love.audio.newSource` are
not tracked, and a game that never calls these accessors is unaffected.

**Images reload in place.** When the edited image keeps the same dimensions,
`relove` uses `Image:replacePixels`, so a cached handle updates without any
re-fetch:

```lua
function love.draw()
    love.graphics.draw(hero, 100, 100)   -- edits to hero.png show up live
end
```

**Shaders and audio are swapped.** They are userdata with no in-place update, so
`relove` replaces the interned object. To see the new one, re-fetch it at the
point of use:

```lua
love.graphics.setShader(relove.shader("assets/blur.glsl"))
```

If an image changes dimensions, it is swapped too (and needs the same re-fetch).
A failed reload keeps the last-good asset and reports an `error`.

## `main.lua` and `conf.lua`

`relove` does not hot-reload `main.lua` as normal gameplay code.

If `main.lua` changes, `relove` reports:

```text
main.lua changed; restart required. relove will not hot reload boot code because it can duplicate state or reset callbacks.
```

This is deliberate. Re-running `main.lua` can:

- duplicate game state
- reload assets twice
- reset callbacks unpredictably
- rerun boot-only code

`conf.lua` also requires restart because LÖVE reads it before the game starts.

Put reloadable gameplay code in modules under `src/` or a similar folder.

### Opt-in `main.lua` reload

If your `main.lua` is thin — it only wires `love.*` callbacks to modules and
holds no state of its own — you can let `relove` re-run it on change instead of
asking for a restart:

```lua
require("dev.relove").start({ reloadMain = true })
```

With `reloadMain`, a `main.lua` change re-runs the file so edited callbacks take
effect, but `love.load` is **not** called again. Live state lives in your modules
(which hot-reload separately) and survives. The catch: any file-scope code in
`main.lua` runs again, so this is only safe for a thin `main.lua`. It is off by
default. `conf.lua` is always restart-only.

## Example project shape

A simple reload-friendly LÖVE project can look like this:

```text
main.lua
conf.lua
src/
  core/
    game.lua
  scenes/
    game.lua
  settings.lua
```

`main.lua` stays thin:

```lua
require("dev.relove").start()

local Game = require("src.core.game")

function love.load()
    Game.load()
end

function love.update(dt)
    Game.update(dt)
end

function love.draw()
    Game.draw()
end
```

The actual reloadable logic lives in `src/` modules.

## Optional editor adapters

The repository includes minimal adapters for VS Code and Neovim:

```text
editor/vscode-relove/    # package.json + extension.js
editor/nvim-relove/      # lua/relove.lua + README
editor/PROTOCOL.md       # the editor-agnostic status.json contract
```

Both watch `.relove/status.json` and turn `relove` errors into editor
diagnostics. The VS Code adapter also parses the error `stack` into clickable
related-information frames.

The adapters are optional; hot reload works without them. To write your own
(Emacs, a TUI, an agent), follow the versioned contract in
[`editor/PROTOCOL.md`](editor/PROTOCOL.md).

## Package layout

```text
relove
├── relove                         # POSIX shell wrapper for the CLI
├── relove.bat                     # Windows wrapper for the CLI
├── tools/
│   └── relove.lua                 # CLI implementation
├── dev/
│   ├── relove.lua                 # runtime entrypoint copied into games
│   └── relove/
│       ├── init.lua               # starts runtime, loads config, custom run loop
│       ├── module_registry.lua    # tracks required modules
│       ├── watcher.lua            # detects source changes, applies ignore globs
│       ├── reloader.lua           # reloads modules safely, runs hooks
│       ├── assets.lua             # opt-in image/shader/audio hot reload
│       ├── reporter.lua           # writes status/log files
│       └── overlay.lua            # draws in-game feedback + history
└── editor/
    ├── PROTOCOL.md                # editor-agnostic status.json contract
    ├── vscode-relove/
    │   ├── package.json
    │   └── extension.js
    └── nvim-relove/
        ├── README.md
        └── lua/relove.lua
```

## How it works

At startup, `relove` wraps `require` so it can remember modules your game loads.

When a watched file changes:

1. `watcher.lua` detects a checksum change.
2. `reloader.lua` reads the file.
3. The file is syntax-checked.
4. If syntax fails, the old code remains active.
5. If syntax passes, the module is required again.
6. If the module returns a table, the old table is patched in place.
7. `reporter.lua` writes status/log files.
8. `overlay.lua` shows feedback in-game.

## Agent-friendly feedback

An agentic helper can inspect:

```bash
./relove status .
./relove logs .
```

Or read directly:

```text
.relove/status.json
.relove/events.log
.relove/errors.log
```

Use cases:

- detect whether the game booted
- detect whether reload succeeded
- detect whether last-good code is being used
- detect restart-required files
- surface runtime errors without screen inspection

## Development-only warning

`relove` is development tooling.

Do not ship it in a released game unless you intentionally want it there.

Before packaging a game, remove the integration block:

```bash
./relove remove .
```

or guard it behind your own development flag.

## Platform notes

`relove` runs on Linux, macOS, and Windows.

The CLI/install path uses:

```text
lua        (runs the CLI)
mkdir      (POSIX `mkdir -p`, Windows `mkdir`; the one unavoidable shell call)
```

Runtime files are copied in pure Lua; the wrapper is `relove` (POSIX) or
`relove.bat` (Windows).

The watcher/reloader backend is shell-free: it reads source files with
`love.filesystem.read` and hashes them with a pure-Lua rolling checksum.

## Troubleshooting

### Nothing reloads

Check that the runtime block is near the top of `main.lua`, before most project modules are required.

Check status:

```bash
./relove status .
```

Check logs:

```bash
./relove logs .
```

### A changed module does not update existing references

Prefer table-returning modules.

This works best:

```lua
local Module = {}
return Module
```

This is harder to update safely:

```lua
return function() end
```

### `main.lua` changed but did not hot reload

Expected.

Restart the game. `main.lua` is boot code.

### `conf.lua` changed but did not hot reload

Expected.

Restart the game. LÖVE reads `conf.lua` before the game starts.

## Public release checklist

Before publishing this repository for general use:

- license: done — MIT (see LICENSE)
- verify the Windows path end-to-end on a real Windows machine (logic is portable; not yet run there)
- automated tests: done — run `test/run.sh` (see `test/README.md`)
- add installation examples for common project layouts
- decide whether the VS Code adapter should be packaged as a real extension

## License

MIT — see [LICENSE](LICENSE). Free to use, modify, and distribute; keep the
copyright notice, no warranty.
