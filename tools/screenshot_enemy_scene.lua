-- tools/screenshot_enemy_scene.lua
-- Captura o CENÁRIO DE COMBATE real (GameplayScene.draw) pra um node
-- específico: prova em que cena cada tipo de encontro acontece e onde o pé
-- do inimigo pousa.
--
--   love . screenshot_enemy_scene <ato>_<nodeType>
--   love . screenshot_enemy_scene 2_elite      → elite do ato 2 (estrada)
--   love . screenshot_enemy_scene 2_boss       → chefe do ato 2 (hall)
--   love . screenshot_enemy_scene 1_boss
--   love . screenshot_enemy_scene 6_battle     → dusk_shade (flutuante)
--
-- ENEMY_SCENE_ID=<id> força o sprite (vale pra arte nova fora do roster).
-- ENEMY_SCENE_INTENT="kind=multi,perHit=5,hits=3" força o intent do HUD.
-- Sufixo "_hud" desenha a cena SEM o HUD/mão (default inclui tudo, que é o
-- que o jogador vê). Saída: enemy_scene_<modo>.png no save dir.
--
-- Por que existe: `screenshot_worldroad interior` só sabia desenhar o hall
-- com um inimigo colado no meio da tela — não passava pelo `GameplayScene`
-- e por isso não provava NADA sobre qual cena o jogo escolhe. Este tool
-- roda o caminho real.

local M = {}

