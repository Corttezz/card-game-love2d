local EnemyStates = {}

EnemyStates.LIST = { "poison", "burn", "weak", "vulnerable", "strength", "enraged", "regen", "block", "veil" }
local INDEX = {}
for i, n in ipairs(EnemyStates.LIST) do INDEX[n] = i end
EnemyStates.INDEX = INDEX

EnemyStates.ALIAS = { fury = "enraged", frail = "vulnerable", eclipse = "enraged", armor = "block" }
EnemyStates.TOKEN_ONLY = { swarm = true }
EnemyStates.PRIORITY = { "burn", "poison", "enraged", "block", "strength", "regen", "vulnerable", "weak", "veil" }
EnemyStates.MAX_KINDS = 2
EnemyStates.RATE = { poison = 0.9, weak = 0.7, strength = 1.15, enraged = 1.3 }
EnemyStates.PRESETS = {
    {}, { "poison" }, { "burn" }, { "weak" }, { "vulnerable" }, { "strength" }, { "enraged" },
    { "regen" }, { "block" }, { "veil" }, { "poison", "weak" }, { "burn", "enraged" },
}

local K_DRIPS, K_MIST, K_GLINT, K_BUBBLES, K_EMBERS = 3, 6, 9, 10, 2
local K_FLAME, K_SWEAT, K_STEAM, K_SPARK, K_MOTE = 11, 12, 13, 14, 15
EnemyStates.K_FLAME, EnemyStates.K_SWEAT, EnemyStates.K_STEAM = K_FLAME, K_SWEAT, K_STEAM
EnemyStates.K_SPARK, EnemyStates.K_MOTE = K_SPARK, K_MOTE

EnemyStates.GEN = {
    poison     = { { k = K_BUBBLES, rate = 1.6, at = "upper", c = { 0.55, 0.86, 0.32 } },
                   { k = K_DRIPS, rate = 0.9, at = "lower", c = { 0.42, 0.70, 0.22 } } },
    burn       = { { k = K_FLAME, rate = 18.0, at = "baseRow" },
                   { k = K_EMBERS, rate = 2.2, at = "base" } },
    weak       = { { k = K_SWEAT, rate = 0.9, at = "head" } },
    vulnerable = { { k = K_GLINT, rate = 1.2, at = "edge", c = { 1.0, 1.0, 1.0 } } },
    strength   = { { k = K_SPARK, rate = 2.4, at = "upper" } },
    enraged    = { { k = K_STEAM, rate = 0, burst = 4, every = 1.2, at = "head" } },
    regen      = { { k = K_MOTE, rate = 2.0, at = "edge" } },
    block      = { { k = K_GLINT, rate = 0, sweep = true, at = "edge", c = { 0.86, 0.93, 1.0 } } },
    veil       = { { k = K_MIST, rate = 2.6, at = "base", back = true } },
}

local NB = 256
local ex, ey = {}, {}
for i = 1, NB do ex[i], ey[i] = 0, 0 end
local B = {
    id = nil, n = 0, headX = 0, headY = 0, baseY = 0, baseL = 0, baseR = 0,
    top = 0, h = 1, w = 1, eyes = {}, nEyes = 0,
}
EnemyStates._B = B

local ST = {
    k = {}, forced = nil, enemy = nil, dmg0 = nil, enemyRef = nil, prevArmor = 0,
    sweepT = -1, shudderT = 0, shudderNext = 3, trembleT = 0, trembleNext = 2.5,
    burstT = 0, active = {}, nActive = 0, kinds = {}, nKinds = 0, clock = 0,
    acc = {}, emitters = {}, nEmit = 0,
}
for i = 1, #EnemyStates.LIST do ST.k[EnemyStates.LIST[i]] = 0 end
for i = 1, 8 do ST.active[i] = false end
for i = 1, 4 do ST.kinds[i] = 0 end
for i = 1, 8 do ST.emitters[i] = { src = nil, i = 0, acc = 0, name = nil } end
EnemyStates._ST = ST

function EnemyStates.canonical(name, enemy)
    if not name then return nil end
    if INDEX[name] then return name end
    if EnemyStates.ALIAS[name] then return EnemyStates.ALIAS[name] end
    local kit = enemy and enemy.kit
    if kit and kit.phases then
        for _, ph in ipairs(kit.phases) do
            if ph.id == name then return "enraged" end
        end
    end
    return nil
end

