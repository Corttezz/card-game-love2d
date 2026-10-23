local Debug = require("src.core.Debug")
local SceneGrade = require("engine.SceneGrade")
local EnemyStates = require("src.ui.EnemyStates")

local EnemyLife = {}

EnemyLife.DIR = "src/data/enemy_life/"
EnemyLife.MAX = 128
EnemyLife.DEATH_FADE = 0.5
EnemyLife.DEFAULT_GAP = { 4.0, 8.0 }
EnemyLife.enabled = true
EnemyLife.fxEnabled = true
EnemyLife._rng = love.math.newRandomGenerator(0x51DE)
EnemyLife._rand = function(a, b)
    if a then return EnemyLife._rng:random(a, b) end
    return EnemyLife._rng:random()
end

EnemyLife.KINDS = { "smoke", "embers", "drips", "spores", "flies", "mist", "frost", "ash", "glint", "bubbles" }
local KIND_INDEX = {}
for i, k in ipairs(EnemyLife.KINDS) do KIND_INDEX[k] = i end
EnemyLife.KIND_INDEX = KIND_INDEX

local K_SMOKE, K_EMBERS, K_DRIPS, K_SPORES, K_FLIES, K_MIST, K_FROST, K_ASH, K_GLINT, K_BUBBLES = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

EnemyLife.SPEC = {
    [K_SMOKE]   = { rate = 2.2, l0 = 1.8, l1 = 2.8, v0 = 4.5, v1 = 7.5, jit = 1.0, wind = 5.0, wob = 0.6,
                    c = { 0.66, 0.64, 0.61 }, a = 0.50, grade = 1 },
    [K_EMBERS]  = { rate = 2.0, l0 = 0.9, l1 = 1.6, v0 = 9.0, v1 = 14.0, jit = 2.0, wind = 3.0, wob = 1.4,
                    c = { 1.00, 0.80, 0.38 }, a = 1.00, grade = 0.2, flicker = true },
    [K_DRIPS]   = { rate = 0.8, l0 = 1.1, l1 = 1.4, v0 = 0, v1 = 0, jit = 0, wind = 0, wob = 0,
                    c = { 0.46, 0.64, 0.26 }, a = 0.95, grade = 0.7, hang = 0.45, grav = 70 },
    [K_SPORES]  = { rate = 1.4, l0 = 2.6, l1 = 3.8, v0 = 2.0, v1 = 4.0, jit = 1.2, wind = 4.0, wob = 1.8,
                    c = { 0.78, 0.80, 0.48 }, a = 0.75, grade = 1 },
    [K_FLIES]   = { rate = 3.0, l0 = 1e9, l1 = 1e9, v0 = 2.6, v1 = 4.2, jit = 0, wind = 0, wob = 0,
                    c = { 0.07, 0.06, 0.05 }, a = 0.95, grade = 1, orbit = true },
    [K_MIST]    = { rate = 2.4, l0 = 3.5, l1 = 5.0, v0 = 0, v1 = 0.4, jit = 1.5, wind = 2.0, wob = 0,
                    c = { 0.80, 0.82, 0.86 }, a = 0.30, grade = 1, back = true, w = 4, spread = 0.5 },
    [K_FROST]   = { rate = 1.6, l0 = 2.0, l1 = 3.0, v0 = -2.5, v1 = -4.5, jit = 0.8, wind = 3.0, wob = 0.8,
                    c = { 0.82, 0.93, 1.00 }, a = 0.85, grade = 0.6, flicker = true },
    [K_ASH]     = { rate = 1.4, l0 = 2.5, l1 = 3.6, v0 = 2.5, v1 = 4.5, jit = 1.0, wind = 6.0, wob = 1.6,
                    c = { 0.36, 0.34, 0.33 }, a = 0.80, grade = 1 },
    [K_GLINT]   = { rate = 0.35, l0 = 0.40, l1 = 0.45, v0 = 0, v1 = 0, jit = 0, wind = 0, wob = 0,
                    c = { 1.00, 0.97, 0.86 }, a = 1.00, grade = 0.3, glint = true },
    [K_BUBBLES] = { rate = 1.0, l0 = 1.2, l1 = 2.0, v0 = 3.0, v1 = 5.0, jit = 0.6, wind = 0.5, wob = 0.7,
                    c = { 0.62, 0.82, 0.50 }, a = 0.85, grade = 1, pop = 0.12 },
    [11]        = { rate = 0, l0 = 0.35, l1 = 0.70, v0 = 4.0, v1 = 8.0, jit = 1.0, wind = 2.0, wob = 0.8,
                    c = { 1.00, 0.58, 0.16 }, a = 1.00, grade = 0.25, flicker = true, flame = true },
    [12]        = { rate = 0, l0 = 0.8, l1 = 1.0, v0 = 0, v1 = 0, jit = 0, wind = 0, wob = 0,
                    c = { 0.72, 0.86, 1.00 }, a = 0.90, grade = 0.6, hang = 0.30, grav = 55 },
    [13]        = { rate = 0, l0 = 0.6, l1 = 1.0, v0 = 8.0, v1 = 12.0, jit = 3.0, wind = 4.0, wob = 0.8,
                    c = { 0.92, 0.92, 0.94 }, a = 0.78, grade = 0.8, grow = true },
    [14]        = { rate = 0, l0 = 0.45, l1 = 0.80, v0 = 10.0, v1 = 16.0, jit = 2.0, wind = 1.0, wob = 1.0,
                    c = { 1.00, 0.24, 0.14 }, a = 1.00, grade = 0.25, flicker = true },
    [15]        = { rate = 0, l0 = 1.5, l1 = 2.2, v0 = 3.0, v1 = 5.0, jit = 1.0, wind = 1.0, wob = 1.2,
                    c = { 0.56, 0.96, 0.56 }, a = 0.80, grade = 0.5, flicker = true },
}
EnemyLife.SPEC[K_SMOKE].grow = true

