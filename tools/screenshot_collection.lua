-- tools/screenshot_collection.lua
-- Captura a tela de coleção: grid (rolada até a carta alvo) + modal de
-- inspeção da carta alvo. Validação visual das cartas animadas em TODAS
-- as renderizações.
-- Roda: love . screenshot_collection [card_id]   (default warrior_standard_bearer)
-- Saída: ~/.local/share/love/card-game/collection_grid.png + collection_inspect.png

local M = {}

function M.run(cardId)
    cardId = cardId or "warrior_standard_bearer"

    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local CardFrame = require("src.ui.CardFrame")
    local CollectionScreen = require("components.CollectionScreen")

    local screen = CollectionScreen:new()
    screen:show(function() end)

    -- Acha a carta alvo na lista filtrada e rola até ela
    local target, targetIdx
    for i, inst in ipairs(screen.filtered or {}) do
        if inst.id == cardId then target = inst; targetIdx = i; break end
    end
    if not target then
        print("[screenshot_collection] carta não encontrada na coleção: " .. cardId)
        for i, inst in ipairs(screen.filtered or {}) do
            if i <= 5 then print("  ex: " .. tostring(inst.id)) end
        end
        return
    end
    print(string.format("[screenshot_collection] alvo %s (idx %d, type=%s)",
        cardId, targetIdx, tostring(target.type)))

    local stepDt = 1 / 60
    local function simulate(secs)
        local elapsed = 0
        while elapsed < secs do
            CardFrame.update()
            screen:update(stepDt)
            elapsed = elapsed + stepDt
        end
    end

    -- Rola o grid pra linha da carta alvo ficar visível
    -- (CARD_H=192, GAP_Y=24, COLS=5 — constantes locais do CollectionScreen)
    local row = math.floor((targetIdx - 1) / 5)
    screen.scrollY = math.min(screen.maxScrollY or 0,
        math.max(0, row * (192 + 24) - 60))

    simulate(0.6)

    love.graphics.clear(0.05, 0.04, 0.08, 1)
    screen:draw()
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "collection_grid.png")
        print("[screenshot_collection] collection_grid.png")
    end)
    love.graphics.present()

    -- Modal de inspeção
    screen.inspectedCard = target
    screen.inspectAnim = 0
    simulate(0.5)

    love.graphics.clear(0.05, 0.04, 0.08, 1)
    screen:draw()
    love.graphics.captureScreenshot(function(imageData)
        imageData:encode("png", "collection_inspect.png")
        print("[screenshot_collection] collection_inspect.png")
        love.event.quit()
    end)
    love.graphics.present()
end

return M
