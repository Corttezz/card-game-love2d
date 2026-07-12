-- tools/test_cards.lua
-- Catálogo + registry + deck: integridade do catálogo (toda carta instancia),
-- createCardInstance (tipos, flags exhaust/innate/retain), rollRarity
-- (determinístico nos extremos + distribuição), pools por classe, starter decks.
-- Conferido em CardDatabase.lua, CardRegistry.lua, DeckManager.lua.
--   love . test_cards

local TK = require("tools.testkit")
local CardDatabase = require("src.systems.CardDatabase")
local CardRegistry = require("src.systems.CardRegistry")
local DeckManager  = require("src.systems.DeckManager")

local VALID_TYPES = { attack = true, defense = true, joker = true, effect = true }
local VALID_RARITY = { common = true, uncommon = true, rare = true, legendary = true, basic = true }

local M = {}

function M.run()
    TK.bootstrap()
    local t = TK.new("cartas: catálogo + registry + deck")

    local db = CardDatabase:new()
    local all = db:getAllCards()

    -- ===== Integridade do catálogo (property test sobre TODAS as cartas) =====
    local total = db:getTotalCardCount()
    t:truthy("catálogo tem cartas (> 80)", total > 80)

    local badSchema, badType, badRarity, instFails = 0, 0, 0, 0
    for id, cd in pairs(all) do
        if not (cd.id and cd.name and cd.type and cd.cost ~= nil) then badSchema = badSchema + 1 end
        if not VALID_TYPES[cd.type] then badType = badType + 1 end
        if cd.rarity and not VALID_RARITY[cd.rarity] then badRarity = badRarity + 1 end
        -- Toda carta precisa instanciar sem erro (renderiza moldura procedural).
        local ok = pcall(function() return db:createCardInstance(cd) end)
        if not ok then instFails = instFails + 1; print("     instância falhou: " .. tostring(id)) end
    end
    t:eq("toda carta tem id/name/type/cost", badSchema, 0)
    t:eq("todo type é válido", badType, 0)
    t:eq("toda rarity é válida", badRarity, 0)
    t:eq("TODA carta instancia sem erro", instFails, 0)

    -- ===== createCardInstance: mapeamento de tipo e flags =====
    t:eq("warrior_strike -> attack", db:createCardInstance(db:getCard("warrior_strike")).type, "attack")
    t:eq("warrior_defend -> defense", db:createCardInstance(db:getCard("warrior_defend")).type, "defense")
    t:eq("joker_001 -> joker", db:createCardInstance(db:getCard("joker_001")).type, "joker")
    t:eq("effect_healing_potion -> effect", db:createCardInstance(db:getCard("effect_healing_potion")).type, "effect")

    -- flags derivadas (rogue_backstab: innate + exhaust)
    local backstab = db:createCardInstance(db:getCard("rogue_backstab"))
    t:truthy("exhaust detectada dos effects", backstab.exhaust == true)
    t:truthy("innate detectada", backstab.innate == true)

    -- tags sempre presentes (derivadas se vazio)
    local strikeInst = db:createCardInstance(db:getCard("warrior_strike"))
    t:truthy("instância tem tags", type(strikeInst.tags) == "table" and #strikeInst.tags > 0)

    -- getCardsByType / getCardsByRarity (retornam mapa {[id]=card}, não sequência)
    t:truthy("getCardsByType('attack') não vazio", next(db:getCardsByType("attack")) ~= nil)
    t:truthy("getCardsByRarity('legendary') não vazio", next(db:getCardsByRarity("legendary")) ~= nil)
    t:falsy("getCard(inexistente) = nil", db:getCard("nao_existe_123"))

    -- ===== CardRegistry: rollRarity =====
    local reg = CardRegistry:new()
    local r = TK.seedRng(999)

    -- extremos determinísticos
    local allCommon = true
    for _ = 1, 200 do
        if reg:rollRarity({ common = 100, uncommon = 0, rare = 0, legendary = 0 }, { rng = r, stream = "card" }) ~= "common" then
            allCommon = false
        end
    end
    t:truthy("peso 100/0/0/0 sempre common", allCommon)

    local allLegendary = true
    for _ = 1, 200 do
        if reg:rollRarity({ common = 0, uncommon = 0, rare = 0, legendary = 100 }, { rng = r, stream = "card" }) ~= "legendary" then
            allLegendary = false
        end
    end
    t:truthy("peso 0/0/0/100 sempre legendary", allLegendary)

    -- distribuição com defaults: todas raridades aparecem, legendary é a mais rara
    local counts = { common = 0, uncommon = 0, rare = 0, legendary = 0 }
    local r2 = TK.seedRng(31337)
    for _ = 1, 3000 do
        local rar = reg:rollRarity(nil, { rng = r2, stream = "card" })
        counts[rar] = (counts[rar] or 0) + 1
    end
    t:truthy("distribuição gera common", counts.common > 0)
    t:truthy("distribuição gera uncommon", counts.uncommon > 0)
    t:truthy("distribuição gera rare", counts.rare > 0)
    t:truthy("distribuição gera legendary", counts.legendary > 0)
    t:truthy("legendary mais rara que common", counts.legendary < counts.common)
    t:truthy("legendary mais rara que rare", counts.legendary < counts.rare)

    -- ===== starter decks e pools por classe =====
    local starter = reg:getStarterDeckForClass("warrior")
    t:eq("starter warrior = 2 cartas", #starter, 2)
    t:eq("starter warrior[1]", starter[1], "warrior_strike")
    t:eq("starter mage[1]", reg:getStarterDeckForClass("mage")[1], "mage_zap")
    t:eq("starter rogue[1]", reg:getStarterDeckForClass("rogue")[1], "rogue_strike")

    -- pool por classe: warrior tem commons; básicas entram em qualquer classe
    local warCommons = reg:getCardsByClassAndRarity("warrior", "common")
    t:truthy("warrior tem pool de commons", #warCommons > 0)
    -- básica (defense_001, sem classe) deve aparecer p/ warrior E mage (sem filtro rarity)
    local function poolHas(list, id)
        for _, x in ipairs(list) do if x == id then return true end end
        return false
    end
    local warAll = reg:getCardsByClassAndRarity("warrior", nil)
    local mageAll = reg:getCardsByClassAndRarity("mage", nil)
    t:truthy("básica no pool de warrior", poolHas(warAll, "defense_001"))
    t:truthy("básica no pool de mage", poolHas(mageAll, "defense_001"))

    -- countDeckTags conta por cópia
    local tags = reg:countDeckTags({ "warrior_strike", "warrior_strike", "warrior_defend" })
    t:truthy("countDeckTags retorna tabela", type(tags) == "table")

    -- ===== DeckManager (modo clássico) =====
    local dm = DeckManager:new()
    t:truthy("getAvailableDecks não vazio", next(dm:getAvailableDecks()) ~= nil)
    local stats = dm:getDeckStats("starter")
    if stats then
        t:truthy("getDeckStats('starter') tem cartas", stats.totalCards > 0)
        t:truthy("getDeckStats soma custo médio", stats.averageCost ~= nil)
    else
        t:truthy("deck 'starter' existe (stats)", false)
    end

    return t:done()
end

return M
