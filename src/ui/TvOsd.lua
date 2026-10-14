local FontManager = require("src.ui.FontManager")

local TvOsd = {}

TvOsd.AMBER     = { 1.00, 0.72, 0.22 }
TvOsd.AMBER_DIM = { 0.50, 0.34, 0.10 }
TvOsd.GREEN     = TvOsd.AMBER
TvOsd.GREEN_DIM = TvOsd.AMBER_DIM

local noiseFrames = nil
local NOISE_W, NOISE_H, NOISE_N = 160, 120, 4

local function ensureNoise()
    if noiseFrames then return end
    noiseFrames = {}
    for f = 1, NOISE_N do
        local data = love.image.newImageData(NOISE_W, NOISE_H)
        data:mapPixel(function()
            local v = love.math.random()
            v = v * v
            return v, v, v, 1
        end)
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        noiseFrames[f] = img
    end
end

function TvOsd.staticNoise(alpha)
    if (alpha or 0) <= 0.01 then return end
    if not require("src.ui.CRTShader").isEnabled() then return end
    ensureNoise()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local t = love.timer.getTime()
    local frame = noiseFrames[1 + (math.floor(t * 12) % NOISE_N)]
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(frame, 0, 0, 0, W / NOISE_W, H / NOISE_H)
    local bandY = (t * 0.35 % 1.3) - 0.15
    if bandY >= -0.1 and bandY <= 1.1 then
        love.graphics.setColor(0, 0, 0, 0.35 * alpha)
        love.graphics.rectangle("fill", 0, bandY * H, W, H * 0.06)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function TvOsd.text(str, x, y, alpha, size)
    alpha = alpha or 1
    if alpha <= 0.02 then return end
    local f = FontManager.getFont(size or 15)
    love.graphics.setFont(f)
    local g = TvOsd.AMBER
    love.graphics.setColor(0, 0, 0, 0.85 * alpha)
    love.graphics.print(str, x + 2, y + 2)
    love.graphics.setColor(g[1], g[2], g[3], 0.25 * alpha)
    love.graphics.print(str, x + 1, y)
    love.graphics.setColor(g[1], g[2], g[3], alpha)
    love.graphics.print(str, x, y)
    love.graphics.setColor(1, 1, 1, 1)
end

function TvOsd.textWidth(str, size)
    return FontManager.getFont(size or 15):getWidth(str)
end

function TvOsd.segmentBar(x, y, value, opts)
    opts = opts or {}
    local n     = opts.segments or 10
    local segW  = opts.segW or 14
    local segH  = opts.segH or 16
    local gap   = opts.gap or 3
    local alpha = opts.alpha or 1
    local filled = math.floor((value or 0) * n + 0.5)
    local g, d = TvOsd.AMBER, TvOsd.AMBER_DIM
    for i = 1, n do
        local sx = x + (i - 1) * (segW + gap)
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        love.graphics.rectangle("fill", sx + 2, y + 2, segW, segH)
        if i <= filled then
            love.graphics.setColor(g[1], g[2], g[3], alpha)
            love.graphics.rectangle("fill", sx, y, segW, segH)
            love.graphics.setColor(1, 1, 1, 0.30 * alpha)
            love.graphics.rectangle("fill", sx, y, segW, 2)
        else
            love.graphics.setColor(d[1], d[2], d[3], 0.55 * alpha)
            love.graphics.rectangle("line", sx + 0.5, y + 0.5, segW - 1, segH - 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return n * (segW + gap) - gap
end

return TvOsd
