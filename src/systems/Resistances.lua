local Enemies = require("src.data.enemies")

local Resistances = {}

Resistances.ENABLED = true

Resistances.TYPES = { "physical", "fire", "ice", "lightning", "dark", "arcane", "poison", "holy" }

local VALID = {}
for _, ty in ipairs(Resistances.TYPES) do VALID[ty] = true end

function Resistances.isValidType(ty)
    return ty ~= nil and VALID[ty] == true
end

Resistances.MULT = { immune = 0, resist = 0.5, weak = 1.5 }

Resistances.LEVEL_ORDER = { immune = 1, resist = 2, weak = 3 }

Resistances.ICON = {
    physical = "sword_short", fire = "flame", ice = "snowflake", lightning = "bolt",
    dark = "moon", arcane = "rune", poison = "status_poison", holy = "star",
}

Resistances.THEME = {
    physical = "physical", fire = "fire", ice = "ice", lightning = "lightning",
    dark = "dark", arcane = "magic", poison = "poison", holy = "holy",
}

Resistances.DOT_TYPE = { poison = "poison", burn = "fire" }

Resistances.ORB_TYPE = { lightning = "lightning", fire = "fire", dark = "dark" }

local ELEMENTS = { "fire", "ice", "lightning", "dark" }

local function hasTag(card, tag)
    for _, t in ipairs((card and card.tags) or {}) do
        if t == tag then return true end
    end
    return false
end

local function elementOf(card)
    for _, el in ipairs(ELEMENTS) do
        if hasTag(card, el) then return el end
    end
    return nil
end

local function explicitOf(card)
    local ty = card and card.damageType
    if ty and VALID[ty] then return ty end
    return nil
end

function Resistances.ofCard(card)
    local ex = explicitOf(card)
    if ex then return ex end
    local el = elementOf(card)
    if el then return el end
    if hasTag(card, "magic") then return "arcane" end
    return "physical"
end

function Resistances.ofSpell(card)
    local ex = explicitOf(card)
    if ex and ex ~= "physical" then return ex end
    return elementOf(card) or "arcane"
end

local function dealsDamage(card)
    if card.type == "attack" and (card.attack or 0) > 0 then return true end
    for _, e in ipairs(card.effects or {}) do
        local t = e.type
        if t == "magic_damage" or t == "aoe_magic_damage" then return true end
        if t == "apply_debuff" and Resistances.DOT_TYPE[e.value] then return true end
        if t == "on_attack_debuff" and Resistances.DOT_TYPE[e.debuffName or "poison"] then return true end
    end
    return false
end

function Resistances.dealsDamage(card)
    return card ~= nil and dealsDamage(card)
end

function Resistances.elementOfCard(card)
    if not card then return nil, false end
    local ex = explicitOf(card)
    local dmg = dealsDamage(card)
    if ex then return ex, dmg end
    if dmg then return Resistances.ofCard(card), true end
    return nil, false
end

function Resistances.badgeOf(card)
    local ty = Resistances.elementOfCard(card)
    if ty == "physical" then return nil end
    return ty
end

local EMPTY = {}

function Resistances.tableFor(enemy)
    if not enemy then return EMPTY end
    local id = enemy.kitId
    if not id or id == "generic" then id = enemy.spriteId end
    return (id and Enemies.RESIST[id]) or EMPTY
end

function Resistances.level(enemy, dtype)
    if not Resistances.ENABLED or not dtype then return nil end
    local lvl = Resistances.tableFor(enemy)[dtype]
    if lvl == "resist" and require("src.systems.CounterJokers").piercesResist(enemy) then return nil end
    return lvl
end

function Resistances.scale(level, v)
    if not level or not v or v <= 0 then return v end
    if level == "immune" then return 0 end
    if level == "resist" then return math.max(1, math.floor(v * Resistances.MULT.resist)) end
    if level == "weak" then return math.floor(v * Resistances.MULT.weak) end
    return v
end

function Resistances.apply(enemy, dtype, v)
    local lvl = Resistances.level(enemy, dtype)
    if not lvl then return v, nil end
    return Resistances.scale(lvl, v), lvl
end

function Resistances.factor(enemy, dtype)
    local lvl = Resistances.level(enemy, dtype)
    return lvl and Resistances.MULT[lvl] or 1
end

function Resistances.entries(enemy)
    local out = {}
    if not Resistances.ENABLED then return out end
    for _, ty in ipairs(Resistances.TYPES) do
        local lvl = Resistances.level(enemy, ty)
        if lvl then out[#out + 1] = { type = ty, level = lvl } end
    end
    table.sort(out, function(a, b)
        local oa, ob = Resistances.LEVEL_ORDER[a.level], Resistances.LEVEL_ORDER[b.level]
        if oa ~= ob then return oa < ob end
        return a.type < b.type
    end)
    return out
end

local function worse(a, b)
    if not a then return b end
    if not b then return a end
    if Resistances.LEVEL_ORDER[b.level] < Resistances.LEVEL_ORDER[a.level] then return b end
    return a
end

function Resistances.cardChannels(card)
    local out = {}
    if not card then return out end
    if card.type == "attack" and (card.attack or 0) > 0 then
        out[#out + 1] = Resistances.ofCard(card)
    end
    for _, e in ipairs(card.effects or {}) do
        local t = e.type
        if t == "magic_damage" or t == "aoe_magic_damage" then
            out[#out + 1] = Resistances.ofSpell(card)
        elseif t == "apply_debuff" and Resistances.DOT_TYPE[e.value] then
            out[#out + 1] = Resistances.DOT_TYPE[e.value]
        elseif t == "on_attack_debuff" and Resistances.DOT_TYPE[e.debuffName or "poison"] then
            out[#out + 1] = Resistances.DOT_TYPE[e.debuffName or "poison"]
        end
    end
    return out
end

function Resistances.cardHint(enemy, card)
    if not Resistances.ENABLED or not enemy or not card then return nil end
    local best
    for _, ty in ipairs(Resistances.cardChannels(card)) do
        local lvl = Resistances.level(enemy, ty)
        if lvl then best = worse(best, { type = ty, level = lvl }) end
    end
    return best
end

return Resistances