local N = EnemyLife.MAX
local pk, px, py, pvx, pvy, plife, pmax, pseed, pem = {}, {}, {}, {}, {}, {}, {}, {}, {}
local pcr, pcg, pcb = {}, {}, {}
for i = 1, N do
    pk[i], px[i], py[i], pvx[i], pvy[i] = 0, 0, 0, 0, 0
    plife[i], pmax[i], pseed[i], pem[i] = 0, 1, 0, 0
    pcr[i], pcg[i], pcb[i] = 1, 1, 1
end
EnemyLife._pk = pk

local cache = {}
local warned = {}
local S = {
    id = nil, data = nil, gapLeft = 0, last = nil, force = nil,
    warm = {}, jobs = {}, jobN = 0, jobI = 0, emit = {}, nEmit = 0,
    deathT = -1, alive = true, live = 0,
    ox = 0, oy = 0, scale = 1, dx = 0, dy = 0, iw = 0, ih = 0, alpha = 1, framed = false,
    wind = 0, gc = { 1, 1, 1 }, cursor = 1, playing = nil, pinned = false,
    enemy = nil, spawnOk = false,
}
EnemyLife._S = S

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn(msg)
end

function EnemyLife.validate(t, id)
    if type(t) ~= "table" then return false, "nao e tabela" end
    if t.fidgets ~= nil then
        if type(t.fidgets) ~= "table" then return false, "fidgets nao e lista" end
        for i, f in ipairs(t.fidgets) do
            if type(f) ~= "table" or type(f.clip) ~= "string" or not f.clip:find("^fidget_") then
                return false, "fidget " .. i .. " sem clip fidget_*"
            end
            if f.fps ~= nil and (type(f.fps) ~= "number" or f.fps <= 0) then return false, "fidget " .. i .. " fps" end
            if f.weight ~= nil and (type(f.weight) ~= "number" or f.weight <= 0) then return false, "fidget " .. i .. " weight" end
        end
    end
    if t.gap ~= nil then
        if type(t.gap) ~= "table" or type(t.gap[1]) ~= "number" or type(t.gap[2]) ~= "number"
            or t.gap[1] <= 0 or t.gap[2] < t.gap[1] then
            return false, "gap invalido"
        end
    end
    if t.states ~= nil then
        if type(t.states) ~= "table" then return false, "states nao e tabela" end
        for name, sd in pairs(t.states) do
            if not EnemyStates.INDEX[name] then return false, "estado desconhecido " .. tostring(name) end
            if type(sd) ~= "table" then return false, "estado " .. name .. " nao e tabela" end
            if sd.clip ~= nil and (type(sd.clip) ~= "string" or not sd.clip:find("^state_")) then
                return false, "estado " .. name .. " clip sem prefixo state_"
            end
            if sd.fps ~= nil and (type(sd.fps) ~= "number" or sd.fps <= 0) then return false, "estado " .. name .. " fps" end
            if sd.fx ~= nil then
                local ok, err = EnemyLife.validate({ fx = sd.fx }, id)
                if not ok then return false, "estado " .. name .. ": " .. err end
            end
        end
    end
    if t.fx ~= nil then
        if type(t.fx) ~= "table" then return false, "fx nao e lista" end
        for i, e in ipairs(t.fx) do
            if type(e) ~= "table" or not KIND_INDEX[e.kind] then return false, "fx " .. i .. " kind desconhecido" end
            if type(e.xr) ~= "number" or type(e.yr) ~= "number" or e.xr < 0 or e.xr > 1 or e.yr < 0 or e.yr > 1 then
                return false, "fx " .. i .. " xr/yr fora de 0..1"
            end
            if e.rate ~= nil and (type(e.rate) ~= "number" or e.rate <= 0) then return false, "fx " .. i .. " rate" end
            if e.spread ~= nil and (type(e.spread) ~= "number" or e.spread < 0 or e.spread > 1) then
                return false, "fx " .. i .. " spread"
            end
            if e.tint ~= nil and (type(e.tint) ~= "table" or type(e.tint[1]) ~= "number"
                or type(e.tint[2]) ~= "number" or type(e.tint[3]) ~= "number") then
                return false, "fx " .. i .. " tint"
            end
            if e.dir ~= nil and e.dir ~= "up" and e.dir ~= "down" and e.dir ~= "side" then
                return false, "fx " .. i .. " dir"
            end
        end
    end
    return true
