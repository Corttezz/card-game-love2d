-- tools/screenshot_round_eval.lua
-- Captura screenshot da RoundEvalScreen (cash out estilo Balatro).
-- Roda: love . screenshot_round_eval [phase]
-- phase: 0..3 — diferentes momentos da timeline.
--   0 = slide-in (0.4s)
--   1 = primeira coin saiu (1.0s)
--   2 = todas coins (2.5s)
--   3 = botão Resgatar pronto (3.5s)
-- Saída: ~/.local/share/love/card-game/round_eval_phase_<n>.png

local M = {}

local Game             = require("src.core.Game")
local CRTShader        = require("src.ui.CRTShader")
local DissolveShader   = require("src.ui.DissolveShader")
local FlashShader      = require("src.ui.FlashShader")
local BoosterShader    = require("src.ui.BoosterShader")
local FoilShader       = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local NegativeShader   = require("src.ui.NegativeShader")
local ScreenShake      = require("src.systems.ScreenShake")
local EventManager     = require("engine.EventManager")
local FloatingText     = require("src.ui.FloatingText")
local CardParticles    = require("src.systems.CardParticles")
local RoundEvalScreen  = require("components.RoundEvalScreen")
local I18n             = require("src.i18n.I18n")

local PHASE_TIMES = { [0] = 0.6, [1] = 1.2, [2] = 2.6, [3] = 5.0 }

function M.run(phase)
    phase = tonumber(phase or 3) or 3
    local targetT = PHASE_TIMES[phase] or 3.6

    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()
    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()
    FoilShader.load()
    PolychromeShader.load()
    NegativeShader.load()
    ScreenShake.install()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    -- Simula gold acumulado pra ter juros visível.
    if game.economySystem then
        game.economySystem.currentGold = 25
    end

    -- Sources de teste com 3 fontes (Vitória + HP cheio + Juros).
    local sources = game:_buildRoundEvalSources()

    local screen = RoundEvalScreen:new()
    -- F3: semeia um breakdown TINTA×SELO pra validar o banner de score.
    game.scoreSystem.lastBattle = {
        tinta = 240, selo = 2.3, total = 552,
        turns = 3, combos = 2, flawless = true, lowHp = false,
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
    -- Backdrop simulando gameplay congelado por trás.
    love.graphics.setColor(0.20, 0.16, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1, 1)

    screen:draw()
    CardParticles.draw()
    FloatingText.draw()
    FlashShader.draw()

    love.graphics.captureScreenshot(function(imageData)
        local path = string.format("round_eval_phase_%d_t%.2f.png", phase, targetT)
        imageData:encode("png", path)
        print("[screenshot_round_eval] " .. path)
        love.event.quit()
    end)
    love.graphics.present()
end

return M
