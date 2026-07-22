-- src/ui/card/components/joker/JokerFooter.lua
-- Rodapé do joker v2 (Jul/2026, "mais trabalhado"): placa navy com bevel
-- direcional ouro-tarot e uma CONSTELAÇÃO — sol, estrela e lua conectados
-- por um fio pontilhado, com sombra projetada e faíscas entre eles.
-- A v1 era um rectOutline uniforme (pillow) com símbolos flutuando.

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local JokerFooter = {}

JokerFooter.HEIGHT = 16

-- Símbolos 5×5 com furo de luz (2 tons + catchlight) — a v1 era cor chapada.
local function drawSunSymbol(cx, cy)
    local c, hi = Palette.TAROT_GOLD, Palette.AGED_GOLD_LIGHT
    PixelCanvas.pixel(cx, cy - 2, c)
    PixelCanvas.pixel(cx - 1, cy - 1, c)
    PixelCanvas.pixel(cx + 1, cy - 1, c)
    PixelCanvas.pixel(cx - 2, cy, c)
    PixelCanvas.pixel(cx - 1, cy, hi)
    PixelCanvas.pixel(cx,     cy, hi)
    PixelCanvas.pixel(cx + 1, cy, c)
    PixelCanvas.pixel(cx + 2, cy, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy + 1, c)
    PixelCanvas.pixel(cx + 1, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx, cy + 2, Palette.TAROT_GOLD_DARK)
end

local function drawStarSymbol(cx, cy)
    local c, hi = Palette.TAROT_GOLD, Palette.AGED_GOLD_LIGHT
    PixelCanvas.pixel(cx, cy - 2, hi)
    PixelCanvas.pixel(cx - 2, cy - 1, c)
    PixelCanvas.pixel(cx - 1, cy - 1, hi)
    PixelCanvas.pixel(cx,     cy - 1, hi)
    PixelCanvas.pixel(cx + 1, cy - 1, c)
    PixelCanvas.pixel(cx + 2, cy - 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy, c)
    PixelCanvas.pixel(cx,     cy, Palette.PARCHMENT_LIGHT) -- coração da estrela
    PixelCanvas.pixel(cx + 1, cy, c)
    PixelCanvas.pixel(cx - 2, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx + 2, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx - 1, cy + 2, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx + 1, cy + 2, Palette.TAROT_GOLD_DARK)
end

local function drawMoonSymbol(cx, cy)
    local c, hi = Palette.TAROT_GOLD, Palette.AGED_GOLD_LIGHT
    PixelCanvas.pixel(cx, cy - 2, hi)
    PixelCanvas.pixel(cx - 1, cy - 1, hi)
    PixelCanvas.pixel(cx,     cy - 1, c)
    PixelCanvas.pixel(cx - 2, cy, hi)
    PixelCanvas.pixel(cx - 1, cy, c)
    PixelCanvas.pixel(cx - 2, cy + 1, c)
    PixelCanvas.pixel(cx - 1, cy + 1, c)
    PixelCanvas.pixel(cx,     cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(cx, cy + 2, Palette.TAROT_GOLD_DARK)
end

-- Sombra projetada do símbolo (silhueta 5×5 grosseira em INK, offset +1+1).
local function drawSymbolShadow(cx, cy)
    PixelCanvas.rect(cx - 1, cy - 1, 4, 4, { 0, 0, 0, 0.35 })
end

function JokerFooter.draw(w, h)
    local fh = JokerFooter.HEIGHT
    local fy = h - fh - 1
    local bx, by = 2, fy
    local bw, bh = w - 4, fh
    local cy = by + math.floor(bh / 2)

    -- Sombra externa sob a placa
    PixelCanvas.rect(bx, by + bh, bw, 1, { 0, 0, 0, 0.7 })

    -- Fundo navy 2 tons (luz de cima)
    local navyTop = Palette.lerp(Palette.TAROT_NAVY, Palette.TAROT_GOLD_DARK, 0.10)
    PixelCanvas.rect(bx, by, bw, math.floor(bh / 2), navyTop)
    PixelCanvas.rect(bx, by + math.floor(bh / 2), bw, math.ceil(bh / 2),
        Palette.TAROT_NAVY_DARK)

    -- Bevel direcional ouro-tarot (era rectOutline uniforme = pillow)
    PixelCanvas.hline(bx, by, bw, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(bx, by, bh, Palette.TAROT_GOLD)
    PixelCanvas.hline(bx, by + bh - 1, bw, Palette.TAROT_GOLD_DARK)
    PixelCanvas.vline(bx + bw - 1, by, bh, Palette.TAROT_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.TAROT_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, { 0, 0, 0, 0.6 })

    -- Diamantes de engaste nas pontas (ligam a placa à moldura)
    PixelCanvas.pixel(bx - 1, cy, Palette.TAROT_GOLD)
    PixelCanvas.pixel(bx, cy - 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx, cy + 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx + bw, cy, Palette.TAROT_GOLD)
    PixelCanvas.pixel(bx + bw - 1, cy - 1, Palette.TAROT_GOLD_DARK)
    PixelCanvas.pixel(bx + bw - 1, cy + 1, Palette.TAROT_GOLD_DARK)

    -- ===== CONSTELAÇÃO: fio pontilhado conectando sol → estrela → lua =====
    local p1 = math.floor(w * 0.28)
    local p2 = math.floor(w * 0.50)
    local p3 = math.floor(w * 0.72)

    -- Fio (pontilhado, por trás dos símbolos)
    for x = p1 + 4, p3 - 4, 3 do
        PixelCanvas.pixel(x, cy, Palette.TAROT_GOLD_DARK)
    end
    -- Faíscas soltas entre os símbolos (céu vivo)
    PixelCanvas.pixel(math.floor((p1 + p2) / 2), cy - 3, Palette.TAROT_GOLD)
    PixelCanvas.pixel(math.floor((p2 + p3) / 2) + 1, cy + 3, Palette.TAROT_GOLD)
    PixelCanvas.pixel(math.floor((p2 + p3) / 2) - 3, cy - 4, Palette.TAROT_GOLD_DARK)

    -- Símbolos com sombra projetada
    drawSymbolShadow(p1, cy); drawSunSymbol(p1, cy)
    drawSymbolShadow(p2, cy); drawStarSymbol(p2, cy)
    drawSymbolShadow(p3, cy); drawMoonSymbol(p3, cy)
end

return JokerFooter
