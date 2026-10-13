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

-- CORINGA NAO TEM CUSTO DE MANA. Ele e passivo: entra nos slots e nunca passa
-- pela mao, entao o `cost` do dado e vestigial — mostrar o numero ensina uma
-- regra que nao existe ("preciso de 2 de mana pra usar esse coringa?").
--
-- Isto e uma PERGUNTA SOBRE A CARTA, nao sobre o desenho, e mora aqui porque
-- ja foi corrigida tres vezes em lugares diferentes: no badge da arte
-- (renderJoker), no tooltip (CardInfoDisplay) e — reportada pelo dono em
-- Set/2026, "tem joker na hora de escolher que apresenta custo tbm" — no chip
-- da escolha de pacote. Cada tela que mostra custo REPETIA o `if`, e a
-- proxima tela ia repetir o defeito. Pergunte aqui.
function CardFrame.showsManaCost(card)
    return card ~= nil and card.type ~= "joker"
end

-- A CARTA ESTA SENDO INTERAGIDA? (hover ou selecao)
--
-- E a regra do dono "idle = estatico, interacao = vivo": a ilustracao so
-- anima quando o jogador esta mexendo naquela carta. Mora AQUI porque os dois
-- limiares abaixo estavam escritos inline, como numeros magicos, dentro da
-- CollectionScreen — e faltavam no `CardGridRender`, que e o renderizador
-- COMPARTILHADO do Deck Viewer e do Gerenciador de Coringas. Resultado: a
-- Colecao animava no hover e o deck da run nao ("na tela de seu deck dentro
-- do jogo, ao fazer hover ou clicar em uma carta, nao fica com animacao" —
-- dono, Set/2026), apesar de o cabecalho do CardGridRender AFIRMAR que o
-- caminho era identico ao da Colecao.
--
-- Ver defect_doctrine 16: regra de dominio repetida em N telas volta na
-- tela N+1. Pergunte aqui em vez de repetir o `if`.
function CardFrame.isInteracting(hoverScale, hoverStrength)
    return (hoverScale or 1) > 1.001 or (hoverStrength or 0) > 0.05
end

-- A imagem que a carta deve desenhar AGORA: a viva quando interagida (se ela
-- tiver animacao), a estatica caso contrario. Devolver `card.image` no
-- fallback e de proposito — carta sem frames animados nunca deixa de desenhar.
function CardFrame.imageFor(card, hoverScale, hoverStrength)
    if card and CardFrame.isInteracting(hoverScale, hoverStrength) then
        local live = CardFrame.liveImage(card)
        if live then return live end
    end
    return card and card.image or nil
end

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

-- FILETE DO TOPO (Out/2026, dono: "o topo das cartas está cortado"): o
-- banner do nome e as gemas de custo/raridade colavam na borda de cima do
-- canvas, então a faixa de nó da moldura (desenhada em y=1) sumia sob o
-- banner e a gema parecia decepada — embaixo a moldura aparecia inteira.
-- Tudo do topo desce TOP_INSET px; a arte cede essa altura.
CardFrame.TOP_INSET = 3

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
    local top    = headerH + CardFrame.TOP_INSET
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
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET })

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
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET })
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

-- Descarta os canvases cacheados. NECESSARIO depois de qualquer coisa que
-- invalide o contexto grafico -- na pratica, love.window.setMode: o Canvas
-- sobrevive como objeto mas seu conteudo e perdido, e CardFrame.render devolve
-- o canvas VAZIO do cache. Sintoma: a carta some e so restam selo e moldura.
-- E o analogo de FontManager.clearCache(), que love.resize ja chama.
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

-- (Declarados ANTES de getAnimation/liveImage: local Lua só existe abaixo da
-- definição — mesma pegadinha do notifyOrbUI no EffectSystem.)
local warned = {}     -- key → true: um aviso por carta, não um por quadro

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print("[CardFrame] " .. msg .. " (" .. tostring(key) .. ")")
end

