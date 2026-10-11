-- tools/audit_cards.lua
-- AUDITORIA CARTA A CARTA (Out/2026, frente de balanceamento).
--
-- Pergunta que esta ferramenta responde, para CADA carta do catalogo:
--   "o que a carta DIZ (descricao exibida, nos 5 idiomas, com a forja
--    aplicada) e EXATAMENTE o que ela FAZ quando jogada?"
--
-- Tres camadas, cada uma com sua propria lista de defeitos:
--
--   1. COMPORTAMENTO — joga a carta num Game de verdade (mesmo caminho do
--      jogador: selectCard -> playSelectedCards -> fila de beats), mede os
--      deltas reais (dano no inimigo, bloqueio, vida, mana, Forca/Destreza/
--      Foco/Espinhos, orbes, compra/descarte, exaurir, debuffs) e compara com
--      o MODELO derivado so dos DADOS da carta. Jokers sao medidos com cartas-
--      sonda (ataque 10 / defesa 10 / cura 15) e um ciclo de turno completo
--      (gatilhos de inicio de turno, espinhos refletidos, bloqueio retido).
--      Repete com a carta FORJADA (+1 e +2): o ganho tem que aparecer no efeito.
--   2. DESCRICAO — renderiza a descricao nos 5 locales (base e forjada) e
--      checa: placeholder cru, numero que nao existe nos dados, numero cravado
--      no template (apodrece na forja), efeito dos dados sem palavra na
--      descricao, palavra-chave na descricao sem efeito nos dados, e o
--      VOCABULARIO canonico por idioma (um termo por conceito).
--   3. CURVA DE PODER — pontos por mana por raridade/classe, com outliers.
--      Informativa (heuristica): o veredito de forca vem do simulador
--      (tools/balance_sim.lua), nao daqui.
--
--   love . test_one test_card_audit        -> trava (falha com qualquer defeito)
--   love . test_one audit_cards            -> relatorio completo no console
--   AUDIT_CARDS_OUT=docs/balance/card_audit.md love . test_one audit_cards
--                                          -> tambem grava o relatorio em arquivo

local TK = require("tools.testkit")

local M = {}

-- ============================================================================
-- Catalogo
-- ============================================================================

local function catalog()
    local CardDatabase = require("src.systems.CardDatabase")
    local all = CardDatabase:getAllCards()
    local ids = {}
    for id in pairs(all) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids, all, CardDatabase
end

local function classOf(cd)
    local c = cd.class
    if c == "warrior" or c == "mage" or c == "rogue" then return c end
    return "warrior"
end

local function hasEff(cd, t)
    for _, e in ipairs(cd.effects or {}) do
        if e.type == t then return e end
    end
    return nil
end

-- ============================================================================
-- 1. COMPORTAMENTO
-- ============================================================================

local FILLER_ID = "defense_001"
local HAND_FILLERS = 5
local DECK_FILLERS = 12

-- Orbes pre-semeados para cartas que EVOCAM (sem eles o evoke e no-op e a
-- medicao nao diria nada). Valores escolhidos pra serem distinguiveis.
local SEED_ORBS = {
    { type = "lightning", value = 5 },
    { type = "ice", value = 4 },
}

local function drain(g)
    local guard = 0
    local cs = g.combatAnimationSystem
    while cs and cs:isBlocking() and guard < 1200 do
        TK.pump(g, 1 / 30)
        guard = guard + 1
    end
    TK.pump(g, 0.3)
end

local function mkInst(CardDatabase, id)
    local cd = CardDatabase:getCard(id)
    return CardDatabase:createCardInstance(cd)
end

