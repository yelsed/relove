# CLI reference

[← Back to index](./index.md)

The CLI runs under `lua` or `luajit` (no LÖVE needed). Once
[installed](./installation.md) the command is `relove`. From a source checkout use
the `./relove` wrapper (`relove.bat` on Windows), or run
`lua tools/relove.lua <command> [project]` directly. `[project]` defaults to `.`.

```sh
relove init   [project]
relove remove [project]
relove status [project]
relove logs   [project]
relove doctor [project]
relove run    [project]
```

## `relove init`

Copies the runtime into `<project>/dev/relove/`, copies the CLI and wrappers, backs
up `main.lua` to `main.lua.relove-backup`, and prepends the hot-reload block to
`main.lua`. Idempotent — the block is never duplicated.

Runtime files are copied in pure Lua from a fixed manifest (no `cp`), so `init` works
the same on every platform.

## `relove remove`

Strips the hot-reload block from `main.lua`, restoring your original code. Only the
block is removed; surrounding code (including blank lines you wrote) is preserved.

## `relove status`

Prints the current `.relove/status.json` — the latest reload event as one JSON
object. Useful for editor integrations and other tooling.

## `relove logs`

Prints the append-only `.relove/events.log` (JSON lines) — the full event history.

## `relove doctor`

Checks a game's setup and prints a pass/fail report:

- `love` runnable on `PATH`
- runtime present (`dev/relove/init.lua`)
- `main.lua` contains the relove block
- `.relove/` is writable

Handy right after `init`, and as a quick health check for CI and other tooling.

## `relove run`

Launches the game with `love`, from the project directory (so the process working
directory matches the game). Equivalent to running `love <project>` yourself, plus
the correct working directory for games that use relative file paths.

See [Runtime feedback files](./editor-adapters.md#the-relove-directory) for what the
runtime writes into `.relove/`.
