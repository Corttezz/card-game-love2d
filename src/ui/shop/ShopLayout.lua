-- src/ui/shop/ShopLayout.lua
-- GEOMETRIA PURA do Balcão do Mercador (Loja v4, docs/plan/shop-v4-estudo.md;
-- histórico v3b/v3c em memory/shop_layout.md).
--
-- A cena é UMA PINTURA 640x360 (assets/sprites/shop/counter_scene.png, montada
-- por tools/shop_v4_compose.py): parede calma do PixelLab em cima e, na frente,
-- DUAS superfícies limpas desenhadas na grade com as arestas em 1:8 (o degrau
-- das cartas e a mesa dos objetos). Desenhada em cover-fit de múltiplo inteiro
-- (2 no espaço virtual 1280x720 = 3 px em 1080p, 4 em 1440p) e TUDO que fica
-- sobre ela é posicionado em COORDENADAS DA ARTE:
--   * 4 cavaletes de carta na aresta da frente do degrau, passo constante;
--   * 4 objetos (3 relíquias + pacote) com o pé numa reta 1:8 do tampo,
--     passo constante;
--   * copo e sino agrupados na ponta esquerda da mesa.
-- `validate` confere que o pé está DENTRO da superfície (máscaras em
-- coordenadas da arte), que nada se sobrepõe e que o pergaminho/botões não
-- invadem a mesa. Janela estreita (4:3, 800x600): a fileira desliza e, se não
-- cabe, se COMPRIME (espaçamento e escala cedem), nunca a ordem.
--
-- Fora da pintura (grade da UI): a placa de título com os dois "?", o
-- PERGAMINHO de detalhe à direita (com o botão COMPRAR) e o botão CONTINUAR
-- no canto inferior direito. Texto e placas são desenhados por cima, na
-- grade da UI, na mesma inclinação.

local ShopLayout = {}

local ShopPerspective = require("src.ui.shop.ShopPerspective")

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

