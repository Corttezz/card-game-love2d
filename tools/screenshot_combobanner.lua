-- tools/screenshot_combobanner.lua
-- Valida o ComboBanner:  love . screenshot_combobanner
--
-- v2 (feedback do dono Set/2026): a versao 1 desenhava o banner ISOLADO
-- sobre o cenario, o que nao testava nada do que ele reclamou. Agora o tool
-- dirige o GameplayScene DE VERDADE — mesma ordem de painter do jogo — com
-- cartas na MAO e cartas VOANDO pro centro, que era exatamente quem estava
-- cobrindo o banner.
--
-- Saidas:
--   combobanner_impact.png    banner + cartas voando + mao (prova de z-order)
--   combobanner_impact_in.png meio da queima de entrada
--   combobanner_multi.png     3 combos no mesmo turno (banner unico)
--   combobanner_reduced.png   com reducedMotion (aparece igual, sem queima)
--   combobanner_small.png     janela estreita (zona aperta → conteudo cede)

local M = {}

local function shot(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name .. ".png")
        print("[screenshot] " .. name .. ".png salvo")
    end)
    love.graphics.present()
end

-- ---------------------------------------------------------------------------
-- Cena de gameplay real (mesmas deps que main.lua passa pro GameplayScene)
-- ---------------------------------------------------------------------------
local function buildScene()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()

    local Config = require("src.core.Config")
    local Theme  = require("src.ui.Theme")
    local Button = require("components.Button")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local SmokeSystem = require("src.systems.SmokeSystem")
    local GameplayScene = require("src.scenes.GameplayScene")
    local I18n = require("src.i18n.I18n")

    I18n.setLocale("pt_BR")   -- captura deterministica (o save pode estar noutro idioma)

    local game = TK.newRunGame("warrior")
    game.enemy.spriteId = "cursed_scarecrow"
    _G.game = game

    local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local bh = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local bx = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_X_RATIO,
        love.graphics.getWidth()) - bw / 2
    local by = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_Y_RATIO,
        love.graphics.getHeight()) - bh / 2

    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local smoke = SmokeSystem:new()

    GameplayScene.init({
        game = game,
        playButton = Button:new(bx, by, bw, bh,
            I18n.t("play_button.label"), function() end, Theme.Colors.SUCCESS, 18),
        endTurnButton = Button:new(bx, by + bh + 10, bw, math.floor(bh * 0.72),
            I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
        topBar = topBar,
        gameUI = gameUI,
        smokeSystem = smoke,
    })
    GameplayScene.setGame(game)

    -- deixa a estrada assentar (camera/vegetacao) antes de qualquer captura
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad._camZ = 6
    for _ = 1, 30 do
        _G.EventManager.update(1 / 30)
        GameplayScene.update(1 / 30)
    end

    return game, GameplayScene
end

-- Monta a mao com cartas que garantem o combo pedido e joga `nPlay` delas.
local function playCombo(game, ids, nPlay)
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    db:loadData()

    game.hand = {}
    for _, id in ipairs(ids) do
        local cd = db:getCard(id)
        if cd then table.insert(game.hand, db:createCardInstance(cd)) end
    end
    -- mana de sobra: o teste e visual, nao economico
    game.player.mana = 10
    game.player.maxMana = 10
    game.selectedCards = {}
    game.turn = "player"

    for i = 1, nPlay do
        local c = game.hand[i]
        if c then table.insert(game.selectedCards, c) end
    end
    game:playSelectedCards()
end

-- Um frame do jogo: o love.update do main tica o EventManager ANTES da
-- scene (o combate inteiro e diferido pra fila de eventos). Sem isso as
-- cartas nunca voam e o impacto — que e quem levanta o banner — nao chega.
local function frame(GameplayScene, dt)
    _G.EventManager.update(dt)
    GameplayScene.update(dt)
end

-- Espera a jogada anterior terminar: playSelectedCards e ignorado enquanto o
-- combatAnimationSystem estiver bloqueando (mesma guarda do jogo).
local function drain(GameplayScene, game)
    for _ = 1, 60 * 12 do
        if not game.combatAnimationSystem:isBlocking() then break end
        frame(GameplayScene, 1 / 60)
    end
    for _ = 1, 30 do frame(GameplayScene, 1 / 60) end
end

-- Avanca a cena ate o banner subir (ele sobe no IMPACTO, nao no clique),
-- e depois mais `extra` segundos. Retorna false se nunca subiu.
local function pumpUntilBanner(GameplayScene, extra)
    local ComboBanner = require("src.ui.ComboBanner")
    local dt = 1 / 60
    for _ = 1, 60 * 6 do
        frame(GameplayScene, dt)
        if ComboBanner.isActive() then break end
    end
    if not ComboBanner.isActive() then return false end
    for _ = 1, math.floor((extra or 0) * 60) do
        frame(GameplayScene, dt)
    end
    return true
end

function M.run()
    local game, GameplayScene = buildScene()
    local ComboBanner = require("src.ui.ComboBanner")

    -- 1 e 2. strike_combo (x1.4): 2 golpes jogados, 2 cartas ficam na mao
    local strikeHand = { "warrior_strike", "warrior_strike",
                         "warrior_defend", "warrior_strike" }
    playCombo(game, strikeHand, 2)
    if not pumpUntilBanner(GameplayScene, 0.10) then
        print("[ERRO] banner nao subiu no impacto — combo nao disparou?")
        love.event.quit(1)
        return
    end
    GameplayScene.draw()
    shot("combobanner_impact_in")

    for _ = 1, 18 do frame(GameplayScene, 1 / 60) end
    GameplayScene.draw()
    shot("combobanner_impact")

    -- 3. tres combos no mesmo turno: 3 golpes (strike_combo + triple_strike)
    --    + uma carta de lifesteal (lifesteal_burst)
    drain(GameplayScene, game)
    ComboBanner.clear()
    game._currentTurnContext = nil
    playCombo(game, { "warrior_strike", "warrior_strike", "warrior_strike",
                      "attack_002", "warrior_defend" }, 4)
    if pumpUntilBanner(GameplayScene, 0.45) then
        GameplayScene.draw()
        shot("combobanner_multi")
    else
        print("[AVISO] combo multiplo nao disparou")
    end

    -- 4. reducedMotion: mesma informacao, sem queima
    _G.gameSettings = _G.gameSettings or {}
    local prev = _G.gameSettings.reducedMotion
    _G.gameSettings.reducedMotion = true
    drain(GameplayScene, game)
    ComboBanner.clear()
    game._currentTurnContext = nil
    playCombo(game, strikeHand, 2)
    if pumpUntilBanner(GameplayScene, 0.40) then
        GameplayScene.draw()
        shot("combobanner_reduced")
    end
    _G.gameSettings.reducedMotion = prev

    -- 5. ZONA APERTADA: janela baixa (o conteudo cede, a banda nao).
    --    Falsifica a janela em vez de setMode — padrao de
    --    memory/ui_layout_invariants.md (setMode repetido em tool nao retorna).
    local realH = love.graphics.getHeight
    love.graphics.getHeight = function() return 520 end
    require("src.ui.FontManager").clearCache()
    drain(GameplayScene, game)
    ComboBanner.clear()
    game._currentTurnContext = nil
    playCombo(game, { "warrior_strike", "warrior_strike", "warrior_strike",
                      "attack_002", "warrior_defend" }, 4)
    if pumpUntilBanner(GameplayScene, 0.45) then
        GameplayScene.draw()
        shot("combobanner_small")
    end
    love.graphics.getHeight = realH
    require("src.ui.FontManager").clearCache()

    love.event.quit()
end

return M
