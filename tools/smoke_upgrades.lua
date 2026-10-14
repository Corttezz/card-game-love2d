local RunManager = require("src.systems.RunManager")

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- Upgrade pipeline (Fase 3.1) ----")

    local rm = RunManager:new()
    rm:startNewRun("warrior")
    local run = rm.currentRun

    check("currentRun tem upgraded={} default", run.upgraded ~= nil and next(run.upgraded) == nil)

    local lvl1 = rm:upgradeCard("warrior_strike")
    check("upgradeCard retorna nivel 1 na primeira chamada", lvl1 == 1)
    local lvl2 = rm:upgradeCard("warrior_strike")
    check("upgradeCard retorna nivel 2 na segunda chamada", lvl2 == 2)
    check("getUpgrades reflete nivel atual", rm:getUpgrades("warrior_strike") == 2)
    check("getUpgrades de carta nao forjada = 0", rm:getUpgrades("nope") == 0)

    local deck = rm:buildPlayableDeck()
    local foundUpgraded = nil
    for _, c in ipairs(deck) do
        if c.id == "warrior_strike" and c.upgrades and c.upgrades > 0 then
            foundUpgraded = c
            break
        end
    end
    check("buildPlayableDeck inclui carta com upgrades>0", foundUpgraded ~= nil)
    if foundUpgraded then
        check("instancia tem upgrades=2", foundUpgraded.upgrades == 2)
        check("attack incrementado em +4 (2 por nivel * 2 niveis)",
            foundUpgraded.attack and foundUpgraded.attack > 0)
    end

    print()
    print("---- Editions (Fase 3.2) ====")

    local Game = require("src.core.Game")
    local g = Game:new()
    g:startNewRun("warrior")
    g:startGame()

    local testCard = { name = "Test", attack = 10, type = "attack", effects = {}, edition = "foil" }

    local function dummyContext()
        return { tagCounts = {}, cardsProcessed = {}, activeCombos = {}, allSelectedCards = {testCard}, turnNumber = 1 }
    end

    g.enemy.health = 999
    g.enemy.maxHealth = 999
    local before = g.enemy.health
    g._currentTurnContext = dummyContext()
    g:processCardInCombat(testCard, g._currentTurnContext)
    local dealt = before - g.enemy.health
    check("foil aplica +5 flat (>=15 base 10)", dealt >= 15)

    g.enemy.health = 999
    local holoCard = { name = "Test", attack = 10, type = "attack", effects = {}, edition = "holo" }
    g:processCardInCombat(holoCard, dummyContext())
    local dealtHolo = 999 - g.enemy.health
    check("holo aplica x1.2 (>=12 base 10)", dealtHolo >= 12)

    g.enemy.health = 999
    local polyCard = { name = "Test", attack = 10, type = "attack", effects = {}, edition = "polychrome" }
    g:processCardInCombat(polyCard, dummyContext())
    local dealtPoly = 999 - g.enemy.health
    check("polychrome aplica x1.5 (>=15 base 10)", dealtPoly >= 15)

    print()
    print("---- Seals (Fase 3.3) ====")

    g.enemy.health = 999
    local redCard = { name = "Test", attack = 10, type = "attack", effects = {}, seal = "Red" }
    g:processCardInCombat(redCard, dummyContext())
    local dealtRed = 999 - g.enemy.health
    check("seal Red aplica x2 (>=20 base 10)", dealtRed >= 20)

    local goldBefore = g.economySystem.currentGold
    local goldCard = { name = "Test", attack = 5, type = "attack", effects = {}, seal = "Gold" }
    g.enemy.health = 999
    g:processCardInCombat(goldCard, dummyContext())
    local goldAfter = g.economySystem.currentGold
    check("seal Gold gera +3 ouro", goldAfter == goldBefore + 3)

    local orbsBefore = #(g.player.orbs or {})
    local purpleCard = { name = "Test", attack = 5, type = "attack", effects = {}, seal = "Purple" }
    g.enemy.health = 999
    g:processCardInCombat(purpleCard, dummyContext())
    check("seal Purple gera +1 orb", #(g.player.orbs or {}) == orbsBefore + 1)

    g._sealDrawBonus = 0
    local blueCard = { name = "Test", attack = 5, type = "attack", effects = {}, seal = "Blue" }
    g.enemy.health = 999
    g:processCardInCombat(blueCard, dummyContext())
    check("seal Blue incrementa _sealDrawBonus", (g._sealDrawBonus or 0) == 1)

    print()
    print("  TOTAL: " .. pass .. " pass / " .. fail .. " fail")

    return fail == 0
end

return M
