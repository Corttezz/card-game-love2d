-- src/ui/card/components/CardDecoration.lua
-- Overlay decorativo sobre a art slot. Desenhado DEPOIS da ilustração,
-- antes da borda externa — não contamina header/footer.
--
-- Presets existentes: sparks, dust, smoke, flash
-- Novos: blood_drips (bg=blood), embers (bg=fire/rage), frost (bg=ice), runes (bg=arcane)
--
-- API: CardDecoration.draw(x, y, w, h, name, accentColor)

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardDecoration = {}

local registry = {}

-- Sparks densos: 2 por canto = 8 pontos ao todo
function registry.sparks(x, y, w, h, accent)
    local accentCol = accent or Palette.AGED_GOLD
    local points = {
        { x + 3, y + 3 }, { x + 5, y + 4 },
        { x + w - 4, y + 3 }, { x + w - 6, y + 4 },
        { x + 3, y + h - 4 }, { x + 5, y + h - 5 },
        { x + w - 4, y + h - 4 }, { x + w - 6, y + h - 5 },
    }
    for _, p in ipairs(points) do
        PixelCanvas.pixel(p[1], p[2], Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1] - 1, p[2], accentCol)
        PixelCanvas.pixel(p[1] + 1, p[2], accentCol)
        PixelCanvas.pixel(p[1], p[2] - 1, accentCol)
        PixelCanvas.pixel(p[1], p[2] + 1, accentCol)
    end
end

function registry.dust(x, y, w, h, accent)
    for i = 1, 18 do
        local sx = x + (i * 6 + 3) % (w - 2) + 1
        local sy = y + (i * 11 + 5) % (h - 2) + 1
        local col = i % 3 == 0 and Palette.AGED_GOLD_LIGHT or Palette.PARCHMENT_LIGHT
        PixelCanvas.pixel(sx, sy, col)
    end
end

function registry.smoke(x, y, w, h, accent)
    -- 6 colunas de wisp
    for i = 0, 5 do
        local bx = x + 3 + math.floor(i * (w - 6) / 5)
        if bx < x + w then
            for yy = 0, h - 1 do
                if (i + yy * 3) % 11 < 3 then
                    PixelCanvas.pixel(bx, y + yy, Palette.PARCHMENT_DARK)
                end
                if (i + yy * 3) % 17 < 1 then
                    PixelCanvas.pixel(bx + 1, y + yy, Palette.PARCHMENT_DARK)
                end
            end
        end
    end
end

function registry.flash(x, y, w, h, accent)
    local accentCol = accent or Palette.AGED_GOLD
    local corners = {
        { x + 2, y + 2 }, { x + w - 3, y + 2 },
        { x + 2, y + h - 3 }, { x + w - 3, y + h - 3 },
    }
    for _, p in ipairs(corners) do
        -- Cruz de 5 pixels
        PixelCanvas.pixel(p[1], p[2], Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1] - 1, p[2], accentCol)
        PixelCanvas.pixel(p[1] + 1, p[2], accentCol)
        PixelCanvas.pixel(p[1], p[2] - 1, accentCol)
        PixelCanvas.pixel(p[1], p[2] + 1, accentCol)
        -- Raios diagonais (2 pixels)
        PixelCanvas.pixel(p[1] - 2, p[2] - 2, accentCol)
        PixelCanvas.pixel(p[1] + 2, p[2] + 2, accentCol)
    end
end

-- Blood drips: 4 gotas verticais tombando da borda superior
function registry.blood_drips(x, y, w, h, accent)
    local cols = { math.floor(w * 0.2), math.floor(w * 0.45), math.floor(w * 0.65), math.floor(w * 0.85) }
    local lengths = { 8, 14, 10, 6 }
    for i, col in ipairs(cols) do
        local len = lengths[i] or 10
        for row = 0, len do
            PixelCanvas.pixel(x + col, y + row, Palette.BLOOD)
        end
        -- gota na ponta
        PixelCanvas.pixel(x + col - 1, y + len, Palette.BLOOD_DARK)
        PixelCanvas.pixel(x + col + 1, y + len, Palette.BLOOD_DARK)
        PixelCanvas.pixel(x + col, y + len + 1, Palette.BLOOD)
    end
end

-- Embers: 8-12 pontos laranja/vermelho em posições aleatórias (baixo pra cima)
function registry.embers(x, y, w, h, accent)
    for i = 1, 10 do
        local sx = x + (i * 7 + 2) % (w - 2) + 1
        local sy = y + h - 2 - (i * 5) % (h / 2)
        local col = i % 3 == 0 and Palette.RUST or Palette.BLOOD
        PixelCanvas.pixel(sx, sy, col)
        if i % 2 == 0 then
            PixelCanvas.pixel(sx, sy - 1, Palette.PARCHMENT_LIGHT)
        end
    end
end

-- Frost: cristais brancos em posições simétricas
function registry.frost(x, y, w, h, accent)
    local points = {
        { x + 4, y + 4 }, { x + w - 5, y + 4 },
        { x + 4, y + h - 5 }, { x + w - 5, y + h - 5 },
        { x + math.floor(w / 2), y + 3 },
        { x + math.floor(w / 2), y + h - 4 },
    }
    for _, p in ipairs(points) do
        PixelCanvas.pixel(p[1], p[2], Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1] - 1, p[2], Palette.STEEL_LIGHT or Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1] + 1, p[2], Palette.STEEL_LIGHT or Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1], p[2] - 1, Palette.STEEL_LIGHT or Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1], p[2] + 1, Palette.STEEL_LIGHT or Palette.PARCHMENT_LIGHT)
    end
end

-- Runes: pequenos símbolos runicos dourados espalhados
function registry.runes(x, y, w, h, accent)
    local pos = {
        { x + 5, y + 5 }, { x + w - 7, y + 7 },
        { x + 5, y + h - 8 }, { x + w - 7, y + h - 6 },
    }
    for i, p in ipairs(pos) do
        -- Símbolo runa 3×3 variando
        if i % 2 == 0 then
            PixelCanvas.hline(p[1], p[2], 3, Palette.AGED_GOLD)
            PixelCanvas.pixel(p[1] + 1, p[2] + 1, Palette.AGED_GOLD)
            PixelCanvas.hline(p[1], p[2] + 2, 3, Palette.AGED_GOLD)
        else
            PixelCanvas.vline(p[1], p[2], 3, Palette.AGED_GOLD)
            PixelCanvas.vline(p[1] + 2, p[2], 3, Palette.AGED_GOLD)
            PixelCanvas.pixel(p[1] + 1, p[2] + 1, Palette.AGED_GOLD)
        end
    end
end

function CardDecoration.draw(x, y, w, h, name, accentColor)
    if not name then return end
    local fn = registry[name]
    if fn then fn(x, y, w, h, accentColor) end
end

-- Dispatch automático por bgPattern se não houver decoration explícita
function CardDecoration.autoForBackground(bgPattern)
    local map = {
        blood  = "blood_drips",
        fire   = "embers",
        rage   = "embers",
        storm  = "sparks",
        ice    = "frost",
        arcane = "runes",
    }
    return map[bgPattern]
end

function CardDecoration.list()
    local names = {}
    for k in pairs(registry) do names[#names + 1] = k end
    return names
end

return CardDecoration
