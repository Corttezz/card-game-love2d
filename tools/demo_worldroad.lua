-- tools/demo_worldroad.lua
-- Demo do WorldRoad com o VISUAL REAL de batalha (game + enemy + HUD).
--
-- Interativo (love . demo_worldroad):
--   SPACE = viagem com encounter (inimigo vem lá de trás)
--   1-6   = troca bioma (com blend)
--   V     = pula pra perto do marco (vista alta)
--   R     = reset camZ
--   ESC   = sair
--
-- Tour (love . demo_worldroad tour): captura 6 keyframes automáticos no save
-- dir (worldroad_k1..k6.png) e sai — pipeline de validação visual da LLM.
--   k1 battle    — inimigo PLANTADO na estrada (getRoadAnchor) + HUD
--   k2 depart    — viagem 15%: herói surge, encounter na crista
--   k3 mid       — viagem 55%: inimigo desce a estrada crescendo
--   k4 arrive    — viagem 92%: quase em posição de batalha
--   k5 blend     — transição bioma 1→2 no meio (cores lerpando)
--   k6 vista     — perto do marco: castelo da vista totalmente revelado

local M = {}

local WorldRoad = require("src.ui.WorldRoad")
local EnemyRenderer = require("src.ui.EnemyRenderer")
local EnemyHud = require("src.ui.EnemyHud")
local LightEngine = require("engine.LightEngine")
local LuminaireEngine = require("engine.LuminaireEngine")

-- POSTGATE: força TODO prop a virar luminária da beira da estrada, pra
-- validar a margem inteira ao vivo (viajando, trocando bioma). Escolhe um
-- kind roadside do catálogo do bioma (lantern se houver, senão o 1º).
local _postKindCache = {}
local function postKindFor(bid)
    local hit = _postKindCache[bid]
    if hit ~= nil then return hit or nil end
    local cat = LuminaireEngine.catalog(bid)
    local pick = cat.lantern and "lantern" or cat.brazier and "brazier"
    if not pick then
        for k, d in pairs(cat) do if d.roadside then pick = k; break end end
    end
    _postKindCache[bid] = pick or false
    return pick
end

local function forcePosts()
    for _, p in ipairs(WorldRoad._props) do
        local k = postKindFor(p.bid)
        if k then
            p.kind = k
            p.variant = 0
            p.cluster = nil
            p.big = 1
        end
    end
end

local game, topBar, gameUI

local function setupGame()
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    topBar = TopBar:new()
    topBar:setGame(game)
    gameUI = GameUI:new()
    _G.topBar, _G.gameUI = topBar, gameUI
end

-- Frame de batalha completo (mesma composição do GameplayScene).
-- LightEngine v1: mundo → inimigo → composite/fork overlay → HUD/UI
local function drawBattleFrame(showEnemy)
    local width, height = love.graphics.getDimensions()
    local topBarH = topBar.height or 80

    love.graphics.clear(0, 0, 0, 1)

    -- v9.2: inimigo via callback do painter (mesma ordem do GameplayScene —
    -- postes mais próximos que ele ficam na frente)
    local bbox, cx, cy
    if showEnemy and not WorldRoad.isTraveling() then
        cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarH, width, height - topBarH)
        WorldRoad.setBattleEnemyDraw(function()
            bbox = EnemyRenderer.draw(game, cx, cy)
        end, cy)
    end

    WorldRoad.draw(0, topBarH, width, height - topBarH, nil)
    WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)

    topBar:draw()
    if bbox then EnemyHud.draw(game, bbox, cx, cy) end

    gameUI:draw(game)
end

local function sim(ticks)
    for _ = 1, ticks do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
    end
end

