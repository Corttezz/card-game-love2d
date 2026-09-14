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

-- MORRER E UM ACONTECIMENTO, NAO UM ESTADO QUE ALGUEM PERCEBE DEPOIS
-- (Set/2026, queixa do dono: "em alguns cenarios o mob nao esta tendo a
-- animacao de morrer, cair no chao").
--
-- A causa era a mesma do ENFURECIDO: so UM caminho de dano (o da carta de
-- ataque, em Game:processCardInCombat) sabia detectar a morte e disparar a
-- animacao. Magia, pulso/evocacao de orbe, veneno e reflexo de espinhos
-- levavam a vida a zero na aritmetica e ninguem avisava ninguem — a tela de
-- espolios abria por cima de um inimigo em pe.
--
-- Agora a VIRADA vivo->morto e marcada AQUI, no unico lugar por onde a vida
-- do inimigo pode cair, seja qual for a fonte. O Game consome `_pendingDeath`
-- (Game:announceDeathIfPending) e transforma em beat. Mesmo contrato do
-- `_pendingEnrage`: a entidade MARCA, o Game ENCENA.
function Enemy:_markDeathIfCrossed(wasAlive)
    if wasAlive and self.health <= 0 then
        self._pendingDeath = true
    end
end

function Enemy:takeDamage(damage)
    local wasAlive = self.health > 0
    -- "vulnerable": dano recebido +50%. Aplica antes de armor.
    if self:hasStatus("vulnerable") then
        damage = math.floor(damage * 1.5)
    end
    local effectiveDamage = math.max(0, damage - self.armor)
    self.armor = math.max(0, self.armor - damage)
    self.health = math.max(0, self.health - effectiveDamage)
    self:_markDeathIfCrossed(wasAlive)

    -- ENFURECIDO (Set/2026): abaixo de 30% de vida o inimigo passa a causar
    -- +50% de dano, PERMANENTE. Isso sempre existiu e era MUDO — acontecia em
    -- toda batalha, mudava a conta de dano que o jogador estava fazendo, e
    -- nada aparecia na tela. Agora o CRUZAMENTO do limiar e um acontecimento:
    --   * vira status REAL `enraged` (pill + tooltip no EnemyHud);
    --   * levanta `_pendingEnrage`, que o Game consome pra dar o INSTANTE
    --     proprio (beat bloqueante com rugido e numero).
    -- O nome e `enraged`, NAO `fury`: `fury` ja e o anti-stall do turno 8+
    -- (Game:enemyTurn), outra mecanica, com pill e tooltip proprios.
    -- O recalculo de `damage` continua acontecendo a CADA dano (e nao so na
    -- virada) de proposito: `baseDamage` cresce com a Furia, e recalcular
    -- mantem o x1.5 sobre a base atual — mexer nisso seria rebalancear.
    -- INVARIANTE PRESERVADA (CLAUDE.md 6): `nextIntentDamage` fica congelado
    -- no anuncio, entao o golpe JA telegrafado nao muda — a furia so vale do
    -- proximo intent em diante. Isso separa naturalmente "ele enfureceu" de
    -- "ele bate mais forte", que e exatamente o que ajuda a leitura.
    if self.health < self.maxHealth * 0.3 then
        local wasEnraged = (self.attackPattern == "aggressive")
        self.attackPattern = "aggressive"
        -- floor: sem ele o HUD (e o dano real) mostrava "30.5" (autoplay A2)
        self.damage = math.floor(self.baseDamage * 1.5)
        if not wasEnraged then
            self._pendingEnrage = true
            -- duration alta = permanente na pratica (onTurnEnd decrementa).
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

-- Aplica um DoT (dano por turno) com a aritmetica dos venenos: bypass do
-- takeDamage de proposito, porque DoT e dano FIXO e nao passa pelo
-- multiplicador de Vulneravel. A armadura absorve e e consumida.
-- `_markDeathIfCrossed` e obrigatorio: esta aritmetica crua nao passa pelo
-- takeDamage, e sem ele morrer de DoT volta a nao ter animacao de morte.
function Enemy:_applyDot(dmg)
    if not dmg or dmg <= 0 then return 0 end
    local wasAlive = self.health > 0
    local eff = math.max(0, dmg - self.armor)
    self.armor = math.max(0, self.armor - dmg)
    self.health = math.max(0, self.health - eff)
    self:_markDeathIfCrossed(wasAlive)
    return dmg
end

-- Chamado pelo Game no final do turno do inimigo.
-- Processa os DoTs (VENENO e QUEIMADURA), decrementa duration, limpa expirados.
-- Retorna (danoVeneno, danoQueimadura) — DOIS numeros porque sao DOIS status
-- diferentes: o veneno e do ladino, a queimadura e do fogo do mago, e somar os
-- dois num numero so seria a mesma confusao que criou o `burn` (Set/2026).
-- O 1o retorno continua sendo o veneno: chamadas antigas nao mudam.
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
    -- Em sequencia, nao somados: com armadura o total sai igual (ela e
    -- consumida), e assim cada DoT tem sua propria travessia do limiar de morte.
    self:_applyDot(poisonDmg)
    self:_applyDot(burnDmg)

    -- Decrementa duration e limpa
    for i = #self.statusEffects, 1, -1 do
        local e = self.statusEffects[i]
        e.duration = e.duration - 1
        if e.duration <= 0 then
            table.remove(self.statusEffects, i)
        end
    end

    return poisonDmg, burnDmg
end

return Enemy
