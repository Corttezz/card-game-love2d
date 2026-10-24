local M = {}

M.policy = "v6"
M.quiet = false

M.PILOTS = {
    naive = { combat = "naive", build = "greedy", path = "random", shop = "impulsive",
        rest = "always_rest", event = "first", bench = false },
    average = { combat = "steps", build = "normal", path = "heuristic", shop = "policy",
        rest = "policy", event = "policy", bench = true,
        pickBase = 0, pickBar = 0.35, shopCards = 1, trimAt = 12 },
    average_v5 = { combat = "steps", build = "v5", path = "heuristic", shop = "policy",
        rest = "policy", event = "policy", bench = true },
    expert = { combat = "search", build = "sim", path = "heuristic", shop = "policy",
        rest = "policy", event = "policy", bench = true },
    expert_fast = { combat = "search", build = "heuristic", path = "heuristic", shop = "policy",
        rest = "policy", event = "policy", bench = true, buildMargin = 2.0 },
    expert_full = { combat = "search", build = "sim", path = "heuristic", shop = "policy",
        rest = "policy", event = "policy", bench = true, simPerFight = 2, simCandidates = 99 },
}
M.PILOTS.v6 = M.PILOTS.expert
M.PILOTS.v5 = M.PILOTS.average_v5
M.PILOTS.v6c = { combat = "search", build = "v5", path = "heuristic", shop = "policy",
    rest = "policy", event = "policy", bench = true }
M.PILOTS.v6b = { combat = "steps", build = "sim", path = "heuristic", shop = "policy",
    rest = "policy", event = "policy", bench = true }

local function prof()
    if M.profile then return M.profile end
    local p = M.PILOTS[M.policy]
    if not p then
        print("[autoplay] piloto desconhecido '" .. tostring(M.policy) .. "' — usando expert")
        p = M.PILOTS.expert
    end
    return p
end
function M.setPilot(name)
    M.policy = name
    M.profile = nil
    return prof()
end
M.pilotName = function() return M.policy end

local function v6Combat() return prof().combat == "search" end
local function v6Build() return prof().build == "sim" end
local function naiveCombat() return prof().combat == "naive" end

local AI = require("tools.balance_ai")
local EventManager = require("engine.EventManager")
local Events       = require("src.data.events")
local MapManager   = require("src.systems.MapManager")
local TagSystem    = require("src.systems.TagSystem")
local ComboSystem  = require("src.systems.ComboSystem")
local Resistances  = require("src.systems.Resistances")

local report = {}
local anomalies = {}
local function anomaly(fmt, ...)
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    table.insert(anomalies, line)
    if not M.quiet then table.insert(report, "  !! ANOMALIA: " .. line) end
    print("[autoplay] !! ANOMALIA: " .. line)
end
local function log(fmt, ...)
    if M.quiet then return end
    local line = select("#", ...) > 0 and fmt:format(...) or fmt
    table.insert(report, line)
end

local function drainPresentation()
    require("src.ui.FloatingText").clear()
    require("src.systems.CardParticles").clear()
    require("src.ui.ComboBanner").clear()
    require("src.ui.OrbRow").clear()
    require("src.ui.CoinBurst").clear()
end
M.drainPresentation = drainPresentation

local function pump(game, secs)
    if M.pumpImpl then return M.pumpImpl(game, secs) end
    drainPresentation()
    local dt = M.pumpDt or (1 / 30)
    for _ = 1, math.max(1, math.floor(secs / dt + 1e-6)) do
        EventManager.update(dt)
        if game.combatAnimationSystem and game.combatAnimationSystem.update then
            game.combatAnimationSystem:update(dt)
        end
        if game.enemy and game.enemy.update then
            game.enemy:update(dt)
        end
        do
            local okER, ER = pcall(require, "src.ui.EnemyRenderer")
            if okER and ER.update then ER.update(dt) end
        end
    end
end

