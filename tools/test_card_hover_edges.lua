local TK = require("tools.testkit")

local M = {}

local CARDS = {
    { id = "warrior_adrenaline_rush" },
    { id = "warrior_bastion" },
    { id = "joker_001" },
    { id = "joker_boss_carrion" },
    { id = "attack_001", edition = "holo" },
}

local POSES = {
    { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 },
    { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 },
}

local T = 1.3
local INSET = 3

local function warp(px, py, w, h, mx, my, hover)
    hover = hover or 1
    local cx, cy = px / w - 0.5, py / h - 0.5
    local press = -(cx * mx + cy * my) * 0.12 * hover
    local wobble = (math.sin(T * 2 + cx * 4) * 0.005 + math.cos(T * 1.7 + cy * 4) * 0.005) * hover
    local k = press + wobble
    return px + cx * w * k, py + cy * h * k
end

local function render(db, entry, pose)
    local Config = require("src.core.Config")
    local inst = db:createCardInstance(db:getCard(entry.id))
    if entry.edition then inst.edition = entry.edition end
    inst.baseScale, inst.currentScale, inst.targetScale = 1, 1, 1
    inst.deferTooltip = true
    inst.noHoverLift = true
    inst.liftOffset, inst.hoverBob, inst.offsetHoverX = 0, 0, 0
    inst.perspectiveRotation = 0
    local range = Config.Cards.TILT_RANGE or 0.15
    if pose then
        inst.isHovered, inst.hoverStrength = true, 1
        inst.tiltX, inst.tiltY = pose[1] * range, pose[2] * range
    else
        inst.isHovered, inst.hoverStrength = false, 0
        inst.tiltX, inst.tiltY = 0, 0
        inst.isDragging = true
    end
    local cv = love.graphics.newCanvas(260, 320)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    inst:draw(80, 90, false, true)
    love.graphics.pop()
    local data = cv:newImageData()
    cv:release()
    return inst, data
end

local function cardAlphaCount(data)
    local n = 0
    for y = 0, data:getHeight() - 1 do
        for x = 0, data:getWidth() - 1 do
            local r, g, b, a = data:getPixel(x, y)
            if a > 0.98 and (r + g + b) > 0.02 then n = n + 1 end
        end
    end
    return n
end

local function outline(w, h, mx, my, hover)
    local pts = {}
    local function add(px, py)
        local qx, qy = warp(px, py, w, h, mx, my, hover)
        pts[#pts + 1] = { qx, qy }
    end
    for c = 0, 8 do add(w * c / 8, 0) end
    for r = 1, 12 do add(w, h * r / 12) end
    for c = 7, 0, -1 do add(w * c / 8, h) end
    for r = 11, 1, -1 do add(0, h * r / 12) end
    return pts
end

local function segDist(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local l2 = dx * dx + dy * dy
    local k = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2)) or 0
    local ex, ey = ax + dx * k - px, ay + dy * k - py
    return math.sqrt(ex * ex + ey * ey)
end

local function outsideBy(pts, px, py)
    local inside, best = false, math.huge
    local n = #pts
    for i = 1, n do
        local a, b = pts[i], pts[(i % n) + 1]
        if ((a[2] > py) ~= (b[2] > py)) and
            (px < (b[1] - a[1]) * (py - a[2]) / (b[2] - a[2]) + a[1]) then
            inside = not inside
        end
        best = math.min(best, segDist(px, py, a[1], a[2], b[1], b[2]))
    end
    return inside and 0 or best
end

local function lightOutside(data, rect, w, h, mx, my, hover)
    local pts = outline(w, h, mx, my, hover)
    local n, sample = 0, nil
    local x0, y0 = math.floor(rect.x) - 14, math.floor(rect.y) - 14
    for y = y0, y0 + h + 28 do
        for x = x0, x0 + w + 28 do
            if x >= 0 and y >= 0 and x < data:getWidth() and y < data:getHeight() then
                local r, g, b, a = data:getPixel(x, y)
                if a > 0.02 and math.max(r, g, b) > 0.12 then
                    if outsideBy(pts, x + 0.5 - rect.x, y + 0.5 - rect.y) > 1.5 then
                        n = n + 1
                        sample = sample or string.format("(%d,%d)", x - math.floor(rect.x), y - math.floor(rect.y))
                    end
                end
            end
        end
    end
    return n, sample
