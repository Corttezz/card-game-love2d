local Debug = require("src.core.Debug")

local ProfileStats = require("engine.ProfileStats")
local Data = require("src.data.unlocks")

local UnlockSystem = {}

local overrideAll = false
local revealAll = false
local listeners = {}
local pendingRun = { cards = {}, classes = {} }

UnlockSystem.lastResult = nil

local lockedBy = {}
for classId, bundles in pairs(Data.CLASS_BUNDLES) do
    for level, b in ipairs(bundles) do
        for _, id in ipairs(b.cards) do
            lockedBy[id] = { kind = "mastery", classId = classId, level = level }
        end
    end
end
for _, m in ipairs(Data.MILESTONES) do
    lockedBy[m.card] = { kind = m.kind, n = m.n }
end
UnlockSystem._lockedBy = lockedBy

local MAX_LEVEL = #Data.LEVEL_COSTS

local function totalActs()
    local Config = require("src.core.Config")
    return Config.TotalActs or 3
end

local function clampAct(n)
    return math.min(n or 1, totalActs())
end

local function emptyState()
    return {
        version = 1,
        mastery = { warrior = 0, mage = 0, rogue = 0 },
        actsCleared = 0,
        bestActReached = 0,
        victories = 0,
        cards = {},
        classes = {},
        discovered = {},
    }
end

local function migrateLegacy(s, u)
    local runs = s.runs or 0
    local wins = s.wins or 0
    local bestAct = s.bestAct or 0
    local cleared = math.max(0, bestAct - 1)
    if wins > 0 then cleared = math.max(cleared, totalActs()) end
    u.actsCleared = cleared
    u.bestActReached = bestAct
    u.victories = wins
    local retro = math.min(Data.LEVEL_COSTS[1] * 10,
        runs * 40 + wins * 300 + bestAct * 40)
    local cap = 0
    for _, c in ipairs(Data.LEVEL_COSTS) do cap = cap + c end
    for _, classId in ipairs(Data.CLASS_ORDER) do
        local xp = retro
        if s.winsByClass and s.winsByClass[classId] then xp = cap end
        u.mastery[classId] = math.min(cap, xp)
    end
    for id in pairs(s.cardsSeen or {}) do u.discovered[id] = true end
    u.migratedLegacy = true
    Debug.log(string.format("[UnlockSystem] perfil antigo migrado: runs=%d wins=%d bestAct=%d -> atos=%d xp/classe=%d",
        runs, wins, bestAct, cleared, retro))
end

local function state()
    local s = ProfileStats.get()
    if type(s.unlocks) ~= "table" then
        local u = emptyState()
        if (s.runs or 0) > 0 or (s.wins or 0) > 0 then
            migrateLegacy(s, u)
        end
        s.unlocks = u
    end
    local u = s.unlocks
    u.mastery = u.mastery or {}
    u.cards = u.cards or {}
    u.classes = u.classes or {}
    u.discovered = u.discovered or {}
    u.actsCleared = u.actsCleared or 0
    u.bestActReached = u.bestActReached or 0
    u.victories = u.victories or 0
    if type(u.sealsWon) ~= "table" then
        u.sealsWon = {}
        for classId, won in pairs(s.winsByClass or {}) do
            if won then u.sealsWon[classId] = 0 end
        end
    end
    return u, s
end

local SEAL_MAX = 10

function UnlockSystem.getSealWon(classId)
    local u = state()
    local w = u.sealsWon[classId]
    return w == nil and -1 or w
end

function UnlockSystem.getClassRecord(classId)
    local u = state()
    u.records = u.records or {}
    local r = u.records[classId] or {}
    return { bestScore = r.bestScore or 0, bestEndless = r.bestEndless or 0 }
end

function UnlockSystem.getMaxSeal(classId)
    if overrideAll then return SEAL_MAX end
    return math.min(SEAL_MAX, UnlockSystem.getSealWon(classId) + 1)
end

function UnlockSystem.ensure()
    state()
end

local function levelFromXP(xp)
    local level, acc = 0, 0
    for i, cost in ipairs(Data.LEVEL_COSTS) do
        if xp >= acc + cost then
            level = i
            acc = acc + cost
        else
            return level, xp - acc, cost
        end
    end
    return MAX_LEVEL, 0, 0
end

function UnlockSystem.getClassMastery(classId)
    local u = state()
    local xpTotal = u.mastery[classId] or 0
    local level, into, cost = levelFromXP(xpTotal)
    return { level = level, maxLevel = MAX_LEVEL, xp = into, xpToNext = cost,
             totalXP = xpTotal }
end

