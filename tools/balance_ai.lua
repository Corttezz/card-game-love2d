-- tools/balance_ai.lua
-- CEREBRO v6 do piloto (Out/2026, frente de balanceamento).
--
-- O v5 (tools/autoplay.lua) decidia o turno por PASSOS heuristicos em ordem
-- fixa (lethal > scaling > cura > emergencia > dano > defesa > orbes > sobra).
-- Cada passo era sensato isolado, mas a ORDEM decidia por ele: um turno em que
-- valia mais aplicar Fraco do que socar, ou evocar em vez de canalizar, so
-- acontecia se a heuristica certa estivesse na frente.
--
-- O v6 troca a ordem fixa por BUSCA: enumera TODOS os subconjuntos jogaveis da
-- mao dentro da mana, simula cada um com o pipeline do jogo (combos reais,
-- coringas com largest-wins, Forca por golpe, Vulneravel amplificando o resto
-- da leva, orbes canalizando/estourando/pulsando, espinhos, veneno tickando
-- DEPOIS do golpe inimigo, Fraco reduzindo o golpe congelado) e escolhe o de
-- maior VALOR.
--
-- O VALOR fala uma lingua so: HP. O turno custa o HP que o golpe anunciado
-- tira agora, e o que resta da luta custa o HP que o inimigo ainda vai tirar
-- ate morrer: (vida restante do inimigo / dano por turno) x (dano liquido que
-- ele causa por turno). Dano, Forca, veneno, Vulneravel e orbes reduzem o
-- primeiro termo; Bloqueio, Fraco e Destreza reduzem o segundo; matar zera
-- tudo. Sem pesos arbitrarios entre "atacar" e "defender" — a conta decide.

local TagSystem   = require("src.systems.TagSystem")
local ComboSystem = require("src.systems.ComboSystem")
local EffectSystem = require("src.systems.EffectSystem")

local AI = {}

-- ============================================================
-- helpers
-- ============================================================

local function hasEff(card, t)
    for _, e in ipairs(card.effects or {}) do
        if e.type == t then return e end
    end
    return nil
end

local function statusOf(enemy, name)
    for _, st in ipairs(enemy.statusEffects or {}) do
        if st.name == name and (st.duration or 0) > 0 then
            return st.stacks or 1, st.duration or 0
        end
    end
    return 0, 0
end

local function focusOf(p)
    return (p.getBuffStacks and p:getBuffStacks("focus")) or 0
end

local function jokerList(game) return game.jokerSlots or {} end

-- multiplicador de cura dos coringas (produto, com floor no fim — EffectSystem)
local function healMult(game)
    local m = 1
    for _, j in ipairs(jokerList(game)) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "heal_multiplier" then m = m * (e.value or 1) end
        end
    end
    return m
end

local function jokerMods(game, ctype)
    local bestMult, flat = nil, 0
    for _, joker in ipairs(jokerList(game)) do
        for _, e in ipairs(joker.effects or {}) do
            if ctype == "attack" then
                if e.type == "damage_multiplier" and e.target == "attack" then
                    if not bestMult or e.value > bestMult then bestMult = e.value end
                elseif e.type == "damage_bonus" then flat = flat + (e.value or 1) end
            elseif ctype == "defense" then
                if e.type == "defense_multiplier" and e.target == "defense" then
                    if not bestMult or e.value > bestMult then bestMult = e.value end
                elseif e.type == "defense_bonus" then flat = flat + (e.value or 1) end
            end
        end
    end
    return bestMult or 1, flat
end

local function hasJokerEffect(game, t)
    for _, j in ipairs(jokerList(game)) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == t then return e, j end
        end
    end
    return nil
end

-- Valor final de UMA carta ataque/defesa (espelho de Game:_resolveCardInCombat
-- computeCardValue): efeitos proprios -> stat (por golpe; scaling = dobro) ->
-- combos do conjunto -> coringas (largest-wins + flats) -> edition -> seal.
function AI.cardValue(game, card, ctx, stat)
    local base, scalingType
    if card.type == "attack" then base, scalingType = card.attack or 0, "strength_scaling"
    elseif card.type == "defense" then base, scalingType = card.defense or 0, "dexterity_scaling"
    else return 0 end
    if base <= 0 then return 0 end
    local v = base
    for _, e in ipairs(card.effects or {}) do
        if e.type == "damage_bonus_self" and card.type == "attack" then v = v + (e.value or 1)
        elseif e.type == "multi_hit" and card.type == "attack" then v = v * math.max(1, e.value or 1) end
    end
    local s = stat or 0
    if hasEff(card, scalingType) then s = s * 2 end
    v = v + s * EffectSystem.hitCount(card)
    if ctx then v = ComboSystem.applyToCardValue(card, v, ctx) end
    local mult, flat = jokerMods(game, card.type)
    v = v * mult + flat
    if card.edition == "foil" then v = v + 5
    elseif card.edition == "holo" then v = v * 1.2
    elseif card.edition == "polychrome" then v = v * 1.5 end
    if card.seal == "Red" then v = v * 2 end
    -- Debuffs do INIMIGO no jogador (kit Out/2026): Fraco corta o ataque,
    -- Frágil corta a defesa — mesma conta (e mesma ordem: por último) do
    -- Game:_resolveCardInCombat.
    local pl = game and game.player
    if pl and pl.hasDebuff then
        if card.type == "attack" and pl:hasDebuff("weak") then
            return math.floor(math.floor(v) * 0.75)
        elseif card.type == "defense" and pl:hasDebuff("frail") then
            return math.floor(math.floor(v) * 0.75)
        end
    end
    return math.floor(v)
end

