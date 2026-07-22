-- src/ui/card/components/CardStatsFooter.lua
-- Rodapé ornamentado v2 (Jul/2026, pedido do dono: "mais trabalhado").
-- Layout: [medalhão-selo c/ glifo] LABEL ‹corrente por tipo› [cartucho c/ valor]
--
-- Identidade POR TIPO (a v1 era uma listra reta atravessando o banner — lia
-- como "laser", não ornamento):
--   attack  → corrente de LÂMINAS (chevrons sangue)
--   defense → banda RIVETADA (aço, rebites)
--   effect  → VINHA (musgo, losangos e brotos)
--   joker   → constelação (fallback — jokers usam JokerFooter)
-- O valor mora num CARTUCHO octogonal (placa engastada), não solto no ar.

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")
local I18n        = require("src.i18n.I18n")

local CardStatsFooter = {}

CardStatsFooter.HEIGHT = 20

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

-- L-bracket 3×3 em cada canto (moldura de placa metálica).
local function drawCornerBracket(x, y, dx, dy)
    for i = 0, 2 do
        PixelCanvas.pixel(x + dx * i, y,          Palette.AGED_GOLD)
        PixelCanvas.pixel(x,          y + dy * i, Palette.AGED_GOLD)
    end
    PixelCanvas.pixel(x, y, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(x + dx * 2, y, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(x, y + dy * 2, Palette.AGED_GOLD_LIGHT)
end

-- ===== MEDALHÃO-SELO 13×13 (esquerda): anel de ouro + corpo no typeColor
-- com luz NW / sombra SE, glifo por cima. Substitui o disco 7×7 que lia
-- como "bolinha" na tela.
local MEDAL_HW = { 2, 3, 4, 5, 5, 5, 6, 5, 5, 5, 4, 3, 2 } -- meia-largura por linha

local function drawSealMedallion(cx, cy, typeColor)
    -- Camadas: INK (silhueta) → anel AGED_GOLD → corpo typeColor
    for i, hw in ipairs(MEDAL_HW) do
        PixelCanvas.hline(cx - hw, cy - 7 + i, hw * 2 + 1, Palette.INK)
    end
    for i, hw in ipairs(MEDAL_HW) do
        local r = hw - 1
        if r >= 0 then
            PixelCanvas.hline(cx - r, cy - 7 + i, r * 2 + 1, Palette.AGED_GOLD)
        end
    end
    for i, hw in ipairs(MEDAL_HW) do
        local r = hw - 2
        if r >= 0 then
            PixelCanvas.hline(cx - r, cy - 7 + i, r * 2 + 1, typeColor)
        end
    end
    -- Volume: quadrante NW clareia, SE escurece (nunca pillow)
    for i, hw in ipairs(MEDAL_HW) do
        local r = hw - 2
        local y = cy - 7 + i
        if r >= 1 then
            if y < cy then
                PixelCanvas.hline(cx - r, y, r, Palette.lighten(typeColor, 0.30))
            elseif y > cy then
                PixelCanvas.hline(cx + 1, y, r, Palette.darken(typeColor, 0.45))
            end
        end
    end
    -- Anel: highlight no arco NW, sombra no arco SE
    PixelCanvas.pixel(cx - 3, cy - 5, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx - 4, cy - 4, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx + 3, cy + 5, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 4, cy + 4, Palette.AGED_GOLD_DARK)
    -- Catchlight
    PixelCanvas.pixel(cx - 2, cy - 2, Palette.PARCHMENT_LIGHT)
end

-- ===== CARTUCHO DO VALOR (direita): placa octogonal engastada. Largura
-- dinâmica (valores de 2 dígitos crescem pra dentro). h fixa 15.
local function cartoucheCut(row, hgt)
    local c = 3
    if row < c then return c - row end
    if row >= hgt - c then return row - (hgt - c - 1) end
    return 0
end

local function drawCartouche(x2, cy, cw, typeColor)
    -- x2 = borda DIREITA; retorna x1 (borda esquerda) pro layout.
    local ch = 15
    local x1 = x2 - cw + 1
    local top = cy - 7
    -- Silhueta INK (carimbo 4-dir do corpo octogonal)
    for _, off in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 0, 0 } }) do
        for row = 0, ch - 1 do
            local cut = cartoucheCut(row, ch)
            PixelCanvas.hline(x1 + cut + off[1], top + row + off[2],
                cw - cut * 2, Palette.INK)
        end
    end
    -- Corpo: typeColor escurecido (fundo do número), NW mais claro
    for row = 1, ch - 2 do
        local cut = cartoucheCut(row, ch) + 1
        local bodyW = cw - cut * 2
        if bodyW > 0 then
            local base = Palette.darken(typeColor, 0.35)
            if row <= 5 then base = Palette.darken(typeColor, 0.15) end
            if row >= ch - 4 then base = Palette.darken(typeColor, 0.55) end
            PixelCanvas.hline(x1 + cut, top + row, bodyW, base)
        end
    end
    -- Filete de ouro no topo interno + engaste nas laterais (garras)
    PixelCanvas.hline(x1 + 4, top + 1, cw - 8, Palette.AGED_GOLD)
    PixelCanvas.hline(x1 + 4, top + ch - 2, cw - 8, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x1 - 1, cy, Palette.AGED_GOLD)
    PixelCanvas.pixel(x2 + 1, cy, Palette.AGED_GOLD)
    return x1
