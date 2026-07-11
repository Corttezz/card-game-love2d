-- src/systems/ShopSystem.lua
-- Sistema de loja inspirado no TFT e Balatro. Pós-redesign Fase 4:
--   • Modo "rewards": gera 3 cartas (post-battle).
--   • Modo "shop":    gera 4 cartas + 1 voucher (upgrade) + 2 booster packs.
--   • Reroll exponencial 5→7→10→14→20 (multiplicador 1.4).
--   • Booster packs como ofertas próprias (Fase 5 implementa abertura).

local ShopSystem = {}
ShopSystem.__index = ShopSystem

local CardDatabase = require("src.systems.CardDatabase")
local CardRegistry = require("src.systems.CardRegistry")
local Rng          = require("src.systems.Rng")

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

    -- Pool de upgrades da loja (cartas vêm do CardRegistry.pickRewardCard).
    instance.shopUpgradePool = {}

    -- Sistema de raridade na loja (como TFT)
    instance.rarityWeights = {
        common = 0.7,
        uncommon = 0.25,
        rare = 0.05,
    }

    -- Cérebro de oferta compartilhado com as recompensas (pity + afinidade +
    -- anti-duplicata moram no CardRegistry.pickRewardCard — uma regra só).
    instance.cardRegistry = CardRegistry:new()
    instance.cardDatabase = CardDatabase:new()

    -- Contexto da run (classe + deck) injetado por quem abre a loja
    -- (CardRewardScreen:show). Sem contexto: pool global, sem afinidade.
    instance.context = {}
    instance._offeredCardIds = {}

    instance:initializeShopPools()

    return instance
end

-- Injeta o contexto da run atual antes de gerar ofertas.
-- ctx = { classId = "warrior", deckIds = { "id1", "id2", ... } }
function ShopSystem:setContext(ctx)
    self.context = ctx or {}
end

-- Inicializa o pool de upgrades disponíveis na loja.
-- (O pool de CARTAS por raridade foi aposentado: ofertas de carta saem do
-- CardRegistry.pickRewardCard, que filtra por classe e aplica pity/afinidade.)
function ShopSystem:initializeShopPools()
    self.shopUpgradePool = {
        { id = "health_upgrade",     name = "Vida Extra",   description = "+10 HP máximo",            cost = 5, effect = "increase_max_health",    value = 10 },
        { id = "mana_upgrade",       name = "Mana Extra",   description = "+1 mana máxima",           cost = 25, effect = "increase_base_mana",    value = 1  },
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
    -- Dedup por geração: a mesma carta nunca aparece 2x na mesma vitrine.
    self._offeredCardIds = {}
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
    -- Delegado pro CardRegistry (pity + afinidade + anti-duplicata + filtro de
    -- classe). Stream "shop": rolls da loja não mexem na sequência de rewards.
    local pick = self.cardRegistry:pickRewardCard({
        classId = self.context.classId,
        rarityWeights = self.rarityWeights,
        deckIds = self.context.deckIds,
        excludeIds = self._offeredCardIds,
        stream = "shop",
    })
    if not pick then return nil end
    self._offeredCardIds[pick.cardId] = true

    local cardData = self.cardDatabase:getCard(pick.cardId)
    if not cardData then return nil end

    local cost = self:calculateCardCost(cardData.rarity)
    -- Recompensa pós-batalha é GRÁTIS (StS: escolha 1 de 3; pagar
    -- é papel da LOJA). Autoplay B: recompensas pagas travavam o
    -- crescimento do deck (~40% puladas por falta de ouro).
    if self.mode == "rewards" then cost = 0 end
    return {
        type = "card",
        id = pick.cardId,
        name = cardData.name,
        description = cardData.description,
        cost = cost,
        rarity = cardData.rarity,
        image = cardData.image,
        -- Afinidade (badge na UI): a oferta foi puxada por tags fortes do deck.
        affinity = pick.affinity or nil,
        affinityTags = pick.affinityTags,
        fromPity = pick.fromPity,
    }
end

function ShopSystem:generateUpgradeOffer()
    -- Metade das vitrines oferece a FORJA (+1 nível numa carta à sua escolha,
    -- custo crescente por forja COMPRADA na run — RunManager:getPaidForgeCost);
    -- a outra metade, um upgrade global do pool clássico.
    local runManager = self.context and self.context.runManager
    if runManager and runManager.getPaidForgeCost
        and Rng.get():random("shop") < 0.5 then
        return {
            type = "upgrade",
            id = "forge_card",
            name = "Forja",
            description = "+1 nível numa carta à sua escolha (você escolhe ao comprar)",
            cost = runManager:getPaidForgeCost(),
            effect = "forge_card",
            value = 1,
        }
    end

    local pool = self.shopUpgradePool
    local pick = Rng.get():pick("shop", pool)
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

-- Sorteia booster pack ponderado por weight (stream "shop" do Rng da run).
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
        name = p.name,
        description = p.description,
        cost = p.cost,
        kind = p.kind,
        size = p.size,
        choose = p.choose,
    }
end

function ShopSystem:calculateCardCost(rarity)
    local rarityMultipliers = {
        common = 1, uncommon = 2, rare = 3, legendary = 10,
    }
    return self.cardCostBase * (rarityMultipliers[rarity] or 1)
end

-- rollRarity local removido: a raridade da loja agora sai do MESMO roll das
-- recompensas (CardRegistry:rollRarity via pickRewardCard) — com pity
-- compartilhado e ordem determinística (o pairs() antigo nem era estável).

-- Refresha ofertas. Custo cresce exponencialmente (Balatro feel) — não linear como antes.
-- Cap em REROLL_MAX pra impedir trap de gold drain.
function ShopSystem:refreshOffers()
    self.refreshCount = self.refreshCount + 1
    -- Linear Balatro-style (base + 2/reroll): o exponencial punia demais o
    -- segundo reroll e o cap ficava irrelevante.
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

function ShopSystem:getRefreshCost()
    return self.refreshCost
end

-- Tabela de tipos de booster pack — exposta pra Fase 5 (BoosterPackSystem) ler.
function ShopSystem.getBoosterTypes()
    return BOOSTER_PACK_TYPES
end

return ShopSystem
