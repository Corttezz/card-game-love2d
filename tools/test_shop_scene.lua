-- tools/test_shop_scene.lua
-- Trava de COMPORTAMENTO do Balcão do Mercador em perspectiva (Loja v3b,
-- src/ui/shop/ShopScene + ShelfItem + CardRewardScreen modo shop).
--
--   1. entrada: os objetos deslizam pra mesa e a tela espelha as cartas; o
--      pergaminho nasce com a primeira oferta SELECIONADA e o COMPRAR armado;
--   2. hover: o objeto levanta, o pergaminho troca de conteúdo; som de hover
--      UMA vez na borda, nunca durante o deslize da tela;
--   3. clique SELECIONA (não compra): pergaminho + brilho + COMPRAR · $N;
--   4. sem ouro: COMPRAR apagado e a compra pelo botão não passa, a placa
--      treme (deny), sem toast;
--   5. compra pelo COMPRAR: objeto some (VENDIDO), voa pro destino certo
--      (carta → deck na TopBar; relíquia → painel do jogador; pacote → abre a
--      tela do pacote, sem voo); o pergaminho passa pra próxima oferta;
--   6. sino: objetos saem deslizando e os novos entram; VENDIDO não sobrevive;
--   7. reducedMotion: nada se move, mas preço, VENDIDO e foco continuam;
--   8. teclado: alvos do NavCursor pra cada objeto, COMPRAR, CONTINUAR, sino.
--
--   love . test_one test_shop_scene

local TK = require("tools.testkit")
local M = {}

local CardRewardScreen = require("components.CardRewardScreen")
local EventManager     = require("engine.EventManager")
local FontManager      = require("src.ui.FontManager")
local I18n             = require("src.i18n.I18n")

local realW, realH = love.graphics.getWidth, love.graphics.getHeight
local realMouse = love.mouse.getPosition
local fakeW, fakeH = 1280, 720
local mouseX, mouseY = 5, 5

local function installFakes()
    love.graphics.getWidth = function() return fakeW end
    love.graphics.getHeight = function() return fakeH end
    love.mouse.getPosition = function() return mouseX, mouseY end
end
local function restoreFakes()
    love.graphics.getWidth, love.graphics.getHeight = realW, realH
    love.mouse.getPosition = realMouse
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

local function itemOf(screen, pred)
    for _, it in ipairs(screen.scene.items) do
        if pred(it) then return it end
    end
end

local function click(screen, it)
    local cx, cy = it:center()
    mouseX, mouseY = cx, cy
    pump(screen, 0.2)
    screen:mousepressed(mouseX, mouseY, 1)
    screen:mousereleased(mouseX, mouseY, 1)
    pump(screen, 0.1)
end

local function buy(screen)
    if screen.buyButton and screen.buyButton.onClick then screen.buyButton.onClick() end
end

local function openShop(t, gold)
    local game = TK.newRunGame("warrior")
    game.economySystem.currentGold = gold or 60
    local toasts = 0
    local realAdd = game.addMessage
    game.addMessage = function(g, ...) toasts = toasts + 1 return realAdd(g, ...) end
    local screen = CardRewardScreen:new(game.shopSystem)
    screen:show(game, function() end, function() end, "shop")
    pump(screen, 1.5)
    return screen, game, function() return toasts end
end

