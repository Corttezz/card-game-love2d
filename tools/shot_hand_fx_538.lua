local M = {}

local W, H = 1600, 900

local function patchDims()
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
end

local function buildScene()
    local TK = require("tools.testkit")
    TK.bootstrap()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local Config = require("src.core.Config")
    local Theme = require("src.ui.Theme")
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
    local bx = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_X_RATIO, W) - bw / 2
    local by = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_Y_RATIO, H) - bh / 2
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({
        game = game,
        playButton = Button:new(bx, by, bw, bh, I18n.t("play_button.label"), function() end,
            Theme.Colors.SUCCESS, 18),
        endTurnButton = Button:new(bx, by + bh + 10, bw, math.floor(bh * 0.72),
            I18n.t("play_button.end_turn"), function() end, Theme.Colors.WARNING, 14),
        topBar = topBar,
        gameUI = GameUI:new(),
        smokeSystem = SmokeSystem:new(),
    })
    GameplayScene.setGame(game)
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.clearCache()
    WorldRoad._camZ = 6
    return game, GameplayScene
end

function M.run()
    patchDims()
    local game, Scene = buildScene()
    local EffectFeedback = require("src.systems.EffectFeedback")
    local cv = love.graphics.newCanvas(W, H)
    local dir = "fx538"
    love.filesystem.createDirectory(dir)

    local function frames(n)
        for _ = 1, n do
            _G.EventManager.update(1 / 60)
            Scene.update(1 / 60)
        end
    end
    local function shoot(name)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        Scene.draw()
        love.graphics.setCanvas()
        local d = cv:newImageData()
        d:encode("png", dir .. "/" .. name .. ".png")
        d:release()
    end
    local function sequence(name, trigger, at)
        trigger()
        local done = 0
        for i, f in ipairs(at) do
            frames(f - done)
            done = f
            shoot(("%s_%d"):format(name, i))
        end
        frames(90)
    end

    frames(120)
    shoot("00_mao")
    sequence("01_descartar", function()
        game.effectSystem:processEffectCard(game, { type = "discard_cards", value = 2 })
    end, { 8, 20, 32 })
    sequence("02_reter", function()
        if game.hand[1] then game.hand[1].retain = true end
        game:discardHandEndOfTurn()
    end, { 12, 30, 50 })
    for _ = 1, 4 do game:drawCard(0) end
    frames(60)
    sequence("03_inata", function()
        local c = game.hand[#game.hand]
        if c then
            c._fxInnate = true
            EffectFeedback.onCardArrives(c, 1)
        end
    end, { 10, 24, 40 })
    sequence("04_embaralhar", function() EffectFeedback.reshuffle(game, 12) end, { 10, 22, 36 })
    sequence("05_mana", function()
        game.player.mana = 0
        game.effectSystem:processEffectCard(game, { type = "restore_mana", value = 2 })
        game.effectSystem:processEffectCard(game, { type = "increase_max_mana", value = 1 })
    end, { 8, 24 })
    sequence("06_pacto", function()
        game.effectSystem:processEffectCard(game, { type = "self_damage", value = 4 })
        game.effectSystem:processEffectCard(game, { type = "add_armor", value = 6 })
    end, { 8, 24 })
    sequence("07_buff_revelar", function()
        game.effectSystem:processEffectCard(game, { type = "apply_buff", value = "thorn", stacks = 2 })
        EffectFeedback.reveal()
    end, { 8, 20 })

    cv:release()
    print("[shot] " .. love.filesystem.getSaveDirectory() .. "/" .. dir)
    love.event.quit()
end

return M