-- Set de frames VÁLIDO = canvases 1..n todos presentes, n ≥ 1. Um buraco
-- aqui não dá erro na hora: `#` ainda devolve n e o blit cai no slot vazio
-- só quando o relógio aponta pra ele — defeito de 1 em n quadros, por
-- horário (Out/2026: CardFrame.render estubado por tools/balance_sim.setup
-- vazava pras suites seguintes; o set nascia {nil, c2..c9} e test_class_select
-- caía em `draw(nil)` uma vez a cada nove rodadas).
local function validSet(canvases)
    local n = #canvases
    if n == 0 then return false end
    for i = 1, n do
        if canvases[i] == nil then return false end
    end
    return true
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
    if not validSet(canvases) then
        warnOnce(key, "getAnimation: set de frames incompleto")
        return nil
    end
    local live = PixelCanvas.new(CardFrame.WIDTH, CardFrame.HEIGHT)
    animCache[key] = { canvases = canvases, fps = frames.fps,
                       live = live, lastIdx = 0, lastReq = love.timer.getTime() }
    CardFrame.update()  -- blit inicial (lastIdx=0 força o primeiro copy)
    return animCache[key]
end

-- ===== Construção PROGRESSIVA + ciclo de vida das animações (perf Out/2026) =====
-- MEDIDO (tools/perf_collection.lua): cada PRIMEIRO hover numa carta montava o
-- set inteiro de uma vez (9 PNGs do disco + 8 composições completas da carta)
-- = engasgo de 8-23ms NO FRAME do hover. Na Coleção, varrer o grid com o mouse
-- é uma sequência de "primeiros hovers": a lista inteira gaguejava. E o
-- animCache crescia sem teto: toda carta já hoverada continuava sendo blitada
-- pra sempre no CardFrame.update, então a tela ficava mais lenta quanto mais
-- o jogador olhava.
-- Agora: (1) liveImage monta o set aos poucos (BUILD_PER_CALL composições por
-- chamada; até lá a carta segue no estático = frame 0, sem salto visual);
-- (2) update só blita animação PEDIDA nos últimos STALE_SECS; (3) teto LRU de
-- MAX_LIVE sets em memória (o resto é recomposto sob demanda).
local BUILD_PER_CALL = 1
local STALE_SECS = 0.35
local MAX_LIVE = 24
-- Régua dos testes (test_card_live_hover): teto e janela de "em uso".
CardFrame.MAX_LIVE, CardFrame.STALE_SECS = MAX_LIVE, STALE_SECS
local building = {}   -- key → { frames, fps, canvases, i }

-- Índice do frame no instante t. Nunca NaN: n = 0 ou t não-finito → 1.
local function frameIndex(anim, t)
    local n = #anim.canvases
    if n <= 0 then return 1 end
    local x = t * anim.fps
    if x ~= x or x == math.huge or x == -math.huge then return 1 end
    return math.floor(x) % n + 1
end

-- Devolve false (e marca a animação) se o slot pedido estiver vazio — quem
-- chama descarta o set e volta pro estático. Jamais derruba o quadro.
local function blitFrame(anim, idx)
    local src = anim.canvases[idx]
    if not src then
        anim.broken = true
        return false
    end
    anim.lastIdx = idx
    -- push("all") preserva canvas/blend/cor de quem chamou (update global OU
    -- liveImage no meio de um draw com canvas ativo).
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(anim.live)
    -- Cópia byte-a-byte do frame (replace+premultiplied evita recombinar
    -- alpha — o conteúdo já veio de um canvas).
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(src, 0, 0)
    love.graphics.pop()
    return true
end

-- Teto MACIO: só descarta animação que ninguém pediu há STALE_SECS. Com mais
-- de MAX_LIVE cartas animadas interagidas no MESMO quadro (coleção com a
-- inspeção + grid, mão cheia + coringas), descartar uma viva a faria ser
-- recomposta no quadro seguinte (8 composições) pra ser descartada de novo —
-- thrash que piscava o estático no lugar do vivo. Passar do teto por um
-- instante custa só memória; o excesso sai assim que fica parado.
local function evictLRU(now)
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    while n > MAX_LIVE do
        local oldestKey, oldestT = nil, math.huge
        for k, a in pairs(animCache) do
            local t = a.lastReq or 0
            if t < oldestT then oldestT, oldestKey = t, k end
        end
        if not oldestKey or (now - oldestT) <= STALE_SECS then return end
        animCache[oldestKey] = nil
        n = n - 1
    end
end

