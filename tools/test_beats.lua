-- tools/test_beats.lua
-- TRAVA DO RITMO DO COMBATE (Set/2026).
--
-- POR QUE ESTE TESTE EXISTE
-- O dono jogou e disse: "muitas coisas so saem acontecendo e fica dificil de
-- entender e acompanhar". O defeito nao era visual — era TEMPO e ORDEM: dano,
-- debuff no inimigo, proc de coringa, pulso de orbe e compra de carta caiam no
-- mesmo instante. A correcao foi transformar o combate numa fila de BEATS
-- (src/systems/CombatBeats.lua), um acontecimento por instante, cada um
-- segurando o proximo.
--
-- "Nao crashou" nao prova nada aqui. Os asserts abaixo checam a ORDEM CAUSAL
-- executada (CombatBeats grava o trace) e o BLOQUEIO (nada anda na frente do
-- que ainda nao aconteceu). Se alguem reverter o mecanismo, cada bloco falha:
--   1. beat sem bloqueio  -> "um beat por vez" cai (tudo roda no 1o frame)
--   2. espinhos na jogada -> "espinhos NAO ferem ao jogar" cai
--   3. reflexo removido   -> "o golpe do inimigo cobra os espinhos" cai
--   4. ordem do turno     -> os indices do trace saem fora de ordem
--   5. orbes agregados    -> "um pulso por orbe" cai (1 beat em vez de 3)
--   6. heal_multiplier mudo -> "coringa de cura tica" cai
--
--   love . test_one test_beats
--   love . test_all

local TK = require("tools.testkit")
local CombatBeats = require("src.systems.CombatBeats")
local EffectSystem = require("src.systems.EffectSystem")

local M = {}

-- Indice do beat `label` no trace (nil se nunca rodou).
local function at(label)
    return CombatBeats.indexOf(label)
end

