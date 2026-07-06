# Installation

[← Back to index](./index.md)

`relove` is a command-line tool. Install it once, then use `relove init` to add
the hot-reload runtime to any LÖVE game. You need a `lua` **or** `luajit`
interpreter on `PATH` — LÖVE already ships `luajit`, so most game machines qualify
without extra installs.

## Homebrew (macOS, Linux)

```sh
brew install yelsed/relove/relove
```

This pulls the formula from the `yelsed/homebrew-relove` tap automatically. Update
with `brew upgrade relove`.

## Install script (no Homebrew)

```sh
curl -fsSL https://raw.githubusercontent.com/yelsed/relove/master/install.sh | sh
```

Installs the runtime to `~/.relove` and a `relove` wrapper to `~/.local/bin`. The
script prints a `PATH` hint if that directory isn't already on your `PATH`.
Overrides:

| Variable | Default | Meaning |
|----------|---------|---------|
| `RELOVE_VERSION` | `master` | Git tag to install, e.g. `v0.1.0`. |
| `RELOVE_PREFIX` | `$HOME/.relove` | Where the runtime is placed. |
| `RELOVE_BIN` | `$HOME/.local/bin` | Where the `relove` wrapper is written. |

## From source

Clone the repository and run the wrapper directly — useful for hacking on relove
itself:

```sh
git clone https://github.com/yelsed/relove
cd relove
./relove init /path/to/your-love-game
```

The wrapper finds its runtime next to itself, so no install step is needed.

## Verify

```sh
relove doctor /path/to/your-love-game
```

See [Getting started](./getting-started.md) to patch and run a game, or the
[CLI reference](./cli.md) for every command.
