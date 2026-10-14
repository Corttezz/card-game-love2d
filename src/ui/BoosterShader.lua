local Debug = require("src.core.Debug")

local BoosterShader = {}

local shader
local loaded = false
local hasSheen = false

local WHITE = {1, 1, 1}

function BoosterShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/booster.glsl")
    if not ok then
        Debug.warn("[BoosterShader] falha ao carregar shaders/booster.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    hasSheen = (s.hasUniform ~= nil)
        and s:hasUniform("sheen") and s:hasUniform("sheen_amt")
    if not hasSheen then
        Debug.warn("[BoosterShader] AVISO: shader sem os uniforms de sheen — o foil "
            .. "vai sair no arco-íris genérico, sem a cor do tipo de pacote.")
    end
    return true
end

function BoosterShader.isAvailable()
    return loaded
end

function BoosterShader.apply(image, phase, dissolve, sheen, amount)
    if not loaded then return false end
    love.graphics.setShader(shader)
    shader:send("booster", {phase or love.timer.getTime(), 0})
    shader:send("dissolve", dissolve or 0)
    shader:send("time", love.timer.getTime())
    shader:send("texture_details", {0, 0, image:getWidth(), image:getHeight()})
    shader:send("image_details", {image:getWidth(), image:getHeight()})
    shader:send("burn_colour_1", {0, 0, 0, 0})
    shader:send("burn_colour_2", {0, 0, 0, 0})
    shader:send("shadow", false)
    if hasSheen then
        shader:send("sheen", sheen or WHITE)
        shader:send("sheen_amt", amount or 0)
    end
    return true
end

function BoosterShader.clear()
    love.graphics.setShader()
end

function BoosterShader.draw(image, x, y, phase, dissolve, r, sx, sy, ox, oy)
    if not BoosterShader.apply(image, phase, dissolve) then
        love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    BoosterShader.clear()
end

return BoosterShader
