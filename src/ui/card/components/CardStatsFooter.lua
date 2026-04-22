-- src/ui/card/components/CardStatsFooter.lua
-- Rodapé ornamentado — mesma densidade do header.
-- Layout: [scroll-end][diamond][glyph disc + label][divider][value][diamond][scroll-end]

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")
local I18n        = require("src.i18n.I18n")

local CardStatsFooter = {}

CardStatsFooter.HEIGHT = 20

-- Mapa tipo -> chave I18n. Resolvido em cada draw via labelFor() pra refletir
-- mudanças de idioma sem cache (CardFrame já invalida o canvas em locale change).
local LABEL_KEYS = {
    attack  = "card_type.attack",
    defense = "card_type.defense",
    joker   = "card_type.passive",
    effect  = "card_type.action",
}

local function labelFor(cardType)
    local key = LABEL_KEYS[cardType]
    if not key then return I18n.t("card_type.unknown") end
    return I18n.t(key)
end

local GLYPH_NAMES = {
    attack  = "stat_sword",
    defense = "stat_shield",
    joker   = "stat_star",
    effect  = "stat_hourglass",
}

local glyphCache = {}
local glyphMissCache = {}

local function tryLoadGlyph(name)
    if glyphCache[name] then return glyphCache[name] end
    if glyphMissCache[name] then return nil end
    local path = "assets/sprites/ui/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then
        glyphMissCache[name] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        glyphMissCache[name] = true
        return nil
    end
    img:setFilter("nearest", "nearest")
    glyphCache[name] = img
    return img
end

local ProceduralGlyphs = {
    stat_sword     = { {0,0,0,1,0},{0,0,1,1,0},{0,1,1,0,0},{1,1,0,0,0},{1,0,0,0,0} },
    stat_shield    = { {1,1,1,1,1},{1,1,0,1,1},{1,0,0,0,1},{0,1,0,1,0},{0,0,1,0,0} },
    stat_hourglass = { {1,1,1,1,1},{0,1,0,1,0},{0,0,1,0,0},{0,1,0,1,0},{1,1,1,1,1} },
    stat_star      = { {0,0,1,0,0},{1,1,1,1,1},{0,1,1,1,0},{0,1,0,1,0},{1,0,0,0,1} },
}

local function drawProceduralGlyph(name, x, y, color)
    local g = ProceduralGlyphs[name] or ProceduralGlyphs.stat_star
    for row = 1, #g do
        for col = 1, #g[row] do
            if g[row][col] == 1 then
                PixelCanvas.pixel(x + col - 1, y + row - 1, color)
            end
        end
    end
end

-- Scroll end-cap (mesma forma do CardHeader)
local function drawScrollEnd(x, y, h, dir)
    local mid = math.floor((h - 1) / 2)
    for row = 0, h - 1 do
        local dist = math.abs(row - mid)
        local ext
        if dist == 0 or dist == 1 then ext = 4
        elseif dist == 2 then ext = 3
        elseif dist == 3 then ext = 2
        else ext = 1 end
        for col = 0, ext - 1 do
            PixelCanvas.pixel(x + dir * col, y + row, Palette.INK)
        end
    end
    for row = 0, h - 1 do
        local dist = math.abs(row - mid)
        if dist <= 1 then
            PixelCanvas.pixel(x + dir * 0, y + row, Palette.AGED_GOLD)
            PixelCanvas.pixel(x + dir * 1, y + row, Palette.AGED_GOLD_LIGHT)
            PixelCanvas.pixel(x + dir * 2, y + row, Palette.AGED_GOLD)
            PixelCanvas.pixel(x + dir * 3, y + row, Palette.AGED_GOLD_DARK)
        elseif dist == 2 then
            PixelCanvas.pixel(x + dir * 0, y + row, Palette.AGED_GOLD_DARK)
            PixelCanvas.pixel(x + dir * 1, y + row, Palette.AGED_GOLD)
        end
    end
    PixelCanvas.pixel(x + dir * 4, y + mid, Palette.AGED_GOLD_LIGHT)
end

-- Gema facetada 3×5: luz vem do topo-esquerda, sombra no bottom-right.
-- (Evita pillow shading — hue shift vertical dá volume real.)
local function drawGem(cx, cy)
    -- Top: highlight ponta
    PixelCanvas.pixel(cx,     cy - 2, Palette.AGED_GOLD_LIGHT)
    -- Upper faceta (mais clara)
    PixelCanvas.pixel(cx - 1, cy - 1, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx,     cy - 1, Palette.PARCHMENT_LIGHT)   -- sparkle
    PixelCanvas.pixel(cx + 1, cy - 1, Palette.AGED_GOLD)
    -- Linha central (cor principal)
    PixelCanvas.pixel(cx - 1, cy,     Palette.AGED_GOLD)
    PixelCanvas.pixel(cx,     cy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx + 1, cy,     Palette.AGED_GOLD_DARK)
    -- Lower faceta (mais escura — sombra light top-left)
    PixelCanvas.pixel(cx - 1, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx,     cy + 1, Palette.AGED_GOLD)
    PixelCanvas.pixel(cx + 1, cy + 1, Palette.AGED_GOLD_DARK)
    -- Bottom: ponta sombra
    PixelCanvas.pixel(cx,     cy + 2, Palette.INK)
