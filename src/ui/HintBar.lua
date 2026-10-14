local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")

local HintBar = {}

local function fit(text, maxW, sizes)
    local font
    for _, size in ipairs(sizes) do
        font = FontManager.getFont(size)
        if font:getWidth(text) <= maxW then
            return font, text
        end
    end
    local out = text
    while #out > 4 and font:getWidth(out .. "…") > maxW do
        local cut = require("utf8").offset(out, -1)
        if not cut or cut <= 1 then out = "" break end
        out = out:sub(1, cut - 1)
    end
    return font, out .. "…"
end

HintBar._fit = fit

HintBar.ENABLED = false

function HintBar.draw(text, opts)
    if not HintBar.ENABLED then return end
    if not text or text == "" then return end
    opts = opts or {}
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local padX = opts.padX or 12
    local maxW = W - 32 - padX * 2
    local sizes = opts.sizes or { 14, 12, 10 }

    local font, shown = fit(text, maxW, sizes)
    local tw = font:getWidth(shown)
    local th = font:getHeight()
    local x = math.floor((W - tw) / 2)
    local y = opts.y or (H - th - 14)

    love.graphics.setColor(0.08, 0.06, 0.05, 0.72)
    love.graphics.rectangle("fill", x - padX, y - 5, tw + padX * 2, th + 10, 6, 6)
    Palette.set(Palette.PARCHMENT)
    love.graphics.setFont(font)
    love.graphics.print(shown, x, y)
    love.graphics.setColor(1, 1, 1, 1)
end

return HintBar
