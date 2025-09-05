-- src/FontManager.lua
-- Sistema de cache de fontes para melhorar performance

local FontManager = {}
FontManager.__index = FontManager

-- Cache de fontes
local fontCache = {}

function FontManager:new()
    local instance = setmetatable({}, FontManager)
    return instance
end

-- Obtém uma fonte com tamanho específico (com cache)
function FontManager.getFont(size)
    local key = tostring(size)
    
    if not fontCache[key] then
        fontCache[key] = love.graphics.newFont(size)
    end
    
    return fontCache[key]
end

-- Obtém uma fonte responsiva baseada na altura da tela
function FontManager.getResponsiveFont(ratio, maxSize)
    local height = love.graphics.getHeight()
    local size = math.min(maxSize, height * ratio)
    return FontManager.getFont(size)
end

-- Limpa o cache de fontes (útil para mudanças de resolução)
function FontManager.clearCache()
    fontCache = {}
end

-- Obtém estatísticas do cache
function FontManager.getCacheStats()
    local count = 0
    for _ in pairs(fontCache) do
        count = count + 1
    end
    return {
        totalFonts = count,
        cacheSize = count
    }
end

return FontManager


