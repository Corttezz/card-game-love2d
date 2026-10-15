local TK = require("tools.testkit")

local M = {}

M.MIN_NAIVE_TURNS = { warrior = 4, rogue = 3, mage = 2 }
M.MIN_NAIVE_TURNS_ALL = 3
M.MAX_EXPERT_TURNS = 8
M.MIN_HEALTH_MUL_BY_ACT = { 1.8, 1.6, 1.2, 0.95, 0.8, 0.75 }
M.MIN_DAMAGE_MUL_BY_ACT = { 0.95, 0.9, 0.85, 0.85, 0.8, 0.8 }
M.MIN_ACT_ENTRY_RATIO = 0.75
M.SEEDS = { 310001, 310002, 310003, 310004, 310005, 310006 }
M.CLASSES = { "warrior", "mage", "rogue" }

local function silent(fn, ...)
    local realPrint = print
    print = function() end
    local ok, a, b = pcall(fn, ...)
    print = realPrint
    return ok, a, b
end

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = deepcopy(v) end
    return o
end

local function firstFightSnap(class, enemyId)
    local Game = require("src.core.Game")
    local g = Game:new()
    g:startNewRun(class)
    local run = g.runManager.currentRun
    return {
        class = class,
        deck = deepcopy(run.currentDeck),
        jokers = {}, jokerActive = {}, services = deepcopy(run.services) or {},
        maxJokerSlots = run.maxJokerSlots,
        act = 1, floorInAct = 1,
        node = { type = "battle", enemyId = enemyId },
        maxHp = g.player.maxHealth,
        baseMana = g.player.baseMaxMana or g.player.maxMana,
    }
end

function M.measure(opts)
    opts = opts or {}
    TK.bootstrap()
    local BS = require("tools.balance_sim")
    local Autoplay = BS.setup("naive")
    local Instant = require("tools.instant_engine")
    Instant.install(Autoplay)
    local EnemyRoster = require("src.systems.EnemyRoster")
    local pool = EnemyRoster.poolFor(1, "battle")
    local seeds = opts.seeds or M.SEEDS
    local pilots = opts.pilots or { "naive", "expert_fast" }
    local rows = {}
    for _, class in ipairs(opts.classes or M.CLASSES) do
        rows[class] = {}
        for _, pilot in ipairs(pilots) do
            Autoplay.setPilot(pilot)
            local acc = { turns = 0, hpLost = 0, worstHp = 0, minTurns = 99, deaths = 0, n = 0, hpMax = 0 }
            for _, enemyId in ipairs(pool) do
                for _, seed in ipairs(seeds) do
                    local snap = firstFightSnap(class, enemyId)
                    Autoplay._resetBattleStats()
                    local ok, r = silent(Autoplay.replayBattle, snap, seed)
                    if not ok then error("replay falhou (" .. class .. "/" .. enemyId .. "): " .. tostring(r)) end
                    acc.n = acc.n + 1
                    acc.turns = acc.turns + (r.turns or 0)
                    acc.hpLost = acc.hpLost + (r.hpLost or 0)
                    acc.hpMax = r.maxHp or acc.hpMax
                    if (r.hpLost or 0) > acc.worstHp then acc.worstHp = r.hpLost end
                    if (r.turns or 99) < acc.minTurns then acc.minTurns = r.turns end
                    if not r.won then acc.deaths = acc.deaths + 1 end
                end
            end
            acc.turns = acc.turns / math.max(1, acc.n)
            acc.hpLost = acc.hpLost / math.max(1, acc.n)
            rows[class][pilot] = acc
        end
    end
    Autoplay.setPilot("expert")
    Instant.uninstall(Autoplay)
    return rows, pool
end

function M.printTable(rows, pool)
    local Config = require("src.core.Config")
    local ActSystem = require("src.systems.ActSystem")
    local pw = Config.Game.ENEMY_POWER or {}
    print(("  ENEMY_POWER dano %.2f vida %.2f"):format(pw.damage or 1, pw.health or 1))
    for a = 1, Config.TotalActs do
        local f1, f8 = ActSystem.getEnemyStats(a, 1, "battle"), ActSystem.getEnemyStats(a, 8, "battle")
        local el, bs = ActSystem.getEnemyStats(a, 4, "elite"), ActSystem.getEnemyStats(a, 8, "boss")
        print(("  ato %d: comum f1 %d/%d  f8 %d/%d  elite f4 %d/%d  chefe %d/%d (vida/dano antes do kit)"):format(
            a, f1.health, f1.damage, f8.health, f8.damage, el.health, el.damage, bs.health, bs.damage))
    end
    print("  inimigos do andar 1: " .. table.concat(pool, ", "))
    print("  classe   | piloto      | turnos (min) | vida perdida (pior) | mortes")
    for _, class in ipairs(M.CLASSES) do
        for pilot, r in pairs(rows[class] or {}) do
            print(("  %-8s | %-11s | %5.2f (%d)   | %5.2f (%d) de %d     | %d/%d"):format(
                class, pilot, r.turns, r.minTurns, r.hpLost, r.worstHp, r.hpMax, r.deaths, r.n))
        end
    end
