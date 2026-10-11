-- tools/test_unlocks.lua
-- Meta-progressão (src/systems/UnlockSystem.lua + src/data/unlocks.lua):
-- regras de classe/carta, XP/maestria, persistência no perfil, migração de
-- perfil antigo, ofertas NUNCA rolando carta bloqueada (N seeds, rewards +
-- loja + pacotes), override de ferramenta e descoberta.
--   love . test_one test_unlocks
--
-- Perfil é FALSO (ProfileStats._swapForTests) e o override de ferramenta é
-- desligado só aqui dentro — ambos restaurados no fim.

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("meta-progressão: UnlockSystem")
    TK.bootstrap()
    local ProfileStats = require("engine.ProfileStats")
    local UnlockSystem = require("src.systems.UnlockSystem")
    local Data = require("src.data.unlocks")
    local CardRegistry = require("src.systems.CardRegistry")
    local CardDatabase = require("src.systems.CardDatabase")
    local Config = require("src.core.Config")

    local prevOverride = UnlockSystem.isOverrideAll()
    local prevProfile = ProfileStats._swapForTests({ runs = 0, wins = 0 })
    UnlockSystem._resetForTests()

    local ok, err = pcall(function()
        local db = CardDatabase:new()
        local all = db:getAllCards()

        -- ===== Integridade dos dados =====
        local reg = CardRegistry:new()
        local starters = {}
        for _, c in ipairs(Data.CLASS_ORDER) do
            for _, id in ipairs(reg:getStarterDeckForClass(c)) do starters[id] = true end
        end
        local unknown, starterLocked = {}, {}
        for id in pairs(UnlockSystem._lockedBy) do
            if not all[id] then unknown[#unknown + 1] = id end
            if starters[id] then starterLocked[#starterLocked + 1] = id end
        end
        t:eq("todo id travado existe no catálogo", #unknown, 0)
        t:eq("nenhuma carta starter é travada", #starterLocked, 0)
        t:falsy("poção concedida por evento nunca é travada",
            UnlockSystem._lockedBy["effect_healing_potion"])
        for classId, bundles in pairs(Data.CLASS_BUNDLES) do
            for lvl, b in ipairs(bundles) do
                for _, id in ipairs(b.cards) do
                    if all[id] and all[id].class ~= classId then
                        t:check("pacote " .. classId .. " nível " .. lvl .. " só tem carta da classe (" .. id .. ")", false)
                    end
                end
            end
        end

        -- Núcleo saudável: perfil NOVO tem pool liberada em toda raridade
        -- que a oferta usa (common/uncommon/rare) pra cada classe.
        for _, classId in ipairs(Data.CLASS_ORDER) do
            for _, r in ipairs({ "common", "uncommon", "rare" }) do
                local pool = reg:_poolFor(classId, r)
                t:check(("perfil novo: %s/%s tem >= 4 cartas ofertáveis (%d)"):format(classId, r, #pool),
                    #pool >= 4)
            end
        end

        -- ===== Classes =====
        t:truthy("guerreiro liberado de início", UnlockSystem.isClassUnlocked("warrior"))
        t:falsy("mago bloqueado de início", UnlockSystem.isClassUnlocked("mage"))
        t:falsy("ladino bloqueado de início", UnlockSystem.isClassUnlocked("rogue"))
        local info = UnlockSystem.getClassUnlockInfo("mage")
        t:eq("info mago: reqKey", info.reqKey, "unlock.class.mage_req")
        t:eq("info mago: goal = 2", info.goal, 2)
        t:eq("info mago: progress 0", info.progress, 0)
        local m0 = UnlockSystem.getClassMastery("warrior")
        t:eq("maestria inicial nível 0", m0.level, 0)
        t:eq("maestria maxLevel 5", m0.maxLevel, 5)
        t:eq("maestria xpToNext do nível 0", m0.xpToNext, Data.LEVEL_COSTS[1])

        local unlockedEvents = {}
        UnlockSystem.onUnlock(function(kind, id) unlockedEvents[#unlockedEvents + 1] = kind .. ":" .. id end)

        -- Chefe do ato 1: libera o marco joker_001, não libera classe.
        t:falsy("joker_001 bloqueado antes", UnlockSystem.isCardUnlocked("joker_001"))
        local nc1, ncl1 = UnlockSystem.onBossDefeated(1, nil)
        t:truthy("chefe ato 1 libera joker_001", UnlockSystem.isCardUnlocked("joker_001"))
        t:eq("chefe ato 1 não libera classe", #ncl1, 0)
        t:eq("info mago: progress 1 após ato 1", UnlockSystem.getClassUnlockInfo("mage").progress, 1)
        -- Chefe do ato 2: mago.
        local _, ncl2 = UnlockSystem.onBossDefeated(2, nil)
        t:eq("chefe ato 2 libera exatamente o mago", ncl2[1], "mage")
        t:truthy("mago liberado", UnlockSystem.isClassUnlocked("mage"))
        t:falsy("ladino ainda bloqueado", UnlockSystem.isClassUnlocked("rogue"))
        t:truthy("listener recebeu class:mage", (function()
            for _, e in ipairs(unlockedEvents) do if e == "class:mage" then return true end end
        end)())
        t:eq("chefe repetido não reprocessa", #(select(1, UnlockSystem.onBossDefeated(2, nil))), 0)

        -- ===== XP / maestria / fim de run =====
        t:eq("XP morte no andar 1 do ato 1 = piso", UnlockSystem.computeRunXP({ actNumber = 1, floorInAct = 1 }), Data.XP.MINIMUM)
        local xpA2 = UnlockSystem.computeRunXP({ actNumber = 2, floorInAct = 4 })
        t:eq("XP morte ato 2 andar 4 = 12 andares + 1 ato", xpA2, 12 * Data.XP.PER_FLOOR + Data.XP.PER_ACT)

        local r1 = UnlockSystem.onRunEnded({ classId = "warrior", victory = false, actNumber = 3, floorInAct = 2 })
        t:truthy("fim de run devolve resultado", r1 and r1.newCards and r1.newClasses)
        t:truthy("fim de run: ganhou nível", (r1.levelsGained or 0) >= 1)
        t:eq("pendente do meio da run aparece no reveal (mago)", r1.newClasses[1], "mage")
        local lvl1 = Data.CLASS_BUNDLES.warrior[1].cards
        for _, id in ipairs(lvl1) do
            t:truthy("nível 1 libera " .. id, UnlockSystem.isCardUnlocked(id))
        end
        t:truthy("reveal lista o pacote 1", r1.bundles[1] and r1.bundles[1].theme == "warrior_1")
        t:falsy("pacote do MAGO não liberou com XP do guerreiro",
            UnlockSystem.isCardUnlocked(Data.CLASS_BUNDLES.mage[1].cards[1]))

        -- Vitória: ladino + marco de vitória; contadores próprios (não dependem
        -- da ordem com ProfileStats.recordVictory).
        local r2 = UnlockSystem.onRunEnded({ classId = "warrior", victory = true,
            actNumber = Config.TotalActs or 3, floorInAct = 8 })
        t:truthy("vitória libera ladino", UnlockSystem.isClassUnlocked("rogue"))
        t:truthy("vitória reporta ladino como NOVO", (function()
            for _, c in ipairs(r2.newClasses) do if c == "rogue" then return true end end
        end)())
        t:truthy("vitória libera joker_003", UnlockSystem.isCardUnlocked("joker_003"))
        -- Morte no endless não paga a run de novo.
        t:eq("morte no endless só paga o endless",
            UnlockSystem.computeRunXP({ actNumber = 5, floorInAct = 2, endlessMode = true, floorsInEndless = 4 }),
            math.max(Data.XP.MINIMUM, 4 * Data.XP.PER_ENDLESS))

        -- ===== Persistência: o estado mora no perfil =====
        local prof = ProfileStats.get()
        t:truthy("estado salvo em profile.unlocks", type(prof.unlocks) == "table")
        t:truthy("XP do guerreiro persistido", (prof.unlocks.mastery.warrior or 0) > 0)
        t:truthy("classe gravada explicitamente", prof.unlocks.classes.mage == true)
        local SaveManager = require("engine.SaveManager")
        local okSer, txt = pcall(SaveManager.serialize, prof)
        t:truthy("perfil com unlocks serializa", okSer and type(txt) == "string")
        local reloaded = okSer and load("return " .. txt)() or nil
        ProfileStats._swapForTests(reloaded)
        t:truthy("recarregado: mago segue liberado", UnlockSystem.isClassUnlocked("mage"))
        t:truthy("recarregado: pacote 1 segue liberado", UnlockSystem.isCardUnlocked(lvl1[1]))

        -- ===== Migração de perfil antigo =====
        ProfileStats._swapForTests({ runs = 12, wins = 0, bestAct = 3, bestFloor = 4,
            cardsSeen = { warrior_bash = true } })
        UnlockSystem.ensure()
        local mig = ProfileStats.get().unlocks
        t:truthy("migração marcada", mig.migratedLegacy)
        t:eq("migração: chegou ao ato 3 = 2 atos completos", mig.actsCleared, 2)
        t:truthy("migração: mago liberado retroativamente", UnlockSystem.isClassUnlocked("mage"))
        t:truthy("migração: XP retroativo > 0", (mig.mastery.warrior or 0) > 0)
        t:truthy("migração: cardsSeen vira descoberta", UnlockSystem.isCardDiscovered("warrior_bash"))
        ProfileStats._swapForTests({ runs = 3, wins = 1, bestAct = 3, winsByClass = { rogue = true } })
        UnlockSystem.ensure()
        t:truthy("migração com vitória: ladino liberado", UnlockSystem.isClassUnlocked("rogue"))
        t:eq("migração: classe vencedora ganha maestria máxima",
            UnlockSystem.getClassMastery("rogue").level, 5)
        -- Perfil novo não é tratado como antigo.
        ProfileStats._swapForTests({ runs = 0, wins = 0 })
        UnlockSystem.ensure()
        t:falsy("perfil novo não migra", ProfileStats.get().unlocks.migratedLegacy)

        -- ===== Ofertas nunca rolam carta bloqueada =====
        local Rng = require("src.systems.Rng")
        local BoosterPackSystem = require("src.systems.BoosterPackSystem")
        local ActSystem = require("src.systems.ActSystem")
        local leaks = {}
        local rolled = 0
        for seed = 1, 60 do
            Rng.setActive(Rng.new(seed))
            for _, classId in ipairs(Data.CLASS_ORDER) do
                local act = (seed % 3) + 1
                local rw = ActSystem.getRarityWeights(act)
                for _, rr in ipairs(reg:generateCardRewards(classId, 3,
                        { rarityWeights = rw, actNumber = act, minRarity = (seed % 5 == 0) and "rare" or nil })) do
                    rolled = rolled + 1
                    if not UnlockSystem.isCardUnlocked(rr.cardId) then leaks[#leaks + 1] = rr.cardId end
                end
                for _, kind in ipairs({ "Standard", "Buffoon", "Arcana", "Spectral" }) do
                    local inst = BoosterPackSystem.generateContents({ kind = kind, size = 3,
                        classId = classId, rarityWeights = rw })
                    for _, c in ipairs(inst) do
                        rolled = rolled + 1
                        if not UnlockSystem.isCardUnlocked(c.id) then leaks[#leaks + 1] = c.id end
                    end
                end
            end
        end
        t:truthy("rolou ofertas suficientes pra valer (" .. rolled .. ")", rolled > 1000)
        t:eq("nenhuma carta bloqueada em rewards/loja/pacotes (60 seeds x 3 classes)", #leaks, 0)
        if #leaks > 0 then print("    vazou: " .. table.concat(leaks, ", ", 1, math.min(#leaks, 8))) end

        -- Loja de verdade (ShopSystem) também.
        local ShopSystem = require("src.systems.ShopSystem")
        local shop = ShopSystem:new()
        local shopLeaks, shopCards = 0, 0
        for seed = 100, 130 do
            Rng.setActive(Rng.new(seed))
            for _, classId in ipairs(Data.CLASS_ORDER) do
                shop:setContext({ classId = classId,
                    rarityWeights = ActSystem.getRarityWeights(3), actNumber = 3 })
                shop:setMode("shop")
                shop:generateOffers()
                for _, o in ipairs(shop.currentOffers) do
                    if o.type == "card" then
                        shopCards = shopCards + 1
                        if not UnlockSystem.isCardUnlocked(o.id) then shopLeaks = shopLeaks + 1 end
                    end
                end
            end
        end
        t:truthy("loja gerou cartas (" .. shopCards .. ")", shopCards > 100)
        t:eq("ShopSystem não oferta carta bloqueada", shopLeaks, 0)

        -- Ofertada = descoberta.
        Rng.setActive(Rng.new(7))
        local pick = reg:pickRewardCard({ classId = "warrior" })
        t:truthy("carta ofertada vira descoberta", pick and UnlockSystem.isCardDiscovered(pick.cardId))

        -- ===== Override de ferramenta =====
        UnlockSystem.setOverrideAll(true)
        t:truthy("override: carta de maestria 5 liberada",
            UnlockSystem.isCardUnlocked(Data.CLASS_BUNDLES.rogue[5].cards[3]))
        t:truthy("override: ladino liberado", UnlockSystem.isClassUnlocked("rogue"))
        t:falsy("override NÃO mente pro 'real' (conquistas)", UnlockSystem.isClassUnlockedReal("rogue"))
        local full = 0
        for _, classId in ipairs(Data.CLASS_ORDER) do
            full = full + #reg:_poolFor(classId, "rare")
        end
        UnlockSystem.setOverrideAll(false)
        local partial = 0
        for _, classId in ipairs(Data.CLASS_ORDER) do
            partial = partial + #reg:_poolFor(classId, "rare")
        end
        t:truthy(("override abre o catálogo inteiro (%d raras vs %d)"):format(full, partial), full > partial)

        -- Contagem pública.
        local nc, tot, ncls, totCls = UnlockSystem.unlockedCount()
        t:eq("unlockedCount: total = catálogo", tot, db:getTotalCardCount())
        t:truthy("unlockedCount: perfil novo < total", nc < tot)
        t:eq("unlockedCount: 1 classe num perfil novo", ncls, 1)
        t:eq("unlockedCount: 3 classes no total", totCls, 3)
    end)
    t:truthy("suite rodou sem erro" .. (ok and "" or (": " .. tostring(err))), ok)

    UnlockSystem._resetForTests()
    UnlockSystem.setOverrideAll(prevOverride)
    ProfileStats._swapForTests(prevProfile)
    return t:done()
end

return M
