local Debug = require("src.core.Debug")

local CardArtSlot = {}

local function computeCoverScale(iconW, iconH, slotW, slotH)
    if iconW <= 0 or iconH <= 0 then return 1 end
    local sW = math.ceil(slotW / iconW)
    local sH = math.ceil(slotH / iconH)
    return math.max(1, sW, sH)
end

CardArtSlot.VALIGN = 0.2

local contentTopCache = {}
function CardArtSlot.contentTop(handle)
    local path = handle and handle.path
    if not path then return 0 end
    local c = contentTopCache[path]
    if c then return c end
    c = 0
    local ok, data = pcall(love.image.newImageData, path)
    if ok and data then
        local w, h = data:getWidth(), data:getHeight()
        c = h
        for yy = 0, h - 1 do
            local hit = false
            for xx = 0, w - 1 do
                local _, _, _, a = data:getPixel(xx, yy)
                if a > 0.05 then hit = true; break end
            end
            if hit then c = yy; break end
        end
    else
        Debug.warn("[CardArtSlot] sem ImageData pro bbox de " .. tostring(path))
    end
    contentTopCache[path] = c
    return c
end

function CardArtSlot.layout(iconW, iconH, x, y, w, h, artData, iconHandle)
    local scale = (artData and artData.artScale)
        or computeCoverScale(iconW, iconH, w, h)
    local drawnW = iconW * scale
    local drawnH = iconH * scale
    local iconX = x + math.floor((w - drawnW) / 2)
    local excess = h - drawnH
    local iconY = y + math.floor(excess * (excess < 0 and CardArtSlot.VALIGN or 0.5))
    if excess < 0 and not (artData and artData.artOffsetY and artData.artOffsetY ~= 0) then
        local ct = CardArtSlot.contentTop(iconHandle or (artData and artData.icon))
        local want = y - ct * scale
        if want > iconY then iconY = math.min(y, want) end
    end
    iconY = iconY + ((artData and artData.artOffsetY) or 0)
    return iconX, iconY, scale
end

function CardArtSlot.draw(x, y, w, h, artData, theme, opts)
    opts = opts or {}

    local iconHandle = opts.iconOverride or artData.icon
    if not opts.skipIcon and iconHandle then
        local iconW = iconHandle.size.w
        local iconH = iconHandle.size.h

        local iconX, iconY, scale = CardArtSlot.layout(iconW, iconH, x, y, w, h, artData,
            artData and artData.icon)

        local top = math.min(y, opts.clipTop or y)
        local sx, sy, sw, sh = love.graphics.getScissor()
        love.graphics.setScissor(x, top, w, y + h - top)
        iconHandle.draw(iconX, iconY, scale)
        if sx then
            love.graphics.setScissor(sx, sy, sw, sh)
        else
            love.graphics.setScissor()
        end
    end
end

return CardArtSlot
