-- tools/test_shop_scene.lua
-- Trava de COMPORTAMENTO do Balcão do Mercador (Loja v3, src/ui/shop/ShopScene).
--
--   1. entrada: os objetos pousam (enter 0 → 1) e a tela espelha as cartas;
--   2. hover: o objeto levanta, a etiqueta balança, o pergaminho troca de
--      conteúdo; som de hover UMA vez na borda, nunca durante o deslize;
--   3. sem ouro: clique NÃO compra, a etiqueta treme (deny), sem toast;
--   4. compra: objeto some (VENDIDO), etiqueta arrancada, o objeto VOA pro
--      destino certo (carta → deck na TopBar; relíquia → painel do jogador;
--      pacote → abre a tela do pacote, sem voo);
--   5. sino: as prateleiras deslizam pra fora e voltam repostas; o estado
--      vendido NÃO sobrevive (ofertas novas), o custo sobe;
--   6. reducedMotion: nada se move, mas preço, VENDIDO e foco continuam;
--   7. teclado: alvos do NavCursor existem pra cada objeto e pro balcão.
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
    mouseX, mouseY = cx, cy + it.rect.h * 0.3
    pump(screen, 0.2)
    screen:mousepressed(mouseX, mouseY, 1)
    screen:mousereleased(mouseX, mouseY, 1)
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
    local t = TK.new("loja v3: balcao do mercador (hover, compra, sino, reducedMotion)")
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
        local landed = 0
        for _, it in ipairs(scene.items) do if it:entered() > 0.99 then landed = landed + 1 end end
        t:eq("todos os objetos pousaram na prateleira (enter = 1)", landed, #scene.items)
        local nCards = 0
        for _, it in ipairs(scene.items) do if it.kind == "card" then nCards = nCards + 1 end end
        t:eq("cartas espelhadas em cardInstances", #screen.cardInstances, nCards)
        for _, it in ipairs(scene.items) do
            t:truthy("objeto " .. it.slot .. " tem geometria", it.rect ~= nil)
        end
        t:truthy("pergaminho pre-foca a primeira carta",
            screen.detailPayload and screen.detailPayload.offer ~= nil)

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
        t:truthy("carta em hover LEVANTA (4..6 px)", card2:liftPx() >= 3.5 and card2:liftPx() <= 7)
        t:eq("pergaminho mostra a carta em hover", screen.detailPayload.offer, card2.offer)
        t:truthy("a luz da lanterna olha pro objeto (alvo em degraus)",
            scene.light.target ~= 0 and scene.light.target % require("src.ui.shop.ShopLayout").LIGHT_STEP == 0)

        -- reliquia: som UMA vez na borda de entrada, nunca re-dispara parado
        local relic = itemOf(screen, function(it) return it.kind == "relic" end)
        t:truthy("ha uma reliquia na prateleira", relic ~= nil)
        rec = {}
        cx, cy = relic:center()
        mouseX, mouseY = cx, cy
        pump(screen, 0.5)
        t:eq("cena marca a reliquia", scene.hovered, relic)
        local hovers = 0
        for _, c in ipairs(rec) do if c.name == "hoverCard" or c.name == "hoverRelic" then hovers = hovers + 1 end end
        t:eq("hover-enter da reliquia toca UMA vez", hovers, 1)
        t:falsy("call site nao crava volume", rec[1] and rec[1].opts and rec[1].opts.volume ~= nil)
        t:truthy("etiqueta balancou com o hover", math.abs(relic.tag.angle) > 0.001 or math.abs(relic.tag.vel) > 0.01)
        pump(screen, 0.8)
        t:truthy("pendulo amortece em menos de 1 s", math.abs(relic.tag.angle) < 0.05)
        -- durante o deslize da tela NAO ha som de hover
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

        -- ================= 3. sem ouro =================
        game.economySystem.currentGold = 0
        local before = toasts()
        click(screen, card2)
        t:falsy("sem ouro: a carta NAO e comprada", card2.offer.purchased)
        t:truthy("sem ouro: a etiqueta treme (deny)", card2.tag.deny > 0)
        t:eq("sem ouro: nenhum toast", toasts() - before, 0)
        t:eq("sem ouro: ouro intacto", game.economySystem.currentGold, 0)
        mouseX, mouseY = 5, 5
        pump(screen, 0.6)

        -- ================= 4. compra =================
        game.economySystem.currentGold = 60
        local added = 0
        local realAddCard = game.addCardToRun
        game.addCardToRun = function(g, ...) added = added + 1 return realAddCard(g, ...) end
        local cost = card2.offer.cost
        click(screen, card2)
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
        local soldItem = scene.bySlot[card2.slot]
        t:truthy("compra: etiqueta arrancada (caiu)", soldItem.tag.torn ~= nil or soldItem.sold)
        t:truthy("compra: pergaminho nao fica preso na carta vendida",
            screen.detailPayload == nil or screen.detailPayload.offer ~= card2.offer)
        -- segundo clique no lugar vazio nao compra de novo
        local gold2 = game.economySystem.currentGold
        click(screen, card2)
        t:eq("clique no VENDIDO nao compra de novo", game.economySystem.currentGold, gold2)

        -- reliquia (elixir/cristal: aplica direto; servicos abrem picker)
        local realPicker = _G.openCardPicker
        _G.openCardPicker = function(_mode, onDone)
            -- escolhe "alguma coisa": muda a assinatura do deck pra nao estornar
            game.runManager:addCardToDeck("warrior_strike")
            if onDone then onDone() end
        end
        game.economySystem.currentGold = 200
        local relicItem = itemOf(screen, function(it) return it.kind == "relic" and not it.sold end)
        if relicItem then
            click(screen, relicItem)
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

        -- pacote: abre a tela do pacote, nao voa
        local opened = 0
        local realOpen = _G.openBoosterPack
        _G.openBoosterPack = function(_pack, cb) opened = opened + 1 end
        local pack = itemOf(screen, function(it) return it.kind == "pack" end)
        t:truthy("ha um pacote no gancho", pack ~= nil)
        if pack then
            click(screen, pack)
            t:truthy("pacote: comprado", pack.offer.purchased)
            t:eq("pacote: abre a tela do pacote", opened, 1)
            t:eq("pacote: nao voa", #scene.flies, 0)
        end
        _G.openBoosterPack = realOpen
        pump(screen, 0.3)

        -- ================= 5. sino =================
        local idsBefore = {}
        for _, o in ipairs(screen.shopOffers) do idsBefore[#idsBefore + 1] = o.id end
        local rerollCost = game.shopSystem:getRefreshCost()
        game.economySystem.currentGold = 100
        screen.refreshButton.onClick()
        t:eq("sino: cobra o custo", game.economySystem.currentGold, 100 - rerollCost)
        t:truthy("sino: custo sobe", game.shopSystem:getRefreshCost() > rerollCost)
        t:truthy("sino: prateleira saindo (objetos antigos em outgoing)", scene.outgoing ~= nil)
        local anySold = false
        for _, it in ipairs(scene.items) do if it.sold then anySold = true end end
        t:falsy("sino: vitrine nova sem VENDIDO", anySold)
        t:eq("sino: um objeto por oferta nova", #scene.items, #screen.shopOffers)
        pump(screen, 0.2)
        t:truthy("sino: estante deslizou pra esquerda", scene.shelfSlide < -10)
        pump(screen, 1.6)
        t:falsy("sino: objetos antigos sumiram", scene.outgoing ~= nil)
        t:truthy("sino: estante voltou ao lugar", math.abs(scene.shelfSlide) < 1)
        local landed2 = 0
        for _, it in ipairs(scene.items) do if it:entered() > 0.99 then landed2 = landed2 + 1 end end
        t:eq("sino: objetos novos pousaram um a um", landed2, #scene.items)
        t:truthy("sino: o rotulo do sino mostra o custo novo",
            screen.refreshButton.text:find(tostring(game.shopSystem:getRefreshCost()), 1, true) ~= nil)
        -- sem ouro o sino nao toca (nem toast)
        game.economySystem.currentGold = 0
        local tb = toasts()
        screen.refreshButton.onClick()
        t:eq("sino sem ouro: nenhum toast", toasts() - tb, 0)
        t:falsy("sino sem ouro: nada desliza", scene.outgoing ~= nil)

        -- ================= 7. teclado: alvos =================
        local NavCursor = require("src.ui.NavCursor")
        NavCursor.beginFrame()
        screen:draw()
        NavCursor.beginFrame()
        local targets = NavCursor._targets()
        local function has(pred)
            for _, tg in ipairs(targets) do if pred(tg) then return true end end
            return false
        end
        t:truthy("teclado: a carta e alvo (Card:draw)", has(function(tg) return type(tg.key) == "table" and tg.key.shopOffer ~= nil end))
        t:truthy("teclado: reliquia/pacote sao alvo", has(function(tg) return type(tg.key) == "string" and tg.key:find("^offer:") ~= nil end))
        t:truthy("teclado: livro-razao e alvo", has(function(tg) return tg.key == screen.skipButton end))
        t:truthy("teclado: sino e alvo", has(function(tg) return tg.key == screen.refreshButton end))
        t:truthy("teclado: '?' das regras e alvo", has(function(tg) return tg.key == "rules" end))
        screen:hide()

        -- ================= 6. reducedMotion =================
        _G.gameSettings.reducedMotion = true
        TK.seedRng(4243)
        local screen2, game2 = openShop(t, 60)
        local sc2 = screen2.scene
        local landed3 = 0
        for _, it in ipairs(sc2.items) do if it:entered() > 0.99 then landed3 = landed3 + 1 end end
        t:eq("reducedMotion: objetos ja na prateleira", landed3, #sc2.items)
        local c1 = itemOf(screen2, function(it) return it.kind == "card" end)
        cx, cy = c1:center()
        mouseX, mouseY = cx, cy
        pump(screen2, 0.3)
        t:eq("reducedMotion: hover marca o objeto (informacao)", sc2.hovered, c1)
        t:eq("reducedMotion: hover sem levantar (movimento)", c1:liftPx(), 0)
        t:eq("reducedMotion: etiqueta parada", c1.tag.angle, 0)
        t:eq("reducedMotion: pergaminho segue o hover", screen2.detailPayload.offer, c1.offer)
        click(screen2, c1)
        t:truthy("reducedMotion: compra funciona", c1.offer.purchased)
        t:truthy("reducedMotion: VENDIDO fica", sc2.bySlot[c1.slot].sold)
        t:eq("reducedMotion: nada voa", #sc2.flies, 0)
        t:falsy("reducedMotion: etiqueta nao cai", sc2.bySlot[c1.slot].tag.torn ~= nil)
        t:noerror("reducedMotion: draw", function() screen2:draw() end)
        screen2.refreshButton.onClick()
        t:falsy("reducedMotion: sino troca na hora (sem deslize)", sc2.outgoing ~= nil)
        t:eq("reducedMotion: estante parada", sc2.shelfSlide, 0)
        screen2:hide()
    end)

    _G.gameSettings.reducedMotion = prevReduced or false
    restoreFakes()
    FontManager.clearCache()
    t:truthy("suite rodou sem erro (" .. tostring(err) .. ")", okRun)
    return t:done()
end

return M
