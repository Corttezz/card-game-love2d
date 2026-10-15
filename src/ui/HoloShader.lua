local Debug = require("src.core.Debug")

local HoloShader = {}

local shader
local loaded = false

function HoloShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/holo.glsl")
    if not ok then
        Debug.warn("[HoloShader] falha ao carregar shaders/holo.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function HoloShader.isAvailable()
    return loaded
end

function HoloShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy, opts)
    strength = math.max(0, math.min(1, strength or 0.5))
    if not loaded or strength < 0.005 then
        love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    local anim = opts and opts.anim or 0
    love.graphics.setShader(shader)
    shader:send("time", anim > 0 and love.timer.getTime() or 0)
    shader:send("strength", strength)
    shader:send("kind", opts and opts.kind or 1)
    shader:send("anim", math.max(0, math.min(1, anim)))
    local iw, ih = image:getWidth(), image:getHeight()
    shader:send("cardSize", { iw, ih })
    local pad = opts and opts.pad or 0
    local hx, hy = (pad + 0.5) / iw, (pad + 0.5) / ih
    shader:send("innerUV", { hx, hy, 1 - hx, 1 - hy })
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

HoloShader.REST = { glow = 0, holo = 0.08 }
HoloShader.FULL = { glow = 0.25, holo = 0.5 }
function HoloShader.strengthFor(fx, gate)
    local rest, full = HoloShader.REST[fx] or 0, HoloShader.FULL[fx] or 0
    gate = math.max(0, math.min(1, gate or 0))
    return rest + (full - rest) * gate
end

return HoloShader
