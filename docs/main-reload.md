# main.lua reload (opt-in)

[← Back to index](./index.md)

By default `relove` does **not** hot-reload `main.lua` as normal gameplay code. When
`main.lua` changes it reports `restart_required` and keeps running the old boot code.

This is deliberate. Re-running `main.lua` can duplicate state, reset callbacks, and
re-run one-time setup. Put reloadable gameplay in `src/` modules, which hot-reload
cleanly, and keep `main.lua` thin.

## Opting in

If your `main.lua` is thin — it only wires `love.*` callbacks to modules and holds no
state of its own — you can let `relove` re-run it on change instead of asking for a
restart:

```lua
require("dev.relove").start({ reloadMain = true })
```

With `reloadMain`, a `main.lua` change re-runs the file so edited callbacks take
effect, but **`love.load` is not called again**. Live state lives in your modules
(which reload separately) and survives.

## The catch

Any file-scope code in `main.lua` runs again on every reload, so this is only safe
for a thin `main.lua` that just wires callbacks. If the re-run fails partway, some
callbacks may already be re-bound and there is no clean rollback — `relove` reports
the error honestly with `usingLastGood = false` (the game may be in an inconsistent
state) rather than pretending it recovered.

`conf.lua` is **always** restart-only. LÖVE reads it before the game starts, so a
change can't be applied live.
