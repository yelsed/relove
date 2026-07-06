# Getting started

[← Back to index](./index.md)

## Prerequisites

- LÖVE installed and runnable as `love`
- a standalone `lua` (or `luajit`) executable on `PATH`
- a shell to run the wrapper: POSIX `sh` uses `relove`, Windows `cmd` uses `relove.bat`

Run [`relove doctor`](./cli.md#relove-doctor) any time to check your setup.

## Install into a game

From the `relove` repository, point `init` at your game project:

```sh
./relove init /path/to/game
```

`init`:

- copies the runtime into `<game>/dev/relove/` and the CLI into `<game>/tools/`,
- writes a backup at `main.lua.relove-backup`,
- prepends a small opt-in block to `main.lua`:

```lua
-- relove dev hot reload start
if love.filesystem.getInfo("dev/relove/init.lua") then
    require("dev.relove").start()
end
-- relove dev hot reload end
```

The `getInfo` guard means the block is inert if the runtime isn't present, so you
can ship the same `main.lua` without relove installed. `init` is idempotent — run
it again and the block is not duplicated.

## Run

```sh
./relove run /path/to/game
```

This launches `love` with the game directory as its working directory. You can also
run the game however you normally do (`love /path/to/game`); the reload block starts
`relove` automatically.

Press `F8` to toggle the in-game overlay (configurable — see
[Configuration](./configuration.md)).

## Remove

```sh
./relove remove /path/to/game
```

Strips the block from `main.lua`, leaving your original code intact.

## Recommended module style

`relove` reloads **table-returning modules** best:

```lua
-- src/player.lua
local Player = {}

function Player.update(entity, dt)
    entity.x = entity.x + dt * 60
end

return Player
```

Because the returned table is patched in place, every `local Player = require("src.player")`
elsewhere keeps working after a reload. Function-returning modules can reload too,
but old local references may still point at the previous function.

Put reloadable gameplay code in `src/` (or similar) modules. Keep `main.lua` thin —
see [main.lua reload](./main-reload.md) for why.
