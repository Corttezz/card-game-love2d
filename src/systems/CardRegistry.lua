-- src/systems/CardRegistry.lua
-- Sistema centralizado para gestão de cartas e classes.
-- Consolida consultas por classe/raridade, starter decks e rolagem de raridade.

local CardRegistry = {}
CardRegistry.__index = CardRegistry

local CardDatabase = require("src.systems.CardDatabase")
local I18n = require("src.i18n.I18n")
local Rng = require("src.systems.Rng")
local Config = require("src.core.Config")

function CardRegistry:new()
    local instance = setmetatable({}, CardRegistry)
    instance.cardDatabase = CardDatabase:new()
    return instance
end

-- Retorna cartas filtradas por classe e raridade
function CardRegistry:getCardsByClassAndRarity(classId, rarity)
    local allCards = self.cardDatabase:getAllCards()
    local filtered = {}
    
    for id, card in pairs(allCards) do
        -- Verifica se pertence à classe (ou é básica)
        local belongsToClass = (card.class == classId) or 
                              (not card.class) or -- Cartas sem classe são consideradas básicas
                              (card.rarity == "basic")
        
        if belongsToClass and (not rarity or card.rarity == rarity) then
            table.insert(filtered, id)
        end
    end

    -- Ordena por id: pairs() não tem ordem estável e a pool alimenta rolls
    -- seedados — sem sort, a mesma seed daria ofertas diferentes por sessão.
    table.sort(filtered)
    return filtered
end

-- Retorna pool de cartas para uma classe específica
function CardRegistry:getClassCardPool(classId)
    return {
        common = self:getCardsByClassAndRarity(classId, "common"),
        uncommon = self:getCardsByClassAndRarity(classId, "uncommon"),
        rare = self:getCardsByClassAndRarity(classId, "rare"),
        legendary = self:getCardsByClassAndRarity(classId, "legendary"),
        basic = self:getCardsByClassAndRarity(classId, "basic")
    }
end

-- Retorna deck inicial para uma classe.
-- Fase 5: deck minimo de 2 cartas (1 attack + 1 defense da classe). O resto e
-- construido via recompensas/loja/eventos. Cada batalha puxa as 2 cartas direto
-- na mao inicial (INITIAL_HAND_SIZE=4 garante folga mesmo com deck curto).
function CardRegistry:getStarterDeckForClass(classId)
    local starterDecks = {
        warrior = { "warrior_strike", "warrior_defend" },
        mage    = { "mage_zap",       "defense_001" },
        rogue   = { "rogue_strike",   "rogue_defend" },
    }
    return starterDecks[classId] or { "attack_001", "defense_001" }
end

local RARITY_ORDER = { "common", "uncommon", "rare", "legendary" }
local RARITY_MIN_ORDER = { common = 1, uncommon = 2, rare = 3, legendary = 4 }

-- Pity de raridade vive em rng.meta (serializado no save junto com o RNG e
-- compartilhado entre recompensas E loja — uma sequência de azar só).
local function getPity(rng)
    rng.meta.cardPity = rng.meta.cardPity or 0
    return rng.meta.cardPity
end

local function setPity(rng, v)
    rng.meta.cardPity = v
end

-- Conta as tags do deck atual (por cópia — 3 cartas de veneno = veneno forte).
-- Alimenta a afinidade das ofertas: escolhas anteriores importam.
function CardRegistry:countDeckTags(deckIds)
    local counts = {}
    for _, id in ipairs(deckIds or {}) do
        local cd = self.cardDatabase:getCard(id)
        if cd and cd.tags then
            for _, tag in ipairs(cd.tags) do
                counts[tag] = (counts[tag] or 0) + 1
            end
        end
    end
    return counts
end

