local Config = require("src.core.Config")
local ValueEasing = require("src.ui.ValueEasing")
local EnemyKits = require("src.data.enemies")
local Rng = require("src.systems.Rng")
local IntentVisibility = require("src.systems.IntentVisibility")

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
    -- statusEffects: lista de debuffs { name, duration, stacks? }
    -- Semantica: duration e em TURNOS (nao segundos). O decremento acontece
    -- em onTurnEnd (apos turno do inimigo), nao em update(dt).
    instance.statusEffects = {}
    -- Valores eased pra display suave de HP/armor (ValueEasing.tick)
    instance.disp = {}
    -- F1 gameplay-overhaul: o inimigo TELEGRAFA a ação do próximo turno.
    -- O kit (src/data/enemies.lua) decide QUAIS golpes ele tem; sem kit, o
    -- "generic" reproduz os quatro intents de antes (testes, modo clássico).
    instance:setKit(kitId or "generic")
    return instance
end

-- ===== Kit de golpes (Out/2026, src/data/enemies.lua) =====
-- Antes havia UMA tabela de intents dividida pelas 21 criaturas. Agora cada
-- criatura tem o seu kit: golpes nomeados, multi-golpe, debuffs no jogador,
-- carga telegrafada, invocação, fases. Trocar o kit zera o histórico de
-- golpes e rola o intent de novo (é o "nascimento" da criatura).
--
-- O hpMul/dmgMul do kit NÃO mora aqui: quem escala vida/dano é o
-- EnemyRoster.spawn, que sabe que está criando um inimigo novo (setKit pode
-- ser chamado em inimigo de teste já montado).
function Enemy:setKit(kitId)
    local kit = EnemyKits.KITS[kitId]
    if not kit then
        -- Fallback silencioso é proibido (CLAUDE.md): avisa e usa o legado.
        print("[Enemy] kit desconhecido '" .. tostring(kitId) .. "' — usando 'generic'")
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
        -- Armadura do inimigo escala com o dano dele: o teto fixo de 20 virava
        -- "nada" no ato 6 (golpe do jogador passa de 100).
        self.maxArmor = math.max(20, math.floor(self.damage * 2.5))
    end
    local passive = kit.passive
    if passive and passive.regenPct then
        local n = math.max(1, math.floor(self.maxHealth * passive.regenPct))
        self:addStatusEffect({ name = "regen", stacks = n, duration = 999 })
    end
    self:rollIntent()
end

-- Golpes ativos agora (kit base ou a fase corrente).
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

-- Quantas vezes seguidas o golpe `id` acabou de sair.
function Enemy:_streak(id)
    local n = 0
    for i = #self._moveHistory, 1, -1 do
        if self._moveHistory[i] ~= id then break end
        n = n + 1
    end
    return n
end

-- Escolhe o PRÓXIMO golpe. Ordem de precedência:
--   1. golpe forçado (carga -> golpe carregado)
--   2. abertura da fase recém-aberta / abertura do kit (1º turno)
--   3. golpe de cadência fixa (`every`)
--   4. sorteio ponderado (stream "enemy"), respeitando minTurn, maxRow e a
--      PRESSÃO GARANTIDA: nunca dois turnos seguidos sem dano (senão o
--      inimigo "stalla" e devolve o problema que o F1 matou).
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
        -- Restrições demais (kit pequeno): relaxa tudo menos o peso.
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

-- Lista normalizada de debuffs do golpe (aceita um só ou lista).
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

-- CONGELA o golpe no momento do anúncio (auditoria Jul/2026, anomalia
-- "escudo furado"): Fúria/buff mutavam self.damage ENTRE o telegraph e a
-- execução — o golpe batia mais forte que o número que o jogador viu. Todo
-- número do intent (dano por golpe, golpes, bloqueio, cura, força) é fixado
-- AQUI; buffs rolados depois só valem no PRÓXIMO intent. Weak do inimigo
-- continua por cima (só reduz).
--
-- `player` (opcional) congela a Vulnerabilidade do jogador junto: o golpe só
-- é ampliado se o jogador JÁ estava vulnerável no anúncio (e ainda estiver
-- na execução) — o número no HUD nunca é menor que o golpe.
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
        charge = m.next and true or nil,
        debuffs = debuffList(m),
        vuln = (player and player.hasDebuff and player:hasDebuff("vulnerable")) or nil,
    }
    self.intent = intent
    self.nextIntent = intent.kind
    self.nextIntentDamage = D
    -- NÉVOA (Out/2026): quanto deste anúncio o HUD pode mostrar. Decidido
    -- AQUI, uma vez por intent, e nunca mais mexido até o próximo anúncio —
    -- o número congelado continua sendo o que acontece (intentHitDamage não
    -- olha isto). Ver src/systems/IntentVisibility.lua.
    self:refreshIntentVisibility()
    return self.nextIntent
end

-- ===== Visibilidade do intent (névoa do bioma / véu / revelação) =====
-- Véu declarado no kit (ou na fase corrente): { level, chance }.
function Enemy:veilSpec()
    local ph = (self._phaseIdx or 0) > 0 and self.kit and self.kit.phases
        and self.kit.phases[self._phaseIdx]
    if ph and ph.veil then return ph.veil end
    return self.kit and self.kit.veil or nil
end

-- (Re)resolve a visibilidade do intent CORRENTE. Chamado no anúncio e por
-- RunModifiers.decorateEnemy (o 1º golpe rola dentro do setKit, antes de o
-- inimigo saber em que bioma nasceu).
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

