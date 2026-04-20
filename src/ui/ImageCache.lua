-- src/ui/ImageCache.lua
-- Cache global de imagens. Evita recarregar o mesmo PNG várias vezes.
-- Use SEMPRE em vez de love.graphics.newImage direto quando o mesmo asset pode ser usado por múltiplas instâncias.

local ImageCache = {}

local cache = {}
local FALLBACK_PATH = "assets/cards/attack/theRock.png"
local fallbackImage = nil

-- Carrega (ou retorna do cache) uma imagem. Em erro, retorna fallback.
function ImageCache.get(path)
    if not path or path == "" then
        return ImageCache.getFallback()
    end

    if cache[path] then
        return cache[path]
    end

    local ok, image = pcall(love.graphics.newImage, path)
    if ok then
        cache[path] = image
        return image
    end

    print("[ImageCache] falha ao carregar: " .. tostring(path))
    return ImageCache.getFallback()
end

-- Retorna a imagem de fallback (cacheada).
function ImageCache.getFallback()
    if not fallbackImage then
        fallbackImage = love.graphics.newImage(FALLBACK_PATH)
    end
    return fallbackImage
end

-- Pré-carrega uma lista de caminhos (opcional; chamar em love.load).
function ImageCache.preload(paths)
    for _, path in ipairs(paths or {}) do
        ImageCache.get(path)
    end
end

-- Limpa o cache (útil ao trocar contexto pesado, ex: fim de run).
function ImageCache.clear()
    cache = {}
    fallbackImage = nil
end

-- Estatísticas (debug).
function ImageCache.stats()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return { entries = count }
end

return ImageCache
