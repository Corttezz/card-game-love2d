-- src/ui/shop/ShopLayout.lua
-- GEOMETRIA PURA do Balcão do Mercador em PERSPECTIVA (Loja v3b,
-- docs/plan/shop-v3-balcao.md §12, referência docs/plan/shop_reference_gpt.png).
--
-- A cena é UMA PINTURA (assets/sprites/shop/counter_scene.png, 688x384):
-- balcão de madeira em três quartos, estantes de frascos ao fundo, vela e
-- caveira à esquerda, lanterna pendurada no alto, pano vermelho na borda.
-- Ela é desenhada em cover-fit (mesma conta do SceneBackground dos salões de
-- chefe) e TUDO que fica sobre ela é posicionado em COORDENADAS DA ARTE:
--   * 4 cavaletes de carta na diagonal da BORDA DO FUNDO (o plano nasce na
--     esquerda, mais perto, e foge pra direita: escala 1,0 → 0,85);
--   * 4 posições de objeto sobre o TAMPO, em diagonal esquerda-frente →
--     direita-fundo (relíquias + pacote);
--   * sino e copo de dados à esquerda, na mesa.
-- Cada slot tem âncora do PÉ, escala por profundidade e inclinação; o
-- layout converte arte→tela e `validate` confere que o pé está DENTRO do
-- tampo pintado (máscaras em coordenadas da arte, como as âncoras dos
-- salões), que nada se sobrepõe e que o pergaminho/botões não invadem a
-- mesa. Quando a janela é estreita (4:3, 800x600) a diagonal se COMPRIME
-- (espaçamento e escala cedem), nunca a ordem.
--
-- Fora da pintura (grade da UI): a placa de título com os dois "?", o
-- PERGAMINHO de detalhe à direita (com o botão COMPRAR) e o botão CONTINUAR
-- no canto inferior direito. Texto e placas de latão são desenhados por
-- cima, na grade da UI, nunca na arte.

local ShopLayout = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

ShopLayout.TOPBAR_H = 56
ShopLayout.CARD_RATIO = 1.5
-- Loja v3c (queixa do dono: "as cartas ainda estão apontadas pra frente"):
-- a carta fica PARALELA à borda do fundo. Base e topo seguem a diagonal da
-- mesa (slope até o ponto de fuga), a borda direita é mais curta (foge) e a
-- largura encolhe (escorço). No hover a carta gira MAIS: o lado direito
-- afunda (encolhe e recua), o esquerdo sobe, e ela levanta um pouco.
ShopLayout.CARD_FORESHORTEN = 0.86   -- largura aparente / largura frontal
ShopLayout.CARD_RK = 0.93            -- altura da borda direita / esquerda (repouso)
ShopLayout.CARD_RK_HOVER = 0.84      -- idem no hover (o lado direito afunda)
ShopLayout.CARD_W_HOVER = 0.95       -- largura no hover (gira mais)
ShopLayout.CARD_LIFT = 8             -- quanto a carta levanta no hover (lado esquerdo; o direito 1/3)
ShopLayout.LIFT = 5                  -- objetos da mesa levantam 4-6 px no hover
ShopLayout.BADGE_RESERVE = 12  -- selo "NOVA" acima da carta

-- PONTO DE FUGA do eixo longo do balcão, medido na pintura (coordenadas da
-- arte): borda do fundo y=181 em x=180 -> y=150 em x=440 (sobe ~6,8 graus);
-- borda da frente y=316 em x=260 -> y=281 em x=440 (sobe ~11 graus). As duas
-- retas se encontram aqui. A "diagonal" num ponto da mesa é a reta até ele.
ShopLayout.VP = { x = 2187, y = -58 }
function ShopLayout.slopeArt(ax, ay)
    local VP = ShopLayout.VP
    return (VP.y - ay) / (VP.x - ax)
end

-- ============================================================================
-- A ARTE: âncoras em pixels da pintura (688x384). Medidas na grade de 32px
-- (tools/preview_out/shop_props/lojacena/scene/lojacena_scene_grid.png).
-- ============================================================================
ShopLayout.ART = {
    w = 688, h = 384,
    -- borda do fundo (prateleira atrás do balcão) onde os cavaletes apoiam
    ledgeMask = { 56, 182, 476, 132, 486, 150, 66, 200 },
    -- tampo do balcão (sem a pilha de livros/moedas do canto e sem a caveira)
    tableMask = { 128, 205, 478, 162, 556, 236, 262, 338, 130, 332 },
    -- cavaletes: pé no centro da base, escala por profundidade
    cards = {
        { x = 118, y = 180, s = 1.00 },
        { x = 214, y = 170, s = 0.95 },
        { x = 308, y = 160, s = 0.90 },
        { x = 398, y = 146, s = 0.85 },
    },
    cardH = 94,          -- altura da carta em px da arte na escala 1,0 (a carta cobre a estante atrás, como na referência)
    -- objetos na mesa (3 relíquias + pacote), esquerda-frente → direita-fundo
    objects = {
        { x = 232, y = 302, s = 1.00 },
        { x = 310, y = 280, s = 0.95 },
        { x = 385, y = 258, s = 0.90 },
        { x = 448, y = 250, s = 0.85 },
    },
    objSize = 86,        -- sprite dos objetos (px da arte) na escala 1,0 (~1,25x a primeira versão: ~180 px em 1080p)
    -- sino na frente-esquerda, copo atrás dele (mais fundo, menor)
    bell = { x = 160, y = 324, s = 0.75 },
    dice = { x = 150, y = 252, s = 0.65 },
    lantern = { x = 448, y = 40, w = 50, h = 64 },   -- a pintada (chama ~ (471, 70))
    flame = { x = 471, y = 72 },
}

