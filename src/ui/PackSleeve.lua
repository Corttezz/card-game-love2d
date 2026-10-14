local PackSleeve = {}

local ImageCache    = require("src.ui.ImageCache")
local PixelCanvas   = require("src.ui.PixelCanvas")
local FontManager   = require("src.ui.FontManager")
local BoosterShader = require("src.ui.BoosterShader")
local PackThemes    = require("src.ui.PackThemes")

local SLEEVE_W, SLEEVE_H = 128, 192

local PROCEDURAL_GLYPHS = {
    Standard  = "✦",
    Buffoon   = "♛",
    Arcana    = "☉",
    Celestial = "✧",
    Spectral  = "☠",
}

local proceduralCache = {}

local hoverState = {}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function seedOf(key)
    local h = 0
    for i = 1, #key do
        h = (h * 31 + key:byte(i)) % 65536
    end
    return h / 65536
end

local function stateFor(key)
    local s = hoverState[key]
    if not s then
        s = { h = 0, seed = seedOf(key) }
        hoverState[key] = s
    end
    return s
end

local function tryLoadPNG(packId)
    if not packId then return nil end
    local path = "assets/sprites/packs/" .. packId .. ".png"
    if love.filesystem.getInfo(path) then
        return ImageCache.get(path)
    end
    return nil
end

local function buildProcedural(kind)
    if proceduralCache[kind] then return proceduralCache[kind] end
    local th = PackThemes.get(kind)

    local bg      = th.base
    local accent  = th.accent
    local outline = { bg[1] * 0.22, bg[2] * 0.22, bg[3] * 0.22, 1 }

    local W, H = SLEEVE_W, SLEEVE_H
    local canvas = love.graphics.newCanvas(W, H)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)

    PixelCanvas.rect(0, 0, W, H, bg)
    PixelCanvas.rectOutline(0, 0, W, H, outline)
    PixelCanvas.rectOutline(2, 2, W - 4, H - 4, accent)
    PixelCanvas.rectOutline(4, 4, W - 8, H - 8, outline)

    local cx, cy = W * 0.5, H * 0.5
    love.graphics.setColor(outline)
    love.graphics.circle("fill", cx, cy, 28)
    love.graphics.setColor(accent)
    love.graphics.circle("fill", cx, cy, 24)
    love.graphics.setColor(outline)
    love.graphics.circle("line", cx, cy, 24)

    local glyph = PROCEDURAL_GLYPHS[kind] or PROCEDURAL_GLYPHS.Standard
    local glyphFont = FontManager.getFont(28)
    love.graphics.setFont(glyphFont)
    love.graphics.setColor(outline)
    local gw = glyphFont:getWidth(glyph)
    local gh = glyphFont:getHeight()
    love.graphics.print(glyph, cx - gw * 0.5, cy - gh * 0.5)

    local titleFont = FontManager.getFont(10)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(accent)
    love.graphics.printf(PackThemes.label(kind), 0, H - 36, W, "center")

    for _, p in ipairs({
        {6, 6}, {W - 14, 6}, {6, H - 14}, {W - 14, H - 14},
    }) do
        PixelCanvas.rect(p[1], p[2], 8, 8, accent)
        PixelCanvas.rectOutline(p[1], p[2], 8, 8, outline)
    end

    love.graphics.pop()
    love.graphics.setCanvas(prevCanvas)

    proceduralCache[kind] = canvas
    return canvas
end

function PackSleeve.getImage(packId, kind)
    local png = tryLoadPNG(packId)
    if png then return png end
    return buildProcedural(kind or "Standard")
end

function PackSleeve.getDimensions()
    return SLEEVE_W, SLEEVE_H
end

function PackSleeve.isMouseOver(cx, cy, scale)
    if not (love.mouse and love.mouse.getPosition) then return false end
    scale = scale or 1
    local w = SLEEVE_W * scale * 0.5
    local h = SLEEVE_H * scale * 0.5
    local mx, my = love.mouse.getPosition()
    return mx >= cx - w and mx <= cx + w and my >= cy - h and my <= cy + h
end

local function drawSparkles(th, cx, cy, scale, alpha, hover, t, seed, still)
    local n = th.sparkles or 0
    if n <= 0 then return end
    local rx = SLEEVE_W * scale * 0.62
    local ry = SLEEVE_H * scale * 0.56
    local px = math.max(2, math.floor(2 * scale))
    local speed = still and 0 or (th.sparkleSpeed or 0.5)

    local prevMode, prevAlphaMode = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add", "alphamultiply")
    for i = 1, n do
        local phase = seed * 6.2832 + i * (6.2832 / n)
        local ang = phase + t * speed
        local sx = cx + math.cos(ang) * rx
        local sy = cy + math.sin(ang * 1.3 + phase) * ry
        local tw = still and 0.7 or (0.5 + 0.5 * math.sin(t * 2.4 + i * 1.7 + seed * 10))
        local a = tw * (0.35 + 0.45 * hover) * alpha
        if a > 0.01 then
            love.graphics.setColor(th.glow[1], th.glow[2], th.glow[3], a)
            love.graphics.rectangle("fill", math.floor(sx), math.floor(sy), px, px)
            love.graphics.setColor(1, 1, 1, a * 0.55)
            love.graphics.rectangle("fill", math.floor(sx), math.floor(sy), 1, 1)
        end
    end
    love.graphics.setBlendMode(prevMode, prevAlphaMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function PackSleeve.drawAt(packId, kind, cx, cy, scale, alpha, opts)
    scale = scale or 1
    alpha = alpha == nil and 1 or alpha
    if alpha <= 0.001 then return end

    local img = PackSleeve.getImage(packId, kind)
    if not img then return end

    opts = opts or {}
    local th    = PackThemes.get(kind)
    local still = reducedMotion()
    local t     = love.timer and love.timer.getTime() or 0
    local dt    = (love.timer and love.timer.getDelta and love.timer.getDelta()) or 0
    local key   = opts.key or tostring(packId or kind or "pack")
    local st    = stateFor(key)

    local target
    if opts.hover ~= nil then
        target = (opts.hover == true and 1) or (opts.hover == false and 0) or opts.hover
    elseif opts.interactive == false then
        target = 0
    else
        target = PackSleeve.isMouseOver(cx, cy, scale) and 1 or 0
    end
    local k = math.min(1, dt * 12)
    st.h = st.h + (target - st.h) * k
    local hover = st.h

    local seed = st.seed
    local breathe = still and 0
        or math.sin(t * 1.7 + seed * 6.2832) * 0.012 * (1 - 0.5 * hover)
    local drawScale = scale * (1 + 0.055 * hover + breathe)
    local lift = -5 * hover
    local rot = (opts.rotation or 0)
        + (still and 0 or math.sin(t * 5.5 + seed * 3) * 0.035 * hover)
    local dy = cy + lift

    if opts.sparkles ~= false then
        drawSparkles(th, cx, dy, scale, alpha, hover, t, seed, still)
    end

    local ox, oy = img:getWidth() * 0.5, img:getHeight() * 0.5
    if opts.shader == true and BoosterShader.isAvailable() then
        BoosterShader.apply(img, opts.phase or t, 0, th.glow, th.sheenAmt or 0.5)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, cx, dy, rot, drawScale, drawScale, ox, oy)
        BoosterShader.clear()
    else
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, cx, dy, rot, drawScale, drawScale, ox, oy)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PackSleeve
