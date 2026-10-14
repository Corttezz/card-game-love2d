local Debug = require("src.core.Debug")

local TagSystem = {}

TagSystem.CATALOG = {
    strike     = { category = "archetype", color = {0.85, 0.30, 0.25}, desc = "Ataque fisico" },
    defend     = { category = "archetype", color = {0.30, 0.55, 0.85}, desc = "Defesa/armor" },
    passive    = { category = "archetype", color = {0.90, 0.75, 0.20}, desc = "Joker passivo" },
    utility    = { category = "archetype", color = {0.45, 0.80, 0.50}, desc = "Efeito/utility" },

    armor       = { category = "mechanic",  color = {0.55, 0.65, 0.75}, desc = "Empilha armor" },
    poison      = { category = "mechanic",  color = {0.40, 0.75, 0.30}, desc = "Aplica veneno" },
    weak        = { category = "mechanic",  color = {0.60, 0.50, 0.80}, desc = "Debuff weak" },
    vulnerable  = { category = "mechanic",  color = {0.80, 0.50, 0.60}, desc = "Debuff vulnerable" },
    strength    = { category = "mechanic",  color = {0.85, 0.45, 0.25}, desc = "Ganha/usa strength" },
    dexterity   = { category = "mechanic",  color = {0.50, 0.70, 0.50}, desc = "Ganha/usa dexterity" },
    channel     = { category = "mechanic",  color = {0.40, 0.60, 0.90}, desc = "Canaliza orb" },
    evoke       = { category = "mechanic",  color = {0.50, 0.30, 0.70}, desc = "Evoca orb" },
    exhaust     = { category = "mechanic",  color = {0.55, 0.40, 0.55}, desc = "Exaurir (remove da run)" },
    innate      = { category = "mechanic",  color = {0.75, 0.75, 0.40}, desc = "Comeca na mao" },
    retain      = { category = "mechanic",  color = {0.75, 0.60, 0.30}, desc = "Nao descarta no fim do turno" },
    draw        = { category = "mechanic",  color = {0.60, 0.85, 0.85}, desc = "Compra cartas" },
    discard     = { category = "mechanic",  color = {0.65, 0.55, 0.45}, desc = "Descarta cartas" },
    heal        = { category = "mechanic",  color = {0.90, 0.55, 0.70}, desc = "Cura" },
    lifesteal   = { category = "mechanic",  color = {0.70, 0.20, 0.30}, desc = "Cura ao atacar" },
    thorn       = { category = "mechanic",  color = {0.50, 0.50, 0.60}, desc = "Reflete dano" },
    aoe         = { category = "mechanic",  color = {0.85, 0.65, 0.35}, desc = "Dano em area" },
    mana        = { category = "mechanic",  color = {0.30, 0.45, 0.90}, desc = "Interage com mana" },
    debuff      = { category = "mechanic",  color = {0.70, 0.40, 0.65}, desc = "Aplica debuff generico" },
    potion      = { category = "mechanic",  color = {0.85, 0.40, 0.85}, desc = "Pocao/consumivel" },

    fire        = { category = "element",   color = {0.95, 0.45, 0.15}, desc = "Fogo" },
    ice         = { category = "element",   color = {0.55, 0.80, 0.95}, desc = "Gelo" },
    lightning   = { category = "element",   color = {0.95, 0.85, 0.25}, desc = "Raio" },
    dark        = { category = "element",   color = {0.30, 0.20, 0.45}, desc = "Sombra" },
    holy        = { category = "element",   color = {0.95, 0.90, 0.65}, desc = "Luz" },
    magic       = { category = "element",   color = {0.60, 0.40, 0.85}, desc = "Magia generica" },

    finisher    = { category = "role",      color = {0.90, 0.20, 0.30}, desc = "Carta de remate" },
    starter     = { category = "role",      color = {0.55, 0.85, 0.55}, desc = "Carta inicial" },
    combo       = { category = "role",      color = {0.85, 0.70, 0.40}, desc = "Peca de combo" },
    cycle       = { category = "role",      color = {0.70, 0.85, 0.55}, desc = "Parte de motor draw/discard" },
    scaling     = { category = "role",      color = {0.80, 0.50, 0.25}, desc = "Escala com estado" },
    zero_cost   = { category = "role",      color = {0.60, 0.60, 0.60}, desc = "Custo zero" },
}

local IMPLICIT_BY_TYPE = {
    attack  = "strike",
    defense = "defend",
    joker   = "passive",
    effect  = "utility",
}

function TagSystem.implicitTagFor(cardType)
    return IMPLICIT_BY_TYPE[cardType]
end

local warnedTag = {}
function TagSystem.isValid(tag)
    if not TagSystem.CATALOG[tag] then
        if not warnedTag[tag] then
            warnedTag[tag] = true
            Debug.warn("[TagSystem] AVISO: tag desconhecida: " .. tostring(tag))
        end
        return false
    end
    return true
end

function TagSystem.getCardTags(card)
    local out = {}
    local seen = {}

    local implicit = IMPLICIT_BY_TYPE[card.type]
    if implicit then
        table.insert(out, implicit)
        seen[implicit] = true
    end

    if card.tags and type(card.tags) == "table" then
        for _, tag in ipairs(card.tags) do
            if type(tag) == "string" and not seen[tag] then
                local clean = tag:gsub("^#", "")
                if not seen[clean] then
                    TagSystem.isValid(clean)
                    table.insert(out, clean)
                    seen[clean] = true
                end
            end
        end
    end

    return out
end

function TagSystem.countTagInCards(cards, tag)
    if not cards or not tag then return 0 end
    local count = 0
    local clean = tag:gsub("^#", "")
    for _, card in ipairs(cards) do
        local tags = TagSystem.getCardTags(card)
        for _, t in ipairs(tags) do
            if t == clean then
                count = count + 1
                break
            end
        end
    end
    return count
end

function TagSystem.countAllTags(cards)
    local counts = {}
    if not cards then return counts end
    for _, card in ipairs(cards) do
        local tags = TagSystem.getCardTags(card)
        local weight = 1
        for _, tag in ipairs(tags) do
            if tag == "combo" then weight = 2 break end
        end
        for _, tag in ipairs(tags) do
            if tag ~= "combo" then
                counts[tag] = (counts[tag] or 0) + weight
            end
        end
    end
    return counts
end

function TagSystem.cardHasTag(card, tag)
    local clean = tag:gsub("^#", "")
    for _, t in ipairs(TagSystem.getCardTags(card)) do
        if t == clean then return true end
    end
    return false
end

function TagSystem.cardHasAnyTag(card, tags)
    for _, tag in ipairs(tags) do
        if TagSystem.cardHasTag(card, tag) then return true end
    end
    return false
end

function TagSystem.cardHasAllTags(card, tags)
    for _, tag in ipairs(tags) do
        if not TagSystem.cardHasTag(card, tag) then return false end
    end
    return true
end

function TagSystem.getTagInfo(tag)
    local clean = tag:gsub("^#", "")
    return TagSystem.CATALOG[clean] or {
        category = "unknown",
        color = {0.5, 0.5, 0.5},
        desc = clean,
    }
end

function TagSystem.listByCategory(category)
    local out = {}
    for tag, info in pairs(TagSystem.CATALOG) do
        if info.category == category then
            table.insert(out, tag)
        end
    end
    table.sort(out)
    return out
end

return TagSystem
