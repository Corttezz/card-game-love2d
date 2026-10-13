-- src/ui/shop/ShopLayout.lua
-- GEOMETRIA PURA do Balcão do Mercador (Loja v3, docs/plan/shop-v3-balcao.md).
--
-- A loja é uma CENA: estante de cima (cartas em pé em suportes), prateleira
-- de baixo (relíquias apoiadas + pacote pendurado num gancho), balcão na
-- frente (sino / copo de dados / livro-razão) e o pergaminho de inspeção
-- pendurado num prego à direita, com a lanterna na parede entre os dois.
--
-- REGRAS (memory/ui_layout_invariants.md §1):
--   * ZONAS, nunca ancoragem vizinho-a-vizinho: cada objeto pertence a UMA
--     zona e as zonas são disjuntas por construção.
--   * quando falta espaço (800x600) quem cede é a ESCALA dos objetos; as
--     bandas nunca trocam de lugar. Quando sobra, a sobra vira RESPIRO entre
--     as bandas (teto por vão) — nunca um terço da tela escuro.
--   * todo objeto apoiado tem o PÉ dentro da tábua (ou do suporte que está
--     na tábua); o pacote é a única peça PENDURADA e não pode tocar a tábua.
--   * informação ANCORADA no objeto: a etiqueta de preço pendura do BEIRAL da
--     tábua onde o objeto está, logo abaixo dele (nunca sobre a arte: o selo
--     de raridade da carta fica à vista); o rótulo (raridade / efeito / nome)
--     mora na mesma banda, à esquerda da etiqueta.
--   * validate() é a prova geométrica — roda nos testes em 7 tamanhos.
--
-- Este módulo não desenha nem lê o estado do jogo: recebe (sw, sh, nCards,
-- nRelics) e devolve retângulos. Quem desenha é ShopScene; quem anima é
-- ShelfItem. Recalculado a cada resize (e barato o bastante por frame).

local ShopLayout = {}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function rect(x, y, w, h)
    return { x = math.floor(x), y = math.floor(y), w = math.floor(w), h = math.floor(h) }
end

-- Proporções do catálogo de arte (assets/sprites/shop + cartas 96x144).
ShopLayout.CARD_RATIO   = 1.5      -- h/w da carta
ShopLayout.PACK_RATIO   = 1.5      -- sleeve 128x192
ShopLayout.LIFT_RESERVE = 14       -- quanto a carta sobe no hover (px no espaço da UI)
ShopLayout.BADGE_RESERVE = 12      -- selo "NOVA" acima da carta (DiscoveryMark) não invade a placa
ShopLayout.RELIC_LIFT   = 8
ShopLayout.TOPBAR_H     = 56

-- Quantos "degraus" o cone de luz pode andar (ver ShopScene.lightOffset).
ShopLayout.LIGHT_STEP   = 7
ShopLayout.LIGHT_STEPS  = 2

-- Etiqueta de preço (price_tag.png é 24x16) em função da largura do objeto.
-- Piso 30: "$20" na fonte 8 são 24 px + folga; abaixo disso o preço vira
-- "..." (visto no Steam Deck, 1280x800 a k=1,25).
local function tagSize(objW)
    local w = clamp(math.floor(objW * 0.28), 30, 36)
    return w, math.floor(w * 0.66)
end