end

function EnemyLife.load(id)
    if not id then return nil end
    local c = cache[id]
    if c ~= nil then return c or nil end
    local path = EnemyLife.DIR .. id .. ".lua"
    if not love.filesystem.getInfo(path) then
        cache[id] = false
        return nil
    end
    local okL, chunk = pcall(love.filesystem.load, path)
    local okR, tbl = false, nil
    if okL and chunk then okR, tbl = pcall(chunk) end
    local valid, err = false, tostring(chunk)
    if okR then valid, err = EnemyLife.validate(tbl, id) else err = tostring(tbl) end
    if not valid then
        warnOnce(id, "[EnemyLife] dados de vida invalidos em " .. path .. ": " .. tostring(err))
        cache[id] = false
        return nil
    end
    cache[id] = tbl
    return tbl
end

function EnemyLife._setData(id, tbl)
    cache[id] = tbl or false
    if S.id == id then S.id = nil end
end

function EnemyLife.isFidget(name)
    return name ~= nil and string.find(name, "fidget_", 1, true) == 1
end

function EnemyLife.isStateClip(name)
    return name ~= nil and string.find(name, "state_", 1, true) == 1
end

function EnemyLife.isIdleLike(name)
    return name == "idle" or EnemyLife.isFidget(name) or EnemyLife.isStateClip(name)
end

function EnemyLife.isLoop(name)
    return name == "idle" or EnemyLife.isStateClip(name)
end

local function clearPool()
    for i = 1, N do pk[i] = 0 end
    S.live = 0
end

local function rollGap()
    local g = (S.data and S.data.gap) or EnemyLife.DEFAULT_GAP
    return g[1] + (g[2] - g[1]) * EnemyLife._rand()
end

local function buildEmitters(data)
    S.nEmit = 0
    for i = #S.emit, 1, -1 do S.emit[i] = nil end
    if not data or not data.fx then return end
    for _, e in ipairs(data.fx) do
        local k = KIND_INDEX[e.kind]
        local sp = EnemyLife.SPEC[k]
        local tint = e.tint or sp.c
        S.nEmit = S.nEmit + 1
        S.emit[S.nEmit] = {
            k = k, xr = e.xr, yr = e.yr, rate = sp.rate * (e.rate or 1),
            spread = e.spread or sp.spread or 0.05, dir = e.dir,
            cr = tint[1], cg = tint[2], cb = tint[3], acc = EnemyLife._rand(), alive = 0,
        }
    end
