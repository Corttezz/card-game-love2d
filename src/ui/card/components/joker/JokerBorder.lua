-- src/ui/card/components/joker/JokerBorder.lua
-- Borda do joker (tarot) — mesma densidade do CardBorder, mas tema navy + gold.
-- Reutiliza os mesmos PNGs ornamentais (corner_flourish, knotwork_strip,
-- vertical_divider, edge_medallion, wear_overlay).

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local JokerBorder = {}

-- Cache de sprites PixelLab
local _sprites = {}
local _loaded = false
local function loadSprites()
    if _loaded then return _sprites end
    _loaded = true
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

function JokerBorder.draw(w, h, rarity)
    local sprites = loadSprites()

    -- CAMADAS BASE — tarot navy escuro + filete dourado
    -- 1) Outline INK
    PixelCanvas.rectOutline(0, 0, w, h, Palette.INK)
    -- 2) Navy escuro
    PixelCanvas.rectOutline(1, 1, w - 2, h - 2, Palette.TAROT_NAVY_DARK)
    PixelCanvas.rectOutline(2, 2, w - 4, h - 4, Palette.TAROT_NAVY_DARK)
    -- 3) Navy mid
    PixelCanvas.rectOutline(3, 3, w - 6, h - 6, Palette.TAROT_NAVY)
    -- 4) Navy escuro (sombra)
    PixelCanvas.rectOutline(4, 4, w - 8, h - 8, Palette.TAROT_NAVY_DARK)
    -- 5) INK
    PixelCanvas.rectOutline(5, 5, w - 10, h - 10, Palette.INK)
    -- 6) Gold tarot brilhante
    PixelCanvas.rectOutline(6, 6, w - 12, h - 12, Palette.TAROT_GOLD)
    -- 7) Gold tarot dark (relevo)
    PixelCanvas.rectOutline(7, 7, w - 14, h - 14, Palette.TAROT_GOLD_DARK)

    -- KNOTWORK STRIP PNG top + bottom
    if sprites.knotwork_strip then
        local strip = sprites.knotwork_strip
        local sw, sh = strip:getWidth(), strip:getHeight()
        local targetW = w - 16
        local targetH = 10
        local scaleX = targetW / sw
        local scaleY = targetH / sh
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(strip, 8, 1, 0, scaleX, scaleY)
        love.graphics.draw(strip, 8, h - 1, 0, scaleX, -scaleY)
    end

    -- VERTICAL DIVIDERS laterais
    if sprites.vertical_divider then
        local div = sprites.vertical_divider
        local dw, dh = 6, math.min(h - 32, 60)
        local sw, sh = div:getWidth(), div:getHeight()
        love.graphics.draw(div, 1, 20, 0, dw / sw, dh / sh)
        love.graphics.draw(div, w - 1 - dw, 20, 0, dw / sw, dh / sh)
    end

    -- EDGE MEDALLIONS nos meios
    if sprites.edge_medallion then
        local med = sprites.edge_medallion
        local ms = 10
        local s = ms / med:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(med, math.floor((w - ms) / 2), 0, 0, s, s)
        love.graphics.draw(med, math.floor((w - ms) / 2), h - ms, 0, s, s)
        love.graphics.draw(med, 0, math.floor((h - ms) / 2), 0, s, s)
        love.graphics.draw(med, w - ms, math.floor((h - ms) / 2), 0, s, s)
    end

    -- CORNER FLOURISHES
    if sprites.corner_flourish then
        local cw, ch = 18, 18
        drawRotatedSprite(sprites.corner_flourish, 0, 0, 0, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 1, w - cw, 0, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 2, w - cw, h - ch, cw, ch)
        drawRotatedSprite(sprites.corner_flourish, 3, 0, h - ch, cw, ch)
    end

    -- WEAR OVERLAY (apenas 12% alpha pra joker — tarot card é mais limpo)
    if sprites.wear_overlay then
        love.graphics.setColor(1, 1, 1, 0.12)
        love.graphics.draw(sprites.wear_overlay, 0, 0, 0,
                           w / sprites.wear_overlay:getWidth(),
                           h / sprites.wear_overlay:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Rarity extras (filete interno além da borda principal, não cortando knotwork)
    if rarity == "legendary" then
        PixelCanvas.rectOutline(9, 9, w - 18, h - 18, Palette.AGED_GOLD_LIGHT)
    elseif rarity == "rare" then
        PixelCanvas.rectOutline(9, 9, w - 18, h - 18, Palette.BLOOD)
    end
end

return JokerBorder
