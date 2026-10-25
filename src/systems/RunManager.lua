local Debug = require("src.core.Debug")

local RunManager = {}
RunManager.__index = RunManager

local CardRegistry = require("src.systems.CardRegistry")
local CardDatabase = require("src.systems.CardDatabase")
local SaveManager  = require("engine.SaveManager")
local Rng          = require("src.systems.Rng")
local Config       = require("src.core.Config")

function RunManager:new()
    local instance = setmetatable({}, RunManager)
    instance.cardRegistry = CardRegistry:new()
    instance.cardDatabase = CardDatabase:new()

    instance.currentRun = nil
    instance.isRunActive = false

    return instance
end

function RunManager:startNewRun(classId, opts)
    local selectedClass = self.cardRegistry:getClassInfo(classId)
    if not selectedClass then
        error("Classe nao encontrada: " .. tostring(classId))
    end

    local rng = Rng.setActive(Rng.new())
    Debug.log("[RunManager] nova run com seed " .. tostring(rng.seed))

    self.currentRun = {
        classId = classId,
        className = selectedClass.name,

        runSeed = rng.seed,

        currentDeck = {},

        jokers = {},
        jokerActive = {},

        currentFloor = 1,
        battlesWon = 0,
        cardsAdded = 0,

        actNumber = 1,
        floorInAct = 1,
        endlessMode = false,
        seal = math.max(0, math.floor((opts and opts.seal) or 0)),

        pendingNodes = nil,
        currentNode = nil,
        mapHistory = {},

        journal = {},
        journalOpen = nil,

        totalDamageDealt = 0,
        totalDamageTaken = 0,
        cardsPlayed = 0,

        cardHistory = {},

        upgraded = {},

        playerState = {
            maxHealth = 100,
            currentHealth = 100,
            gold = 99
        }
    }

    self:initializeStarterDeck(classId)

    self.isRunActive = true
    return self.currentRun
end

function RunManager:initializeStarterDeck(classId)
    local starterCards = self.cardRegistry:getStarterDeckForClass(classId)
    for _, cardId in ipairs(starterCards) do
        table.insert(self.currentRun.currentDeck, cardId)
    end
end

function RunManager:getCurrentDeck()
    if not self.currentRun then return {} end
    return self.currentRun.currentDeck
end

function RunManager:getDeckCardIds()
    if not self.currentRun then return {} end
    local ids = {}
    for _, entry in ipairs(self.currentRun.currentDeck) do
        local id = type(entry) == "table" and entry.id or entry
        if id then table.insert(ids, id) end
    end
    return ids
end

function RunManager:addCardToDeck(cardId, meta)
    if not self.currentRun then
        return false
    end

    local entry = cardId
    if meta and (meta.edition or meta.seal) then
        entry = { id = cardId, edition = meta.edition, seal = meta.seal }
    end
    table.insert(self.currentRun.currentDeck, entry)
    self.currentRun.cardsAdded = self.currentRun.cardsAdded + 1

    table.insert(self.currentRun.cardHistory, {
        cardId = cardId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime(),
        meta = meta,
    })

    self:journalNote({ kind = "card", id = cardId,
                       edition = meta and meta.edition })

    return true
end

function RunManager:getMaxJokerSlots()
    local base = (Config.Game and Config.Game.MAX_JOKER_SLOTS) or 3
    if not self.currentRun then return base end
    return self.currentRun.maxJokerSlots or (base + self:getServiceCount("joker_slot"))
end

function RunManager:getActiveJokerCount()
    if not self.currentRun then return 0 end
    local act = self.currentRun.jokerActive or {}
    local n = 0
    for i = 1, #(self.currentRun.jokers or {}) do
        if act[i] then n = n + 1 end
    end
    return n
end

function RunManager:_ensureJokerActive()
    if not self.currentRun then return end
    self.currentRun.jokers = self.currentRun.jokers or {}
    local act = self.currentRun.jokerActive
    if not act then
        act = {}
        local cap = self:getMaxJokerSlots()
        for i = 1, #self.currentRun.jokers do
            act[i] = (i <= cap)
        end
        self.currentRun.jokerActive = act
    else
        local cap = self:getMaxJokerSlots()
        local active = 0
        for i = 1, #self.currentRun.jokers do
            if act[i] == nil then act[i] = false end
            if act[i] then
                active = active + 1
                if active > cap then act[i] = false end
            end
        end
    end
