local WindowPlacement = {}

function WindowPlacement.validDisplay(settings, count)
    local d = tonumber(settings and settings.windowDisplay)
    if d and d >= 1 and d <= (count or 1) and d == math.floor(d) then return d end
    return 1
end

function WindowPlacement.validPosition(settings, w, h, dw, dh)
    local x, y = tonumber(settings and settings.windowX), tonumber(settings and settings.windowY)
    if not (x and y and w and h and dw and dh) then return nil end
    if x < 0 or y < 0 or x + w > dw or y + h > dh then return nil end
    return math.floor(x), math.floor(y)
end

function WindowPlacement.restore(settings)
    local count = love.window.getDisplayCount and love.window.getDisplayCount() or 1
    local d = WindowPlacement.validDisplay(settings, count)
    if d ~= 1 then
        local okDim, dw, dh = pcall(love.window.getDesktopDimensions, d)
        if okDim then
            local w, h = love.graphics.getDimensions()
            love.window.setPosition(math.max(0, math.floor((dw - w) / 2)),
                math.max(0, math.floor((dh - h) / 2)), d)
        end
    end
    return d
end

function WindowPlacement.restorePosition(settings, display)
    local okDim, dw, dh = pcall(love.window.getDesktopDimensions, display)
    if not okDim then return end
    local w, h = love.graphics.getDimensions()
    local x, y = WindowPlacement.validPosition(settings, w, h, dw, dh)
    if x then love.window.setPosition(x, y, display) end
end

function WindowPlacement.remember(settings)
    if not (love.window and love.window.isOpen and love.window.isOpen()) then return false end
    local x, y, d = love.window.getPosition()
    if not d then return false end
    local changed = settings.windowDisplay ~= d
    settings.windowDisplay = d
    if not love.window.getFullscreen() and not (love.window.isMinimized and love.window.isMinimized()) then
        changed = changed or settings.windowX ~= x or settings.windowY ~= y
        settings.windowX, settings.windowY = x, y
    end
    return changed
end

return WindowPlacement