-- ============================================================================
-- TOUR: keyframes automáticos (frame-driven — captureScreenshot só funciona
-- de forma confiável dentro do loop real de frames, não em presents manuais)
-- ============================================================================
local function runTour()
    setupGame()

    -- Cada step: setup() roda 1x, simTicks de aquecimento, showEnemy no draw.
    local steps = {
        { name = "worldroad_k1_battle", simTicks = 40, showEnemy = true,
          setup = function()
              WorldRoad.setBiome(1)
              WorldRoad._camZ = 6
          end },
        { name = "worldroad_k2_depart", showEnemy = false,
          simTicks = math.floor(0.15 * WorldRoad.TRAVEL_DURATION * 30),
          setup = function()
              WorldRoad.travel({ encounter = EnemyRenderer.getEncounterBillboard(game.enemy) })
          end },
        { name = "worldroad_k3_mid", showEnemy = false,
          simTicks = math.floor(0.40 * WorldRoad.TRAVEL_DURATION * 30) },
        { name = "worldroad_k4_arrive", showEnemy = false,
          simTicks = math.floor(0.37 * WorldRoad.TRAVEL_DURATION * 30) },
        { name = "worldroad_k5_blend", simTicks = 33, showEnemy = true,
          setup = function()
              -- garante viagem terminada antes do blend
              for _ = 1, 150 do WorldRoad.update(1 / 30) end
              WorldRoad.setBiome(2)
          end },
        { name = "worldroad_k6_vista", simTicks = 40, showEnemy = true,
          setup = function()
              for _ = 1, 80 do WorldRoad.update(1 / 30) end   -- termina blend
              WorldRoad._camZ = WorldRoad.TRAVEL_DISTANCE * 8 * 0.92
              WorldRoad._props = {}
          end },
    }

    local idx = 1
    local ticksLeft = nil
    local captured = false

    love.update = function(dt)
        local step = steps[idx]
        if not step then return end
        if ticksLeft == nil then
            if step.setup then step.setup() end
            ticksLeft = step.simTicks or 30
        end
        if ticksLeft > 0 then
            WorldRoad.update(1 / 30)
            EnemyRenderer.update(1 / 30)
            ticksLeft = ticksLeft - 1
        end
    end

    love.draw = function()
        local step = steps[idx]
        if not step then return end
        drawBattleFrame(step.showEnemy)

        if ticksLeft == 0 and not captured then
            captured = true
            local name = step.name
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", name .. ".png")
                print("[tour] " .. name .. ".png salvo")
                -- avança pro próximo step
                idx = idx + 1
                ticksLeft = nil
                captured = false
                if not steps[idx] then love.event.quit() end
            end)
        end
    end

    love.keypressed = function(key)
        if key == "escape" then love.event.quit() end
    end
end

-- ============================================================================
-- INTERATIVO
-- ============================================================================
-- GALERIA DE MONSTROS (tecla M): roster completo v5, idle rodando no
-- cenário real; setas trocam, H = hurt, K = morte, J = revive.
local MONSTER_ROSTER = {
    { id = "cursed_scarecrow",  label = "Espantalho Maldito  (Ato 1 - comum)" },
    { id = "harvest_reaper",    label = "Ceifador da Colheita  (Ato 1 - elite)" },
    { id = "carrion_king",      label = "Rei Carnica  (Ato 1 - BOSS)", boss = true },
    { id = "moon_gargoyle",     label = "Gargula da Lua  (Ato 2 - comum)" },
    { id = "rune_golem",        label = "Golem de Runas  (Ato 2 - elite)" },
    { id = "tower_lich",        label = "Lich da Torre  (Ato 2 - BOSS)", boss = true },
    { id = "ember_imp",         label = "Diabrete de Brasa  (Ato 3 - comum)" },
    { id = "obsidian_sentinel", label = "Sentinela de Obsidiana  (Ato 3 - elite)" },
    { id = "abyss_tyrant",      label = "Tirano do Abismo  (Ato 3 - BOSS)", boss = true },
    { id = "frost_wight",       label = "Morto-Gelido  (Endless Gelo - comum)" },
    { id = "glacier_knight",    label = "Cavaleiro da Geleira  (Endless Gelo - elite)" },
    { id = "winter_monarch",    label = "Monarca do Inverno  (Endless Gelo - BOSS)", boss = true },
    { id = "bog_ghoul",         label = "Carnical do Brejo  (Endless Pantano - comum)" },
    { id = "mire_hag",          label = "Bruxa do Lamacal  (Endless Pantano - elite)" },
    { id = "rot_colossus",      label = "Colosso da Podridao  (Endless Pantano - BOSS)", boss = true },
    { id = "dusk_shade",        label = "Sombra do Crepusculo  (Endless Anoitecer - comum)" },
    { id = "blood_duke",        label = "Duque de Sangue  (Endless Anoitecer - elite)" },
    { id = "eclipse_queen",     label = "Rainha do Eclipse  (Endless Anoitecer - BOSS)", boss = true },
}

