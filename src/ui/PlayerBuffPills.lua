local StatusPill = require("src.ui.StatusPill")

local PlayerBuffPills = {}
PlayerBuffPills.__index = PlayerBuffPills

local BADGE_SIZE = 36
local BADGE_SPACING = 8

PlayerBuffPills.BAND_HEIGHT = BADGE_SIZE
PlayerBuffPills.BAND_GAP = 6

local PERMANENT_THRESHOLD = 90

local JOKER_DERIVED = {
    on_attack_heal   = "lifesteal",
    regen_per_turn   = "regen",
    damage_per_turn  = "bleed",
    retain_armor     = "retain_armor",
}

local HAS_PERMANENT_DESC = {
    thorn = true, lifesteal = true, regen = true, bleed = true, retain_armor = true,
}

local ORDER = {
    "strength", "dexterity", "focus",
    "thorn", "lifesteal", "regen", "bleed", "retain_armor",
    "weak_self", "frail", "vulnerable_self", "poison_self", "burn_self", "frost",
}

local DEBUFF_PILL = {
    weak = "weak_self", frail = "frail", vulnerable = "vulnerable_self",
    poison = "poison_self", burn = "burn_self",
}
PlayerBuffPills.DEBUFF_PILL = DEBUFF_PILL
local ORDER_INDEX = {}
for i, name in ipairs(ORDER) do ORDER_INDEX[name] = i end

function PlayerBuffPills:new()
    local instance = setmetatable({}, PlayerBuffPills)
    instance.animTime = 0
    return instance
end

function PlayerBuffPills:update(dt)
    self.animTime = self.animTime + (dt or 0)
end

function PlayerBuffPills.collect(player, game)
    if not player then return {} end
    local byName, order = {}, {}

    local function entry(name)
        local e = byName[name]
        if not e then
            e = { name = name, stacks = 0, duration = 0, showStacks = true }
            byName[name] = e
            order[#order + 1] = e
        end
        return e
    end

    if (player.strength or 0) > 0 then
        entry("strength").stacks = player.strength
    end
    if (player.dexterity or 0) > 0 then
        entry("dexterity").stacks = player.dexterity
    end

    for _, b in ipairs(player.buffs or {}) do
        local e = entry(b.name)
        e.stacks = e.stacks + (b.stacks or 1)
        local d = b.duration or 1
        if d > 0 and d < PERMANENT_THRESHOLD then
            e.duration = math.max(e.duration, d)
            e.timed = true
        end
    end

    for _, d in ipairs(player.debuffs or {}) do
        local pill = DEBUFF_PILL[d.name]
        if pill and (d.duration or 0) > 0 then
            local e = entry(pill)
            e.stacks = e.stacks + (d.stacks or 1)
            e.duration = math.max(e.duration, d.duration)
            e.timed = true
            if pill ~= "poison_self" and pill ~= "burn_self" then
                e.showStacks = false
            end
        end
    end

    if (player.frost or 0) > 0 then
        local e = entry("frost")
        e.stacks = player.frost
        e.duration = 1
        local vars = require("src.systems.BossMechanics").playerPillVars(game, "frost")
        if vars then
            e.value, e.max = vars.value, vars.max
        end
    end

    for _, joker in ipairs((game and game.jokerSlots) or {}) do
        for _, eff in ipairs(joker.effects or {}) do
            local pill = JOKER_DERIVED[eff.type]
            if pill then
                local e = entry(pill)
                e.stacks = e.stacks + (eff.value or 0)
            end
        end
    end

    for _, e in ipairs(order) do
        if HAS_PERMANENT_DESC[e.name] and not e.timed then
            e.variant = "permanent"
        end
        if e.name == "retain_armor" then
            e.showStacks = false
            e.stacks = 1
        end
        if e.duration <= 0 then e.duration = 1 end
    end

    table.sort(order, function(a, b)
        local ia = ORDER_INDEX[a.name] or (#ORDER + 1)
        local ib = ORDER_INDEX[b.name] or (#ORDER + 1)
        if ia ~= ib then return ia < ib end
        return a.name < b.name
    end)

    return order
end

function PlayerBuffPills.getBandTop(panelY)
    return math.floor(panelY - PlayerBuffPills.BAND_GAP - PlayerBuffPills.BAND_HEIGHT)
end

local function availableWidth(panelX)
    return math.max(120, love.graphics.getWidth() * 0.5 - panelX)
end

function PlayerBuffPills.getPillSize(count, panelX)
    return StatusPill.fitSize(count, availableWidth(panelX), BADGE_SIZE, BADGE_SPACING)
end

function PlayerBuffPills:draw(player, panelX, panelY, panelW, game)
    if not player then return end
    local buffs = PlayerBuffPills.collect(player, game)
    if #buffs == 0 then return end

    local startX = math.floor(panelX)
    local size = PlayerBuffPills.getPillSize(#buffs, startX)
    local y = PlayerBuffPills.getBandTop(panelY) + (PlayerBuffPills.BAND_HEIGHT - size)

    StatusPill.drawRow(buffs, startX, y, {
        size = size,
        spacing = BADGE_SPACING,
        animTime = self.animTime,
        pulseHalo = true,
        showStacksAlways = true,
    })
    for i, b in ipairs(buffs) do
        if b.name == "focus" then
            require("src.systems.Tutorial").anchor("buff_focus",
                startX + (i - 1) * (size + BADGE_SPACING), y, size, size)
        end
    end
end

return PlayerBuffPills
