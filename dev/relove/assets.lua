-- Opt-in asset hot reload. A game loads assets through relove.image/shader/audio
-- instead of love.graphics.newImage/newShader/love.audio.newSource; relove then
-- interns them by path, watches the files, and reloads on change.
--
-- Images reload in place with Image:replacePixels when the dimensions still match,
-- so a cached handle (local hero = relove.image("hero.png")) updates without a
-- re-fetch. Shaders and audio are userdata with no in-place update, so they are
-- swapped and the game must re-fetch through the accessor to see the new one.
--
-- Games that never call these accessors are completely unaffected.

local Assets = {}

local function getInfo(path)
    if love and love.filesystem then
        local info = love.filesystem.getInfo(path, "file")
        if info then
            return { size = info.size or 0, modtime = info.modtime or 0 }
        end
    end

    return nil
end

local function loadObject(kind, path, sourceType)
    if kind == "image" then
        return love.graphics.newImage(path)
    elseif kind == "shader" then
        return love.graphics.newShader(path)
    elseif kind == "audio" then
        return love.audio.newSource(path, sourceType or "static")
    end

    error("unknown asset kind: " .. tostring(kind))
end

function Assets.new(reporter, overlay, options)
    options = options or {}

    return setmetatable({
        reporter = reporter,
        overlay = overlay,
        interval = options.interval or 0.15,
        elapsed = 0,
        entries = {},
    }, { __index = Assets })
end

function Assets:report(status)
    if self.overlay then
        self.overlay.setStatus(status)
    end
    if self.reporter then
        self.reporter.write(status)
    end
end

-- Key by kind + sourceType + path so the same file used as two kinds (or a source
-- as both static and stream) interns as distinct entries instead of colliding.
local function entryKey(kind, path, sourceType)
    return table.concat({ kind, sourceType or "", path }, "\0")
end

function Assets:intern(kind, path, sourceType)
    local key = entryKey(kind, path, sourceType)
    local entry = self.entries[key]
    if entry then
        return entry.object
    end

    -- A load failure here is a genuine missing/broken asset; let it surface like a
    -- normal love error rather than swallowing it.
    local object = loadObject(kind, path, sourceType)
    local info = getInfo(path) or {}

    self.entries[key] = {
        kind = kind,
        path = path,
        object = object,
        sourceType = sourceType,
        modtime = info.modtime or 0,
        size = info.size or 0,
    }

    return object
end

function Assets:image(path)
    return self:intern("image", path)
end

function Assets:shader(path)
    return self:intern("shader", path)
end

function Assets:audio(path, sourceType)
    return self:intern("audio", path, sourceType)
end

-- Release the userdata we're about to drop so a swap doesn't leak (and stop a
-- playing Source so it doesn't keep sounding under the replacement).
local function releaseOld(entry)
    if entry.kind == "audio" then
        pcall(function() entry.object:stop() end)
    end
    pcall(function() entry.object:release() end)
end

function Assets:reload(entry)
    local path = entry.path
    local info = getInfo(path)
    if not info then
        self:report({ status = "error", file = path, message = "asset file missing", usingLastGood = true })
        return
    end

    if entry.kind == "image" then
        -- Decode once. Prefer in-place replacePixels so cached handles update; it
        -- needs matching dimensions, so on mismatch build a new Image from the same
        -- data and swap. A decode failure keeps the last-good image.
        local okData, imageData = pcall(love.image.newImageData, path)
        if not okData then
            self:report({ status = "error", file = path, message = tostring(imageData), usingLastGood = true })
            return
        end

        local inPlace = pcall(function() entry.object:replacePixels(imageData) end)
        if not inPlace then
            local okNew, newImage = pcall(love.graphics.newImage, imageData)
            if not okNew then
                self:report({ status = "error", file = path, message = tostring(newImage), usingLastGood = true })
                return
            end
            releaseOld(entry)
            entry.object = newImage
        end

        entry.modtime = info.modtime or 0
        entry.size = info.size or 0
        local suffix = inPlace and " (in place)" or " (swapped; re-fetch to see it)"
        self:report({ status = "ok", file = path, message = "reloaded asset " .. path .. suffix, usingLastGood = false })
        return
    end

    -- Shaders and audio are userdata with no in-place update: rebuild and swap.
    local ok, newObject = pcall(loadObject, entry.kind, path, entry.sourceType)
    if not ok then
        self:report({ status = "error", file = path, message = tostring(newObject), usingLastGood = true })
        return
    end

    releaseOld(entry)
    entry.object = newObject
    entry.modtime = info.modtime or 0
    entry.size = info.size or 0
    self:report({ status = "ok", file = path, message = "reloaded asset " .. path .. " (swapped; re-fetch to see it)", usingLastGood = false })
end

function Assets:scan()
    for _, entry in pairs(self.entries) do
        local info = getInfo(entry.path)
        if info and (info.modtime ~= entry.modtime or info.size ~= entry.size) then
            self:reload(entry)
        end
    end
end

function Assets:update(dt)
    self.elapsed = self.elapsed + (dt or 0)

    if self.elapsed < self.interval then
        return
    end

    self.elapsed = 0
    self:scan()
end

return Assets