-- Sorteia UMA carta de oferta com pity + afinidade + anti-duplicata.
-- opts:
--   classId       — filtra pool da classe (nil = todas as cartas com raridade)
--   rarityWeights — pesos { common=, uncommon=, rare=, legendary= } (qualquer escala)
--   minRarity     — piso ("uncommon"/"rare" pra elites/bosses)
--   deckIds       — ids do deck atual (afinidade + penalidade de cópia)
--   excludeIds    — set { [cardId]=true } já oferecidos (dedup na mesma oferta)
--   rng, stream   — default Rng.get() / "card" (loja usa "shop")
-- Retorna { cardId, rarity, affinity, affinityTags, fromPity } ou nil.
function CardRegistry:pickRewardCard(opts)
    opts = opts or {}
    local rng = opts.rng or Rng.get()
    local stream = opts.stream or "card"
    local cfg = Config.Offers

    local rarity, fromPity = self:rollRarity(opts.rarityWeights, { rng = rng, stream = stream })
    if opts.minRarity and (RARITY_MIN_ORDER[rarity] or 0) < (RARITY_MIN_ORDER[opts.minRarity] or 0) then
        rarity = opts.minRarity
    end

    -- Pool da raridade (fallback desce a escada se vazia — ex: legendary numa
    -- classe sem lendárias não pode travar a oferta).
    local pool = self:_poolFor(opts.classId, rarity)
    if #pool == 0 then
        for _, r in ipairs({ "rare", "uncommon", "common" }) do
            pool = self:_poolFor(opts.classId, r)
            if #pool > 0 then rarity = r; break end
        end
    end
    if #pool == 0 then return nil end

    local tagCounts = opts._tagCounts or self:countDeckTags(opts.deckIds)
    local copies = {}
    for _, id in ipairs(opts.deckIds or {}) do
        copies[id] = (copies[id] or 0) + 1
    end

    local entries = {}
    for _, cardId in ipairs(pool) do
        if not (opts.excludeIds and opts.excludeIds[cardId]) then
            local weight = 1.0
            local affinityTags = nil
            local cd = self.cardDatabase:getCard(cardId)

            -- Afinidade: cada tag da carta que é "forte" no deck puxa a oferta.
            if cd and cd.tags then
                local bonus = 0
                for _, tag in ipairs(cd.tags) do
                    if (tagCounts[tag] or 0) >= cfg.AFFINITY_MIN_COUNT then
                        bonus = bonus + cfg.AFFINITY_PER_TAG
                        affinityTags = affinityTags or {}
                        table.insert(affinityTags, tag)
                    end
                end
                if bonus > cfg.AFFINITY_CAP then bonus = cfg.AFFINITY_CAP end
                weight = weight * (1 + bonus)
            end

            -- Anti-saturação: cópias demais no deck ⇒ oferta perde peso.
            if (copies[cardId] or 0) >= cfg.DUPE_THRESHOLD then
                weight = weight * cfg.DUPE_PENALTY
            end

            table.insert(entries, {
                item = { cardId = cardId, affinityTags = affinityTags },
                weight = weight,
            })
        end
    end
    if #entries == 0 then return nil end

    local picked = rng:weighted(stream, entries)
    return {
        cardId = picked.cardId,
        rarity = rarity,
        affinity = picked.affinityTags ~= nil,
        affinityTags = picked.affinityTags,
        fromPity = fromPity or nil,
    }
end

-- Pool ordenada por classe+raridade; classId nil = todas as cartas da raridade.
function CardRegistry:_poolFor(classId, rarity)
    if classId then
        return self:getCardsByClassAndRarity(classId, rarity)
    end
    local ids = {}
    for id, card in pairs(self.cardDatabase:getAllCards()) do
        if card.rarity == rarity then table.insert(ids, id) end
    end
    table.sort(ids)
    return ids
end

-- Gera recompensas de cartas para uma classe (sem duplicata na mesma oferta).
-- opts.rarityWeights: pesos customizados (ActSystem passa por ato).
-- opts.minRarity: "uncommon"/"rare" para forcar piso (elites/bosses).
-- opts.deckIds: deck atual — liga afinidade e anti-duplicata.
function CardRegistry:generateCardRewards(classId, numCards, opts)
    opts = opts or {}
    local rewards = {}
    local exclude = {}
    local tagCounts = self:countDeckTags(opts.deckIds)

    for _ = 1, numCards or 3 do
        local pick = self:pickRewardCard({
            classId = classId,
            rarityWeights = opts.rarityWeights,
            minRarity = opts.minRarity,
            deckIds = opts.deckIds,
            excludeIds = exclude,
            rng = opts.rng,
            stream = opts.stream or "card",
            _tagCounts = tagCounts,
        })
        if pick then
            exclude[pick.cardId] = true
            table.insert(rewards, pick)
        end
    end

    return rewards
end