end

local function body()
    local t = TK.new("piso de dificuldade: primeira luta do ato 1 por classe x piloto")
    TK.bootstrap()
    local Config = require("src.core.Config")
    local ActSystem = require("src.systems.ActSystem")

    local pw = Config.Game.ENEMY_POWER or { damage = 1, health = 1 }
    local byAct = Config.Game.ENEMY_POWER_BY_ACT or {}
    local prevHm = math.huge
    for a = 1, Config.TotalActs do
        local pa = byAct[a] or {}
        local hm = (pw.health or 1) * (pa.health or 1)
        local dm = (pw.damage or 1) * (pa.damage or 1)
        local want = M.MIN_HEALTH_MUL_BY_ACT[a] or M.MIN_HEALTH_MUL_BY_ACT[#M.MIN_HEALTH_MUL_BY_ACT]
        t:check(("ato %d: vida do inimigo x%.2f >= x%.2f"):format(a, hm, want), hm >= want - 1e-9)
        local wantD = M.MIN_DAMAGE_MUL_BY_ACT[a] or M.MIN_DAMAGE_MUL_BY_ACT[#M.MIN_DAMAGE_MUL_BY_ACT]
        t:check(("ato %d: dano do inimigo x%.2f >= x%.2f"):format(a, dm, wantD), dm >= wantD - 1e-9)
        t:check(("ato %d: multiplicador de vida nao sobe em relacao ao ato anterior (x%.2f)"):format(a, hm), hm <= prevHm + 1e-9)
        prevHm = hm
    end
    for a = 1, Config.TotalActs - 1 do
        local b1 = ActSystem.getEnemyStats(a, 8, "boss").health
        local b2 = ActSystem.getEnemyStats(a + 1, 8, "boss").health
        local c1 = ActSystem.getEnemyStats(a, 8, "battle").health
        local c2 = ActSystem.getEnemyStats(a + 1, 1, "battle").health
        t:check(("chefe do ato %d (%d) mais forte que o do ato %d (%d)"):format(a + 1, b2, a, b1), b2 > b1)
        t:check(("comum do 1o andar do ato %d (%d) >= %d%% do comum do fim do ato %d (%d)"):format(
            a + 1, c2, math.floor(M.MIN_ACT_ENTRY_RATIO * 100 + 0.5), a, c1), c2 >= c1 * M.MIN_ACT_ENTRY_RATIO)
    end
    local f1 = ActSystem.getEnemyStats(1, 1, "battle")
    t:check(("andar 1: vida %d > 24"):format(f1.health), f1.health > 24)

    local rows, pool = M.measure()
    M.printTable(rows, pool)
    local sumNaive = 0
    for _, class in ipairs(M.CLASSES) do
        local n, e = rows[class].naive, rows[class].expert_fast
        sumNaive = sumNaive + n.turns
        local want = M.MIN_NAIVE_TURNS[class] or M.MIN_NAIVE_TURNS_ALL
        t:check(("%s: naive leva >= %d turnos em media (%.2f)"):format(class, want, n.turns), n.turns >= want)
        t:check(("%s: naive nunca fecha a primeira luta em 1 turno (min %d)"):format(class, n.minTurns), n.minTurns >= 2)
        t:check(("%s: expert fecha em <= %d turnos em media (%.2f)"):format(class, M.MAX_EXPERT_TURNS, e.turns),
            e.turns <= M.MAX_EXPERT_TURNS)
        t:eq(class .. ": naive sobrevive a primeira luta", n.deaths, 0)
        t:eq(class .. ": expert sobrevive a primeira luta", e.deaths, 0)
        t:check(("%s: expert perde no maximo o que o naive perde (%.2f <= %.2f)"):format(class, e.hpLost, n.hpLost),
            e.hpLost <= n.hpLost + 1e-9)
    end
    local avgNaive = sumNaive / #M.CLASSES
    t:check(("media das classes: naive leva >= %d turnos (%.2f)"):format(M.MIN_NAIVE_TURNS_ALL, avgNaive),
        avgNaive >= M.MIN_NAIVE_TURNS_ALL)
    return t:done()
end

function M.run(mode)
    local BS = require("tools.balance_sim")
    if mode == "measure" then
        local ok, rows, pool = pcall(M.measure)
        if not ok then
            BS.teardown()
            error(rows, 0)
        end
        M.printTable(rows, pool)
        BS.teardown()
        return true
    end
    local ok, res = pcall(body)
    BS.teardown()
    if not ok then error(res, 0) end
    return res
end

return M