-- Revela o intent de agora e os `turns - 1` anúncios seguintes (carta de
-- Revelar). `turns` nil/1 = só o corrente.
function Enemy:revealIntent(turns)
    turns = turns or 1
    self.intentVisibility = "full"
    self.intentVeilCause = "reveal"
    self._revealTurns = math.max(self._revealTurns or 0, turns - 1)
end

-- Revela só os PRÓXIMOS `turns` anúncios (pulso do orbe de Raio: acontece no
-- fim do turno do jogador, quando o intent corrente já vai ser executado).
function Enemy:revealNextIntent(turns)
    self._revealTurns = math.max(self._revealTurns or 0, turns or 1)
end

-- O intent como o JOGADOR tem direito de ver — a única leitura que piloto e
-- UI podem fazer quando a névoa está fechada. Nunca inclui número escondido:
--   full       → o próprio intent congelado (mesma tabela de getIntent)
--   type_only  → kind, pierce, debuffs (nomes) e flags; números = nil
--   hidden     → { kind = "unknown" }
-- `visibility` vem sempre preenchido.
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
        pierce = it.pierce, charge = it.charge }
    if it.debuffs then
        known.debuffs = {}
        for i, d in ipairs(it.debuffs) do known.debuffs[i] = { name = d.name } end
    end
    return known
end

-- Dano total que o jogador PODE saber que vem: número só com visibilidade
-- cheia; nil quando a névoa esconde (o piloto estima por
-- expectedDamagePerTurn, como um jogador faria).
function Enemy:getKnownIncomingDamage(player)
    if self:getIntentVisibility() ~= "full" then return nil end
    return self:getIncomingDamage(player)
end

-- Anuncia um golpe ESPECÍFICO do kit (testes e ferramentas de captura).
-- Passa pelo mesmo congelamento do rollIntent.
function Enemy:forceIntent(moveId, player)
    self._forcedNext = moveId
    return self:rollIntent(player)
end

-- Intent corrente. Se alguém sobrescreveu nextIntent/nextIntentDamage por
-- fora (testes antigos montam o cenário assim), sintetiza o golpe legado
-- correspondente — o contrato antigo (attack/strong ×1.6/defend/buff +2)
-- continua valendo pra quem escreve só esses dois campos.
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

-- Dano de UM golpe do intent, como vai acontecer (e como o HUD mostra):
-- weak do inimigo reduz; vulnerável do jogador amplia só se congelado.
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

-- Dano TOTAL previsto do intent (todos os golpes) — o que o piloto e
-- qualquer preview devem ler. Não desconta Bloqueio.
function Enemy:getIncomingDamage(player)
    local it = self:getIntent()
    return self:intentHitDamage(player) * (it.hits or 0)
end

-- Dano MÉDIO por turno do kit ativo (média ponderada dos golpes sorteáveis,
-- golpes × multiplicador × dano atual). Só pra estimar o FUTURO (piloto de
-- balanceamento); o turno corrente usa o intent congelado.
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

-- Valor de preview do intent pro HUD: (kind, número, intent).
--   golpe com dano       → dano POR GOLPE (weak/vulnerável aplicados)
--   defend               → armor que vai ganhar
--   buff                 → +dano permanente
--   heal                 → cura
--   debuff/charge/summon → 0 (o HUD desenha ícone, sem número)
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

-- Armor do intent defend: proporcional ao dano (inimigo forte defende forte).
function Enemy:getDefendAmount()
    return math.min(self.maxArmor, math.max(6, math.floor(self.damage * 0.8)))
end

-- ===== Execução do intent (chamada pelo Game, cada parte no seu beat) =====
function Enemy:healSelf(n)
    if not n or n <= 0 or self.health <= 0 then return 0 end
    local before = self.health
    self.health = math.min(self.maxHealth, self.health + n)
    return self.health - before
end

function Enemy:gainStrength(n)
    if not n or n <= 0 then return end
    self.baseDamage = self.baseDamage + n
    self.damage = self.damage + n
end

-- Regeneração passiva (status `regen`): cura no fim do turno do inimigo.
function Enemy:tickRegen()
    if not self:hasStatus("regen") or self.health <= 0 then return 0 end
    return self:healSelf(self:getStatusStacks("regen"))
end

-- FASES (Rainha do Eclipse): cruzar a fração de vida troca o kit e sobe o
-- dano. Mesmo contrato do ENFURECIDO: a entidade MARCA (`_pendingPhase`), o
-- Game ENCENA (Game:_announcePhaseIfPending). O intent já anunciado NÃO muda.
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
    -- Mesmo ponto único de queda de vida: a troca de FASE também é marcada
    -- aqui (dano direto e DoT passam por este funil).
    self:_checkPhase()
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
--
-- DoT IGNORA o Bloqueio (Out/2026, padrão StS): o tick cai no fim do turno do
-- inimigo, logo depois de ele DEFENDER — com a armadura absorvendo, todo turno
-- de defesa engolia o veneno inteiro e era o que mais travava o ladino no fim
-- do jogo (mesma regra do DoT no jogador, Player:tickDebuffDots).
function Enemy:_applyDot(dmg)
    if not dmg or dmg <= 0 then return 0 end
    local wasAlive = self.health > 0
    self.health = math.max(0, self.health - dmg)
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
    -- Em sequencia, nao somados: cada DoT tem sua propria travessia do limiar
    -- de morte.
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
