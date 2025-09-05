local Config = require("src.core.Config")

local Enemy = {}
Enemy.__index = Enemy

function Enemy:new(health, damage)
    local instance = setmetatable({}, Enemy)
    instance.maxHealth = health
    instance.health = health
    instance.damage = damage
    instance.baseDamage = damage
    instance.armor = 0
    instance.maxArmor = 20
    instance.attackCooldown = 0
    instance.attackPattern = "normal" -- normal, aggressive, defensive
    instance.statusEffects = {}
    return instance
end

function Enemy:takeDamage(damage)
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    self.health = math.max(0, self.health - effectiveDamage)
    
    -- Inimigo fica mais agressivo quando está com pouca vida
    if self.health < self.maxHealth * 0.3 then
        self.attackPattern = "aggressive"
        self.damage = self.baseDamage * 1.5
    end
end

function Enemy:addArmor(value)
    self.armor = math.min(self.maxArmor, self.armor + value)
end

function Enemy:isDefeated()
    return self.health <= 0
end

function Enemy:getHealthPercentage()
    return self.health / self.maxHealth
end

function Enemy:update(dt)
    -- Atualiza cooldown de ataque
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end
    
    -- Atualiza efeitos de status
    for i = #self.statusEffects, 1, -1 do
        local effect = self.statusEffects[i]
        effect.duration = effect.duration - dt
        
        if effect.duration <= 0 then
            table.remove(self.statusEffects, i)
        end
    end
end

function Enemy:canAttack()
    return self.attackCooldown <= 0
end

function Enemy:performAttack()
    if self:canAttack() then
        self.attackCooldown = 1.0 -- 1 segundo de cooldown
        return self.damage
    end
    return 0
end

function Enemy:addStatusEffect(effect)
    table.insert(self.statusEffects, effect)
end

return Enemy
