local M = {}

M.BIOMES = { "fields", "highlands", "abyss", "frost", "marsh", "dusk" }
M.TOP = 80
M.PROGRESS = { 0, 0.3, 0.6, 0.75, 0.8125, 0.875, 0.9, 1.0 }
M.SHEET_COLS = { { p = 0, tag = "longe" }, { p = 0.3, tag = "0.3" }, { p = 0.6, tag = "meio" },
    { p = 0.75, tag = "andar7" }, { p = 0.875, tag = "chefe" }, { p = 1.0, door = 0.5, tag = "porta" } }
M.TODS = { 0.65, 0.85, 1.0 }
M.CW, M.CH = 420, 260

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

function M.setup()
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    return WorldRoad, function() love.timer.getTime = realTime end
end

function M.prepare(WorldRoad, act, p, tod)
    love.math.setRandomSeed(7)
    WorldRoad.clearCache()
    WorldRoad.restoreProgress(act, 1)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad._segBase = 0
    WorldRoad._camZ = p * WorldRoad.TRAVEL_DISTANCE * 8
    WorldRoad._entry = nil
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
    WorldRoad._camZ = p * WorldRoad.TRAVEL_DISTANCE * 8
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad._props = {}
    require("src.ui.CastleDrift").reset()
end

function M.draw(WorldRoad, cv, W, H, act, door, castleOn)
    love.math.setRandomSeed(11)
    if door then
        WorldRoad._entry = { phase = "door", t = 0, doorK = door, fade = 0 }
    end
    WorldRoad.castleLights = castleOn
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 1)
    WorldRoad.draw(0, M.TOP, W, H - M.TOP, act)
    WorldRoad.drawLightComposite(0, M.TOP, W, H - M.TOP)
    love.graphics.setCanvas()
    WorldRoad.castleLights = nil
    WorldRoad._entry = nil
    return WorldRoad._castleTop
end

function M.frontRegion(WorldRoad, W, H, ct)
    local g = WorldRoad.domeGeom(0, M.TOP, W, H - M.TOP)
    local hw = math.max(60, ct.w * 0.6)
    local x0 = math.max(0, math.floor(ct.cx - hw))
    local x1 = math.min(W - 1, math.floor(ct.cx + hw))
    local depth = math.floor((H - M.TOP) * 0.18)
    return g, x0, x1, depth
end

function M.diff(WorldRoad, W, H, ct, dOn, dOff, off)
    off = off or 4
    local g, x0, x1, depth = M.frontRegion(WorldRoad, W, H, ct)
    local maxD, sum, n, lit, dyMax = 0, 0, 0, 0, -1
    for px = x0, x1 do
        local cy = math.floor(g.crestYAt(px)) + off
        for py = cy, math.min(H - 1, cy + depth) do
            local r1, g1, b1 = dOn:getPixel(px, py)
            local r0, g0, b0 = dOff:getPixel(px, py)
            local d = math.max(r1 - r0, g1 - g0, b1 - b0)
            if d > maxD then maxD = d end
            if d > 1.5 / 255 then
                lit = lit + 1
                if py - cy > dyMax then dyMax = py - cy end
            end
            sum = sum + (r1 + g1 + b1 - r0 - g0 - b0) / 3
            n = n + 1
        end
    end
    return maxD * 255, n > 0 and sum / n * 255 or 0, lit, n, dyMax + off
end

function M.render(WorldRoad, cv, W, H, act, p, tod, door, castleOn)
    M.prepare(WorldRoad, act, p, tod)
    return M.draw(WorldRoad, cv, W, H, act, door, castleOn)
end

