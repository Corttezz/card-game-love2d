local TK = require("tools.testkit")

local M = {}

local TIER_RANK = { common = 1, elite = 2, miniboss = 3, boss = 4 }
local NODE_TIER = { battle = "common", elite = "elite", mini_boss = "miniboss", boss = "boss" }

local function goToNode(game, nodeType)
    local rm = game.runManager
    local run = rm.currentRun
    run.stage = "fork"
    run.pendingNodes = nil
    rm:advanceFloorInAct()
    rm:generateNextNodes(3)
    rm:chooseNode(1, { hp = game.player.health, maxHp = game.player.maxHealth,
        gold = game.economySystem.currentGold })
    run.currentNode.type = nodeType
    run.currentNode.enemyId = nil
    require("src.systems.EnemyRoster").assignNodes(run, { run.currentNode })
    game:nextPhase()
    return game.enemy.spriteId
end

local function continueFromDisk()
    local Game = require("src.core.Game")
    local g = Game:new()
    local ok = g.runManager:loadRun()
    if ok then g:resumeRun() end
    return g, ok
end

local function kill(game)
    game.enemy.health = 0
    game:_onEnemyDeath()
end

local function checkEntries(t, Bestiary, Enemies)
    local list = Bestiary.entries()
    local expected = {}
    local total = 0
    for act, byNode in ipairs(Enemies.ROSTER) do
        for node, ids in pairs(byNode) do
            for _, id in ipairs(ids) do
                total = total + 1
                expected[id] = { act = act, tier = NODE_TIER[node] }
            end
        end
    end
    t:eq("entries: uma entrada por id do ROSTER", #list, total)
    local count, okFields, okOrder = {}, true, true
    for i, e in ipairs(list) do
        count[e.id] = (count[e.id] or 0) + 1
        local want = expected[e.id]
        if not (want and want.act == e.act and want.tier == e.tier
            and TIER_RANK[e.tier] and e.spriteId == e.id and type(e.biome) == "string"
            and Enemies.HOME_BIOME[e.id] == e.act) then
            okFields = false
            t:check("entrada coerente: " .. tostring(e.id), false)
        end
        local p = list[i - 1]
        if p and (p.act > e.act or (p.act == e.act and TIER_RANK[p.tier] > TIER_RANK[e.tier])) then
            okOrder = false
        end
    end
    local dup = false
    for id in pairs(expected) do
        if count[id] ~= 1 then dup = true; t:check("id aparece uma vez: " .. id, false) end
    end
    t:truthy("entries: ato, tipo, bioma e sprite válidos", okFields)
    t:falsy("entries: nenhum id faltando ou repetido", dup)
    t:truthy("entries: ordem ato 1..6, comum > elite > mini-chefe > chefe", okOrder)
    t:eq("entries: primeiro é comum do ato 1", list[1].act .. ":" .. list[1].tier, "1:common")
    t:eq("entries: último é o chefe do ato 6", list[#list].id, Enemies.ROSTER[6].boss[1])
    t:falsy("id fora do roster não entra", Bestiary.has("generic"))
end

function M.run()
    local t = TK.new("bestiário: criaturas descobertas, derrotadas e que te derrotaram")
    TK.bootstrap()
    local ProfileStats = require("engine.ProfileStats")
    local SaveManager = require("engine.SaveManager")
    local Bestiary = require("src.systems.Bestiary")
    local Enemies = require("src.data.enemies")

    local prevProfile = ProfileStats._swapForTests({ runs = 0, wins = 0 })
    local origWrite = SaveManager.writeFile
    local profileWrites = 0
    SaveManager.writeFile = function(path, ...)
        if path == "profile.lua" then profileWrites = profileWrites + 1 end
        return origWrite(path, ...)
    end
    Bestiary._resetForTests()

    local ok, err = pcall(function()
        checkEntries(t, Bestiary, Enemies)

        t:falsy("perfil sem dados: nada visto", Bestiary.isSeen(Enemies.ROSTER[1].battle[1]))
        t:falsy("perfil sem dados: nenhuma novidade", Bestiary.anyNew())

        local game = TK.newRunGame("warrior")
        TK.seedRng(4242)
        local first = game.enemy.spriteId
        t:truthy("1ª luta usa criatura do roster", Bestiary.has(first))
        t:eq("1ª luta da run: vista uma vez", Bestiary.stats(first).seen, 1)
        t:truthy("criatura vista ganha o '!'", Bestiary.isNew(first))
        t:truthy("anyNew com criatura nova", Bestiary.anyNew())
        t:eq("runNewCount conta a 1ª criatura", Bestiary.runNewCount(), 1)
        t:falsy("vista e não derrotada", Bestiary.isDefeated(first))

        kill(game)
        t:eq("morte do inimigo: derrotada 1x", Bestiary.stats(first).defeated, 1)
        t:truthy("isDefeated depois da vitória", Bestiary.isDefeated(first))
        game:_onEnemyDeath()
        t:falsy("2ª resolução da mesma luta não conta", game:noteBestiary("defeated"))
        t:eq("derrotada continua 1x", Bestiary.stats(first).defeated, 1)
        t:eq("vista continua 1x", Bestiary.stats(first).seen, 1)

        local second = goToNode(game, "elite")
        t:eq("elite tem tipo elite", Bestiary.entry(second).tier, "elite")
        local seenBefore = Bestiary.stats(second).seen
        t:eq("luta nova conta a vista", seenBefore, 1)
        local newBefore = Bestiary.runNewCount()
        game.player.health = game.player.health - 3
        game:checkpointRun()

        local g2, loaded = continueFromDisk()
        t:truthy("Continuar no meio da luta carregou", loaded)
        t:eq("Continuar: mesma criatura", g2.enemy.spriteId, second)
        t:eq("Continuar no meio da luta não conta outra vista", Bestiary.stats(second).seen, seenBefore)
        t:eq("Continuar mantém a contagem de novas da run", Bestiary.runNewCount(), newBefore)
        local g3 = continueFromDisk()
        t:eq("Continuar duas vezes: ainda uma vista", Bestiary.stats(second).seen, seenBefore)

        kill(g3)
        t:eq("vitória depois de Continuar conta 1x", Bestiary.stats(second).defeated, 1)
        g3.runManager.currentRun.stage = "cashout"
        g3:checkpointRun()
        local g4 = continueFromDisk()
        t:eq("Continuar no cash out não recontabiliza a vitória", Bestiary.stats(second).defeated, 1)
        t:eq("Continuar no cash out não recontabiliza a vista", Bestiary.stats(second).seen, seenBefore)
        if g4.enemy and g4.enemy.health > 0 then g4.enemy.health = 0 end
        g4._deathHandled, g4._deathStaged = true, true

        local boss = goToNode(g4, "boss")
        t:eq("chefe tem tipo chefe", Bestiary.entry(boss).tier, "boss")
        t:eq("chefe não conta antes da entrada", Bestiary.stats(boss).seen, 0)
        t:truthy("entrada do chefe conta a vista", g4:noteBestiary("seen"))
        t:falsy("entrada repetida não conta", g4:noteBestiary("seen"))
        t:eq("chefe visto 1x", Bestiary.stats(boss).seen, 1)
        g4:checkpointRun()
        local g5 = continueFromDisk()
        t:eq("Continuar no chefe não reconta", Bestiary.stats(boss).seen, 1)

        g5.player.health = 0
        t:truthy("game over", g5:checkGameOver())
        t:eq("morte do jogador: te derrotou 1x", Bestiary.stats(boss).killedYou, 1)
        g5:checkGameOver()
        t:eq("checkGameOver repetido não reconta", Bestiary.stats(boss).killedYou, 1)
        t:falsy("chefe que te matou não está derrotado", Bestiary.isDefeated(boss))

        local runNew = Bestiary.runNewCount()
        t:eq("runNewCount = criaturas inéditas da run", runNew, #Bestiary.runNewIds())
        t:truthy("runNewCount sobrevive ao fim da run (tela final)", runNew >= 3)

        local fresh = 0
        for _, e in ipairs(Bestiary.entries()) do
            if Bestiary.isNew(e.id) then fresh = fresh + 1 end
        end
        t:eq("novidades do perfil = vistas", fresh, Bestiary.newCount())
        t:truthy("clearNew limpa", Bestiary.clearNew(first))
        t:falsy("clearNew repetido devolve false", Bestiary.clearNew(first))
        t:falsy("isNew depois do clearNew", Bestiary.isNew(first))
        for _, e in ipairs(Bestiary.entries()) do Bestiary.clearNew(e.id) end
        t:falsy("anyNew depois de limpar tudo", Bestiary.anyNew())

        local g6 = require("src.core.Game"):new()
        g6:startNewRun("warrior")
        t:eq("run nova zera runNewCount", Bestiary.runNewCount(), 0)
        g6:startGame()
        local again = g6.enemy.spriteId
        t:eq("criatura já conhecida não conta como nova", Bestiary.runNewCount(),
            (Bestiary.stats(again).seen > 1) and 0 or 1)
        t:falsy("criatura já conhecida não volta a ter '!'",
            Bestiary.stats(again).seen > 1 and Bestiary.isNew(again))

        g6.runManager.currentRun.campaignWon = true
        g6.runManager.currentRun.endlessMode = true
        local endlessId = goToNode(g6, "battle")
        local before = Bestiary.stats(endlessId).seen
        t:truthy("endless: luta conta", before >= 1)
        kill(g6)
        t:truthy("endless: vitória conta", Bestiary.isDefeated(endlessId))
        g6:abandonRun()
        t:eq("abandonar não mexe nas contagens", Bestiary.stats(endlessId).seen, before)

        t:eq("sandbox: nenhum write em profile.lua sob HEADLESS_TOOL", profileWrites, 0)

        local path = "bestiary_roundtrip.tool.lua"
        ProfileStats._setPathForTests(path)
        Bestiary.markSeen(first)
        Bestiary.markSeen(first)
        Bestiary.markDefeated(first)
        Bestiary.markKilledYou(second)
        ProfileStats._setPathForTests(path)
        local s = Bestiary.stats(first)
        t:eq("round-trip: vista", s.seen, 2)
        t:eq("round-trip: derrotada", s.defeated, 1)
        t:eq("round-trip: te derrotou", Bestiary.stats(second).killedYou, 1)
        t:truthy("round-trip: '!' persiste", Bestiary.isNew(first))
        t:truthy("round-trip: second vista via killedYou", Bestiary.isSeen(second))
        t:truthy("round-trip: arquivo no perfil de teste", love.filesystem.getInfo(path) ~= nil)
        love.filesystem.remove(path)
        love.filesystem.remove(path .. ".bak")
        ProfileStats._setPathForTests(nil)
    end)
    if not ok then t:check("sem erro: " .. tostring(err), false) end

    SaveManager.writeFile = origWrite
    ProfileStats._setPathForTests(nil)
    ProfileStats._swapForTests(prevProfile)
    Bestiary._resetForTests()
    pcall(function() require("engine.SaveManager").deleteRun() end)
    return TK.verdict(t.fail == 0)
end

return M