-- Ordem de jogada dentro da leva: quem PREPARA vem antes de quem COLHE.
-- debuff (Vulneravel/Fraco) > buff (Forca/Destreza/Foco/mana) > canalizar >
-- resto (defesa, cura, compra) > ataques (maior primeiro: Eco dobra o 1o) >
-- evocar.
local function playRank(c)
    if hasEff(c, "apply_debuff") and (c.attack or 0) <= 0 then return 0 end
    if hasEff(c, "gain_strength") or hasEff(c, "gain_dexterity")
        or hasEff(c, "apply_buff") or hasEff(c, "increase_max_mana") then
        if (c.attack or 0) <= 0 then return 1 end
    end
    if hasEff(c, "evoke_orb") or hasEff(c, "evoke_all_orbs") then return 5 end
    if hasEff(c, "channel_orb") and (c.attack or 0) <= 0 then return 2 end
    if c.type == "attack" then return 4 end
    return 3
end

function AI.sortForPlay(set)
    local out = {}
    for i, c in ipairs(set) do out[i] = c end
    table.sort(out, function(x, y)
        local rx, ry = playRank(x), playRank(y)
        if rx ~= ry then return rx < ry end
        if x.type == "attack" and y.type == "attack" then
            return (x.attack or 0) * EffectSystem.hitCount(x)
                > (y.attack or 0) * EffectSystem.hitCount(y)
        end
        return tostring(x.id) < tostring(y.id)
    end)
    return out
end

-- ============================================================
-- Contexto de BATALHA: estimativas do deck que alimentam o "custo do resto"
-- ============================================================