local function runInteractive(postgate)
    setupGame()
    WorldRoad.setBiome(1)
    WorldRoad._camZ = 6

    local gallery = false
    local gIdx = 1

    local function applyGalleryMonster()
        local e = MONSTER_ROSTER[gIdx]
        game.enemy.spriteId = e.id
        game.enemy.isBoss = e.boss or false
        EnemyRenderer.clearCache()   -- reseta anim (revive) e troca sprite
    end

    love.update = function(dt)
        WorldRoad.update(dt)
        EnemyRenderer.update(dt)
        if postgate then forcePosts() end   -- margem inteira em postes
    end

    love.draw = function()
        drawBattleFrame(true)
        love.graphics.setColor(1, 1, 1, 0.85)
        if gallery then
            local e = MONSTER_ROSTER[gIdx]
            local FontManager = require("src.ui.FontManager")
            love.graphics.setFont(FontManager.getFont(16))
            love.graphics.setColor(0.08, 0.06, 0.05, 0.85)
            local label = gIdx .. "/" .. #MONSTER_ROSTER .. "  " .. e.label
            local fw = love.graphics.getFont():getWidth(label)
            love.graphics.rectangle("fill",
                (love.graphics.getWidth() - fw) / 2 - 12, 96, fw + 24, 26, 7, 7)
            love.graphics.setColor(0.95, 0.85, 0.6, 1)
            love.graphics.print(label, (love.graphics.getWidth() - fw) / 2, 100)
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.setFont(FontManager.getFont(12))
            love.graphics.print(
                "GALERIA: setas troca monstro | H dano | K morte | J revive | 1-6 bioma | M sair da galeria",
                12, love.graphics.getHeight() - 24)
        else
            love.graphics.print(
                "SPACE viagem+encounter | 1-6 bioma | V vista | R reset | M galeria"
                .. " | L luz " .. (LightEngine.isEnabled() and "ON" or "OFF")
                .. " | O/P ambiente "
                .. string.format("%.2f", LightEngine.debugAmbientScale)
                .. " | T hora "
                .. string.format("%.2f", WorldRoad._timeOfDay or 1)
                .. " | ESC sair",
                12, love.graphics.getHeight() - 24)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.keypressed = function(key)
        if key == "m" then
            gallery = not gallery
            if gallery then
                applyGalleryMonster()
            else
                -- restaura o inimigo do contexto atual da run
                game.enemy.spriteId = EnemyRenderer.resolveSpriteId(1, "battle")
                game.enemy.isBoss = false
                EnemyRenderer.clearCache()
            end
            return
        end
        if gallery then
            if key == "right" or key == "d" then
                gIdx = gIdx % #MONSTER_ROSTER + 1
                applyGalleryMonster()
            elseif key == "left" or key == "a" then
                gIdx = (gIdx - 2) % #MONSTER_ROSTER + 1
                applyGalleryMonster()
            elseif key == "h" then
                EnemyRenderer.triggerHurt()
            elseif key == "k" then
                EnemyRenderer.triggerDeath(game.enemy.spriteId)
            elseif key == "j" then
                applyGalleryMonster()
            elseif key == "escape" then
                love.event.quit()
            elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 6 then
                WorldRoad.setBiome(tonumber(key))
            end
            return
        end
        if key == "space" and not WorldRoad.isTraveling() then
            WorldRoad.travel({ encounter = EnemyRenderer.getEncounterBillboard(game.enemy) })
        elseif key == "l" then
            -- LightEngine v1: toggle do motor (validação A/B ao vivo)
            LightEngine.setEnabled(not LightEngine.isEnabled())
        elseif key == "o" then
            -- calibração: escurece o ambiente (debug — não persiste)
            LightEngine.debugAmbientScale =
                math.max(0.30, LightEngine.debugAmbientScale - 0.05)
        elseif key == "p" then
            LightEngine.debugAmbientScale =
                math.min(1.30, LightEngine.debugAmbientScale + 0.05)
        elseif key == "t" then
            -- F6.1: cicla o tempo do dia (dia → tarde → anoitecer), com
            -- a transição ease real do jogo
            local cur = WorldRoad._timeOfDayTarget or 1
            local nxt = cur >= 1 and 0 or (cur >= 0.5 and 1 or 0.5)
            WorldRoad.setTimeOfDay(nxt)
        elseif key == "v" then
            WorldRoad._camZ = WorldRoad.TRAVEL_DISTANCE * 8 * 0.92
            WorldRoad._props = {}
        elseif key == "r" then
            WorldRoad._camZ = 6
            WorldRoad._props = {}
        elseif key == "escape" then
            love.event.quit()
        elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 6 then
            WorldRoad.setBiome(tonumber(key))
        end
    end

    love.mousepressed = function() end
    love.mousereleased = function() end
    love.mousemoved = function() end
    love.resize = function() end
