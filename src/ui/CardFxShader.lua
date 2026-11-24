local Debug = require("src.core.Debug")

local CardFxShader = {}

local shader
local loaded = false
local tried = false

CardFxShader.MODES = { ash = 1, seal = 2, mirror = 3, wind = 4, dawn = 5 }

CardFxShader.PALETTES = {
    ash    = { { 1.00, 0.86, 0.48, 1 }, { 1.00, 0.40, 0.08, 1 } },
    seal   = { { 1.00, 0.93, 0.72, 1 }, { 0.62, 0.36, 1.00, 1 } },
    mirror = { { 0.92, 0.97, 1.00, 1 }, { 0.60, 0.78, 1.00, 1 } },
    wind   = { { 0.78, 0.42, 0.30, 1 }, { 0.35, 0.18, 0.14, 1 } },
    dawn   = { { 1.00, 0.90, 0.55, 1 }, { 1.00, 0.70, 0.30, 1 } },
}

function CardFxShader.load()
    tried = true
    local ok, s = pcall(love.graphics.newShader, "shaders/card_fx.glsl")
    if not ok then
        Debug.warn("[CardFxShader] falha ao carregar shaders/card_fx.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function CardFxShader.ensure()
    if not loaded and not tried and love and love.graphics and love.graphics.newShader then
        CardFxShader.load()
    end
    return loaded
end

function CardFxShader.isAvailable()
    return loaded
end

local function send(name, value)
    if shader:hasUniform(name) then shader:send(name, value) end
end

function CardFxShader.apply(canvas, fx, pad, w, h)
    if not loaded then return false end
    local cw, ch = canvas:getDimensions()
    local pal = CardFxShader.PALETTES[fx.mode] or CardFxShader.PALETTES.ash
    love.graphics.setShader(shader)
    send("mode", CardFxShader.MODES[fx.mode] or 1)
    send("progress", math.max(0, math.min(1, fx.progress or 0)))
    send("time", love.timer.getTime())
    send("card_rect", { pad / cw, pad / ch, (pad + w) / cw, (pad + h) / ch })
    send("canvas_px", { cw, ch })
    send("col_a", fx.colA or pal[1])
    send("col_b", fx.colB or pal[2])
    send("seed", fx.seed or 0)
    send("side", fx.side or 1)
    return true
end

return CardFxShader
