-- tools/screenshot_joker_manager.lua
-- Valida o Gerenciador de Coringas alinhado ao DeckViewer/Coleção
-- (feedback Jul/2026: "não está parecido com o deck e a coleção").
--   joker_manager.png       — grid parado (ativos + bancada)
--   joker_manager_hover.png — hover num coringa da bancada
--   love . screenshot_joker_manager

local M = {}

local function capture(name)
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", name)
        print("[joker_mgr] " .. name .. " salvo")
    end)
    love.graphics.present()
end

function M.run()
    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local CardDatabase = require("src.systems.CardDatabase")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    -- coleção de 6 coringas (3 ativos pelo cap + 3 na bancada)
    local jokerIds = {}
    for id, cd in pairs(CardDatabase:getAllCards()) do
        if cd.type == "joker" then
            table.insert(jokerIds, id)
            if #jokerIds >= 6 then break end
        end
    end
    table.sort(jokerIds)
    for _, id in ipairs(jokerIds) do game:addJokerToRun(id) end

    local screen = require("components.JokerManagerScreen"):new()
    screen:show(game)

    local dt = 1 / 30
    for _ = 1, 20 do screen:update(dt) end

    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("joker_manager.png")

    -- hover num card da 1ª FILEIRA (posiciona o mouse de verdade):
    -- valida o tooltip ABAIXO da carta (feedback: acima cobria o topo)
    if #screen._cardRects >= 2 then
        local r = screen._cardRects[2]
        love.mouse.setPosition(r.x + r.w / 2, r.y + r.h / 2)
    end
    for _ = 1, 12 do screen:update(dt); love.graphics.clear(0,0,0,1); screen:draw() end
    love.graphics.clear(0, 0, 0, 1)
    screen:draw()
    capture("joker_manager_hover.png")

    love.event.quit()
end

return M
