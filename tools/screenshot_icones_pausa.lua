local M = {}

local SIZES = { { 1024, 768 }, { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }
local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

local function fakeWindow(w, h)
    local rw, rh, rd = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = rw, rh, rd
    end
end

function M.run(arg)
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local FontManager = require("src.ui.FontManager")
    local UiScale = require("src.ui.UiScale")
    UiScale.force(nil)
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    local PauseMenu = require("components.PauseMenu")
    local prefix = (type(arg) == "string" and arg ~= "") and arg or "icones_pausa"
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc)
        for _, sz in ipairs(SIZES) do
            local w, h = sz[1], sz[2]
            local restore = fakeWindow(w, h)
            FontManager.clearCache()
            for _, focus in ipairs({ "resume", "jokers" }) do
                local p = PauseMenu:new()
                p:show(game, {}, { quiet = true })
                p:_focusKey(focus)
                for _ = 1, 20 do p:update(1 / 30) end
                local canvas = love.graphics.newCanvas(w, h)
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0.16, 0.12, 0.09, 1)
                p:draw()
                love.graphics.setCanvas()
                local problems = p:validate()
                if #problems > 0 then
                    print(("[FAIL] %s %dx%d %s: %s"):format(loc, w, h, focus, table.concat(problems, "; ")))
                end
                canvas:newImageData():encode("png",
                    ("%s_%s_%dx%d_%s.png"):format(prefix, focus, w, h, loc))
                p.visible = false
            end
            restore()
        end
    end
    FontManager.clearCache()
    return true
end

return M
