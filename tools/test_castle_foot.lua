local TK = require("tools.testkit")
local P = require("tools.castle_foot_probe")

local M = {}

local TOPS = { 80, 0 }

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

function M.run()
    local t = TK.new("test_castle_foot")
    local WorldRoad = require("src.ui.WorldRoad")
    local CD = require("src.ui.CastleDrift")
    local FEET = require("src.data.castle_feet")

    for _, bid in ipairs(P.BIOMES) do
        local f = P.scan(bid)
        local d = FEET[bid]
        local same = d ~= nil and d.iw == f.iw and d.ih == f.ih and #d.gap == #f.gap
        if same then
            for c = 1, f.iw do
                if d.gap[c] ~= f.gap[c] then same = false; break end
            end
        end
        t:truthy(("%s: perfil do pe em src/data/castle_feet.lua confere com os %d quadros do PNG (rode tools/castle_feet_scan.py se a arte mudou)")
            :format(bid, f.frames), same)
    end

    local drifts = { -CD.MAX, 0, CD.MAX }
    for _, res in ipairs(P.RES) do
        local W, H = res[1], res[2]
        for _, top in ipairs(TOPS) do
            local g = WorldRoad.domeGeom(0, top, W, H - top)
            for _, bid in ipairs(P.BIOMES) do
                local f = P.scan(bid)
                local worst, wp, wd, n = -math.huge, 0, 0, 0
                for i = 0, 100 do
                    local prog = i / 100
                    local s = WorldRoad.castleScale(g, W, bid, prog)
                    for _, dr in ipairs(drifts) do
                        local cx = g.cx + dr * CD.envelope(prog) * W
                        local baseY = WorldRoad.castleBaseY(g, bid, cx, s, f.iw, f.ih, prog)
                        local ct = { s = s, cx = cx, baseY = baseY }
                        local e = P.exposure(ct, W, H, top, bid, g.crestYAt)
                        n = n + 1
                        if e > worst then worst, wp, wd = e, prog, dr end
                    end
                end
                t:truthy(("%s %dx%d topo %d: nenhum pixel do pe acima da crista em %d quadros da aproximacao (pior %.1f px, progresso %.2f, desvio %+.3f)")
                    :format(bid, W, H, top, n, worst, wp, wd), worst <= -1)
            end
        end
    end

    require("src.ui.PixelCanvas").enableNearest()
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local ok, err = pcall(function()
        for _, res in ipairs(P.RES) do
            local W, H = res[1], res[2]
            local restore = patchDims(W, H)
            local cv = love.graphics.newCanvas(W, H)
            for act = 1, 6 do
                local bid = P.BIOMES[act]
                WorldRoad.restoreProgress(act, 1)
                WorldRoad._blend = nil
                WorldRoad._prevBiomeIndex = nil
                WorldRoad._birdTimer = 1e9
                for _, st in ipairs({ { p = 1, d = 0 }, { p = 0.5, d = 1 }, { p = 0.5, d = -1 } }) do
                    WorldRoad._segBase = 0
                    WorldRoad._camZ = st.p * WorldRoad.TRAVEL_DISTANCE * 8
                    WorldRoad.update(1 / 30)
                    WorldRoad._camZ = st.p * WorldRoad.TRAVEL_DISTANCE * 8
                    CD.reset()
                    for _ = 1, 8 do
                        if st.d ~= 0 then CD.pick(st.d, WorldRoad._camZ - 1, 1e-3) end
                    end
                    love.graphics.setCanvas(cv)
                    WorldRoad.draw(0, P.TOP, W, H - P.TOP, act)
                    love.graphics.setCanvas()
                    local ct = WorldRoad._castleTop
                    local g = WorldRoad.domeGeom(0, P.TOP, W, H - P.TOP)
                    local e = ct and ct.bid == bid and P.exposure(ct, W, H, P.TOP, bid, g.crestYAt) or math.huge
                    t:truthy(("ato %d %s %dx%d desenho real (progresso %.1f, desvio %+d): pe coberto pela crista (pior %.1f px)")
                        :format(act, bid, W, H, st.p, st.d, e), e <= -1)
                end
            end
            CD.reset()
            cv:release()
            restore()
        end
    end)
    love.timer.getTime = realTime
    t:truthy("desenho real rodou sem erro " .. tostring(err or ""), ok)
    return t:done()
end

return M