local function allBattleCards(game)
    local list = {}
    for _, src in ipairs({ game.hand or {}, game.deck or {}, game.discard or {} }) do
        for _, c in ipairs(src) do list[#list + 1] = c end
    end
    return list
end

-- Estimativa de dano/bloqueio por turno do DECK (sem estado de batalha).
function AI.deckProfile(game)
    local cards = allBattleCards(game)
    local n = math.max(1, #cards)
    local mana = (game.player and game.player.maxMana) or 3
    local hand = 5
    local dmgPerMana, blkPerMana, atkCards, defCards, hits = 0, 0, 0, 0, 0
    local nAtk, nDef = 0, 0
    for _, c in ipairs(cards) do
        local cost = math.max(1, c.cost or 1)
        if c.type == "attack" and (c.attack or 0) > 0 then
            nAtk = nAtk + 1
            local d = (c.attack or 0) * EffectSystem.hitCount(c)
            dmgPerMana = dmgPerMana + d / cost
            hits = hits + EffectSystem.hitCount(c)
        elseif c.type == "defense" and (c.defense or 0) > 0 then
            nDef = nDef + 1
            blkPerMana = blkPerMana + (c.defense or 0) / cost
        end
        for _, e in ipairs(c.effects or {}) do
            if e.type == "magic_damage" or e.type == "aoe_magic_damage" then
                dmgPerMana = dmgPerMana + (e.value or 0) / cost; nAtk = nAtk + 0.5
            elseif e.type == "add_armor" then
                blkPerMana = blkPerMana + (e.value or 0) / cost; nDef = nDef + 0.5
            end
        end
    end
    local atkShare = nAtk / n
    local defShare = nDef / n
    local avgDmgPM = nAtk > 0 and dmgPerMana / nAtk or 5
    local avgBlkPM = nDef > 0 and blkPerMana / nDef or 5
    -- mana dividida entre ataque e defesa ~ pela composicao do deck
    local atkMana = mana * math.min(1, atkShare / math.max(0.01, atkShare + defShare) + 0.15)
    local prof = {
        dpt = math.max(3, avgDmgPM * atkMana),
        bpt = avgBlkPM * (mana - atkMana) * 0.9,
        attacksPerTurn = math.min(hand * atkShare, mana),
        hitsPerAttack = nAtk > 0 and math.max(1, hits / math.max(1, nAtk)) or 1,
        defsPerTurn = math.min(hand * defShare, mana),
        deckSize = n,
        -- Bloqueio que o deck consegue por turno se PRIORIZAR defesa (limitado
        -- pelas cartas de defesa que chegam na mao e pela mana).
        maxBlock = (function()
            local defs = math.min(mana, math.max(0.5, hand * defShare) * 1.2)
            local b = avgBlkPM * defs
            -- 2+ defesas na mesma leva: Muralha x1.4 + Torre +6 por carta
            if defs >= 1.8 then b = b * 1.4 + 6 * defs end
            return b
        end)(),
    }
    return prof
end

function AI.newBattle(game)
    return {
        prof = AI.deckProfile(game),
        dealt = 0, turns = 0,
        -- vazamento medido: HP perdido / golpe anunciado, nos turnos de ataque
        hitTurns = 0, incSum = 0, lostSum = 0,
    }
end

-- Fracao do golpe medio que passa nos turnos futuros: estimada pelo bloqueio
-- que o deck consegue (deck de muralha vaza pouco, deck de ataque vaza muito)
-- e corrigida pelo que a batalha MEDIU. Uma constante unica (0.65) fazia o
-- guerreiro de muralha correr atras de dano no A3+ em vez de segurar o golpe.
function AI.leakOf(bctx, inc)
    local est = 1 - 0.8 * (bctx.prof.maxBlock or 0) / math.max(1, inc)
    est = math.max(0.15, math.min(0.9, est))
    if bctx.hitTurns >= 2 and bctx.incSum > 0 then
        local meas = bctx.lostSum / bctx.incSum
        est = 0.5 * est + 0.5 * math.max(0.05, math.min(1, meas))
    end
    return est
end

-- dano por turno usado no custo do resto: blend do perfil com o medido
local function dptOf(bctx)
    local est = bctx.prof.dpt
    if bctx.turns >= 2 then
        local meas = bctx.dealt / bctx.turns
        return math.max(3, 0.5 * est + 0.5 * meas)
    end
    return math.max(3, est)
end

-- dano esperado por turno do inimigo (mistura de intents: 50% attack, 16%
-- strong x1.6, 34% defend/buff) — so o FUTURO usa isto; o turno atual usa o
-- intent congelado de verdade.
local function avgIncoming(enemy)
    -- Kit do inimigo (Out/2026): media ponderada dos golpes dele — o kit
    -- define quanto cada criatura bate (multi-golpe, perfurante, carga).
    if enemy.expectedDamagePerTurn then
        return enemy:expectedDamagePerTurn() + 0.3
    end
    -- (Buff soma +2 permanente: ~0.3/turno de crescimento medio.)
    return (enemy.damage or 0) * (0.50 + 0.16 * 1.6) + 0.3
end

-- ============================================================
-- SIMULACAO de um conjunto (uma leva + fim do turno + golpe inimigo)
-- ============================================================

local function copyOrbs(list)
    local out = {}
    for i, o in ipairs(list or {}) do out[i] = { type = o.type, value = o.value } end
    return out
end

-- NÉVOA DE INTENÇÃO (Out/2026, src/systems/IntentVisibility.lua): o piloto
-- DECIDE com o que o jogador VÊ. Devolve o golpe que vem como ele é
-- conhecido: { perHit, hits, pierce, armor, known }.
--   full       números congelados (Vulnerável congelado entra, como no HUD);
--   type_only  o TIPO é conhecido: golpe de dano vira a média do kit
--              (expectedDamagePerTurn) em 1 golpe; defender vira o bloqueio
--              padrão; buff/cura/debuff/carga = 0 de dano; perfurante é tipo,
--              então segue conhecido;
--   hidden     média do kit, sem perfurante nem bloqueio.
-- MEDIÇÃO (diag/incSum do autoplay) continua lendo o real — só a escolha de
-- cartas passa por aqui. Sem kit (testes antigos) cai no contrato legado.
local DAMAGE_KINDS = { attack = true, strong = true, multi = true }
function AI.knownThreat(e, p)
    local th = { perHit = 0, hits = 0, pierce = false, armor = 0, known = true }
    local it = e.getKnownIntent and e:getKnownIntent(p) or (e.getIntent and e:getIntent()) or nil
    if not it then
        local kind = e.nextIntent or "attack"
        if kind == "attack" or kind == "strong" then
            th.perHit, th.hits = e.nextIntentDamage or e.damage or 0, 1
            if kind == "strong" then th.perHit = math.floor(th.perHit * 1.6) end
        elseif kind == "defend" then
            th.armor = e.getDefendAmount and e:getDefendAmount() or 6
        end
        return th
    end
    if it.hidden then
        th.known = false
        local vis = it.visibility or "hidden"
        local expected = math.ceil(e.expectedDamagePerTurn and e:expectedDamagePerTurn() or (e.damage or 0))
        if vis == "hidden" or DAMAGE_KINDS[it.kind] then
            th.perHit, th.hits = expected, 1
        end
        if vis == "type_only" then
            th.pierce = it.pierce and true or false
            if it.kind == "defend" then
                th.armor = e.getDefendAmount and e:getDefendAmount() or 0
            end
        end
        return th
    end
    th.perHit, th.hits, th.pierce = it.perHit or 0, it.hits or 0, it.pierce and true or false
    if it.vuln and p and p.hasDebuff and p:hasDebuff("vulnerable") then
        th.perHit = math.floor(th.perHit * 1.5)
    end
    th.armor = it.armor or 0
    return th
end

function AI.simulate(game, set, bctx, opts)
    opts = opts or {}
    local p, e = game.player, game.enemy
    local S = {
        eHp = e.health, eArmor = e.armor or 0,
        vuln = e:hasStatus("vulnerable"), weak = e:hasStatus("weak"),
        str = p.strength or 0, dex = p.dexterity or 0, focus = focusOf(p),
        armor = p.armor or 0, maxArmor = p.maxArmor or 30,
        hp = p.health, maxHp = p.maxHealth,
        orbs = copyOrbs(p.orbs), slots = p.orbSlots or 3,
        thorn = (p.getBuffStacks and p:getBuffStacks("thorn")) or 0,
        drawn = 0, manaGain = 0, maxManaGain = 0, selfDmg = 0, healed = 0,
        exhausts = 0, strGain = 0, dexGain = 0, focusGain = 0,
        vulnAdd = 0, weakAdd = 0, discards = 0, mystery = 0,
        echoUsed = game._echoFiredThisTurn and true or false,
        toxinUsed = game._toxinAppliedThisTurn and true or false,
    }
    local _, vulnDur0 = statusOf(e, "vulnerable")
    local _, weakDur0 = statusOf(e, "weak")
    local pSt, pDur = statusOf(e, "poison")
    local bSt, bDur = statusOf(e, "burn")
    S.poison, S.poisonDur = pSt, pDur
    S.burn, S.burnDur = bSt, bDur
    local thornFired = {}
    for k, v in pairs(game._jokerThornFiredThisTurn or {}) do thornFired[k] = v end
    local hm = healMult(game)
    local function heal(v)
        local amt = math.floor(v * hm)
        local real = math.min(amt, S.maxHp - S.hp)
        S.hp = S.hp + real
        S.healed = S.healed + real
    end
    local function hit(d)
        if d <= 0 or S.eHp <= 0 then return end
        if S.vuln then d = math.floor(d * 1.5) end
        local eff = math.max(0, d - S.eArmor)
        S.eArmor = math.max(0, S.eArmor - d)
        S.eHp = S.eHp - eff
    end
    local function addPoison(st, dur)
        S.poison = S.poison + st
        S.poisonDur = S.poisonDur + dur
    end
    local function evoke(o)
        local v = (o.value or 1) + S.focus
        if o.type == "lightning" or o.type == "dark" then
            hit(EffectSystem.orbEvokeValue(o, S.focus))
        elseif o.type == "fire" then
            hit(EffectSystem.orbEvokeValue(o, S.focus)); S.burn = S.burn + math.max(1, math.floor(v / 2)); S.burnDur = S.burnDur + 2
        elseif o.type == "ice" then S.armor = math.min(S.maxArmor, S.armor + v)
        elseif o.type == "holy" then heal(v) end
    end
    local function channel(t, v)
        if #S.orbs >= S.slots then evoke(table.remove(S.orbs, 1)) end
        S.orbs[#S.orbs + 1] = { type = t, value = v }
    end

    -- combos do conjunto (modulo real)
    local ctx = { allSelectedCards = set, tagCounts = TagSystem.countAllTags(set), game = game }
    ComboSystem.detect(ctx, game)

    -- Impeto do guerreiro: decide ANTES de resolver (applyClassTurnPassives)
    if game.selectedClass == "warrior" and not game._impetusFiredThisTurn then
        local atks = game._attacksThisTurn or 0
        for _, c in ipairs(set) do if (c.attack or 0) > 0 then atks = atks + 1 end end
        if atks >= require("src.core.Game").IMPETUS_ATTACKS then S.str = S.str + 1; S.strGain = S.strGain + 1 end
    end
    -- Toxinas do ladino (Out/2026): 2+ ataques no turno = +TOXIN_GROWTH na passiva
    local toxin = math.max(1, (game.classPassiveTier and game:classPassiveTier() or 1)
        + (require("src.core.Game").ROGUE_POISON_OFFSET or 0)) + (game._toxinBonus or 0)
    if game.selectedClass == "rogue" and not game._toxinGrowFiredThisTurn then
        local atks = game._attacksThisTurn or 0
        for _, c in ipairs(set) do if (c.attack or 0) > 0 then atks = atks + 1 end end
        if atks >= 2 then toxin = toxin + require("src.core.Game").TOXIN_GROWTH end
    end

    local onAtkHeal, onAtkDebuffs = 0, {}
    for _, j in ipairs(jokerList(game)) do
        for _, ef in ipairs(j.effects or {}) do
            if ef.type == "on_attack_heal" then onAtkHeal = onAtkHeal + (ef.value or 0)
            elseif ef.type == "on_attack_debuff" then onAtkDebuffs[#onAtkDebuffs + 1] = ef end
        end
    end
    local echoEff = hasJokerEffect(game, "echo_first_attack")

    for _, c in ipairs(AI.sortForPlay(set)) do
        if c.exhaust then S.exhausts = S.exhausts + 1 end
        if c.type == "attack" then
            if S.eHp > 0 then
                local v = AI.cardValue(game, c, ctx, S.str)
                if echoEff and not S.echoUsed then
                    S.echoUsed = true
                    v = math.floor(v * (echoEff.value or 2))
                end
                hit(v)
                if game.selectedClass == "rogue" and not S.toxinUsed and S.eHp > 0 then
                    S.toxinUsed = true; addPoison(toxin, 2)
                end
                if onAtkHeal > 0 then heal(onAtkHeal) end
                for _, ef in ipairs(onAtkDebuffs) do
                    if (ef.debuffName or "poison") == "poison" then
                        addPoison(ef.stacks or 1, ef.duration or 2)
                    end
                end
                for _, ef in ipairs(c.effects or {}) do
                    if ef.type == "on_attack_heal" then heal(ef.value or 0)
                    elseif ef.type == "on_attack_debuff" and (ef.debuffName or "poison") == "poison" then
                        addPoison(ef.stacks or 1, ef.duration or 2)
                    end
                end
            end
        elseif c.type == "defense" then
            local v = AI.cardValue(game, c, ctx, S.dex)
            S.armor = math.min(S.maxArmor, S.armor + v)
            for _, ef in ipairs(c.effects or {}) do
                if ef.type == "on_defend_damage" then S.thorn = S.thorn + (ef.value or 0) end
            end
            for _, j in ipairs(jokerList(game)) do
                for _, ef in ipairs(j.effects or {}) do
                    if ef.type == "on_defend_damage" then
                        local jid = j.id or j
                        if not thornFired[jid] then
                            thornFired[jid] = true
                            S.thorn = S.thorn + (ef.value or 0)
                        end
                    end
                end
            end
        end
        -- efeitos secundarios (ataque/defesa/efeito), na ordem dos dados
        for _, ef in ipairs(c.effects or {}) do
            local t, v = ef.type, ef.value
            if t == "instant_heal" then heal(v or 0)
            elseif t == "self_damage" then S.hp = S.hp - (v or 0); S.selfDmg = S.selfDmg + (v or 0)
            elseif t == "restore_mana" then S.manaGain = S.manaGain + (v or 0)
            elseif t == "increase_max_mana" then
                S.maxManaGain = S.maxManaGain + (v or 0); S.manaGain = S.manaGain + (v or 0)
            elseif t == "add_armor" then S.armor = math.min(S.maxArmor, S.armor + (v or 0))
            elseif t == "magic_damage" or t == "aoe_magic_damage" then hit(v or 0)
            elseif t == "draw_cards" then S.drawn = S.drawn + (v or 0)
            elseif t == "discard_cards" then S.discards = S.discards + (v or 0)
            elseif t == "apply_debuff" then
                if v == "poison" then addPoison(ef.stacks or 1, ef.duration or 2)
                elseif v == "vulnerable" then S.vuln = true; S.vulnAdd = S.vulnAdd + (ef.duration or 2)
                elseif v == "weak" then S.weak = true; S.weakAdd = S.weakAdd + (ef.duration or 2) end
            elseif t == "apply_buff" and v == "focus" then
                S.focus = S.focus + (ef.stacks or 1); S.focusGain = S.focusGain + (ef.stacks or 1)
            elseif t == "gain_strength" then S.str = S.str + (v or 0); S.strGain = S.strGain + (v or 0)
            elseif t == "gain_dexterity" then S.dex = S.dex + (v or 0); S.dexGain = S.dexGain + (v or 0)
            elseif t == "channel_orb" then channel(ef.orbType or "lightning", v or 1)
            elseif t == "evoke_orb" then
                if #S.orbs > 0 then evoke(table.remove(S.orbs, 1)) end
            elseif t == "evoke_all_orbs" then
                while #S.orbs > 0 do evoke(table.remove(S.orbs, 1)) end
            elseif t == "mystery" then S.mystery = S.mystery + 1
            end
        end
    end

    -- combos de EVENTO (uma vez por leva)
    for _, combo in ipairs(ctx.activeCombos or {}) do
        local b = combo.bonus
        if b then
            if b.type == "apply_debuff" and (b.debuff or "poison") == "poison" then
                addPoison(b.stacks or 1, b.duration or 2)
            elseif b.type == "heal" then heal(b.value or 0)
            elseif b.type == "evoke_on_combo" then
                if #S.orbs > 0 then evoke(table.remove(S.orbs, 1)) end
            end
        end
    end

    S.preEndHp = S.eHp
    local endsTurn = not opts.noEndTurn
    if endsTurn and S.eHp > 0 then
        -- pulso dos orbes (fim do turno do jogador, ANTES do inimigo)
        for _, o in ipairs(S.orbs) do
            local pv = EffectSystem.orbPulseValue({ type = o.type, value = o.value }, S.focus)
            if o.type == "lightning" or o.type == "fire" then hit(pv)
            elseif o.type == "ice" then S.armor = math.min(S.maxArmor, S.armor + pv)
            elseif o.type == "holy" then heal(pv)
            elseif o.type == "dark" then o.value = (o.value or 1) + 2 end
        end
    end
    S.lethal = S.eHp <= 0

    -- golpe inimigo (intent CONGELADO) + espinhos + DoT
    S.hpLoss = 0
    S.killedAfterHit = false
    if endsTurn and not S.lethal then
        local eArmorAtk = 0  -- armadura do inimigo EXPIRA no inicio do turno dele
        S.eArmor = eArmorAtk
        -- Intent CONGELADO do kit (Out/2026): golpes x dano por golpe,
        -- perfurante, bloqueio do proprio inimigo e debuffs no jogador — como
        -- o JOGADOR o conhece (névoa de intenção: AI.knownThreat).
        local th = AI.knownThreat(e, p)
        local perHit, hits, pierce = th.perHit, th.hits, th.pierce
        S.eArmor = th.armor
        if S.weak and perHit > 0 then perHit = math.floor(perHit * 0.75) end
        local dmg = perHit * hits
        if dmg > 0 then
            if pierce then
                S.hpLoss = dmg
                S.armorLeft = S.armor
            else
                S.hpLoss = math.max(0, dmg - S.armor)
                S.armorLeft = math.max(0, S.armor - dmg)
            end
            if S.thorn > 0 then
                -- reflexo nao passa pelo Vulneravel? passa: takeDamage
                hit(S.thorn)
            end
        else
            S.armorLeft = S.armor
        end
        -- Veneno/queimadura NO JOGADOR ticam no upkeep seguinte (ignoram o
        -- Bloqueio): o que ja esta nele + o que este golpe aplica.
        if p.getDebuffStacks then
            local pdot = p:getDebuffStacks("poison") + p:getDebuffStacks("burn")
            for _, d in ipairs((it and it.debuffs) or {}) do
                if d.name == "poison" or d.name == "burn" then pdot = pdot + (d.stacks or 0) end
            end
            S.hpLoss = S.hpLoss + pdot
        end
        -- DoT no fim do turno do inimigo (IGNORA a armadura — Enemy:_applyDot)
        if S.eHp > 0 then
            local dot = (S.poisonDur > 0 and S.poison or 0) + (S.burnDur > 0 and S.burn or 0)
            S.eHp = S.eHp - dot
            if S.poisonDur > 0 then S.poisonDur = S.poisonDur - 1 end
            if S.burnDur > 0 then S.burnDur = S.burnDur - 1 end
        end
        S.killedAfterHit = S.eHp <= 0
    end
    return S
end

-- ============================================================
-- VALOR (em HP) de um resultado simulado
-- ============================================================

function AI.score(game, set, S, bctx)
    local p, e = game.player, game.enemy
    local dpt = dptOf(bctx)
    local inc = avgIncoming(e)
    local prof = bctx.prof

    -- morte do jogador neste turno = pior resultado possivel
    if S.hp - S.hpLoss <= 0 then return -1e9 + S.eHp end

    if S.lethal then
        -- todos os lethais sao bons; prefere gastar menos recurso de uso unico
        return 1e6 + S.hp - S.exhausts * 3 - #set * 0.01
    end

    -- ---- o resto da luta ----
    local eLeft = math.max(0, S.eHp)
    -- orbes: pulso por turno (raio/fogo) entra no dpt; o evoke eventual
    -- e a sombra crescendo descontam da vida
    local orbDpt, orbBlk, orbHeal = 0, 0, 0
    for _, o in ipairs(S.orbs) do
        local pv = EffectSystem.orbPulseValue({ type = o.type, value = o.value }, S.focus)
        if o.type == "lightning" or o.type == "fire" then
            orbDpt = orbDpt + pv
            eLeft = eLeft - ((o.value or 1) + S.focus) * 0.5
        elseif o.type == "ice" then orbBlk = orbBlk + pv
        elseif o.type == "holy" then orbHeal = orbHeal + pv
        elseif o.type == "dark" then
            eLeft = eLeft - ((o.value or 1) + 2 + S.focus) * 2 * 0.6
        end
    end
    local strBonus = S.strGain * prof.attacksPerTurn * prof.hitsPerAttack
    -- Vulneravel que ainda vale no PROXIMO turno amplia o proximo turno de dano
    local vulnNext = (S.vulnAdd > 1) and 0.5 * dpt * math.min(S.vulnAdd - 1, 2) or 0
    eLeft = eLeft - vulnNext
    local futDpt = dpt + strBonus + orbDpt
    local manaPerTurn = math.max(1, p.maxMana or 3)
    if S.maxManaGain > 0 then futDpt = futDpt * (1 + S.maxManaGain / manaPerTurn) end
    -- TEMPO ATE MATAR, turno a turno. O DoT NAO e um desconto instantaneo
    -- da vida: veneno empilha stacks E duracao (Enemy:addStatusEffect), entao
    -- 12 stacks x 12 turnos "valem" 144 mas chegam 12 por turno. A 1a versao
    -- descontava tudo de uma vez, achava a luta ganha (T=0) e o ladino
    -- PASSAVA o turno com 5 de mana e 5 cartas na mao.
    local T
    do
        local hpLeft = math.max(0, eLeft)
        local pst, pdur = S.poison, math.max(0, S.poisonDur)
        local bst, bdur = S.burn, math.max(0, S.burnDur)
        local d = math.max(1, futDpt)
        local t = 0
        while hpLeft > 0 and t < 40 do
            local tick = d
            if pdur > 0 then tick = tick + pst * 0.9; pdur = pdur - 1 end
            if bdur > 0 then tick = tick + bst * 0.9; bdur = bdur - 1 end
            if hpLeft <= tick then
                t = t + hpLeft / tick
                hpLeft = 0
            else
                hpLeft = hpLeft - tick
                t = t + 1
            end
        end
        T = t
    end

    -- dano liquido por turno que o inimigo ainda causa
    -- Fracao do golpe medio que PASSA nos turnos futuros. Nao sai do perfil
    -- do deck: bloquear custa a MESMA mana que atacar, e a conta "dpt do
    -- ataque + bpt da defesa" contava a mana duas vezes (a 1a versao do v6
    -- achava a luta quase gratis e trocava dano por cura inutil).
    local LEAK = AI.leakOf(bctx, inc)
    local blkExtra = S.dexGain * prof.defsPerTurn + orbBlk
    local netIn = math.max(0.15 * inc, inc * LEAK - 0.75 * blkExtra) - orbHeal
    -- o inimigo ESCALA: Buff (+2 permanente) e a Furia do turno 8+
    local growth = 0.16 * 2 * LEAK
    -- Fraco que ainda vale nos proximos turnos
    local weakFuture = (S.weakAdd > 1) and 0.25 * inc * math.min(S.weakAdd - 1, 2) or 0

    local futureLoss = 0
    if not S.killedAfterHit then
        futureLoss = math.max(0, netIn * T + 0.5 * growth * T * T - weakFuture)
    end

    -- ---- o que sobrou pra este turno ----
    local cardVal = (dpt / math.max(1, prof.attacksPerTurn + prof.defsPerTurn)) * (inc / math.max(1, dpt))
    local bonus = 0
    bonus = bonus + S.drawn * cardVal * 0.6
    bonus = bonus + S.manaGain * (dpt / manaPerTurn) * (inc / math.max(1, dpt)) * 0.5
    bonus = bonus + S.mystery * 4
    -- Bloqueio retido (Bastiao) vale no proximo golpe
    if p.retainArmor and S.armorLeft then
        bonus = bonus + math.min(S.armorLeft, inc) * 0.7
    end
    -- carta de uso unico gasta sem necessidade custa um pouco
    bonus = bonus - S.exhausts * 1.5
    -- desempate: entre planos de mesmo valor, o que causa mais dano AGORA
    bonus = bonus + 0.05 * math.max(0, (e.health or 0) - S.eHp)

    return (S.hp - S.hpLoss) - futureLoss + bonus
end

-- ============================================================
-- BUSCA: melhor subconjunto da mao
-- ============================================================

local function playable(game)
    local out = {}
    for _, c in ipairs(game.hand or {}) do
        if c.type ~= "joker" then out[#out + 1] = c end
    end
    return out
end

-- Enumera subconjuntos com custo <= mana (podando por custo). Limite de mao
-- grande: a partir de 12 cartas, so as 12 de maior "valor bruto" entram na
-- busca (2^12 = 4096 avaliacoes ja e o teto razoavel por leva).
function AI.bestSet(game, bctx, opts)
    local cards = playable(game)
    -- orcamento de motor esgotado: carta de PURO ciclo sai da busca (senao
    -- uma Sosia que se paga vira loop infinito de "comprar e comprar")
    if opts and opts.excludeMotor then
        local keep = {}
        for _, c in ipairs(cards) do
            local pure = c.type == "effect" and (hasEff(c, "draw_cards") or hasEff(c, "restore_mana"))
                and not hasEff(c, "channel_orb") and not hasEff(c, "apply_debuff")
                and not hasEff(c, "gain_strength") and not hasEff(c, "gain_dexterity")
            if not pure then keep[#keep + 1] = c end
        end
        cards = keep
    end
    local mana = game.player.mana or 0
    if #cards > 12 then
        table.sort(cards, function(a, b)
            local va = (a.attack or 0) + (a.defense or 0) + #(a.effects or {}) * 3
            local vb = (b.attack or 0) + (b.defense or 0) + #(b.effects or {}) * 3
            return va > vb
        end)
        for i = #cards, 13, -1 do table.remove(cards, i) end
    end
    local best, bestScore, bestS = {}, nil, nil
    local cur = {}
    local evals = 0
    local function consider()
        evals = evals + 1
        local S = AI.simulate(game, cur, bctx)
        local sc = AI.score(game, cur, S, bctx)
        if not bestScore or sc > bestScore + 1e-9 then
            bestScore = sc
            best = {}
            for i, c in ipairs(cur) do best[i] = c end
            bestS = S
        end
    end
    local function rec(i, manaLeft)
        if i > #cards then consider(); return end
        rec(i + 1, manaLeft)
        local c = cards[i]
        local cost = c.cost or 0
        if cost <= manaLeft then
            cur[#cur + 1] = c
            rec(i + 1, manaLeft - cost)
            cur[#cur] = nil
        end
    end
    rec(1, mana)
    return best, bestScore, bestS, evals
end

-- ============================================================
-- DECK BUILDING: quanto uma carta VALE pra ESTE deck
-- ============================================================
-- Moeda: "pontos" da curva de poder da auditoria (tools/audit_cards.lua,
-- ~1 ponto = 1 de dano imediato). Uma carta ocupa MANA e ocupa um ESPACO na
-- mao: o que ela rende acima do que a mesma mana renderia "na media" e o
-- SUPERAVIT. Entra no deck quem melhora a media do deck (deck enxuto compra
-- a carta boa mais vezes — diluir e perder).

local LAMBDA = 5.5   -- pontos que 1 de mana rende numa carta media

-- Combos simples (Out/2026): a Saraivada/Muralha pagam densidade de ATAQUE/
-- DEFESA na mao, o Par paga COPIAS da mesma carta no deck.
local COMBO_TYPE_W = { attack = 0.25, defense = 0.2 }
local PAIR_W = 0.6

local function deckIdsOf(game)
    local out = {}
    local run = game.runManager and game.runManager.currentRun
    for _, e in ipairs((run and run.currentDeck) or {}) do
        out[#out + 1] = type(e) == "table" and e.id or e
    end
    return out
end

function AI.deckContext(game)
    local CardDatabase = require("src.systems.CardDatabase")
    local ids = deckIdsOf(game)
    local tags, n = {}, #ids
    local blockCards, attackCards, scaling, strSrc = 0, 0, 0, 0
    for _, id in ipairs(ids) do
        local cd = CardDatabase:getCard(id)
        if cd then
            for _, t in ipairs(TagSystem.getCardTags(cd)) do tags[t] = (tags[t] or 0) + 1 end
            if cd.type == "defense" or hasEff(cd, "add_armor") then blockCards = blockCards + 1 end
            if cd.type == "attack" then attackCards = attackCards + 1 end
            if hasEff(cd, "gain_strength") or hasEff(cd, "apply_buff")
                or hasEff(cd, "channel_orb") or (hasEff(cd, "apply_debuff")
                and (hasEff(cd, "apply_debuff").value == "poison")) then
                scaling = scaling + 1
            end
            if hasEff(cd, "gain_strength") then strSrc = strSrc + 1 end
        end
    end
    local run = game.runManager and game.runManager.currentRun or {}
    local ctx = { ids = ids, n = n, tags = tags, blockCards = blockCards,
        attackCards = attackCards, scaling = scaling, strSrc = strSrc,
        act = run.actNumber or 1, class = game.selectedClass }
    -- jokers possuidos: flat por ataque/defesa mudam o valor de carta barata
    ctx.atkFlat, ctx.defFlat = 0, 0
    for _, e in ipairs(run.jokers or {}) do
        local jid = type(e) == "table" and e.id or e
        local jd = CardDatabase:getCard(jid)
        for _, ef in ipairs((jd and jd.effects) or {}) do
            if ef.type == "damage_bonus" then ctx.atkFlat = ctx.atkFlat + (ef.value or 0) end
            if ef.type == "defense_bonus" then ctx.defFlat = ctx.defFlat + (ef.value or 0) end
            if ef.type == "on_attack_debuff" then ctx.atkFlat = ctx.atkFlat + 1.5 end
        end
    end
    -- media do deck (a referencia de "melhora o deck?")
    local sum = 0
    for _, id in ipairs(ids) do
        local cd = CardDatabase:getCard(id)
        if cd then sum = sum + AI.cardWorth(game, cd, ctx, true) end
    end
    ctx.avg = n > 0 and sum / n or 0
    return ctx
end

-- Superavit da carta pra ESTE deck. `inDeck` = avaliando carta que ja esta
-- no deck (nao conta a propria carta como "sinergia consigo mesma").
function AI.cardWorth(game, cd, dctx, inDeck)
    if not cd then return -99 end
    if cd.type == "joker" then return 99 end   -- coringa nao dilui (bancada)
    local Audit = require("tools.audit_cards")
    local pts = Audit.cardPoints(cd)
    local hits = 1
    for _, e in ipairs(cd.effects or {}) do
        if e.type == "multi_hit" then hits = e.value or 1 end
    end
    -- coringas de bonus fixo pagam POR carta de ataque/defesa
    if cd.type == "attack" then pts = pts + dctx.atkFlat * hits end
    if cd.type == "defense" then pts = pts + dctx.defFlat end
    -- Forca escala por golpe: quem tem fonte de Forca valoriza ataque multiplo
    if cd.type == "attack" then
        local strExp = math.min(4, dctx.strSrc * 1.5)
        if hasEff(cd, "strength_scaling") then strExp = strExp * 2 end
        pts = pts + strExp * hits * 0.6
    end
    -- passivas de classe
    if dctx.class == "warrior" and cd.type == "attack" and (cd.cost or 0) <= 1 then
        pts = pts + 1.0   -- Impeto: 2 ataques/turno
    elseif dctx.class == "mage" and hasEff(cd, "channel_orb") then
        pts = pts + 1.0   -- Foco da Conduite multiplica orbes
    elseif dctx.class == "rogue" and cd.type == "attack" and (cd.cost or 0) == 0 then
        pts = pts + 0.8   -- Toxinas no 1o ataque, carta gratis abre o turno
    end
    -- sinergia dos combos simples: densidade do tipo (Saraivada/Muralha) e
    -- copias da mesma carta (Par)
    local tw = COMBO_TYPE_W[cd.type]
    if tw then
        local c = ((cd.type == "attack") and dctx.attackCards or dctx.blockCards)
            - (inDeck and 1 or 0)
        pts = pts + tw * math.min(6, c)
        local copies = 0
        for _, id in ipairs(dctx.ids or {}) do if id == cd.id then copies = copies + 1 end end
        if inDeck then copies = copies - 1 end
        pts = pts + PAIR_W * math.min(2, copies)
    end
    -- necessidades do deck
    local n = math.max(1, dctx.n)
    local isBlock = cd.type == "defense" or hasEff(cd, "add_armor") ~= nil
    if isBlock and dctx.blockCards / n < 0.30 then pts = pts + 2.5 end
    if cd.type == "attack" and dctx.attackCards / n < 0.35 then pts = pts + 2.0 end
    local isScaling = hasEff(cd, "gain_strength") or hasEff(cd, "apply_buff")
        or hasEff(cd, "strength_per_turn") or hasEff(cd, "channel_orb")
    if isScaling and dctx.act >= 2 and dctx.scaling < 3 then pts = pts + 2.0 end
    -- exaurir: so 1x por batalha — vale menos em luta longa (atos altos)
    if cd.exhaust or hasEff(cd, "exhaust") then pts = pts * (dctx.act >= 3 and 0.75 or 0.85) end
    return pts - LAMBDA * (cd.cost or 0) + ((cd.cost or 0) == 0 and -1.0 or 0)
end

-- Entra no deck? (recompensa/loja). Margem: deck pequeno aceita carta "media";
-- deck grande so aceita quem MELHORA a media.
-- `marginMul` (pipeline Out/2026): o piloto expert_fast usa a MESMA conta
-- com margem maior — medido, a margem 1x deixa o deck em 16-19 cartas onde a
-- simulacao (expert) para em 10-13, e e o tamanho do deck que separa as
-- taxas de vitoria dos dois.
function AI.wantsCard(game, cd, dctx, marginMul)
    dctx = dctx or AI.deckContext(game)
    if not cd then return false, -99 end
    if cd.type == "joker" then return true, 99 end
    local w = AI.cardWorth(game, cd, dctx, false)
    local margin
    if dctx.n < 8 then margin = -2.0
    elseif dctx.n < 14 then margin = 0.0
    elseif dctx.n < 20 then margin = 1.0
    else margin = 2.5 end
    if marginMul and margin > 0 then margin = margin * marginMul end
    if marginMul and dctx.n >= 10 then margin = margin + (marginMul - 1) * 1.5 end
    return w >= dctx.avg + margin, w
end

-- Pior carta do deck (alvo da tesoura). Nunca a ultima defesa.
function AI.worstCard(game, dctx)
    local CardDatabase = require("src.systems.CardDatabase")
    dctx = dctx or AI.deckContext(game)
    local worst, worstW
    local defs = 0
    for _, id in ipairs(dctx.ids) do
        local cd = CardDatabase:getCard(id)
        if cd and (cd.type == "defense" or hasEff(cd, "add_armor")) then defs = defs + 1 end
    end
    for _, id in ipairs(dctx.ids) do
        local cd = CardDatabase:getCard(id)
        local isDef = cd and (cd.type == "defense" or hasEff(cd, "add_armor"))
        if cd and not (isDef and defs <= 3) then
            local w = AI.cardWorth(game, cd, dctx, true)
            if not worstW or w < worstW then worst, worstW = id, w end
        end
    end
    return worst, worstW
end

-- Carta de MOTOR: compra/mana que, jogada sozinha primeiro, revela a mao nova
-- antes de decidir o resto.
local function isMotor(c)
    return hasEff(c, "draw_cards") ~= nil
        or (hasEff(c, "restore_mana") ~= nil and c.type == "effect")
end

-- Decide a PROXIMA leva do turno. Retorna (picks, motivo) ou ({}, "") pra
-- encerrar o turno.
function AI.planLeva(game, bctx, opts)
    opts = opts or {}
    local best, sc, S = AI.bestSet(game, bctx, { excludeMotor = opts.noMotorSplit })
    if #best == 0 then return {}, "" end
    if S and S.lethal then return best, "LETHAL" end
    if opts.noMotorSplit then return best, "plano" end
    -- motor primeiro: se o melhor plano compra/gera mana, joga SO o motor e
    -- replaneja com a mao nova (o resto do plano pode mudar).
    local motor = {}
    for _, c in ipairs(best) do if isMotor(c) then motor[#motor + 1] = c end end
    if #motor > 0 and #motor < #best then
        return motor, "motor"
    end
    return best, (#motor > 0) and "motor+plano" or "plano"
end

return AI
