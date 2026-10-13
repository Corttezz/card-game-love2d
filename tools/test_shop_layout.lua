-- tools/test_shop_layout.lua
-- Trava GEOMÉTRICA do Balcão do Mercador em perspectiva (Loja v3b,
-- src/ui/shop/ShopLayout.lua).
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
--    escala cedem), nunca a ordem nem a profundidade (escala decresce da
--    esquerda pra direita).
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

-- A BORDA DO DEGRAU DO FUNDO medida NA PINTURA (independente da constante do
-- layout): por coluna x 80..441, a maior queda de luminância (linha clara do
-- tampo do degrau -> face escura) numa janela de ±4 px em torno de uma reta
-- aproximada lida a olho (188 em x=118, -0,1175); mínimos quadrados.
local function measurePaintedEdge()
    local data = love.image.newImageData("assets/sprites/shop/counter_scene.png")
    local function lum(x, y)
        local r, g, b = data:getPixel(x, y)
        return (r + g + b) / 3
    end
    local n, sx, sy, sxx, sxy = 0, 0, 0, 0, 0
    for x = 80, 441 do
        local y0 = 188 - 0.1175 * (x - 118)
        local best, bestY = -1e9, nil
        for y = math.floor(y0) - 4, math.floor(y0) + 4 do
            local d = lum(x, y) - lum(x, y + 1)
            if d > best then best, bestY = d, y end
        end
        n = n + 1
        sx, sy, sxx, sxy = sx + x, sy + bestY, sxx + x * x, sxy + x * bestY
    end
    local k = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return { a = (sy - k * sx) / n, k = k }
end

