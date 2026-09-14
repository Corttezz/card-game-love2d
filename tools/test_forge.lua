-- tools/test_forge.lua
-- Forja/upgrade: getForgeGains (regra por cenário), applyUpgradesToInstance
-- (aritmética +ATQ/+DEF/+efeito por nível), upgradeCard (cap infinito),
-- getPaidForgeCost (custo crescente 1.35^n, cap 60), canUpgrade.
--
-- + CÓPIAS REPETIDAS (Set/2026): o deck pode ter N cópias do MESMO id e cada
-- uma é uma carta própria. Cobre as duas metades do defeito reportado pelo
-- dono ("se eu tiver duas cartas iguais, na tela de forjar só aparece uma"):
--   (a) DADOS  — forjar/remover/duplicar A CÓPIA escolhida não toca nas outras
--                (RunManager: upgradeCardAt / removeCardAt / duplicateCardAt);
--   (b) TELA   — o picker da bigorna (RestScreen) lista UMA ENTRADA POR CÓPIA.
-- Conferido em RunManager.lua + Config.Offers + components/RestScreen.lua.
--   love . test_forge

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

    -- =====================================================================
    -- CÓPIAS REPETIDAS DO MESMO ID
    -- =====================================================================
    -- Regressão: enquanto o nível morava em currentRun.upgraded[cardId],
    -- forjar uma "Golpe" subia TODAS as "Golpe" do deck — e por isso o picker
    -- deduplicava a grade. Reverter para o mapa por id derruba os eq() abaixo.
    local rc = RunManager:new()
    rc:startNewRun("warrior")
    local deck = rc.currentRun.currentDeck
    -- Starter do guerreiro = warrior_strike + warrior_defend. Mais duas
    -- cópias de warrior_strike: três no total (índices 1, 3 e 4).
    rc:addCardToDeck("warrior_strike")
    rc:addCardToDeck("warrior_strike")
    t:eq("deck com 3 copias de warrior_strike", TK.count(deck, function(e)
        return RunManager.entryId(e) == "warrior_strike"
    end), 3)

    -- FORJAR uma cópia não mexe nas outras.
    t:eq("forjar a copia 3 -> nivel 1", rc:upgradeCardAt(3), 1)
    t:eq("forjar a copia 3 de novo -> nivel 2", rc:upgradeCardAt(3), 2)
    t:eq("copia 3 esta em +2", rc:getUpgradesAt(3), 2)
    t:eq("copia 1 NAO foi forjada junto", rc:getUpgradesAt(1), 0)
    t:eq("copia 4 NAO foi forjada junto", rc:getUpgradesAt(4), 0)

    -- buildPlayableDeck respeita o nível de CADA cópia.
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

    -- DUPLICAR a cópia forjada entrega uma cópia NO MESMO nível, e a original
    -- segue sozinha (forjar a nova não mexe na velha).
    local newIdx = rc:duplicateCardAt(3)
    t:eq("duplicata nasce no nivel da copia escolhida", rc:getUpgradesAt(newIdx), 2)
    rc:upgradeCardAt(newIdx)
    t:eq("forjar a duplicata sobe so ela", rc:getUpgradesAt(newIdx), 3)
    t:eq("a copia de origem continua em +2", rc:getUpgradesAt(3), 2)

    -- REMOVER pelo índice tira A CÓPIA apontada (não a primeira do id).
    local before = #deck
    t:truthy("removeCardAt remove", rc:removeCardAt(4))
    t:eq("deck encolheu 1", #deck, before - 1)
    t:eq("a copia forjada +2 sobreviveu", rc:getUpgradesAt(3), 2)
    t:eq("sobraram 3 copias de warrior_strike", TK.count(deck, function(e)
        return RunManager.entryId(e) == "warrior_strike"
    end), 3)

    -- SAVE/LOAD: o nível por cópia viaja no save (é campo do item de
    -- currentDeck, serializado junto com edition/seal).
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

    -- upgradeCard(id) legado (eventos/autoplay): sobe UMA cópia só, a de
    -- menor nível.
    local rl = RunManager:new()
    rl:startNewRun("warrior")
    rl:addCardToDeck("warrior_strike")
    rl:upgradeCard("warrior_strike")
    local sum = rl:getUpgradesAt(1) + rl:getUpgradesAt(3)
    t:eq("upgradeCard(id) sobe UMA copia (soma dos niveis = 1)", sum, 1)

    -- =====================================================================
    -- A GRADE DA BIGORNA MOSTRA TODAS AS CÓPIAS
    -- =====================================================================
    -- É a metade visível do defeito: com o dedupe por id, um deck de 4 cartas
    -- com 3 "Golpe" rendia 2 entradas na tela.
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

    -- Cada entrada aponta pra um índice DIFERENTE do deck (identidade da
    -- cópia é o índice, nunca o id).
    local seenIdx = {}
    local dup = false
    for _, e in ipairs(screen.cardEntries) do
        if seenIdx[e.idx] then dup = true end
        seenIdx[e.idx] = true
    end
    t:falsy("nenhuma entrada repete o mesmo indice de deck", dup)

    -- Forjar pela TELA (o caminho do jogador) mexe só na cópia clicada.
    local picked = nil
    for _, e in ipairs(screen.cardEntries) do
        if e.id == "warrior_strike" then picked = e end   -- fica na ULTIMA
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