-- Sistema de raridade com pesos customizaveis + PITY acumulativo.
-- weights: { common=N, uncommon=N, rare=N, legendary=N } (qualquer escala).
-- opts: { rng=, stream= }. Retorna (rarity, fromPity).
--
-- Pity ("blizzard" adaptado do StS): cada roll SEM rare/legendary incrementa
-- um contador que infla o peso de rare+legendary em PITY_STEP por nível;
-- na HARD_PITY-ésima oferta seca, rare é garantida. Sair rare+ zera. O
-- contador só se move quando rare é POSSÍVEL no peso (pools 100/0/0/0 dos
-- testes não inflam nada).
function CardRegistry:rollRarity(weights, opts)
    weights = weights or { common = 37, uncommon = 37, rare = 25, legendary = 1 }
    opts = opts or {}
    local rng = opts.rng or Rng.get()
    local stream = opts.stream or "card"
    local cfg = Config.Offers

    local rareW = weights.rare or 0
    local legW = weights.legendary or 0
    local rarePossible = rareW > 0 or legW > 0
    local pity = getPity(rng)

    -- Hard pity: garantia absoluta de rare+ (proporcional entre rare/legendary).
    if rarePossible and pity >= cfg.HARD_PITY then
        setPity(rng, 0)
        if legW > 0 and rng:random(stream) * (rareW + legW) > rareW then
            return "legendary", true
        end
        return "rare", true
    end

    -- Pesos efetivos: pity infla rare/legendary multiplicativamente.
    local mult = rarePossible and (1 + cfg.PITY_STEP * pity) or 1
    local eff = {
        common    = weights.common or 0,
        uncommon  = weights.uncommon or 0,
        rare      = rareW * mult,
        legendary = legW * mult,
    }
    local total = eff.common + eff.uncommon + eff.rare + eff.legendary
    if total <= 0 then return "common", false end

    local roll = rng:random(stream) * total
    local acc = 0
    local rolled = "common"
    for _, rarity in ipairs(RARITY_ORDER) do
        acc = acc + eff[rarity]
        if roll <= acc then
            rolled = rarity
            break
        end
    end

    if rolled == "rare" or rolled == "legendary" then
        setPity(rng, 0)
    elseif rarePossible then
        setPity(rng, pity + 1)
    end

    return rolled, false
end

-- Verifica se uma carta pertence a uma classe
function CardRegistry:isClassCard(cardId, classId)
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData then return false end
    
    return cardData.class == classId or 
           cardData.rarity == "basic" or 
           not cardData.class
end

-- Informações das classes (nome/descricao traduzidos via I18n).
function CardRegistry:getClassInfo(classId)
    local classes = {
        warrior = {
            id = "warrior",
            name = I18n.t("classes.warrior.name"),
            description = I18n.t("classes.warrior.desc"),
            -- Passiva de classe (identidade de gameplay — Jul/2026)
            passiveName = I18n.t("classes.warrior.passive_name"),
            passiveDesc = I18n.t("classes.warrior.passive_desc"),
            color = {0.8, 0.2, 0.2, 1.0},
            avatar = "assets/classes/warrior.png",
            traits = {
                strength_focus = true,
                armor_synergy = true,
                exhaust_mechanic = true
            }
        },
        mage = {
            id = "mage",
            name = I18n.t("classes.mage.name"),
            description = I18n.t("classes.mage.desc"),
            -- Passiva de classe (identidade de gameplay — Jul/2026)
            passiveName = I18n.t("classes.mage.passive_name"),
            passiveDesc = I18n.t("classes.mage.passive_desc"),
            color = {0.2, 0.2, 0.8, 1.0},
            avatar = "assets/classes/mage.png",
            traits = {
                orb_mechanic = true,
                focus_scaling = true,
                card_draw = true
            }
        },
        rogue = {
            id = "rogue",
            name = I18n.t("classes.rogue.name"),
            description = I18n.t("classes.rogue.desc"),
            -- Passiva de classe (identidade de gameplay — Jul/2026)
            passiveName = I18n.t("classes.rogue.passive_name"),
            passiveDesc = I18n.t("classes.rogue.passive_desc"),
            color = {0.2, 0.8, 0.2, 1.0},
            avatar = "assets/classes/rogue.png",
            traits = {
                poison_synergy = true,
                dexterity_focus = true,
                discard_mechanics = true
            }
        }
    }

    return classes[classId]
end

-- Retorna todas as classes
function CardRegistry:getAllClasses()
    return {
        warrior = self:getClassInfo("warrior"),
        mage = self:getClassInfo("mage"),
        rogue = self:getClassInfo("rogue")
    }
end

-- Delegate methods para manter compatibilidade com CardDatabase
function CardRegistry:getCard(cardId)
    return self.cardDatabase:getCard(cardId)
end

function CardRegistry:getAllCards()
    return self.cardDatabase:getAllCards()
end

function CardRegistry:getCardsByType(cardType)
    return self.cardDatabase:getCardsByType(cardType)
end

function CardRegistry:getCardsByRarity(rarity)
    return self.cardDatabase:getCardsByRarity(rarity)
end

function CardRegistry:createCardInstance(cardData)
    return self.cardDatabase:createCardInstance(cardData)
end

return CardRegistry
