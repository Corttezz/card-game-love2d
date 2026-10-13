-- src/ui/shop/ShopLayout.lua
-- GEOMETRIA PURA do Balcão do Mercador (Loja v5; v4 em
-- docs/plan/shop-v4-estudo.md; histórico v3b/v3c/reta/v4/v5 em
-- memory/shop_layout.md).
--
-- A cena é UMA PINTURA (assets/sprites/shop/counter_scene.png, montada por
-- tools/shop_v4_compose.py): parede calma em cima e, na frente, DUAS
-- superfícies limpas desenhadas na grade com as arestas em 1:8 (o DEGRAU das
-- cartas e a MESA dos objetos). Desenhada em cover-fit e TUDO que mora nela é
-- posicionado num ESPAÇO DA BANCADA comum (coordenadas da arte):
--   u = ao longo do tampo (a coluna x da arte; as retas sobem 1 px a cada 8)
--   d = profundidade (a reta y0 - x/8 de cada superfície: maior = mais perto)
-- Cartas, cavaletes, plaquinhas, objetos e etiquetas saem desse espaço por
-- parâmetros CENTRAIS (SHELF / TABLE / PLAQUE, abaixo), nunca por coordenada
-- de tela solta:
--   * cartas: um GRUPO de cavaletes com vão constante, centrado na zona da
--     vitrine; base de cada carta encaixada no trilho, trilho apoiado no
--     tampo do degrau; preço numa plaquinha pregada na FACE do degrau, logo
--     abaixo da própria carta (vínculo físico: é o mesmo móvel);
--   * mesa: três grupos com intenção (ferramentas do mercador | serviços |
--     consumível), profundidades levemente diferentes; preço numa plaquinha
--     em pé no tampo, logo À FRENTE do pé do objeto.
-- `validate` confere apoio (pé dentro da superfície pintada), vínculo
-- (plaquinha colada no dono), nada sobreposto, nada perto demais da borda
-- da frente e a coluna da direita (pergaminho, CONTINUAR) livre. Janela
-- estreita (4:3): a fileira desliza e, se não cabe, o VÃO cede e só depois a
-- escala, nunca a ordem.
--
-- Fora da pintura (interface, grade da UI, prioriza leitura): a placa de
-- título com os "?", o PERGAMINHO de detalhe à direita (com o COMPRAR) e o
-- botão CONTINUAR no canto inferior direito.

local ShopLayout = {}

local ShopPerspective = require("src.ui.shop.ShopPerspective")

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

