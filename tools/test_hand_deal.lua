-- tools/test_hand_deal.lua
-- TRAVA da cortina da mão + distribuição das cartas (src/ui/HandDeal) e do
-- jeito que o GameplayScene a usa.
--
-- Bug do dono (Out/2026): a mão, os botões, os coringas e o HUD apareciam
-- no meio da porta do castelo e da entrada do chefe. Regra fixada:
--   * ZERO carta visível da viagem/porta até o FIM da cinemática;
--   * depois as cartas são DADAS uma a uma (escalonadas), da pilha do deck;
--   * botões/coringas/prévia e (no salão) o HUD só DEPOIS da última carta;
--   * na estrada: inimigo chega → cartas; o HUD do herói fica (é o status
--     dele, não cutscene);
--   * chefe SEM roteiro próprio ganha a entrada genérica (salão vazio →
--     impacto → nome) — nunca mais "luta como antes" com a mão na tela.
--
--   love . test_one test_hand_deal

local TK = require("tools.testkit")

local M = {}

local function noop() end

local function fakeCard()
    local c = { dissolve = 0, renderX = 0, renderY = 0, materialized = 0 }
    function c:cancelDissolveAnim() self.cancelled = (self.cancelled or 0) + 1 end
    function c:start_materialize() self.materialized = self.materialized + 1; self.dissolve = 0 end
    function c:setRenderPos(x, y) self.renderX, self.renderY = x, y end
    return c
end