end

-- ===== CORRENTES ORNAMENTAIS POR TIPO (entre label e cartucho) =====

-- attack: lâminas — chevrons ">" encadeados em sangue, fio de luz no gume.
local function chainBlades(x1, x2, cy)
    PixelCanvas.hline(x1, cy, x2 - x1 + 1, Palette.BLOOD_DARK)
    for x = x1 + 1, x2 - 2, 4 do
        PixelCanvas.pixel(x,     cy - 1, Palette.BLOOD)
        PixelCanvas.pixel(x + 1, cy,     Palette.lighten(Palette.BLOOD, 0.35))
        PixelCanvas.pixel(x,     cy + 1, Palette.BLOOD_DARK)
    end
end

-- defense: banda rivetada — trilho duplo de aço com rebites 2×2.
local function chainRivets(x1, x2, cy)
    PixelCanvas.hline(x1, cy - 1, x2 - x1 + 1, Palette.STEEL)
    PixelCanvas.hline(x1, cy + 1, x2 - x1 + 1, Palette.darken(Palette.STEEL, 0.4))
    for x = x1 + 2, x2 - 2, 5 do
        PixelCanvas.pixel(x,     cy - 1, Palette.STEEL_LIGHT)
        PixelCanvas.pixel(x + 1, cy - 1, Palette.STEEL)
        PixelCanvas.pixel(x,     cy,     Palette.STEEL)
        PixelCanvas.pixel(x + 1, cy,     Palette.INK)
    end
end

-- effect: vinha — talo com losangos de musgo e brotos claros alternados.
local function chainVine(x1, x2, cy)
    PixelCanvas.hline(x1, cy, x2 - x1 + 1, Palette.PARCHMENT_DARK)
    local n = 0
    for x = x1 + 2, x2 - 2, 5 do
        n = n + 1
        PixelCanvas.pixel(x,     cy - 1, Palette.MOSS)
        PixelCanvas.pixel(x - 1, cy,     Palette.MOSS)
        PixelCanvas.pixel(x + 1, cy,     Palette.MOSS)
        PixelCanvas.pixel(x,     cy + 1, Palette.darken(Palette.MOSS, 0.4))
        PixelCanvas.pixel(x, cy,
            n % 2 == 0 and Palette.GREEN_BRIGHT or Palette.AGED_GOLD_LIGHT)
    end
end

-- fallback (joker via renderStandard, tipo desconhecido): pontos de ouro.
local function chainDots(x1, x2, cy)
    for x = x1 + 1, x2 - 1, 4 do
        PixelCanvas.pixel(x, cy, Palette.AGED_GOLD)
        PixelCanvas.pixel(x + 1, cy, Palette.AGED_GOLD_DARK)
    end
end

local CHAINS = {
    attack  = chainBlades,
    defense = chainRivets,
    effect  = chainVine,
}

