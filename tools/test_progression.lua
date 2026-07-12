-- tools/test_progression.lua
-- Progressão da run: RunManager (deck/jokers/atos), MapManager (nós),
-- ActSystem (curvas de HP/dano por ato/andar, endless, cura inter-ato).
-- Conferido em RunManager.lua, MapManager.lua, ActSystem.lua.
--   love . test_progression

local TK = require("tools.testkit")
local RunManager = require("src.systems.RunManager")
local MapManager = require("src.systems.MapManager")
local ActSystem  = require("src.systems.ActSystem")

local M = {}

function M.run()
    TK.bootstrap()
    TK.seedRng(4242)
    local t = TK.new("progressão: Run + Map + Act")

    -- ===================== RUNMANAGER =====================
    local rm = RunManager:new()
    t:falsy("sem run ativa no new", rm:hasActiveRun())

    rm:startNewRun("warrior")
    t:truthy("hasActiveRun após startNewRun", rm:hasActiveRun())
    local run = rm.currentRun
    t:eq("run começa no ato 1", run.actNumber, 1)
    t:eq("run começa no andar 1", run.floorInAct, 1)
    t:eq("starter deck = 2 cartas", #run.currentDeck, 2)
    t:eq("ouro inicial da run = 99", run.playerState.gold, 99)

    -- classe inválida deve lançar erro
    t:throws("startNewRun com classe inválida lança", function()
        RunManager:new():startNewRun("classe_inexistente")
    end)

    -- addCardToDeck (string simples)
    rm:addCardToDeck("warrior_bash")
    t:eq("addCardToDeck cresce o deck", #run.currentDeck, 3)
    local ids = rm:getDeckCardIds()
    t:eq("getDeckCardIds conta todas", #ids, 3)

    -- addCardToDeck com meta (edition) guarda tabela {id, edition}
    rm:addCardToDeck("warrior_strike", { edition = "negative" })
    local last = run.currentDeck[#run.currentDeck]
    t:eq("carta com meta é tabela {id,...}", type(last), "table")
    t:eq("meta.edition preservada", last.edition, "negative")

    -- jokers: separados do deck (invariante Balatro)
    local deckSizeBefore = #run.currentDeck
    local jokAdded = rm:addJokerToRun("joker_001")
    t:truthy("addJokerToRun ok", jokAdded)
    t:eq("joker NÃO entra no currentDeck", #run.currentDeck, deckSizeBefore)
    t:eq("joker vai pra run.jokers", #run.jokers, 1)
    rm:removeJokerFromRun("joker_001")
    t:eq("removeJokerFromRun esvazia", #run.jokers, 0)

    -- removeCardFromDeck
    local n = #run.currentDeck
    rm:removeCardFromDeck("warrior_bash")
    t:eq("removeCardFromDeck remove 1", #run.currentDeck, n - 1)

    -- advanceFloorInAct: transições
    local rm2 = RunManager:new(); rm2:startNewRun("mage")
    rm2.currentRun.floorInAct = 3
    t:eq("avanço normal retorna 'advanced'", rm2:advanceFloorInAct(3), "advanced")
    t:eq("andar incrementou", rm2.currentRun.floorInAct, 4)

    rm2.currentRun.floorInAct = 8; rm2.currentRun.actNumber = 1
    t:eq("fim de ato (não-final) retorna 'act_complete'", rm2:advanceFloorInAct(3), "act_complete")
    t:eq("virou ato 2", rm2.currentRun.actNumber, 2)
    t:eq("andar reset p/ 1", rm2.currentRun.floorInAct, 1)

    rm2.currentRun.floorInAct = 8; rm2.currentRun.actNumber = 3
    t:eq("fim do ato final retorna 'endless_start'", rm2:advanceFloorInAct(3), "endless_start")
    t:truthy("endlessMode ativado", rm2.currentRun.endlessMode)

    -- ===================== MAPMANAGER =====================
    t:eq("FLOORS_PER_ACT = 8", MapManager.FLOORS_PER_ACT, 8)

    local nodes = MapManager.generate(3, 1, 3)
    t:eq("generate andar 3 -> 3 nós", #nodes, 3)
    t:truthy("nó tem .type", nodes[1] and nodes[1].type ~= nil)

    local boss = MapManager.generate(8, 1, 3)
    t:eq("andar 8 -> 1 nó forçado", #boss, 1)
    t:eq("andar 8 -> BOSS", boss[1].type, "boss")

    local mini = MapManager.generate(7, 1, 3)
    t:eq("andar 7 -> MINI-BOSS", mini[1].type, "mini_boss")

    -- floorToAct: floor global -> (ato, andar)
    local function fa(g) local a, f = MapManager.floorToAct(g); return a, f end
    local a1, f1 = fa(1);  t:truthy("floor 1 -> ato 1 andar 1", a1 == 1 and f1 == 1)
    local a8, f8 = fa(8);  t:truthy("floor 8 -> ato 1 andar 8", a8 == 1 and f8 == 8)
    local a9, f9 = fa(9);  t:truthy("floor 9 -> ato 2 andar 1", a9 == 2 and f9 == 1)
    local a24, f24 = fa(24); t:truthy("floor 24 -> ato 3 andar 8", a24 == 3 and f24 == 8)

    -- ===================== ACTSYSTEM =====================
    -- battle: curva do ato (HP e dano floored)
    local s = ActSystem.getEnemyStats(1, 1, "battle")
    t:eq("ato1 andar1 battle HP = 14", s.health, 14)
    t:eq("ato1 andar1 battle dano = 4", s.damage, 4)
    t:eq("ato1 andar8 battle HP = 56", ActSystem.getEnemyStats(1, 8, "battle").health, 56)

    -- boss: stats fixos
    t:eq("boss ato1 HP = 110", ActSystem.getEnemyStats(1, 8, "boss").health, 110)
    t:eq("boss ato1 dano = 12", ActSystem.getEnemyStats(1, 8, "boss").damage, 12)
    t:eq("boss ato3 HP = 420", ActSystem.getEnemyStats(3, 8, "boss").health, 420)

    -- mini_boss: 70% HP, 80% dano do boss
    t:eq("mini_boss ato1 HP = floor(110*0.7)=77", ActSystem.getEnemyStats(1, 7, "mini_boss").health, 77)
    t:eq("mini_boss ato1 dano = floor(12*0.8)=9", ActSystem.getEnemyStats(1, 7, "mini_boss").damage, 9)

    -- elite: multiplica battle
    t:eq("elite ato1 andar1 HP = floor(14*1.4)=19", ActSystem.getEnemyStats(1, 1, "elite").health, 19)

    -- endless: floor 1 == base do ato 3 (fator 1.0), depois escala 1.18^(f-1)
    local e1 = ActSystem.getEnemyStats(4, 1, "battle")
    t:eq("endless andar1 HP = base ato3 (165)", e1.health, 165)
    local e5 = ActSystem.getEnemyStats(4, 5, "battle")
    t:truthy("endless escala HP acima do andar 1", e5.health > e1.health)

    -- pesos de raridade e cura inter-ato
    t:eq("cura inter-ato ato1 = 0.30", ActSystem.getInterActHealPercent(1), 0.30)
    t:eq("cura inter-ato ato2 = 0.40", ActSystem.getInterActHealPercent(2), 0.40)
    t:eq("cura inter-ato endless = 0", ActSystem.getInterActHealPercent(4), 0)
    t:eq("raridade ato1 common = 70", ActSystem.getRarityWeights(1).common, 70)
    t:eq("raridade endless legendary = 10", ActSystem.getRarityWeights(4).legendary, 10)

    return t:done()
end

return M
