-- tools/screenshot_damage_preview.lua
-- Valida a PREVIA DE DANO na batalha real (GameplayScene, mesma ordem de
-- painter do jogo), com 2..5 cartas SELECIONADAS e uma carta em hover.
--
--   CARDGAME_IDENTITY=x PREVIEW_W=1920 PREVIEW_H=1080 PREVIEW_LOCALE=de \
--     love . test_one screenshot_damage_preview
--
-- Saidas (save dir), prefixo dmgprev_<W>x<H>_<locale>_:
--   sel2.png      2 golpes (combo de ataques) + hover numa 3a carta
--   sel3.png      3 cartas: golpes + defesa (ataque e bloqueio juntos)
--   sel5.png      5 cartas com coringa, Forca e armadura no inimigo (RESUMO)
--   sel5_details.png  a mesma leva com DETALHES (clique na placa / tecla V)
--   combo_tooltip.png  hover numa ficha de combo da placa (o que ele faz)
--   lethal.png    leva que mata (rotulo LETAL)
--   resolving.png no meio da resolucao (total correndo + combo)

local M = {}

-- Sem janela (CARDGAME_HEADLESS=1, dono jogando): PREVIEW_W/H viram uma
-- tela FALSIFICADA — canvas desse tamanho com getWidth/getHeight mentindo
-- (mesmo truque de screenshot_enemy_scene) e o PNG sai do canvas.
local vcanvas

local function shot(name)
    if vcanvas then
        love.graphics.setCanvas()
        vcanvas:newImageData():encode("png", name .. ".png")
        print("[screenshot] " .. name .. ".png salvo")
        return
    end
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name .. ".png")
        print("[screenshot] " .. name .. ".png salvo")
    end)
    love.graphics.present()
end

