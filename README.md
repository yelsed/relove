# relove

`relove` is a small, drop-in hot-reload helper for [LÖVE](https://love2d.org/) games.

```text
save Lua file -> running game reloads module -> errors are shown without killing the session
```

It sits beside a normal LÖVE game and keeps your code reloadable while you work.
Remove it and the game is byte-for-byte what it was — no framework, no lock-in.

📖 **Full documentation lives in [`docs/`](docs/index.md).** This page is the
overview; every topic below links into it.

## Quick start

Install the CLI (needs `lua` or `luajit` on `PATH` — LÖVE ships `luajit`):

```sh
brew install yelsed/relove/relove
# or, without Homebrew:
curl -fsSL https://raw.githubusercontent.com/yelsed/relove/master/install.sh | sh
```

Then add relove to a game and run it:

```sh
relove init /path/to/your-love-game   # patch a game
relove run  /path/to/your-love-game   # launch it with love
```

Edit any table-returning module under `src/` while the game runs — the change
applies in place. Press `F8` to toggle the in-game status overlay.

New to it? See [Installation](docs/installation.md) and [Getting started](docs/getting-started.md).

## Features

- Drop-in install into an existing LÖVE project.
- Watches loaded Lua modules and reloads changed ones in place.
- Keeps the last working code active when a reload fails.
- In-game status/error overlay with recent history.
- Opt-in image / shader / audio hot reload.
- Per-module reload hooks (`__accept` veto, `__dispose`, `__hotreload`).
- Machine-readable status files for editors and other tooling.
- Project-local CLI, plus optional VS Code and Neovim adapters.

## What relove is not

Not a game framework. It does not require a scene manager, an entity-component
system, a custom asset pipeline, a custom editor, or an LSP server. Your game
keeps using plain `love.load` / `love.update` / `love.draw`; `relove` is just
development tooling around them.

## Documentation

| Page | What it covers |
|------|----------------|
| [Getting started](docs/getting-started.md) | Install, patch a game, run it, module style |
| [Configuration](docs/configuration.md) | `.relove.lua`, `start()` options, ignore globs |
| [Reload hooks](docs/reload-hooks.md) | `__accept` veto, `__dispose`, `__hotreload` |
| [Asset hot reload](docs/asset-reload.md) | Opt-in image / shader / audio reload |
| [main.lua reload](docs/main-reload.md) | Opt-in re-run of boot code |
| [CLI reference](docs/cli.md) | `init` · `remove` · `status` · `logs` · `doctor` · `run` |
| [Editor adapters](docs/editor-adapters.md) | VS Code, Neovim, and the `.relove/` status contract |
| [Platform notes](docs/platform-notes.md) | Linux, macOS, Windows |
| [Troubleshooting](docs/troubleshooting.md) | Common problems and fixes |

## Development only

`relove` is development tooling — do not ship it in a released game. Before
packaging, remove the integration block:

```sh
./relove remove /path/to/your-love-game
```

or guard it behind your own development flag.

## License

MIT — see [LICENSE](LICENSE). Free to use, modify, and distribute; keep the
copyright notice, no warranty.
