-- tools/test_shop_sale.lua
-- Trava da OFERTA DO DIA (Loja v3 F4, Out/2026 — ShopSystem:applyDailySale,
-- Config.Offers.DAILY_SALE):
--   1. flag DESLIGADA (setada à mão: o default é LIGADA desde 13/Out/2026,
--      decisão de UX do dono após a bateria shop-sale): nenhuma oferta traz
--      saleDiscount e os streams do Rng não andam;
--   2. flag LIGADA (default): UMA e só uma oferta da loja com saleDiscount = pct,
--      preço = floor(preço cheio × (1 - pct)), basePrice guardado;
--   3. a recompensa pós-batalha (grátis) NUNCA ganha etiqueta;
--   4. o reroll sorteia de novo (continua 1 e só 1; muda de objeto ao longo
--      das seeds); mesma seed → mesma oferta e mesmo preço;
--   5. a etiqueta viaja no save: exportState/importState e o checkpoint
--      real (RunManager save → load) devolvem a mesma oferta com o mesmo
--      preço e a mesma marca;
--   6. o asset da etiqueta (price_tag_sale.png) existe;
--   7. o knob BALANCE_SHOP_SALE do balance_sim liga a flag.
--   love . test_one test_shop_sale

local TK = require("tools.testkit")

local M = {}

local function openShop(game, mode)
    local ShopSystem = require("src.systems.ShopSystem")
    local shop = ShopSystem:new()
    shop:setContext(ShopSystem.runContext(game, mode or "shop"))
    shop:setMode(mode or "shop")
    shop:generateOffers()
    return shop
end

