-- src/ui/card/components/CardBorder.lua
-- Moldura pixel art densa com ASIMETRIA e DESGASTE orgânico.
-- Cada carta tem variação única (seed via card id) evitando padrão uniforme.
--
-- Camadas:
--   1) Outline INK 1px
--   2) Banda sépia 3 tons
--   3) Filete AGED_GOLD
--   4) Knotwork seccionado (com gaps deliberados — "desgastado")
--   5) Bolts irregulares nos meios (1-2 por lado, não 1 fixo)
--   6) Scrollwork nos cantos
--   7) Aging agressivo: cracks, chunks, tarnish, faded spots (asymétrico)
--   8) Rare/legendary: detalhes extras

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardBorder = {}

-- ===== Cache de sprites ornamentais PixelLab =====
local _sprites = {}
local _spritesLoaded = false
local function loadSprites()
    if _spritesLoaded then return _sprites end
    _spritesLoaded = true
    local files = {
        corner_flourish  = "assets/sprites/ui/corner_flourish.png",
        vertical_divider = "assets/sprites/ui/vertical_divider.png",
        wear_overlay     = "assets/sprites/ui/wear_overlay.png",
        knotwork_strip   = "assets/sprites/ui/knotwork_strip.png",
        edge_medallion   = "assets/sprites/ui/edge_medallion.png",
    }
    for k, path in pairs(files) do
        if love.filesystem.getInfo(path) then
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                _sprites[k] = img
            end
        end
    end
    return _sprites
end

-- Desenha sprite rotacionado e escalado. rot: 0=TL, 1=TR, 2=BR, 3=BL.
local function drawRotatedSprite(img, rot, x, y, w, h)
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx = w / iw
    local sy = h / ih
    love.graphics.setColor(1, 1, 1, 1)
    if rot == 0 then
        love.graphics.draw(img, x, y, 0, sx, sy)
    elseif rot == 1 then
        love.graphics.draw(img, x + w, y, math.pi / 2, sy, sx)
    elseif rot == 2 then
        love.graphics.draw(img, x + w, y + h, math.pi, sx, sy)
    elseif rot == 3 then
        love.graphics.draw(img, x, y + h, -math.pi / 2, sy, sx)
    end
end

