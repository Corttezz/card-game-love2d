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
local CardRewardScreen = require("components.CardRewardScreen")
local EventManager     = require("engine.EventManager")
local FontManager      = require("src.ui.FontManager")
local I18n             = require("src.i18n.I18n")

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

function M.run()
    TK.bootstrap()
    I18n.init()
    local t = TK.new("loja v3b: geometria do balcao em perspectiva (9 tamanhos x 5 idiomas)")

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
    end
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
