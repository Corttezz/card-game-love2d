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

    -- DEBUFFS que o INIMIGO aplica (Out/2026, src/data/enemies.lua):
    -- weak/frail/vulnerable/poison/burn. Lista separada de `buffs` porque o
    -- relógio é outro: buff decai no upkeep do jogador; debuff decai no FIM
    -- do turno do inimigo e PULA o turno em que foi aplicado (padrão StS
    -- "justApplied") — "Fraco 2" vale para os 2 próximos turnos do jogador.
    instance.debuffs = {}

    return instance
end

-- `pierce` = golpe que ATRAVESSA o Bloqueio (lança de gelo, raio rúnico).
-- A Vulnerabilidade do jogador já vem aplicada no dano pelo Enemy
-- (intentHitDamage) — aqui ela não entra de novo.
function Player:takeDamage(damage, pierce)
    if pierce then
        self.health = math.max(0, self.health - damage)
        return
    end
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    self.health = math.max(0, self.health - effectiveDamage)
end

-- ===== Debuffs do inimigo =====
-- DoT (poison/burn) soma pilhas E duração (mesma aritmética do Enemy);
-- weak/frail/vulnerable somam só duração.
local DOT_DEBUFF = { poison = true, burn = true }

function Player:addDebuff(name, duration, stacks)
    duration = duration or 1
    stacks = stacks or 1
    self.debuffs = self.debuffs or {}
    for _, d in ipairs(self.debuffs) do
        if d.name == name then
            d.duration = d.duration + duration
            if DOT_DEBUFF[name] then d.stacks = (d.stacks or 0) + stacks end
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

-- Fim do turno do INIMIGO: decrementa, exceto o que foi aplicado agora.
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

-- Veneno/queimadura no JOGADOR: perda de vida que ignora o Bloqueio, no
-- começo do turno dele. Devolve (veneno, queimadura) — dois números, nunca
-- somados (mesma regra do Enemy:onTurnEnd).
function Player:tickDebuffDots()
    local poison = self:getDebuffStacks("poison")
    local burn = self:getDebuffStacks("burn")
    if poison > 0 then self:loseHealth(poison) end
    if burn > 0 then self:loseHealth(burn) end
    return poison, burn
end

-- Fraco: os ATAQUES do jogador causam 25% menos.
function Player:applyWeakToAttack(dmg)
    if self:hasDebuff("weak") then return math.floor(dmg * 0.75) end
    return dmg
end

-- Frágil: o Bloqueio das DEFESAS do jogador rende 25% menos.
function Player:applyFrailToBlock(block)
    if self:hasDebuff("frail") then return math.floor(block * 0.75) end
    return block
end

function Player:addArmor(value)
    self.armor = math.min(self.maxArmor, self.armor + value)
end

-- Perda de HP DIRETA (ignora armor). Usada por custos auto-infligidos
-- (self_damage, damage_per_turn) — "pagar com sangue" não pode ser
-- absorvido pela armadura, senão o custo é fictício (auditoria F0).
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

-- Buffs cuja DURACAO nao acumula: stackear dois deles soma a intensidade mas
-- a janela continua sendo a mesma (o buff vale "ate o meu proximo turno").
-- "thorn" (Espinhos, Set/2026) e o caso: duas Barreiras de Fogo no mesmo turno
-- refletem mais, nao por mais turnos — somar duracao faria o reflexo sobreviver
-- ao turno seguinte, que e exatamente o contrario do contrato StS.
local NON_CUMULATIVE_DURATION = { thorn = true }

-- Adiciona/stack um buff nomeado. Se ja existe, soma duracao e stacks
-- (excecao: NON_CUMULATIVE_DURATION mantem a maior duracao).
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

-- Chamado no inicio do turno do jogador. Decrementa duracao de buffs e
-- remove expirados. Efeitos continuos ja foram aplicados (strength e stat, nao buff).
function Player:onTurnStart()
    -- F1 gameplay-overhaul: BLOQUEIO ZERA todo turno (StS). Defesa vira
    -- decisão por turno em vez de poupança — o "banco de armor 50" que
    -- imunizava o jogador morreu aqui. Jokers futuros podem setar
    -- retainArmor pra manter uma fração.
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

-- Reseta stats transientes (fim de batalha). Strength/dexterity/orbs/buffs sao
-- per-battle por default. Coisas permanentes (maxHealth, maxMana base) ficam.
function Player:resetTransientStats()
    self.strength = 0
    self.dexterity = 0
    self.orbs = {}
    self.buffs = {}
    self.debuffs = {}
    self.armor = 0
end

return Player