-- Canvas VIVO (animado) da carta, ou nil se ela não tem animação (ou se o
-- set ainda está sendo montado — quem chama desenha o estático, que É o
-- frame 0).
-- Contrato de uso (regra do dono, Jul/2026): os pontos de renderização
-- desenham instance.image (estático) por padrão e trocam pra este canvas
-- SÓ na interação — hover, carta selecionada pra jogar, inspeção ampliada.
function CardFrame.liveImage(card)
    local key = cacheKey(card)
    local now = love.timer.getTime()
    local anim = animCache[key]
    if anim then
        local stale = (now - (anim.lastReq or 0)) > STALE_SECS
        anim.lastReq = now
        if stale then
            -- update() parou de blitar enquanto ninguém olhava: sincroniza já.
            blitFrame(anim, frameIndex(anim, now))
        end
        if anim.broken then
            -- slot vazio achado no blit: fora do cache, carta segue estática.
            warnOnce(key, "animação com frame vazio descartada")
            animCache[key] = nil
            return nil
        end
        return anim.live
    end

    local b = building[key]
    if not b then
        local okA, art = pcall(CardArt.resolve, card)
        if not okA or not art or not art.iconName then return nil end
        if not IconFramesLoader.has(art.iconName) then return nil end
        local frames = IconFramesLoader.getIncremental(art.iconName, 1)
        if not frames or #frames.frames == 0 then return nil end
        if not cache[key] then
            local okR, err = pcall(CardFrame.render, card)
            if not okR then
                print("[CardFrame] liveImage: render falhou para " .. key .. ": " .. tostring(err))
                return nil
            end
        end
        -- O frame 0 do set É o canvas estático do cache. Sem ele (render
        -- substituído por um stub, cache limpo no meio) o set nasceria com
        -- buraco na posição 1 — ver validSet. Avisa e fica no estático.
        if not cache[key] then
            warnOnce(key, "render não preencheu o cache; sem animação")
            return nil
        end
        b = { frames = frames.frames, fps = frames.fps,
              canvases = { cache[key] }, i = 1 }
        building[key] = b
        return nil
    end

    local made = 0
    while b.i < #b.frames and made < BUILD_PER_CALL do
        b.i = b.i + 1
        local ok, cv = pcall(renderOne, card, frameHandle(b.frames[b.i]))
        if not ok then
            print("[CardFrame] falha compondo frame " .. b.i .. " de " .. key .. ": " .. tostring(cv))
            building[key] = nil
            return nil
        end
        b.canvases[b.i] = cv
        made = made + 1
    end
    if b.i < #b.frames then return nil end

    building[key] = nil
    if not validSet(b.canvases) then
        warnOnce(key, "set de frames incompleto; sem animação")
        return nil
    end
    anim = { canvases = b.canvases, fps = b.fps, lastIdx = 0, lastReq = now,
             live = PixelCanvas.new(CardFrame.WIDTH, CardFrame.HEIGHT) }
    animCache[key] = anim
    blitFrame(anim, frameIndex(anim, now))
    evictLRU(now)
    return anim.live
end

-- Tick global (main.lua love.update, todos os estados): quando o frame
-- corrente de uma animação EM USO muda, blita o canvas pré-renderizado no
-- canvas vivo. Animação que ninguém pediu nos últimos STALE_SECS não custa
-- nada (liveImage ressincroniza quando ela volta a ser pedida).
function CardFrame.update()
    local t = love.timer.getTime()
    local n = 0
    for key, anim in pairs(animCache) do
        n = n + 1
        if anim.broken then
            animCache[key] = nil
        elseif (t - (anim.lastReq or t)) <= STALE_SECS then
            local idx = frameIndex(anim, t)
            if idx ~= anim.lastIdx then blitFrame(anim, idx) end
        end
    end
    -- o excesso sobre o teto macio sai quando as cartas ficam paradas
    if n > MAX_LIVE then evictLRU(t) end
end

-- Quantos sets de animação estão vivos em memória (régua/teste de perf).
function CardFrame._liveCount()
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    return n
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
    for k in pairs(building) do
        if k:sub(1, #prefix) == prefix then building[k] = nil end
    end
end

-- Invalida os canvases. Chamar SEMPRE que algo invalidar o contexto grafico —
-- na pratica `love.window.setMode`: o Canvas sobrevive como OBJETO mas o
-- conteudo dele e perdido, e render() devolveria o canvas VAZIO do cache.
-- Sintoma: a carta some e sobram so moldura e selo. E o analogo de
-- FontManager.clearCache(), e love.resize chama os dois lado a lado.
-- (Havia uma 2a definicao desta funcao acima, sobrescrita por esta e
-- incompleta — so limpava `cache`, deixando `animCache` morto. Removida.)
function CardFrame.clearCache()
    cache = {}
    animCache = {}
    building = {}
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