-- nCards: cartas na estante de cima; nRelics: relíquias apoiadas na
-- prateleira de baixo (o pacote ocupa a última célula, pendurado).
function ShopLayout.layout(sw, sh, nCards, nRelics, opts)
    opts = opts or {}
    nCards = math.max(1, nCards or 4)
    nRelics = math.max(0, nRelics or 3)
    local topBarH = opts.topBarH or ShopLayout.TOPBAR_H

    local margin = clamp(math.floor(sw * 0.025), 12, 40)
    local panelW = math.floor(math.min(sw - margin * 2, math.max(1560, sh * 1.25)))
    local panelX = math.floor((sw - panelW) * 0.5)
    local panelY = topBarH
    local panelH = sh - panelY - math.floor(margin * 0.6)
    local wall = rect(panelX, panelY, panelW, panelH)

    -- ===== colunas: [estantes + balcão] | lanterna | pergaminho =====
    local gap = clamp(math.floor(sw * 0.02), 14, 36)
    local scrollW = clamp(math.floor(panelW * 0.26), 220, 350)
    local lanternW = clamp(math.floor(panelW * 0.07), 56, 96)
    local leftW = panelW - scrollW - lanternW - gap * 2
    if leftW < 340 then
        -- janela estreita: o pergaminho e a lanterna cedem ANTES da vitrine
        -- virar miniatura
        local need = 340 - leftW
        local fromLantern = math.min(need, lanternW - 36)
        lanternW = lanternW - fromLantern
        scrollW = math.max(150, scrollW - (need - fromLantern))
        leftW = panelW - scrollW - lanternW - gap * 2
    end
    local leftX = panelX
    local scrollX = panelX + panelW - scrollW

    -- ===== células (as duas prateleiras dividem a MESMA grade de colunas) =====
    local cols = math.max(nCards, nRelics + 1)
    local gapX = clamp(math.floor(leftW * 0.02), 8, 20)
    local innerPad = clamp(math.floor(leftW * 0.03), 10, 30)
    local cellW = math.floor((leftW - innerPad * 2 - gapX * (cols - 1)) / cols)
    local fill = 0.86

    local signH = 30
    local boardT = clamp(math.floor(leftW * 0.022), 12, 22)   -- espessura da tábua

    local cardW = math.floor(cellW * fill)
    local cardH = math.floor(cardW * ShopLayout.CARD_RATIO)
    local relicH = math.floor(cardH * 0.70)
    local objH = clamp(math.floor(cardH * 0.36), 48, 96)      -- sino / copo / livro

    -- bandas derivadas do tamanho da carta (recalculadas se a escala ceder)
    local standH, tagW, tagH, bandH, plankT, frontH
    local function derive()
        standH = clamp(math.floor(cardW * 0.16), 12, 24)
        tagW, tagH = tagSize(cardW)
        -- banda sob a tábua: etiqueta pendurada (len 4) OU duas linhas de rótulo
        bandH = math.max(tagH + 10, 26)
        plankT = clamp(math.floor(objH * 0.22), 12, 22)
        frontH = math.max(tagH + 12, 28)
    end
    derive()

    -- Altura que a coluna esquerda pede; se não cabe, a ESCALA cede.
    local gapMin = 10
    local function need()
        local top = ShopLayout.BADGE_RESERVE + ShopLayout.LIFT_RESERVE + cardH
            + math.ceil(standH / 2) + boardT + bandH
        local bottom = ShopLayout.RELIC_LIFT + relicH + boardT + bandH
        local counter = objH + plankT + frontH
        return signH + top + gapMin + bottom + gapMin + counter, top, bottom, counter
    end
    local total = need()
    -- As bandas fixas (suporte, etiqueta, tampo) têm piso e não encolhem na
    -- mesma proporção: itera até caber, tirando da carta o que sobrou.
    for _ = 1, 4 do
        if total <= panelH then break end
        local f = (panelH - signH - gapMin * 2) / (total - signH - gapMin * 2)
        cardH = math.max(48, math.floor(cardH * math.min(f, 0.98)))
        cardW = math.floor(cardH / ShopLayout.CARD_RATIO)
        relicH = math.max(30, math.floor(relicH * math.min(f, 0.98)))
        objH = math.max(40, math.floor(objH * math.min(f, 0.98)))
        derive()
        total = need()
    end
    local topZoneH, bottomZoneH, counterH
    total, topZoneH, bottomZoneH, counterH = need()

    -- Sobra vertical = RESPIRO entre as bandas (teto por vão) + margem no
    -- topo; o que ainda sobrar fica sob o balcão (só em janela larga com k=1,
    -- que o UiScale evita em 1080p+).
    local slack = math.max(0, panelH - total)
    local gapTB = gapMin + math.min(56, math.floor(slack * 0.30))
    local gapBC = gapMin + math.min(56, math.floor(slack * 0.30))
    local topMargin = math.min(40, math.floor(slack * 0.16))

    local sign = rect(leftX, panelY, leftW, signH)
    local shelfTop = rect(leftX, panelY + signH + topMargin, leftW, topZoneH)
    local shelfBottom = rect(leftX, shelfTop.y + shelfTop.h + gapTB, leftW, bottomZoneH)
    local counter = rect(leftX, shelfBottom.y + shelfBottom.h + gapBC, leftW, counterH)

    local board1 = rect(leftX, shelfTop.y + shelfTop.h - bandH - boardT, leftW, boardT)
    local board2 = rect(leftX, shelfBottom.y + shelfBottom.h - bandH - boardT, leftW, boardT)
    local band1 = rect(leftX, board1.y + board1.h, leftW, bandH)
    local band2 = rect(leftX, board2.y + board2.h, leftW, bandH)

    -- Etiqueta pendurada do beiral da tábua, encostada à direita do objeto;
    -- o rótulo ocupa o resto da banda, à esquerda.
    local function hangingTag(objRect, board)
        return { ax = objRect.x + objRect.w - math.floor(tagW * 0.5) - 1, ay = board.y + board.h,
                 len = 4, w = tagW, h = tagH }
    end
    local function labelRect(objRect, band)
        return rect(objRect.x, band.y + 3, math.max(10, objRect.w - tagW - 6), band.h - 6)
    end

    -- ===== estante de cima: cartas em suportes =====
    local cards = {}
    for i = 1, nCards do
        local cellX = leftX + innerPad + (i - 1) * (cellW + gapX)
        local x = cellX + math.floor((cellW - cardW) / 2)
        local standW = math.floor(cardW * 0.74)
        local stand = rect(x + (cardW - standW) / 2, board1.y - standH, standW, standH)
        -- a carta entra no rasgo do suporte: pé no meio do suporte, o lábio da
        -- frente (metade de baixo) cobre a base da carta
        local foot = stand.y + math.floor(standH * 0.5)
        local r = rect(x, foot - cardH, cardW, cardH)
        cards[i] = {
            kind = "card", cell = rect(cellX, shelfTop.y, cellW, shelfTop.h),
            rect = r, foot = foot, stand = stand, board = board1, band = band1,
            standVariant = ((i - 1) % 3) + 1,
            tag = hangingTag(r, board1), label = labelRect(r, band1),
            lift = ShopLayout.LIFT_RESERVE,
        }
    end

    -- ===== prateleira de baixo: relíquias apoiadas + pacote no gancho =====
    local relics = {}
    local relicW = math.floor(cellW * fill)
    for j = 1, nRelics do
        local cellX = leftX + innerPad + (j - 1) * (cellW + gapX)
        local x = cellX + math.floor((cellW - relicW) / 2)
        local r = rect(x, board2.y - relicH, relicW, relicH)
        relics[j] = {
            kind = "relic", cell = rect(cellX, shelfBottom.y, cellW, shelfBottom.h),
            rect = r, foot = board2.y, board = board2, band = band2,
            tag = hangingTag(r, board2), label = labelRect(r, band2),
            lift = ShopLayout.RELIC_LIFT,
        }
    end

    local packCol = nRelics + 1
    local packCellX = leftX + innerPad + (packCol - 1) * (cellW + gapX)
    local hookW, hookH = 10, 14
    local hook = rect(packCellX + cellW / 2 - hookW / 2, band1.y + band1.h, hookW, hookH)
    local packTop = hook.y + hook.h - 3
    local packMaxH = board2.y - 6 - packTop          -- pendurado: nunca encosta na tábua
    local packH = math.max(24, math.min(packMaxH, math.floor(cellW * fill * ShopLayout.PACK_RATIO)))
    local packW = math.floor(packH / ShopLayout.PACK_RATIO)
    local packR = rect(packCellX + cellW / 2 - packW / 2, packTop, packW, packH)
    -- a célula do pacote começa no gancho (sob a banda da estante de cima)
    local packCellY = band1.y + band1.h
    local pack = {
        kind = "pack", cell = rect(packCellX, packCellY, cellW, shelfBottom.y + shelfBottom.h - packCellY),
        rect = packR, hook = hook, board = board2, band = band2, hanging = true,
        -- o pacote não toca a tábua: a etiqueta pendura do beiral da tábua de
        -- baixo como as das relíquias (mesma linha de leitura), nome ao lado
        tag = hangingTag(packR, board2), label = labelRect(packR, band2),
        lift = 0,
    }

    -- ===== balcão: sino | copo de dados | livro-razão (apoiados no tampo) =====
    local plank = rect(counter.x, counter.y + objH, counter.w, plankT)
    local front = rect(counter.x, plank.y + plank.h, counter.w, frontH)
    local objFoot = plank.y + math.floor(plankT * 0.6)   -- pé afunda no tampo (perspectiva)
    local cpad = clamp(math.floor(counter.w * 0.04), 12, 48)
    local bellS = objH
    local diceS = objH
    local ledgerW = math.floor(objH * 1.25)
    local ledgerH = math.floor(ledgerW * 0.8)
    local bell = rect(counter.x + cpad, objFoot - bellS, bellS, bellS)
    local dice = rect(bell.x + bell.w + cpad * 1.6, objFoot - diceS, diceS, diceS)
    local ledger = rect(counter.x + counter.w - cpad - ledgerW, objFoot - ledgerH, ledgerW, ledgerH)
    counter.plank, counter.front, counter.foot = plank, front, objFoot
    counter.bell, counter.dice, counter.ledger = bell, dice, ledger
    -- etiquetas do balcão: penduradas do beiral do tampo, sob o objeto
    counter.bellTag = { ax = bell.x + bell.w - math.floor(tagW * 0.5), ay = plank.y + plank.h,
                        len = 4, w = tagW, h = tagH }
    counter.ledgerTag = { ax = ledger.x + ledger.w - math.floor(tagW * 0.5), ay = plank.y + plank.h,
                          len = 4, w = tagW, h = tagH }

    -- ===== pergaminho (prego + rolo) — altura pelo CONTEÚDO, não pela tela =====
    local nail = rect(scrollX + scrollW / 2 - 4, panelY + 4, 8, 10)
    local rollerH = clamp(math.floor(scrollW * 0.10), 18, 40)
    local footH = math.floor(rollerH * 1.3)
    local inset = clamp(math.floor(scrollW * 0.13), 12, 48)
    -- a carta no pergaminho é MENOR que a da prateleira (ela repete a arte;
    -- quem decide é o texto) e o bloco de texto tem altura própria
    local artH = math.floor(cardH * 0.78)
    local textH = clamp(math.floor(panelH * 0.34), 150, 240)
    local scrollH = math.min(panelH - (nail.y + nail.h - 2 - panelY) - 4,
        rollerH + 8 + artH + textH + footH + 12)
    local scroll = rect(scrollX, nail.y + nail.h - 2, scrollW, scrollH)
    scroll.nail = nail
    scroll.rollerH, scroll.footH, scroll.inset = rollerH, footH, inset
    scroll.artMaxH = artH
    scroll.body = rect(scroll.x + inset, scroll.y + rollerH + 6,
        scroll.w - inset * 2, scroll.h - rollerH - footH - 12)

    -- ===== lanterna: entre a prateleira e o pergaminho, na altura da estante =====
    local lantern = rect(leftX + leftW + gap, shelfTop.y + 2, lanternW,
        clamp(math.floor(lanternW * 1.6), 90, 160))

    -- "?" das regras (ao lado do título, posição final derivada do texto no
    -- draw) e "?" dos dados, no canto direito da placa.
    local help = rect(sign.x + sign.w - 56, sign.y + 4, 22, 22)
    local diceHelp = rect(sign.x + sign.w - 26, sign.y + 4, 22, 22)

    return {
        sw = sw, sh = sh, wall = wall, sign = sign,
        shelfTop = shelfTop, shelfBottom = shelfBottom, counter = counter,
        scroll = scroll, lantern = lantern,
        board1 = board1, board2 = board2, band1 = band1, band2 = band2,
        cards = cards, relics = relics, pack = pack,
        cardW = cardW, cardH = cardH, relicH = relicH, cellW = cellW,
        leftW = leftW, tagW = tagW, tagH = tagH,
        help = help, diceHelp = diceHelp,
    }
