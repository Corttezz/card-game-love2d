-- tools/test_shop_services.lua
-- SERVIÇOS DA LOJA (Set/2026): tesoura (remover), prensa (duplicar), bancada
-- de coringa (+1 slot ativo) e grimório (+1 compra por turno).
--
-- O QUE ESTA SUITE TRAVA (e por que cada trava existe)
--
--  1. CUSTO CRESCENTE + TETO. Serviço barato pra sempre é serviço que zera a
--     decisão econômica: com remoção a $8 fixa o jogador compra todas e o
--     deck vira uma faca. O custo tem que subir por compra NA MESMA RUN.
--
--  2. DISPONIBILIDADE É ESTADO, NÃO SORTE. A tesoura some quando o deck está
--     no osso (RestScreen:doRemove recusa deixar o deck abaixo de 2 cartas —
--     vender ali é vender algo que a tela seguinte nega), e os serviços com
--     teto somem da vitrine quando o teto é batido. Sem isso a loja cobra por
--     nada.
--
--  3. A TESOURA É FIXA NA PRATELEIRA. Com seis relíquias disputando as vagas,
--     uma remoção sorteada apareceria em ~1 de cada 6 lojas e a mecânica
--     viraria decoração. O teste prova que ela está em TODA vitrine de loja
--     (e em NENHUMA recompensa pós-batalha, que não vende serviço).
--
--  4. O EFEITO ACONTECE DE VERDADE. Slot comprado tem que deixar um QUARTO
--     coringa ficar ativo; compra extra tem que aparecer no draw do turno E
--     na mão inicial da batalha. Esta é a lição do P3.2 (rebalance Jul/2026):
--     três upgrades ficaram meses na vitrine aplicando só um toast.
--
--  5. PAGOU E NÃO LEVOU = ESTORNO. Os serviços de deck cobram ANTES de abrir
--     o picker de carta, e o picker pode ser fechado no "Voltar". Sem estorno
--     o ouro some e o slot fica carimbado VENDIDO. (A forja tinha esse buraco
--     desde sempre; ele entra na mesma trava.)
--
--  6. O LEDGER SOBREVIVE AO SAVE. Slot de coringa e compra extra são
--     permanentes: se `currentRun.services` não viajasse no save, fechar o
--     jogo devolveria os coringas pra bancada.
--
--  7. A VITRINE DE 2 RELÍQUIAS AINDA CABE. `upgrades` foi de 1 pra 2; a
--     fileira 2 da loja agora tem 4 células. A geometria é provada em vários
--     tamanhos de janela, não olhada numa captura.
--
--   love . test_one test_shop_services

local TK = require("tools.testkit")

local Config       = require("src.core.Config")
local ShopServices = require("src.systems.ShopServices")
local ShopSystem   = require("src.systems.ShopSystem")
local RunManager   = require("src.systems.RunManager")

local M = {}

-- Conta ofertas de upgrade por id numa vitrine.
local function upgradeIds(offers)
    local out = {}
    for _, o in ipairs(offers) do
        if o.type == "upgrade" then out[o.id] = (out[o.id] or 0) + 1 end
    end
    return out
end

-- Loja pronta pra gerar ofertas com o contexto de uma run real.
local function openShop(game, mode)
    local shop = ShopSystem:new()
    shop:setContext({
        classId = game.runManager.currentRun.classId,
        runManager = game.runManager,
        actNumber = game.runManager.currentRun.actNumber or 1,
    })
    shop:setMode(mode or "shop")
    shop:generateOffers()
    return shop
end

