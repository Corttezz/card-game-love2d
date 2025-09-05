local Config = require("src.core.Config")

local Player = {}
Player.__index = Player

function Player:new()
    local instance = setmetatable({}, Player)
    instance.maxHealth = Config.Game.PLAYER_MAX_HEALTH -- Vida máxima
    instance.health = instance.maxHealth -- Vida atual
    instance.armor = 0 -- Armadura inicial
    instance.mana = Config.Game.PLAYER_MAX_MANA -- Mana inicial
    instance.maxMana = Config.Game.PLAYER_MAX_MANA -- Mana máxima
    instance.maxArmor = Config.Game.PLAYER_MAX_ARMOR -- Armadura máxima
    return instance
end

function Player:takeDamage(damage)
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    self.health = math.max(0, self.health - effectiveDamage)
end

function Player:addArmor(value)
    self.armor = math.min(self.maxArmor, self.armor + value)
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

function Player:spendMana(cost)
    if self.mana >= cost then
        self.mana = self.mana - cost
        return true -- Mana suficiente
    else
        return false -- Mana insuficiente
    end
end

function Player:getHealthPercentage()
    return self.health / self.maxHealth
end

function Player:getManaPercentage()
    return self.mana / self.maxMana
end

return Player