end

-- L-bracket 3×3 em cada canto — substitui os 4 dots antigos que não liam a 1x.
-- dx,dy: direção do L (-1,-1 top-left / +1,-1 top-right / etc).
local function drawCornerBracket(x, y, dx, dy)
    -- Linha principal (3px em cada direção) — cor principal dourada
    for i = 0, 2 do
        PixelCanvas.pixel(x + dx * i, y,        Palette.AGED_GOLD)
        PixelCanvas.pixel(x,          y + dy * i, Palette.AGED_GOLD)
    end
    -- Junção com highlight
    PixelCanvas.pixel(x, y, Palette.AGED_GOLD_LIGHT)
    -- Faíscas nas pontas (dá "peso" visual)
    PixelCanvas.pixel(x + dx * 2, y, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(x, y + dy * 2, Palette.AGED_GOLD_LIGHT)
end

-- Disco 7×7 atrás do glifo. Luz top-left: rim mais claro nos pixels do canto
-- superior-esquerdo, INK no resto. Centro recebe "lift" do typeColor com
-- highlight no quadrante NW e shadow no quadrante SE (volume real, não pillow).
local function drawGlyphDisc(cx, cy, typeColor)
    local disc = {
        "  XXX  ",
        " XXXXX ",
        "XXXXXXX",
        "XXXXXXX",
        "XXXXXXX",
        " XXXXX ",
        "  XXX  ",
    }
    for row = 1, #disc do
        local line = disc[row]
        for col = 1, #line do
            if line:sub(col, col) == "X" then
                local px = cx + col - 4
                local py = cy + row - 4
                -- Quadrante NW = highlight (lighten), SE = shadow (darken)
                local dx, dy = px - cx, py - cy
                local color
                if dx < 0 and dy < 0 then
                    color = Palette.lighten(typeColor, 0.35)
                elseif dx > 0 and dy > 0 then
                    color = Palette.darken(typeColor, 0.55)
                else
                    color = typeColor
                end
                PixelCanvas.pixel(px, py, color)
            end
        end
    end
    -- Rim direcional: top-left = AGED_GOLD_LIGHT (luz), bottom-right = INK (sombra)
    local rimNW = { {0,-3},{1,-3},{-1,-3},{2,-2},{-2,-2},{3,-1},{-3,-1},{-3,0},{-3,1},{-2,2} }
    local rimSE = { {3,0},{3,1},{2,2},{0,3},{-1,3},{1,3} }
    for _, p in ipairs(rimNW) do
        PixelCanvas.pixel(cx + p[1], cy + p[2], Palette.AGED_GOLD)
    end
    for _, p in ipairs(rimSE) do
        PixelCanvas.pixel(cx + p[1], cy + p[2], Palette.INK)
    end
    -- Shine: ponto branco top-left (catchlight)
    PixelCanvas.pixel(cx - 1, cy - 1, Palette.PARCHMENT_LIGHT)
end

function CardStatsFooter.draw(w, h, card)
    local fh = CardStatsFooter.HEIGHT
    local fy = h - fh - 1
    local typeColor = Palette.forCardType(card.type) or Palette.PARCHMENT_DARK

    -- Footer ocupa width completa (sem inset) — pedido do user
    local bx, by = 1, fy
    local bw, bh = w - 2, fh

    -- Sombra externa embaixo do banner
    PixelCanvas.rect(bx, by + bh, bw, 1, { 0, 0, 0, 0.7 })

    -- ===== FUNDO COM 2 TONS DE INK (vertical gradient sutil) =====
    -- Top half: ink levemente clareado (mistura com parchment_dark)
    -- Bottom half: ink puro (mais escuro) — dá sensação de profundidade
    -- vinda da iluminação top-left, sem padrão visual concorrente.
    local inkTop    = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.18)
    local inkBottom = Palette.INK
    PixelCanvas.rect(bx, by,                 bw, math.floor(bh / 2), inkTop)
    PixelCanvas.rect(bx, by + math.floor(bh / 2), bw, math.ceil(bh / 2), inkBottom)

    -- ===== TYPE-STRIPE com hue shifting (3 rows: highlight/main/shadow) =====
    -- Luz vinda de cima: row superior = lighten, row central = cor pura,
    -- row inferior = darken. Dá relevo real à faixa colorida.
    local stripeY = by + math.floor(bh / 2) - 1
    PixelCanvas.hline(bx + 1, stripeY,     bw - 2, Palette.lighten(typeColor, 0.25))
    PixelCanvas.hline(bx + 1, stripeY + 1, bw - 2, typeColor)
    PixelCanvas.hline(bx + 1, stripeY + 2, bw - 2, Palette.darken(typeColor, 0.55))

    -- ===== BEVEL DIRECIONAL (luz top-left, sombra bottom-right) =====
    -- Substitui o "pillow shading" antigo (rectOutline uniforme).
    -- Borda externa
    PixelCanvas.hline(bx, by, bw, Palette.AGED_GOLD_LIGHT)         -- top: highlight
    PixelCanvas.vline(bx, by, bh, Palette.AGED_GOLD)               -- left: gold
    PixelCanvas.hline(bx, by + bh - 1, bw, Palette.AGED_GOLD_DARK) -- bottom: shadow
    PixelCanvas.vline(bx + bw - 1, by, bh, Palette.AGED_GOLD_DARK) -- right: shadow
    -- Borda interna (1px dentro)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.AGED_GOLD)
    PixelCanvas.vline(bx + 1, by + 1, bh - 2, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, { 0, 0, 0, 0.8 })
    PixelCanvas.vline(bx + bw - 2, by + 1, bh - 2, Palette.INK)

    -- ===== CORNER BRACKETS (substitui os 4 dots antigos) =====
    -- L-shaped 3px em cada canto, dão "moldura" de placa metálica.
    drawCornerBracket(bx + 2,        by + 2,         1,  1)  -- top-left
    drawCornerBracket(bx + bw - 3,   by + 2,        -1,  1)  -- top-right
    drawCornerBracket(bx + 2,        by + bh - 3,    1, -1)  -- bottom-left
    drawCornerBracket(bx + bw - 3,   by + bh - 3,   -1, -1)  -- bottom-right

    -- Gemas facetadas separadoras (meio do banner — substitui diamonds antigos)
    drawGem(bx + 7,        by + math.floor(bh / 2))
    drawGem(bx + bw - 8,   by + math.floor(bh / 2))

    -- Label à esquerda — BOLD multi-pass pra legibilidade (fonte 10)
    local font = PixelFont.get(10)
    love.graphics.setFont(font)
    local label = labelFor(card.type)
    local labelX = bx + 10
    local labelY = by + math.floor((bh - font:getHeight()) / 2)
    -- Outline preto 8-direções
    love.graphics.setColor(0, 0, 0, 1)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                love.graphics.print(label, labelX + dx, labelY + dy)
            end
        end
    end
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    love.graphics.print(label, labelX, labelY)

    -- Divisor vertical entre label e stat
    local labelW = font:getWidth(label)
    local divX = labelX + labelW + 3
    PixelCanvas.vline(divX, by + 3, bh - 6, Palette.AGED_GOLD)

    -- Glyph disc + stat à direita
    local value
    if card.type == "attack" and (card.attack or 0) > 0 then
        value = tostring(card.attack)
    elseif card.type == "defense" and (card.defense or 0) > 0 then
        value = tostring(card.defense)
    end

    local glyphName = GLYPH_NAMES[card.type]
    local statFont = PixelFont.get(12)
    local valueW = value and statFont:getWidth(value) or 0

    -- Disco do glyph (7×7) próximo ao valor
    local discCX = bx + bw - 8 - valueW - 5
    local discCY = by + math.floor(bh / 2)
    drawGlyphDisc(discCX, discCY, typeColor)

    -- Glyph por cima do disco
    if glyphName then
        local pngGlyph = tryLoadGlyph(glyphName)
        if pngGlyph then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(pngGlyph, discCX - 3, discCY - 3, 0,
                               6 / pngGlyph:getWidth(), 6 / pngGlyph:getHeight())
        else
            drawProceduralGlyph(glyphName, discCX - 2, discCY - 2, Palette.AGED_GOLD_LIGHT)
        end
    end

    -- Valor à direita — BOLD multi-pass
    if value then
        love.graphics.setFont(statFont)
        local vx = bx + bw - 7 - valueW
        local vy = by + math.floor((bh - statFont:getHeight()) / 2)
        love.graphics.setColor(0, 0, 0, 1)
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    love.graphics.print(value, vx + dx, vy + dy)
                end
            end
        end
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
        love.graphics.print(value, vx, vy)
    end
end

function CardStatsFooter.clearCache()
    glyphCache = {}
    glyphMissCache = {}
end

return CardStatsFooter
