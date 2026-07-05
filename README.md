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
```

Press `F8` to toggle the overlay.

When reload fails, the overlay shows that the game is using last-good code.

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

## Optional VS Code adapter

The repository includes a minimal VS Code adapter:

```text
editor/vscode-relove/
  package.json
  extension.js
```

It watches:

```text
.relove/status.json
```

and turns `relove` errors into editor diagnostics.

The adapter is optional. Hot reload works without it.

## Package layout

```text
relove
├── relove                         # shell wrapper for the CLI
├── tools/
│   └── relove.lua                 # CLI implementation
├── dev/
│   ├── relove.lua                 # runtime entrypoint copied into games
│   └── relove/
│       ├── init.lua               # starts runtime and custom run loop
│       ├── module_registry.lua    # tracks required modules
│       ├── watcher.lua            # detects source changes
│       ├── reloader.lua           # reloads modules safely
│       ├── reporter.lua           # writes status/log files
│       └── overlay.lua            # draws in-game feedback
└── editor/
    └── vscode-relove/
        ├── package.json
        └── extension.js
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

- choose and add a license
- verify the Windows path end-to-end on a real Windows machine (logic is portable; not yet run there)
- add automated tests for the watcher/reloader
- add installation examples for common project layouts
- decide whether the VS Code adapter should be packaged as a real extension

## License

No license has been chosen yet.

If this should be usable by everyone, add a permissive license before publishing. MIT is the obvious default for this kind of tool, but the project owner should make that decision.