ShopLayout.TOPBAR_H = 56
ShopLayout.CARD_RATIO = 1.5
-- Loja "reta" (13/Out/2026, queixa do dono: "as cartas não estão seguindo a
-- mesma reta"): a carta, o trilho do cavalete, a plaquinha de raridade e a
-- etiqueta de preço moram no MESMO frame (ShopPerspective.edgeFrame): a
-- base de toda carta fica sobre a BORDA PINTADA do degrau do fundo
-- (ART.ledgeEdge, medida na pintura), as quatro colineares. O topo foge pro
-- ponto de fuga (perspectiva de verdade: a borda direita sai mais curta
-- sozinha, sem fator inventado). No hover a carta NÃO gira: sai do cavalete
-- na perpendicular da borda (CARD_LIFT px), cresce CARD_HOVER_SCALE e volta
-- pelo mesmo caminho.
ShopLayout.CARD_FORESHORTEN = 0.82   -- largura aparente / largura frontal
ShopLayout.CARD_HOVER_SCALE = 1.06   -- escala da carta levantada
ShopLayout.CARD_LIFT_MIN = 10        -- quanto a carta sai do cavalete (px de UI)
ShopLayout.CARD_LIFT = 14
-- plaquinha de latão da raridade: comum não leva placa (prancha
-- lojareta_placas: a fileira sem a placa da comum leu mais limpa e a
-- raridade da carta comum já está no pergaminho)
ShopLayout.PLATE_COMMON = false
-- Trilho do cavalete em px de ARTE e quanto dele cobre a carta: só a borda
-- inferior da moldura (o rodapé com tipo e valor é informação, fica à vista).
ShopLayout.RAIL_ART = 4
ShopLayout.RAIL_COVER_ART = 2
ShopLayout.LIFT = 5                  -- objetos da mesa levantam 4-6 px no hover
ShopLayout.BADGE_RESERVE = 12  -- selo "NOVA" acima da carta

-- ============================================================================
-- Loja v4 (13/Out/2026, docs/plan/shop-v4-estudo.md): UMA inclinação de pixel
-- art, 1:8 (sobe 1 px de arte a cada 8 px pra direita, ~7,1 graus), igual nas
-- duas superfícies e em tudo que mora nelas. Inclinação inteira = degraus
-- todos de 8 px: a escadinha irregular dos 6,83 graus da v3 some. Sem ponto de
-- fuga (projeção oblíqua paralela, como a pixel art de mesa costuma ser):
-- as retas são paralelas e a escala não muda ao longo delas.
-- ============================================================================
ShopLayout.RUN = 8
ShopLayout.K = -1 / ShopLayout.RUN
function ShopLayout.slopeArt() return ShopLayout.K end

-- y (arte) da reta "y0 - x/8" na coluna x, em DEGRAUS (como a pintura é
-- desenhada por tools/shop_v4_compose.py). A contínua difere < 1 px.
function ShopLayout.lineY(y0, x) return y0 - math.floor(x / ShopLayout.RUN) end

-- ============================================================================
-- A ARTE: 640x360 (tools/shop_v4_compose.py). Parede do PixelLab em cima; o
-- DEGRAU das cartas e a MESA dos objetos desenhados na grade, arestas em 1:8.
-- Retas "y = y0 - x/8" (y0 = altura na coluna 0):
-- ============================================================================
local LINES = {
    shelfTop = 186,      -- aresta de trás do tampo do degrau
    shelfEdge = 196,     -- aresta da FRENTE do degrau: base das cartas
    shelfFace = 208,     -- fim da face da frente do degrau
    tableBack = 221,     -- aresta de trás do tampo da mesa
    tableEdge = 306,     -- aresta da frente do tampo
    objects = 290,       -- pé dos objetos da mesa
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
    tableMask = band(LINES.tableBack, LINES.tableEdge, 0),
    -- cavaletes: passo constante ao longo da borda
    cards = { { x = 110 }, { x = 208 }, { x = 306 }, { x = 404 } },
    cardH = 96,          -- altura da carta em px da arte (192 px virtuais)
    -- objetos da mesa (3 relíquias + pacote): passo constante, pé na reta
    objects = { { x = 168 }, { x = 246 }, { x = 324 }, { x = 402 } },
    objSize = 64,        -- sprite na escala 1 da grade (pixel = pixel da cena)
    -- sino e copo agrupados na ponta esquerda da mesa (copo um pouco atrás)
    bell = { x = 100, y0 = LINES.objects + 4, size = 34 },
    dice = { x = 60, y0 = LINES.objects - 10, size = 32 },
}
for _, o in ipairs(ShopLayout.ART.objects) do o.y = LINES.objects - o.x / ShopLayout.RUN; o.s = 1 end
for _, c in ipairs(ShopLayout.ART.cards) do c.s = 1 end
for _, k in ipairs({ "bell", "dice" }) do
    local o = ShopLayout.ART[k]
    o.y = o.y0 - o.x / ShopLayout.RUN
    o.s = 1
end

-- cover-fit idêntico ao SceneBackground.getCoverTransform
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

-- ============================================================================
-- PLAQUINHAS NA GRADE DA ARTE (v4). Queixa do dono: "o suporte da carta tem
-- poucos pixels e está fazendo escadinha". Trilho, plaquinha de raridade e
-- etiqueta de preço são desenhados no canvas da ARTE (ShopPerspective.artPass)
-- como retângulos em DEGRAUS da grade: a coluna x tem o topo na reta
-- lineY(y0, x) (mesma fase das arestas pintadas). Só o TEXTO sai na grade da
-- UI, cisalhado na mesma inclinação, por cima.
-- ============================================================================
ShopLayout.TAG_W, ShopLayout.TAG_H = 15, 8     -- etiqueta de preço (px de arte)
ShopLayout.PLATE_H = 8                         -- plaquinha de raridade
ShopLayout.POST_H = 3                          -- batentes do trilho (acima dele)
ShopLayout.SWING = 2                           -- folga do balanço da etiqueta
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

-- Etiqueta pendurada: cordão do ponto (cordX, cordY) da arte até o furo no
-- meio do topo do cartão (x0, topo na reta y0). `box` = cartão + balanço +
-- cordão em px de tela (validação e hit-test).
local function artTag(cv, cordX, cordY, x0, y0)
    local W, H, S = ShopLayout.TAG_W, ShopLayout.TAG_H, ShopLayout.SWING
    local T = { x0 = x0, y0 = y0, cordX = cordX, cordY = cordY, slope = ShopLayout.K }
    local b = stepBox(cv, x0 - S, W + S * 2, y0, H)
    local hx, hy = toScreen(cv, cordX, cordY)
    local top = math.min(b.y, math.floor(hy))
    T.box = rect(math.min(b.x, hx - 1), top, math.max(b.x + b.w, hx + 1) - math.min(b.x, hx - 1), b.y + b.h - top)
    T.w, T.h = W * cv.s, H * cv.s              -- px de tela (compat)
    T.ax, T.ay = hx, hy
    T.len = (lineY(y0, x0 + math.floor(W / 2)) - cordY) * cv.s
    return T
end
ShopLayout.artTag = artTag

-- Etiqueta de um objeto da mesa: o cartão deitado no tampo à direita-frente
-- do pé (o cordão sai da silhueta; o ponto exato vem no draw, tiePoint).
local function objectTag(cv, ax, ay, sizeArt)
    local W = ShopLayout.TAG_W
    local cx = math.floor(ax + sizeArt * 0.30 + 0.5)
    local x0 = cx - math.floor(W / 2)
    local topRow = math.floor(ay) + 1
    return artTag(cv, cx, math.floor(ay) - 6, x0, topRow + math.floor(x0 / ShopLayout.RUN))
end
ShopLayout.objectTag = objectTag

-- Placas da carta (trilho [x0, x1] na grade, aresta = LINES.shelfEdge):
--   rarity = plaquinha pregada na FACE do degrau, logo abaixo do trilho,
--            centrada; a largura final sai do texto (maxW = trilho)
--   tag    = etiqueta pendurada da ponta DIREITA do trilho, abaixo da
--            plaquinha ("left": ponta esquerda; "out": ao lado da ponta)
--   plate  = caixa de trilho + batentes + plaquinha (validação/hit-test)
local function railPlates(c, cv, side)
    local E = ShopLayout.LINES.shelfEdge
    local x0, x1 = c.railX0, c.railX1
    local W, PH = ShopLayout.TAG_W, ShopLayout.PLATE_H
    local rarity = { x0 = x0, w = x1 - x0 + 1, y0 = E + 1, h = PH, slope = ShopLayout.K }
    rarity.x, rarity.y = toScreen(cv, x0, lineY(E + 1, x0))
    rarity.maxW = (x1 - x0 + 1) * cv.s
    local up = ShopLayout.RAIL_ART + ShopLayout.POST_H
    local plate = stepBox(cv, x0, x1 - x0 + 1, E - up, up + 1 + PH)
    local tag
    if side == "out" then
        local tx = x1 + 2
        tag = artTag(cv, tx + math.floor(W / 2), lineY(E, tx) - 1, tx, E + 1)
    else
        local tx = (side == "left") and x0 or (x1 - W + 1)
        local cx = tx + math.floor(W / 2)
        tag = artTag(cv, cx, lineY(E, cx), tx, E + 2 + PH + 1)
    end
    tag.side = side
    return { plate = plate, rarity = rarity, tag = tag, railW = (x1 - x0 + 1) * cv.s }
end

function ShopLayout.frameAtF(f, u, v)
    return f.ox + u, f.oy + f.k * u - (v or 0)
end

-- Os 4 cantos da carta (TL, TR, BR, BL), px de tela, no frame da borda:
-- base sobre a borda (vb acima dela, dentro do trilho), topo PARALELO à
-- base (a mesma reta 1:8: projeção oblíqua, sem ponto de fuga). hover 0..1 (já com easing) escala em torno do centro da
-- base; lift px desloca na PERPENDICULAR da borda. Nenhum dos dois gira.
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

function ShopLayout.layout(sw, sh, nCards, nRelics, opts)
    opts = opts or {}
    nCards = math.max(1, nCards or 4)
    nRelics = math.max(0, nRelics or 3)
    local A = ShopLayout.ART
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

    -- ===== cavaletes =====
    local lineH = clamp(math.floor(8 * cv.s / 1.875), 8, 11) + 2
    local cardH0 = A.cardH * cv.s
    local cards = {}
    -- em 4:3 o cover-fit corta a esquerda da pintura: a diagonal inteira
    -- desliza pra direita (em px da arte) até a primeira carta caber na tela
    local leftArt = (6 - cv.ox) / cv.s
    local cardShift = math.max(0, leftArt + (A.cardH * cv.s / ShopLayout.CARD_RATIO) / 2 / cv.s - A.cards[1].x)
    local vFit, lastX, lastS = 1, 1, 1
    local function buildCards(xFit, sizeFit)
        cards = {}
        lastX, lastS = xFit, sizeFit
        sizeFit = sizeFit * vFit
        local x1 = A.cards[1].x + cardShift
        for i = 1, nCards do
            local a = A.cards[math.min(i, #A.cards)]
            local ax = x1 + (a.x - A.cards[1].x) * xFit
            local h = math.floor(cardH0 * a.s * sizeFit)
            local w = math.floor(h / ShopLayout.CARD_RATIO)
            local qw = math.floor(w * ShopLayout.CARD_FORESHORTEN)
            -- UM frame por carta: origem na borda pintada sob o centro dela
            local c = { kind = "card", art = { x = ax }, depth = a.s, qw = qw, qh = h }
            local f = ShopPerspective.edgeFrame(c, cv)
            c.frame, c.art.y, c.slope = f, f.art.y, f.k
            -- trilho do cavalete (RAIL_ART px de arte) com a quina de baixo
            -- da frente SOBRE a borda; a carta senta nele e ele cobre só
            -- RAIL_COVER_ART px da borda de baixo da moldura
            local lipH = math.floor(ShopLayout.RAIL_ART * cv.s + 0.5)
            c.vb = (ShopLayout.RAIL_ART - ShopLayout.RAIL_COVER_ART) * cv.s
            c.lipH = lipH
            c.footX = f.ox
            local _, footY = ShopLayout.frameAtF(f, 0, c.vb)
            c.foot = math.floor(footY)
            local x0, y0, xa, ya, x2, y2, x3, y3 = ShopLayout.cardQuad(c, 0, 0)
            c.rect = bboxOf({ x0, xa, x2, x3 }, { y0, ya, y2, y3 })
            -- trilho na GRADE da arte (colunas inteiras), centrado na carta
            local railArt = math.floor(qw / cv.s + 0.5) + 6
            c.railX0 = math.floor(f.art.x - railArt / 2 + 0.5)
            c.railX1 = c.railX0 + railArt - 1
            local plates = railPlates(c, cv, "right")
            c.railW = plates.railW
            c.stand = ShopLayout.stepBox(cv, c.railX0, railArt, ShopLayout.LINES.shelfEdge - ShopLayout.RAIL_ART,
                ShopLayout.RAIL_ART + 1)
            c.standVariant = ((i - 1) % 3) + 1
            c.plate, c.rarity, c.tag = plates.plate, plates.rarity, plates.tag
            c.lineH = lineH
            -- sai do cavalete proporcional à carta (CARD_LIFT_MIN..CARD_LIFT)
            c.lift = clamp(math.floor(h * 0.075), ShopLayout.CARD_LIFT_MIN, ShopLayout.CARD_LIFT)
            cards[i] = c
        end
    end
    buildCards(1, 1)
    -- janela estreita: comprime a diagonal (e, se ainda não cabe, a escala)
    local function cardsRight()
        local c = cards[#cards]
        return math.max(c.rect.x + c.rect.w, c.plate.x + c.plate.w, c.tag.box.x + c.tag.box.w)
    end
    if cardsRight() > limitX then
        local x1 = cards[1].rect.x
        local fit = clamp((limitX - x1 - cards[#cards].rect.w) / (cardsRight() - x1 - cards[#cards].rect.w), 0.5, 1)
        buildCards(fit, 1)
        -- vizinhas se tocando? encolhe junto
        for _ = 1, 3 do
            local touching = false
            for i = 2, #cards do
                if cards[i].rect.x < cards[i - 1].plate.x + cards[i - 1].plate.w + 2 then touching = true end
            end
            if not touching and cardsRight() <= limitX then break end
            fit = fit * 0.92
            buildCards(fit, math.max(0.7, fit))
        end
    end
    -- e na VERTICAL: a 1:8 sobe a carta da direita; levantada (com o selo)
    -- ela não pode passar da TopBar nem da placa de título (4:3 desliza a
    -- fileira pra direita, que é mais alto). Quem cede é a altura.
    local signBox = { x = margin, y = topBarH + 4, w = math.floor(sw * 0.42), h = 30 }
    for _ = 1, 4 do
        local worst = 1
        for _, c in ipairs(cards) do
            local reach = c.lift + math.ceil(c.qh * (ShopLayout.CARD_HOVER_SCALE - 1)) + ShopLayout.BADGE_RESERVE
            local ceil = topBarH + 2
            if c.rect.x < signBox.x + signBox.w then ceil = signBox.y + signBox.h + 2 end
            local d = ceil - (c.rect.y - reach)
            if d > 0 then worst = math.min(worst, (c.qh - d - 2) / c.qh) end
        end
        if worst >= 1 then break end
        vFit = vFit * worst
        buildCards(lastX, lastS)
    end

    -- ===== objetos na mesa =====
    local objSize0 = A.objSize * cv.s
    local objects = {}
    -- a fileira da mesa (copo, sino, objetos) desliza INTEIRA quando o
    -- cover-fit corta a esquerda (4:3): o copo continua na ponta
    local objShift = math.max(0, leftArt + A.dice.size * 0.6 - A.dice.x)
    local function buildObjects(xFit, sizeFit)
        objects = {}
        local x1 = A.objects[1].x + objShift
        local n = nRelics + 1
        for j = 1, n do
            local a = A.objects[math.min(j, #A.objects)]
            local ax = x1 + (a.x - A.objects[1].x) * xFit
            local ay = ShopLayout.LINES.objects - ax / ShopLayout.RUN
            local fx, fy = toScreen(cv, ax, ay)
            local slope = ShopLayout.K
            local size = math.floor(objSize0 * a.s * sizeFit)
            local skew = math.abs(slope) * size / 2
            local r = rect(fx - size / 2, fy - size - skew, size, size + skew * 2)
            local isPack = j > nRelics
            -- etiqueta deitada no tampo, à direita-frente do pé
            local tag = objectTag(cv, ax, ay, size / cv.s)
            objects[j] = {
                kind = isPack and "pack" or "relic",
                art = { x = ax, y = ay }, depth = a.s, slope = slope,
                rect = r, foot = math.floor(fy), footX = math.floor(fx), size = size,
                tag = tag, plate = tag.box,
                lift = ShopLayout.LIFT,
            }
        end
    end
    buildObjects(1, 1)
    local function objectsRight()
        local o = objects[#objects]
        return math.max(o.rect.x + o.rect.w, o.plate.x + o.plate.w)
    end
    if objectsRight() > limitX then
        local x1 = objects[1].rect.x
        local fit = clamp((limitX - x1 - objects[#objects].rect.w) / (objectsRight() - x1 - objects[#objects].rect.w), 0.5, 1)
        buildObjects(fit, 1)
        for _ = 1, 3 do
            local touching = false
            for j = 2, #objects do
                if objects[j].plate.x < objects[j - 1].plate.x + objects[j - 1].plate.w + 2 then touching = true end
            end
            if not touching and objectsRight() <= limitX then break end
            fit = fit * 0.92
            buildObjects(fit, math.max(0.7, fit))
        end
    end
    local relics, pack = {}, nil
    for _, o in ipairs(objects) do
        if o.kind == "relic" then relics[#relics + 1] = o else pack = o end
    end

    -- ===== sino e copo (esquerda da mesa) =====
    local function counterObj(a, withTag)
        local ax = a.x + objShift
        local ay = a.y0 - ax / ShopLayout.RUN
        local fx, fy = toScreen(cv, ax, ay)
        local size = math.floor(a.size * cv.s)
        local slope = ShopLayout.K
        local o = {
            art = { x = ax, y = ay }, depth = a.s, slope = slope, size = size,
            rect = rect(fx - size / 2, fy - size, size, size),
            foot = math.floor(fy), footX = math.floor(fx),
            lift = ShopLayout.LIFT,
        }
        if withTag then
            o.tag = objectTag(cv, ax, ay, a.size)
            o.plate = o.tag.box
        else
            o.plate = rect(fx - 1, fy, 2, 2)
        end
        return o
    end
    local bell = counterObj(A.bell, true)
    local dice = counterObj(A.dice, false)

    -- etiqueta da carta: ponta DIREITA do trilho; se ali ela cairia sobre o
    -- sino/copo (4:3 aperta a carta 1 contra o copo) ou sobre um objeto da
    -- mesa (o pacote sob a carta 4 em 16:9), passa pra ponta esquerda
    local function hits(tg, o)
        local tr = tg.box
        for _, r in ipairs({ o.rect, o.plate }) do
            if tr.x < r.x + r.w and r.x < tr.x + tr.w and tr.y < r.y + r.h and r.y < tr.y + tr.h then
                return true
            end
        end
        return false
    end
    for _, c in ipairs(cards) do
        local function blocked(tg)
            local b = hits(tg, dice) or hits(tg, bell)
            for _, o in ipairs(objects) do b = b or hits(tg, o) end
            return b
        end
        if c.tag and blocked(c.tag) then
            for _, side in ipairs({ "left", "out" }) do
                local tg = railPlates(c, cv, side).tag
                if not blocked(tg) then c.tag = tg break end
            end
        end
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

    -- v4: sem lanterna pintada (a parede nova é calma; a luz vem da
    -- esquerda, fora do quadro). ShopProps aceita lantern = nil.
    local lantern = nil

    return {
        sw = sw, sh = sh, wall = wall, cover = cv, art = A,
        sign = sign, help = help, diceHelp = diceHelp,
        cards = cards, relics = relics, pack = pack, objects = objects,
        bell = bell, dice = dice,
        scroll = scroll, continueBtn = continueBtn, lantern = lantern,
        limitX = limitX,
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

function ShopLayout.validate(L)
    local bad = {}
    local function fail(msg, ...) bad[#bad + 1] = msg:format(...) end
    local screen = { x = 0, y = 0, w = L.sw, h = L.sh }
    local A, cv = L.art, L.cover

    -- pé no que está pintado
    for i, c in ipairs(L.cards) do
        local ax, ay = toArt(cv, c.frame.ox, c.frame.oy)
        if not pointInPoly(ax, ay, A.ledgeMask) then
            fail("cavalete %d: base (%d,%d na arte) fora da borda do fundo", i, ax, ay)
        end
        if c.foot < c.stand.y or c.foot > c.stand.y + c.stand.h then fail("carta %d: pe fora do suporte", i) end
        local reach = c.lift + math.ceil(c.qh * (ShopLayout.CARD_HOVER_SCALE - 1)) + ShopLayout.BADGE_RESERVE
        local lifted = { x = c.rect.x, y = c.rect.y - reach, w = c.rect.w, h = c.rect.h + reach }
        if not inside(L.wall, lifted) then fail("carta %d levantada %s escapa da parede", i, fmt(lifted)) end
        if c.plate.x + c.plate.w > L.limitX then fail("placa da carta %d invade o pergaminho", i) end
        if c.rect.w < 40 or c.rect.h < 60 then fail("carta %d ilegivel (%dx%d)", i, c.rect.w, c.rect.h) end
        if i > 1 then
            local prev = L.cards[i - 1]
            if overlaps(prev.plate, c.plate) then fail("placas das cartas %d e %d se tocam", i - 1, i) end
            if prev.rect.x + prev.rect.w > c.rect.x + 2 then fail("cartas %d e %d se sobrepoem", i - 1, i) end
        end
    end
    local all = {}
    for j, o in ipairs(L.objects) do
        local ax, ay = toArt(cv, o.footX, o.foot)
        if not pointInPoly(ax, ay, A.tableMask) then
            fail("objeto %d: pe (%d,%d na arte) fora do tampo", j, ax, ay)
        end
        if not inside(L.wall, o.rect) then fail("objeto %d fora da parede", j) end
        if o.plate.x + o.plate.w > L.limitX then fail("placa do objeto %d invade o pergaminho", j) end
        if o.rect.w < 28 then fail("objeto %d minusculo (%dpx)", j, o.rect.w) end
        if j > 1 and overlaps(L.objects[j - 1].plate, o.plate) then fail("placas dos objetos %d e %d se tocam", j - 1, j) end
        all[#all + 1] = { name = "objeto " .. j, r = union(o.rect, o.plate) }
    end
    for _, e in ipairs({ { "sino", L.bell }, { "copo", L.dice } }) do
        local o = e[2]
        local ax, ay = toArt(cv, o.footX, o.foot)
        if not pointInPoly(ax, ay, A.tableMask) then fail("%s: pe (%d,%d na arte) fora do tampo", e[1], ax, ay) end
        all[#all + 1] = { name = e[1], r = union(o.rect, o.plate) }
    end
    if overlaps(union(L.bell.rect, L.bell.plate), union(L.dice.rect, L.dice.plate)) then
        fail("sino e copo se sobrepoem")
    end
    -- mesa x cartas: um objeto da mesa não pode cobrir uma carta, a faixa
    -- da raridade nem a etiqueta de preço pendurada dela
    for _, e in ipairs(all) do
        for i, c in ipairs(L.cards) do
            if overlaps(e.r, union(c.rect, c.plate)) then fail("%s cobre a carta %d", e.name, i) end
            if c.tag then
                local tr = c.tag.box
                if overlaps(e.r, tr) then fail("%s cobre a etiqueta da carta %d", e.name, i) end
                if not inside(L.wall, tr) then fail("etiqueta da carta %d fora da parede", i) end
                if tr.x + tr.w > L.limitX then fail("etiqueta da carta %d invade o pergaminho", i) end
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
    for _, e in ipairs(all) do
        if overlaps(e.r, L.scroll) then fail("%s invade o pergaminho", e.name) end
        if overlaps(e.r, L.continueBtn) then fail("%s invade o CONTINUAR", e.name) end
        if overlaps(e.r, L.sign) then fail("%s invade a placa de titulo", e.name) end
    end
    for i, c in ipairs(L.cards) do
        local r = union(c.rect, c.plate)
        if overlaps(r, L.scroll) then fail("carta %d invade o pergaminho", i) end
        local grow = math.ceil(c.qh * (ShopLayout.CARD_HOVER_SCALE - 1))
        if overlaps({ x = r.x, y = r.y - ShopLayout.BADGE_RESERVE - c.lift - grow, w = r.w, h = r.h }, L.sign) then
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
