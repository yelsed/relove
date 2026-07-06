local Reloader = {}

local function sourcePath(path)
    if love and love.filesystem and love.filesystem.getSource then
        return love.filesystem.getSource() .. "/" .. path
    end

    return path
end

local function readFile(path)
    -- love.filesystem.read is portable (no shell) and reads fresh from physfs.
    -- io.open is the fallback for non-LÖVE contexts (tests, CLI reuse).
    if love and love.filesystem and love.filesystem.read then
        local content, size = love.filesystem.read(path)
        if content then
            return content, size
        end
    end

    local file = io.open(sourcePath(path), "r")
    if file then
        local content = file:read("*a")
        file:close()
        return content, #content
    end

    return nil
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

function Reloader.new(registry, reporter, overlay, options)
    options = options or {}

    return setmetatable({
        registry = registry,
        reporter = reporter,
        overlay = overlay,
        reloadMain = options.reloadMain,
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
        if self.reloadMain then
            return self:reloadMainChunk(path)
        end
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

    return self:reloadModule(record)
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

-- Opt-in (start{ reloadMain = true }). Re-runs main.lua so edited love.* callbacks
-- take effect without a restart. It does NOT re-call love.load; live state kept in
-- modules survives (they hot-reload separately). Any file-scope work in main.lua
-- re-runs, so this is best for a thin main.lua that only wires callbacks.
function Reloader:reloadMainChunk(path)
    local content = readFile(path)
    if not content then
        self:report({ status = "error", file = path, message = "could not read file", usingLastGood = true })
        return false
    end

    local loader, syntaxError = compile(path, content)
    if syntaxError then
        self:report({ status = "error", file = path, message = syntaxError, usingLastGood = true })
        return false
    end

    local ok, err = xpcall(loader, debug.traceback)
    if not ok then
        -- Unlike a module reload, we can't roll back a half-run boot chunk: some
        -- callbacks may already be re-bound. Report honestly that we are NOT on
        -- clean last-good code.
        self:report({
            status = "error",
            file = path,
            message = (tostring(err):match("^[^\n]+") or tostring(err)) .. " (main.lua ran partway; state may be inconsistent)",
            stack = tostring(err),
            usingLastGood = false,
        })
        return false
    end

    self:report({
        status = "ok",
        file = path,
        message = "reloaded main.lua (callbacks re-bound; boot code re-ran)",
        usingLastGood = false,
    })
    return true
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

    local loader, syntaxError = compile(path, content)
    if syntaxError then
        local status = { status = "error", file = path, message = syntaxError, usingLastGood = true }
        self:report(status)
        return false
    end

    local oldExport = record.exported

    -- A module can veto a reload it can't safely take right now (e.g. a suspended
    -- coroutine or an in-flight critical section). __accept runs on the old export
    -- before the new chunk executes, so a veto has no side effects. Return false to
    -- veto; nil/true lets the reload proceed. A re-save re-attempts.
    if type(oldExport) == "table" and type(oldExport.__accept) == "function" then
        local called, accepted, reason = pcall(oldExport.__accept, oldExport)
        if called and accepted == false then
            local message = "reload vetoed by " .. name
            if reason then
                message = message .. ": " .. tostring(reason)
            end
            self:report({ status = "vetoed", file = path, message = message, usingLastGood = true })
            return false, "vetoed"
        end
    end

    local oldPackageValue = package.loaded[name]
    package.loaded[name] = nil

    -- Run the chunk we already compiled instead of making require re-read and
    -- re-compile the file; the preload searcher runs before LÖVE's own loader.
    local oldPreload = package.preload[name]
    package.preload[name] = loader

    local ok, newExportOrError = xpcall(function()
        return self.registry.originalRequire(name)
    end, debug.traceback)

    package.preload[name] = oldPreload

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
