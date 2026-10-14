local TK = require("tools.testkit")
local RunManager = require("src.systems.RunManager")
local RestScreen = require("components.RestScreen")

local M = {}

function M.run()
    TK.bootstrap()
    TK.seedRng(7)
    local t = TK.new("forja: upgrades")

    local rm = RunManager:new()
    rm:startNewRun("warrior")
    local db = rm.cardDatabase

    local gStrike = RunManager.getForgeGains(db:getCard("warrior_strike"))
    t:eq("ataque puro ganha +2 ATQ/nível", gStrike.atk, 2)
    t:falsy("ataque puro NÃO ganha DEF", gStrike.def)

    local gDef = RunManager.getForgeGains(db:getCard("warrior_defend"))
    t:eq("defesa pura ganha +2 DEF/nível", gDef.def, 2)
    t:falsy("defesa pura NÃO ganha ATQ", gDef.atk)

    local gHeal = RunManager.getForgeGains(db:getCard("effect_healing_potion"))
    t:eq("efeito ganha +1/nível", gHeal.effect, 1)
    t:truthy("efeito tem effectIndex", gHeal.effectIndex ~= nil)

    local gJoker = RunManager.getForgeGains(db:getCard("joker_001"))
    t:truthy("joker sem stat/efeito upgradável -> gains vazio", next(gJoker) == nil)

    local inst = db:createCardInstance(db:getCard("warrior_strike"))
    local baseAtk = inst.attack
    rm:applyUpgradesToInstance(inst, 2)
    t:eq("applyUpgrades +2*2 no ataque", inst.attack, baseAtk + 4)
    t:eq("instance.upgrades registra o nível", inst.upgrades, 2)

    local instD = db:createCardInstance(db:getCard("warrior_defend"))
    local baseDef = instD.defense
    rm:applyUpgradesToInstance(instD, 3)
    t:eq("applyUpgrades +2*3 na defesa", instD.defense, baseDef + 6)

    t:eq("upgradeCard 1x -> nível 1", rm:upgradeCard("warrior_strike"), 1)
    t:eq("upgradeCard 2x -> nível 2", rm:upgradeCard("warrior_strike"), 2)
    for _ = 1, 8 do rm:upgradeCard("warrior_strike") end
    t:eq("upgrade infinito (cap 0) chega a 10", rm:getUpgrades("warrior_strike"), 10)

    t:truthy("canUpgrade carta com stat", rm:canUpgrade("warrior_strike"))
    t:falsy("canUpgrade joker não-forjável", rm:canUpgrade("joker_001"))
    t:falsy("canUpgrade id inexistente", rm:canUpgrade("carta_fantasma"))

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

    local rc = RunManager:new()
    rc:startNewRun("warrior")
    local deck = rc.currentRun.currentDeck
    rc:addCardToDeck("warrior_strike")
    rc:addCardToDeck("warrior_strike")
    t:eq("deck com 3 copias de warrior_strike", TK.count(deck, function(e)
        return RunManager.entryId(e) == "warrior_strike"
    end), 3)

    t:eq("forjar a copia 3 -> nivel 1", rc:upgradeCardAt(3), 1)
    t:eq("forjar a copia 3 de novo -> nivel 2", rc:upgradeCardAt(3), 2)
    t:eq("copia 3 esta em +2", rc:getUpgradesAt(3), 2)
    t:eq("copia 1 NAO foi forjada junto", rc:getUpgradesAt(1), 0)
    t:eq("copia 4 NAO foi forjada junto", rc:getUpgradesAt(4), 0)

    local lvls = {}
    for _, c in ipairs(rc:buildPlayableDeck()) do
        if c.id == "warrior_strike" then
            table.insert(lvls, c.upgrades or 0)
        end
    end
    table.sort(lvls)
    t:eq("deck jogavel tem 3 copias de warrior_strike", #lvls, 3)
    t:eq("niveis por copia no deck jogavel: 0/0/2",
        table.concat(lvls, "/"), "0/0/2")

    local newIdx = rc:duplicateCardAt(3)
    t:eq("duplicata nasce no nivel da copia escolhida", rc:getUpgradesAt(newIdx), 2)
    rc:upgradeCardAt(newIdx)
    t:eq("forjar a duplicata sobe so ela", rc:getUpgradesAt(newIdx), 3)
    t:eq("a copia de origem continua em +2", rc:getUpgradesAt(3), 2)

    local before = #deck
    t:truthy("removeCardAt remove", rc:removeCardAt(4))
    t:eq("deck encolheu 1", #deck, before - 1)
    t:eq("a copia forjada +2 sobreviveu", rc:getUpgradesAt(3), 2)
    t:eq("sobraram 3 copias de warrior_strike", TK.count(deck, function(e)
        return RunManager.entryId(e) == "warrior_strike"
    end), 3)

    rc:saveRun()
    local rloaded = RunManager:new()
    t:truthy("loadRun leu o save", (rloaded:loadRun()))
    local loadedLvls = {}
    for i, entry in ipairs(rloaded.currentRun.currentDeck) do
        if RunManager.entryId(entry) == "warrior_strike" then
            table.insert(loadedLvls, rloaded:getUpgradesAt(i))
        end
    end
    table.sort(loadedLvls)
    t:eq("niveis por copia sobrevivem ao save/load",
        table.concat(loadedLvls, "/"), "0/2/3")

    local rl = RunManager:new()
    rl:startNewRun("warrior")
    rl:addCardToDeck("warrior_strike")
    rl:upgradeCard("warrior_strike")
    local sum = rl:getUpgradesAt(1) + rl:getUpgradesAt(3)
    t:eq("upgradeCard(id) sobe UMA copia (soma dos niveis = 1)", sum, 1)

    local game = TK.newRunGame("warrior")
    game.runManager:addCardToDeck("warrior_strike")
    game.runManager:addCardToDeck("warrior_strike")
    local gdeck = game.runManager.currentRun.currentDeck
    local screen = RestScreen:new()
    screen:show(game, function() end, "forge")

    t:eq("picker lista uma entrada POR COPIA", #screen.cardList, #gdeck)
    local shown = TK.count(screen.cardEntries, function(e)
        return e.id == "warrior_strike"
    end)
    t:eq("as 3 copias de Golpe aparecem na grade", shown, 3)

    local seenIdx = {}
    local dup = false
    for _, e in ipairs(screen.cardEntries) do
        if seenIdx[e.idx] then dup = true end
        seenIdx[e.idx] = true
    end
    t:falsy("nenhuma entrada repete o mesmo indice de deck", dup)

    local picked = nil
    for _, e in ipairs(screen.cardEntries) do
        if e.id == "warrior_strike" then picked = e end
    end
    t:truthy("achou uma copia de Golpe na grade", picked ~= nil)
    screen:_onPickCard(picked)
    local others = 0
    for i, entry in ipairs(gdeck) do
        if RunManager.entryId(entry) == "warrior_strike" and i ~= picked.idx then
            others = others + game.runManager:getUpgradesAt(i)
        end
    end
    t:eq("a copia clicada foi forjada", game.runManager:getUpgradesAt(picked.idx), 1)
    t:eq("as outras copias continuam em +0", others, 0)
    screen:hide()

    return t:done()
end

return M
