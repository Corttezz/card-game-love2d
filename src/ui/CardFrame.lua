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

-- ============================================================================
-- CARTA VISIVEL = CARTA VIVA (regra do dono, 13/Out/2026)
-- ============================================================================
-- "A todo momento as cartas que estao sendo exibidas na tela eu quero que
-- elas fiquem com a animacao sendo mostrada. Elas nao podem estar estaticas
-- em NENHUM tipo de visualizacao em nenhum local."
--
-- Isto REVOGA a regra de Jul/2026 ("idle = estatico, interacao = vivo"), que
-- morava aqui como `isInteracting`/`imageFor(card, hoverScale, hoverStrength)`.
-- A animacao do icone agora aparece em TODA renderizacao de carta: mao,
-- coringas ativos, espolios, loja (bancada e pergaminho), pacote, Colecao
-- (grade e inspecao), Deck Viewer, Gerenciador de Coringas, cartas iniciais
-- da classe, revelacoes de desbloqueio, pickers, cartas voando no combate.
--
-- A UNICA excecao e `reducedMotion` (Configuracoes -> Jogo): a opcao remove
-- MOVIMENTO, e o loop do icone e movimento. Com ela ligada a carta fica no
-- frame 0, que e pixel a pixel a arte estatica — e hover/selecao NAO reabrem
-- a animacao (seria movimento de novo). Informacao nunca e removida: o frame
-- 0 e a ilustracao completa.
--
-- A decisao mora SO aqui. Toda tela pergunta `CardFrame.displayImage(card)`
-- (ver defect_doctrine 16: regra repetida em N telas volta na tela N+1 — foi
-- assim que o Deck Viewer ficou sem animacao em Set/2026). `liveImage` e o
-- mecanismo (monta e devolve o quadro corrente); `displayImage` e a REGRA.
-- Trava: tools/test_cards_always_live.lua (nenhum arquivo de tela chama
-- `liveImage` direto).
function CardFrame.liveEnabled()
    local s = _G.gameSettings
    return not (s and s.reducedMotion)
end

-- A imagem que a carta deve desenhar AGORA: o quadro corrente da animacao
-- quando ela existe (e o movimento esta ligado), a estatica caso contrario.
-- Devolver `card.image` no fallback e de proposito — carta sem frames
-- animados (ou com o set ainda montando) nunca deixa de desenhar: o
-- estatico E o frame 0, entao nao ha salto visual quando o set termina.
function CardFrame.displayImage(card)
    if not card then return nil end
    if CardFrame.liveEnabled() then
        local live = CardFrame.liveImage(card)
        if live then return live end
    end
    return card.image
end

local cache = {}
-- Cartas com ícone animado (icons_anim/): key → { canvases = {...}, fps,
-- lastReq }. `canvases` = a carta COMPLETA pré-renderizada uma vez por frame
-- do ícone; `liveImage` devolve o canvas do quadro corrente e as telas o
-- desenham no lugar de `instance.image` (swap temporário no draw). Como o
-- frame está DENTRO da imagem da carta, hover warp/holo/editions/CRT aplicam
-- na animação de graça. Regra de quando usar: `displayImage` (topo).
local animCache = {}
-- Camadas base/chrome de uma carta animada (ver renderLayers), guardadas
-- entre o render ESTÁTICO e a montagem do set — assim o set custa só as
-- composições. key → { under, over, t }. Expiram em LAYER_TTL s sem uso.
local layerCache = {}

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

local function renderStandard(card, w, h, iconOverride, skipIcon)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "parchment",
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET, skipIcon = skipIcon })

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

local function renderJoker(card, w, h, iconOverride, skipIcon)
    local rarity = card.rarity or "common"
    local art    = CardArt.resolve(card)
    local name   = I18n.cardName(card)

    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, "tarot",
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET, skipIcon = skipIcon })
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

