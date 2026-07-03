local Reporter = {}

Reporter.lastMessage = nil
Reporter.statusPath = ".relove/status.json"
Reporter.errorLogPath = ".relove/errors.log"
Reporter.eventLogPath = ".relove/events.log"

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
    local ok = pcall(function()
        os.execute('mkdir -p .relove')
    end)

    if not ok and love and love.filesystem then
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