local function buildScene(locale)
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

    I18n.setLocale(locale or "pt_BR")

    TK.seedRng(777)
    local game = TK.newRunGame("warrior")
    game.enemy.spriteId = "cursed_scarecrow"
    _G.game = game

    local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local bh = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({
        game = game,
        playButton = Button:new(0, 0, bw, bh,
            I18n.t("play_button.label"), function() end, Theme.Colors.SUCCESS, 18),
        endTurnButton = Button:new(0, 0, bw, math.floor(bh * 0.72),
            I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
        topBar = topBar,
        gameUI = GameUI:new(),
        smokeSystem = SmokeSystem:new(),
    })
    GameplayScene.setGame(game)
    if GameplayScene.updatePlayButtonPosition then GameplayScene.updatePlayButtonPosition() end

    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad._camZ = 6
    for _ = 1, 40 do
        _G.EventManager.update(1 / 30)
        GameplayScene.update(1 / 30)
    end
    return game, GameplayScene
end

local function frame(GameplayScene, dt)
    _G.EventManager.update(dt)
    GameplayScene.update(dt)
end

local function settle(GameplayScene, secs)
    for _ = 1, math.floor((secs or 0.5) * 60) do frame(GameplayScene, 1 / 60) end
end

-- Mao com estas cartas; seleciona as `nSel` primeiras pelo caminho do jogo.
local function setupHand(game, ids, nSel, keepHp)
    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    game.hand = {}
    for _, id in ipairs(ids) do
        local cd = db:getCard(id)
        if cd then game.hand[#game.hand + 1] = db:createCardInstance(cd) end
    end
    game.player.mana, game.player.maxMana = 10, 10
    game.enemy.maxHealth = math.max(game.enemy.maxHealth, 120)
    if not keepHp then game.enemy.health = game.enemy.maxHealth end
    game.selectedCards = {}
    game.turn = "player"
    for i = 1, nSel do game:selectCard(game.hand[i]) end
end

-- Sem janela, love.mouse.setPosition nao alcanca nada (janela 1x1 fora da
-- tela): o mouse vira um ponto FALSO injetado no portao do InputFocus — e o
-- que todo hover do jogo le (love.mouse.getPosition).
local fakeMouse
local function mouseTo(x, y)
    if fakeMouse then fakeMouse.x, fakeMouse.y = x, y else love.mouse.setPosition(x, y) end
end

local function hoverOn(GameplayScene, card)
    -- move o mouse pro centro da carta em repouso
    local x = (card.layoutX or card.x or 0) + 64
    local y = (card.layoutY or card.y or 0) + 60
    mouseTo(x, y)
    if GameplayScene.mousemoved then GameplayScene.mousemoved(x, y, 0, 0) end
end

function M.run()
    local W, H = tonumber(os.getenv("PREVIEW_W")), tonumber(os.getenv("PREVIEW_H"))
    if W and H then
        if os.getenv("CARDGAME_HEADLESS") == "1" then
            vcanvas = love.graphics.newCanvas(W, H)
            fakeMouse = { x = 5, y = 5 }
            require("src.ui.InputFocus").installMouseGate(nil, function() return fakeMouse.x, fakeMouse.y end)
            love.graphics.getWidth = function() return W end
            love.graphics.getHeight = function() return H end
            love.graphics.getDimensions = function() return W, H end
        else
            love.window.setMode(W, H, { resizable = true })
        end
    end
    W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local locale = os.getenv("PREVIEW_LOCALE") or "pt_BR"
    local prefix = string.format("dmgprev_%dx%d_%s_", W, H, locale)

    local game, GS = buildScene(locale)
    local db = require("src.systems.CardDatabase"):new()
    db:loadData()

    local function capture(name)
        if vcanvas then love.graphics.setCanvas(vcanvas) end
        love.graphics.clear(0, 0, 0, 1)
        GS.draw()
        require("src.ui.StatusTooltip").draw()   -- o main desenha no fim do quadro
        shot(prefix .. name)
    end

    -- 1. dois golpes (combo) + hover num terceiro
    setupHand(game, { "warrior_strike", "warrior_strike", "warrior_bash",
        "warrior_defend", "warrior_quick_strike" }, 2)
    settle(GS, 0.6)
    hoverOn(GS, game.hand[3])
    settle(GS, 0.4)
    capture("sel2")

    -- 2. golpes + defesa
    mouseTo(5, 5); GS.mousemoved(5, 5, 0, 0)
    setupHand(game, { "warrior_strike", "warrior_defend", "warrior_shield_slam",
        "warrior_strike", "warrior_iron_wave" }, 3)
    settle(GS, 0.6)
    capture("sel3")

    -- 3. cinco cartas, coringa multiplicador, Forca e Bloqueio no inimigo
    game.player.strength = 2
    game.enemy.armor = 8
    game.jokerSlots = { db:createCardInstance(db:getCard("joker_001")) }
    setupHand(game, { "warrior_strike", "warrior_twin_strike", "warrior_bash",
        "warrior_heavy_blade", "warrior_defend", "warrior_quick_strike" }, 5)
    settle(GS, 0.6)
    -- RESUMO (default) e DETALHES (clique na placa / V) da MESMA leva
    -- (detalhes primeiro: o lastRect que o hover abaixo mira e o do RESUMO)
    local Panel = require("src.ui.DamagePreviewPanel")
    Panel.setDetails(true)
    capture("sel5_details")
    Panel.setDetails(false)
    settle(GS, 0.1)
    capture("sel5")

    -- 3b. hover numa FICHA de combo da placa (resumo): tooltip com o que ele faz
    local PR = Panel.lastRect
    if PR then
        local fy = PR.firstRowY + 6
        local fx = PR.x + 14
        -- a 1a linha pode ser LETAL; desce uma linha se for o caso
        mouseTo(fx, fy)
        GS.mousemoved(fx, fy, 0, 0)
        settle(GS, 0.3)
        -- o tooltip tem pop-in por TEMPO REAL: agenda um quadro e espera
        for _ = 1, 3 do
            GS.draw(); require("src.ui.StatusTooltip").draw()
            love.timer.sleep(0.08)
        end
        capture("combo_tooltip")
        mouseTo(5, 5); GS.mousemoved(5, 5, 0, 0)
    end

    -- 4. leva letal
    game.enemy.armor = 0
    game.enemy.health = 18
    setupHand(game, { "warrior_strike", "warrior_heavy_blade", "warrior_defend",
        "warrior_strike" }, 2, true)
    settle(GS, 0.6)
    capture("lethal")

    -- 4b. mago: orbes canalizando/evocando e cartas magicas (extras do painel)
    game.selectedClass = "mage"
    game.player.strength = 0
    game.jokerSlots = {}
    game.player.orbs = { { type = "lightning", value = 4 }, { type = "dark", value = 5 } }
    setupHand(game, { "mage_zap", "mage_twin_bolts", "mage_dualcast",
        "mage_mind_spike", "mage_magic_barrier" }, 4)
    settle(GS, 0.6)
    capture("mage")
    game.selectedClass = "warrior"
    game.player.orbs = {}

    -- 5. no meio da resolucao
    game.enemy.health = game.enemy.maxHealth
    setupHand(game, { "warrior_strike", "warrior_twin_strike", "warrior_bash",
        "warrior_defend" }, 3)
    settle(GS, 0.3)
    game:playSelectedCards()
    for _ = 1, 60 * 6 do
        frame(GS, 1 / 60)
        local seq = game.combatAnimationSystem
        if game.enemy.health < game.enemy.maxHealth - 6 then break end
        if not (seq and seq:isBlocking()) then break end
    end
    settle(GS, 0.25)
    capture("resolving")
    return true
end

return M