-- Chave do cache por (id, nível de forja). Memoizada por instância numa
-- tabela de chaves FRACAS: com toda carta visível pedindo a imagem viva a
-- cada draw (Out/2026), montar a string por chamada eram dezenas de
-- alocações por quadro — lixo que o GC paga.
local keyMemo = setmetatable({}, { __mode = "k" })
local function cacheKey(card)
    local up = card.upgrades or 0
    local m = keyMemo[card]
    if m and m.up == up then return m.key end
    local key = (card.id or (tostring(card.name) .. "_" .. tostring(card.type)))
        .. "+" .. tostring(up)
    keyMemo[card] = { key = key, up = up }
    return key
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

-- A carta é composta em TRÊS camadas, nesta ordem:
--   base   — pergaminho sólido + textura (opaco, sem nada da carta)
--   ícone  — a ilustração (estática, ou um frame da animação), recortada ao slot
--   chrome — decoração, sombra de recesso, moldura, banner do nome, gemas,
--            selo, rodapé, gemas de forja (tudo que fica POR CIMA do ícone)
-- e os cantos são recortados por último. `renderOne` desenha as três direto
-- num canvas (o render ESTÁTICO). Pra ANIMAÇÃO (Out/2026, carta visível =
-- viva) a base e o chrome são renderizados UMA vez em canvases próprios e
-- cada frame do ícone vira `base + frame + chrome` (3 draws, ~0,1 ms) em vez
-- de recompor a carta inteira (texto, moldura, ~0,7 ms medido) — era isso
-- que fazia a Coleção gaguejar com dezenas de cartas ganhando vida ao mesmo
-- tempo. Paridade pixel a pixel com o render direto: test_cards_always_live.
local function drawBase(card, w, h)
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

end

local function drawChrome(card, w, h, iconOverride, skipIcon)
    if card.type == "joker" then
        renderJoker(card, w, h, iconOverride, skipIcon)
    else
        renderStandard(card, w, h, iconOverride, skipIcon)
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

end

local function cutCorners(w, h)
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

end

local function renderOne(card, iconOverride)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)
    drawBase(card, w, h)
    drawChrome(card, w, h, iconOverride, false)
    cutCorners(w, h)
    PixelCanvas.endDraw()
    return canvas
end

-- Camada reutilizável da animação: { over }. O chrome nasce num canvas
-- TRANSPARENTE (fica pré-multiplicado) e é composto com
-- ("alpha", "premultiplied") — matematicamente o mesmo "over" do desenho
-- direto, a menos de arredondamento de 8 bits. A BASE (cor + textura, 2
-- draws) é redesenhada direto em cada composição: canvas a menos por carta.
local function renderLayers(card)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local over = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(over, true)
    drawChrome(card, w, h, nil, true)
    PixelCanvas.endDraw()
    return { over = over }
end

-- Um frame da animação a partir das camadas: base + ícone + chrome + cantos.
local function composeFrame(card, layers, iconOverride)
    local w, h = CardFrame.WIDTH, CardFrame.HEIGHT
    local canvas = PixelCanvas.new(w, h)
    PixelCanvas.beginDraw(canvas, true)
    drawBase(card, w, h)
    local art = CardArt.resolve(card)
    local ax, ay, aw, ah = artSlotBounds(card)
    CardArtSlot.draw(ax, ay, aw, ah, art, (card.type == "joker") and "tarot" or "parchment",
        { iconOverride = iconOverride, clipTop = CardFrame.TOP_INSET })
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(layers.over, 0, 0)
    love.graphics.setBlendMode("alpha")
    cutCorners(w, h)
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
    -- render ESTÁTICO com o frame 0 da animação. Os demais frames ficam
    -- LAZY (liveImage sob orçamento / getAnimation). Antes: 116 cartas ×
    -- (~9 PNGs do disco + ~9 composições completas) num frame só = travada
    -- de segundos na primeira abertura.
    --
    -- v11 (Out/2026, carta visível = viva): carta com ícone animado nasce
    -- pelas CAMADAS — base e chrome renderizados uma vez e o frame 0 composto
    -- por cima (mesmo caminho dos outros frames: o set nunca "pisca" na volta
    -- do loop). As camadas ficam em layerCache até o set ser montado, então
    -- animar custa só as composições (~0,1 ms cada), não a carta inteira.
    local art = CardArt.resolve(card)
    local first = art.iconName and IconFramesLoader.first(art.iconName)
    if first then
        local layers = renderLayers(card)
        layers.t = love.timer.getTime()
        layerCache[key] = layers
        cache[key] = composeFrame(card, layers, frameHandle(first))
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
-- aqui não dá erro na hora: `#` ainda devolve n e o draw cai no slot vazio
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

