-- src/ui/FontManager.lua
-- Loader cacheado da fonte pixel default do jogo.
-- Aponta pra assets/fonts/pixel.ttf (Press Start 2P, OFL). Todos os call sites
-- usam getFont/getResponsiveFont e ganham visual pixel automaticamente.
-- Fallback: se o TTF falhar, cai no default do LÖVE com warning no console.

local FontManager = {}
FontManager.__index = FontManager

local DEFAULT_FONT_PATH = "assets/fonts/pixel.ttf"
local FONT_PATH = DEFAULT_FONT_PATH
local fontCache = {}
local ttfAvailable = nil   -- nil = unchecked, true/false = resolvido

local function ttfExists()
    if ttfAvailable ~= nil then return ttfAvailable end
    ttfAvailable = love.filesystem.getInfo(FONT_PATH) ~= nil
    if not ttfAvailable then
        print("[FontManager] AVISO: " .. FONT_PATH .. " não encontrado — usando fonte default do LÖVE.")
    end
    return ttfAvailable
end

-- Define um TTF alternativo (para idiomas com glifos fora do ASCII/latim,
-- como CJK ou cirilico). Limpa cache e re-resolve disponibilidade.
-- Passar nil ou string vazia volta pro pixel.ttf default.
function FontManager.setFontPath(path)
    local newPath = (path and path ~= "") and path or DEFAULT_FONT_PATH
    if newPath == FONT_PATH then return end
    FONT_PATH = newPath
    ttfAvailable = nil   -- forca recheck
    fontCache = {}        -- invalida cache, sera regenerado on-demand
    print("[FontManager] font path agora: " .. FONT_PATH)
end

function FontManager.getFontPath() return FONT_PATH end

function FontManager:new()
    return setmetatable({}, FontManager)
end

-- Obtém fonte pixel no tamanho pedido. Cache por tamanho.
-- `setFilter("nearest", ...)` é crítico — sem isso a fonte fica borrada
-- mesmo sendo pixel TTF.
function FontManager.getFont(size)
    size = math.max(1, math.floor(size or 12))
    local key = tostring(size)

    if not fontCache[key] then
        local font
        if ttfExists() then
            local ok, result = pcall(love.graphics.newFont, FONT_PATH, size)
            if ok then
                font = result
            else
                print("[FontManager] Falha ao carregar " .. FONT_PATH .. " @ " .. size .. ": " .. tostring(result))
            end
        end
        if not font then
            font = love.graphics.newFont(size)  -- fallback default LÖVE
        end
        font:setFilter("nearest", "nearest")
        fontCache[key] = font
    end

    return fontCache[key]
end

-- Fonte responsiva à altura da janela, clampada por maxSize.
function FontManager.getResponsiveFont(ratio, maxSize)
    local height = love.graphics.getHeight()
    local size = math.min(maxSize, math.floor(height * ratio))
    return FontManager.getFont(size)
end

-- Invalida cache (chamar em love.resize).
function FontManager.clearCache()
    fontCache = {}
end

-- Debug: estatísticas do cache.
function FontManager.getCacheStats()
    local count = 0
    for _ in pairs(fontCache) do count = count + 1 end
    return { totalFonts = count, cacheSize = count }
end

return FontManager
