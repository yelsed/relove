local Watcher = {}

function Watcher.new(registry, reloader, options)
    options = options or {}

    return setmetatable({
        registry = registry,
        reloader = reloader,
        -- Guard types here too: a bad config value must fall back, never crash.
        interval = type(options.interval) == "number" and options.interval or 0.15,
        ignore = type(options.ignore) == "table" and options.ignore or nil,
        elapsed = 0,
        files = {},
    }, { __index = Watcher })
end

-- A trailing-slash glob (vendor/) is a directory prefix; otherwise `*`/`?` match
-- against the full path or the basename (so *.min.lua catches nested files too).
local function matchesGlob(path, glob)
    if glob:sub(-1) == "/" then
        return path:sub(1, #glob) == glob
    end

    local pattern = "^" .. glob:gsub("[%.%-%+%(%)%[%]%^%$%%]", "%%%0"):gsub("%*", ".*"):gsub("%?", ".") .. "$"
    if path:match(pattern) then
        return true
    end

    local base = path:match("[^/]+$")
    return base ~= nil and base:match(pattern) ~= nil
end

function Watcher:isIgnored(path)
    if not self.ignore then
        return false
    end

    for _, glob in ipairs(self.ignore) do
        if matchesGlob(path, glob) then
            return true
        end
    end

    return false
end

local function sourcePath(path)
    if love and love.filesystem and love.filesystem.getSource then
        return love.filesystem.getSource() .. "/" .. path
    end

    return path
end

local function getInfo(path)
    -- Prefer LÖVE's getInfo: it reports modtime, which lets scan() skip the
    -- expensive checksum when a file is untouched. io.open only gives size.
    if love and love.filesystem then
        local info = love.filesystem.getInfo(path, "file")
        if info then
            return { size = info.size or 0, modtime = info.modtime or 0 }
        end
    end

    local file = io.open(sourcePath(path), "r")
    if file then
        local size = file:seek("end") or 0
        file:close()
        return { size = size, modtime = 0 }
    end

    return nil
end

local function checksum(path)
    -- Pure-Lua rolling hash: portable (no `cksum`), and only runs after the
    -- getInfo modtime/size gate, so it isn't paid for untouched files.
    local content

    if love and love.filesystem and love.filesystem.read then
        content = love.filesystem.read(path)
    end

    if not content then
        local file = io.open(sourcePath(path), "r")
        if file then
            content = file:read("*a")
            file:close()
        end
    end

    if not content then
        return "missing"
    end

    local hash = #content
    for index = 1, #content do
        hash = (hash * 33 + content:byte(index)) % 4294967296
    end

    return tostring(#content) .. ":" .. tostring(hash)
end

function Watcher:remember(path, entry, info, signature)
    self.files[path] = {
        kind = entry.kind,
        module = entry.module,
        modtime = info and info.modtime or entry.modtime or 0,
        size = info and info.size or entry.size or 0,
        signature = signature or checksum(path),
    }
end

function Watcher:scan()
    local watched = self.registry.listWatchedFiles()


    for path, entry in pairs(watched) do
        local info = getInfo(path)
        if info and not self:isIgnored(path) then
            local previous = self.files[path]

            if not previous then
                -- First sighting: record a baseline (one checksum) without reloading.
                self:remember(path, entry, info, nil)
            -- ponytail: modtime has ~1s resolution, so two same-size edits inside
            -- one second are missed; acceptable to avoid a checksum per file per poll.
            elseif previous.modtime ~= info.modtime or previous.size ~= info.size then
                local signature = checksum(path)
                if previous.signature ~= signature then
                    local _, reason = self.reloader:reloadPath(path, entry.kind)
                    if reason == "vetoed" then
                        -- Keep the new modtime/size so we don't retry every poll, but
                        -- keep the OLD signature so the next save (even identical bytes)
                        -- re-attempts the vetoed reload. Honors "a re-save re-attempts".
                        self:remember(path, entry, info, previous.signature)
                    else
                        self:remember(path, entry, info, signature)
                    end
                else
                    -- Metadata moved but content is identical; refresh stored stats.
                    self:remember(path, entry, info, signature)
                end
            end
        end
    end

end

function Watcher:update(dt)
    self.elapsed = self.elapsed + (dt or 0)

    if self.elapsed < self.interval then
        return
    end

    self.elapsed = 0
    self:scan()
end

return Watcher
