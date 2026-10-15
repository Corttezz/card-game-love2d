local Config = require("src.core.Config")

local Player = {}
Player.__index = Player

local DEFAULT_ORB_SLOTS = 3

function Player.maxHealthFor(classId)
    local byClass = Config.Game.CLASS_MAX_HEALTH
    return (classId and byClass and byClass[classId]) or Config.Game.PLAYER_MAX_HEALTH
end

function Player:new(classId)
    local instance = setmetatable({}, Player)
    instance.maxHealth = Player.maxHealthFor(classId)
    instance.health = instance.maxHealth
    instance.armor = 0
    instance.mana = Config.Game.PLAYER_MAX_MANA
    instance.maxMana = Config.Game.PLAYER_MAX_MANA
    instance.baseMaxMana = Config.Game.PLAYER_MAX_MANA
    instance.maxArmor = Config.Game.PLAYER_MAX_ARMOR

    instance.strength = 0
    instance.dexterity = 0

    instance.orbs = {}
    instance.orbSlots = DEFAULT_ORB_SLOTS

    instance.buffs = {}

    instance.debuffs = {}

    return instance
end

function Player:takeDamage(damage, pierce)
    if pierce then
        self.health = math.max(0, self.health - damage)
        return
    end
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    self.health = math.max(0, self.health - effectiveDamage)
end

local DOT_DEBUFF = { poison = true, burn = true }

function Player:addDebuff(name, duration, stacks)
    duration = duration or 1
    stacks = stacks or 1
    self.debuffs = self.debuffs or {}
    for _, d in ipairs(self.debuffs) do
        if d.name == name then
            if DOT_DEBUFF[name] then
                d.stacks = (d.stacks or 0) + stacks
                d.duration = math.max(d.duration, duration)
            else
                d.duration = d.duration + duration
            end
            d.fresh = true
            return d
        end
    end
    local d = { name = name, duration = duration,
        stacks = DOT_DEBUFF[name] and stacks or 1, fresh = true }
    table.insert(self.debuffs, d)
    return d
end

function Player:hasDebuff(name)
    for _, d in ipairs(self.debuffs or {}) do
        if d.name == name and d.duration > 0 then return true end
    end
    return false
end

function Player:getDebuffStacks(name)
    for _, d in ipairs(self.debuffs or {}) do
        if d.name == name and d.duration > 0 then return d.stacks or 1 end
    end
    return 0
end

function Player:decayDebuffs()
    for i = #(self.debuffs or {}), 1, -1 do
        local d = self.debuffs[i]
        if d.fresh then
            d.fresh = nil
        else
            d.duration = d.duration - 1
            if d.duration <= 0 then table.remove(self.debuffs, i) end
        end
    end
end

function Player:tickDebuffDots()
    local poison = self:getDebuffStacks("poison")
    local burn = self:getDebuffStacks("burn")
    if poison > 0 then self:loseHealth(poison) end
    if burn > 0 then self:loseHealth(burn) end
    return poison, burn
end

function Player:applyWeakToAttack(dmg)
    if self:hasDebuff("weak") then return math.floor(dmg * 0.75) end
    return dmg
end

function Player:applyFrailToBlock(block)
    if self:hasDebuff("frail") then return math.floor(block * 0.75) end
    return block
end

function Player:addArmor(value)
    self.armor = math.min(self.maxArmor, self.armor + value)
end

function Player:loseHealth(value)
    self.health = math.max(0, self.health - value)
end

function Player:heal(value)
    self.health = math.min(self.maxHealth, self.health + value)
end

function Player:isAlive()
    return self.health > 0
end

function Player:restoreMana()
    self.mana = self.maxMana
end

function Player:resetMaxMana()
    self.maxMana = self.baseMaxMana
    if self.mana > self.maxMana then
        self.mana = self.maxMana
    end
end

function Player:spendMana(cost)
    if self.mana >= cost then
        self.mana = self.mana - cost
        return true
    else
        return false
    end
end

function Player:getHealthPercentage()
    return self.health / self.maxHealth
end

function Player:getManaPercentage()
    return self.mana / self.maxMana
end

function Player:gainStrength(n)
    self.strength = self.strength + (n or 0)
end

function Player:gainDexterity(n)
    self.dexterity = self.dexterity + (n or 0)
end

function Player:addOrb(orb)
    if not orb or not orb.type then return nil end
    local overflow = nil
    if #self.orbs >= self.orbSlots then
        overflow = table.remove(self.orbs, 1)
    end
    table.insert(self.orbs, orb)
    return overflow
end

function Player:popOldestOrb()
    if #self.orbs == 0 then return nil end
    return table.remove(self.orbs, 1)
end

function Player:countOrbsByType(orbType)
    local n = 0
    for _, o in ipairs(self.orbs) do
        if o.type == orbType then n = n + 1 end
    end
    return n
end

local NON_CUMULATIVE_DURATION = { thorn = true }

function Player:addBuff(name, duration, stacks)
    duration = duration or 1
    stacks = stacks or 1
    for _, b in ipairs(self.buffs) do
        if b.name == name then
            if NON_CUMULATIVE_DURATION[name] then
                b.duration = math.max(b.duration, duration)
            else
                b.duration = b.duration + duration
            end
            b.stacks = (b.stacks or 1) + stacks
            return
        end
    end
    table.insert(self.buffs, { name = name, duration = duration, stacks = stacks })
end

function Player:getBuffStacks(name)
    for _, b in ipairs(self.buffs) do
        if b.name == name then return b.stacks or 1 end
    end
    return 0
end

function Player:onTurnStart()
    if not self.retainArmor then
        self.armor = 0
    end
    for i = #self.buffs, 1, -1 do
        local b = self.buffs[i]
        b.duration = b.duration - 1
        if b.duration <= 0 then
            table.remove(self.buffs, i)
        end
    end
end

function Player:resetTransientStats()
    self.strength = 0
    self.dexterity = 0
    self.orbs = {}
    self.buffs = {}
    self.debuffs = {}
    self.armor = 0
end

return Player