function M.run()
    local t = TK.new("servicos da loja (remover/duplicar/slot de coringa/compra)")
    TK.seedRng(90210)

    -- ========================================================================
    -- 1. CUSTO: cresce por compra e bate no teto
    -- ========================================================================
    local rm = RunManager:new()
    rm:startNewRun("warrior")

    local cfgRemove = Config.Offers.SERVICES.remove_card
    t:eq("tesoura: 1a compra custa a base",
        ShopServices.cost("remove_card", rm), cfgRemove.base)

    rm:registerService("remove_card")
    local c2 = ShopServices.cost("remove_card", rm)
    t:truthy("tesoura: 2a compra custa mais que a 1a", c2 > cfgRemove.base)
    t:eq("ledger conta a compra", rm:getServiceCount("remove_card"), 1)

    -- Teto: muitas compras não deixam o custo explodir.
    for _ = 1, 20 do rm:registerService("remove_card") end
    t:eq("tesoura: custo bate no teto e para",
        ShopServices.cost("remove_card", rm), cfgRemove.max)

    -- Estorno desfaz o ledger (compra cancelada não encarece a próxima).
    local antes = rm:getServiceCount("remove_card")
    rm:unregisterService("remove_card")
    t:eq("estorno desfaz uma compra no ledger",
        rm:getServiceCount("remove_card"), antes - 1)
    rm:unregisterService("nao_existe")
    t:eq("estorno de servico nunca comprado nao vira negativo",
        rm:getServiceCount("nao_existe"), 0)

    -- ========================================================================
    -- 2. DISPONIBILIDADE por estado da run
    -- ========================================================================
    local rm2 = RunManager:new()
    rm2:startNewRun("warrior")
    local deck = rm2.currentRun.currentDeck
    t:truthy("deck starter tem 2 cartas (premissa do teste)", #deck == 2)
    t:falsy("tesoura NAO e ofertada com deck de 2 cartas",
        ShopServices.isAvailable("remove_card", rm2))

    rm2:addCardToDeck("warrior_strike")
    t:truthy("tesoura volta a ser ofertada com deck de 3 cartas",
        ShopServices.isAvailable("remove_card", rm2))

    local capJoker = Config.Offers.SERVICES.joker_slot.maxPerRun
    t:truthy("bancada de coringa disponivel no inicio",
        ShopServices.isAvailable("joker_slot", rm2))
    for _ = 1, capJoker do rm2:registerService("joker_slot") end
    t:falsy("bancada de coringa some depois do teto de compras",
        ShopServices.isAvailable("joker_slot", rm2))

    local capDraw = Config.Offers.SERVICES.card_draw_upgrade.maxPerRun
    for _ = 1, capDraw do rm2:registerService("card_draw_upgrade") end
    t:falsy("grimorio de compra some depois do teto",
        ShopServices.isAvailable("card_draw_upgrade", rm2))

    -- ========================================================================
    -- 3. VITRINE: tesoura fixa na loja, ausente na recompensa, sem repetida
    -- ========================================================================
    local game = TK.newRunGame("warrior")
    -- Deck acima do minimo pra tesoura poder aparecer.
    for _ = 1, 4 do game.runManager:addCardToDeck("warrior_strike") end

    local semTesoura, repetida = 0, 0
    for _ = 1, 12 do
        local shop = openShop(game, "shop")
        local ids = upgradeIds(shop:getCurrentOffers())
        if not ids.remove_card then semTesoura = semTesoura + 1 end
        for _, n in pairs(ids) do if n > 1 then repetida = repetida + 1 end end
    end
    t:eq("tesoura aparece em TODA vitrine de loja", semTesoura, 0)
    t:eq("nenhuma reliquia aparece duas vezes na mesma loja", repetida, 0)

    local shopCfg = ShopSystem:new():getModeConfig()
    t:eq("loja abre 2 vagas de reliquia", shopCfg.upgrades, 2)

    local semServico = true
    for _ = 1, 6 do
        local rew = openShop(game, "rewards")
        for _, o in ipairs(rew:getCurrentOffers()) do
            if o.type == "upgrade" then semServico = false end
        end
    end
    t:truthy("recompensa pos-batalha nao vende reliquia nenhuma", semServico)

    -- Tesoura some da vitrine quando o deck fica curto demais.
    local gameCurto = TK.newRunGame("warrior")
    local shopCurto = openShop(gameCurto, "shop")
    t:falsy("tesoura fora da vitrine com deck no osso",
        upgradeIds(shopCurto:getCurrentOffers()).remove_card)

    -- Oferta montada carrega o que a tela precisa pra aplicar.
    local ofertaTesoura
    for _, o in ipairs(openShop(game, "shop"):getCurrentOffers()) do
        if o.id == "remove_card" then ofertaTesoura = o end
    end
    t:truthy("oferta da tesoura existe", ofertaTesoura ~= nil)
    if ofertaTesoura then
        t:eq("oferta da tesoura despacha o efeito certo",
            ofertaTesoura.effect, "remove_card")
        t:eq("oferta da tesoura pede o picker de remocao",
            ofertaTesoura.picker, "remove")
        t:truthy("oferta da tesoura tem custo > 0", (ofertaTesoura.cost or 0) > 0)
        t:truthy("oferta da tesoura tem nome traduzido (nao o id cru)",
            ofertaTesoura.name ~= nil and ofertaTesoura.name ~= "remove_card")
    end

    -- ========================================================================
    -- 3b. A VITRINE OLHA A RUN: coringa parado na bancada puxa a oferta
    -- ========================================================================
    -- Sem isso a bancada de coringa disputa a vaga rotativa em pé de igualdade
    -- com outras cinco relíquias e aparece em ~1 de cada 6 lojas — quem
    -- acumulou coringas pode terminar a corrida sem nunca ver a coisa que
    -- resolveria o problema dele.
    local rmPeso = RunManager:new()
    rmPeso:startNewRun("warrior")
    local pesoLivre = ShopServices.weight("joker_slot", rmPeso)
    for _ = 1, Config.Game.MAX_JOKER_SLOTS + 1 do
        rmPeso:addJokerToRun("joker_001")
    end
    local pesoComBancada = ShopServices.weight("joker_slot", rmPeso)
    t:truthy("bancada de coringa pesa MAIS quando ha coringa parado",
        pesoComBancada > pesoLivre)
    t:eq("sem coringa parado, o peso e o do catalogo",
        pesoLivre, ShopServices.get("joker_slot").weight)

    -- ========================================================================
    -- 4. EFEITO REAL: slot de coringa e compra extra
    -- ========================================================================
    local gj = TK.newRunGame("warrior")
    local rmj = gj.runManager
    local baseSlots = Config.Game.MAX_JOKER_SLOTS

    -- Enche a colecao com 1 coringa a mais do que cabe.
    for _ = 1, baseSlots + 1 do rmj:addJokerToRun("joker_001") end
    gj:recomputeMaxJokerSlots()
    t:eq("sem compra, so o teto base fica ativo",
        rmj:getActiveJokerCount(), baseSlots)
    t:falsy("ativar o excedente e recusado no teto base",
        (rmj:setJokerActive(baseSlots + 1, true)))

    rmj:registerService("joker_slot")
    gj:recomputeMaxJokerSlots()
    t:eq("bancada comprada sobe o teto de ativos",
        rmj:getMaxJokerSlots(), baseSlots + 1)
    t:truthy("o coringa da bancada agora pode entrar em campo",
        (rmj:setJokerActive(baseSlots + 1, true)))
    gj:rebuildJokerSlots()
    t:eq("jokerSlots passa a ter o coringa extra",
        #gj.jokerSlots, baseSlots + 1)

    -- Compra extra por turno.
    local gd = TK.newRunGame("warrior")
    for _ = 1, 12 do gd.runManager:addCardToDeck("warrior_strike") end
    gd:synchronizeRunDeck()
    gd:resetHandAndDeck()
    TK.pump(gd, 1.0)
    local maoBase = #gd.hand

    gd.runManager:registerService("card_draw_upgrade")
    t:eq("Game enxerga o servico comprado",
        gd:getShopServiceCount("card_draw_upgrade"), 1)
    gd.hand = {}
    gd:drawForTurn()
    TK.pump(gd, 1.0)
    t:eq("grimorio da +1 carta no draw do turno", #gd.hand, maoBase + 1)

    gd:resetHandAndDeck()
    TK.pump(gd, 1.0)
    t:eq("grimorio tambem vale pra mao inicial da batalha",
        #gd.hand, maoBase + 1)

    -- ========================================================================
    -- 4b. COFRE: o teto dos juros sobe, e sobe de verdade
    -- ========================================================================
    -- Diferente das outras relíquias, esta REALIMENTA a fonte de ouro. As
    -- travas aqui são três:
    --   • o teto efetivo sai do LEDGER, não de um campo solto que alguém
    --     esqueceria de salvar;
    --   • calculateInterest (que a TopBar lê todo frame e o cash-out usa pra
    --     PAGAR) enxerga o teto novo — número prometido e número pago são o
    --     mesmo, que foi a razão de existir do calculateInterest;
    --   • o guarda-corpo do Config segura, pra que nenhum caminho futuro
    --     transforme juros em motor infinito.
    local EconomySystem = require("src.systems.EconomySystem")
    local gi = TK.newRunGame("warrior")
    local porCompra = Config.Offers.INTEREST_CAP_PER_BUY

    gi.economySystem.currentGold = 500   -- cofre farto: o teto é quem limita
    local jurosBase = gi.economySystem:calculateInterest()
    t:eq("sem compra, juros no teto base", jurosBase, 5)

    gi.runManager:registerService("interest_cap")
    gi:syncInterestCap()
    t:eq("1 compra sobe o teto em INTEREST_CAP_PER_BUY",
        gi.economySystem:getInterestCap(), 5 + porCompra)
    t:eq("os juros PAGOS acompanham o teto novo",
        gi.economySystem:calculateInterest(), 5 + porCompra)

    gi.runManager:registerService("interest_cap")
    gi:syncInterestCap()
    t:eq("2a compra sobe de novo (repetivel)",
        gi.economySystem:getInterestCap(), 5 + porCompra * 2)

    -- O teto NÃO dá dinheiro sozinho: continua limitado por floor(ouro/5).
    gi.economySystem.currentGold = 10
    t:eq("cofre vazio: teto alto nao inventa juros",
        gi.economySystem:calculateInterest(), 2)

    -- Guarda-corpo: nem 999 compras estouram o teto do teto.
    local eco = EconomySystem:new()
    eco:setBonusInterestCap(999)
    t:eq("guarda-corpo limita o teto total",
        eco:getInterestCap(), Config.Offers.INTEREST_CAP_MAX)
    eco:setBonusInterestCap(-5)
    t:eq("bonus negativo nao baixa o teto base", eco:getInterestCap(), 5)

    -- Corrida nova volta ao base (o bônus é da RUN, não do objeto).
    eco:setBonusInterestCap(6)
    eco:resetForNewRun()
    t:eq("corrida nova volta ao teto base", eco:getInterestCap(), 5)

    -- O preço sobe a cada compra — é o freio principal do composto.
    local rmJuros = RunManager:new()
    rmJuros:startNewRun("warrior")
    local p1 = ShopServices.cost("interest_cap", rmJuros)
    rmJuros:registerService("interest_cap")
    local p2 = ShopServices.cost("interest_cap", rmJuros)
    rmJuros:registerService("interest_cap")
    local p3 = ShopServices.cost("interest_cap", rmJuros)
    t:truthy("cofre encarece a cada compra", p3 > p2 and p2 > p1)
    t:truthy("as 3 primeiras compras custam mais que uma lendaria (30)",
        p1 + p2 + p3 > 30 * 3)
    -- Sem teto de compras: o pedido foi "aumentar sempre".
    t:truthy("cofre continua ofertavel depois de 2 compras",
        ShopServices.isAvailable("interest_cap", rmJuros))

    -- A placa do tile mostra o MESMO numero que o efeito aplica.
    local ofertaCofre
    do
        local shopC = ShopSystem:new()
        shopC:setContext({ runManager = rmJuros })
        ofertaCofre = shopC:buildServiceOffer("interest_cap")
    end
    t:truthy("oferta do cofre existe", ofertaCofre ~= nil)
    if ofertaCofre then
        t:eq("value da oferta = ganho real por compra",
            ofertaCofre.value, porCompra)
        local UT = require("src.ui.UpgradeTile")
        local placa = UT.effectLabel(ofertaCofre) or ""
        t:truthy("placa do tile imprime o numero (nao '{value}')",
            placa:find(tostring(porCompra), 1, true) ~= nil
                and not placa:find("{value}", 1, true))
    end

    -- ========================================================================
    -- 5. ESTORNO: pagou, fechou o picker sem escolher, recebe de volta
    -- ========================================================================
    local CardRewardScreen = require("components.CardRewardScreen")
    local ge = TK.newRunGame("warrior")
    for _ = 1, 4 do ge.runManager:addCardToDeck("warrior_strike") end
    ge.economySystem.currentGold = 200

    local tela = CardRewardScreen:new(ge.shopSystem)
    tela.game = ge
    tela.visible = false   -- sem layout: o estorno nao pode depender de desenho
    tela.shopOffers = {}
    tela.cardPositions = {}

    -- O picker que NAO escolhe carta nenhuma (o "Voltar" do jogador).
    local origPicker = _G.openCardPicker
    _G.openCardPicker = function(_mode, onDone) if onDone then onDone() end end

    local ouroAntes = ge.economySystem.currentGold
    local forjasAntes = ge.runManager.currentRun.paidForges or 0
    local oferta = {
        type = "upgrade", id = "remove_card", effect = "remove_card",
        cost = 8, value = 1, purchased = true,
    }
    ge.economySystem:spendGold(oferta.cost, oferta.type, oferta.id)
    tela:applyUpgrade(oferta)
    t:eq("picker cancelado devolve o ouro do servico",
        ge.economySystem.currentGold, ouroAntes)
    t:eq("picker cancelado nao encarece a proxima compra",
        ge.runManager:getServiceCount("remove_card"), 0)
    t:falsy("oferta cancelada volta a ficar comprável", oferta.purchased)

    local ofertaForja = {
        type = "upgrade", id = "forge_card", effect = "forge_card",
        cost = 5, value = 1, purchased = true,
    }
    ge.economySystem:spendGold(ofertaForja.cost, ofertaForja.type, ofertaForja.id)
    tela:applyUpgrade(ofertaForja)
    t:eq("forja cancelada tambem devolve o ouro",
        ge.economySystem.currentGold, ouroAntes)
    t:eq("forja cancelada nao conta como forja paga",
        ge.runManager.currentRun.paidForges or 0, forjasAntes)

    -- O picker que ESCOLHE (remove uma carta): nada é estornado.
    _G.openCardPicker = function(_mode, onDone)
        ge.runManager:removeCardAt(1)
        if onDone then onDone() end
    end
    local oferta2 = {
        type = "upgrade", id = "remove_card", effect = "remove_card",
        cost = 8, value = 1, purchased = true,
    }
    ge.economySystem:spendGold(oferta2.cost, oferta2.type, oferta2.id)
    tela:applyUpgrade(oferta2)
    t:eq("servico usado NAO devolve ouro",
        ge.economySystem.currentGold, ouroAntes - oferta2.cost)
    t:eq("servico usado conta no ledger",
        ge.runManager:getServiceCount("remove_card"), 1)
    t:truthy("oferta usada continua vendida", oferta2.purchased)

    -- A prensa (duplicar) muda o deck pra CIMA: a assinatura tem que enxergar.
    _G.openCardPicker = function(_mode, onDone)
        ge.runManager:duplicateCardAt(1)
        if onDone then onDone() end
    end
    local oferta3 = {
        type = "upgrade", id = "duplicate_card", effect = "duplicate_card",
        cost = 12, value = 1, purchased = true,
    }
    local ouroPre3 = ge.economySystem.currentGold
    ge.economySystem:spendGold(oferta3.cost, oferta3.type, oferta3.id)
    tela:applyUpgrade(oferta3)
    t:eq("prensa usada NAO devolve ouro",
        ge.economySystem.currentGold, ouroPre3 - oferta3.cost)

    -- A forja não mexe no TAMANHO do deck, só no nível: a assinatura também
    -- tem que enxergar isso (senão toda forja usada seria estornada).
    _G.openCardPicker = function(_mode, onDone)
        ge.runManager:upgradeCardAt(1)
        if onDone then onDone() end
    end
    local oferta4 = {
        type = "upgrade", id = "forge_card", effect = "forge_card",
        cost = 5, value = 1, purchased = true,
    }
    local ouroPre4 = ge.economySystem.currentGold
    ge.economySystem:spendGold(oferta4.cost, oferta4.type, oferta4.id)
    tela:applyUpgrade(oferta4)
    t:eq("forja usada NAO devolve ouro",
        ge.economySystem.currentGold, ouroPre4 - oferta4.cost)

    _G.openCardPicker = origPicker

    -- ========================================================================
    -- 6. LEDGER sobrevive ao save/load
    -- ========================================================================
    local gs = TK.newRunGame("warrior")
    gs.runManager:registerService("joker_slot")
    gs.runManager:registerService("card_draw_upgrade")
    gs.runManager:registerService("card_draw_upgrade")
    gs.runManager:registerService("interest_cap")
    gs.runManager:registerService("interest_cap")
    t:truthy("save escreveu", (gs.runManager:saveRun()))

    local rmLoad = RunManager:new()
    t:truthy("load leu", (rmLoad:loadRun()))
    t:eq("bancada comprada sobrevive ao save",
        rmLoad:getServiceCount("joker_slot"), 1)
    t:eq("compras extras sobrevivem ao save",
        rmLoad:getServiceCount("card_draw_upgrade"), 2)
    -- Antes do primeiro startGame não existe espelho em currentRun.maxJokerSlots:
    -- o teto ainda tem que contar as bancadas compradas, senão o jogador
    -- reabre o jogo com coringas rebaixados pra bancada.
    rmLoad.currentRun.maxJokerSlots = nil
    t:eq("teto de coringas conta a bancada mesmo sem espelho",
        rmLoad:getMaxJokerSlots(), Config.Game.MAX_JOKER_SLOTS + 1)
    t:eq("cofre (teto de juros) sobrevive ao save",
        rmLoad:getServiceCount("interest_cap"), 2)

    -- O CAMINHO INTEIRO do Continuar: carregar a run e remontar o jogo tem
    -- que devolver o teto de juros comprado. O espelho vive no EconomySystem,
    -- que `startGame` reseta — é exatamente aqui que um teto comprado
    -- sumiria sem ninguém perceber (o jogador só veria "meus juros
    -- diminuíram" umas batalhas depois).
    local Game = require("src.core.Game")
    local gResume = Game:new()
    gResume.runManager = rmLoad
    gResume.isRunMode = true
    t:truthy("resumeRun remontou a run", (gResume:resumeRun()))
    gResume.economySystem.currentGold = 500
    t:eq("teto de juros volta certo depois do Continuar",
        gResume.economySystem:getInterestCap(),
        5 + Config.Offers.INTEREST_CAP_PER_BUY * 2)
    t:eq("e os juros pagos ja usam o teto restaurado",
        gResume.economySystem:calculateInterest(),
        5 + Config.Offers.INTEREST_CAP_PER_BUY * 2)

    -- Run recém-criada não herda ledger de outra run.
    local rmNovo = RunManager:new()
    rmNovo:startNewRun("mage")
    t:eq("run nova comeca com ledger zerado",
        rmNovo:getServiceCount("joker_slot"), 0)

    -- ========================================================================
    -- 7. GEOMETRIA: a vitrine de 2 relíquias cabe em qualquer janela
    -- ========================================================================
    local tela2 = CardRewardScreen:new(game.shopSystem)
    tela2.game = game
    tela2.mode = "shop"
    tela2.modeConfig = game.shopSystem:getModeConfig()
    tela2.shopOffers = openShop(game, "shop"):getCurrentOffers()
    for i, o in ipairs(tela2.shopOffers) do o._slot = i end

    local TAMANHOS = {
        { 1920, 1080 }, { 1600, 900 }, { 1366, 768 }, { 1280, 720 }, { 1024, 768 },
    }
    local gw, gh = love.graphics.getWidth, love.graphics.getHeight
    for _, dim in ipairs(TAMANHOS) do
        love.graphics.getWidth  = function() return dim[1] end
        love.graphics.getHeight = function() return dim[2] end
        tela2:updateLayout()
        local bad = tela2:validateLayout()
        t:check(("vitrine %dx%d com 2 reliquias: layout integro%s")
            :format(dim[1], dim[2], #bad > 0 and (" -> " .. bad[1]) or ""),
            #bad == 0)
        t:eq(("vitrine %dx%d tem 8 slots (4 cartas + 2 reliquias + 2 pacotes)")
            :format(dim[1], dim[2]), tela2.slotCount, 8)
    end
    love.graphics.getWidth, love.graphics.getHeight = gw, gh

    -- ========================================================================
    -- 7b. ARTE: quem tem PNG usa o PNG; quem não tem, DIZ que não tem
    -- ========================================================================
    -- O grimório de compra extra reaproveita `card_draw_upgrade` — o id (e o
    -- PNG do livro) que existia desde sempre em assets/sprites/vouchers/ e
    -- ficou órfão quando o P3.2 tirou da vitrine o upgrade que só soltava
    -- toast. Reusar o id devolve arte E animação de graça; a trava garante
    -- que um rename futuro não volte a deixá-lo sem sprite em silêncio.
    local UpgradeTile = require("src.ui.UpgradeTile")
    t:truthy("grimorio reaproveita o PNG de voucher que ja existia",
        UpgradeTile.staticSprite("card_draw_upgrade") ~= nil)

    -- Débito de arte declarado: os demais serviços caem no selo ornamental do
    -- UpgradeTile (que nunca deixa buraco). Não é falha — é lista de pendência
    -- impressa no log, pra não virar "ninguém percebeu".
    local semArte = {}
    for _, svc in ipairs(ShopServices.CATALOG) do
        if not UpgradeTile.staticSprite(svc.id) then
            semArte[#semArte + 1] = svc.id
        end
    end
    print("  [info] servicos ainda sem PNG em assets/sprites/vouchers/: "
        .. (#semArte > 0 and table.concat(semArte, ", ") or "nenhum"))

    -- ========================================================================
    -- 8. i18n: cada serviço tem texto nos 5 locales
    -- ========================================================================
    local I18n = require("src.i18n.I18n")
    local locAtual = I18n.getLocale()
    for _, code in ipairs(I18n.getAvailable()) do
        I18n.setLocale(code)
        for _, svc in ipairs(ShopServices.CATALOG) do
            for _, part in ipairs({ "name", "effect", "desc" }) do
                local key = "shop_items." .. svc.id .. "." .. part
                local txt = I18n.t(key, { value = 1 }, "__missing__")
                t:check(code .. " tem " .. key,
                    txt ~= "__missing__" and txt ~= key and txt ~= "")
            end
        end
        for _, key in ipairs({ "reward.joker_slot_gained", "reward.service_refunded",
                              "reward.extra_draw", "reward.interest_cap_raised" }) do
            local txt = I18n.t(key, { n = 1 }, "__missing__")
            t:check(code .. " tem " .. key,
                txt ~= "__missing__" and txt ~= key and txt ~= "")
        end
    end
    I18n.setLocale(locAtual)

    return t:done()
end

return M
