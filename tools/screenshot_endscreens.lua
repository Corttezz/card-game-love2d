local M = {}

local Game         = require("src.core.Game")
local CRTShader    = require("src.ui.CRTShader")
local EndScreens   = require("src.scenes.EndScreens")
local EventManager = require("engine.EventManager")
local I18n         = require("src.i18n.I18n")

local SHOTS = { { t = 1.2, tag = "a" }, { t = 2.8, tag = "b" } }

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[endscreens] " .. name .. " salvo")
    end)
    love.graphics.present()
end

function M.run(locale)
    _G.EventManager = EventManager
    _G.Event = require("engine.Event")
    I18n.init()
    I18n.setLocale(locale or "pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    CRTShader.load()

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    game.score = 4820
    game.currentPhase = 14
    _G.game = game

    local suffix = (locale and locale ~= "pt_BR") and ("_" .. locale) or ""

    for _, screen in ipairs({
        { key = "gameover", fn = EndScreens.drawGameOver },
        { key = "victory",  fn = EndScreens.drawVictory },
    }) do
        local elapsed = 0
        local shotIdx = 1
        local dt = 1 / 60
        while shotIdx <= #SHOTS do
            EventManager.update(dt)
            love.graphics.clear(0, 0, 0, 1)
            screen.fn(game)
            elapsed = elapsed + dt
            if elapsed >= SHOTS[shotIdx].t then
                capture(("endscreen_%s_%s%s.png"):format(
                    screen.key, SHOTS[shotIdx].tag, suffix))
                shotIdx = shotIdx + 1
            end
        end
    end

    love.event.quit()
end

return M