function M.run(mode)
    mode = mode or "2_boss"
    local act = tonumber(mode:match("^(%d+)")) or 1
    local nodeType = mode:match("^%d+_(%a[%a_]*)") or "boss"

    -- ENEMY_SCENE_VIRTUAL=2560x1440: tela FALSIFICADA maior que o monitor
    -- (setMode acima do desktop trava — mesmo truque do boss_rooms). Desenha
    -- num canvas desse tamanho com getWidth/getHeight mentindo.
    local vw, vh = (os.getenv("ENEMY_SCENE_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
    local vcanvas
    if vw then
        vw, vh = tonumber(vw), tonumber(vh)
        vcanvas = love.graphics.newCanvas(vw, vh)
        love.graphics.getWidth = function() return vw end
        love.graphics.getHeight = function() return vh end
        love.graphics.getDimensions = function() return vw, vh end
    end

    local I18n = require("src.i18n.I18n")
    I18n.init()
    if os.getenv("TUT_LOCALE") then I18n.setLocale(os.getenv("TUT_LOCALE"), true) end
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")

    local game = Game:new()
    game:startNewRun(os.getenv("ENEMY_SCENE_CLASS") or "warrior")
    game:startGame()

    -- Força o node/ato pedidos (o mapa normalmente decide isto).
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = (nodeType == "boss") and 8 or 3
    run.currentNode = { type = nodeType }
    -- ENEMY_SCENE_ID=<id>: força o sprite (arte nova ainda fora do roster)
    local forcedId = os.getenv("ENEMY_SCENE_ID")
    if forcedId and forcedId ~= "" then mode = mode .. "_" .. forcedId end
    game.enemy.spriteId = (forcedId and forcedId ~= "") and forcedId
        or EnemyRenderer.resolveSpriteId(act, nodeType)
    game.enemy.isBoss = (nodeType == "boss")


    -- KIT DO INIMIGO (Out/2026): monta o inimigo pelo roster (kit + stats do
    -- ato) e, com ENEMY_SCENE_MOVE=<id do golpe>, anuncia aquele golpe — é o
    -- que prova na tela o intent novo (multi-golpe, debuff, perfurante...).
    -- ENEMY_SCENE_DEBUFFS=weak,frail,poison põe debuffs no jogador (pills).
    -- ENEMY_SCENE_HOVER=1 posiciona o mouse no intent (tooltip do golpe).
    do
        local EnemyRoster = require("src.systems.EnemyRoster")
        local ActSystem = require("src.systems.ActSystem")
        local Enemy = require("src.entities.Enemy")
        local stats = ActSystem.getEnemyStats(act, run.floorInAct, nodeType)
        local sid = game.enemy.spriteId
        game.enemy = EnemyRoster.spawn(Enemy, sid, stats)
        game.enemy.isBoss = (nodeType == "boss")
        local mv = os.getenv("ENEMY_SCENE_MOVE")
        if mv and mv ~= "" then
            game.enemy:forceIntent(mv, game.player)
            mode = mode .. "_" .. mv
        end
        for name in (os.getenv("ENEMY_SCENE_DEBUFFS") or ""):gmatch("[^,]+") do
            game.player:addDebuff(name, 2, (name == "poison" or name == "burn") and 4 or 1)
        end
        -- ENEMY_SCENE_VISIBILITY=full|type_only|hidden[:veil]: NÉVOA DE
        -- INTENÇÃO (src/systems/IntentVisibility). Dá ao inimigo o contexto
        -- do bioma (como RunModifiers.decorateEnemy faria) e força o nível —
        -- a captura prova o box com "?", o véu correndo e a nevasca
        -- engrossando pelo hook do WeatherEngine (o loop de update abaixo
        -- deixa o clima perseguir o alvo). ":veil" marca a causa como véu
        -- da criatura (tooltip cita o nome dela).
        local vis = os.getenv("ENEMY_SCENE_VISIBILITY")
        if vis and vis ~= "" then
            local IV = require("src.systems.IntentVisibility")
            local level, cause = vis:match("^([%a_]+):?(%a*)$")
            game.enemy.fogContext = IV.contextFor(run)
            game.enemy.intentVisibility = level
            game.enemy.intentVeilCause = (cause == "veil") and "veil" or "fog"
            IV.noteActive(game.enemy)
            mode = mode .. "_vis_" .. level .. ((cause == "veil") and "_veil" or "")
        end
    end

    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local width, height = love.graphics.getDimensions()
    local playButton = Button:new(width * 0.80, height * 0.80, 150, 46, "Jogar")

    GameplayScene.init({
        game = game, topBar = topBar, gameUI = gameUI,
        playButton = playButton,
    })

    -- BOSS: o jogo só mostra o interior DEPOIS da cutscene da porta. O tool
    -- pula a cerimônia (é o estado de combate que interessa aqui).
    if nodeType == "boss" then GameplayScene._debugForceBossEntered() end

    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(nodeType == "boss" and 1 or 0.75, true)
    for _ = 1, 90 do
        WorldRoad.update(1 / 30)
        EnemyRenderer.update(1 / 30)
        local IFX = require("src.ui.InteriorFX"); IFX.update(1 / 30, IFX.hallFor(act))
    end
    if os.getenv("ENEMY_SCENE_VISIBILITY") then
        -- prova numérica do hook: a nevasca engrossou junto com a névoa?
        local WE = require("engine.WeatherEngine")
        print(string.format("[screenshot] clima: intensidade=%.2f (boost da névoa=%.2f) partículas=%d",
            WE.intensity(), WE.veilBoost(), WE.count()))
    end

    -- Layout real do cluster do intent, capturado do próprio draw.
    local EnemyHud = require("src.ui.EnemyHud")
    local lastL
    local origLayout = EnemyHud.layout
    EnemyHud.layout = function(...)
        local L = origLayout(...)
        lastL = L
        return L
    end
    -- ENEMY_SCENE_INTENT="kind=multi,perHit=5,hits=3,pierce=1,debuff=frail":
    -- força o intent mostrado no HUD (validação dos ícones de intent).
    local intentSpec = os.getenv("ENEMY_SCENE_INTENT")
    if intentSpec and intentSpec ~= "" then
        local it = { perHit = 0, hits = 0, armor = 0, strength = 0, heal = 0,
            summon = 0, debuffs = {} }
        for k, v in intentSpec:gmatch("(%w+)=([%w_]+)") do
            if k == "debuff" then
                it.debuffs[#it.debuffs + 1] = { name = v, stacks = 2, duration = 2 }
            elseif k == "kind" then it.kind = v
            elseif k == "pierce" or k == "charge" then it[k] = (v == "1")
            else it[k] = tonumber(v) or v end
        end
        it.id = it.id or it.kind
        it.raw = it.perHit
        mode = mode .. "_intent_" .. it.kind .. ((it.pierce and "_pierce") or "")
        game.enemy.intent = it
        game.enemy.nextIntent = it.kind
        game.enemy.nextIntentDamage = it.raw
    end

    -- ENEMY_SCENE_PLAYER_DEBUFFS="weak,frail,vulnerable": debuffs no jogador
    -- (pills do HUD dele) — validação dos ícones de status do lado do herói.
    local pdeb = os.getenv("ENEMY_SCENE_PLAYER_DEBUFFS")
    if pdeb and pdeb ~= "" and game.player.addDebuff then
        for name in pdeb:gmatch("[%w_]+") do game.player:addDebuff(name, 2, 2) end
    end

    -- ENEMY_SCENE_WORLD_ONLY=1: só mundo + inimigo, sem HUD (arte de loja).
    -- ENEMY_SCENE_TOD=0..1: hora do dia (0 = dia, 1 = anoitecer).
    if os.getenv("ENEMY_SCENE_WORLD_ONLY") == "1" then
        GameplayScene.WORLD_ONLY = true
        mode = mode .. "_world"
    end
    local tod = tonumber(os.getenv("ENEMY_SCENE_TOD") or "")
    if tod then
        WorldRoad.setTimeOfDay(tod, true)
        for _ = 1, 30 do WorldRoad.update(1 / 30); EnemyRenderer.update(1 / 30) end
    end

    -- ENEMY_SCENE_CLEAN=1: sem os toasts de início de run ("Jogo
    -- iniciado!", ouro inicial) — quadro limpo pra screenshot de loja.
    if os.getenv("ENEMY_SCENE_CLEAN") == "1" and game.messageSystem then
        game.messageSystem.messages = {}
    end

    -- TUT_SELECT=1: uma carta selecionada (a prévia de dano aparece)
    if os.getenv("TUT_SELECT") then
        game.selectedCards = { game.hand[1] }
        if game.hand[1] then game.hand[1].isSelected = true end
        -- a prévia só existe depois do update dela (o jogo roda isto todo quadro)
        require("src.ui.DamagePreviewPanel").update(game, nil, 1)
    end
    if vcanvas then love.graphics.setCanvas(vcanvas) end
    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()
    -- TUT_TIP=<conversa>[:<fala>]: o narrador do tutorial por cima (as
    -- âncoras acabaram de ser reportadas por este draw). TUT_LOCALE troca o
    -- idioma.
    if os.getenv("TUT_TIP") then
        local Tutorial = require("src.systems.Tutorial")
        local conv, line = os.getenv("TUT_TIP"):match("^([%w_]+):?([%w_]*)$")
        Tutorial._show(conv, line ~= "" and line or nil, game)
        Tutorial.draw()
        mode = mode .. "_tut_" .. conv .. "_" .. (line or "") .. "_" .. (os.getenv("TUT_LOCALE") or "pt_BR")
            .. "_" .. love.graphics.getWidth() .. "x" .. love.graphics.getHeight()
    end
    -- Tooltip do golpe: 2ª passada com o mouse em cima do intent (a 1ª
    -- passada calcula o layout real do cluster).
    if os.getenv("ENEMY_SCENE_HOVER") == "1" then
        local L = lastL
        if L and L.iw > 0 then
            local hx = math.floor(L.cx - L.totalW / 2 + L.iw / 2)
            local hy = math.floor(L.rowY + L.rowH / 2)
            love.mouse.getPosition = function() return hx, hy end
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
            -- o tooltip é desenhado pelo main.lua no fim do frame
            -- (relógio adiantado: o pop-in do tooltip já assentou)
            local ST = require("src.ui.StatusTooltip")
            local realTime = love.timer.getTime
            love.timer.getTime = function() return realTime() + 2 end
            if ST.draw then ST.draw() end
            love.timer.getTime = realTime
        end
    end
    if vcanvas then
        love.graphics.setCanvas()
        local path = "enemy_scene_" .. mode .. "_" .. vw .. "x" .. vh .. ".png"
        vcanvas:newImageData():encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
        return
    end

    love.graphics.captureScreenshot(function(imageData)
        local path = "enemy_scene_" .. mode .. ".png"
        imageData:encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
