-- src/ui/CardFrame.lua
-- Compositor de carta — estilo grimório inspirado em assets/cards/*.png.
-- Fluxo:
--   1) Canvas = cor sólida de pergaminho
--   2) Texture PNG de papel envelhecido cobre toda a carta
--   3) Ilustração central direto no pergaminho (sem inner frame)
--   4) Borda ornamental + medalhões nos cantos + banner nome + footer + badges
--
-- Dimensões: 96×144 lógicos (BASE_SCALE 1.333 → 128×192 na tela).

local PixelCanvas     = require("src.ui.PixelCanvas")
local Palette         = require("src.ui.Palette")
local CardArt         = require("src.ui.CardArt")
local I18n            = require("src.i18n.I18n")

local CardBorder      = require("src.ui.card.components.CardBorder")
local CardHeader      = require("src.ui.card.components.CardHeader")
local CardCostBadge   = require("src.ui.card.components.CardCostBadge")
local CardRaritySeal  = require("src.ui.card.components.CardRaritySeal")
local CardArtSlot     = require("src.ui.card.components.CardArtSlot")
local CardDecoration  = require("src.ui.card.components.CardDecoration")
local CardStatsFooter = require("src.ui.card.components.CardStatsFooter")

local JokerBorder = require("src.ui.card.components.joker.JokerBorder")
local JokerHeader = require("src.ui.card.components.joker.JokerHeader")
local JokerSeal   = require("src.ui.card.components.joker.JokerSeal")
local JokerFooter = require("src.ui.card.components.joker.JokerFooter")

local CardFrame = {}

CardFrame.WIDTH  = 96
CardFrame.HEIGHT = 144

local cache = {}

-- Textura de pergaminho global
local _parchmentTex
local _parchmentLoaded = false
local function getParchmentTex()
    if _parchmentLoaded then return _parchmentTex end
    _parchmentLoaded = true
    local path = "assets/sprites/ui/parchment_texture.png"
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            _parchmentTex = img
        end
    end
    return _parchmentTex
end

local function artSlotBounds(card)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    -- Slot cola direto no header e no footer (sem gap vertical).
    -- Joker e card padrão usam header/footer DIFERENTES com alturas próprias —
    -- usar a altura errada cria gap visual ("arte cortada abaixo do título").
    local headerH, footerH
    if card.type == "joker" then
        headerH = JokerHeader.HEIGHT       -- 16 (não 18 do CardHeader)
        footerH = JokerFooter.HEIGHT       -- 16 (não 20 do CardStatsFooter)
    else
        headerH = CardHeader.computeHeight(card, w)  -- 18 single ou 24 wrap
        footerH = CardStatsFooter.HEIGHT             -- 20
    end
    local top    = headerH
    local bottom = h - footerH
    return 5, top, w - 10, bottom - top
end

-- Inset por raridade: painel sólido do banner PNG não preenche a largura
-- inteira em todas as raridades. Rare é quase full-width (bar vermelho grosso),
-- mas common/uncommon/legendary têm ornamentos curly nas pontas que não
-- projetam sombra. Inset é quantos pixels encolher a sombra top em cada lado.
local BANNER_SHADOW_INSET = {
    common    = 3,  -- curly ends nas 2 pontas do banner azul/gold
    uncommon  = 3,  -- flourishes verdes, painel central menor
    rare      = 0,  -- barra vermelha quase full-width → shadow match
    legendary = 3,  -- painel azul+gold com ornamentos nas pontas
}

-- Inset shadow pra dar profundidade ao art slot: cria impressão de que o bg
-- está RECESSED abaixo das bandas de header/footer. Inspirado no `emboss`+
-- `darken` do Balatro (engine/ui.lua:749 + functions/misc_functions.lua:851).
--
-- TOP shadow: só no range horizontal da banner do título, ajustado por
--   raridade via BANNER_SHADOW_INSET (painel sólido varia de largura).
-- BOTTOM shadow: full width — footer é quase edge-to-edge (x=1..95).
-- LEFT/RIGHT shadow: 1-2px coluna — CardBorder projeta sombra lateral.
local function drawRecessShadow(ax, ay, aw, ah, bannerX, bannerW, rarity)
    -- TOP: sombra sob a banner com inset por raridade
    local inset = BANNER_SHADOW_INSET[rarity or "common"] or 0
    local tx = bannerX + inset
    local tw = bannerW - inset * 2
    Palette.set(Palette.INK, 0.38)
    love.graphics.rectangle("fill", tx, ay,     tw, 1)
    Palette.set(Palette.INK, 0.20)
    love.graphics.rectangle("fill", tx, ay + 1, tw, 1)

    -- BOTTOM: footer é full-width, shadow cobre o art slot inteiro.
    -- Alphas subidos pra ficar visível (antes 0.22/0.10, agora 0.32/0.16).
    Palette.set(Palette.INK, 0.32)
    love.graphics.rectangle("fill", ax, ay + ah - 1, aw, 1)
    Palette.set(Palette.INK, 0.16)
    love.graphics.rectangle("fill", ax, ay + ah - 2, aw, 1)

    -- LEFT + RIGHT: 2px de profundidade (antes 1px com alpha 0.14 — invisível).
    -- Border externa casta sombra rightward no left edge, leftward no right.
    Palette.set(Palette.INK, 0.26)
    love.graphics.rectangle("fill", ax,          ay + 2, 1, ah - 4)
    love.graphics.rectangle("fill", ax + aw - 1, ay + 2, 1, ah - 4)
    Palette.set(Palette.INK, 0.12)
    love.graphics.rectangle("fill", ax + 1,      ay + 2, 1, ah - 4)
    love.graphics.rectangle("fill", ax + aw - 2, ay + 2, 1, ah - 4)

    love.graphics.setColor(1, 1, 1, 1)
end

local function renderStandard(card, w, h)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "parchment")

    CardDecoration.draw(ax, ay, aw, ah, art.decoration, art.accent)
    local autoDec = CardDecoration.autoForBackground(art.bgPattern)
    if autoDec and autoDec ~= art.decoration then
        CardDecoration.draw(ax, ay, aw, ah, autoDec, art.accent)
    end

    -- Depth: inset shadow antes da borda externa (art slot "afunda").
    -- Banner coords sincronizadas com CardHeader.draw: bx=15, bw=w-30.
    drawRecessShadow(ax, ay, aw, ah, 15, w - 30, rarity)

    CardBorder.draw(w, h, card.type, rarity, card.id)
    CardHeader.draw(w, name, rarity)
    CardCostBadge.draw(card.cost or 0)
    CardRaritySeal.draw(w, rarity)
    CardStatsFooter.draw(w, h, card)
end

local function renderJoker(card, w, h)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "tarot")
    CardDecoration.draw(ax, ay, aw, ah, art.decoration or "flash", art.accent)
    -- Aplica decoração auto pelo bg pattern (mesmo comportamento de renderStandard)
    -- — ex: joker_001 tem bg=abyss → abyss_tendrils por cima do tarot card.
    local autoDec = CardDecoration.autoForBackground(art.bgPattern)
    if autoDec and autoDec ~= (art.decoration or "flash") then
        CardDecoration.draw(ax, ay, aw, ah, autoDec, art.accent)
    end

    -- Mesmo inset shadow do standard pra dar profundidade.
    -- JokerHeader usa bx=13, bw=w-26 (diferente do standard).
    drawRecessShadow(ax, ay, aw, ah, 13, w - 26, rarity)

    JokerBorder.draw(w, h, rarity)
    JokerHeader.draw(w, name, rarity)
    CardCostBadge.draw(card.cost or 0)
    JokerSeal.draw(w, rarity)
    JokerFooter.draw(w, h)
end

function CardFrame.render(card)
    local key = card.id or (tostring(card.name) .. "_" .. tostring(card.type))
    if cache[key] then return cache[key] end

    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)

    -- Parchment base sólido
    local baseColor = (card.type == "joker") and (Palette.TAROT_CREAM or Palette.PARCHMENT_LIGHT)
                                              or Palette.PARCHMENT_LIGHT
    PixelCanvas.rect(0, 0, w, h, baseColor)

    -- Texture overlay no canvas inteiro (só para cartas standard)
    local tex = getParchmentTex()
    if tex and card.type ~= "joker" then
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.draw(tex, 0, 0, 0, w / tex:getWidth(), h / tex:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end

    if card.type == "joker" then
        renderJoker(card, w, h)
    else
        renderStandard(card, w, h)
    end

    -- Stepped pixel-art corner cut (3px em L) — aplicado por último pra recortar
    -- tudo: base + texture + borda + header + footer + seals. setBlendMode("replace")
    -- sobrescreve alpha pra 0, criando transparência real nos cantos.
    local CORNER_CUT = 3
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0)
    for i = 0, CORNER_CUT - 1 do
        local rowLen = CORNER_CUT - i
        -- top-left
        love.graphics.rectangle("fill", 0, i, rowLen, 1)
        -- top-right
        love.graphics.rectangle("fill", w - rowLen, i, rowLen, 1)
        -- bottom-left
        love.graphics.rectangle("fill", 0, h - 1 - i, rowLen, 1)
        -- bottom-right
        love.graphics.rectangle("fill", w - rowLen, h - 1 - i, rowLen, 1)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)

    PixelCanvas.endDraw()

    cache[key] = canvas
    return canvas
end

function CardFrame.invalidate(card)
    local key = card.id or (card.name or "?")
    cache[key] = nil
end

function CardFrame.clearCache()
    cache = {}
end

-- Quando o idioma muda, todas as cartas precisam ser re-renderizadas pra
-- mostrar o nome no novo idioma no banner do header.
I18n.onLocaleChanged(function() CardFrame.clearCache() end)

CardFrame.components = {
    border = CardBorder,
    header = CardHeader,
    costBadge = CardCostBadge,
    raritySeal = CardRaritySeal,
    artSlot = CardArtSlot,
    decoration = CardDecoration,
    footer = CardStatsFooter,
    jokerBorder = JokerBorder,
    jokerHeader = JokerHeader,
    jokerSeal   = JokerSeal,
    jokerFooter = JokerFooter,
}

return CardFrame