function M.run()
    local t = TK.new("hand_deal")
    TK.bootstrap()
    local HandDeal = require("src.ui.HandDeal")
    local BC = require("src.ui.BossCinematic")
    local GS = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local ER = require("src.ui.EnemyRenderer")
    local Button = require("components.Button")

    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local DT = 1 / 30

    -- ===== 1. módulo puro (sem EventManager: a carta aparece no instante) =====
    local savedEM, savedEv = _G.EventManager, _G.Event
    _G.EventManager, _G.Event = nil, nil
    HandDeal.reset()
    local g = { hand = { fakeCard(), fakeCard(), fakeCard(), fakeCard() },
                enemy = { isAlive = function() return true end } }
    t:falsy("sem cortina: mão livre", HandDeal.hidesHand())
    t:falsy("sem cortina: UI livre", HandDeal.hidesUI())
    t:eq("sem cortina: 4 visíveis", HandDeal.visibleCount(g), 4)
    HandDeal.setCurtain(true, g, { hud = false })
    t:truthy("cortina: mão some", HandDeal.hidesHand())
    t:truthy("cortina: UI some", HandDeal.hidesUI())
    t:falsy("cortina sem hud: HUD fica", HandDeal.hidesHud())
    t:truthy("cortina: ocupado", HandDeal.isBusy())
    t:eq("cortina: 0 visíveis", HandDeal.visibleCount(g), 0)
    HandDeal.setCurtain(true, g, { hud = true })
    t:truthy("hud latched enquanto abaixada", HandDeal.hidesHud())
    HandDeal.setCurtain(false, g)
    t:falsy("cortina sobe", HandDeal.hidesHand())
    t:truthy("distribuindo", HandDeal.isDealing())
    t:truthy("UI espera a distribuição", HandDeal.hidesUI())
    t:truthy("HUD espera a distribuição (modo hud)", HandDeal.hidesHud())
    for _, c in ipairs(g.hand) do
        t:truthy("toda carta na pilha ao começar", HandDeal.holds(c))
        t:eq("carta invisível na pilha", c.dissolve, 1)
        t:eq("dissolve pendente cancelado", c.cancelled, 1)
    end
    HandDeal.update(0, g)
    t:eq("t=0: a 1ª carta sai da pilha", HandDeal.visibleCount(g), 1)
    t:eq("1ª apareceu (sem EventManager: na hora)", g.hand[1].dissolve, 0)
    t:eq("2ª ainda na pilha", g.hand[2].dissolve, 1)
    HandDeal.update(HandDeal.STAGGER * 0.5, g)
    t:eq("meio compasso: ainda 1", HandDeal.visibleCount(g), 1)
    HandDeal.update(HandDeal.STAGGER * 0.6, g)
    t:eq("1 compasso: 2 cartas", HandDeal.visibleCount(g), 2)
    HandDeal.update(HandDeal.STAGGER * 2, g)
    t:eq("3 compassos: 4 cartas", HandDeal.visibleCount(g), 4)
    t:truthy("UI ainda espera o respiro final", HandDeal.hidesUI())
    HandDeal.update(HandDeal.TAIL, g)
    t:falsy("respiro passou: UI volta", HandDeal.hidesUI())
    t:falsy("HUD volta", HandDeal.hidesHud())
    t:falsy("não ocupado", HandDeal.isBusy())
    -- interrupção: cortina abaixa no meio → quem faltava fica na pilha
    HandDeal.setCurtain(true, g)
    HandDeal.setCurtain(false, g)
    HandDeal.update(HandDeal.STAGGER * 1.2, g)
    t:eq("2 dadas", HandDeal.visibleCount(g), 2)
    HandDeal.setCurtain(true, g)
    t:falsy("cortina interrompe", HandDeal.isDealing())
    t:eq("cortina: nada visível", HandDeal.visibleCount(g), 0)
    HandDeal.setCurtain(false, g)
    t:truthy("sobe de novo: redistribui do zero", HandDeal.holds(g.hand[1]))
    -- carta jogada no meio da distribuição não quebra nada
    HandDeal.update(0, g)
    table.remove(g.hand, 2)
    HandDeal.update(HandDeal.STAGGER * 5 + HandDeal.TAIL, g)
    t:eq("carta que saiu da mão é ignorada", HandDeal.visibleCount(g), 3)
    t:falsy("termina mesmo assim", HandDeal.isDealing())
    -- inimigo morto atrás da cortina (morte do chefe): MESA FECHADA — nada
    -- de carta nem botão por cima do corpo; a próxima cortina reabre
    local gd = { hand = { fakeCard() }, enemy = { isAlive = function() return false end } }
    HandDeal.setCurtain(true, gd, { hud = true })
    HandDeal.setCurtain(false, gd)
    t:falsy("inimigo morto: sem distribuição", HandDeal.isDealing())
    t:truthy("inimigo morto: mesa fechada", HandDeal.isClosed())
    t:truthy("inimigo morto: mão não volta", HandDeal.hidesHand())
    t:truthy("inimigo morto: botões não voltam", HandDeal.hidesUI())
    t:truthy("inimigo morto: HUD (modo hud) não volta", HandDeal.hidesHud())
    t:eq("inimigo morto: 0 visíveis", HandDeal.visibleCount(gd), 0)
    t:eq("inimigo morto: carta intacta", gd.hand[1].dissolve, 0)
    gd.enemy.isAlive = function() return true end
    HandDeal.setCurtain(true, gd)
    t:falsy("cortina nova reabre a mesa", HandDeal.isClosed())
    HandDeal.setCurtain(false, gd)
    t:truthy("e distribui de novo", HandDeal.isDealing())
    _G.EventManager, _G.Event = savedEM, savedEv

    -- ===== 2. cena: viagem → porta → entrada do chefe → distribuição =====
    local function mountScene(game)
        GS.setGame(game)
        GS.init({
            game = game,
            playButton = Button:new(700, 550, 180, 60, "Jogar", noop),
            endTurnButton = Button:new(700, 620, 180, 44, "Encerrar", noop),
            topBar = { update = noop, draw = noop, height = 80,
                       mousepressed = function() return false end,
                       mousereleased = function() return false end },
            gameUI = { update = noop, draw = noop, show = noop, hide = noop },
        })
        _G.game = game
        WorldRoad.setBiome(game.runManager.currentRun.actNumber or 1)
    end
    local stage = {
        cx = 960, cy = 840,
        bbox = { cx = 960, topY = 500, bottomY = 840, width = 300, height = 340 },
        foot = { drawX = 800, drawY = 480, scale = 2.6 },
        hall = 1, w = 1920, h = 1080, tr = { scale = 4.8, ox = 0, oy = -74 },
    }

    local game = TK.newRunGame("warrior")
    local run = game.runManager.currentRun
    run.actNumber, run.floorInAct = 1, 7
    run.currentNode = { type = "boss" }
    game.enemy.spriteId = "carrion_king"
    game.enemy.isBoss = true
    mountScene(game)
    GS.update(DT)            -- ancora o andar
    run.floorInAct = 8       -- andar novo → a cena caminha até o castelo
    GS.update(DT)
    t:truthy("chefe: a cena viaja", WorldRoad.isTraveling())
    t:truthy("viagem: cortina abaixada", HandDeal.hidesHand())
    t:truthy("mão lógica cheia (as cartas existem, só não aparecem)", #game.hand >= 2)
    t:eq("viagem: 0 cartas visíveis", HandDeal.visibleCount(game), 0)
    t:falsy("aproximação: HUD ainda não some (a porta é que esconde)", HandDeal.hidesHud())

    local el, maxVisibleBeforeEnd, sawDoor, sawIntro, hudHiddenAtDoor = 0, 0, false, false, false
    local liftT, introEndT = nil, nil
    local lastVisible, maxJump, dealSamples = 0, 0, {}
    local uiShownWhileDealing = false
    while el < 40 do
        GS.update(DT)
        el = el + DT
        if WorldRoad.isEntering() then
            sawDoor = true
            if HandDeal.hidesHud() then hudHiddenAtDoor = true end
        end
        if BC.isActive() then
            sawIntro = true
            BC.setStage(stage)
        elseif sawIntro and not introEndT then
            introEndT = el
        end
        local vis = HandDeal.visibleCount(game)
        if not introEndT then
            maxVisibleBeforeEnd = math.max(maxVisibleBeforeEnd, vis)
        else
            if vis > lastVisible then
                if not liftT then liftT = el end
                dealSamples[#dealSamples + 1] = el
                maxJump = math.max(maxJump, vis - lastVisible)
            end
            if HandDeal.isDealing() and not HandDeal.hidesUI() then uiShownWhileDealing = true end
            lastVisible = vis
            if vis == #game.hand and not HandDeal.isBusy() then break end
        end
    end
    t:truthy("a porta abriu", sawDoor)
    t:truthy("a entrada tocou", sawIntro)
    t:truthy("na porta o HUD some", hudHiddenAtDoor)
    t:eq("ZERO carta visível da viagem ao fim da entrada", maxVisibleBeforeEnd, 0)
    t:truthy("a entrada terminou", introEndT ~= nil)
    t:truthy("distribuição começou DEPOIS da entrada", liftT ~= nil and liftT >= introEndT)
    t:eq("uma carta por vez", maxJump, 1)
    t:eq("todas as cartas dadas", #dealSamples, #game.hand)
    for i = 2, #dealSamples do
        t:near(("compasso entre cartas %d/%d"):format(i - 1, i),
            dealSamples[i] - dealSamples[i - 1], HandDeal.STAGGER, DT * 1.5)
    end
    t:falsy("botões/HUD só depois da última carta", uiShownWhileDealing)
    t:falsy("no fim: mão livre", HandDeal.hidesHand())
    t:falsy("no fim: UI livre", HandDeal.hidesUI())
    t:falsy("no fim: HUD livre", HandDeal.hidesHud())
    t:truthy("no fim: cena quieta (tutorial pode falar)", GS.isQuiet())
    for _, c in ipairs(game.hand) do
        t:falsy("carta fora da pilha", HandDeal.holds(c))
    end

    -- ===== 2b. depois do chefe: cash out e espólios DENTRO do salão =====
    -- (dono, Out/2026): o "só o mundo" atrás das telas de espólios é o
    -- salão com o cadáver enquanto o nó for o do chefe; a estrada só volta
    -- quando a encruzilhada troca o nó.
    t:eq("salão aberto: mundo-só = salão", GS.worldOnlyMode(), "hall")
    game.enemy.health = 0
    game._deathHandled = true
    GS.update(DT)
    t:eq("chefe morto: cash out/espólios no salão", GS.worldOnlyMode(), "hall")
    t:truthy("chefe morto: mesa fechada (sem mão por cima do corpo)", HandDeal.hidesHand())
    local okDraw, errDraw = pcall(GS.drawWorldOnly)
    t:truthy("drawWorldOnly no salão desenha sem erro: " .. tostring(errDraw), okDraw)
    run.currentNode = { type = "battle" }   -- a encruzilhada trocou o nó
    t:eq("nó deixado: mundo-só = estrada", GS.worldOnlyMode(), "road")
    run.currentNode = { type = "boss" }
    game.enemy.health = 10
    game._deathHandled = false

    -- ===== 3. salão sem roteiro próprio: entrada genérica =====
    local g2 = TK.newRunGame("warrior")
    local run2 = g2.runManager.currentRun
    run2.actNumber, run2.floorInAct = 2, 8
    run2.currentNode = { type = "boss" }
    g2.enemy.spriteId = "__sem_roteiro__"
    g2.enemy.isBoss = true
    mountScene(g2)
    GS.update(DT)
    GS._onBossEntered()
    t:truthy("chefe sem roteiro: entrada GENÉRICA toca", BC.isActive())
    t:truthy("genérica: salão vazio no começo", BC.hidesBoss())
    t:truthy("genérica: cortina abaixada", HandDeal.hidesHand())
    BC.setStage(stage)
    local sawTitle, el2 = false, 0
    while BC.isActive() and el2 < 10 do
        GS.update(DT)
        el2 = el2 + DT
        if BC._debug().title then sawTitle = true end
    end
    t:truthy("genérica: cartão com o nome", sawTitle)
    t:truthy("genérica: distribuição depois", HandDeal.isDealing())
    t:eq("genérica: 1 carta no primeiro instante", HandDeal.visibleCount(g2), 1)
    -- quem não é chefe não tem entrada
    local g3 = TK.newRunGame("warrior")
    g3.enemy.isBoss = false
    t:falsy("inimigo comum não tem entrada", BC.startIntro(g3))

    -- ===== 4. estrada: inimigo chega → cartas; HUD do herói fica =====
    local g4 = TK.newRunGame("warrior")
    local run4 = g4.runManager.currentRun
    run4.actNumber, run4.floorInAct = 1, 2
    run4.currentNode = { type = "battle" }
    mountScene(g4)
    GS.update(DT)
    run4.floorInAct = 3
    GS.update(DT)
    t:truthy("estrada: a cena viaja", WorldRoad.isTraveling())
    t:truthy("estrada: cortina abaixada", HandDeal.hidesHand())
    t:falsy("estrada: HUD do herói fica", HandDeal.hidesHud())
    local el4, vis4Before, arrived, liftT4 = 0, 0, nil, nil
    while el4 < 20 do
        GS.update(DT)
        el4 = el4 + DT
        if not arrived and not WorldRoad.isTraveling() then arrived = el4 end
        local vis = HandDeal.visibleCount(g4)
        if not liftT4 and vis > 0 then liftT4 = el4 end
        if not arrived then vis4Before = math.max(vis4Before, vis) end
        if vis == #g4.hand and not HandDeal.isBusy() then break end
    end
    t:truthy("estrada: inimigo chegou", arrived ~= nil)
    t:eq("estrada: 0 cartas antes da chegada", vis4Before, 0)
    t:truthy("estrada: cartas só depois da quicada de chegada",
        liftT4 ~= nil and liftT4 >= arrived + 0.5)
    t:eq("estrada: todas dadas", HandDeal.visibleCount(g4), #g4.hand)
    t:falsy("estrada: HUD nunca esteve escondido", HandDeal.hidesHud())

    -- ===== 5. input fechado atrás da cortina =====
    HandDeal.setCurtain(true, g4)
    t:falsy("clique na mão atrás da cortina não consome", GS.mousepressed(700, 560, 1))
    HandDeal.setCurtain(false, g4)

    -- ===== 6. run NOVA: a 1ª luta CHEGA pela estrada (dono, 13/Out) =====
    -- "quando clica em Jogar a tela já é o inimigo com as cartas, sem
    -- animação": startGame pede requestArrival e o 1º andar viaja como
    -- qualquer outro; Continuar (resumeWorld) nunca repete a chegada.
    local g5 = TK.newRunGame("warrior")
    local run5 = g5.runManager.currentRun
    run5.actNumber, run5.floorInAct = 1, 1
    run5.currentNode = { type = "battle" }
    mountScene(g5)
    GS.requestArrival()
    t:truthy("pedido de chegada registrado", GS.hasPendingArrival())
    GS.update(DT)
    t:truthy("run nova: a 1ª luta viaja pela estrada", WorldRoad.isTraveling())
    t:truthy("run nova: cortina abaixada na viagem", HandDeal.hidesHand())
    t:falsy("pedido consumido", GS.hasPendingArrival())
    local el5, vis5Before, arrived5 = 0, 0, nil
    while el5 < 20 do
        GS.update(DT)
        el5 = el5 + DT
        if not arrived5 and not WorldRoad.isTraveling() then arrived5 = el5 end
        local vis = HandDeal.visibleCount(g5)
        if not arrived5 then vis5Before = math.max(vis5Before, vis) end
        if vis == #g5.hand and not HandDeal.isBusy() then break end
    end
    t:truthy("run nova: inimigo chegou", arrived5 ~= nil)
    t:eq("run nova: 0 cartas antes da chegada", vis5Before, 0)
    t:eq("run nova: todas dadas no fim", HandDeal.visibleCount(g5), #g5.hand)
    -- Continuar: sem pedido, ancorado, nada viaja
    local g6 = TK.newRunGame("warrior")
    local run6 = g6.runManager.currentRun
    run6.actNumber, run6.floorInAct = 1, 1
    run6.currentNode = { type = "battle" }
    mountScene(g6)
    GS.requestArrival()
    GS.resumeWorld(g6)
    t:falsy("Continuar limpa o pedido de chegada", GS.hasPendingArrival())
    GS.update(DT); GS.update(DT)
    t:falsy("Continuar: a 1ª luta nao viaja", WorldRoad.isTraveling())
    -- sem pedido (testes/tools): como sempre, nasce pronta
    local g7 = TK.newRunGame("warrior")
    g7.runManager.currentRun.currentNode = { type = "battle" }
    mountScene(g7)
    GS.update(DT); GS.update(DT)
    t:falsy("sem pedido: nasce pronta (comportamento dos tools)", WorldRoad.isTraveling())

    GS.setGame(game)
    _G.gameSettings = savedSettings
    return t:done()
end

return M