function EnemyStates.prepare(id)
    if not id then return false end
    B.id = id
    B.n = 0
    B.nEyes = 0
    local path = "assets/sprites/characters/enemies/" .. id .. "/animations/idle/south/0.png"
    if not love.filesystem.getInfo(path) then path = "assets/sprites/characters/enemies/" .. id .. "/south.png" end
    local ok, d = pcall(love.image.newImageData, path)
    if not ok or not d then return false end
    local w, h = d:getWidth(), d:getHeight()
    B.w, B.h = w, h
    local top, bot, minX, maxX = h, -1, w, -1
    local cand = 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.1 then
                if y < top then top = y end
                if y > bot then bot = y end
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                local edge = x == 0 or y == 0 or x == w - 1 or y == h - 1
                if not edge then
                    local _, _, _, a1 = d:getPixel(x - 1, y)
                    local _, _, _, a2 = d:getPixel(x + 1, y)
                    local _, _, _, a3 = d:getPixel(x, y - 1)
                    local _, _, _, a4 = d:getPixel(x, y + 1)
                    edge = a1 <= 0.1 or a2 <= 0.1 or a3 <= 0.1 or a4 <= 0.1
                end
                if edge then cand = cand + 1 end
            end
        end
    end
    if bot < 0 then return false end
    local stride = math.max(1, math.floor(cand / NB + 0.999))
    local c = 0
    local hx, hn = 0, 0
    local headBand = top + math.max(2, math.floor((bot - top) * 0.12))
    local bl, br = maxX, minX
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.1 then
                if y <= headBand then hx, hn = hx + x, hn + 1 end
                if y >= bot - 4 then
                    if x < bl then bl = x end
                    if x > br then br = x end
                end
                local edge = x == 0 or y == 0 or x == w - 1 or y == h - 1
                if not edge then
                    local _, _, _, a1 = d:getPixel(x - 1, y)
                    local _, _, _, a2 = d:getPixel(x + 1, y)
                    local _, _, _, a3 = d:getPixel(x, y - 1)
                    local _, _, _, a4 = d:getPixel(x, y + 1)
                    edge = a1 <= 0.1 or a2 <= 0.1 or a3 <= 0.1 or a4 <= 0.1
                end
                if edge then
                    c = c + 1
                    if c % stride == 0 and B.n < NB then
                        B.n = B.n + 1
                        ex[B.n], ey[B.n] = x, y
                    end
                end
            end
        end
    end
    B.top, B.baseY = top, bot
    B.headX = hn > 0 and hx / hn or (minX + maxX) / 2
    B.headY = top + 1
    B.baseL, B.baseR = bl, br
    local em = require("src.data.enemy_emissives")[id]
    for i = #B.eyes, 1, -1 do B.eyes[i] = nil end
    if em then
        for _, a in ipairs(em) do
            B.nEyes = B.nEyes + 1
            B.eyes[B.nEyes] = { a.xr * w, a.yr * h }
        end
    end
    return true
end

local function resetSt()
    for i = 1, #EnemyStates.LIST do ST.k[EnemyStates.LIST[i]] = 0 end
end

function EnemyStates.reset()
    resetSt()
    ST.enemyRef, ST.dmg0, ST.prevArmor = nil, nil, 0
    ST.sweepT = -1
    ST.nActive, ST.nKinds, ST.nEmit = 0, 0, 0
    B.id = nil
end

function EnemyStates.force(list)
    ST.forced = list
    if not list then ST.presetI = nil end
end

