-- tools/screenshot_sombras_mundo.lua
-- Capturas de PROVA das sombras do mundo (Out/2026, "a fogueira é um
-- círculo e a sombra é o círculo inteiro depois dela"). Mesmo processo,
-- mesmos casos antes e depois da mudança no ShadowEngine — a comparação
-- é lado a lado, por caso.
--
--   love . test_one screenshot_sombras_mundo antes
--   love . test_one screenshot_sombras_mundo depois
--
-- Casos (relógio congelado, RNG semeado, tod 0.5 = sombra média):
--   rest<b>    fogueira do descanso plantada na estrada do bioma b (1..6)
--   chest1     baú (marco baixo e largo)
--   props<b>   campo do bioma b (pedras, tocos, moitas, árvores, luminárias)
--   fork       encruzilhada com estandarte + loja + tenda (NÃO podem mudar)
--   up_<id>    criatura apoiada em pé na estrada (rato, touro, lavrador)
--   dead_<id>  cadáver da mesma criatura (clip death terminado)
--   float      criatura flutuante (dusk_shade)
-- Saída: sombras_<tag>_<caso>.png no save dir.

local M = {}

local CREATURES = { "plague_rats", "blight_bull", "hollow_farmer" }

local function restKey(bid)
    if bid == "fields" then return "landmark_rest" end
    return bid .. "_landmark_rest"
end

function M.run(tag)
    tag = tag or "antes"
    if tag == "dump" then return M.dump() end
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local biomes = require("src.data.biomes")
    -- relógio REAL congelado: flicker das luminárias e balanço de pose leem
    -- love.timer.getTime; sem isso o par com/sem sombra difere no campo
    -- inteiro (lightmap) e a máscara da sombra vira ruído.
    -- (constante, não a hora real: assim duas rodadas — antes/depois de uma
    -- mudança no motor — saem byte a byte comparáveis)
    local T0 = 1000
    love.timer.getTime = function() return T0 end
    local width, height = love.graphics.getDimensions()
    local topBarH = 80
    local out = {}

    local function freeze()
        love.math.setRandomSeed(42)
        math.randomseed(42)
        WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
        WorldRoad.clearCache()
        WorldRoad._time = 0
        WorldRoad._birds, WorldRoad._critters, WorldRoad._ambient = {}, {}, {}
        WorldRoad._birdTimer = 1e9
        WorldRoad.setTimeOfDay(0.5, true)
    end

    local function settle(bio, camZ, ticks)
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = camZ
        for _ = 1, ticks or 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
    end

    -- cada caso sai em DOIS quadros: com sombra e com o ShadowEngine mudo
    -- (sprite/queue/silhouette devolvem true sem desenhar — o fallback de
    -- elipse também não entra). A diferença entre os dois É a sombra, e é
    -- o que a prancha de revisão pinta por cima.
    local ShadowEngine = require("engine.ShadowEngine")
    local origSprite, origQueue, origSil =
        ShadowEngine.sprite, ShadowEngine.queue, ShadowEngine.silhouette
    local function mute(on)
        if on then
            ShadowEngine.sprite = function() return true end
            ShadowEngine.queue = function() return true end
            ShadowEngine.silhouette = function() return true end
        else
            ShadowEngine.sprite, ShadowEngine.queue, ShadowEngine.silhouette =
                origSprite, origQueue, origSil
        end
    end

    local shoot
    -- pre: re-arma o que o draw CONSOME (WorldRoad.draw zera o callback
    -- do inimigo a cada quadro — sem re-armar, o 2º quadro do par sai vazio)
    shoot = function(name, bio, pre)
        if not name:match("_ns$") then
            mute(true)
            shoot(name .. "_ns", bio, pre)
            mute(false)
        end
        if pre then pre() end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
        love.graphics.setColor(1, 1, 1, 1)
        local path = "sombras_" .. tag .. "_" .. name .. ".png"
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", path)
            print("[sombras] salvo " .. path)
        end)
        love.graphics.present()
        out[#out + 1] = path
    end

    -- 1) fogueira do descanso em cada bioma + baú
    for bio = 1, 6 do
        freeze()
        settle(bio, 5.5)
        WorldRoad._landmark = { key = restKey(biomes[bio].id),
            z = WorldRoad._camZ + 4.0, size = 3.6, phase = 0 }
        shoot("rest" .. bio, bio)
    end
    freeze()
    settle(1, 5.5)
    WorldRoad._landmark = { key = "landmark_chest",
        z = WorldRoad._camZ + 4.0, size = 2.6, phase = 0 }
    shoot("chest1", 1)
    WorldRoad._landmark = nil

    -- 2) campo de props por bioma
    for bio = 1, 6 do
        freeze()
        settle(bio, 5.5)
        shoot("props" .. bio, bio)
    end

    -- 3) encruzilhada: estandarte + loja + tenda (prova de que NÃO mudam)
    freeze()
    settle(2, 5.5)
    WorldRoad.showFork({ { type = "battle" }, { type = "shop" }, { type = "event" } },
        function() end)
    for _ = 1, 40 do WorldRoad.update(1 / 30) end
    shoot("fork", 2)
    WorldRoad._fork = nil

    -- 3b) encruzilhadas SEM props (só os marcos projetam): prova de que
    -- estandarte, loja, tenda, obelisco e totem ficam pixel a pixel iguais
    for i, nodes in ipairs({
        { { type = "battle" }, { type = "shop" }, { type = "event" } },
        { { type = "elite" }, { type = "mini_boss" }, { type = "treasure" } },
        { { type = "rest" }, { type = "battle" }, { type = "rest" } },
    }) do
        freeze()
        settle(2, 5.5)
        WorldRoad._props = {}
        WorldRoad.showFork(nodes, function() end)
        for _ = 1, 40 do WorldRoad.update(1 / 30) end
        shoot("forkclean" .. i, 2)
        WorldRoad._fork = nil
    end

    -- 4) criaturas: em pé, cadáver, flutuante
    local I18n = require("src.i18n.I18n")
    I18n.init()
    local Game = require("src.core.Game")
    local function plant(sid, dead, bio)
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        _G.game = game
        game.enemy.spriteId = sid
        game.enemy.isBoss = false
        EnemyRenderer.resetRun()
        freeze()
        settle(bio or 1, 6)
        for _ = 1, 30 do EnemyRenderer.update(1 / 30) end
        if dead then
            game.enemy.health = 0
            EnemyRenderer.triggerDeath(sid)
            for _ = 1, 45 do
                EnemyRenderer.update(1 / 30)
                WorldRoad.update(1 / 30)
            end
        end
        local cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarH, width, height - topBarH)
        return function()
            WorldRoad.setBattleEnemyDraw(function()
                EnemyRenderer.draw(game, cx, cy)
            end, cy)
        end
    end
    for _, sid in ipairs(CREATURES) do
        shoot("up_" .. sid, 1, plant(sid, false, 1))
        shoot("dead_" .. sid, 1, plant(sid, true, 1))
    end
    shoot("float", 6, plant("dusk_shade", false, 6))
    WorldRoad.setBattleEnemyDraw(nil)

    print("[sombras] save dir: " .. love.filesystem.getSaveDirectory())
    print("[sombras] " .. #out .. " capturas (" .. tag .. ")")
    love.event.quit()
    return true
end

-- Modo auxiliar: despeja os sprites PROCEDURAIS dos props (makeShrine etc.)
-- como PNG, pra classificar a pegada de cada tipo olhando a arte.
--   love . test_one screenshot_sombras_mundo dump
function M.dump()
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local width, height = love.graphics.getDimensions()
    local n = 0
    for bio = 1, 6 do
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for _ = 1, 3 do
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 80, width, height - 80, bio)
            WorldRoad._camZ = WorldRoad._camZ + 6
            WorldRoad.update(1 / 30)
        end
        for key, img in pairs(WorldRoad._spriteCache) do
            if img and type(img) ~= "boolean" and img.getWidth then
                local cv = love.graphics.newCanvas(img:getWidth(), img:getHeight())
                love.graphics.setCanvas(cv)
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, 0, 0)
                love.graphics.setCanvas()
                cv:newImageData():encode("png", "sprite_" .. key .. ".png")
                n = n + 1
            end
        end
    end
    print("[sombras] " .. n .. " sprites despejados em " .. love.filesystem.getSaveDirectory())
    love.event.quit()
    return true
end

return M
