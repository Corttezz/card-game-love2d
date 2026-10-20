local M = {}

local CW, CH = 240, 150

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

function M.frames()
    local out = {}
    for i = 0, 20 do out[#out + 1] = { p = i / 20 } end
    for _, k in ipairs({ 0.34, 0.67, 1 }) do out[#out + 1] = { p = 1, door = k } end
    return out
end

function M.setDrift(dir, camZ)
    local CD = require("src.ui.CastleDrift")
    CD.reset()
    if dir == 0 then return end
    for _ = 1, 8 do CD.pick(dir, camZ - 1, 1e-3) end
end

function M.run(arg)
    local label = tostring(arg or "depois")
    local P = require("tools.castle_foot_probe")
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local dir = "castelo_base/" .. label
    love.filesystem.createDirectory(dir)
    local frames = M.frames()
    local drifts = { -1, 0, 1 }
    local report = {}
    local sheet = love.graphics.newCanvas(CW * 6, CH * #frames)
    for ri, res in ipairs(P.RES) do
        local W, H = res[1], res[2]
        local restore = patchDims(W, H)
        local cv = love.graphics.newCanvas(W, H)
        for act = 1, 6 do
            local bid = P.BIOMES[act]
            WorldRoad.clearCache()
            WorldRoad.restoreProgress(act, 1)
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            WorldRoad._birdTimer = 1e9
            WorldRoad.setTimeOfDay(0, true)
            love.graphics.setCanvas(sheet)
            love.graphics.clear(0, 0, 0, 1)
            love.graphics.setCanvas()
            local worstAll = -math.huge
            for fi, fr in ipairs(frames) do
                for di, dr in ipairs(drifts) do
                    WorldRoad._segBase = 0
                    WorldRoad._camZ = fr.p * WorldRoad.TRAVEL_DISTANCE * 8
                    WorldRoad._entry = nil
                    WorldRoad.update(1 / 30)
                    WorldRoad._camZ = fr.p * WorldRoad.TRAVEL_DISTANCE * 8
                    WorldRoad._props = {}
                    M.setDrift(dr, WorldRoad._camZ)
                    if fr.door then
                        WorldRoad._entry = { phase = "door", t = 0, doorK = fr.door, fade = 0 }
                    end
                    love.graphics.setCanvas(cv)
                    love.graphics.clear(0, 0, 0, 1)
                    WorldRoad.draw(0, P.TOP, W, H - P.TOP, act)
                    WorldRoad.drawLightComposite(0, P.TOP, W, H - P.TOP)
                    love.graphics.setCanvas()
                    WorldRoad._entry = nil
                    local ct = WorldRoad._castleTop
                    local worst = P.exposure(ct, W, H, P.TOP, bid)
                    if worst > worstAll then worstAll = worst end
                    local x0 = math.floor(ct.cx - ct.w / 2)
                    local x1 = math.floor(ct.cx + ct.w / 2)
                    love.graphics.setCanvas(sheet)
                    love.graphics.setColor(1, 1, 1, 1)
                    for side, fx in ipairs({ x0, x1 }) do
                        local ky = P.crestAt(W, H, P.TOP, fx)
                        local qx = (side == 1) and (fx - 60) or (fx - CW + 60)
                        local q = love.graphics.newQuad(qx, ky - CH * 0.6, CW, CH, W, H)
                        local col = (side - 1) * 3 + di - 1
                        love.graphics.draw(cv, q, col * CW, (fi - 1) * CH)
                        q:release()
                    end
                    love.graphics.setColor(1, 0, 0, 1)
                    love.graphics.rectangle("fill", 0, (fi - 1) * CH, CW * 6, 1)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.setCanvas()
                    if fr.p == 1 and not fr.door and dr == 0 then
                        cv:newImageData():encode("png", string.format("%s/ato%d_%dx%d_perto.png", dir, act, W, H))
                    end
                end
                if fi % 6 == 0 then collectgarbage() end
            end
            local path = string.format("%s/ato%d_%dx%d_pes.png", dir, act, W, H)
            sheet:newImageData():encode("png", path)
            report[#report + 1] = string.format("ato %d %s %dx%d: pior pe acima da crista %.1f px", act, bid, W, H, worstAll)
            love.graphics.present()
        end
        cv:release()
        restore()
    end
    sheet:release()
    love.timer.getTime = realTime
    for _, l in ipairs(report) do print("[ok] " .. l) end
    print("[ok] " .. love.filesystem.getSaveDirectory() .. "/" .. dir)
    return true
end

return M
