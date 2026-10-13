-- tools/test_shop_layout.lua
-- Trava GEOMÉTRICA do Balcão do Mercador (Loja v3, src/ui/shop/ShopLayout.lua).
--
-- 1) ShopLayout.validate em 7 tamanhos (800x600 até 2560x1440): zonas
--    disjuntas (estantes / balcão / pergaminho / lanterna), PÉ de todo objeto
--    dentro da tábua (ou do suporte que está na tábua), pacote PENDURADO sem
--    tocar a prateleira, nada fora da tela, carta legível.
-- 2) A tela REAL (CardRewardScreen em modo shop) nasce e CRESCE/ENCOLHE com
--    a janela falsificada, nos 5 idiomas, e continua íntegra: o caminho do
--    love.resize (FontManager/CardFrame limpos + updateLayout + rebuild).
-- 3) Quando falta espaço quem cede é a ESCALA dos objetos, nunca a posição
--    das bandas (800x600 tem carta menor que 1920x1080, com a mesma ordem
--    placa → estante → prateleira → balcão).
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
    { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 },
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

-- O que o jogo faz no love.resize (main.lua): limpa fontes/canvas, recalcula
-- o layout e reconstrói as instâncias.
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
    local t = TK.new("loja v3: geometria do balcao (zonas, pe na tabua, 7 tamanhos x 5 idiomas)")

    -- ===== 1) layout puro =====
    for _, s in ipairs(SIZES) do
        local L = ShopLayout.layout(s[1], s[2], 4, 3)
        local bad = ShopLayout.validate(L)
        t:eq(("%dx%d: layout puro integro (%s)"):format(s[1], s[2], first(bad)), #bad, 0)
        -- ordem das bandas nunca muda
        t:truthy(("%dx%d: placa > estante > prateleira > balcao"):format(s[1], s[2]),
            L.sign.y < L.shelfTop.y and L.shelfTop.y + L.shelfTop.h <= L.shelfBottom.y
            and L.shelfBottom.y + L.shelfBottom.h <= L.counter.y)
        t:truthy(("%dx%d: pergaminho a direita de tudo"):format(s[1], s[2]),
            L.scroll.x >= L.counter.x + L.counter.w and L.scroll.x >= L.lantern.x + L.lantern.w)
        -- o pacote pendurado nunca toca a tabua de baixo
        t:truthy(("%dx%d: pacote pendurado nao toca a prateleira"):format(s[1], s[2]),
            L.pack.rect.y + L.pack.rect.h < L.board2.y)
        -- todo objeto do balcao com o pe no tampo
        for _, k in ipairs({ "bell", "dice", "ledger" }) do
            local r = L.counter[k]
            t:truthy(("%dx%d: %s apoiado no tampo"):format(s[1], s[2], k),
                r.y + r.h >= L.counter.plank.y and r.y + r.h <= L.counter.plank.y + L.counter.plank.h)
        end
    end
    -- quem cede e a escala: a carta encolhe em 800x600, as bandas ficam
    local small = ShopLayout.layout(800, 600, 4, 3)
    local big = ShopLayout.layout(1920, 1080, 4, 3)
    t:truthy("800x600 tem carta menor que 1920x1080", small.cardW < big.cardW)
    t:truthy("a carta nunca fica ilegivel (>= 60px) nem em 800x600", small.cardW >= 60)
    -- menos reliquias / mais cartas tambem fecham
    for _, cfg in ipairs({ { 4, 2 }, { 4, 0 }, { 5, 3 }, { 3, 3 } }) do
        local L = ShopLayout.layout(1024, 768, cfg[1], cfg[2])
        local bad = ShopLayout.validate(L)
        t:eq(("%d cartas + %d reliquias: integro (%s)"):format(cfg[1], cfg[2], first(bad)), #bad, 0)
    end

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
            for _, s in ipairs(SIZES) do
                resizeTo(screen, s[1], s[2])
                pump(screen, 0.05)
                local bad = screen:validateLayout()
                t:eq(("%s %dx%d apos resize (%s)"):format(code, s[1], s[2], first(bad)), #bad, 0)
                -- os objetos acompanharam a tabua (pe no suporte / na tabua)
                for _, it in ipairs(screen.scene.items) do
                    if it.rect and it.kind == "card" then
                        t:truthy(("%s %dx%d: carta %d apoiada no suporte"):format(code, s[1], s[2], it.slot),
                            it.foot >= it.geom.stand.y and it.foot <= it.geom.stand.y + it.geom.stand.h)
                    end
                end
                -- os botoes invisiveis do balcao cobrem os objetos
                local C = screen.scene.L.counter
                t:truthy(("%s %dx%d: livro-razao = botao Continuar"):format(code, s[1], s[2]),
                    screen.skipButton and screen.skipButton.x == C.ledger.x and screen.skipButton.y == C.ledger.y)
                t:truthy(("%s %dx%d: sino = botao Novas ofertas"):format(code, s[1], s[2]),
                    screen.refreshButton and screen.refreshButton.x == C.bell.x)
                -- desenhar nao lanca em nenhum tamanho
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
