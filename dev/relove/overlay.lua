local Overlay = {}

Overlay.enabled = true
Overlay.visible = true
Overlay.status = {
    status = "info",
    message = "relove watching",
}

local palette = {
    ok = { 0.15, 0.75, 0.35, 0.92 },
    info = { 0.25, 0.55, 1.0, 0.92 },
    restart_required = { 1.0, 0.72, 0.22, 0.94 },
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

    love.graphics.pop()
end

return Overlay