ShopLayout.TOPBAR_H = 56
ShopLayout.CARD_RATIO = 1.5
ShopLayout.CARD_FORESHORTEN = 0.82   -- largura aparente / largura frontal
-- Loja v5 (briefing do dono: "evite que a carta simplesmente suba e pareça
-- levitar sobre o suporte"): o hover NÃO levanta nem cresce a carta. O ponto
-- de apoio (centro da base, no trilho) fica parado; o que responde ao mouse
-- é o tilt 3D (Card.hoverTilt) com a base PRESA (card_perspective.glsl em
-- modo quad) e o destaque (contorno + trilho aceso).
ShopLayout.CARD_HOVER_SCALE = 1.0
ShopLayout.CARD_LIFT = 0
-- Trilho do cavalete em px de ARTE e quanto dele cobre a carta: só a borda
-- inferior da moldura (o rodapé com tipo e valor é informação, fica à vista).
ShopLayout.RAIL_ART = 4
ShopLayout.RAIL_COVER_ART = 2
ShopLayout.LIFT = 0                  -- objetos da mesa: hover sem levantar (v5)
ShopLayout.BADGE_RESERVE = 12        -- selo "NOVA" acima da carta
ShopLayout.POST_H = 3                -- batentes do trilho (acima dele)

-- ============================================================================
-- PARÂMETROS DA VITRINE (Loja v5, item 11 do briefing): tudo que posiciona
-- carta, objeto e preço mora AQUI, em px de arte. Mudou a quantidade de
-- ofertas ou a janela? A conta abaixo refaz o grupo a partir destes números.
-- ============================================================================
ShopLayout.SHELF = {
    gap = 10,        -- vão entre os trilhos de duas cartas vizinhas
    gapMin = 4,      -- janela estreita: o vão cede até aqui antes da escala
    railPad = 3,     -- o trilho passa railPad px de cada lado da carta
    zonePad = 8,     -- respiro das bordas da zona da vitrine
}
ShopLayout.TABLE = {
    line = 284,      -- y0 da reta-base dos pés (a aresta da frente é 306)
    depthStep = 4,   -- um passo de profundidade (arte); + = mais perto
    -- Da esquerda pra direita, três grupos: ferramentas do mercador (copo
    -- de dados, sino), serviços (relíquias) e o consumível (pacote). `gap` =
    -- distância do pé anterior; o vão ENTRE grupos é maior que o de dentro.
    -- dados do copo À FRENTE dele ({dx, dy} do pé do dado, relativo ao pé
    -- do copo): jogados ou o dado de enfeite, longe do sino
    dice = { gap = 0, depth = -1, size = 32, diceAt = { { -11, 12 }, { 7, 14 } } },
    bell = { gap = 44, depth = 0.5, size = 40 },
    relicGap0 = 66,             -- sino -> 1ª relíquia (separa os grupos)
    relicGap = 62,              -- entre relíquias
    relicDepth = { 0, -1, 0 },  -- trio em V raso: o do meio um passo atrás
    packGap = 74, packDepth = 0.5,
    objSize = 64,               -- caixa nominal (sprite em ESCALA 1 da grade)
    objFootprint = 52,          -- largura nominal que dois vizinhos não dividem
    frontMargin = 6,            -- plaquinha termina >= 6 px antes da aresta
}
ShopLayout.PLAQUE = {
    h = 9,           -- linhas de arte, contorno incluso
    faceTop = 1,     -- carta: topo 1 linha abaixo da aresta (na FACE do degrau)
    ahead = 3,       -- objeto: topo 3 px à frente do pé (no TAMPO, diante dele)
    gem = 4,         -- gema de raridade (carta incomum/rara/lendária) + contorno
    padX = 3,        -- contorno + folga de cada lado do texto
    font = 10, fontMin = 8,
}

-- ============================================================================
-- Loja v4: UMA inclinação de pixel art, 1:8 (sobe 1 px de arte a cada 8 px
-- pra direita, ~7,1 graus), igual nas duas superfícies e em tudo que mora
-- nelas. Inclinação inteira = degraus todos de 8 px. Projeção oblíqua: as
-- retas são paralelas e a escala não muda ao longo delas (a 4ª carta tem o
-- mesmo tamanho da 1ª: nada encolhe "porque está à direita").
-- ============================================================================
ShopLayout.RUN = 8
ShopLayout.K = -1 / ShopLayout.RUN
function ShopLayout.slopeArt() return ShopLayout.K end

-- y (arte) da reta "y0 - x/8" na coluna x, em DEGRAUS (como a pintura é
-- desenhada por tools/shop_v4_compose.py). A contínua difere < 1 px.
function ShopLayout.lineY(y0, x) return y0 - math.floor(x / ShopLayout.RUN) end

-- ============================================================================
-- A ARTE: 640x360 (tools/shop_v4_compose.py). Retas "y = y0 - x/8" (y0 =
-- altura na coluna 0), espelhadas em G do tools/pixellab_shop_v4.py:
-- ============================================================================
local LINES = {
    shelfTop = 186,      -- aresta de trás do tampo do degrau
    shelfEdge = 196,     -- aresta da FRENTE do degrau: base das cartas
    shelfFace = 208,     -- fim da face da frente do degrau
    tableBack = 221,     -- aresta de trás do tampo da mesa
    tableEdge = 306,     -- aresta da frente do tampo
}
ShopLayout.LINES = LINES
-- faixa entre duas retas (arte), estendida além das bordas da pintura
local function band(y0a, y0b, pad)
    pad = pad or 0
    return { -40, y0a + 5 - pad, 680, y0a - 85 - pad, 680, y0b - 85 + pad, -40, y0b + 5 + pad }
end
ShopLayout.ART = {
    w = 640, h = 360,
    -- base das cartas: a aresta da frente do degrau (contínua)
    ledgeEdge = { x0 = 0, y0 = LINES.shelfEdge, k = ShopLayout.K },
    ledgeMask = band(LINES.shelfTop, LINES.shelfEdge, 2),
    faceMask = band(LINES.shelfEdge, LINES.shelfFace, 0),
    tableMask = band(LINES.tableBack, LINES.tableEdge, 0),
    cardH = 96,          -- altura da carta em px da arte (192 px virtuais)
}

-- cover-fit em MÚLTIPLO INTEIRO quando o recorte extra é pequeno (<= 20%):
-- 1280x720 virtual -> 2 (3 px em 1080p, 4 em 1440p). Janela de outra
-- proporção (4:3) cai no fracionário em vez de cortar meia mesa.
local function coverTransform(sw, sh, aw, ah)
    local need = math.max(sw / aw, sh / ah)
    local si = math.ceil(need - 1e-6)
    local s = (si / need <= 1.2) and si or need
    local dw, dh = aw * s, ah * s
    return { s = s, dw = dw, dh = dh, ox = (sw - dw) / 2, oy = (sh - dh) / 2 }
end
ShopLayout.coverTransform = coverTransform

local function toScreen(cv, ax, ay)
    return cv.ox + ax * cv.s, cv.oy + ay * cv.s
end
ShopLayout.toScreen = toScreen

local function toArt(cv, x, y)
    return (x - cv.ox) / cv.s, (y - cv.oy) / cv.s
end
ShopLayout.toArt = toArt

local function pointInPoly(px, py, poly)
    local inside = false
    local n = #poly / 2
    local j = n
    for i = 1, n do
        local xi, yi = poly[i * 2 - 1], poly[i * 2]
        local xj, yj = poly[j * 2 - 1], poly[j * 2]
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end
ShopLayout.pointInPoly = pointInPoly

local function bboxOf(xs, ys)
    local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
    for i = 1, #xs do
        x0 = math.min(x0, xs[i]); x1 = math.max(x1, xs[i])
        y0 = math.min(y0, ys[i]); y1 = math.max(y1, ys[i])
    end
    return rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
end
ShopLayout.bboxOf = bboxOf

local lineY = ShopLayout.lineY

-- Caixa (px de TELA) de um retângulo em degraus: colunas x0..x0+w-1, topo
-- na reta de intercepto y0, h linhas.
function ShopLayout.stepBox(cv, x0, w, y0, h)
    local yl, yr = lineY(y0, x0), lineY(y0, x0 + w - 1)
    local top, bot = math.min(yl, yr), math.max(yl, yr) + h
    local sx, sy = toScreen(cv, x0, top)
    return rect(sx, sy, w * cv.s, (bot - top) * cv.s)
end
local stepBox = ShopLayout.stepBox

-- ============================================================================
-- PLAQUINHA DE PREÇO (Loja v5). UM tratamento para todo preço da vitrine:
-- latão envelhecido com o valor em tinta clara, desenhado na GRADE da arte
-- (degraus 1:8 na mesma fase das arestas), texto por cima na grade da UI.
-- O vínculo físico é o lugar:
--   card   = pregada na FACE do degrau, centrada sob a própria carta
--   object = em pé no TAMPO, centrada logo à frente do pé do objeto
-- A largura final sai do texto (ShelfItem.plaqueArt); aqui fica a caixa
-- MÁXIMA (validação e hit-test) e o eixo (cx).
-- ============================================================================
local function plaque(cv, kind, cx, y0, maxW)
    local P = ShopLayout.PLAQUE
    local w = math.max(9, math.floor(maxW))
    local x0 = math.floor(cx - w / 2 + 0.5)
    local pq = { kind = kind, cx = cx, x0 = x0, w = w, y0 = y0, h = P.h, slope = ShopLayout.K }
    -- caixa: o cartão + 1 linha de sombra embaixo
    pq.box = stepBox(cv, x0, w, y0, P.h + 1)
    return pq
end
ShopLayout.plaque = plaque

function ShopLayout.frameAtF(f, u, v)
    return f.ox + u, f.oy + f.k * u - (v or 0)
end

-- Os 4 cantos da carta (TL, TR, BR, BL), px de tela, no frame da borda:
-- base sobre a borda (vb acima dela, dentro do trilho), topo PARALELO à
-- base (a mesma reta 1:8: projeção oblíqua, sem ponto de fuga). `hover` e
-- `lift` ficam na assinatura por compatibilidade: com CARD_HOVER_SCALE = 1 e
-- CARD_LIFT = 0 (v5) a pose do hover é a do repouso; o movimento do hover é
-- o tilt do shader, com a base presa.
function ShopLayout.cardQuad(c, hover, lift)
    hover, lift = hover or 0, lift or 0
    local f = c.frame
    local w, h = c.qw, c.qh
    local blx, bly = ShopLayout.frameAtF(f, -w / 2, c.vb)
    local brx, bry = ShopLayout.frameAtF(f, w / 2, c.vb)
    local tlx, tly = blx, bly - h
    local trx, try_ = brx, tly + f.k * w
    local cx, cy = ShopLayout.frameAtF(f, 0, c.vb)
    local sc = 1 + (ShopLayout.CARD_HOVER_SCALE - 1) * hover
    local dx, dy = f.nx * lift, f.ny * lift
    local function T(x, y) return cx + (x - cx) * sc + dx, cy + (y - cy) * sc + dy end
    local x0, y0 = T(tlx, tly)
    local x1, y1 = T(trx, try_)
    local x2, y2 = T(brx, bry)
    local x3, y3 = T(blx, bly)
    return x0, y0, x1, y1, x2, y2, x3, y3
end

-- A fileira da mesa como LISTA (arte, relativa ao 1º pé): grupos e
-- profundidades saem de ShopLayout.TABLE. nRelics pode ser 0..n.
function ShopLayout.tableRow(nRelics, withPack)
    local T = ShopLayout.TABLE
    local row = {}
    local x = 0
    row[#row + 1] = { key = "dice", dx = x, depth = T.dice.depth, size = T.dice.size }
    x = x + T.bell.gap
    row[#row + 1] = { key = "bell", dx = x, depth = T.bell.depth, size = T.bell.size }
    for i = 1, nRelics do
        x = x + ((i == 1) and T.relicGap0 or T.relicGap)
        local d = T.relicDepth[((i - 1) % #T.relicDepth) + 1]
        row[#row + 1] = { key = "relic", index = i, dx = x, depth = d, size = T.objSize }
    end
    if withPack ~= false then
        x = x + ((nRelics > 0) and T.packGap or T.relicGap0)
        row[#row + 1] = { key = "pack", dx = x, depth = T.packDepth, size = T.objSize }
    end
    return row
end

function ShopLayout.layout(sw, sh, nCards, nRelics, opts)
    opts = opts or {}
    nCards = math.max(1, nCards or 4)
    nRelics = math.max(0, nRelics or 3)
    local A = ShopLayout.ART
    local SH, TB, P = ShopLayout.SHELF, ShopLayout.TABLE, ShopLayout.PLAQUE
    local topBarH = opts.topBarH or ShopLayout.TOPBAR_H

    local margin = clamp(math.floor(sw * 0.02), 10, 32)
    local wall = rect(0, topBarH, sw, sh - topBarH)
    local cv = coverTransform(sw, sh, A.w, A.h)

    -- ===== coluna da direita: pergaminho + CONTINUAR =====
    local scrollW = clamp(math.floor(sw * 0.26), 210, 340)
    local scrollX = sw - margin - scrollW
    local contW = clamp(math.floor(sw * 0.17), 150, 230)
    local contH = 40
    local continueBtn = rect(sw - margin - contW, sh - margin - contH, contW, contH)
    local limitX = scrollX - 10          -- nada da mesa passa daqui

    -- ===== a ZONA da vitrine em px de arte: da borda visível esquerda até o
    -- pergaminho (4:3 corta a esquerda da pintura: a zona começa depois) =====
    local zoneL = math.max(0, (6 - cv.ox) / cv.s) + SH.zonePad
    local zoneR = (limitX - cv.ox) / cv.s - SH.zonePad

    -- ===== cavaletes =====
    local lineH = clamp(math.floor(8 * cv.s / 1.875), 8, 11) + 2
    local cardH0 = A.cardH * cv.s
    local cards = {}
    local vFit = 1
    local lastGap, lastSize = SH.gap, 1
    local function buildCards(gap, sizeFit)
        cards = {}
        lastGap, lastSize = gap, sizeFit
        sizeFit = sizeFit * vFit
        local h = math.floor(cardH0 * sizeFit)
        local w = math.floor(h / ShopLayout.CARD_RATIO)
        local qw = math.floor(w * ShopLayout.CARD_FORESHORTEN)
        local railArt = math.floor(qw / cv.s + 0.5) + SH.railPad * 2
        local groupW = nCards * railArt + (nCards - 1) * gap
        -- o GRUPO centrado na zona (um conjunto organizado pelo mesmo
        -- comerciante: vão constante, sem escada de vãos largos)
        local x0 = math.floor(zoneL + math.max(0, (zoneR - zoneL - groupW) / 2) + 0.5)
        for i = 1, nCards do
            local railX0 = x0 + (i - 1) * (railArt + gap)
            local ax = railX0 + railArt / 2
            -- UM frame por carta: origem na borda pintada sob o centro dela
            local c = { kind = "card", art = { x = ax }, depth = 1, qw = qw, qh = h }
            local f = ShopPerspective.edgeFrame(c, cv)
            c.frame, c.art.y, c.slope = f, f.art.y, f.k
            -- ÂNCORA = centro da base. O trilho (RAIL_ART px de arte) tem a
            -- quina de baixo da frente SOBRE a aresta; a carta senta nele e
            -- ele cobre só RAIL_COVER_ART px da moldura: sem fresta.
            c.vb = (ShopLayout.RAIL_ART - ShopLayout.RAIL_COVER_ART) * cv.s
            c.lipH = math.floor(ShopLayout.RAIL_ART * cv.s + 0.5)
            c.footX = f.ox
            local fx, footY = ShopLayout.frameAtF(f, 0, c.vb)
            c.anchor = { x = fx, y = footY }
            c.foot = math.floor(footY)
            local qx0, qy0, qx1, qy1, qx2, qy2, qx3, qy3 = ShopLayout.cardQuad(c, 0, 0)
            c.rect = bboxOf({ qx0, qx1, qx2, qx3 }, { qy0, qy1, qy2, qy3 })
            -- trilho na GRADE da arte (colunas inteiras), centrado na carta
            c.railX0 = railX0
            c.railX1 = railX0 + railArt - 1
            c.railW = railArt * cv.s
            c.stand = stepBox(cv, c.railX0, railArt, LINES.shelfEdge - ShopLayout.RAIL_ART,
                ShopLayout.RAIL_ART + 1)
            -- preço: plaquinha na face do degrau, sob a carta (máx = trilho)
            c.plaque = plaque(cv, "card", ax, LINES.shelfEdge + P.faceTop, railArt - 2)
            local sb, pb = c.stand, c.plaque.box
            local px0, py0 = math.min(sb.x, pb.x), math.min(sb.y, pb.y)
            c.plate = rect(px0, py0, math.max(sb.x + sb.w, pb.x + pb.w) - px0,
                math.max(sb.y + sb.h, pb.y + pb.h) - py0)
            c.standVariant = ((i - 1) % 3) + 1
            c.lineH = lineH
            c.lift = 0
            cards[i] = c
        end
    end
    buildCards(SH.gap, 1)
    -- janela estreita: primeiro o vão cede, depois a escala
    local function cardsRight()
        local c = cards[#cards]
        return math.max(c.rect.x + c.rect.w, c.plate.x + c.plate.w)
    end
    local function cardsLeft() return cards[1].plate.x end
    local zoneLs, zoneRs = toScreen(cv, zoneL, 0), toScreen(cv, zoneR, 0)
    if cardsRight() > zoneRs + 1 or cardsLeft() < zoneLs - 1 then
        buildCards(SH.gapMin, 1)
        for _ = 1, 6 do
            if cardsRight() <= limitX and cardsLeft() >= 4 then break end
            buildCards(SH.gapMin, math.max(0.6, lastSize * 0.93))
        end
    end
    -- VERTICAL: a 1:8 sobe a carta da direita; com o selo NOVA ela não pode
    -- passar da TopBar nem da placa de título. Quem cede é a altura.
    local signBox = { x = margin, y = topBarH + 4, w = math.floor(sw * 0.42), h = 30 }
    for _ = 1, 4 do
        local worst = 1
        for _, c in ipairs(cards) do
            local reach = ShopLayout.BADGE_RESERVE
            local ceil = topBarH + 4
            if c.rect.x < signBox.x + signBox.w then ceil = signBox.y + signBox.h + 4 end
            local d = ceil - (c.rect.y - reach)
            if d > 0 then worst = math.min(worst, (c.qh - d - 2) / c.qh) end
        end
        if worst >= 1 then break end
        vFit = vFit * worst
        buildCards(lastGap, lastSize)
    end

    -- ===== mesa: três grupos, pé na reta-base + profundidade =====
    local hasPack = true
    local row = ShopLayout.tableRow(nRelics, hasPack)
    local first, last = row[1], row[#row]
    -- extensão à esquerda do 1º pé: metade do copo ou o dado à frente dele
    local leftExt = math.max(first.size * 0.5, -TB.dice.diceAt[1][1] + 10)
    local spanArt = last.dx + last.size * 0.45 + leftExt
    local avail = zoneR - zoneL
    local xFit = 1
    if spanArt > avail then
        xFit = clamp((avail - last.size * 0.45 - leftExt) / math.max(1, last.dx), 0.5, 1)
    end
    local rowW = last.dx * xFit + last.size * 0.45 + leftExt
    local startX = zoneL + math.max(0, (avail - rowW) / 2) + leftExt
    local function place(e)
        local ax = math.floor(startX + e.dx * xFit + 0.5)
        local y0 = TB.line + e.depth * TB.depthStep
        local ay = lineY(y0, ax)
        local fx, fy = toScreen(cv, ax, ay)
        local size = math.floor(e.size * cv.s)
        local hitW = math.floor(math.min(e.size, TB.objFootprint) * cv.s)
        local o = {
            art = { x = ax, y = ay, y0 = y0 }, depth = e.depth, slope = ShopLayout.K,
            size = size, foot = math.floor(fy), footX = math.floor(fx),
            rect = rect(fx - hitW / 2, fy - size, hitW, size),
            lift = 0, key = e.key,
        }
        if e.key ~= "dice" then
            -- plaquinha em pé no tampo, à frente do pé
            o.plaque = plaque(cv, "object", ax, y0 + P.ahead, 26)
            o.plate = o.plaque.box
        else
            o.plate = rect(fx - 1, fy, 2, 2)
        end
        return o
    end
    local objects, relics, pack, bell, dice = {}, {}, nil, nil, nil
    for _, e in ipairs(row) do
        local o = place(e)
        if e.key == "relic" then
            o.kind = "relic"
            relics[#relics + 1] = o
            objects[#objects + 1] = o
        elseif e.key == "pack" then
            o.kind = "pack"
            pack = o
            objects[#objects + 1] = o
        elseif e.key == "bell" then bell = o
        elseif e.key == "dice" then dice = o end
    end

    -- ===== placa de título (sobre a pintura, canto superior esquerdo) =====
    local sign = rect(margin, topBarH + 4, math.floor(sw * 0.42), 30)
    local help = rect(sign.x + sign.w - 56, sign.y + 4, 22, 22)
    local diceHelp = rect(sign.x + sign.w - 26, sign.y + 4, 22, 22)

    -- ===== pergaminho (prego + rolo + miolo + COMPRAR), altura pelo conteúdo =====
    local nail = rect(scrollX + scrollW / 2 - 4, topBarH + 4, 8, 10)
    local rollerH = clamp(math.floor(scrollW * 0.10), 18, 40)
    local footH = math.floor(rollerH * 1.3)
    local inset = clamp(math.floor(scrollW * 0.13), 12, 48)
    local artH = math.floor(cards[1].rect.h * 0.95)
    local textH = clamp(math.floor(sh * 0.26), 120, 190)
    local buyH = 38
    local cordH = clamp(math.floor(sh * 0.025), 10, 22)
    local maxH = continueBtn.y - 10 - (nail.y + nail.h + cordH)
    local scrollH = math.min(maxH, rollerH + 8 + artH + textH + buyH + 10 + footH + 12)
    local scroll = rect(scrollX, nail.y + nail.h + cordH, scrollW, scrollH)
    scroll.nail = nail
    scroll.rollerH, scroll.footH, scroll.inset = rollerH, footH, inset
    scroll.artMaxH = artH
    scroll.buy = rect(scroll.x + inset, scroll.y + scroll.h - footH - 8 - buyH, scroll.w - inset * 2, buyH)
    scroll.body = rect(scroll.x + inset, scroll.y + rollerH + 6,
        scroll.w - inset * 2, scroll.buy.y - 8 - (scroll.y + rollerH + 6))

    return {
        sw = sw, sh = sh, wall = wall, cover = cv, art = A,
        sign = sign, help = help, diceHelp = diceHelp,
        cards = cards, relics = relics, pack = pack, objects = objects,
        bell = bell, dice = dice,
        scroll = scroll, continueBtn = continueBtn, lantern = nil,
        limitX = limitX, zone = { l = zoneL, r = zoneR },
        cardW = cards[1].rect.w, cardH = cards[1].rect.h,
        leftW = limitX,
    }
end

-- ============================================================================
-- VALIDAÇÃO
-- ============================================================================
local function inside(outer, inner, tol)
    tol = tol or 1
    return inner.x >= outer.x - tol and inner.y >= outer.y - tol
        and inner.x + inner.w <= outer.x + outer.w + tol
        and inner.y + inner.h <= outer.y + outer.h + tol
end
local function overlaps(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
local function fmt(r) return ("(%d,%d %dx%d)"):format(r.x, r.y, r.w, r.h) end
local function union(a, b)
    local x0, y0 = math.min(a.x, b.x), math.min(a.y, b.y)
    local x1, y1 = math.max(a.x + a.w, b.x + b.w), math.max(a.y + a.h, b.y + b.h)
    return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end
ShopLayout.overlaps = overlaps

-- Os 4 cantos (arte) de uma plaquinha, nas colunas das pontas.
function ShopLayout.plaqueCorners(pq)
    local xl, xr = pq.x0, pq.x0 + pq.w - 1
    return {
        { xl + 0.5, lineY(pq.y0, xl) + 0.5 }, { xr + 0.5, lineY(pq.y0, xr) + 0.5 },
        { xr + 0.5, lineY(pq.y0, xr) + pq.h - 0.5 }, { xl + 0.5, lineY(pq.y0, xl) + pq.h - 0.5 },
    }
end

function ShopLayout.validate(L)
    local bad = {}
    local function fail(msg, ...) bad[#bad + 1] = msg:format(...) end
    local screen = { x = 0, y = 0, w = L.sw, h = L.sh }
    local A, cv = L.art, L.cover
    local P = ShopLayout.PLAQUE

    -- cartas: apoio, vínculo da plaquinha, vizinhas
    for i, c in ipairs(L.cards) do
        local ax, ay = toArt(cv, c.frame.ox, c.frame.oy)
        if not pointInPoly(ax, ay, A.ledgeMask) then
            fail("cavalete %d: base (%d,%d na arte) fora da borda do fundo", i, ax, ay)
        end
        if c.foot < c.stand.y or c.foot > c.stand.y + c.stand.h then fail("carta %d: pe fora do suporte", i) end
        local lifted = { x = c.rect.x, y = c.rect.y - ShopLayout.BADGE_RESERVE, w = c.rect.w,
            h = c.rect.h + ShopLayout.BADGE_RESERVE }
        if not inside(L.wall, lifted) then fail("carta %d (com selo) %s escapa da parede", i, fmt(lifted)) end
        if c.plate.x + c.plate.w > L.limitX then fail("placa da carta %d invade o pergaminho", i) end
        if c.rect.w < 40 or c.rect.h < 60 then fail("carta %d ilegivel (%dx%d)", i, c.rect.w, c.rect.h) end
        -- plaquinha: na FACE do degrau (pintada), sob a carta
        for _, p in ipairs(ShopLayout.plaqueCorners(c.plaque)) do
            if not pointInPoly(p[1], p[2], A.faceMask) then
                fail("plaquinha da carta %d fora da face do degrau", i)
                break
            end
        end
        if math.abs(c.plaque.cx - c.frame.art.x) > 1 then fail("plaquinha da carta %d fora do eixo da carta", i) end
        if i > 1 then
            local prev = L.cards[i - 1]
            if overlaps(prev.plate, c.plate) then fail("cavaletes das cartas %d e %d se tocam", i - 1, i) end
            if prev.rect.x + prev.rect.w > c.rect.x + 2 then fail("cartas %d e %d se sobrepoem", i - 1, i) end
        end
    end
    -- mesa: pé no tampo, plaquinha no tampo, longe da aresta da frente
    local all = {}
    local tableItems = {}
    for j, o in ipairs(L.objects) do tableItems[#tableItems + 1] = { "objeto " .. j, o } end
    tableItems[#tableItems + 1] = { "sino", L.bell }
    tableItems[#tableItems + 1] = { "copo", L.dice }
    for _, e in ipairs(tableItems) do
        local name, o = e[1], e[2]
        local ax, ay = toArt(cv, o.footX, o.foot)
        if not pointInPoly(ax, ay, A.tableMask) then fail("%s: pe (%d,%d na arte) fora do tampo", name, ax, ay) end
        if not inside(L.wall, o.rect) then fail("%s fora da parede", name) end
        if o.plate.x + o.plate.w > L.limitX then fail("placa do %s invade o pergaminho", name) end
        if o.plaque then
            local pq = o.plaque
            for _, p in ipairs(ShopLayout.plaqueCorners(pq)) do
                if not pointInPoly(p[1], p[2], A.tableMask) then fail("plaquinha do %s fora do tampo", name) break end
            end
            local bottom = lineY(pq.y0, pq.x0) + pq.h
            local edge = lineY(LINES.tableEdge, pq.x0)
            if edge - bottom < ShopLayout.TABLE.frontMargin then
                fail("plaquinha do %s a %d px da aresta da frente", name, edge - bottom)
            end
            if math.abs(pq.cx - o.art.x) > 1 then fail("plaquinha do %s fora do eixo do pe", name) end
            local gap = pq.y0 - o.art.y0
            if gap < 1 or gap > P.ahead + 1 then fail("plaquinha do %s solta do pe (%d px)", name, gap) end
        end
        all[#all + 1] = { name = name, r = union(o.rect, o.plate), o = o }
    end
    for a = 1, #all do
        for b = a + 1, #all do
            local pa, pb = all[a].o.plate, all[b].o.plate
            if overlaps(pa, pb) then fail("placas do %s e do %s se tocam", all[a].name, all[b].name) end
            -- a plaquinha de um não cai sobre o vizinho
            if all[a].o.plaque and overlaps(pa, all[b].o.rect) then
                fail("plaquinha do %s cai sobre o %s", all[a].name, all[b].name)
            end
            if all[b].o.plaque and overlaps(pb, all[a].o.rect) then
                fail("plaquinha do %s cai sobre o %s", all[b].name, all[a].name)
            end
        end
    end
    -- mesa x cartas: um objeto da mesa não pode cobrir carta nem cavalete.
    -- O cavalete termina na reta 1:8 de baixo da plaquinha: compara o topo do
    -- objeto com essa reta na coluna MAIS BAIXA do trecho em comum (a caixa
    -- alinhada aos eixos acusaria sobreposição que não existe na diagonal).
    for _, e in ipairs(all) do
        for i, c in ipairs(L.cards) do
            local r, pl = e.r, c.plate
            local x0, x1 = math.max(r.x, pl.x), math.min(r.x + r.w, pl.x + pl.w)
            if x1 > x0 then
                local ax = math.floor((x0 - cv.ox) / cv.s)
                local _, bottom = toScreen(cv, ax, lineY(c.plaque.y0 + c.plaque.h + 1, ax))
                if r.y < bottom then fail("%s cobre a carta %d", e.name, i) end
            end
        end
    end

    -- coluna da direita
    for _, name in ipairs({ "scroll", "continueBtn", "sign" }) do
        if not inside(L.wall, L[name]) then fail("%s %s fora da parede", name, fmt(L[name])) end
    end
    if not inside(L.wall, L.scroll.nail) then fail("prego fora da parede") end
    if overlaps(L.scroll, L.continueBtn) then fail("pergaminho invade o CONTINUAR") end
    if L.scroll.body.w < 130 then fail("pergaminho estreito demais (%dpx)", L.scroll.body.w) end
    if L.scroll.body.h < L.scroll.artMaxH + 50 then fail("pergaminho baixo demais pro conteudo (%d)", L.scroll.body.h) end
    if not inside(L.scroll, L.scroll.buy) then fail("COMPRAR fora do pergaminho") end
    if overlaps(L.scroll.buy, L.scroll.body) then fail("COMPRAR invade o texto do pergaminho") end
    -- CONTINUAR inteiro na tela, com respiro da borda (CRT come a moldura)
    local cb = L.continueBtn
    if cb.x < 0 or cb.y < 0 or cb.x + cb.w > L.sw - 8 or cb.y + cb.h > L.sh - 8 then
        fail("CONTINUAR %s colado/fora da borda", fmt(cb))
    end
    for _, e in ipairs(all) do
        if overlaps(e.r, L.scroll) then fail("%s invade o pergaminho", e.name) end
        if overlaps(e.r, L.continueBtn) then fail("%s invade o CONTINUAR", e.name) end
        if overlaps(e.r, L.sign) then fail("%s invade a placa de titulo", e.name) end
    end
    for i, c in ipairs(L.cards) do
        local r = union(c.rect, c.plate)
        if overlaps(r, L.scroll) then fail("carta %d invade o pergaminho", i) end
        if overlaps({ x = r.x, y = r.y - ShopLayout.BADGE_RESERVE, w = r.w, h = r.h }, L.sign) then
            fail("carta %d (com selo) invade a placa de titulo", i)
        end
    end
    for _, name in ipairs({ "help", "diceHelp" }) do
        if not inside(L.sign, L[name]) then fail("'?' (%s) fora da placa", name) end
    end
    if overlaps(L.help, L.diceHelp) then fail("os dois '?' se sobrepoem") end
    if not inside(screen, L.wall) then fail("parede fora da tela") end
    return bad
end

return ShopLayout
