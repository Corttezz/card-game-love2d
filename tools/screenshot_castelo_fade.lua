local M = {}

local function frameOut(cv, path)
    cv:newImageData():encode("png", path)
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local W, H = 1920, 1080
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
    local topBarH = 80
    local label = tostring(arg or "fade")
    local dir = "castelo_fade/" .. label
    love.filesystem.createDirectory(dir)
    require("src.i18n.I18n").init()
    require("src.i18n.I18n").setLocale("en", true)
    local MM = require("src.systems.MapManager")
    local tod = tonumber(os.getenv("CASTELO_TOD") or "") or 0.85
    for bio = 1, 6 do
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        love.math.setRandomSeed(7)
        WorldRoad.restoreProgress(bio, 3)
        for _ = 1, 400 do
            if WorldRoad.isPrewarmed(bio) then break end
            WorldRoad.prewarmTick(0.05, bio)
        end
        WorldRoad.setTimeOfDay(tod, true)
        WorldRoad._birdTimer = 1e9
        local function draw()
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
            WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
            love.graphics.setCanvas()
        end
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for _ = 1, 5 do
            WorldRoad.update(1 / 60)
            WorldRoad.setBattleEnemyDraw(function() end, nil)
            draw()
        end
        frameOut(cv, string.format("%s/b%d_0_batalha.png", dir, bio))
        local cxs = { WorldRoad._castleTop.cx }
        local nodes = {}
        for i, ty in ipairs({ "battle", "rest", "shop" }) do
            nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
        end
        WorldRoad.showFork(nodes, function() end)
        local fadeAt, mids, maxStep = nil, 0, 0
        local fadeFrom, fadeTo
        for f = 1, 150 do
            WorldRoad.update(1 / 60)
            draw()
            local cx = WorldRoad._castleTop.cx
            local prev = cxs[#cxs]
            cxs[#cxs + 1] = cx
            local cf = WorldRoad._castleFade
            if cf.t0 and not fadeAt then
                fadeAt = f
                fadeFrom, fadeTo = W / 2 + cf.from, cx
                frameOut(cv, string.format("%s/b%d_1_fade_inicio.png", dir, bio))
            elseif fadeAt and f == fadeAt + 9 then
                frameOut(cv, string.format("%s/b%d_2_fade_meio.png", dir, bio))
            end
            if not cf.t0 then maxStep = math.max(maxStep, math.abs(cx - prev)) end
        end
        frameOut(cv, string.format("%s/b%d_3_encruzilhada.png", dir, bio))
        local f = WorldRoad._fork
        local b = f and f.markBoxes and f.markBoxes[2]
        if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
        for _ = 1, 85 do
            WorldRoad.update(1 / 30)
            draw()
            local cx = WorldRoad._castleTop.cx
            if not WorldRoad._castleFade.t0 then maxStep = math.max(maxStep, math.abs(cx - cxs[#cxs])) end
            cxs[#cxs + 1] = cx
        end
        frameOut(cv, string.format("%s/b%d_4_landmark.png", dir, bio))
        print(string.format("bioma %d: fade %s (de %.0f para %.0f), maior passo sem fade %.1f px",
            bio, fadeAt and ("no quadro " .. fadeAt) or "nenhum", fadeFrom or -1, fadeTo or -1, maxStep))
    end
    print(love.filesystem.getSaveDirectory() .. "/" .. dir)
    love.event.quit()
    return true
end

return M
