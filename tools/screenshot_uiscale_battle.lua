-- tools/screenshot_uiscale_battle.lua
-- A BATALHA com a escala de UI (src/ui/UiScale.lua): mão, carta em hover com
-- descrição ao lado, prévia de dano, intent/pills do inimigo, orbes, toast e
-- TopBar — em 5 tamanhos, janela FALSIFICADA + canvas (sem setMode).
--
--   love . test_one screenshot_uiscale_battle          → pt_BR
--   love . test_one screenshot_uiscale_battle de       → outro idioma
--
-- Saída: uiscale_battle_<cena>_<W>x<H>_<loc>.png
--   warrior  2 cartas selecionadas + hover numa 3ª + toast
--   mage     orbes canalizados + 3 selecionadas
--   boss     salão do chefe do ato 2 (laje baixa) + hover

local M = {}

local SIZES = {
    { 1024, 768 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 3840, 2160 },
    { 1280, 800, deck = true },   -- Steam Deck: Auto em 125% (UiScale deviceMul)
}
-- DECK=1 no ambiente: só o tamanho do Steam Deck
if os.getenv("DECK") == "1" then SIZES = { { 1280, 800, deck = true } } end

function M.run(locale)
    locale = locale or "pt_BR"
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local UiScale = require("src.ui.UiScale")
    local FontManager = require("src.ui.FontManager")
    local Config = require("src.core.Config")
    local Theme  = require("src.ui.Theme")
    local Button = require("components.Button")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local I18n = require("src.i18n.I18n")
    I18n.setLocale(locale)

    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    local realMouse = love.mouse.getPosition
    local W, H = 1024, 768
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
    local mx, my = 5, 5
    love.mouse.getPosition = function() return mx, my end

    TK.seedRng(777)
    local game = TK.newRunGame("warrior")
    UiScale.force(nil)   -- o testkit congela em 1; aqui queremos a escala real
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    local function initScene()
        local bw = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
        local bh = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
        GameplayScene.init({
            game = game,
            playButton = Button:new(0, 0, bw, bh,
                I18n.t("play_button.label"), function() end, Theme.Colors.SUCCESS, 18),
            endTurnButton = Button:new(0, 0, bw, math.floor(bh * 0.72),
                I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
            topBar = topBar,
            gameUI = GameUI:new(),
        })
        GameplayScene.setGame(game)
    end

    local db = require("src.systems.CardDatabase"):new()
    db:loadData()
    local function setupHand(ids, nSel)
        game.hand = {}
        for _, id in ipairs(ids) do
            local cd = db:getCard(id)
            if cd then game.hand[#game.hand + 1] = db:createCardInstance(cd) end
        end
        game.player.mana, game.player.maxMana = 10, 10
        game.enemy.maxHealth = math.max(game.enemy.maxHealth, 120)
        game.enemy.health = game.enemy.maxHealth
        game.selectedCards = {}
        game.turn = "player"
        for i = 1, nSel do game:selectCard(game.hand[i]) end
    end
    local function frames(n)
        for _ = 1, n do
            UiScale.begin(); _G.EventManager.update(1 / 30); UiScale.finish()
            GameplayScene.update(1 / 30)
            if game.messageSystem then game.messageSystem:update(0) end
        end
    end
    local function hover(idx)
        local c = game.hand[idx]
        local k = UiScale.k()
        mx, my = ((c.layoutX or 0) + 60) * k, ((c.layoutY or 0) + 60) * k
    end
    -- mede o inimigo (bbox em pixels da tela) pra tabela de proporção
    local realERDraw = EnemyRenderer.draw
    local lastBbox
    EnemyRenderer.draw = function(...)
        local b = realERDraw(...)
        lastBbox = b
        return b
    end
    local function capture(name)
        lastBbox = nil
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas({ cv, stencil = true })
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        require("src.ui.StatusTooltip").draw()
        UiScale.begin()
        require("src.ui.FloatingText").draw()
        UiScale.finish()
        love.graphics.setCanvas()
        local file = ("uiscale_battle_%s_%dx%d%s_%s.png"):format(name, W, H,
            UiScale.deviceMultiplier() ~= 1 and "deck" or "", locale)
        cv:newImageData():encode("png", file)
        local pct = lastBbox and (lastBbox.bottomY - lastBbox.topY) / H * 100 or -1
        print(("[uiscale_battle] %s  k=%.2f  inimigo=%.1f%% da altura"):format(file, UiScale.k(), pct))
    end
    local function scene(act, nodeType)
        local run = game.runManager.currentRun
        run.actNumber, run.floorInAct = act, (nodeType == "boss") and 8 or 3
        run.currentNode = { type = nodeType }
        game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, nodeType)
        game.enemy.isBoss = nodeType == "boss"
        GameplayScene.resetTurnState()
        if nodeType == "boss" then GameplayScene._debugForceBossEntered() end
        WorldRoad.setBiome(act)
    end

    local ok, err = pcall(function()
        for _, sz in ipairs(SIZES) do
            W, H = sz[1], sz[2]
            UiScale.setDeviceMultiplier(sz.deck and 1.25 or 1)
            FontManager.clearCache()
            WorldRoad.clearCache()
            initScene()

            -- guerreiro: seleção + hover + toast
            game.selectedClass = "warrior"
            game.player.orbs = {}
            scene(1, "battle")
            setupHand({ "warrior_strike", "warrior_strike", "warrior_bash",
                "warrior_defend", "warrior_quick_strike", "warrior_iron_wave" }, 2)
            mx, my = 5, 5
            frames(25)
            GameplayScene.draw()   -- o hover mede o retângulo do último desenho
            hover(3)
            frames(12)
            if game.messageSystem then
                game.messageSystem.messages = {}
                game:addMessage(I18n.t("messages.armor_capped", { max = 30, wasted = 4 }, "!"), "warning")
                game.messageSystem:update(0.3)   -- entrada assentada
            end
            capture("warrior")

            -- mago: orbes
            game.selectedClass = "mage"
            game.player.orbs = { { type = "lightning", value = 4 }, { type = "dark", value = 5 } }
            setupHand({ "mage_zap", "mage_twin_bolts", "mage_dualcast",
                "mage_mind_spike", "mage_magic_barrier" }, 3)
            mx, my = 5, 5
            frames(20)
            capture("mage")

            -- chefe no salão (ato 2: laje baixa — o caso apertado do palco)
            game.selectedClass = "warrior"
            game.player.orbs = {}
            scene(2, "boss")
            setupHand({ "warrior_strike", "warrior_bash", "warrior_defend",
                "warrior_iron_wave", "warrior_quick_strike" }, 0)
            mx, my = 5, 5
            frames(20)
            GameplayScene.draw()
            hover(3)
            frames(12)
            capture("boss")
        end
    end)
    if not ok then print("[uiscale_battle] FALHOU: " .. tostring(err)) end
    EnemyRenderer.draw = realERDraw
    UiScale.setDeviceMultiplier(1)
    UiScale.reset()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    love.mouse.getPosition = realMouse
    UiScale.force(1)
    return ok
end

return M