-- ===== Ciclo de vida das animações (v3, Out/2026 — "carta visível = viva") =====
-- Cada carta animada tem um SET de canvases (a carta completa composta uma
-- vez por frame do ícone). `liveImage` devolve DIRETO o canvas do quadro
-- corrente — não existe mais um "canvas vivo" intermediário blitado a cada
-- mudança de frame: com dezenas de cartas vivas no mesmo quadro (Coleção,
-- Deck Viewer) isso eram dezenas de trocas de canvas por segundo pra copiar
-- um canvas em outro. Quem desenha já pede a imagem a cada draw (swap
-- temporário de `instance.image`), então devolver o quadro certo basta.
--
-- Custo controlado em TRÊS lugares:
--   1. ORÇAMENTO GLOBAL por quadro, somado em TODAS as cartas: abrir a
--      Coleção pede 15-20 cartas vivas de uma vez = ~90 ms de trabalho
--      (decodificar 9 PNGs a ~0,36 ms + compor 8 frames a ~0,34 ms por
--      carta, medido em tools/perf_card_anim_units); sem teto isso é um engasgo num
--      quadro só. Cada UNIDADE é um PNG decodificado ou um frame composto;
--      o quadro para quando gastou BUILD_BUDGET_MS de relógio OU
--      BUILD_PER_FRAME unidades (o teto por contagem é o que torna o
--      comportamento determinístico sob relógio simulado nos testes). As
--      cartas ganham vida em ondas, na ordem em que foram pedidas, em
--      ~0,5 s pra grade inteira; até lá desenham o estático = frame 0, sem
--      salto visual.
--   2. SÓ QUEM FOI PEDIDO fica em memória: animação que ninguém desenhou há
--      STALE_SECS é candidata a sair quando o cache passa de MAX_LIVE sets.
--      O teto é MACIO: nunca descarta uma animação em uso (seria recomposta
--      no quadro seguinte — thrash que piscava o estático).
--   3. Nada acontece em `update()` além de higiene: zero blits.
-- Memória: um set = 9 canvases 96×144 ≈ 0,5 MB; MAX_LIVE 64 ≈ 32 MB de VRAM
-- no pior caso (≈3× a grade visível da Coleção, pra rolar sem recompor).
local BUILD_PER_FRAME = 8      -- unidades (PNG ou frame) por quadro
local BUILD_BUDGET_MS = 2.5    -- relógio gasto montando, por quadro
local STALE_SECS = 0.35
local MAX_LIVE = 64
local LAYER_TTL = 3.0
-- Régua dos testes (test_card_live_hover / test_cards_always_live).
CardFrame.MAX_LIVE, CardFrame.STALE_SECS = MAX_LIVE, STALE_SECS
CardFrame.BUILD_PER_FRAME, CardFrame.BUILD_BUDGET_MS = BUILD_PER_FRAME, BUILD_BUDGET_MS
local building = {}   -- key → { frames, fps, canvases, i, layers }

-- Orçamento do quadro: reposto em CardFrame.update() (love.update) e, como
-- rede pra quem roda sem o update (tools antigos), quando o relógio andou
-- mais que BUDGET_WINDOW desde a última reposição.
local BUDGET_WINDOW = 1 / 30
local budget = { left = BUILD_PER_FRAME, spentMs = 0, t0 = -math.huge }

