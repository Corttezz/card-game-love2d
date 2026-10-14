local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")

local CardDecoration = {}

local registry = {}

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
        PixelCanvas.pixel(p[1], p[2], Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(p[1] - 1, p[2], accentCol)
        PixelCanvas.pixel(p[1] + 1, p[2], accentCol)
        PixelCanvas.pixel(p[1], p[2] - 1, accentCol)
        PixelCanvas.pixel(p[1], p[2] + 1, accentCol)
        PixelCanvas.pixel(p[1] - 2, p[2] - 2, accentCol)
        PixelCanvas.pixel(p[1] + 2, p[2] + 2, accentCol)
    end
end

function registry.blood_drips(x, y, w, h, accent)
    local cols = { math.floor(w * 0.2), math.floor(w * 0.45), math.floor(w * 0.65), math.floor(w * 0.85) }
    local lengths = { 8, 14, 10, 6 }
    for i, col in ipairs(cols) do
        local len = lengths[i] or 10
        for row = 0, len do
            PixelCanvas.pixel(x + col, y + row, Palette.BLOOD)
        end
        PixelCanvas.pixel(x + col - 1, y + len, Palette.BLOOD_DARK)
        PixelCanvas.pixel(x + col + 1, y + len, Palette.BLOOD_DARK)
        PixelCanvas.pixel(x + col, y + len + 1, Palette.BLOOD)
    end
end

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

function registry.runes(x, y, w, h, accent)
    local pos = {
        { x + 5, y + 5 }, { x + w - 7, y + 7 },
        { x + 5, y + h - 8 }, { x + w - 7, y + h - 6 },
    }
    for i, p in ipairs(pos) do
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

function registry.poison_bubbles(x, y, w, h, accent)
    local pts = {
        { x + 5,        y + 8 },
        { x + 11,       y + h - 7 },
        { x + w - 6,    y + 5 },
        { x + w - 10,   y + h - 9 },
        { x + math.floor(w * 0.35), y + math.floor(h * 0.7) },
        { x + math.floor(w * 0.65), y + math.floor(h * 0.25) },
        { x + math.floor(w * 0.5),  y + h - 5 },
    }
    for i, p in ipairs(pts) do
        PixelCanvas.pixel(p[1],     p[2],     Palette.MOSS)
        PixelCanvas.pixel(p[1] - 1, p[2],     Palette.MOSS)
        PixelCanvas.pixel(p[1] + 1, p[2],     Palette.MOSS)
        PixelCanvas.pixel(p[1],     p[2] - 1, Palette.MOSS)
        PixelCanvas.pixel(p[1],     p[2] + 1, Palette.MOSS)
        PixelCanvas.pixel(p[1] - 1, p[2] - 1, Palette.GREEN_BRIGHT)
        if i % 3 == 0 then
            PixelCanvas.pixel(p[1] - 1, p[2] - 2, Palette.PARCHMENT_LIGHT)
        end
    end
end

function registry.shadow_wisps(x, y, w, h, accent)
    for col = 0, 2 do
        for yy = 0, h - 1 do
            if (col * 5 + yy * 2) % (8 + col * 4) == 0 then
                PixelCanvas.pixel(x + 1 + col, y + yy, Palette.INK)
            end
            if (col * 7 + yy * 3) % (8 + col * 4) == 0 then
                PixelCanvas.pixel(x + w - 2 - col, y + yy, Palette.INK)
            end
        end
    end

    local function curl(startX, dir)
        for i = 0, 7 do
            local dx = math.floor(math.sin(i * 0.6) * 2) * dir
            PixelCanvas.pixel(startX + dx, y + 2 + i, Palette.INK)
            if i > 2 and i < 6 then
                PixelCanvas.pixel(startX + dx + dir, y + 2 + i, Palette.MAGENTA_DARK)
            end
        end
    end
    curl(x + 6, 1)
    curl(x + w - 7, -1)

    local speckles = {
        { x + 4,  y + 8 },  { x + w - 5, y + 11 },
        { x + 3,  y + h - 12 }, { x + w - 4, y + h - 9 },
        { x + 7,  y + h / 2 }, { x + w - 8, y + h / 2 - 5 },
        { x + 5,  y + 22 }, { x + w - 6, y + 28 },
    }
    for _, s in ipairs(speckles) do
        PixelCanvas.pixel(s[1], s[2], Palette.MAGENTA_DARK)
        PixelCanvas.pixel(s[1] + 1, s[2], Palette.PURPLE_DEEP)
    end
end

function registry.abyss_tendrils(x, y, w, h, accent)
    local cols = {
        math.floor(w * 0.15), math.floor(w * 0.4),
        math.floor(w * 0.62), math.floor(w * 0.85),
    }
    local lens = { 12, 18, 14, 10 }
    for i, col in ipairs(cols) do
        local len = lens[i] or 12
        for row = 0, len do
            PixelCanvas.pixel(x + col, y + row, Palette.INK)
            if row > len - 4 then
                PixelCanvas.pixel(x + col - 1, y + row, Palette.MAGENTA_DARK)
                PixelCanvas.pixel(x + col + 1, y + row, Palette.MAGENTA_DARK)
            end
        end
        if i == 2 or i == 4 then
            PixelCanvas.pixel(x + col, y + len + 1, Palette.AGED_GOLD)
            PixelCanvas.pixel(x + col, y + len + 2, Palette.INK)
        end
    end

    local botCols = { math.floor(w * 0.25), math.floor(w * 0.5), math.floor(w * 0.78) }
    local botLens = { 6, 9, 5 }
    for i, col in ipairs(botCols) do
        local len = botLens[i]
        for row = 0, len do
            local dx = math.floor(math.sin(row * 0.5) * 2) * (i % 2 == 0 and 1 or -1)
            PixelCanvas.pixel(x + col + dx, y + h - 1 - row, Palette.INK)
        end
    end

    local extraEyes = {
        { x + 8,        y + math.floor(h * 0.55) },
        { x + w - 9,    y + math.floor(h * 0.45) },
        { x + math.floor(w * 0.4),  y + math.floor(h * 0.85) },
        { x + math.floor(w * 0.7),  y + math.floor(h * 0.65) },
    }
    for _, e in ipairs(extraEyes) do
        PixelCanvas.pixel(e[1] - 1, e[2], Palette.AGED_GOLD_DARK)
        PixelCanvas.pixel(e[1],     e[2], Palette.INK)
        PixelCanvas.pixel(e[1] + 1, e[2], Palette.AGED_GOLD_DARK)
    end

    local bones = {
        { x + 6,         y + h - 3 },
        { x + w - 10,    y + h - 4 },
        { x + math.floor(w * 0.55), y + h - 3 },
    }
    for _, b in ipairs(bones) do
        PixelCanvas.hline(b[1], b[2], 3, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(b[1] - 1, b[2] - 1, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(b[1] + 3, b[2] - 1, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(b[1] - 1, b[2] + 1, Palette.PARCHMENT_LIGHT)
        PixelCanvas.pixel(b[1] + 3, b[2] + 1, Palette.PARCHMENT_LIGHT)
    end
end

function registry.void_stars(x, y, w, h, accent)
    local function nebulaBlob(cx, cy, size)
        local dots = {
            { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
            { 2, 0 }, { -2, 1 }, { 1, 2 }, { -1, -1 }, { 2, -1 },
            { 0, 2 }, { -2, 0 }, { 1, -1 }, { 3, 0 },
        }
        for i, d in ipairs(dots) do
            local color = (i % 3 == 0) and Palette.PURPLE or Palette.PURPLE_DEEP
            PixelCanvas.pixel(cx + d[1] * size, cy + d[2] * size, color)
        end
    end
    nebulaBlob(x + 12,    y + 14,         1)
    nebulaBlob(x + w - 14, y + h - 18,    1)

    local stars = {
        { 0.08, 0.10 }, { 0.22, 0.33 }, { 0.35, 0.15 },
        { 0.48, 0.40 }, { 0.62, 0.18 }, { 0.75, 0.35 },
        { 0.88, 0.12 }, { 0.15, 0.58 }, { 0.30, 0.78 },
        { 0.52, 0.68 }, { 0.68, 0.82 }, { 0.82, 0.60 },
        { 0.40, 0.90 }, { 0.90, 0.85 },
        { 0.55, 0.05 }, { 0.18, 0.92 },
    }
    for i, s in ipairs(stars) do
        local sx = x + math.floor(s[1] * w)
        local sy = y + math.floor(s[2] * h)
        PixelCanvas.pixel(sx, sy, Palette.PARCHMENT_LIGHT)
        if i % 3 == 0 then
            PixelCanvas.pixel(sx - 1, sy, Palette.AGED_GOLD)
            PixelCanvas.pixel(sx + 1, sy, Palette.AGED_GOLD)
            PixelCanvas.pixel(sx, sy - 1, Palette.AGED_GOLD)
            PixelCanvas.pixel(sx, sy + 1, Palette.AGED_GOLD)
            if i % 6 == 3 then
                PixelCanvas.pixel(sx - 2, sy, Palette.AGED_GOLD_DARK)
                PixelCanvas.pixel(sx + 2, sy, Palette.AGED_GOLD_DARK)
            end
        end
    end

    local dust = {
        { 0.12, 0.20 }, { 0.28, 0.42 }, { 0.42, 0.25 },
        { 0.58, 0.30 }, { 0.72, 0.45 }, { 0.85, 0.50 },
        { 0.20, 0.65 }, { 0.45, 0.55 }, { 0.60, 0.75 },
        { 0.78, 0.72 }, { 0.10, 0.78 }, { 0.65, 0.10 },
        { 0.92, 0.30 }, { 0.05, 0.45 },
    }
    for i, d in ipairs(dust) do
        local dx = x + math.floor(d[1] * w)
        local dy = y + math.floor(d[2] * h)
        local col = (i % 2 == 0) and Palette.STEEL or Palette.STEEL_LIGHT
        PixelCanvas.pixel(dx, dy, col)
    end

    local function line(x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local steps = math.max(math.abs(dx), math.abs(dy))
        for i = 0, steps do
            local px = x1 + math.floor(dx * i / steps)
            local py = y1 + math.floor(dy * i / steps)
            if i % 2 == 0 then
                PixelCanvas.pixel(px, py, Palette.AGED_GOLD_DARK)
            end
        end
    end
    local s = {}
    for i, p in ipairs(stars) do
        s[i] = { x + math.floor(p[1] * w), y + math.floor(p[2] * h) }
    end
    line(s[1][1], s[1][2], s[2][1], s[2][2])
    line(s[2][1], s[2][2], s[3][1], s[3][2])
    line(s[8][1], s[8][2], s[9][1], s[9][2])
    line(s[10][1], s[10][2], s[11][1], s[11][2])
end

function CardDecoration.draw(x, y, w, h, name, accentColor)
    if not name then return end
    local fn = registry[name]
    if fn then fn(x, y, w, h, accentColor) end
end

function CardDecoration.autoForBackground(bgPattern)
    local map = {
        blood  = "blood_drips",
        fire   = "embers",
        rage   = "embers",
        storm  = "sparks",
        ice    = "frost",
        arcane = "runes",
        poison = "poison_bubbles",
        shadow = "shadow_wisps",
        abyss  = "abyss_tendrils",
        void   = "void_stars",
    }
    return map[bgPattern]
end

function CardDecoration.list()
    local names = {}
    for k in pairs(registry) do names[#names + 1] = k end
    return names
end

return CardDecoration
