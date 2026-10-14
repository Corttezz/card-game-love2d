local TK = require("tools.testkit")
local SaveManager = require("engine.SaveManager")

local M = {}

local fs = love.filesystem

local function clean(path)
    for _, p in ipairs({ path, path .. ".tmp", path .. ".bak" }) do
        if fs.getInfo(p) then fs.remove(p) end
    end
    for _, item in ipairs(fs.getDirectoryItems("")) do
        if item:find(path .. ".corrupt", 1, true) == 1 then fs.remove(item) end
    end
end

local function valueOf(path)
    local v = SaveManager.decodeData(fs.read(path) or "", path)
    return v and v.v
end

local TRUNCATED = "return {\n  v = 9,\n  nested = {"

local function testAtomic(t)
    local P = "ti_atomic.lua"
    clean(P)
    SaveManager.quarantined[P] = nil

    t:truthy("1a. primeira escrita ok", SaveManager.writeFile(P, "return { v = 1 }"))
    local v, info = SaveManager.readDataFile(P)
    t:eq("1a. lê do principal", info.source, "main")
    t:eq("1a. valor", v and v.v, 1)
    t:falsy("1a. nenhum .tmp sobra", fs.getInfo(P .. ".tmp"))

    SaveManager.writeFile(P, "return { v = 2 }")
    t:eq("1b. principal = v2", valueOf(P), 2)
    t:eq("1b. .bak = geração anterior (v1)", valueOf(P .. ".bak"), 1)

    local ok = SaveManager.writeFile(P, "return 5")
    t:falsy("1c. conteúdo que não devolve tabela é recusado", ok)
    t:eq("1c. principal intacto", valueOf(P), 2)

    fs.write(P, TRUNCATED)
    v, info = SaveManager.readDataFile(P)
    t:eq("1d. principal truncado → recupera do .bak", info.source, "bak")
    t:eq("1d. valor do .bak", v and v.v, 1)
    t:truthy("1d. cópia .corrupt-<ts> preservada",
        info.corruptCopy and fs.getInfo(info.corruptCopy))

    fs.remove(P)
    fs.write(P .. ".tmp", "return { v = 3 }")
    v, info = SaveManager.readDataFile(P)
    t:eq("1e. sem principal → lê o .tmp (mais novo que o .bak)", info.source, "tmp")
    t:eq("1e. valor do .tmp", v and v.v, 3)

    fs.remove(P .. ".tmp")
    fs.write(P .. ".bak", "return { v = 1 }")
    fs.write(P, TRUNCATED)
    t:truthy("1f. escreve por cima de principal corrompido",
        SaveManager.writeFile(P, "return { v = 4 }"))
    t:eq("1f. principal = v4", valueOf(P), 4)
    t:eq("1f. .bak segue sendo o último BOM (v1)", valueOf(P .. ".bak"), 1)

    local realRename = SaveManager._rename
    SaveManager._rename = function() return false end
    local okF = SaveManager.writeFile(P, "return { v = 5 }")
    SaveManager._rename = realRename
    t:truthy("1g. fallback sem rename grava", okF)
    t:eq("1g. principal = v5", valueOf(P), 5)
    t:eq("1g. .bak = v4", valueOf(P .. ".bak"), 4)
    t:falsy("1g. .tmp limpo", fs.getInfo(P .. ".tmp"))

    clean(P)
    SaveManager.quarantined[P] = nil
end

local function testProfile(t)
    local ProfileStats = require("engine.ProfileStats")
    local P = "ti_profile.lua"
    clean(P)
    SaveManager.quarantined[P] = nil

    ProfileStats._setPathForTests(P)
    ProfileStats.recordRunStart("warrior")
    ProfileStats.recordVictory(6, 8, "warrior")
    ProfileStats.recordVictory(6, 8, "mage")
    t:truthy("2a. perfil gravado (sandbox de teste)", fs.getInfo(P))
    t:truthy("2a. .bak gerado", fs.getInfo(P .. ".bak"))

    fs.write(P, TRUNCATED)
    ProfileStats._setPathForTests(P)
    local s = ProfileStats.get()
    t:eq("2b. perfil recuperado do .bak (wins da geração anterior)", s.wins, 1)
    t:falsy("2b. recuperado → NÃO está em modo recuperação",
        ProfileStats.isRecoveryMode())
    ProfileStats.flush()
    local healed = SaveManager.decodeData(fs.read(P), P)
    t:eq("2b. próximo save cura o principal", healed and healed.wins, 1)

    clean(P)
    SaveManager.quarantined[P] = nil
    fs.write(P, TRUNCATED)
    ProfileStats._setPathForTests(P)
    s = ProfileStats.get()
    t:truthy("2c. sem backup → modo recuperação", ProfileStats.isRecoveryMode())
    ProfileStats.recordVictory(1, 1, "rogue")
    ProfileStats.flush()
    t:eq("2c. arquivo danificado NÃO foi sobrescrito pelos defaults",
        fs.read(P), TRUNCATED)
    local hasCopy = false
    for _, item in ipairs(fs.getDirectoryItems("")) do
        if item:find(P .. ".corrupt", 1, true) == 1 then hasCopy = true end
    end
    t:truthy("2c. cópia .corrupt-<ts> do perfil preservada", hasCopy)

    ProfileStats._setPathForTests(nil)
    clean(P)
    SaveManager.quarantined[P] = nil
end