end

-- ============================================================================
-- VALIDAÇÃO — a prova que layout por acumulação nunca tem
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

local function tagRect(tag)
    return { x = tag.ax - tag.w / 2, y = tag.ay + tag.len, w = tag.w, h = tag.h }
end
ShopLayout.tagRect = tagRect

local function fmt(r) return ("(%d,%d %dx%d)"):format(r.x, r.y, r.w, r.h) end

function ShopLayout.validate(L)
    local bad = {}
    local function fail(msg, ...) bad[#bad + 1] = msg:format(...) end
    local screen = { x = 0, y = 0, w = L.sw, h = L.sh }

    if not inside(screen, L.wall) then fail("parede %s fora da tela", fmt(L.wall)) end
    for _, name in ipairs({ "sign", "shelfTop", "shelfBottom", "counter", "scroll", "lantern" }) do
        if not inside(L.wall, L[name]) then
            fail("zona %s %s escapa da parede %s", name, fmt(L[name]), fmt(L.wall))
        end
    end
    if L.scroll.nail and not inside(L.wall, L.scroll.nail) then fail("prego fora da parede") end
    for _, name in ipairs({ "help", "diceHelp" }) do
        if not inside(L.sign, L[name]) then fail("'?' (%s) fora da placa", name) end
    end
    if overlaps(L.help, L.diceHelp) then fail("os dois '?' da placa se sobrepoem") end

    -- zonas disjuntas e em ordem
    if overlaps(L.shelfTop, L.shelfBottom) then fail("estante de cima invade a prateleira de baixo") end
    if L.counter.y < L.shelfBottom.y + L.shelfBottom.h then fail("balcao (y=%d) sobe na prateleira (fim %d)", L.counter.y, L.shelfBottom.y + L.shelfBottom.h) end
    if L.sign.y + L.sign.h > L.shelfTop.y then fail("placa invade a estante") end
    for _, name in ipairs({ "shelfTop", "shelfBottom", "counter", "sign" }) do
        if overlaps(L[name], L.scroll) then fail("%s invade o pergaminho", name) end
        if overlaps(L[name], L.lantern) then fail("%s invade a lanterna", name) end
    end
    if overlaps(L.lantern, L.scroll) then fail("lanterna invade o pergaminho") end
    if L.scroll.body.w < 130 then fail("pergaminho estreito demais (%dpx)", L.scroll.body.w) end
    if L.scroll.body.h < L.scroll.artMaxH + 60 then fail("pergaminho baixo demais pro conteudo (%d)", L.scroll.body.h) end
    -- espaço morto: nenhum vão entre bandas da coluna esquerda passa de 60px
    local gapTB = L.shelfBottom.y - (L.shelfTop.y + L.shelfTop.h)
    local gapBC = L.counter.y - (L.shelfBottom.y + L.shelfBottom.h)
    if gapTB > 70 then fail("vao estante/prateleira de %dpx (teto 70)", gapTB) end
    if gapBC > 70 then fail("vao prateleira/balcao de %dpx (teto 70)", gapBC) end
    local tail = L.wall.y + L.wall.h - (L.counter.y + L.counter.h)
    if tail < -1 then fail("balcao sai da parede por %dpx", -tail) end
    if tail > math.max(70, L.wall.h * 0.2) then fail("faixa morta sob o balcao: %dpx", tail) end

    -- cartas: suporte na tábua, pé no suporte, retângulo (levantado) na zona,
    -- etiqueta pendurada do beiral e rótulo na banda sem se tocarem
    local prev
    for i, c in ipairs(L.cards) do
        local s, b = c.stand, c.board
        if s.y + s.h < b.y or s.y + s.h > b.y + b.h then
            fail("carta %d: suporte (base y=%d) fora da tabua [%d,%d]", i, s.y + s.h, b.y, b.y + b.h)
        end
        if c.foot < s.y or c.foot > s.y + s.h then
            fail("carta %d: pe (y=%d) fora do suporte [%d,%d]", i, c.foot, s.y, s.y + s.h)
        end
        local reach = c.lift + ShopLayout.BADGE_RESERVE
        local lifted = { x = c.rect.x, y = c.rect.y - reach, w = c.rect.w, h = c.rect.h + reach }
        if not inside(L.shelfTop, lifted) then fail("carta %d levantada + selo %s escapa da estante %s", i, fmt(lifted), fmt(L.shelfTop)) end
        if not inside(c.cell, c.rect, 0) then fail("carta %d %s fora da celula %s", i, fmt(c.rect), fmt(c.cell)) end
        local tr = tagRect(c.tag)
        if c.tag.ay ~= b.y + b.h then fail("carta %d: etiqueta nao pendura do beiral da tabua", i) end
        if not inside(c.band, tr, 2) then fail("carta %d: etiqueta %s fora da banda %s", i, fmt(tr), fmt(c.band)) end
        if overlaps(tr, c.rect) then fail("carta %d: etiqueta cobre a carta", i) end
        if not inside(c.band, c.label, 1) then fail("carta %d: rotulo fora da banda", i) end
        if c.label.x + c.label.w > tr.x then fail("carta %d: rotulo passa por baixo da etiqueta", i) end
        if prev and overlaps(prev, c.rect) then fail("cartas %d e %d se sobrepoem", i - 1, i) end
        if c.rect.w < 40 or c.rect.h < 60 then fail("carta %d ilegivel (%dx%d)", i, c.rect.w, c.rect.h) end
        prev = c.rect
    end

    prev = nil
    for j, r in ipairs(L.relics) do
        if r.foot < r.board.y or r.foot > r.board.y + r.board.h then
            fail("reliquia %d: pe (y=%d) fora da tabua [%d,%d]", j, r.foot, r.board.y, r.board.y + r.board.h)
        end
        local lifted = { x = r.rect.x, y = r.rect.y - r.lift, w = r.rect.w, h = r.rect.h + r.lift }
        if not inside(L.shelfBottom, lifted) then fail("reliquia %d levantada %s escapa da prateleira %s", j, fmt(lifted), fmt(L.shelfBottom)) end
        if not inside(r.cell, r.rect, 0) then fail("reliquia %d fora da celula", j) end
        local tr = tagRect(r.tag)
        if not inside(r.band, tr, 2) then fail("reliquia %d: etiqueta fora da banda", j) end
        if overlaps(tr, r.rect) then fail("reliquia %d: etiqueta cobre o objeto", j) end
        if r.label.x + r.label.w > tr.x then fail("reliquia %d: rotulo passa por baixo da etiqueta", j) end
        if prev and overlaps(prev, r.rect) then fail("reliquias %d e %d se sobrepoem", j - 1, j) end
        if r.rect.w < 30 or r.rect.h < 30 then fail("reliquia %d minuscula (%dx%d)", j, r.rect.w, r.rect.h) end
        prev = r.rect
    end

    local p = L.pack
    if p.rect.y > p.hook.y + p.hook.h then fail("pacote solto do gancho (y=%d > %d)", p.rect.y, p.hook.y + p.hook.h) end
    if p.rect.y + p.rect.h >= p.board.y then fail("pacote pendurado encosta na tabua (fim %d >= %d)", p.rect.y + p.rect.h, p.board.y) end
    if not inside(p.cell, p.rect, 0) then fail("pacote %s fora da celula %s", fmt(p.rect), fmt(p.cell)) end
    if prev and overlaps(prev, p.rect) then fail("pacote sobrepoe a ultima reliquia") end
    if p.rect.w < 24 then fail("pacote minusculo (%dpx)", p.rect.w) end
    local ptr = tagRect(p.tag)
    if overlaps(ptr, p.rect) then fail("pacote: etiqueta cobre o pacote") end
    if not inside(p.band, ptr, 2) then fail("pacote: etiqueta fora da banda") end

    -- balcão: objetos apoiados no tampo, em ordem, sem se tocar; etiquetas na frente
    local C = L.counter
    local order = { { "sino", C.bell }, { "dados", C.dice }, { "livro", C.ledger } }
    local last
    for _, e in ipairs(order) do
        local name, r = e[1], e[2]
        if not inside(C, r) then fail("%s %s fora do balcao %s", name, fmt(r), fmt(C)) end
        local foot = r.y + r.h
        if foot < C.plank.y or foot > C.plank.y + C.plank.h then
            fail("%s: pe (y=%d) fora do tampo [%d,%d]", name, foot, C.plank.y, C.plank.y + C.plank.h)
        end
        if r.h < 32 then fail("%s miudo (%dpx)", name, r.h) end
        if last and r.x < last.r.x + last.r.w + 4 then fail("%s encosta em %s", name, last.name) end
        last = { name = name, r = r }
    end
    for _, e in ipairs({ { "sino", C.bellTag }, { "livro", C.ledgerTag } }) do
        local tr = tagRect(e[2])
        if not inside(C.front, tr, 2) then fail("etiqueta do %s %s fora da frente do balcao %s", e[1], fmt(tr), fmt(C.front)) end
    end
    if overlaps(tagRect(C.bellTag), tagRect(C.ledgerTag)) then fail("etiquetas do balcao se tocam") end

    return bad
end

return ShopLayout