function EnemyStates.cycleForced()
    local P = EnemyStates.PRESETS
    ST.presetI = ((ST.presetI or 0) % #P) + 1
    ST.forced = P[ST.presetI]
    return ST.forced
end

function EnemyStates.forcedLabel()
    if not ST.forced then return "ao vivo" end
    if #ST.forced == 0 then return "nenhum" end
    return table.concat(ST.forced, "+")
end

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

function EnemyStates.read(enemy, dying)
    resetSt()
    if dying then return end
    if ST.forced then
        for _, n in ipairs(ST.forced) do ST.k[n] = 1 end
        if ST.k.block > 0 and ST.sweepT < 0 and ST.clock - (ST.lastSweep or 0) > 2.5 then
            ST.sweepT = 0
            ST.lastSweep = ST.clock
        end
        return
    end
    if not enemy then return end
    if ST.enemyRef ~= enemy then
        ST.enemyRef = enemy
        ST.dmg0 = enemy.baseDamage
        ST.prevArmor = enemy.armor or 0
    end
    for _, e in ipairs(enemy.statusEffects or {}) do
        local n = EnemyStates.canonical(e.name, enemy)
        if n then
            local s = e.stacks or 1
            local kk = clamp(0.45 + 0.11 * s, 0.45, 1)
            if n == "weak" or n == "vulnerable" then kk = clamp(0.6 + 0.2 * (e.duration or 1), 0.6, 1) end
            if kk > ST.k[n] then ST.k[n] = kk end
        end
    end
    if enemy.attackPattern == "aggressive" and ST.k.enraged < 0.6 then ST.k.enraged = 0.6 end
    local armor = enemy.armor or 0
    if armor > 0 then
        ST.k.block = clamp(armor / math.max(1, (enemy.maxHealth or 100) * 0.12), 0.35, 1)
    end
    if armor > ST.prevArmor + 0.5 then ST.sweepT = 0 end
    ST.prevArmor = armor
    if ST.dmg0 and enemy.baseDamage and enemy.baseDamage > ST.dmg0 then
        ST.k.strength = clamp(0.5 + 2 * (enemy.baseDamage - ST.dmg0) / math.max(1, ST.dmg0), 0.5, 1)
    end
    if enemy.intentVeilCause == "veil" and enemy.intentVisibility and enemy.intentVisibility ~= "full" then
        ST.k.veil = 0.8
    end
end

function EnemyStates.level(name) return ST.k[name] or 0 end

function EnemyStates.any()
    for i = 1, #EnemyStates.LIST do
        if ST.k[EnemyStates.LIST[i]] > 0 then return true end
    end
    return false
end

function EnemyStates.rate()
    local r = 1
    for n, m in pairs(EnemyStates.RATE) do
        local k = ST.k[n]
        if k > 0 then r = r * (1 + (m - 1) * math.max(0.6, k)) end
    end
    return clamp(r, 0.6, 1.45)
end

function EnemyStates.stretchPx()
    local s = 0
    if ST.k.weak > 0 then s = s - (ST.k.weak > 0.7 and 2 or 1) end
    if ST.k.strength > 0 then s = s + 1 end
    return s
end

function EnemyStates.jitterPx()
    if ST.shudderT > 0 or ST.trembleT > 0 then
        return (math.floor(ST.clock * 30) % 2 == 0) and 1 or -1
    end
    return 0
end

function EnemyStates.tint(r, g, b, t)
    local k = ST.k.poison
    if k > 0 then
        r = r * (1 - 0.20 * k)
        b = b * (1 - 0.24 * k)
    end
    k = ST.k.weak
    if k > 0 then
        local l = 0.299 * r + 0.587 * g + 0.114 * b
        local d = 0.28 * k
        r, g, b = r + (l - r) * d, g + (l - g) * d, b + (l - b) * d
    end
    k = ST.k.block
    if k > 0 then
        r = r * (1 - 0.07 * k)
        g = g * (1 - 0.03 * k)
    end
    return r, g, b
end

function EnemyStates.charK(t)
    local k = ST.k.burn
    if k <= 0 then return 0 end
    return k * (0.75 + 0.25 * math.sin((t or 0) * 13) * math.sin((t or 0) * 5.3))
end

function EnemyStates.eyePulse(t)
    local k = ST.k.enraged
    if k <= 0 or B.nEyes == 0 then return 0 end
    return k * (0.5 + 0.5 * math.sin((t or 0) * 6))
end

local function stateData(data, name)
    local s = data and data.states and data.states[name]
    return s
end

local function chooseKinds(data)
    ST.nActive, ST.nKinds, ST.nEmit = 0, 0, 0
    local KI = package.loaded["src.ui.EnemyLife"] and package.loaded["src.ui.EnemyLife"].KIND_INDEX or {}
    for pass = 1, 2 do
        for _, n in ipairs(EnemyStates.PRIORITY) do
            if ST.k[n] > 0 and ST.nKinds < EnemyStates.MAX_KINDS then
                local sd = stateData(data, n)
                local list = (sd and sd.fx) or EnemyStates.GEN[n]
                local src = list[pass]
                if src then
                    local kind = src.k or KI[src.kind]
                    local dup = false
                    for i = 1, ST.nKinds do if ST.kinds[i] == kind then dup = true end end
                    if kind and not dup then
                        ST.nKinds = ST.nKinds + 1
                        ST.kinds[ST.nKinds] = kind
                        ST.nEmit = ST.nEmit + 1
                        local e = ST.emitters[ST.nEmit]
                        e.src, e.name, e.kind = src, n, kind
                    end
                end
            end
        end
    end
end
EnemyStates._chooseKinds = chooseKinds

function EnemyStates.kindCount() return ST.nKinds end

local function pickPoint(at, R)
    if at == "baseRow" then
        return B.baseL - 1 + R() * (B.baseR - B.baseL + 2), B.baseY - R() * 2
    end
    if B.n == 0 then return B.w * 0.5, B.h * 0.5 end
    local H = math.max(1, B.baseY - B.top)
    for _ = 1, 8 do
        local i = math.floor(R() * B.n) + 1
        local x, y = ex[i], ey[i]
        local f = (y - B.top) / H
        if at == "edge"
            or (at == "upper" and f < 0.7)
            or (at == "lower" and f > 0.45)
            or (at == "head" and f < 0.25)
            or (at == "base" and f > 0.9) then
            return x, y
        end
    end
    if at == "head" then return B.headX + (R() - 0.5) * 4, B.headY end
    if at == "base" then return B.baseL + R() * math.max(1, B.baseR - B.baseL), B.baseY end
    local i = math.floor(R() * B.n) + 1
    return ex[i], ey[i]
end

function EnemyStates.update(dt, data, L, dying)
    ST.clock = ST.clock + dt
    if ST.shudderT > 0 then ST.shudderT = ST.shudderT - dt end
    if ST.trembleT > 0 then ST.trembleT = ST.trembleT - dt end
    if ST.sweepT >= 0 then
        ST.sweepT = ST.sweepT + dt
        if ST.sweepT > 0.6 then ST.sweepT = -1 end
    end
    if dying then
        ST.nEmit, ST.nKinds = 0, 0
        return
    end
    local R = L._rand
    if ST.k.poison > 0 then
        ST.shudderNext = ST.shudderNext - dt
        if ST.shudderNext <= 0 then
            ST.shudderT = 0.18
            ST.shudderNext = 3 + 3 * R()
        end
    end
    if ST.k.vulnerable > 0 then
        ST.trembleNext = ST.trembleNext - dt
        if ST.trembleNext <= 0 then
            ST.trembleT = 0.25
            ST.trembleNext = 2.5 + 1.5 * R()
        end
    end
    chooseKinds(data)
    if not L.spawning() then return end
    for i = 1, ST.nEmit do
        local e = ST.emitters[i]
        local src = e.src
        local k = ST.k[e.name]
        if src.xr then
            e.acc = e.acc + dt * (src.rate or 1) * 1.5 * k
            while e.acc >= 1 do
                e.acc = e.acc - 1
                local sp = src.spread or 0.05
                L.spawnRaw(e.kind, src.xr * B.w + (R() - 0.5) * sp * B.w, src.yr * B.h, src.tint)
            end
        elseif src.sweep then
            if ST.sweepT >= 0 then
                local band = B.w * (ST.sweepT / 0.6) * 1.2 - B.w * 0.1
                for _ = 1, 3 do
                    local x, y = pickPoint("edge", R)
                    if math.abs(x - band) < 3 then L.spawnRaw(e.kind, x, y, src.c) end
                end
            end
        elseif src.burst then
            ST.burstT = ST.burstT - dt
            if ST.burstT <= 0 then
                ST.burstT = src.every * (0.7 + 0.6 * R())
                for _ = 1, src.burst do
                    L.spawnRaw(e.kind, B.headX + (R() - 0.5) * 6, B.headY + R() * 2, src.c)
                end
            end
        else
            e.acc = e.acc + dt * src.rate * k
            while e.acc >= 1 do
                e.acc = e.acc - 1
                local x, y = pickPoint(src.at, R)
                L.spawnRaw(e.kind, x, y, src.c)
            end
        end
    end
end

function EnemyStates.loopFor(data, warm)
    if not data or not data.states then return "idle", nil, nil end
    for _, n in ipairs(EnemyStates.PRIORITY) do
        if ST.k[n] > 0 then
            local sd = data.states[n]
            if sd and sd.clip and warm[sd.clip] then return sd.clip, sd.fps, sd end
        end
    end
    return "idle", nil, nil
end

function EnemyStates.eyes() return B.eyes, B.nEyes end

return EnemyStates
