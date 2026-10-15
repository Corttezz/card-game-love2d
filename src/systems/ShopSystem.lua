local Debug = require("src.core.Debug")

local ShopSystem = {}
ShopSystem.__index = ShopSystem

local CardDatabase  = require("src.systems.CardDatabase")
local CardRegistry  = require("src.systems.CardRegistry")
local Rng           = require("src.systems.Rng")
local I18n          = require("src.i18n.I18n")
local ShopServices  = require("src.systems.ShopServices")

local function itemName(id, fallback)
    return I18n.t("shop_items." .. tostring(id) .. ".name", nil, fallback or id)
end

local function itemDesc(id, fallback, vars)
    return I18n.t("shop_items." .. tostring(id) .. ".desc", vars, fallback or "")
end

local BOOSTER_PACK_TYPES = {
    {
        id = "pack_standard",
        name = "Fardo do Mercador",
        description = "3 cartas ao acaso; escolha 1.",
        kind = "Standard", cost = 4, weight = 1.0,
        size = 3, choose = 1,
    },
    {
        id = "pack_buffoon",
        name = "Estojo do Saltimbanco",
        description = "2 coringas; escolha 1.",
        kind = "Buffoon", cost = 4, weight = 0.6,
        size = 2, choose = 1,
    },
    {
        id = "pack_arcana",
        name = "Relicario do Vidente",
        description = "3 cartas seletas; escolha 1.",
        kind = "Arcana", cost = 4, weight = 1.0,
        size = 3, choose = 1,
    },
    {
        id = "pack_celestial",
        name = "Cofre do Astrologo",
        description = "3 cartas seletas; escolha 1.",
        kind = "Celestial", cost = 4, weight = 1.0,
        size = 3, choose = 1,
    },
    {
        id = "pack_spectral",
        name = "Mortalha do Coveiro",
        description = "2 cartas, nenhuma comum; escolha 1.",
        kind = "Spectral", cost = 4, weight = 0.3,
        size = 2, choose = 1,
    },
}

local MODE_CONFIG = {
    rewards = {
        cards = 3,
        upgrades = 0,
        boosters = 0,
        canReroll = false,
        canSkip = true,
        skipBonus = 0,
    },
    shop = {
        cards = 4,
        upgrades = 3,
        boosters = 1,
        canReroll = true,
        canSkip = true,
        skipBonus = 3,
    },
}

local CLASSIC_UPGRADE_WEIGHT = {
    health_upgrade = 1.0,
    mana_upgrade   = 0.7,
}
local FORGE_WEIGHT = 1.2

local REROLL_BASE = 4
local REROLL_MAX = 30

function ShopSystem:new()
    local instance = setmetatable({}, ShopSystem)

    instance.isOpen = false
    instance.currentOffers = {}
    instance.refreshCost = REROLL_BASE
    instance.refreshCount = 0
    instance.mode = "shop"

    instance.cardCostBase = 3
    instance.upgradeCostBase = 5

    instance.shopUpgradePool = {}

    instance.rarityWeights = {
        common = 0.7,
        uncommon = 0.25,
        rare = 0.05,
    }

    instance.cardRegistry = CardRegistry:new()
    instance.cardDatabase = CardDatabase:new()

    instance.context = {}
    instance._offeredCardIds = {}
    instance._offeredUpgradeIds = {}

    instance:initializeShopPools()

    return instance
end

function ShopSystem:setContext(ctx)
    self.context = ctx or {}
end

function ShopSystem.runContext(game, mode)
    local run = game.runManager and game.runManager.currentRun
    local actNumber = (run and run.actNumber) or 1
    local nodeType = run and run.currentNode and run.currentNode.type or nil
    local minRarity = nil
    if mode == "rewards" and nodeType == "elite" then
        minRarity = "uncommon"
    elseif mode == "rewards" and nodeType == "boss" then
        minRarity = "rare"
    end
    local ActSystem = require("src.systems.ActSystem")
    return {
        classId = (run and run.classId) or game.selectedClass,
        deckIds = (game.runManager and game.runManager.getDeckCardIds)
            and game.runManager:getDeckCardIds() or nil,
        runManager = game.runManager,
        actNumber = actNumber,
        rarityWeights = ActSystem.getRarityWeights(actNumber),
        minRarity = minRarity,
        nodeType = mode == "rewards" and nodeType or nil,
    }