local function sales(offers)
    local out = {}
    for i, o in ipairs(offers) do
        if o.saleDiscount then out[#out + 1] = { i = i, o = o } end
    end
    return out
end

function M.run()
    local t = TK.new("Oferta do dia (loja)")
    TK.bootstrap()
    local Config = require("src.core.Config")
    local Offers = Config.Offers
    local saved = { on = Offers.DAILY_SALE, pct = Offers.DAILY_SALE_PCT }
    local g = TK.newRunGame("warrior")
    local Rng = require("src.systems.Rng")

    -- ===== 1) desligada =====
    Offers.DAILY_SALE = false
    TK.seedRng(31337)
    local shop = openShop(g, "shop")
    t:truthy("loja gera ofertas", #shop:getCurrentOffers() >= 5)
    t:eq("desligada: 0 ofertas com desconto", #sales(shop:getCurrentOffers()), 0)
    local stateOff = Rng.get():getState().states.shop
    TK.seedRng(31337)
    local shopOff2 = openShop(g, "shop")
    t:eq("desligada: o stream shop não anda a mais (mesma seed, mesmo estado)",
        Rng.get():getState().states.shop, stateOff)
    t:eq("desligada: mesma vitrine por seed", shopOff2:getCurrentOffers()[1].id, shop:getCurrentOffers()[1].id)

    -- ===== 2) ligada =====
    Offers.DAILY_SALE = true
    Offers.DAILY_SALE_PCT = 0.25
    TK.seedRng(31337)
    shop = openShop(g, "shop")
    local list = sales(shop:getCurrentOffers())
    t:eq("ligada: 1 e só 1 oferta com desconto", #list, 1)
    local sale = list[1] and list[1].o
    if sale then
        t:eq("desconto = 0,25", sale.saleDiscount, 0.25)
        t:truthy("preço cheio guardado em basePrice", (sale.basePrice or 0) > 0)
        t:eq("preço = floor(cheio × 0,75)", sale.cost, math.floor(sale.basePrice * 0.75))
        t:truthy("preço é inteiro", sale.cost == math.floor(sale.cost))
        t:truthy("preço com desconto < preço cheio", sale.cost < sale.basePrice)
    end
    -- toda oferta sem etiqueta ficou com o preço de antes (comparando com a
    -- vitrine gerada com a flag desligada na mesma seed, até a etiqueta)
    local same = true
    for i, o in ipairs(shop:getCurrentOffers()) do
        local ref = shopOff2:getCurrentOffers()[i]
        if ref and o.id == ref.id and not o.saleDiscount and o.cost ~= ref.cost then same = false end
    end
    t:truthy("quem não é a oferta do dia custa o mesmo de sempre", same)

    -- ===== 3) recompensa nunca =====
    TK.seedRng(31337)
    local rew = openShop(g, "rewards")
    t:eq("recompensa pós-batalha: 0 etiquetas", #sales(rew:getCurrentOffers()), 0)

    -- ===== 4) reroll e seed =====
    TK.seedRng(777)
    shop = openShop(g, "shop")
    local firstId = sales(shop:getCurrentOffers())[1].o.id
    local firstCost = sales(shop:getCurrentOffers())[1].o.cost
    local changed, okCount = false, true
    for _ = 1, 6 do
        shop:refreshOffers()
        local l = sales(shop:getCurrentOffers())
        if #l ~= 1 then okCount = false end
        if l[1] and l[1].o.id ~= firstId then changed = true end
    end
    t:truthy("reroll: continua 1 e só 1 com etiqueta", okCount)
    t:truthy("reroll: a etiqueta muda de objeto em 6 rerolls", changed)
    TK.seedRng(777)
    local again = openShop(g, "shop")
    local a1 = sales(again:getCurrentOffers())[1]
    t:truthy("mesma seed → mesma oferta do dia e mesmo preço",
        a1 and a1.o.id == firstId and a1.o.cost == firstCost)
    local differs = false
    for seed = 1, 12 do
        TK.seedRng(1000 + seed)
        local s = openShop(g, "shop")
        local l = sales(s:getCurrentOffers())
        if #l ~= 1 then okCount = false end
        if l[1] and l[1].i ~= 1 then differs = true end
    end
    t:truthy("12 seeds: sempre exatamente 1 etiqueta", okCount)
    t:truthy("12 seeds: a etiqueta não cai sempre na 1ª vaga", differs)

    -- ===== 5) save =====
    TK.seedRng(4242)
    shop = openShop(g, "shop")
    local before = sales(shop:getCurrentOffers())[1]
    local st = shop:exportState()
    local ShopSystem = require("src.systems.ShopSystem")
    local back = ShopSystem:new()
    back:importState(st)
    local after = sales(back:getCurrentOffers())[1]
    t:truthy("exportState/importState preserva etiqueta, preço e basePrice",
        after and before and after.i == before.i and after.o.id == before.o.id
        and after.o.cost == before.o.cost and after.o.basePrice == before.o.basePrice
        and after.o.saleDiscount == before.o.saleDiscount)
    -- checkpoint real: a vitrine mora em currentRun.shopState (CardRewardScreen)
    local run = g.runManager.currentRun
    st.key = "shop|1|1|0"
    run.shopState = st
    g:checkpointRun()
    local RunManager = require("src.systems.RunManager")
    local rm2 = RunManager:new()
    t:truthy("save carregado", rm2:loadRun())
    local loaded = rm2.currentRun and rm2.currentRun.shopState
    local ls = loaded and sales(loaded.offers or {})[1]
    t:truthy("depois de carregar: a mesma oferta do dia, mesmo preço",
        ls and before and ls.o.id == before.o.id and ls.o.cost == before.o.cost
        and ls.o.basePrice == before.o.basePrice and ls.o.saleDiscount == 0.25)
    t:eq("depois de carregar: ainda 1 e só 1", loaded and #sales(loaded.offers or {}) or -1, 1)
    local restored = ShopSystem:new()
    restored:importState(loaded)
    t:eq("Continuar não sorteia outra etiqueta (importState não gera)", #sales(restored:getCurrentOffers()), 1)
    run.shopState = nil
    g.runManager:deleteSave()

    -- ===== 6) asset =====
    t:truthy("asset price_tag_sale.png existe", love.filesystem.getInfo("assets/sprites/shop/price_tag_sale.png") ~= nil)

    -- ===== 7) knob e default =====
    Offers.DAILY_SALE = false
    local src = love.filesystem.read("tools/balance_sim.lua") or ""
    t:truthy("balance_sim lê BALANCE_SHOP_SALE", src:find('BALANCE_SHOP_SALE', 1, true) ~= nil)
    t:truthy("balance_sim liga Config.Offers.DAILY_SALE", src:find('CO.DAILY_SALE = true', 1, true) ~= nil)
    t:truthy("balance_sim desliga com BALANCE_SHOP_SALE=0", src:find('CO.DAILY_SALE = false', 1, true) ~= nil)
    t:eq("default do jogo: oferta do dia LIGADA (decisão de UX, 13/Out/2026)", saved.on, true)

    Offers.DAILY_SALE, Offers.DAILY_SALE_PCT = saved.on, saved.pct
    return t:done()
end

return M