function UnlockSystem.computeRunXP(summary)
    summary = summary or {}
    local X = Data.XP
    local MapManager = require("src.systems.MapManager")
    local perAct = MapManager.FLOORS_PER_ACT or 8
    local act = summary.actNumber or 1
    local floor = summary.floorInAct or 1
    local endlessFloors = 0
    if summary.endlessMode and not summary.victory then
        return math.max(X.MINIMUM, (summary.floorsInEndless or 0) * X.PER_ENDLESS)
    end
    if summary.endlessMode then
        endlessFloors = summary.floorsInEndless or 0
        act = math.min(act, totalActs())
        floor = perAct
    end
    local floors = (act - 1) * perAct + floor
    local acts = summary.actsCleared
    if not acts then
        acts = math.max(0, act - 1)
        if summary.victory or summary.endlessMode then acts = totalActs() end
    end
    local xp = floors * X.PER_FLOOR + acts * X.PER_ACT
        + endlessFloors * X.PER_ENDLESS
    if summary.victory then xp = xp + X.VICTORY end
    return math.max(X.MINIMUM, math.floor(xp))
end

local function milestoneMet(lb, u, s)
    if lb.kind == "act_cleared" then return u.actsCleared >= clampAct(lb.n) end
    if lb.kind == "reach_act" then
        return u.bestActReached >= clampAct(lb.n) or u.actsCleared >= clampAct(lb.n)
    end
    if lb.kind == "victory" then return u.victories > 0 end
    return false
end

local function cardUnlockedReal(cardId, u, s)
    local lb = lockedBy[cardId]
    if not lb then return true end
    if u.cards[cardId] then return true end
    if lb.kind == "mastery" then
        local lvl = levelFromXP(u.mastery[lb.classId] or 0)
        return lvl >= lb.level
    end
    return milestoneMet(lb, u, s)
end

function UnlockSystem.isCardUnlocked(cardId)
    if overrideAll then return true end
    local u, s = state()
    return cardUnlockedReal(cardId, u, s)
end

function UnlockSystem.isCardUnlockedReal(cardId)
    local u, s = state()
    return cardUnlockedReal(cardId, u, s)
end

function UnlockSystem.markDiscovered(cardId)
    if not cardId then return false end
    local u, s = state()
    if u.discovered[cardId] or (s.cardsSeen and s.cardsSeen[cardId]) then return false end
    u.discovered[cardId] = true
    u.freshInCollection = u.freshInCollection or {}
    u.freshInCollection[cardId] = true
    u.runDiscoveries = (u.runDiscoveries or 0) + 1
    return true
end

function UnlockSystem.isFresh(cardId)
    local u = state()
    return (u.freshInCollection and u.freshInCollection[cardId]) and true or false
end

function UnlockSystem.freshSet()
    local u = state()
    u.freshInCollection = u.freshInCollection or {}
    return u.freshInCollection
end

function UnlockSystem.freshCount()
    local u = state()
    local n = 0
    for _ in pairs(u.freshInCollection or {}) do n = n + 1 end
    return n
end

function UnlockSystem.clearFresh(cardId)
    local u = state()
    if not (u.freshInCollection and u.freshInCollection[cardId]) then return false end
    u.freshInCollection[cardId] = nil
    ProfileStats.flush()
    return true
end

function UnlockSystem.runDiscoveries()
    local u = state()
    return u.runDiscoveries or 0
end

local function classUnlockedReal(classId, u, s)
    local def = Data.CLASSES[classId]
    if not def then return false end
    if def.always or u.classes[classId] then return true end
    if def.actCleared and u.actsCleared >= clampAct(def.actCleared) then return true end
    if def.orVictory and u.victories > 0 then return true end
    return false
end

local function isStarterOfUnlockedClass(cardId, u, s)
    local ok, CardRegistry = pcall(require, "src.systems.CardRegistry")
    local decks = ok and CardRegistry and CardRegistry.STARTER_DECKS
    if not decks then return false end
    for classId, ids in pairs(decks) do
        for _, id in ipairs(ids) do
            if id == cardId and classUnlockedReal(classId, u, s) then return true end
        end
    end
    return false
end

function UnlockSystem.isCardDiscovered(cardId)
    if revealAll then return true end
    local u, s = state()
    if u.discovered[cardId] then return true end
    if (s.cardsSeen and s.cardsSeen[cardId]) == true then return true end
    return isStarterOfUnlockedClass(cardId, u, s)
end

function UnlockSystem.isClassUnlocked(classId)
    if overrideAll then return Data.CLASSES[classId] ~= nil end
    local u, s = state()
    return classUnlockedReal(classId, u, s)
end

function UnlockSystem.isClassUnlockedReal(classId)
    local u, s = state()
    return classUnlockedReal(classId, u, s)
end

