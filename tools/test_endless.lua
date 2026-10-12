-- tools/test_endless.lua
-- O ENDLESS É ALCANÇÁVEL a partir da vitória (auditoria Out/2026, BLOCKER).
--
-- O defeito: depois do chefe final, checkVictory apagava o save e a tela de
-- vitória só oferecia "jogar de novo"/menu. O único lugar que ligava o
-- endlessMode era RunManager:advanceFloorInAct — que nunca mais rodava depois
-- do último chefe. Resultado: a conquista "Além da Página" (andar 10 do
-- endless) era impossível, e o XP por andar de endless era código morto.
--
-- O contrato travado aqui:
--   1. a vitória é registrada UMA vez (perfil + maestria) no checkVictory;
--   2. "Seguir no Endless" (Game:enterEndless) só funciona DEPOIS disso e
--      mantém a run viva — salva, retoma, avança andares, a dificuldade cresce;
--   3. morrer (ou abandonar) no endless NÃO conta outra vitória nem uma
--      derrota: só o XP dos andares extras;
--   4. o andar 10 do endless é alcançável e dispara a conquista.
--
--   love . test_one test_endless

local TK = require("tools.testkit")

local M = {}

local function bossKilled(g)
    local Config = require("src.core.Config")
    local MapManager = require("src.systems.MapManager")
    local run = g.runManager.currentRun
    run.actNumber = Config.TotalActs
    run.floorInAct = MapManager.FLOORS_PER_ACT
    run.currentFloor = Config.TotalActs * MapManager.FLOORS_PER_ACT
    run.currentNode = { type = "boss" }
    run.pendingNodes = nil
    run.endlessMode = false
    g.enemy.isBoss = true
    g.enemy.health = 0
    return run
end

