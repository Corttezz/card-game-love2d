-- src/ui/card/components/joker/JokerHeader.lua
-- Banner ornamentado do nome em tema TAROT (navy + dourado).
-- Compartilha o mesmo padrão de raridade do CardHeader, mas com paleta diferente:
--   - Fundo TAROT_NAVY em vez de INK
--   - Filete TAROT_GOLD em vez de AGED_GOLD
--   - Texto TAROT_CREAM
--   - Ornamentos por raridade (diamond / leaf / ruby / medallion)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")

local JokerHeader = {}

JokerHeader.HEIGHT = 16  -- mantido pequeno pra preservar área do art slot

-- Cache de fundos PNG de banner joker por raridade.
-- Paths: assets/sprites/ui/banner_joker_<rarity>.png (fallback: banner_<rarity>.png)
-- Retorna { image, quad, srcW, srcH } com bottom 4 rows recortados (mesma razão
-- do CardHeader: a borda inferior do PNG cria "shelf" feio sob o art slot).
local _bannerCache  = {}
local _bannerMisses = {}
function JokerHeader._getBannerBg(rarity)
    rarity = rarity or "common"
    if _bannerCache[rarity] then return _bannerCache[rarity] end
    if _bannerMisses[rarity] then return nil end
    local paths = {
        "assets/sprites/ui/banner_joker_" .. rarity .. ".png",
        "assets/sprites/ui/banner_" .. rarity .. ".png",
    }
    for _, path in ipairs(paths) do
        if love.filesystem.getInfo(path) then
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                local iw, ih = img:getWidth(), img:getHeight()
                local cropH = math.max(1, ih - 4)
                local quad = love.graphics.newQuad(0, 0, iw, cropH, iw, ih)
                local entry = { image = img, quad = quad, srcW = iw, srcH = cropH }
                _bannerCache[rarity] = entry
                return entry
            end
        end
    end
    _bannerMisses[rarity] = true
    return nil
end

local function styleFor(rarity)
    rarity = rarity or "common"
    if rarity == "uncommon" then
        return {
            outer    = Palette.TAROT_GOLD,
            innerHi  = Palette.AGED_GOLD_LIGHT,
            accent   = Palette.MOSS,
            accentHi = Palette.GREEN_BRIGHT,
            gem      = Palette.MOSS,
            edgeKind = "leaf",
            topKind  = "dots_uncommon",
        }
    elseif rarity == "rare" then
        return {
            outer    = Palette.TAROT_GOLD,
            innerHi  = Palette.AGED_GOLD_LIGHT,
            accent   = Palette.BLOOD,
            accentHi = Palette.PARCHMENT_LIGHT,
            gem      = Palette.BLOOD,
            edgeKind = "ruby",
            topKind  = "crown_rare",
        }
    elseif rarity == "legendary" then
        return {
            outer    = Palette.AGED_GOLD_LIGHT,
            innerHi  = Palette.PARCHMENT_LIGHT,
            accent   = Palette.TAROT_GOLD,
            accentHi = Palette.PARCHMENT_LIGHT,
            gem      = Palette.AGED_GOLD_LIGHT,
            edgeKind = "medallion",
            topKind  = "sparkles",
        }
    else
        return {
            outer    = Palette.TAROT_GOLD,
            innerHi  = Palette.TAROT_GOLD_DARK,
            accent   = Palette.TAROT_GOLD,
            accentHi = Palette.AGED_GOLD_LIGHT,
            gem      = Palette.TAROT_GOLD,
            edgeKind = "diamond",
            topKind  = "dots_simple",
        }
    end
end

-- ===== End-cap ornaments =====

local function drawDiamondSimple(cx, cy, st)
    PixelCanvas.pixel(cx,     cy - 1, st.accentHi)
    PixelCanvas.pixel(cx - 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy,     st.accentHi)
    PixelCanvas.pixel(cx + 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.TAROT_GOLD_DARK)
end

local function drawLeaf(cx, cy, st)
    PixelCanvas.pixel(cx,     cy - 2, st.accentHi)
    PixelCanvas.pixel(cx - 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx + 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx,     cy - 1, st.accentHi)
    PixelCanvas.pixel(cx - 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy,     Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx + 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx,     cy + 2, Palette.AGED_GOLD_DARK)
end

