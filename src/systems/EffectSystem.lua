local Debug = require("src.core.Debug")

local EffectSystem = {}
EffectSystem.__index = EffectSystem

local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local CardFeel = require("src.systems.CardFeel")
local CombatBeats = require("src.systems.CombatBeats")
local function msg(key, vars) return I18n.t("messages." .. key, vars) end

local function notifyOrbUI(fn, ...)
    local ok, OrbRow = pcall(require, "src.ui.OrbRow")
    if ok and OrbRow and OrbRow[fn] then
        pcall(OrbRow[fn], ...)
    end
end

function EffectSystem:new()
    return setmetatable({}, EffectSystem)
end

local function sinkOf(game)
    return game and game._beatSink or nil
end

local function checkEnrage(game)
    if game and game.announceEnrageIfPending then
        game:announceEnrageIfPending(sinkOf(game))
    end
end

local function enemyHurt()
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER and ER.triggerHurt then pcall(ER.triggerHurt) end
end

local function showEnemyDamage(v)
    if not v or v <= 0 then return end
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if not okER then return end
    if ER.triggerHurt then pcall(ER.triggerHurt) end
    if not ER.getLastPos then return end
    local ex, ey = ER.getLastPos()
    if not ex then return end
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT and FloatingText.spawn then
        FloatingText.spawn("-" .. tostring(v), ex, ey - 40, { kind = "damage" })
    end
end

