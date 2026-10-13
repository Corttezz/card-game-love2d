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
--     bandas nunca trocam de lugar.
--   * todo objeto apoiado tem o PÉ dentro da tábua (ou do suporte que está
--     na tábua); o pacote é a única peça PENDURADA e não pode tocar a tábua.
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
ShopLayout.RELIC_LIFT   = 8
ShopLayout.TOPBAR_H     = 56

-- Quantos "degraus" o cone de luz pode andar (ver ShopScene.lightOffset).
ShopLayout.LIGHT_STEP   = 7
ShopLayout.LIGHT_STEPS  = 2

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
    local scrollW = clamp(math.floor(panelW * 0.27), 220, 360)
    local lanternW = clamp(math.floor(panelW * 0.045), 36, 64)
    local leftW = panelW - scrollW - lanternW - gap * 2
    if leftW < 340 then
        -- janela estreita: o pergaminho cede ANTES da vitrine virar miniatura
        scrollW = math.max(150, scrollW - (340 - leftW))
        leftW = panelW - scrollW - lanternW - gap * 2
    end
    local leftX = panelX
    local scrollX = panelX + panelW - scrollW

    -- ===== bandas verticais da coluna esquerda =====
    local signH = 30
    local counterH = clamp(math.floor(panelH * 0.19), 62, 110)
    local gapY = 10
    local shelfRegionH = panelH - signH - counterH - gapY
    local boardT = clamp(math.floor(leftW * 0.022), 10, 22)   -- espessura da tábua (arte 16 px ~1:1 no espaço virtual)
    local shelfGap = 14

    -- ===== células (as duas prateleiras dividem a MESMA grade de colunas) =====
    local cols = math.max(nCards, nRelics + 1)
    local gapX = clamp(math.floor(leftW * 0.02), 8, 20)
    local innerPad = clamp(math.floor(leftW * 0.03), 10, 30)
    local cellW = math.floor((leftW - innerPad * 2 - gapX * (cols - 1)) / cols)
    local fill = 0.86

    local cardW = math.floor(cellW * fill)
    local cardH = math.floor(cardW * ShopLayout.CARD_RATIO)
    local standH = clamp(math.floor(cardW * 0.11), 8, 18)
    local relicH = math.floor(cardH * 0.70)

    -- Altura que as duas estantes pedem; se não cabe, a ESCALA cede.
    local function need(ch, rh)
        -- a carta entra no rasgo do suporte: metade do suporte fica acima da tábua
        local top = ShopLayout.LIFT_RESERVE + ch + math.ceil(standH / 2) + boardT
        local bottom = ShopLayout.RELIC_LIFT + rh + boardT
        return top + shelfGap + bottom, top, bottom
    end
    local total = need(cardH, relicH)
    if total > shelfRegionH then
        local f = shelfRegionH / total
        cardH = math.max(48, math.floor(cardH * f))
        cardW = math.floor(cardH / ShopLayout.CARD_RATIO)
        relicH = math.max(30, math.floor(relicH * f))
        standH = clamp(math.floor(cardW * 0.11), 8, 18)
    end
    local topZoneH, bottomZoneH
    total, topZoneH, bottomZoneH = need(cardH, relicH)

    -- Sobra vertical: um pouco vira respiro entre as estantes (lê como
    -- dois andares), o resto afasta o balcão das prateleiras.
    local slack = math.max(0, shelfRegionH - total)
    local extraShelfGap = math.min(28, math.floor(slack * 0.35))
    local topMargin = math.min(24, math.floor((slack - extraShelfGap) * 0.4))
    shelfGap = shelfGap + extraShelfGap

    local sign = rect(leftX, panelY, leftW, signH)
    local shelfTop = rect(leftX, panelY + signH + topMargin, leftW, topZoneH)
    local shelfBottom = rect(leftX, shelfTop.y + shelfTop.h + shelfGap, leftW, bottomZoneH)
    local counter = rect(leftX, panelY + panelH - counterH, leftW, counterH)

    local board1 = rect(leftX, shelfTop.y + shelfTop.h - boardT, leftW, boardT)
    local board2 = rect(leftX, shelfBottom.y + shelfBottom.h - boardT, leftW, boardT)

    -- ===== objetos da estante de cima: cartas em suportes =====
    local tagW = clamp(math.floor(cardW * 0.34), 24, 44)
    local tagH = math.floor(tagW * 0.66)
    local cards = {}
    for i = 1, nCards do
        local cellX = leftX + innerPad + (i - 1) * (cellW + gapX)
        local x = cellX + math.floor((cellW - cardW) / 2)
        local standW = math.floor(cardW * 0.72)
        local stand = rect(x + (cardW - standW) / 2, board1.y - standH, standW, standH)
        -- a carta entra no rasgo do suporte: pé no meio do suporte
        local foot = stand.y + math.floor(standH * 0.5)
        local r = rect(x, foot - cardH, cardW, cardH)
        cards[i] = {
            kind = "card", cell = rect(cellX, shelfTop.y, cellW, shelfTop.h),
            rect = r, foot = foot, stand = stand, board = board1,
            standVariant = ((i - 1) % 3) + 1,
            -- etiqueta amarrada no canto superior direito; o barbante desce
            -- até ABAIXO da faixa do nome (18% da carta) pra não cobrir o
            -- título, e a etiqueta cai sobre a borda direita da ilustração
            tag = { ax = r.x + r.w - math.floor(tagW * 0.42), ay = r.y + 2,
                    len = math.max(8, math.floor(cardH * 0.19)), w = tagW, h = tagH },
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
            rect = r, foot = board2.y, board = board2,
            -- barbante preso na tábua de cima, etiqueta caindo na frente do ombro direito
            tag = { ax = r.x + math.floor(r.w * 0.74), ay = board1.y + board1.h,
                    len = math.max(6, (r.y + math.floor(r.h * 0.30)) - (board1.y + board1.h) - tagH),
                    w = tagW, h = tagH },
            lift = ShopLayout.RELIC_LIFT,
        }
    end

    local packCol = nRelics + 1
    local packCellX = leftX + innerPad + (packCol - 1) * (cellW + gapX)
    local hookW, hookH = 10, 14
    local hook = rect(packCellX + cellW / 2 - hookW / 2, board1.y + board1.h, hookW, hookH)
    local packTop = hook.y + hook.h - 3
    local packMaxH = board2.y - 6 - packTop          -- pendurado: nunca encosta na tábua
    local packH = math.max(24, math.min(packMaxH, math.floor(cellW * fill * ShopLayout.PACK_RATIO)))
    local packW = math.floor(packH / ShopLayout.PACK_RATIO)
    -- a célula do pacote começa no gancho (sob a tábua de cima) e vai até o
    -- fim da prateleira: é o único objeto que atravessa o vão entre andares
    local packCellY = board1.y + board1.h
    local pack = {
        kind = "pack", cell = rect(packCellX, packCellY, cellW, shelfBottom.y + shelfBottom.h - packCellY),
        rect = rect(packCellX + cellW / 2 - packW / 2, packTop, packW, packH),
        hook = hook, board = board2, hanging = true,
        tag = { ax = hook.x + hookW / 2 - 6, ay = hook.y + hook.h - 2,
                len = 6, w = tagW, h = tagH },
        lift = 0,
    }

    -- ===== balcão: sino | copo de dados | livro-razão (apoiados no tampo) =====
    local frontH = clamp(math.floor(counterH * 0.30), 14, 30)
    local plankT = clamp(math.floor(counterH * 0.18), 8, 18)
    local plank = rect(counter.x, counter.y + counterH - frontH - plankT, counter.w, plankT)
    local objH = counterH - frontH - plankT - 4
    local objFoot = plank.y + plankT - 3
    local cpad = clamp(math.floor(counter.w * 0.04), 12, 40)
    local bellS = clamp(math.floor(objH * 0.95), 28, 60)
    local diceS = clamp(math.floor(objH * 0.95), 28, 56)
    local ledgerW = clamp(math.floor(objH * 1.25), 40, 80)
    local ledgerH = math.floor(ledgerW * 0.8)
    local bell = rect(counter.x + cpad, objFoot - bellS, bellS, bellS)
    local dice = rect(bell.x + bell.w + cpad * 1.5, objFoot - diceS, diceS, diceS)
    local ledger = rect(counter.x + counter.w - cpad - ledgerW, objFoot - ledgerH, ledgerW, ledgerH)
    counter.plank, counter.frontH = plank, frontH
    counter.bell, counter.dice, counter.ledger = bell, dice, ledger
    counter.foot = objFoot
    -- rótulo de giz na frente do balcão, sob cada objeto (zona própria)
    counter.labelY = plank.y + plankT + 2
    counter.labelH = frontH - 2

    -- ===== pergaminho (prego + rolo) e lanterna =====
    local nail = rect(scrollX + scrollW / 2 - 4, panelY + 4, 8, 10)
    local scroll = rect(scrollX, nail.y + nail.h - 2, scrollW, panelH - (nail.y + nail.h - 2 - panelY) - 4)
    scroll.nail = nail
    -- rolos de cima e de baixo (o de baixo leva a borla) e o miolo legível
    scroll.rollerH = clamp(math.floor(scrollW * 0.10), 18, 40)
    scroll.footH = math.floor(scroll.rollerH * 1.3)
    local inset = clamp(math.floor(scrollW * 0.13), 12, 48)
    scroll.body = rect(scroll.x + inset, scroll.y + scroll.rollerH + 6,
        scroll.w - inset * 2, scroll.h - scroll.rollerH - scroll.footH - 12)

    local lantern = rect(leftX + leftW + gap, shelfTop.y + 6, lanternW,
        clamp(math.floor(lanternW * 1.6), 48, 100))

    return {
        sw = sw, sh = sh, wall = wall, sign = sign,
        shelfTop = shelfTop, shelfBottom = shelfBottom, counter = counter,
        scroll = scroll, lantern = lantern,
        board1 = board1, board2 = board2,
        cards = cards, relics = relics, pack = pack,
        cardW = cardW, cardH = cardH, relicH = relicH, cellW = cellW,
        leftW = leftW,
        -- "?" das regras no canto direito da placa
        help = rect(sign.x + sign.w - 26, sign.y + 4, 22, 22),
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

    -- zonas disjuntas
    if overlaps(L.shelfTop, L.shelfBottom) then fail("estante de cima invade a prateleira de baixo") end
    if L.counter.y < L.shelfBottom.y + L.shelfBottom.h then fail("balcao (y=%d) sobe na prateleira (fim %d)", L.counter.y, L.shelfBottom.y + L.shelfBottom.h) end
    if L.sign.y + L.sign.h > L.shelfTop.y then fail("placa invade a estante") end
    for _, name in ipairs({ "shelfTop", "shelfBottom", "counter", "sign" }) do
        if overlaps(L[name], L.scroll) then fail("%s invade o pergaminho", name) end
        if overlaps(L[name], L.lantern) then fail("%s invade a lanterna", name) end
    end
    if overlaps(L.lantern, L.scroll) then fail("lanterna invade o pergaminho") end
    if L.scroll.body.w < 130 then fail("pergaminho estreito demais (%dpx)", L.scroll.body.w) end

    -- cartas: suporte na tábua, pé no suporte, retângulo (levantado) na zona
    local prev
    for i, c in ipairs(L.cards) do
        local s, b = c.stand, c.board
        if s.y + s.h < b.y or s.y + s.h > b.y + b.h then
            fail("carta %d: suporte (base y=%d) fora da tabua [%d,%d]", i, s.y + s.h, b.y, b.y + b.h)
        end
        if c.foot < s.y or c.foot > s.y + s.h then
            fail("carta %d: pe (y=%d) fora do suporte [%d,%d]", i, c.foot, s.y, s.y + s.h)
        end
        local lifted = { x = c.rect.x, y = c.rect.y - c.lift, w = c.rect.w, h = c.rect.h + c.lift }
        if not inside(L.shelfTop, lifted) then fail("carta %d levantada %s escapa da estante %s", i, fmt(lifted), fmt(L.shelfTop)) end
        if not inside(c.cell, c.rect, 0) then fail("carta %d %s fora da celula %s", i, fmt(c.rect), fmt(c.cell)) end
        local tagR = { x = c.tag.ax - c.tag.w / 2, y = c.tag.ay + c.tag.len, w = c.tag.w, h = c.tag.h }
        if not inside(L.shelfTop, tagR, 2) then fail("carta %d: etiqueta %s fora da estante", i, fmt(tagR)) end
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

    -- balcão: objetos apoiados no tampo, em ordem, sem se tocar
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
        if last and r.x < last.r.x + last.r.w + 4 then fail("%s encosta em %s", name, last.name) end
        last = { name = name, r = r }
    end
    if C.labelH < 10 then fail("frente do balcao sem altura pro rotulo (%d)", C.labelH) end

    return bad
end

return ShopLayout
