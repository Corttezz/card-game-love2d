-- src/ui/card/components/CardRaritySeal.lua
-- Desenha o selo circular de raridade no canto superior direito.
-- Cor varia com rarity; legendary tem halo dourado com faíscas.
--
-- API: CardRaritySeal.draw(w, rarity)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardRaritySeal = {}

CardRaritySeal.SIZE = 11

local function drawCircle(ox, oy, size, fill, outline)
    PixelCanvas.rect(ox, oy + 1, size, size - 2, fill)
    PixelCanvas.rect(ox + 1, oy, size - 2, size, fill)
    PixelCanvas.hline(ox + 1, oy, size - 2, outline)
    PixelCanvas.hline(ox + 1, oy + size - 1, size - 2, outline)
    PixelCanvas.vline(ox, oy + 1, size - 2, outline)
    PixelCanvas.vline(ox + size - 1, oy + 1, size - 2, outline)
    PixelCanvas.pixel(ox + 1, oy + 1, outline)
    PixelCanvas.pixel(ox + size - 2, oy + 1, outline)
    PixelCanvas.pixel(ox + 1, oy + size - 2, outline)
    PixelCanvas.pixel(ox + size - 2, oy + size - 2, outline)
end

function CardRaritySeal.draw(w, rarity)
    rarity = rarity or "common"
    local color = Palette.forRarity(rarity)
    local size = CardRaritySeal.SIZE
    local ox = w - size - 1
    local oy = 1

    -- Halo lendário (faíscas douradas em volta)
    if rarity == "legendary" then
        PixelCanvas.pixel(ox - 1, oy + 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox + size, oy + 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox, oy - 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox + size - 1, oy - 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox - 1, oy + size - 2, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox + size, oy + size - 2, Palette.AGED_GOLD)
    end

    -- Disco externo
    drawCircle(ox, oy, size, color, Palette.INK)
    -- Núcleo interno (gema central)
    local core = rarity == "legendary" and Palette.AGED_GOLD_LIGHT
              or rarity == "rare" and Palette.PARCHMENT_LIGHT
              or rarity == "uncommon" and Palette.PARCHMENT_LIGHT
              or Palette.PARCHMENT_DARK
    PixelCanvas.rect(ox + 3, oy + 3, size - 6, size - 6, core)
    PixelCanvas.pixel(ox + 4, oy + 4, Palette.PARCHMENT_LIGHT)
end

return CardRaritySeal
