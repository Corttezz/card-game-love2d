local M = {}

local SIZES = {
    { 1024, 768 },
    { 1920, 1080 },
    { 800, 600 },
    { 640, 480 },
    { 1280, 400 },
    { 2560, 1440 },
}

local function fakeWindow(w, h)
    local realW, realH = love.graphics.getWidth, love.graphics.getHeight
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    return function() love.graphics.getWidth, love.graphics.getHeight = realW, realH end
end

local function drawBackdrop(w, h)
    for i = 0, 15 do
        local t = i / 15
        love.graphics.setColor(0.18 + 0.10 * t, 0.14 + 0.06 * t, 0.10, 1)
        love.graphics.rectangle("fill", 0, math.floor(h * i / 16), w, math.ceil(h / 16) + 1)
    end
    love.graphics.setColor(0.35, 0.28, 0.18, 1)
    for x = 0, w, 96 do love.graphics.rectangle("fill", x, h * 0.62, 48, h * 0.38) end
    love.graphics.setColor(1, 1, 1, 1)
end

local function capture(name, w, h, drawFn)
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    drawBackdrop(w, h)
    drawFn()
    love.graphics.setCanvas()
    canvas:newImageData():encode("png", name)
    print("[pause] " .. name .. " salvo")
end

local function settle(screen, secs)
    for _ = 1, math.floor((secs or 1) * 60) do screen:update(1 / 60) end
end

function M.run(locale)
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale(locale or "pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    _G.gameSettings = _G.gameSettings or require("engine.SaveManager").loadSettings()

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = 2, 5

    local FontManager = require("src.ui.FontManager")
    local PauseMenu = require("components.PauseMenu")
    local SettingsMenu = require("components.SettingsMenu")
    local tag = (locale and locale ~= "pt_BR") and ("_" .. locale) or ""

    for _, s in ipairs(SIZES) do
        local w, h = s[1], s[2]
        local restore = fakeWindow(w, h)
        FontManager.clearCache()
        local suffix = ("%dx%d%s"):format(w, h, tag)

        local pause = PauseMenu:new()
        pause:show(game, {})
        settle(pause, 1.0)
        capture("pause_main_" .. suffix .. ".png", w, h, function() pause:draw() end)

        if pause.keypressed then pause:keypressed("down") end
        settle(pause, 0.4)
        capture("pause_focus_" .. suffix .. ".png", w, h, function() pause:draw() end)

        if pause.armAbandon then pause:armAbandon() else
            pause.confirmingAbandon = true; pause:rebuild()
        end
        settle(pause, 0.4)
        capture("pause_confirm_" .. suffix .. ".png", w, h, function() pause:draw() end)

        local settings = SettingsMenu:new()
        settings:show({ onClose = function() end })
        settle(settings, 1.0)
        capture("settings_" .. suffix .. ".png", w, h, function() settings:draw() end)
        if settings.setTab then
            for i = 2, (settings.tabCount and settings:tabCount() or 1) do
                settings:setTab(i)
                settle(settings, 0.5)
                capture(("settings_tab%d_%s.png"):format(i, suffix), w, h,
                    function() settings:draw() end)
            end
        end
        restore()
    end
    FontManager.clearCache()
    love.event.quit()
end

return M
