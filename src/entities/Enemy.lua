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
    instance.attackPattern = "normal"
    -- statusEffects: lista de debuffs { name, duration, stacks? }
    -- Semantica: duration e em TURNOS (nao segundos). O decremento acontece
    -- em onTurnEnd (apos turno do inimigo), nao em update(dt).
    instance.statusEffects = {}
    return instance
end

function Enemy:takeDamage(damage)
    -- "vulnerable": dano recebido +50%. Aplica antes de armor.
    if self:hasStatus("vulnerable") then
        damage = math.floor(damage * 1.5)
    end
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    self.health = math.max(0, self.health - effectiveDamage)

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

-- Alias para consistência com Player:isAlive()
function Enemy:isAlive()
    return self.health > 0
end

function Enemy:getHealthPercentage()
    return self.health / self.maxHealth
end

function Enemy:update(dt)
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end
    -- NOTA: decremento de duracao de statusEffects nao e mais feito aqui (era em dt,
    -- o que fazia poison sumir em segundos). Agora e por turno via onTurnEnd.
end

function Enemy:canAttack()
    return self.attackCooldown <= 0
end

function Enemy:performAttack()
    if self:canAttack() then
        self.attackCooldown = 1.0
        local dmg = self.damage
        -- "weak": dano infligido -25%
        if self:hasStatus("weak") then
            dmg = math.floor(dmg * 0.75)
        end
        return dmg
    end
    return 0
end

function Enemy:addStatusEffect(effect)
    -- Se debuff ja existe, stackeia duration/stacks.
    for _, e in ipairs(self.statusEffects) do
        if e.name == effect.name then
            e.duration = (e.duration or 0) + (effect.duration or 1)
            e.stacks = (e.stacks or 1) + (effect.stacks or 1)
            return
        end
    end
    table.insert(self.statusEffects, {
        name = effect.name,
        duration = effect.duration or 1,
        stacks = effect.stacks or 1,
    })
end

function Enemy:hasStatus(name)
    for _, e in ipairs(self.statusEffects) do
        if e.name == name and e.duration > 0 then return true end
    end
    return false
end

function Enemy:getStatusStacks(name)
    for _, e in ipairs(self.statusEffects) do
        if e.name == name then return e.stacks or 1 end
    end
    return 0
end

-- Chamado pelo Game no final do turno do inimigo.
-- Processa DoT (poison), decrementa duration, limpa expirados.
-- Retorna dano de poison infligido (para UI/logs).
function Enemy:onTurnEnd()
    local poisonDmg = 0
    for _, e in ipairs(self.statusEffects) do
        if e.name == "poison" and e.duration > 0 then
            poisonDmg = poisonDmg + (e.stacks or 1)
        end
    end
    if poisonDmg > 0 then
        -- takeDamage direto, bypass vulnerable multiplier (poison e DoT fixo)
        local eff = math.max(0, poisonDmg - self.armor)
        self.armor = math.max(0, self.armor - poisonDmg)
        self.health = math.max(0, self.health - eff)
    end

    -- Decrementa duration e limpa
    for i = #self.statusEffects, 1, -1 do
        local e = self.statusEffects[i]
        e.duration = e.duration - 1
        if e.duration <= 0 then
            table.remove(self.statusEffects, i)
        end
    end

    return poisonDmg
end

return Enemy
