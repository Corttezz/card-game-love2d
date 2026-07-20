local Config = require("src.core.Config")
local ValueEasing = require("src.ui.ValueEasing")

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
    -- Valores eased pra display suave de HP/armor (ValueEasing.tick)
    instance.disp = {}
    -- F1 gameplay-overhaul: o inimigo TELEGRAFA a ação do próximo turno.
    instance:rollIntent()
    return instance
end

-- ===== Intents (F1 do gameplay-overhaul-v1) =====
-- O inimigo anuncia o que fará no próximo turno (nextIntent); o EnemyHud
-- desenha ícone + número. Cria "janelas": turno de defend/buff do inimigo é
-- a hora de burstar; ataque forte é a hora de defender.
local INTENTS = {
    { kind = "attack", weight = 50 },  -- dano normal
    { kind = "strong", weight = 16 },  -- dano ×1.6
    { kind = "defend", weight = 18 },  -- ganha armor
    { kind = "buff",   weight = 16 },  -- +2 dano permanente
}

function Enemy:rollIntent()
    -- Pressão garantida: nunca 2 turnos seguidos sem atacar (senão o
    -- inimigo "stalla" e devolve o problema que queremos matar).
    if self._lastIntentNonAttack then
        self.nextIntent = (math.random() < 0.30) and "strong" or "attack"
        self._lastIntentNonAttack = false
        self.nextIntentDamage = self.damage
        return self.nextIntent
    end
    local total = 0
    for _, it in ipairs(INTENTS) do total = total + it.weight end
    local r = math.random() * total
    for _, it in ipairs(INTENTS) do
        r = r - it.weight
        if r <= 0 then
            self.nextIntent = it.kind
            break
        end
    end
    self.nextIntent = self.nextIntent or "attack"
    self._lastIntentNonAttack =
        (self.nextIntent == "defend" or self.nextIntent == "buff")
    -- CONGELA o dano bruto no momento do anuncio (auditoria Jul/2026,
    -- anomalia "escudo furado"): Furia/BUFF mutavam self.damage ENTRE o
    -- telegraph e a execucao — o golpe batia mais forte que o numero que o
    -- jogador viu. Preview e performAttack leem este valor; buffs rolados
    -- depois so valem no PROXIMO intent. Weak continua por cima (so reduz).
    self.nextIntentDamage = self.damage
    return self.nextIntent
end

-- Valor de preview do intent pro HUD: (kind, número).
--   attack/strong → dano previsto (com weak aplicado)
--   defend        → armor que vai ganhar
--   buff          → +2 (dano permanente)
function Enemy:getIntentPreview()
    local kind = self.nextIntent or "attack"
    if kind == "defend" then
        return kind, self:getDefendAmount()
    elseif kind == "buff" then
        return kind, 2
    end
    local dmg = self.nextIntentDamage or self.damage
    if kind == "strong" then dmg = math.floor(dmg * 1.6) end
    if self:hasStatus("weak") then dmg = math.floor(dmg * 0.75) end
    return kind, dmg
end

-- Armor do intent defend: proporcional ao dano (inimigo forte defende forte).
function Enemy:getDefendAmount()
    return math.min(self.maxArmor, math.max(6, math.floor(self.damage * 0.8)))
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
        -- floor: sem ele o HUD (e o dano real) mostrava "30.5" (autoplay A2)
        self.damage = math.floor(self.baseDamage * 1.5)
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
    -- Ease HP/armor display pra "number ticker" suave quando dano chega.
    self.disp = self.disp or {}
    ValueEasing.tick(self.disp, "health", self.health or 0, dt, 9)
    ValueEasing.tick(self.disp, "armor", self.armor or 0, dt, 12)
    -- NOTA: decremento de duracao de statusEffects nao e mais feito aqui (era em dt,
    -- o que fazia poison sumir em segundos). Agora e por turno via onTurnEnd.
end

function Enemy:canAttack()
    return self.attackCooldown <= 0
end

function Enemy:performAttack()
    if self:canAttack() then
        self.attackCooldown = 1.0
        -- Executa o valor CONGELADO no anuncio do intent (nunca mais forte
        -- que o numero que o jogador viu no HUD).
        local dmg = self.nextIntentDamage or self.damage
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
