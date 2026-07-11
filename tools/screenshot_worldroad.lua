-- tools/screenshot_worldroad.lua
-- Captura o WorldRoad (mundo rolante) nos 3 biomas, empilhados verticalmente,
-- pra validação visual. Roda via: love . screenshot_worldroad
-- Saída: worldroad_screenshot.png no save dir.

local M = {}

local WorldRoad = require("src.ui.WorldRoad")
local LightEngine = require("engine.LightEngine")

-- LightEngine v1: overlays (composite multiply + fork marks) — mesma ordem
-- do GameplayScene. Helper local pra manter os modos legíveis.
local function overlays(x, y, w, h)
    WorldRoad.drawOverlays(x, y, w, h)
end

function M.run(mode)
    require("src.ui.PixelCanvas").enableNearest()

    -- prefixo "nolight_": baseline A/B com o motor de luz DESLIGADO
    if mode and mode:match("^nolight_") then
        LightEngine.setEnabled(false)
        mode = mode:gsub("^nolight_", "")
    end

    -- prefixos F6.1: "day_" = andar 1 (dia), "mid_" = meio do ato.
    -- Default = 1 (anoitecer/boss — mood cheio, o look validado).
    if mode and mode:match("^day_") then
        WorldRoad.setTimeOfDay(0, true)
        mode = mode:gsub("^day_", "")
    elseif mode and mode:match("^mid_") then
        WorldRoad.setTimeOfDay(0.5, true)
        mode = mode:gsub("^mid_", "")
    end

    -- prefixo "dark_": cenário BEM escuro (revisão de emissivos/olhos —
    -- ambiente a 55% do noturno; é onde luz mal posicionada aparece)
    if mode and mode:match("^dark_") then
        LightEngine.debugAmbientScale = 0.55
        WorldRoad.setTimeOfDay(1, true)
        mode = mode:gsub("^dark_", "")
    end

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
        local bio = tonumber(mode:match("%d")) or 1
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        local segLen = WorldRoad.TRAVEL_DISTANCE * 8
        -- v10.2: máximo NATURAL da caminhada (sem boost de câmera) —
        -- calibra CASTLE_APPROACH pra caber sem cortar/sair da esfera
        WorldRoad._camZ = segLen * 1.0
        WorldRoad._segBase = 0
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        -- mata o blend residual do setBiome (paleta pura, igual ao modo
        -- endless) e passa o MESMO bioma no draw — o 1 hardcoded criava
        -- blend invertido fields→bioma que a mountains_front do v5.8 expôs
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^entry%d?$") then
        -- v10: CERIMÔNIA DA PORTA congelada no meio (fase door, ~0.7) —
        -- valida frames da porta + boost do clamp em cena. "entry3" = bioma 3
        local topBarH = 80
        local bio = tonumber(mode:match("%d")) or 1
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        local segLen = WorldRoad.TRAVEL_DISTANCE * 8
        WorldRoad._camZ = segLen * 1.0
        WorldRoad._segBase = 0
        WorldRoad._entry = { phase = "door", t = 0,
                             doorK = 0, fade = 0, sound = nil }
        for _ = 1, 30 do WorldRoad.update(1 / 30) end   -- ~1s → doorK ≈ 0.7
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
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
            overlays(0, topBarH, width, height - topBarH)
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
                overlays(0, topBarH, width, height - topBarH)
            end
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "poke" then
        -- v9.7: CENÁRIO INTERATIVO — varre cliques fora dos marcos
        -- (árvores/postes/cercas/nuvens) e captura ~0.17s depois, no meio
        -- da mexidinha (pêndulo + folhinhas + squash de nuvem + rajada)
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.showFork({
            { type = "battle", label = "Batalha", desc = "x" },
            { type = "rest",   label = "Descanso", desc = "x" },
            { type = "shop",   label = "Loja", desc = "x" },
        }, function() end)
        for _ = 1, 20 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        local hits = 0
        for gy = 0.10, 0.92, 0.08 do
            for gx = 0.05, 0.95, 0.06 do
                if WorldRoad.pokeSceneAt(gx * width,
                    topBarH + gy * (height - topBarH)) then
                    hits = hits + 1
                end
            end
        end
        print("[poke] alvos atingidos na varredura: " .. hits)
        local GrassField = require("engine.GrassField")
        GrassField.pokeAt(0.30, WorldRoad._camZ + 3, WorldRoad._time)
        for _ = 1, 5 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        overlays(0, topBarH, width, height - topBarH)
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
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "grassanim" then
        -- SEQUÊNCIA TEMPORAL (v7.4.x): 24 frames consecutivos com câmera
        -- PARADA — análise numérica de ondas/bandas coerentes no gramado
        -- (diff por linha frame a frame localiza artefato de movimento)
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        -- warmup COM draw: o cache de fileiras (e o broto de entrada) só
        -- existe quando desenha — sem isso a captura mede o broto, não o
        -- regime (lição: a 1ª análise mediu a animação de entrada)
        for _ = 1, 90 do
            WorldRoad.update(1 / 30)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        end
        for i = 1, 24 do
            WorldRoad.update(1 / 30)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            local path = string.format("ga_%02d.png", i)
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", path)
            end)
            love.graphics.present()
        end
        print("[screenshot] 24 frames ga_XX.png salvos")
        love.event.quit()
        return
    elseif mode and mode:match("^lumanim%d$") then
        -- v9.1: PROVA do fogo animado das luminárias — converte os props
        -- do bioma em luminárias (ciclo pelo catálogo) e salva 2 instantes
        -- (lum_a/lum_b.png); diff das duas mostra SÓ chama/lâmpada mexendo
        local LuminaireEngine = require("engine.LuminaireEngine")
        local bio = tonumber(mode:match("%d")) or 1
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.update(1 / 30)
        local kinds = {}
        local bid = require("src.data.biomes")[bio].id
        for kind in pairs(LuminaireEngine.catalog(bid)) do
            kinds[#kinds + 1] = kind
        end
        table.sort(kinds)
        local ki = 0
        for _, p in ipairs(WorldRoad._props) do
            if p.kind ~= "tuft" and p.kind ~= "fence" then
                ki = ki + 1
                p.kind = kinds[(ki % #kinds) + 1]
                p.variant = 0
                p.cluster = nil
                p.big = 1
            end
        end
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        for fi, name in ipairs({ "lum_a.png", "lum_b.png" }) do
            if fi == 2 then
                for _ = 1, 5 do WorldRoad.update(1 / 30) end
            end
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
            overlays(0, topBarH, width, height - topBarH)
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", name)
                print("[screenshot] salvo: " .. name)
            end)
            love.graphics.present()
        end
        love.event.quit()
        return
    elseif mode == "bench" or mode == "bench0" then
        -- BENCHMARK de CPU (v7.4): 200 frames de VIAGEM simulada (camZ
        -- avançando = pior caso do tapete de grama). Mede update+draw sem
        -- present (CPU puro; GPU com 7k sprites pequenos é trivial).
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)  -- aquece caches
        local GrassField = require("engine.GrassField")
        GrassField.disabled = (mode == "bench0")   -- A/B: sem grama
        local N = 200
        local tStart = love.timer.getTime()
        for _ = 1, N do
            WorldRoad.update(1 / 60)
            WorldRoad._camZ = WorldRoad._camZ + 0.045   -- ritmo de viagem
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        local ms = (love.timer.getTime() - tStart) / N * 1000
        local stats = love.graphics.getStats()
        print(string.format(
            "[bench] %.2f ms/frame CPU (update+draw) | sprites de grama: %d | drawcalls: %d",
            ms, GrassField._lastCount or -1, stats.drawcalls))
        love.event.quit()
        return
    elseif mode == "grass" then
        -- VALIDAÇÃO DE VENTO (v7.1): mesmo bioma em 2 instantes (Δ1.1s) —
        -- diff das capturas prova que as lâminas do GrassField balançam.
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for shot = 1, 2 do
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            love.graphics.setColor(0.1, 0.08, 0.06, 1)
            love.graphics.rectangle("fill", 0, 0, width, topBarH)
            local path = "worldroad_grass" .. shot .. ".png"
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", path)
                print("[screenshot] salvo em save-dir: " .. path)
            end)
            love.graphics.present()
            if shot == 1 then
                for _ = 1, 33 do WorldRoad.update(1 / 30) end
            end
        end
        love.event.quit()
        return
    elseif mode == "all" then
        -- TODOS os 6 biomas em UM processo (protocolo anti-wedge do driver:
        -- 1 contexto GL, não 6 — ver memory nvidia-driver-love-crash).
        -- Salva worldroad_full1.png .. worldroad_full6.png no save dir.
        local topBarH = 80
        for bio = 1, 6 do
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.clearCache()
            WorldRoad.setBiome(bio)
            WorldRoad._camZ = 5.5
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
            overlays(0, topBarH, width, height - topBarH)
            love.graphics.setColor(0.1, 0.08, 0.06, 1)
            love.graphics.rectangle("fill", 0, 0, width, topBarH)
            local path = "worldroad_full" .. bio .. ".png"
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", path)
                print("[screenshot] salvo em save-dir: " .. path)
            end)
            love.graphics.present()
        end
        love.event.quit()
        return
    elseif mode == "full" or (mode and mode:match("^full%d$")) then
        -- Um bioma em tela cheia (proporção real de gameplay, com topbar fake)
        -- "full" = bioma 1; "full5" = bioma 5, etc.
        local topBarH = 80
        local bio = tonumber(mode:match("%d")) or 1
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^postgate%d?") then
        -- v9.2: MARGEM TOTAL de postes — a beira do caminho INTEIRA (perto
        -- até a crista) forrada de postes nos dois lados, pra VALIDAR cada
        -- posição possível (flip do braço, glow, sombra, sumir na dobra).
        -- Sem monstro: foco na cobertura da margem. "postgate3" = bioma 3.
        local bio = tonumber(mode:match("%d")) or 1
        local topBarH = 80
        WorldRoad.clearCache(); WorldRoad.setBiome(bio)
        local camZ = 4; WorldRoad._camZ = camZ
        for _ = 1, 30 do WorldRoad.update(1/30) end
        WorldRoad._blend = nil; WorldRoad._prevBiomeIndex = nil
        -- força SÓ postes, DENSO: um par a cada 0.7 unidade, de perto (rel
        -- ~0.5) até além da crista (emersão) — cobre a margem inteira
        WorldRoad._props = {}
        local bid = require("src.data.biomes")[bio].id
        local rel = 0.5
        while rel < 30 do
            for side = -1, 1, 2 do
                WorldRoad._props[#WorldRoad._props+1] = {
                    z = camZ + rel, kind = "lantern", side = side,
                    lane = 0, variant = 0, bid = bid, big = 1, jitter = 0,
                }
            end
            rel = rel + 0.7
        end
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^enemy%d_") then
        -- Monstro PLANTADO na estrada do bioma: "enemy4_winter_monarch"
        -- (valida roster endless no cenário certo, com HUD desligado)
        local bio = tonumber(mode:match("^enemy(%d)_"))
        local sid = mode:match("^enemy%d_(.+)$")
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local I18n = require("src.i18n.I18n")
        I18n.init()
        local Game = require("src.core.Game")
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        _G.game = game
        game.enemy.spriteId = sid
        game.enemy.isBoss = (sid == "winter_monarch" or sid == "rot_colossus"
            or sid == "eclipse_queen")
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 6
        for _ = 1, 30 do
            WorldRoad.update(1 / 30)
            EnemyRenderer.update(1 / 30)
        end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        -- v9.2: inimigo via callback do painter (props próximos na frente)
        local cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarH, width, height - topBarH)
        WorldRoad.setBattleEnemyDraw(function()
            EnemyRenderer.draw(game, cx, cy)
        end, cy)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
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
        overlays(0, topBarH, width, height - topBarH)
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
            overlays(0, (i - 1) * panelH, width, panelH)
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
            overlays(0, (act - 1) * panelH, width, panelH)
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
