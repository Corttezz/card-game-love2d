local FontManager = require("src.ui.FontManager")
local utf8 = require("utf8")

local TextFit = {}

TextFit.MIN_SIZE = 8

local function ellipsize(font, text, maxW)
    if font:getWidth(text) <= maxW then return text end
    local ell = "..."
    local ellW = font:getWidth(ell)
    local out = ""
    for _, code in utf8.codes(text) do
        local ch = utf8.char(code)
        if font:getWidth(out .. ch) + ellW > maxW then break end
        out = out .. ch
    end
    return out .. ell
end

function TextFit.fit(text, desiredSize, maxW, minSize)
    text = tostring(text or "")
    minSize = minSize or TextFit.MIN_SIZE
    if text == "" or not maxW or maxW <= 0 then
        return FontManager.getFont(desiredSize or 12), text, desiredSize or 12
    end
    local size = math.max(minSize, math.floor(desiredSize or 12))
    while size > minSize do
        local font = FontManager.getFont(size)
        if font:getWidth(text) <= maxW then return font, text, size end
        size = size - 1
    end
    local font = FontManager.getFont(minSize)
    return font, ellipsize(font, text, maxW), minSize
end

function TextFit.print(text, x, y, opts)
    opts = opts or {}
    local font, drawText = TextFit.fit(text, opts.size, opts.maxW, opts.minSize)
    love.graphics.setFont(font)
    local dx = x
    if opts.maxW and opts.align == "center" then
        dx = x + math.floor((opts.maxW - font:getWidth(drawText)) / 2)
    elseif opts.maxW and opts.align == "right" then
        dx = x + opts.maxW - font:getWidth(drawText)
    end
    if opts.shadow then
        local r, g, b, a = love.graphics.getColor()
        love.graphics.setColor(opts.shadow)
        love.graphics.print(drawText, dx + 1, y + 1)
        love.graphics.setColor(r, g, b, a)
    end
    love.graphics.print(drawText, dx, y)
    return font:getWidth(drawText), font:getHeight()
end

return TextFit