local function testRunSave(t)
    local base = SaveManager.PATHS.run
    t:truthy("3. sob ferramenta o save é *.tool.lua", base:find("tool", 1, true))
    SaveManager.deleteRun()
    SaveManager.saveRun({ marker = "A" })
    SaveManager.saveRun({ marker = "B" })
    fs.write(base, TRUNCATED)
    local data = SaveManager.loadRun()
    t:eq("3a. run corrompida volta do .bak", data and data.marker, "A")
    SaveManager.deleteRun()
    t:falsy("3b. deleteRun apaga principal/.tmp/.bak (hasRun falso)", SaveManager.hasRun())
    t:falsy("3b. nem .bak sobra", fs.getInfo(base .. ".bak"))
    SaveManager.quarantined[base] = nil
end

local function shelf(offers)
    local out = {}
    for i, o in ipairs(offers) do
        out[i] = ("%s:%s:$%s:%s"):format(o.type, o.id, tostring(o.cost),
            o.purchased and "VENDIDO" or "-")
    end
    return table.concat(out, " | ")
end

local function reload()
    local Game = require("src.core.Game")
    local g = Game:new()
    local ok = g.runManager:loadRun()
    if ok then g:resumeRun() end
    return g, ok
end

local function firstCard(offers)
    for _, o in ipairs(offers) do
        if o.type == "card" and not o.purchased then
            local cd = require("src.systems.CardDatabase"):getCard(o.id)
            if cd and cd.type ~= "joker" then return o end
        end
    end
end

local function testShop(t)
    local CardRewardScreen = require("components.CardRewardScreen")
    TK.seedRng(424242)
    local game = TK.newRunGame("warrior")
    local run = game.runManager.currentRun
    run.stage = "shop"
    run.mapHistory = { { actNumber = 1, floorInAct = 2, type = "shop" } }
    game.economySystem.currentGold = 500

    local screen = CardRewardScreen:new(game.shopSystem)
    screen:show(game, nil, function() end, "shop")
    t:truthy("4a. vitrine nova entra no currentRun", run.shopState ~= nil)

    local offer = firstCard(screen.shopOffers)
    t:truthy("4a. há carta comprável", offer)
    if offer then screen:purchaseOffer(offer) end
    if screen.refreshButton then screen.refreshButton.onClick() end
    local offer2 = firstCard(screen.shopOffers)
    if offer2 then screen:purchaseOffer(offer2) end
    local before = shelf(screen.shopOffers)
    local costBefore = game.shopSystem:getRefreshCost()
    local goldBefore = game.economySystem.currentGold
    t:truthy("4a. reroll encareceu", costBefore > 5)

    game:checkpointRun()
    require("src.systems.Rng").get():random("shop")
    local g2, ok = reload()
    t:truthy("4b. save carregou", ok)
    local screen2 = CardRewardScreen:new(g2.shopSystem)
    screen2:show(g2, nil, function() end, "shop")
    t:eq("4b. vitrine idêntica (ofertas, preços, VENDIDO)",
        shelf(screen2.shopOffers), before)
    t:eq("4b. custo de reroll preservado", g2.shopSystem:getRefreshCost(), costBefore)
    t:eq("4b. ouro preservado", g2.economySystem.currentGold, goldBefore)

    local left = false
    screen2:_exitWithFlourish()
    screen2.onSkipped = nil
    TK.pump(g2, 2.0)
    left = g2.runManager.currentRun.shopState == nil
    t:truthy("4c. sair da loja limpa shopState", left)
    return g2
end

local function testRewards(t)
    local CardRewardScreen = require("components.CardRewardScreen")
    TK.seedRng(777)
    local game = TK.newRunGame("mage")
    local run = game.runManager.currentRun
    run.stage = "rewards"
    run.mapHistory = { { actNumber = 1, floorInAct = 1, type = "battle" } }

    local screen = CardRewardScreen:new(game.shopSystem)
    screen.onSkipped = nil
    screen:show(game, nil, nil, "rewards")
    local first = shelf(screen.shopOffers)
    game:checkpointRun()
    require("src.systems.Rng").get():random("card")
    require("src.systems.Rng").get():random("shop")

    local g2 = reload()
    local screen2 = CardRewardScreen:new(g2.shopSystem)
    screen2:show(g2, nil, nil, "rewards")
    t:eq("5a. recompensa idêntica após Continuar", shelf(screen2.shopOffers), first)

    local offer = firstCard(screen2.shopOffers)
    if offer then screen2:purchaseOffer(offer) end
    local deckAfter = #g2.runManager.currentRun.currentDeck
    g2:checkpointRun()
    local g3 = reload()
    local screen3 = CardRewardScreen:new(g3.shopSystem)
    screen3:show(g3, nil, nil, "rewards")
    t:truthy("5b. carta pega segue VENDIDA", screen3.shopOffers[offer and offer._slot or 1].purchased)
    t:truthy("5b. escolha-1 travada após Continuar", screen3._rewardTaken)
    local other = firstCard(screen3.shopOffers)
    if other then screen3:purchaseOffer(other) end
    t:eq("5b. nenhuma 2ª carta entrou no deck",
        #g3.runManager.currentRun.currentDeck, deckAfter)
end

function M.run()
    local t = TK.new("integridade de save + vitrine persistida")
    TK.bootstrap()
    testAtomic(t)
    testProfile(t)
    testRunSave(t)
    testShop(t)
    testRewards(t)
    SaveManager.deleteRun()
    return t:done()
end

return M
