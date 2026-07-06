local Reporter = {}

-- Anchor state to the project source dir so status/logs land where the editor
-- looks (<project>/.relove), regardless of the cwd the game was launched from.
local function projectBase()
    if love and love.filesystem and love.filesystem.getSource then
        return love.filesystem.getSource()
    end

    return "."
end

local base = projectBase()
local stateDir = base .. "/.relove"

Reporter.lastMessage = nil
Reporter.statePath = stateDir
Reporter.statusPath = stateDir .. "/status.json"
Reporter.errorLogPath = stateDir .. "/errors.log"
Reporter.eventLogPath = stateDir .. "/events.log"

local isWindows = package.config:sub(1, 1) == "\\"

local function osQuote(value)
    value = tostring(value)
    if isWindows then
        return '"' .. value:gsub('"', '') .. '"'
    end

    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function escapeJsonString(value)
    value = tostring(value or "")
    value = value:gsub('\\', '\\\\')
    value = value:gsub('"', '\\"')
    value = value:gsub('\n', '\\n')
    value = value:gsub('\r', '\\r')
    value = value:gsub('\t', '\\t')
    return value
end

local function encodeJson(value)
    local kind = type(value)

    if kind == "nil" then
        return "null"
    end

    if kind == "boolean" or kind == "number" then
        return tostring(value)
    end

    if kind == "string" then
        return '"' .. escapeJsonString(value) .. '"'
    end

    if kind == "table" then
        local parts = {}
        for key, item in pairs(value) do
            table.insert(parts, '"' .. escapeJsonString(key) .. '":' .. encodeJson(item))
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end

    return '"<' .. kind .. '>"'
end

local function ensureProjectStateDir()
    -- The CLI's `init` already created .relove; this is a per-process safety net,
    -- memoized so we don't fork a mkdir on every status write. Pure Lua can't
    -- create a directory, so this is the one runtime shell-out (OS-aware).
    if Reporter._stateDirReady then
        return
    end

    Reporter._stateDirReady = true

    local ok
    if isWindows then
        ok = os.execute("mkdir " .. osQuote((Reporter.statePath:gsub("/", "\\"))) .. " >NUL 2>&1")
    else
        ok = os.execute("mkdir -p " .. osQuote(Reporter.statePath))
    end

    -- Only touch the save dir if the shell mkdir was unavailable/failed; on POSIX
    -- mkdir -p is idempotent (ok every run) so the save dir stays untouched.
    if not (ok == true or ok == 0) and love and love.filesystem then
        love.filesystem.createDirectory(".relove")
    end
end

local function appendFile(path, content)
    local file = io.open(path, "a")
    if not file then
        return false
    end

    file:write(content)
    file:close()
    return true
end

local function writeFile(path, content)
    local file = io.open(path, "w")
    if file then
        file:write(content)
        file:close()
        return true
    end

    if love and love.filesystem then
        return love.filesystem.write(path, content)
    end

    return false
end

local function now()
    if love and love.timer then
        return love.timer.getTime()
    end

    return os.time()
end

function Reporter.write(payload)
    ensureProjectStateDir()

    payload.updatedAt = payload.updatedAt or now()
    -- Stamp the contract version so editor/agent adapters can evolve safely.
    payload.schemaVersion = payload.schemaVersion or 1

    local encoded = encodeJson(payload)
    writeFile(Reporter.statusPath, encoded .. "\n")

    appendFile(Reporter.eventLogPath, encoded .. "\n")

    if payload.status == "error" or payload.status == "restart_required" then
        appendFile(Reporter.errorLogPath, encoded .. "\n")
    end

    local message = payload.status .. ":" .. tostring(payload.file or "") .. ":" .. tostring(payload.message or "")
    if message ~= Reporter.lastMessage then
        Reporter.lastMessage = message
        print("[relove] " .. tostring(payload.status) .. " " .. tostring(payload.file or "") .. " " .. tostring(payload.message or ""))
    end
end

function Reporter.ok(file, message)
    Reporter.write({
        status = "ok",
        file = file,
        message = message or "reload ok",
        usingLastGood = false,
    })
end

function Reporter.info(file, message)
    Reporter.write({
        status = "info",
        file = file,
        message = message or "info",
        usingLastGood = false,
    })
end

function Reporter.restartRequired(file, message)
    Reporter.write({
        status = "restart_required",
        file = file,
        message = message or "restart required",
        usingLastGood = true,
    })
end

function Reporter.error(file, message, stack, usingLastGood)
    Reporter.write({
        status = "error",
        file = file,
        message = tostring(message or "unknown error"),
        stack = stack,
        usingLastGood = usingLastGood ~= false,
    })
end

return Reporter
