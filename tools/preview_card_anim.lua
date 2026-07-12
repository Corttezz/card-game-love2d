-- tools/preview_card_anim.lua
-- Contact sheet de carta com ícone ANIMADO (icons_anim/): renderiza a carta
-- em N instantes do loop (canvas estático do CardFrame + CardAnimationLayer
-- com t fixo) pra validar geometria (cover-fit/crop) e vida do movimento
-- sem abrir o jogo.
--
-- Uso:  love . preview_card_anim [card_id]     (default: warrior_standard_bearer)
-- Saída: ~/.local/share/love/card-game/preview_card_anim.png

local M = {}

function M.run(cardId)
    cardId = cardId or "warrior_standard_bearer"
    require("src.ui.PixelCanvas").enableNearest()
    local I18n = require("src.i18n.I18n")
    I18n.init()

    local CardDatabase       = require("src.systems.CardDatabase")
    local CardFrame          = require("src.ui.CardFrame")
    local CardArt            = require("src.ui.CardArt")
    local CardAnimationLayer = require("src.ui.card.CardAnimationLayer")
    local IconFramesLoader   = require("src.ui.IconFramesLoader")
    local FontManager        = require("src.ui.FontManager")

    local db = CardDatabase:new()
    local cd = db:getCard(cardId)
    if not cd then
        print("[preview_card_anim] carta não encontrada: " .. tostring(cardId))
        return
    end
    local inst = db:createCardInstance(cd)
    local cardCanvas = CardFrame.render(cd)
    local art = CardArt.resolve(cd)

    -- Animação = canvases pré-renderizados por frame (CardFrame.getAnimation)
    local anim = CardFrame.getAnimation(cd)
    local nShots, fps
    if anim then
        nShots = #anim.canvases
        fps = anim.fps
        print(string.format("[preview_card_anim] %s: %d canvases @ %sfps",
            art.iconName, nShots, tostring(fps)))
    else
        nShots = 6
        fps = 8
        print("[preview_card_anim] SEM frames em icons_anim/" .. tostring(art.iconName)
            .. " — mostrando só overlays procedurais")
    end

    local SCALE = 2
    local cw, ch = CardFrame.WIDTH * SCALE, CardFrame.HEIGHT * SCALE
    local pad = 12
    local cols = math.min(nShots, 5)
    local rows = math.ceil(nShots / cols)
    local W = pad + cols * (cw + pad)
    local H = pad + rows * (ch + pad + 14)

    local canvas = love.graphics.newCanvas(W, H)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.16, 0.13, 0.11, 1)
    love.graphics.setFont(FontManager.getFont(11))

    for i = 0, nShots - 1 do
        local col = i % cols
        local row = math.floor(i / cols)
        local x = pad + col * (cw + pad)
        local y = pad + row * (ch + pad + 14)
        -- t escolhido pra cair exatamente no frame i do loop
        local t = i / fps
        local frameCanvas = anim and anim.canvases[i + 1] or cardCanvas
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(frameCanvas, x, y, 0, SCALE, SCALE)
        CardAnimationLayer.draw(inst, art, x, y, SCALE, SCALE, t)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(string.format("f%d t=%.2fs", i, t), x, y + ch + 2)
    end

    love.graphics.setCanvas()
    local img = canvas:newImageData()
    img:encode("png", "preview_card_anim.png")
    print("[preview] salvou " .. love.filesystem.getSaveDirectory()
        .. "/preview_card_anim.png")

    -- Verificação do canvas VIVO (o que as telas seguram como instance.image):
    -- espera 1.5 frames de animação e confere que CardFrame.update() mudou
    -- o conteúdo. Pega regressão do tipo "anima no preview mas não no jogo".
    if anim and anim.live then
        local d1 = anim.live:newImageData():getString()
        local t0 = love.timer.getTime()
        while love.timer.getTime() - t0 < (1.5 / fps) do end
        CardFrame.update()
        local d2 = anim.live:newImageData():getString()
        print("[preview_card_anim] canvas vivo atualiza via CardFrame.update(): "
            .. (d1 ~= d2 and "SIM" or "NAO (BUG!)"))
    end
end

return M
