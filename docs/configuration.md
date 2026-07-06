# Configuration

[← Back to index](./index.md)

`relove` needs no configuration. When you want to tune it, there are two ways —
inline options and a config file — and inline options win.

## Inline options

Pass a table to `start(...)`:

```lua
require("dev.relove").start({ interval = 0.1, overlayKey = "f9" })
```

## `.relove.lua`

Drop a `.relove.lua` file at the project root that returns a table:

```lua
-- .relove.lua
return {
    interval = 0.1,          -- poll interval in seconds (default 0.15)
    overlayKey = "f9",       -- overlay toggle key (default f8)
    overlay = true,          -- set false to disable the overlay entirely
    reloadMain = false,      -- opt-in main.lua re-run; default false
    ignore = {               -- paths/globs to never watch or reload
        "vendor/",           -- trailing slash = directory prefix
        "*.min.lua",         -- * and ? glob the full path or basename
    },
}
```

Inline `start(options)` wins over `.relove.lua` for any key set in both. A broken
`.relove.lua` (syntax error, or a field of the wrong type) is ignored with a printed
warning rather than blocking startup — a bad `interval` falls back to the default
instead of crashing the game.

## Options

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `interval` | number | `0.15` | Seconds between file-change polls. |
| `overlayKey` | string | `"f8"` | Key that toggles the overlay. |
| `overlay` | boolean | `true` | `false` disables the overlay entirely. |
| `reloadMain` | boolean | `false` | Opt in to re-running `main.lua` on change. See [main.lua reload](./main-reload.md). |
| `ignore` | table | — | List of paths/globs never watched or reloaded. |

## Ignore globs

`ignore` matching rules:

- A **trailing slash** (`vendor/`) is a directory prefix — it matches every path
  under that folder.
- Otherwise `*` and `?` are globs matched against **the full path or the basename**,
  so `*.min.lua` catches nested files too.

`ignore` applies to every watched file — Lua modules **and** the assets you load
through the [asset accessors](./asset-reload.md). An over-broad glob like `*.lua`
also silences `main.lua` / `conf.lua` restart detection, so keep globs specific.
