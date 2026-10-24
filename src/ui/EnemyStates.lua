local EnemyStates = {}

EnemyStates.LIST = { "poison", "burn", "weak", "vulnerable", "strength", "enraged", "regen", "block", "veil" }
local INDEX = {}
for i, n in ipairs(EnemyStates.LIST) do INDEX[n] = i end
EnemyStates.INDEX = INDEX

EnemyStates.ALIAS = { fury = "enraged", frail = "vulnerable", eclipse = "enraged", armor = "block" }
EnemyStates.TOKEN_ONLY = { swarm = true }
EnemyStates.PRIORITY = { "burn", "poison", "enraged", "block", "strength", "regen", "vulnerable", "weak", "veil" }
EnemyStates.MAX_KINDS = 4
EnemyStates.RATE = { poison = 0.9, weak = 0.7, strength = 1.15, enraged = 1.3 }
EnemyStates.PRESETS = {
    {}, { "poison" }, { "burn" }, { "weak" }, { "vulnerable" }, { "strength" }, { "enraged" },
    { "regen" }, { "block" }, { "veil" }, { "poison", "weak" }, { "burn", "enraged" },
}

local K_DRIPS, K_MIST, K_GLINT, K_EMBERS, K_ASH = 3, 6, 9, 2, 8
local K_SWEAT, K_STEAM, K_SPARK = 12, 13, 14
local K_STAR, K_MIASMA, K_VAPOR, K_ABSORB = 18, 19, 20, 21
EnemyStates.K_SWEAT, EnemyStates.K_STEAM, EnemyStates.K_SPARK = K_SWEAT, K_STEAM, K_SPARK
EnemyStates.K_STAR, EnemyStates.K_MIASMA, EnemyStates.K_VAPOR, EnemyStates.K_ABSORB = K_STAR, K_MIASMA, K_VAPOR, K_ABSORB
EnemyStates.K_MOTE = K_ABSORB

EnemyStates.GEN = {
    poison     = { { k = K_DRIPS, rate = 2.2, at = "under", c = { 0.46, 0.82, 0.24 } },
                   { k = K_MIASMA, rate = 1.6, at = "upper" } },
    burn       = { { k = K_EMBERS, rate = 7.0, at = "top" },
                   { k = K_ASH, rate = 1.6, at = "head", c = { 0.22, 0.20, 0.20 } } },
    weak       = { { k = K_STAR, rate = 0, stars = 3, at = "head" },
                   { k = K_SWEAT, rate = 1.6, at = "head", sweat = true } },
    vulnerable = { { k = K_GLINT, rate = 2.4, at = "edge", c = { 0.92, 0.74, 1.0 } } },
    strength   = { { k = K_SPARK, rate = 20.0, at = "top" } },
    enraged    = { { k = K_STEAM, rate = 0, burst = 10, every = 1.0, at = "head" } },
    regen      = { { k = K_ABSORB, rate = 9.0, at = "edge" } },
    block      = { { k = K_GLINT, rate = 0, sweep = true, at = "edge", c = { 0.90, 0.95, 1.0 } },
                   { k = K_GLINT, rate = 0.9, at = "edge", c = { 0.86, 0.93, 1.0 } } },
    veil       = { { k = K_MIST, rate = 1.2, at = "base", back = true } },
}

local NB = 256
local ex, ey, eu, ed = {}, {}, {}, {}
for i = 1, NB do ex[i], ey[i], eu[i], ed[i] = 0, 0, false, false end
local B = {
    id = nil, n = 0, headX = 0, headY = 0, baseY = 0, baseL = 0, baseR = 0,
    top = 0, h = 1, w = 1, eyes = {}, nEyes = 0, nUp = 0, nDown = 0, cx = 0, cy = 0,
}
EnemyStates._B = B

