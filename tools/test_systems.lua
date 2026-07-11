-- tools/test_systems.lua
-- Valida a entrega STS-improvements v1 (docs/plan/sts-improvements-v1.md):
--   Step 1 — Rng seedável com streams (determinismo + roundtrip getState)
--   Step 2 — pity de raridade + afinidade/anti-duplicata nas ofertas
--   Step 3 — upgrade infinito + custo crescente da forja paga
--   Step 6 — Events.roll com histórico por ato
-- Rodar: love . test_systems   (headless-ish; sai com exit code)

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

    -- ===== Step 1: Rng =====

    -- 1. Determinismo por seed: mesma seed → mesma sequência por stream.
    local a = Rng.new(12345)
    local b = Rng.new(12345)
    local same = true
    for _ = 1, 50 do
        if a:random("card", 1000) ~= b:random("card", 1000) then same = false break end
    end
    check("mesma seed => mesma sequencia (stream card)", same)

    -- 2. Streams independentes: card e shop divergem entre si.
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

    -- 3. Roundtrip getState/setState: salvar e restaurar continua a sequência.
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

    -- 4. Estado ausente/corrompido não crasha (save antigo).
    local r3 = Rng.fromState(nil)
    check("fromState(nil) devolve Rng novo utilizavel", r3:random("misc", 10) >= 1)

    -- ===== Step 2: pity + ofertas =====

    local reg = CardRegistry:new()

    -- 5. Peso 100/0/0/0: sempre common e o pity NÃO se move (rare impossível).
    local r5 = Rng.new(42)
    local onlyCommon = true
    for _ = 1, 200 do
        local rar = reg:rollRarity({ common = 100, uncommon = 0, rare = 0, legendary = 0 },
            { rng = r5, stream = "card" })
        if rar ~= "common" then onlyCommon = false break end
    end
    check("peso 100/0/0/0 => sempre common", onlyCommon)
    check("pity nao se move sem rare possivel", (r5.meta.cardPity or 0) == 0)

    -- 6. Hard pity: com contador no limite, o próximo roll é rare+.
    local r6 = Rng.new(4242)
    r6.meta.cardPity = Config.Offers.HARD_PITY
    local forced = reg:rollRarity({ common = 90, uncommon = 9, rare = 1, legendary = 0 },
        { rng = r6, stream = "card" })
    check("hard pity forca rare", forced == "rare" or forced == "legendary")
    check("hard pity reseta o contador", (r6.meta.cardPity or 0) == 0)

    -- 7. Janela de pity: com pesos do ato 1 (rare 5%), nunca passa de HARD_PITY
    --    ofertas sem rare+ — e o crescimento do peso segura a janela real bem
    --    abaixo do teto na prática.
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

    -- 8. Ofertas sem duplicata + estrutura de afinidade coerente.
    Rng.setActive(Rng.new(2026))
    local deckIds = {}
    -- Monta um deck com 3 cópias da primeira carta common do warrior que tenha
    -- tags (afinidade precisa de tag presente 2+ vezes).
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
    -- Coerência do flag: affinity ⟺ carta tem tag forte do deck.
    local tagCounts = reg:countDeckTags(deckIds)
    local coherent = true
    for _, rw in ipairs(rewards) do
        local cd = reg:getCard(rw.cardId)
        local expected = false
        if cd and cd.tags then
            for _, t in ipairs(cd.tags) do
                if (tagCounts[t] or 0) >= Config.Offers.AFFINITY_MIN_COUNT then
                    expected = true
                end
            end
        end
        if (rw.affinity or false) ~= expected then coherent = false end
    end
    check("flag de afinidade coerente com as tags do deck", coherent)

    -- 9. minRarity continua respeitado (piso de elite/boss).
    local floorRw = reg:generateCardRewards("warrior", 5, { minRarity = "rare" })
    local allRare = #floorRw > 0
    for _, rw in ipairs(floorRw) do
        if rw.rarity ~= "rare" and rw.rarity ~= "legendary" then allRare = false end
    end
    check("minRarity=rare nunca entrega abaixo", allRare)

    -- ===== Step 3: upgrade infinito + custo de forja =====

    local rm = RunManager:new()
    rm:startNewRun("warrior")
    local anyCard = rm:getDeckCardIds()[1]

    -- 10. Cap 0 = infinito: 7 forjas seguidas funcionam.
    check("Config.Game.UPGRADE_LEVEL_CAP == 0 (infinito)", Config.Game.UPGRADE_LEVEL_CAP == 0)
    local lastLvl = 0
    for _ = 1, 7 do
        lastLvl = rm:upgradeCard(anyCard) or lastLvl
    end
    check("7 forjas na mesma carta => nivel 7", lastLvl == 7)
    check("canUpgrade continua true sem cap", rm:canUpgrade(anyCard))

    -- 11. Stats da instância refletem o nível (fonte única Config.Offers).
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

    -- 11b. Regra de forja por CENÁRIO (playtest: ataque puro ganhava DEF
    -- fantasma — defense=0 é truthy). getForgeGains é a fonte única.
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
    -- Instância real: a carta forjada +7 não pode ter DEF fantasma.
    if upgraded and cdBase and (cdBase.defense or 0) == 0 then
        check("instancia atk-only forjada mantem DEF 0",
            (upgraded.defense or 0) == 0)
    end

    -- 12. Custo da forja paga cresce: base 5 -> 7 -> 9 (x1.35, arredondado).
    local c0 = rm:getPaidForgeCost()
    rm:registerPaidForge()
    local c1 = rm:getPaidForgeCost()
    rm:registerPaidForge()
    local c2 = rm:getPaidForgeCost()
    check("custo forja paga cresce (" .. c0 .. "->" .. c1 .. "->" .. c2 .. ")",
        c0 == Config.Offers.FORGE_COST_BASE and c1 > c0 and c2 > c1)

    -- ===== Steps 1+2: reprodutibilidade ponta-a-ponta =====

    -- 13. Mapa: mesma seed => mesma sequência de nodes.
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

    -- ===== Step 6: eventos =====

    -- 14. Histórico: evento visto no ato não repete (com pool > 1).
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
    -- Ato diferente libera o evento de novo.
    local freedElsewhere = false
    for _ = 1, 60 do
        local e = Events.roll(2, history)
        if e and e.id == ev1.id then freedElsewhere = true break end
    end
    check("evento visto no ato 1 pode sair no ato 2", freedElsewhere)

    -- ===== Fix Jul/2026: attack anim (loop infinito + encolhimento) =====

    -- 14b. Ciclo attack→idle: o clip de ataque é ONE-SHOT e volta pro idle
    -- sozinho (bug: caía no default loop+pingpong e repetia pra sempre).
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
            -- 3s simulados >> 9 frames a 12fps (~0.75s): tem que ter voltado.
            for _ = 1, 180 do ER.update(1 / 60) end
            check("attack e ONE-SHOT e volta pro idle",
                ER.debugState().animName == "idle")
        end

        -- 14c. Escala estável: a referência de escala é o IDLE; o canvas cru
        -- do attack (PixelLab sem crop) é maior mas NÃO pode mudar o corpo.
        local mi = ER.debugClipMetrics("cursed_scarecrow", "idle")
        local ma = ER.debugClipMetrics("cursed_scarecrow", "attack")
        check("clip metrics: idle medido", mi.h > 0)
        check("clip metrics: attack canvas maior (cru)", ma.h > mi.h)
    end

    -- 15. Save do RunManager carrega rngState (roundtrip via serialize).
    local SaveManager = require("engine.SaveManager")
    rm.currentRun.rngState = Rng.get():getState()
    local serialized = "return " .. SaveManager.serialize(rm.currentRun)
    local chunk = loadstring and loadstring(serialized) or load(serialized)
    local okParse, revived = pcall(chunk)
    check("run com rngState serializa e parseia", okParse and type(revived) == "table"
        and revived.rngState and revived.rngState.seed == Rng.get().seed)

    Rng.clearActive()

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
