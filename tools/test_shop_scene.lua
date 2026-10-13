-- tools/test_shop_scene.lua
-- Trava de COMPORTAMENTO do Balcão do Mercador em perspectiva (Loja v3b,
-- src/ui/shop/ShopScene + ShelfItem + CardRewardScreen modo shop).
--
--   1. entrada: os objetos deslizam pra mesa e a tela espelha as cartas; o
--      pergaminho nasce com a primeira oferta SELECIONADA e o COMPRAR armado;
--   2. hover (v5): NADA levanta (carta nem objeto): o ponto de apoio fica
--      parado; a carta gira em torno da base (tilt com a base presa); som de
--      hover UMA vez na borda, nunca durante o deslize da tela;
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
local ShelfItemM       = require("src.ui.shop.ShelfItem")

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
            play = function(_, name, opts) rec[#rec + 1] = { name = name, opts = opts, tb = (name == "cardSelect" or name == "hoverCard") and debug.traceback("", 2) or nil } end,
            playSound = function(_, name) rec[#rec + 1] = { name = name } end,
        }
        local cx, cy = card2:center()
        mouseX, mouseY = cx, cy
        pump(screen, 0.5)
        t:eq("cena marca a carta sob o mouse", scene.hovered, card2)
        t:eq("tela espelha hoveredOffer", screen.hoveredOffer, card2.offer)
        t:near("v5: carta em hover NAO sai do cavalete (sem levitar)", card2:liftPx(), 0, 1e-9)
        do
            -- Loja "reta": hover sem torção (ângulo da base igual ao repouso) e
            -- sem salto: passo por quadro limitado, ida e volta pelo mesmo caminho
            local ShelfItem = require("src.ui.shop.ShelfItem")
            local ShopPerspective = require("src.ui.shop.ShopPerspective")
            local probe = ShelfItem.new("card", card2.offer, 99)
            probe:setGeometry(card2.geom)
            local function baseDeg()
                local _, _, _, _, x2, y2, x3, y3 = probe:cardCorners()
                return ShopPerspective.angleOf(x3, y3, x2, y2)
            end
            local rest = baseDeg()
            local ins, outs, maxStep, maxTwist = {}, {}, 0, 0
            local prev = probe:liftPx()
            for f = 1, 20 do
                probe:update(ShelfItem.HOVER_TIME / 12, true)
                ins[f] = probe:liftPx()
                maxStep = math.max(maxStep, math.abs(ins[f] - prev)); prev = ins[f]
                maxTwist = math.max(maxTwist, math.abs(baseDeg() - rest))
            end
            for f = 1, 20 do
                probe:update(ShelfItem.HOVER_TIME / 12, false)
                outs[f] = probe:liftPx()
                maxStep = math.max(maxStep, math.abs(outs[f] - prev)); prev = outs[f]
                maxTwist = math.max(maxTwist, math.abs(baseDeg() - rest))
            end
            -- v5: o hover não move a carta (nenhum quadro, nenhum px)
            t:truthy(("hover: apoio parado em todos os quadros (maior passo %.3f px)"):format(maxStep), maxStep <= 1e-9)
            t:truthy(("hover sem torcao (%.3f graus)"):format(maxTwist), maxTwist <= 0.01)
            -- a curva do destaque continua simétrica (entra e sai pelo mesmo caminho)
            local hv = {}
            local p2 = ShelfItem.new("card", card2.offer, 97)
            p2:setGeometry(card2.geom)
            for f = 1, 12 do p2:update(ShelfItem.HOVER_TIME / 12, true); hv[f] = p2.hover end
            local sym = 0
            for f = 1, 11 do
                p2:update(ShelfItem.HOVER_TIME / 12, false)
                sym = math.max(sym, math.abs(p2.hover - hv[12 - f]))
            end
            t:truthy("hover: destaque entra suave (1o quadro < 5%)", hv[1] < 0.05)
            t:truthy(("hover: destaque sai pelo mesmo caminho (%.4f)"):format(sym), sym <= 1e-6)
            -- PLAQUINHA DE PREÇO: um latão só; comum sem gema; valor legível
            -- (contraste >= 4,5) com e sem ouro
            t:falsy("comum sem gema", ShelfItem.showsGem("common"))
            for _, rar in ipairs({ "uncommon", "rare", "legendary" }) do
                t:truthy(rar .. " com gema de raridade", ShelfItem.showsGem(rar))
            end
            for _, af in ipairs({ true, false }) do
                local cr = ShelfItem.contrast(ShelfItem.priceInk(af, false), ShelfItem.plaqueFace(af))
                t:truthy(("preco %s: contraste %.2f >= 4,5 no latao"):format(af and "normal" or "sem ouro", cr), cr >= 4.5)
            end
            -- a plaquinha final cabe no que o layout reservou e mostra o preço exato
            local Q = ShelfItem.plaqueArt(card2.geom.plaque, card2:priceText(), card2.offer.rarity, scene.L.cover)
            t:eq("plaquinha mostra o preco exato da oferta", Q.text, "$" .. tostring(card2.offer.cost))
            t:truthy("plaquinha final dentro da reservada",
                Q.x0 >= card2.geom.plaque.x0 and Q.x0 + Q.w <= card2.geom.plaque.x0 + card2.geom.plaque.w)
            -- Loja v4: TILT 3D do hover por cima da pose (a conta da mão,
            -- Card.hoverTilt). Mouse levado pro espaço da carta pela homografia
            -- de repouso: canto sup. direito -> (+1, -1); centro -> 0; sai -> 0.
            local Card = require("src.cards.base.Card")
            local ht = Card.hoverTilt(1, 0)
            t:truthy("Card.hoverTilt: canto sup. direito = (+1, -1) no shader", ht.uvX == 1 and ht.uvY == -1)
            t:near("Card.hoverTilt: centro = sem tilt", Card.hoverTilt(0.5, 0.5).uvX, 0, 1e-9)
            local tp = ShelfItem.new("card", card2.offer, 98)
            tp:setGeometry(card2.geom)
            local r0, r1, r2 = ShopPerspective.homography(require("src.ui.shop.ShopLayout").cardQuad(card2.geom, 0, 0))
            local function hoverAt(u, v, secs)
                local mx, my = ShopPerspective.mapH(r0, r1, r2, u, v)
                for _ = 1, math.floor(secs * 60) do tp:update(1 / 60, true, mx, my) end
            end
            local _, _, _, _, bx2, by2, bx3, by3 = tp:cardCorners()
            local restBase = ShopPerspective.angleOf(bx3, by3, bx2, by2)
            hoverAt(0.92, 0.08, 1.0)
            t:truthy(("tilt: mouse no canto sup. direito inclina pra la (%.2f, %.2f)"):format(tp.tilt.x, tp.tilt.y),
                tp.tilt.x > 0.8 and tp.tilt.y < -0.8)
            local _, _, _, _, hx2, hy2, hx3, hy3 = tp:cardCorners()
            t:near("tilt: a pose diagonal continua (base no mesmo angulo)",
                ShopPerspective.angleOf(hx3, hy3, hx2, hy2), restBase, 0.01)
            hoverAt(0.08, 0.92, 1.0)
            t:truthy(("tilt: canto inf. esquerdo (%.2f, %.2f)"):format(tp.tilt.x, tp.tilt.y),
                tp.tilt.x < -0.8 and tp.tilt.y > 0.8)
            -- amortecido: um quadro depois de trocar de canto ainda não chegou
            hoverAt(0.92, 0.92, 1 / 60)
            t:truthy(("tilt amortecido (1 quadro: %.2f)"):format(tp.tilt.x), tp.tilt.x < 0)
            hoverAt(0.5, 0.5, 1.0)
            t:truthy(("tilt: centro = carta reta (%.3f, %.3f)"):format(tp.tilt.x, tp.tilt.y),
                math.abs(tp.tilt.x) < 0.05 and math.abs(tp.tilt.y) < 0.05)
            -- v5: BASE PRESA. O press do shader (espelho ShelfItem.warpUV) não
            -- mexe nenhum ponto da base em modo quad; o topo, sim.
            local worstBase, topMove = 0, 0
            for _, m in ipairs({ { 1, -1 }, { -1, 1 }, { 1, 1 }, { -1, -1 }, { 0, 1 } }) do
                for _, u in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
                    local wu, wv = ShelfItem.warpUV(u, 1, m[1], m[2], 1, 0.7, true)
                    worstBase = math.max(worstBase, math.abs(wu - u), math.abs(wv - 1))
                    local tu, tv = ShelfItem.warpUV(u, 0, m[1], m[2], 1, 0.7, true)
                    topMove = math.max(topMove, math.abs(tu - u), math.abs(tv))
                end
            end
            t:truthy(("tilt: base presa no trilho (desvio %.6f)"):format(worstBase), worstBase <= 1e-9)
            t:truthy(("tilt: o topo responde ao mouse (%.4f)"):format(topMove), topMove > 0.01)
            local wu0 = select(2, ShelfItem.warpUV(0.5, 1, 0, 1, 1, 0, false))
            t:truthy("tilt: fora do modo quad (mao/recompensa) nada muda", math.abs(wu0 - 1) > 1e-4)
            t:near("tilt: sem parallax (a carta nao anda com o mouse)", tp.tilt.ox, 0, 1e-9)
            hoverAt(0.92, 0.08, 1.0)
            for _ = 1, 60 do tp:update(1 / 60, false) end
            t:truthy(("tilt: ao sair volta suave a pose (%.3f, %.3f)"):format(tp.tilt.x, tp.tilt.y),
                math.abs(tp.tilt.x) < 0.01 and math.abs(tp.tilt.y) < 0.01 and math.abs(tp.tilt.ox) < 0.05)
        end
        t:eq("pergaminho segue a SELECAO, nao o hover (leitura estavel)",
            screen.detailPayload.offer, screen.selectedOffer)

        local relic = itemOf(screen, function(it) return it.kind == "relic" and not it:floats() end)
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
        t:near("v5: hover do objeto sem levantar (apoio na mesa)", relic:liftPx(), 0, 1e-9)

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
        local names = {}
        for _, c in ipairs(rec) do names[#names + 1] = tostring(c.name); if c.tb and os.getenv("SHOP_TB") then print(c.name, c.tb) end end
        t:eq("hover-enter da reliquia toca UMA vez [" .. table.concat(names, ",") .. "]", hovers, 1)
        t:falsy("call site nao crava volume", rec[1] and rec[1].opts and rec[1].opts.volume ~= nil)
        -- v5 r2: o pacote FLUTUA no hover (dono); a etiqueta balança
        local packIt = itemOf(screen, function(it) return it.kind == "pack" end)
        if packIt then
            mouseX, mouseY = packIt:center()
            pump(screen, 0.5)
            t:truthy(("pacote flutua no hover (%.1f px)"):format(packIt:liftPx()), packIt:liftPx() >= 4)
            t:truthy("etiqueta do pacote balancou no hover", math.abs(packIt.tag.angle) > 0 or math.abs(packIt.tag.vel) > 0)
            mouseX, mouseY = 5, 5
            pump(screen, 1.2)
            t:near("pacote volta a mesa", packIt:liftPx(), 0, 1e-6)
        end
        -- som de hover por objeto: poção/cristal/pacote têm código próprio
        local probeP = require("src.ui.shop.ShelfItem").new("relic", { id = "health_upgrade", cost = 1 }, 90)
        t:eq("hover da pocao toca o som dela", probeP:hoverSfx()[1], "shopPotionBubble")
        t:truthy("pocao flutua", probeP:floats())
        t:eq("compra da pocao toca o som dela", probeP:buySfx()[1], "shopPotionDrink")
        -- pergaminho enrola/desenrola ao trocar a oferta mostrada
        local before = screen.selectedOffer
        local other = itemOf(screen, function(it) return it.kind == "card" and it.offer ~= before end)
        screen:setSelectedOffer(other.offer)
        pump(screen, 2 / 60)
        t:truthy(("pergaminho enrola ao trocar (%.2f)"):format(scene.scrollOpen), scene.scrollOpen < 0.5)
        pump(screen, 0.5)
        t:near("pergaminho reabre", scene.scrollOpen, 1, 1e-6)
        t:noerror("draw com o pergaminho no meio do caminho", function()
            scene.scrollOpen = 0.4; screen:draw(); scene.scrollOpen = 1
        end)
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
        -- v5: a plaquinha sem ouro troca de TOM (latão oxidado), não só a cor
        -- do texto; e a fita do COMPRAR lê o ouro no próprio desenho
        t:truthy("sem ouro: latao da plaquinha muda de tom",
            ShelfItemM.plaqueFace(false)[1] < ShelfItemM.plaqueFace(true)[1] - 0.1)
        screen.buyButton:setEnabled(true)
        screen:draw()
        t:truthy("sem ouro: a fita COMPRAR se apaga no proprio quadro", screen.buyButton.disabled)
        -- papel: legenda (tipo/raridade) com contraste >= 4,5 no pergaminho
        local CDP = require("src.ui.CardDetailPanel")
        for _, rar in ipairs({ "common", "uncommon", "rare", "legendary" }) do
            local c = CDP.onPaper(require("src.ui.Palette").darken(require("src.ui.Palette").forRarity(rar), 0.55))
            t:truthy(rar .. ": raridade legivel no papel (>= 4,5)",
                ShelfItemM.contrast(c, require("src.ui.Palette").PARCHMENT_LIGHT) >= 4.5)
        end
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
        t:truthy("reducedMotion: hover sem tilt", c1.tilt.x == 0 and c1.tilt.y == 0)
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

        -- ================= 9. pergaminho (v5): textos longos nos 5 idiomas =================
        -- Para cada idioma e tamanho, as ofertas da vitrine + as 12 cartas de
        -- DESCRIÇÃO mais longa do jogo naquele idioma: o conteúdo inteiro
        -- cabe no miolo do pergaminho (acima do COMPRAR), sem cortar texto e
        -- sem descer a descrição abaixo de 8 px. O preço não se repete na
        -- legenda (está no COMPRAR). O CRT recebe a zona de leitura.
        _G.gameSettings.reducedMotion = false
        local CardDetailPanel = require("src.ui.CardDetailPanel")
        local ShopScene = require("src.ui.shop.ShopScene")
        local worstLocale, panelChecks, panelFails = nil, 0, 0
        for _, code in ipairs(I18n.getAvailable()) do
            I18n.setLocale(code)
            for _, sz in ipairs({ { 1024, 768 }, { 1280, 720 }, { 1366, 768 }, { 1280, 800 } }) do
                fakeW, fakeH = sz[1], sz[2]
                FontManager.clearCache()
                TK.seedRng(4242)
                local sc3 = openShop(t, 60)
                local L3 = sc3.scene.L
                local db = sc3.cardDatabase
                local cards = {}
                for id, cd in pairs(db:getAllCards()) do
                    if cd.type ~= "joker" then
                        local d = I18n.cardDesc({ id = id, description = cd.description }) or ""
                        cards[#cards + 1] = { id = id, cd = cd, len = #d }
                    end
                end
                table.sort(cards, function(a, b) return a.len > b.len end)
                local payloads = {}
                for i = 1, math.min(12, #cards) do
                    local cd = cards[i].cd
                    payloads[#payloads + 1] = { kind = "card", instance = db:createCardInstance(cd),
                        offer = { id = cards[i].id, name = cd.name, description = cd.description,
                                  rarity = cd.rarity or "common", cost = 99 } }
                end
                for _, o in ipairs(sc3.shopOffers) do
                    local kind = (o.type == "card" and "card") or (o.type == "upgrade" and "voucher") or "pack"
                    payloads[#payloads + 1] = { kind = kind, offer = o, instance = o.cardInstance }
                end
                for _, pl in ipairs(payloads) do
                    local r = CardDetailPanel.draw(L3.scroll.body, pl, { parchment = true, chrome = false,
                        artMaxH = L3.scroll.artMaxH, priceOnButton = true, objectArt = ShopScene.portrait,
                        canAfford = true })
                    panelChecks = panelChecks + 1
                    local ok = r and r.fits and r.contentBottom <= L3.scroll.buy.y - 4 and r.font.desc >= 8
                    if not ok then
                        panelFails = panelFails + 1
                        worstLocale = worstLocale or ("%s %dx%d %s (fim %s, COMPRAR %d)"):format(code, sz[1], sz[2],
                            tostring(pl.offer.id), tostring(r and r.contentBottom), L3.scroll.buy.y)
                    end
                end
                -- a legenda não repete o preço (a fita COMPRAR mostra)
                sc3:draw()
                local fit = sc3._detailFit
                t:truthy(("%s %dx%d: pergaminho da loja mede e cabe"):format(code, sz[1], sz[2]), fit ~= nil and fit.fits)
                local CRT = require("src.ui.CRTShader")
                local cx, cy, cw, ch = CRT.getCalmRect()
                t:truthy(("%s %dx%d: CRT recebe a zona de leitura do pergaminho"):format(code, sz[1], sz[2]),
                    cw > 0 and math.abs(cx - L3.scroll.x) < 1 and math.abs(cw - L3.scroll.w) < 1)
                local _, _, cw2 = CRT.getCalmRect2()
                t:truthy(("%s %dx%d: CRT recebe a zona de leitura do CONTINUAR"):format(code, sz[1], sz[2]), cw2 > 0)
                CRT.setCalmRect(0, 0, 0, 0); CRT.setCalmRect2(0, 0, 0, 0)
                sc3:hide()
            end
        end
        I18n.setLocale("pt_BR")
        fakeW, fakeH = 1280, 720
        FontManager.clearCache()
        t:eq(("pergaminho: %d paineis (5 idiomas x 4 tamanhos) cabem sem cortar [%s]"):format(panelChecks,
            tostring(worstLocale)), panelFails, 0)
    end)

    _G.gameSettings.reducedMotion = prevReduced or false
    restoreFakes()
    FontManager.clearCache()
    t:truthy("suite rodou sem erro (" .. tostring(err) .. ")", okRun)
    return t:done()
end

return M