local function budgetReset(now)
    budget.left = BUILD_PER_FRAME
    budget.spentMs = 0
    budget.t0 = now
end

local function budgetTick(now)
    -- `now < t0`: o relógio ANDOU PRA TRÁS (suites com relógio simulado em
    -- sequência) — sem isto o orçamento nunca mais era reposto e a montagem
    -- parava: test_class_select falhava SÓ dentro do test_all.
    if now < budget.t0 or now - budget.t0 >= BUDGET_WINDOW then budgetReset(now) end
end

local function budgetOk()
    return budget.left > 0 and budget.spentMs < BUILD_BUDGET_MS
end

-- Uma unidade de trabalho gasta: conta e relógio (t0 = antes do trabalho).
local function budgetSpend(t0)
    budget.left = budget.left - 1
    budget.spentMs = budget.spentMs + (love.timer.getTime() - t0) * 1000
end

-- Índice do frame no instante t. Nunca NaN: n = 0 ou t não-finito → 1.
local function frameIndex(anim, t)
    local n = #anim.canvases
    if n <= 0 then return 1 end
    local x = t * anim.fps
    if x ~= x or x == math.huge or x == -math.huge then return 1 end
    return math.floor(x) % n + 1
end

-- Quadro corrente de uma animação pronta (também usado por tools/preview).
function CardFrame.frameAt(anim, t)
    return anim and anim.canvases[frameIndex(anim, t)] or nil
end

-- Retorna { canvases, fps } se a carta tem ícone animado; nil caso contrário.
-- Monta o set INTEIRO agora (sem orçamento) — é o caminho dos tools/testes e
-- da inspeção que quer a animação completa num só passo. O frame 0 reusa o
-- canvas estático já composto no render.
function CardFrame.getAnimation(card)
    local key = cacheKey(card)
    if animCache[key] then return animCache[key] end
    local art = CardArt.resolve(card)
    local frames = art.iconName and IconFramesLoader.get(art.iconName)
    if not frames then return nil end
    local canvases = {}
    local layers = layerCache[key] or renderLayers(card)
    for i, img in ipairs(frames.frames) do
        if i == 1 and cache[key] then
            canvases[1] = cache[key]   -- estático = frame 0, já composto
        else
            canvases[i] = composeFrame(card, layers, frameHandle(img))
        end
    end
    cache[key] = cache[key] or canvases[1]
    layerCache[key] = nil
    if not validSet(canvases) then
        warnOnce(key, "getAnimation: set de frames incompleto")
        return nil
    end
    building[key] = nil
    animCache[key] = { canvases = canvases, fps = frames.fps,
                       lastReq = love.timer.getTime() }
    return animCache[key]
end

-- Teto MACIO: só descarta animação que ninguém pediu há STALE_SECS. Com mais
-- de MAX_LIVE cartas animadas visíveis no MESMO quadro, descartar uma viva a
-- faria ser recomposta no quadro seguinte pra ser descartada de novo —
-- thrash que piscava o estático no lugar do vivo. Passar do teto por um
-- instante custa só memória; o excesso sai assim que sai da tela.
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

