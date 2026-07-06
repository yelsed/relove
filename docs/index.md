# relove

Drop-in hot reload for [LÖVE](https://love2d.org) games. Edit a Lua module while
the game runs and see the change instantly — no restart, no framework lock-in.

`relove` sits beside your game: it patches `main.lua` with a small opt-in block,
watches your source files, and swaps changed modules in place. Remove it and your
game is byte-for-byte what it was.

## Why it works

Lua modules that return tables can be reloaded because `relove` mutates the *old*
exported table in place — so every live `local M = require("...")` keeps working
against the same reference. That single trick is the whole engine; everything else
(assets, hooks, editor feedback) builds on it.

## Documentation

| Page | What it covers |
|------|----------------|
| [Installation](./installation.md) | Homebrew, install script, from source |
| [Getting started](./getting-started.md) | Patch a game, run it, module style |
| [Configuration](./configuration.md) | `.relove.lua`, `start()` options, ignore globs |
| [Reload hooks](./reload-hooks.md) | `__accept` veto, `__dispose`, `__hotreload` |
| [Asset hot reload](./asset-reload.md) | Opt-in image / shader / audio reload |
| [main.lua reload](./main-reload.md) | Opt-in re-run of boot code |
| [CLI reference](./cli.md) | `init` · `remove` · `status` · `logs` · `doctor` · `run` |
| [Editor adapters](./editor-adapters.md) | VS Code, Neovim, and the `.relove/` protocol |
| [Platform notes](./platform-notes.md) | Linux, macOS, Windows |
| [Troubleshooting](./troubleshooting.md) | Common problems and fixes |

## Status

Prototype / early development. Runs on Linux, macOS, and Windows. The runtime is
shell-free on the hot path; the only OS call left is `mkdir`.
