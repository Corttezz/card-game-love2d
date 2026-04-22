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

-- Desenha `text` em (x, y) com outline preto offset pra legibilidade em qualquer fundo.
-- - color: {r,g,b,a} do texto principal (default branco).
-- - outlineAlpha: alpha do outline preto (default 0.9).
-- - diagonals: se true, usa 8-offset (mais bold); se false/nil, 4-offset padrão.
-- Assume que a fonte correta já foi setada via setFont — a função não troca fonte.
local OUTLINE_OFFSETS_4 = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local OUTLINE_OFFSETS_8 = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }
function FontManager.drawWithOutline(text, x, y, color, outlineAlpha, diagonals)
    local offsets = diagonals and OUTLINE_OFFSETS_8 or OUTLINE_OFFSETS_4
    local alpha = outlineAlpha or 0.9
    love.graphics.setColor(0, 0, 0, alpha)
    for _, o in ipairs(offsets) do
        love.graphics.print(text, x + o[1], y + o[2])
    end
    if color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.print(text, x, y)
end

return FontManager
