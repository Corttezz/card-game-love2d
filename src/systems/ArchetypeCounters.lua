local I18n = require("src.i18n.I18n")
local TagSystem = require("src.systems.TagSystem")

local AC = {}

AC.STATUS = "counter"

AC.ARCHETYPE = {
    metal_freeze  = "metal",
    magnet        = "metal",
    lightning_rod = "lightning",
    card_flood    = "loop",
    copy_exile    = "copies",
    strength_tax  = "strength",
    drink_poison  = "poison",
    no_thorns     = "thorns",
    pierce_all    = "block",
    exhaust_tax   = "exhaust",
    blood_mirror  = "blood",
    eclipse_first = "echo",
}

function AC.spec(enemy)
    local kit = enemy and enemy.kit
    return kit and kit.counter or nil
end

function AC.active(game, kind)
    local e = game and game.enemy
    if not e or (e.health or 0) <= 0 then return nil end
    local s = AC.spec(e)
    if s and s.kind == kind then return s end
    return nil
end

function AC.onSpawn(enemy)
    if not AC.spec(enemy) then return end
    local BM = require("src.systems.BossMechanics")
    BM.setStacks(enemy, AC.STATUS, 1)
end

function AC.pillVars(enemy)
    local s = AC.spec(enemy)
    if not s then return nil end
    return { variant = s.kind, stacks = 1, value = s.value or 0, max = s.from or s.min or 0 }
end

local function text(key, vars, fallback)
    return I18n.t("enemy_kit." .. key, vars, fallback or key)
end

function AC.describe(enemy)
    local v = AC.pillVars(enemy)
    if not v then return nil end
    return text("status.counter.desc_" .. v.variant, v, "")
end

function AC.announce(game)
    local e = game and game.enemy
    local d = e and AC.describe(e)
    if not d or d == "" or not game.addMessage then return end
    game:addMessage(text("msg.counter_intro", { text = d }, "{text}"), "warning")
end

function AC.fire(game, kind, value, opts)
    if not game then return end
    game._counterFires = game._counterFires or {}
    game._counterFires[kind] = (game._counterFires[kind] or 0) + 1
    local line = text("msg.counter_" .. kind, { value = value }, kind)
    if game.addMessage then game:addMessage(line, "warning") end
    if opts and opts.quiet then return end
    local okER, ER = pcall(require, "src.ui.EnemyRenderer")
    local okFT, FloatingText = pcall(require, "src.ui.FloatingText")
    if okER and okFT and ER.getLastPos then
        local ex, ey = ER.getLastPos()
        if ex and ey then
            FloatingText.spawn(line, ex, ey - 40, { kind = "movename", hold = 0.6, lift = 26 })
        end
    end
end

function AC.isMetal(card)
    return card and TagSystem.cardHasTag(card, "metal") or false
end

function AC.freezeTag(game)
    return AC.active(game, "metal_freeze") and "metal" or nil
end

function AC.magnetArmor(game, card)
    local s = AC.active(game, "magnet")
    if s and AC.isMetal(card) then return s.value or 0 end
    return 0
end

function AC.floodArmor(game, nthCard)
    local s = AC.active(game, "card_flood")
    if s and nthCard >= (s.from or 9) then return s.value or 0 end
    return 0
end

function AC.eclipseMult(game)
    local s = AC.active(game, "eclipse_first")
    return s and (s.value or 50) / 100 or nil
end

function AC.onCardPlayed(game, card)
    local e = game and game.enemy
    if not e then return end
    local n = game._cardsPlayedTurn or 0
    local armor = AC.magnetArmor(game, card)
    if armor > 0 then
        e:addArmor(armor)
        AC.fire(game, "magnet", armor)
    end
    local flood = AC.active(game, "card_flood")
    if flood then
        local from = flood.from or 9
        if n == from - 1 then
            AC.fire(game, "card_flood_warn", from, { quiet = true })
        elseif n >= from then
            local BM = require("src.systems.BossMechanics")
            local m = BM.spec(e)
            if m and m.kind == "runes" then
                BM.setStacks(e, m.status, math.min(m.max, BM.stacks(e, m.status) + 1))
            end
            e:addArmor(flood.value or 0)
            AC.fire(game, "card_flood", n)
        end
    end
    local mf = AC.active(game, "metal_freeze")
    if mf and AC.isMetal(card) and game.player then
        game.player.frost = (game.player.frost or 0) + (mf.value or 1)
        AC.fire(game, "metal_freeze", mf.value or 1, { quiet = true })
    end
end

function AC.exiles(game, card)
    if not AC.active(game, "copy_exile") or not card or not card.id then return false end
    game._playedIdsTurn = game._playedIdsTurn or {}
    local n = (game._playedIdsTurn[card.id] or 0) + 1
    game._playedIdsTurn[card.id] = n
    if n >= 2 then
        AC.fire(game, "copy_exile", n)
        return true
    end
    return false
end

function AC.onEvoke(game, orb)
    local s = AC.active(game, "lightning_rod")
    if not s or not orb or orb.type ~= "lightning" then return end
    game.enemy:gainStrength(s.value or 1)
    AC.fire(game, "lightning_rod", s.value or 1)
end

function AC.onExhaust(game)
    local s = AC.active(game, "exhaust_tax")
    if not s then return end
    game.enemy:gainStrength(s.value or 1)
    AC.fire(game, "exhaust_tax", s.value or 1)
end

function AC.onSelfDamage(game, lost)
    local s = AC.active(game, "blood_mirror")
    if not s or not lost or lost <= 0 then return end
    local healed = game.enemy:healSelf(lost)
    if healed > 0 then AC.fire(game, "blood_mirror", healed) end
end

function AC.blocksThorns(game)
    if not AC.active(game, "no_thorns") then return false end
    AC.fire(game, "no_thorns", 0)
    return true
end

function AC.piercesAll(enemy)
    local s = AC.spec(enemy)
    return (s and s.kind == "pierce_all") or false
end

function AC.onPlayerTurnEnd(game)
    local s = AC.active(game, "strength_tax")
    local p = game and game.player
    if not s or not p or (p.strength or 0) < (s.min or 4) then return 0 end
    local steal = math.floor(p.strength / 2)
    p.strength = p.strength - steal
    game.enemy:gainStrength(steal)
    AC.fire(game, "strength_tax", steal)
    return steal
end

function AC.drinkPoison(game)
    local s = AC.active(game, "drink_poison")
    local e = game and game.enemy
    if not s or not e then return 0 end
    local BM = require("src.systems.BossMechanics")
    local m = BM.spec(e)
    local roots = (m and m.kind == "roots") and BM.stacks(e, m.status) or 1
    local cap = roots * (s.value or 2)
    for _, st in ipairs(e.statusEffects or {}) do
        if st.name == "poison" and (st.stacks or 0) > 0 then
            local n = math.min(cap, st.stacks)
            st.stacks = st.stacks - n
            st.duration = math.max(0, math.min(st.duration or 0, st.stacks))
            local healed = e:healSelf(n)
            AC.fire(game, "drink_poison", n)
            return n, healed
        end
    end
    return 0
end

return AC
