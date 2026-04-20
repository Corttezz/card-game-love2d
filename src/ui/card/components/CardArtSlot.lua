-- src/ui/card/components/CardArtSlot.lua
-- Art slot: ilustração central com opção de cover/contain.
-- Default: **cover fit** — o ícone preenche o slot todo (ambas dimensões);
-- overflow é cortado pelo scissor, dando o efeito "ilustração encosta
-- nos banners de nome e stats".
--
-- Overrides por carta (em `src/data/card_art.lua`):
--   artData.artScale  = número (1, 1.5, 2, etc.) — substitui o cover automático.
--     - nil   → cover-fit inteiro (padrão)
--     - 1     → ícone nativo sem zoom (64×64 centrado — tipo o visual antigo)
--     - outro → scale fixo (pode ser fracional pra PNG)
--   artData.artOffsetY = pixels pra deslocar o ícone verticalmente (útil pra
--     sprites cujo subject não tá no centro do 64×64).
--
-- opts:
--   skipIcon = true  → não desenha o ícone (usado pelo Joker, anima via overlay)

local PixelCanvas = require("src.ui.PixelCanvas")

local CardArtSlot = {}

-- Escala inteira que cobre o slot (pixel-perfect, sem blur). Usa ceil pra
-- garantir que o ícone preenche as duas dimensões.
local function computeCoverScale(iconW, iconH, slotW, slotH)
    if iconW <= 0 or iconH <= 0 then return 1 end
    local sW = math.ceil(slotW / iconW)
    local sH = math.ceil(slotH / iconH)
    return math.max(1, sW, sH)
end

function CardArtSlot.draw(x, y, w, h, artData, theme, opts)
    opts = opts or {}

    if not opts.skipIcon and artData.icon then
        local iconW = artData.icon.size.w
        local iconH = artData.icon.size.h

        local scale = artData.artScale or computeCoverScale(iconW, iconH, w, h)
        local drawnW = iconW * scale
        local drawnH = iconH * scale
        local iconX = x + math.floor((w - drawnW) / 2)
        local iconY = y + math.floor((h - drawnH) / 2) + (artData.artOffsetY or 0)

        local sx, sy, sw, sh = love.graphics.getScissor()
        love.graphics.setScissor(x, y, w, h)
        artData.icon.draw(iconX, iconY, scale)
        if sx then
            love.graphics.setScissor(sx, sy, sw, sh)
        else
            love.graphics.setScissor()
        end
    end
end

return CardArtSlot
