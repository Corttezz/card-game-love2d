local M = {}

local Game             = require("src.core.Game")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local FlashShader      = require("src.ui.FlashShader")
local BoosterShader    = require("src.ui.BoosterShader")
local FoilShader       = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local RoundEvalScreen  = require("components.RoundEvalScreen")
local I18n             = require("src.i18n.I18n")

local PHASE_TIMES = { [0] = 0.6, [1] = 1.2, [2] = 2.6, [3] = 5.0 }

function M.run(phase, locale)
    phase = tonumber(phase or 3) or 3
    local targetT = PHASE_TIMES[phase] or 3.6

    I18n.init()
    if locale then I18n.setLocale(locale) end
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()
    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()
    FoilShader.load()
    PolychromeShader.load()
    ScreenShake.install()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    if game.economySystem then
        game.economySystem.currentGold = 25
    end

    if os.getenv("ROUND_NODE") then
        game.runManager.currentRun.currentNode = { type = os.getenv("ROUND_NODE") }
    end
    local sources = game:_buildRoundEvalSources()

    local screen = RoundEvalScreen:new()
    game.scoreSystem.lastBattle = {
        tinta = 240, selo = 2.3, total = 552,
        turns = 3, combos = 2, flawless = true, lowHp = false,
        breakdown = {
            { label = I18n.t("score.enemy_defeated"),
              value = I18n.t("score.pts", { n = 240 }) },
            { label = I18n.t("score.fast_win", { n = 3 }),    value = "+30%" },
            { label = I18n.t("score.card_combos", { n = 2 }), value = "+50%" },
            { label = I18n.t("score.flawless"),               value = "+100%" },
        },
    }
    screen:show(game, sources, function() end)

    local stepDt = 1/60
    local elapsed = 0
    while elapsed < targetT do
        EventManager.update(stepDt)
        FloatingText.update(stepDt)
        FlashShader.update(stepDt)
        ScreenShake.update(stepDt)
        CardParticles.update(stepDt)
        screen:update(stepDt)
        elapsed = elapsed + stepDt
    end

    love.graphics.clear(0.05, 0.04, 0.08, 1)
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0.20, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    screen:draw()
    CardParticles.draw()
    FloatingText.draw()
    FlashShader.draw()

    love.graphics.captureScreenshot(function(imageData)
        local path = string.format("round_eval_phase_%d_t%.2f%s.png", phase, targetT,
            (locale and locale ~= "pt_BR") and ("_" .. locale) or "")
        imageData:encode("png", path)
        print("[screenshot_round_eval] " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
