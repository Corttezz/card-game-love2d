-- src/systems/ShopSystem.lua
-- Sistema de loja inspirado no TFT e Balatro. Pós-redesign Fase 4:
--   • Modo "rewards": gera 3 cartas (post-battle).
--   • Modo "shop":    gera 4 cartas + 1 voucher (upgrade) + 2 booster packs.
--   • Reroll exponencial 5→7→10→14→20 (multiplicador 1.4).
--   • Booster packs como ofertas próprias (Fase 5 implementa abertura).

local ShopSystem = {}
ShopSystem.__index = ShopSystem

local CardDatabase = require("src.systems.CardDatabase")

-- Catálogo de booster packs disponíveis na loja. Custo + tamanho do conteúdo.
-- Fase 5 vai usar `size` (cards mostrados) e `choose` (cards escolhidos)
-- ao abrir o pack pra renderizar a UI.
local BOOSTER_PACK_TYPES = {
    {
        id = "pack_standard",
        name = "Pacote Padrão",
        description = "3 cartas; escolha 1.",
        kind = "Standard", cost = 4, weight = 1.0,
        size = 3, choose = 1,
    },
    {
        id = "pack_buffoon",
        name = "Pacote Bufão",
        description = "2 jokers; escolha 1.",
        kind = "Buffoon", cost = 4, weight = 0.6,
        size = 2, choose = 1,
    },
    {
        id = "pack_arcana",
        name = "Pacote Arcano",
        description = "3 tarôs; escolha 1.",
        kind = "Arcana", cost = 4, weight = 1.0,
        size = 3, choose = 1,
    },
    {
        id = "pack_celestial",
        name = "Pacote Celestial",
        description = "3 planetas; escolha 1.",
        kind = "Celestial", cost = 4, weight = 1.0,
        size = 3, choose = 1,
    },
    {
        id = "pack_spectral",
        name = "Pacote Espectral",
        description = "2 espectrais; escolha 1.",
        kind = "Spectral", cost = 4, weight = 0.3,
        size = 2, choose = 1,
    },
}

-- Configurações por modo (Fase 4.2). "rewards" = post-battle; "shop" = SHOP node.
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
        upgrades = 1,
        boosters = 2,
        canReroll = true,
        canSkip = true,
        skipBonus = 3,  -- ouro extra ao pular a loja
    },
}

local REROLL_BASE = 5
local REROLL_MULT = 1.4
-- Cap pra reroll cost: sem isso o jogador pode trapar gold infinitamente em
-- rerolls (5→7→10→...→2.4M após 20 cliques). Balatro tem cap análogo.
local REROLL_MAX = 30

function ShopSystem:new()
    local instance = setmetatable({}, ShopSystem)

    -- Estado da loja
    instance.isOpen = false
    instance.currentOffers = {}
    instance.refreshCost = REROLL_BASE
    instance.refreshCount = 0
    instance.mode = "shop"  -- "shop" | "rewards"

    -- Configurações da loja
    instance.cardCostBase = 3
    instance.upgradeCostBase = 5

    -- Pool de cartas disponíveis na loja
    instance.shopCardPool = {}
    instance.shopUpgradePool = {}

    -- Sistema de raridade na loja (como TFT)
    instance.rarityWeights = {
        common = 0.7,
        uncommon = 0.25,
        rare = 0.05,
    }

    instance:initializeShopPools()

    return instance
end

-- Inicializa os pools de cartas e upgrades disponíveis na loja.
function ShopSystem:initializeShopPools()
    local cardDatabase = CardDatabase:new()
    local allCards = cardDatabase:getAllCards()

    for cardId, cardData in pairs(allCards) do
        if cardData.rarity then
            self.shopCardPool[cardData.rarity] = self.shopCardPool[cardData.rarity] or {}
            table.insert(self.shopCardPool[cardData.rarity], cardId)
        end
    end

    self.shopUpgradePool = {
        { id = "health_upgrade",     name = "Vida Extra",   description = "+10 HP máximo",            cost = 5, effect = "increase_max_health",    value = 10 },
        { id = "mana_upgrade",       name = "Mana Extra",   description = "+1 mana máxima",           cost = 8, effect = "increase_base_mana",     value = 1  },
        { id = "card_draw_upgrade",  name = "Cartas Extras",description = "+1 carta por turno",       cost = 6, effect = "increase_card_draw",     value = 1  },
        { id = "damage_upgrade",     name = "Dano Bônus",   description = "+2 dano em cartas de ataque", cost = 4, effect = "increase_attack_damage", value = 2 },
        { id = "defense_upgrade",    name = "Defesa Bônus", description = "+2 defesa em cartas defensivas", cost = 4, effect = "increase_defense",   value = 2  },
    }
