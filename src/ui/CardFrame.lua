-- src/ui/CardFrame.lua
-- Compositor de carta — estilo grimório inspirado em assets/cards/*.png.
-- Fluxo:
--   1) Canvas = cor sólida de pergaminho
--   2) Texture PNG de papel envelhecido cobre toda a carta
--   3) Ilustração central direto no pergaminho (sem inner frame)
--   4) Borda ornamental + medalhões nos cantos + banner nome + footer + badges
--
-- Dimensões: 96×144 lógicos (BASE_SCALE 1.333 → 128×192 na tela).

local PixelCanvas      = require("src.ui.PixelCanvas")
local Palette          = require("src.ui.Palette")
local CardArt          = require("src.ui.CardArt")
local I18n             = require("src.i18n.I18n")
local IconFramesLoader = require("src.ui.IconFramesLoader")

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
local JokerMoon   = require("src.ui.card.components.joker.JokerMoon")
local JokerFooter = require("src.ui.card.components.joker.JokerFooter")

local CardFrame = {}

CardFrame.WIDTH  = 96
CardFrame.HEIGHT = 144

local cache = {}
-- Cartas com ícone animado (icons_anim/): key → { canvases = {...}, fps,
-- live = Canvas, lastIdx }. `canvases` = a carta COMPLETA pré-renderizada uma
-- vez por frame; `live` = o canvas ÚNICO que todo mundo segura como
-- instance.image. CardFrame.update() (chamado no love.update) blita o frame
-- corrente no live quando o índice muda — assim TODA renderização (mão,
-- coleção, loja, deck viewer, tooltips) anima sem saber de nada, e hover
-- warp/holo/editions/CRT aplicam na animação de graça.
local animCache = {}

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

-- Exposto pro CardAnimationLayer posicionar frames animados do ícone na
-- mesma geometria do canvas estático (coords locais do canvas 96×144).
function CardFrame.artSlotBounds(card)
    return artSlotBounds(card)
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

local function renderStandard(card, w, h, iconOverride)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "parchment",
        { iconOverride = iconOverride })

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

local function renderJoker(card, w, h, iconOverride)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "tarot",
        { iconOverride = iconOverride })
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
    -- Joker NAO tem custo de mana (passivo, nunca passa pela mao) — o badge
    -- de custo aqui era vestigial. No lugar: lua crescente tarot, contrapeso
    -- do JokerSeal do canto direito (pedido do dono, Jul/2026).
    JokerMoon.draw()
    JokerSeal.draw(w, rarity)
    JokerFooter.draw(w, h)
end

local function cacheKey(card)
    return (card.id or (tostring(card.name) .. "_" .. tostring(card.type)))
        .. "+" .. tostring(card.upgrades or 0)
end

-- Adapta um love.Image de frame animado pro contrato de handle do IconLoader
-- ({ size, draw }) — assim o CardArtSlot posiciona o frame EXATAMENTE como o
-- ícone estático (cover-fit/artScale/artOffsetY idênticos).
local function frameHandle(img)
    return {
        size = { w = img:getWidth(), h = img:getHeight() },
        draw = function(x, y, scale)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y, 0, scale, scale)
        end,
    }
end

local function renderOne(card, iconOverride)
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
        renderJoker(card, w, h, iconOverride)
    else
        renderStandard(card, w, h, iconOverride)
    end

    -- GEMAS DE FORJA (v2 Jul/2026 — substitui o selo "+N" que duplicava
    -- informação e brigava com o footer): detalhe SUTIL que ESCALA com a
    -- evolução. Uma gema esmeralda 3×3 por nível numa fileira discreta na
    -- base do art slot; do 6º nível em diante vira gema + "xN". O VALOR real
    -- já muda no footer (verde-forja) — a carta é o template vivo.
    if (card.upgrades or 0) > 0 then
        local lvl = card.upgrades
        local gems = math.min(lvl, 5)
        local gy = h - CardStatsFooter.HEIGHT - 7
        local gx = 7
        local GEM_HI  = { 0.62, 0.95, 0.55, 1 }
        local GEM_MID = { 0.30, 0.68, 0.30, 1 }
        local GEM_LO  = { 0.10, 0.32, 0.12, 1 }
        for i = 1, gems do
            local cxp = gx + (i - 1) * 6
            -- Losango 3×3 facetado (luz no topo)
            PixelCanvas.pixel(cxp,     gy - 1, GEM_HI)
            PixelCanvas.pixel(cxp - 1, gy,     GEM_MID)
            PixelCanvas.pixel(cxp,     gy,     GEM_HI)
            PixelCanvas.pixel(cxp + 1, gy,     GEM_LO)
            PixelCanvas.pixel(cxp,     gy + 1, GEM_LO)
        end
        if lvl > 5 then
            local FontManager = require("src.ui.FontManager")
            local f = FontManager.getFont(8)
            love.graphics.setFont(f)
            local tag = "x" .. tostring(lvl)
            love.graphics.setColor(0, 0, 0, 0.9)
            love.graphics.print(tag, gx + gems * 6 + 2, gy - 4)
            love.graphics.setColor(GEM_HI)
            love.graphics.print(tag, gx + gems * 6 + 1, gy - 5)
            love.graphics.setColor(1, 1, 1, 1)
        end
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

    return canvas
end

function CardFrame.render(card)
    local key = cacheKey(card)
    if cache[key] then return cache[key] end

    -- v10.6 (perf — "engasgada ao abrir a Coleção"): na INSTANCIAÇÃO só o
    -- render ESTÁTICO com o frame 0 da animação (idle = frame 0, regra do
    -- dono). Os demais frames + canvas vivo ficam LAZY em getAnimation()
    -- — chamado no primeiro hover/inspeção, que é onde a animação aparece.
    -- Antes: 116 cartas × (~9 PNGs do disco + ~9 composições completas)
    -- num frame só = travada de segundos na primeira abertura.
    local art = CardArt.resolve(card)
    local first = art.iconName and IconFramesLoader.first(art.iconName)
    if first then
        cache[key] = renderOne(card, frameHandle(first))
        return cache[key]
    end

    cache[key] = renderOne(card)
    return cache[key]
end

-- Retorna { canvases, fps, live } se a carta tem ícone animado; nil caso
-- contrário. v10.6: é AQUI que o set completo é construído (lazy, no
-- primeiro hover/inspeção) — ~9 composições de UMA carta ≈ poucos ms,
-- imperceptível. O frame 0 reusa o canvas estático já composto no render.
function CardFrame.getAnimation(card)
    local key = cacheKey(card)
    if animCache[key] then return animCache[key] end
    local art = CardArt.resolve(card)
    local frames = art.iconName and IconFramesLoader.get(art.iconName)
    if not frames then return nil end
    local canvases = {}
    for i, img in ipairs(frames.frames) do
        if i == 1 and cache[key] then
            canvases[1] = cache[key]   -- estático = frame 0, já composto
        else
            canvases[i] = renderOne(card, frameHandle(img))
        end
    end
    cache[key] = cache[key] or canvases[1]
    local live = PixelCanvas.new(CardFrame.WIDTH, CardFrame.HEIGHT)
    animCache[key] = { canvases = canvases, fps = frames.fps,
                       live = live, lastIdx = 0 }
    CardFrame.update()  -- blit inicial (lastIdx=0 força o primeiro copy)
    return animCache[key]
end

-- Canvas VIVO (animado) da carta, ou nil se ela não tem animação.
-- Contrato de uso (regra do dono, Jul/2026): os pontos de renderização
-- desenham instance.image (estático) por padrão e trocam pra este canvas
-- SÓ na interação — hover, carta selecionada pra jogar, inspeção ampliada.
function CardFrame.liveImage(card)
    local ok, anim = pcall(CardFrame.getAnimation, card)
    if ok and anim then return anim.live end
    return nil
end

-- Tick global (main.lua love.update, todos os estados): quando o frame
-- corrente de uma animação muda, blita o canvas pré-renderizado no canvas
-- vivo. Custo: 1 draw 96×144 por carta animada, `fps` vezes por segundo.
function CardFrame.update()
    local t = love.timer.getTime()
    for _, anim in pairs(animCache) do
        local n = #anim.canvases
        local idx = math.floor(t * anim.fps) % n + 1
        if idx ~= anim.lastIdx then
            anim.lastIdx = idx
            -- push("all") preserva canvas/blend/cor de quem chamou (update
            -- global OU render lazy no meio de um draw com canvas ativo).
            love.graphics.push("all")
            love.graphics.origin()
            love.graphics.setCanvas(anim.live)
            -- Cópia byte-a-byte do frame (replace+premultiplied evita
            -- recombinar alpha — o conteúdo já veio de um canvas).
            love.graphics.setBlendMode("replace", "premultiplied")
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(anim.canvases[idx], 0, 0)
            love.graphics.pop()
        end
    end
end

function CardFrame.invalidate(card)
    -- Keys carregam o sufixo "+<upgrades>" — invalida todos os níveis do ID.
    local prefix = (card.id or (card.name or "?")) .. "+"
    for k in pairs(cache) do
        if k:sub(1, #prefix) == prefix then cache[k] = nil end
    end
    for k in pairs(animCache) do
        if k:sub(1, #prefix) == prefix then animCache[k] = nil end
    end
end

function CardFrame.clearCache()
    cache = {}
    animCache = {}
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