local function drawRuby(cx, cy, st)
    PixelCanvas.pixel(cx,     cy - 2, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx - 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx,     cy - 1, st.accentHi)
    PixelCanvas.pixel(cx + 1, cy - 1, st.accent)
    PixelCanvas.pixel(cx - 1, cy,     Palette.BLOOD_DARK)
    PixelCanvas.pixel(cx,     cy,     st.accent)
    PixelCanvas.pixel(cx + 1, cy,     Palette.BLOOD_DARK)
    PixelCanvas.pixel(cx - 1, cy + 1, st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.BLOOD_DARK)
    PixelCanvas.pixel(cx + 1, cy + 1, st.accent)
    PixelCanvas.pixel(cx,     cy + 2, Palette.INK)
end

local function drawMedallion(cx, cy, st)
    -- Medalhão compacto 3x3 (menor que CardHeader pra dar espaço pro nome no joker)
    PixelCanvas.pixel(cx,     cy - 1, st.accent)
    PixelCanvas.pixel(cx - 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy,     st.accentHi)
    PixelCanvas.pixel(cx + 1, cy,     st.accent)
    PixelCanvas.pixel(cx,     cy + 1, Palette.AGED_GOLD_DARK)
    -- Halo (4 pixels nos diagonais externos)
    PixelCanvas.pixel(cx - 1, cy - 1, st.gem)
    PixelCanvas.pixel(cx + 1, cy - 1, st.gem)
    PixelCanvas.pixel(cx - 1, cy + 1, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(cx + 1, cy + 1, Palette.AGED_GOLD_DARK)
end

local function drawEndCap(kind, cx, cy, st)
    if     kind == "leaf"      then drawLeaf(cx, cy, st)
    elseif kind == "ruby"      then drawRuby(cx, cy, st)
    elseif kind == "medallion" then drawMedallion(cx, cy, st)
    else                            drawDiamondSimple(cx, cy, st)
    end
end

-- ===== Top trim =====

local function drawTopDotsSimple(bx, by, bw, st)
    for i = 0, 2 do
        local px = bx + 12 + i * math.floor((bw - 24) / 3)
        PixelCanvas.pixel(px, by, st.accentHi)
    end
end

local function drawTopDotsUncommon(bx, by, bw, st)
    for i = 0, 4 do
        local px = bx + 10 + i * math.floor((bw - 20) / 4)
        if i % 2 == 0 then
            PixelCanvas.pixel(px, by,     st.accent)
            PixelCanvas.pixel(px, by - 1, st.accentHi)
        else
            PixelCanvas.pixel(px, by, Palette.AGED_GOLD_LIGHT)
        end
    end
end

local function drawTopCrownRare(bx, by, bw, st)
    local positions = { 12, math.floor(bw / 2), bw - 13 }
    for _, dx in ipairs(positions) do
        local px = bx + dx
        PixelCanvas.pixel(px,     by - 2, Palette.AGED_GOLD_LIGHT)
        PixelCanvas.pixel(px - 1, by - 1, st.accent)
        PixelCanvas.pixel(px,     by - 1, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(px + 1, by - 1, st.accent)
        PixelCanvas.pixel(px,     by,     Palette.BLOOD_DARK)
    end
    PixelCanvas.pixel(bx + math.floor(bw * 0.30), by, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(bx + math.floor(bw * 0.70), by, Palette.AGED_GOLD_LIGHT)
end

local function drawTopSparklesLegendary(bx, by, bw, st)
    local positions = {
        { bx + 12,                       0 },
        { bx + math.floor(bw * 0.30),   -1 },
        { bx + math.floor(bw / 2),       0 },
        { bx + math.floor(bw * 0.70),   -1 },
        { bx + bw - 13,                  0 },
    }
    for i, p in ipairs(positions) do
        local px, dy = p[1], p[2]
        local cy = by + dy
        if i % 2 == 1 then
            PixelCanvas.pixel(px,     cy - 1, st.accentHi)
            PixelCanvas.pixel(px - 1, cy,     st.gem)
            PixelCanvas.pixel(px,     cy,     st.accentHi)
            PixelCanvas.pixel(px + 1, cy,     st.gem)
            PixelCanvas.pixel(px,     cy + 1, st.gem)
        else
            PixelCanvas.pixel(px, cy,     st.accentHi)
            PixelCanvas.pixel(px, cy - 1, st.accent)
        end
    end
end

local function drawTopTrim(kind, bx, by, bw, st)
    if     kind == "dots_uncommon" then drawTopDotsUncommon(bx, by, bw, st)
    elseif kind == "crown_rare"    then drawTopCrownRare(bx, by, bw, st)
    elseif kind == "sparkles"      then drawTopSparklesLegendary(bx, by, bw, st)
    else                                drawTopDotsSimple(bx, by, bw, st)
    end
end

local function drawBottomTrim(rarity, bx, by, bw, bh, st)
    if rarity == "legendary" then
        PixelCanvas.pixel(bx + 4,        by + bh,     st.accent)
        PixelCanvas.pixel(bx + 4,        by + bh + 1, Palette.AGED_GOLD_DARK)
        PixelCanvas.pixel(bx + bw - 5,   by + bh,     st.accent)
        PixelCanvas.pixel(bx + bw - 5,   by + bh + 1, Palette.AGED_GOLD_DARK)
        PixelCanvas.pixel(bx + math.floor(bw / 2), by + bh,     Palette.AGED_GOLD_LIGHT)
    elseif rarity == "rare" then
        PixelCanvas.hline(bx + 6, by + bh, bw - 12, Palette.BLOOD_DARK)
    elseif rarity == "uncommon" then
        for i = bx + 8, bx + bw - 8, 4 do
            PixelCanvas.pixel(i, by + bh, st.accent)
        end
    end
end

function JokerHeader.draw(w, cardName, rarity)
    local h  = JokerHeader.HEIGHT
    local st = styleFor(rarity)
    local bx, by = 13, 1
    local bw, bh = w - 26, h - 1

    -- Tenta carregar PNG de fundo joker por raridade
    local bgEntry = JokerHeader._getBannerBg(rarity)
    if bgEntry then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgEntry.image, bgEntry.quad, bx, by, 0,
                           bw / bgEntry.srcW, bh / bgEntry.srcH)
        -- NÃO desenha sombra externa nem ornamentos por cima
    else
        -- Fallback procedural: sombra + navy + bevel
        PixelCanvas.rect(bx + 1, by + bh, bw, 1, { 0, 0, 0, 0.6 })
        -- Fallback procedural limpo: navy + bevel duplo + ornamentos por raridade
        PixelCanvas.rect(bx, by, bw, bh, Palette.TAROT_NAVY)
        PixelCanvas.rectOutline(bx, by, bw, bh, st.outer)
        PixelCanvas.rectOutline(bx + 1, by + 1, bw - 2, bh - 2, Palette.TAROT_GOLD_DARK)
        PixelCanvas.hline(bx + 2, by + 2,      bw - 4, st.innerHi or Palette.AGED_GOLD_LIGHT)
        PixelCanvas.hline(bx + 2, by + bh - 3, bw - 4, Palette.TAROT_NAVY_DARK)
        drawEndCap(st.edgeKind, bx + 4,        by + math.floor(bh / 2), st)
        drawEndCap(st.edgeKind, bx + bw - 5,   by + math.floor(bh / 2), st)
        drawTopTrim(st.topKind, bx, by, bw, st)
        drawBottomTrim(rarity, bx, by, bw, bh, st)
    end

    -- ===== TEXTO =====
    -- Tenta tamanhos 10 → 9 → 8 → 7 antes de truncar (preserva nome quando possivel).
    local utf8 = require("utf8")
    local name = cardName or "?"
    local maxW = bw - 12
    local font
    for _, size in ipairs({ 10, 9, 8, 7 }) do
        local f = PixelFont.get(size)
        if f:getWidth(name) <= maxW then
            font = f
            break
        end
    end
    if not font then
        -- Truncate por codepoint UTF-8 no menor tamanho
        font = PixelFont.get(7)
        local out = name
        local suffix = "."
        while font:getWidth(out) > maxW and utf8.len(out) > 1 do
            local cutAt = utf8.offset(out, -1)
            if not cutAt then break end
            out = out:sub(1, cutAt - 1) .. suffix
            suffix = ""
        end
        name = out
    end
    love.graphics.setFont(font)
    local tw = font:getWidth(name)
    local tx = bx + math.floor((bw - tw) / 2)
    local ty = by + math.floor((bh - font:getHeight()) / 2)

    -- Outline preto
    love.graphics.setColor(0, 0, 0, 1)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                love.graphics.print(name, tx + dx, ty + dy)
            end
        end
    end
    -- Texto sempre cream (mantém legibilidade — raridade muda só os ornamentos)
    love.graphics.setColor(Palette.TAROT_CREAM)
    love.graphics.print(name, tx, ty)
end

return JokerHeader
