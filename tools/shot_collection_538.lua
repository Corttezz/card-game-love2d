local M = {}

-- Painel de inspecao da Colecao no tamanho de janela (SHOT_W/H) e escala (SHOT_K) pedidos.
function M.run(tag)
    local W = tonumber(os.getenv("SHOT_W") or "") or 1280
    local H = tonumber(os.getenv("SHOT_H") or "") or 720
    local k = tonumber(os.getenv("SHOT_K") or "") or 1
    local cardId = os.getenv("SHOT_CARD") or "effect_mystery_card"
    love.window.setMode(W, H)
    require("src.i18n.I18n").init()
    if os.getenv("SHOT_LANG") then require("src.i18n.I18n").setLanguage(os.getenv("SHOT_LANG")) end
    require("src.ui.PixelCanvas").enableNearest()
    local UiScale = require("src.ui.UiScale")
    UiScale.force(k)
    local CollectionScreen = UiScale.adopt(require("components.CollectionScreen"))
    local CardFrame = require("src.ui.CardFrame")
    require("src.systems.UnlockSystem").setRevealAll(true)
    local screen = CollectionScreen:new()
    screen:show(function() end)
    for _ = 1, 200 do
        if screen._buildDone then break end
        screen:_buildInstances(1)
    end
    screen.filter = "all"
    screen:_applyFilter()
    local target
    for _, f in ipairs({ "all", "effect", "attack", "skill", "power" }) do
        screen.filter = f
        screen:_applyFilter()
        for _, inst in ipairs(screen.filtered or {}) do
            if inst.id == cardId then target = inst break end
        end
        if target then break end
    end
    if not target then print("[shot_collection_538] carta nao achada " .. cardId) return false end
    screen.inspectedCard = target
    screen.inspectAnim = 0
    for _ = 1, 40 do CardFrame.update(); screen:update(1 / 60) end
    local cv = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.05, 0.04, 0.08, 1)
    love.graphics.origin()
    screen:draw()
    love.graphics.setCanvas()
    love.filesystem.createDirectory("shots538")
    local name = ("shots538/colecao_%s_%dx%d_k%s.png"):format(tag or "x", W, H, tostring(k))
    cv:newImageData():encode("png", name)
    print("  foto " .. name)
    return true
end

return M
