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
        -- P0.1 (rebalance Jul/2026): class=='basic' e NEUTRA OFERTAVEL — devolve
        -- 9 cartas ao jogo (attack_cleave, defense_bulwark, scroll_wisdom,
        -- mystery_card, joker_004/005 e os 3 legendarios joker_001/002/003).
        -- O clause antigo por rarity=='basic' era codigo morto e foi removido.
        local belongsToClass = (card.class == classId) or
                              (not card.class) or -- Cartas sem classe são consideradas básicas
                              (card.class == "basic")
        
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

-- ===== Afinidade de ofertas (P0.5, rebalance Jul/2026) =====
-- Tags genericas demais para sinalizar arquetipo (quase toda carta as tem):
-- conta-las fazia a afinidade puxar "mais do mesmo" em vez de build.
local AFFINITY_TAG_BLACKLIST = { strike = true, defend = true, armor = true, magic = true }
-- Peso por tag forte. SUPERSEDE Config.Offers.AFFINITY_PER_TAG=0.20 (handoff:
-- centralizar em Config.Offers junto com o cap por ato e a blacklist).
local AFFINITY_PER_TAG = 0.45
-- Cap PROGRESSIVO por ato (era 0.60 flat em Config.Offers.AFFINITY_CAP):
-- A1 baixo preserva a variedade do draft inicial (2 primeiros picks nao
-- travam a run); A2/A3 entregam densidade de arquetipo onde importa.
-- Endless (ato > 3) usa o cap do A3.
local AFFINITY_CAP_BY_ACT = { [1] = 0.9, [2] = 1.2, [3] = 1.5 }
-- P0.2: cartas neutras (class nil ou 'basic') ofertam com peso reduzido —
-- a vitrine continua majoritariamente da classe.
local NEUTRAL_CARD_WEIGHT = 0.6

-- P0.10: set { [jokerId]=true } dos jokers ja POSSUIDOS pela run (colecao +
-- bancada). Dedup e de OFERTA apenas: a posse/colecao fica intocada (lei do
-- projeto) — a vitrine e que nao repete joker (flat duplicado e valor
-- marginal; multiplicador duplicado vale zero pos-largest-wins P0.9).
local function buildOwnedJokerSet(runManager)
    local owned = {}
    local run = runManager and runManager.currentRun
    if run and run.jokers then
        for _, entry in ipairs(run.jokers) do
            local id = type(entry) == "table" and entry.id or entry
            if id then owned[id] = true end
        end
    end
    return owned
end

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
--   actNumber     — ato atual (P0.5: cap progressivo de afinidade 0.9/1.2/1.5)
--   runManager    — P0.10: dedup de joker já possuído (ou passe ownedJokerIds)
--   ownedJokerIds — set { [jokerId]=true } pré-construído (opcional)
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

    -- P0.5: cap de afinidade progressivo por ato (endless herda o do A3).
    local actNumber = opts.actNumber or 1
    local affinityCap = AFFINITY_CAP_BY_ACT[math.min(actNumber, 3)] or 1.5

    -- P0.10: jokers já possuídos saem da vitrine (posse intocada).
    local ownedJokers = opts.ownedJokerIds or buildOwnedJokerSet(opts.runManager)

    local entries = {}
    for _, cardId in ipairs(pool) do
        local cd = self.cardDatabase:getCard(cardId)
        local excluded = (opts.excludeIds and opts.excludeIds[cardId])
            or (cd and cd.type == "joker" and ownedJokers[cardId])
        if not excluded then
            -- P0.2: neutras (class nil/'basic') entram com peso base 0.6.
            local weight = (cd and (cd.class == nil or cd.class == "basic"))
                and NEUTRAL_CARD_WEIGHT or 1.0
            local affinityTags = nil

            -- Afinidade: cada tag da carta que é "forte" no deck puxa a oferta.
            -- P0.5: tags genéricas (blacklist) não contam; 0.45/tag com cap por ato.
            if cd and cd.tags then
                local bonus = 0
                for _, tag in ipairs(cd.tags) do
                    if not AFFINITY_TAG_BLACKLIST[tag]
                        and (tagCounts[tag] or 0) >= cfg.AFFINITY_MIN_COUNT then
                        bonus = bonus + AFFINITY_PER_TAG
                        affinityTags = affinityTags or {}
                        table.insert(affinityTags, tag)
                    end
                end
                if bonus > affinityCap then bonus = affinityCap end
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
            actNumber = opts.actNumber,       -- P0.5: cap de afinidade por ato
            runManager = opts.runManager,     -- P0.10: dedup de joker possuído
            ownedJokerIds = opts.ownedJokerIds,
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
-- P0.1: mesmo critério de belongsToClass — class=='basic' é neutra (o clause
-- antigo por rarity=='basic' foi removido).
function CardRegistry:isClassCard(cardId, classId)
    local cardData = self.cardDatabase:getCard(cardId)
    if not cardData then return false end

    return cardData.class == classId or
           cardData.class == "basic" or
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
