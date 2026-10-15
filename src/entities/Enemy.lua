local Debug = require("src.core.Debug")
local ValueEasing = require("src.ui.ValueEasing")
local EnemyKits = require("src.data.enemies")
local Rng = require("src.systems.Rng")
local IntentVisibility = require("src.systems.IntentVisibility")
local BossMechanics = require("src.systems.BossMechanics")

local Enemy = {}
Enemy.__index = Enemy

function Enemy:new(health, damage, kitId)
    local instance = setmetatable({}, Enemy)
    instance.maxHealth = health
    instance.health = health
    instance.damage = damage
    instance.baseDamage = damage
    instance.armor = 0
    instance.maxArmor = 20
    instance.attackCooldown = 0
    instance.attackPattern = "normal"
    instance.statusEffects = {}
    instance.disp = {}
    instance:setKit(kitId or "generic")
    return instance
end

function Enemy:setKit(kitId)
    local kit = EnemyKits.KITS[kitId]
    if not kit then
        Debug.warn("[Enemy] kit desconhecido '" .. tostring(kitId) .. "' — usando 'generic'")
        kitId, kit = "generic", EnemyKits.KITS.generic
    end
    self.kitId = kitId
    self.kit = kit
    self._phaseIdx = 0
    self._phaseOpener = nil
    self._moveHistory = {}
    self._rollIndex = 0
    self._forcedNext = nil
    self._pendingPhase = nil
    self._revealTurns = 0
    if kitId ~= "generic" then
        self.maxArmor = math.max(20, math.floor(self.damage * 2.5))
    end
    local passive = kit.passive
    if passive and passive.regenPct then
        local n = math.max(1, math.floor(self.maxHealth * passive.regenPct))
        self:addStatusEffect({ name = "regen", stacks = n, duration = 999 })
    end
    BossMechanics.onSpawn(self)
    self:rollIntent()
end

function Enemy:_moves()
    local ph = (self._phaseIdx or 0) > 0 and self.kit.phases
        and self.kit.phases[self._phaseIdx]
    return (ph and ph.moves) or self.kit.moves
end

function Enemy:_findMove(id)
    for _, m in ipairs(self:_moves()) do
        if m.id == id then return m end
    end
    for _, m in ipairs(self.kit.moves) do
        if m.id == id then return m end
    end
    for _, ph in ipairs(self.kit.phases or {}) do
        for _, m in ipairs(ph.moves) do
            if m.id == id then return m end
        end
    end
    return nil
end

local function dealsDamage(m)
    return (m.mult or 0) > 0
end

function Enemy:_streak(id)
    local n = 0
    for i = #self._moveHistory, 1, -1 do
        if self._moveHistory[i] ~= id then break end
        n = n + 1
    end
    return n
end

