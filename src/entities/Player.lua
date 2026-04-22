local Config = require("src.core.Config")

local Player = {}
Player.__index = Player

-- Slots de orb (Fase 2): orbs sao stackados por cartas de channel.
-- Orb = { type="lightning"|"ice"|"dark"|"fire"|"holy", value=N }
-- Ao evocar, aplica efeito e remove (FIFO: evoca o mais antigo).
local DEFAULT_ORB_SLOTS = 3

function Player:new()
    local instance = setmetatable({}, Player)
    instance.maxHealth = Config.Game.PLAYER_MAX_HEALTH
    instance.health = instance.maxHealth
    instance.armor = 0
    instance.mana = Config.Game.PLAYER_MAX_MANA
    instance.maxMana = Config.Game.PLAYER_MAX_MANA
    instance.baseMaxMana = Config.Game.PLAYER_MAX_MANA
    instance.maxArmor = Config.Game.PLAYER_MAX_ARMOR

    -- Estatisticas transientes (resetadas por batalha em resetTransientStats).
    -- Strength = bonus aditivo a todo ataque; Dexterity = bonus aditivo a toda defesa.
    -- Acumulam durante a batalha via cartas tipo "gain_strength".
    instance.strength = 0
    instance.dexterity = 0

    -- Slots de orb para arquetipo Canalizador.
    instance.orbs = {}
    instance.orbSlots = DEFAULT_ORB_SLOTS

    -- Buffs genericos (nome + duracao em turnos). Diferente de orbs/strength,
    -- permitem efeitos narrativos (ex: "focus", "concentration") e expiram por turno.
    instance.buffs = {}

    return instance
end

function Player:takeDamage(damage)
    -- Debuff "vulnerable" do jogador amplificaria dano recebido (futuro).
    -- Por ora: armor absorve, resto vai pra HP.
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

-- ===== Fase 2: strength/dexterity/orbs/buffs =====

function Player:gainStrength(n)
    self.strength = self.strength + (n or 0)
end

function Player:gainDexterity(n)
    self.dexterity = self.dexterity + (n or 0)
end

-- Adiciona um orb ao fim da fila. Se cheio, descarta o mais antigo (e retorna-o
-- pro caller aplicar efeito "overflow evoke" no futuro, por ora ignoramos).
function Player:addOrb(orb)
    if not orb or not orb.type then return nil end
    local overflow = nil
    if #self.orbs >= self.orbSlots then
        overflow = table.remove(self.orbs, 1)
    end
    table.insert(self.orbs, orb)
    return overflow
end

-- Remove e retorna o orb mais antigo (FIFO). Caller aplica o efeito do orb.
function Player:popOldestOrb()
    if #self.orbs == 0 then return nil end
    return table.remove(self.orbs, 1)
end

-- Conta orbs por tipo (util para jokers/combos que olham orbs ativos).
function Player:countOrbsByType(orbType)
    local n = 0
    for _, o in ipairs(self.orbs) do
        if o.type == orbType then n = n + 1 end
    end
    return n
end

-- Adiciona/stack um buff nomeado. Se ja existe, soma duracao e stacks.
function Player:addBuff(name, duration, stacks)
    duration = duration or 1
    stacks = stacks or 1
    for _, b in ipairs(self.buffs) do
        if b.name == name then
            b.duration = b.duration + duration
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

-- Chamado no inicio do turno do jogador. Decrementa duracao de buffs e
-- remove expirados. Efeitos continuos ja foram aplicados (strength e stat, nao buff).
function Player:onTurnStart()
    for i = #self.buffs, 1, -1 do
        local b = self.buffs[i]
        b.duration = b.duration - 1
        if b.duration <= 0 then
            table.remove(self.buffs, i)
        end
    end
end

-- Reseta stats transientes (fim de batalha). Strength/dexterity/orbs/buffs sao
-- per-battle por default. Coisas permanentes (maxHealth, maxMana base) ficam.
function Player:resetTransientStats()
    self.strength = 0
    self.dexterity = 0
    self.orbs = {}
    self.buffs = {}
    self.armor = 0
end

return Player
