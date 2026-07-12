-- tools/test_forge.lua
-- Forja/upgrade: getForgeGains (regra por cenário), applyUpgradesToInstance
-- (aritmética +ATQ/+DEF/+efeito por nível), upgradeCard (cap infinito),
-- getPaidForgeCost (custo crescente 1.35^n, cap 60), canUpgrade.
-- Conferido em RunManager.lua + Config.Offers.
--   love . test_forge

local TK = require("tools.testkit")
local RunManager = require("src.systems.RunManager")

local M = {}

function M.run()
    TK.bootstrap()
    TK.seedRng(7)
    local t = TK.new("forja: upgrades")

    local rm = RunManager:new()
    rm:startNewRun("warrior")
    local db = rm.cardDatabase

    -- getForgeGains: cenário ATAQUE puro (warrior_strike: atk 8, def 0)
    local gStrike = RunManager.getForgeGains(db:getCard("warrior_strike"))
    t:eq("ataque puro ganha +2 ATQ/nível", gStrike.atk, 2)
    t:falsy("ataque puro NÃO ganha DEF", gStrike.def)

    -- cenário DEFESA pura (warrior_defend: def 7, atk 0)
    local gDef = RunManager.getForgeGains(db:getCard("warrior_defend"))
    t:eq("defesa pura ganha +2 DEF/nível", gDef.def, 2)
    t:falsy("defesa pura NÃO ganha ATQ", gDef.atk)

    -- cenário EFEITO (effect_healing_potion: instant_heal, sem atk/def)
    local gHeal = RunManager.getForgeGains(db:getCard("effect_healing_potion"))
    t:eq("efeito ganha +1/nível", gHeal.effect, 1)
    t:truthy("efeito tem effectIndex", gHeal.effectIndex ~= nil)

    -- cenário NÃO-FORJÁVEL (joker_001: damage_multiplier não é upgradável)
    local gJoker = RunManager.getForgeGains(db:getCard("joker_001"))
    t:truthy("joker sem stat/efeito upgradável -> gains vazio", next(gJoker) == nil)

    -- applyUpgradesToInstance: aritmética real
    local inst = db:createCardInstance(db:getCard("warrior_strike"))
    local baseAtk = inst.attack
    rm:applyUpgradesToInstance(inst, 2)
    t:eq("applyUpgrades +2*2 no ataque", inst.attack, baseAtk + 4)
    t:eq("instance.upgrades registra o nível", inst.upgrades, 2)

    local instD = db:createCardInstance(db:getCard("warrior_defend"))
    local baseDef = instD.defense
    rm:applyUpgradesToInstance(instD, 3)
    t:eq("applyUpgrades +2*3 na defesa", instD.defense, baseDef + 6)

    -- upgradeCard: infinito (cap 0)
    t:eq("upgradeCard 1x -> nível 1", rm:upgradeCard("warrior_strike"), 1)
    t:eq("upgradeCard 2x -> nível 2", rm:upgradeCard("warrior_strike"), 2)
    for _ = 1, 8 do rm:upgradeCard("warrior_strike") end
    t:eq("upgrade infinito (cap 0) chega a 10", rm:getUpgrades("warrior_strike"), 10)

    -- canUpgrade
    t:truthy("canUpgrade carta com stat", rm:canUpgrade("warrior_strike"))
    t:falsy("canUpgrade joker não-forjável", rm:canUpgrade("joker_001"))
    t:falsy("canUpgrade id inexistente", rm:canUpgrade("carta_fantasma"))

    -- getPaidForgeCost: 5 -> 7 -> 9 -> 12 (floor(5*1.35^n + 0.5)), cap 60
    local rm3 = RunManager:new(); rm3:startNewRun("rogue")
    t:eq("forja paga #0 = 5", rm3:getPaidForgeCost(), 5)
    rm3:registerPaidForge()
    t:eq("forja paga #1 = 7", rm3:getPaidForgeCost(), 7)
    rm3:registerPaidForge()
    t:eq("forja paga #2 = 9", rm3:getPaidForgeCost(), 9)
    rm3:registerPaidForge()
    t:eq("forja paga #3 = 12", rm3:getPaidForgeCost(), 12)
    for _ = 1, 30 do rm3:registerPaidForge() end
    t:eq("forja paga satura no cap 60", rm3:getPaidForgeCost(), 60)

    return t:done()
end

return M
