local M = {}

function M.run()
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()

    local W = tonumber(os.getenv("MENU_W")) or 1024
    local H = tonumber(os.getenv("MENU_H")) or 768
    local canvas = love.graphics.newCanvas(W, H)
    local realW, realH, realD = love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions
    love.graphics.getWidth = function() return W end
    love.graphics.getHeight = function() return H end
    love.graphics.getDimensions = function() return W, H end
    require("src.ui.FontManager").clearCache()

    local fake = { x = W * 0.92, y = H * 0.92 }
    require("src.ui.InputFocus").installMouseGate(nil, function() return fake.x, fake.y end)

    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local Menu = require("components.Menu")
    local menu = Menu:new()
    menu:enterWithIntro()
    local function pump(secs)
        for _ = 1, math.floor(secs * 60) do
            _G.EventManager.update(1 / 60)
            menu:update(1 / 60)
        end
    end
    local function shot(name)
        love.graphics.push("all")
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        love.graphics.pop()
        canvas:newImageData():encode("png", name)
        print("[menu_life] " .. name)
    end
    local prefix = ("menu_life_%dx%d"):format(W, H)

    pump(4.2)
    menu._candleFlare = 0.5
    shot(prefix .. ".png")

    local b = menu.buttons.play
    fake.x, fake.y = b.x + b.width / 2, b.y + b.height / 2
    pump(0.4)
    shot(prefix .. "_hover.png")

    fake.x, fake.y = W * 0.92, H * 0.92
    _G.gameSettings.reducedMotion = true
    pump(0.5)
    shot(prefix .. "_reduced.png")
    _G.gameSettings.reducedMotion = false

    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = realW, realH, realD
    print("[menu_life] em " .. love.filesystem.getSaveDirectory())
    return true
end

return M
