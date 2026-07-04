local Registry = require("dev.relove.module_registry")
local Reporter = require("dev.relove.reporter")
local Overlay = require("dev.relove.overlay")
local Reloader = require("dev.relove.reloader")
local Watcher = require("dev.relove.watcher")

local Relove = {
    _version = "0.1.0",
    started = false,
}

local function traceback(err)
    return debug.traceback(tostring(err), 2)
end

local function safeCall(runtime, label, fn, ...)
    local args = { ... }
    local ok, result = xpcall(function()
        return fn(unpack(args))
    end, traceback)

    if not ok then
        local message = tostring(result):match("^[^\n]+") or tostring(result)
        -- Lua errors read "path/to/file.lua:LINE: message"; pull the real culprit
        -- out so diagnostics land on source instead of the callback label.
        local sourceFile, sourceLine = message:match("([%w_%-%./]+%.lua):(%d+)")
        local status = {
            status = "error",
            file = sourceFile or label,
            line = sourceLine and tonumber(sourceLine) or nil,
            label = label,
            message = message,
            stack = tostring(result),
            usingLastGood = true,
        }

        runtime.lastStatus = status
        Overlay.setStatus(status)
        Reporter.write(status)
        return nil
    end

    return result
end

local function installRunLoop(runtime)
    if runtime.originalRun then
        return
    end

    runtime.originalRun = love.run

    love.run = function()
        local moduleCount = 0
        for _ in pairs(Registry.modules) do
            moduleCount = moduleCount + 1
        end
        local bootStatus = {
            status = "info",
            file = "relove",
            message = "watching " .. tostring(moduleCount) .. " loaded modules",
            usingLastGood = false,
        }
        Overlay.setStatus(bootStatus)
        Reporter.write(bootStatus)

        if runtime.watcher then
            runtime.watcher:scan()
        end

        if love.load then
            local parsedArgs = arg
            if love.arg and love.arg.parseGameArguments then
                parsedArgs = love.arg.parseGameArguments(arg)
            end
            safeCall(runtime, "love.load", love.load, parsedArgs, arg)
        end

        if love.timer then
            love.timer.step()
        end

        local dt = 0

        return function()
            if love.event then
                love.event.pump()

                for name, a, b, c, d, e, f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then
                            return a or 0
                        end
                    end

                    local consumed = false
                    if name == "keypressed" then
                        consumed = Overlay.keypressed(a)
                    end

                    local handler = love.handlers and love.handlers[name]
                    if handler and not consumed then
                        safeCall(runtime, "love.handlers." .. name, handler, a, b, c, d, e, f)
                    end
                end
            end

            if love.timer then
                dt = love.timer.step()
            end

            if runtime.watcher then
                runtime.watcher:update(dt)
            end

            if love.update then
                safeCall(runtime, "love.update", love.update, dt)
            end

            if love.graphics and love.graphics.isActive() then
                love.graphics.origin()
                love.graphics.clear(love.graphics.getBackgroundColor())

                if love.draw then
                    safeCall(runtime, "love.draw", love.draw)
                end

                Overlay.draw()
                love.graphics.present()
            end

            if love.timer then
                love.timer.sleep(0.001)
            end
        end
    end
end

function Relove.start(options)
    if Relove.started then
        return Relove
    end

    options = options or {}
    Relove.started = true
    Relove.options = options

    Overlay.configure(options)
    Registry.install()

    Relove.reloader = Reloader.new(Registry, Reporter, Overlay)
    Relove.watcher = Watcher.new(Registry, Relove.reloader, {
        interval = options.interval or options.pollInterval or 0.15,
    })

    installRunLoop(Relove)

    local status = {
        status = "info",
        file = "relove",
        message = "watching saved Lua files",
        usingLastGood = false,
    }

    Overlay.setStatus(status)
    Reporter.write(status)

    return Relove
end

function Relove.status()
    return Relove.lastStatus
end

function Relove.stop()
    Registry.restoreRequire()
    Relove.started = false
end

return Relove
