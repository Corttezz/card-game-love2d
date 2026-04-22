-- src/ui/card/components/CardRaritySeal.lua
-- Selo circular de raridade no canto superior direito (11px).
-- Renderiza PNG do PixelLab (assets/sprites/ui/seal_<rarity>.png) quando disponível;
-- fallback procedural simples (disco + cor + halo lendário).
--
-- API: CardRaritySeal.draw(w, rarity)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardRaritySeal = {}

CardRaritySeal.SIZE = 11

-- ===== Cache dos PNG seals =====
local _sealCache = {}
local _sealMisses = {}
local function loadSeal(rarity)
    if _sealCache[rarity] then return _sealCache[rarity] end
    if _sealMisses[rarity] then return nil end
    local path = "assets/sprites/ui/seal_" .. rarity .. ".png"
    if not love.filesystem.getInfo(path) then
        _sealMisses[rarity] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        _sealMisses[rarity] = true
        return nil
    end
    img:setFilter("nearest", "nearest")
    _sealCache[rarity] = img
    return img
end

-- ===== Fallback procedural =====
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

local function drawProcedural(ox, oy, size, rarity, color)
    -- Halo lendário (faíscas douradas)
    if rarity == "legendary" then
        PixelCanvas.pixel(ox - 1, oy + 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox + size, oy + 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox, oy - 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox + size - 1, oy - 1, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox - 1, oy + size - 2, Palette.AGED_GOLD)
        PixelCanvas.pixel(ox + size, oy + size - 2, Palette.AGED_GOLD)
    end
    drawCircle(ox, oy, size, color, Palette.INK)
    local core = rarity == "legendary" and Palette.AGED_GOLD_LIGHT
              or rarity == "rare" and Palette.PARCHMENT_LIGHT
              or rarity == "uncommon" and Palette.PARCHMENT_LIGHT
              or Palette.PARCHMENT_DARK
    PixelCanvas.rect(ox + 3, oy + 3, size - 6, size - 6, core)
    PixelCanvas.pixel(ox + 4, oy + 4, Palette.PARCHMENT_LIGHT)
end

function CardRaritySeal.draw(w, rarity)
    rarity = rarity or "common"
    local size = CardRaritySeal.SIZE
    local ox = w - size - 1
    local oy = 1

    local png = loadSeal(rarity)
    if png then
        -- Renderiza PNG escalado para size×size com nearest filter (já está setado no load).
        local sx = size / png:getWidth()
        local sy = size / png:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(png, ox, oy, 0, sx, sy)
        -- Halo dourado pra legendary fica à mostra fora do PNG
        if rarity == "legendary" then
            PixelCanvas.pixel(ox - 1, oy + 1, Palette.AGED_GOLD)
            PixelCanvas.pixel(ox + size, oy + 1, Palette.AGED_GOLD)
            PixelCanvas.pixel(ox - 1, oy + size - 2, Palette.AGED_GOLD)
            PixelCanvas.pixel(ox + size, oy + size - 2, Palette.AGED_GOLD)
        end
    else
        -- Fallback procedural (mesma estética antiga)
        local color = Palette.forRarity(rarity)
        drawProcedural(ox, oy, size, rarity, color)
    end
end

return CardRaritySeal
