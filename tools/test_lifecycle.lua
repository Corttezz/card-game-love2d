-- tools/test_lifecycle.lua
-- Ciclo de vida da RUN: o que o save guarda, o que o Continuar reabre, e as
-- portas que deixavam a run num estado impossível. Cada bloco é um defeito
-- achado na revisão de lançamento (Out/2026), descrito como o jogador o vê.
--
--   love . test_one test_lifecycle

local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("ciclo de vida da run (save / Continuar / fim)")
    TK.bootstrap()
    TK.seedRng(20261010)

    local Game       = require("src.core.Game")
    local ResumeFlow = require("src.systems.ResumeFlow")
    local SaveManager = require("engine.SaveManager")
    local Config     = require("src.core.Config")

    -- 1. "A batalha seguinte começou com o inimigo atacando primeiro."
    do
        local g = TK.newRunGame("mage")
        g.turn = "enemy"            -- golpe final veio do pulso de orbe do fim de turno
        g._endTurnQueued = true     -- ou de um "Encerrar turno" enfileirado
        g.runManager.currentRun.currentNode = { type = "battle" }
        g:nextPhase()
        t:eq("batalha nova SEMPRE abre no turno do jogador", g.turn, "player")
        t:falsy("encerrar-turno enfileirado na luta anterior nao vaza", g._endTurnQueued)
        t:eq("o save da batalha nova marca o estagio 'battle'",
            g.runManager.currentRun.stage, "battle")
    end

    -- 2. "Morri com o menu de pausa aberto, salvei, e o Continuar me trouxe de
    --    volta com 1 de vida."
    do
        local g = TK.newRunGame("warrior")
        g:checkpointRun()
        SaveManager.deleteRun()
        g.player.health = 0
        g:checkpointRun()
        t:falsy("jogador MORTO nao grava save (nada de ressuscitar)", SaveManager.hasRun())
    end

    -- 3. "Venci o jogo e o menu ainda oferecia Continuar — de volta ao chefe."
    do
        local g = TK.newRunGame("rogue")
        local run = g.runManager.currentRun
        g:checkpointRun()
        t:truthy("(pre) ha save durante a run", SaveManager.hasRun())
        run.actNumber = Config.TotalActs
        run.floorInAct = require("src.systems.MapManager").FLOORS_PER_ACT
        run.currentNode = { type = "boss" }
        g.enemy.health = 0
        t:truthy("matar o chefe final e vitoria", g:checkVictory())
        t:falsy("vitoria APAGA o save (sem Continuar pro chefe ja vencido)", SaveManager.hasRun())
        g:checkpointRun()
        t:falsy("e nenhum checkpoint posterior o recria", SaveManager.hasRun())
    end

    -- 4. "Salvei no acampamento/evento/loja e o Continuar abriu uma LUTA."
    --    "Saí no cash out e refiz a batalha já vencida com o ouro no bolso."
    do
        local cases = {
            { stage = nil,          want = "battle", why = "save antigo sem estagio = luta (compat)" },
            { stage = "battle",     want = "battle", why = "no meio da luta = refaz a luta" },
            { stage = "cashout",    want = "cashout", why = "venceu e saiu antes do Resgatar = cash out" },
            { stage = "rewards",    want = "rewards", why = "resgatou e saiu = recompensa, nao luta" },
            { stage = "rest",       want = "rest", why = "acampamento reabre o acampamento" },
            { stage = "event",      want = "event", why = "evento reabre o evento" },
            { stage = "shop",       want = "shop", why = "loja reabre a loja" },
            { stage = "event_done", want = "map", why = "escolha do evento feita NAO reabre (aplicaria 2x)" },
            { stage = "rest_done",  want = "map", why = "fogueira usada NAO reabre (curaria 2x)" },
        }
        for _, c in ipairs(cases) do
            t:eq(c.why, ResumeFlow.stageAction({ stage = c.stage }), c.want)
        end
        t:eq("encruzilhada pendente vence qualquer estagio",
            ResumeFlow.stageAction({ stage = "rewards", pendingNodes = { { type = "battle" } } }), "fork")
        t:eq("estagio desconhecido segue pra encruzilhada (nunca luta fantasma)",
            ResumeFlow.stageAction({ stage = "???" }), "map")
        t:eq("sem run, nada a reabrir alem da luta padrao", ResumeFlow.stageAction(nil), "battle")
    end

    -- 5. O estágio VIAJA no save (sem isto o item 4 seria decoração).
    do
        local g = TK.newRunGame("warrior")
        local run = g.runManager.currentRun
        run.stage, run.stageEventId = "event", "altar"
        g:checkpointRun()
        local g2 = Game:new()
        t:truthy("save recarrega", g2.runManager:loadRun() == true)
        t:eq("estagio sobrevive ao save", g2.runManager.currentRun.stage, "event")
        t:eq("o evento salvo sobrevive (reabre o MESMO)", g2.runManager.currentRun.stageEventId, "altar")
        SaveManager.deleteRun()
    end

    -- 6. Evento salvo é encontrável por id.
    do
        local Events = require("src.data.events")
        local any = Events.POOL[1]
        t:truthy("Events.get acha evento do pool por id", Events.get(any.id) == any)
        t:falsy("Events.get de id inexistente devolve nil", Events.get("nao_existe"))
    end

    -- 7. Escolher a opção do evento / usar a fogueira marca o nó como feito.
    do
        local g = TK.newRunGame("warrior")
        local run = g.runManager.currentRun
        local RestScreen = require("components.RestScreen")
        local rs = RestScreen:new()
        run.stage = "rest"
        rs:show(g, function() end)
        rs:doHeal()
        t:eq("curar na fogueira marca 'rest_done'", run.stage, "rest_done")
        rs:hide()

        run.stage = "shop"
        rs:show(g, function() end, "forge")
        rs:_markCampUsed()
        t:eq("picker da loja NAO mexe no estagio", run.stage, "shop")
        rs:hide()

        local EventScreen = require("components.EventScreen")
        local es = EventScreen:new()
        local Events = require("src.data.events")
        run.stage = "event"
        es:show(Events.POOL[1], g, function() end)
        t:truthy("(pre) evento tem botoes", es.buttons and #es.buttons > 0)
        es.buttons[#es.buttons].onClick()
        t:eq("escolher a opcao marca 'event_done'", run.stage, "event_done")
        es:hide()
    end

    -- 7b. "O evento me matou e a run seguiu a 0 HP" / "cliquei numa opção
    --     sem ouro, ela subiu -$20 e gastou o evento sem cobrar nada".
    do
        local Events = require("src.data.events")
        local g = TK.newRunGame("warrior")
        local altar = Events.get("altar_proibido")
        local sac = altar.options[1]
        g.player.health = 8
        t:falsy("altar (8 HP) com 8 de vida: opcao IMPAGAVEL", Events.canAfford(sac, g))
        g.player.health = 9
        t:truthy("altar com 9 de vida: pagavel", Events.canAfford(sac, g))
        g.player.armor = 20
        sac.apply(g)
        t:eq("custo de sangue ignora armadura e deixa 1 de vida", g.player.health, 1)
        t:truthy("evento nunca mata", g.player:isAlive())

        local aposta = Events.get("aposta_ouro").options[1]
        g.economySystem.currentGold = 5
        t:falsy("aposta de $20 com $5: impagavel", Events.canAfford(aposta, g))

        local EventScreen = require("components.EventScreen")
        local es = EventScreen:new()
        es:show(Events.get("aposta_ouro"), g, function() end)
        t:truthy("botao da opcao impagavel nasce DESABILITADO", es.buttons[1].disabled)
        es:keypressed("1")
        t:truthy("atalho 1 nao escolhe opcao desabilitada", #es.buttons > 0)
        es:hide()
    end

    -- 7b2. Bigorna forja a CÓPIA sorteada (forja é por cópia, não por id).
    do
        local Events = require("src.data.events")
        local anvil = Events.get("bigorna_antiga").options[1]
        local hitHigh = false
        for seed = 1, 12 do
            TK.seedRng(seed)
            local g = TK.newRunGame("warrior")
            local run = g.runManager.currentRun
            local id = (type(run.currentDeck[1]) == "table") and run.currentDeck[1].id or run.currentDeck[1]
            run.currentDeck = { { id = id, up = 2 }, { id = id, up = 0 } }
            anvil.apply(g)
            if g.runManager:getEntryLevel(run.currentDeck[1]) == 3 then hitHigh = true end
        end
        t:truthy("bigorna as vezes forja a copia JA forjada (sorteio por copia, nao 'a de menor nivel do id')", hitHigh)
        TK.seedRng(20261010)
    end

    -- 7c. "Comprei a Forja, apertei Voltar e perdi o ouro."
    do
        local g = TK.newRunGame("warrior")
        local CardRewardScreen = require("components.CardRewardScreen")
        local scr = CardRewardScreen:new(g.shopSystem)
        scr:show(g, function() end, function() end, "shop")
        local run = g.runManager.currentRun
        run.paidForges = 2
        local offer = { id = "forge", effect = "forge_card", cost = 7, purchased = true, type = "upgrade" }
        local gold0 = g.economySystem.currentGold
        -- A loja abre o picker generico (_G.openCardPicker) e decide o estorno
        -- pela assinatura do deck: se nada mudou, o jogador saiu pelo Voltar.
        local prev = _G.openCardPicker
        _G.openCardPicker = function(_, onDone) onDone(false) end   -- jogador apertou Voltar
        scr:applyUpgrade(offer)
        t:eq("Voltar sem forjar devolve o ouro", g.economySystem.currentGold - gold0, 7)
        t:falsy("e a oferta volta a ficar a venda", offer.purchased)
        t:eq("e o preco da proxima forja nao sobe por uma forja que nao houve", run.paidForges, 2)
        _G.openCardPicker = function(_, onDone)                      -- forjou de verdade
            g.runManager:upgradeCardAt(1)
            onDone(true)
        end
        offer.purchased = true
        scr:applyUpgrade(offer)
        t:eq("forja feita: nada devolvido", g.economySystem.currentGold - gold0, 7)
        t:eq("forja feita conta no preco", run.paidForges, 3)
        _G.openCardPicker = prev
        scr:hide()
    end

    -- 7d. Abandonar pelo pause rende XP de maestria uma vez e apaga o save.
    do
        local g = TK.newRunGame("warrior")
        local run = g.runManager.currentRun
        run.actNumber, run.floorInAct = 2, 4
        local UnlockSystem = require("src.systems.UnlockSystem")
        -- Perfil FALSO: o XP acumulado pelas suites anteriores pode ter
        -- maxado o guerreiro, e no nivel maximo o XP nao cresce mais.
        local ProfileStats = require("engine.ProfileStats")
        local prevProfile = ProfileStats._swapForTests({ runs = 0, wins = 0 })
        UnlockSystem._resetForTests()
        UnlockSystem.ensure()
        local before = UnlockSystem.getClassMastery("warrior").xp
        g:abandonRun()
        local after = UnlockSystem.getClassMastery("warrior").xp
        t:truthy("abandonar rende XP de maestria (StS: abandonar = morrer)", after > before)
        t:falsy("abandonar apaga o save", g.runManager:hasSavedRun())
        g:abandonRun()
        t:eq("abandonar de novo nao paga XP duas vezes", UnlockSystem.getClassMastery("warrior").xp, after)
        ProfileStats._swapForTests(prevProfile)
        UnlockSystem._resetForTests()
        UnlockSystem.setOverrideAll(true)   -- todo arg de tool roda com o catalogo inteiro
    end

    -- 8. advanceFloorInAct sem argumento usa a fonte única de atos.
    do
        local g = TK.newRunGame("warrior")
        local run = g.runManager.currentRun
        local MapManager = require("src.systems.MapManager")
        run.actNumber = Config.TotalActs
        run.floorInAct = MapManager.FLOORS_PER_ACT
        t:eq("so passa pro endless DEPOIS do ultimo ato de Config.TotalActs",
            g.runManager:advanceFloorInAct(), "endless_start")
        run.endlessMode, run.actNumber, run.floorInAct = false, 1, MapManager.FLOORS_PER_ACT
        t:eq("ato 1 completo vira ato 2", g.runManager:advanceFloorInAct(), "act_complete")
    end

    -- 9. InputFocus.hideAll fecha toda tela registrada (menu nunca nasce morto).
    do
        local IF = require("src.ui.InputFocus")
        IF.clear()
        local a = { v = true }
        function a:isVisible() return self.v end
        function a:hide() self.v = false end
        local b = { v = true }
        function b:isVisible() return self.v end
        function b:hide() self.v = false end
        IF.register("rest", a, { keepChrome = true })
        IF.register("pause", b)
        t:eq("hideAll fechou as duas telas", IF.hideAll(), 2)
        t:falsy("cobertura (descanso) fechada", a:isVisible())
        t:falsy("modal (pausa) fechada", b:isVisible())
        t:eq("sem tela visivel, o foco volta pro menu", IF.activeName(), nil)

        -- "Morri com o menu de pausa aberto": modal sobre a luta CONGELA o combate.
        b.v = true
        t:truthy("pausa aberta na luta congela o combate", IF.freezesCombat("playing"))
        t:falsy("pausa fora da luta nao congela nada", IF.freezesCombat("mapSelection"))
        b.v = false
        t:falsy("pausa fechada: o combate segue", IF.freezesCombat("playing"))
        a.v = true
        t:falsy("cobertura (descanso) nao congela a luta", IF.freezesCombat("playing"))
        a.v = false
        IF.clear()
    end

    return t:done()
end

return M
