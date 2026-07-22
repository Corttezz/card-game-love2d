-- src/ui/card/components/CardCostBadge.lua
-- Badge de custo de mana no canto superior esquerdo: GEMA DE MANA lapidada
-- (losango facetado azul-arcano com engaste dourado), número em bone white
-- contornado em tinta.
--
-- Redesign Jul/2026: o disco aço 11×11 era ilegível e "morto" — a gema usa o
-- MESMO azul do ManaOrb do HUD (Palette.MANA*, identidade única de mana no
-- jogo) e o idioma de joalheria dos banners (facetas + engaste AGED_GOLD,
-- como os rubis/medalhões do CardHeader). Pixel colocado à mão: a este
-- tamanho (13px), PNG rebaixado vira borrão — procedural nítido ganha.
--
-- Geometria: gema em x∈[1,13] + engastes em x=0/x=14 — o banner do nome
-- começa em x=15 (CardHeader bx), então nada colide.
--
-- API: CardCostBadge.draw(cost)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")

local CardCostBadge = {}

CardCostBadge.SIZE = 13

-- Meia-largura por linha (13 linhas): losango "cushion cut" — pontas de 3px
-- (1px fica fino demais em outline) e cintura cheia de 13px nas 3 linhas
-- centrais, onde mora o número.
local HW = { 1, 2, 3, 4, 5, 6, 6, 6, 5, 4, 3, 2, 1 }

function CardCostBadge.draw(cost)
    local ox, oy = 1, 2
    local size = CardCostBadge.SIZE
    local cx = ox + 6  -- coluna central da gema

    -- Sombra projetada (+1,+1) — mesmo idioma de profundidade do banner.
    for i, hw in ipairs(HW) do
        PixelCanvas.hline(cx - hw + 1, oy + i, hw * 2 + 1, { 0, 0, 0, 0.35 })
    end

    -- Corpo em INK (vira o outline 1px quando o fill entra por cima).
    for i, hw in ipairs(HW) do
        PixelCanvas.hline(cx - hw, oy + i - 1, hw * 2 + 1, Palette.INK)
    end

    -- Fill interno (1px menor por linha; pontas y0/y12 ficam 100% outline).
    for i = 2, 12 do
        local hw = HW[i] - 1
        PixelCanvas.hline(cx - hw, oy + i - 1, hw * 2 + 1, Palette.MANA)
    end

    -- Facetas: quadrante superior-esquerdo pega luz, inferior-direito afunda.
    for i = 2, 6 do
        local hw = HW[i] - 1
        if hw > 0 then
            PixelCanvas.hline(cx - hw, oy + i - 1, hw, Palette.MANA_LIGHT)
        end
    end
    for i = 8, 12 do
        local hw = HW[i] - 1
        if hw > 0 then
            PixelCanvas.hline(cx + 1, oy + i - 1, hw, Palette.MANA_DEEP)
        end
    end

    -- Glint especular (2px em diagonal, canto iluminado).
    PixelCanvas.pixel(cx - 2, oy + 2, Palette.MANA_GLINT)
    PixelCanvas.pixel(cx - 3, oy + 3, Palette.MANA_GLINT)

    -- Engaste dourado nos 4 pontos do losango (garras de joalheiro — liga a
    -- gema ao ouro envelhecido da moldura/banners).
    PixelCanvas.pixel(cx,     oy - 1,    Palette.AGED_GOLD_LIGHT) -- norte
    PixelCanvas.pixel(cx,     oy + 13,   Palette.AGED_GOLD_DARK)  -- sul
    PixelCanvas.pixel(cx - 7, oy + 6,    Palette.AGED_GOLD)       -- oeste
    PixelCanvas.pixel(cx + 7, oy + 6,    Palette.AGED_GOLD)       -- leste

    -- Número do custo: bone white com outline INK 4-direções (legível sobre
    -- qualquer faceta da gema).
    local font = PixelFont.get(8)
    love.graphics.setFont(font)
    local s = tostring(cost or 0)
    local tw = font:getWidth(s)
    local tx = ox + math.floor((size - tw) / 2)
    local ty = oy + 3
    love.graphics.setColor(Palette.INK)
    love.graphics.print(s, tx - 1, ty)
    love.graphics.print(s, tx + 1, ty)
    love.graphics.print(s, tx, ty - 1)
    love.graphics.print(s, tx, ty + 1)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    love.graphics.print(s, tx, ty)
end

return CardCostBadge
