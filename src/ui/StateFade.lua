local StateFade = {}

local S = nil
local keep = nil

function StateFade.begin(dur)
    local g = love.graphics
    local okL, last = pcall(function() return require("src.ui.CRTShader").lastScene() end)
    if not okL or not last then S = nil; return false end
    local ok, cv = pcall(function()
        local w, h = last:getDimensions()
        local c = keep
        if not c or c:getWidth() ~= w or c:getHeight() ~= h then c = g.newCanvas(w, h) end
        local prev = g.getCanvas()
        g.push("all")
        g.setCanvas(c)
        g.clear(0, 0, 0, 1)
        g.origin()
        g.setShader()
        g.setBlendMode("replace")
        g.setColor(1, 1, 1, 1)
        g.draw(last, 0, 0)
        g.pop()
        g.setCanvas(prev)
        return c
    end)
    if not ok or not cv then S = nil; return false end
    keep = cv
    S = { cv = cv, t = 0, dur = math.max(0.05, dur or 0.4) }
    return true
end

function StateFade.isActive() return S ~= nil end

function StateFade.alpha()
    if not S then return 0 end
    local k = math.min(1, S.t / S.dur)
    return 1 - k * k * (3 - 2 * k)
end

function StateFade.update(dt)
    if not S then return end
    S.t = S.t + (dt or 0)
    if S.t >= S.dur then S = nil end
end

function StateFade.draw()
    if not S then return end
    local a = StateFade.alpha()
    if a <= 0 then return end
    local g = love.graphics
    local W, H = g.getDimensions()
    g.push("all")
    g.origin()
    g.setShader()
    g.setColor(1, 1, 1, a)
    g.draw(S.cv, 0, 0, 0, W / S.cv:getWidth(), H / S.cv:getHeight())
    g.pop()
end

function StateFade.cancel() S = nil end

return StateFade
