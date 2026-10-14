local M = {}

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

function M.run(only)
    local I18n        = require("src.i18n.I18n")
    local Events      = require("src.data.events")
    local EventScreen = require("components.EventScreen")
    local Game        = require("src.core.Game")
    local Rng         = require("src.systems.Rng")

    local fw, fh = (os.getenv("EVENT_SIZE") or ""):match("^(%d+)x(%d+)$")
    if fw then
        fw, fh = tonumber(fw), tonumber(fh)
        love.graphics.getWidth = function() return fw end
        love.graphics.getHeight = function() return fh end
        love.graphics.getDimensions = function() return fw, fh end
    end
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or require("engine.EventManager")

    Rng.setActive(Rng.new(20260912))

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    local ev = os.getenv("EVENT_ID") and Events.get(os.getenv("EVENT_ID")) or Events.roll(1, {})
    if not ev then
        print("[screenshot_event] nenhum evento sorteado")
        return false
    end
    print("[screenshot_event] evento: " .. tostring(ev.id)
        .. " (" .. tostring(#(ev.options or {})) .. " opcoes)")

    local list = only and { only } or LOCALES
    local screen = EventScreen:new()

    for _, loc in ipairs(list) do
        I18n.setLocale(loc)
        require("src.ui.FontManager").clearCache()

        screen:show(ev, game, function() end)

        local EM = require("engine.EventManager")
        for _ = 1, 60 do
            EM.update(1 / 60)
            screen:update(1 / 60)
        end

        local W, H = love.graphics.getWidth(), love.graphics.getHeight()
        local canvas = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(canvas)
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)
        screen:draw()
        if os.getenv("TUT_TIP") then
            local Tutorial = require("src.systems.Tutorial")
            Tutorial.setScreens({ event = screen })
            local conv, line = os.getenv("TUT_TIP"):match("^([%w_]+):?([%w_]*)$")
            Tutorial._show(conv, line ~= "" and line or nil, game)
            Tutorial.draw()
        end
        love.graphics.setCanvas()

        local name = "event_" .. loc .. ".png"
        if os.getenv("EVENT_ID") then
            name = ("event_%s_%s_%dx%d.png"):format(ev.id, loc, W, H)
        end
        canvas:newImageData():encode("png", name)
        print("[screenshot_event] " .. name)

        screen:hide()
    end

    return true
end

return M
