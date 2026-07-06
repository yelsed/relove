# Troubleshooting

[← Back to index](./index.md)

First, run [`relove doctor`](./cli.md#relove-doctor) — it checks the four things that
break setups (LÖVE on PATH, runtime present, `main.lua` patched, `.relove/` writable).

## A module edit doesn't reload

- Confirm the module **returns a table** and you use it via `require`. See
  [module style](./getting-started.md#recommended-module-style).
- Check it isn't excluded by an [`ignore` glob](./configuration.md#ignore-globs) — an
  over-broad glob like `*.lua` silences everything.
- The poll uses modtime, which has ~1s resolution. Two same-size edits inside one
  second can be missed; save again.

## A reload was "vetoed"

A module's [`__accept`](./reload-hooks.md#__acceptold--veto-a-reload) hook refused the
reload (e.g. a live coroutine or transition). The running code is unchanged. Save again
once the module is in a safe state — a re-save always re-attempts.

## `main.lua` changes ask for a restart

That's the default. `main.lua` is restart-only unless you opt in with
[`reloadMain = true`](./main-reload.md). `conf.lua` is always restart-only.

## An edited image doesn't update on screen

- Only assets loaded through the [accessors](./asset-reload.md) (`relove.image`, etc.)
  are tracked — not raw `love.graphics.newImage`.
- If you changed the image's **dimensions**, it was swapped, not patched in place —
  re-fetch the handle: `hero = relove.image("assets/hero.png")`.

## The overlay isn't showing

- It may be toggled off — press `F8` (or your `overlayKey`).
- It may be disabled via `overlay = false` in [configuration](./configuration.md).

## `.relove/status.json` isn't updating in my editor

Watch the `.relove` **directory**, not the file directly — editors save atomically via
temp-file + rename, which breaks a watch bound to a single inode. See
[Editor adapters](./editor-adapters.md#writing-your-own-adapter).
