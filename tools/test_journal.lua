-- tools/test_journal.lua
-- Roteiro da run (RunManager journal*): abertura/fecho por nó, captura das
-- escolhas pelos sinks, idempotência do journalEnd, backfill de mapHistory,
-- endless (o par ato/andar repete) e sobrevivência ao save/load.
--   love . test_one test_journal

local TK = require("tools.testkit")

local M = {}

function M.run()
    TK.bootstrap()
    TK.seedRng(11)
    local t = TK.new("roteiro da run")

    -- ===== ciclo de vida de uma entrada =====
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        run.mapHistory, run.journal, run.journalOpen = {}, {}, nil

        -- Fora de nó: no-op legítimo (deck inicial), não cria entrada.
        rm:journalNote({ kind = "card", id = "warrior_strike" })
        t:eq("nota fora de nó não cria entrada", #rm:getJournal(), 0)

        run.actNumber, run.floorInAct, run.currentFloor = 1, 3, 3
        rm:journalBegin({ type = "shop" }, { hp = 50, maxHp = 60, gold = 40 })
        t:eq("journalBegin cria a entrada", #run.journal, 1)
        t:eq("hp de entrada gravado", run.journal[1].hpIn, 50)
        t:eq("ato gravado", run.journal[1].act, 1)
        t:eq("andar gravado", run.journal[1].floor, 3)

        rm:journalNote({ kind = "card", id = "warrior_bash" })
        rm:journalNote({ kind = "remove", id = "warrior_defend" })
        t:eq("duas escolhas anotadas no nó aberto", #run.journal[1].gains, 2)

        rm:journalEvent("evt_x", 2, "Tocar o altar")
        t:eq("opção do evento gravada", run.journal[1].optionLabel, "Tocar o altar")

        t:truthy("journalEnd fecha", rm:journalEnd({ hp = 44, gold = 12 }))
        t:eq("hp de saída gravado", run.journal[1].hpOut, 44)
        t:eq("ouro de saída gravado", run.journal[1].goldOut, 12)

        -- Idempotente: showMapSelection pode rodar duas vezes.
        t:falsy("journalEnd repetido é no-op", rm:journalEnd({ hp = 1, gold = 1 }))
        t:eq("segundo journalEnd não sobrescreve", run.journal[1].hpOut, 44)
        t:eq("nenhuma entrada extra criada", #run.journal, 1)

        -- Depois de fechado, nota volta a ser no-op.
        rm:journalNote({ kind = "card", id = "warrior_strike" })
        t:eq("nota após o fecho não entra no nó", #run.journal[1].gains, 2)
    end

    -- ===== os sinks do RunManager alimentam o nó aberto =====
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
        rm:journalBegin({ type = "rest" }, { hp = 30, maxHp = 60, gold = 20 })

        rm:addCardToDeck("warrior_bash")
        rm:upgradeCard("warrior_strike")
        rm:removeCardFromDeck("warrior_bash")

        local kinds = {}
        for _, g in ipairs(run.journal[1].gains) do
            kinds[g.kind] = (kinds[g.kind] or 0) + 1
        end
        t:eq("addCardToDeck anotou a carta", kinds.card, 1)
        t:eq("upgradeCard anotou a forja", kinds.forge, 1)
        t:eq("removeCardFromDeck anotou a remoção", kinds.remove, 1)

        -- registerPaidForge NÃO anota (duplicaria a forja de upgradeCard).
        local before = #run.journal[1].gains
        rm:registerPaidForge()
        t:eq("registerPaidForge não duplica a forja", #run.journal[1].gains, before)
    end

    -- ===== chooseNode abre a entrada =====
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
        rm:generateNextNodes(3)
        local node = rm:chooseNode(1, { hp = 60, maxHp = 60, gold = 10 })
        t:truthy("chooseNode devolveu o nó", node)
        t:eq("chooseNode abriu a entrada do roteiro", #run.journal, 1)
        t:eq("tipo do nó bate com o escolhido", run.journal[1].type, node.type)
        t:truthy("entrada do nó atual em aberto", rm:isJournalEntryOpen(run.journal[1]))
    end

    -- ===== nó que resolve sem passar pelo journalEnd =====
    -- O autoplay (tools/autoplay.lua) chama chooseNode direto e nunca fecha a
    -- entrada. Sem o auto-fecho do journalBegin isso empilharia entradas
    -- zumbis e todas as escolhas seguintes cairiam no nó errado.
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        run.mapHistory, run.journal, run.journalOpen = {}, {}, nil

        run.actNumber, run.floorInAct, run.currentFloor = 1, 1, 1
        rm:journalBegin({ type = "battle" }, { hp = 60, maxHp = 60, gold = 10 })
        rm:journalNote({ kind = "card", id = "warrior_bash" })
        -- (sem journalEnd — o nó "some")
        run.floorInAct, run.currentFloor = 2, 2
        rm:journalBegin({ type = "shop" }, { hp = 52, maxHp = 60, gold = 30 })
        rm:journalNote({ kind = "card", id = "warrior_strike" })

        t:eq("duas entradas, sem zumbi", #run.journal, 2)
        t:eq("entrada esquecida foi fechada", run.journalOpen, 2)
        t:eq("escolha do nó 1 ficou no nó 1", #run.journal[1].gains, 1)
        t:eq("escolha do nó 2 ficou no nó 2", #run.journal[2].gains, 1)
        t:eq("nó 2 continua aberto", run.journal[2].hpOut, nil)
    end

    -- ===== backfill: run que começou antes do roteiro existir =====
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        -- Save legado: mapHistory cheio, journal inexistente.
        run.journal, run.journalOpen = nil, nil
        run.mapHistory = {
            { actNumber = 1, floorInAct = 1, type = "battle" },
            { actNumber = 1, floorInAct = 2, type = "shop" },
        }
        local j = rm:getJournal()
        t:eq("backfill recria os nós só do mapHistory", #j, 2)
        t:truthy("entrada de backfill marcada como parcial", j[1].partial)
        t:eq("tipo preservado no backfill", j[2].type, "shop")

        -- Run em andamento: os nós novos entram completos e NÃO duplicam.
        run.journal = {}
        run.actNumber, run.floorInAct, run.currentFloor = 1, 3, 3
        table.insert(run.mapHistory, { actNumber = 1, floorInAct = 3, type = "rest" })
        rm:journalBegin({ type = "rest" }, { hp = 55, maxHp = 60, gold = 30 })
        rm:journalEnd({ hp = 60, gold = 30 })

        j = rm:getJournal()
        t:eq("sem duplicata entre mapHistory e journal", #j, 3)
        t:truthy("nó antigo continua parcial", j[1].partial)
        t:truthy("segundo nó antigo continua parcial", j[2].partial)
        t:falsy("nó novo tem detalhes", j[3].partial)
        t:eq("nó novo carrega o resultado", j[3].hpOut, 60)
    end

    -- ===== endless: (ato, andar) repete e o roteiro não perde nós =====
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
        run.endlessMode = true
        for i = 1, 3 do
            run.actNumber, run.floorInAct, run.currentFloor = 4, 1, 24 + i
            table.insert(run.mapHistory, { actNumber = 4, floorInAct = 1, type = "battle" })
            rm:journalBegin({ type = "battle" }, { hp = 40, maxHp = 60, gold = 10 })
            rm:journalEnd({ hp = 35, gold = 20 })
        end
        t:eq("três nós no mesmo (ato, andar) sobrevivem", #rm:getJournal(), 3)
    end

    -- ===== gatilho: clique no bloco de ATO da TopBar =====
    -- O bloco "ATO N / andar X" não tinha clique nenhum; a TopBar engolia o
    -- evento e devolvia true. Este teste fixa a zona: clicar no progresso
    -- chama o callback do Roteiro, e clicar no DECK continua chamando o dele.
    do
        local game = TK.newRunGame("warrior")
        local TopBar = require("components.TopBar")
        local bar = TopBar:new()
        bar:setGame(game)

        local hits = { act = 0, deck = 0 }
        bar:setActClickCallback(function() hits.act = hits.act + 1 end)
        bar:setDeckClickCallback(function() hits.deck = hits.deck + 1 end)

        local L = bar:_layout()
        t:truthy("TopBar expõe o bloco de progresso em run", L.progress ~= nil)
        if L.progress then
            local y = math.floor(bar.height / 2)
            bar:mousepressed(L.progress.x + L.progress.w / 2, y, 1)
            t:eq("clique no ATO abre o Roteiro", hits.act, 1)
            t:eq("clique no ATO não dispara o deck", hits.deck, 0)

            bar:mousepressed(L.deck.x + L.deck.w / 2, y, 1)
            t:eq("clique no DECK continua abrindo o deck", hits.deck, 1)
            t:eq("clique no DECK não dispara o Roteiro", hits.act, 1)

            -- Abaixo da barra não é zona da TopBar.
            bar:mousepressed(L.progress.x + L.progress.w / 2, bar.height + 40, 1)
            t:eq("clique fora da barra não abre nada", hits.act, 1)
        end

        -- A tela em si tem que abrir/fechar sem estado de run montado à mão.
        local screen = require("components.RunJournalScreen"):new()
        t:noerror("RunJournalScreen abre", function() screen:show(game) end)
        t:truthy("fica visível", screen:isVisible())
        t:noerror("layout resolve", function() screen:_layout() end)
        t:noerror("RunJournalScreen fecha", function() screen:hide() end)
        t:falsy("fica invisível", screen:isVisible())
    end

    -- ===== persistência: o roteiro viaja no save sem migration =====
    do
        local game = TK.newRunGame("warrior")
        local rm = game.runManager
        local run = rm.currentRun
        run.mapHistory, run.journal, run.journalOpen = {}, {}, nil
        run.actNumber, run.floorInAct, run.currentFloor = 2, 5, 13
        table.insert(run.mapHistory, { actNumber = 2, floorInAct = 5, type = "elite" })
        rm:journalBegin({ type = "elite" }, { hp = 44, maxHp = 60, gold = 77 })
        rm:journalNote({ kind = "forge", id = "warrior_strike", lvl = 3 })
        rm:journalEnd({ hp = 31, gold = 99 })
        t:truthy("saveRun ok", rm:saveRun())

        local game2 = TK.newRunGame("warrior")
        t:truthy("loadRun ok", game2.runManager:loadRun())
        local j = game2.runManager:getJournal()
        t:eq("roteiro sobreviveu ao save/load", #j, 1)
        t:eq("resultado sobreviveu", j[1].hpOut, 31)
        t:eq("escolha sobreviveu", j[1].gains[1].kind, "forge")
        t:eq("nível da forja sobreviveu", j[1].gains[1].lvl, 3)
        game2.runManager:deleteSave()
    end

    return t:done()
end

return M