end

-- ============================================================================
-- BG: folhear os candidatos de background do bioma 1 ao vivo (1-4 troca)
-- ============================================================================
local function runBgPreview()
    setupGame()
    WorldRoad.setBiome(1)
    WorldRoad._camZ = 6

    local OPTS = {
        { key = "opt1_snowpeaks",  label = "1  Snow Peaks (serra nevada, amanhecer)" },
        { key = "opt2_ruinhills",  label = "2  Ruin Hills (colinas + torres quebradas)" },
        { key = "opt3_mistforest", label = "3  Mist Forest (floresta em nevoa)" },
        { key = "opt4_autumnkeep", label = "4  Autumn Keep (outono + ruina)" },
    }
    -- carrega cada candidato recortado a 400x128 + um "front" transparente
    local dir = "assets/sprites/world/_bg_candidates/fields/"
    local transparentFront
    do
        local fd = love.image.newImageData(400, 128)  -- tudo alpha 0
        transparentFront = love.graphics.newImage(fd)
    end
    local imgs = {}
    for _, o in ipairs(OPTS) do
        local ok, raw = pcall(love.image.newImageData, dir .. o.key .. ".png")
        if ok and raw then
            local cw = math.min(400, raw:getWidth())
            local ch = math.min(128, raw:getHeight())
            local crop = love.image.newImageData(cw, ch)
            crop:paste(raw, 0, 0, 0, 0, cw, ch)
            local img = love.graphics.newImage(crop)
            img:setFilter("nearest", "nearest")
            imgs[o.key] = img
        end
    end

    local cur = 1
    local function apply(i)
        cur = i
        local o = OPTS[i]
        -- injeta no cache do WorldRoad (getSprite retorna o cacheado)
        WorldRoad._spriteCache["fields_mountains"] = imgs[o.key]
        WorldRoad._spriteCache["fields_mountains_front"] = transparentFront
    end
    apply(1)

    love.update = function(dt)
        WorldRoad.update(dt)
        EnemyRenderer.update(dt)
        -- reinjeta todo frame (barato) — algo interno pode recachear
        local o = OPTS[cur]
        WorldRoad._spriteCache["fields_mountains"] = imgs[o.key]
        WorldRoad._spriteCache["fields_mountains_front"] = transparentFront
    end

    love.draw = function()
        drawBattleFrame(true)
        local FontManager = require("src.ui.FontManager")
        love.graphics.setFont(FontManager.getFont(16))
        local label = OPTS[cur].label
        local fw = love.graphics.getFont():getWidth(label)
        love.graphics.setColor(0.08, 0.06, 0.05, 0.85)
        love.graphics.rectangle("fill",
            (love.graphics.getWidth() - fw) / 2 - 12, 92, fw + 24, 26, 7, 7)
        love.graphics.setColor(0.95, 0.85, 0.6, 1)
        love.graphics.print(label, (love.graphics.getWidth() - fw) / 2, 96)
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setFont(FontManager.getFont(12))
        love.graphics.print("1-4 troca background | T hora | ESC sair",
            12, love.graphics.getHeight() - 24)
        love.graphics.setColor(1, 1, 1, 1)
    end

    love.keypressed = function(key)
        if key == "escape" then love.event.quit()
        elseif key == "t" then
            local cur2 = WorldRoad._timeOfDayTarget or 1
            local nxt = cur2 >= 1 and 0 or (cur2 >= 0.5 and 1 or 0.5)
            WorldRoad.setTimeOfDay(nxt)
        elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= 4 then
            apply(tonumber(key))
        end
    end
    love.mousepressed = function() end
    love.mousereleased = function() end
    love.mousemoved = function() end
    love.resize = function() end
end

function M.run(mode)
    if mode == "tour" then
        runTour()
    elseif mode == "postgate" then
        runInteractive(true)   -- margem inteira em postes (validação ao vivo)
    elseif mode == "bg" then
        runBgPreview()         -- folhear candidatos de bg do bioma 1
    else
        runInteractive()
    end
end

return M