function M.run()
    local t = TK.new("endless")
    TK.bootstrap()
    TK.seedRng(4242)
    local PS = require("engine.ProfileStats")
    local SaveManager = require("engine.SaveManager")
    local UnlockSystem = require("src.systems.UnlockSystem")
    local AS = require("src.systems.AchievementSystem")
    local ActSystem = require("src.systems.ActSystem")
    local Config = require("src.core.Config")
    local Game = require("src.core.Game")
    local EndScreens = require("src.scenes.EndScreens")
    local Data = require("src.data.unlocks")

    local prevProfile = PS._swapForTests({ runs = 1, wins = 0, losses = 0 })
    local ok, err = pcall(function()
        SaveManager.deleteRun()

        -- ===== 1. Vitória registrada uma vez =====
        local g = TK.newRunGame("warrior")
        local run = bossKilled(g)
        t:truthy("chefe final morto: checkVictory reconhece", g:checkVictory())
        t:eq("vitoria contada no perfil", PS.get().wins, 1)
        t:truthy("a run sabe que venceu a campanha (viaja no save)", run.campaignWon)
        t:truthy("maestria recebeu o resultado de vitoria",
            UnlockSystem.lastResult and UnlockSystem.lastResult.victory)
        g:checkVictory(); g:checkVictory()
        t:eq("checkVictory repetido (todo frame) NAO conta outra vitoria", PS.get().wins, 1)
        t:falsy("o save da run foi apagado na vitoria", SaveManager.hasRun())
        t:falsy("a vitoria NAO liga o endless sozinha (defect_doctrine 14)", run.endlessMode)

        -- ===== 2. A tela de vitória oferece o Endless =====
        t:truthy("tela de vitoria oferece o Endless", EndScreens.canEndless(g))
        local acts = EndScreens.actions("victory", g)
        t:eq("primeiro botao (primario) da vitoria e o Endless", acts[1].key, "endless")
        local over = EndScreens.actions("gameOver", g)
        for _, a in ipairs(over) do
            t:truthy("game over nao oferece endless (" .. a.key .. ")", a.key ~= "endless")
        end

        -- enterEndless antes da vitória: recusa
        local g0 = TK.newRunGame("mage")
        t:falsy("enterEndless SEM vitoria registrada recusa", g0:enterEndless())
        t:falsy("... e nao liga o modo", g0.runManager.currentRun.endlessMode)

        -- ===== 3. Entrar no Endless =====
        t:truthy("enterEndless depois da vitoria aceita", g:enterEndless())
        t:truthy("endlessMode ligado", run.endlessMode)
        t:eq("gameState volta a ser jogavel", g.gameState, "playing")
        t:falsy("enterEndless duas vezes recusa", g:enterEndless())
        t:falsy("checkVictory nao dispara de novo no endless", g:checkVictory())
        t:eq("perfil continua com UMA vitoria", PS.get().wins, 1)
        t:eq("nenhuma derrota contada", PS.get().losses, 0)
        t:falsy("vitoria ja nao oferece Endless depois de entrar", EndScreens.canEndless(g))

        -- A encruzilhada depois da recompensa avança pro andar 1 do endless.
        t:eq("fim do ultimo ato vira 'endless_start'",
            g.runManager:advanceFloorInAct(), "endless_start")
        t:eq("ato endless = TotalActs+1", run.actNumber, Config.TotalActs + 1)
        t:eq("floorsInEndless = 1 no primeiro andar", run.floorsInEndless, 1)
        t:eq("mesma conta da conquista (AchievementSystem.endlessFloor)",
            AS.endlessFloor(run), 1)

        -- Salva e retoma
        run.stage = "fork"
        g:checkpointRun()
        t:truthy("a run do endless SALVA (checkpointRun aceita)", SaveManager.hasRun())
        local data = SaveManager.loadRun()
        t:truthy("save guarda endlessMode", data and data.endlessMode)
        t:truthy("save guarda campaignWon", data and data.campaignWon)
        t:eq("save guarda floorsInEndless", data and data.floorsInEndless, 1)

        -- Ciclos de 8: andar 10 alcançável, aviso de desbloqueio só uma vez
        local statuses = {}
        for _ = 2, 10 do
            local st = g.runManager:advanceFloorInAct()
            statuses[st] = (statuses[st] or 0) + 1
        end
        t:eq("andar 10 do endless alcancado", run.floorsInEndless, 10)
        t:eq("'endless_start' NAO repete a cada ciclo", statuses.endless_start, nil)
        t:eq("virada de ciclo vira 'endless_cycle'", statuses.endless_cycle, 1)

        -- Conquista Além da Página
        local s = PS.get()
        s.achievements, s.achievementDates = {}, {}
        AS._resetTransient()
        run.currentNode = { type = "battle" }
        AS.onBattleWon(g)
        t:truthy("conquista alem_da_pagina dispara no andar 10 do endless",
            AS.isUnlocked("alem_da_pagina"))

        -- Dificuldade cresce pelo andar ABSOLUTO (não zera a cada ciclo)
        local a1 = ActSystem.getEnemyStats(Config.TotalActs + 1, 1, "battle", 1)
        local a9 = ActSystem.getEnemyStats(Config.TotalActs + 1, 1, "battle", 9)
        t:truthy(("inimigo do andar 9 do endless e mais forte que o do 1 (%d > %d)")
            :format(a9.health, a1.health), a9.health > a1.health)

        -- ===== 4. Morte no endless (após retomar o save) =====
        g:checkpointRun()
        local g2 = Game:new()
        t:truthy("Continuar carrega a run do endless", g2.runManager:loadRun())
        g2:resumeRun()
        local run2 = g2.runManager.currentRun
        t:truthy("retomada segue no endless", run2.endlessMode)
        t:eq("retomada mantem o andar do endless", run2.floorsInEndless, 10)
        g2.player.health = 0
        t:truthy("morte no endless = game over", g2:checkGameOver())
        t:eq("morte no endless NAO conta outra vitoria", PS.get().wins, 1)
        t:eq("morte no endless NAO conta derrota (runs = wins + losses)", PS.get().losses, 0)
        local res = UnlockSystem.lastResult
        t:falsy("resultado do endless nao e vitoria", res and res.victory)
        t:eq("XP da morte no endless = andares extras",
            res and res.xpGained, math.max(Data.XP.MINIMUM, 10 * Data.XP.PER_ENDLESS))
        t:falsy("save apagado na morte do endless", SaveManager.hasRun())
        g2:checkGameOver()
        t:eq("checkGameOver repetido nao conta nada", PS.get().losses, 0)

        -- Abandono no endless: mesmo tratamento
        local g3 = TK.newRunGame("rogue")
        local run3 = bossKilled(g3)
        g3:checkVictory()
        local winsAntes = PS.get().wins
        g3:enterEndless()
        g3.runManager:advanceFloorInAct()
        g3:abandonRun()
        t:eq("abandono no endless nao conta derrota", PS.get().losses, 0)
        t:eq("abandono no endless nao conta outra vitoria", PS.get().wins, winsAntes)
        t:truthy("(run3 estava no endless)", run3.endlessMode)

        -- Sanidade: derrota comum continua contando
        local g4 = TK.newRunGame("warrior")
        g4.player.health = 0
        g4:checkGameOver()
        t:eq("derrota fora do endless continua contando", PS.get().losses, 1)

        -- Relógio/turnos da run (resumo da tela final)
        local g5 = TK.newRunGame("warrior")
        g5:tickRunClock(2.5, "playing")
        g5:tickRunClock(10, "menu")
        g5:tickRunClock(10, "victory")
        t:near("relogio da run so conta em jogo", g5.runManager.currentRun.playSeconds, 2.5, 1e-6)
    end)
    PS._swapForTests(prevProfile)
    SaveManager.deleteRun()
    t:truthy("suite sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