end

function ShopSystem:initializeShopPools()
    self.shopUpgradePool = {
        { id = "health_upgrade",     name = "Elixir Vital",    description = "+10 de vida maxima",  cost = 5,  effect = "increase_max_health", value = 10 },
        { id = "mana_upgrade",       name = "Cristal de Eter", description = "+1 de mana maxima",   cost = 25, effect = "increase_base_mana",  value = 1  },
    }
end

function ShopSystem:setMode(mode)
    if not MODE_CONFIG[mode] then
        Debug.warn("[ShopSystem] modo desconhecido '" .. tostring(mode) .. "' — usando 'shop'")
        mode = "shop"
    end
    self.mode = mode
    self.refreshCount = 0
    self.refreshCost = REROLL_BASE
end

function ShopSystem:getModeConfig()
    return MODE_CONFIG[self.mode] or MODE_CONFIG.shop
end

function ShopSystem:openShop(mode)
    self.isOpen = true
    if mode then self:setMode(mode) end
    self:generateOffers()
end

function ShopSystem:closeShop()
    self.isOpen = false
    self.currentOffers = {}
end

function ShopSystem:generateOffers()
    self.currentOffers = {}
    self._offeredCardIds = {}
    local cfg = self:getModeConfig()
    local RunModifiers = require("src.systems.RunModifiers")
    local run = self.context.runManager and self.context.runManager.currentRun

    local nCards = cfg.cards
    if self.mode == "rewards" then
        nCards = math.max(1, nCards + RunModifiers.rewardCardsDelta(run))
    end
    local Offers = require("src.core.Config").Offers or {}
    local sustainSlot = false
    if self.mode == "rewards" and Offers.SUSTAIN_GUARANTEE
        and (self.context.nodeType == "elite" or self.context.nodeType == "boss")
        and self.cardRegistry.countSustain
        and self.cardRegistry:countSustain(self.context.deckIds) < (Offers.SUSTAIN_MIN_SOURCES or 2) then
        sustainSlot = true
    end
    local jokerSlot = nil
    if self.mode == "rewards" then
        local chance = ShopSystem.rewardJokerChance(self.context.nodeType)
        if ShopSystem.forceNextRewardJoker then
            ShopSystem.forceNextRewardJoker = false
            chance = 1
        end
        if chance > 0 and Rng.get():random("shop") < chance then jokerSlot = nCards end
        if sustainSlot and jokerSlot == 1 then jokerSlot = nil end
    end
    for i = 1, nCards do
        local extra = nil
        if self.mode == "rewards" then
            extra = { jokers = (i == jokerSlot) and "only" or "none", requireSustain = (sustainSlot and i == 1) or nil }
        end
        local offer = self:generateCardOffer(extra)
        if not offer and extra and extra.jokers == "only" then
            offer = self:generateCardOffer({ jokers = "none" })
        end
        if offer then table.insert(self.currentOffers, offer) end
    end
    self:_applyBossJoker()

    self._offeredUpgradeIds = {}
    local upgradesLeft = cfg.upgrades
    if upgradesLeft > 0 then
        for _, svc in ipairs(ShopServices.CATALOG) do
            if upgradesLeft <= 0 then break end
            if svc.fixture then
                local offer = self:buildServiceOffer(svc.id)
                if offer then
                    table.insert(self.currentOffers, offer)
                    self._offeredUpgradeIds[svc.id] = true
                    upgradesLeft = upgradesLeft - 1
                end
            end
        end
    end

    for _ = 1, upgradesLeft do
        local offer = self:generateUpgradeOffer()
        if offer then
            table.insert(self.currentOffers, offer)
            self._offeredUpgradeIds[offer.id] = true
        end
    end

    for _ = 1, cfg.boosters do
        local offer = self:generateBoosterOffer()
        if offer then table.insert(self.currentOffers, offer) end
    end

    for _, o in ipairs(self.currentOffers) do
        o.cost = RunModifiers.price(run, o.cost)
    end

    self:applyDailySale()
