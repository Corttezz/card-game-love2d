-- src/ui/GrimoirePage.lua
-- Folha de grimório pintada em pixel (seleção de classe v4, Out/2026): papel
-- em 4 tons com dither Bayer, borda rasgada coluna a coluna, beirada queimada
-- e duas manchas de tinta velha. Gerada UMA vez por tamanho numa ImageData
-- em meia resolução e desenhada ×2 com nearest — o grão do papel tem o mesmo
-- tamanho de pixel do resto da UI, em qualquer proporção (o wear_overlay da
-- carta é 2:3 fixo e esticá-lo deformava os rasgos).
--
--   GrimoirePage.draw(x, y, w, h, seed)

local Palette = require("src.ui.Palette")

local GrimoirePage = {}
GrimoirePage.PX = 2            -- tamanho do pixel do papel na tela

local cache = {}               -- "w:h:seed" -> Image

local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }

local function lerp(a, b, t) return a + (b - a) * t end

local function build(w, h, seed)
    local n = love.math.noise
    local data = love.image.newImageData(w, h)
    local light, mid, dark = Palette.PARCHMENT_LIGHT, Palette.PARCHMENT, Palette.PARCHMENT_DARK
    local ink = Palette.INK
    -- tons do papel (claro → escuro) — o ruído escolhe o tom, o Bayer mistura
    local tones = {
        light,
        { lerp(light[1], mid[1], 0.45), lerp(light[2], mid[2], 0.45), lerp(light[3], mid[3], 0.45) },
        { lerp(light[1], mid[1], 0.8), lerp(light[2], mid[2], 0.8), lerp(light[3], mid[3], 0.8) },
        mid,
        { lerp(mid[1], dark[1], 0.6), lerp(mid[2], dark[2], 0.6), lerp(mid[3], dark[3], 0.6) },
        dark,
    }
    -- borda rasgada: quanto cada coluna/linha da beirada foi comida
    local function tear(i, side)
        local v = n(i * 0.21, side * 7.3 + seed) * 0.7 + n(i * 0.07, side * 3.1 + seed) * 0.6
        return math.floor(v * 4)   -- 0..4 px (meia resolução)
    end
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local eatL, eatR = tear(y, 1), tear(y, 2)
            local eatT, eatB = tear(x, 3), tear(x, 4)
            local dl, dr, dt, db = x - eatL, (w - 1 - x) - eatR, y - eatT, (h - 1 - y) - eatB
            local d = math.min(dl, dr, dt, db)
            if d < 0 then
                data:setPixel(x, y, 0, 0, 0, 0)
            elseif d == 0 then
                -- contorno queimado de 1 px
                data:setPixel(x, y, ink[1], ink[2], ink[3], 1)
            else
                local grain = n(x * 0.035 + seed, y * 0.035) * 0.45 + n(x * 0.12, y * 0.12 + seed) * 0.12
                -- escurece perto da beirada (chamuscado) e nas manchas
                local edge = math.max(0, 1 - d / 7) ^ 1.5
                local stain = 0
                for k = 1, 2 do
                    local sx = w * (0.2 + 0.6 * n(seed + k * 13.7, 0.5))
                    local sy = h * (0.15 + 0.7 * n(seed + k * 5.1, 1.5))
                    local r = math.min(w, h) * (0.10 + 0.08 * k)
                    local dd = math.sqrt((x - sx) ^ 2 + (y - sy) ^ 2) / r
                    if dd < 1 then stain = math.max(stain, (1 - dd) * 0.18) end
                end
                local v = grain * 0.45 + edge * 1.1 + stain
                local b = BAYER[(y % 4) * 4 + (x % 4) + 1] / 16 - 0.5
                local idx = math.floor((v + b * 0.35) * #tones) + 1
                idx = math.max(1, math.min(#tones, idx))
                local c = tones[idx]
                data:setPixel(x, y, c[1], c[2], c[3], 1)
            end
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

function GrimoirePage.image(w, h, seed)
    local px = GrimoirePage.PX
    local lw, lh = math.max(8, math.floor(w / px)), math.max(8, math.floor(h / px))
    seed = seed or 1
    local key = lw .. ":" .. lh .. ":" .. seed
    if not cache[key] then cache[key] = build(lw, lh, seed) end
    return cache[key]
end

function GrimoirePage.draw(x, y, w, h, seed)
    local img = GrimoirePage.image(w, h, seed)
    local px = GrimoirePage.PX
    -- sombra da folha sobre a pedra
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.draw(img, math.floor(x) + 6, math.floor(y) + 8, 0, px, px)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(x), math.floor(y), 0, px, px)
end

return GrimoirePage
