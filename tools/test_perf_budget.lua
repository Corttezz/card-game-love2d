-- tools/test_perf_budget.lua
-- TRAVA DE REGRESSÃO DE PERFORMANCE do WorldRoad (Out/2026).
--
-- Não mede milissegundo (varia por máquina e por carga — numa máquina
-- compartilhada o ruído é maior que a regressão). Trava as CAUSAS que a
-- otimização removeu, todas determinísticas:
--   1. orçamento de DRAW CALLS por frame (era ~800-1000; hoje ~400);
--   2. câmera PARADA não reconstrói nada: a grama reusa o lote (vento no
--      shader) e o chão do domo reusa a malha — 0 sprites escritos pela
--      CPU por frame em batalha;
--   3. o cache NÃO fica velho: câmera andando, fork abrindo e troca de
--      bioma reconstroem (otimização que congela a cena é bug pior);
--   4. ALOCAÇÃO por frame (GC) abaixo de um teto;
--   5. troca de bioma PRÉ-AQUECIDA: o 1º frame do bioma novo não
--      decodifica PNG (era o engasgo de 100-370 ms da troca de ato).
-- Medir ms de verdade: love . test_one perf_probe [WxH[:phases|:switch]]

local TK = require("tools.testkit")

local M = {}

local DRAWCALL_BUDGET = 600      -- por frame, câmera parada, bioma 1
local ALLOC_BUDGET_KB = 40       -- por frame, GC parado (era ~130; hoje ~30)
local SWITCH_DECODE_BUDGET = 0   -- PNGs decodificados no 1º frame do bioma novo

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
        -- 1º draw instala o bioma; pré-aquecimento síncrono (orçamento grande)
        frame(1)
        for _ = 1, 4000 do
            if WorldRoad.isPrewarmed(1) and WorldRoad.isPrewarmed(2) then break end
            WorldRoad.prewarmTick(0.05)
        end
        t:truthy("pré-aquecimento termina (bioma atual e o próximo)",
            WorldRoad.isPrewarmed(1) and WorldRoad.isPrewarmed(2))

        -- passa o broto das fileiras (animação de CPU de ~1.4s)
        for _ = 1, 110 do frame(1) end

        -- ---- 1+2: câmera parada --------------------------------------
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

        -- ---- 4: alocação ----------------------------------------------
        collectgarbage("collect")
        collectgarbage("stop")
        local k0 = collectgarbage("count")
        for _ = 1, 30 do frame(1) end
        local perKB = (collectgarbage("count") - k0) / 30
        collectgarbage("restart")
        t:check(("alocação por frame ≤ %d KB (obtido %.1f KB)"):format(ALLOC_BUDGET_KB, perKB),
            perKB <= ALLOC_BUDGET_KB)

        -- ---- 3: o cache não fica velho --------------------------------
        WorldRoad._camZ = WorldRoad._camZ + 0.37
        GrassField.resetStats()
        domeBefore = WorldRoad._domeBuilds or 0
        frame(1)
        t:check("câmera andou → grama reconstrói (nada reusado)",
            GrassField.stats.builds > 0 and GrassField.stats.replays == 0)
        t:check("câmera andou → chão do domo reconstrói",
            (WorldRoad._domeBuilds or 0) > domeBefore)
        for _ = 1, 3 do frame(1) end     -- assenta de novo

        WorldRoad.showFork({ { type = "battle" }, { type = "rest" },
            { type = "shop" } }, function() end)
        GrassField.resetStats()
        frame(1); frame(1)
        t:check("fork abrindo → grama reconstrói (clareira dos braços)",
            GrassField.stats.builds > 0)
        for _ = 1, 40 do frame(1) end     -- animIn chega em 1
        GrassField.resetStats()
        for _ = 1, 5 do frame(1) end
        t:check("fork aberto e parado → grama volta a reusar o lote",
            GrassField.stats.builds == 0 and GrassField.stats.replays > 0)
        WorldRoad._fork = nil

        -- ---- 5: troca de bioma pré-aquecida ---------------------------
        local decodes = 0
        local realNewImage, realNewImageData = love.graphics.newImage,
            love.image.newImageData
        love.graphics.newImage = function(...)
            decodes = decodes + 1
            return realNewImage(...)
        end
        love.image.newImageData = function(a, ...)
            -- só conta DECODIFICAÇÃO de arquivo (string = caminho)
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

    -- ---- 6: seleção de classe aquece o bioma 1 mesmo com o mundo parado
    -- em outro ato (run anterior terminou no ato 4) ----------------------
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
