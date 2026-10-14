local M = {}

local ENTER_AT = { 0.00, 0.06, 0.14, 0.24, 0.40 }
local EXIT_AT  = { 0.00, 0.08, 0.16, 0.24, 0.32 }

local function sheet(frames, name, labels)
    local W, H = frames[1]:getWidth(), frames[1]:getHeight()
    local S = 0.34
    local tw, th = math.floor(W * S), math.floor(H * S)
    local pad = 6
    local out = love.graphics.newCanvas(tw * #frames + pad * (#frames + 1), th + pad * 2 + 16)
    love.graphics.setCanvas(out)
    love.graphics.clear(0.10, 0.09, 0.11, 1)
    local font = love.graphics.newFont(11)
    love.graphics.setFont(font)
    for i, img in ipairs(frames) do
        local x = pad + (i - 1) * (tw + pad)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, x, pad, 0, S, S)
        love.graphics.setColor(0.95, 0.85, 0.45, 1)
        love.graphics.print(labels[i], x, pad + th + 3)
    end
    love.graphics.setCanvas()
    out:newImageData():encode("png", name)
    print("[screenshot_event_anim] " .. name)
end

local function capture(screen)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local c = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(c)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    love.graphics.setCanvas()
    return love.graphics.newImage(c:newImageData())
end

function M.run()
    local I18n        = require("src.i18n.I18n")
    local Events      = require("src.data.events")
    local EventScreen = require("components.EventScreen")
    local Game        = require("src.core.Game")
    local Rng         = require("src.systems.Rng")
    local EM          = require("engine.EventManager")

    I18n.init()
    I18n.setLocale("pt_BR")
    require("src.ui.PixelCanvas").enableNearest()
    _G.EventManager = _G.EventManager or EM

    Rng.setActive(Rng.new(20260912))
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()

    local ev = Events.roll(1, {})
    if not ev then print("[screenshot_event_anim] sem evento"); return false end

    local screen = EventScreen:new()
    local DT = 1 / 60

    screen:show(ev, game, function() end)
    local frames, labels, t, idx = {}, {}, 0, 1
    while idx <= #ENTER_AT do
        if t >= ENTER_AT[idx] - 1e-6 then
            frames[#frames + 1] = capture(screen)
            labels[#labels + 1] = string.format("t=%.2fs oy=%.0f fade=%.2f",
                t, screen.panelOy or 0, screen.fade or 1)
            idx = idx + 1
        else
            EM.update(DT)
            screen:update(DT)
            capture(screen)
            t = t + DT
        end
    end
    sheet(frames, "event_anim_enter.png", labels)

    for _ = 1, 40 do EM.update(DT); screen:update(DT); capture(screen) end
    screen:_closeWithFade()
    frames, labels, t, idx = {}, {}, 0, 1
    while idx <= #EXIT_AT do
        if t >= EXIT_AT[idx] - 1e-6 then
            frames[#frames + 1] = capture(screen)
            labels[#labels + 1] = string.format("t=%.2fs oy=%.0f fade=%.2f vis=%s",
                t, screen.panelOy or 0, screen.fade or 1, tostring(screen.visible))
            idx = idx + 1
        else
            EM.update(DT)
            screen:update(DT)
            if screen.visible then capture(screen) end
            t = t + DT
        end
    end
    sheet(frames, "event_anim_exit.png", labels)

    return true
end

return M
