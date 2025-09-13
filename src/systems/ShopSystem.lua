-- src/systems/ShopSystem.lua
-- Sistema de loja inspirado no TFT e Balatro

local ShopSystem = {}
ShopSystem.__index = ShopSystem

local CardDatabase = require("src.systems.CardDatabase")

function ShopSystem:new()
    local instance = setmetatable({}, ShopSystem)
    
    -- Estado da loja
    instance.isOpen = false
    instance.currentOffers = {}
    instance.refreshCost = 2
    instance.refreshCount = 0
    
    -- Configurações da loja
    instance.maxOffers = 5
    instance.cardCostBase = 3
    instance.upgradeCostBase = 5
    
    -- Pool de cartas disponíveis na loja
    instance.shopCardPool = {}
    instance.shopUpgradePool = {}
    
    -- Sistema de raridade na loja (como TFT)
    instance.rarityWeights = {
        common = 0.7,    -- 70%
        uncommon = 0.25, -- 25%
        rare = 0.05     -- 5%
    }
    
    instance:initializeShopPools()
    
    return instance
end

-- Inicializa os pools de cartas e upgrades disponíveis na loja
function ShopSystem:initializeShopPools()
    local cardDatabase = CardDatabase:new()
    local allCards = cardDatabase:getAllCards()
    
    -- Separa cartas por raridade
    for cardId, cardData in pairs(allCards) do
        if cardData.rarity then
            if not self.shopCardPool[cardData.rarity] then
                self.shopCardPool[cardData.rarity] = {}
            end
            table.insert(self.shopCardPool[cardData.rarity], cardId)
        end
    end
    
    -- Define upgrades disponíveis
    self.shopUpgradePool = {
        {
            id = "health_upgrade",
            name = "Vida Extra",
            description = "+10 HP máximo",
            cost = 5,
            effect = "increase_max_health",
            value = 10
        },
        {
            id = "mana_upgrade", 
            name = "Mana Extra",
            description = "+1 mana máxima",
            cost = 8,
            effect = "increase_base_mana",
            value = 1
        },
        {
            id = "card_draw_upgrade",
            name = "Cartas Extras",
            description = "+1 carta por turno",
            cost = 6,
            effect = "increase_card_draw",
            value = 1
        },
        {
            id = "damage_upgrade",
            name = "Dano Bônus",
            description = "+2 dano em cartas de ataque",
            cost = 4,
            effect = "increase_attack_damage",
            value = 2
        },
        {
            id = "defense_upgrade",
            name = "Defesa Bônus", 
            description = "+2 defesa em cartas defensivas",
            cost = 4,
            effect = "increase_defense",
            value = 2
        }
    }
end

-- Abre a loja e gera ofertas
function ShopSystem:openShop()
    self.isOpen = true
    self:generateOffers()
end

-- Fecha a loja
function ShopSystem:closeShop()
    self.isOpen = false
    self.currentOffers = {}
end

-- Gera ofertas aleatórias para a loja
function ShopSystem:generateOffers()
    self.currentOffers = {}
    
    -- Gera cartas (70% das ofertas)
    local cardOffers = math.floor(self.maxOffers * 0.7)
    for i = 1, cardOffers do
        local offer = self:generateCardOffer()
        if offer then
            table.insert(self.currentOffers, offer)
        end
    end
    
    -- Gera upgrades (30% das ofertas)
    local upgradeOffers = self.maxOffers - #self.currentOffers
    for i = 1, upgradeOffers do
        local offer = self:generateUpgradeOffer()
        if offer then
            table.insert(self.currentOffers, offer)
        end
    end
end

-- Gera uma oferta de carta
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
                image = cardData.image
            }
        end
    end
    
    return nil
end

-- Gera uma oferta de upgrade
function ShopSystem:generateUpgradeOffer()
    local availableUpgrades = self.shopUpgradePool
    local randomUpgrade = availableUpgrades[love.math.random(#availableUpgrades)]
    
    return {
        type = "upgrade",
        id = randomUpgrade.id,
        name = randomUpgrade.name,
        description = randomUpgrade.description,
        cost = randomUpgrade.cost,
        effect = randomUpgrade.effect,
        value = randomUpgrade.value
    }
end

-- Calcula custo de uma carta baseado na raridade
function ShopSystem:calculateCardCost(rarity)
    local rarityMultipliers = {
        common = 1,
        uncommon = 2,
        rare = 3,
        legendary = 5
    }
    
    return self.cardCostBase * (rarityMultipliers[rarity] or 1)
end

-- Rola raridade baseado nos pesos
function ShopSystem:rollRarity()
    local roll = love.math.random()
    local cumulative = 0
    
    for rarity, weight in pairs(self.rarityWeights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return rarity
        end
    end
    
    return "common" -- Fallback
end

-- Refresha as ofertas da loja
function ShopSystem:refreshOffers()
    self.refreshCount = self.refreshCount + 1
    self.refreshCost = self.refreshCost + self.refreshCount -- Custo aumenta a cada refresh
    self:generateOffers()
end

-- Compra um item da loja
function ShopSystem:purchaseItem(offerIndex, economySystem)
    local offer = self.currentOffers[offerIndex]
    if not offer then return false end
    
    if economySystem:spendGold(offer.cost, offer.type, offer.id) then
        -- Remove a oferta da loja
        table.remove(self.currentOffers, offerIndex)
        return true, offer
    end
    
    return false
end

-- Retorna ofertas atuais
function ShopSystem:getCurrentOffers()
    return self.currentOffers
end

-- Retorna custo de refresh
function ShopSystem:getRefreshCost()
    return self.refreshCost
end

return ShopSystem