-- ===== Bolt com shine =====
local function drawBolt(x, y)
    PixelCanvas.rect(x - 1, y - 1, 5, 5, Palette.INK)
    PixelCanvas.rect(x, y, 3, 3, Palette.AGED_GOLD)
    PixelCanvas.pixel(x, y, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(x + 2, y + 2, Palette.AGED_GOLD_DARK)
    PixelCanvas.pixel(x + 1, y + 1, Palette.INK)
end

-- ===== Scrollwork L-shape 6×6 =====
local function drawCornerScroll(ox, oy, dx, dy, variant)
    variant = variant or 1
    local patterns = {
        -- Variant 1: curva suave
        {
            { 0, 0, "G" }, { 1, 0, "G" }, { 2, 0, "G" },
            { 0, 1, "G" }, { 1, 1, "L" },
            { 0, 2, "G" }, { 2, 2, "d" },
            { 3, 3, "d" }, { 4, 4, "d" }, { 5, 5, "G" },
        },
        -- Variant 2: mais geométrico
        {
            { 0, 0, "G" }, { 1, 0, "L" }, { 2, 0, "G" },
            { 0, 1, "L" }, { 2, 1, "G" },
            { 0, 2, "G" }, { 1, 2, "G" }, { 3, 2, "d" },
            { 3, 3, "G" }, { 4, 4, "d" }, { 5, 5, "G" },
        },
    }
    local pattern = patterns[variant]
    local colors = {
        G = Palette.AGED_GOLD,
        L = Palette.AGED_GOLD_LIGHT,
        d = Palette.AGED_GOLD_DARK,
    }
    for _, p in ipairs(pattern) do
        PixelCanvas.pixel(ox + dx * p[1], oy + dy * p[2], colors[p[3]])
    end
end

-- ===== Knotwork seccionado (padrão com gaps deliberados pra parecer desgastado) =====
-- Pattern básico: pontos duplos alternando com single, com gaps ocasionais.
-- Usa seed pra variar cada carta.
local function drawKnotworkH(y, startX, endX, seed, rareMode)
    local x = startX
    local skip = false
    while x < endX - 2 do
        -- Determinístico: "desgaste" a cada N passos baseado em seed
        local wear = ((x * 7 + seed * 13) % 31 < 4)
        if wear then
            -- Skip: só uma marquinha escura
            PixelCanvas.pixel(x, y, Palette.PARCHMENT_DARK)
            x = x + 4
        else
            -- Pattern rich knot: 3-pixel piece
            PixelCanvas.pixel(x, y, Palette.AGED_GOLD_DARK)
            PixelCanvas.pixel(x + 1, y, Palette.AGED_GOLD_LIGHT)
            PixelCanvas.pixel(x + 2, y, Palette.AGED_GOLD_DARK)
            if rareMode and ((x + seed) % 6 == 0) then
                PixelCanvas.pixel(x + 1, y - 1, Palette.AGED_GOLD)
                PixelCanvas.pixel(x + 1, y + 1, Palette.AGED_GOLD)
            end
            x = x + 4
        end
    end
end

local function drawKnotworkV(x, startY, endY, seed, rareMode)
    local y = startY
    while y < endY - 2 do
        local wear = ((y * 11 + seed * 17) % 29 < 4)
        if wear then
            PixelCanvas.pixel(x, y, Palette.PARCHMENT_DARK)
            y = y + 4
        else
            PixelCanvas.pixel(x, y, Palette.AGED_GOLD_DARK)
            PixelCanvas.pixel(x, y + 1, Palette.AGED_GOLD_LIGHT)
            PixelCanvas.pixel(x, y + 2, Palette.AGED_GOLD_DARK)
            if rareMode and ((y + seed) % 6 == 0) then
                PixelCanvas.pixel(x - 1, y + 1, Palette.AGED_GOLD)
                PixelCanvas.pixel(x + 1, y + 1, Palette.AGED_GOLD)
            end
            y = y + 4
        end
    end
end

-- ===== Asymmetric damage: cracks longos, chunks e faded spots =====
local function drawDamage(w, h, seed)
    -- Cracks longos (3-5 pixels irregulares) em posições random
    local crackCount = 5
    for i = 1, crackCount do
        local edge = ((seed * i * 31) % 4)  -- 0=top 1=right 2=bottom 3=left
        local along, across
        if edge == 0 then  -- top
            along = 12 + (seed * i * 7) % (w - 24)
            across = 1
            PixelCanvas.pixel(along, across, Palette.INK)
            PixelCanvas.pixel(along + 1, across + 1, Palette.INK)
            PixelCanvas.pixel(along, across + 2, Palette.INK)
        elseif edge == 1 then  -- right
            along = 12 + (seed * i * 7) % (h - 24)
            across = w - 2
            PixelCanvas.pixel(across, along, Palette.INK)
            PixelCanvas.pixel(across - 1, along + 1, Palette.INK)
            PixelCanvas.pixel(across - 2, along, Palette.INK)
        elseif edge == 2 then  -- bottom
            along = 12 + (seed * i * 7) % (w - 24)
            across = h - 2
            PixelCanvas.pixel(along, across, Palette.INK)
            PixelCanvas.pixel(along + 1, across - 1, Palette.INK)
            PixelCanvas.pixel(along, across - 2, Palette.INK)
        else  -- left
            along = 12 + (seed * i * 7) % (h - 24)
            across = 1
            PixelCanvas.pixel(across, along, Palette.INK)
            PixelCanvas.pixel(across + 1, along + 1, Palette.INK)
            PixelCanvas.pixel(across + 2, along, Palette.INK)
        end
    end

    -- Chunks faltando (2×2 sepia_dark asymétricos)
    local chunks = 3
    for i = 1, chunks do
        local x = 5 + (seed * i * 23) % (w - 10)
        local y = 5 + (seed * i * 19) % (h - 10)
        -- Só nas bordas externas
        if x < 10 or x > w - 10 or y < 10 or y > h - 10 then
            PixelCanvas.rect(x, y, 2, 2, Palette.PARCHMENT_DARK)
            PixelCanvas.pixel(x, y, Palette.INK)
        end
    end

    -- Tarnish spots (escurecimento dispersos, variados em tamanho)
    for i = 1, 15 do
        local x = (seed * i * 11 + 5) % (w - 4) + 2
        local y = (seed * i * 13 + 3) % (h - 4) + 2
        -- Só na banda sépia (bordas externas)
        if x < 8 or x > w - 9 or y < 8 or y > h - 9 then
            PixelCanvas.pixel(x, y, Palette.PARCHMENT_DARK)
        end
    end

    -- Faded spot (highlight envelhecido) — 3×3 cluster
    local fx = 5 + (seed * 29) % (w - 10)
    local fy = 5 + (seed * 37) % (h - 10)
    if fx < 10 or fx > w - 12 or fy < 10 or fy > h - 12 then
        PixelCanvas.pixel(fx, fy, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(fx + 1, fy, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(fx, fy + 1, Palette.PARCHMENT_LIGHT)
    end
end

-- ===== Rarity corner brackets (substitui filete colorido full-perimeter) =====
-- Desenha 4 brackets em L nos cantos do art slot (offset interno 9,9).
-- Complexidade escala por raridade:
--   uncommon  → L simples 5×5 verde MOSS
--   rare      → L 7×7 BLOOD + curl pixel + gem central
--   legendary → L 8×8 AGED_GOLD c/ borda interna AGED_GOLD_LIGHT + gem dupla + 2 sparkles
-- common/basic não desenha (cartas limpas).
local function drawCorner(ox, oy, dx, dy, size, mainColor, highlightColor, gem, sparkle)
    -- L-bracket: arm horizontal e vertical de comprimento `size`, com outline INK
    -- Arm horizontal (size px)
    for i = 0, size - 1 do
        PixelCanvas.pixel(ox + dx * i, oy, mainColor)
    end
    -- Arm vertical
    for i = 0, size - 1 do
        PixelCanvas.pixel(ox, oy + dy * i, mainColor)
    end
    -- Cantos arredondados (notch INK no inner corner)
    PixelCanvas.pixel(ox + dx, oy + dy, Palette.INK)
    -- Highlight 1px ao longo do bracket externo (relevo)
    if highlightColor then
        for i = 1, size - 2 do
            PixelCanvas.pixel(ox + dx * i, oy - dy, highlightColor)
            PixelCanvas.pixel(ox - dx, oy + dy * i, highlightColor)
        end
    end
    -- Gema no joelho do L (1 pixel central)
    if gem then
        PixelCanvas.pixel(ox + dx, oy, gem)
        PixelCanvas.pixel(ox, oy + dy, gem)
    end
    -- Sparkle: 2 pixels diagonais distantes
    if sparkle then
        PixelCanvas.pixel(ox + dx * (size + 1), oy + dy * (size + 1), sparkle)
        PixelCanvas.pixel(ox + dx * (size + 2), oy + dy * (size + 2), Palette.AGED_GOLD)
    end
end

local function drawRarityCorners(w, h, rarity, seed)
    if rarity == "common" or rarity == "basic" or not rarity then return end
    -- INSET 13: dentro do filete dourado, fora dos corner_flourish (PNG 18×18)
    local INSET = 13
    local x1, y1 = INSET, INSET
    local x2, y2 = w - 1 - INSET, INSET
    local x3, y3 = INSET, h - 1 - INSET
    local x4, y4 = w - 1 - INSET, h - 1 - INSET

    if rarity == "uncommon" then
        -- L 8px MOSS + highlight GREEN_BRIGHT (mais visível)
        local s = 8
        drawCorner(x1, y1,  1,  1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)
        drawCorner(x2, y2, -1,  1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)
        drawCorner(x3, y3,  1, -1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)
        drawCorner(x4, y4, -1, -1, s, Palette.MOSS, Palette.GREEN_BRIGHT, nil, nil)

    elseif rarity == "rare" then
        -- L 10px BLOOD + highlight BLOOD_DARK + gem central AGED_GOLD
        local s = 10
        drawCorner(x1, y1,  1,  1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)
        drawCorner(x2, y2, -1,  1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)
        drawCorner(x3, y3,  1, -1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)
        drawCorner(x4, y4, -1, -1, s, Palette.BLOOD, Palette.BLOOD_DARK, Palette.AGED_GOLD, nil)

    elseif rarity == "legendary" then
        -- L 12px AGED_GOLD + highlight AGED_GOLD_LIGHT + gem PARCHMENT + sparkle
        local s = 12
        drawCorner(x1, y1,  1,  1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
        drawCorner(x2, y2, -1,  1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
        drawCorner(x3, y3,  1, -1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
        drawCorner(x4, y4, -1, -1, s, Palette.AGED_GOLD, Palette.AGED_GOLD_LIGHT, Palette.PARCHMENT_LIGHT, Palette.AGED_GOLD_LIGHT)
    end
end

-- ===== Bolts variados (1-2 por lado, posição variável) =====
local function drawAsymmetricBolts(w, h, seed)
    -- Top: 1 ou 2 bolts em posição variável
    local topCount = 1 + (seed % 2)
    for i = 0, topCount - 1 do
        local bx = 15 + ((seed * (i + 1) * 7) % (w - 30))
        drawBolt(bx, 1)
    end
    -- Bottom
    local botCount = 1 + ((seed * 3) % 2)
    for i = 0, botCount - 1 do
        local bx = 15 + ((seed * (i + 1) * 11) % (w - 30))
        drawBolt(bx, h - 4)
    end
    -- Left
    drawBolt(1, 15 + ((seed * 13) % (h - 30)))
    -- Right
    drawBolt(w - 4, 15 + ((seed * 17) % (h - 30)))
end

function CardBorder.draw(w, h, cardType, rarity, cardId)
    local sprites = loadSprites()
    local typeColor   = Palette.forCardType(cardType) or Palette.PARCHMENT_DARK
    local rarityColor = Palette.forRarity(rarity) or Palette.PARCHMENT_DARK

    -- Seed determinístico por carta
    local seed = 1
    if cardId then
        for i = 1, #cardId do
            seed = (seed * 31 + cardId:byte(i)) % 997
        end
    end

    -- CAMADAS BASE (mais espessas — borda 8px total com 6 filetes)
    -- 1) Outline externo INK
    PixelCanvas.rectOutline(0, 0, w, h, Palette.INK)
    -- 2) Sépia dark (anel mais escuro)
    PixelCanvas.rectOutline(1, 1, w - 2, h - 2, Palette.PARCHMENT_DARK)
    -- 3) Sépia mid (claro envelhecido)
    PixelCanvas.rectOutline(2, 2, w - 4, h - 4, Palette.PARCHMENT)
    -- 4) Sépia dark (sombra interna)
    PixelCanvas.rectOutline(3, 3, w - 6, h - 6, Palette.PARCHMENT_DARK)
    -- 5) INK (linha escura embaixo do filete dourado)
    PixelCanvas.rectOutline(4, 4, w - 8, h - 8, Palette.INK)
    -- 6) AGED_GOLD brilhante (filete principal)
    PixelCanvas.rectOutline(5, 5, w - 10, h - 10, Palette.AGED_GOLD)
    -- 7) AGED_GOLD_DARK (relevo dentro do gold)
    PixelCanvas.rectOutline(6, 6, w - 12, h - 12, Palette.AGED_GOLD_DARK)

    -- HORIZONTAL KNOTWORK STRIP (PNG) top + bottom — principal ornamento da borda
    if sprites.knotwork_strip then
        local strip = sprites.knotwork_strip
        local sw, sh = strip:getWidth(), strip:getHeight()
        local targetW = w - 16
        local targetH = 10
        local scaleX = targetW / sw
        local scaleY = targetH / sh
        love.graphics.setColor(1, 1, 1, 1)
        -- Topo
        love.graphics.draw(strip, 8, 1, 0, scaleX, scaleY)
        -- Base (flip vertical)
        love.graphics.draw(strip, 8, h - 1, 0, scaleX, -scaleY)
    end

    -- VERTICAL DIVIDERS (PNG) nas 2 laterais — rotacionado vertical
    if sprites.vertical_divider then
        local div = sprites.vertical_divider
        local dw, dh = 6, math.min(h - 32, 60)
        local sw, sh = div:getWidth(), div:getHeight()
        local scaleX = dw / sw
        local scaleY = dh / sh
        local leftY = 16 + (seed % 12)
        local rightY = 16 + ((seed * 7) % 12)
        love.graphics.draw(div, 1, leftY, 0, scaleX, scaleY)
        love.graphics.draw(div, w - 1 - dw, rightY, 0, scaleX, scaleY)
    end

    -- EDGE MEDALLIONS: disco ornamental PNG nos meios das 4 bordas
    if sprites.edge_medallion then
        local med = sprites.edge_medallion
        local ms = 10
        local sw, sh = med:getWidth(), med:getHeight()
        local s = ms / sw
        love.graphics.setColor(1, 1, 1, 1)
        -- Top middle
        love.graphics.draw(med, math.floor((w - ms) / 2), 0, 0, s, s)
        -- Bottom middle
        love.graphics.draw(med, math.floor((w - ms) / 2), h - ms, 0, s, s)
        -- Left middle
        love.graphics.draw(med, 0, math.floor((h - ms) / 2), 0, s, s)
        -- Right middle
        love.graphics.draw(med, w - ms, math.floor((h - ms) / 2), 0, s, s)
    end

    -- CORNER FLOURISHES (PNG rotacionado nos 4 cantos — maior agora)
    if sprites.corner_flourish then
        local cw, ch = 18, 18
        drawRotatedSprite(sprites.corner_flourish, 0, 0, 0, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 1, w - cw, 0, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 2, w - cw, h - ch, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 3, 0, h - ch, cw, ch)
    else
        drawCornerScroll(2, 2, 1, 1, 1)
        drawCornerScroll(w - 3, 2, -1, 1, 1)
        drawCornerScroll(2, h - 3, 1, -1, 2)
        drawCornerScroll(w - 3, h - 3, -1, -1, 2)
    end

    -- DANO asimétrico
    drawDamage(w, h, seed)

    -- WEAR OVERLAY (PNG multiply bem sutil cobrindo toda a carta — dá aparência antiga)
    if sprites.wear_overlay then
        love.graphics.setColor(1, 1, 1, 0.20)
        love.graphics.draw(sprites.wear_overlay, 0, 0, 0,
                           w / sprites.wear_overlay:getWidth(),
                           h / sprites.wear_overlay:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- RARITY: substitui o filete interno por CORNER-PIECES ornamentais.
    -- Cada raridade tem brackets em L nos 4 cantos com complexidade crescente.
    -- (Não desenha nada para common/basic — cartas comuns ficam clean.)
    drawRarityCorners(w, h, rarity, seed)
end

return CardBorder