local function pushJokerProc(game, sink, joker, label, kind)
    if not joker then return end
    local slotIndex
    for i, j in ipairs(game.jokerSlots or {}) do
        if j == joker then slotIndex = i break end
    end
    if not slotIndex then return end
    local proc = { slotIndex = slotIndex, joker = joker,
                   label = label, kind = kind or "mult" }
    if sink then
        sink[#sink + 1] = proc
        return
    end
    local now = (love.timer and love.timer.getTime()) or 0
    if not game._directProcT or now - game._directProcT > 0.6 then
        game._directProcT, game._directProcN = now, 0
    end
    game._directProcN = (game._directProcN or 0) + 1
    local ord = game._directProcN
    local function fire()
        local ok, JokerProcFx = pcall(require, "src.ui.JokerProcFx")
        if ok and JokerProcFx.tick then pcall(JokerProcFx.tick, proc, ord) end
    end
    local EM = _G.EventManager
    if EM and EM.after and ord > 1 then
        EM.after((ord - 1) * 0.18, fire)
    else
        fire()
    end
end

function EffectSystem:notifyJokerProc(game, joker, label, kind, sink)
    pushJokerProc(game, sink, joker, label, kind)
end

local DEBUFF_THEME = { burn = "fire" }
local warnedTheme = {}
local function debuffTheme(name)
    if DEBUFF_THEME[name] then return DEBUFF_THEME[name] end
    if CardFeel.THEMES[name] then return name end
    if not warnedTheme[name] then
        warnedTheme[name] = true
        Debug.warn("[EffectSystem] debuff sem tema visual: '" .. tostring(name)
            .. "' (usando magic) — registre em DEBUFF_THEME ou CardFeel.THEMES")
    end
    return "magic"
end

local function multLabel(v)
    return "×" .. string.format("%g", v or 1)
end

function EffectSystem:jokerSteps(game, card, baseValue, turnContext, echoFired)
    local finalValue = baseValue
    local entries = {}
    local echoUsed = false

    local bestMult, bestMultJoker = nil, nil
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                local isMatchingMult =
                    (effect.type == "damage_multiplier" and effect.target == "attack"
                        and card.type == "attack")
                    or (effect.type == "defense_multiplier" and effect.target == "defense"
                        and card.type == "defense")
                if isMatchingMult and (not bestMult
                    or (effect.value or 1) > (bestMult.value or 1)) then
                    bestMult = effect
                    bestMultJoker = joker
                end
            end
        end
    end
    if bestMult then
        local newValue, m = self:processEffect(bestMult, card, finalValue, turnContext)
        if newValue ~= finalValue then
            finalValue = newValue
            entries[#entries + 1] = { joker = bestMultJoker, op = "mult",
                value = bestMult.value or 1, label = multLabel(bestMult.value),
                kind = "mult", text = m, after = finalValue }
        end
    end

    if card.type == "attack" and not echoFired then
        for _, joker in ipairs(game.jokerSlots or {}) do
            for _, effect in ipairs(joker.effects or {}) do
                if effect.type == "echo_first_attack" then
                    echoUsed = true
                    local fator = effect.value or 2
                    finalValue = finalValue * fator
                    entries[#entries + 1] = { joker = joker, op = "mult", value = fator,
                        label = multLabel(fator), kind = "mult",
                        text = msg("echo_first", { value = fator }), after = finalValue }
                    break
                end
            end
            if echoUsed then break end
        end
    end

    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                if effect.type ~= "damage_multiplier" and effect.type ~= "defense_multiplier"
                    and effect.type ~= "echo_first_attack" then
                    local newValue, m = self:processEffect(effect, card, finalValue, turnContext)
                    if newValue ~= finalValue then
                        local delta = newValue - finalValue
                        finalValue = newValue
                        entries[#entries + 1] = { joker = joker, op = "add", value = delta,
                            label = (delta >= 0 and "+" or "") .. string.format("%g", delta),
                            kind = "chips", text = m, after = finalValue }
                    end
                end
            end
        end
    end
    return finalValue, entries, echoUsed
end

function EffectSystem:applyJokerEffects(game, card, baseValue, turnContext)
    local finalValue, entries, echoUsed = self:jokerSteps(game, card, baseValue,
        turnContext, game._echoFiredThisTurn)
    if echoUsed then game._echoFiredThisTurn = true end
    local procs = {}
    for _, e in ipairs(entries) do
        pushJokerProc(game, procs, e.joker, e.label, e.kind)
    end
    return finalValue, procs
end

function EffectSystem:predictJokerProcs(game, card)
    if not game or not game.jokerSlots or #game.jokerSlots == 0 then return 0 end
    local isAtk = card.type == "attack"
    local isDef = card.type == "defense"
    if not isAtk and not isDef then return 0 end
    local n, multSeen = 0, false
    for _, joker in ipairs(game.jokerSlots) do
        for _, e in ipairs(joker.effects or {}) do
            local t = e.type
            if isAtk then
                if t == "damage_multiplier" and e.target == "attack" then
                    if not multSeen then n = n + 1; multSeen = true end
                elseif t == "echo_first_attack" then
                    if not game._echoFiredThisTurn then n = n + 1 end
                elseif t == "damage_bonus" or t == "on_attack_heal"
                    or t == "on_attack_debuff" then
                    n = n + 1
                end
            else
                if t == "defense_multiplier" and e.target == "defense" then
                    if not multSeen then n = n + 1; multSeen = true end
                elseif t == "defense_bonus" or t == "on_defend_damage" then
                    n = n + 1
                end
            end
        end
    end
    return n
end

function EffectSystem:processEffect(effect, card, currentValue, turnContext)
    local t = effect.type
    local v = effect.value or 1
    local target = effect.target

    if t == "damage_multiplier" and target == "attack" and card.type == "attack" then
        return currentValue * v, msg("dmg_multiplier", { value = v })

    elseif t == "defense_multiplier" and target == "defense" and card.type == "defense" then
        return currentValue * v, msg("def_multiplier", { value = v })

    elseif t == "damage_bonus" and card.type == "attack" then
        return currentValue + v, msg("dmg_bonus", { value = v })

    elseif t == "defense_bonus" and card.type == "defense" then
        return currentValue + v, msg("def_bonus", { value = v })
    end

    return currentValue, nil
end

function EffectSystem.hitCount(card)
    for _, e in ipairs((card and card.effects) or {}) do
        if e.type == "multi_hit" and card.type == "attack" then
            return math.max(1, e.value or 1)
        end
    end
    return 1
end

function EffectSystem:applyCardEffects(game, card, baseValue)
    local finalValue = baseValue
    if not card.effects or type(card.effects) ~= "table" then
        return finalValue
    end
    for _, effect in ipairs(card.effects) do
        local t = effect.type
        local v = effect.value or 1

        if t == "damage_bonus_self" and card.type == "attack" then
            finalValue = finalValue + v

        elseif t == "multi_hit" and card.type == "attack" then
            finalValue = finalValue * math.max(1, v)
        end
    end
    return finalValue
end

local SELF_STEPPED = {
    channel_orb = true, evoke_orb = true, evoke_all_orbs = true,
}
local EFFECT_HOLD = {
    apply_debuff = "STATUS", apply_buff = "STATUS",
    gain_strength = "STATUS", gain_dexterity = "STATUS",
    increase_max_mana = "STATUS",
}

function EffectSystem:processEffectCardStepped(game, effect, showFallback)
    local run = function()
        local handled = self:processEffectCard(game, effect)
        if not handled and showFallback then
            local text = I18n.effectDesc(effect)
            if text and text ~= "" then game:addMessage(text, "info") end
        end
    end
    if SELF_STEPPED[effect.type] then
        run()
        return
    end
    CombatBeats.step(sinkOf(game), "effect." .. tostring(effect.type), run,
        EFFECT_HOLD[effect.type] or "SIDE_EFFECT")
end

function EffectSystem:processEffectCard(game, effect)
    local t = effect.type
    local v = effect.value or 0

    if t == "instant_heal" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        Sfx.play("healShimmer")
        CardFeel.burstAtPlayer("heal", 1.0)
        return true

    elseif t == "self_damage" then
        game.player:loseHealth(v)
        return true

    elseif t == "restore_mana" then
        game.player.mana = math.min(game.player.maxMana, game.player.mana + v)
        return true

    elseif t == "increase_max_mana" then
        game.player.maxMana = game.player.maxMana + v
        game.player.mana = game.player.mana + v
        return true

    elseif t == "add_armor" then
        game.player:addArmor(v)
        return true

    elseif t == "magic_damage" then
        game.enemy:takeDamage(v)
        checkEnrage(game)
        game.score = game.score + v
        CardFeel.burstAtEnemy("magic", 0.9)
        showEnemyDamage(v)
        return true

    elseif t == "draw_cards" then
        for i = 1, v do game:drawCard((i - 1) * 0.08) end
        return true

    elseif t == "apply_debuff" then
        local debuff = {
            name = effect.value or "debuff",
            duration = effect.duration or 2,
            stacks = effect.stacks or 1,
        }
        game.enemy:addStatusEffect(debuff)
        if debuff.name == "poison" then
            require("src.systems.AchievementSystem").onPoisonApplied(game, game.enemy)
        end
        Sfx.play("debuffApplied")
        CardFeel.burstAtEnemy(debuffTheme(debuff.name), 0.8)
        return true

    elseif t == "reveal_intent" then
        if game.enemy and game.enemy.revealIntent then
            local wasHidden = game.enemy:getIntentVisibility() ~= "full"
            game.enemy:revealIntent(math.max(1, math.floor(v > 0 and v or 1)))
            if wasHidden then
                game:addMessage(I18n.t("messages.intent_revealed", nil, "Intent revealed"), "info")
                Sfx.play("effectChime")
            end
        end
        return true

    elseif t == "discard_cards" then
        local discarded = 0
        for _ = 1, v do
            if #game.hand > 0 then
                local card = table.remove(game.hand,
                    require("src.systems.Rng").get():random("misc", #game.hand))
                table.insert(game.discard, card)
                discarded = discarded + 1
            end
        end
        return true

    elseif t == "gain_strength" then
        game.player:gainStrength(v)
        Sfx.play("strengthGain")
        CardFeel.burstAtPlayer("buff", 0.9)
        return true

    elseif t == "gain_dexterity" then
        game.player:gainDexterity(v)
        Sfx.play("strengthGain", { pitch = 1.15 })
        CardFeel.burstAtPlayer("armor", 0.9)
        return true

    elseif t == "apply_buff" then
        local name = effect.value or "buff"
        local stacks = effect.stacks or 1
        local duration = effect.duration or 3
        game.player:addBuff(name, duration, stacks)
        return true

    elseif t == "channel_orb" then
        self:_stepChannelOrb(game, { type = effect.orbType or "lightning", value = v },
            sinkOf(game))
        return true

    elseif t == "evoke_orb" then
        if #(game.player.orbs or {}) == 0 then
            game:addMessage(msg("no_orbs"), "warning")
            return true
        end
        self:_stepEvokeOrb(game, sinkOf(game), 1)
        return true

    elseif t == "evoke_all_orbs" then
        local count = #game.player.orbs
        for k = 1, count do
            self:_stepEvokeOrb(game, sinkOf(game), k)
        end
        if count > 0 then
            CombatBeats.step(sinkOf(game), "orb.evoke_all_done", function() end, "MICRO")
        end
        return true

    elseif t == "aoe_magic_damage" then
        game.enemy:takeDamage(v)
        checkEnrage(game)
        game.score = game.score + v
        CardFeel.burstAtEnemy("magic", 1.2)
        showEnemyDamage(v)
        return true

    elseif t == "mystery" then
        local pool = effect.pool or {
            { type = "instant_heal", value = 6 },
            { type = "draw_cards", value = 2 },
            { type = "add_armor", value = 8 },
            { type = "magic_damage", value = 8 },
            { type = "gain_strength", value = 2 },
            { type = "channel_orb", orbType = "lightning", value = 3 },
        }
        local pick = pool[require("src.systems.Rng").get():random("misc", #pool)]
        return self:processEffectCard(game, pick)

    elseif t == "strength_scaling" or t == "dexterity_scaling"
        or t == "multi_hit" or t == "damage_bonus_self"
        or t == "retain_armor" then
        return true

    elseif t == "exhaust" or t == "innate" or t == "retain" then
        return true
    end

    return false
end

function EffectSystem.orbPulseValue(orb, focus)
    local ev = (orb.value or 1) + (focus or 0)
    if orb.type == "lightning" or orb.type == "ice" then
        return math.ceil(ev / 2)
    elseif orb.type == "fire" or orb.type == "holy" then
        return math.ceil(ev / 3)
    end
    return 0
end

function EffectSystem.orbEvokeValue(orb, focus)
    local ev = (orb.value or 1) + (focus or 0)
    if orb.type == "dark" then return ev * 2 end
    return ev
end

function EffectSystem:_evokeOrbEffect(game, orb)
    if not orb then return end
    local v = orb.value or 1
    local focus = 0
    if game.player and game.player.getBuffStacks then
        focus = game.player:getBuffStacks("focus") or 0
    end
    v = v + focus
    local dmg = EffectSystem.orbEvokeValue(orb, focus)
    if orb.type == "lightning" then
        game.enemy:takeDamage(dmg)
        checkEnrage(game)
        CardFeel.burstAtEnemy("lightning", 1.1)
        showEnemyDamage(dmg)
    elseif orb.type == "ice" then
        game.player:addArmor(v)
        CardFeel.burstAtPlayer("ice", 0.9)
    elseif orb.type == "dark" then
        game.enemy:takeDamage(dmg)
        checkEnrage(game)
        CardFeel.burstAtEnemy("dark", 1.2)
        showEnemyDamage(dmg)
    elseif orb.type == "fire" then
        game.enemy:takeDamage(dmg)
        checkEnrage(game)
        game.enemy:addStatusEffect({ name = "burn", duration = 2,
            stacks = math.max(1, math.floor(v / 2)) })
        CardFeel.burstAtEnemy("fire", 1.1)
        showEnemyDamage(dmg)
    elseif orb.type == "holy" then
        local amount = self:applyHealMultiplier(game, v)
        game.player:heal(amount)
        CardFeel.burstAtPlayer("holy", 1.0)
    end
end

local CHANNEL_PITCH_BASE, CHANNEL_PITCH_STEP = 0.92, 0.15
local EVOKE_PITCH_BASE,   EVOKE_PITCH_STEP   = 1.02, 0.10
local OVERFLOW_PITCH = 0.72

function EffectSystem:_stepChannelOrb(game, orb, sink)
    local p = game.player
    if not p or not p.addOrb then return end

    CombatBeats.step(sink, "orb.make_room", function()
        if #(p.orbs or {}) < (p.orbSlots or 3) then return end
        local overflow = p:popOldestOrb()
        if not overflow then return end
        CombatBeats.mark("orb.overflow")
        CombatBeats.extendCurrent("ORB")
        notifyOrbUI("notifyEvoke", 1, overflow, "overflow")
        self:_evokeOrbEffect(game, overflow)
        game:addMessage(msg("orb_overflow", { name = I18n.t("status.orb_" .. tostring(overflow.type)
            .. ".name", nil, tostring(overflow.type)) }), "arcane")
        Sfx.play("orbEvoke", { pitch = OVERFLOW_PITCH })
    end, "MICRO")

    CombatBeats.step(sink, "orb.channel", function()
        p:addOrb(orb)
        local slot = #p.orbs
        require("src.systems.AchievementSystem").onOrbChanneled(game)
        Sfx.play("orbChannel",
            { pitch = CHANNEL_PITCH_BASE + (slot - 1) * CHANNEL_PITCH_STEP })
        notifyOrbUI("notifyChannel", slot, orb)
    end, "ORB")
end

function EffectSystem:_stepEvokeOrb(game, sink, ord)
    CombatBeats.step(sink, "orb.evoke", function()
        local orb = game.player:popOldestOrb()
        if not orb then return end
        notifyOrbUI("notifyEvoke", 1, orb, "evoke")
        self:_evokeOrbEffect(game, orb)
        local pitch = EVOKE_PITCH_BASE - ((ord or 1) - 1) * EVOKE_PITCH_STEP
        Sfx.play("orbEvoke", { pitch = math.max(0.78, pitch) })
    end, "ORB")
end

local PULSE_LAND_STEP = 0.06
local PULSE_LANDING = {
    lightning = { theme = "lightning", where = "enemy",  pitch = 1.22, k = 1.00 },
    fire      = { theme = "fire",      where = "enemy",  pitch = 1.08, k = 1.10 },
    ice       = { theme = "ice",       where = "player", pitch = 1.18, k = 0.95 },
    holy      = { theme = "holy",      where = "player", pitch = 1.26, k = 0.90 },
    dark      = { theme = "dark",      where = "orb",    pitch = 0.94, k = 0.95 },
}

local function landPulse(orbType, idx, landed)
    local cfg = PULSE_LANDING[orbType]
    if not cfg or not landed then return end
    local theme = CardFeel.THEMES[cfg.theme]
    if theme and theme.sfx then
        Sfx.play(theme.sfx, { pitch = cfg.pitch + (idx - 1) * PULSE_LAND_STEP })
    end
    if cfg.where == "enemy" then
        enemyHurt()
        CardFeel.burstAtEnemy(cfg.theme, cfg.k)
    elseif cfg.where == "player" then
        CardFeel.burstAtPlayer(cfg.theme, cfg.k)
    elseif cfg.where == "orb" then
        notifyOrbUI("burstAtSlot", idx, cfg.theme, cfg.k)
    end
end

function EffectSystem.previewPulseLanding(orbType, idx)
    landPulse(orbType, idx or 1, true)
end

function EffectSystem:orbPassiveTick(game, sink)
    local p = game.player
    if not p or not p.orbs or #p.orbs == 0 then return end
    sink = sink or sinkOf(game)
    local focus = (p.getBuffStacks and p:getBuffStacks("focus")) or 0
    for i, orb in ipairs(p.orbs) do
        local idx, o = i, orb
        local pulse = EffectSystem.orbPulseValue(o, focus)
        CombatBeats.step(sink, "orb.pulse." .. tostring(o.type), function()
            local landed = false
            if o.type == "lightning" or o.type == "fire" then
                notifyOrbUI("notifyPulse", idx, "-" .. pulse, "damage")
                if pulse > 0 and game.enemy and game.enemy:isAlive() then
                    game.enemy:takeDamage(pulse)
                    checkEnrage(game)
                    landed = true
                    if o.type == "lightning" and game.enemy.revealNextIntent then
                        game.enemy:revealNextIntent(1)
                    end
                end
            elseif o.type == "ice" then
                notifyOrbUI("notifyPulse", idx, "+" .. pulse, "armor")
                if pulse > 0 then
                    p:addArmor(pulse)
                    landed = true
                end
            elseif o.type == "holy" then
                notifyOrbUI("notifyPulse", idx, "+" .. pulse, "heal")
                if pulse > 0 then
                    local amount = self:applyHealMultiplier(game, pulse)
                    p:heal(amount)
                    landed = true
                end
            elseif o.type == "dark" then
                o.value = (o.value or 1) + 2
                notifyOrbUI("notifyPulse", idx, "+2", "grow")
                landed = true
            end
            landPulse(o.type, idx, landed)
        end, "ORB")
    end
end

function EffectSystem.announceBurnTick(game, dmg)
    if not dmg or dmg <= 0 then return end
    Sfx.play("impactFire", { pitch = 1.15 })
    CardFeel.burstAtEnemy("fire", 0.9)
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER then
        if ER.triggerHurt then pcall(ER.triggerHurt) end
        if ER.getLastPos then
            local ex, ey = ER.getLastPos()
            local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
            if okFT and ex and ey then
                FloatingText.spawn("-" .. dmg, ex, ey,
                    { color = { 1.0, 0.55, 0.20, 1 }, fontSize = 18 })
            end
        end
    end
end

function EffectSystem:applyHealMultiplier(game, amount, procSink)
    local final = amount
    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                if effect.type == "heal_multiplier" then
                    local before = final
                    final = final * (effect.value or 1)
                    if math.floor(final) ~= math.floor(before) then
                        pushJokerProc(game, procSink, joker,
                            multLabel(effect.value or 1) .. " PV", "heal")
                    end
                end
            end
        end
    end
    return math.floor(final)
end

function EffectSystem.thornStacks(game)
    local p = game and game.player
    if not p or not p.getBuffStacks then return 0 end
    return p:getBuffStacks("thorn") or 0
end

function EffectSystem:fireThornReflect(game)
    local v = EffectSystem.thornStacks(game)
    if v <= 0 then return 0 end
    local enemy = game.enemy
    if not enemy or not enemy.isAlive or not enemy:isAlive() then return 0 end
    enemy:takeDamage(v)
    Sfx.play("thornReflect")
    CardFeel.burstAtEnemy("physical", 0.7)
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    if okER and ER.triggerHurt then ER.triggerHurt() end
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okFT and okER and ER.getLastPos then
        local ex, ey = ER.getLastPos()
        if ex and ey then
            FloatingText.spawn("-" .. v, ex, ey, { kind = "damage", fontSize = 20 })
        end
    end

    local armados = game._jokerThornFiredThisTurn
    if armados then
        for _, slotJoker in ipairs(game.jokerSlots or {}) do
            if slotJoker and armados[slotJoker.id or slotJoker] then
                self:notifyJokerProc(game, slotJoker, "-" .. v, "damage")
            end
        end
    end

    return v
end

EffectSystem.TRIGGER_OF = {
    on_attack_heal     = "attack",
    on_attack_debuff   = "attack",
    on_defend_damage   = "defend",
    channel_per_turn   = "turn_start",
    strength_per_turn  = "turn_start",
    regen_per_turn     = "turn_start",
    damage_per_turn    = "turn_start",
    on_turn_start_draw = "turn_start",
}

function EffectSystem:applyTriggerEffects(game, triggerType, context)
    local sink = context and context.beatSink

    for _, joker in ipairs(game.jokerSlots or {}) do
        if joker.effects then
            for _, effect in ipairs(joker.effects) do
                if EffectSystem.TRIGGER_OF[effect.type] == triggerType then
                    local j, e = joker, effect
                    CombatBeats.step(sink, "trigger." .. triggerType .. "." .. tostring(e.type),
                        function()
                            if context then context.sourceJoker = j end
                            self:processTriggerEffect(game, e, triggerType, context)
                            if context then context.sourceJoker = nil end
                        end, EffectSystem.beatHoldFor(e.type))
                end
            end
        end
    end

    if context and context.sourceCard and context.sourceCard.effects then
        for _, effect in ipairs(context.sourceCard.effects) do
            if EffectSystem.TRIGGER_OF[effect.type] == triggerType then
                local e = effect
                CombatBeats.step(sink, "trigger." .. triggerType .. "." .. tostring(e.type),
                    function()
                        if context then context.sourceJoker = nil end
                        self:processTriggerEffect(game, e, triggerType, context)
                    end, EffectSystem.beatHoldFor(e.type))
            end
        end
    end
end

local TRIGGER_HOLD = {
    on_defend_damage   = "STATUS",
    on_attack_debuff   = "STATUS",
    strength_per_turn  = "STATUS",
    channel_per_turn   = "ORB",
}
function EffectSystem.beatHoldFor(effectType)
    return TRIGGER_HOLD[effectType] or "SIDE_EFFECT"
end

function EffectSystem:processTriggerEffect(game, effect, triggerType, context)
    local t = effect.type
    local v = effect.value or 0

    if t == "on_attack_heal" and triggerType == "attack" then
        local amount = self:applyHealMultiplier(game, v, context and context.procSink)
        game.player:heal(amount)
        Sfx.play("healShimmerSoft")
        pushJokerProc(game, context and context.procSink, context and context.sourceJoker,
            "+" .. amount .. " PV", "heal")

    elseif t == "on_defend_damage" and triggerType == "defend" then
        local fired = true
        local joker = context and context.sourceJoker
        if joker then
            local jid = joker.id or joker
            game._jokerThornFiredThisTurn = game._jokerThornFiredThisTurn or {}
            if game._jokerThornFiredThisTurn[jid] then
                fired = false
            else
                game._jokerThornFiredThisTurn[jid] = true
            end
        end
        if fired and game.player and game.player.addBuff then
            game.player:addBuff("thorn", 1, v)
            pushJokerProc(game, context and context.procSink, joker,
                "+" .. v .. " " .. I18n.t("status.thorn.name", nil, "Espinhos"), "buff")
            local okCF, CF = pcall(require, "src.systems.CardFeel")
            if okCF then CF.burstAtPlayer("armor", 0.6) end
        end

    elseif t == "channel_per_turn" and triggerType == "turn_start" then
        if game.player and game.player.addOrb then
            self:_stepChannelOrb(game,
                { type = effect.orbType or "lightning", value = math.max(1, v) }, nil)
            pushJokerProc(game, context and context.procSink,
                context and context.sourceJoker, "+1 Orbe", "buff")
        end

    elseif t == "strength_per_turn" and triggerType == "turn_start" then
        game.player:gainStrength(v)
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "+" .. v .. " Forca", "buff")

    elseif t == "regen_per_turn" and triggerType == "turn_start" then
        local amount = self:applyHealMultiplier(game, v, context and context.procSink)
        game.player:heal(amount)
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "+" .. amount .. " PV", "heal")

    elseif t == "damage_per_turn" and triggerType == "turn_start" then
        game.player:loseHealth(v)
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "-" .. v .. " PV", "damage")

    elseif t == "on_turn_start_draw" and triggerType == "turn_start" then
        local n = math.max(1, v)
        for i = 1, n do
            game:drawCard((i - 1) * 0.06)
        end
        pushJokerProc(game, context and context.procSink,
            context and context.sourceJoker, "+" .. n .. " cartas", "buff")

    elseif t == "on_attack_debuff" and triggerType == "attack" then
        if context and context.target and context.target.addStatusEffect then
            local name = effect.debuffName or "poison"
            context.target:addStatusEffect({
                name = name,
                stacks = effect.stacks or 1,
                duration = effect.duration or 2,
            })
            Sfx.play("debuffApplied")
            local okCF, CardFeel = pcall(require, "src.systems.CardFeel")
            if okCF then
                CardFeel.burstAtEnemy(debuffTheme(name), 0.8)
            end
            pushJokerProc(game, context.procSink, context.sourceJoker,
                I18n.t("status." .. name .. ".name", nil, name), "buff")
        end
    end
end

return EffectSystem