end

function EnemyLife.setEnemy(id)
    S.id = id
    S.pinned = false
    S.data = EnemyLife.load(id)
    S.last, S.force, S.playing = nil, nil, nil
    S.deathT, S.alive, S.framed = -1, true, false
    for k in pairs(S.warm) do S.warm[k] = nil end
    for i = #S.jobs, 1, -1 do S.jobs[i] = nil end
    S.jobN, S.jobI = 0, 0
    clearPool()
    buildEmitters(S.data)
    S.gapLeft = rollGap()
    EnemyStates.reset()
    S.jobN = 1
    S.jobs[1] = { prep = true }
    if S.data and S.data.fidgets then
        for _, f in ipairs(S.data.fidgets) do
            S.jobN = S.jobN + 1
            S.jobs[S.jobN] = f
        end
    end
    if S.data and S.data.states then
        for _, n in ipairs(EnemyStates.LIST) do
            local sd = S.data.states[n]
            if sd and sd.clip then
                S.jobN = S.jobN + 1
                S.jobs[S.jobN] = { clip = sd.clip, fps = sd.fps, loop = true }
            end
        end
    end
end

function EnemyLife.prewarm(id)
    if id and id ~= S.id then EnemyLife.setEnemy(id) end
    if id then S.pinned = true end
end

local function runJob()
    if not S.id or S.jobI >= S.jobN then return false end
    S.jobI = S.jobI + 1
    local f = S.jobs[S.jobI]
    if f.prep then
        EnemyStates.prepare(S.id)
        return true
    end
    local SpriteAnimation = require("src.ui.SpriteAnimation")
    if not SpriteAnimation.exists(S.id, f.clip, "south") then
        warnOnce(S.id .. "|" .. f.clip, "[EnemyLife] clip " .. f.clip .. " de " .. tostring(S.id) .. " nao existe no disco")
        return true
    end
    SpriteAnimation.new(S.id, f.clip, "south", f.fps or 10, { loop = false })
    local ER = package.loaded["src.ui.EnemyRenderer"]
    if ER and ER.debugClipMetrics then ER.debugClipMetrics(S.id, f.clip) end
    S.warm[f.clip] = true
    return true
end

function EnemyLife.prewarmNow(id)
    EnemyLife.prewarm(id)
    while runJob() do end
end

function EnemyLife.isWarm(clip) return S.warm[clip] == true end