function UnlockSystem.getClassUnlockInfo(classId)
    local def = Data.CLASSES[classId]
    if not def then
        return { unlocked = false, reqKey = "unlock.class.default", vars = {}, progress = 0, goal = 1 }
    end
    local u = state()
    local unlocked = UnlockSystem.isClassUnlocked(classId)
    local vars = {}
    for k, v in pairs(def.vars or {}) do vars[k] = v end
    if def.always then
        return { unlocked = true, reqKey = def.reqKey, vars = vars, progress = 1, goal = 1 }
    end
    local goal = clampAct(def.actCleared or 1)
    if vars.act then vars.act = goal end
    local progress = math.min(goal, u.actsCleared or 0)
    if unlocked then progress = goal end
    return { unlocked = unlocked, reqKey = def.reqKey, vars = vars,
             progress = progress, goal = goal }
end

function UnlockSystem.getCardHint(cardId)
    local lb = lockedBy[cardId]
    if not lb or UnlockSystem.isCardUnlockedReal(cardId) then
        return "unlocks.hint.undiscovered", {}
    end
    if lb.kind == "mastery" then
        local I18n = require("src.i18n.I18n")
        return "unlocks.hint.mastery", {
            class = I18n.t("classes." .. lb.classId .. ".name", nil, lb.classId),
            level = lb.level,
        }
    end
    if lb.kind == "act_cleared" then return "unlocks.hint.act_cleared", { act = clampAct(lb.n) } end
    if lb.kind == "reach_act" then return "unlocks.hint.reach_act", { act = clampAct(lb.n) } end
    if lb.kind == "victory" then return "unlocks.hint.victory", {} end
    return "unlocks.hint.undiscovered", {}
end

function UnlockSystem.unlockedCount()
    local u, s = state()
    local CardDatabase = require("src.systems.CardDatabase")
    local nCards, total = 0, 0
    for id in pairs(CardDatabase:getAllCards()) do
        total = total + 1
        if cardUnlockedReal(id, u, s) then nCards = nCards + 1 end
    end
    local nClasses = 0
    for _, c in ipairs(Data.CLASS_ORDER) do
        if classUnlockedReal(c, u, s) then nClasses = nClasses + 1 end
    end
    return nCards, total, nClasses, #Data.CLASS_ORDER
end

function UnlockSystem.getBundles(classId)
    return Data.CLASS_BUNDLES[classId] or {}
end

function UnlockSystem.setOverrideAll(v) overrideAll = v and true or false end
function UnlockSystem.isOverrideAll() return overrideAll end
function UnlockSystem.setRevealAll(v) revealAll = v and true or false end

function UnlockSystem.onUnlock(fn)
    if type(fn) == "function" then listeners[#listeners + 1] = fn end
end

local function notify(kind, id)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, kind, id)
        if not ok then Debug.warn("[UnlockSystem] listener falhou: " .. tostring(err)) end
    end
end

local function snapshot()
    local u, s = state()
    local cards, classes = {}, {}
    for id in pairs(lockedBy) do
        if cardUnlockedReal(id, u, s) then cards[id] = true end
    end
    for _, c in ipairs(Data.CLASS_ORDER) do
        if classUnlockedReal(c, u, s) then classes[c] = true end
    end
    return cards, classes
end

