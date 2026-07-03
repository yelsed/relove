local Reloader = {}

local function sourcePath(path)
    if love and love.filesystem and love.filesystem.getSource then
        return love.filesystem.getSource() .. "/" .. path
    end

    return path
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function readFile(path)
    local handle = io.popen("cat " .. shellQuote(sourcePath(path)))
    if handle then
        local content = handle:read("*a")
        local ok = handle:close()
        if ok and content then
            return content, #content
        end
    end

    local file = io.open(sourcePath(path), "r")
    if file then
        local content = file:read("*a")
        file:close()
        return content, #content
    end

    local content, size = love.filesystem.read(path)
    return content, size
end

local function compile(path, content)
    local loader, err

    if loadstring then
        loader, err = loadstring(content, "@" .. path)
    else
        loader, err = load(content, "@" .. path)
    end

    return loader, err
end

local function shallowPatchTable(old, new)
    for key in pairs(old) do
        if new[key] == nil then
            old[key] = nil
        end
    end

    for key, value in pairs(new) do
        old[key] = value
    end
end

function Reloader.new(registry, reporter, overlay)
    return setmetatable({
        registry = registry,
        reporter = reporter,
        overlay = overlay,
    }, { __index = Reloader })
end

function Reloader:report(status)
    if self.overlay then
        self.overlay.setStatus(status)
    end

    self.reporter.write(status)
end

function Reloader:reloadPath(path, kind)
    if kind == "main" then
        self:validateRestartOnly(path, "main.lua changed; restart required. relove will not hot reload boot code because it can duplicate state or reset callbacks.")
        return
    end

    if kind == "config" then
        self:validateRestartOnly(path, "conf.lua changed; restart required. LÖVE reads config before the game starts.")
        return
    end

    local record = self.registry.getByPath(path)
    if not record then
        self.reporter.info(path, "change detected but module is not loaded yet")
        if self.overlay then
            self.overlay.setStatus({ status = "info", file = path, message = "module not loaded yet", usingLastGood = false })
        end
        return
    end

    self:reloadModule(record)
end

function Reloader:validateRestartOnly(path, message)
    local content = readFile(path)
    if not content then
        self.reporter.error(path, "could not read file", nil, true)
        if self.overlay then
            self.overlay.setStatus({ status = "error", file = path, message = "could not read file", usingLastGood = true })
        end
        return
    end

    local _, err = compile(path, content)
    if err then
        self.reporter.error(path, err, nil, true)
        if self.overlay then
            self.overlay.setStatus({ status = "error", file = path, message = err, usingLastGood = true })
        end
        return
    end

    self.reporter.restartRequired(path, message)
    if self.overlay then
        self.overlay.setStatus({ status = "restart_required", file = path, message = message, usingLastGood = true })
    end
end

function Reloader:reloadModule(record)
    local path = record.path
    local name = record.name
    local content = readFile(path)

    if not content then
        self.reporter.error(path, "could not read file", nil, true)
        if self.overlay then
            self.overlay.setStatus({ status = "error", file = path, message = "could not read file", usingLastGood = true })
        end
        return false
    end

    local _, syntaxError = compile(path, content)
    if syntaxError then
        local status = { status = "error", file = path, message = syntaxError, usingLastGood = true }
        self:report(status)
        return false
    end

    local oldExport = record.exported
    local oldPackageValue = package.loaded[name]
    package.loaded[name] = nil

    local ok, newExportOrError = xpcall(function()
        return self.registry.originalRequire(name)
    end, debug.traceback)

    if not ok then
        package.loaded[name] = oldPackageValue
        local status = {
            status = "error",
            file = path,
            message = tostring(newExportOrError),
            stack = tostring(newExportOrError),
            usingLastGood = true,
        }
        self:report(status)
        return false
    end

    local newExport = newExportOrError

    if type(oldExport) == "table" and type(newExport) == "table" then
        local dispose = oldExport.__dispose
        if type(dispose) == "function" then
            pcall(dispose, oldExport)
        end

        shallowPatchTable(oldExport, newExport)
        package.loaded[name] = oldExport
        record.exported = oldExport

        local hotreload = oldExport.__hotreload
        if type(hotreload) == "function" then
            pcall(hotreload, oldExport, newExport)
        end
    else
        package.loaded[name] = newExport
        record.exported = newExport
    end

    record.lastKnownGood = content
    self.registry.updateFileStats(path)

    local message = "reloaded " .. name
    if type(oldExport) ~= "table" then
        message = message .. " (non-table export; old local references may not update)"
    end

    local status = { status = "ok", file = path, message = message, usingLastGood = false }
    self:report(status)
    return true
end

return Reloader
