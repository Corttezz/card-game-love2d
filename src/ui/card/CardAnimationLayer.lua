-- src/ui/card/CardAnimationLayer.lua
-- Overlay animado drawn DEPOIS do canvas estático da carta.
-- Não invalida cache (canvas continua sendo reutilizado); anima pintando em cima.
--
-- Catálogo de overlays (por trigger):
--   legendary             → halo dourado pulsante
--   rare                  → glow interno sutil vermelho
--   joker                 → anel rotativo de 8 pontos dourados
--   bgPattern=fire/rage   → embers subindo
--   bgPattern=blood       → gota de sangue caindo
--   bgPattern=storm       → flash branco ocasional
--   bgPattern=ice         → brilho cristalino pulsante
--
-- API:
--   CardAnimationLayer.draw(card, art, x, y, scaleX, scaleY, t)
--     onde x,y = canto superior esquerdo da carta no screen, scaleX/Y = escala aplicada,
--     e t = love.timer.getTime() (passado pra evitar custo repetido).

local Palette = require("src.ui.Palette")
local AnimatedIconLoader = require("src.ui.AnimatedIconLoader")
local IconFramesLoader  = require("src.ui.IconFramesLoader")
local IconAnimations = require("src.ui.card.IconAnimations")

local CardAnimationLayer = {}

local enabled = true
function CardAnimationLayer.setEnabled(v) enabled = v end
function CardAnimationLayer.isEnabled() return enabled end

-- Dimensões base do canvas da carta (antes da escala)
local CANVAS_W, CANVAS_H = 96, 144

-- ====== Overlays ======

-- Retângulo contornado com alpha (fora do canvas — apenas pintura por cima)
local function drawPulsingBorder(x, y, w, h, color, alpha, thickness)
    thickness = thickness or 2
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    for i = 0, thickness - 1 do
        love.graphics.rectangle("line", x - i, y - i, w + i * 2, h + i * 2)
    end
end

local function legendaryHalo(x, y, sx, sy, t)
    local alpha = 0.25 + math.sin(t * 2.0) * 0.15
    local w = CANVAS_W * sx
    local h = CANVAS_H * sy
    drawPulsingBorder(x, y, w, h, Palette.AGED_GOLD_LIGHT, alpha, 2)
    -- Halo mais solto 4px fora
    drawPulsingBorder(x - 2, y - 2, w + 4, h + 4, Palette.AGED_GOLD, alpha * 0.4, 1)
end

local function rareGlow(x, y, sx, sy, t)
    local alpha = 0.12 + math.sin(t * 2.5) * 0.06
    local w = CANVAS_W * sx
    local h = CANVAS_H * sy
    love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], alpha)
    -- Glow interno: retângulo preenchido sobre a art slot
    local artY = y + 17 * sy
    local artH = 107 * sy
    love.graphics.rectangle("fill", x + 4 * sx, artY, (CANVAS_W - 8) * sx, artH)
end

-- Anel rotativo de 8 pontos em volta do centro da carta (pra joker)
local function jokerRing(x, y, sx, sy, t)
    local cx = x + CANVAS_W * sx / 2
    local cy = y + CANVAS_H * sy / 2
    local radius = math.min(CANVAS_W, CANVAS_H) * sx * 0.28
    local dotSize = math.max(2, 3 * sx)
    love.graphics.setColor(Palette.TAROT_GOLD[1], Palette.TAROT_GOLD[2], Palette.TAROT_GOLD[3], 0.85)
    for i = 0, 7 do
        local a = t * 0.8 + i * math.pi * 2 / 8
        local px = cx + math.cos(a) * radius
        local py = cy + math.sin(a) * radius
        -- Alpha varia por posição (pulsa)
        local alpha = 0.5 + math.sin(t * 3 + i) * 0.3
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha)
        love.graphics.rectangle("fill", px - dotSize / 2, py - dotSize / 2, dotSize, dotSize)
    end
end

-- Embers subindo (fire/rage bg). 4 partículas com posição determinística via t.
local function embers(x, y, sx, sy, t)
    -- Art slot area (dentro da carta)
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy
    for i = 0, 4 do
        local seed = i * 2.7
        -- Posição horizontal varia suavemente
        local px = aX + ((math.sin(t * 0.5 + seed) + 1) / 2) * aW
        -- Altura: wrap-around de baixo pra cima
        local cycle = (t * 20 + i * 30) % 80
        local py = aY + aH - cycle * (aH / 80)
        local alpha = 1 - cycle / 80
        local col = (i % 2 == 0) and Palette.BLOOD or Palette.RUST
        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.9)
        love.graphics.rectangle("fill", px, py, math.max(2, 2 * sx), math.max(2, 2 * sy))
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT[1], Palette.AGED_GOLD_LIGHT[2], Palette.AGED_GOLD_LIGHT[3], alpha * 0.5)
        love.graphics.rectangle("fill", px, py - 1, math.max(1, sx), math.max(1, sy))
    end
