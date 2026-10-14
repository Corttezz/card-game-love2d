local Debug = require("src.core.Debug")

local DissolveShader = {}

local shader
local loaded = false

local DEFAULT_BURN_1 = {1.0, 0.55, 0.05, 1.0}
local DEFAULT_BURN_2 = {0.85, 0.12, 0.02, 1.0}

function DissolveShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/dissolve.glsl")
    if not ok then
        Debug.warn("[DissolveShader] falha ao carregar shaders/dissolve.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function DissolveShader.isAvailable()
    return loaded
end

function DissolveShader.apply(image, dissolve, burnColors, isShadow, noiseScale)
    if not loaded then return false end
    dissolve = math.max(0, math.min(1, dissolve or 0))
    burnColors = burnColors or {DEFAULT_BURN_1, DEFAULT_BURN_2}

    love.graphics.setShader(shader)
    shader:send("dissolve", dissolve)
    shader:send("time", love.timer.getTime())
    shader:send("noise_scale", noiseScale or { 0, 0 })

    local w = image:getWidth()
    local h = image:getHeight()
    shader:send("texture_details", {0, 0, w, h})
    shader:send("image_details", {w, h})

    local c1 = burnColors[1] or DEFAULT_BURN_1
    local c2 = burnColors[2] or {0, 0, 0, 0}
    shader:send("burn_colour_1", c1)
    shader:send("burn_colour_2", c2)
    shader:send("shadow", isShadow and true or false)
    return true
end

function DissolveShader.clear()
    love.graphics.setShader()
end

function DissolveShader.draw(image, x, y, dissolve, burnColors, r, sx, sy, ox, oy)
    if not DissolveShader.apply(image, dissolve, burnColors) then
        love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    DissolveShader.clear()
end

function DissolveShader.palette(kind)
    local palettes = {
        attack    = {{0.85, 0.12, 0.02, 1.0}, {1.0, 0.55, 0.05, 1.0}},
        defense   = {{0.25, 0.45, 0.85, 1.0}, {0.70, 0.85, 1.00, 1.0}},
        joker     = {{1.0, 0.85, 0.20, 1.0},  {0.85, 0.55, 0.10, 1.0}},
        effect    = {{0.35, 0.80, 0.35, 1.0}, {0.85, 1.00, 0.60, 1.0}},
        booster   = {{0.55, 0.30, 0.85, 1.0}, {0.95, 0.65, 0.95, 1.0}},
        exhaust   = {{0.10, 0.10, 0.10, 1.0}, {0.40, 0.20, 0.20, 1.0}},
        default   = {{0.65, 0.45, 0.15, 1.0}, {0.90, 0.75, 0.35, 1.0}},
    }
    return palettes[kind] or palettes.default
end

return DissolveShader