function M.run()
    TK.bootstrap()
    I18n.init()
    local t = TK.new("loja v3b: geometria do balcao em perspectiva (9 tamanhos x 5 idiomas)")

    PAINT = measurePaintedEdge()
    t:truthy(("borda pintada medida: %.2f graus"):format(math.deg(math.atan(-PAINT.k))),
        math.abs(math.deg(math.atan(-PAINT.k)) - 6.83) < 0.5)
    do
        local E = ShopLayout.ART.ledgeEdge
        t:truthy("ART.ledgeEdge = a borda medida (inclinacao)", math.abs(E.k - PAINT.k) < 0.002)
        t:truthy("ART.ledgeEdge = a borda medida (altura em x=118/398)",
            math.abs(E.y0 + E.k * (118 - E.x0) - (PAINT.a + PAINT.k * 118)) < 0.5
            and math.abs(E.y0 + E.k * (398 - E.x0) - (PAINT.a + PAINT.k * 398)) < 0.5)
    end

    -- ===== 1) layout puro =====
    for _, s in ipairs(SIZES) do
        local L = ShopLayout.layout(s[1], s[2], 4, 3)
        local bad = ShopLayout.validate(L)
        t:eq(("%dx%d: layout puro integro (%s)"):format(s[1], s[2], first(bad)), #bad, 0)
        -- profundidade: a escala decresce da esquerda pra direita (diagonal)
        t:truthy(("%dx%d: cartas encolhem pro fundo"):format(s[1], s[2]),
            L.cards[1].rect.h > L.cards[#L.cards].rect.h and L.cards[1].rect.x < L.cards[#L.cards].rect.x)
        t:truthy(("%dx%d: objetos encolhem pro fundo e sobem"):format(s[1], s[2]),
            L.objects[1].rect.w > L.objects[#L.objects].rect.w and L.objects[1].foot > L.objects[#L.objects].foot)
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
        -- Loja "reta": UMA reta por carta. Carta (base), trilho, plaquinha de
        -- raridade e etiqueta no MESMO frame; ângulos a <= 0,5 grau entre si e
        -- da borda MEDIDA na pintura; as 4 bases colineares com a borda.
        local tag = ("%dx%d: "):format(s[1], s[2])
        local cv = L.cover
        local edgeDeg = math.deg(math.atan(PAINT.k))
        for i, c in ipairs(L.cards) do
            local f = c.frame
            local x0, y0, x1, y1, x2, y2, x3, y3 = ShopLayout.cardQuad(c, 0, 0)
            local baseDeg = ShopPerspective.angleOf(x3, y3, x2, y2)
            local rlx, rly = ShopLayout.frameAtF(f, -c.railW / 2, 0)
            local rrx, rry = ShopLayout.frameAtF(f, c.railW / 2, 0)
            local railDeg = ShopPerspective.angleOf(rlx, rly, rrx, rry)
            local plateDeg = math.deg(math.atan(c.rarity.slope))
            local tagDeg = math.deg(math.atan(c.tag.slope))
            local function same(name, d1, d2)
                t:truthy(("%scarta %d: %s (%.2f x %.2f graus)"):format(tag, i, name, d1, d2), math.abs(d1 - d2) <= 0.5)
            end
            same("base da carta = trilho", baseDeg, railDeg)
            same("base da carta = plaquinha", baseDeg, plateDeg)
            same("trilho = plaquinha", railDeg, plateDeg)
            same("etiqueta = trilho", tagDeg, railDeg)
            same("base da carta = borda pintada", baseDeg, edgeDeg)
            same("trilho = borda pintada", railDeg, edgeDeg)
            -- COLINEAR (não só paralela): a quina de baixo do trilho cai SOBRE a
            -- reta medida na pintura, nas duas pontas
            for _, p in ipairs({ { rlx, rly }, { rrx, rry } }) do
                local ax, ay = (p[1] - cv.ox) / cv.s, (p[2] - cv.oy) / cv.s
                local d = ay - (PAINT.a + PAINT.k * ax)
                t:truthy(("%scarta %d: trilho sobre a borda pintada (%.2f px de arte)"):format(tag, i, d), math.abs(d) <= 1.0)
            end
            -- a base da carta fica DENTRO do trilho (cobre <= 3 px de arte)
            t:truthy(tag .. "carta " .. i .. ": trilho cobre <= 3 px de arte da carta",
                c.vb <= ShopLayout.RAIL_ART * cv.s + 0.01 and (ShopLayout.RAIL_ART * cv.s - c.vb) <= 3 * cv.s + 0.01)
            t:truthy(tag .. "carta " .. i .. ": borda direita mais curta (foge pro ponto de fuga)", (y2 - y1) < (y3 - y0))
            t:truthy(tag .. "carta " .. i .. ": diagonal sobe pra direita", c.slope < -0.05)
            -- HOVER: mesmo ângulo, sai na perpendicular da borda, escala 1,06
            local h0, h1, h2, h3, h4, h5, h6, h7 = ShopLayout.cardQuad(c, 1, c.lift)
            same("hover: base no mesmo angulo", ShopPerspective.angleOf(h6, h7, h4, h5), baseDeg)
            same("hover: topo no mesmo angulo", ShopPerspective.angleOf(h0, h1, h2, h3), ShopPerspective.angleOf(x0, y0, x1, y1))
            local mx0, my0 = (x2 + x3) / 2, (y2 + y3) / 2
            local mx1, my1 = (h4 + h6) / 2, (h5 + h7) / 2
            local along = (mx1 - mx0) * f.ux + (my1 - my0) * f.uy
            local perp = (mx1 - mx0) * f.nx + (my1 - my0) * f.ny
            t:truthy(("%scarta %d: hover sai na PERPENDICULAR (%.2f ao longo)"):format(tag, i, along), math.abs(along) <= 0.01)
            t:truthy(("%scarta %d: hover sobe 10..14 px (%.1f)"):format(tag, i, perp), perp >= 10 - 0.01 and perp <= 14 + 0.01)
            t:near(tag .. "carta " .. i .. ": hover escala 1,06", (h4 - h6) / (x2 - x3), ShopLayout.CARD_HOVER_SCALE, 1e-6)
        end
        for j, o in ipairs(L.objects) do
            t:near(tag .. "objeto " .. j .. " segue a diagonal", o.slope, ShopLayout.slopeArt(o.art.x, o.art.y), 1e-6)
            t:near(tag .. "etiqueta do objeto " .. j .. " na diagonal", o.tag.slope, o.slope, 1e-9)
            t:truthy(tag .. "objeto " .. j .. " sem placa de 2 linhas (etiqueta pendurada)", o.tag.w <= 38)
        end
        t:truthy(tag .. "sino com etiqueta de preco na diagonal", L.bell.tag ~= nil and L.bell.tag.slope < 0)
        t:falsy(tag .. "copo sem etiqueta (nome so no hover)", L.dice.tag ~= nil)
    end
    -- a perspectiva única: borda do fundo mais rasa que a da frente (mesmo VP)
    t:truthy("borda do fundo (~-6,8 graus) mais rasa que a da frente (~-11 graus)",
        math.abs(ShopLayout.slopeArt(180, 181)) < math.abs(ShopLayout.slopeArt(260, 316)))
    t:near("borda do fundo medida: ~6,8 graus", math.deg(math.atan(-ShopLayout.slopeArt(180, 181))), 6.8, 0.6)
    t:near("borda da frente medida: ~11 graus", math.deg(math.atan(-ShopLayout.slopeArt(260, 316))), 11, 0.8)
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
    t:falsy("a caveira (canto) nao esta no tampo", ShopLayout.pointInPoly(40, 150, A.tableMask))
    t:truthy("meio da borda do fundo esta na borda", ShopLayout.pointInPoly(260, 165, A.ledgeMask))

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
