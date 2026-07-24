-- src/ui/card/components/joker/JokerFooter.lua
-- Rodapé do joker v2 (Jul/2026, "mais trabalhado"): placa navy com bevel
-- direcional ouro-tarot e uma CONSTELAÇÃO — sol, estrela e lua conectados
-- por um fio pontilhado, com sombra projetada e faíscas entre eles.
-- A v1 era um rectOutline uniforme (pillow) com símbolos flutuando.

local Palette          = require("src.ui.Palette")
local PixelCanvas      = require("src.ui.PixelCanvas")
local BackgroundLoader = require("src.ui.card.BackgroundLoader")

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

    -- Fundo navy em DEGRADÊ contínuo (v3.4: o split 2-tons tinha emenda
    -- horizontal dura — mesma "reta" do rodapé standard).
    local navyTop = Palette.lerp(Palette.TAROT_NAVY, Palette.TAROT_GOLD_DARK, 0.10)
    for row = 0, bh - 1 do
        local t = row / (bh - 1)
        PixelCanvas.hline(bx, by + row, bw,
            Palette.lerp(navyTop, Palette.TAROT_NAVY_DARK, t))
    end

    -- Grão do material (denso e muito sutil — matéria, não ruído)
    for y = by + 1, by + bh - 2 do
        for x = bx + 1, bx + bw - 2 do
            local g = (x * 3557 + y * 2953) % 17
            if g == 0 then
                PixelCanvas.pixel(x, y, { 1, 1, 1, 0.04 })
            elseif g == 1 then
                PixelCanvas.pixel(x, y, { 0, 0, 0, 0.10 })
            end
        end
    end

    -- Textura "void" sobre o navy (v3.4: alpha 0.14→0.24)
    local tex = BackgroundLoader.get("void")
    if tex then
        local quad = love.graphics.newQuad(0, 0, bw - 2, bh - 2,
            tex:getWidth(), tex:getHeight())
        love.graphics.setColor(1, 1, 1, 0.24)
        love.graphics.draw(tex, quad, bx + 1, by + 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- v3: filete de ouro ACIMA da placa (a v1 tinha e ligava o rodapé à
    -- moldura; a v2 tirou e a placa ficou "solta" na base da carta).
    PixelCanvas.hline(bx + 1, by - 1, bw - 2, Palette.TAROT_GOLD_DARK)

    -- Bevel direcional ouro-tarot (era rectOutline uniforme = pillow).
    -- v3.2: linha interna de baixo era preta — vala entre placa e moldura;
    -- agora bronze-tarot (flush).
    local bronze = Palette.lerp(Palette.TAROT_GOLD_DARK, Palette.INK, 0.45)
    PixelCanvas.hline(bx, by, bw, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(bx, by, bh, Palette.TAROT_GOLD)
    PixelCanvas.hline(bx, by + bh - 1, bw, Palette.TAROT_GOLD_DARK)
    PixelCanvas.vline(bx + bw - 1, by, bh, Palette.TAROT_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.TAROT_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, bronze)

    -- Desgaste sutil (v3.3, realista): lascas de 2px CONCENTRADAS nas
    -- bordas (onde a mão gasta), centro quase intocado — nada de
    -- pixel-confete solto (feedback do dono). Determinístico.
    for y = by, by + bh - 1 do
        for x = bx, bx + bw - 2 do
            local edgeDist = math.min(x - bx, (bx + bw - 1) - x,
                                      y - by, (by + bh - 1) - y)
            local r = (x * 7919 + y * 6271) % 223
            local thresh
            if edgeDist <= 1 then thresh = 8
            elseif edgeDist <= 3 then thresh = 2
            else thresh = 0 end
            if r < thresh then
                PixelCanvas.pixel(x,     y, { 0, 0, 0, 0.28 })
                PixelCanvas.pixel(x + 1, y, { 0, 0, 0, 0.16 })
            end
        end
    end

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
