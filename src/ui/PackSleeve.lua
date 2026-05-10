-- src/ui/PackSleeve.lua
-- Renderiza o "envelope" (sleeve) de um booster pack — a carta selada que
-- aparece centralizada antes de explodir e revelar o conteúdo.
--
-- Estratégia atual (pré-PixelLab):
--   • Tenta carregar PNG em assets/sprites/packs/<id>.png se existir.
--   • Senão gera um canvas procedural com palette por kind + booster shader.
--
-- Quando PixelLab gerar os PNGs (ver memory/pixellab_queue_packs.md), o branch
-- procedural vira fallback de erro só.

local PackSleeve = {}

local ImageCache    = require("src.ui.ImageCache")
local PixelCanvas   = require("src.ui.PixelCanvas")
local Palette       = require("src.ui.Palette")
local FontManager   = require("src.ui.FontManager")
local BoosterShader = require("src.ui.BoosterShader")

-- Paleta + glyph por kind (usado quando PNG não existe).
local KIND_STYLES = {
    Standard = {
        bg = {0.85, 0.78, 0.55, 1},        -- pergaminho amarelado
        accent = {0.65, 0.18, 0.12, 1},    -- selo vermelho
        outline = {0.20, 0.13, 0.08, 1},
        glyph = "✦",
        title = "PACOTE\nPADRÃO",
    },
    Buffoon = {
        bg = {0.55, 0.20, 0.18, 1},        -- couro vermelho
        accent = {0.90, 0.78, 0.20, 1},    -- bordas dourado
        outline = {0.10, 0.05, 0.05, 1},
        glyph = "♛",
        title = "PACOTE\nBUFÃO",
    },
    Arcana = {
        bg = {0.18, 0.13, 0.30, 1},        -- indigo profundo
        accent = {0.85, 0.65, 0.20, 1},    -- olho dourado
        outline = {0.08, 0.05, 0.15, 1},
        glyph = "☉",
        title = "PACOTE\nARCANO",
    },
    Celestial = {
        bg = {0.10, 0.18, 0.35, 1},        -- navy
        accent = {0.85, 0.85, 0.95, 1},    -- prata
        outline = {0.05, 0.10, 0.18, 1},
        glyph = "✧",
        title = "PACOTE\nCELESTIAL",
    },
    Spectral = {
        bg = {0.18, 0.30, 0.18, 1},        -- pálido fantasmagórico
        accent = {0.55, 0.85, 0.65, 1},    -- glow verde
        outline = {0.05, 0.10, 0.05, 1},
        glyph = "☠",
        title = "PACOTE\nESPECTRAL",
    },
}

-- Cache de canvases procedurais por kind (evita regerar todo frame).
local proceduralCache = {}

-- Tenta achar PNG em assets/sprites/packs/<id>.png. Retorna ImageData ou nil.
local function tryLoadPNG(packId)
    if not packId then return nil end
    local path = "assets/sprites/packs/" .. packId .. ".png"
    if love.filesystem.getInfo(path) then
        return ImageCache.get(path)
    end
    return nil
end

-- Gera canvas procedural pra um kind. Cache por kind.
local function buildProcedural(kind)
    if proceduralCache[kind] then return proceduralCache[kind] end
    local style = KIND_STYLES[kind] or KIND_STYLES.Standard

    local W, H = 128, 192
    local canvas = love.graphics.newCanvas(W, H)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)

    -- Fundo do envelope.
    PixelCanvas.rect(0, 0, W, H, style.bg)
    -- Borda dupla (outline grosso + accent fino dentro).
    PixelCanvas.rectOutline(0, 0, W, H, style.outline)
    PixelCanvas.rectOutline(2, 2, W - 4, H - 4, style.accent)
    PixelCanvas.rectOutline(4, 4, W - 8, H - 8, style.outline)

    -- "Selo" central — disco com glyph.
    local cx, cy = W * 0.5, H * 0.5
    love.graphics.setColor(style.outline)
    love.graphics.circle("fill", cx, cy, 28)
    love.graphics.setColor(style.accent)
    love.graphics.circle("fill", cx, cy, 24)
    love.graphics.setColor(style.outline)
    love.graphics.circle("line", cx, cy, 24)

    -- Glyph no selo.
    local glyphFont = FontManager.getFont(28)
    love.graphics.setFont(glyphFont)
    love.graphics.setColor(style.outline)
    local gw = glyphFont:getWidth(style.glyph)
    local gh = glyphFont:getHeight()
    love.graphics.print(style.glyph, cx - gw * 0.5, cy - gh * 0.5)

    -- Título empilhado embaixo (multilinha).
    local titleFont = FontManager.getFont(10)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(style.accent)
    love.graphics.printf(style.title, 0, H - 36, W, "center")

    -- Cantos decorativos (4 pequenos rects nas pontas).
    for _, p in ipairs({
        {6, 6}, {W - 14, 6}, {6, H - 14}, {W - 14, H - 14},
    }) do
        PixelCanvas.rect(p[1], p[2], 8, 8, style.accent)
        PixelCanvas.rectOutline(p[1], p[2], 8, 8, style.outline)
    end

    love.graphics.pop()
    love.graphics.setCanvas(prevCanvas)

    proceduralCache[kind] = canvas
    return canvas
end

-- Retorna a Image (PNG do PixelLab OU canvas procedural) pra um pack.
-- Prioridade: PNG > procedural por kind > Standard fallback.
function PackSleeve.getImage(packId, kind)
    local png = tryLoadPNG(packId)
    if png then return png end
    return buildProcedural(kind or "Standard")
end

-- Desenha o sleeve já com booster shader aplicado (iridescente animado).
-- (cx, cy) é o centro do desenho. scale opcional (default 1).
-- alpha opcional (default 1) — usado pelo PackOpenScreen pra fade no explode.
-- Esta função RESPEITA a alpha externa em vez de sobrescrever (bug F7.5).
function PackSleeve.drawAt(packId, kind, cx, cy, scale, alpha)
    scale = scale or 1
    alpha = alpha == nil and 1 or alpha
    if alpha <= 0.001 then return end

    local img = PackSleeve.getImage(packId, kind)
    if not img then return end

    local w = img:getWidth() * scale
    local h = img:getHeight() * scale

    if BoosterShader.isAvailable() then
        BoosterShader.apply(img, love.timer.getTime(), 0)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, cx - w * 0.5, cy - h * 0.5, 0, scale, scale)
        BoosterShader.clear()
    else
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(img, cx - w * 0.5, cy - h * 0.5, 0, scale, scale)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackSleeve.getDimensions()
    return 128, 192
end

return PackSleeve