function M.run()
    TK.bootstrap()
    I18n.init()
    I18n.setLocale("pt_BR")
    local t = TK.new("loja v3b: balcao em perspectiva (selecao, COMPRAR, sino, reducedMotion)")
    installFakes()
    local prevReduced = _G.gameSettings and _G.gameSettings.reducedMotion
    _G.gameSettings = _G.gameSettings or {}
    _G.gameSettings.reducedMotion = false

    local okRun, err = pcall(function()
        -- ================= 1. entrada =================
        TK.seedRng(4242)
        local screen, game, toasts = openShop(t, 60)
        local scene = screen.scene
        t:truthy("a cena existe apos show()", scene ~= nil)
        t:eq("um objeto por oferta", #scene.items, #screen.shopOffers)
        local settled = 0
        for _, it in ipairs(scene.items) do if math.abs(it.slide.x) < 1 then settled = settled + 1 end end
        t:eq("todos os objetos deslizaram pra mesa", settled, #scene.items)
        local nCards = 0
        for _, it in ipairs(scene.items) do if it.kind == "card" then nCards = nCards + 1 end end
        t:eq("cartas espelhadas em cardInstances", #screen.cardInstances, nCards)
        for _, it in ipairs(scene.items) do
            t:truthy("objeto " .. it.slot .. " tem geometria", it.rect ~= nil)
        end
        t:truthy("pergaminho nasce com a primeira oferta selecionada",
            screen.selectedOffer ~= nil and screen.selectedOffer == screen.shopOffers[1])
        t:truthy("COMPRAR armado com o preco", screen.buyButton and screen.buyButton.text:find("%$") ~= nil)
        t:falsy("COMPRAR ligado com ouro", screen.buyButton.disabled)

        -- ================= 2. hover =================
        local card2 = itemOf(screen, function(it) return it.kind == "card" and it.index == 2 end)
        t:truthy("ha uma segunda carta", card2 ~= nil)
        local rec = {}
        local realAudio = _G.audioSystem
        _G.audioSystem = {
            sources = { hoverCard = true, cardSelect = true, hoverRelic = true },
            play = function(_, name, opts) rec[#rec + 1] = { name = name, opts = opts } end,
            playSound = function(_, name) rec[#rec + 1] = { name = name } end,
        }
        local cx, cy = card2:center()
        mouseX, mouseY = cx, cy
        pump(screen, 0.5)
        t:eq("cena marca a carta sob o mouse", scene.hovered, card2)
        t:eq("tela espelha hoveredOffer", screen.hoveredOffer, card2.offer)
        t:truthy("carta em hover LEVANTA (6..9 px)", card2:liftPx() >= 5.5 and card2:liftPx() <= 9.5)
        t:eq("pergaminho segue a SELECAO, nao o hover (leitura estavel)",
            screen.detailPayload.offer, screen.selectedOffer)

        local relic = itemOf(screen, function(it) return it.kind == "relic" end)
        t:truthy("ha uma reliquia na mesa", relic ~= nil)
        rec = {}
        -- v3c: hover = o MESMO sprite (fonte, espelho, cisalhamento), só levantado
        local L = scene.L
        local restPose = relic:pose()
        local restParams = relic:uprightParams(L, false, 0)
        cx, cy = relic:center()
        mouseX, mouseY = cx, cy
        pump(screen, 0.5)
        t:eq("cena marca a reliquia", scene.hovered, relic)
        local hovPose = relic:pose()
        local hovParams = relic:uprightParams(L, true, 1.3)
        t:eq("hover: mesma arte (fonte do sprite)", hovPose.src, restPose.src)
        t:eq("hover: mesmo espelho", hovPose.flip, restPose.flip)
        t:near("hover: mesmo cisalhamento (diagonal)", hovPose.slope, restPose.slope, 1e-9)
        t:truthy("arte antiga do voucher (nao objects/)", tostring(restPose.src):find("sprites/vouchers/", 1, true) ~= nil)
        t:near("hover: mesmo pe (x)", hovParams.fx, restParams.fx, 1e-6)
        t:near("hover: mesmo pe (y)", hovParams.fy, restParams.fy, 1e-6)
        t:near("hover: mesma escala", hovParams.s, restParams.s, 1e-9)
        t:truthy("hover: objeto levanta 4..6 px", relic:liftPx() >= 4 and relic:liftPx() <= 6.01)
        -- quadro da animação no hover tem o MESMO tamanho do PNG estático
        t:eq("hover: quadro animado do mesmo tamanho", hovParams.img:getWidth(), restParams.img:getWidth())
        local joker = itemOf(screen, function(it) return it.offer and it.offer.id == "joker_slot" end)
        if joker then t:truthy("bancada de coringa espelhada (segue a bancada)", joker:pose().flip) end

        -- nada flutua: todo pé de coluna encostado (e a sombra) DENTRO do tampo pintado
        local ShopPerspective = require("src.ui.shop.ShopPerspective")
        local ShopLayout = require("src.ui.shop.ShopLayout")
        for _, it in ipairs(scene.items) do
            if it.kind ~= "card" and it.rect then
                local o = it:uprightParams(L, false, 0)
                local pts = ShopPerspective.contactPoints(o)
                local out = 0
                for _, p in ipairs(pts) do
                    if not ShopLayout.pointInPoly(p[1], p[2], L.art.tableMask) then out = out + 1 end
                end
                t:truthy(("objeto %s encosta na mesa (%d colunas de contato)"):format(it.offer.id, #pts), #pts >= 3)
                t:eq(("objeto %s: contato dentro do tampo"):format(it.offer.id), out, 0)
            end
        end
        -- sombra de contato, nunca elipse
        local realEllipse = love.graphics.ellipse
        local ellipses = 0
        love.graphics.ellipse = function(...) ellipses = ellipses + 1 return realEllipse(...) end
        local okDraw = pcall(function() screen:draw() end)
        love.graphics.ellipse = realEllipse
        t:truthy("draw da loja sem erro", okDraw)
        t:eq("nenhuma sombra em elipse (objeto flutuando)", ellipses, 0)
        local hovers = 0
        for _, c in ipairs(rec) do if c.name == "hoverCard" or c.name == "hoverRelic" then hovers = hovers + 1 end end
        t:eq("hover-enter da reliquia toca UMA vez", hovers, 1)
        t:falsy("call site nao crava volume", rec[1] and rec[1].opts and rec[1].opts.volume ~= nil)
        rec = {}
        mouseX, mouseY = 5, 5
        pump(screen, 0.3)
        screen.slideOffsetY = -200
        cx, cy = relic:center()
        mouseX, mouseY = cx, cy - 200
        pump(screen, 0.3)
        local hovers2 = 0
        for _, c in ipairs(rec) do if c.name == "hoverCard" or c.name == "hoverRelic" then hovers2 = hovers2 + 1 end end
        t:eq("tela deslizando nao toca hover", hovers2, 0)
        screen.slideOffsetY = 0
        mouseX, mouseY = 5, 5
        pump(screen, 0.3)
        _G.audioSystem = realAudio

        -- ================= 3. clique seleciona =================
        local goldBefore = game.economySystem.currentGold
        click(screen, card2)
        t:eq("clique SELECIONA (nao compra): ouro intacto", game.economySystem.currentGold, goldBefore)
        t:falsy("clique nao compra", card2.offer.purchased)
        t:eq("oferta selecionada e a clicada", screen.selectedOffer, card2.offer)
        t:truthy("objeto selecionado brilha", card2.selected)
        t:eq("pergaminho mostra a selecionada", screen.detailPayload.offer, card2.offer)
        t:truthy("COMPRAR mostra o preco da selecionada",
            screen.buyButton.text:find(tostring(card2.offer.cost), 1, true) ~= nil)
        mouseX, mouseY = 5, 5
        pump(screen, 0.3)
        t:eq("selecao fica depois do mouse sair", screen.selectedOffer, card2.offer)

        -- ================= 4. sem ouro =================
        game.economySystem.currentGold = 0
        local before = toasts()
        pump(screen, 0.1)
        screen:_refreshBuyButton()
        t:truthy("sem ouro: COMPRAR apagado", screen.buyButton.disabled)
        screen:purchaseOffer(card2.offer, card2.offer.id)
        t:falsy("sem ouro: a compra NAO passa", card2.offer.purchased)
        t:truthy("sem ouro: a placa treme (deny)", card2.deny > 0)
        t:eq("sem ouro: nenhum toast", toasts() - before, 0)
        pump(screen, 0.6)

        -- ================= 5. compra pelo COMPRAR =================
        game.economySystem.currentGold = 60
        local added = 0
        local realAddCard = game.addCardToRun
        game.addCardToRun = function(g, ...) added = added + 1 return realAddCard(g, ...) end
        local cost = card2.offer.cost
        pump(screen, 0.1)
        buy(screen)
        game.addCardToRun = realAddCard
        t:truthy("compra: oferta marcada", card2.offer.purchased)
        t:truthy("compra: objeto VENDIDO", (scene.bySlot[card2.slot] or card2).sold)
        t:eq("compra: ouro debitado", game.economySystem.currentGold, 60 - cost)
        t:eq("compra: carta entrou na corrida (addCardToRun)", added, 1)
        t:eq("compra: a carta VOA (1 objeto no ar)", #scene.flies, 1)
        local fly = scene.flies[1]
        pump(screen, 0.6)
        t:truthy("compra: carta voou pro DECK na TopBar (y < 60)", fly.y < 60)
        t:eq("compra: voo terminou", #scene.flies, 0)
        t:truthy("compra: pergaminho passa pra outra oferta",
            screen.selectedOffer ~= nil and screen.selectedOffer ~= card2.offer and not screen.selectedOffer.purchased)
        local gold2 = game.economySystem.currentGold
        click(screen, card2)
        buy(screen)
        t:truthy("clique no VENDIDO nao compra de novo", game.economySystem.currentGold >= gold2 - 0
            and card2.offer.purchased)

        local realPicker = _G.openCardPicker
        _G.openCardPicker = function(_mode, onDone)
            game.runManager:addCardToDeck("warrior_strike")
            if onDone then onDone() end
        end
        game.economySystem.currentGold = 200
        local relicItem = itemOf(screen, function(it) return it.kind == "relic" and not it.sold end)
        if relicItem then
            click(screen, relicItem)
            buy(screen)
            t:truthy("reliquia: comprada", relicItem.offer.purchased)
            t:truthy("reliquia: VENDIDO", scene.bySlot[relicItem.slot].sold)
            if #scene.flies > 0 then
                local f = scene.flies[1]
                pump(screen, 0.6)
                t:truthy("reliquia: voa pro painel do jogador (canto inferior esquerdo)",
                    f.y > fakeH * 0.5 and f.x < fakeW * 0.3)
            end
        end
        _G.openCardPicker = realPicker

        local opened = 0
        local realOpen = _G.openBoosterPack
        _G.openBoosterPack = function(_pack, cb) opened = opened + 1 end
        local pack = itemOf(screen, function(it) return it.kind == "pack" end)
        t:truthy("ha um pacote na mesa", pack ~= nil)
        if pack then
            click(screen, pack)
            buy(screen)
            t:truthy("pacote: comprado", pack.offer.purchased)
            t:eq("pacote: abre a tela do pacote", opened, 1)
            t:eq("pacote: nao voa", #scene.flies, 0)
        end
        _G.openBoosterPack = realOpen
        pump(screen, 0.3)

        -- ================= 6. sino =================
        local rerollCost = game.shopSystem:getRefreshCost()
        game.economySystem.currentGold = 100
        screen.refreshButton.onClick()
        t:eq("sino: cobra o custo", game.economySystem.currentGold, 100 - rerollCost)
        t:truthy("sino: custo sobe", game.shopSystem:getRefreshCost() > rerollCost)
        t:truthy("sino: objetos antigos saindo (outgoing)", scene.outgoing ~= nil)
        local anySold = false
        for _, it in ipairs(scene.items) do if it.sold then anySold = true end end
        t:falsy("sino: vitrine nova sem VENDIDO", anySold)
        t:eq("sino: um objeto por oferta nova", #scene.items, #screen.shopOffers)
        t:truthy("sino: os novos esperam fora da mesa (a direita)", scene.items[1].slide.x > 10)
        pump(screen, 0.2)
        t:truthy("sino: antigos deslizando pra esquerda", scene.outgoing and scene.outgoing[1].slide.x < -10)
        pump(screen, 1.6)
        t:falsy("sino: objetos antigos sumiram", scene.outgoing ~= nil)
        local settled2 = 0
        for _, it in ipairs(scene.items) do if math.abs(it.slide.x) < 1 then settled2 = settled2 + 1 end end
        t:eq("sino: objetos novos chegaram um a um", settled2, #scene.items)
        t:truthy("sino: a primeira oferta nova ja esta selecionada",
            screen.selectedOffer ~= nil and screen.selectedOffer == screen.shopOffers[1])
        t:truthy("sino: o rotulo do sino mostra o custo novo",
            screen.refreshButton.text:find(tostring(game.shopSystem:getRefreshCost()), 1, true) ~= nil)
        game.economySystem.currentGold = 0
        local tb = toasts()
        screen.refreshButton.onClick()
        t:eq("sino sem ouro: nenhum toast", toasts() - tb, 0)
        t:falsy("sino sem ouro: nada desliza", scene.outgoing ~= nil)

        -- ================= 8. teclado: alvos =================
        game.economySystem.currentGold = 100
        pump(screen, 0.1)
        local NavCursor = require("src.ui.NavCursor")
        NavCursor.beginFrame()
        screen:draw()
        NavCursor.beginFrame()
        local targets = NavCursor._targets()
        local function has(pred)
            for _, tg in ipairs(targets) do if pred(tg) then return true end end
            return false
        end
        t:truthy("teclado: a carta e alvo (chave = instancia com shopOffer)",
            has(function(tg) return type(tg.key) == "table" and tg.key.shopOffer ~= nil end))
        t:truthy("teclado: reliquia/pacote sao alvo", has(function(tg) return type(tg.key) == "string" and tg.key:find("^offer:") ~= nil end))
        t:truthy("teclado: CONTINUAR e alvo", has(function(tg) return tg.key == screen.skipButton end))
        t:truthy("teclado: sino e alvo", has(function(tg) return tg.key == screen.refreshButton end))
        t:truthy("teclado: COMPRAR e alvo", has(function(tg) return tg.key == screen.buyButton end))
        t:truthy("teclado: '?' das regras e alvo", has(function(tg) return tg.key == "rules" end))
        screen:hide()

        -- ================= 7. reducedMotion =================
        _G.gameSettings.reducedMotion = true
        TK.seedRng(4243)
        local screen2, game2 = openShop(t, 60)
        local sc2 = screen2.scene
        local settled3 = 0
        for _, it in ipairs(sc2.items) do if math.abs(it.slide.x) < 1 then settled3 = settled3 + 1 end end
        t:eq("reducedMotion: objetos ja na mesa", settled3, #sc2.items)
        local c1 = itemOf(screen2, function(it) return it.kind == "card" and it.index == 2 end)
        cx, cy = c1:center()
        mouseX, mouseY = cx, cy
        pump(screen2, 0.3)
        t:eq("reducedMotion: hover marca o objeto (informacao)", sc2.hovered, c1)
        t:eq("reducedMotion: hover sem levantar (movimento)", c1:liftPx(), 0)
        click(screen2, c1)
        t:eq("reducedMotion: clique seleciona", screen2.selectedOffer, c1.offer)
        buy(screen2)
        t:truthy("reducedMotion: compra funciona", c1.offer.purchased)
        t:truthy("reducedMotion: VENDIDO fica", sc2.bySlot[c1.slot].sold)
        t:eq("reducedMotion: nada voa", #sc2.flies, 0)
        t:noerror("reducedMotion: draw", function() screen2:draw() end)
        game2.economySystem.currentGold = 100
        screen2.refreshButton.onClick()
        t:falsy("reducedMotion: sino troca na hora (sem deslize)", sc2.outgoing ~= nil)
        t:eq("reducedMotion: objetos parados", sc2.items[1].slide.x, 0)
        screen2:hide()
    end)

    _G.gameSettings.reducedMotion = prevReduced or false
    restoreFakes()
    FontManager.clearCache()
    t:truthy("suite rodou sem erro (" .. tostring(err) .. ")", okRun)
    return t:done()
end

return M
