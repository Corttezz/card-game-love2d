-- src/ui/CardGridRender.lua
-- Render de carta "mini" num grid, com warp 3D (mesh+shader), sombra direcional
-- e camada de animação de ícone — IDÊNTICO ao drawCardMini da CollectionScreen.
-- Extraído pra ser COMPARTILHADO: o Deck Viewer da run usa exatamente o mesmo
-- caminho de render que a aba de Coleção, então o hover (profundidade/tilt/
-- sombra/ícone vivo) fica igualzinho (pedido do Daniel: "tudo idêntico").
--
-- draw(instance, x, y, cardW, cardH, hoverScale, alpha, mouseUV, hoverStrength)
--   mouseUV: vec2 [-1,1] relativo ao centro da carta (0,0 = sem press)
--   hoverStrength: 0..1 (usa pro warp + pro offset tilt da sombra)

local Config             = require("src.core.Config")
local CardMesh           = require("src.ui.CardMesh")
local CardArt            = require("src.ui.CardArt")
local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")

local M = {}

function M.draw(instance, x, y, cardW, cardH, hoverScale, alpha, mouseUV, hoverStrength)
    if not instance.image then return end
    hoverScale = hoverScale or 1
    alpha = alpha or 1
    mouseUV = mouseUV or { 0, 0 }
    hoverStrength = hoverStrength or 0

    local baseScale = cardW / instance.image:getWidth()
    local drawScale = baseScale * hoverScale
    local drawW = instance.image:getWidth() * drawScale
    local drawH = instance.image:getHeight() * drawScale
    -- Lift visual quando hover (carta sobe em direção ao cursor)
    local lift = (hoverScale - 1) * 30
    local cx = x + cardW / 2
    local cy = y + cardH / 2 - lift

    -- Sombra direcional (luz acima do centro + press shift oposto)
    local screenW = love.graphics.getWidth()
    local dirX = (cx - screenW / 2) / (screenW / 2)
    if dirX > 1 then dirX = 1 elseif dirX < -1 then dirX = -1 end
    local shadowMaxX = (Config.Cards and Config.Cards.SHADOW_MAX_HORIZ_OFFSET) or 20
    local shadowBaseY = (Config.Cards and Config.Cards.SHADOW_BASE_OFFSET_Y) or 6
    local shadowPressShift = (Config.Cards and Config.Cards.SHADOW_PRESS_SHIFT) or 14
    local shadowBaseAlpha = (Config.Cards and Config.Cards.SHADOW_ALPHA) or 0.50
    local baseLift = (Config.Cards and Config.Cards.BASE_LIFT) or 3

    local shadowDx = -dirX * shadowMaxX - mouseUV[1] * shadowPressShift * hoverStrength
    local shadowDy = shadowBaseY + (baseLift + lift) * 0.5
                   - mouseUV[2] * shadowPressShift * hoverStrength * 0.7
    local shAlpha = shadowBaseAlpha * alpha + (hoverScale - 1) * 0.4
    if shAlpha > 0.85 then shAlpha = 0.85 end

    local px = math.floor(cx - drawW / 2)
    local py = math.floor(cy - drawH / 2)

    local shader = CardMesh.getShader()
    local timeNow = love.timer.getTime()
    if shader then
        local mesh = CardMesh.getMesh(instance.image:getWidth(), instance.image:getHeight())
        mesh:setTexture(instance.image)
        love.graphics.setShader(shader)
        CardMesh.setUniforms(shader, mouseUV, hoverStrength, timeNow, instance.image)
        love.graphics.setColor(0, 0, 0, shAlpha)
        love.graphics.draw(mesh, px + shadowDx, py + shadowDy, 0, drawScale, drawScale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(mesh, px, py, 0, drawScale, drawScale)
        love.graphics.setShader()
    else
        love.graphics.setColor(0, 0, 0, shAlpha)
        love.graphics.draw(instance.image,
            math.floor(px + shadowDx), math.floor(py + shadowDy),
            0, drawScale, drawScale)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(instance.image, px, py, 0, drawScale, drawScale)
    end

    -- Icon animations por cima (ícone vivo — mesma camada da Coleção)
    if not instance._cachedArt then
        local ok, a = pcall(CardArt.resolve, instance)
        instance._cachedArt = ok and a or { bgPattern = nil }
    end
    CardAnimationLayer.draw(instance, instance._cachedArt, px, py, drawScale, drawScale)
    love.graphics.setColor(1, 1, 1, 1)
end

return M