end

function ShopSystem:applyDailySale()
    local Offers = require("src.core.Config").Offers or {}
    if not Offers.DAILY_SALE or self.mode ~= "shop" then return nil end
    local pct = tonumber(Offers.DAILY_SALE_PCT) or 0.25
    local eligible = {}
    for i, o in ipairs(self.currentOffers) do
        if (o.cost or 0) > 0 and not o.saleDiscount then eligible[#eligible + 1] = i end
    end
    if #eligible == 0 then return nil end
    local idx = eligible[Rng.get():random("shop", #eligible)]
    local o = self.currentOffers[idx]
    o.basePrice = o.cost
    o.saleDiscount = pct
    o.cost = math.floor(o.cost * (1 - pct))
    return o
end

function ShopSystem.rewardJokerChance(nodeType)
    local odds = require("src.core.Config").Offers.REWARD_JOKER_CHANCE
    if type(odds) ~= "table" then return 1 end
    return tonumber(odds[nodeType or "battle"] or odds.battle) or 0
end

function ShopSystem:_applyBossJoker()
    if self.mode ~= "rewards" or self.context.nodeType ~= "boss" then return nil end
    local run = self.context.runManager and self.context.runManager.currentRun
    local cardId = require("src.systems.BossJokers").offerFor(run)
    if not cardId then return nil end
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData then return nil end
    local slot = nil
    for i, o in ipairs(self.currentOffers) do
        if o.type == "card" then slot = i end
    end
    local offer = {
        type = "card",
        id = cardId,
        name = cardData.name,
        description = cardData.description,
        cost = 0,
        rarity = cardData.rarity,
        image = cardData.image,
        bossJoker = true,
        isNew = require("src.systems.UnlockSystem").markDiscovered(cardId),
    }
    if slot then
        self._offeredCardIds[self.currentOffers[slot].id] = nil
        self.currentOffers[slot] = offer
    else
        table.insert(self.currentOffers, offer)
    end
    self._offeredCardIds[cardId] = true
    return offer
end

function ShopSystem:generateCardOffer(extra)
    local pick = self.cardRegistry:pickRewardCard({
        requireSustain = extra and extra.requireSustain or nil,
        jokers = extra and extra.jokers or nil,
        classId = self.context.classId,
        rarityWeights = self.context.rarityWeights or self.rarityWeights,
        minRarity = self.context.minRarity,
        deckIds = self.context.deckIds,
        actNumber = self.context.actNumber,
        runManager = self.context.runManager,
        excludeIds = self._offeredCardIds,
        stream = "shop",
    })
    if not pick then return nil end
    self._offeredCardIds[pick.cardId] = true

    local cardData = self.cardDatabase:getCard(pick.cardId)
    if not cardData then return nil end

    local cost = self:calculateCardCost(cardData.rarity)
    if self.mode == "rewards" then cost = 0 end
    return {
        type = "card",
        id = pick.cardId,
        name = cardData.name,
        description = cardData.description,
        cost = cost,
        rarity = cardData.rarity,
        image = cardData.image,
        affinity = pick.affinity or nil,
        affinityTags = pick.affinityTags,
        fromPity = pick.fromPity,
        isNew = pick.isNew,
        sustainSlot = (extra and extra.requireSustain) and true or nil,
    }
end

function ShopSystem:buildServiceOffer(id)
    local svc = ShopServices.get(id)
    if not svc then
        Debug.warn("[ShopSystem] servico desconhecido: " .. tostring(id))
        return nil
    end
    local runManager = self.context and self.context.runManager
    if not ShopServices.isAvailable(id, runManager) then return nil end

    local cost = ShopServices.cost(id, runManager)
    if not cost then return nil end

    local value = ShopServices.value(id)
    return {
        type = "upgrade",
        id = id,
        name = itemName(id, id),
        description = itemDesc(id, "", { value = value }),
        cost = cost,
        effect = svc.effect,
        value = value,
        picker = svc.picker,
        isService = true,
    }
end

function ShopSystem:generateUpgradeOffer()
    local runManager = self.context and self.context.runManager
    local offered = self._offeredUpgradeIds or {}
    local entries = {}

    local function candidate(offer, weight)
        if offer and not offered[offer.id] and (weight or 0) > 0 then
            table.insert(entries, { item = offer, weight = weight })
        end
    end

    if runManager and runManager.getPaidForgeCost then
        candidate({
            type = "upgrade",
            id = "forge_card",
            name = itemName("forge_card", "Forja"),
            description = itemDesc("forge_card",
                "+1 nivel numa carta a sua escolha (voce escolhe ao comprar)"),
            cost = runManager:getPaidForgeCost(),
            effect = "forge_card",
            value = 1,
            picker = "forge",
        }, FORGE_WEIGHT)
    end

    for _, pick in ipairs(self.shopUpgradePool) do
        candidate({
            type = "upgrade",
            id = pick.id,
            name = itemName(pick.id, pick.name),
            description = itemDesc(pick.id, pick.description, { value = pick.value }),
            cost = pick.cost,
            effect = pick.effect,
            value = pick.value,
        }, CLASSIC_UPGRADE_WEIGHT[pick.id] or 1.0)
    end

    for _, svc in ipairs(ShopServices.CATALOG) do
        if not svc.fixture then
            candidate(self:buildServiceOffer(svc.id),
                ShopServices.weight(svc.id, runManager))
        end
    end

    if #entries == 0 then return nil end
    return Rng.get():weighted("shop", entries)
end

function ShopSystem:generateBoosterOffer()
    local entries = {}
    for _, p in ipairs(BOOSTER_PACK_TYPES) do
        table.insert(entries, { item = p, weight = p.weight })
    end
    local p = Rng.get():weighted("shop", entries)
    if not p then return nil end
    return {
        type = "booster_pack",
        id = p.id,
        name = itemName(p.id, p.name),
        description = itemDesc(p.id, p.description),
        cost = p.cost,
        kind = p.kind,
        size = p.size,
        choose = p.choose,
    }
end

function ShopSystem:calculateCardCost(rarity)
    local rarityMultipliers = {
        common = 1, uncommon = 2, rare = 3, legendary = 7,
    }
    return self.cardCostBase * (rarityMultipliers[rarity] or 1)
end

function ShopSystem:refreshOffers()
    self.refreshCount = self.refreshCount + 1
    local raw = REROLL_BASE + 2 * self.refreshCount
    self.refreshCost = math.min(raw, REROLL_MAX)
    self:generateOffers()
end

function ShopSystem:purchaseItem(offerIndex, economySystem)
    local offer = self.currentOffers[offerIndex]
    if not offer then return false end

    if economySystem:spendGold(offer.cost, offer.type, offer.id) then
        table.remove(self.currentOffers, offerIndex)
        return true, offer
    end

    return false
end

function ShopSystem:getCurrentOffers()
    return self.currentOffers
end

local function plainCopy(v, depth)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" then return v end
    if t ~= "table" or depth > 4 or getmetatable(v) then return nil end
    local out = {}
    for k, x in pairs(v) do
        local kt = type(k)
        if (kt == "string" or kt == "number") and k ~= "cardInstance" then
            out[k] = plainCopy(x, depth + 1)
        end
    end
    return out
end

function ShopSystem:exportState()
    local offers = {}
    for i, o in ipairs(self.currentOffers or {}) do offers[i] = plainCopy(o, 0) end
    return {
        mode = self.mode,
        offers = offers,
        refreshCount = self.refreshCount,
        refreshCost = self.refreshCost,
    }
end

function ShopSystem:importState(st)
    local offers = {}
    for i, o in ipairs((st and st.offers) or {}) do offers[i] = plainCopy(o, 0) end
    self.currentOffers = offers
    self.refreshCount = (st and st.refreshCount) or 0
    self.refreshCost = (st and st.refreshCost) or REROLL_BASE
end

function ShopSystem:getRefreshCost()
    local rm = self.context and self.context.runManager
    return require("src.systems.RunModifiers").price(rm and rm.currentRun, self.refreshCost)
end

function ShopSystem.getBoosterTypes()
    return BOOSTER_PACK_TYPES
end

return ShopSystem
