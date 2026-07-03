local Watcher = {}

function Watcher.new(registry, reloader, options)
    options = options or {}

    return setmetatable({
        registry = registry,
        reloader = reloader,
        interval = options.interval or 0.15,
        elapsed = 0,
        files = {},
    }, { __index = Watcher })
end

local function sourcePath(path)
    if love and love.filesystem and love.filesystem.getSource then
        return love.filesystem.getSource() .. "/" .. path
    end

    return path
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function getInfo(path)
    local file = io.open(sourcePath(path), "r")
    if file then
        local size = file:seek("end") or 0
        file:close()
        return { size = size, modtime = 0 }
    end

    if not love or not love.filesystem then
        return nil
    end

    return love.filesystem.getInfo(path, "file")
end

local function checksum(path)
    local handle = io.popen("cksum " .. shellQuote(sourcePath(path)))
    if handle then
        local line = handle:read("*l")
        handle:close()
        if line and line ~= "" then
            return line
        end
    end

    local file = io.open(sourcePath(path), "r")
    local content

    if file then
        content = file:read("*a")
        file:close()
    else
        content = love.filesystem.read(path)
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
        if info then
            local previous = self.files[path]
            local signature = checksum(path)

            if previous and previous.signature ~= signature then
                self:remember(path, entry, info, signature)
                self.reloader:reloadPath(path, entry.kind)
            elseif not previous then
                self:remember(path, entry, info, signature)
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