end

function RunManager:addJokerToRun(jokerId, meta)
    if not self.currentRun then return nil, false end
    self.currentRun.jokers = self.currentRun.jokers or {}
    self:_ensureJokerActive()

    local entry = jokerId
    if meta and (meta.edition or meta.seal) then
        entry = { id = jokerId, edition = meta.edition, seal = meta.seal }
    end
    table.insert(self.currentRun.jokers, entry)
    local idx = #self.currentRun.jokers

    local activated = self:getActiveJokerCount() < self:getMaxJokerSlots()
    self.currentRun.jokerActive[idx] = activated

    table.insert(self.currentRun.cardHistory, {
        cardId = jokerId,
        floor = self.currentRun.currentFloor,
        timestamp = love.timer.getTime(),
        meta = meta,
        slot = "joker",
    })

    self:journalNote({ kind = "joker", id = jokerId, active = activated,
                       edition = meta and meta.edition })

    return idx, activated
end

function RunManager:removeJokerAt(index)
    if not self.currentRun or not self.currentRun.jokers then return false end
    if not self.currentRun.jokers[index] then return false end
    self:_ensureJokerActive()
    table.remove(self.currentRun.jokers, index)
    table.remove(self.currentRun.jokerActive, index)
    return true
end

function RunManager:removeJokerFromRun(jokerId)
    if not self.currentRun or not self.currentRun.jokers then return false end
    self:_ensureJokerActive()
    for i, entry in ipairs(self.currentRun.jokers) do
        local id = type(entry) == "table" and entry.id or entry
        if id == jokerId then
            table.remove(self.currentRun.jokers, i)
            table.remove(self.currentRun.jokerActive, i)
            return true
        end
    end
    return false
end

function RunManager:setJokerActive(index, active)
    if not self.currentRun then return false, "no_run" end
    self:_ensureJokerActive()
    if not self.currentRun.jokers[index] then return false, "invalid" end
    if active and not self.currentRun.jokerActive[index] then
        if self:getActiveJokerCount() >= self:getMaxJokerSlots() then
            return false, "cap"
        end
    end
    self.currentRun.jokerActive[index] = active and true or false
    return true
end

function RunManager:isJokerActive(index)
    if not self.currentRun then return false end
    self:_ensureJokerActive()
    return self.currentRun.jokerActive[index] and true or false
end

function RunManager:_instanceFromJokerEntry(entry)
    local id, edition, seal
    if type(entry) == "table" then
        id, edition, seal = entry.id, entry.edition, entry.seal
    else
        id = entry
    end
    local cardData = self.cardDatabase:getCard(id)
    if not cardData then
        Debug.warn("[RunManager] AVISO: joker não encontrado no banco de dados: " .. tostring(id))
        return nil
    end
    local instance = self.cardDatabase:createCardInstance(cardData)
    if edition and edition ~= "negative" then instance.edition = edition end
    if seal then instance.seal = seal end
    return instance
end

function RunManager:buildJokerInstances()
    if not self.currentRun or not self.currentRun.jokers then return {} end
    self:_ensureJokerActive()

    local instances = {}
    for i, entry in ipairs(self.currentRun.jokers) do
        if self.currentRun.jokerActive[i] then
            local inst = self:_instanceFromJokerEntry(entry)
            if inst then
                inst._ownedIndex = i
                table.insert(instances, inst)
            end
        end
    end
    return instances
end

function RunManager:buildAllJokerInstances()
    if not self.currentRun or not self.currentRun.jokers then return {} end
    self:_ensureJokerActive()

    local instances = {}
    for i, entry in ipairs(self.currentRun.jokers) do
        local inst = self:_instanceFromJokerEntry(entry)
        if inst then
            inst._ownedIndex = i
            inst._active = self.currentRun.jokerActive[i] and true or false
            table.insert(instances, inst)
        end
    end
    return instances
end

function RunManager:removeCardFromDeck(cardId)
    if not self.currentRun then return false end

    for i, deckCardId in ipairs(self.currentRun.currentDeck) do
        if deckCardId == cardId then
            table.remove(self.currentRun.currentDeck, i)
            self:journalNote({ kind = "remove", id = cardId })
            return true
        end
    end

    return false
