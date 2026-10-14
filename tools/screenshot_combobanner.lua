local M = {}

local function shot(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name .. ".png")
        print("[screenshot] " .. name .. ".png salvo")
    end)
    love.graphics.present()
end

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

    I18n.setLocale("pt_BR")

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

    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad._camZ = 6
    for _ = 1, 30 do
        _G.EventManager.update(1 / 30)
        GameplayScene.update(1 / 30)
    end

    return game, GameplayScene
end

local function playCombo(game, ids, nPlay)
    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    db:loadData()

    game.hand = {}
    for _, id in ipairs(ids) do
        local cd = db:getCard(id)
        if cd then table.insert(game.hand, db:createCardInstance(cd)) end
    end
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

local function frame(GameplayScene, dt)
    _G.EventManager.update(dt)
    GameplayScene.update(dt)
end

local function drain(GameplayScene, game)
    for _ = 1, 60 * 12 do
        if not game.combatAnimationSystem:isBlocking() then break end
        frame(GameplayScene, 1 / 60)
    end
    for _ = 1, 30 do frame(GameplayScene, 1 / 60) end
end

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