-- Indice do primeiro beat cujo label comeca com `prefix`.
local function atPrefix(prefix)
    for i, l in ipairs(CombatBeats.log) do
        if l:sub(1, #prefix) == prefix then return i end
    end
    return nil
end

local function countPrefix(prefix)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l:sub(1, #prefix) == prefix then n = n + 1 end
    end
    return n
end

local function countExact(label)
    local n = 0
    for _, l in ipairs(CombatBeats.log) do
        if l == label then n = n + 1 end
    end
    return n
end

local function thornCard(value)
    return {
        id = "tk_thorn", name = "Teste Espinhos", type = "defense",
        cost = 1, attack = 0, defense = 5,
        effects = { { type = "on_defend_damage", value = value } },
    }
end

function M.run()
    local t = TK.new("ritmo do combate: beats, ordem causal e espinhos")
    TK.bootstrap()

    -- ========================================================================
    -- 1. A FILA SEGURA: um beat por vez
    -- ========================================================================
    CombatBeats.clear()
    CombatBeats.startTrace()
    local ran = {}
    CombatBeats.push("a", function() ran[#ran + 1] = "a" end, 0.5)
    CombatBeats.push("b", function() ran[#ran + 1] = "b" end, 0.5)
    CombatBeats.push("c", function() ran[#ran + 1] = "c" end, 0.5)
    TK.pump(nil, 0.2)
    t:eq("um beat por vez: so o 1o rodou em 0.2s", #ran, 1)
    TK.pump(nil, 0.5)
    t:eq("o 2o so roda depois do hold do 1o", #ran, 2)
    TK.pump(nil, 1.2)
    t:eq("a fila drena inteira", #ran, 3)
    t:eq("ordem preservada", table.concat(ran, ","), "a,b,c")
    t:eq("fila vazia no fim", CombatBeats.pending(), 0)

    -- SEMANTICA MEDIDA: push joga no FIM da fila mesmo chamado de dentro de um
    -- beat. E por isso que resolucao de carta e turno do inimigo sao escritos
    -- como CADEIA (o beat corrente empurra os passos dele e, por ultimo, o elo
    -- seguinte) — pre-agendar carta 1 e carta 2 juntas jogaria os efeitos da
    -- carta 1 pra depois da carta 2. Este assert existe pra que a regra nao
    -- seja "descoberta" de novo na marra.
    ran = {}
    CombatBeats.push("outer", function()
        ran[#ran + 1] = "outer"
        CombatBeats.push("inner", function() ran[#ran + 1] = "inner" end, 0.1)
    end, 0.1)
    CombatBeats.push("after", function() ran[#ran + 1] = "after" end, 0.1)
    TK.pump(nil, 1.0)
    t:eq("push de dentro de um beat vai pro FIM da fila (regra da cadeia)",
        table.concat(ran, ","), "outer,after,inner")
    CombatBeats.stopTrace()

    -- ========================================================================
    -- 2. ESPINHOS: a carta ARMA, o GOLPE DO INIMIGO cobra
    --    (pedido do dono: "esse dano nao deveria ser so quando o inimigo
    --     atacar?" — antes o reflexo saia no instante em que a carta era jogada)
    -- ========================================================================
    local g = TK.newRunGame("warrior")
    TK.pump(g, 0.5)
    local hpEnemy = g.enemy.health
    g:processCardInCombat(thornCard(7), nil)
    t:eq("espinhos NAO ferem ao jogar a carta", g.enemy.health, hpEnemy)
    t:eq("a carta armou 7 de espinhos", g.player:getBuffStacks("thorn"), 7)
    t:eq("bloqueio da carta entrou normalmente", g.player.armor, 5)

    -- O inimigo ATACA -> o reflexo acontece.
    g.enemy.nextIntent = "attack"
    g.enemy.damage = 6; g.enemy.baseDamage = 6; g.enemy.nextIntentDamage = 6
    g.battleTurn = 1
    g.turn = "enemy"
    g:enemyTurn()
    TK.pump(g, 3.5)
    t:eq("o golpe do inimigo cobra os espinhos (-7)", g.enemy.health, hpEnemy - 7)
    t:eq("espinhos expiram no upkeep do jogador seguinte",
        g.player:getBuffStacks("thorn"), 0)
    t:eq("a vez voltou pro jogador", g.turn, "player")

    -- CONTROLE: inimigo que NAO ataca nao leva reflexo nenhum.
    local g2 = TK.newRunGame("warrior")
    TK.pump(g2, 0.5)
    local hp2 = g2.enemy.health
    g2:processCardInCombat(thornCard(7), nil)
    g2.enemy.nextIntent = "defend"
    g2.battleTurn = 1
    g2.turn = "enemy"
    g2:enemyTurn()
    TK.pump(g2, 3.5)
    t:eq("inimigo que DEFENDE nao leva reflexo", g2.enemy.health, hp2)

    -- ========================================================================
    -- 3. ORDEM CAUSAL DO TURNO DO INIMIGO
    -- ========================================================================
    local g3 = TK.newRunGame("warrior")
    TK.pump(g3, 0.5)
    g3:processCardInCombat(thornCard(4), nil)      -- espinhos armados
    g3.enemy:addStatusEffect({ name = "poison", stacks = 3, duration = 3 })
    g3.enemy.nextIntent = "attack"
    g3.enemy.damage = 4; g3.enemy.baseDamage = 4; g3.enemy.nextIntentDamage = 4
    g3.battleTurn = 1
    g3.turn = "enemy"

    CombatBeats.clear()
    CombatBeats.startTrace()
    g3:enemyTurn()

    -- BLOQUEIO: o turno inteiro NAO pode caber num piscar de olhos.
    TK.pump(g3, 0.2)
    local early = #CombatBeats.log
    t:truthy("turno do inimigo NAO resolve tudo em 0.2s (bloqueia mesmo)",
        early > 0 and early <= 2)
    t:truthy("isBlocking() segura o jogo enquanto ha beats pendentes",
        g3.combatAnimationSystem:isBlocking())

    TK.pump(g3, 4.0)
    CombatBeats.stopTrace()
    local order = {
        "enemy.telegraph", "enemy.attack", "player.thorn_reflect",
        "enemy.dot", "enemy.next_intent", "player.upkeep",
        "player.draw", "turn.player_ready",
    }
    local prev, okOrder = 0, true
    for _, label in ipairs(order) do
        local idx = at(label)
        if not idx then
            t:truthy("beat presente no turno: " .. label, false)
            okOrder = false
        elseif idx <= prev then
            okOrder = false
        else
            prev = idx
        end
    end
    t:truthy("ordem causal do turno do inimigo (" .. CombatBeats.traceString() .. ")",
        okOrder)
    t:truthy("nenhum beat do turno se repetiu (re-entrancia bloqueada)",
        countExact("enemy.telegraph") == 1 and countExact("enemy.attack") == 1)

    -- ========================================================================
    -- 4. ORBES DO MAGO: um pulso por orbe, cada um no instante dele
    -- ========================================================================
    local gm = TK.newRunGame("mage")
    TK.pump(gm, 0.5)
    gm.player.orbs = {}
    gm.player:addOrb({ type = "lightning", value = 4 })
    gm.player:addOrb({ type = "ice", value = 4 })
    gm.player:addOrb({ type = "lightning", value = 4 })
    local enemyHpM = gm.enemy.health

    CombatBeats.clear()
    CombatBeats.startTrace()
    gm:endTurn()
    TK.pump(gm, 0.15)
    t:eq("pulso dos orbes: so o primeiro saiu em 0.15s", countPrefix("orb.pulse."), 1)
    TK.pump(gm, 2.0)
    CombatBeats.stopTrace()
    t:eq("um beat de pulso POR ORBE (3 orbes = 3 beats)",
        countPrefix("orb.pulse."), 3)
    -- Valor esperado pela formula CANONICA (a mesma que a UI exibe) — o mago
    -- comeca com Foco 2 (passiva Conduite), entao cravar "2 de dano" no teste
    -- seria testar um numero desatualizado em vez da mecanica.
    local focusM = gm.player:getBuffStacks("focus") or 0
    local expectedPulse = 0
    for _, o in ipairs({ { type = "lightning", value = 4 }, { type = "lightning", value = 4 } }) do
        expectedPulse = expectedPulse + EffectSystem.orbPulseValue(o, focusM)
    end
    t:eq("os pulsos aplicaram o dano de cada orbe",
        gm.enemy.health, enemyHpM - expectedPulse)
    t:truthy("o pulso de gelo virou bloqueio", gm.player.armor >= 2)

    -- evoke_all_orbs tambem evoca UM DE CADA VEZ
    local gm2 = TK.newRunGame("mage")
    TK.pump(gm2, 0.5)
    gm2.player.orbs = {}
    gm2.player:addOrb({ type = "lightning", value = 3 })
    gm2.player:addOrb({ type = "lightning", value = 3 })
    CombatBeats.clear()
    CombatBeats.startTrace()
    local steps = {}
    gm2._beatSink = steps
    gm2.effectSystem:processEffectCard(gm2, { type = "evoke_all_orbs" })
    gm2._beatSink = nil
    CombatBeats.pushAll(steps)
    TK.pump(gm2, 2.0)
    CombatBeats.stopTrace()
    t:eq("evoke_all_orbs: um beat de evoke por orbe", countExact("orb.evoke"), 2)
    t:eq("evoke_all_orbs esvaziou os orbes", #gm2.player.orbs, 0)

    -- ========================================================================
    -- 5. CORINGA QUE MUDA UM NUMERO TEM QUE TICAR
    --    (Abraco Sombrio: defense_bonus ticava, heal_multiplier era MUDO)
    -- ========================================================================
    local gj = TK.newRunGame("warrior")
    TK.pump(gj, 0.5)
    gj:addJokerToRun("warrior_dark_embrace")
    local jk = gj.jokerSlots[#gj.jokerSlots]
    t:truthy("Abraco Sombrio ativo no slot", jk ~= nil)
    local procs = {}
    local healed = gj.effectSystem:applyHealMultiplier(gj, 10, procs)
    t:eq("heal_multiplier 1.5 aplicou o valor", healed, 15)
    t:eq("heal_multiplier EMPURRA proc (coringa deixa de ser mudo)", #procs, 1)
    t:truthy("o proc aponta o slot do coringa certo",
        procs[1] and procs[1].joker == jk)

    -- Cobertura: TODO tipo continuo de coringa do catalogo empurra proc.
    do
        local gAll = TK.newRunGame("warrior")
        TK.pump(gAll, 0.5)
        gAll.jokerSlots = {
            { effects = { { type = "damage_multiplier", target = "attack", value = 2 } } },
            { effects = { { type = "damage_bonus", value = 3 } } },
        }
        local _, p1 = gAll.effectSystem:applyJokerEffects(gAll, { type = "attack" }, 10)
        t:eq("damage_multiplier + damage_bonus ticam (2 procs)", #p1, 2)
        gAll.jokerSlots = {
            { effects = { { type = "defense_multiplier", target = "defense", value = 1.5 } } },
            { effects = { { type = "defense_bonus", value = 2 } } },
        }
        local _, p2 = gAll.effectSystem:applyJokerEffects(gAll, { type = "defense" }, 10)
        t:eq("defense_multiplier + defense_bonus ticam (2 procs)", #p2, 2)
    end

    -- ========================================================================
    -- 6. RESOLUCAO DE CARTA: impacto > coringas > efeitos > dissolve > proxima
    -- ========================================================================
    local gc = TK.newRunGame("rogue")
    TK.pump(gc, 0.5)
    -- Carta de ataque com efeito secundario (veneno): o debuff no inimigo tem
    -- que acontecer DEPOIS do dano, num instante proprio.
    local atk = {
        id = "tk_atk", name = "Teste Golpe", type = "attack",
        cost = 0, attack = 6, defense = 0,
        effects = { { type = "apply_debuff", value = "poison", stacks = 2, duration = 2 } },
    }
    table.insert(gc.hand, atk)
    gc.player.mana = 3
    gc:selectCard(atk)
    CombatBeats.clear()
    CombatBeats.startTrace()
    gc:playSelectedCards()
    TK.pump(gc, 6.0)
    CombatBeats.stopTrace()
    local iImpact = atPrefix("card.impact.")
    local iEffect = at("effect.apply_debuff")
    local iDissolve = at("card.dissolve")
    t:truthy("carta impactou (" .. CombatBeats.traceString() .. ")", iImpact ~= nil)
    t:truthy("o debuff no inimigo tem beat proprio", iEffect ~= nil)
    t:truthy("debuff DEPOIS do impacto", iImpact and iEffect and iEffect > iImpact)
    t:truthy("dissolve DEPOIS do efeito da carta",
        iDissolve and iEffect and iDissolve > iEffect)
    t:truthy("o veneno chegou no inimigo", gc.enemy:hasStatus("poison"))

    -- ========================================================================
    -- 7. ENFURECIDO: o inimigo cruzar os 30% de vida e um ACONTECIMENTO
    --    (era mudo: +50% de dano permanente sem toast, som, pill ou instante —
    --     acontecia em TODA batalha e mudava a conta de dano do jogador)
    -- ========================================================================
    local ge = TK.newRunGame("warrior")
    TK.pump(ge, 0.5)
    ge.enemy.health = 10                 -- 30% de 18 = 5.4: ainda acima
    ge.enemy.damage = 6; ge.enemy.baseDamage = 6
    ge.enemy:rollIntent()
    local intentBefore = ge.enemy.nextIntentDamage
    t:falsy("antes de ferir: nao esta enfurecido", ge.enemy:hasStatus("enraged"))

    local bigHit = {
        id = "tk_big", name = "Teste Pancada", type = "attack",
        cost = 0, attack = 8, defense = 0, effects = {},
    }
    table.insert(ge.hand, bigHit)
    ge.player.mana = 3
    ge:selectCard(bigHit)
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge:playSelectedCards()
    TK.pump(ge, 6.0)
    CombatBeats.stopTrace()

    t:truthy("inimigo ferido vira status REAL `enraged` (pill no HUD)",
        ge.enemy:hasStatus("enraged"))
    local iImpactE = atPrefix("card.impact.")
    local iRage = at("enemy.enraged")
    t:truthy("o enfurecimento tem BEAT proprio (" .. CombatBeats.traceString() .. ")",
        iRage ~= nil)
    t:truthy("o enfurecimento vem DEPOIS do golpe que o causou",
        iImpactE and iRage and iRage > iImpactE)
    t:eq("o dano dele subiu 50%", ge.enemy.damage, math.floor(6 * 1.5))
    -- INVARIANTE (CLAUDE.md 6): o golpe JA anunciado no HUD nao muda.
    t:eq("o intent ja telegrafado NAO fica mais forte",
        ge.enemy.nextIntentDamage, intentBefore)

    -- so anuncia na VIRADA: ferir de novo nao repete o acontecimento
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge.enemy:takeDamage(1)
    ge:announceEnrageIfPending(nil)
    TK.pump(ge, 1.0)
    CombatBeats.stopTrace()
    t:eq("enfurecer e evento de VIRADA, nao se repete a cada dano",
        countExact("enemy.enraged"), 0)

    -- checkpoint no turno do inimigo: fonte fora da carta nunca fica muda
    local ge2 = TK.newRunGame("warrior")
    TK.pump(ge2, 0.5)
    ge2.enemy.health = 4                 -- ja abaixo do limiar
    ge2.enemy:takeDamage(0)              -- cruza pelo caminho canonico
    t:truthy("dano de qualquer fonte marca o enfurecimento pendente",
        ge2.enemy._pendingEnrage == true)
    ge2.enemy.nextIntent = "defend"
    ge2.battleTurn = 1
    ge2.turn = "enemy"
    CombatBeats.clear()
    CombatBeats.startTrace()
    ge2:enemyTurn()
    TK.pump(ge2, 4.0)
    CombatBeats.stopTrace()
    t:eq("checkpoint do turno anuncia o enfurecimento pendente",
        countExact("enemy.enraged"), 1)
    t:truthy("o checkpoint vem ANTES do inimigo agir",
        at("enemy.enraged") and at("enemy.defend")
        and at("enemy.enraged") < at("enemy.defend"))

    -- ========================================================================
    -- 8. CONTRATO: todo trigger de processTriggerEffect esta em TRIGGER_OF
    --    (esquecer de registrar = o trigger nunca mais dispara, em silencio)
    -- ========================================================================
    do
        local src = love.filesystem.read("src/systems/EffectSystem.lua")
        local missing = {}
        for ttype, trig in src:gmatch('t == "(%w+)" and triggerType == "(%w+)"') do
            if EffectSystem.TRIGGER_OF[ttype] ~= trig then
                missing[#missing + 1] = ttype .. "->" .. trig
            end
        end
        t:eq("TRIGGER_OF cobre todo trigger implementado ("
            .. table.concat(missing, ", ") .. ")", #missing, 0)
    end

    CombatBeats.clear()
    return t:done()
end

return M
