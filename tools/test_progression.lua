local TK = require("tools.testkit")
local RunManager = require("src.systems.RunManager")
local MapManager = require("src.systems.MapManager")
local ActSystem  = require("src.systems.ActSystem")
local Config     = require("src.core.Config")

local M = {}

function M.run()
    TK.bootstrap()
    TK.seedRng(4242)
    local t = TK.new("progressão: Run + Map + Act")

    local rm = RunManager:new()
    t:falsy("sem run ativa no new", rm:hasActiveRun())

    rm:startNewRun("warrior")
    t:truthy("hasActiveRun após startNewRun", rm:hasActiveRun())
    local run = rm.currentRun
    t:eq("run começa no ato 1", run.actNumber, 1)
    t:eq("run começa no andar 1", run.floorInAct, 1)
    t:eq("starter deck = 2 cartas", #run.currentDeck, 2)
    t:eq("ouro inicial da run = 99", run.playerState.gold, 99)

    t:throws("startNewRun com classe inválida lança", function()
        RunManager:new():startNewRun("classe_inexistente")
    end)

    rm:addCardToDeck("warrior_bash")
    t:eq("addCardToDeck cresce o deck", #run.currentDeck, 3)
    local ids = rm:getDeckCardIds()
    t:eq("getDeckCardIds conta todas", #ids, 3)

    rm:addCardToDeck("warrior_strike", { edition = "foil" })
    local last = run.currentDeck[#run.currentDeck]
    t:eq("carta com meta é tabela {id,...}", type(last), "table")
    t:eq("meta.edition preservada", last.edition, "foil")

    local deckSizeBefore = #run.currentDeck
    local jokAdded = rm:addJokerToRun("joker_001")
    t:truthy("addJokerToRun ok", jokAdded)
    t:eq("joker NÃO entra no currentDeck", #run.currentDeck, deckSizeBefore)
    t:eq("joker vai pra run.jokers", #run.jokers, 1)
    rm:removeJokerFromRun("joker_001")
    t:eq("removeJokerFromRun esvazia", #run.jokers, 0)

    local n = #run.currentDeck
    rm:removeCardFromDeck("warrior_bash")
    t:eq("removeCardFromDeck remove 1", #run.currentDeck, n - 1)

    local rm2 = RunManager:new(); rm2:startNewRun("mage")
    rm2.currentRun.floorInAct = 3
    t:eq("avanço normal retorna 'advanced'", rm2:advanceFloorInAct(), "advanced")
    t:eq("andar incrementou", rm2.currentRun.floorInAct, 4)

    rm2.currentRun.floorInAct = 8; rm2.currentRun.actNumber = 1
    t:eq("fim de ato (não-final) retorna 'act_complete'", rm2:advanceFloorInAct(), "act_complete")
    t:eq("virou ato 2", rm2.currentRun.actNumber, 2)
    t:eq("andar reset p/ 1", rm2.currentRun.floorInAct, 1)

    local rmFull = RunManager:new(); rmFull:startNewRun("warrior")
    for ato = 1, Config.TotalActs - 1 do
        rmFull.currentRun.actNumber = ato
        rmFull.currentRun.floorInAct = MapManager.FLOORS_PER_ACT
        local st = rmFull:advanceFloorInAct()
        t:eq("ato " .. ato .. " -> " .. (ato + 1) .. " é 'act_complete'",
            st, "act_complete")
        t:falsy("ato " .. ato .. " NAO liga o endless (jogo ficaria "
            .. "invencivel: checkVictory retorna false em endless)",
            rmFull.currentRun.endlessMode)
    end

    rm2.currentRun.floorInAct = 8
    rm2.currentRun.actNumber = Config.TotalActs
    t:eq("fim do ato final retorna 'endless_start'", rm2:advanceFloorInAct(), "endless_start")
    t:truthy("endlessMode ativado", rm2.currentRun.endlessMode)

    t:eq("FLOORS_PER_ACT = 8", MapManager.FLOORS_PER_ACT, 8)

    local nodes = MapManager.generate(3, 1, 3)
    t:eq("generate andar 3 -> 3 nós", #nodes, 3)
    t:truthy("nó tem .type", nodes[1] and nodes[1].type ~= nil)

    local boss = MapManager.generate(8, 1, 3)
    t:eq("andar 8 -> 1 nó forçado", #boss, 1)
    t:eq("andar 8 -> BOSS", boss[1].type, "boss")

    local mini = MapManager.generate(7, 1, 3)
    t:eq("andar 7 -> MINI-BOSS", mini[1].type, "mini_boss")

    local function fa(g) local a, f = MapManager.floorToAct(g); return a, f end
    local a1, f1 = fa(1);  t:truthy("floor 1 -> ato 1 andar 1", a1 == 1 and f1 == 1)
    local a8, f8 = fa(8);  t:truthy("floor 8 -> ato 1 andar 8", a8 == 1 and f8 == 8)
    local a9, f9 = fa(9);  t:truthy("floor 9 -> ato 2 andar 1", a9 == 2 and f9 == 1)
    local a24, f24 = fa(24); t:truthy("floor 24 -> ato 3 andar 8", a24 == 3 and f24 == 8)

    local savedPower = Config.Game.ENEMY_POWER
    local savedByActRaw = Config.Game.ENEMY_POWER_BY_ACT
    Config.Game.ENEMY_POWER = nil
    Config.Game.ENEMY_POWER_BY_ACT = nil
    local s = ActSystem.getEnemyStats(1, 1, "battle")
    t:eq("ato1 andar1 battle HP = 14", s.health, 14)
    t:eq("ato1 andar1 battle dano = 4", s.damage, 4)
    t:eq("ato1 andar8 battle HP = 56", ActSystem.getEnemyStats(1, 8, "battle").health, 56)

    t:eq("boss ato1 HP = 110", ActSystem.getEnemyStats(1, 8, "boss").health, 110)
    t:eq("boss ato1 dano = 12", ActSystem.getEnemyStats(1, 8, "boss").damage, 12)
    t:eq("boss ato3 HP = 420", ActSystem.getEnemyStats(3, 8, "boss").health, 420)

    t:eq("mini_boss ato1 HP = floor(110*0.7)=77", ActSystem.getEnemyStats(1, 7, "mini_boss").health, 77)
    t:eq("mini_boss ato1 dano = floor(12*0.8)=9", ActSystem.getEnemyStats(1, 7, "mini_boss").damage, 9)

    t:eq("elite ato1 andar1 HP = floor(14*1.4)=19", ActSystem.getEnemyStats(1, 1, "elite").health, 19)
    Config.Game.ENEMY_POWER = { damage = 0.5, health = 0.5 }
    local half = ActSystem.getEnemyStats(1, 8, "boss")
    t:eq("ENEMY_POWER escala a vida", half.health, math.floor(110 * 0.5))
    t:eq("ENEMY_POWER escala o dano", half.damage, math.floor(12 * 0.5))
    local savedByAct = savedByActRaw
    Config.Game.ENEMY_POWER_BY_ACT = { [1] = { damage = 0.5, health = 0.5 }, [6] = { damage = 2, health = 2 } }
    t:eq("ENEMY_POWER_BY_ACT compoe a vida (ato 1)", ActSystem.getEnemyStats(1, 8, "boss").health, math.floor(110 * 0.25))
    t:eq("ENEMY_POWER_BY_ACT compoe o dano (ato 1)", ActSystem.getEnemyStats(1, 8, "boss").damage, math.floor(12 * 0.25))
    t:eq("ENEMY_POWER_BY_ACT ausente no ato = 1,0", ActSystem.getEnemyStats(2, 8, "boss").health, math.floor(220 * 0.5))
    local e7 = ActSystem.getEnemyStats(7, 1, "battle", 1)
    Config.Game.ENEMY_POWER = nil; Config.Game.ENEMY_POWER_BY_ACT = nil
    t:eq("ENEMY_POWER_BY_ACT: endless herda o ultimo ato", e7.health,
        ActSystem.getEnemyStats(7, 1, "battle", 1).health)
    Config.Game.ENEMY_POWER_BY_ACT = savedByAct
    Config.Game.ENEMY_POWER = savedPower

    local primeiroEndless = Config.TotalActs + 1
    local baseUltimo = ActSystem.getEnemyStats(Config.TotalActs, 1, "battle")
    local e1 = ActSystem.getEnemyStats(primeiroEndless, 1, "battle")
    t:eq("endless andar1 HP = base do ultimo ato", e1.health, baseUltimo.health)
    local e5 = ActSystem.getEnemyStats(primeiroEndless, 5, "battle")
    t:truthy("endless escala HP acima do andar 1", e5.health > e1.health)

    t:eq("cura inter-ato ato1 = 0.30", ActSystem.getInterActHealPercent(1), 0.30)
    t:eq("cura inter-ato ato2 = 0.40", ActSystem.getInterActHealPercent(2), 0.40)
    t:eq("cura inter-ato endless = 0",
        ActSystem.getInterActHealPercent(primeiroEndless), 0)
    t:eq("raridade ato1 common = 70", ActSystem.getRarityWeights(1).common, 70)
    t:eq("raridade endless legendary = 10",
        ActSystem.getRarityWeights(primeiroEndless).legendary, 10)

    return t:done()
end

return M
