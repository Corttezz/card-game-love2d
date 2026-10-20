local Rng = require("src.systems.Rng")
local Config = require("src.core.Config")
local CardRegistry = require("src.systems.CardRegistry")
local RunManager = require("src.systems.RunManager")
local MapManager = require("src.systems.MapManager")
local Events = require("src.data.events")

local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- STS-improvements v1: systems test ----")

    local a = Rng.new(12345)
    local b = Rng.new(12345)
    local same = true
    for _ = 1, 50 do
        if a:random("card", 1000) ~= b:random("card", 1000) then same = false break end
    end
    check("mesma seed => mesma sequencia (stream card)", same)

    local c = Rng.new(777)
    local cardSeq, shopSeq = {}, {}
    for i = 1, 10 do
        cardSeq[i] = c:random("card", 1000000)
        shopSeq[i] = c:random("shop", 1000000)
    end
    local diverge = false
    for i = 1, 10 do
        if cardSeq[i] ~= shopSeq[i] then diverge = true break end
    end
    check("streams card/shop divergem", diverge)

    local r1 = Rng.new(999)
    for _ = 1, 17 do r1:random("map", 100) end
    local snapshot = r1:getState()
    local after1 = {}
    for i = 1, 8 do after1[i] = r1:random("map", 1000000) end
    local r2 = Rng.fromState(snapshot)
    local after2 = {}
    for i = 1, 8 do after2[i] = r2:random("map", 1000000) end
    local rtOk = true
    for i = 1, 8 do
        if after1[i] ~= after2[i] then rtOk = false break end
    end
    check("roundtrip getState/setState continua identico", rtOk)
    check("counters serializados", snapshot.counters and snapshot.counters.map == 17)

    local r3 = Rng.fromState(nil)
    check("fromState(nil) devolve Rng novo utilizavel", r3:random("misc", 10) >= 1)

    local reg = CardRegistry:new()

    local r5 = Rng.new(42)
    local onlyCommon = true
    for _ = 1, 200 do
        local rar = reg:rollRarity({ common = 100, uncommon = 0, rare = 0, legendary = 0 },
            { rng = r5, stream = "card" })
        if rar ~= "common" then onlyCommon = false break end
    end
    check("peso 100/0/0/0 => sempre common", onlyCommon)
    check("pity nao se move sem rare possivel", (r5.meta.cardPity or 0) == 0)

    local r6 = Rng.new(4242)
    r6.meta.cardPity = Config.Offers.HARD_PITY
    local forced = reg:rollRarity({ common = 90, uncommon = 9, rare = 1, legendary = 0 },
        { rng = r6, stream = "card" })
    check("hard pity forca rare", forced == "rare" or forced == "legendary")
    check("hard pity reseta o contador", (r6.meta.cardPity or 0) == 0)

    local r7 = Rng.new(31337)
    local maxDry, dry = 0, 0
    for _ = 1, 400 do
        local rar = reg:rollRarity({ common = 70, uncommon = 25, rare = 5, legendary = 0 },
            { rng = r7, stream = "card" })
        if rar == "rare" or rar == "legendary" then
            dry = 0
        else
            dry = dry + 1
            if dry > maxDry then maxDry = dry end
        end
    end
    check("pity limita jejum de rare a <= HARD_PITY (" .. maxDry .. ")",
        maxDry <= Config.Offers.HARD_PITY)

    Rng.setActive(Rng.new(2026))
    local deckIds = {}
    local pool = reg:getCardsByClassAndRarity("warrior", "common")
    local tagged = nil
    for _, id in ipairs(pool) do
        local cd = reg:getCard(id)
        if cd and cd.tags and #cd.tags > 0 then tagged = id break end
    end
    if tagged then
        deckIds = { tagged, tagged, tagged }
    end
    local rewards = reg:generateCardRewards("warrior", 3, { deckIds = deckIds })
    check("gera 3 ofertas", #rewards == 3)
    local dupFound = false
    local seen = {}
    for _, rw in ipairs(rewards) do
        if seen[rw.cardId] then dupFound = true end
        seen[rw.cardId] = true
    end
    check("sem duplicata na mesma oferta", not dupFound)
    local AFFINITY_BLACKLIST = { strike = true, defend = true, armor = true, magic = true }
    local tagCounts = reg:countDeckTags(deckIds)
    local coherent = true
    for _, rw in ipairs(rewards) do
        local cd = reg:getCard(rw.cardId)
        local expected = false
        if cd and cd.tags then
            for _, t in ipairs(cd.tags) do
                if not AFFINITY_BLACKLIST[t]
                    and (tagCounts[t] or 0) >= Config.Offers.AFFINITY_MIN_COUNT then
                    expected = true
                end
            end
        end
        if (rw.affinity or false) ~= expected then coherent = false end
    end
    check("flag de afinidade coerente com as tags do deck", coherent)

    local floorRw = reg:generateCardRewards("warrior", 5, { minRarity = "rare" })
    local allRare = #floorRw > 0
    for _, rw in ipairs(floorRw) do
        if rw.rarity ~= "rare" and rw.rarity ~= "legendary" then allRare = false end
    end
    check("minRarity=rare nunca entrega abaixo", allRare)

    local rm = RunManager:new()
    rm:startNewRun("warrior")
    local anyCard = rm:getDeckCardIds()[1]

    check("Config.Game.UPGRADE_LEVEL_CAP == 0 (infinito)", Config.Game.UPGRADE_LEVEL_CAP == 0)
    local lastLvl = 0
    for _ = 1, 7 do
        lastLvl = rm:upgradeCard(anyCard) or lastLvl
    end
    check("7 forjas na mesma carta => nivel 7", lastLvl == 7)
    check("canUpgrade continua true sem cap", rm:canUpgrade(anyCard))

    local deck = rm:buildPlayableDeck()
    local upgraded = nil
    for _, inst in ipairs(deck) do
        if inst.id == anyCard then upgraded = inst break end
    end
    local cdBase = rm.cardDatabase:getCard(anyCard)
    local statOk = upgraded ~= nil
    if upgraded and cdBase and cdBase.attack and cdBase.attack > 0 then
        statOk = upgraded.attack == cdBase.attack + Config.Offers.FORGE_ATK_PER_LVL * 7
    end
    check("instancia forjada +7 tem stats corretos", statOk)
    check("instancia marca upgrades=7", upgraded and upgraded.upgrades == 7)

    local gAtk = RunManager.getForgeGains({ attack = 8, defense = 0 })
    check("forja: ataque puro ganha SO ATQ",
        gAtk.atk ~= nil and gAtk.def == nil and gAtk.effect == nil)
    local gDef = RunManager.getForgeGains({ attack = 0, defense = 6 })
    check("forja: defesa pura ganha SO DEF", gDef.def ~= nil and gDef.atk == nil)
    local gHyb = RunManager.getForgeGains({ attack = 5, defense = 4 })
    check("forja: hibrida ganha ambos", gHyb.atk ~= nil and gHyb.def ~= nil)
    local gEff = RunManager.getForgeGains({ attack = 0, defense = 0,
        effects = { { type = "instant_heal", value = 8 } } })
    check("forja: effect card ganha no efeito",
        gEff.effect ~= nil and gEff.effectIndex == 1)
    local gNone = RunManager.getForgeGains({ attack = 0, defense = 0 })
    check("forja: carta sem nada nao e forjavel", next(gNone) == nil)
    if upgraded and cdBase and (cdBase.defense or 0) == 0 then
        check("instancia atk-only forjada mantem DEF 0",
            (upgraded.defense or 0) == 0)
    end

    local c0 = rm:getPaidForgeCost()
    rm:registerPaidForge()
    local c1 = rm:getPaidForgeCost()
    rm:registerPaidForge()
    local c2 = rm:getPaidForgeCost()
    check("custo forja paga cresce (" .. c0 .. "->" .. c1 .. "->" .. c2 .. ")",
        c0 == Config.Offers.FORGE_COST_BASE and c1 > c0 and c2 > c1)

    Rng.setActive(Rng.new(555))
    local nodesA = {}
    for f = 1, 6 do
        local n = MapManager.generate(f, 1, 3)
        for _, node in ipairs(n) do table.insert(nodesA, node.type) end
    end
    Rng.setActive(Rng.new(555))
    local nodesB = {}
    for f = 1, 6 do
        local n = MapManager.generate(f, 1, 3)
        for _, node in ipairs(n) do table.insert(nodesB, node.type) end
    end
    check("mapa reprodutivel por seed", table.concat(nodesA, ",") == table.concat(nodesB, ","))

    Rng.setActive(Rng.new(88))
    local history = {}
    local ev1 = Events.roll(1, history)
    history[ev1.id] = 1
    local repeated = false
    for _ = 1, 30 do
        local e = Events.roll(1, history)
        if e and e.id == ev1.id then repeated = true break end
    end
    check("evento nao repete no mesmo ato", not repeated)
    local freedElsewhere = false
    for _ = 1, 60 do
        local e = Events.roll(2, history)
        if e and e.id == ev1.id then freedElsewhere = true break end
    end
    check("evento visto no ato 1 pode sair no ato 2", freedElsewhere)

    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER and ER.debugState then
        local fakeGame = { enemy = { spriteId = "cursed_scarecrow", health = 10 } }
        ER.clearCache()
        local okDraw = pcall(function()
            love.graphics.push("all")
            ER.draw(fakeGame, 400, 400)
            love.graphics.pop()
        end)
        check("renderer draw executa em teste", okDraw)
        if okDraw then
            check("renderer inicia em idle", ER.debugState().animName == "idle")
            ER.triggerAttack("attack", nil)
            check("triggerAttack toca o clip attack",
                ER.debugState().animName == "attack")
            for _ = 1, 180 do ER.update(1 / 60) end
            check("attack e ONE-SHOT e volta pro idle",
                ER.debugState().animName == "idle")
        end

        local mi = ER.debugClipMetrics("cursed_scarecrow", "idle")
        local ma = ER.debugClipMetrics("cursed_scarecrow", "attack")
        check("clip metrics: idle medido", mi.h > 0)
        check("clip metrics: attack medido no mesmo canvas do idle", ma.h > 0 and ma.h >= mi.h)
    end

    local SaveManager = require("engine.SaveManager")
    rm.currentRun.rngState = Rng.get():getState()
    local serialized = "return " .. SaveManager.serialize(rm.currentRun)
    local chunk = loadstring and loadstring(serialized) or load(serialized)
    local okParse, revived = pcall(chunk)
    check("run com rngState serializa e parseia", okParse and type(revived) == "table"
        and revived.rngState and revived.rngState.seed == Rng.get().seed)

    local rmJ = RunManager:new()
    rmJ:startNewRun("warrior")
    local cap = rmJ:getMaxJokerSlots()
    local jids = { "joker_001", "joker_002", "joker_003", "joker_004" }
    for _, jid in ipairs(jids) do rmJ:addJokerToRun(jid) end

    check("coleção guarda TODOS os jokers comprados (4)",
        #rmJ.currentRun.jokers == 4)
    check("ativos limitados ao teto (cap)", rmJ:getActiveJokerCount() == cap)
    check("excedente vai pra bancada (nao some)",
        (#rmJ.currentRun.jokers - rmJ:getActiveJokerCount()) == (4 - cap))
    check("buildJokerInstances devolve SO os ativos",
        #rmJ:buildJokerInstances() == cap)
    check("buildAllJokerInstances devolve todos (4)",
        #rmJ:buildAllJokerInstances() == 4)

    local okOff = rmJ:setJokerActive(1, false)
    check("desativar reduz ativos", okOff and rmJ:getActiveJokerCount() == cap - 1)
    local okOn = rmJ:setJokerActive(4, true)
    check("ativar benchado sobe ativos", okOn and rmJ:getActiveJokerCount() == cap)
    local okCap, reason = rmJ:setJokerActive(1, true)
    check("ativar com slots cheios barra (cap)", (not okCap) and reason == "cap")

    do
        local SaveManager = require("engine.SaveManager")
        local s = "return " .. SaveManager.serialize(rmJ.currentRun)
        local chunk = loadstring and loadstring(s) or load(s)
        local okP, revived = pcall(chunk)
        local activeCount = 0
        if okP and revived and revived.jokerActive then
            for i = 1, #(revived.jokers or {}) do
                if revived.jokerActive[i] then activeCount = activeCount + 1 end
            end
        end
        check("jokerActive serializa e mantem contagem",
            okP and activeCount == cap)
    end
    rmJ:endRun()

    Rng.clearActive()

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
