# Asset hot reload (opt-in)

[← Back to index](./index.md)

`relove` can hot-reload images, shaders, and audio — but only for assets you load
through its accessors instead of the raw LÖVE loaders. A game that never calls these
accessors is completely unaffected.

```lua
local relove = require("dev.relove")

local hero  = relove.image("assets/hero.png")
local blur  = relove.shader("assets/blur.glsl")
local hit   = relove.audio("assets/hit.wav")            -- "static" by default
local music = relove.audio("assets/song.ogg", "stream")
```

`relove` interns each asset by path (and, for audio, by source type), watches the
file, and reloads on change. Assets loaded with the raw `love.graphics.newImage` /
`love.audio.newSource` are not tracked.

## Images reload in place

When the edited image keeps the **same dimensions**, `relove` uses
`Image:replacePixels`, so a cached handle updates with no re-fetch:

```lua
function love.draw()
    love.graphics.draw(hero, 100, 100)   -- edits to hero.png show up live
end
```

If the image **changes dimensions**, it is swapped for a new `Image` instead. Your
cached `hero` handle keeps drawing the old pixels (it is not force-released — it's
dropped for the garbage collector) until you re-fetch it through the accessor:

```lua
hero = relove.image("assets/hero.png")   -- re-fetch after a size change
```

## Shaders and audio are swapped

Shaders and audio are userdata with no in-place update, so `relove` replaces the
interned object. To see the new one, re-fetch it at the point of use:

```lua
love.graphics.setShader(relove.shader("assets/blur.glsl"))
```

On an audio swap the old `Source` is stopped and released, so it doesn't keep
sounding or leak under the replacement.

## Notes

- A failed reload (missing file, decode error) keeps the last-good asset and reports
  an `error`.
- Asset reload respects [`ignore` globs](./configuration.md#ignore-globs) — an ignored
  path is never reloaded.
- The accessors return `nil` before `start()` has run, so a mis-ordered call fails
  loudly rather than silently.