function M.roadProfile(WorldRoad, W, H, d)
    local g = WorldRoad.domeGeom(0, M.TOP, W, H - M.TOP)
    local hw = math.max(8, math.floor(W * 0.03))
    local x0, x1 = math.floor(g.cx - hw), math.floor(g.cx + hw)
    local bins = {}
    local cy = math.floor(g.crestApexY) + 6
    local bh = math.max(4, math.floor((H - M.TOP) / 250))
    for b = 0, 15 do
        local sum, n = 0, 0
        for py = cy + b * bh, cy + b * bh + bh - 1 do
            for px = x0, x1 do
                local r, gg, bb = d:getPixel(px, py)
                sum = sum + 0.299 * r + 0.587 * gg + 0.114 * bb
                n = n + 1
            end
        end
        bins[#bins + 1] = sum / n * 255
    end
    return bins
end

function M.bandStep(bins)
    local worst = 0
    for i = 2, #bins do
        worst = math.max(worst, math.abs(bins[i] - bins[i - 1]))
    end
    local far = 0
    for i = 9, #bins do far = far + bins[i] end
    far = far / (#bins - 8)
    local near = math.min(bins[1], bins[2], bins[3], bins[4])
    local rise = 0
    for i = 1, #bins - 3 do rise = math.max(rise, bins[i + 3] - bins[i]) end
    return worst, far - near, far, rise
end

function M.measure(W, H)
    local WorldRoad, restoreT = M.setup()
    local restore = patchDims(W, H)
    local cv = love.graphics.newCanvas(W, H)
    local rows = {}
    for act = 1, 6 do
        for _, tod in ipairs(M.TODS) do
            for _, p in ipairs(M.PROGRESS) do
                M.prepare(WorldRoad, act, p, tod)
                local ct = M.draw(WorldRoad, cv, W, H, act, nil, false)
                local dOff = cv:newImageData()
                ct = M.draw(WorldRoad, cv, W, H, act, nil, true)
                local dOn = cv:newImageData()
                local mx, mean, lit, n, dy = M.diff(WorldRoad, W, H, ct, dOn, dOff)
                local bins = M.roadProfile(WorldRoad, W, H, dOn)
                local step, dip = M.bandStep(bins)
                rows[#rows + 1] = { act = act, bid = M.BIOMES[act], tod = tod, p = p,
                    max = mx, mean = mean, lit = lit, n = n, dy = dy, step = step, dip = dip }
                dOn:release()
                dOff:release()
            end
            collectgarbage()
        end
    end
    cv:release()
    restore()
    restoreT()
    return rows
end

function M.sheets(label, W, H)
    local WorldRoad, restoreT = M.setup()
    local restore = patchDims(W, H)
    local dir = "castelo_luz/" .. label
    love.filesystem.createDirectory(dir)
    local cv = love.graphics.newCanvas(W, H)
    local CW, CH = M.CW, M.CH
    local sheet = love.graphics.newCanvas(CW * #M.SHEET_COLS, CH * #M.TODS)
    for act = 1, 6 do
        love.graphics.setCanvas(sheet)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setCanvas()
        for ri, tod in ipairs(M.TODS) do
            for ci, col in ipairs(M.SHEET_COLS) do
                local ct = M.render(WorldRoad, cv, W, H, act, col.p, tod, col.door, true)
                local g = WorldRoad.domeGeom(0, M.TOP, W, H - M.TOP)
                local ky = g.crestYAt(ct.cx)
                local q = love.graphics.newQuad(ct.cx - CW / 2, ky - CH * 0.45, CW, CH, W, H)
                love.graphics.setCanvas(sheet)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(cv, q, (ci - 1) * CW, (ri - 1) * CH)
                q:release()
                love.graphics.setColor(1, 0, 0, 1)
                love.graphics.rectangle("fill", (ci - 1) * CW, (ri - 1) * CH, 1, CH)
                love.graphics.rectangle("fill", 0, (ri - 1) * CH, CW * #M.SHEET_COLS, 1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.setCanvas()
                if ri == #M.TODS then
                    cv:newImageData():encode("png", string.format("%s/ato%d_%s_noite.png", dir, act, col.tag))
                end
            end
            collectgarbage()
        end
        sheet:newImageData():encode("png", string.format("%s/ato%d_folha.png", dir, act))
        love.graphics.present()
    end
    sheet:release()
    cv:release()
    restore()
    restoreT()
    return love.filesystem.getSaveDirectory() .. "/" .. dir
end

function M.run(arg)
    local label = tostring(arg or "depois")
    local W, H = 1920, 1080
    local rows = M.measure(W, H)
    local lines = { "ato;bioma;tod;progresso;max_255;media_255;px_acesos;px_total;dy_max;degrau_fim_estrada;faixa_escura" }
    for _, r in ipairs(rows) do
        lines[#lines + 1] = string.format("%d;%s;%.2f;%.4f;%.2f;%.3f;%d;%d;%d;%.1f;%.1f",
            r.act, r.bid, r.tod, r.p, r.max, r.mean, r.lit, r.n, r.dy, r.step, r.dip)
    end
    local dir = M.sheets(label, W, H)
    love.filesystem.write("castelo_luz/" .. label .. "/medidas.csv", table.concat(lines, "\n"))
    for _, l in ipairs(lines) do print(l) end
    print("[ok] " .. dir)
    return true
end

return M
