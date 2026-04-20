-- src/ui/IconLoader.lua
-- Resolve um nome de ícone para um "handle" desenhável.
-- Prefere PNGs em assets/sprites/icons/<name>.png (alta qualidade via pixel-mcp).
-- Fallback: matrizes em PixelIcons.lua (arte base feita a mão).
--
-- Handle retornado:
--   {
--     kind = "image" | "matrix",
--     draw = function(x, y, scale?) -- desenha o ícone em (x, y) com escala opcional
--     size = { w, h }               -- dimensões naturais (antes da escala)
--   }

local PixelIcons  = require("src.ui.PixelIcons")
local PixelCanvas = require("src.ui.PixelCanvas")
local ImageCache  = require("src.ui.ImageCache")

local IconLoader = {}

local handleCache = {}

-- Tenta carregar PNG; retorna Image ou nil.
local function tryLoadPNG(name)
    local path = "assets/sprites/icons/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        img:setFilter("nearest", "nearest")
        return img
    end
    return nil
end

-- Retorna um handle para o ícone `name`.
function IconLoader.get(name)
    if handleCache[name] then return handleCache[name] end

    local png = tryLoadPNG(name)
    if png then
        local h = {
            kind = "image",
            image = png,
            size = { w = png:getWidth(), h = png:getHeight() },
            draw = function(x, y, scale)
                scale = scale or 1
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(png, math.floor(x), math.floor(y), 0, scale, scale)
            end,
        }
        handleCache[name] = h
        return h
    end

    -- Fallback: matriz
    local matrix = PixelIcons.get(name)
    local size = #matrix > 0 and { w = #matrix[1], h = #matrix } or { w = 16, h = 16 }
    local h = {
        kind = "matrix",
        matrix = matrix,
        size = size,
        draw = function(x, y, scale)
            PixelCanvas.drawBitmapScaled(matrix, x, y, scale or 1)
        end,
    }
    handleCache[name] = h
    return h
end

-- Invalida cache (ex: após novo PNG aparecer no disco).
function IconLoader.clearCache()
    handleCache = {}
end

return IconLoader
