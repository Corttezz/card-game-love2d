-- tools/test_shop_layout.lua
-- Trava GEOMÉTRICA do Balcão do Mercador (Loja v4, inclinação única 1:8,
-- src/ui/shop/ShopLayout.lua). As arestas são MEDIDAS na pintura.
--
-- 1) ShopLayout.validate em 9 tamanhos (800x600 até 2560x1440, mais o Steam
--    Deck e o 4:3 a k=0,75): pé de todo cavalete na BORDA DO FUNDO pintada e
--    de todo objeto no TAMPO pintado (máscaras em coordenadas da arte),
--    nada se sobrepõe (placas, objetos x cartas, pergaminho, CONTINUAR,
--    placa de título), nada fora da tela, carta legível.
-- 2) A tela REAL (CardRewardScreen em modo shop) nasce e CRESCE/ENCOLHE com
--    a janela falsificada, nos 5 idiomas, e continua íntegra: o caminho do
--    love.resize (FontManager/CardFrame limpos + updateLayout + rebuild).
-- 3) Quando falta largura (4:3), a DIAGONAL se comprime (espaçamento e
--    escala cedem), nunca a ordem; passo constante ao longo da reta.
--
--   love . test_one test_shop_layout

local TK = require("tools.testkit")
local M = {}

local ShopLayout       = require("src.ui.shop.ShopLayout")
local ShopPerspective  = require("src.ui.shop.ShopPerspective")
local CardRewardScreen = require("components.CardRewardScreen")
local EventManager     = require("engine.EventManager")
local FontManager      = require("src.ui.FontManager")
local I18n             = require("src.i18n.I18n")

local PAINT

local SIZES = {
    { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1366, 768 },
    { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 }, { 1067, 800 }, { 1280, 800 },
}

local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local fakeW, fakeH = nil, nil
local function installFakeWindow()
    love.graphics.getWidth = function() return fakeW or realW() end
    love.graphics.getHeight = function() return fakeH or realH() end
end
local function restoreWindow()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
end

local function pump(screen, secs)
    local dt = 1 / 60
    local elapsed = 0
    while elapsed < secs do
        EventManager.update(dt)
        screen:update(dt)
        elapsed = elapsed + dt
    end
end

local function resizeTo(screen, w, h)
    fakeW, fakeH = w, h
    FontManager.clearCache()
    require("src.ui.CardFrame").clearCache()
    screen:updateLayout()
    if #(screen.shopOffers or {}) > 0 then
        screen:createCardInstances()
        screen:createOfferButtons()
    end
end

local function first(bad) return #bad > 0 and bad[1] or "ok" end

