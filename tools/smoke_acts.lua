-- tools/smoke_acts.lua
-- Fase 5: valida curvas de ato, endless scaling, starter deck minimo.

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

    -- 1. Config.Acts tem 3 atos
    check("Config.Acts tem 3 atos", #Config.Acts == 3)

    -- 2. Curva ato 1 (rebalanced): f=1 -> hp 14, f=8 -> hp 56
    local s1 = ActSystem.getEnemyStats(1, 1, "battle")
    check("ato 1, floor 1 battle: hp = 14", s1.health == 14)
    local s8 = ActSystem.getEnemyStats(1, 8, "battle")
    check("ato 1, floor 8 battle: hp = 56", s8.health == 56)

    -- 3. Boss stats fixos (rebalanced)
    local b1 = ActSystem.getEnemyStats(1, 8, "boss")
    check("boss ato 1: hp = 140", b1.health == 140)
    local b3 = ActSystem.getEnemyStats(3, 8, "boss")
    check("boss ato 3: hp = 500", b3.health == 500)

    -- 4. Elite: HP * eliteHPMul (f=4 -> 8+4*6=32; *1.6 = 51)
    local e = ActSystem.getEnemyStats(1, 4, "elite")
    check("elite ato 1 f=4: hp = floor(32*1.6)", e.health == math.floor(32 * 1.6))

    -- 5. Endless: act 4+, base do ato 3 f=1 = 165
    local endlessF1 = ActSystem.getEnemyStats(4, 1, "battle")
    local endlessF5 = ActSystem.getEnemyStats(4, 5, "battle")
    check("endless f1 = hp base act3 f1 (165)", endlessF1.health == 165)
    check("endless scala exponencial", endlessF5.health > endlessF1.health * 1.5)

    -- 6. Rarity weights do ato 1 sao Slay-early
    local w1 = ActSystem.getRarityWeights(1)
    check("ato 1: common e maioria absoluta", w1.common >= 60)
    local w3 = ActSystem.getRarityWeights(3)
    check("ato 3: rare > common", w3.rare > w3.common)

    -- 7. InterActHeal valores
    check("ato 1 interActHeal = 0.30", ActSystem.getInterActHealPercent(1) == 0.30)
    check("endless interActHeal = 0", ActSystem.getInterActHealPercent(4) == 0)

    -- 8. Act name
    check("ato 1 nome = Catacumbas", ActSystem.getActName(1) == "Catacumbas")
    check("endless tem Endless no nome",
        ActSystem.getActName(4, 3):find("Endless") ~= nil)

    -- 9. Starter deck de 2 cartas por classe
    local reg = CardRegistry:new()
    check("starter warrior = 2 cartas", #reg:getStarterDeckForClass("warrior") == 2)
    check("starter mage = 2 cartas", #reg:getStarterDeckForClass("mage") == 2)
    check("starter rogue = 2 cartas", #reg:getStarterDeckForClass("rogue") == 2)

    -- 10. rollRarity com pesos customizados funciona
    math.randomseed(42)
    local counts = { common = 0, uncommon = 0, rare = 0, legendary = 0 }
    for _ = 1, 1000 do
        local r = reg:rollRarity({ common = 100, uncommon = 0, rare = 0, legendary = 0 })
        counts[r] = counts[r] + 1
    end
    check("rollRarity com peso 100/0/0/0 retorna so common", counts.common == 1000)

    -- 11. generateCardRewards aplica minRarity
    local rewards = reg:generateCardRewards("warrior", 5, { minRarity = "rare" })
    local allRareOrUp = true
    for _, r in ipairs(rewards) do
        if r.rarity ~= "rare" and r.rarity ~= "legendary" then allRareOrUp = false end
    end
    check("generateCardRewards com minRarity=rare nunca retorna common",
        allRareOrUp and #rewards >= 1)

    -- 12. Config.Game ajustado
    check("PLAYER_MAX_HEALTH = 60", Config.Game.PLAYER_MAX_HEALTH == 60)
    check("INITIAL_HAND_SIZE = 4", Config.Game.INITIAL_HAND_SIZE == 4)

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
