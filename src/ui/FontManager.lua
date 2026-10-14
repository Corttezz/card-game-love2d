local Debug = require("src.core.Debug")

local FontManager = {}
FontManager.__index = FontManager

local DEFAULT_FONT_PATH = "assets/fonts/pixel.ttf"
local FONT_PATH = DEFAULT_FONT_PATH
local fontCache = {}
local ttfAvailable = nil
local UiScale

local function ttfExists()
    if ttfAvailable ~= nil then return ttfAvailable end
    ttfAvailable = love.filesystem.getInfo(FONT_PATH) ~= nil
    if not ttfAvailable then
        Debug.warn("[FontManager] AVISO: " .. FONT_PATH .. " não encontrado — usando fonte default do LÖVE.")
    end
    return ttfAvailable
end

function FontManager.setFontPath(path)
    local newPath = (path and path ~= "") and path or DEFAULT_FONT_PATH
    if newPath == FONT_PATH then return end
    FONT_PATH = newPath
    ttfAvailable = nil
    fontCache = {}
    require("src.core.Debug").log("[FontManager] font path agora: " .. FONT_PATH)
end

function FontManager.getFontPath() return FONT_PATH end

function FontManager:new()
    return setmetatable({}, FontManager)
end

function FontManager.getFont(size)
    size = math.max(1, math.floor(size or 12))
    UiScale = UiScale or require("src.ui.UiScale")
    local dpi = UiScale.fontDpi()
    local key = dpi == 1 and tostring(size) or (size .. "@" .. dpi)

    if not fontCache[key] then
        local font
        if ttfExists() then
            local ok, result = pcall(love.graphics.newFont, FONT_PATH, size, "normal", dpi)
            if ok then
                font = result
            else
                Debug.warn("[FontManager] Falha ao carregar " .. FONT_PATH .. " @ " .. size .. ": " .. tostring(result))
            end
        end
        if not font then
            font = love.graphics.newFont(size, "normal", dpi)
        end
        font:setFilter("nearest", "nearest")
        fontCache[key] = font
    end

    return fontCache[key]
end

function FontManager.getResponsiveFont(ratio, maxSize)
    local height = love.graphics.getHeight()
    local size = math.min(maxSize, math.floor(height * ratio))
    return FontManager.getFont(size)
end

function FontManager.clearCache()
    fontCache = {}
end

function FontManager.getCacheStats()
    local count = 0
    for _ in pairs(fontCache) do count = count + 1 end
    return { totalFonts = count, cacheSize = count }
end

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
