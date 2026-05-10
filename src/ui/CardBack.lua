-- src/ui/CardBack.lua
-- Desenha a "costa" (verso) de uma carta usando o MESMO pipeline 3D que
-- Card.lua usa em hover (CardMesh + shader card_perspective.glsl + sombra
-- direcional). Diferença vs Card.lua: aqui é só uma textura PNG estática,
-- sem mesh de art slot / banner / overlay holo. Mas o WARP de perspectiva
-- e a sombra são idênticos.
--
-- Estratégia:
--   1. Tenta carregar `assets/cards/back.png` (gerado via PixelLab).
--   2. Se ausente, fallback geométrico (corpo INK + borda gold + sigilo).
--
-- Compartilhado por BootScene (cascade do splash) e Menu (cartas flutuantes).
--
-- Uso (com hover state):
--   CardBack.draw(cx, cy, w, h, {
--       alpha = 1, scale = 1, rot = 0, dissolve = 0,
--       tiltX = 0, tiltY = 0,             -- radianos (em TILT_RANGE units)
--       hoverStrength = 0,                -- 0..1 (intensidade do warp)
--       liftOffset = 0,                   -- pixels (negativo = sobe)
--       perspectiveRotation = 0,          -- radianos (Z tilt)
--   })

local Palette  = require("src.ui.Palette")
local CardMesh = require("src.ui.CardMesh")

local BACK_PATH = "assets/cards/back.png"

local CardBack = {}

-- Image cache local. Tenta load uma vez; cacheia o resultado.
local _img
local _triedLoad = false

-- Raio em pixels do chamfer dos 4 cantos (na resolução nativa do PNG).
-- 5 px no PNG 192x288 = ~3 px quando renderizado a 96x144. Suficiente pra
-- esconder o pixel preto no canto e fazer a sombra acompanhar a borda
-- arredondada (sombra herda alpha mask do mesh + textura).
local CORNER_RADIUS = 5

-- Aplica alpha-mask circular em cada canto da ImageData. Pixels fora do
-- arco viram (0,0,0,0) — assim a textura passa a ter cantos transparentes,
-- e o shader (que multiplica color * texel) propaga isso pro shadow também.
local function roundCorners(imgData, r)
    local w, h = imgData:getWidth(), imgData:getHeight()
    -- Centros dos arcos em cada canto (a r,r de distância da quina).
    local cx = { r, w - 1 - r, r,         w - 1 - r }
    local cy = { r, r,         h - 1 - r, h - 1 - r }
    -- Bbox de cada canto (não percorre a imagem inteira).
    local boxX = { 0, w - r, 0,     w - r }
    local boxY = { 0, 0,     h - r, h - r }
    local r2 = r * r
    for i = 1, 4 do
        for x = boxX[i], boxX[i] + r - 1 do
            for y = boxY[i], boxY[i] + r - 1 do
                local dx = x - cx[i]
                local dy = y - cy[i]
                if dx * dx + dy * dy > r2 then
                    imgData:setPixel(x, y, 0, 0, 0, 0)
                end
            end
        end
    end
end

local function loadBackImage()
    if _triedLoad then return _img end
    _triedLoad = true
    if not love.filesystem.getInfo(BACK_PATH) then return nil end

    -- Load ImageData (mutável) pra arredondar cantos antes de virar Image.
    local okData, imgData = pcall(love.image.newImageData, BACK_PATH)
    if not okData or not imgData then
        -- Fallback: load como Image direto (sem rounding).
        local ok, img = pcall(love.graphics.newImage, BACK_PATH)
        if ok and img then img:setFilter("nearest", "nearest"); _img = img end
        return _img
    end

    roundCorners(imgData, CORNER_RADIUS)

    local ok, img = pcall(love.graphics.newImage, imgData)
    if ok and img then
        img:setFilter("nearest", "nearest")
        _img = img
    end
    return _img
end

function CardBack.reload()
    _img = nil
    _triedLoad = false
end

-- Constantes de hover/sombra. Mesmos valores que Card.lua usa via
-- Config.Cards (TILT_RANGE 0.15, SHADOW_BASE_OFFSET_Y 6, etc).
local TILT_RANGE              = 0.15
local SHADOW_BASE_OFFSET_Y    = 6
local SHADOW_MAX_HORIZ_OFFSET = 20
local SHADOW_PRESS_SHIFT      = 14
local SHADOW_ALPHA            = 0.50
local BASE_LIFT               = 3

