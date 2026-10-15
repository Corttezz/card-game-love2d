local BM = {}

local floor, max, min = math.floor, math.max, math.min

function BM.spec(enemy)
    local kit = enemy and enemy.kit
    return kit and kit.mechanic or nil
end

function BM.stacks(enemy, name)
    if not enemy or not enemy.statusEffects then return 0 end
    for _, st in ipairs(enemy.statusEffects) do
        if st.name == name then return st.stacks or 0 end
    end
    return 0
end

function BM.setStacks(enemy, name, n)
    n = max(0, floor(n or 0))
    local list = enemy.statusEffects
    for i, st in ipairs(list) do
        if st.name == name then
            if n <= 0 then
                table.remove(list, i)
            else
                st.stacks, st.duration = n, 999
            end
            return n
        end
    end
    if n > 0 then list[#list + 1] = { name = name, stacks = n, duration = 999 } end
    return n
end

local function mech(enemy)
    enemy._mech = enemy._mech or { turnDmg = 0, broke = 0 }
    return enemy._mech
end

local function queue(enemy, ev)
    enemy._mechEvents = enemy._mechEvents or {}
    enemy._mechEvents[#enemy._mechEvents + 1] = ev
end

function BM.runeThreshold(enemy)
    local m = BM.spec(enemy)
    if not m or m.kind ~= "runes" then return nil end
    return max(1, floor((enemy.maxHealth or 1) * m.breakPct))
end

function BM.onSpawn(enemy)
    enemy._mech = nil
    enemy._mechEvents = nil
    local m = BM.spec(enemy)
    if not m then return end
    if m.kind == "runes" then
        BM.setStacks(enemy, m.status, m.start or 0)
    end
end

function BM.forcedMove(enemy)
    local m = BM.spec(enemy)
    if not m then return nil end
    if m.kind == "runes" and BM.stacks(enemy, m.status) >= m.max then
        return m.move
    end
    return nil
end

function BM.shapeIntent(enemy, intent, move)
    local m = BM.spec(enemy)
    if not m then return end
    if m.kind == "runes" and move.runes then
        intent.runes = true
        intent.hits = (intent.perHit or 0) > 0 and BM.stacks(enemy, m.status) or 0
    end
end

function BM.onDamaged(enemy, hpLost, source)
    local m = BM.spec(enemy)
    if not m or not hpLost or hpLost <= 0 or enemy.health <= 0 then return end
    if m.kind == "runes" and source ~= "dot" then
        local s = mech(enemy)
        s.turnDmg = s.turnDmg + hpLost
        local due = floor(s.turnDmg / BM.runeThreshold(enemy)) - s.broke
        if due > 0 then
            s.broke = s.broke + due
            queue(enemy, { kind = "rune_break", n = due })
        end
    end
end

function BM.onPlayerTurnStart(game)
    local e = game and game.enemy
    if not e or not BM.spec(e) then return end
    local s = mech(e)
    s.turnDmg, s.broke = 0, 0
end

function BM.hasPending(enemy)
    return enemy and enemy._mechEvents and #enemy._mechEvents > 0 or false
end

function BM.popEvent(enemy)
    local list = enemy and enemy._mechEvents
    if not list or #list == 0 then return nil end
    return table.remove(list, 1)
end

function BM.applyEvent(enemy, ev)
    local m = BM.spec(enemy)
    if not m or not enemy:isAlive() then return nil end
    if ev.kind == "rune_break" then
        local have = BM.stacks(enemy, m.status)
        local n = min(ev.n or 1, have)
        if n <= 0 then return nil end
        BM.setStacks(enemy, m.status, have - n)
        local it = enemy.intent
        if it and it.runes then
            it.hits = min(it.hits or 0, have - n)
        end
        return { kind = "rune_break", n = n, left = have - n }
    end
    return nil
end

function BM.turnEndSteps(enemy)
    local m = BM.spec(enemy)
    if not m or not enemy:isAlive() then return {} end
    if m.kind == "runes" then
        return { { kind = "rune_gain", n = m.gain or 1 } }
    end
    return {}
end

function BM.applyStep(enemy, step)
    local m = BM.spec(enemy)
    if not m or not enemy:isAlive() then return nil end
    if step.kind == "rune_gain" then
        local have = BM.stacks(enemy, m.status)
        local n = min(step.n, m.max - have)
        if n <= 0 then return nil end
        BM.setStacks(enemy, m.status, have + n)
        return { kind = "rune_gain", n = n, total = have + n }
    end
    return nil
end

function BM.onHitLanded(enemy, intent)
    local m = BM.spec(enemy)
    if not m or not intent then return end
    if m.kind == "runes" and intent.runes then
        BM.setStacks(enemy, m.status, BM.stacks(enemy, m.status) - 1)
    end
end

function BM.strikeFor(enemy, intent)
    local m = BM.spec(enemy)
    if not m or not intent then return nil end
    if m.kind == "runes" and intent.runes then return "rune" end
    local s = m.strikes
    return s and s[intent.id] or nil
end

function BM.pillVars(enemy, name)
    local m = BM.spec(enemy)
    if not m or m.status ~= name then return nil end
    if m.kind == "runes" then
        return { value = BM.runeThreshold(enemy), max = m.max,
                 dealt = floor(mech(enemy).turnDmg) }
    end
    return nil
end

return BM
