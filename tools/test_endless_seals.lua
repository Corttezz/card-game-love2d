local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("pos-jogo: selos do grimorio + endless em ciclos")
    TK.bootstrap()
    local RM = require("src.systems.RunModifiers")
    local Config = require("src.core.Config")
    local ActSystem = require("src.systems.ActSystem")

    local base = { seal = 0 }
    local st = { health = 100, damage = 10 }
    local same = RM.enemyStats(base, st, "battle")
    t:eq("selo 0: vida igual", same.health, 100)
    t:eq("selo 0: dano igual", same.damage, 10)
    t:eq("selo 0: preco igual", RM.price(base, 9), 9)
    t:eq("selo 0: cura igual", RM.healMul(base, "rest"), 1)
    t:eq("selo 0: elite igual", RM.eliteWeightMul(base), 1)
    t:eq("selo 0: ouro inicial padrao", RM.startingGold(base, 10), 10)
    t:eq("selo 0: pontos x1", RM.scoreMul(base), 1)

    local s3 = { seal = 3 }
    t:near("selo 3 traz o 1 (elite x1.5)", RM.eliteWeightMul(s3), 1.5, 1e-9)
    t:near("selo 3 traz o 2 (fogueira x0.75)", RM.healMul(s3, "rest"), 0.75, 1e-9)
    t:near("selo 3: loja x1.15", RM.priceMul(s3), 1.15, 1e-9)
    t:eq("selo 3: carta $9 vira $11 (arredonda pra cima)", RM.price(s3, 9), 11)
    t:eq("selo 3 NAO traz o 4 (vida comum igual)", RM.enemyStats(s3, st, "battle").health, 100)
    local s10 = { seal = 10 }
    t:eq("selo 10: vida comum +10%", RM.enemyStats(s10, st, "battle").health, 110)
    t:eq("selo 10: chefe +15%", RM.enemyStats(s10, st, "boss").health, 115)
    t:eq("selo 10: elite dano x1.15 x1.10", RM.enemyStats(s10, st, "elite").damage,
        math.floor(10 * 1.15 * 1.10 + 0.5))
    t:eq("selo 10: comeca sem ouro", RM.startingGold(s10, 10), 0)
    t:eq("selo 10: vitoria -1", RM.victoryGoldDelta(s10), -1)
    t:eq("selo 10: recompensa -1 carta", RM.rewardCardsDelta(s10), -1)
    t:near("selo 10: pontos x2", RM.scoreMul(s10), 2.0, 1e-9)

    local g = TK.newRunGame("warrior")
    local g7 = (function()
        local Game = require("src.core.Game")
        local x = Game:new()
        x:startNewRun("warrior", { seal = 9 })
        x:startGame()
        return x
    end)()
    t:eq("run nasce com o selo escolhido", g7.runManager.currentRun.seal, 9)
    t:eq("Bolsa Leve: run nasce sem ouro", g7.economySystem.currentGold, 0)
    local v0 = g:_buildRoundEvalSources()[1].dollars
    local v7 = g7:_buildRoundEvalSources()[1].dollars
    t:eq("Bolsa Leve: vitoria paga $1 a menos", v7, v0 - 1)
    TK.seedRng(77)
    g7.shopSystem:setContext({ classId = "warrior", runManager = g7.runManager })
    g7.shopSystem:setMode("rewards")
    g7.shopSystem:generateOffers()
    t:eq("Escolha Curta: recompensa com 2 cartas", #g7.shopSystem:getCurrentOffers(), 2)
    local function shopTotal(game)
        TK.seedRng(4242)
        game.shopSystem:setContext({ classId = "warrior", runManager = game.runManager })
        game.shopSystem:setMode("shop")
        game.shopSystem:generateOffers()
        local sum = 0
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do sum = sum + (o.cost or 0) end
        return sum, game.shopSystem:getRefreshCost()
    end
    local p0, r0 = shopTotal(g)
    local p9, r9 = shopTotal(g7)
    t:truthy(("Mercado Caro: vitrine mais cara ($%d > $%d)"):format(p9, p0), p9 > p0)
    t:truthy("Mercado Caro: reroll mais caro", r9 > r0)
    local RestScreen = require("components.RestScreen")
    local rs = RestScreen.new and RestScreen:new() or setmetatable({}, { __index = RestScreen })
    rs.game = g7
    t:near("fogueira com Cura Escassa = 22.5%", rs:_healPct(), 0.225, 1e-9)
    rs.game = g
    t:near("fogueira base = 30%", rs:_healPct(), 0.30, 1e-9)
    local MapManager = require("src.systems.MapManager")
    local function eliteCount(mul)
        TK.seedRng(9)
        local n = 0
        for _ = 1, 400 do
            for _, node in ipairs(MapManager.generate(4, 1, 3, { eliteMul = mul })) do
                if node.type == "elite" then n = n + 1 end
            end
        end
        return n
    end
    local e1, e3 = eliteCount(1), eliteCount(3)
    t:truthy(("elite x3 aparece mais (%d > %d)"):format(e3, e1), e3 > e1)

    local PS = require("engine.ProfileStats")
    local US = require("src.systems.UnlockSystem")
    local prev = PS._swapForTests({ runs = 0, wins = 0 })
    US._resetForTests()
    t:eq("sem vitoria: so o selo 0", US.getMaxSeal("warrior"), 0)
    US.onRunEnded({ classId = "warrior", victory = true, actNumber = 6, seal = 0 })
    t:eq("venceu sem selo: abre o 1", US.getMaxSeal("warrior"), 1)
    t:eq("outra classe nao ganha nada", US.getMaxSeal("mage"), 0)
    local r = US.onRunEnded({ classId = "warrior", victory = true, actNumber = 6, seal = 1 })
    t:eq("venceu no 1: abre o 2", US.getMaxSeal("warrior"), 2)
    t:eq("resultado avisa o selo novo", r.sealUnlocked, 2)
    US.onRunEnded({ classId = "warrior", victory = false, actNumber = 3, seal = 2 })
    t:eq("derrota nao abre selo", US.getMaxSeal("warrior"), 2)
    PS._swapForTests({ runs = 5, wins = 1, winsByClass = { rogue = true } })
    US._resetForTests()
    t:eq("perfil antigo com vitoria: selo 1 aberto (nao pune)", US.getMaxSeal("rogue"), 1)
    PS._swapForTests(prev)
    US._resetForTests()

    local ge = TK.newRunGame("warrior")
    TK.seedRng(1234)
    local run = ge.runManager.currentRun
    run.actNumber, run.floorInAct = Config.TotalActs, 8
    run.currentFloor = Config.TotalActs * 8
    run.campaignWon = true
    t:eq("vira endless", ge.runManager:advanceFloorInAct(), "endless_start")
    local pend = RM.pending(run)
    t:truthy("ciclo 1 abre escolha de 2", pend and #pend == 2)
    t:truthy("as duas maldicoes sao diferentes", pend and pend[1] ~= pend[2])
    t:eq("ciclo = 1", RM.cycle(run), 1)
    t:eq("abrir de novo nao re-sorteia (idempotente)", RM.beginEndlessCycle(run)[1], pend[1])
    t:falsy("escolha fora da lista e recusada", RM.chooseCurse(run, "nao_existe"))
    t:truthy("escolhe a 1a", RM.chooseCurse(run, pend[1]))
    t:eq("acumulo 1", RM.curseStacks(run, pend[1]), 1)
    t:falsy("sem escolha aberta depois de escolher", RM.pending(run))
    t:truthy("pontos sobem com maldicao", RM.scoreMul(run) > 1)

    TK.seedRng(1234)
    local r2 = { endless = nil }
    local again = RM.beginEndlessCycle(r2)
    t:eq("mesma seed, mesma escolha", again[1] .. again[2], pend[1] .. pend[2])

    local rt = { endless = { cycle = 0, curses = { fome = 3 }, order = { "fome" } } }
    local voltou = false
    for _ = 1, 30 do
        local pp = RM.beginEndlessCycle(rt)
        if pp[1] == "fome" or pp[2] == "fome" then voltou = true end
        rt.endless.pending = nil
    end
    t:falsy("maldicao no teto nao volta ao sorteio (30 ciclos)", voltou)

    for _ = 1, 8 do ge.runManager:advanceFloorInAct() end
    t:eq("8 andares depois: ciclo 2", RM.cycle(run), 2)
    t:truthy("ciclo 2 com escolha aberta", RM.pending(run) ~= nil)
    ge:checkpointRun()
    local RunManager = require("src.systems.RunManager")
    local rmL = RunManager:new()
    t:truthy("carrega", rmL:loadRun())
    t:truthy("escolha aberta viaja no save", RM.pending(rmL.currentRun) ~= nil)
    t:eq("maldicoes viajam no save", RM.totalCurseStacks(rmL.currentRun), 1)

    local Enemy = require("src.entities.Enemy")
    local en = Enemy:new(200, 10)
    RM.decorateEnemy({ endless = { curses = { couraca_abissal = 2 } } }, en)
    t:eq("Couraca x2: bloqueio 16% da vida", en.armor, 32)

    local h8 = ActSystem.endlessFactors(8)
    local h40 = ActSystem.endlessFactors(40)
    local _, d8 = ActSystem.endlessFactors(8)
    t:truthy(("fim do ciclo 1 ate x2.5 de vida (x%.2f)"):format(h8), h8 <= 2.5)
    t:truthy(("fim do ciclo 5 passa de x50 (x%.0f)"):format(h40), h40 >= 50)
    t:truthy("dano cresce mais devagar que vida", d8 < h8)
    local prevF, mono = 0, true
    for n = 1, 80 do
        local f = ActSystem.endlessFactors(n)
        if f <= prevF then mono = false end
        prevF = f
    end
    t:truthy("curva sempre crescente", mono)
    local A = Config.TotalActs
    local b6 = ActSystem.getEnemyStats(A, 8, "boss")
    local bc1 = ActSystem.getEnemyStats(A + 1, 8, "boss", 8)
    local bc2 = ActSystem.getEnemyStats(A + 1, 8, "boss", 16)
    t:eq("chefe do ciclo 1 = chefe do ato 6", bc1.health, b6.health)
    t:truthy("chefe do ciclo 2 mais forte", bc2.health > bc1.health)

    local ECS = require("components.EndlessCurseScreen")
    local sizes = { { 800, 600 }, { 1024, 768 }, { 1280, 720 }, { 1920, 1080 }, { 2560, 1440 } }
    for _, s in ipairs(sizes) do
        local probs = ECS.validate(ECS.layout(s[1], s[2]), s[1], s[2])
        t:truthy(("maldicao: layout %dx%d%s"):format(s[1], s[2],
            #probs > 0 and (": " .. table.concat(probs, "; ")) or ""), #probs == 0)
    end
    local Layout = require("src.ui.ClassSelectLayout")
    for _, s in ipairs(sizes) do
        local ok, errs = Layout.validate(Layout.compute(s[1], s[2], 3))
        t:truthy(("selecao com banda de selo %dx%d%s"):format(s[1], s[2],
            ok and "" or (": " .. table.concat(errs, "; "))), ok)
    end
    local scr = ECS:new()
    ECS.watch(scr, ge, "mapSelection")
    t:truthy("observador abre a tela com escolha pendente", scr:isVisible())
    t:noerror("teclado escolhe a 2a", function()
        scr:keypressed("right"); scr:keypressed("return")
    end)
    t:falsy("fechou depois de escolher", scr:isVisible())
    t:falsy("escolha consumida", RM.pending(run))
    ECS.watch(scr, ge, "mapSelection")
    t:falsy("sem pendencia, nao reabre", scr:isVisible())

    ge.runManager:deleteSave()
    return t:done()
end

return M
