-- src/ui/card/components/joker/JokerMoon.lua
-- Ornamento do canto superior ESQUERDO do joker: lua crescente dourada com
-- estrela na concavidade — contrapeso tarot do JokerSeal (estrela 6 pontas,
-- canto direito). Ocupa o lugar onde ficava o badge de custo de mana
-- (removido Jul/2026: joker é passivo, não tem mana — o custo era dado
-- vestigial exibido à toa).
--
-- Pixel colocado à mão (13×13): outline INK via carimbo 4-direções da
-- própria silhueta (idioma dos componentes de carta).
--
-- API: JokerMoon.draw()

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local JokerMoon = {}

JokerMoon.SIZE = 13

-- Spans {xa, xb} por linha (13 linhas): crescente em "C" (abre pra direita),
-- pontas afiladas que avançam sobre a concavidade.
local MOON = {
    { 4, 7 },  -- ponta superior
    { 3, 8 },
    { 2, 6 },
    { 1, 5 },
    { 1, 4 },
    { 0, 4 },
    { 0, 4 },  -- barriga (esquerda)
    { 0, 4 },
    { 1, 4 },
    { 1, 5 },
    { 2, 6 },
    { 3, 8 },
    { 4, 7 },  -- ponta inferior
}

local function stamp(ox, oy, color, dx, dy)
    for i, sp in ipairs(MOON) do
        PixelCanvas.hline(ox + sp[1] + dx, oy + i - 1 + dy,
            sp[2] - sp[1] + 1, color)
    end
end

function JokerMoon.draw()
    local ox, oy = 1, 1

    -- Outline INK: silhueta carimbada nas 4 direções.
    stamp(ox, oy, Palette.INK, 1, 0)
    stamp(ox, oy, Palette.INK, -1, 0)
    stamp(ox, oy, Palette.INK, 0, 1)
    stamp(ox, oy, Palette.INK, 0, -1)

    -- Corpo dourado tarot.
    stamp(ox, oy, Palette.TAROT_GOLD, 0, 0)

    -- Sombra na borda interna (lado côncavo, direita de cada span).
    for i, sp in ipairs(MOON) do
        PixelCanvas.pixel(ox + sp[2], oy + i - 1, Palette.TAROT_GOLD_DARK)
    end

    -- Rim light no arco externo superior-esquerdo.
    for i = 2, 6 do
        PixelCanvas.pixel(ox + MOON[i][1], oy + i - 1, Palette.AGED_GOLD_LIGHT)
    end

    -- Estrela 5px na concavidade (cruz), cream com centro claro — ecoa a gema
    -- central do JokerSeal do canto oposto.
    local sx, sy = ox + 9, oy + 6
    PixelCanvas.pixel(sx,     sy - 1, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(sx - 1, sy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(sx,     sy,     Palette.TAROT_CREAM)
    PixelCanvas.pixel(sx + 1, sy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(sx,     sy + 1, Palette.AGED_GOLD_LIGHT)

    -- Faísca solta acima da estrela (assimetria viva, tarot).
    PixelCanvas.pixel(sx + 2, sy - 3, Palette.TAROT_GOLD)
end

return JokerMoon