-- cover-fit idêntico ao SceneBackground.getCoverTransform
local function coverTransform(sw, sh, aw, ah)
    local s = math.max(sw / aw, sh / ah)
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

-- Etiqueta de preço PENDURADA (a das cartas, que o dono gostou), agora
-- também nos objetos: cordão de `len` px a partir de (ax, ay), cartão w x h
-- cisalhado na diagonal (`slope`). `box` = caixa ocupada (validação/hit).
local function hangingTag(ax, ay, lineH, slope)
    local bandH = lineH + 6
    local w = clamp(math.floor(bandH * 1.8), 26, 38)
    local h = math.floor(w * 0.66)
    local len = 4
    local skew = math.abs(slope) * w
    local tag = { ax = math.floor(ax), ay = math.floor(ay), len = len, w = w, h = h, slope = slope }
    tag.box = rect(ax - w / 2 - 4, ay - skew / 2, w + 8, len + h + skew + 2)
    return tag
end
ShopLayout.hangingTag = hangingTag

-- Faixa da raridade da carta: retângulo CISALHADO na diagonal logo abaixo do
-- cavalete. `band` = { x, y (topo na ponta esquerda), w, h, slope };
-- `plate` = a caixa ocupada (validação/hit-test). O preço mora SÓ na
-- etiqueta pendurada da ponta direita (informação repetida é ruído).
local function cardPlates(cx, topY, w, lineH, slope)
    local bandH = lineH + 6
    local x = cx - w / 2
    local band = { x = math.floor(x), y = math.floor(topY - slope * w / 2), w = math.floor(w), h = bandH, slope = slope }
    local ys = { band.y, band.y + slope * band.w, band.y + bandH, band.y + slope * band.w + bandH }
    local plate = bboxOf({ band.x, band.x + band.w, band.x, band.x + band.w }, ys)
    local tw = clamp(math.floor(bandH * 1.8), 26, 38)
    local ax = band.x + band.w - math.floor(tw * 0.5) + 2
    local tag = hangingTag(ax, band.y + slope * (ax - band.x) + band.h, lineH, slope)
    return { plate = plate, band = band, tag = tag }
end

