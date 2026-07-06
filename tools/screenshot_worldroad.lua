-- tools/screenshot_worldroad.lua
-- Captura o WorldRoad (mundo rolante) nos 3 biomas, empilhados verticalmente,
-- pra validação visual. Roda via: love . screenshot_worldroad
-- Saída: worldroad_screenshot.png no save dir.

local M = {}

local WorldRoad = require("src.ui.WorldRoad")

function M.run(mode)
    require("src.ui.PixelCanvas").enableNearest()

    -- prefixo "wide_": valida em aspect de monitor grande (1914x1011)
    if mode and mode:match("^wide_") then
        love.window.setMode(1914, 1011)
        mode = mode:gsub("^wide_", "")
    end

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
    elseif mode == "gate" or (mode and mode:match("^gate%d$")) then
        -- FIM DE TRECHO: castelo grande com o portão visível (validação da
        -- curva de aproximação v5). camZ a 92% do segmento. "gate3" = bioma 3.
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(tonumber(mode:match("%d")) or 1)
        local segLen = WorldRoad.TRAVEL_DISTANCE * 8
        WorldRoad._camZ = segLen * 0.92
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "fork" or mode == "fork2" then
        -- A ENCRUZILHADA (v5): estrada bifurcada com 3 marcos + hover no 2.
        -- "fork2" captura o MEIO da convergência (braço escolhido virando
        -- a estrada central).
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.showFork({
            { type = "battle", label = "Batalha", desc = "Um inimigo bloqueia a estrada" },
            { type = "rest",   label = "Descanso", desc = "Fogueira acolhedora" },
            { type = "shop",   label = "Loja", desc = "Um mercador acena" },
        }, function() end)
        -- alguns frames pra animIn assentar + registrar markBoxes (precisa
        -- de draw pra calcular as hitboxes)
        for _ = 1, 20 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        end
        if WorldRoad._fork then WorldRoad._fork.hover = 2 end
        if mode == "fork2" then
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[3]
            if b then
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            for _ = 1, 85 do   -- atravessa a convergência INTEIRA (2.4s)
                WorldRoad.update(1 / 30)   -- exercita onChosen + _landmark
                WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            end
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
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
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
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
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
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
