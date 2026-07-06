local Overlay = {}

Overlay.enabled = true
Overlay.visible = true
Overlay.status = {
    status = "info",
    message = "relove watching",
}
Overlay.history = {}
Overlay.historyLimit = 5

local palette = {
    ok = { 0.15, 0.75, 0.35, 0.92 },
    info = { 0.25, 0.55, 1.0, 0.92 },
    restart_required = { 1.0, 0.72, 0.22, 0.94 },
    vetoed = { 0.62, 0.45, 0.95, 0.94 },
    error = { 1.0, 0.22, 0.22, 0.96 },
    panel = { 0.04, 0.05, 0.08, 0.82 },
    text = { 0.95, 0.97, 1.0, 1.0 },
    muted = { 0.72, 0.78, 0.86, 1.0 },
}

function Overlay.configure(options)
    options = options or {}

    if options.overlay == false then
        Overlay.enabled = false
    end

    Overlay.toggleKey = options.overlayKey or "f8"
end

function Overlay.setStatus(status)
    Overlay.status = status or Overlay.status

    if status then
        Overlay.pushHistory(status)
    end
end

function Overlay.pushHistory(status)
    local entry = {
        status = status.status or "info",
        file = status.file,
        message = status.message,
    }

    -- Skip consecutive duplicates (e.g. the two boot infos) so history stays useful.
    local last = Overlay.history[#Overlay.history]
    if last and last.status == entry.status and last.file == entry.file and last.message == entry.message then
        return
    end

    Overlay.history[#Overlay.history + 1] = entry
    while #Overlay.history > Overlay.historyLimit do
        table.remove(Overlay.history, 1)
    end
end

function Overlay.keypressed(key)
    if key == Overlay.toggleKey then
        Overlay.visible = not Overlay.visible
        return true
    end

    return false
end

local function line(text, x, y, width, color)
    love.graphics.setColor(color)
    love.graphics.printf(text or "", x, y, width, "left")
end

function Overlay.draw()
    if not Overlay.enabled or not Overlay.visible or not love.graphics then
        return
    end

    local status = Overlay.status or {}
    local statusName = status.status or "info"
    local accent = palette[statusName] or palette.info
    local width = math.min(620, love.graphics.getWidth() - 24)
    local height = statusName == "error" and 118 or 74
    local x = 12
    local y = 12

    love.graphics.push("all")
    love.graphics.setColor(palette.panel)
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)

    love.graphics.setColor(accent)
    love.graphics.rectangle("fill", x, y, 5, height, 3, 3)

    local title = "relove: " .. statusName
    if status.usingLastGood then
        title = title .. " · using last good code"
    end

    line(title, x + 16, y + 10, width - 28, palette.text)

    local detail = status.message or "watching"
    if status.file then
        detail = status.file .. " — " .. detail
    end

    line(detail, x + 16, y + 34, width - 28, palette.muted)

    if statusName == "error" and status.stack then
        local stackLine = tostring(status.stack):match("[^\n]+") or tostring(status.stack)
        line(stackLine, x + 16, y + 78, width - 28, palette.muted)
    end

    -- Recent history below the main card (newest first, excluding the current event).
    local recentCount = #Overlay.history - 1
    if recentCount > 0 then
        local rowHeight = 18
        local historyY = y + height + 8
        love.graphics.setColor(palette.panel)
        love.graphics.rectangle("fill", x, historyY, width, recentCount * rowHeight + 12, 8, 8)

        local row = 0
        for index = #Overlay.history - 1, 1, -1 do
            local entry = Overlay.history[index]
            local rowY = historyY + 6 + row * rowHeight

            love.graphics.setColor(palette[entry.status] or palette.info)
            love.graphics.rectangle("fill", x + 10, rowY + 5, 6, 6, 2, 2)

            local text = entry.status
            if entry.file then
                text = text .. " · " .. entry.file
            end
            if entry.message then
                text = text .. " — " .. entry.message
            end

            -- Keep each event on one row; a long message would wrap and overlap.
            if #text > 88 then
                text = text:sub(1, 85) .. "..."
            end

            line(text, x + 24, rowY, width - 36, palette.muted)
            row = row + 1
        end
    end

    love.graphics.pop()
end

return Overlay
