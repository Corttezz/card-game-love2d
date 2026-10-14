local M = {}

function M.run(cardId)
    cardId = cardId or "warrior_iron_wave"

    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local CardFrame = require("src.ui.CardFrame")
    local CollectionScreen = require("components.CollectionScreen")

    if os.getenv("STORE_REVEAL") == "1" then
        require("src.systems.UnlockSystem").setRevealAll(true)
    end
    local screen = CollectionScreen:new()
    screen:show(function() end)
    for _ = 1, 200 do
        if screen._buildDone then break end
        screen:_buildInstances(1)
    end
    screen:_applyFilter()
    if os.getenv("COLLECTION_FILTER") then
        screen.filter = os.getenv("COLLECTION_FILTER")
        screen:_applyFilter()
    end

    local target, targetIdx
    for i, inst in ipairs(screen.filtered or {}) do
        if inst.id == cardId then target = inst; targetIdx = i; break end
    end
    if not target and os.getenv("STORE_REVEAL") == "1" and screen.filtered
        and screen.filtered[1] then
        print("[screenshot_collection] AVISO: " .. cardId
            .. " fora da aba atual — usando a 1a carta (" .. screen.filtered[1].id .. ")")
        target, targetIdx = screen.filtered[1], 1
        cardId = target.id
    end
    if not target then
        print("[screenshot_collection] carta não encontrada na coleção: " .. cardId)
        for i, inst in ipairs(screen.filtered or {}) do
            if i <= 5 then print("  ex: " .. tostring(inst.id)) end
        end
        love.event.quit(1)
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