-- AS ARESTAS MEDIDAS NA PINTURA (independente das constantes do layout):
-- por coluna x, a última linha CLARA do tampo (o realce de 1 px que o
-- tools/shop_v4_compose.py desenha) logo antes de uma linha escura, numa
-- janela de ±6 px em torno de y0 - x/8. Devolve a reta de mínimos quadrados,
-- o MAIOR desvio entre a linha real e lineY() e quantos degraus internos
-- não têm 8 px (escadinha irregular).
local function measureEdge(data, y0)
    -- o PNG tem margem (ART.pad) em volta do miolo: mede em coordenadas do miolo
    local P = ShopLayout.ART.pad
    local function lum(x, y)
        local r, g, b = data:getPixel(x + P.x, y + P.y)
        return 0.299 * r + 0.587 * g + 0.114 * b
    end
    local n, sx, sy, sxx, sxy = 0, 0, 0, 0, 0
    local worst, runs, last, runLen = 0, {}, nil, 0
    for x = 0, ShopLayout.ART.w - 1 do
        local yc = y0 - x / 8
        local best, bestY = -1e9, nil
        for y = math.floor(yc) - 6, math.floor(yc) + 6 do
            if y >= 0 and y + 1 < ShopLayout.ART.h then
                local d = lum(x, y) - lum(x, y + 1)
                if d > best then best, bestY = d, y end
            end
        end
        worst = math.max(worst, math.abs(bestY - (ShopLayout.lineY(y0, x) - 1)))
        if bestY == last then runLen = runLen + 1
        else
            if last then runs[#runs + 1] = runLen end
            last, runLen = bestY, 1
        end
        n = n + 1
        sx, sy, sxx, sxy = sx + x, sy + bestY, sxx + x * x, sxy + x * bestY
    end
    local k = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    local irregular = 0
    for i = 2, #runs do if runs[i] ~= 8 then irregular = irregular + 1 end end
    return { a = (sy - k * sx) / n + 1, k = k, worst = worst, steps = #runs, irregular = irregular }
end

function M.run()
    TK.bootstrap()
    I18n.init()
    local t = TK.new("loja v4: geometria do balcao 1:8 (9 tamanhos x 5 idiomas)")

    local data = love.image.newImageData("assets/sprites/shop/counter_scene.png")
    local PAD = ShopLayout.ART.pad
    t:eq("pintura = miolo 640x360 + margem", data:getWidth() * 1000 + data:getHeight(),
        (640 + 2 * PAD.x) * 1000 + 360 + 2 * PAD.y)
    -- v5: escala INTEIRA da cena nas resoluções suportadas (virtual pelo UiScale)
    local UiScale = require("src.ui.UiScale")
    for _, r in ipairs({ { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1920, 1080 }, { 2560, 1440 }, { 1280, 800 } }) do
        local k = UiScale.k(r[1], r[2])
        local vw, vh = math.floor(r[1] / k + 0.5), math.floor(r[2] / k + 0.5)
        local cv = ShopLayout.coverTransform(vw, vh, 640, 360, PAD)
        t:truthy(("%dx%d: pixel da cena inteiro (s=%.3f, %.3f px reais)"):format(r[1], r[2], cv.s, cv.s * k),
            cv.integer and math.abs(cv.s * k - math.floor(cv.s * k + 0.5)) < 1e-6)
        -- a pintura com margem cobre a janela inteira
        t:truthy(("%dx%d: pintura cobre a janela"):format(r[1], r[2]),
            cv.ox - PAD.x * cv.s <= 0 and cv.oy - PAD.y * cv.s <= 0
            and cv.ox + (640 + PAD.x) * cv.s >= vw and cv.oy + (360 + PAD.y) * cv.s >= vh)
    end
    local Ls = ShopLayout.LINES
    PAINT = measureEdge(data, Ls.shelfEdge)
    local FRONT = measureEdge(data, Ls.tableEdge)
    for name, E in pairs({ ["degrau (cartas)"] = PAINT, ["mesa (objetos)"] = FRONT }) do
        t:truthy(("%s: aresta medida a %.2f graus (1:8 = 7,13)"):format(name, math.deg(math.atan(-E.k))),
            math.abs(math.deg(math.atan(-E.k)) - math.deg(math.atan(1 / 8))) < 0.5)
        t:eq(name .. ": aresta = lineY() em TODA coluna (desvio em px de arte)", E.worst, 0)
        t:eq(name .. ": degraus todos de 8 px (sem escadinha irregular)", E.irregular, 0)
    end
    t:truthy("as duas superficies paralelas (mesma inclinacao)", math.abs(PAINT.k - FRONT.k) < 0.002)
    t:near("ShopLayout.K = 1:8", ShopLayout.K, -1 / 8, 1e-12)

    -- ===== 1) layout puro =====
    for _, s in ipairs(SIZES) do
        local L = ShopLayout.layout(s[1], s[2], 4, 3)
        local bad = ShopLayout.validate(L)
        t:eq(("%dx%d: layout puro integro (%s)"):format(s[1], s[2], first(bad)), #bad, 0)
        -- projeção oblíqua: escala CONSTANTE ao longo da reta e PASSO constante
        -- (centro a centro, ±1 px); a fileira sobe pra direita
        local function evenStep(list)
            local step = list[2] - list[1]
            for i = 3, #list do
                if math.abs((list[i] - list[i - 1]) - step) > 1.01 then return false end
            end
            return step > 0
        end
        local cardsX = {}
        for i, c in ipairs(L.cards) do cardsX[i] = c.frame.ox end
        local SH, TB = ShopLayout.SHELF, ShopLayout.TABLE
        t:truthy(("%dx%d: cartas com passo constante na borda"):format(s[1], s[2]), evenStep(cardsX))
        t:truthy(("%dx%d: cartas do mesmo tamanho"):format(s[1], s[2]), L.cards[1].qh == L.cards[#L.cards].qh)
        -- v5: GRUPO de cavaletes (vão = SHELF.gap, ou gapMin na janela
        -- estreita), não uma escada de vãos largos; a subida da fileira
        -- inteira fica suave
        local vao = L.cards[2].railX0 - L.cards[1].railX1 - 1
        t:truthy(("%dx%d: vao entre cavaletes %d px de arte (gap %d..%d)"):format(s[1], s[2], vao, SH.gapMin, SH.gap),
            vao >= SH.gapMin and vao <= SH.gap)
        local rise = (L.cards[1].frame.oy - L.cards[#L.cards].frame.oy) / L.cover.s
        t:truthy(("%dx%d: subida da fileira de cartas %.1f px de arte (<= 30)"):format(s[1], s[2], rise),
            rise > 0 and rise <= 30)
        -- mesa: três grupos com intenção (ferramentas | serviços | pacote),
        -- vão dentro do grupo menor que entre grupos, profundidades diferentes
        t:truthy(("%dx%d: copo e sino agrupados na ponta esquerda"):format(s[1], s[2]),
            L.dice.footX < L.bell.footX and L.bell.footX < L.objects[1].footX)
        if #L.relics >= 3 then
            local within = L.relics[2].art.x - L.relics[1].art.x
            local between = L.relics[1].art.x - L.bell.art.x
            local toPack = L.pack.art.x - L.relics[#L.relics].art.x
            t:truthy(("%dx%d: grupos: vao interno %d < vao entre grupos (%d, %d)"):format(s[1], s[2], within, between, toPack),
                within < between and within < toPack)
            t:truthy(("%dx%d: trio de reliquias em V raso (o do meio atras)"):format(s[1], s[2]),
                L.relics[2].art.y0 < L.relics[1].art.y0 and L.relics[2].art.y0 < L.relics[3].art.y0)
        end
        -- tudo da mesa à esquerda do pergaminho
        for j, o in ipairs(L.objects) do
            t:truthy(("%dx%d: objeto %d a esquerda do pergaminho"):format(s[1], s[2], j),
                o.plate.x + o.plate.w <= L.scroll.x)
        end
        t:truthy(("%dx%d: COMPRAR dentro do pergaminho, acima do rodape"):format(s[1], s[2]),
            L.scroll.buy.y + L.scroll.buy.h <= L.scroll.y + L.scroll.h - L.scroll.footH + 2)
        t:truthy(("%dx%d: CONTINUAR no canto inferior direito"):format(s[1], s[2]),
            L.continueBtn.x + L.continueBtn.w <= s[1] and L.continueBtn.y + L.continueBtn.h <= s[2]
            and L.continueBtn.x > s[1] * 0.6 and L.continueBtn.y > s[2] * 0.8)
        -- Loja "reta": UMA reta por carta. Carta (base), trilho e plaquinha
        -- de preço no MESMO frame; ângulos a <= 0,5 grau entre si e da borda
        -- MEDIDA na pintura; as 4 bases colineares com a borda.
        local tag = ("%dx%d: "):format(s[1], s[2])
        local cv = L.cover
        local edgeDeg = math.deg(math.atan(PAINT.k))
        for i, c in ipairs(L.cards) do
            local f = c.frame
            local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(c, 0, 0)
            local baseDeg = ShopPerspective.angleOf(x3, y3, x2, y2)
            -- trilho na grade: quinas de baixo das duas pontas (colunas inteiras)
            local rlx, rly = ShopLayout.toScreen(cv, c.railX0, Ls.shelfEdge - c.railX0 / 8)
            local rrx, rry = ShopLayout.toScreen(cv, c.railX1 + 1, Ls.shelfEdge - (c.railX1 + 1) / 8)
            local railDeg = ShopPerspective.angleOf(rlx, rly, rrx, rry)
            local plateDeg = math.deg(math.atan(c.plaque.slope))
            local function same(name, d1, d2)
                t:truthy(("%scarta %d: %s (%.2f x %.2f graus)"):format(tag, i, name, d1, d2), math.abs(d1 - d2) <= 0.5)
            end
            same("base da carta = trilho", baseDeg, railDeg)
            same("base da carta = plaquinha", baseDeg, plateDeg)
            same("trilho = plaquinha", railDeg, plateDeg)
            same("base da carta = borda pintada", baseDeg, edgeDeg)
            same("trilho = borda pintada", railDeg, edgeDeg)
            -- COLINEAR (não só paralela): a quina de baixo do trilho cai SOBRE a
            -- reta medida na pintura, nas duas pontas
            for _, p in ipairs({ { rlx, rly }, { rrx, rry } }) do
                local ax, ay = (p[1] - cv.ox) / cv.s, (p[2] - cv.oy) / cv.s
                local d = ay - (ShopLayout.lineY(Ls.shelfEdge, math.floor(ax)) - 0.5)
                t:truthy(("%scarta %d: trilho sobre a borda pintada (%.2f px de arte)"):format(tag, i, d), math.abs(d) <= 1.0)
            end
            -- a base da carta fica DENTRO do trilho (cobre <= 3 px de arte)
            t:truthy(tag .. "carta " .. i .. ": trilho cobre <= 3 px de arte da carta",
                c.vb <= ShopLayout.RAIL_ART * cv.s + 0.01 and (ShopLayout.RAIL_ART * cv.s - c.vb) <= 3 * cv.s + 0.01)
            t:truthy(tag .. "carta " .. i .. ": bordas laterais iguais (projecao obliqua, sem ponto de fuga)",
                math.abs((y2 - y1) - (y3 - y0)) < 0.01)
            t:truthy(tag .. "carta " .. i .. ": diagonal sobe pra direita", c.slope < -0.05)
            -- HOVER (v5): a carta NÃO levanta nem cresce: a pose do hover é a
            -- do repouso e a âncora (centro da base, no trilho) não se move
            local h0, h1, h2, h3, h4, h5, h6, h7 = ShopLayout.cardQuad(c, 1, c.lift)
            local moved = math.max(math.abs(h4 - x2), math.abs(h5 - y2), math.abs(h6 - x3), math.abs(h7 - y3),
                math.abs(h0 - x0), math.abs(h1 - y0))
            t:truthy(("%scarta %d: hover nao desloca a carta nem o apoio (%.3f px)"):format(tag, i, moved), moved <= 1e-6)
            -- ÂNCORA = centro da base, dentro do trilho (sem fresta): a base da
            -- carta fica entre o topo do trilho e a aresta
            local by = (y2 + y3) / 2
            local railTop = f.oy - ShopLayout.RAIL_ART * cv.s
            t:truthy(("%scarta %d: base encaixada no trilho (%.1f entre %.1f e %.1f)"):format(tag, i, by, railTop, f.oy),
                by > railTop + 0.5 and by <= f.oy + 0.01)
            t:near(tag .. "carta " .. i .. ": ancora no centro da base", c.anchor.x, (x2 + x3) / 2, 1e-6)
            -- PREÇO: plaquinha na FACE do degrau, no eixo da carta, logo abaixo
            -- da aresta (vínculo físico com o próprio cavalete)
            local pq = c.plaque
            t:truthy(tag .. "carta " .. i .. ": plaquinha no eixo da carta", math.abs(pq.cx - f.art.x) <= 1)
            t:truthy(tag .. "carta " .. i .. ": plaquinha colada na aresta (<= 2 linhas abaixo)",
                pq.y0 - Ls.shelfEdge >= 1 and pq.y0 - Ls.shelfEdge <= 2)
            t:truthy(tag .. "carta " .. i .. ": plaquinha cabe na face do degrau",
                pq.y0 + pq.h <= Ls.shelfFace - 1)
            t:truthy(tag .. "carta " .. i .. ": plaquinha nao passa do trilho",
                pq.x0 >= c.railX0 and pq.x0 + pq.w - 1 <= c.railX1)
        end
        for j, o in ipairs(L.objects) do
            t:near(tag .. "objeto " .. j .. " segue a diagonal", o.slope, ShopLayout.slopeArt(o.art.x, o.art.y), 1e-6)
            local pq = o.plaque
            t:near(tag .. "plaquinha do objeto " .. j .. " na diagonal", pq.slope, o.slope, 1e-9)
            -- vínculo: centrada no pé, À FRENTE dele (no tampo), colada
            t:truthy(tag .. "plaquinha do objeto " .. j .. " no eixo do pe", math.abs(pq.cx - o.art.x) <= 1)
            t:truthy(tag .. "plaquinha do objeto " .. j .. " a frente do pe (1.." .. ShopLayout.PLAQUE.ahead .. " px)",
                pq.y0 - o.art.y0 >= 1 and pq.y0 - o.art.y0 <= ShopLayout.PLAQUE.ahead)
            -- longe da aresta da frente (objeto não atravessa a borda da mesa)
            local front = ShopLayout.lineY(Ls.tableEdge, pq.x0) - (ShopLayout.lineY(pq.y0, pq.x0) + pq.h)
            t:truthy(("%splaquinha do objeto %d a %d px da aresta da frente (>= %d)"):format(tag, j, front, TB.frontMargin),
                front >= TB.frontMargin)
        end
        t:truthy(tag .. "sino com plaquinha de preco na diagonal", L.bell.plaque ~= nil and L.bell.plaque.slope < 0)
        t:falsy(tag .. "copo sem preco (nao e mercadoria)", L.dice.plaque ~= nil)
        -- CONTINUAR inteiro na tela, com respiro (o CRT come a moldura)
        local cb = L.continueBtn
        t:truthy(tag .. "CONTINUAR visivel com respiro da borda",
            cb.x >= 8 and cb.y >= 8 and cb.x + cb.w <= s[1] - 8 and cb.y + cb.h <= s[2] - 8)
    end
    -- v5: luz da cena nos sprites = a queda da pintura (vela à esquerda):
    -- mais escuro pra direita, nunca abaixo de 0,7 (o objeto continua legível)
    local aL, aR = ShopLayout.ambientAt(80, 260), ShopLayout.ambientAt(420, 230)
    t:truthy(("luz ambiente cai pra direita (%.2f -> %.2f)"):format(aL[1], aR[1]), aR[1] < aL[1])
    t:truthy("luz ambiente entre 0,7 e 1", aR[1] >= 0.7 and aL[1] <= 1)
    -- sombra da carta: só à DIREITA (luz da esquerda), 3 px, sem invadir a vizinha
    local ShelfItem = require("src.ui.shop.ShelfItem")
    local Lg = ShopLayout.layout(1280, 720, 4, 3)
    local gapArt = Lg.cards[2].railX0 - Lg.cards[1].railX1 - 1 + 2 * ShopLayout.SHELF.railPad
    t:truthy(("sombra da carta (%d px) cabe no vao ate a vizinha (%d px)"):format(ShelfItem.CARD_SHADOW.w, gapArt),
        ShelfItem.CARD_SHADOW.w < gapArt)
    -- inclinação única 1:8 em qualquer ponto
    t:near("slopeArt = 1:8 em qualquer ponto", ShopLayout.slopeArt(180, 181), ShopLayout.slopeArt(260, 316), 1e-12)
    -- quem cede e a escala/espacamento: 4:3 tem carta menor que 16:9
    local narrow = ShopLayout.layout(1024, 768, 4, 3)
    local wide = ShopLayout.layout(1366, 768, 4, 3)
    t:truthy("4:3 comprime a diagonal (ultima carta mais a esquerda que em 16:9)",
        narrow.cards[4].rect.x < wide.cards[4].rect.x)
    t:truthy("a carta nunca fica ilegivel (>= 60px) nem em 800x600",
        ShopLayout.layout(800, 600, 4, 3).cards[1].rect.w >= 60)
    for _, cfg in ipairs({ { 4, 2 }, { 4, 0 }, { 3, 3 } }) do
        local L = ShopLayout.layout(1024, 768, cfg[1], cfg[2])
        local bad = ShopLayout.validate(L)
        t:eq(("%d cartas + %d reliquias: integro (%s)"):format(cfg[1], cfg[2], first(bad)), #bad, 0)
    end
    -- pé dentro das máscaras pintadas (ponto-no-polígono funciona)
    local A = ShopLayout.ART
    t:truthy("centro do tampo esta no tampo", ShopLayout.pointInPoly(330, 250, A.tableMask))
    t:falsy("a parede nao esta no tampo", ShopLayout.pointInPoly(40, 150, A.tableMask))
    t:truthy("meio do degrau esta no degrau", ShopLayout.pointInPoly(260, 152, A.ledgeMask))

    -- ===== 2) a tela real: nasce pequena e cresce, nos 5 idiomas =====
    installFakeWindow()
    local okRun, err = pcall(function()
        local game = TK.newRunGame("warrior")
        if game.economySystem then game.economySystem.currentGold = 60 end
        for _, code in ipairs(I18n.getAvailable()) do
            I18n.setLocale(code)
            fakeW, fakeH = 800, 600
            local screen = CardRewardScreen:new(game.shopSystem)
            screen:show(game, function() end, function() end, "shop")
            pump(screen, 0.3)
            local bad0 = screen:validateLayout()
            t:eq(("%s 800x600: loja integra ao NASCER (%s)"):format(code, first(bad0)), #bad0, 0)
            t:truthy(code .. ": a cena existe", screen.scene ~= nil and screen.scene.L ~= nil)
            t:eq(code .. ": 8 slots (4 cartas + 3 reliquias + 1 pacote)", screen.slotCount, 8)
            t:truthy(code .. ": COMPRAR existe", screen.buyButton ~= nil)
            for _, s in ipairs(SIZES) do
                resizeTo(screen, s[1], s[2])
                pump(screen, 0.05)
                local bad = screen:validateLayout()
                t:eq(("%s %dx%d apos resize (%s)"):format(code, s[1], s[2], first(bad)), #bad, 0)
                for _, it in ipairs(screen.scene.items) do
                    if it.rect and it.kind == "card" then
                        t:truthy(("%s %dx%d: carta %d apoiada no cavalete"):format(code, s[1], s[2], it.slot),
                            it.foot >= it.geom.stand.y and it.foot <= it.geom.stand.y + it.geom.stand.h)
                    end
                end
                local L = screen.scene.L
                t:truthy(("%s %dx%d: CONTINUAR = botao Continuar"):format(code, s[1], s[2]),
                    screen.skipButton and screen.skipButton.x == L.continueBtn.x and screen.skipButton.y == L.continueBtn.y)
                t:truthy(("%s %dx%d: sino = hitbox Novas ofertas"):format(code, s[1], s[2]),
                    screen.refreshButton and screen.refreshButton.x == L.bell.rect.x)
                t:truthy(("%s %dx%d: COMPRAR no rodape do pergaminho"):format(code, s[1], s[2]),
                    screen.buyButton.x == L.scroll.buy.x and screen.buyButton.y == L.scroll.buy.y)
                t:noerror(("%s %dx%d: draw"):format(code, s[1], s[2]), function() screen:draw() end)
            end
            screen:hide()
        end
        I18n.setLocale("pt_BR")
    end)
    restoreWindow()
    FontManager.clearCache()
    t:truthy("suite da tela rodou sem erro (" .. tostring(err) .. ")", okRun)

    return t:done()
end

return M
