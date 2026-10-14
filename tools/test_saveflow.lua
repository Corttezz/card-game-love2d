local M = {}

local function fail(msg)
    print("[FAIL] " .. msg)
    M._failed = true
end

local function okp(cond, msg)
    if cond then print("[ok] " .. msg) else fail(msg) end
end

function M.run()
    M._failed = false
    local I18n = require("src.i18n.I18n")
    I18n.init()
    local Game = require("src.core.Game")
    local SaveManager = require("engine.SaveManager")

    print("=== limpeza inicial ===")
    SaveManager.deleteRun()
    okp(not SaveManager.hasRun(), "sem save no início")

    print("=== cenário A: progresso → abandono → run nova ===")
    local g1 = Game:new()
    g1:startNewRun("warrior")
    g1:startGame()
    local run1 = g1.runManager.currentRun
    run1.currentFloor = 5
    run1.actNumber = 2
    g1:addCardToRun("warrior_golpe_poderoso")
    g1:checkpointRun()
    okp(SaveManager.hasRun(), "checkpoint salvou run A no disco")

    g1.runManager:deleteSave()
    g1.runManager.currentRun = nil
    g1.runManager.isRunActive = false
    require("src.systems.Rng").clearActive()
    okp(not SaveManager.hasRun(),
        "abandono APAGOU o save do disco (deleteSave)")

    local g2 = Game:new()
    g2:startNewRun("mage")
    g2:startGame()
    local run2 = g2.runManager.currentRun
    okp(run2.classId == "mage", "run nova é da classe escolhida (mage)")
    okp((run2.currentFloor or 0) == 1,
        "run nova começa no andar 1 (era " .. tostring(run2.currentFloor) .. ")")
    okp((run2.actNumber or 0) == 1, "run nova começa no ato 1")
    okp(#run2.currentDeck <= 3,
        "deck novo é starter (" .. #run2.currentDeck .. " cartas)")

    print("=== cenário B: 'restart do app' com run B ativa salva ===")
    g2.runManager.currentRun.currentFloor = 3
    g2:checkpointRun()
    okp(SaveManager.hasRun(), "run B checkpointada")
    local g3 = Game:new()
    okp(not (g3.runManager:hasActiveRun()),
        "app reaberto: nenhuma run ativa em memória")
    okp(SaveManager.hasRun(), "app reaberto: save da run B existe (Continuar deve aparecer)")

    print("=== cenário C: com save antigo no disco, Jogar (não Continuar) ===")
    local g4 = Game:new()
    g4:startNewRun("rogue")
    g4:startGame()
    local run4 = g4.runManager.currentRun
    okp(run4.classId == "rogue", "Jogar com save antigo presente: classe nova vale")
    okp((run4.currentFloor or 0) == 1, "Jogar com save antigo: andar 1")
    okp(#run4.currentDeck <= 3, "Jogar com save antigo: deck starter")
    g4:checkpointRun()
    local data = SaveManager.loadRun()
    okp(data and data.classId == "rogue",
        "checkpoint da run nova SOBRESCREVEU o save antigo no disco")

    print("=== cenário D: abandono NÃO re-salva por callback retardatário ===")
    g4.runManager:deleteSave()
    g4.runManager.currentRun = nil
    g4.runManager.isRunActive = false
    g4:checkpointRun()
    okp(not SaveManager.hasRun(),
        "checkpoint retardatário pós-abandono NÃO ressuscita o save")

    SaveManager.deleteRun()
    print(M._failed and "=== RESULTADO: FALHOU ===" or "=== RESULTADO: TUDO OK ===")
    return not M._failed
end

return M
