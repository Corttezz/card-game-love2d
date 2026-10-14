local TK = require("tools.testkit")

local M = {}

local DRAWCALL_BUDGET = 600
local ALLOC_BUDGET_KB = 40
local SWITCH_DECODE_BUDGET = 0

function M.run()
    local t = TK.new("perf budget (WorldRoad: draw calls, cache, GC, troca de bioma)")
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")

    local WorldRoad = require("src.ui.WorldRoad")
    local GrassField = require("engine.GrassField")
    local W, H = love.graphics.getDimensions()
    local canvas = love.graphics.newCanvas(W, H)
    local topBarH = 52

    WorldRoad.clearCache()
    WorldRoad.resetRun()
    WorldRoad._birdTimer = 1e9

    local function frame(bio)
        WorldRoad.update(1 / 60)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, W, H - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, W, H - topBarH)
        love.graphics.setCanvas()
    end

    local ok, err = pcall(function()
        frame(1)
        for _ = 1, 4000 do
            if WorldRoad.isPrewarmed(1) and WorldRoad.isPrewarmed(2) then break end
            WorldRoad.prewarmTick(0.05)
        end
        t:truthy("pré-aquecimento termina (bioma atual e o próximo)",
            WorldRoad.isPrewarmed(1) and WorldRoad.isPrewarmed(2))

        for _ = 1, 110 do frame(1) end

        GrassField.resetStats()
        local domeBefore = WorldRoad._domeBuilds or 0
        local s0 = love.graphics.getStats().drawcalls
        frame(1)
        local dc = love.graphics.getStats().drawcalls - s0
        t:check(("draw calls por frame ≤ %d (obtido %d)"):format(DRAWCALL_BUDGET, dc),
            dc > 0 and dc <= DRAWCALL_BUDGET)
        for _ = 1, 29 do frame(1) end
        local st = GrassField.stats
        t:eq("grama com câmera parada: nenhuma fatia reconstruída em 30 frames",
            st.builds, 0)
        t:eq("grama com câmera parada: 0 sprites escritos pela CPU", st.sprites, 0)
        t:check(("grama com câmera parada: fatias reusadas (%d)"):format(st.replays),
            st.replays >= 30)
        t:eq("chão do domo com câmera parada: malha não reconstruída",
            WorldRoad._domeBuilds or 0, domeBefore)

        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 30 do frame(1) end
        local perKB = (collectgarbage("count") - k0) / 30
        collectgarbage("restart")
        t:check(("alocação por frame ≤ %d KB (obtido %.1f KB)"):format(ALLOC_BUDGET_KB, perKB),
            perKB <= ALLOC_BUDGET_KB)

        WorldRoad._camZ = WorldRoad._camZ + 0.37
        GrassField.resetStats()
        domeBefore = WorldRoad._domeBuilds or 0
        frame(1)
        t:check("câmera andou → grama reconstrói (nada reusado)",
            GrassField.stats.builds > 0 and GrassField.stats.replays == 0)
        t:check("câmera andou → chão do domo reconstrói",
            (WorldRoad._domeBuilds or 0) > domeBefore)
        for _ = 1, 3 do frame(1) end

        WorldRoad.showFork({ { type = "battle" }, { type = "rest" },
            { type = "shop" } }, function() end)
        GrassField.resetStats()
        frame(1); frame(1)
        t:check("fork abrindo → grama reconstrói (clareira dos braços)",
            GrassField.stats.builds > 0)
        for _ = 1, 40 do frame(1) end
        GrassField.resetStats()
        for _ = 1, 5 do frame(1) end
        t:check("fork aberto e parado → grama volta a reusar o lote",
            GrassField.stats.builds == 0 and GrassField.stats.replays > 0)

        local realDraw, lastCtx = GrassField.draw, nil
        GrassField.draw = function(ctx, ...)
            lastCtx = ctx
            return realDraw(ctx, ...)
        end
        local okF, errF = pcall(function()
            local f = WorldRoad._fork
            f.chosen, f.hover = 2, 2
            f.converge = { t = 0, k = 0, duration = 2.4,
                z0 = WorldRoad._camZ, dist = 10 }
            local closed = false
            f.onChosen = function() closed = true end
            local fadedArmOk, sawFaded, convBuilt = true, false, true
            while WorldRoad._fork and not closed do
                GrassField.resetStats()
                frame(1)
                if WorldRoad._fork then
                    convBuilt = convBuilt and GrassField.stats.builds > 0
                end
                local k = WorldRoad._fork and WorldRoad._fork.converge.k or 1
                if WorldRoad._fork and k >= 0.7 and lastCtx
                   and lastCtx.roadCenters then
                    local z = WorldRoad._camZ + 14
                    local cs, _, ws = lastCtx.roadCenters(z, 0.5)
                    if cs then
                        sawFaded = true
                        fadedArmOk = fadedArmOk and ws ~= nil
                            and ws[1] == 0 and ws[3] == 0 and ws[2] == 1
                    end
                end
            end
            t:check("fork fechando → grama reconstrói a cada frame da convergência",
                convBuilt)
            t:check("fork fechando → braço que sumiu não deixa clareira (largura 0)",
                sawFaded and fadedArmOk)
            for _ = 1, 3 do frame(1) end
            GrassField.resetStats()
            for _ = 1, 5 do frame(1) end
            t:check("fork fechado e assentado → grama volta a reusar o lote",
                GrassField.stats.builds == 0 and GrassField.stats.replays > 0)
        end)
        GrassField.draw = realDraw
        if not okF then error(errF, 0) end
        WorldRoad._fork = nil
        WorldRoad._landmark = nil

        local decodes = 0
        local realNewImage, realNewImageData = love.graphics.newImage,
            love.image.newImageData
        love.graphics.newImage = function(...)
            decodes = decodes + 1
            return realNewImage(...)
        end
        love.image.newImageData = function(a, ...)
            if type(a) == "string" then decodes = decodes + 1 end
            return realNewImageData(a, ...)
        end
        local ok2, err2 = pcall(function()
            GrassField.resetStats()
            frame(2)
            t:check(("troca de bioma: 1º frame decodifica ≤ %d PNG (obtido %d)")
                :format(SWITCH_DECODE_BUDGET, decodes), decodes <= SWITCH_DECODE_BUDGET)
            t:check("troca de bioma → grama reconstrói (cor nova)",
                GrassField.stats.builds > 0)
        end)
        love.graphics.newImage, love.image.newImageData = realNewImage, realNewImageData
        if not ok2 then error(err2, 0) end
    end)
    t:check("cenário roda sem erro" .. (ok and "" or (": " .. tostring(err))), ok)

    do
        local WR = require("src.ui.WorldRoad")
        WR.clearCache()
        local prevIdx = WR._biomeIndex
        WR._biomeIndex = 4
        for _ = 1, 2000 do
            if WR.isPrewarmed(1) then break end
            WR.prewarmTick(1, 1)
        end
        t:check("prewarmTick(_, 1) aquece o bioma 1 com o mundo em outro ato",
            WR.isPrewarmed(1))
        WR._biomeIndex = prevIdx
    end

    WorldRoad.resetRun()
    WorldRoad.clearCache()
    return t:done()
end

return M
