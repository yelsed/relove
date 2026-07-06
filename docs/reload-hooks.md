# Reload hooks

[← Back to index](./index.md)

A table-returning module can define optional hooks that `relove` calls during a
reload. All are optional; a module that defines none reloads normally.

```lua
local Scene = {}

-- Called just BEFORE the reload, on the OLD module. Return false to veto a reload
-- the module can't safely take right now. The new chunk is not executed on a veto,
-- so it has no side effects. An optional second return is shown as the reason.
function Scene.__accept(old)
    if old.transition and old.transition:isRunning() then
        return false, "mid-transition"
    end
end

-- Called on the OLD module right before its table is patched, so it can release
-- resources it owns (timers, threads, canvases).
function Scene.__dispose(old)
    if old.canvas then old.canvas:release() end
end

-- Called on the patched module AFTER the reload, with the freshly loaded table,
-- so it can migrate or re-derive state.
function Scene.__hotreload(current, incoming)
    current.version = (current.version or 0) + 1
end

return Scene
```

## `__accept(old)` — veto a reload

Runs on the old export before the new chunk executes. Return `false` (optionally
with a reason string) to refuse the reload; return `nil`/`true` to let it proceed.

When a module vetoes, `relove` keeps the running code and reports status `vetoed`
(the file changed on disk but was not applied). **A re-save re-attempts** — even
saving byte-identical content triggers another attempt, so once the module is in a
state where it accepts (the coroutine finished, the transaction committed), the next
save applies.

This is the practical answer to coroutine-safe reload: a module with a live
coroutine returns `false` until it's safe.

## `__dispose(old)` — release resources

Runs on the old export right before its table is patched. Use it to free things the
module owns — release canvases, stop timers, close handles — so the reload doesn't
leak them.

## `__hotreload(current, incoming)` — migrate state

Runs on the patched module after the reload. `current` is the live (patched) table;
`incoming` is the freshly loaded one. Use it to bump a version, re-derive cached
state, or reconcile anything the plain shallow patch didn't cover.

## Ordering

For a normal table reload:

1. `__accept(old)` — may veto.
2. new chunk runs.
3. `__dispose(old)`.
4. old table is shallow-patched with the new fields.
5. `__hotreload(current, incoming)`.

Hook errors are caught (`pcall`) so a throwing hook can't take down the reload loop.