-- Canvas do QUADRO CORRENTE da animação da carta, ou nil se ela não tem
-- animação (ou se o set ainda está sendo montado — quem chama desenha o
-- estático, que É o frame 0).
--
-- Este é o MECANISMO. A REGRA de quando usar mora em `displayImage`
-- (topo do arquivo): telas não chamam `liveImage` direto — assim o
-- `reducedMotion` vale em todo lugar de uma vez.
function CardFrame.liveImage(card)
    local key = cacheKey(card)
    local now = love.timer.getTime()
    local anim = animCache[key]
    if anim then
        anim.lastReq = now
        local cv = anim.canvases[frameIndex(anim, now)]
        if not cv then
            -- slot vazio: fora do cache, carta segue estática (e avisa).
            warnOnce(key, "animação com frame vazio descartada")
            animCache[key] = nil
            return nil
        end
        return cv
    end

    budgetTick(now)
    if not budgetOk() then return nil end   -- quadro cheio: próxima leva

    local b = building[key]
    if not b then
        local okA, art = pcall(CardArt.resolve, card)
        if not okA or not art or not art.iconName then return nil end
        if not IconFramesLoader.has(art.iconName) then return nil end
        local t0 = love.timer.getTime()
        local frames = IconFramesLoader.getIncremental(art.iconName, 1)
        budgetSpend(t0)
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
    end

    if not b.layers then
        if layerCache[key] then
            b.layers = layerCache[key]
        else
            local t0 = love.timer.getTime()
            local okL, layers = pcall(renderLayers, card)
            budgetSpend(t0)
            if not okL then
                print("[CardFrame] falha nas camadas de " .. key .. ": " .. tostring(layers))
                building[key] = nil
                return nil
            end
            b.layers = layers
        end
    end

    while b.i < #b.frames and budgetOk() do
        b.i = b.i + 1
        local t0 = love.timer.getTime()
        local ok, cv = pcall(composeFrame, card, b.layers, frameHandle(b.frames[b.i]))
        budgetSpend(t0)
        if not ok then
            print("[CardFrame] falha compondo frame " .. b.i .. " de " .. key .. ": " .. tostring(cv))
            building[key] = nil
            return nil
        end
        b.canvases[b.i] = cv
    end
    if b.i < #b.frames then return nil end

    building[key] = nil
    layerCache[key] = nil   -- set pronto: as camadas já cumpriram o papel
    if not validSet(b.canvases) then
        warnOnce(key, "set de frames incompleto; sem animação")
        return nil
    end
    anim = { canvases = b.canvases, fps = b.fps, lastReq = now }
    animCache[key] = anim
    evictLRU(now)
    return anim.canvases[frameIndex(anim, now)]
end

-- Tick global (main.lua love.update, todos os estados): repõe o orçamento
-- de composição do quadro e faz a higiene do cache. NÃO blita nada — o
-- quadro corrente é escolhido na hora do draw (liveImage).
function CardFrame.update()
    local t = love.timer.getTime()
    budgetReset(t)
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    -- o excesso sobre o teto macio sai quando as cartas saem da tela
    if n > MAX_LIVE then evictLRU(t) end
    -- camadas de carta que nasceu mas nunca ganhou vida (Coleção instancia
    -- o catálogo inteiro; só as visíveis montam o set) expiram
    for k, L in pairs(layerCache) do
        if not building[k] and (t - (L.t or t)) > LAYER_TTL then layerCache[k] = nil end
    end
end

-- Quantos sets de animação estão vivos em memória (régua/teste de perf).
function CardFrame._liveCount()
    local n = 0
    for _ in pairs(animCache) do n = n + 1 end
    return n
end

-- Paridade das camadas (teste): o frame 0 pelo caminho da ANIMAÇÃO (base +
-- ícone estático + chrome, o que `render` devolve pra carta animada) contra
-- a carta DESENHADA DIRETO num canvas só — os dois têm que bater pixel a
-- pixel (a menos de ±1 de arredondamento do pré-multiplicado).
function CardFrame._renderDirectForParity(card)
    local art = CardArt.resolve(card)
    local first = art.iconName and IconFramesLoader.first(art.iconName)
    if not first then return nil end
    return renderOne(card, frameHandle(first))
end

-- Camadas em espera (régua de memória transitória).
function CardFrame._layerCount()
    local n = 0
    for _ in pairs(layerCache) do n = n + 1 end
    return n
end

-- Quantas cartas ainda estão com o set em montagem (régua de perf).
function CardFrame._buildingCount()
    local n = 0
    for _ in pairs(building) do n = n + 1 end
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
    for k in pairs(layerCache) do
        if k:sub(1, #prefix) == prefix then layerCache[k] = nil end
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
    layerCache = {}
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