function Enemy:_chooseMove()
    local t = self._rollIndex
    if self._forcedNext then
        local m = self:_findMove(self._forcedNext)
        self._forcedNext = nil
        if m then return m end
    end
    if self._phaseOpener then
        local m = self:_findMove(self._phaseOpener)
        self._phaseOpener = nil
        if m then return m end
    end
    local mechMove = BossMechanics.forcedMove(self)
    if mechMove then
        local m = self:_findMove(mechMove)
        if m then return m end
    end
    if t == 1 and self.kit.opener then
        local m = self:_findMove(self.kit.opener)
        if m then return m end
    end
    local moves = self:_moves()
    for _, m in ipairs(moves) do
        if m.every and t > 1 and t % m.every == 0 then return m end
    end

    local last = self._moveHistory[#self._moveHistory]
    local lastMove = last and self:_findMove(last)
    local needDamage = lastMove and not dealsDamage(lastMove)
    local pool, total = {}, 0
    for _, m in ipairs(moves) do
        local w = m.weight or 0
        local ok = w > 0
            and (not m.minTurn or t >= m.minTurn)
            and self:_streak(m.id) < (m.maxRow or 2)
            and (not needDamage or dealsDamage(m))
        if ok then
            pool[#pool + 1] = m
            total = total + w
        end
    end
    if #pool == 0 then
        for _, m in ipairs(moves) do
            if (m.weight or 0) > 0 then
                pool[#pool + 1] = m
                total = total + m.weight
            end
        end
    end
    if #pool == 0 then return moves[1] end
    local r = Rng.get():random("enemy") * total
    for _, m in ipairs(pool) do
        r = r - m.weight
        if r <= 0 then return m end
    end
    return pool[#pool]
end

local function debuffList(m)
    local d = m.debuff
    if not d then return nil end
    if d.name then d = { d } end
    local out = {}
    for i, x in ipairs(d) do
        out[i] = { name = x.name, duration = x.duration or 1, stacks = x.stacks or 1 }
    end
    return out
end

function Enemy:rollIntent(player)
    self._rollIndex = (self._rollIndex or 0) + 1
    local m = self:_chooseMove()
    self._moveHistory[#self._moveHistory + 1] = m.id
    if m.next then self._forcedNext = m.next end

    local D = self.damage
    local hits = m.hits or 1
    if m.swarm then
        hits = math.min(8, hits + self:getStatusStacks("swarm"))
    end
    local strength = m.strengthFlat
    if m.strength then
        strength = math.max(2, math.floor((self.baseDamage or D) * m.strength))
    end
    local hasDmg = (m.mult or 0) > 0
    local intent = {
        id = m.id,
        kind = m.kind or "attack",
        raw = D,
        perHit = hasDmg and math.max(1, math.floor(D * m.mult)) or 0,
        hits = hasDmg and hits or 0,
        pierce = m.pierce or nil,
        armor = m.armor and math.floor(self:getDefendAmount() * m.armor) or 0,
        strength = strength or 0,
        heal = m.heal and math.max(1, math.floor(self.maxHealth * m.heal)) or 0,
        summon = m.summon or 0,
        swarm = m.swarm or nil,
        charge = m.next and true or nil,
        debuffs = debuffList(m),
        vuln = (player and player.hasDebuff and player:hasDebuff("vulnerable")) or nil,
    }
    BossMechanics.shapeIntent(self, intent, m)
    self.intent = intent
    self.nextIntent = intent.kind
    self.nextIntentDamage = D
    self:refreshIntentVisibility()
    return self.nextIntent
end

function Enemy:veilSpec()
    local ph = (self._phaseIdx or 0) > 0 and self.kit and self.kit.phases
        and self.kit.phases[self._phaseIdx]
    if ph and ph.veil then return ph.veil end
    return self.kit and self.kit.veil or nil
end

function Enemy:refreshIntentVisibility()
    local level, cause = IntentVisibility.resolve(self)
    self.intentVisibility = level
    self.intentVeilCause = cause
    IntentVisibility.noteActive(self)
    return level
end

function Enemy:getIntentVisibility()
    return self.intentVisibility or "full"
end

function Enemy:revealIntent(turns)
    turns = turns or 1
    self.intentVisibility = "full"
    self.intentVeilCause = "reveal"
    self._revealTurns = math.max(self._revealTurns or 0, turns - 1)
end

function Enemy:revealNextIntent(turns)
    self._revealTurns = math.max(self._revealTurns or 0, turns or 1)
end

function Enemy:getKnownIntent(player)
    local it = self:getIntent()
    local lvl = self:getIntentVisibility()
    if lvl == "full" then
        local copy = {}
        for k, v in pairs(it) do copy[k] = v end
        copy.visibility = "full"
        return copy
    end
    if lvl == "hidden" then
        return { kind = "unknown", id = "unknown", visibility = "hidden", hidden = true }
    end
    local known = { id = it.id, kind = it.kind, visibility = "type_only", hidden = true,
        pierce = it.pierce, charge = it.charge, frost = it.frost }
    if it.debuffs then
        known.debuffs = {}
        for i, d in ipairs(it.debuffs) do known.debuffs[i] = { name = d.name } end
    end
    return known
end

function Enemy:getKnownIncomingDamage(player)
    if self:getIntentVisibility() ~= "full" then return nil end
    return self:getIncomingDamage(player)
end

function Enemy:forceIntent(moveId, player)
    self._forcedNext = moveId
    return self:rollIntent(player)
end

function Enemy:getIntent()
    local it = self.intent
    local kind = self.nextIntent or "attack"
    local raw = self.nextIntentDamage or self.damage
    if it and it.kind == kind and it.raw == raw then return it end
    local synth = { id = kind, kind = kind, raw = raw, perHit = 0, hits = 0,
        armor = 0, strength = 0, heal = 0, summon = 0 }
    if kind == "attack" then
        synth.perHit, synth.hits = raw, 1
    elseif kind == "strong" then
        synth.perHit, synth.hits = math.floor(raw * 1.6), 1
    elseif kind == "defend" then
        synth.armor = self:getDefendAmount()
    elseif kind == "buff" then
        synth.strength = 2
    end
    self.intent = synth
    return synth
end

function Enemy:intentHitDamage(player)
    local it = self:getIntent()
    local dmg = it.perHit or 0
    if dmg <= 0 then return 0 end
    if self:hasStatus("weak") then dmg = math.floor(dmg * 0.75) end
    if it.vuln and player and player.hasDebuff and player:hasDebuff("vulnerable") then
        dmg = math.floor(dmg * 1.5)
    end
    return dmg
end

function Enemy:getIncomingDamage(player)
    local it = self:getIntent()
    return self:intentHitDamage(player) * (it.hits or 0)
end

function Enemy:expectedDamagePerTurn()
    local total, sum = 0, 0
    for _, m in ipairs(self:_moves()) do
        local w = m.weight or 0
        if w > 0 then
            total = total + w
            sum = sum + w * (m.mult or 0) * (m.hits or 1)
        end
    end
    if total <= 0 then return self.damage or 0 end
    return (self.damage or 0) * sum / total
end

function Enemy:getIntentPreview(player)
    local it = self:getIntent()
    local kind = it.kind
    if (it.perHit or 0) > 0 then
        return kind, self:intentHitDamage(player), it
    elseif kind == "defend" then
        return kind, it.armor, it
    elseif kind == "buff" then
        return kind, it.strength, it
    elseif kind == "heal" then
        return kind, it.heal, it
    end
    return kind, 0, it
end

function Enemy:getDefendAmount()
    return math.min(self.maxArmor, math.max(6, math.floor(self.damage * 0.8)))
end

function Enemy:healSelf(n)
    if not n or n <= 0 or self.health <= 0 then return 0 end
    local before = self.health
    self.health = math.min(self.maxHealth, self.health + n)
    self.healedTotal = (self.healedTotal or 0) + (self.health - before)
    return self.health - before
end

function Enemy:gainStrength(n)
    if not n or n <= 0 then return end
    self.baseDamage = self.baseDamage + n
    self.damage = self.damage + n
end

function Enemy:tickRegen()
    if not self:hasStatus("regen") or self.health <= 0 then return 0 end
    return self:healSelf(self:getStatusStacks("regen"))
end

function Enemy:_checkPhase()
    local phases = self.kit and self.kit.phases
    if not phases or self.health <= 0 then return end
    local nextIdx = (self._phaseIdx or 0) + 1
    local ph = phases[nextIdx]
    if ph and self.health <= self.maxHealth * (ph.at or 0.5) then
        self._phaseIdx = nextIdx
        self._pendingPhase = ph
        self._phaseOpener = ph.opener
        self._moveHistory = {}
        local mul = ph.dmgMul or 1
        self.baseDamage = math.floor(self.baseDamage * mul)
        self.damage = math.floor(self.damage * mul)
        self:addStatusEffect({ name = ph.id or "eclipse", stacks = 1, duration = 999 })
    end
end

function Enemy:_markDeathIfCrossed(wasAlive)
    if wasAlive and self.health <= 0 then
        self._pendingDeath = true
    end
    self:_checkPhase()
end

function Enemy:takeDamage(damage)
    local wasAlive = self.health > 0
    if self:hasStatus("vulnerable") then
        damage = math.floor(damage * 1.5)
    end
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    local hpBefore = self.health
    self.health = math.max(0, self.health - effectiveDamage)
    BossMechanics.onDamaged(self, hpBefore - self.health, "hit")
    self:_markDeathIfCrossed(wasAlive)

    if self.health < self.maxHealth * 0.3 then
        local wasEnraged = (self.attackPattern == "aggressive")
        self.attackPattern = "aggressive"
        self.damage = math.floor(self.baseDamage * 1.5)
        if not wasEnraged then
            self._pendingEnrage = true
            self:addStatusEffect({ name = "enraged", stacks = 1, duration = 999 })
        end
    end
end

function Enemy:addArmor(value)
    self.armor = math.min(self.maxArmor, self.armor + value)
end

function Enemy:isDefeated()
    return self.health <= 0
end

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
    self.disp = self.disp or {}
    ValueEasing.tick(self.disp, "health", self.health or 0, dt, 9)
    ValueEasing.tick(self.disp, "armor", self.armor or 0, dt, 12)
end

function Enemy:canAttack()
    return self.attackCooldown <= 0
end

function Enemy:performAttack()
    if self:canAttack() then
        self.attackCooldown = 1.0
        local dmg = self.nextIntentDamage or self.damage
        if self:hasStatus("weak") then
            dmg = math.floor(dmg * 0.75)
        end
        return dmg
    end
    return 0
end

Enemy.POISON_DECAY = true

local function decays(name)
    return name == "poison" and Enemy.POISON_DECAY
end

function Enemy:addStatusEffect(effect)
    for _, e in ipairs(self.statusEffects) do
        if e.name == effect.name then
            e.duration = (e.duration or 0) + (effect.duration or 1)
            e.stacks = (e.stacks or 1) + (effect.stacks or 1)
            if decays(e.name) then e.duration = e.stacks end
            return
        end
    end
    local e = {
        name = effect.name,
        duration = effect.duration or 1,
        stacks = effect.stacks or 1,
    }
    if decays(e.name) then e.duration = e.stacks end
    table.insert(self.statusEffects, e)
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

function Enemy:_applyDot(dmg)
    if not dmg or dmg <= 0 then return 0 end
    local wasAlive = self.health > 0
    local hpBefore = self.health
    self.health = math.max(0, self.health - dmg)
    BossMechanics.onDamaged(self, hpBefore - self.health, "dot")
    self:_markDeathIfCrossed(wasAlive)
    return dmg
end

function Enemy:onTurnEnd()
    local poisonDmg, burnDmg = 0, 0
    for _, e in ipairs(self.statusEffects) do
        if e.duration > 0 then
            if e.name == "poison" then
                poisonDmg = poisonDmg + (e.stacks or 1)
            elseif e.name == "burn" then
                burnDmg = burnDmg + (e.stacks or 1)
            end
        end
    end
    self:_applyDot(poisonDmg)
    self:_applyDot(burnDmg)

    for i = #self.statusEffects, 1, -1 do
        local e = self.statusEffects[i]
        if decays(e.name) then
            e.stacks = (e.stacks or 1) - 1
            e.duration = e.stacks
        else
            e.duration = e.duration - 1
        end
        if e.duration <= 0 then
            table.remove(self.statusEffects, i)
        end
    end

    return poisonDmg, burnDmg
end

return Enemy