local ST = {
    k = {}, forced = nil, enemy = nil, dmg0 = nil, enemyRef = nil, prevArmor = 0,
    sweepT = -1, shudderT = 0, shudderNext = 3, trembleT = 0, trembleNext = 2.5, rageT = 0,
    burstT = 0, active = {}, nActive = 0, kinds = {}, nKinds = 0, clock = 0,
    acc = {}, emitters = {}, nEmit = 0, shrugT = 0,
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
    B.nUp, B.nDown = 0, 0
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
                local up, dn = y == 0, y == h - 1
                if not edge then
                    local _, _, _, a1 = d:getPixel(x - 1, y)
                    local _, _, _, a2 = d:getPixel(x + 1, y)
                    local _, _, _, a3 = d:getPixel(x, y - 1)
                    local _, _, _, a4 = d:getPixel(x, y + 1)
                    up, dn = a3 <= 0.1, a4 <= 0.1
                    edge = a1 <= 0.1 or a2 <= 0.1 or up or dn
                end
                if edge then
                    c = c + 1
                    if c % stride == 0 and B.n < NB then
                        B.n = B.n + 1
                        ex[B.n], ey[B.n], eu[B.n], ed[B.n] = x, y, up, dn
                        if up then B.nUp = B.nUp + 1 end
                        if dn then B.nDown = B.nDown + 1 end
                    end
                end
            end
        end
    end
    B.top, B.baseY = top, bot
    B.headX = hn > 0 and hx / hn or (minX + maxX) / 2
    B.headY = top + 1
    B.baseL, B.baseR = bl, br
    B.cx, B.cy = (minX + maxX) / 2, (top + bot) / 2
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

EnemyStates.SHRUG_DUR = 0.42

function EnemyStates.shrug()
    if _G.gameSettings and _G.gameSettings.reducedMotion then return end
    ST.shrugT = EnemyStates.SHRUG_DUR
end

function EnemyStates.shrugging()
    return ST.shrugT > 0
end

function EnemyStates.stretchPx()
    local s = 0
    if ST.shrugT > 0 then
        local p = 1 - ST.shrugT / EnemyStates.SHRUG_DUR
        s = s + ((p < 0.25 or p > 0.75) and 1 or 3)
    end
    if ST.k.weak > 0 then s = s - (ST.k.weak > 0.7 and 3 or 2) end
    if ST.k.strength > 0 then s = s + 1 end
    return s
end

function EnemyStates.jitterPx()
    if ST.shudderT > 0 or ST.trembleT > 0 or ST.rageT > 0 then
        return (math.floor(ST.clock * 30) % 2 == 0) and 1 or -1
    end
    return 0
end

function EnemyStates.tint(r, g, b, t)
    if EnemyStates.shader() then return r, g, b end
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
        if (at == "top" and eu[i] and f < 0.85)
            or (at == "under" and ed[i] and f > 0.3)
            or at == "edge"
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
    if ST.rageT > 0 then ST.rageT = ST.rageT - dt end
    if ST.shrugT > 0 then ST.shrugT = math.max(0, ST.shrugT - dt) end
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
                ST.rageT = 0.32
                for m = 1, src.burst do
                    local side = (m % 2 == 0) and 1 or -1
                    L.spawnRaw(e.kind, B.headX + side * (1 + R() * 4), B.headY + R() * 3, src.c,
                        side * (5 + R() * 9), -(7 + R() * 7))
                end
            end
        elseif src.stars then
            local have = L.countKind(e.kind)
            for m = have + 1, src.stars do
                L.spawnRaw(e.kind, B.headX, B.top + 1, src.c, 0, 0, 1e9, (m - 1) * 2.0944)
            end
        elseif e.kind == K_ABSORB then
            e.acc = e.acc + dt * src.rate * k
            while e.acc >= 1 do
                e.acc = e.acc - 1
                local x, y = pickPoint("under", R)
                local side = (x < B.cx) and -1 or 1
                local sx = x + side * (2 + R() * 5)
                local sy = y + 4 + R() * 6
                local vy = -(14 + R() * 8)
                local life = 0.9 + R() * 0.5
                L.spawnRaw(e.kind, sx, sy, src.c, -side * (3 + R() * 3), vy, life)
            end
        elseif src.sweat then
            e.acc = e.acc + dt * src.rate * k
            while e.acc >= 1 do
                e.acc = e.acc - 1
                local side = (R() < 0.5) and -1 or 1
                local hw = math.max(3, (B.baseR - B.baseL) * 0.12)
                L.spawnRaw(e.kind, B.headX + side * hw * (0.6 + R() * 0.6), B.headY + 2 + R() * 4, src.c,
                    side * (6 + R() * 8), -(10 + R() * 8))
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

local SH = { ok = nil, sh = nil, quads = {}, l1 = { 0, 0, 0, 0 }, l2 = { 0, 0, 0, 0 },
             size = { 1, 1 }, rows = { 0, 1 }, grade = { 1, 1, 1 } }
EnemyStates.PAD = 10
EnemyStates._SH = SH

function EnemyStates.shader()
    if SH.ok == nil then
        local ok, sh = pcall(love.graphics.newShader, "shaders/enemy_states.glsl")
        SH.ok = ok and true or false
        SH.sh = ok and sh or nil
        if not ok then require("src.core.Debug").warn("[EnemyStates] shader de estados nao compilou: " .. tostring(sh)) end
    end
    return SH.sh
end

function EnemyStates.shaderLevels()
    local k = ST.k
    return k.poison, k.burn, k.weak, k.vulnerable, k.strength, k.enraged, k.regen, k.block, k.veil
end

local function quadFor(w, h)
    local key = w * 8192 + h
    local q = SH.quads[key]
    if not q then
        local P = EnemyStates.PAD
        q = love.graphics.newQuad(-P, -P, w + 2 * P, h + 2 * P, w, h)
        SH.quads[key] = q
    end
    return q
end

function EnemyStates.drawBody(img, x, y, scale, r, g, b, a, grade)
    if not img or not EnemyStates.any() then return false end
    local sh = EnemyStates.shader()
    if not sh then return false end
    local w, h = img:getDimensions()
    local k = ST.k
    SH.l1[1], SH.l1[2], SH.l1[3], SH.l1[4] = k.poison, k.burn, k.weak, k.vulnerable
    SH.l2[1], SH.l2[2], SH.l2[3], SH.l2[4] = k.strength, k.enraged, k.regen, k.block
    SH.size[1], SH.size[2] = w, h
    if B.id and B.w == w and B.h == h then
        SH.rows[1], SH.rows[2] = B.top, B.baseY
    else
        SH.rows[1], SH.rows[2] = 0, h - 1
    end
    if grade then SH.grade[1], SH.grade[2], SH.grade[3] = grade[1], grade[2], grade[3]
    else SH.grade[1], SH.grade[2], SH.grade[3] = 1, 1, 1 end
    sh:send("texSize", SH.size)
    sh:send("time", ST.clock)
    sh:send("L1", SH.l1)
    sh:send("L2", SH.l2)
    sh:send("veilK", k.veil)
    sh:send("grade", SH.grade)
    sh:send("rows", SH.rows)
    sh:send("flick", (ST.trembleT > 0 and k.vulnerable > 0) and 1 or 0)
    sh:send("seed", ((B.w * 7 + B.h * 13) % 29) * 0.37)
    local prev = love.graphics.getShader()
    love.graphics.setShader(sh)
    love.graphics.setColor(r, g, b, a)
    local P = EnemyStates.PAD
    love.graphics.draw(img, quadFor(w, h), math.floor(x) - P * scale, math.floor(y) - P * scale, 0, scale, scale)
    love.graphics.setShader(prev)
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

local FIRE = { x = 0, y = 0, radius = 100, color = { 1.0, 0.52, 0.18 }, intensity = 0.6, flicker = "fire",
               seed = 7, z = 0, dither = false }
EnemyStates._fire = FIRE

function EnemyStates.submitLight(LE, x, y, w, z)
    local k = ST.k.burn
    if k <= 0 or not LE or not LE.submit then return false end
    FIRE.x, FIRE.y = x, y
    FIRE.radius = math.max(40, w * 0.85)
    FIRE.intensity = 0.55 * k
    FIRE.z = z
    LE.submit(FIRE)
    return true
end

return EnemyStates