end

function M.run()
    local t = TK.new("hover de rara/lendaria nao come a borda da carta")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    t:truthy("HoloShader carrega", require("src.ui.HoloShader").load())
    t:truthy("shader de perspectiva disponivel", require("src.ui.CardMesh").getShader() ~= nil)
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local realGetTime = love.timer.getTime
    love.timer.getTime = function() return T end
    local ok, err = pcall(function()
        for _, entry in ipairs(CARDS) do
            local probe = db:createCardInstance(db:getCard(entry.id))
            t:truthy(entry.id .. " passa pelo canvas offscreen (holo/glow/edition)",
                entry.edition ~= nil or probe.visualEffect == "holo" or probe.visualEffect == "glow")
            local restInst, restData = render(db, entry, nil)
            local restCount = cardAlphaCount(restData)
            local rw, rh = restInst.image:getWidth(), restInst.image:getHeight()
            local rlit, rwhere = lightOutside(restData, restInst.lastDrawRect, rw, rh, 0, 0, 0)
            t:eq(entry.id .. " em repouso: nada claro fora da carta " .. tostring(rwhere or ""), rlit, 0)
            for _, pose in ipairs(POSES) do
                local inst, data = render(db, entry, pose)
                local rect = inst.lastDrawRect
                local w, h = inst.image:getWidth(), inst.image:getHeight()
                local missing, total = {}, 0
                local function check(px, py)
                    local qx, qy = warp(px, py, w, h, pose[1], pose[2])
                    local sx, sy = math.floor(rect.x + qx), math.floor(rect.y + qy)
                    total = total + 1
                    local a = 0
                    if sx >= 0 and sy >= 0 and sx < data:getWidth() and sy < data:getHeight() then
                        local _, _, _, aa = data:getPixel(sx, sy)
                        a = aa
                    end
                    if a < 0.5 and #missing < 3 then
                        missing[#missing + 1] = string.format("(%d,%d)", px, py)
                    end
                    return a >= 0.5
                end
                local bad = 0
                for c = 0, 8 do
                    local px = INSET + (w - 2 * INSET) * c / 8
                    if not check(px, INSET) then bad = bad + 1 end
                    if not check(px, h - INSET) then bad = bad + 1 end
                end
                for r = 1, 11 do
                    local py = INSET + (h - 2 * INSET) * r / 12
                    if not check(INSET, py) then bad = bad + 1 end
                    if not check(w - INSET, py) then bad = bad + 1 end
                end
                local label = string.format("%s hover (%d,%d)", entry.id, pose[1], pose[2])
                t:eq(label .. ": borda inteira visivel " .. table.concat(missing, " "), bad, 0)
                local lit, where = lightOutside(data, rect, w, h, pose[1], pose[2], 1)
                t:eq(label .. ": nada claro fora da carta " .. tostring(where or ""), lit, 0)
                local count = cardAlphaCount(data)
                t:truthy(string.format("%s: area opaca %d >= 95%% da crua %d", label, count, restCount),
                    count >= restCount * 0.95)
            end
        end
    end)
    local ok2, err2 = pcall(function()
        for _, id in ipairs({ "joker_001", "joker_boss_carrion" }) do
            local inst, data = render(db, { id = id }, nil)
            local rect = inst.lastDrawRect
            local lit = 0
            for y = math.floor(rect.y) - 4, math.floor(rect.y) - 1 do
                for x = math.floor(rect.x) + 4, math.floor(rect.x + rect.w) - 5 do
                    local _, _, _, a = data:getPixel(x, y)
                    if a > 0.02 then lit = lit + 1 end
                end
            end
            t:eq(id .. " em repouso: nada desenhado fora da carta (sem halo lendario)", lit, 0)
        end
    end)
    love.timer.getTime = realGetTime
    t:truthy("sem erro: " .. tostring(err), ok)
    t:truthy("sem erro no halo: " .. tostring(err2), ok2)
    return t:done()
end

return M