-- Os 4 cantos da carta (TL, TR, BR, BL) no cavalete, em px de tela.
--   hover 0..1 (gira mais), lift px (o lado esquerdo sobe tudo, o direito 1/3)
function ShopLayout.cardQuad(c, hover, lift)
    hover, lift = hover or 0, lift or 0
    local s = c.slope
    local w = c.qw * (1 + (ShopLayout.CARD_W_HOVER - 1) * hover)
    local h = c.qh
    local rk = ShopLayout.CARD_RK + (ShopLayout.CARD_RK_HOVER - ShopLayout.CARD_RK) * hover
    local xl = c.footX - c.qw / 2
    local xr = xl + w
    local yl = c.foot + s * (xl - c.footX)
    local yr = c.foot + s * (xr - c.footX)
    local liftL, liftR = lift, lift / 3
    return xl, yl - h - liftL, xr, yr - h * rk - liftR, xr, yr - liftR, xl, yl - liftL
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
    local function buildCards(xFit, sizeFit)
        cards = {}
        local x1 = A.cards[1].x + cardShift
        for i = 1, nCards do
            local a = A.cards[math.min(i, #A.cards)]
            local ax = x1 + (a.x - A.cards[1].x) * xFit
            local fx, fy = toScreen(cv, ax, a.y)
            local slope = ShopLayout.slopeArt(ax, a.y)
            local h = math.floor(cardH0 * a.s * sizeFit)
            local w = math.floor(h / ShopLayout.CARD_RATIO)
            local qw = math.floor(w * ShopLayout.CARD_FORESHORTEN)
            -- lábio do cavalete: cobre o pé da carta (px de tela)
            local lipH = clamp(math.floor(h * 0.07), 5, 14)
            local foot = math.floor(fy - lipH * 0.5)
            local c = { footX = math.floor(fx), foot = foot, slope = slope, qw = qw, qh = h }
            local x0, y0, xa, ya, x2, y2, x3, y3 = ShopLayout.cardQuad(c, 0, 0)
            local r = bboxOf({ x0, xa, x2, x3 }, { y0, ya, y2, y3 })
            local stand = rect(fx - qw / 2 - 4, fy - lipH, qw + 8, lipH)
            local plates = cardPlates(fx, fy + 4, math.max(qw, 70), lineH, slope)
            c.kind, c.art, c.depth = "card", { x = ax, y = a.y }, a.s
            c.rect, c.stand, c.lipH = r, stand, lipH
            c.standVariant = ((i - 1) % 3) + 1
            c.plate, c.band, c.tag = plates.plate, plates.band, plates.tag
            c.lift = ShopLayout.CARD_LIFT
            cards[i] = c
        end
    end
    buildCards(1, 1)
    -- janela estreita: comprime a diagonal (e, se ainda não cabe, a escala)
    local function cardsRight()
        local c = cards[#cards]
        return math.max(c.rect.x + c.rect.w, c.plate.x + c.plate.w)
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

    -- ===== objetos na mesa =====
    local objSize0 = A.objSize * cv.s
    local objects = {}
    local objShift = math.max(0, leftArt + (A.objSize * 0.75) - A.objects[1].x)
    local function buildObjects(xFit, sizeFit)
        objects = {}
        local x1 = A.objects[1].x + objShift
        local n = nRelics + 1
        for j = 1, n do
            local a = A.objects[math.min(j, #A.objects)]
            local ax = x1 + (a.x - A.objects[1].x) * xFit
            local fx, fy = toScreen(cv, ax, a.y)
            local slope = ShopLayout.slopeArt(ax, a.y)
            local size = math.floor(objSize0 * a.s * sizeFit)
            local skew = math.abs(slope) * size / 2
            local r = rect(fx - size / 2, fy - size - skew, size, size + skew * 2)
            local isPack = j > nRelics
            -- etiqueta presa à base, do lado direito, na diagonal
            local tx = fx + size * 0.30
            local tag = hangingTag(tx, fy + slope * (tx - fx) - 2, lineH, slope)
            objects[j] = {
                kind = isPack and "pack" or "relic",
                art = { x = ax, y = a.y }, depth = a.s, slope = slope,
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
    local function counterObj(a, sizeK, withTag)
        local fx, fy = toScreen(cv, a.x, a.y)
        local size = math.floor(objSize0 * a.s * sizeK)
        local slope = ShopLayout.slopeArt(a.x, a.y)
        local o = {
            art = { x = a.x, y = a.y }, depth = a.s, slope = slope, size = size,
            rect = rect(fx - size / 2, fy - size, size, size),
            foot = math.floor(fy), footX = math.floor(fx),
            lift = ShopLayout.LIFT,
        }
        if withTag then
            local tx = fx + size * 0.28
            o.tag = hangingTag(tx, fy + slope * (tx - fx) - 2, lineH, slope)
            o.plate = o.tag.box
        else
            o.plate = rect(fx - 1, fy, 2, 2)
        end
        return o
    end
    local bell = counterObj(A.bell, 0.8, true)
    local dice = counterObj(A.dice, 0.8, false)

    -- etiqueta da carta: canto DIREITO da faixa; se ali ela cairia sobre o
    -- sino/copo (4:3 aperta a carta 1 contra o copo), passa pro canto esquerdo
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
        if c.tag and (hits(c.tag, dice) or hits(c.tag, bell)) then
            local b = c.band
            local ax = b.x + math.floor(c.tag.w * 0.5) + 2
            c.tag = hangingTag(ax, b.y + b.slope * (ax - b.x) + b.h, lineH, b.slope)
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
    local maxH = continueBtn.y - 10 - (nail.y + nail.h - 2)
    local scrollH = math.min(maxH, rollerH + 8 + artH + textH + buyH + 10 + footH + 12)
    local scroll = rect(scrollX, nail.y + nail.h - 2, scrollW, scrollH)
    scroll.nail = nail
    scroll.rollerH, scroll.footH, scroll.inset = rollerH, footH, inset
    scroll.artMaxH = artH
    scroll.buy = rect(scroll.x + inset, scroll.y + scroll.h - footH - 8 - buyH, scroll.w - inset * 2, buyH)
    scroll.body = rect(scroll.x + inset, scroll.y + rollerH + 6,
        scroll.w - inset * 2, scroll.buy.y - 8 - (scroll.y + rollerH + 6))

    -- lanterna pintada (ShopProps usa o rect pra mariposa/poeira; o sprite
    -- não é desenhado: a chama já está na arte)
    local lx, ly = toScreen(cv, A.lantern.x, A.lantern.y)
    local lantern = rect(lx, ly, A.lantern.w * cv.s, A.lantern.h * cv.s)
    local flx, fly = toScreen(cv, A.flame.x, A.flame.y)
    lantern.flame = { x = math.floor(flx), y = math.floor(fly) }

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
        local ax, ay = toArt(cv, c.footX, c.stand.y + c.stand.h)
        if not pointInPoly(ax, ay, A.ledgeMask) then
            fail("cavalete %d: base (%d,%d na arte) fora da borda do fundo", i, ax, ay)
        end
        if c.foot < c.stand.y or c.foot > c.stand.y + c.stand.h then fail("carta %d: pe fora do suporte", i) end
        local reach = c.lift + ShopLayout.BADGE_RESERVE
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
        if overlaps({ x = r.x, y = r.y - ShopLayout.BADGE_RESERVE - c.lift, w = r.w, h = r.h }, L.sign) then
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