end

function RunManager:generateNextNodes(numNodes)
    if not self.currentRun then return nil end
    local MapManager = require("src.systems.MapManager")
    local act = self.currentRun.actNumber or 1
    local floorInAct = self.currentRun.floorInAct or 1
    self.currentRun.pendingNodes = MapManager.generate(floorInAct, act, numNodes or 3,
        { eliteMul = require("src.systems.RunModifiers").eliteWeightMul(self.currentRun) })
    require("src.systems.EnemyRoster").assignNodes(self.currentRun,
        self.currentRun.pendingNodes)
    return self.currentRun.pendingNodes
end

function RunManager:repairPendingNodes()
    local run = self.currentRun
    if not run or type(run.pendingNodes) ~= "table" then return 0 end
    local fixed, removed = require("src.systems.MapManager").dedupeNodes(run.pendingNodes)
    if removed > 0 then
        Debug.warn("[RunManager] encruzilhada salva com tipo repetido: " .. removed .. " opcao(oes) removida(s)")
        run.pendingNodes = (#fixed > 0) and fixed or nil
    end
    return removed
end

function RunManager:chooseNode(index, snapshot)
    if not self.currentRun or not self.currentRun.pendingNodes then return nil end
    local node = self.currentRun.pendingNodes[index]
    if not node then return nil end

    local options = self.currentRun.pendingNodes
    self.currentRun.currentNode = node
    self.currentRun.pendingNodes = nil
    table.insert(self.currentRun.mapHistory, {
        actNumber = self.currentRun.actNumber,
        floorInAct = self.currentRun.floorInAct,
        type = node.type,
    })

    self:journalBegin(node, snapshot, options, index)

    return node
end

function RunManager:advanceFloorInAct(totalActs)
    totalActs = totalActs or Config.TotalActs or 3
    if not self.currentRun then return "advanced" end
    local MapManager = require("src.systems.MapManager")

    self.currentRun.floorInAct = self.currentRun.floorInAct + 1
    self.currentRun.currentFloor = self.currentRun.currentFloor + 1

    local status = "advanced"
    if self.currentRun.floorInAct > MapManager.FLOORS_PER_ACT then
        if self.currentRun.actNumber >= totalActs then
            local jaEndless = self.currentRun.actNumber > totalActs
            self.currentRun.endlessMode = true
            self.currentRun.floorInAct = 1
            self.currentRun.actNumber = totalActs + 1
            status = jaEndless and "endless_cycle" or "endless_start"
            require("src.systems.RunModifiers").beginEndlessCycle(self.currentRun)
        else
            self.currentRun.actNumber = self.currentRun.actNumber + 1
            self.currentRun.floorInAct = 1
            status = "act_complete"
        end
    end
    if self.currentRun.endlessMode then
        self.currentRun.floorsInEndless = math.max(0,
            (self.currentRun.currentFloor or 0) - totalActs * MapManager.FLOORS_PER_ACT)
    end
    return status
end

function RunManager:getCurrentNode()
    return self.currentRun and self.currentRun.currentNode
end

function RunManager:getPendingNodes()
    return self.currentRun and self.currentRun.pendingNodes
end

function RunManager:_openJournalEntry()
    local run = self.currentRun
    if not run or not run.journalOpen then return nil end
    return run.journal and run.journal[run.journalOpen]
end

function RunManager:journalBegin(node, snapshot, options, pick)
    local run = self.currentRun
    if not run or not node then return nil end
    run.journal = run.journal or {}
    snapshot = snapshot or {}
    local branches = nil
    if type(options) == "table" and #options > 0 then
        branches = {}
        for i, opt in ipairs(options) do branches[i] = tostring(opt.type or "?") end
        if not pick or not options[pick] then
            pick = nil
            for i, opt in ipairs(options) do if opt == node then pick = i end end
        end
    end

    if run.journalOpen then
        self:journalEnd(snapshot)
    end

    table.insert(run.journal, {
        act    = run.actNumber or 1,
        floor  = run.floorInAct or 1,
        gfloor = run.currentFloor or 1,
        type   = node.type,
        branches = branches,
        pick   = branches and pick or nil,
        hpIn   = snapshot.hp,
        maxHp  = snapshot.maxHp,
        goldIn = snapshot.gold,
        gains  = {},
        at     = os.time(),
    })
    run.journalOpen = #run.journal
    return run.journal[run.journalOpen]
end

function RunManager:journalNote(entry)
    if not entry then return false end
    local open = self:_openJournalEntry()
    if not open then
        local Debug = require("src.core.Debug")
        Debug.trace("[roteiro] nota fora de no:", entry.kind, tostring(entry.id))
        return false
    end
    open.gains = open.gains or {}
    table.insert(open.gains, entry)
    return true
end

function RunManager:journalEvent(eventId, optionIndex, optionLabel)
    local open = self:_openJournalEntry()
    if not open then return false end
    if eventId then open.eventId = eventId end
    if optionIndex then open.optionIndex = optionIndex end
    if optionLabel then open.optionLabel = optionLabel end
    return true
end

function RunManager:journalEnd(snapshot)
    local run = self.currentRun
    if not run or not run.journalOpen then return false end
    local open = run.journal and run.journal[run.journalOpen]
    run.journalOpen = nil
    if not open then return false end
    snapshot = snapshot or {}
    open.hpOut   = snapshot.hp
    open.goldOut = snapshot.gold
    if snapshot.maxHp then open.maxHp = snapshot.maxHp end
    return true
end

function RunManager:getJournal()
    local run = self.currentRun
    if not run then return {} end

    local mh = run.mapHistory or {}
    local jn = run.journal or {}
    local legacyCount = math.max(0, #mh - #jn)

    local out = {}
    for k = 1, legacyCount do
        local h = mh[k]
        table.insert(out, {
            act = h.actNumber or 1,
            floor = h.floorInAct or 1,
            gfloor = k,
            type = h.type,
            gains = {},
            partial = true,
        })
    end
    for _, e in ipairs(jn) do
        table.insert(out, e)
    end
    return out
end

function RunManager:isJournalEntryOpen(entry)
    local open = self:_openJournalEntry()
    return open ~= nil and open == entry
end

function RunManager.getUpgradeCap()
    local cap = Config.Game.UPGRADE_LEVEL_CAP
    if cap == nil then return 5 end
    return cap
end

function RunManager:getEntryLevel(entry)
    if entry == nil then return 0 end
    if type(entry) == "table" then
        if entry.up then return entry.up end
        local legacy = self.currentRun and self.currentRun.upgraded
        return (legacy and legacy[entry.id]) or 0
    end
    local legacy = self.currentRun and self.currentRun.upgraded
    return (legacy and legacy[entry]) or 0
end

function RunManager.entryId(entry)
    if entry == nil then return nil end
    if type(entry) == "table" then return entry.id end
    return entry
end

function RunManager:getUpgradesAt(index)
    if not self.currentRun then return 0 end
    return self:getEntryLevel(self.currentRun.currentDeck[index])
end

function RunManager:_entryTableAt(index)
    local deck = self.currentRun and self.currentRun.currentDeck
    local entry = deck and deck[index]
    if not entry then return nil end
    if type(entry) == "table" then
        entry.up = entry.up or self:getEntryLevel(entry)
        return entry
    end
    local t = { id = entry, up = self:getEntryLevel(entry) }
    deck[index] = t
    return t
end

function RunManager:getDeckCopies()
    local out = {}
    if not self.currentRun then return out end
    for i, entry in ipairs(self.currentRun.currentDeck) do
        local id = RunManager.entryId(entry)
        if id then
            table.insert(out, {
                index = i,
                id = id,
                level = self:getEntryLevel(entry),
                edition = type(entry) == "table" and entry.edition or nil,
                seal = type(entry) == "table" and entry.seal or nil,
            })
        end
    end
    return out
end

function RunManager:hasAnyUpgrade()
    if not self.currentRun then return false end
    if next(self.currentRun.upgraded or {}) then return true end
    for _, entry in ipairs(self.currentRun.currentDeck or {}) do
        if type(entry) == "table" and (entry.up or 0) > 0 then return true end
    end
    return false
end

function RunManager:upgradeCardAt(index)
    if not self.currentRun then return nil end
    local entry = self.currentRun.currentDeck[index]
    if not entry then
        Debug.warn("[RunManager] upgradeCardAt: indice fora do deck: " .. tostring(index))
        return nil
    end
    local current = self:getEntryLevel(entry)
    local cap = RunManager.getUpgradeCap()
    if cap > 0 and current >= cap then
        return nil
    end
    local t = self:_entryTableAt(index)
    if not t then return nil end
    t.up = current + 1
    self:journalNote({ kind = "forge", id = t.id, lvl = t.up })
    return t.up
end

function RunManager:canUpgradeAt(index)
    if not self.currentRun then return false end
    local entry = self.currentRun.currentDeck[index]
    local id = RunManager.entryId(entry)
    if not id then return false end
    local cardData = self.cardDatabase:getCard(id)
    if not cardData or next(RunManager.getForgeGains(cardData)) == nil then
        return false
    end
    local cap = RunManager.getUpgradeCap()
    if cap <= 0 then return true end
    return self:getEntryLevel(entry) < cap
end

function RunManager:removeCardAt(index)
    if not self.currentRun then return false end
    local entry = self.currentRun.currentDeck[index]
    if not entry then return false end
    local id = RunManager.entryId(entry)
    table.remove(self.currentRun.currentDeck, index)
    self:journalNote({ kind = "remove", id = id })
    return true
end

function RunManager:duplicateCardAt(index)
    if not self.currentRun then return nil end
    local entry = self.currentRun.currentDeck[index]
    if not entry then return nil end
    local id = RunManager.entryId(entry)
    local lvl = self:getEntryLevel(entry)
    local meta = nil
    if type(entry) == "table" and (entry.edition or entry.seal) then
        meta = { edition = entry.edition, seal = entry.seal }
    end
    if not self:addCardToDeck(id, meta) then return nil end
    local newIndex = #self.currentRun.currentDeck
    if lvl > 0 then
        local t = self:_entryTableAt(newIndex)
        if t then t.up = lvl end
    end
    return newIndex
end

function RunManager:upgradeCard(cardId)
    if not self.currentRun then return 0 end
    local best, bestLvl = nil, nil
    for i, entry in ipairs(self.currentRun.currentDeck) do
        if RunManager.entryId(entry) == cardId and self:canUpgradeAt(i) then
            local lvl = self:getEntryLevel(entry)
            if not bestLvl or lvl < bestLvl then best, bestLvl = i, lvl end
        end
    end
    if not best then
        Debug.warn("[RunManager] upgradeCard: nenhuma copia forjavel de " .. tostring(cardId))
        return nil
    end
    return self:upgradeCardAt(best)
end

function RunManager:canUpgrade(cardId)
    if not self.currentRun then return false end
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData or next(RunManager.getForgeGains(cardData)) == nil then
        return false
    end
    local cap = RunManager.getUpgradeCap()
    if cap <= 0 then return true end
    local any = false
    for i, entry in ipairs(self.currentRun.currentDeck or {}) do
        if RunManager.entryId(entry) == cardId then
            any = true
            if self:getEntryLevel(entry) < cap then return true end
        end
    end
    if any then return false end
    local lvl = (self.currentRun.upgraded and self.currentRun.upgraded[cardId]) or 0
    return lvl < cap
end

function RunManager:getPaidForgeCost()
    local n = (self.currentRun and self.currentRun.paidForges) or 0
    local cfg = Config.Offers
    local cost = cfg.FORGE_COST_BASE * (cfg.FORGE_COST_MULT ^ n)
    return math.min(cfg.FORGE_COST_MAX, math.floor(cost + 0.5))
end

function RunManager:registerPaidForge()
    if not self.currentRun then return end
    self.currentRun.paidForges = (self.currentRun.paidForges or 0) + 1
end

function RunManager:unregisterPaidForge()
    if not self.currentRun then return end
    self.currentRun.paidForges = math.max(0, (self.currentRun.paidForges or 0) - 1)
end

function RunManager:_services()
    if not self.currentRun then return nil end
    self.currentRun.services = self.currentRun.services or {}
    return self.currentRun.services
end

function RunManager:getServiceCount(id)
    local s = self:_services()
    if not s or not id then return 0 end
    return s[id] or 0
end

function RunManager:registerService(id)
    local s = self:_services()
    if not s or not id then return 0 end
    s[id] = (s[id] or 0) + 1
    return s[id]
end

function RunManager:unregisterService(id)
    local s = self:_services()
    if not s or not id then return 0 end
    s[id] = math.max(0, (s[id] or 0) - 1)
    return s[id]
end

function RunManager:getUpgrades(cardId)
    if not self.currentRun then return 0 end
    local best = 0
    for _, entry in ipairs(self.currentRun.currentDeck or {}) do
        if RunManager.entryId(entry) == cardId then
            best = math.max(best, self:getEntryLevel(entry))
        end
    end
    if best == 0 and self.currentRun.upgraded then
        best = self.currentRun.upgraded[cardId] or 0
    end
    return best
end

local UPGRADABLE_EFFECT_TYPES = {
    instant_heal = true, magic_damage = true, aoe_magic_damage = true,
    add_armor = true, damage_bonus = true, defense_bonus = true,
    damage_bonus_self = true, gain_strength = true, gain_dexterity = true,
}

local STACK_EFFECT_TYPES = { apply_debuff = true }
RunManager.STACK_EFFECT_TYPES = STACK_EFFECT_TYPES
RunManager.STACKED_DEBUFFS = { poison = true, burn = true }

function RunManager.getForgeGains(cardData)
    if not cardData then return {} end
    local gains = {}
    local hasBasic = false
    if (cardData.attack or 0) > 0 then
        gains.atk = Config.Offers.FORGE_ATK_PER_LVL
        hasBasic = true
    end
    if (cardData.defense or 0) > 0 then
        gains.def = Config.Offers.FORGE_DEF_PER_LVL
        hasBasic = true
    end
    if not hasBasic and cardData.effects then
        for i, eff in ipairs(cardData.effects) do
            local field = nil
            if type(eff.value) == "number" and UPGRADABLE_EFFECT_TYPES[eff.type] then
                field = "value"
            elseif STACK_EFFECT_TYPES[eff.type] then
                if RunManager.STACKED_DEBUFFS[eff.value] then
                    field = type(eff.stacks) == "number" and "stacks" or nil
                else
                    field = type(eff.duration) == "number" and "duration" or nil
                end
            end
            if field then
                gains.effectIndex = i
                gains.effectType = eff.type
                gains.effectField = field
                gains.effect = Config.Offers.FORGE_EFFECT_PER_LVL
                break
            end
        end
    end
    return gains
end

function RunManager:applyUpgradesToInstance(instance, level)
    if not instance or not level or level <= 0 then return instance end
    instance.upgrades = level
    local gains = RunManager.getForgeGains(instance)
    if gains.atk then
        instance.attack = instance.attack + gains.atk * level
    end
    if gains.def then
        instance.defense = instance.defense + gains.def * level
    end
    if gains.effectIndex and instance.effects
        and instance.effects[gains.effectIndex] then
        local eff = instance.effects[gains.effectIndex]
        local field = gains.effectField or "value"
        eff[field] = eff[field] + gains.effect * level
    end
    local ok, img = pcall(function()
        return require("src.ui.CardFrame").render(instance)
    end)
    if ok and img then instance.image = img end
    return instance
end

function RunManager:_migrateJokersFromDeck()
    if not self.currentRun or not self.currentRun.currentDeck then return end
    self.currentRun.jokers = self.currentRun.jokers or {}
    self:_ensureJokerActive()
    local cap = self:getMaxJokerSlots()
    for i = 1, #self.currentRun.currentDeck do
        local entry = self.currentRun.currentDeck[i]
        local cardId = type(entry) == "table" and entry.id or entry
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData and cardData.type == "joker" then
            table.insert(self.currentRun.jokers, entry)
            local activated = self:getActiveJokerCount() < cap
            self.currentRun.jokerActive[#self.currentRun.jokers] = activated
            Debug.log("[RunManager] migrou joker de currentDeck → jokers: " .. tostring(cardId))
        end
    end
    for i = #self.currentRun.currentDeck, 1, -1 do
        local entry = self.currentRun.currentDeck[i]
        local cardId = type(entry) == "table" and entry.id or entry
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData and cardData.type == "joker" then
            table.remove(self.currentRun.currentDeck, i)
        end
    end
end

function RunManager:buildPlayableDeck()
    if not self.currentRun then return {} end

    self:_migrateJokersFromDeck()

    local playableCards = {}
    local upgradedMap = self.currentRun.upgraded or {}

    for _, entry in ipairs(self.currentRun.currentDeck) do
        local cardId, edition, seal
        if type(entry) == "table" then
            cardId = entry.id
            edition = entry.edition
            seal = entry.seal
        else
            cardId = entry
        end

        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            local cardInstance = self.cardDatabase:createCardInstance(cardData)
            local lvl = (type(entry) == "table" and entry.up)
                or upgradedMap[cardId] or 0
            if lvl > 0 then
                self:applyUpgradesToInstance(cardInstance, lvl)
            end
            if edition and edition ~= "negative" then cardInstance.edition = edition end
            if seal then cardInstance.seal = seal end
            table.insert(playableCards, cardInstance)
        else
            Debug.warn("[RunManager] AVISO: carta não encontrada no banco de dados: " .. tostring(cardId))
        end
    end

    return playableCards
end

function RunManager:getCurrentRunStats()
    if not self.currentRun then return nil end

    return {
        class = self.currentRun.className,
        floor = self.currentRun.currentFloor,
        battlesWon = self.currentRun.battlesWon,
        deckSize = #self.currentRun.currentDeck,
        cardsAdded = self.currentRun.cardsAdded,
        averageCardsPerFloor = self.currentRun.cardsAdded / math.max(1, self.currentRun.currentFloor - 1),

        deckComposition = self:analyzeDeckComposition()
    }
end

function RunManager:analyzeDeckComposition()
    if not self.currentRun then return {} end

    local composition = {
        attack = 0,
        defense = 0,
        joker = 0,
        totalCards = #self.currentRun.currentDeck,
        rarityDistribution = {
            common = 0,
            uncommon = 0,
            rare = 0
        }
    }

    for _, cardId in ipairs(self.currentRun.currentDeck) do
        local cardData = self.cardDatabase:getCard(cardId)
        if cardData then
            if cardData.type == "attack" then
                composition.attack = composition.attack + 1
            elseif cardData.type == "defense" then
                composition.defense = composition.defense + 1
            elseif cardData.type == "joker" then
                composition.joker = composition.joker + 1
            end

            local rarity = cardData.rarity or "common"
            composition.rarityDistribution[rarity] = (composition.rarityDistribution[rarity] or 0) + 1
        end
    end

    return composition
end

function RunManager:saveRun()
    if not self.currentRun then return false, "sem run ativa" end
    self.currentRun.rngState = Rng.get():getState()
    local ok, err = SaveManager.saveRun(self.currentRun)
    if not ok then
        Debug.err("[RunManager] falha ao salvar:", err)
        return false, err
    end
    return true
end

function RunManager:loadRun()
    local runData = SaveManager.loadRun()
    if not runData then return false, "nenhum save válido" end

    self.currentRun = runData
    self.isRunActive = true
    self:repairPendingNodes()

    Rng.setActive(Rng.fromState(runData.rngState))
    if not runData.rngState then
        Debug.warn("[RunManager] save sem rngState (pré-seed) — RNG novo gerado")
    end
    return true
end

function RunManager:deleteSave()
    SaveManager.deleteRun()
end

function RunManager:hasSavedRun()
    return SaveManager.hasRun()
end

function RunManager:endRun(victory)
    if not self.currentRun then return nil end

    local finalStats = self:getCurrentRunStats()
    finalStats.victory = victory
    finalStats.finalScore = self:calculateFinalScore(victory)

    self.currentRun = nil
    self.isRunActive = false
    Rng.clearActive()

    return finalStats
end

function RunManager:calculateFinalScore(victory)
    if not self.currentRun then return 0 end

    local baseScore = self.currentRun.battlesWon * 100
    local floorBonus = self.currentRun.currentFloor * 50
    local victoryBonus = victory and 1000 or 0

    return baseScore + floorBonus + victoryBonus
end

function RunManager:hasActiveRun()
    return self.isRunActive and self.currentRun ~= nil
end

function RunManager:getCurrentClassInfo()
    if not self.currentRun then return nil end
    return self.cardRegistry:getClassInfo(self.currentRun.classId)
end

return RunManager