end

-- Define o modo antes de gerar ofertas. "rewards" pra post-battle; "shop" pra SHOP node.
function ShopSystem:setMode(mode)
    if mode ~= "rewards" and mode ~= "shop" then mode = "shop" end
    self.mode = mode
    -- Reset de reroll por sessão da loja.
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

-- Gera ofertas aleatórias seguindo o config do modo atual.
function ShopSystem:generateOffers()
    self.currentOffers = {}
    local cfg = self:getModeConfig()

    for _ = 1, cfg.cards do
        local offer = self:generateCardOffer()
        if offer then table.insert(self.currentOffers, offer) end
    end

    for _ = 1, cfg.upgrades do
        local offer = self:generateUpgradeOffer()
        if offer then table.insert(self.currentOffers, offer) end
    end

    for _ = 1, cfg.boosters do
        local offer = self:generateBoosterOffer()
        if offer then table.insert(self.currentOffers, offer) end
    end
end

function ShopSystem:generateCardOffer()
    local rarity = self:rollRarity()
    local availableCards = self.shopCardPool[rarity]

    if availableCards and #availableCards > 0 then
        local randomCardId = availableCards[love.math.random(#availableCards)]
        local cardData = CardDatabase:new():getCard(randomCardId)

        if cardData then
            local cost = self:calculateCardCost(cardData.rarity)
            return {
                type = "card",
                id = randomCardId,
                name = cardData.name,
                description = cardData.description,
                cost = cost,
                rarity = cardData.rarity,
                image = cardData.image,
            }
        end
    end

    return nil
end

function ShopSystem:generateUpgradeOffer()
    local pool = self.shopUpgradePool
    local pick = pool[love.math.random(#pool)]
    return {
        type = "upgrade",
        id = pick.id,
        name = pick.name,
        description = pick.description,
        cost = pick.cost,
        effect = pick.effect,
        value = pick.value,
    }
end

-- Sorteia booster pack ponderado por weight. Fase 5 implementa abertura.
function ShopSystem:generateBoosterOffer()
    local totalWeight = 0
    for _, p in ipairs(BOOSTER_PACK_TYPES) do totalWeight = totalWeight + p.weight end
    local roll = love.math.random() * totalWeight
    local cumulative = 0
    for _, p in ipairs(BOOSTER_PACK_TYPES) do
        cumulative = cumulative + p.weight
        if roll <= cumulative then
            return {
                type = "booster_pack",
                id = p.id,
                name = p.name,
                description = p.description,
                cost = p.cost,
                kind = p.kind,
                size = p.size,
                choose = p.choose,
            }
        end
    end
    return nil
end

function ShopSystem:calculateCardCost(rarity)
    local rarityMultipliers = {
        common = 1, uncommon = 2, rare = 3, legendary = 5,
    }
    return self.cardCostBase * (rarityMultipliers[rarity] or 1)
end

function ShopSystem:rollRarity()
    local roll = love.math.random()
    local cumulative = 0
    for rarity, weight in pairs(self.rarityWeights) do
        cumulative = cumulative + weight
        if roll <= cumulative then return rarity end
    end
    return "common"
end

-- Refresha ofertas. Custo cresce exponencialmente (Balatro feel) — não linear como antes.
-- Cap em REROLL_MAX pra impedir trap de gold drain.
function ShopSystem:refreshOffers()
    self.refreshCount = self.refreshCount + 1
    local raw = math.floor(REROLL_BASE * (REROLL_MULT ^ self.refreshCount) + 0.5)
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

function ShopSystem:getRefreshCost()
    return self.refreshCost
end

-- Tabela de tipos de booster pack — exposta pra Fase 5 (BoosterPackSystem) ler.
function ShopSystem.getBoosterTypes()
    return BOOSTER_PACK_TYPES
end

return ShopSystem
