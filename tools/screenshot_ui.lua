-- tools/screenshot_ui.lua
-- Captura as telas de UI SEM harness próprio (levantamento do redesign UI/UX):
--   love . screenshot_ui menu|class|settings|rest|event|collection|all
-- Salva ui_<tela>.png no save dir. Segue o pipeline de validação visual do
-- memory/balatro_fidelity_directive.md ("ver com os olhos").

local M = {}

-- padrão do screenshot_worldroad "all": loop SÍNCRONO draw→capture→present
-- (encadear present dentro do callback de captura não dispara o próximo)
local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "ui_" .. name .. ".png")
        print("[screenshot] ui_" .. name .. ".png salvo")
    end)
    love.graphics.present()
end

local function simulate(obj, secs)
    for _ = 1, math.floor(secs * 30) do
        obj:update(1 / 30)
    end
end

function M.run(mode)
    mode = mode or "all"
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local shots = {}

    local function addShot(name, fn)
        if mode == "all" or mode == name then
            shots[#shots + 1] = { name = name, fn = fn }
        end
    end

    addShot("menu", function()
        local Menu = require("components.Menu")
        local menu = Menu:new()
        simulate(menu, 2.4)              -- intro stagger termina
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
    end)

    addShot("class", function()
        local ClassSelectionScreen = require("components.ClassSelectionScreen")
        local cs = ClassSelectionScreen:new()
        cs:show(function() end, function() end)
        simulate(cs, 1.0)
        love.graphics.clear(0, 0, 0, 1)
        cs:draw()
    end)

    addShot("settings", function()
        local Menu = require("components.Menu")
        local SettingsMenu = require("components.SettingsMenu")
        local menu = Menu:new()
        simulate(menu, 2.4)
        local sm = SettingsMenu:new()
        sm:show()
        love.graphics.clear(0, 0, 0, 1)
        menu:draw()
        sm:draw()
    end)

    addShot("rest", function()
        local RestScreen = require("components.RestScreen")
        local rs = RestScreen:new()
        rs:show(game, function() end)
        simulate(rs, 0.8)
        love.graphics.clear(0, 0, 0, 1)
        rs:draw()
    end)

    addShot("event", function()
        local Events = require("src.data.events")
        local EventScreen = require("components.EventScreen")
        local ev = Events.roll(1)
        -- prefere evento COM ilustração (valida o slot de arte do redesign)
        for _ = 1, 30 do
            if ev and love.filesystem.getInfo(
                "assets/sprites/ui/event_" .. tostring(ev.id) .. ".png") then
                break
            end
            ev = Events.roll(1) or ev
        end
        if not ev then print("[screenshot] sem evento") return end
        local es = EventScreen:new()
        es:show(ev, game, function() end)
        simulate(es, 0.8)
        love.graphics.clear(0, 0, 0, 1)
        es:draw()
    end)

    addShot("collection", function()
        local CollectionScreen = require("components.CollectionScreen")
        local cs = CollectionScreen:new()
        cs:show(function() end)
        simulate(cs, 0.8)
        love.graphics.clear(0, 0, 0, 1)
        cs:draw()
    end)

    for _, s in ipairs(shots) do
        local ok, err = pcall(s.fn)
        if ok then
            capture(s.name)
        else
            print("[screenshot] " .. s.name .. " FALHOU: " .. tostring(err))
        end
    end
    love.event.quit()
end

return M
