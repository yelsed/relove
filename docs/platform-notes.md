# Platform notes

[← Back to index](./index.md)

`relove` runs on Linux, macOS, and Windows.

## Shell usage

The **hot path is shell-free**: the watcher/reloader read source files with
`love.filesystem.read` and hash them with a pure-Lua rolling checksum. No `cksum`,
`cat`, or `io.popen` in the reload loop.

The **install path is shell-free too**: `relove init` copies runtime files in pure
Lua from a fixed manifest (no `cp`).

The one remaining OS call is directory creation, because Lua cannot create a directory
on its own:

```text
lua      (runs the CLI)
mkdir    (POSIX `mkdir -p`, Windows `mkdir`; the one unavoidable shell call)
```

`relove init` creates `.relove/` up front, so at runtime the directory almost always
already exists and no `mkdir` fires on the status-write path.

## Wrappers

- POSIX: `relove` (a `sh` wrapper)
- Windows: `relove.bat`

Both call `lua tools/relove.lua`. OS detection uses `package.config:sub(1, 1)` (`/` on
POSIX, `\` on Windows), which works under plain Lua and under LÖVE.

## Windows status

The Windows code paths (quoting, `mkdir`, `cd /d`, the `.bat` wrapper, backslash
`arg[0]` normalization) are implemented and unit-covered, but not yet run end-to-end
on a real Windows machine. Treat Windows as "supported, pending real-hardware
verification". Run [`relove doctor`](./cli.md#relove-doctor) to sanity-check a setup.