function CardBack.draw(x, y, w, h, opts)
    opts = opts or {}
    local alpha    = opts.alpha or 1
    local scale    = opts.scale or 1
    local rot      = opts.rot or 0
    local dissolve = opts.dissolve or 0

    -- Estado de hover (0 a 1) e tilts em radianos (TILT_RANGE units).
    local tiltX               = opts.tiltX or 0
    local tiltY               = opts.tiltY or 0
    local hoverStrength       = opts.hoverStrength or 0
    local liftOffset          = opts.liftOffset or 0
    local perspectiveRotation = opts.perspectiveRotation or 0

    if alpha <= 0 then return end
    local a = alpha * (1 - dissolve)
    if a <= 0 then return end

    local img = loadBackImage()
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sx = (w / iw) * scale
        local sy = (h / ih) * scale

        -- mouseUV normalizado em [-1, 1] pro shader (mesma fórmula de Card.lua).
        local mouseUV = {
            math.max(-1, math.min(1, tiltX / TILT_RANGE)),
            math.max(-1, math.min(1, tiltY / TILT_RANGE)),
        }

        -- Baseline lift: BASE_LIFT (carta flutua) + liftOffset (hover lift).
        -- Negativo = carta sobe.
        local totalLift = liftOffset - BASE_LIFT

        -- Shadow offset: combina dirX (posição na tela), tilt e lift.
        local screenW = love.graphics.getWidth()
        local cardCxAbs = x
        local dirX = math.max(-1, math.min(1, (cardCxAbs - screenW / 2) / (screenW / 2)))
        local shadowOffsetX = -dirX * SHADOW_MAX_HORIZ_OFFSET
                            - mouseUV[1] * SHADOW_PRESS_SHIFT * hoverStrength
        local liftMag = math.abs(liftOffset) + BASE_LIFT
        local shadowOffsetY = SHADOW_BASE_OFFSET_Y + liftMag * 0.5
                            - mouseUV[2] * SHADOW_PRESS_SHIFT * hoverStrength * 0.7
        local shadowAlpha = (SHADOW_ALPHA + liftMag * 0.003) * a
        if shadowAlpha > 0.85 then shadowAlpha = 0.85 end

        -- Push transform: translate ao centro da carta (incluindo lift), rotate Z + perspective.
        love.graphics.push()
        love.graphics.translate(x, y + totalLift)
        love.graphics.rotate(rot + perspectiveRotation)
        love.graphics.scale(sx, sy)

        local drawX = -iw / 2
        local drawY = -ih / 2

        local shader = CardMesh.getShader()
        local timeNow = love.timer.getTime()

        -- ===== Sombra warpada (mesma deformação do card) =====
        if shader then
            local mesh = CardMesh.getMesh(iw, ih)
            mesh:setTexture(img)
            love.graphics.setShader(shader)
            CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, img)
            love.graphics.setColor(0, 0, 0, shadowAlpha)
            love.graphics.draw(mesh, drawX + shadowOffsetX / sx, drawY + shadowOffsetY / sy)

            -- ===== Card principal (mesmo mesh+shader) =====
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(mesh, drawX, drawY)
            love.graphics.setShader()
        else
            -- Fallback sem shader: draw plano.
            love.graphics.setColor(0, 0, 0, shadowAlpha)
            love.graphics.draw(img, drawX + shadowOffsetX / sx, drawY + shadowOffsetY / sy)
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(img, drawX, drawY)
        end

        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    -- ============== Path 2: fallback geométrico (sem PNG) ==============
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rot)
    love.graphics.scale(scale, scale)

    local hw, hh = w / 2, h / 2

    love.graphics.setColor(0, 0, 0, 0.55 * a)
    love.graphics.rectangle("fill", -hw + 4, -hh + 4, w, h)

    love.graphics.setColor(Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3], a)
    love.graphics.rectangle("fill", -hw, -hh, w, h)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], a)
    love.graphics.rectangle("line", -hw, -hh, w, h)

    love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2], Palette.PARCHMENT_DARK[3], a)
    local cs = math.min(w, h) * 0.22
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 0, -cs, cs, 0, 0, cs, -cs, 0)

    love.graphics.setLineWidth(1)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return CardBack
