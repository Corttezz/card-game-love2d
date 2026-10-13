-- src/systems/DamagePreview.lua
-- PREVIA DE DANO (Out/2026, pedido do dono: "o combo de muitas cartas da
-- dano demais — o problema nao e o dano, e que NAO FICA CLARO quanto vai dar.
-- O jogador seleciona um milhao de cartas e pronto, nao precisa pensar").
--
-- Duas pecas, as duas PURAS (nao tocam em game/player/enemy):
--
--   DamagePreview.cardValue(game, card, turnContext, st)
--     -> valor, passos, jokerEntries, ecoUsado
--     O valor de UMA carta de ataque/defesa: efeitos proprios -> Forca/
--     Destreza (por golpe; scaling = dobro) -> combos -> coringas (maior
--     multiplicador vence + planos) -> edicao -> selo -> Fraco/Fragil.
--     E a FONTE UNICA: Game:_resolveCardInCombat chama esta mesma funcao e so
--     acrescenta os efeitos colaterais (toast, proc de coringa, banner). Previa
--     e resultado nao podem divergir porque sao a mesma conta.
--
--   DamagePreview.simulate(game, cards)
--     -> { damage, blocked, block, heal, thorn, lethal, combos, cards = {...},
--          extras = {...}, uncertain }
--     A leva INTEIRA, carta a carta, na ordem em que o combate resolve
--     (ordem de selecao): Impeto do guerreiro antes de tudo, Forca/Foco/
--     Vulneravel ganhos no meio da leva valendo pras cartas seguintes, orbes
--     canalizando/estourando, armadura do inimigo absorvendo, inimigo morto
--     no meio da leva (os ataques seguintes nao saem), premio de combo no fim.
--     Trava: tools/test_damage_preview.lua joga centenas de levas aleatorias
--     pelo combate de verdade e compara.

local EffectSystem = require("src.systems.EffectSystem")
local ComboSystem  = require("src.systems.ComboSystem")
local TagSystem    = require("src.systems.TagSystem")

local DamagePreview = {}

-- ===== Edicao e selo (Fase 3.2/3.3) — fonte unica, o Game usa daqui =====
-- Foil e plano; Holo/Polychrome multiplicam; Negative nao mexe no valor (o
-- efeito dele e +1 slot de coringa, em Game:recomputeMaxJokerSlots).
DamagePreview.EDITION_FLAT = { foil = 5 }
DamagePreview.EDITION_MULT = { holo = 1.2, polychrome = 1.5 }
-- Red: x2 valor (retrigger via mult). Outros selos sao efeito pos-jogada.
DamagePreview.SEAL_VALUE_MULT = { Red = 2.0 }

-- Enfraquecido/Fragil (debuffs do INIMIGO no jogador): -25%, por ultimo.
local DEBUFF_CUT = 0.75

local function hasEff(card, t)
    for _, e in ipairs((card and card.effects) or {}) do
        if e.type == t then return e end
    end
    return nil
end

-- Estado do turno que a leva enxerga. Sem `st`, le do jogo AGORA.
local function liveState(game)
    local p = game.player
    return {
        strength  = (p and p.strength) or 0,
        dexterity = (p and p.dexterity) or 0,
        echoFired = game._echoFiredThisTurn and true or false,
        weak  = p and p.hasDebuff and p:hasDebuff("weak") or false,
        frail = p and p.hasDebuff and p:hasDebuff("frail") or false,
    }
end
DamagePreview.liveState = liveState

-- Valor de UMA carta attack/defense. `st` = { strength, dexterity, echoFired,
-- weak, frail }. Devolve (valor, passos, jokerEntries, ecoUsado).
-- Passos (lidos pela UI): { kind, value/delta/mult, after, label? }
--   base · effects (multi-golpe/bonus proprio) · stat · combo · joker ·
--   edition · seal · weak/frail
function DamagePreview.cardValue(game, card, turnContext, st)
    st = st or liveState(game)
    local isAtk = card.type == "attack"
    local base = (isAtk and card.attack or card.defense) or 0
    local steps = { { kind = "base", value = base, after = base } }

    -- 1. efeitos da propria carta (multi_hit, damage_bonus_self)
    local v = game.effectSystem and game.effectSystem:applyCardEffects(game, card, base)
        or EffectSystem.applyCardEffects(nil, game, card, base)
    local hits = EffectSystem.hitCount(card)
    if v ~= base then
        steps[#steps + 1] = { kind = "effects", hits = hits, delta = v - base, after = v }
    end

    -- 2. Forca/Destreza — por golpe; carta com *_scaling conta o stat em DOBRO
    -- (auditoria Jul/2026, fonte unica do statBonus).
    local stat = isAtk and (st.strength or 0) or (st.dexterity or 0)
    if stat ~= 0 and hasEff(card, isAtk and "strength_scaling" or "dexterity_scaling") then
        stat = stat * 2
    end
    local statDelta = stat * hits
    if statDelta ~= 0 then
        v = v + statDelta
        steps[#steps + 1] = { kind = "stat", stat = isAtk and "strength" or "dexterity",
            delta = statDelta, after = v }
    end

    -- 3. combos da leva
    local comboSteps
    v, comboSteps = ComboSystem.cardSteps(card, v, turnContext, game)
    for _, cs in ipairs(comboSteps) do
        steps[#steps + 1] = { kind = "combo", combo = cs.combo, op = cs.op,
            value = cs.value, after = cs.after }
    end

    -- 4. coringas (maior multiplicador vence + planos somam + Eco)
    local entries, echoUsed = {}, false
    if game.effectSystem then
        v, entries, echoUsed = game.effectSystem:jokerSteps(game, card, v,
            turnContext, st.echoFired)
    end
    for _, e in ipairs(entries) do
        steps[#steps + 1] = { kind = "joker", joker = e.joker, op = e.op,
            value = e.value, after = e.after }
    end

    -- 5. edicao
    local ed = card.edition
    if ed and (DamagePreview.EDITION_FLAT[ed] or DamagePreview.EDITION_MULT[ed]) then
        local flat = DamagePreview.EDITION_FLAT[ed]
        if flat then v = v + flat end
        local mult = DamagePreview.EDITION_MULT[ed]
        if mult then v = v * mult end
        steps[#steps + 1] = { kind = "edition", edition = ed, after = v }
    end

    -- 6. selo
    local sm = card.seal and DamagePreview.SEAL_VALUE_MULT[card.seal]
    if sm then
        v = v * sm
        steps[#steps + 1] = { kind = "seal", seal = card.seal, op = "mult",
            value = sm, after = v }
    end

    v = math.floor(v)

    -- 7. Fraco (ataque) / Fragil (defesa): por ultimo, como no StS.
    if isAtk and st.weak then
        v = math.floor(v * DEBUFF_CUT)
        steps[#steps + 1] = { kind = "weak", op = "mult", value = DEBUFF_CUT, after = v }
    elseif not isAtk and st.frail then
        v = math.floor(v * DEBUFF_CUT)
        steps[#steps + 1] = { kind = "frail", op = "mult", value = DEBUFF_CUT, after = v }
    end
    steps[#steps].after = v
    return v, steps, entries, echoUsed
end

-- ============================================================================
-- Simulacao da leva
-- ============================================================================

-- turnContext igual ao de Game:playSelectedCards (combos detectados).
function DamagePreview.buildContext(cards, game)
    local snapshot = {}
    for _, c in ipairs(cards or {}) do snapshot[#snapshot + 1] = c end
    local ctx = {
        allSelectedCards = snapshot,
        tagCounts = TagSystem.countAllTags(snapshot),
        cardsProcessed = {},
        activeCombos = {},
        game = game,
    }
    ComboSystem.detect(ctx, game)
    return ctx
end

-- Inimigo/jogador SIMULADOS (copias rasas dos campos que a conta le).
local function simEnemy(enemy)
    local vuln = enemy and enemy.hasStatus and enemy:hasStatus("vulnerable") or false
    return { health = (enemy and enemy.health) or 0, armor = (enemy and enemy.armor) or 0,
        vuln = vuln }
end

local function simPlayer(game)
    local p = game.player or {}
    local orbs = {}
    for _, o in ipairs(p.orbs or {}) do orbs[#orbs + 1] = { type = o.type, value = o.value } end
    local st = liveState(game)
    st.armor = p.armor or 0
    st.maxArmor = p.maxArmor or math.huge
    st.focus = (p.getBuffStacks and p:getBuffStacks("focus")) or 0
    st.orbs = orbs
    st.orbSlots = p.orbSlots or 3
    return st
end

-- Cura com os coringas de cura, SEM efeito colateral. A previa roda todo
-- quadro (hover/selecao); EffectSystem:applyHealMultiplier sem sink dispara
-- o proc DIRETO no JokerProcFx — foi assim que o Calice do Sabio ficou
-- soltando "×1.5 PV" do nada enquanto o jogador so passava o mouse (bug do
-- dono, Out/2026). O sink descartavel engole o proc; a conta e a mesma.
local function previewHeal(game, v)
    local es = game.effectSystem
    if not (es and es.applyHealMultiplier) then return v end
    return es:applyHealMultiplier(game, v, {})
end

function DamagePreview.simulate(game, cards)
    local R = { damage = 0, blocked = 0, block = 0, heal = 0, thorn = 0, poison = 0,
        lethal = false, cards = {}, extras = {}, uncertain = false }
    if not game or not game.player or not game.enemy or not cards or #cards == 0 then
        R.combos = {}
        return R
    end
    local ctx = DamagePreview.buildContext(cards, game)
    R.combos = ctx.activeCombos
    R.context = ctx
    local E = simEnemy(game.enemy)
    local P = simPlayer(game)
    R.enemyHealth = E.health

    -- dano no inimigo: Vulneravel (x1.5, floor) antes da armadura, que absorve
    local function hitEnemy(dmg, source)
        if dmg <= 0 then return 0 end
        if E.vuln then dmg = math.floor(dmg * 1.5) end
        local through = math.max(0, dmg - E.armor)
        local absorbed = dmg - through
        E.armor = math.max(0, E.armor - dmg)
        local dealt = math.min(E.health, through)
        E.health = math.max(0, E.health - through)
        R.damage = R.damage + dealt
        R.blocked = R.blocked + absorbed
        return dealt, absorbed, dmg
    end
    local function addArmor(v)
        local before = P.armor
        P.armor = math.min(P.maxArmor, P.armor + v)
        R.block = R.block + (P.armor - before)
    end
    local function extra(kind, value, info)
        if value and value ~= 0 then
            R.extras[#R.extras + 1] = { kind = kind, value = value, info = info }
        end
    end

    -- evocar um orbe (espelho de EffectSystem:_evokeOrbEffect)
    local function evoke(orb, why)
        if not orb then return end
        local v = (orb.value or 1) + P.focus
        if orb.type == "lightning" or orb.type == "fire" or orb.type == "dark" then
            extra("orb", (hitEnemy(EffectSystem.orbEvokeValue(orb, P.focus))),
                { orb = orb.type, why = why })
        elseif orb.type == "ice" then
            addArmor(v)
            extra("orb_block", v, { orb = orb.type, why = why })
        elseif orb.type == "holy" then
            R.heal = R.heal + previewHeal(game, v)
        end
    end
    local function channel(orb)
        if #P.orbs >= P.orbSlots then evoke(table.remove(P.orbs, 1), "overflow") end
        P.orbs[#P.orbs + 1] = orb
    end

    -- efeito secundario / de carta de efeito (espelho de processEffectCard)
    local function effect(e)
        local t, v = e.type, e.value or 0
        if t == "magic_damage" or t == "aoe_magic_damage" then
            extra("magic", (hitEnemy(v)))
        elseif t == "add_armor" then
            addArmor(v)
        elseif t == "apply_debuff" then
            if e.value == "vulnerable" then E.vuln = true end
            if e.value == "poison" then R.poison = R.poison + (e.stacks or 1) end
        elseif t == "gain_strength" then
            P.strength = P.strength + v
        elseif t == "gain_dexterity" then
            P.dexterity = P.dexterity + v
        elseif t == "apply_buff" then
            if e.value == "focus" then P.focus = P.focus + (e.stacks or 1) end
        elseif t == "channel_orb" then
            channel({ type = e.orbType or "lightning", value = v })
        elseif t == "evoke_orb" then
            evoke(table.remove(P.orbs, 1), "evoke")
        elseif t == "evoke_all_orbs" then
            local n = #P.orbs
            for _ = 1, n do evoke(table.remove(P.orbs, 1), "evoke") end
        elseif t == "instant_heal" then
            R.heal = R.heal + previewHeal(game, v)
        elseif t == "mystery" then
            R.uncertain = true
        end
    end
    local function additionalEffects(card)
        for _, e in ipairs(card.effects or {}) do
            local t = e.type
            if t ~= "strength_scaling" and t ~= "dexterity_scaling"
                and t ~= "multi_hit" and t ~= "damage_bonus_self" then
                effect(e)
            end
        end
    end
    -- gatilhos on_attack / on_defend: coringas primeiro, depois a propria carta
    local function triggers(card, kind)
        local function one(e, fromJoker, joker)
            if kind == "attack" and e.type == "on_attack_heal" then
                R.heal = R.heal + previewHeal(game, e.value or 0)
            elseif kind == "attack" and e.type == "on_attack_debuff" then
                local name = e.debuffName or "poison"
                if name == "vulnerable" then E.vuln = true end
                if name == "poison" then R.poison = R.poison + (e.stacks or 1) end
            elseif kind == "defend" and e.type == "on_defend_damage" then
                -- coringa arma 1x por turno (P2.3); carta arma por carta
                if fromJoker then
                    local jid = joker.id or joker
                    P.thornFired = P.thornFired or {}
                    local real = game._jokerThornFiredThisTurn or {}
                    if not P.thornFired[jid] and not real[jid] then
                        P.thornFired[jid] = true
                        R.thorn = R.thorn + (e.value or 0)
                    end
                else
                    R.thorn = R.thorn + (e.value or 0)
                end
            end
        end
        for _, j in ipairs(game.jokerSlots or {}) do
            for _, e in ipairs(j.effects or {}) do one(e, true, j) end
        end
        for _, e in ipairs(card.effects or {}) do one(e, false) end
    end

    -- Impeto do guerreiro: IMPETUS_ATTACKS (3) ataques no turno (somando levas) = +1 Forca
    -- ANTES das cartas resolverem (Game:applyClassTurnPassives).
    if game.selectedClass == "warrior" and not game._impetusFiredThisTurn then
        local attacks = game._attacksThisTurn or 0
        for _, c in ipairs(cards) do
            if (c.attack or 0) > 0 then attacks = attacks + 1 end
        end
        if attacks >= require("src.core.Game").IMPETUS_ATTACKS then
            P.strength = P.strength + 1
            R.impetus = true
        end
    end
    -- Toxinas do ladino: o 1o ataque do turno envenena (so informativo); a
    -- passiva cresce (Game.TOXIN_GROWTH) se esta leva fecha 2+ ataques no turno
    local toxinsUsed = game._toxinAppliedThisTurn
    local toxinBonus = game._toxinBonus or 0
    if game.selectedClass == "rogue" and not game._toxinGrowFiredThisTurn then
        local attacks = game._attacksThisTurn or 0
        for _, c in ipairs(cards) do
            if (c.attack or 0) > 0 then attacks = attacks + 1 end
        end
        if attacks >= 2 then toxinBonus = toxinBonus + require("src.core.Game").TOXIN_GROWTH end
    end

    for _, card in ipairs(cards) do
        local entry = { card = card, type = card.type }
        if card.type == "attack" then
            if E.health <= 0 then
                entry.skipped = true   -- inimigo ja caiu: o golpe nao sai
            else
                local v, steps, _, echoUsed = DamagePreview.cardValue(game, card, ctx, P)
                if echoUsed then P.echoFired = true end
                entry.value, entry.steps = v, steps
                local dealt, absorbed, landed = hitEnemy(v)
                entry.dealt, entry.absorbed, entry.landed = dealt, absorbed, landed
                entry.vuln = E.vuln
                if game.selectedClass == "rogue" and not toxinsUsed and E.health > 0 then
                    toxinsUsed = true
                    R.poison = R.poison + (game.classPassiveTier and game:classPassiveTier() or 1)
                        + toxinBonus
                end
                triggers(card, "attack")
                additionalEffects(card)
                if card.seal == "Purple" then
                    -- Player:addOrb: transborda o mais antigo SEM evocar
                    if #P.orbs >= P.orbSlots then table.remove(P.orbs, 1) end
                    P.orbs[#P.orbs + 1] = { type = "lightning", value = 1 }
                end
            end
        elseif card.type == "defense" then
            local v, steps = DamagePreview.cardValue(game, card, ctx, P)
            entry.value, entry.steps = v, steps
            addArmor(v)
            triggers(card, "defend")
            additionalEffects(card)
            if card.seal == "Purple" then
                if #P.orbs >= P.orbSlots then table.remove(P.orbs, 1) end
                P.orbs[#P.orbs + 1] = { type = "lightning", value = 1 }
            end
        elseif card.type == "effect" then
            for _, e in ipairs(card.effects or {}) do effect(e) end
        end
        R.cards[#R.cards + 1] = entry
    end

    R.lethal = E.health <= 0 and R.enemyHealth > 0
    R.enemyHealthAfter = E.health
    return R
end

-- ============================================================================
-- Dicas de combo (o que a selecao dispara e o que falta pra disparar)
-- ============================================================================

-- O que `card` GANHARIA de combo se entrasse agora no fim da selecao:
-- lista de { combo = regra, value = bonus } (Saraivada/Muralha/Par). O selo da
-- mao e a linha de hover do painel leem daqui.
function DamagePreview.combosAddedBy(selected, card, game)
    local with = {}
    for _, c in ipairs(selected or {}) do with[#with + 1] = c end
    with[#with + 1] = card
    local out = {}
    for _, rule in ipairs(ComboSystem.RULES) do
        local b = ComboSystem.ruleBonusFor(rule, card, with, game)
        if b > 0 then out[#out + 1] = { combo = rule, value = b } end
    end
    return out
end

return DamagePreview
