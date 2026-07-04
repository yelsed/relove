local Registry = {}

Registry.originalRequire = require
Registry.modules = {}
Registry.pathToName = {}
Registry.installed = false

local function moduleToPath(name)
    return (name:gsub("%.", "/")) .. ".lua"
end

local function isReloveModule(name)
    return name == "dev.relove" or name:match("^dev%.relove%.") ~= nil
end

local function fileInfo(path)
    if not love or not love.filesystem then
        return nil
    end

    return love.filesystem.getInfo(path, "file")
end

function Registry.resolvePath(name)
    local path = moduleToPath(name)
    if fileInfo(path) then
        return path
    end

    return nil
end

function Registry.remember(name, exported)
    if isReloveModule(name) then
        return exported
    end

    local path = Registry.resolvePath(name)
    if not path then
        return exported
    end

    local info = fileInfo(path) or {}
    local record = Registry.modules[name] or {
        name = name,
        path = path,
        lastKnownGood = nil,
    }

    record.exported = exported
    record.modtime = info.modtime or record.modtime or 0
    record.size = info.size or record.size or 0

    Registry.modules[name] = record
    Registry.pathToName[path] = name

    return exported
end

function Registry.install()
    if Registry.installed then
        return
    end

    Registry.installed = true

    _G.require = function(name)
        local exported = Registry.originalRequire(name)
        return Registry.remember(name, exported)
    end
end

function Registry.getByPath(path)
    local name = Registry.pathToName[path]
    if not name then
        return nil
    end

    return Registry.modules[name]
end

function Registry.listWatchedFiles()
    local files = {}

    for _, record in pairs(Registry.modules) do
        files[record.path] = {
            kind = "module",
            module = record.name,
            path = record.path,
            modtime = record.modtime or 0,
            size = record.size or 0,
        }
    end

    local mainInfo = fileInfo("main.lua")
    if mainInfo then
        files["main.lua"] = {
            kind = "main",
            path = "main.lua",
            modtime = mainInfo.modtime or 0,
        }
    end

    local configInfo = fileInfo("conf.lua")
    if configInfo then
        files["conf.lua"] = {
            kind = "config",
            path = "conf.lua",
            modtime = configInfo.modtime or 0,
        }
    end

    return files
end

function Registry.updateFileStats(path)
    local info = fileInfo(path)
    local record = Registry.getByPath(path)

    if record and info then
        record.modtime = info.modtime or record.modtime or 0
        record.size = info.size or record.size or 0
    end
end

function Registry.restoreRequire()
    if Registry.installed then
        _G.require = Registry.originalRequire
        Registry.installed = false
    end
end

return Registry