function CardStatsFooter.draw(w, h, card)
    local fh = CardStatsFooter.HEIGHT
    local fy = h - fh - 1
    local typeColor = Palette.forCardType(card.type) or Palette.PARCHMENT_DARK

    local bx, by = 1, fy
    local bw, bh = w - 2, fh
    local cy = by + math.floor(bh / 2)

    -- Sombra externa embaixo do banner
    PixelCanvas.rect(bx, by + bh, bw, 1, { 0, 0, 0, 0.7 })

    -- Fundo 2 tons de ink (luz vinda de cima)
    local inkTop = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.18)
    PixelCanvas.rect(bx, by, bw, math.floor(bh / 2), inkTop)
    PixelCanvas.rect(bx, by + math.floor(bh / 2), bw, math.ceil(bh / 2), Palette.INK)

    -- Bevel direcional (luz top-left, sombra bottom-right)
    PixelCanvas.hline(bx, by, bw, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.vline(bx, by, bh, Palette.AGED_GOLD)
    PixelCanvas.hline(bx, by + bh - 1, bw, Palette.AGED_GOLD_DARK)
    PixelCanvas.vline(bx + bw - 1, by, bh, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.AGED_GOLD)
    PixelCanvas.vline(bx + 1, by + 1, bh - 2, Palette.AGED_GOLD_DARK)
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, { 0, 0, 0, 0.8 })
    PixelCanvas.vline(bx + bw - 2, by + 1, bh - 2, Palette.INK)

    -- Corner brackets
    drawCornerBracket(bx + 2,      by + 2,       1,  1)
    drawCornerBracket(bx + bw - 3, by + 2,      -1,  1)
    drawCornerBracket(bx + 2,      by + bh - 3,  1, -1)
    drawCornerBracket(bx + bw - 3, by + bh - 3, -1, -1)

    -- ===== MEDALHÃO-SELO com o glifo do tipo (esquerda) =====
    local medCX = bx + 10
    drawSealMedallion(medCX, cy, typeColor)
    local glyphName = GLYPH_NAMES[card.type]
    if glyphName then
        local pngGlyph = tryLoadGlyph(glyphName)
        if pngGlyph then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(pngGlyph, medCX - 3, cy - 3, 0,
                7 / pngGlyph:getWidth(), 7 / pngGlyph:getHeight())
        else
            drawProceduralGlyph(glyphName, medCX - 2, cy - 2, Palette.AGED_GOLD_LIGHT)
        end
    end

    -- ===== LABEL =====
    local font = PixelFont.get(10)
    love.graphics.setFont(font)
    local label = labelFor(card.type)
    local labelX = bx + 19
    local labelY = by + math.floor((bh - font:getHeight()) / 2)
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
    local labelEnd = labelX + font:getWidth(label)

    -- ===== VALOR no cartucho (direita) — só attack/defense têm número =====
    local value
    if card.type == "attack" and (card.attack or 0) > 0 then
        value = tostring(card.attack)
    elseif card.type == "defense" and (card.defense or 0) > 0 then
        value = tostring(card.defense)
    end

    local chainRight = bx + bw - 6  -- default: corrente vai até perto da borda
    if value then
        local statFont = PixelFont.get(12)
        local valueW = statFont:getWidth(value)
        local cw = math.max(15, valueW + 9)
        local cartX2 = bx + bw - 4
        local cartX1 = drawCartouche(cartX2, cy, cw, typeColor)
        chainRight = cartX1 - 4

        love.graphics.setFont(statFont)
        local vx = cartX1 + math.floor((cw - valueW) / 2)
        -- -1: fonte default imprime o dígito ~2px abaixo do y (ascender) —
        -- mesma lição do badge de custo.
        local vy = by + math.floor((bh - statFont:getHeight()) / 2) - 1
        love.graphics.setColor(0, 0, 0, 1)
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    love.graphics.print(value, vx + dx, vy + dy)
                end
            end
        end
        if (card.upgrades or 0) > 0 then
            love.graphics.setColor(0.55, 0.92, 0.45, 1) -- verde-forja (StS)
        else
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
        end
        love.graphics.print(value, vx, vy)
    end

    -- ===== CORRENTE ORNAMENTAL do tipo, preenchendo o vão =====
    local chainLeft = labelEnd + 5
    if chainRight - chainLeft >= 8 then
        local chain = CHAINS[card.type] or chainDots
        chain(chainLeft, chainRight, cy)
    end
end

function CardStatsFooter.clearCache()
    glyphCache = {}
    glyphMissCache = {}
end

return CardStatsFooter
