#!/usr/bin/env lua

local command = arg[1]
local target = arg[2] or "."

-- package.config's first char is the path separator: "/" on POSIX, "\" on Windows.
local isWindows = package.config:sub(1, 1) == "\\"

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

-- Wordmark with the LÖVE umlaut over the o. Printed on human-facing commands
-- (usage, init) but never on status/logs/doctor, whose output is parsed.
local banner = [[
              ..
 _ __ ___| | ___ __   _____
| '__/ _ \ |/ _ \\ \ / / _ \
| |  |  __/ | (_) |\ V /|  __/
|_|   \___|_|\___/  \_/  \___|
]]

local function printBanner()
    io.write(banner)
end

-- The runtime is a fixed, known set of files, so init copies from this manifest
-- instead of shelling out to `cp -R` (which needs a POSIX shell and dir listing).
local runtimeModules = {
    "init.lua",
    "module_registry.lua",
    "watcher.lua",
    "reloader.lua",
    "reporter.lua",
    "overlay.lua",
    "assets.lua",
}

-- Quote a path for os.execute. Windows cmd.exe uses double quotes; POSIX sh uses
-- single quotes with the standard '\'' escape.
local function osQuote(value)
    value = tostring(value)
    if isWindows then
        return '"' .. value:gsub('"', '') .. '"'
    end

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

-- Binary-safe copy so the manifest works for any runtime file without a shell.
local function copyFile(source, dest)
    local input = io.open(source, "rb")
    if not input then
        error("could not read " .. source)
    end

    local data = input:read("*a")
    input:close()

    local output = assert(io.open(dest, "wb"))
    output:write(data)
    output:close()
end

local function fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end

    return false
end

-- Pure Lua cannot create a directory, so this is the one place init/runtime still
-- shells out. mkdir -p is idempotent on POSIX; Windows mkdir creates intermediate
-- dirs and only errors when the leaf exists, which we swallow via >NUL.
local function makeDir(path)
    if isWindows then
        os.execute("mkdir " .. osQuote((path:gsub("/", "\\"))) .. " >NUL 2>&1")
    else
        os.execute("mkdir -p " .. osQuote(path))
    end
end

local function makeExecutable(path)
    if not isWindows then
        os.execute("chmod +x " .. osQuote(path))
    end
end

local function scriptRoot()
    -- An installed CLI (Homebrew, curl script) lives outside the repo, so its
    -- wrapper points RELOVE_RUNTIME at the bundled runtime directory. When set it
    -- wins over the arg[0]-relative guess below, which only works from a checkout.
    local override = os.getenv("RELOVE_RUNTIME")
    if override and override ~= "" then
        return (override:gsub("\\", "/"))
    end

    -- relove.bat passes a backslash arg[0] (from %~dp0); normalize to forward
    -- slashes so the pattern matches on Windows too. join/io.open accept "/" on
    -- Windows, and makeDir converts back to "\" for the mkdir shell call.
    local script = (arg[0] or "tools/relove.lua"):gsub("\\", "/")
    local root = script:gsub("/tools/relove%.lua$", "")

    if root == script or root == "" then
        return "."
    end

    return root
end

local function ensureRuntime(targetDir)
    local source = scriptRoot()
    local sourceRuntime = join(source, "dev/relove")
    local sourceEntry = join(source, "dev/relove.lua")
    local sourceCli = join(source, "tools/relove.lua")
    local sourceWrapper = join(source, "relove")
    local sourceWrapperWin = join(source, "relove.bat")
    local targetDev = join(targetDir, "dev")
    local targetRuntime = join(targetDev, "relove")
    local targetTools = join(targetDir, "tools")

    if not fileExists(sourceEntry) then
        error("could not find relove runtime at " .. sourceEntry)
    end

    if targetDir == "." or targetDir == source then
        makeDir(join(targetDir, ".relove"))
        return
    end

    makeDir(targetRuntime)
    makeDir(targetTools)

    for _, name in ipairs(runtimeModules) do
        copyFile(join(sourceRuntime, name), join(targetRuntime, name))
    end

    copyFile(sourceEntry, join(targetDev, "relove.lua"))
    copyFile(sourceCli, join(targetTools, "relove.lua"))
    makeExecutable(join(targetTools, "relove.lua"))

    if fileExists(sourceWrapper) then
        copyFile(sourceWrapper, join(targetDir, "relove"))
        makeExecutable(join(targetDir, "relove"))
    end

    if fileExists(sourceWrapperWin) then
        copyFile(sourceWrapperWin, join(targetDir, "relove.bat"))
    end

    makeDir(join(targetDir, ".relove"))
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

    -- endPos lands on the newline the block appended after endMarker; sub(endPos + 1)
    -- already excludes it, so don't eat a second newline (that was deleting a real
    -- blank line from the user's main.lua).
    endPos = endPos + #endMarker

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
    -- cd into the game dir so the process CWD matches it (relative raw io/os paths
    -- resolve against the game, not the launch dir). `run` is a dev convenience that
    -- already shells out, so the cd is fine here (unlike the hot/install path).
    if isWindows then
        os.execute("cd /d " .. osQuote((targetDir:gsub("/", "\\"))) .. " && love .")
    else
        os.execute("cd " .. osQuote(targetDir) .. " && love .")
    end
end

local function commandSucceeds(probe)
    local ok = os.execute(probe)
    -- Lua 5.1/LuaJIT return the raw exit code (0 = success); 5.2+ return true.
    return ok == true or ok == 0
end

local function doctor(targetDir)
    local loveProbe = isWindows
        and "love --version >NUL 2>&1"
        or "love --version >/dev/null 2>&1"
    local hasLove = commandSucceeds(loveProbe)

    local hasRuntime = fileExists(join(targetDir, "dev/relove/init.lua"))

    local mainContent = readFile(join(targetDir, "main.lua"))
    local patched = mainContent ~= nil and mainContent:find(startMarker, 1, true) ~= nil

    -- Create .relove if absent so the probe tests writability of the location,
    -- not mere existence (the runtime recreates the dir at launch anyway).
    makeDir(join(targetDir, ".relove"))
    local probePath = join(targetDir, ".relove/.doctor-probe")
    local writable = false
    local probe = io.open(probePath, "w")
    if probe then
        probe:close()
        os.remove(probePath)
        writable = true
    end

    local function mark(ok)
        return ok and "  [ok]   " or "  [FAIL] "
    end

    print("relove doctor — " .. targetDir)
    print(mark(hasLove) .. "love runnable on PATH")
    print(mark(hasRuntime) .. "runtime present (dev/relove/init.lua)")
    print(mark(patched) .. "main.lua contains relove block")
    print(mark(writable) .. ".relove writable")

    if hasLove and hasRuntime and patched and writable then
        print("relove looks healthy.")
    else
        print("relove has problems (see [FAIL] above).")
    end
end

local function usage()
    printBanner()
    print("relove - drop-in LÖVE hot reload")
    print("")
    print("Usage:")
    print("  relove init [project]")
    print("  relove remove [project]")
    print("  relove status [project]")
    print("  relove logs [project]")
    print("  relove doctor [project]")
    print("  relove run [project]")
end

if command == "init" then
    printBanner()
    ensureRuntime(target)
    patchMain(target)
elseif command == "remove" then
    removeBlock(target)
elseif command == "status" then
    printStatus(target)
elseif command == "logs" then
    printLogs(target)
elseif command == "doctor" then
    doctor(target)
elseif command == "run" then
    run(target)
else
    usage()
end
