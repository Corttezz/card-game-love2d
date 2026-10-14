local ActSystem = require("src.systems.ActSystem")
local Config = require("src.core.Config")
local CardRegistry = require("src.systems.CardRegistry")

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- Fase 5 acts smoke test ----")

    check("Config.Acts tem um registro por ato de Config.TotalActs",
        #Config.Acts == Config.TotalActs)
    check("ha mais de um ato", Config.TotalActs >= 3)

    local savedPower, savedByAct = Config.Game.ENEMY_POWER, Config.Game.ENEMY_POWER_BY_ACT
    Config.Game.ENEMY_POWER, Config.Game.ENEMY_POWER_BY_ACT = nil, nil
    local s1 = ActSystem.getEnemyStats(1, 1, "battle")
    check("ato 1, floor 1 battle: hp = 14", s1.health == 14)
    local s8 = ActSystem.getEnemyStats(1, 8, "battle")
    check("ato 1, floor 8 battle: hp = 56", s8.health == 56)

    local b1 = ActSystem.getEnemyStats(1, 8, "boss")
    check("boss ato 1: hp = 110 (rebalance autoplay)", b1.health == 110)
    local b3 = ActSystem.getEnemyStats(3, 8, "boss")
    check("boss ato 3: hp = 420 (rebalance autoplay b4)", b3.health == 420)

    local e = ActSystem.getEnemyStats(1, 4, "elite")
    check("elite ato 1 f=4: hp = floor(32*1.4)", e.health == math.floor(32 * 1.4))
    Config.Game.ENEMY_POWER, Config.Game.ENEMY_POWER_BY_ACT = savedPower, savedByAct

    local primeiroEndless = Config.TotalActs + 1
    local baseUltimo = ActSystem.getEnemyStats(Config.TotalActs, 1, "battle")
    local endlessF1 = ActSystem.getEnemyStats(primeiroEndless, 1, "battle")
    local endlessF5 = ActSystem.getEnemyStats(primeiroEndless, 5, "battle")
    check("endless f1 parte da curva do ultimo ato",
        endlessF1.health == baseUltimo.health)
    check("endless scala exponencial", endlessF5.health > endlessF1.health * 1.5)

    local w1 = ActSystem.getRarityWeights(1)
    check("ato 1: common e maioria absoluta", w1.common >= 60)
    local w3 = ActSystem.getRarityWeights(3)
    check("ato 3: rare > common", w3.rare > w3.common)

    check("ato 1 interActHeal = 0.30", ActSystem.getInterActHealPercent(1) == 0.30)
    check("endless interActHeal = 0",
        ActSystem.getInterActHealPercent(Config.TotalActs + 1) == 0)

    local I18n = require("src.i18n.I18n")
    local entryLocale = I18n.getLocale()

    I18n.setLocale("pt_BR")
    check("ato 1 nome (pt_BR) = Catacumbas", ActSystem.getActName(1) == "Catacumbas")
    local endlessName = ActSystem.getActName(Config.TotalActs + 1, 3)
    check("endless (pt_BR) tem Sem Fim no nome (" .. endlessName .. ")",
        endlessName:find("Sem Fim") ~= nil)

    I18n.setLocale("en")
    check("ato 1 nome (en) = Catacombs", ActSystem.getActName(1) == "Catacombs")
    I18n.setLocale("de")
    check("ato 1 nome (de) = Katakomben", ActSystem.getActName(1) == "Katakomben")
    check("ato 1 traduz (pt != de)",
        ActSystem.getActName(1) ~= "Catacumbas")

    I18n.setLocale(entryLocale)

    local reg = CardRegistry:new()
    check("starter warrior = 2 cartas", #reg:getStarterDeckForClass("warrior") == 2)
    check("starter mage = 2 cartas", #reg:getStarterDeckForClass("mage") == 2)
    check("starter rogue = 2 cartas", #reg:getStarterDeckForClass("rogue") == 2)

    math.randomseed(42)
    local counts = { common = 0, uncommon = 0, rare = 0, legendary = 0 }
    for _ = 1, 1000 do
        local r = reg:rollRarity({ common = 100, uncommon = 0, rare = 0, legendary = 0 })
        counts[r] = counts[r] + 1
    end
    check("rollRarity com peso 100/0/0/0 retorna so common", counts.common == 1000)

    local rewards = reg:generateCardRewards("warrior", 5, { minRarity = "rare" })
    local allRareOrUp = true
    for _, r in ipairs(rewards) do
        if r.rarity ~= "rare" and r.rarity ~= "legendary" then allRareOrUp = false end
    end
    check("generateCardRewards com minRarity=rare nunca retorna common",
        allRareOrUp and #rewards >= 1)

    check("PLAYER_MAX_HEALTH = 60", Config.Game.PLAYER_MAX_HEALTH == 60)
    check("INITIAL_HAND_SIZE = 5 (F1)", Config.Game.INITIAL_HAND_SIZE == 5)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
