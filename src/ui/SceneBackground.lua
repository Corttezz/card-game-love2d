-- src/ui/SceneBackground.lua
-- Carrega e desenha backgrounds de tela cheia gerados via PixelLab.
-- Arquivos esperados em assets/sprites/scenes/<scene>.png.
-- Cena desenha o PNG escalado pra ocupar toda a tela (nearest) + overlay escuro
-- suave pra não competir com conteúdo.
--
-- Uso:
--   if SceneBackground.draw("menu", width, height) then ... end
--
-- Cenas conhecidas: menu, gameplay, collection, gameOver, victory, classSelection, cardReward.

local Palette = require("src.ui.Palette")

local SceneBackground = {}

local cache = {}
local missCache = {}

local function load(scene)
    if cache[scene] then return cache[scene] end
    if missCache[scene] then return nil end
    local path = "assets/sprites/scenes/" .. scene .. ".png"
    if not love.filesystem.getInfo(path) then
        missCache[scene] = true
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        missCache[scene] = true
        return nil
    end
    img:setFilter("nearest", "nearest")
    cache[scene] = img
    return img
end

-- Desenha a cena ocupando toda a janela. Retorna true se o PNG existe.
function SceneBackground.draw(scene, width, height, overlayAlpha)
    local img = load(scene)
    if not img then return false end
    overlayAlpha = overlayAlpha or 0.35

    local iw, ih = img:getWidth(), img:getHeight()
    local sx = width / iw
    local sy = height / ih
    -- Usa o maior pra cobrir (cover); centraliza o excedente
    local s = math.max(sx, sy)
    local dw = iw * s
    local dh = ih * s
    local ox = (width - dw) / 2
    local oy = (height - dh) / 2

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, ox, oy, 0, s, s)

    -- Overlay escuro pra suavizar legibilidade do texto por cima
    if overlayAlpha > 0 then
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], overlayAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end

    love.graphics.setColor(1, 1, 1, 1)
    return true
end

-- Desenha a cena com ZOOM extra + offset de parallax (o zoom cria a folga
-- pra imagem deslocar sem mostrar borda). offX/offY em pixels de tela.
-- Retorna (true, transform) se o PNG existe — transform = {scale, ox, oy}
-- pra ancorar elementos na imagem (ex: brilho das velas do Menu v2.1).
function SceneBackground.drawParallax(scene, width, height, overlayAlpha, offX, offY, zoom)
    local img = load(scene)
    if not img then return false end
    overlayAlpha = overlayAlpha or 0.35
    zoom = zoom or 1.06
    offX, offY = offX or 0, offY or 0

    local iw, ih = img:getWidth(), img:getHeight()
    local s = math.max(width / iw, height / ih) * zoom
    local dw, dh = iw * s, ih * s
    -- offset limitado à folga do zoom (nunca mostra borda)
    local slackX = (dw - width) / 2
    local slackY = (dh - height) / 2
    offX = math.max(-slackX, math.min(slackX, offX))
    offY = math.max(-slackY, math.min(slackY, offY))
    local ox = (width - dw) / 2 + offX
    local oy = (height - dh) / 2 + offY

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, ox, oy, 0, s, s)
    if overlayAlpha > 0 then
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], overlayAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end
    love.graphics.setColor(1, 1, 1, 1)
    return true, { scale = s, ox = ox, oy = oy, dw = dw, dh = dh }
end

-- Como drawParallax, mas faz CROSSFADE entre duas cenas (mesmo tamanho) —
-- usado pela animação de vela do Menu (frames de flicker desenhados à mão).
-- `mix` 0 = 100% sceneA, 1 = 100% sceneB. As duas usam o MESMO transform
-- (calculado a partir de sceneA), e o overlay ink é aplicado UMA vez no fim.
-- Retorna (true, transform) igual ao drawParallax.
function SceneBackground.drawParallaxCrossfade(sceneA, sceneB, mix, width, height,
                                               overlayAlpha, offX, offY, zoom)
    local imgA = load(sceneA)
    if not imgA then return false end
    local imgB = load(sceneB) or imgA
    mix = math.max(0, math.min(1, mix or 0))
    overlayAlpha = overlayAlpha or 0.35
    zoom = zoom or 1.06
    offX, offY = offX or 0, offY or 0

    local iw, ih = imgA:getWidth(), imgA:getHeight()
    local s = math.max(width / iw, height / ih) * zoom
    local dw, dh = iw * s, ih * s
    local slackX = (dw - width) / 2
    local slackY = (dh - height) / 2
    offX = math.max(-slackX, math.min(slackX, offX))
    offY = math.max(-slackY, math.min(slackY, offY))
    local ox = (width - dw) / 2 + offX
    local oy = (height - dh) / 2 + offY

    -- base sempre opaca (evita "vazar" preto no meio do crossfade); o alvo
    -- entra por cima com alpha = mix.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(imgA, ox, oy, 0, s, s)
    if mix > 0 then
        love.graphics.setColor(1, 1, 1, mix)
        love.graphics.draw(imgB, ox, oy, 0, s, s)
    end
    if overlayAlpha > 0 then
        love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], overlayAlpha)
        love.graphics.rectangle("fill", 0, 0, width, height)
    end
    love.graphics.setColor(1, 1, 1, 1)
    return true, { scale = s, ox = ox, oy = oy, dw = dw, dh = dh }
end

function SceneBackground.has(scene)
    return load(scene) ~= nil
end

-- Retorna (imgW, imgH) da scene. Útil pra computar o mesmo cover-fit que draw
-- faz e converter coordenadas PNG → coordenadas de tela.
function SceneBackground.getSize(scene)
    local img = load(scene)
    if not img then return nil, nil end
    return img:getWidth(), img:getHeight()
end

-- Retorna o transform cover-fit que `draw(scene, width, height)` aplica:
--   { scale, dw, dh, ox, oy }
-- onde a scene PNG é renderizada em (ox, oy) com dimensões (dw, dh).
-- Use pra mapear (em.xr, em.yr) normalizado da PNG para coordenadas de tela:
--   screenX = ox + em.xr * dw
--   screenY = oy + em.yr * dh
function SceneBackground.getCoverTransform(scene, width, height)
    local iw, ih = SceneBackground.getSize(scene)
    if not iw then return nil end
    local sx = width / iw
    local sy = height / ih
    local s = math.max(sx, sy)
    local dw = iw * s
    local dh = ih * s
    return {
        scale = s,
        dw = dw, dh = dh,
        ox = (width - dw) / 2,
        oy = (height - dh) / 2,
        imgW = iw, imgH = ih,
    }
end

function SceneBackground.clearCache()
    cache = {}
    missCache = {}
end

return SceneBackground
