-- src/ui/PixelBackground.lua
-- Gera backgrounds tileáveis/procedurais em canvases pixel-perfect.
-- Cacheados por (nome, w, h) — chamar uma vez e reutilizar.
--
-- Presets:
--   casinoTable(w, h) — verde escuro de mesa de cassino com textura
--   voidStars(w, h)   — fundo escuro com estrelas piscantes
--   dungeon(w, h)     — pedra tileada com runas
--   parchment(w, h)   — bege com manchas (para telas de menu)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local PixelBackground = {}

local cache = {}

local function keyOf(name, w, h)
    return name .. "_" .. w .. "x" .. h
end

-- Seed determinístico baseado em x,y (para que backgrounds sejam estáveis).
local function seedRand(x, y, salt)
    local n = x * 374761393 + y * 668265263 + (salt or 0) * 1103515245
    n = (n % 2147483647)
    return (n / 2147483647)
end

-- =========================================================================
--                            CASINO TABLE
-- =========================================================================
function PixelBackground.casinoTable(w, h)
    local k = keyOf("casino", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    -- Verde escuro profundo como base
    PixelCanvas.rect(0, 0, w, h, { 0.05, 0.18, 0.10, 1 })
    -- Textura sutil de feltro via dither
    for yy = 0, h - 1, 2 do
        for xx = 0, w - 1, 2 do
            if seedRand(xx, yy, 7) < 0.08 then
                love.graphics.setColor(0.08, 0.24, 0.13, 1)
                love.graphics.rectangle("fill", xx, yy, 1, 1)
            end
        end
    end
    -- Vinheta radial escura nos cantos (desenhada em pixel quadrado simulado)
    for step = 0, 40 do
        local alpha = (step / 40) * 0.4
        love.graphics.setColor(0, 0, 0, alpha * 0.04)
        love.graphics.rectangle("line", step, step, w - step * 2, h - step * 2)
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

-- =========================================================================
--                            VOID STARS
-- =========================================================================
function PixelBackground.voidStars(w, h)
    local k = keyOf("voidStars", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    PixelCanvas.rect(0, 0, w, h, Palette.VOID)

    -- Estrelas pequenas (brancas)
    for i = 1, 180 do
        local x = math.floor(seedRand(i, 1, 11) * w)
        local y = math.floor(seedRand(i, 2, 13) * h)
        PixelCanvas.pixel(x, y, Palette.CYAN_PALE)
    end
    -- Estrelas médias (amarelas)
    for i = 1, 30 do
        local x = math.floor(seedRand(i, 3, 17) * w)
        local y = math.floor(seedRand(i, 4, 19) * h)
        PixelCanvas.pixel(x, y, Palette.YELLOW)
        PixelCanvas.pixel(x + 1, y, Palette.ORANGE)
        PixelCanvas.pixel(x, y + 1, Palette.ORANGE)
    end
    -- Nebulosas roxas (cloud)
    for i = 1, 5 do
        local cx = math.floor(seedRand(i, 5, 23) * w)
        local cy = math.floor(seedRand(i, 6, 29) * h)
        for r = 0, 20 do
            for a = 0, 6.28, 0.3 do
                local px = math.floor(cx + math.cos(a) * r)
                local py = math.floor(cy + math.sin(a) * r * 0.6)
                if px >= 0 and px < w and py >= 0 and py < h then
                    if seedRand(px, py, 31) < 0.05 * (1 - r / 20) then
                        PixelCanvas.pixel(px, py, Palette.PURPLE_DEEP)
                    end
                end
            end
        end
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

-- =========================================================================
--                             DUNGEON STONES
-- =========================================================================
function PixelBackground.dungeon(w, h)
    local k = keyOf("dungeon", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    PixelCanvas.rect(0, 0, w, h, Palette.BG_DEEPEST)

    local tile = 16
    for row = 0, math.floor(h / tile) do
        for col = 0, math.floor(w / tile) do
            local tx = col * tile
            local ty = row * tile
            -- offset alternado em linhas ímpares (tijolo)
            if row % 2 == 1 then tx = tx - tile / 2 end

            local variant = math.floor(seedRand(col, row, 41) * 3)
            local baseColor = Palette.BG_DEEP
            if variant == 1 then baseColor = Palette.BG_MID end
            if variant == 2 then baseColor = Palette.OUTLINE_SOFT end

            PixelCanvas.rect(tx, ty, tile - 1, tile - 1, baseColor)
            PixelCanvas.rect(tx + 1, ty + 1, tile - 3, 1, Palette.lighten(baseColor, 0.2))
            PixelCanvas.rect(tx + 1, ty + tile - 3, tile - 3, 1, Palette.darken(baseColor, 0.6))
        end
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

-- =========================================================================
--                              PARCHMENT
-- =========================================================================
function PixelBackground.parchment(w, h)
    local k = keyOf("parchment", w, h)
    if cache[k] then return cache[k] end

    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    -- bege quente
    PixelCanvas.rect(0, 0, w, h, { 0.85, 0.72, 0.48, 1 })
    -- ruído orgânico
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local n = seedRand(x, y, 43)
            if n < 0.03 then
                love.graphics.setColor(0.5, 0.35, 0.15, 1)
                love.graphics.rectangle("fill", x, y, 1, 1)
            elseif n < 0.06 then
                love.graphics.setColor(0.7, 0.55, 0.3, 1)
                love.graphics.rectangle("fill", x, y, 1, 1)
            end
        end
    end

    PixelCanvas.endDraw()
    cache[k] = canvas
    return canvas
end

-- Limpa cache (ex: mudança de resolução).
function PixelBackground.clearCache()
    cache = {}
end

return PixelBackground