end

-- Gota de sangue caindo (blood bg)
local function bloodDrip(x, y, sx, sy, t)
    local aX = x + 8 * sx
    local aY = y + 17 * sy
    local aH = 107 * sy
    local cycle = (t * 30) % 180
    if cycle > aH then return end
    local dropY = aY + cycle
    local alpha = 1 - cycle / aH
    love.graphics.setColor(Palette.BLOOD[1], Palette.BLOOD[2], Palette.BLOOD[3], alpha)
    love.graphics.rectangle("fill", aX, dropY, 2 * sx, 3 * sy)
end

-- Flash de raio ocasional (storm bg)
local function stormFlash(x, y, sx, sy, t)
    -- Trigger uma vez a cada ~2.5s
    local cycle = t % 2.5
    if cycle < 0.08 then
        local w = CANVAS_W * sx
        local h = CANVAS_H * sy
        local alpha = 0.3 * (1 - cycle / 0.08)
        love.graphics.setColor(1, 1, 1, alpha)
        local aX = x + 4 * sx
        local aY = y + 17 * sy
        love.graphics.rectangle("fill", aX, aY, 88 * sx, 107 * sy)
    end
end

-- Brilho cristalino (ice bg) — 3 pontos alternando alpha
local function iceShimmer(x, y, sx, sy, t)
    local points = {
        { 0.3, 0.35 }, { 0.6, 0.45 }, { 0.45, 0.65 },
    }
    local aX = x + 4 * sx
    local aY = y + 17 * sy
    local aW = 88 * sx
    local aH = 107 * sy
    for i, p in ipairs(points) do
        local alpha = math.max(0, math.sin(t * 4 + i * 1.7))
        love.graphics.setColor(1, 1, 1, alpha * 0.7)
        local px = aX + p[1] * aW
        local py = aY + p[2] * aH
        love.graphics.rectangle("fill", px, py, math.max(2, 2 * sx), math.max(2, 2 * sy))
    end
end

-- ====== Dispatcher ======

function CardAnimationLayer.draw(card, art, x, y, scaleX, scaleY, t)
    if not enabled then return end
    scaleX = scaleX or 1
    scaleY = scaleY or 1
    t = t or love.timer.getTime()

    -- Preserva cor vigente (HoloShader pode ter setado)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setBlendMode("alpha")

    local rarity = card.rarity or "common"

    -- Rarity overlays
    if rarity == "legendary" then
        legendaryHalo(x, y, scaleX, scaleY, t)
    elseif rarity == "rare" then
        rareGlow(x, y, scaleX, scaleY, t)
    end

    -- Joker: apenas ring rotativo (ícone estático map_object renderizado pelo canvas)
    if card.type == "joker" then
        jokerRing(x, y, scaleX, scaleY, t)
    end

    -- bgPattern-based overlays
    local bg = art and art.bgPattern
    if bg == "fire" or bg == "rage" then
        embers(x, y, scaleX, scaleY, t)
    elseif bg == "blood" then
        bloodDrip(x, y, scaleX, scaleY, t)
    elseif bg == "storm" then
        stormFlash(x, y, scaleX, scaleY, t)
    elseif bg == "ice" then
        iceShimmer(x, y, scaleX, scaleY, t)
    end

    -- ICON animations para TODOS os tipos (incluindo joker agora):
    -- procedural overlay sutil (shine/drip/sparkle/deity_glow).
    if art and art.iconName then
        local iconX = x + 16 * scaleX
        local iconY = y + 38 * scaleY
        local iconW = 64 * scaleX
        local iconH = 64 * scaleY

        local frames = IconFramesLoader.get(art.iconName)
        if frames then
            local frame = frames:frameAt(t)
            if frame then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(frame, iconX, iconY, 0, scaleX, scaleY)
            end
        else
            IconAnimations.draw(art.iconName, iconX, iconY, iconW, iconH, t)
        end
    end

    -- Restaura
    love.graphics.setColor(r, g, b, a)
end

return CardAnimationLayer
