#!/usr/bin/env lua

local command = arg[1]
local target = arg[2] or "."

local startMarker = "-- relove dev hot reload start"
local endMarker = "-- relove dev hot reload end"
local block = table.concat({
    startMarker,
    'if love.filesystem.getInfo("dev/relove/init.lua") then',
    '    require("dev.relove").start()',
    'end',
    endMarker,
    '',
}, "\n")

local function shellQuote(value)
    value = tostring(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function join(a, b)
    if a == "." then
        return b
    end

    if a:sub(-1) == "/" then
        return a .. b
    end

    return a .. "/" .. b
end

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file = assert(io.open(path, "w"))
    file:write(content)
    file:close()
end

local function fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end

    return false
end

local function scriptRoot()
    local script = arg[0] or "tools/relove.lua"
    local root = script:gsub("/tools/relove%.lua$", "")

    if root == script then
        return "."
    end

    if root == "" then
        return "."
    end

    return root
end

local function ensureRuntime(targetDir)
    local source = scriptRoot()
    local sourceRuntime = join(source, "dev/relove")
    local sourceEntry = join(source, "dev/relove.lua")
    local targetDev = join(targetDir, "dev")
    local sourceCli = join(source, "tools/relove.lua")
    local sourceWrapper = join(source, "relove")
    local targetTools = join(targetDir, "tools")

    if not fileExists(sourceEntry) then
        error("could not find relove runtime at " .. sourceEntry)
    end

    if targetDir == "." or targetDir == source then
        os.execute("mkdir -p " .. shellQuote(join(targetDir, ".relove")))
        return
    end

    os.execute("mkdir -p " .. shellQuote(targetDev))
    os.execute("mkdir -p " .. shellQuote(targetTools))
    os.execute("cp -R " .. shellQuote(sourceRuntime) .. " " .. shellQuote(targetDev .. "/"))
    os.execute("cp " .. shellQuote(sourceEntry) .. " " .. shellQuote(join(targetDev, "relove.lua")))
    os.execute("cp " .. shellQuote(sourceCli) .. " " .. shellQuote(join(targetTools, "relove.lua")))
    if fileExists(sourceWrapper) then
        os.execute("cp " .. shellQuote(sourceWrapper) .. " " .. shellQuote(join(targetDir, "relove")))
        os.execute("chmod +x " .. shellQuote(join(targetDir, "relove")))
    end
    os.execute("chmod +x " .. shellQuote(join(targetTools, "relove.lua")))
    os.execute("mkdir -p " .. shellQuote(join(targetDir, ".relove")))
end

local function patchMain(targetDir)
    local path = join(targetDir, "main.lua")
    local content = readFile(path)

    if not content then
        error("main.lua not found in " .. targetDir)
    end

    if content:find(startMarker, 1, true) then
        print("relove already installed in " .. path)
        return
    end

    local backup = join(targetDir, "main.lua.relove-backup")
    if not fileExists(backup) then
        writeFile(backup, content)
    end

    writeFile(path, block .. content)
    print("installed relove in " .. path)
end

local function removeBlock(targetDir)
    local path = join(targetDir, "main.lua")
    local content = readFile(path)

    if not content then
        error("main.lua not found in " .. targetDir)
    end

    local startPos = content:find(startMarker, 1, true)
    if not startPos then
        print("relove block not found in " .. path)
        return
    end

    local endPos = content:find(endMarker, startPos, true)
    if not endPos then
        error("relove start marker exists without end marker")
    end

    endPos = endPos + #endMarker
    if content:sub(endPos + 1, endPos + 1) == "\n" then
        endPos = endPos + 1
    end

    writeFile(path, content:sub(1, startPos - 1) .. content:sub(endPos + 1))
    print("removed relove block from " .. path)
end

local function printStatus(targetDir)
    local statusPath = join(targetDir, ".relove/status.json")
    local content = readFile(statusPath)

    if not content then
        print("no relove status found at " .. statusPath)
        return
    end

    io.write(content)
end

local function printLogs(targetDir)
    local logPath = join(targetDir, ".relove/events.log")
    local content = readFile(logPath)

    if not content then
        print("no relove event log found at " .. logPath)
        return
    end

    io.write(content)
end

local function run(targetDir)
    os.execute("cd " .. shellQuote(targetDir) .. " && love .")
end

local function usage()
    print("relove - drop-in LÖVE hot reload")
    print("")
    print("Usage:")
    print("  relove init [project]")
    print("  relove remove [project]")
    print("  relove status [project]")
    print("  relove logs [project]")
    print("  relove run [project]")
end

if command == "init" then
    ensureRuntime(target)
    patchMain(target)
elseif command == "remove" then
    removeBlock(target)
elseif command == "status" then
    printStatus(target)
elseif command == "logs" then
    printLogs(target)
elseif command == "run" then
    run(target)
else
    usage()
end
