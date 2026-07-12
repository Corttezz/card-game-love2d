-- src/ui/RadialGlow.lua
-- Imagem radial 128×128 cacheada (falloff quadrático) pra glows/spotlights
-- baratos: luz de vela do Menu, spotlight dos heróis na seleção de classe.
-- Desenhe com blend "add" e a cor/alpha desejados.

local RadialGlow = {}
local img

function RadialGlow.get()
    if img then return img end
    local N = 128
    local data = love.image.newImageData(N, N)
    data:mapPixel(function(px, py)
        local dx = (px - N / 2) / (N / 2)
        local dy = (py - N / 2) / (N / 2)
        local d = math.sqrt(dx * dx + dy * dy)
        local v = math.max(0, 1 - d)
        v = v * v
        return 1, 1, 1, v
    end)
    img = love.graphics.newImage(data)
    img:setFilter("linear", "linear")
    return img
end

return RadialGlow
