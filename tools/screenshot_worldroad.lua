-- tools/screenshot_worldroad.lua
-- Captura o WorldRoad (mundo rolante) nos 3 biomas, empilhados verticalmente,
-- pra validação visual. Roda via: love . screenshot_worldroad
-- Saída: worldroad_screenshot.png no save dir.

local M = {}

local WorldRoad = require("src.ui.WorldRoad")

function M.run(mode)
    require("src.ui.PixelCanvas").enableNearest()

    local width, height = love.graphics.getDimensions()

    love.graphics.clear(0, 0, 0, 1)

    if mode == "interior" then
        -- Interior de castelo (boss/elite): SceneBackground + inimigo fixo
        local SceneBackground = require("src.ui.SceneBackground")
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local I18n = require("src.i18n.I18n")
        I18n.init()
        local Game = require("src.core.Game")
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        _G.game = game
        local InteriorFX = require("src.ui.InteriorFX")
        for _ = 1, 40 do
            EnemyRenderer.update(1 / 30)
            InteriorFX.update(1 / 30, 1)
        end
        SceneBackground.draw("castle_hall_1", width, height, 0.15)
        InteriorFX.draw(1)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, 80)
        EnemyRenderer.draw(game, math.floor(width / 2), math.floor(height * 0.68))
    elseif mode == "blend6" then
        -- Reproduz a chegada no bioma 6 vindo do 5: blend de crossfade
        -- ATIVO + viagem + encounter (condição real de gameplay que os
        -- modos estáticos não exercitam)
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(5)
        WorldRoad._camZ = 5 * 7.3
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.setBiome(6)                      -- dispara o blend (2.2s)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "grave_slime" }),
        })
        for _ = 1, 34 do                            -- ~1.1s: meio do blend
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, nil)
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, nil)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "full" or (mode and mode:match("^full%d$")) then
        -- Um bioma em tela cheia (proporção real de gameplay, com topbar fake)
        -- "full" = bioma 1; "full5" = bioma 5, etc.
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(tonumber(mode:match("%d")) or 1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "travel" then
        -- Meio de uma viagem: herói andando + poeira + inimigo vindo lá de trás
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "grave_slime" }),
        })
        -- avança até ~65% da viagem (inimigo já emergiu da crista e cresce).
        -- draw a cada tick pra _heroScreenPos existir e a poeira spawnar.
        for _ = 1, 70 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "endless" then
        -- Biomas endless (4-6: frost/marsh/dusk) empilhados
        local panelH = math.floor(height / 3)
        for i = 1, 3 do
            local act = i + 3
            WorldRoad.clearCache()
            WorldRoad.setBiome(act)
            WorldRoad._blend = nil       -- paleta pura (sem meio-blend)
            WorldRoad._camZ = act * 7.3
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad.draw(0, (i - 1) * panelH, width, panelH, act)
        end
    else
        local panelH = math.floor(height / 3)
        for act = 1, 3 do
            WorldRoad.clearCache()
            WorldRoad.setBiome(act)
            -- distâncias diferentes pra mostrar pontos distintos da serpentina
            WorldRoad._camZ = act * 7.3
            -- simula tempo pra nuvens/props assentarem
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            -- simula viagem em andamento no painel 2 (bob ativo)
            if act == 2 then WorldRoad.travel({ distance = 10, duration = 3 }) ; WorldRoad.update(0.5) end

            WorldRoad.draw(0, (act - 1) * panelH, width, panelH, act)
        end
    end

    love.graphics.captureScreenshot(function(imageData)
        local path = "worldroad_screenshot.png"
        imageData:encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)

    love.graphics.present()
end

return M