function M.stateSignature(game, label, turn, kind, value)
    local p, e = game.player, game.enemy
    local hand = {}
    for _, c in ipairs(game.hand or {}) do hand[#hand + 1] = tostring(c.id) end
    local st = {}
    for _, s in ipairs((e and e.statusEffects) or {}) do
        st[#st + 1] = ("%s:%s/%s"):format(tostring(s.name), tostring(s.stacks), tostring(s.duration))
    end
    local buffs = {}
    for _, b in ipairs((p and p.buffs) or {}) do
        buffs[#buffs + 1] = ("%s:%s/%s"):format(tostring(b.name), tostring(b.stacks), tostring(b.duration))
    end
    local rngSig = ""
    do
        local okR, Rng = pcall(require, "src.systems.Rng")
        if okR and Rng.hasActive and Rng.hasActive() then
            local parts = {}
            for _, name in ipairs(Rng.STREAMS) do
                local s = Rng.get():getStreamState(name)
                parts[#parts + 1] = name .. "=" .. tostring(s and s.counter) .. ":"
                    .. tostring(s and s.state)
            end
            rngSig = table.concat(parts, ";")
        end
    end
    return table.concat({
        tostring(label), "T" .. tostring(turn),
        ("hp=%d/%d ar=%d mana=%d str=%d dex=%d"):format(p.health, p.maxHealth, p.armor or 0,
            p.mana or 0, p.strength or 0, p.dexterity or 0),
        ("ehp=%d/%d ear=%d"):format(e.health, e.maxHealth or 0, e.armor or 0),
        "intent=" .. tostring(kind) .. ":" .. tostring(value),
        "est=" .. table.concat(st, ","), "buf=" .. table.concat(buffs, ","),
        "orbs=" .. tostring(#(p.orbs or {})),
        "hand=" .. table.concat(hand, ","),
        "gold=" .. tostring(game.economySystem and game.economySystem.currentGold or 0),
        "rng=" .. rngSig,
    }, " | ")
end

local function handSummary(game)
    local parts = {}
    for _, c in ipairs(game.hand) do
        local stat = (c.attack or 0) > 0 and (c.attack .. "atk")
            or (c.defense or 0) > 0 and (c.defense .. "def")
            or c.type
        table.insert(parts, ("%s(%d:%s)"):format(c.name or c.id, c.cost or 0, stat))
    end
    return table.concat(parts, " ")
end

local function hasEffect(card, etype)
    for _, e in ipairs(card.effects or {}) do
        if e.type == etype then return true end
    end
    return false
end

local function hasDebuffEffect(card, which)
    for _, e in ipairs(card.effects or {}) do
        if e.type == "apply_debuff" and e.value == which then return true end
    end
    return false
end

local function hasBuffEffect(card, which)
    for _, e in ipairs(card.effects or {}) do
        if e.type == "apply_buff" and e.value == which then return true end
    end
    return false
end

local function getFocus(p)
    return (p.getBuffStacks and p:getBuffStacks("focus")) or 0
end

local function jokerMods(game, ctype)
    local bestMult, flat = nil, 0
    for _, joker in ipairs(game.jokerSlots or {}) do
        for _, e in ipairs(joker.effects or {}) do
            if ctype == "attack" then
                if e.type == "damage_multiplier" and e.target == "attack" then
                    local v = e.value or 1
                    if not bestMult or v > bestMult then bestMult = v end
                elseif e.type == "damage_bonus" then
                    flat = flat + (e.value or 1)
                end
            elseif ctype == "defense" then
                if e.type == "defense_multiplier" and e.target == "defense" then
                    local v = e.value or 1
                    if not bestMult or v > bestMult then bestMult = v end
                elseif e.type == "defense_bonus" then
                    flat = flat + (e.value or 1)
                end
            end
        end
    end
    return bestMult or 1, flat
end

local function buildCtx(set)
    local ctx = { allSelectedCards = set, tagCounts = TagSystem.countAllTags(set) }
    ComboSystem.detect(ctx)
    return ctx
end

local function withCard(set, extra)
    local out = {}
    for _, c in ipairs(set) do out[#out + 1] = c end
    out[#out + 1] = extra
    return out
end

local function simulateCardValue(game, card, ctx)
    local base, stat, scalingType
    if card.type == "attack" then
        base = card.attack or 0
        stat = game.player.strength or 0
        scalingType = "strength_scaling"
    elseif card.type == "defense" then
        base = card.defense or 0
        stat = game.player.dexterity or 0
        scalingType = "dexterity_scaling"
    else
        return 0
    end
    if base <= 0 then return 0 end
    local v = base
    for _, e in ipairs(card.effects or {}) do
        if e.type == "damage_bonus_self" and card.type == "attack" then
            v = v + (e.value or 1)
        elseif e.type == "multi_hit" and card.type == "attack" then
            v = v * math.max(1, e.value or 1)
        end
    end
    local s = stat
    for _, e in ipairs(card.effects or {}) do
        if e.type == scalingType then s = s * 2; break end
    end
    v = v + s
    if ctx then v = ComboSystem.applyToCardValue(card, v, ctx) end
    local mult, flat = jokerMods(game, card.type)
    v = v * mult + flat
    if card.edition == "foil" then v = v + 5
    elseif card.edition == "holo" then v = v * 1.2
    elseif card.edition == "polychrome" then v = v * 1.5 end
    if card.seal == "Red" then v = v * 2 end
    return math.floor(v)
end

local function playRank(c)
    if hasEffect(c, "apply_debuff") then return 0 end
    if hasEffect(c, "gain_strength") or hasEffect(c, "gain_dexterity")
        or hasEffect(c, "apply_buff") or hasEffect(c, "increase_max_mana") then
        return 1
    end
    if hasEffect(c, "evoke_orb") or hasEffect(c, "evoke_all_orbs") then return 5 end
    if hasEffect(c, "channel_orb") and (c.attack or 0) <= 0 then return 2 end
    if (c.attack or 0) > 0 then return 4 end
    return 3
end

local function sortedForPlay(set)
    local out = {}
    for _, c in ipairs(set) do out[#out + 1] = c end
    table.sort(out, function(x, y) return playRank(x) < playRank(y) end)
    return out
end

local function evokeDmgOfOrb(orb, focus)
    local v = (orb.value or 1) + focus
    if orb.type == "lightning" then return v, "lightning"
    elseif orb.type == "dark" then return v * 2, "dark"
    elseif orb.type == "fire" then return v, "fire" end
    return 0
end

local function simulateSetDamage(game, set)
    if #set == 0 then return 0 end
    local p = game.player
    local focus = getFocus(p)
    local ctx = buildCtx(set)
    local vuln = game.enemy:hasStatus("vulnerable")
    if not vuln then
        for _, c in ipairs(set) do
            if hasDebuffEffect(c, "vulnerable") then vuln = true; break end
        end
    end
    local orbs = {}
    for _, o in ipairs(p.orbs or {}) do
        orbs[#orbs + 1] = { type = o.type, value = o.value }
    end
    local slots = p.orbSlots or 3
    local total = 0
    local function addDmg(d, dtype)
        if d > 0 then
            d = Resistances.apply(game.enemy, dtype, d)
            if vuln then d = math.floor(d * 1.5) end
            total = total + d
        end
    end
    for _, c in ipairs(sortedForPlay(set)) do
        if c.type == "attack" then
            addDmg(simulateCardValue(game, c, ctx), Resistances.ofCard(c))
        end
        for _, e in ipairs(c.effects or {}) do
            if e.type == "magic_damage" or e.type == "aoe_magic_damage" then
                addDmg(e.value or 0, Resistances.ofSpell(c))
            elseif e.type == "channel_orb" then
                if #orbs >= slots then
                    addDmg(evokeDmgOfOrb(table.remove(orbs, 1), focus))
                end
                orbs[#orbs + 1] = { type = e.orbType or "lightning", value = e.value or 1 }
            elseif e.type == "evoke_orb" then
                if #orbs > 0 then
                    addDmg(evokeDmgOfOrb(table.remove(orbs, 1), focus))
                end
            elseif e.type == "evoke_all_orbs" then
                while #orbs > 0 do
                    addDmg(evokeDmgOfOrb(table.remove(orbs, 1), focus))
                end
            end
        end
    end
    return total
end

local function freeDamageThisTurn(game)
    local enemy = game.enemy
    local poison = enemy:hasStatus("poison") and enemy:getStatusStacks("poison") or 0
    local freePoison = Resistances.apply(enemy, "poison", poison)
    local p = game.player
    local focus = getFocus(p)
    local pulse = 0
    for _, orb in ipairs(p.orbs or {}) do
        local ev = (orb.value or 1) + focus
        if orb.type == "lightning" then
            pulse = pulse + Resistances.apply(enemy, "lightning", math.ceil(ev / 2))
        elseif orb.type == "fire" then
            pulse = pulse + Resistances.apply(enemy, "fire", math.ceil(ev / 3))
        end
    end
    return freePoison + pulse, freePoison, pulse
end

local function healValue(game, card)
    local v = 0
    for _, e in ipairs(card.effects or {}) do
        if e.type == "instant_heal" then v = v + (e.value or 0) end
    end
    if v <= 0 then return 0 end
    local mult = 1
    for _, j in ipairs(game.jokerSlots or {}) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "heal_multiplier" then mult = mult * (e.value or 1) end
        end
    end
    return math.floor(v * mult)
end

local function healPassesGate(game, card)
    local v = healValue(game, card)
    if v <= 0 then return false end
    local missing = game.player.maxHealth - game.player.health
    return missing >= v * 0.6
end

local function multJokerStats(game)
    local n, best = 0, 1
    for _, j in ipairs(game.jokerSlots or {}) do
        for _, e in ipairs(j.effects or {}) do
            if e.type == "damage_multiplier" or e.type == "defense_multiplier" then
                n = n + 1
                if (e.value or 1) > best then best = e.value or 1 end
            end
        end
    end
    return n, best
end

local battleStats

local runRec = nil
local function recOffer(id)
    if runRec and id then runRec.offered[id] = (runRec.offered[id] or 0) + 1 end
end

local dotMeter = { declared = 0, effective = 0, absorbedTicks = 0, ticks = 0 }
local function installDotMeter()
    local Enemy = require("src.entities.Enemy")
    if Enemy._autoplayDotHooked then return end
    Enemy._autoplayDotHooked = true
    local orig = Enemy._applyDot
    Enemy._applyDot = function(self, dmg)
        local hpBefore = self.health
        local ret = orig(self, dmg)
        if (dmg or 0) > 0 then
            local eff = hpBefore - self.health
            dotMeter.declared = dotMeter.declared + dmg
            dotMeter.effective = dotMeter.effective + eff
            dotMeter.ticks = dotMeter.ticks + 1
            if eff < dmg then
                dotMeter.absorbedTicks = dotMeter.absorbedTicks + 1
            end
        end
        return ret
    end
end

local ledger = nil
local curBeat = nil
local function sourceOf(label)
    if not label then return "card" end
    if label:find("^orb%.") or label:find("^effect%.evoke") or label:find("^effect%.channel")
        or label:find("^turn%.orb") then return "orb" end
    if label:find("^effect%.magic_damage") or label:find("^effect%.aoe_magic_damage") then return "magic" end
    if label:find("^player%.thorn_reflect") or label:find("^trigger%..*on_defend_damage") then return "thorn" end
    if label:find("^enemy%.dot") then return "dot" end
    if label:find("^card%.impact") or label:find("^passive%.") then return "card" end
    if label:find("^effect%.") or label:find("^trigger%.") then return "effect" end
    return "other"
end
local function installDamageLedger()
    local Enemy = require("src.entities.Enemy")
    if Enemy._autoplayLedgerHooked then return end
    Enemy._autoplayLedgerHooked = true
    local origTake = Enemy.takeDamage
    Enemy.takeDamage = function(self, dmg)
        local before = self.health
        local r = origTake(self, dmg)
        if ledger then
            local k = sourceOf(curBeat)
            ledger[k] = (ledger[k] or 0) + math.max(0, before - self.health)
        end
        return r
    end
    local origDot = Enemy._applyDot
    Enemy._applyDot = function(self, dmg)
        local before = self.health
        local r = origDot(self, dmg)
        if ledger then ledger.dot = (ledger.dot or 0) + math.max(0, before - self.health) end
        return r
    end
    local CB = require("src.systems.CombatBeats")
    local origPush = CB.push
    CB.push = function(label, fn, hold)
        local wrapped = fn and function()
            local prev = curBeat
            curBeat = label
            fn()
            curBeat = prev
        end or nil
        return origPush(label, wrapped, hold)
    end
end

local function chooseMotorCard(game)
    local pool = #(game.deck or {}) + #(game.discard or {})
    for _, c in ipairs(game.hand) do
        if c.type == "effect" and not c.frozen and (c.cost or 0) <= game.player.mana then
            if hasEffect(c, "draw_cards") and pool >= 1
                and ((c.cost or 0) == 0 or game.player.mana - (c.cost or 0) >= 1) then
                return c
            end
            if hasEffect(c, "restore_mana") then
                local v = 0
                for _, e in ipairs(c.effects or {}) do
                    if e.type == "restore_mana" then v = v + (e.value or 0) end
                end
                if v > (c.cost or 0) then return c end
            end
        end
    end
    return nil
end

local function bestDamageSet(game, budget, isPicked, perMana)
    local pool = {}
    for _, c in ipairs(game.hand) do
        if not isPicked(c) and c.type ~= "joker" and not c.frozen then
            local isDmg = (c.attack or 0) > 0
            if not isDmg then
                for _, e in ipairs(c.effects or {}) do
                    local t = e.type
                    if t == "magic_damage" or t == "aoe_magic_damage"
                        or t == "evoke_orb" or t == "evoke_all_orbs"
                        or t == "channel_orb"
                        or (t == "apply_debuff" and e.value == "vulnerable") then
                        isDmg = true
                        break
                    end
                end
            end
            if isDmg then pool[#pool + 1] = c end
        end
    end
    local set, cost = {}, 0
    local inSet = {}
    while true do
        local cur = simulateSetDamage(game, set)
        local best, bestScore
        for _, c in ipairs(pool) do
            if not inSet[c] and cost + (c.cost or 0) <= budget then
                local gain = simulateSetDamage(game, withCard(set, c)) - cur
                local score = perMana and (gain / math.max(1, c.cost or 0)) or gain
                if gain > 0 and (not best or score > bestScore) then
                    best, bestScore = c, score
                end
            end
        end
        if not best then break end
        inSet[best] = true
        table.insert(set, best)
        cost = cost + (best.cost or 0)
    end
    return set, cost
end

local function chooseBatch(game, turnState)
    local p = game.player
    local hand = game.hand
    local enemy = game.enemy
    local manaLeft = p.mana
    local threat = AI.knownThreat(enemy, p)
    local incoming = threat.perHit * threat.hits
    local hpRatio = p.health / p.maxHealth
    local run = (game.runManager and game.runManager.currentRun) or {}
    local floorInAct = run.floorInAct or 1
    local armorCap = p.maxArmor or 30

    local picks, reasons = {}, {}
    local function picked(card)
        for _, x in ipairs(picks) do if x == card then return true end end
        return false
    end
    local function pick(card, why)
        if card.frozen then return end
        table.insert(picks, card)
        manaLeft = manaLeft - (card.cost or 0)
        reasons[why] = true
    end
    local function whyStr()
        local why = {}
        for r in pairs(reasons) do table.insert(why, r) end
        table.sort(why)
        return table.concat(why, "+")
    end

    local free = freeDamageThisTurn(game)
    local targetHP = enemy.health + (enemy.armor or 0)
    local need = targetHP - free

    local function planDefense(requireEff, why)
        if incoming <= 0 then return end
        local target = math.min(incoming, armorCap)
        local armorNow = p.armor or 0
        if armorNow >= target then return end
        local cands = {}
        for _, c in ipairs(hand) do
            if not picked(c) and c.type ~= "joker" then
                local armor = 0
                if (c.defense or 0) > 0 then
                    armor = simulateCardValue(game, c, buildCtx(withCard(picks, c)))
                else
                    for _, e in ipairs(c.effects or {}) do
                        if e.type == "add_armor" then armor = armor + (e.value or 0) end
                    end
                end
                if armor > 0 then
                    table.insert(cands, { card = c, armor = armor })
                end
            end
        end
        if not enemy:hasStatus("weak") then
            for _, c in ipairs(hand) do
                if not picked(c) and hasDebuffEffect(c, "weak") then
                    table.insert(cands, { card = c,
                        armor = math.floor(incoming * 0.25), virtualWeak = true })
                    break
                end
            end
        end
        table.sort(cands, function(a, b)
            return a.armor / math.max(1, a.card.cost or 0)
                > b.armor / math.max(1, b.card.cost or 0)
        end)
        for _, d in ipairs(cands) do
            if armorNow >= target then break end
            local cost = d.card.cost or 0
            local eff = d.armor / math.max(1, cost)
            if cost <= manaLeft
                and (not requireEff or eff >= requireEff or cost == 0) then
                pick(d.card, d.virtualWeak and "weak-defesa" or (why or "defender"))
                armorNow = armorNow + d.armor
            end
        end
    end

    if need <= 0 then
        planDefense(nil, "dano-gratis")
        for _, c in ipairs(hand) do
            if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker"
                and (hasEffect(c, "gain_strength") or hasEffect(c, "gain_dexterity")
                    or hasEffect(c, "apply_buff") or hasEffect(c, "increase_max_mana")
                    or (hasEffect(c, "channel_orb") and (c.attack or 0) <= 0)) then
                pick(c, "dano-gratis")
            end
        end
        return picks, (#picks > 0 and whyStr() or "")
    end

    do
        local set = bestDamageSet(game, manaLeft, picked, false)
        if #set > 0 and simulateSetDamage(game, set) >= need then
            for _, c in ipairs(set) do pick(c, "LETHAL") end
            planDefense(5)
            return picks, whyStr()
        end
    end

    do
        local fullSet = bestDamageSet(game, manaLeft, picked, false)
        local dpt = simulateSetDamage(game, fullSet) + free
        if targetHP / math.max(1, dpt) >= 4 then
            for _, c in ipairs(hand) do
                if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker"
                    and (hasEffect(c, "gain_strength") or hasBuffEffect(c, "focus")
                        or hasEffect(c, "increase_max_mana")) then
                    pick(c, "scaling")
                end
            end
        end
    end

    local nearBossFloor = floorInAct >= 7
    local healThreshold = nearBossFloor and 0.50 or 0.35
    local maxHeals = nearBossFloor and 2 or 1
    if hpRatio < healThreshold then
        for _, c in ipairs(hand) do
            if turnState.healsUsed >= maxHeals then break end
            if not picked(c) and (c.cost or 0) <= manaLeft
                and healPassesGate(game, c) then
                pick(c, "curar")
                turnState.healsUsed = turnState.healsUsed + 1
            end
        end
    end

    local emergency = incoming >= p.health * 0.25
        or (hpRatio < 0.6 and incoming >= p.health * 0.15)
    if emergency then planDefense(nil) end

    local wallBlocked = false
    do
        local set = bestDamageSet(game, manaLeft, picked, true)
        local wall = enemy.armor or 0
        local total = simulateSetDamage(game, set)
        if #set > 0 then
            if wall > 0 and total <= wall then
                wallBlocked = true
            else
                for _, c in ipairs(set) do pick(c, "dano") end
            end
        end
    end

    if not emergency then planDefense(5) end

    for _, c in ipairs(hand) do
        if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker"
            and hasEffect(c, "channel_orb") and (c.attack or 0) <= 0 then
            pick(c, "channel")
        end
    end
    do
        local orbs = p.orbs or {}
        local channelPending = false
        for _, c in ipairs(hand) do
            if hasEffect(c, "channel_orb") then channelPending = true; break end
        end
        local dmgOrbs = 0
        for _, o in ipairs(orbs) do
            if o.type == "lightning" or o.type == "dark" or o.type == "fire" then
                dmgOrbs = dmgOrbs + 1
            end
        end
        local oldest = orbs[1]
        local darkReady = oldest and oldest.type == "dark"
            and ((oldest.value or 1) + getFocus(p)) * 2 >= targetHP
        local orbsFull = #orbs >= (p.orbSlots or 3)
        for _, c in ipairs(hand) do
            if not picked(c) and (c.cost or 0) <= manaLeft and c.type ~= "joker" then
                if hasEffect(c, "evoke_all_orbs") then
                    if dmgOrbs >= 2 then pick(c, "evoke") end
                elseif hasEffect(c, "evoke_orb") then
                    if (orbsFull and channelPending) or darkReady then
                        pick(c, "evoke")
                    end
                end
            end
        end
    end

    for pass = 1, 2 do
        for _, c in ipairs(hand) do
            local wantPass = (pass == 1 and c.type ~= "attack")
                or (pass == 2 and c.type == "attack")
            if wantPass and not picked(c) and (c.cost or 0) <= manaLeft
                and c.type ~= "joker" then
                local skip = false
                if c.type == "defense"
                    and (p.armor or 0) >= armorCap then
                    skip = true
                end
                if hasEffect(c, "evoke_orb") or hasEffect(c, "evoke_all_orbs") then
                    skip = true
                end
                if hasEffect(c, "instant_heal") then
                    if not healPassesGate(game, c)
                        or turnState.healsUsed >= maxHeals then
                        skip = true
                    end
                end
                if pass == 2 and wallBlocked then
                    skip = true
                end
                if not skip then
                    pick(c, "sobra")
                    if hasEffect(c, "instant_heal") then
                        turnState.healsUsed = turnState.healsUsed + 1
                    end
                end
            end
        end
    end

    for _, c in ipairs(hand) do
        if not picked(c) and c.type == "joker" and (c.cost or 0) <= manaLeft
            and game.canAcceptJoker and game:canAcceptJoker() then
            pick(c, "joker")
        end
    end

    return picks, whyStr()
end

local function playLeva(game, picks, why, levaNum)
    local pickNames = {}
    for _, c in ipairs(picks) do table.insert(pickNames, c.name or c.id) end
    log("  → leva %d: [%s] (%s)", levaNum,
        table.concat(pickNames, ", "), why ~= "" and why or "?")
    if v6Combat() then
        picks = AI.sortForPlay(picks)
    else
        table.sort(picks, function(x, y) return playRank(x) < playRank(y) end)
    end
    if battleStats and battleStats.plays then
        local ps = battleStats.plays
        local n = #picks
        ps.n = ps.n + 1
        ps.cards = ps.cards + n
        if n > ps.max then ps.max = n end
        ps.hist[n] = (ps.hist[n] or 0) + 1
        local ctx = buildCtx(picks)
        if #(ctx.activeCombos or {}) > 0 then ps.withCombo = ps.withCombo + 1 end
        for _, c in ipairs(picks) do
            if c.type == "attack" or c.type == "defense" then
                local stat = c.type == "attack" and game.player.strength or game.player.dexterity
                local plain = AI.cardValue(game, c, nil, stat)
                local combo = AI.cardValue(game, c, ctx, stat)
                local k = c.type == "attack" and "atk" or "def"
                ps[k] = ps[k] + combo
                ps[k .. "Combo"] = ps[k .. "Combo"] + (combo - plain)
            end
        end
        if battleStats.dmgParts then
            local okDP, DP = pcall(require, "src.systems.DamagePreview")
            if okDP then
                local okCtx, tctx = pcall(DP.buildContext, picks, game)
                for _, c in ipairs(picks) do
                    if c.type == "attack" and okCtx then
                        local okV, _, steps = pcall(DP.cardValue, game, c, tctx)
                        if okV and steps then
                            local prev = 0
                            for _, s in ipairs(steps) do
                                local after = s.after or prev
                                local kind = s.kind
                                if kind == "weak" or kind == "frail" then kind = "debuff" end
                                if kind == "edition" or kind == "seal" then kind = "edition" end
                                battleStats.dmgParts[kind] = (battleStats.dmgParts[kind] or 0) + (after - prev)
                                prev = after
                            end
                        end
                    end
                end
            end
        end
    end
    for _, c in ipairs(picks) do game:selectCard(c) end
    game:playSelectedCards()
    local guard = 0
    while game.combatAnimationSystem:isBlocking() and guard < 900 do
        pump(game, 1 / 30)
        guard = guard + 1
    end
end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local o = {}
    for k, x in pairs(v) do o[k] = deepcopy(x) end
    return o
end

local function snapshotBattle(game)
    local run = game.runManager.currentRun
    return {
        class = game.selectedClass,
        deck = deepcopy(run.currentDeck), jokers = deepcopy(run.jokers),
        jokerActive = deepcopy(run.jokerActive), services = deepcopy(run.services),
        maxJokerSlots = run.maxJokerSlots,
        act = run.actNumber, floorInAct = run.floorInAct,
        node = deepcopy(run.currentNode),
        hp = game.player.health, maxHp = game.player.maxHealth,
        baseMana = game.player.baseMaxMana or game.player.maxMana,
    }
end

local function playBattle(game, label)
    if M.onBattleStart then M.onBattleStart(snapshotBattle(game)) end
    local turnCount = 0
    local dmgTakenBefore = game.player.health
    local realDecisions = 0

    local jokersPlayed = 0
    local battlePool = #game.hand + #game.deck + #game.discard
        + #(game._exhaustedThisBattle or {})

    log("")
    log("### %s — inimigo %d HP (dmg %d)", label,
        game.enemy.maxHealth, game.enemy.damage)

    do
        local n, eff = multJokerStats(game)
        if n > (battleStats.multJokersMax or 0) then battleStats.multJokersMax = n end
        if eff > (battleStats.multEffective or 1) then battleStats.multEffective = eff end
    end

    local bctx = AI.newBattle(game)
    ledger = {}
    local diag = { atkTurns = 0, inc = 0, armorOnAtk = 0, unblocked = 0, blockedTurns = 0,
        manaLeft = 0, leftover = 0, wastedBlock = 0, dealt = 0, enemyDealt = 0 }
    local deckSizeAtStart = #((game.runManager.currentRun or {}).currentDeck or {})
    local potionsBefore = ((game.runManager.currentRun or {}).potions) or 0
    while game.enemy:isAlive() and game.player:isAlive() do
        turnCount = turnCount + 1
        if turnCount > 40 then
            log("- !! batalha passou de 40 turnos — abortando (stall?)")
            return false, "stall"
        end

        local kind, value, itLog = game.enemy:getIntentPreview(game.player)
        if itLog and (itLog.hits or 0) > 1 then value = tostring(value) .. "x" .. itLog.hits end
        local shownValue = value
        if game.enemy.getKnownIncomingDamage and game.enemy:getKnownIncomingDamage(game.player) == nil then
            shownValue = "?"
        end

        if M.traceSink then
            M.traceSink[#M.traceSink + 1] = M.stateSignature(game, label, turnCount, kind, value)
        end

        log("- T%d: HP %d/%d armor %d | mana %d | intent %s %s | mao: %s",
            turnCount, game.player.health, game.player.maxHealth,
            game.player.armor, game.player.mana,
            kind:upper(), tostring(shownValue or ""), handSummary(game))

        do
            local run = game.runManager and game.runManager.currentRun
            if game.usePotion and run and (run.potions or 0) > 0 then
                local p = game.player
                local inc = game.enemy.getIncomingDamage and game.enemy:getIncomingDamage(p) or 0
                local low = naiveCombat() and 0.30 or 0.40
                if p.health <= p.maxHealth * low
                    or (not naiveCombat() and (p.health - math.max(0, inc - (p.armor or 0))) <= p.maxHealth * 0.25) then
                    local okP, amt = game:usePotion()
                    if okP then
                        battleStats.potionsUsed = (battleStats.potionsUsed or 0) + 1
                        log("  → bebi a poção: +%d HP (%d/%d)", amt or 0, p.health, p.maxHealth)
                    end
                end
            end
        end

        local hpBefore = game.player.health
        local enemyBefore = game.enemy.health
        local levas = 0
        local turnState = { healsUsed = 0 }
        local thornCardReflect = 0
        local defensePlayedThisTurn = false

        local MOTOR_MAX_LEVAS = 3
        local motorLevas = 0
        if naiveCombat() then
            while levas < 4 and game.enemy:isAlive() and game.player:isAlive() do
                local picks, m = {}, game.player.mana
                for pass = 1, 2 do
                    for _, c in ipairs(game.hand) do
                        local isAtk = c.type == "attack"
                        if c.type ~= "joker" and not c.frozen
                            and ((pass == 1 and isAtk) or (pass == 2 and not isAtk))
                            and (c.cost or 0) <= m then
                            picks[#picks + 1] = c; m = m - (c.cost or 0)
                        end
                    end
                end
                if #picks == 0 then break end
                levas = levas + 1
                local handBefore = #game.hand
                playLeva(game, picks, "naive", levas)
                if #game.hand >= handBefore and game.player.mana <= 0 then break end
            end
        elseif v6Combat() then
            while levas < 8 and game.enemy:isAlive() and game.player:isAlive() do
                local picks, why = AI.planLeva(game, bctx,
                    { noMotorSplit = motorLevas >= MOTOR_MAX_LEVAS })
                if #picks == 0 then
                    local afford = {}
                    local m = game.player.mana
                    for _, c in ipairs(game.hand) do
                        if c.type ~= "joker" and (c.cost or 0) <= m then
                            afford[#afford + 1] = c; m = m - (c.cost or 0)
                        end
                    end
                    if #afford > 0 then
                        local s0 = AI.score(game, {}, AI.simulate(game, {}, bctx), bctx)
                        local s1 = AI.score(game, afford, AI.simulate(game, afford, bctx), bctx)
                        log("  → passou o turno: vazio %.1f x jogar %d cartas %.1f",
                            s0, #afford, s1)
                    end
                    break
                end
                if why == "motor" then motorLevas = motorLevas + 1 end
                levas = levas + 1
                for _, c in ipairs(picks) do
                    if c.type == "defense" then
                        defensePlayedThisTurn = true
                        for _, e in ipairs(c.effects or {}) do
                            if e.type == "on_defend_damage" then
                                thornCardReflect = thornCardReflect + (e.value or 0)
                            end
                        end
                    end
                end
                local function sig()
                    local p, e = game.player, game.enemy
                    local hand = {}
                    for _, c in ipairs(game.hand) do hand[#hand + 1] = tostring(c) end
                    return table.concat({ e.health, e.armor or 0, p.health, p.armor,
                        p.mana, p.strength, p.dexterity, #(p.orbs or {}),
                        #(e.statusEffects or {}), table.concat(hand, ",") }, "|")
                end
                local before = sig()
                playLeva(game, picks, why, levas)
                if why ~= "motor" and sig() == before then break end
            end
        end
        while not v6Combat() and not naiveCombat() and motorLevas < MOTOR_MAX_LEVAS and levas < 6 do
            local motor = chooseMotorCard(game)
            if not motor then break end
            motorLevas = motorLevas + 1
            local handBefore, manaBefore = #game.hand, game.player.mana
            levas = levas + 1
            if motor.type == "joker" then jokersPlayed = jokersPlayed + 1 end
            playLeva(game, { motor }, "motor", levas)
            if not game.enemy:isAlive() or not game.player:isAlive() then break end
            if #game.hand <= handBefore - 1 and game.player.mana < manaBefore then
                break
            end
        end

        while not v6Combat() and not naiveCombat() and levas < 6 and game.enemy:isAlive()
            and game.player:isAlive() do
            local picks, why = chooseBatch(game, turnState)
            if #picks == 0 then break end
            levas = levas + 1

            for _, c in ipairs(picks) do
                if c.type == "joker" then jokersPlayed = jokersPlayed + 1 end
                if c.type == "defense" then
                    defensePlayedThisTurn = true
                    for _, e in ipairs(c.effects or {}) do
                        if e.type == "on_defend_damage" then
                            thornCardReflect = thornCardReflect + (e.value or 0)
                        end
                    end
                end
            end

            local snapHP = game.enemy.health
            local snapArmor = game.player.armor
            local snapHand = #game.hand
            local snapMana = game.player.mana
            playLeva(game, picks, why, levas)
            if game.enemy.health == snapHP and game.player.armor == snapArmor
                and #game.hand >= snapHand and game.player.mana >= snapMana then
                break
            end
        end

        if defensePlayedThisTurn or thornCardReflect > 0 then
            local jokerThorn = 0
            if defensePlayedThisTurn then
                for _, j in ipairs(game.jokerSlots or {}) do
                    for _, e in ipairs(j.effects or {}) do
                        if e.type == "on_defend_damage" then
                            jokerThorn = jokerThorn + (e.value or 0)
                        end
                    end
                end
            end
            local reflect = thornCardReflect + jokerThorn
            if reflect > 0 then
                battleStats.thornReflect = (battleStats.thornReflect or 0) + reflect
                battleStats.thornTurns = (battleStats.thornTurns or 0) + 1
            end
        end
        do
            local act = (game.runManager.currentRun
                and game.runManager.currentRun.actNumber) or 1
            local f = getFocus(game.player)
            battleStats.focusMaxByAct[act] =
                math.max(battleStats.focusMaxByAct[act] or 0, f)
        end

        local leftoverPlayable = 0
        for _, c in ipairs(game.hand) do
            if (c.cost or 0) <= game.player.mana then
                leftoverPlayable = leftoverPlayable + 1
            end
        end
        if leftoverPlayable > 0 then realDecisions = realDecisions + 1 end

        do
            local nowPool = #game.hand + #game.deck + #game.discard
                + #(game._exhaustedThisBattle or {}) + jokersPlayed
            if nowPool ~= battlePool then
                anomaly("cartas sumiram/apareceram na batalha: pool %d -> %d (T%d)",
                    battlePool, nowPool, turnCount)
                battlePool = nowPool
            end
        end
        if (game.player.armor or 0) >= (game.player.maxArmor or 30) then
            battleStats.armorCapHits = (battleStats.armorCapHits or 0) + 1
        end

        local armorBeforeEnemy = game.player.armor or 0
        local nextKind = game.enemy:getIntentPreview(game.player)
        local nextIt = game.enemy:getIntent()
        local nextVal = game.enemy:getIncomingDamage(game.player)
        local nextPierce = nextIt.pierce and true or false
        local dotNext = game.player:getDebuffStacks("poison") + game.player:getDebuffStacks("burn")
        for _, d in ipairs(nextIt.debuffs or {}) do
            if d.name == "poison" or d.name == "burn" then dotNext = dotNext + (d.stacks or 0) end
        end
        local dmgTakenBeforeEnemy =
            (game.scoreSystem._battle and game.scoreSystem._battle.damageTaken) or 0
        diag.manaLeft = diag.manaLeft + (game.player.mana or 0)
        diag.leftover = diag.leftover + leftoverPlayable
        if (nextVal or 0) > 0 then
            diag.atkTurns = diag.atkTurns + 1
            diag.inc = diag.inc + nextVal
            diag.armorOnAtk = diag.armorOnAtk + armorBeforeEnemy
            diag.unblocked = diag.unblocked + math.max(0, nextVal - armorBeforeEnemy)
            if armorBeforeEnemy >= nextVal then diag.blockedTurns = diag.blockedTurns + 1 end
        else
            diag.wastedBlock = diag.wastedBlock + armorBeforeEnemy
        end

        if game.enemy:isAlive() and game.turn == "player" then
            game:endTurn()
            local guardP = 0
            while game.combatAnimationSystem:isBlocking() and guardP < 600 do
                pump(game, 1 / 30)
                guardP = guardP + 1
            end
        end
        if game.enemy:isAlive() and game.turn == "enemy" then
            game:enemyTurn()
            local guardET = 0
            while game.combatAnimationSystem:isBlocking() and guardET < 600 do
                pump(game, 1 / 30)
                guardET = guardET + 1
            end
            pump(game, 0.2)
        end

        local dmgTakenAfterEnemy =
            (game.scoreSystem._battle and game.scoreSystem._battle.damageTaken) or 0
        local enemyDealt = dmgTakenAfterEnemy - dmgTakenBeforeEnemy
        if (nextVal or 0) > 0 and not nextPierce and dotNext == 0
            and armorBeforeEnemy >= (nextVal or 0) + 4
            and enemyDealt > 0 then
            anomaly("escudo furado: %d de escudo vs golpe %s %d, inimigo furou %d",
                armorBeforeEnemy, nextKind, nextVal or 0, enemyDealt)
        end

        bctx.turns = bctx.turns + 1
        bctx.dealt = bctx.dealt + math.max(0, enemyBefore - game.enemy.health)
        diag.dealt = diag.dealt + math.max(0, enemyBefore - game.enemy.health)
        diag.enemyDealt = diag.enemyDealt + math.max(0, enemyDealt)
        if (nextVal or 0) > 0 then
            bctx.hitTurns = bctx.hitTurns + 1
            bctx.incSum = bctx.incSum + nextVal
            bctx.lostSum = bctx.lostSum + math.max(0, enemyDealt)
        end
        log("    dano causado %d | dano sofrido %d | inimigo %d HP",
            enemyBefore - game.enemy.health,
            math.max(0, hpBefore - game.player.health),
            math.max(0, game.enemy.health))
    end

    pump(game, 1.5)

    do
        local act = (game.runManager.currentRun
            and game.runManager.currentRun.actNumber) or 1
        local ba = battleStats.byAct[act]
            or { dealt = 0, taken = 0, turns = 0, battles = 0 }
        ba.dealt = ba.dealt + (game.enemy.maxHealth - math.max(0, game.enemy.health))
        ba.taken = ba.taken + math.max(0, dmgTakenBefore - game.player.health)
        ba.turns = ba.turns + turnCount
        ba.battles = ba.battles + 1
        local cn = game.runManager.currentRun and game.runManager.currentRun.currentNode
        if cn and cn.type == "boss" then
            ba.bossTurns = (ba.bossTurns or 0) + turnCount
            ba.bosses = (ba.bosses or 0) + 1
        end
        battleStats.byAct[act] = ba
    end

    local won = not game.enemy:isAlive() and game.player:isAlive()
    battleStats.battles = battleStats.battles + 1
    battleStats.turns = battleStats.turns + turnCount
    battleStats.realDecisionTurns = battleStats.realDecisionTurns + realDecisions
    battleStats.totalTurns = battleStats.totalTurns + turnCount
    battleStats.dmgTaken = battleStats.dmgTaken
        + math.max(0, dmgTakenBefore - game.player.health)
    if battleStats.dmg and ledger then
        for k, v in pairs(ledger) do battleStats.dmg[k] = (battleStats.dmg[k] or 0) + v end
    end
    if battleStats.battleLog then
        local run = game.runManager.currentRun or {}
        local node = run.currentNode or {}
        battleStats.battleLog[#battleStats.battleLog + 1] = {
            act = run.actNumber or 1, floor = run.floorInAct or 1,
            node = node.type or "battle",
            enemy = game.enemy.spriteId or game.enemy.kitId or game.enemy.name,
            enemyMaxHp = game.enemy.maxHealth, enemyHpLeft = math.max(0, game.enemy.health or 0),
            enemyHealed = game.enemy.healedTotal or 0,
            turns = turnCount, won = won,
            hpLost = math.max(0, dmgTakenBefore - game.player.health),
            hpEnd = math.max(0, game.player.health), maxHp = game.player.maxHealth,
            deckSize = deckSizeAtStart,
            dmg = ledger, diag = diag,
        }
    end
    do
        local pots = ((game.runManager.currentRun or {}).potions) or 0
        if pots > potionsBefore then battleStats.potionsFound = (battleStats.potionsFound or 0) + (pots - potionsBefore) end
    end
    ledger = nil

    if won then
        local sb = game.scoreSystem.lastBattle
        if sb then
            local parts = {}
            for _, item in ipairs(sb.breakdown or {}) do
                table.insert(parts, item.label .. " " .. item.value)
            end
            log("- **VITORIA em %d turnos** → +%d pts (%s)", turnCount,
                sb.total, table.concat(parts, " · "))
        end
    else
        log("- **MORREU** na batalha (turno %d)", turnCount)
    end
    return won, turnCount
end

local function deckIdList(game)
    local out = {}
    local deck = (game.runManager.currentRun
        and game.runManager.currentRun.currentDeck) or {}
    for _, e in ipairs(deck) do
        out[#out + 1] = type(e) == "table" and e.id or e
    end
    return out
end

local function classTagAffinity(game, cardData)
    local deckTags = {}
    for _, id in ipairs(deckIdList(game)) do
        local cd = game.deckManager.cardDatabase:getCard(id)
        for _, t in ipairs(TagSystem.getCardTags(cd or {})) do
            deckTags[t] = (deckTags[t] or 0) + 1
        end
    end
    local score = 0
    for _, t in ipairs(TagSystem.getCardTags(cardData or {})) do
        score = score + (deckTags[t] or 0)
    end
    return score
end

local RARITY_SCORE = { common = 1, uncommon = 3, rare = 6, legendary = 10 }

local CLASS_ARCHETYPE = {
    warrior = { strike = 3, armor = 2, defend = 2, strength = 2 },
    mage    = { channel = 3, magic = 3, lightning = 2, evoke = 2,
                defend = 2, armor = 2, ice = 1 },
    rogue   = { poison = 3, strike = 2, finisher = 2,
                defend = 2, armor = 1, thorn = 1 },
}

local function archetypeScore(game, cardData)
    local classId = game.selectedClass or "warrior"
    local prior = CLASS_ARCHETYPE[classId] or {}
    local s = 0
    for _, t in ipairs(TagSystem.getCardTags(cardData or {})) do
        s = s + (prior[t] or 0)
    end
    return s
end

local function normalBar(game, dctx)
    local p = prof()
    dctx = dctx or AI.deckContext(game)
    return dctx.avg + (p.pickBase or -1.5) + math.max(0, dctx.n - 8) * (p.pickBar or 0.35)
end
local function hasHeal(cd)
    for _, e in ipairs((cd and cd.effects) or {}) do
        if e.type == "instant_heal" or e.type == "on_attack_heal" or e.type == "regen_per_turn" then
            return true
        end
    end
    return false
end
local function normalCardScore(game, offer, cd, dctx)
    dctx = dctx or AI.deckContext(game)
    local s = AI.cardWorth(game, cd, dctx, false)
        + (RARITY_SCORE[offer.rarity or (cd and cd.rarity) or "common"] or 1) * 0.5
    if hasHeal(cd) then
        local heals = 0
        for _, id in ipairs(dctx.ids or {}) do
            if hasHeal(game.deckManager.cardDatabase:getCard(id)) then heals = heals + 1 end
        end
        if heals < 2 then s = s + 3 end
    end
    local n = math.max(1, dctx.n)
    local isBlock = cd and (cd.type == "defense")
    if isBlock and dctx.blockCards / n < 0.35 then s = s + 3 end
    if cd and cd.type == "attack" and dctx.attackCards / n > 0.55 then s = s - 3 end
    return s
end

local function forgeScore(game, cardId, counts)
    local RunManager = require("src.systems.RunManager")
    local cd = game.deckManager.cardDatabase:getCard(cardId)
    if not cd then return -1 end
    if not game.runManager:canUpgrade(cardId) then return -1 end
    local gains = RunManager.getForgeGains(cd)
    local realGain = (gains.atk or 0) + (gains.def or 0) + (gains.effect or 0)
    if realGain <= 0 then return -1 end
    local copies = (counts and counts[cardId]) or 1
    local deckN = math.max(1, #deckIdList(game))
    local avgTurns = (battleStats and battleStats.battles > 0)
        and (battleStats.turns / battleStats.battles) or 6
    local cycles = math.max(1, (avgTurns * 4) / deckN)
    local cost = math.max(1, cd.cost or 1)
    local s = (copies * cycles / cost) * realGain
        * (1 + archetypeScore(game, cd) * 0.3)
    local classId = game.selectedClass or "warrior"
    if classId == "warrior" and (cd.attack or 0) > 0 then
        s = s * 1.5
    elseif classId == "rogue" and (cd.attack or 0) > 0 and (cd.cost or 0) <= 1 then
        s = s * 1.5
    elseif classId == "mage" then
        for _, e in ipairs(cd.effects or {}) do
            local t = e.type
            if t == "magic_damage" or t == "aoe_magic_damage" or t == "add_armor"
                or t == "draw_cards" or t == "restore_mana" then
                s = s * 1.5
                break
            end
        end
    end
    if battleStats then
        local act = (game.runManager.currentRun
            and game.runManager.currentRun.actNumber) or 1
        local ba = battleStats.byAct and battleStats.byAct[act]
        if ba and ba.turns > 2 and (ba.taken / ba.turns) >= 6
            and (battleStats.armorCapHits or 0) == 0
            and (cd.defense or 0) > 0 then
            s = s * 2
        end
    end
    return s
end

local function forgeIndexFor(game, cardId)
    local rm = game.runManager
    local run = rm and rm.currentRun
    if not run then return nil end
    local best, bestLvl
    for i, entry in ipairs(run.currentDeck or {}) do
        local RM = require("src.systems.RunManager")
        if RM.entryId(entry) == cardId and rm:canUpgradeAt(i) then
            local lvl = rm:getEntryLevel(entry)
            if not bestLvl or lvl < bestLvl then best, bestLvl = i, lvl end
        end
    end
    return best
end

local function bestForgeTarget(game)
    local counts = {}
    for _, id in ipairs(deckIdList(game)) do
        counts[id] = (counts[id] or 0) + 1
    end
    local bestId, bestS
    for id in pairs(counts) do
        local s = forgeScore(game, id, counts)
        if s > 0 and (not bestS or s > bestS) then bestId, bestS = id, s end
    end
    return bestId, bestS or 0
end

local JOKER_EFFECT_SCORE = {
    damage_bonus = 8, defense_bonus = 6, on_attack_heal = 6,
    on_defend_damage = 4,
    regen_per_turn = 5, strength_per_turn = 12, on_turn_start_draw = 15,
    channel_per_turn = 10, on_attack_debuff = 8,
    echo_first_attack = 10, retain_armor = 14,
    damage_per_turn = -8,
}

local function scoreJokerParts(inst, game)
    local flat, dmgMult, defMult = 0, nil, nil
    local run = game and game.runManager and game.runManager.currentRun
    local act = (run and run.actNumber) or 1
    local Counter = require("src.systems.CounterJokers")
    for _, e in ipairs(inst.effects or {}) do
        local t = e.type
        local counter = Counter.pilotScore(e, act)
        if counter then
            flat = flat + counter
        elseif t == "damage_multiplier" and e.target == "attack" then
            dmgMult = math.max(dmgMult or 1, e.value or 1)
        elseif t == "defense_multiplier" and e.target == "defense" then
            defMult = math.max(defMult or 1, e.value or 1)
        elseif t == "heal_multiplier" then
            flat = flat + ((e.value or 1) - 1) * 12
        elseif JOKER_EFFECT_SCORE[t] then
            flat = flat + JOKER_EFFECT_SCORE[t] * (tonumber(e.value) or 1)
        else
            flat = flat + 2
        end
    end
    return flat, dmgMult, defMult
end

local function optimizeJokerBench(game, whenLabel)
    local rm = game.runManager
    if not prof().bench then return end
    if not (game.isRunMode and rm.hasActiveRun and rm:hasActiveRun()) then return end
    if not game.setJokerActive then return end
    local all = rm:buildAllJokerInstances()
    if #all == 0 then return end
    local cap = rm:getMaxJokerSlots()

    local entries = {}
    for _, inst in ipairs(all) do
        local flat, dm, dfm = scoreJokerParts(inst, game)
        table.insert(entries, {
            idx = inst._ownedIndex, name = inst.name or inst.id,
            flat = flat, dmgMult = dm, defMult = dfm, score = flat,
        })
    end
    local function grantBest(field)
        local best
        for _, en in ipairs(entries) do
            if en[field] and (not best or en[field] > best[field]) then
                best = en
            end
        end
        if best then best.score = best.score + (best[field] - 1) * 40 end
    end
    grantBest("dmgMult")
    grantBest("defMult")

    table.sort(entries, function(a, b) return a.score > b.score end)
    local want = {}
    for i = 1, math.min(cap, #entries) do want[entries[i].idx] = true end

    local changed = false
    for _, en in ipairs(entries) do
        if not want[en.idx] and rm:isJokerActive(en.idx) then
            game:setJokerActive(en.idx, false)
            changed = true
        end
    end
    for i = 1, math.min(cap, #entries) do
        local en = entries[i]
        if not rm:isJokerActive(en.idx) then
            local ok = game:setJokerActive(en.idx, true)
            if ok then changed = true end
        end
    end
    if changed then
        local names = {}
        for i = 1, math.min(cap, #entries) do names[#names + 1] = entries[i].name end
        log("  (bancada %s: ativei [%s] de %d possuidos)",
            whenLabel or "?", table.concat(names, ", "), #entries)
    end
end

local function primeShopContext(game, mode)
    if game.shopSystem.setContext then
        local ShopSystem = require("src.systems.ShopSystem")
        game.shopSystem:setContext(ShopSystem.runContext(game, mode or game.shopSystem.mode or "shop"))
    end
end

local function cardValueScore(game, cardId)
    local cd = game.deckManager.cardDatabase:getCard(cardId)
    if not cd then return 0 end
    return (RARITY_SCORE[cd.rarity or "common"] or 1) * 2
        + archetypeScore(game, cd) * 2
        + classTagAffinity(game, cd) * 0.5
        + ((cd.attack or 0) + (cd.defense or 0)) / 4
end

local function installHeadlessPicker(game)
    _G.openCardPicker = function(mode)
        local ids = deckIdList(game)
        if #ids == 0 then return end
        if mode == "remove" then
            if #ids <= 8 then
                log("  (picker: deck %d ja enxuto — nao removi)", #ids)
                return
            end
            local defCount = 0
            for _, id in ipairs(ids) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                if cd and cd.type == "defense" then defCount = defCount + 1 end
            end
            local worst, worstS
            if v6Build() then
                local dctx = AI.deckContext(game)
                local cands = {}
                for _, id in ipairs(ids) do
                    local cd = game.deckManager.cardDatabase:getCard(id)
                    local isDef = cd and cd.type == "defense"
                    if cd and not (isDef and defCount <= 3) then
                        cands[#cands + 1] = { id = id, w = AI.cardWorth(game, cd, dctx, true) }
                    end
                end
                table.sort(cands, function(a, b) return a.w < b.w end)
                local baseLoss = M.evalDeckSim(game, nil)
                local seen = {}
                for i = 1, math.min(3, #cands) do
                    local id = cands[i].id
                    if not seen[id] then
                        seen[id] = true
                        local loss = M.evalDeckSim(game, function(snap)
                            for k, e in ipairs(snap.deck) do
                                if (type(e) == "table" and e.id or e) == id then
                                    table.remove(snap.deck, k); break
                                end
                            end
                        end)
                        if not worstS or loss < worstS then worst, worstS = id, loss end
                    end
                end
                if worst and worstS > baseLoss + 1 then
                    log("  (picker: nenhuma remocao ajuda na simulacao — mantive o deck)")
                    return
                end
            else
            for _, id in ipairs(ids) do
                local cd = game.deckManager.cardDatabase:getCard(id)
                local isDef = cd and cd.type == "defense"
                if not (isDef and defCount <= 3) then
                    local s = cardValueScore(game, id)
                    if not worstS or s < worstS then worst, worstS = id, s end
                end
            end
            end
            if not worst then
                log("  (picker: nada removivel com seguranca)")
                return
            end
            game.runManager:removeCardFromDeck(worst)
            if game.synchronizeRunDeck then game:synchronizeRunDeck() end
            log("  (picker: REMOVI a pior carta: %s)", worst)
        elseif mode == "duplicate" then
            local best, bestS
            for _, id in ipairs(ids) do
                local s = cardValueScore(game, id)
                if not bestS or s > bestS then best, bestS = id, s end
            end
            game:addCardToRun(best)
            log("  (picker: DUPLIQUEI a melhor carta: %s)", best)
        elseif mode == "forge" then
            local bestId, bestS = bestForgeTarget(game)
            if bestId then
                local lvl = game.runManager:upgradeCard(bestId)
                log("  (picker: FORJEI %s → nivel %s, score %.1f)",
                    bestId, tostring(lvl), bestS)
            end
        end
    end
end

local function doRewards(game)
    game.shopSystem:setMode("rewards")
    primeShopContext(game, "rewards")
    game.shopSystem:generateOffers()
    local offers = game.shopSystem:getCurrentOffers()
    for _, o in ipairs(offers) do if o.type == "card" then recOffer(o.id) end end
    for _, o in ipairs(offers) do if o.sustainSlot then battleStats.sustainSlots = (battleStats.sustainSlots or 0) + 1 end end

    local best, bestScore = nil, -1
    if prof().build == "greedy" then
        for _, o in ipairs(offers) do
            if o.type == "card" and game.economySystem:canAfford(o.cost) then
                local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 10 + (o.cost or 0)
                if s > bestScore then best, bestScore = o, s end
            end
        end
    elseif v6Build() then
        local ids, byId = {}, {}
        for _, o in ipairs(offers) do
            if o.type == "card" and game.economySystem:canAfford(o.cost) then
                ids[#ids + 1] = o.id; byId[o.id] = o
            end
        end
        local pickId, gain = M.pickBySim(game, M.simCandidates(game, ids))
        if pickId then best, bestScore = byId[pickId], gain end
    elseif prof().build == "heuristic" then
        local dctx = AI.deckContext(game)
        for _, o in ipairs(offers) do
            if o.type == "card" and game.economySystem:canAfford(o.cost) then
                local cd = game.deckManager.cardDatabase:getCard(o.id)
                local want, w = AI.wantsCard(game, cd, dctx, prof().buildMargin)
                if want and w > bestScore then best, bestScore = o, w end
            end
        end
    else
    for _, o in ipairs(offers) do
        if o.type == "card" and game.economySystem:canAfford(o.cost) then
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 2
                + classTagAffinity(game, cd)
                + archetypeScore(game, cd) * 2 - o.cost * 0.5
            if s > bestScore then best, bestScore = o, s end
        end
    end
    if prof().build == "normal" then
        local dctx = AI.deckContext(game)
        best, bestScore = nil, -math.huge
        for _, o in ipairs(offers) do
            if o.type == "card" and game.economySystem:canAfford(o.cost) then
                local cd = game.deckManager.cardDatabase:getCard(o.id)
                local s = normalCardScore(game, o, cd, dctx)
                if s > bestScore then best, bestScore = o, s end
            end
        end
        if best then
            local cd = game.deckManager.cardDatabase:getCard(best.id)
            local bar = normalBar(game, dctx)
            if not (cd and cd.type == "joker") and bestScore < bar then
                log("- Recompensa: pulei (%s valor %.1f < barra %.1f, deck %d media %.1f)",
                    best.name, bestScore, bar, dctx.n, dctx.avg)
                best = nil
            end
        end
    end
    end

    local deckSize = #deckIdList(game)
    if prof().build == "v5" and best and deckSize > 18 and (RARITY_SCORE[best.rarity] or 1) < 6 then
        best = nil
    end

    if best then
        local goldBefore = game.economySystem.currentGold
        game.economySystem:spendGold(best.cost, best.type, best.id)
        if game.economySystem.currentGold ~= goldBefore - best.cost then
            anomaly("ouro errado na recompensa: %d - %d != %d",
                goldBefore, best.cost, game.economySystem.currentGold)
        end
        game:addCardToRun(best.id)
        log("- Recompensa: comprei **%s** (%s, $%d) → ouro $%d",
            best.name, best.rarity or "?", best.cost,
            game.economySystem.currentGold)
        local cd = game.deckManager.cardDatabase:getCard(best.id)
        if cd and cd.type == "joker" then
            optimizeJokerBench(game, "recompensa")
        end
    else
        log("- Recompensa: pulei (nada valia / deck cheio) → ouro $%d",
            game.economySystem.currentGold)
    end

end

local function chooseNode(game, pending)
    local hpRatio = game.player.health / game.player.maxHealth
    local gold = game.economySystem.currentGold
    local BT = MapManager.NODE_TYPES
    local run = game.runManager.currentRun

    if prof().path == "random" then
        local i = M._pilotRng and M._pilotRng:random(1, #pending) or 1
        return i, pending[i]
    end

    local dptEstimate
    local ba = battleStats and battleStats.byAct
        and battleStats.byAct[run.actNumber]
    if ba and ba.turns and ba.turns > 0 then
        dptEstimate = ba.dealt / ba.turns
    else
        local deckDmg, deckN = 0, 0
        for _, id in ipairs(deckIdList(game)) do
            local cd = game.deckManager.cardDatabase:getCard(id)
            if cd and (cd.attack or 0) > 0 then
                deckDmg = deckDmg + cd.attack / math.max(1, cd.cost or 1)
                deckN = deckN + 1
            end
        end
        local dmgPerMana = deckN > 0 and deckDmg / deckN or 7
        dptEstimate = dmgPerMana * (game.player.maxMana or 3)
    end
    local ActSystem = require("src.systems.ActSystem")
    local eliteStats = ActSystem.getEnemyStats(run.actNumber,
        math.min(8, run.floorInAct + 1), "elite")
    local canElite = dptEstimate * 6 >= (eliteStats.health or 60)

    local nearBoss = (run.floorInAct or 1) >= 6
    local want
    if nearBoss and hpRatio < 0.7 then
        want = { BT.REST, BT.EVENT, BT.SHOP, BT.BATTLE }
    elseif hpRatio < 0.5 then
        want = { BT.REST, BT.EVENT, BT.BATTLE, BT.SHOP }
    elseif gold >= 14 then
        want = canElite and { BT.SHOP, BT.ELITE, BT.BATTLE, BT.EVENT, BT.REST }
            or { BT.SHOP, BT.BATTLE, BT.EVENT, BT.REST, BT.ELITE }
    elseif hpRatio > 0.75 and canElite then
        want = { BT.ELITE, BT.BATTLE, BT.EVENT, BT.SHOP, BT.REST }
    else
        want = { BT.BATTLE, BT.EVENT, BT.REST, BT.SHOP, BT.ELITE }
    end

    if nearBoss and gold >= 30 then
        local si, ei
        for i, t in ipairs(want) do
            if t == BT.SHOP and not si then si = i end
            if t == BT.EVENT and not ei then ei = i end
        end
        if si and ei and si > ei then
            table.remove(want, si)
            table.insert(want, ei, BT.SHOP)
        end
    end

    for _, wantType in ipairs(want) do
        for i, node in ipairs(pending) do
            if node.type == wantType then return i, node end
        end
    end
    return 1, pending[1]
end

local function doRest(game)
    local p = game.player
    local floorInAct = game.runManager.currentRun.floorInAct or 1
    local nearBoss = floorInAct >= 6
    if prof().rest == "always_rest" or p.health <= p.maxHealth * (nearBoss and 0.75 or 0.6) then
        local restPct = require("src.core.Config").Game.REST_HEAL_PCT or 0.30
        local amt = math.floor(p.maxHealth * restPct * require("src.systems.RunModifiers")
            .healMul(game.runManager.currentRun, "rest"))
        p:heal(amt)
        log("- Acampamento: **descansei** +%d HP → %d/%d", amt, p.health, p.maxHealth)
    else
        local bestId, bestS = bestForgeTarget(game)
        if bestId then
            local lvl = game.runManager:upgradeCard(bestId)
            log("- Acampamento: **forjei** %s → nivel +%s (score %.1f)",
                bestId, tostring(lvl), bestS)
        else
            log("- Acampamento: nada forjavel — descansei mesmo cheio")
            p:heal(math.floor(p.maxHealth * (require("src.core.Config").Game.REST_HEAL_PCT or 0.30)))
        end
    end
end

local function scoreEventEntry(game, entry, isCost)
    local p = game.player
    local hp, maxHp = p.health, p.maxHealth
    local gold = game.economySystem.currentGold
    local deckN = #deckIdList(game)
    local sign = isCost and -1 or 1

    if type(entry) ~= "table" or not entry.k then return 0 end
    local k, n, pct = entry.k, tonumber(entry.n) or 0, tonumber(entry.pct) or 0

    if isCost and k == "hp" then
        if hp - n <= 4 then return -1000 end
        return -n * (hp < maxHp * 0.4 and 1.6 or 0.6)
    end
    if isCost and k == "gold" then
        if gold < n then return -1000 end
        return -n / 8
    end
    if k == "chance_trap" then
        return -(pct / 100) * n * 1.2
    end
    if k == "remove_random" then
        return (deckN > 16) and 3 or -6
    end

    if k == "remove_choice"  then return sign * ((deckN >= 14) and 12 or 5) end
    if k == "dup_choice"     then return sign * 8 end
    if k == "forge_choice" or k == "forge_random" then return sign * 7 end
    if k == "max_mana"       then return sign * 12 end
    if k == "max_hp"         then return sign * 7 end
    if k == "card_legendary" then return sign * 10 end
    if k == "card_rare"      then return sign * ((deckN > 18) and 3 or 6) end
    if k == "cards_random"   then return sign * ((deckN > 16) and -2 or 2) end
    if k == "card_potion" or k == "chance_potion" then return sign * 2 end
    if k == "mystery"        then return sign * 1 end
    if k == "heal_pct" then
        local heal = math.min(maxHp * n / 100, maxHp - hp)
        return sign * (heal / maxHp) * 30
    end
    if k == "heal_flat" then
        local heal = math.min(n, maxHp - hp)
        return sign * (heal / maxHp) * 30
    end
    if k == "gamble" or k == "chance_gold" then
        return sign * (pct / 100) * n / 6
    end
    if k == "gold" then return sign * n / 6 end

    anomaly("evento com chave de %s desconhecida: '%s' — o piloto pontuou 0",
        isCost and "custo" or "ganho", tostring(k))
    return 0
end

local function doEvent(game)
    local run = game.runManager.currentRun
    local ev = Events.roll(run.actNumber or 1, nil, require("src.systems.EnemyRoster").biomeAct(run))
    if not ev then
        log("- Evento: nenhum disponivel")
        return
    end
    local bestIdx, bestScore = #ev.options, 0.5
    if prof().event == "first" then
        bestIdx = #ev.options
        for i, opt in ipairs(ev.options) do
            local ok = true
            for _, c in ipairs(opt.costs or {}) do
                if type(c) == "table" then
                    if c.k == "gold" and game.economySystem.currentGold < (tonumber(c.n) or 0) then ok = false end
                    if c.k == "hp" and game.player.health - (tonumber(c.n) or 0) <= 4 then ok = false end
                end
            end
            if ok then bestIdx = i break end
        end
        bestScore = 0
    end
    for i, opt in ipairs(ev.options) do
        if prof().event == "first" then break end
        local s = 0
        for _, g in ipairs(opt.gains or {}) do s = s + scoreEventEntry(game, g, false) end
        for _, c in ipairs(opt.costs or {}) do s = s + scoreEventEntry(game, c, true) end
        if (opt.gains or opt.costs) and s > bestScore then
            bestIdx, bestScore = i, s
        end
    end
    local opt = ev.options[bestIdx]
    local okApply, feedback = pcall(opt.apply, game)
    log("- Evento **%s**: escolhi '%s' (score %.1f) → %s", ev.title, opt.label,
        bestScore, okApply and (feedback or "ok") or ("ERRO: " .. tostring(feedback)))
end

local REAL_UPGRADES = {
    increase_base_mana = true,
    increase_max_health = true,
    forge_card = true,
}

local SERVICE_EFFECTS = {
    add_joker_slot    = true,
    raise_interest_cap = true,
    increase_draw     = true,
}

local function applyUpgradeOffer(game, o)
    local p = game.player
    local rm = game.runManager
    local efeito = o.effect

    local OBSERVAVEL = {
        increase_base_mana  = function() return p.maxMana end,
        increase_max_health = function() return p.maxHealth end,
        add_joker_slot      = function()
            return (rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots()) or 0
        end,
        raise_interest_cap  = function()
            return (game.economySystem and game.economySystem.getInterestCap
                and game.economySystem:getInterestCap()) or 0
        end,
        increase_draw       = function()
            return (rm and rm.getServiceCount and rm:getServiceCount("card_draw_upgrade")) or 0
        end,
    }
    local observa = OBSERVAVEL[efeito]
    local antes = observa and observa() or nil

    if efeito == "increase_base_mana" then
        p.baseMaxMana = (p.baseMaxMana or p.maxMana) + (o.value or 1)
        p.maxMana = p.maxMana + (o.value or 1)
        p.mana = p.mana + (o.value or 1)
    elseif efeito == "increase_max_health" then
        p.maxHealth = p.maxHealth + (o.value or 0)
        p.health = p.health + (o.value or 0)

    elseif efeito == "add_joker_slot" then
        if rm and rm.registerService then rm:registerService(o.id) end
        if game.recomputeMaxJokerSlots then game:recomputeMaxJokerSlots() end
    elseif efeito == "raise_interest_cap" then
        if rm and rm.registerService then rm:registerService(o.id) end
        if game.syncInterestCap then game:syncInterestCap() end
    elseif efeito == "increase_draw" then
        if rm and rm.registerService then rm:registerService(o.id) end

    elseif efeito == "remove_card" or efeito == "duplicate_card"
        or efeito == "forge_card" then
        if efeito == "forge_card" then
            if rm and rm.registerPaidForge then rm:registerPaidForge() end
        elseif rm and rm.registerService then
            rm:registerService(o.id)
        end
        if _G.openCardPicker then _G.openCardPicker(o.picker) end
        return

    else
        anomaly("upgrade sem caminho no piloto: %s (efeito '%s') — ouro gasto "
            .. "sem efeito aplicado", tostring(o.id or "?"), tostring(efeito))
        return
    end

    if observa and observa() == antes then
        anomaly("ouro queimado: upgrade %s nao alterou seu observavel (%s)",
            tostring(o.id or efeito or "?"), tostring(antes))
    end
end

local function doShop(game)
    game.shopSystem:setMode("shop")
    primeShopContext(game, "shop")
    game.shopSystem:generateOffers()

    local run = game.runManager.currentRun
    local act = run.actNumber or 1
    local floorInAct = run.floorInAct or 1
    if runRec and runRec.eco then
        local visit = { act = act, gold = game.economySystem.currentGold }
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if o.effect == "add_joker_slot" then
                visit.slotCost = o.cost
                visit.slotAffordable = game.economySystem.currentGold >= o.cost
            end
        end
        table.insert(runRec.eco.shops, visit)
    end
    local reserve = (floorInAct >= 6) and 0 or math.min(50, 15 * act)
    local function spendable()
        return game.economySystem.currentGold - reserve
    end

    local bought = 0
    local boughtJoker = false

    local function scoreCardOffer(o)
        local cd = game.deckManager.cardDatabase:getCard(o.id)
        if v6Build() then
            local want, w = AI.wantsCard(game, cd)
            if not want then return -1 end
            return 6 + w
        end
        local s = (RARITY_SCORE[o.rarity or "common"] or 1) * 2
            + classTagAffinity(game, cd) + archetypeScore(game, cd) * 2
        if prof().build == "normal" then
            if cd and cd.type == "joker" then return 99 end
            local dctx = AI.deckContext(game)
            local w, bar = normalCardScore(game, o, cd, dctx), normalBar(game, dctx)
            if w < bar then return -1 end
            return 6 + (w - bar)
        end
        local deckSize = #deckIdList(game)
        if deckSize > 18 and (RARITY_SCORE[o.rarity or "common"] or 1) < 6 then
            s = -1
        end
        return s
    end

    local function tryManaUpgrade()
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if o.type == "upgrade" and o.effect == "increase_base_mana"
                and game.economySystem.currentGold >= 25
                and game.economySystem:canAfford(o.cost) then
                game.economySystem:spendGold(o.cost, o.type, o.id)
                applyUpgradeOffer(game, o)
                run._usedShop = true
                bought = bought + 1
                log("- Loja: comprei **%s** ($%d) — mana base %d (prioridade maxima)",
                    o.name, o.cost, game.player.baseMaxMana or game.player.maxMana)
                return true
            end
        end
        return false
    end
    tryManaUpgrade()

    if prof().shop == "impulsive" then
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if bought >= 3 then break end
            if o.type == "card" then recOffer(o.id) end
            if game.economySystem:canAfford(o.cost) then
                if o.type == "card" then
                    game.economySystem:spendGold(o.cost, o.type, o.id)
                    game:addCardToRun(o.id)
                    bought = bought + 1
                    log("- Loja (impulsiva): comprei **%s** ($%d)", o.name, o.cost)
                elseif o.type == "upgrade" and o.effect ~= "remove_card" then
                    game.economySystem:spendGold(o.cost, o.type, o.id)
                    applyUpgradeOffer(game, o)
                    bought = bought + 1
                    log("- Loja (impulsiva): comprei **%s** ($%d)", o.name, o.cost)
                end
                run._usedShop = true
            end
        end
        if bought == 0 then
            log("- Loja (impulsiva): nada cabia no bolso ($%d)", game.economySystem.currentGold)
        end
        return
    end

    local rerolls = 0
    while rerolls < 2 do
        local bestCardScore = -1
        for _, o in ipairs(game.shopSystem:getCurrentOffers()) do
            if o.type == "card" then
                bestCardScore = math.max(bestCardScore, scoreCardOffer(o))
            end
        end
        local refreshCost = game.shopSystem:getRefreshCost()
        if bestCardScore < 6
            and game.economySystem.currentGold >= refreshCost + 15 then
            game.economySystem:spendGold(refreshCost, "refresh", "shop_refresh")
            game.shopSystem:refreshOffers()
            rerolls = rerolls + 1
            log("- Loja: REROLL #%d ($%d) — vitrine sem carta com score >= 6",
                rerolls, refreshCost)
        else
            break
        end
    end

    local offers = game.shopSystem:getCurrentOffers()
    for _, o in ipairs(offers) do if o.type == "card" then recOffer(o.id) end end

    local rm = game.runManager
    local Config = require("src.core.Config")
    local function serviceWorth(o)
        local ef = o.effect
        if ef == "increase_draw" then
            return 10
        elseif ef == "add_joker_slot" then
            local possuidos = #((run.jokers) or {})
            local ativos = (rm and rm.getMaxJokerSlots and rm:getMaxJokerSlots())
                or (game.maxJokerSlots or 3)
            return (possuidos > ativos) and 9 or -1
        elseif ef == "raise_interest_cap" then
            local eco = game.economySystem
            local tetoNovo = (eco:getInterestCap() or 5)
                + ((Config.Offers and Config.Offers.INTEREST_CAP_PER_BUY) or 2)
            local precisaNoBolso = 5 * tetoNovo
            if act > 2 then return -1 end
            if eco.currentGold - o.cost < precisaNoBolso then return -1 end
            return 8
        end
        return -1
    end

    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and SERVICE_EFFECTS[o.effect] then
            local w = serviceWorth(o)
            if w > 0 and game.economySystem:canAfford(o.cost)
                and spendable() >= o.cost then
                game.economySystem:spendGold(o.cost, o.type, o.id)
                applyUpgradeOffer(game, o)
                run._usedShop = true
                bought = bought + 1
                log("- Loja: comprei SERVICO **%s** ($%d, peso %.1f)",
                    o.name, o.cost, w)
            end
        end
    end

    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and o.effect == "remove_card"
            and #deckIdList(game) >= (prof().trimAt or 14)
            and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            applyUpgradeOffer(game, o)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei SERVICO **%s** ($%d, deck %d cartas)",
                o.name, o.cost, #deckIdList(game))
        end
    end

    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and o.effect == "forge_card"
            and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            local target, ts = bestForgeTarget(game)
            if target and ts > 0 then
                game.economySystem:spendGold(o.cost, o.type, o.id)

                local idx = forgeIndexFor(game, target)
                local before = idx and game.runManager:getUpgradesAt(idx) or nil
                local lvl = idx and game.runManager:upgradeCardAt(idx) or nil
                if game.runManager.registerPaidForge then
                    game.runManager:registerPaidForge()
                end
                if not idx then
                    anomaly("ouro queimado: nenhuma copia forjavel de %s", target)
                elseif not lvl or lvl <= before then
                    anomaly("ouro queimado: forja de %s (copia %d) nao subiu "
                        .. "de nivel (%s -> %s)", target, idx,
                        tostring(before), tostring(lvl))
                end
                run._usedShop = true
                bought = bought + 1
                log("- Loja: **FORJEI** %s → nivel %s ($%d, score %.1f)",
                    target, tostring(lvl), o.cost, ts)
            end
        end
    end

    local cardOffers = {}
    for _, o in ipairs(offers) do
        if o.type == "card" then table.insert(cardOffers, o) end
    end
    if v6Build() then
        for _ = 1, 2 do
            if bought >= 3 then break end
            local ids, byId = {}, {}
            for _, o in ipairs(cardOffers) do
                if not o._bought and game.economySystem:canAfford(o.cost)
                    and spendable() >= o.cost then
                    ids[#ids + 1] = o.id; byId[o.id] = o
                end
            end
            if #ids == 0 then break end
            local pickId, gain = M.pickBySim(game, M.simCandidates(game, ids))
            local o = pickId and byId[pickId]
            if not o or gain < 1.0 then break end
            o._bought = true
            game.economySystem:spendGold(o.cost, o.type, o.id)
            game:addCardToRun(o.id)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei **%s** ($%d, simulacao -%.1f HP)", o.name, o.cost, gain)
            local cd = game.deckManager.cardDatabase:getCard(o.id)
            if cd and cd.type == "joker" then boughtJoker = true end
        end
        cardOffers = {}
    end
    table.sort(cardOffers, function(a, b)
        return scoreCardOffer(a) > scoreCardOffer(b)
    end)
    local cardsThisVisit, cardCap = 0, prof().shopCards or 99
    for _, o in ipairs(cardOffers) do
        if bought >= 3 then break end
        local s = scoreCardOffer(o)
        local cd = game.deckManager.cardDatabase:getCard(o.id)
        local isJoker = cd and cd.type == "joker"
        if s >= 6 and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost and (isJoker or cardsThisVisit < cardCap) then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            game:addCardToRun(o.id)
            run._usedShop = true
            bought = bought + 1
            if not isJoker then cardsThisVisit = cardsThisVisit + 1 end
            log("- Loja: comprei **%s** ($%d, score %.1f)", o.name, o.cost, s)
            if isJoker then boughtJoker = true end
        end
    end

    for _, o in ipairs(offers) do
        if bought >= 3 then break end
        if o.type == "upgrade" and o.effect == "increase_max_health"
            and REAL_UPGRADES[o.effect]
            and game.economySystem:canAfford(o.cost)
            and spendable() >= o.cost then
            game.economySystem:spendGold(o.cost, o.type, o.id)
            applyUpgradeOffer(game, o)
            run._usedShop = true
            bought = bought + 1
            log("- Loja: comprei upgrade filler **%s** ($%d)", o.name, o.cost)
        end
    end

    if boughtJoker then
        optimizeJokerBench(game, "compra na loja")
    end

    if bought == 0 then
        log("- Loja: sai sem comprar (ouro $%d, reserva $%d)",
            game.economySystem.currentGold, reserve)
    end
end

local function playRun(classId, runIdx, maxEndlessFloors, seed, opts)
    opts = opts or {}
    local Game = require("src.core.Game")
    EventManager.clear()
    drainPresentation()
    local game = Game:new()
    game:startNewRun(classId, { seal = tonumber(os.getenv("BALANCE_SEAL") or "0") or 0 })

    if seed then
        local Rng = require("src.systems.Rng")
        Rng.setActive(Rng.new(seed))
        game.runManager.currentRun.runSeed = seed
        love.math.setRandomSeed(seed)
        math.randomseed(seed)
    end

    runRec = {
        class = classId, seed = seed, offered = {}, acquired = {},
        floors = 0, won = false,
        deckByBattle = {}, forges = {}, purchases = {},
    }
    M.lastRecord = runRec
    M._pilotRng = love.math.newRandomGenerator(seed or 1)
    do
        local rm = game.runManager
        local origAt = rm.upgradeCardAt
        rm.upgradeCardAt = function(self, idx)
            local lvl = origAt(self, idx)
            local e = self.currentRun and self.currentRun.currentDeck and self.currentRun.currentDeck[idx]
            runRec.forges[#runRec.forges + 1] = { id = e and (type(e) == "table" and e.id or e) or "?",
                level = lvl, battle = runRec.floors,
                act = self.currentRun and self.currentRun.actNumber or 1 }
            return lvl
        end
    end
    do
        local floorRef = function() return runRec.floors end
        local origCard, origJoker = game.addCardToRun, game.addJokerToRun
        local inCard = false
        game.addCardToRun = function(self, id, meta)
            runRec.acquired[#runRec.acquired + 1] = { id = id, floor = floorRef() }
            inCard = true
            local r1, r2 = origCard(self, id, meta)
            inCard = false
            return r1, r2
        end
        game.addJokerToRun = function(self, id, meta)
            if not inCard then
                runRec.acquired[#runRec.acquired + 1] = { id = id, floor = floorRef() }
            end
            return origJoker(self, id, meta)
        end
    end
    runRec.eco = { earned = {}, spent = {}, byType = {}, shops = {}, slot = {} }
    do
        local eco, rm = game.economySystem, game.runManager
        local function act()
            return (rm.currentRun and rm.currentRun.actNumber) or 1
        end
        local origEarn, origSpend = eco.earnGold, eco.spendGold
        eco.earnGold = function(self, amount, source)
            local got = origEarn(self, amount, source)
            local a = act()
            runRec.eco.earned[a] = (runRec.eco.earned[a] or 0) + (got or 0)
            return got
        end
        eco.spendGold = function(self, amount, itemType, itemId)
            local ok = origSpend(self, amount, itemType, itemId)
            if ok then
                local a = act()
                runRec.eco.spent[a] = (runRec.eco.spent[a] or 0) + amount
                local k = tostring(itemId and itemType == "upgrade" and itemId or itemType)
                runRec.eco.byType[k] = (runRec.eco.byType[k] or 0) + amount
                runRec.purchases[#runRec.purchases + 1] = { act = a, battle = runRec.floors,
                    kind = tostring(itemType), id = tostring(itemId or itemType), gold = amount }
            end
            return ok
        end
    end

    game:startGame()
    pump(game, 0.5)
    installHeadlessPicker(game)

    battleStats = {
        battles = 0, turns = 0, dmgTaken = 0,
        realDecisionTurns = 0, totalTurns = 0,
        armorCapHits = 0,
        byAct = {},
        focusMaxByAct = {},
        thornReflect = 0, thornTurns = 0,
        multJokersMax = 0, multEffective = 1,
        potionsUsed = 0, potionsFound = 0, sustainSlots = 0,
        plays = { n = 0, cards = 0, max = 0, hist = {}, withCombo = 0,
            atk = 0, atkCombo = 0, def = 0, defCombo = 0 },
        dmg = {}, dmgParts = {}, battleLog = {},
    }

    log("")
    log("---")
    log("## RUN %d — %s", runIdx, classId:upper())

    local outcome = "?"
    local floors = 0
    local lastAct = 1

    while true do
        floors = floors + 1
        runRec.floors = floors
        runRec.deckByBattle[floors] = #((game.runManager.currentRun or {}).currentDeck or {})
        local run = game.runManager.currentRun
        local nodeType = (run.currentNode and run.currentNode.type) or "battle"
        local label = ("A%d-F%d [%s]"):format(
            run.actNumber, run.floorInAct, nodeType)

        if (run.actNumber or 1) ~= lastAct then
            lastAct = run.actNumber or 1
            optimizeJokerBench(game, ("inicio do A%d"):format(lastAct))
        end

        local won = playBattle(game, label)
        if not won then
            outcome = ("MORREU em %s (score %d)"):format(label, game.score)
            runRec.death = { act = run.actNumber, floor = run.floorInAct,
                node = nodeType, sprite = game.enemy and game.enemy.spriteId,
                enemyHpLeft = game.enemy and math.max(0, game.enemy.health or 0),
                enemyMaxHp = game.enemy and game.enemy.maxHealth }
            break
        end

        if game:checkVictory() then
            outcome = ("VENCEU O JOGO em %s (score %d)"):format(label, game.score)
            runRec.won = true
            if (maxEndlessFloors or 0) > 0 and game.enterEndless and game:enterEndless() then
                runRec.endless = true
                log("- Vitoria: **seguindo no endless** (ate %d andares)", maxEndlessFloors)
            else
                break
            end
        end
        if run.endlessMode and (run.floorsInEndless or 0) >= (maxEndlessFloors or 0) then
            outcome = ("parou no endless F%d (score %d)"):format(
                run.floorsInEndless or 0, game.score)
            runRec.endlessFloors = run.floorsInEndless or 0
            break
        end
        if opts.maxBattles and floors >= opts.maxBattles then
            outcome = ("CORTE em %s apos %d batalhas (score %d)"):format(label, floors, game.score)
            runRec.cut = true
            break
        end

        if game._buildRoundEvalSources then
            local sources = game:_buildRoundEvalSources()
            local total = 0
            local names = {}
            for _, s in ipairs(sources or {}) do
                total = total + (s.dollars or 0)
                table.insert(names, (s.label or "?") .. " $" .. (s.dollars or 0))
            end
            if total > 0 then
                game.economySystem:earnGold(total, "round_eval")
            end
            log("- Resgate: +$%d (%s) → ouro $%d", total,
                table.concat(names, " · "), game.economySystem.currentGold)
        end

        doRewards(game)

        local safety = 0
        repeat
            safety = safety + 1
            if not game.runManager:getPendingNodes() then
                game.runManager:advanceFloorInAct()
                game.runManager:generateNextNodes(3)
            end
            do
                local RM = require("src.systems.RunModifiers")
                local pend = RM.pending(game.runManager.currentRun)
                if pend then
                    local best, bestS = pend[1], math.huge
                    for _, id in ipairs(pend) do
                        local c = RM.getCurse(id)
                        if c and c.score < bestS then best, bestS = id, c.score end
                    end
                    RM.chooseCurse(game.runManager.currentRun, best)
                    log("- Endless: maldicao escolhida **%s** (ciclo %d)", best,
                        RM.cycle(game.runManager.currentRun))
                end
            end
            local pending = game.runManager:getPendingNodes()
            local idx, node = chooseNode(game, pending)
            local opts = {}
            for _, n in ipairs(pending) do table.insert(opts, n.type) end
            game.runManager:chooseNode(idx)
            log("")
            log("**Caminho A%d-F%d**: opcoes [%s] → escolhi **%s** (HP %d%%, $%d)",
                game.runManager.currentRun.actNumber,
                game.runManager.currentRun.floorInAct,
                table.concat(opts, ", "), node.type,
                math.floor(100 * game.player.health / game.player.maxHealth),
                game.economySystem.currentGold)

            local BT = MapManager.NODE_TYPES
            if node.type == BT.REST then
                doRest(game)
            elseif node.type == BT.EVENT then
                doEvent(game)
            elseif node.type == BT.SHOP then
                doShop(game)
            else
                game:nextPhase()
                pump(game, 0.5)
                break
            end
        until safety > 12

        if not game.player:isAlive() then
            outcome = ("MORREU fora de batalha (evento?) score %d"):format(game.score)
            runRec.death = { act = game.runManager.currentRun.actNumber,
                floor = game.runManager.currentRun.floorInAct, node = "event" }
            break
        end
        if safety > 12 then
            outcome = "loop de mapa abortado (bug?)"
            break
        end
    end

    local run = game.runManager.currentRun
    runRec.outcome = outcome
    runRec.act, runRec.floorInAct = run.actNumber, run.floorInAct
    runRec.score = game.score
    runRec.hpEnd, runRec.maxHp = game.player.health, game.player.maxHealth
    runRec.gold = game.economySystem.currentGold
    runRec.endlessFloors = run.endlessMode and (run.floorsInEndless or 0) or 0
    runRec.curses = require("src.systems.RunModifiers").totalCurseStacks(run)
    runRec.battles = battleStats.battles
    runRec.potionsUsed, runRec.potionsFound, runRec.sustainSlots = battleStats.potionsUsed, battleStats.potionsFound, battleStats.sustainSlots
    runRec.turns = battleStats.turns
    runRec.byAct = battleStats.byAct
    runRec.plays = battleStats.plays
    runRec.dmg = battleStats.dmg
    runRec.dmgParts = battleStats.dmgParts
    runRec.battleLog = battleStats.battleLog
    runRec.pilot = M.policy
    runRec.seal = run.seal or 0
    runRec.deck, runRec.jokers = {}, {}
    for _, e in ipairs(run.currentDeck or {}) do
        runRec.deck[#runRec.deck + 1] = type(e) == "table" and e.id or e
    end
    for i, e in ipairs(run.jokers or {}) do
        runRec.jokers[#runRec.jokers + 1] = {
            id = type(e) == "table" and e.id or e,
            active = game.runManager.isJokerActive and game.runManager:isJokerActive(i) or false,
        }
    end
    log("")
    log("### Resultado: %s", outcome)
    log("- Andares visitados: %d | Ato final: A%d-F%d%s", floors,
        run.actNumber, run.floorInAct, run.endlessMode and " (endless)" or "")
    log("- Batalhas: %d | turnos/batalha: %.1f", battleStats.battles,
        battleStats.battles > 0 and battleStats.turns / battleStats.battles or 0)
    log("- Turnos com decisao REAL (sobrou carta pagavel): %d de %d (%.0f%%)",
        battleStats.realDecisionTurns, battleStats.totalTurns,
        battleStats.totalTurns > 0
            and 100 * battleStats.realDecisionTurns / battleStats.totalTurns or 0)
    log("- Bloqueio no cap: %d turno(s) — defesa alem disso evapora",
        battleStats.armorCapHits or 0)
    log("- Deck final: %d cartas | Ouro final: $%d | Score: %d",
        #(run.currentDeck or {}), game.economySystem.currentGold, game.score)

    for act, ba in pairs(battleStats.byAct) do
        if ba.turns > 0 then
            log("- A%d: dano/turno %.1f | sofrido/turno %.1f | %.1f turnos/batalha",
                act, ba.dealt / ba.turns, ba.taken / ba.turns,
                ba.turns / math.max(1, ba.battles))
        end
    end

    log("- Tripwires v5:")
    log("  - jokers multiplicadores ativos (max simultaneo): %d | efetivo x%.2f (P0.9: max, nunca produto)",
        battleStats.multJokersMax or 0, battleStats.multEffective or 1)
    if classId == "mage" then
        local fm = battleStats.focusMaxByAct or {}
        log("  - foco do mago (max por ato): A1 %d | A2 %d | A3 %d",
            fm[1] or 0, fm[2] or 0, fm[3] or 0)
    end
    if (battleStats.thornTurns or 0) > 0 then
        log("  - thorn refletido/turno (estimado, regra P2.3): %.1f em %d turno(s) — banda alvo 25-38 (Muralha)",
            battleStats.thornReflect / battleStats.thornTurns,
            battleStats.thornTurns)
    end

    do
        local names = {}
        for _, id in ipairs(run.currentDeck or {}) do
            local cardId = type(id) == "table" and id.id or id
            local cd = game.deckManager.cardDatabase:getCard(cardId)
            table.insert(names, (cd and cd.name or tostring(cardId)))
        end
        log("- Deck: %s", table.concat(names, ", "))
    end

    return outcome
end

function M.run(runsArg, classArg, seedArg)
    local runsPerClass = tonumber(runsArg or "2") or 2
    local classes = { "warrior", "mage", "rogue" }
    if classArg and classArg ~= "all" then classes = { classArg } end
    local seedBase = tonumber(seedArg)

    _G.EventManager = EventManager
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    installDotMeter()
    if os.getenv("AUTOPLAY_PILOT") and os.getenv("AUTOPLAY_PILOT") ~= "" then
        M.setPilot(os.getenv("AUTOPLAY_PILOT"))
    end
    log("- Piloto: **%s**", tostring(M.policy))

    log("# Diario do Piloto de IA — autoplay v5")
    log("")
    log("Runs por classe: %d | Classes: %s | Seed base: %s", runsPerClass,
        table.concat(classes, ", "), seedBase and tostring(seedBase) or "aleatoria")

    local outcomes = {}
    for _, classId in ipairs(classes) do
        for i = 1, runsPerClass do
            local seed = seedBase and (seedBase + i) or nil
            local ok, res = pcall(playRun, classId, i, 3, seed)
            if ok then
                table.insert(outcomes, classId .. " #" .. i
                    .. (seed and (" (seed " .. seed .. ")") or "") .. ": " .. res)
            else
                table.insert(outcomes, classId .. " #" .. i .. ": CRASH " .. tostring(res))
                log("")
                log("!!! CRASH na run: %s", tostring(res))
            end
        end
    end

    log("")
    log("---")
    log("## Placar geral")
    for _, o in ipairs(outcomes) do log("- %s", o) end
    log("")
    log("## Veneno/DoT: quanto a armadura do inimigo comeu")
    if dotMeter.ticks > 0 then
        local perdido = dotMeter.declared - dotMeter.effective
        log("- ticks de DoT: %d | declarado %d | efetivo %d | ABSORVIDO %d (%.1f%%)",
            dotMeter.ticks, dotMeter.declared, dotMeter.effective, perdido,
            100 * perdido / math.max(1, dotMeter.declared))
        log("- ticks com absorcao parcial ou total: %d (%.1f%% dos ticks)",
            dotMeter.absorbedTicks,
            100 * dotMeter.absorbedTicks / dotMeter.ticks)
    else
        log("- nenhum tick de DoT nesta bateria")
    end

    log("")
    log("## Anomalias detectadas: %d", #anomalies)
    for _, an in ipairs(anomalies) do log("- %s", an) end
    if #anomalies > 0 then
        print(("\n[autoplay] *** %d ANOMALIAS — ver relatorio ***"):format(#anomalies))
    end

    local content = table.concat(report, "\n")
    love.filesystem.write("autoplay_report.md", content)
    print("\n[autoplay] relatorio salvo: autoplay_report.md ("
        .. #report .. " linhas)")
    love.event.quit()
end

function M.playRunRecord(classId, runIdx, seed, opts)
    local outcome = playRun(classId, runIdx,
        tonumber(os.getenv("BALANCE_ENDLESS") or "0") or 0, seed, opts)
    local rec = M.lastRecord or {}
    rec.outcome = rec.outcome or outcome
    return rec
end
function M.installHooks() installDotMeter(); installDamageLedger() end
function M.getAnomalies() return anomalies end
function M.getReport() return report end

function M.replayBattle(snap, seed)
    local Game = require("src.core.Game")
    local game = Game:new()
    game:startNewRun(snap.class)
    local run = game.runManager.currentRun
    run.currentDeck = deepcopy(snap.deck)
    run.jokers = deepcopy(snap.jokers) or {}
    run.jokerActive = deepcopy(snap.jokerActive) or {}
    run.services = deepcopy(snap.services) or {}
    run.maxJokerSlots = snap.maxJokerSlots
    run.actNumber, run.floorInAct = snap.act, snap.floorInAct
    run.currentNode = deepcopy(snap.node) or { type = "battle" }
    local Rng = require("src.systems.Rng")
    Rng.setActive(Rng.new(seed))
    love.math.setRandomSeed(seed)
    math.randomseed(seed)
    game:startGame()
    pump(game, 0.3)
    game.player.maxHealth = snap.maxHp
    game.player.baseMaxMana = snap.baseMana
    game.player.maxMana = snap.baseMana
    game:nextPhase()
    pump(game, 0.3)
    game.player.health = snap.maxHp
    M._resetBattleStats()
    local before = game.player.health
    local won, turns = playBattle(game, "bench")
    return { won = won and true or false, hpLost = before - math.max(0, game.player.health),
        turns = turns, maxHp = snap.maxHp,
        enemyLeft = game.enemy and game.enemy.maxHealth
            and math.max(0, game.enemy.health) / math.max(1, game.enemy.maxHealth) or 0 }
end
M.snapshotBattle = snapshotBattle

M.SIM_PER_FIGHT = 1
M.SIM_CANDIDATES = 2
local function simPerFight() return prof().simPerFight or M.SIM_PER_FIGHT end
function M.simCandidates(game, ids)
    local cap = prof().simCandidates or M.SIM_CANDIDATES
    if not cap or #ids <= cap then return ids end
    local cdb = game.deckManager.cardDatabase
    local dctx = AI.deckContext(game)
    local scored = {}
    for _, id in ipairs(ids) do
        local cd = cdb:getCard(id)
        scored[#scored + 1] = { id = id, w = AI.cardWorth(game, cd, dctx, false) }
    end
    table.sort(scored, function(a, b) return a.w > b.w end)
    local out = {}
    for i = 1, math.min(cap, #scored) do out[#out + 1] = scored[i].id end
    return out
end
local evalCounter = 0
function M.evalDeckSim(game, mutate)
    local Rng = require("src.systems.Rng")
    local savedRng = Rng.get()
    local savedLove = love.math.getRandomState()
    local savedStats, savedQuiet, savedHook = battleStats, M.quiet, M.onBattleStart
    M.quiet = true
    M.onBattleStart = nil
    local base = snapshotBattle(game)
    local run = game.runManager.currentRun
    local Config = require("src.core.Config")
    local act, floor = run.actNumber or 1, run.floorInAct or 1
    if floor >= 8 and act < (Config.TotalActs or 6) then act, floor = act + 1, 0 end
    local fights = {
        { act = act, floor = 8, node = "boss" },
        { act = act, floor = math.min(7, floor + 2), node = "battle" },
    }
    if mutate then mutate(base) end
    evalCounter = evalCounter + 1
    local savedQueues = EventManager.queues

    local total, n = 0, 0
    local realPrint = print
    for fi, f in ipairs(fights) do
        for k = 1, simPerFight() do
            local snap = deepcopy(base)
            snap.act, snap.floorInAct, snap.node = f.act, f.floor, { type = f.node }
            EventManager.queues = { base = {}, ui = {} }
            print = function() end
            local ok, r = pcall(M.replayBattle, snap, 9100000 + fi * 101 + k * 7919
                + (run.runSeed or 0) % 100000)
            print = realPrint
            drainPresentation()
            if ok and r then
                local loss = math.min(r.hpLost, r.maxHp)
                if not r.won then loss = loss + 30 + 60 * (r.enemyLeft or 1) end
                total, n = total + loss, n + 1
            end
        end
    end
    EventManager.queues = savedQueues
    Rng.setActive(savedRng)
    love.math.setRandomState(savedLove)
    math.randomseed((run.runSeed or 1) + evalCounter * 31)
    battleStats, M.quiet, M.onBattleStart = savedStats, savedQuiet, savedHook
    return n > 0 and total / n or 999
end

function M.pickBySim(game, ids)
    local cdb = game.deckManager.cardDatabase
    local baseLoss = M.evalDeckSim(game, nil)
    local best, bestLoss = nil, baseLoss
    for _, id in ipairs(ids) do
        local cd = cdb:getCard(id)
        local loss = M.evalDeckSim(game, function(snap)
            if cd and cd.type == "joker" then
                snap.jokers = snap.jokers or {}
                snap.jokers[#snap.jokers + 1] = id
                snap.jokerActive = snap.jokerActive or {}
                local active = 0
                for i = 1, #snap.jokers - 1 do if snap.jokerActive[i] then active = active + 1 end end
                snap.jokerActive[#snap.jokers] = active < (snap.maxJokerSlots or 3)
            else
                snap.deck[#snap.deck + 1] = id
            end
        end)
        if loss < bestLoss then best, bestLoss = id, loss end
    end
    return best, baseLoss - bestLoss, baseLoss
end

M._playBattle = playBattle
function M._resetBattleStats()
    battleStats = {
        battles = 0, turns = 0, dmgTaken = 0,
        realDecisionTurns = 0, totalTurns = 0,
        armorCapHits = 0, byAct = {},
        focusMaxByAct = {}, thornReflect = 0, thornTurns = 0,
        multJokersMax = 0, multEffective = 1,
        potionsUsed = 0, potionsFound = 0, sustainSlots = 0,
        plays = { n = 0, cards = 0, max = 0, hist = {}, withCombo = 0,
            atk = 0, atkCombo = 0, def = 0, defCombo = 0 },
        dmg = {}, dmgParts = {}, battleLog = {},
    }
end

return M