-- Estado neutro e conhecido. Nada de passiva de classe, nada de joker.
local function neutralGame(cls, CardDatabase)
    local g = TK.newRunGame(cls)
    TK.pump(g, 0.4)
    drain(g)
    local p = g.player
    p.maxHealth = 60; p.health = 30
    p.armor = 0; p.maxArmor = 999
    p.maxMana = 20; p.mana = 10
    p.strength = 0; p.dexterity = 0
    p.orbs = {}; p.buffs = {}
    p.retainArmor = false
    local e = g.enemy
    e.maxHealth = 900; e.health = 900; e.armor = 0
    e.statusEffects = {}
    e.attackPattern = "normal"
    e._pendingEnrage = nil
    g.jokerSlots = {}
    g.hand, g.deck, g.discard = {}, {}, {}
    g._exhaustedThisBattle = {}
    g.selectedCards = {}
    g._toxinAppliedThisTurn = true   -- silencia a passiva do ladino
    g._impetusFiredThisTurn = true   -- silencia a passiva do guerreiro
    g._attacksThisTurn = 0
    g._echoFiredThisTurn = false
    g._jokerThornFiredThisTurn = {}
    for _ = 1, HAND_FILLERS do
        local f = mkInst(CardDatabase, FILLER_ID); f._filler = true
        g.hand[#g.hand + 1] = f
    end
    for _ = 1, DECK_FILLERS do
        local f = mkInst(CardDatabase, FILLER_ID); f._filler = true
        g.deck[#g.deck + 1] = f
    end
    return g
end

local function snapshot(g)
    local p, e = g.player, g.enemy
    local s = {
        enemyHp = e.health, enemyArmor = e.armor,
        hp = p.health, armor = p.armor, mana = p.mana, maxMana = p.maxMana,
        str = p.strength, dex = p.dexterity,
        focus = p:getBuffStacks("focus"), thorn = p:getBuffStacks("thorn"),
        hand = #g.hand, deck = #g.deck, discard = #g.discard,
        exhausted = #(g._exhaustedThisBattle or {}),
        orbs = {}, status = {},
    }
    for _, o in ipairs(p.orbs or {}) do s.orbs[#s.orbs + 1] = { type = o.type, value = o.value } end
    for _, st in ipairs(e.statusEffects or {}) do
        s.status[st.name] = { stacks = st.stacks, duration = st.duration }
    end
    return s
end

local function playOne(g, inst)
    g.hand[#g.hand + 1] = inst
    g:selectCard(inst)
    g:playSelectedCards()
    drain(g)
end

-- Modelo puro de DADOS (o que a carta promete), carta jogada SOZINHA,
-- Forca/Destreza/Foco 0, sem joker. `inst` ja vem forjada quando for o caso.
-- Combos: so os que a PROPRIA carta dispara sozinha (tag `combo` conta em
-- dobro — regra documentada do ComboSystem, anunciada por banner).
local STAT = 3   -- Forca/Destreza do cenario "com stats"

local function expectedFor(inst, seeded, withStats)
    local TagSystem = require("src.systems.TagSystem")
    local ComboSystem = require("src.systems.ComboSystem")
    local ex = {
        enemyDmg = 0, armor = 0, hpDelta = 0, mana = 0, maxMana = 0,
        str = 0, dex = 0, focus = 0, thorn = 0,
        drawn = 0, discarded = 0, exhaust = inst.exhaust and true or false,
        status = {}, orbs = {},
        notes = {},
    }
    local ctx = { allSelectedCards = { inst }, tagCounts = TagSystem.countAllTags({ inst }) }
    ComboSystem.detect(ctx)
    local function comboApply(v)
        local before = v
        v = ComboSystem.applyToCardValue(inst, v, ctx)
        if v ~= before then ex.notes[#ex.notes + 1] = "auto-combo" end
        return v
    end
    local vuln = false
    local function hitEnemy(d)
        if vuln then d = math.floor(d * 1.5) end
        ex.enemyDmg = ex.enemyDmg + d
    end
    local function addStatus(name, stacks, duration)
        local st = ex.status[name]
        if st then
            st.stacks = st.stacks + stacks
            st.duration = st.duration + duration
        else
            ex.status[name] = { stacks = stacks, duration = duration }
        end
        if name == "vulnerable" then vuln = true end
    end
    local orbs = {}
    for _, o in ipairs(seeded or {}) do orbs[#orbs + 1] = { type = o.type, value = o.value } end
    local function evokeOrb(o)
        -- Foco ja ganho NESTA carta (Consumir: Foco antes de evocar) conta
        local v = o.value + ex.focus
        if o.type == "lightning" then hitEnemy(v)
        elseif o.type == "dark" then hitEnemy(v * 2)
        elseif o.type == "fire" then
            hitEnemy(v); addStatus("burn", math.max(1, math.floor(v / 2)), 2)
        elseif o.type == "ice" then ex.armor = ex.armor + v
        elseif o.type == "holy" then ex.hpDelta = ex.hpDelta + v end
    end

    -- valor principal (ataque/defesa)
    if inst.type == "attack" then
        local v = inst.attack or 0
        local hits = 1
        for _, e in ipairs(inst.effects or {}) do
            if e.type == "damage_bonus_self" then v = v + (e.value or 1)
            elseif e.type == "multi_hit" then
                hits = math.max(1, e.value or 1); v = v * hits
            end
        end
        if withStats then
            -- Forca vale POR GOLPE; strength_scaling = Forca em DOBRO
            local s = STAT * (hasEff(inst, "strength_scaling") and 2 or 1)
            v = v + s * hits
        end
        v = comboApply(v)
        hitEnemy(math.floor(v))
        -- gatilhos da propria carta (sourceCard) no ataque
        for _, e in ipairs(inst.effects or {}) do
            if e.type == "on_attack_heal" then ex.hpDelta = ex.hpDelta + (e.value or 0)
            elseif e.type == "on_attack_debuff" then
                addStatus(e.debuffName or "poison", e.stacks or 1, e.duration or 2)
            end
        end
    elseif inst.type == "defense" then
        local v = inst.defense or 0
        if withStats then
            v = v + STAT * (hasEff(inst, "dexterity_scaling") and 2 or 1)
        end
        v = comboApply(v)
        ex.armor = ex.armor + math.floor(v)
        for _, e in ipairs(inst.effects or {}) do
            if e.type == "on_defend_damage" then ex.thorn = ex.thorn + (e.value or 0) end
        end
    end

    -- efeitos secundarios, na ordem
    if inst.type ~= "joker" then
        for _, e in ipairs(inst.effects or {}) do
            local t, v = e.type, e.value
            if t == "instant_heal" then ex.hpDelta = ex.hpDelta + v
            elseif t == "self_damage" then ex.hpDelta = ex.hpDelta - v
            elseif t == "restore_mana" then ex.mana = ex.mana + v
            elseif t == "increase_max_mana" then
                ex.maxMana = ex.maxMana + v; ex.mana = ex.mana + v
            elseif t == "add_armor" then ex.armor = ex.armor + v
            elseif t == "magic_damage" or t == "aoe_magic_damage" then hitEnemy(v)
            elseif t == "draw_cards" then ex.drawn = ex.drawn + v
            elseif t == "discard_cards" then ex.discarded = ex.discarded + v
            elseif t == "apply_debuff" then
                addStatus(v, e.stacks or 1, e.duration or 2)
            elseif t == "apply_buff" then
                if v == "focus" then ex.focus = ex.focus + (e.stacks or 1)
                else ex.notes[#ex.notes + 1] = "buff:" .. tostring(v) end
            elseif t == "gain_strength" then ex.str = ex.str + v
            elseif t == "gain_dexterity" then ex.dex = ex.dex + v
            elseif t == "channel_orb" then
                if #orbs >= 3 then evokeOrb(table.remove(orbs, 1)) end
                orbs[#orbs + 1] = { type = e.orbType or "lightning", value = v }
            elseif t == "evoke_orb" then
                if #orbs > 0 then evokeOrb(table.remove(orbs, 1)) end
            elseif t == "evoke_all_orbs" then
                while #orbs > 0 do evokeOrb(table.remove(orbs, 1)) end
            elseif t == "mystery" then
                ex.mystery = true
            end
        end
    end
    ex.orbs = orbs
    return ex
end

local function orbsStr(list)
    local p = {}
    for _, o in ipairs(list or {}) do p[#p + 1] = o.type .. ":" .. tostring(o.value) end
    return "[" .. table.concat(p, ",") .. "]"
end

local function statusStr(st)
    local keys = {}
    for k in pairs(st or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    local p = {}
    for _, k in ipairs(keys) do
        p[#p + 1] = string.format("%s %d/%dt", k, st[k].stacks or 0, st[k].duration or 0)
    end
    return "{" .. table.concat(p, ", ") .. "}"
end

-- Mede uma carta NAO-joker jogada sozinha (opcionalmente forjada).
local function measureCard(CardDatabase, RunManager, id, level, withStats)
    local cd = CardDatabase:getCard(id)
    local g = neutralGame(classOf(cd), CardDatabase)
    if withStats then g.player.strength = STAT; g.player.dexterity = STAT end
    local inst = mkInst(CardDatabase, id)
    if level and level > 0 then
        g.runManager:applyUpgradesToInstance(inst, level)
    end
    local seeded = nil
    if hasEff(inst, "evoke_orb") or hasEff(inst, "evoke_all_orbs") then
        seeded = SEED_ORBS
        for _, o in ipairs(SEED_ORBS) do
            g.player.orbs[#g.player.orbs + 1] = { type = o.type, value = o.value }
        end
    end
    local before = snapshot(g)
    playOne(g, inst)
    local after = snapshot(g)

    local fillersInDiscard = 0
    for _, c in ipairs(g.discard) do if c._filler then fillersInDiscard = fillersInDiscard + 1 end end
    local inDiscard = false
    for _, c in ipairs(g.discard) do if c == inst then inDiscard = true end end
    local exhaustedNow = false
    for _, eid in ipairs(g._exhaustedThisBattle or {}) do if eid == id then exhaustedNow = true end end

    local got = {
        enemyDmg = before.enemyHp - after.enemyHp,
        armor = after.armor - before.armor,
        hpDelta = after.hp - before.hp,
        -- mana: o custo sai na selecao, entao o liquido do efeito e +custo
        mana = after.mana - before.mana + (inst.cost or 0),
        maxMana = after.maxMana - before.maxMana,
        str = after.str - before.str, dex = after.dex - before.dex,
        focus = after.focus - before.focus, thorn = after.thorn - before.thorn,
        drawn = before.deck - after.deck,
        discarded = fillersInDiscard,
        exhaust = exhaustedNow and not inDiscard,
        status = after.status, orbs = after.orbs,
        handLeft = after.hand,
    }
    local ex = expectedFor(inst, seeded, withStats)
    return got, ex, inst
end

local CMP_FIELDS = { "enemyDmg", "armor", "hpDelta", "mana", "maxMana", "str", "dex",
    "focus", "thorn", "drawn", "discarded" }

local function compare(id, label, got, ex, issues)
    if ex.mystery then
        -- aleatorio por design: so exige que ALGO tenha acontecido
        local any = got.enemyDmg ~= 0 or got.armor ~= 0 or got.hpDelta ~= 0 or got.drawn ~= 0
            or got.str ~= 0 or #got.orbs > 0
        if not any then issues[#issues + 1] = id .. label .. ": Carta Misterio nao fez nada" end
        return
    end
    for _, f in ipairs(CMP_FIELDS) do
        if (got[f] or 0) ~= (ex[f] or 0) then
            issues[#issues + 1] = string.format("%s%s: %s medido %s, dados prometem %s",
                id, label, f, tostring(got[f]), tostring(ex[f]))
        end
    end
    if got.exhaust ~= ex.exhaust then
        issues[#issues + 1] = string.format("%s%s: exaurir medido %s, dados %s",
            id, label, tostring(got.exhaust), tostring(ex.exhaust))
    end
    if orbsStr(got.orbs) ~= orbsStr(ex.orbs) then
        issues[#issues + 1] = string.format("%s%s: orbes medidos %s, dados %s",
            id, label, orbsStr(got.orbs), orbsStr(ex.orbs))
    end
    -- debuffs no inimigo: so os declarados (ignora `enraged`, que nao vem da carta)
    local gs, es = {}, {}
    for k, v in pairs(got.status or {}) do if k ~= "enraged" then gs[k] = v end end
    for k, v in pairs(ex.status or {}) do es[k] = v end
    if statusStr(gs) ~= statusStr(es) then
        issues[#issues + 1] = string.format("%s%s: debuffs medidos %s, dados %s",
            id, label, statusStr(gs), statusStr(es))
    end
end

-- ----- Jokers -------------------------------------------------------------

local function probe(CardDatabase, id, field, value)
    local inst = mkInst(CardDatabase, id)
    if field then inst[field] = value end
    inst.tags = { inst.type == "attack" and "strike" or "defend" } -- sem combo
    return inst
end

-- Roda o turno do inimigo INTEIRO (golpe de 1, espinhos, DoT, upkeep, compra,
-- gatilhos de inicio de turno) e devolve o snapshot depois.
local function fullEnemyCycle(g)
    g.enemy.nextIntent = "attack"
    g.enemy.nextIntentDamage = 1
    g.enemy.damage = 1; g.enemy.baseDamage = 1
    g.enemy.attackCooldown = 0
    g.turn = "player"
    g:endTurn()
    drain(g)
    g:enemyTurn()
    drain(g)
    TK.pump(g, 0.5)
    drain(g)
end

local function jokerScenario(CardDatabase, id)
    local cd = id and CardDatabase:getCard(id)
    local cls = cd and classOf(cd) or "warrior"
    local res = {}

    local function withJoker(g)
        if id then
            local j = mkInst(CardDatabase, id)
            g.jokerSlots = { j }
            g:syncJokerFlags()
        end
    end

    -- A) ataque-sonda 10
    do
        local g = neutralGame(cls, CardDatabase); withJoker(g)
        local s0 = snapshot(g)
        playOne(g, probe(CardDatabase, "warrior_strike", "attack", 10))
        local s1 = snapshot(g)
        res.atkDmg = s0.enemyHp - s1.enemyHp
        res.atkHeal = s1.hp - s0.hp
        res.atkStatus = s1.status
        -- segundo ataque no MESMO turno (Eco so vale no primeiro)
        local s2a = snapshot(g)
        playOne(g, probe(CardDatabase, "warrior_strike", "attack", 10))
        res.atkDmg2 = s2a.enemyHp - snapshot(g).enemyHp
    end
    -- B) defesa-sonda 10, depois o turno do inimigo inteiro
    do
        local g = neutralGame(cls, CardDatabase); withJoker(g)
        local s0 = snapshot(g)
        playOne(g, probe(CardDatabase, "warrior_defend", "defense", 10))
        local s1 = snapshot(g)
        res.defArmor = s1.armor - s0.armor
        res.defThorn = s1.thorn
        local hpBeforeTurn, enemyBefore = s1.hp, s1.enemyHp
        local strBefore = s1.str
        fullEnemyCycle(g)
        local s2 = snapshot(g)
        res.reflect = enemyBefore - s2.enemyHp
        res.turnHp = s2.hp - hpBeforeTurn            -- regen / custo / golpe absorvido
        res.turnStr = s2.str - strBefore
        res.turnHand = s2.hand
        res.turnOrbs = s2.orbs
        res.armorKept = s2.armor
    end
    -- C) cura-sonda: Pocao de Cura (15)
    do
        local g = neutralGame(cls, CardDatabase); withJoker(g)
        g.player.health = 10
        local s0 = snapshot(g)
        playOne(g, mkInst(CardDatabase, "effect_healing_potion"))
        res.heal = snapshot(g).hp - s0.hp
    end
    return res
end

local function jokerExpected(cd, base)
    local ex = {
        atkDmg = base.atkDmg, atkDmg2 = base.atkDmg2, atkHeal = base.atkHeal,
        defArmor = base.defArmor, defThorn = base.defThorn, reflect = base.reflect,
        turnHp = base.turnHp, turnStr = base.turnStr, turnHand = base.turnHand,
        turnOrbs = #base.turnOrbs, armorKept = base.armorKept, heal = base.heal,
        atkStatus = {},
    }
    local dmgMult, defMult = 1, 1
    local dmgFlat, defFlat = 0, 0
    local echo = nil
    local healMult = 1
    for _, e in ipairs(cd.effects or {}) do
        local t, v = e.type, e.value
        if t == "damage_multiplier" then dmgMult = math.max(dmgMult, v)
        elseif t == "defense_multiplier" then defMult = math.max(defMult, v)
        elseif t == "damage_bonus" then dmgFlat = dmgFlat + v
        elseif t == "defense_bonus" then defFlat = defFlat + v
        elseif t == "echo_first_attack" then echo = v or 2
        elseif t == "heal_multiplier" then healMult = healMult * v
        elseif t == "on_attack_heal" then ex.atkHeal = ex.atkHeal + v
        elseif t == "on_attack_debuff" then
            ex.atkStatus[e.debuffName or "poison"] = { stacks = e.stacks or 1, duration = e.duration or 2 }
        elseif t == "on_defend_damage" then ex.defThorn = ex.defThorn + v; ex.reflect = ex.reflect + v
        elseif t == "regen_per_turn" then ex.turnHp = ex.turnHp + v
        elseif t == "damage_per_turn" then ex.turnHp = ex.turnHp - v
        elseif t == "strength_per_turn" then ex.turnStr = ex.turnStr + v
        elseif t == "on_turn_start_draw" then ex.turnHand = ex.turnHand + v
        elseif t == "channel_per_turn" then ex.turnOrbs = ex.turnOrbs + 1
        elseif t == "retain_armor" then ex.retain = true
        end
    end
    local function atk(baseV, first)
        local v = 10 * dmgMult
        if echo and first then v = v * echo end
        return math.floor(v + dmgFlat)
    end
    ex.atkDmg = atk(10, true)
    ex.atkDmg2 = atk(10, false)
    ex.defArmor = math.floor(10 * defMult + defFlat)
    -- regen/heal passam pelo multiplicador de cura do proprio joker
    if healMult ~= 1 then
        ex.heal = math.floor(15 * healMult)
    end
    if ex.retain then ex.armorKept = math.max(0, ex.defArmor - 1) end -- golpe de 1
    return ex
end

local function compareJoker(id, got, ex, issues)
    local fields = { "atkDmg", "atkDmg2", "atkHeal", "defArmor", "defThorn", "reflect",
        "turnHp", "turnStr", "turnHand", "armorKept", "heal" }
    for _, f in ipairs(fields) do
        if (got[f] or 0) ~= (ex[f] or 0) then
            issues[#issues + 1] = string.format("%s [joker]: %s medido %s, dados prometem %s",
                id, f, tostring(got[f]), tostring(ex[f]))
        end
    end
    if #got.turnOrbs ~= ex.turnOrbs then
        issues[#issues + 1] = string.format("%s [joker]: orbes no turno %d, dados %d",
            id, #got.turnOrbs, ex.turnOrbs)
    end
    local gs = {}
    for k, v in pairs(got.atkStatus or {}) do if k ~= "enraged" then gs[k] = v end end
    if statusStr(gs) ~= statusStr(ex.atkStatus) then
        issues[#issues + 1] = string.format("%s [joker]: debuff no ataque %s, dados %s",
            id, statusStr(gs), statusStr(ex.atkStatus))
    end
end

function M.behaviorAudit(opts)
    opts = opts or {}
    local ids, all, CardDatabase = catalog()
    local RunManager = require("src.systems.RunManager")
    local issues, rows = {}, {}
    local baseJoker = nil
    local counted = { cards = 0, jokers = 0, forged = 0 }
    for _, id in ipairs(ids) do
        local cd = all[id]
        if os.getenv("AUDIT_DEBUG") == "1" then
            io.stdout:write(string.format("[audit] %s t=%.2f", id, os.clock()), "\n")
            io.stdout:flush()
        end
        if cd.type == "joker" then
            baseJoker = baseJoker or jokerScenario(CardDatabase, nil)
            local got = jokerScenario(CardDatabase, id)
            local ex = jokerExpected(cd, baseJoker)
            compareJoker(id, got, ex, issues)
            counted.jokers = counted.jokers + 1
            rows[#rows + 1] = { id = id, kind = "joker", got = got }
        else
            local got, ex, inst = measureCard(CardDatabase, RunManager, id, 0)
            compare(id, "", got, ex, issues)
            if cd.type == "attack" or cd.type == "defense" then
                local gs, es = measureCard(CardDatabase, RunManager, id, 0, true)
                compare(id, " (Forca/Destreza " .. STAT .. ")", gs, es, issues)
                counted.withStats = (counted.withStats or 0) + 1
            end
            counted.cards = counted.cards + 1
            rows[#rows + 1] = { id = id, kind = "card", got = got, ex = ex, inst = inst }
            -- forja: o ganho declarado TEM que aparecer no efeito medido
            local gains = RunManager.getForgeGains(cd)
            if next(gains) ~= nil and not hasEff(cd, "mystery") then
                for _, lvl in ipairs({ 1, 2 }) do
                    local g2, e2 = measureCard(CardDatabase, RunManager, id, lvl)
                    compare(id, " (forja +" .. lvl .. ")", g2, e2, issues)
                    counted.forged = counted.forged + 1
                    -- e o ganho e REAL (nao so o modelo acompanhando o modelo)
                    local delta = (g2.enemyDmg - got.enemyDmg) + (g2.armor - got.armor)
                        + (g2.hpDelta - got.hpDelta) + (g2.str - got.str) + (g2.dex - got.dex)
                    if delta <= 0 then
                        issues[#issues + 1] = string.format(
                            "%s (forja +%d): forjar nao mudou nada mensuravel", id, lvl)
                    end
                end
            end
        end
    end
    return issues, rows, counted
end

-- ============================================================================
-- 2. DESCRICAO
-- ============================================================================

local LOCALES = { "pt_BR", "en", "es", "fr", "de" }

-- Termos canonicos (minusculo, sem acento). Um conceito = um termo por idioma.
-- `any` = qualquer um basta pra "mencionar" o conceito.
local VOCAB = {
    damage    = { pt_BR = { "dano" }, en = { "damage" }, es = { "dano" }, fr = { "degat" }, de = { "schaden" } },
    block     = { pt_BR = { "bloqueio" }, en = { "block" }, es = { "bloqueo" }, fr = { "blocage" }, de = { "block" } },
    heal      = { pt_BR = { "cura", "regenera" }, en = { "heal", "regen" }, es = { "cura", "regenera" },
                  fr = { "soign", "soin", "regenere" }, de = { "heil", "regener" } },
    lose_hp   = { pt_BR = { "perde" }, en = { "lose" }, es = { "pierde" }, fr = { "perd" }, de = { "verlier" } },
    mana      = { pt_BR = { "mana" }, en = { "mana" }, es = { "mana" }, fr = { "mana" }, de = { "mana" } },
    draw      = { pt_BR = { "compra" }, en = { "draw" }, es = { "roba" }, fr = { "pioche" }, de = { "zieh" } },
    discard   = { pt_BR = { "descarta" }, en = { "discard" }, es = { "descarta" }, fr = { "defausse" }, de = { "wirf", "abwerf", "abgeworfen" } },
    poison    = { pt_BR = { "veneno" }, en = { "poison" }, es = { "veneno" }, fr = { "poison" }, de = { "gift" } },
    vulnerable= { pt_BR = { "vulneravel" }, en = { "vulnerable" }, es = { "vulnerable" }, fr = { "vulnerable" }, de = { "verwundbar" } },
    weak      = { pt_BR = { "fraco" }, en = { "weak" }, es = { "debil" }, fr = { "faible" }, de = { "schwach" } },
    strength  = { pt_BR = { "forca" }, en = { "strength" }, es = { "fuerza" }, fr = { "force" }, de = { "staerke" } },
    dexterity = { pt_BR = { "destreza" }, en = { "dexterity" }, es = { "destreza" }, fr = { "dexterite" }, de = { "geschick" } },
    focus     = { pt_BR = { "foco" }, en = { "focus" }, es = { "foco" }, fr = { "focus" }, de = { "fokus" } },
    channel   = { pt_BR = { "canaliza" }, en = { "channel" }, es = { "canaliza" }, fr = { "canalise" }, de = { "kanalisiere" } },
    evoke     = { pt_BR = { "evoca" }, en = { "evoke" }, es = { "evoca" }, fr = { "evoque" }, de = { "loese", "loest" } },
    exhaust   = { pt_BR = { "exaurir" }, en = { "exhaust" }, es = { "agotar" }, fr = { "epuiser" }, de = { "erschoepfen" } },
    innate    = { pt_BR = { "inato" }, en = { "innate" }, es = { "innato" }, fr = { "inne" }, de = { "angeboren" } },
    retain    = { pt_BR = { "retencao" }, en = { "retain" }, es = { "retencion" }, fr = { "conservation" }, de = { "behalten" } },
    thorn     = { pt_BR = { "espinhos" }, en = { "thorns" }, es = { "espinas" }, fr = { "epines" }, de = { "dornen" } },
    multi     = { pt_BR = { "vezes" }, en = { "twice", "times" }, es = { "veces" }, fr = { "fois" }, de = { "mal" } },
    lightning = { pt_BR = { "raio" }, en = { "lightning" }, es = { "rayo" }, fr = { "foudre" }, de = { "blitz" } },
    ice       = { pt_BR = { "gelo" }, en = { "ice" }, es = { "hielo" }, fr = { "glace" }, de = { "eis" } },
    dark      = { pt_BR = { "sombra" }, en = { "shadow" }, es = { "sombra" }, fr = { "ombre" }, de = { "schatten" } },
    fire      = { pt_BR = { "fogo" }, en = { "fire" }, es = { "fuego" }, fr = { "feu" }, de = { "feuer" } },
    holy      = { pt_BR = { "sagrado" }, en = { "holy" }, es = { "sagrado" }, fr = { "sacre" }, de = { "heilig" } },
    per_turn  = { pt_BR = { "turno" }, en = { "turn" }, es = { "turno" }, fr = { "tour" }, de = { "zug" } },
    max_mana  = { pt_BR = { "maxima" }, en = { "max" }, es = { "maximo" }, fr = { "max" }, de = { "max" } },
    percent   = { pt_BR = { "%" }, en = { "%" }, es = { "%" }, fr = { "%" }, de = { "%" } },
    double    = { pt_BR = { "dobra" }, en = { "double" }, es = { "duplica" }, fr = { "double" }, de = { "verdoppel" } },
}

-- Sinonimos PROIBIDOS (vocabulario fora do padrao): termo -> canonico.
local FORBIDDEN = {
    pt_BR = { ["armor"] = "Bloqueio", ["armadura"] = "Bloqueio", ["escuridao"] = "Sombra",
              ["lifesteal"] = "cura ao atacar", ["stacks"] = "de Veneno", ["exaure"] = "Exaurir",
              ["ganhe "] = "Ganha", ["compre "] = "Compra", ["orb escuro"] = "Sombra", ["sombrio"] = "Sombra",
              ["nesta batalha"] = "(Forca/Destreza/Foco ja duram a batalha)" },
    en    = { ["armor"] = "Block", ["darkness"] = "Shadow", ["lifesteal"] = "heal on attack",
              ["this battle"] = "(stats already last the battle)" },
    es    = { ["armadura"] = "Bloqueo", ["oscuridad"] = "Sombra", ["en esta batalla"] = "(dura la batalla)" },
    fr    = { ["armure"] = "Blocage", ["sombre"] = "Ombre", ["givre"] = "Glace", ["pour ce combat"] = "(dure le combat)" },
    de    = { ["ruestung"] = "Block", ["dunkelheit"] = "Schatten", ["frost"] = "Eis", ["fuer diesen kampf"] = "(gilt den Kampf)" },
}

-- "nesta batalha" e informacao REAL so onde o efeito some no fim da batalha
-- e o jogador poderia achar que nao (mana maxima). Forca/Destreza/Foco sempre
-- duram a batalha — repetir isso em umas cartas e nao em outras e ruido.
local BATTLE_PHRASE = { ["nesta batalha"] = true, ["this battle"] = true,
    ["en esta batalla"] = true, ["pour ce combat"] = true, ["fuer diesen kampf"] = true }

-- Padroes de FORMATO (Lua patterns sobre o texto normalizado): a mesma ideia
-- escrita sempre do mesmo jeito dentro de um idioma.
local STYLE = {
    pt_BR = { { "%d+ hp", "use \"N de HP\"" }, { "em ataques", "use \"em cartas de ataque\"" },
              { "em defesas", "use \"em cartas de defesa\"" }, { "voce perde", "use \"Perde\"" },
              { "%+%d+ de forca", "use \"Ganha N de Forca\"" }, { "%+%d+ de destreza", "use \"Ganha N de Destreza\"" },
              { "hp por turno", "use \"no inicio de cada turno\"" }, { "extra por turno", "use \"no inicio de cada turno\"" },
              { "inicio do turno", "use \"inicio de cada turno\"" } },
    en    = { { "on attacks", "use \"on attack cards\"" }, { "on defenses", "use \"on defense cards\"" },
              { "you lose", "use \"Lose\"" }, { "twice", "use \"{value} times\"" } },
    es    = { { "%d+ hp", "use \"PV\"" }, { "en ataques", "use \"en cartas de ataque\"" },
              { "en defensas", "use \"en cartas de defensa\"" } },
    fr    = { { "%d+ hp", "use \"PV\"" }, { "sur les attaques", "use \"sur les cartes d'attaque\"" },
              { "sur les defenses", "use \"sur les cartes de defense\"" } },
    de    = { { "%d+ hp", "use \"LP\"" }, { "verursacht ", "use \"Verursache\" (imperativo, como Erhalte/Ziehe)" },
              { "heilt ", "use \"Heile\"" }, { "stellt ", "use \"Stelle\"" }, { "regeneriert ", "use \"Regeneriere\"" },
              { "auf angriffe%f[^%w]", "use \"auf Angriffskarten\"" }, { "auf verteidigungen%f[^%w]", "use \"auf Verteidigungskarten\"" } },
}

local ORB_CONCEPT = { lightning = "lightning", ice = "ice", dark = "dark", fire = "fire", holy = "holy" }

-- Conceitos que os DADOS exigem que a descricao mencione.
local function requiredConcepts(cd)
    local req = {}
    local function need(c, why) req[c] = req[c] or why end
    if cd.type == "attack" and (cd.attack or 0) > 0 then need("damage", "ataque") end
    if cd.type == "defense" and (cd.defense or 0) > 0 then need("block", "defesa") end
    if cd.exhaust or hasEff(cd, "exhaust") then need("exhaust", "exaurir") end
    if cd.innate or hasEff(cd, "innate") then need("innate", "inato") end
    if cd.retain then need("retain", "retencao") end
    for _, e in ipairs(cd.effects or {}) do
        local t = e.type
        if t == "instant_heal" or t == "on_attack_heal" or t == "regen_per_turn"
            or t == "heal_multiplier" then need("heal", t)
        elseif t == "self_damage" or t == "damage_per_turn" then need("lose_hp", t)
        elseif t == "restore_mana" then need("mana", t)
        elseif t == "increase_max_mana" then need("mana", t); need("max_mana", t)
        elseif t == "add_armor" or t == "defense_bonus" or t == "defense_multiplier"
            or t == "retain_armor" then need("block", t)
        elseif t == "magic_damage" or t == "aoe_magic_damage" or t == "damage_bonus"
            or t == "damage_multiplier" then need("damage", t)
        elseif t == "draw_cards" or t == "on_turn_start_draw" then need("draw", t)
        elseif t == "discard_cards" then need("discard", t)
        elseif t == "apply_debuff" then need(e.value, t)
        elseif t == "on_attack_debuff" then need(e.debuffName or "poison", t)
        elseif t == "apply_buff" then need(e.value, t)
        elseif t == "gain_strength" or t == "strength_per_turn" or t == "strength_scaling" then
            need("strength", t)
        elseif t == "gain_dexterity" or t == "dexterity_scaling" then need("dexterity", t)
        elseif t == "channel_orb" or t == "channel_per_turn" then
            need("channel", t); need(ORB_CONCEPT[e.orbType or "lightning"], t)
        elseif t == "evoke_orb" or t == "evoke_all_orbs" then need("evoke", t)
        elseif t == "on_defend_damage" then need("thorn", t)
        elseif t == "multi_hit" then need("multi", t)
        elseif t == "echo_first_attack" then need("double", t)
        end
        if t == "damage_multiplier" or t == "defense_multiplier" or t == "heal_multiplier" then
            need("percent", t)
        end
        if t == "regen_per_turn" or t == "damage_per_turn" or t == "strength_per_turn"
            or t == "on_turn_start_draw" or t == "channel_per_turn" then
            need("per_turn", t)
        end
    end
    return req
end

-- Conceitos que, se aparecem na descricao, PRECISAM existir nos dados.
local CLAIM_CHECK = { "poison", "vulnerable", "weak", "strength", "dexterity", "focus",
    "exhaust", "innate", "retain", "thorn", "evoke", "channel", "discard", "draw",
    "lose_hp", "multi" }

local function norm(s)
    s = s:lower()
    local map = { ["á"]="a",["à"]="a",["â"]="a",["ã"]="a",["ä"]="ae",["é"]="e",["ê"]="e",["è"]="e",
        ["í"]="i",["ó"]="o",["ô"]="o",["õ"]="o",["ö"]="oe",["ú"]="u",["ü"]="ue",["ç"]="c",["ß"]="ss",
        ["ñ"]="n",["Á"]="a",["É"]="e",["Í"]="i",["Ó"]="o",["Ú"]="u",["Ç"]="c" }
    for k, v in pairs(map) do s = s:gsub(k, v) end
    return s
end

local function mentions(text, locale, concept)
    local v = VOCAB[concept]
    if not v then return true end
    for _, w in ipairs(v[locale] or {}) do
        if text:find(w, 1, true) then return true end
    end
    return false
end

local function cardHasConcept(cd, concept)
    local req = requiredConcepts(cd)
    if req[concept] then return true end
    -- descreve um efeito que de fato existe por outro caminho
    if concept == "lose_hp" then return false end
    return false
end

-- Valores numericos legitimos que podem aparecer no texto.
local function allowedNumbers(inst)
    local ok = { [1] = true }
    local function add(n)
        if type(n) == "number" then ok[math.floor(n + 0.5)] = true end
    end
    add(inst.attack); add(inst.defense)
    local channels = 0
    for _, e in ipairs(inst.effects or {}) do
        add(e.value); add(e.stacks); add(e.duration)
        if type(e.value) == "number" and (e.type:find("_multiplier") or e.type == "echo_first_attack") then
            add((e.value - 1) * 100)
        end
        if e.type == "channel_orb" then channels = channels + 1 end
        if e.type == "multi_hit" then add(e.value) end
    end
    add(channels)
    return ok
end

function M.descAudit()
    local I18n = require("src.i18n.I18n")
    local ids, all, CardDatabase = catalog()
    local RunManager = require("src.systems.RunManager")
    local rm = RunManager:new()
    local issues = {}
    local saved = I18n.getLocale()
    local rawByLocale = {}
    for _, loc in ipairs(LOCALES) do
        I18n.setLocale(loc, true)
        for _, id in ipairs(ids) do
            local cd = all[id]
            local inst = CardDatabase:createCardInstance(cd)
            local key = "cards." .. id .. ".desc"
            local raw = I18n.t(key, nil, "\0MISS")
            if raw == "\0MISS" then
                issues[#issues + 1] = string.format("%s [%s]: SEM descricao traduzida (%s)", id, loc, key)
            else
                rawByLocale[loc] = rawByLocale[loc] or {}
                rawByLocale[loc][id] = raw
                local nameRaw = I18n.t("cards." .. id .. ".name", nil, "\0MISS")
                if nameRaw == "\0MISS" then
                    issues[#issues + 1] = string.format("%s [%s]: SEM nome traduzido", id, loc)
                end
                local text = I18n.cardDesc(inst)
                if text:find("{", 1, true) then
                    issues[#issues + 1] = string.format("%s [%s]: placeholder cru: %s", id, loc, text)
                end
                local n = norm(text)
                -- (a) todo efeito dos dados tem palavra na descricao
                for concept, why in pairs(requiredConcepts(cd)) do
                    if not mentions(n, loc, concept) then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: descricao nao menciona '%s' (efeito %s): \"%s\"",
                            id, loc, concept, why, text)
                    end
                end
                -- (b) toda palavra-chave da descricao existe nos dados
                local req = requiredConcepts(cd)
                for _, concept in ipairs(CLAIM_CHECK) do
                    if not req[concept] and mentions(n, loc, concept) then
                        -- "Conta em DOBRO para combos" e "2 vezes" nao sao multi_hit
                        -- "Retencao: nao e descartada" explica a palavra-chave, nao e descarte
                        local skip = (concept == "discard" and cd.retain)
                        if not skip then
                            issues[#issues + 1] = string.format(
                                "%s [%s]: descricao fala de '%s' mas a carta nao tem esse efeito: \"%s\"",
                                id, loc, concept, text)
                        end
                    end
                end
                -- (c) numeros: so os que existem nos dados
                local okNum = allowedNumbers(inst)
                for num in text:gmatch("%d+") do
                    local v = tonumber(num)
                    if not okNum[v] then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: numero %s nao existe nos dados: \"%s\"", id, loc, num, text)
                    end
                end
                -- (d) numero CRAVADO no template que coincide com um valor dos
                -- dados (apodrece no proximo rebalance/forja)
                local rawNoPh = raw:gsub("{%w+}", "")
                for num in rawNoPh:gmatch("%d+") do
                    local v = tonumber(num)
                    local clash = false
                    if v == inst.attack or v == inst.defense then clash = true end
                    for _, e in ipairs(inst.effects or {}) do
                        if e.value == v or e.stacks == v or e.duration == v then clash = true end
                        if type(e.value) == "number" and tostring(e.type):find("_multiplier$")
                            and math.floor((e.value - 1) * 100 + 0.5) == v then clash = true end
                    end
                    if clash then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: numero %s CRAVADO no template (use placeholder): \"%s\"",
                            id, loc, num, raw)
                    end
                end
                -- (e) vocabulario proibido
                for bad, good in pairs(FORBIDDEN[loc] or {}) do
                    local exempt = BATTLE_PHRASE[bad] and hasEff(cd, "increase_max_mana")
                    if not exempt and n:find(bad, 1, true) then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: vocabulario fora do padrao '%s' (use %s): \"%s\"",
                            id, loc, bad, good, text)
                    end
                end
                for _, st in ipairs(STYLE[loc] or {}) do
                    if n:find(st[1]) then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: formato fora do padrao (%s): \"%s\"", id, loc, st[2], text)
                    end
                end
                -- (h) LINHAS DE EFEITO (painel de detalhe / colecao / inspecao):
                -- todo efeito tem chave traduzida — sem cair no `description`
                -- PT dos dados nem no tipo cru — e nenhum numero inventado.
                for _, e in ipairs(cd.effects or {}) do
                    local MISS = "\0MISS"
                    local q = (type(e.value) == "string" and e.value) or e.orbType or e.debuffName
                    local has = I18n.t("effects." .. tostring(e.type), nil, MISS) ~= MISS
                        or (q and I18n.t("effects." .. tostring(e.type) .. "_" .. q, nil, MISS) ~= MISS)
                    local et = I18n.effectDesc(e)
                    if not has then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: efeito '%s' sem linha traduzida (cai em \"%s\")", id, loc, tostring(e.type), et)
                    end
                    if et:find("{", 1, true) then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: linha de efeito com placeholder cru: %s", id, loc, et)
                    end
                    local okE = { [1] = true }
                    for _, k in ipairs({ "value", "stacks", "duration" }) do
                        if type(e[k]) == "number" then okE[math.floor(e[k] + 0.5)] = true end
                    end
                    if type(e.value) == "number" and tostring(e.type):find("_multiplier$") then
                        okE[math.floor((e.value - 1) * 100 + 0.5)] = true
                    end
                    if e.stacks == nil then okE[1] = true end
                    if e.duration == nil then okE[2] = true end
                    for num in et:gmatch("%d+") do
                        if not okE[tonumber(num)] then
                            issues[#issues + 1] = string.format(
                                "%s [%s]: linha de efeito com numero %s que nao e do efeito: %s", id, loc, num, et)
                        end
                    end
                end
                -- (f) forja: o numero novo aparece na descricao forjada
                local gains = RunManager.getForgeGains(cd)
                if next(gains) ~= nil then
                    local f = CardDatabase:createCardInstance(cd)
                    rm:applyUpgradesToInstance(f, 2)
                    local ft = I18n.cardDesc(f)
                    local newVal
                    if gains.atk then newVal = f.attack
                    elseif gains.def then newVal = f.defense
                    elseif gains.effectIndex then newVal = f.effects[gains.effectIndex].value end
                    local found = false
                    for num in ft:gmatch("%d+") do
                        if tonumber(num) == newVal then found = true end
                    end
                    if not found then
                        issues[#issues + 1] = string.format(
                            "%s [%s]: forjada +2 (%s -> %s) mas a descricao nao mostra: \"%s\"",
                            id, loc, tostring(gains.atk and "atk" or gains.def and "def" or gains.effectType),
                            tostring(newVal), ft)
                    end
                end
            end
        end
    end
    I18n.setLocale(saved, true)
    -- (g) PARALELISMO entre idiomas: o mesmo conjunto de placeholders
    for _, id in ipairs(ids) do
        local base = rawByLocale.pt_BR and rawByLocale.pt_BR[id]
        if base then
            local function phs(s)
                local set, list = {}, {}
                for ph in s:gmatch("{(%w+)}") do
                    if not set[ph] then set[ph] = true; list[#list + 1] = ph end
                end
                table.sort(list)
                return table.concat(list, ",")
            end
            local want = phs(base)
            for _, loc in ipairs(LOCALES) do
                local r = rawByLocale[loc] and rawByLocale[loc][id]
                if r and phs(r) ~= want then
                    issues[#issues + 1] = string.format(
                        "%s [%s]: placeholders {%s} diferentes do pt_BR {%s}", id, loc, phs(r), want)
                end
            end
        end
    end
    return issues
end

-- ============================================================================
-- 3. CURVA DE PODER (heuristica — o veredito e do simulador)
-- ============================================================================

-- Pesos em "pontos" (~1 ponto = 1 de dano imediato num inimigo do A1-A2).
M.WEIGHTS = {
    damage = 1.0, block = 0.85, heal = 0.9, draw = 3.5, discard = -0.5,
    mana = 5.5, max_mana = 12, strength = 4.5, dexterity = 3.5, focus = 5,
    poison_tick = 0.9, vulnerable_turn = 3.0, weak_turn = 2.5, burn_tick = 0.9,
    orb = { lightning = 1.6, ice = 1.3, dark = 2.2, fire = 1.8, holy = 1.2 },
    evoke = 5, self_damage = -0.8, thorn = 0.7, exhaust_tax = 0.0,
    innate = 1.5, retain = 1.5,
}

function M.cardPoints(cd)
    local W = M.WEIGHTS
    local pts = 0
    local hits = 1
    local base = 0
    if cd.type == "attack" then base = cd.attack or 0 end
    for _, e in ipairs(cd.effects or {}) do
        if e.type == "multi_hit" then hits = e.value or 1 end
        if e.type == "damage_bonus_self" then base = base + (e.value or 0) end
    end
    pts = pts + base * hits * W.damage
    if cd.type == "defense" then pts = pts + (cd.defense or 0) * W.block end
    for _, e in ipairs(cd.effects or {}) do
        local t, v = e.type, e.value
        if t == "instant_heal" or t == "on_attack_heal" then pts = pts + v * W.heal
        elseif t == "self_damage" then pts = pts + v * W.self_damage
        elseif t == "restore_mana" then pts = pts + v * W.mana
        elseif t == "increase_max_mana" then pts = pts + v * W.max_mana
        elseif t == "add_armor" then pts = pts + v * W.block
        elseif t == "magic_damage" or t == "aoe_magic_damage" then pts = pts + v * W.damage
        elseif t == "draw_cards" then pts = pts + v * W.draw
        elseif t == "discard_cards" then pts = pts + v * W.discard
        elseif t == "apply_debuff" then
            local d, s = e.duration or 2, e.stacks or 1
            if v == "poison" then pts = pts + s * d * W.poison_tick
            elseif v == "vulnerable" then pts = pts + d * W.vulnerable_turn
            elseif v == "weak" then pts = pts + d * W.weak_turn end
        elseif t == "apply_buff" and v == "focus" then pts = pts + (e.stacks or 1) * W.focus
        elseif t == "gain_strength" then pts = pts + v * W.strength
        elseif t == "gain_dexterity" then pts = pts + v * W.dexterity
        elseif t == "strength_scaling" then pts = pts + 2
        elseif t == "dexterity_scaling" then pts = pts + 2
        elseif t == "channel_orb" then pts = pts + v * (W.orb[e.orbType or "lightning"] or 1.5)
        elseif t == "evoke_orb" then pts = pts + W.evoke
        elseif t == "evoke_all_orbs" then pts = pts + W.evoke * 2
        elseif t == "on_defend_damage" then pts = pts + v * W.thorn
        elseif t == "mystery" then pts = pts + 6
        end
    end
    if cd.innate then pts = pts + W.innate end
    if cd.retain then pts = pts + W.retain end
    return pts
end

function M.powerCurve()
    local ids, all = catalog()
    local groups, rows = {}, {}
    for _, id in ipairs(ids) do
        local cd = all[id]
        if cd.type ~= "joker" then
            local pts = M.cardPoints(cd)
            local denom = math.max(0.5, cd.cost or 0)
            -- exaurir = carta de uso unico na batalha: vale o mesmo por mana,
            -- mas aparece marcada (comparar so dentro do mesmo perfil)
            local r = { id = id, cls = cd.class or "basic", rarity = cd.rarity or "common",
                cost = cd.cost or 0, pts = pts, ppm = pts / denom,
                exhaust = (cd.exhaust or hasEff(cd, "exhaust")) and true or false }
            rows[#rows + 1] = r
            local key = r.rarity
            groups[key] = groups[key] or {}
            table.insert(groups[key], r)
        end
    end
    local stats = {}
    for key, list in pairs(groups) do
        local s, s2 = 0, 0
        for _, r in ipairs(list) do s = s + r.ppm; s2 = s2 + r.ppm * r.ppm end
        local n = #list
        local mean = s / n
        local sd = math.sqrt(math.max(0, s2 / n - mean * mean))
        stats[key] = { mean = mean, sd = sd, n = n }
        for _, r in ipairs(list) do
            r.z = sd > 0 and (r.ppm - mean) / sd or 0
        end
    end
    table.sort(rows, function(a, b) return a.ppm > b.ppm end)
    return rows, stats
end

-- ============================================================================
-- Relatorio
-- ============================================================================

function M.collect()
    TK.bootstrap()
    local bIssues, rows, counted = M.behaviorAudit()
    local dIssues = M.descAudit()
    local curve, cstats = M.powerCurve()
    return { behavior = bIssues, desc = dIssues, rows = rows, counted = counted,
        curve = curve, curveStats = cstats }
end

function M.report(res)
    local out = {}
    local function p(fmt, ...)
        out[#out + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
    end
    p("# Auditoria de cartas")
    p("")
    p("Cartas medidas: %d nao-joker + %d jokers, %d medicoes forjadas.",
        res.counted.cards, res.counted.jokers, res.counted.forged)
    p("")
    p("## Comportamento x dados (%d divergencias)", #res.behavior)
    for _, s in ipairs(res.behavior) do p("- %s", s) end
    p("")
    p("## Descricao x dados (%d divergencias)", #res.desc)
    for _, s in ipairs(res.desc) do p("- %s", s) end
    p("")
    p("## Curva de poder (pontos por mana, heuristica)")
    p("")
    local keys = {}
    for k in pairs(res.curveStats) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local s = res.curveStats[k]
        p("- %s: media %.1f pts/mana (dp %.1f, n=%d)", k, s.mean, s.sd, s.n)
    end
    p("")
    p("| carta | classe | raridade | custo | pts | pts/mana | z |")
    p("|---|---|---|---|---|---|---|")
    for _, r in ipairs(res.curve) do
        p("| %s%s | %s | %s | %d | %.1f | %.1f | %+.1f |", r.id, r.exhaust and " (exaurir)" or "",
            r.cls, r.rarity, r.cost, r.pts, r.ppm, r.z or 0)
    end
    return table.concat(out, "\n")
end

function M.run()
    local okC, res = xpcall(M.collect, debug.traceback)
    if not okC then
        print("[audit_cards] CRASH: " .. tostring(res))
        return false
    end
    local text = M.report(res)
    print(text)
    local outPath = os.getenv("AUDIT_CARDS_OUT")
    if outPath and outPath ~= "" then
        local f = io.open(outPath, "w")
        if f then f:write(text, "\n"); f:close(); print("[audit_cards] gravado: " .. outPath)
        else print("[audit_cards] AVISO: nao consegui gravar " .. outPath) end
    end
    return #res.behavior == 0 and #res.desc == 0
end

return M