local function orderedCardIds()
    local out = {}
    for _, c in ipairs(Data.CLASS_ORDER) do
        for _, b in ipairs(Data.CLASS_BUNDLES[c] or {}) do
            for _, id in ipairs(b.cards) do out[#out + 1] = id end
        end
    end
    for _, m in ipairs(Data.MILESTONES) do out[#out + 1] = m.card end
    return out
end

local function diffAndGrant(beforeCards, beforeClasses)
    local u = state()
    local afterCards, afterClasses = snapshot()
    local newCards, newClasses = {}, {}
    for _, id in ipairs(orderedCardIds()) do
        if afterCards[id] and not beforeCards[id] then
            u.cards[id] = true
            newCards[#newCards + 1] = id
            notify("card", id)
        end
    end
    for _, c in ipairs(Data.CLASS_ORDER) do
        if afterClasses[c] and not beforeClasses[c] then
            u.classes[c] = true
            newClasses[#newClasses + 1] = c
            notify("class", c)
        end
    end
    return newCards, newClasses
end

function UnlockSystem.onRunStarted(classId, deckIds)
    state()
    pendingRun = { cards = {}, classes = {} }
    for _, entry in ipairs(deckIds or {}) do
        local id = type(entry) == "table" and entry.id or entry
        if UnlockSystem.markDiscovered(id) then
            state().freshInCollection[id] = nil
        end
    end
    state().runDiscoveries = 0
end

function UnlockSystem.onBossDefeated(actNumber, game)
    local u = state()
    actNumber = actNumber or 0
    if actNumber <= u.actsCleared then return {}, {} end
    local bc, bcl = snapshot()
    u.actsCleared = actNumber
    u.bestActReached = math.max(u.bestActReached, actNumber + 1)
    local newCards, newClasses = diffAndGrant(bc, bcl)
    for _, id in ipairs(newCards) do pendingRun.cards[#pendingRun.cards + 1] = id end
    for _, c in ipairs(newClasses) do pendingRun.classes[#pendingRun.classes + 1] = c end
    if (#newCards > 0 or #newClasses > 0) then
        ProfileStats.flush()
        if game and game.addMessage then
            local I18n = require("src.i18n.I18n")
            for _, c in ipairs(newClasses) do
                game:addMessage(I18n.t("unlocks.toast_class",
                    { name = I18n.t("classes." .. c .. ".name", nil, c) }), "success")
            end
            for _, id in ipairs(newCards) do
                game:addMessage(I18n.t("unlocks.toast_card",
                    { name = I18n.cardName(id) }), "success")
            end
        end
        local okS, Sfx = pcall(require, "src.systems.Sfx")
        if okS then Sfx.play("comboTrigger", { pitch = 1.1 }) end
    end
    return newCards, newClasses
end

function UnlockSystem.onRunEnded(summary)
    summary = summary or {}
    local u = state()
    local classId = summary.classId
    local bc, bcl = snapshot()
    local before = classId and UnlockSystem.getClassMastery(classId) or nil

    local xp = UnlockSystem.computeRunXP(summary)
    if classId and Data.CLASS_BUNDLES[classId] then
        u.mastery[classId] = (u.mastery[classId] or 0) + xp
    end
    if classId then
        u.records = u.records or {}
        local rec = u.records[classId] or {}
        rec.bestScore = math.max(rec.bestScore or 0, math.floor(summary.score or 0))
        if summary.endlessMode then
            rec.bestEndless = math.max(rec.bestEndless or 0, summary.floorsInEndless or 0)
        end
        u.records[classId] = rec
    end
    local sealUnlocked = nil
    if summary.victory then
        u.actsCleared = math.max(u.actsCleared, totalActs())
        u.victories = u.victories + 1
        if classId then
            local beforeMax = UnlockSystem.getMaxSeal(classId)
            local won = u.sealsWon[classId]
            u.sealsWon[classId] = math.max(won == nil and -1 or won, summary.seal or 0)
            local afterMax = UnlockSystem.getMaxSeal(classId)
            if afterMax > beforeMax then sealUnlocked = afterMax end
        end
    end
    u.bestActReached = math.max(u.bestActReached, summary.actNumber or 0)

    local after = classId and UnlockSystem.getClassMastery(classId) or nil
    local newCards, newClasses = diffAndGrant(bc, bcl)

    local seen = {}
    for _, id in ipairs(newCards) do seen[id] = true end
    for i = #pendingRun.cards, 1, -1 do
        local id = pendingRun.cards[i]
        if not seen[id] then table.insert(newCards, 1, id); seen[id] = true end
    end
    local seenC = {}
    for _, c in ipairs(newClasses) do seenC[c] = true end
    for i = #pendingRun.classes, 1, -1 do
        local c = pendingRun.classes[i]
        if not seenC[c] then table.insert(newClasses, 1, c); seenC[c] = true end
    end
    pendingRun = { cards = {}, classes = {} }

    local levelsGained = 0
    local bundles = {}
    if before and after then
        levelsGained = after.level - before.level
        for lvl = before.level + 1, after.level do
            local b = Data.CLASS_BUNDLES[classId][lvl]
            if b then bundles[#bundles + 1] = { level = lvl, theme = b.theme, cards = b.cards } end
        end
    end

    ProfileStats.flush()
    local result = {
        newCards = newCards, newClasses = newClasses, levelsGained = levelsGained,
        xpGained = xp, classId = classId, before = before, after = after,
        bundles = bundles, victory = summary.victory and true or false,
        sealUnlocked = sealUnlocked,
        newDiscoveries = u.runDiscoveries or 0,
    }
    UnlockSystem.lastResult = result
    require("src.systems.UnlockQueue").addRunResult(result)
    Debug.log(string.format("[UnlockSystem] fim de run (%s): +%d XP, +%d nivel(is), %d carta(s), %d classe(s) novas",
        tostring(classId), xp, levelsGained, #newCards, #newClasses))
    return result
end

function UnlockSystem._resetForTests()
    overrideAll = false
    revealAll = false
    pendingRun = { cards = {}, classes = {} }
    UnlockSystem.lastResult = nil
end

return UnlockSystem
