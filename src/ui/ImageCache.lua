-- src/ui/ImageCache.lua
-- Cache global de imagens. Evita recarregar o mesmo PNG várias vezes.
-- Use SEMPRE em vez de love.graphics.newImage direto quando o mesmo asset pode ser usado por múltiplas instâncias.

local ImageCache = {}

local cache = {}
local missCache = {}   -- caminhos que JÁ falharam (não re-tenta nem re-loga)
local FALLBACK_PATH = "assets/cards/attack/theRock.png"
local fallbackImage = nil

-- Carrega (ou retorna do cache) uma imagem. Em erro, retorna fallback.
-- O miss é CACHEADO e logado UMA vez — antes, um PNG faltando em tela
-- (voucher da loja) re-tentava o disco e spammava o log a cada frame.
function ImageCache.get(path)
    if not path or path == "" then
        return ImageCache.getFallback()
    end

    if cache[path] then
        return cache[path]
    end
    if missCache[path] then
        return ImageCache.getFallback()
    end

    local ok, image = pcall(love.graphics.newImage, path)
    if ok then
        cache[path] = image
        return image
    end

    missCache[path] = true
    print("[ImageCache] falha ao carregar: " .. tostring(path))
    return ImageCache.getFallback()
end

-- Como get(), mas retorna NIL no miss (sem fallback) — pra quem quer
-- detectar "arte não existe" e desenhar o próprio fallback (voucher da
-- loja mostrava theRock.png no lugar da arte que faltava).
function ImageCache.tryGet(path)
    if not path or path == "" then return nil end
    if cache[path] then return cache[path] end
    if missCache[path] then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if ok then
        cache[path] = image
        return image
    end
    missCache[path] = true
    print("[ImageCache] falha ao carregar: " .. tostring(path))
    return nil
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
    missCache = {}
    fallbackImage = nil
end

-- Estatísticas (debug).
function ImageCache.stats()
    local count = 0
    for _ in pairs(cache) do count = count + 1 end
    return { entries = count }
end

return ImageCache
