local TagSystem   = require("src.systems.TagSystem")
local ComboSystem = require("src.systems.ComboSystem")
local EffectSystem = require("src.systems.EffectSystem")
local Enemy = require("src.entities.Enemy")

local AI = {}

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

local function allBattleCards(game)
    local list = {}
    for _, src in ipairs({ game.hand or {}, game.deck or {}, game.discard or {} }) do
        for _, c in ipairs(src) do list[#list + 1] = c end
    end
    return list
end

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
    local atkMana = mana * math.min(1, atkShare / math.max(0.01, atkShare + defShare) + 0.15)
    local prof = {
        dpt = math.max(3, avgDmgPM * atkMana),
        bpt = avgBlkPM * (mana - atkMana) * 0.9,
        attacksPerTurn = math.min(hand * atkShare, mana),
        hitsPerAttack = nAtk > 0 and math.max(1, hits / math.max(1, nAtk)) or 1,
        defsPerTurn = math.min(hand * defShare, mana),
        deckSize = n,
        maxBlock = (function()
            local defs = math.min(mana, math.max(0.5, hand * defShare) * 1.2)
            local b = avgBlkPM * defs
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
        hitTurns = 0, incSum = 0, lostSum = 0,
    }
end

function AI.leakOf(bctx, inc)
    local est = 1 - 0.8 * (bctx.prof.maxBlock or 0) / math.max(1, inc)
    est = math.max(0.15, math.min(0.9, est))
    if bctx.hitTurns >= 2 and bctx.incSum > 0 then
        local meas = bctx.lostSum / bctx.incSum
        est = 0.5 * est + 0.5 * math.max(0.05, math.min(1, meas))
    end
    return est
end

local function dptOf(bctx)
    local est = bctx.prof.dpt
    if bctx.turns >= 2 then
        local meas = bctx.dealt / bctx.turns
        return math.max(3, 0.5 * est + 0.5 * meas)
    end
    return math.max(3, est)
end

local function avgIncoming(enemy)
    if enemy.expectedDamagePerTurn then
        return enemy:expectedDamagePerTurn() + 0.3
    end
    return (enemy.damage or 0) * (0.50 + 0.16 * 1.6) + 0.3
end

local function copyOrbs(list)
    local out = {}
    for i, o in ipairs(list or {}) do out[i] = { type = o.type, value = o.value } end
    return out
end

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
        S.poisonDur = Enemy.POISON_DECAY and S.poison or (S.poisonDur + dur)
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

    local ctx = { allSelectedCards = set, tagCounts = TagSystem.countAllTags(set), game = game }
    ComboSystem.detect(ctx, game)

    if game.selectedClass == "warrior" and not game._impetusFiredThisTurn then
        local atks = game._attacksThisTurn or 0
        for _, c in ipairs(set) do if (c.attack or 0) > 0 then atks = atks + 1 end end
        if atks >= require("src.core.Game").IMPETUS_ATTACKS then S.str = S.str + 1; S.strGain = S.strGain + 1 end
    end
    local toxin = game.toxinStacks and game:toxinStacks() or 1
    if game.selectedClass == "rogue" and not game._toxinGrowFiredThisTurn then
        local atks = game._attacksThisTurn or 0
        for _, c in ipairs(set) do if (c.attack or 0) > 0 then atks = atks + 1 end end
        if atks >= 2 and game.toxinStacks then
            toxin = game:toxinStacks((game._toxinBonus or 0) + require("src.core.Game").TOXIN_GROWTH)
        end
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
        for _, o in ipairs(S.orbs) do
            local pv = EffectSystem.orbPulseValue({ type = o.type, value = o.value }, S.focus)
            if o.type == "lightning" or o.type == "fire" then hit(pv)
            elseif o.type == "ice" then S.armor = math.min(S.maxArmor, S.armor + pv)
            elseif o.type == "holy" then heal(pv)
            elseif o.type == "dark" then o.value = (o.value or 1) + 2 end
        end
    end
    S.lethal = S.eHp <= 0

    S.hpLoss = 0
    S.killedAfterHit = false
    if endsTurn and not S.lethal then
        local eArmorAtk = 0
        S.eArmor = eArmorAtk
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
                hit(S.thorn)
            end
        else
            S.armorLeft = S.armor
        end
        if p.getDebuffStacks then
            local pdot = p:getDebuffStacks("poison") + p:getDebuffStacks("burn")
            for _, d in ipairs((it and it.debuffs) or {}) do
                if d.name == "poison" or d.name == "burn" then pdot = pdot + (d.stacks or 0) end
            end
            S.hpLoss = S.hpLoss + pdot
        end
        if S.eHp > 0 then
            local dot = (S.poisonDur > 0 and S.poison or 0) + (S.burnDur > 0 and S.burn or 0)
            S.eHp = S.eHp - dot
            if Enemy.POISON_DECAY then
                if S.poison > 0 then S.poison = S.poison - 1 end
                S.poisonDur = S.poison
            elseif S.poisonDur > 0 then S.poisonDur = S.poisonDur - 1 end
            if S.burnDur > 0 then S.burnDur = S.burnDur - 1 end
        end
        S.killedAfterHit = S.eHp <= 0
    end
    return S
end

function AI.mechanicBonus(game, set, S)
    local e = game.enemy
    local BM = require("src.systems.BossMechanics")
    local m = BM.spec(e)
    if not m then return 0 end
    if m.kind == "runes" then
        local T = BM.runeThreshold(e)
        local st = e._mech or {}
        local dealt = (st.turnDmg or 0) + math.max(0, (e.health or 0) - S.eHp)
        local breaks = math.max(0, math.floor(dealt / T) - (st.broke or 0))
        breaks = math.min(breaks, BM.stacks(e, m.status))
        return breaks * 0.5 * (e.baseDamage or e.damage or 0)
    end
    return 0
end

function AI.score(game, set, S, bctx)
    local p, e = game.player, game.enemy
    local dpt = dptOf(bctx)
    local inc = avgIncoming(e)
    local prof = bctx.prof

    if S.hp - S.hpLoss <= 0 then return -1e9 + S.eHp end

    if S.lethal then
        return 1e6 + S.hp - S.exhausts * 3 - #set * 0.01
    end

    local eLeft = math.max(0, S.eHp)
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
    local vulnNext = (S.vulnAdd > 1) and 0.5 * dpt * math.min(S.vulnAdd - 1, 2) or 0
    eLeft = eLeft - vulnNext
    local futDpt = dpt + strBonus + orbDpt
    local manaPerTurn = math.max(1, p.maxMana or 3)
    if S.maxManaGain > 0 then futDpt = futDpt * (1 + S.maxManaGain / manaPerTurn) end
    local T
    do
        local hpLeft = math.max(0, eLeft)
        local pst, pdur = S.poison, math.max(0, S.poisonDur)
        local bst, bdur = S.burn, math.max(0, S.burnDur)
        local d = math.max(1, futDpt)
        local t = 0
        while hpLeft > 0 and t < 40 do
            local tick = d
            if pdur > 0 then
                tick = tick + pst * 0.9
                pdur = pdur - 1
                if Enemy.POISON_DECAY then pst = pst - 1; pdur = pst end
            end
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

    local LEAK = AI.leakOf(bctx, inc)
    local blkExtra = S.dexGain * prof.defsPerTurn + orbBlk
    local netIn = math.max(0.15 * inc, inc * LEAK - 0.75 * blkExtra) - orbHeal
    local growth = 0.16 * 2 * LEAK
    local weakFuture = (S.weakAdd > 1) and 0.25 * inc * math.min(S.weakAdd - 1, 2) or 0

    local futureLoss = 0
    if not S.killedAfterHit then
        futureLoss = math.max(0, netIn * T + 0.5 * growth * T * T - weakFuture)
    end

    local cardVal = (dpt / math.max(1, prof.attacksPerTurn + prof.defsPerTurn)) * (inc / math.max(1, dpt))
    local bonus = 0
    bonus = bonus + S.drawn * cardVal * 0.6
    bonus = bonus + S.manaGain * (dpt / manaPerTurn) * (inc / math.max(1, dpt)) * 0.5
    bonus = bonus + S.mystery * 4
    if p.retainArmor and S.armorLeft then
        bonus = bonus + math.min(S.armorLeft, inc) * 0.7
    end
    bonus = bonus - S.exhausts * 1.5
    bonus = bonus + 0.05 * math.max(0, (e.health or 0) - S.eHp)
    bonus = bonus + AI.mechanicBonus(game, set, S)

    return (S.hp - S.hpLoss) - futureLoss + bonus
end

local function playable(game)
    local out = {}
    for _, c in ipairs(game.hand or {}) do
        if c.type ~= "joker" then out[#out + 1] = c end
    end
    return out
end

function AI.bestSet(game, bctx, opts)
    local cards = playable(game)
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

local LAMBDA = 5.5

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
    local sum = 0
    for _, id in ipairs(ids) do
        local cd = CardDatabase:getCard(id)
        if cd then sum = sum + AI.cardWorth(game, cd, ctx, true) end
    end
    ctx.avg = n > 0 and sum / n or 0
    return ctx
end

function AI.cardWorth(game, cd, dctx, inDeck)
    if not cd then return -99 end
    if cd.type == "joker" then return 99 end
    local Audit = require("tools.audit_cards")
    local pts = Audit.cardPoints(cd)
    local hits = 1
    for _, e in ipairs(cd.effects or {}) do
        if e.type == "multi_hit" then hits = e.value or 1 end
    end
    if cd.type == "attack" then pts = pts + dctx.atkFlat * hits end
    if cd.type == "defense" then pts = pts + dctx.defFlat end
    if cd.type == "attack" then
        local strExp = math.min(4, dctx.strSrc * 1.5)
        if hasEff(cd, "strength_scaling") then strExp = strExp * 2 end
        pts = pts + strExp * hits * 0.6
    end
    if dctx.class == "warrior" and cd.type == "attack" and (cd.cost or 0) <= 1 then
        pts = pts + 1.0
    elseif dctx.class == "mage" and hasEff(cd, "channel_orb") then
        pts = pts + 1.0
    elseif dctx.class == "rogue" and cd.type == "attack" and (cd.cost or 0) == 0 then
        pts = pts + 0.8
    end
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
    local n = math.max(1, dctx.n)
    local isBlock = cd.type == "defense" or hasEff(cd, "add_armor") ~= nil
    if isBlock and dctx.blockCards / n < 0.30 then pts = pts + 2.5 end
    if cd.type == "attack" and dctx.attackCards / n < 0.35 then pts = pts + 2.0 end
    local isScaling = hasEff(cd, "gain_strength") or hasEff(cd, "apply_buff")
        or hasEff(cd, "strength_per_turn") or hasEff(cd, "channel_orb")
    if isScaling and dctx.act >= 2 and dctx.scaling < 3 then pts = pts + 2.0 end
    if cd.exhaust or hasEff(cd, "exhaust") then pts = pts * (dctx.act >= 3 and 0.75 or 0.85) end
    return pts - LAMBDA * (cd.cost or 0) + ((cd.cost or 0) == 0 and -1.0 or 0)
end

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

local function isMotor(c)
    return hasEff(c, "draw_cards") ~= nil
        or (hasEff(c, "restore_mana") ~= nil and c.type == "effect")
end

function AI.planLeva(game, bctx, opts)
    opts = opts or {}
    local best, sc, S = AI.bestSet(game, bctx, { excludeMotor = opts.noMotorSplit })
    if #best == 0 then return {}, "" end
    if S and S.lethal then return best, "LETHAL" end
    if opts.noMotorSplit then return best, "plano" end
    local motor = {}
    for _, c in ipairs(best) do if isMotor(c) then motor[#motor + 1] = c end end
    if #motor > 0 and #motor < #best then
        return motor, "motor"
    end
    return best, (#motor > 0) and "motor+plano" or "plano"
end

return AI