local function pick()
    local fl = S.data and S.data.fidgets
    if not fl or #fl == 0 then return nil end
    local total = 0
    for _, f in ipairs(fl) do
        if S.warm[f.clip] and (f.clip ~= S.last or #fl == 1) then total = total + (f.weight or 1) end
    end
    if total <= 0 then return nil end
    local r = EnemyLife._rand() * total
    for _, f in ipairs(fl) do
        if S.warm[f.clip] and (f.clip ~= S.last or #fl == 1) then
            r = r - (f.weight or 1)
            if r <= 0 then return f end
        end
    end
    return nil
end

function EnemyLife.force(n)
    local fl = S.data and S.data.fidgets
    if fl and fl[n] then S.force = n return true end
    return false
end

local function reduced()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function freeSlot()
    for _ = 1, N do
        local i = S.cursor
        S.cursor = (S.cursor % N) + 1
        if pk[i] == 0 then return i end
    end
    return nil
end

local function spawn(e, ei)
    local i = freeSlot()
    if not i then return end
    local sp = EnemyLife.SPEC[e.k]
    local R = EnemyLife._rand
    local w = S.iw
    pk[i] = e.k
    pem[i] = ei
    px[i] = e.xr * w + (R() - 0.5) * e.spread * w + S.dx
    py[i] = e.yr * S.ih + S.dy
    local life = sp.l0 + (sp.l1 - sp.l0) * R()
    plife[i], pmax[i] = life, life
    pseed[i] = R() * 6.2832
    local v = sp.v0 + (sp.v1 - sp.v0) * R()
    local vx, vy = (R() - 0.5) * sp.jit, -v
    if e.k == K_MIST then
        py[i] = py[i] + (R() - 0.5) * 3
        vx, vy = (R() - 0.5) * sp.jit * 2, -v
    end
    if e.dir == "down" then vy = math.abs(v)
    elseif e.dir == "up" then vy = -math.abs(v)
    elseif e.dir == "side" then
        local s = (S.wind < 0) and -1 or 1
        vx, vy = s * math.max(2, math.abs(v)), (R() - 0.5) * 0.6
    end
    if sp.orbit then
        px[i], py[i] = e.xr * w, e.yr * S.ih
        vx = v * ((R() < 0.5) and -1 or 1)
        vy = 8 + 8 * R()
    end
    pvx[i], pvy[i] = vx, vy
    pcr[i], pcg[i], pcb[i] = e.cr, e.cg, e.cb
    e.alive = e.alive + 1
    S.live = S.live + 1
end

function EnemyLife._spawnRaw(kind, ax, ay, tint)
    local i = freeSlot()
    if not i then return end
    local sp = EnemyLife.SPEC[kind]
    local R = EnemyLife._rand
    pk[i] = kind
    pem[i] = 0
    px[i] = ax + S.dx
    py[i] = ay + S.dy
    local life = sp.l0 + (sp.l1 - sp.l0) * R()
    plife[i], pmax[i] = life, life
    pseed[i] = R() * 6.2832
    local v = sp.v0 + (sp.v1 - sp.v0) * R()
    pvx[i], pvy[i] = (R() - 0.5) * sp.jit, -v
    local c = tint or sp.c
    pcr[i], pcg[i], pcb[i] = c[1], c[2], c[3]
    S.live = S.live + 1
end
EnemyLife.spawnRaw = EnemyLife._spawnRaw

local function kill(i)
    local e = pem[i] > 0 and S.emit[pem[i]] or nil
    if e then e.alive = e.alive - 1 end
    pk[i] = 0
    S.live = S.live - 1
end

local function windNow()
    if not SceneGrade.isActive() then return 0 end
    local GF = package.loaded["engine.GrassField"]
    if not GF or not GF.windAt then return 0 end
    local P = GF.PRESETS[SceneGrade.biome() or "fields"]
    if not P then return 0 end
    local WR = package.loaded["src.ui.WorldRoad"]
    local t = (WR and WR._time) or love.timer.getTime()
    return GF.windAt(0.5, 0, t, P, 0)
end

local function tickFx(dt, spawning)
    S.wind = windNow()
    local wind = S.wind
    if spawning then
        for ei = 1, S.nEmit do
            local e = S.emit[ei]
            local sp = EnemyLife.SPEC[e.k]
            if sp.orbit then
                local want = math.max(1, math.floor(e.rate + 0.5))
                if e.alive < want then spawn(e, ei) end
            else
                e.acc = e.acc + dt * e.rate
                while e.acc >= 1 do
                    e.acc = e.acc - 1
                    spawn(e, ei)
                end
            end
        end
    end
    if S.live <= 0 then return end
    for i = 1, N do
        local k = pk[i]
        if k ~= 0 then
            local sp = EnemyLife.SPEC[k]
            plife[i] = plife[i] - dt
            if plife[i] <= 0 then
                kill(i)
            elseif sp.orbit then
                pseed[i] = pseed[i] + pvx[i] * dt / 6
            else
                local age = pmax[i] - plife[i]
                if sp.hang then
                    if age > sp.hang then
                        pvy[i] = pvy[i] + sp.grav * dt
                        py[i] = py[i] + pvy[i] * dt
                    end
                else
                    local wob = sp.wob > 0 and math.sin(age * 2.7 + pseed[i]) * sp.wob or 0
                    px[i] = px[i] + (pvx[i] + wind * sp.wind + wob) * dt
                    py[i] = py[i] + pvy[i] * dt
                end
            end
        end
    end
end

function EnemyLife.update(dt, id, animName, frameIdx, busy)
    if not id then return nil end
    if id ~= S.id then
        if S.pinned and busy then
            runJob()
            return nil
        end
        EnemyLife.setEnemy(id)
    end
    S.pinned = false
    runJob()
    local dying = (animName == "death") or not S.alive
    if dying then
        if S.deathT < 0 then S.deathT = 0 end
        S.deathT = S.deathT + dt
        if S.deathT >= EnemyLife.DEATH_FADE then clearPool() end
    elseif S.deathT >= 0 then
        S.deathT = -1
    end
    local red = reduced()
    S.spawnOk = EnemyLife.fxEnabled and S.framed and not dying and not red
    EnemyStates.read(S.enemy, dying)
    if red then
        if S.live > 0 then clearPool() end
    else
        EnemyStates.update(dt, S.data, EnemyLife, dying)
        tickFx(dt, S.spawnOk and S.nEmit > 0)
    end
    if EnemyLife.isFidget(animName) then
        S.playing = animName
        return nil
    end
    S.playing = nil
    local loopName, loopFps, loopSd = EnemyStates.loopFor(S.data, S.warm)
    if not dying and EnemyLife.isLoop(animName) and animName ~= loopName and frameIdx == 1 and not busy then
        return loopName, loopFps or 8, true
    end
    local fidgetOk = animName == "idle" or (loopSd and loopSd.fidgets and animName == loopName)
    if not EnemyLife.enabled or red or dying or busy or not fidgetOk then return nil end
    local fl = S.data and S.data.fidgets
    if not fl or #fl == 0 then return nil end
    if S.force then
        if frameIdx ~= 1 then return nil end
        local f = fl[S.force]
        if not S.warm[f.clip] then return nil end
        S.force = nil
        S.last = f.clip
        S.gapLeft = rollGap()
        return f.clip, f.fps or 10
    end
    S.gapLeft = S.gapLeft - dt
    if S.gapLeft > 0 or frameIdx ~= 1 then return nil end
    local f = pick()
    if not f then return nil end
    S.last = f.clip
    S.gapLeft = rollGap()
    return f.clip, f.fps or 10
end

function EnemyLife.resumeIdle(anim)
    if anim and anim.frames and #anim.frames > 1 then
        anim.currentFrame = 2
        anim.elapsed = 0
        anim._dir = 1
    end
end

function EnemyLife.spawning() return S.spawnOk end

function EnemyLife.loopClip()
    local n, fps = EnemyStates.loopFor(S.data, S.warm)
    return n, fps
end

function EnemyLife.animRate(animName)
    if not EnemyLife.isLoop(animName) or reduced() then return 1 end
    return EnemyStates.rate()
end

function EnemyLife.stretchPx() return EnemyStates.stretchPx() end
function EnemyLife.jitterPx()
    if reduced() then return 0 end
    return EnemyStates.jitterPx()
end
function EnemyLife.tint(r, g, b) return EnemyStates.tint(r, g, b) end
function EnemyLife.charK(t) return EnemyStates.charK(t) end
function EnemyLife.eyePulse(t)
    if reduced() then return 0 end
    return EnemyStates.eyePulse(t)
end
EnemyLife.States = EnemyStates

function EnemyLife.frame(ox, oy, scale, dxA, dyA, iw, ih, alive, alpha, enemy)
    S.enemy = enemy
    S.ox, S.oy, S.scale = ox, oy, scale
    S.dx, S.dy, S.iw, S.ih = dxA, dyA, iw, ih
    S.alive = alive
    S.alpha = alpha or 1
    S.framed = true
    SceneGrade.color("enemy", SceneGrade.depth(), S.gc)
end

local function rect(ax, ay, w, h)
    local s = S.scale
    local bx, by = math.floor(S.ox), math.floor(S.oy)
    local x0 = math.floor(bx + ax * s)
    local y0 = math.floor(by + ay * s)
    local x1 = math.floor(bx + (ax + w) * s)
    local y1 = math.floor(by + (ay + h) * s)
    if x1 <= x0 then x1 = x0 + 1 end
    if y1 <= y0 then y1 = y0 + 1 end
    love.graphics.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
end

local function drawLayer(back, mask)
    if S.live <= 0 or not S.framed or not EnemyLife.fxEnabled or reduced() then return end
    local deathK = 1
    if S.deathT >= 0 then deathK = math.max(0, 1 - S.deathT / EnemyLife.DEATH_FADE) end
    if deathK <= 0 then return end
    local gc = S.gc
    local fl = math.floor
    for i = 1, N do
        local k = pk[i]
        if k ~= 0 then
            local sp = EnemyLife.SPEC[k]
            if (sp.back == true) == back then
                local age = pmax[i] - plife[i]
                local a = sp.a * deathK * S.alpha
                if not sp.orbit then
                    a = a * math.min(1, age / 0.25) * math.min(1, plife[i] / 0.4)
                end
                if sp.flicker then
                    a = a * (0.65 + 0.35 * math.sin(age * 17 + pseed[i] * 3))
                end
                if a > 0.02 then
                    if mask then
                        love.graphics.setColor(1, 1, 1, 1)
                    else
                        local g = sp.grade
                        local r = pcr[i] * (1 - g + g * gc[1])
                        local gg = pcg[i] * (1 - g + g * gc[2])
                        local b = pcb[i] * (1 - g + g * gc[3])
                        if sp.orbit and math.sin(pseed[i] * 23) > 0.6 then
                            r, gg, b = r + 0.30, gg + 0.29, b + 0.26
                        end
                        love.graphics.setColor(r, gg, b, a)
                    end
                    local ax, ay
                    if sp.orbit then
                        local ph = pseed[i]
                        ax = fl(px[i] + S.dx + math.cos(ph) * pvy[i] + math.sin(ph * 2.3) * 1.2)
                        ay = fl(py[i] + S.dy + math.sin(ph * 1.7) * pvy[i] * 0.45)
                        rect(ax, ay, 1, 1)
                    else
                        ax, ay = fl(px[i]), fl(py[i])
                        if sp.glint then
                            local q = age / pmax[i]
                            rect(ax, ay, 1, 1)
                            if q > 0.25 and q < 0.75 then
                                rect(ax - 1, ay, 1, 1); rect(ax + 1, ay, 1, 1)
                                rect(ax, ay - 1, 1, 1); rect(ax, ay + 1, 1, 1)
                            end
                        elseif sp.hang then
                            local hk = math.min(1, age / sp.hang)
                            rect(ax, ay, 1, (hk > 0.6 or age > sp.hang) and 2 or 1)
                        elseif sp.pop and plife[i] < sp.pop then
                            rect(ax - 1, ay - 1, 1, 1); rect(ax + 1, ay - 1, 1, 1)
                            rect(ax - 1, ay + 1, 1, 1); rect(ax + 1, ay + 1, 1, 1)
                        elseif sp.w then
                            rect(ax, ay, sp.w, 1)
                        else
                            local sz = (sp.grow and age > pmax[i] * 0.45) and 2 or 1
                            if sp.flame then
                                if age < pmax[i] * 0.5 then rect(ax, ay, 1, 2) else rect(ax, ay, 1, 1) end
                            else
                                rect(ax, ay, sz, sz)
                            end
                        end
                    end
                end
            end
        end
    end
end

function EnemyLife.drawBack() drawLayer(true, false) end
function EnemyLife.drawFront(mask)
    drawLayer(false, mask == true)
    if mask == true then love.graphics.setColor(1, 1, 1, 1) end
end

function EnemyLife.liveCount() return S.live end
function EnemyLife.playing() return S.playing end
function EnemyLife.current() return S.id, S.data end
function EnemyLife.gapLeft() return S.gapLeft end

function EnemyLife.reload(id)
    cache[id] = nil
    warned[id] = nil
    if S.id == id then S.id = nil end
    EnemyLife.prewarmNow(id)
end

function EnemyLife.reset()
    EnemyStates.reset()
    S.enemy = nil
    S.pinned = false
    S.jobN, S.jobI = 0, 0
    S.id, S.data, S.playing = nil, nil, nil
    S.framed = false
    clearPool()
end

function EnemyLife.clearCache()
    for k in pairs(cache) do cache[k] = nil end
    for k in pairs(warned) do warned[k] = nil end
    EnemyLife.reset()
end

return EnemyLife
