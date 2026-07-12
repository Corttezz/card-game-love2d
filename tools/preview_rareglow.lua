-- tools/preview_rareglow.lua
-- Renderiza uma carta RARA pelo caminho AO VIVO (Card:draw) pra capturar o
-- rareGlow (filtro vermelho) da CardAnimationLayer, que não entra no canvas
-- estático do CardFrame. Usar: love . preview_rareglow
-- Saída: rareglow_live.png no saveDir.

local M = {}

function M.run()
    local PixelCanvas = require("src.ui.PixelCanvas")
    PixelCanvas.enableNearest()
    local I18n = require("src.i18n.I18n"); pcall(I18n.init)

    pcall(function() require("src.ui.CardMesh").load() end)
    pcall(function() require("src.ui.HoloShader").load() end)

    local CardDatabase = require("src.systems.CardDatabase")
    local db = CardDatabase:new()
    local CardFrame = require("src.ui.CardFrame")

    -- Cobaia fria (escudo azul) forçada RARA — o filtro vermelho fica óbvio.
    local base = db:getCard("warrior_defend")
    if not base then print("[rareglow] warrior_defend não encontrada"); return end
    local cd = {}
    for k, v in pairs(base) do cd[k] = v end
    cd.rarity = "rare"
    cd.id = "warrior_defend_AS_rare"
    local inst = db:createCardInstance(cd)
    pcall(function() CardFrame.invalidate(cd) end)
    inst.image = CardFrame.render(cd)

    -- Estado neutro (sem warp/hover) pra ver a carta reta.
    inst.isDragging = false
    inst.isHovered = false
    inst.liftOffset = 0
    inst.hoverStrength = 0
    inst.tiltX = 0
    inst.tiltY = 0

    local W, H = 360, 520
    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.12, 0.10, 0.09, 1)  -- fundo escuro neutro
    love.graphics.setColor(1, 1, 1, 1)
    -- draw centraliza pela própria lógica; posiciona no meio do canvas
    inst:draw(W / 2, H / 2, false, false)
    love.graphics.setCanvas()

    local data = canvas:newImageData()
    data:encode("png", "rareglow_live.png")
    print("[rareglow] saved rareglow_live.png (rarity=" .. tostring(cd.rarity) .. ")")
    print("[rareglow] saveDir: " .. love.filesystem.getSaveDirectory())
end

return M
