local Debug = require("src.core.Debug")
local MusicCues = require("engine.MusicCues")
local CeilingDebris = require("engine.CeilingDebris")
local REACT = require("src.data.music_reactions")

local MusicReact = {}

MusicReact.positionProbe = nil
MusicReact.loopProbe = nil
MusicReact.codeProbe = nil
MusicReact.shakeFn = nil
MusicReact.lightFn = nil
MusicReact.breathFn = nil

local cueCache = {}
local tracker = nil
local trackerKey = nil
local bossId = nil
local hall = nil
local active = false
local clock = 0
local lastAt = { shake = -99, drop = -99, debris = -99, breath = -99 }
local swell = { left = 0, rate = 0, style = nil, acc = 0 }
local rain = { left = 0, total = 0, acc = 0, list = nil, power = 0, n = 0, i = 0 }
local trickle = { next = 0 }
local ambient = { acc = 0 }
local shake = { time = 0, dur = 0, amp = 0 }
MusicReact.shakeOffsetProbe = nil
local stats = { hit = 0, swell = 0, drop = 0, shake = 0, debris = 0, light = 0, breath = 0 }

local function settings() return _G.gameSettings or {} end

function MusicReact.enabled()
    return settings().musicReact ~= false
end

local function reduced()
    return settings().reducedMotion and true or false
end

function MusicReact.cueKeyFor(code)
    if not code then return nil end
    local MD = require("src.systems.MusicDirector")
    for id, c in pairs(MD.BOSS_TRACKS) do
        if c == code and love.filesystem.getInfo("audio/music/" .. MD.bossFile(id)) then
            return id
        end
    end
    local file = MD.TRACKS[code]
    if file then return (file:gsub("%.mp3$", ""):gsub("%-", "_")) end
    return nil
end

function MusicReact.cuesFor(key)
    if not key then return nil end
    if cueCache[key] ~= nil then return cueCache[key] or nil end
    local path = "src/data/music_cues/" .. key .. ".lua"
    local data = false
    if love.filesystem.getInfo(path) then
        local ok, res = pcall(require, "src.data.music_cues." .. key)
        if ok and type(res) == "table" then
            data = res
        else
            Debug.warn("[MusicReact] cues invalidos: " .. path)
        end
    end
    cueCache[key] = data
    return data or nil
end

local function currentCode()
    if MusicReact.codeProbe then return MusicReact.codeProbe() end
    local a = _G.audioSystem
    if not (a and a.isAudioAvailable and a:isAudioAvailable()) then return nil end
    local code = a.currentMusic
    local cf = a.musicCrossfade
    if cf and cf.to ~= code then return nil end
    return code
end

local function position(code)
    if MusicReact.positionProbe then return MusicReact.positionProbe(code) end
    local a = _G.audioSystem
    local e = a and a.sources and a.sources[code]
    local src = e and e.template
    if not src or not src:isPlaying() then return nil end
    local ok, pos = pcall(src.tell, src, "seconds")
    return ok and pos or nil
end

local function loopPoints(code)
    if MusicReact.loopProbe then return MusicReact.loopProbe(code) end
    local a = _G.audioSystem
    if a and a.getLoopPoints then
        local ok, ls, le = pcall(a.getLoopPoints, a, code)
        if ok then return ls, le end
    end
    return nil, nil
end

local function reactionFor(id)
    return REACT.BY_BOSS[id or ""] or REACT.DEFAULT
end

local function areaFor(h)
    return REACT.AREA[h or 1] or REACT.AREA[1]
end

local function spawnEntry(e, count, area)
    local style = REACT.STYLES[e[1]]
    if not style or count <= 0 then return 0 end
    if e[4] == "streak" then
        return CeilingDebris.spawnStreak(style, count, area)
    end
    return CeilingDebris.spawn(style, count, area, (e[4] == "cluster") and 6 or nil)
end

local function entryCount(e, power)
    return math.floor(e[2] + (e[3] - e[2]) * power + 0.5)
end

local function spawnList(list, power, fraction)
    if not list then return 0 end
    local n = 0
    local area = areaFor(hall)
    for _, e in ipairs(list) do
        local count = entryCount(e, power)
        if fraction then
            count = (e[4] == "streak") and count or math.ceil(count * fraction)
        end
        n = n + spawnEntry(e, count, area)
    end
    return n
end

local function startRain(list, power)
    local R = REACT.RAIN or { now = 1, spread = 0 }
    local n = spawnList(list, power, R.now)
    rain.list, rain.power = list, power
    rain.total = 0
    for _, e in ipairs(list) do
        if e[4] ~= "streak" then
            rain.total = rain.total + math.max(0, entryCount(e, power) - math.ceil(entryCount(e, power) * R.now))
        end
    end
    rain.left = (rain.total > 0) and (R.spread or 0) or 0
    rain.acc, rain.n, rain.i = 0, 0, 0
    return n
end

local function rainTick(dt)
    if rain.left <= 0 or not rain.list then return 0 end
    rain.left = rain.left - dt
    rain.acc = rain.acc + dt * rain.total / math.max(0.05, REACT.RAIN.spread)
    local n = 0
    local area = areaFor(hall)
    local list = rain.list
    while rain.acc >= 1 and rain.n < rain.total do
        rain.acc = rain.acc - 1
        local pick
        for _ = 1, #list do
            rain.i = (rain.i % #list) + 1
            if list[rain.i][4] ~= "streak" then pick = list[rain.i] break end
        end
        if not pick then break end
        n = n + spawnEntry(pick, 1, area)
        rain.n = rain.n + 1
    end
    if rain.n >= rain.total then rain.left = 0 end
    return n
end

local function nextTrickle()
    local T = REACT.TRICKLE or { min = 1.1, max = 2.4 }
    return clock + T.min + love.math.random() * (T.max - T.min)
end

local function trickleTick(r)
    if reduced() or not r.trickle then return 0 end
    if clock < trickle.next then return 0 end
    trickle.next = nextTrickle()
    local e = r.trickle
    local count = love.math.random(e[2], e[3])
    return spawnEntry({ e[1], count, count, "streak" }, count, areaFor(hall))
end

local function ambientTick(dt, r, fill)
    if reduced() or not r.ambient then return 0 end
    local a = r.ambient
    local maxN = a[2] or 10
    local n = 0
    if fill then
        while CeilingDebris.floatingCount() < maxN do
            if CeilingDebris.spawnFloat(REACT.STYLES[a[1]], areaFor(hall), true) == 0 then break end
            n = n + 1
        end
        return n
    end
    if CeilingDebris.floatingCount() >= maxN then
        ambient.acc = 0
        return 0
    end
    ambient.acc = ambient.acc + dt
    if ambient.acc < (a[3] or 0.6) then return 0 end
    ambient.acc = ambient.acc - (a[3] or 0.6)
    return CeilingDebris.spawnFloat(REACT.STYLES[a[1]], areaFor(hall))
end

local function doShake(i, d)
    if reduced() then return false end
    if clock - lastAt.shake < REACT.COOLDOWN.shake then return false end
    lastAt.shake = clock
    stats.shake = stats.shake + 1
    if MusicReact.shakeFn then
        MusicReact.shakeFn(i, d)
    else
        shake.amp = math.max(shake.amp, i or 1)
        shake.dur = math.max(shake.dur, d or 0.12)
        shake.time = shake.dur
    end
    return true
end

function MusicReact.shakeOffset()
    if MusicReact.shakeOffsetProbe then return MusicReact.shakeOffsetProbe() end
    if shake.time <= 0 then return 0, 0 end
    local user = (settings().screenshake ~= nil) and settings().screenshake or 1
    if user <= 0 then return 0, 0 end
    local mag = shake.amp * (shake.time / math.max(0.001, shake.dur)) * user
    return (love.math.random() - 0.5) * 2 * mag, (love.math.random() - 0.5) * 2 * mag
end

local function doLight(k, d)
    if reduced() then k = k * REACT.REDUCED_LIGHT end
    stats.light = stats.light + 1
    if MusicReact.lightFn then return MusicReact.lightFn(k, d) end
    local InteriorFX = require("src.ui.InteriorFX")
    if InteriorFX.musicPulse then InteriorFX.musicPulse(k, d) end
end

local function doDebris(list, power, force)
    if reduced() then return 0 end
    if not force and clock - lastAt.debris < REACT.COOLDOWN.debris then return 0 end
    lastAt.debris = clock
    local n = spawnList(list, power)
    stats.debris = stats.debris + n
    return n
end

local function doBreath(power)
    if reduced() then return false end
    if clock - lastAt.breath < REACT.COOLDOWN.breath then return false end
    if MusicReact.breathFn then
        if not MusicReact.breathFn(power) then return false end
    else
        local ER = require("src.ui.EnemyRenderer")
        if not ER.musicBreath(power) then return false end
        local BA = require("src.ui.BossAura")
        if BA.musicPulse then BA.musicPulse(power) end
    end
    lastAt.breath = clock
    stats.breath = stats.breath + 1
    return true
end

local function onCue(cue)
    local r = reactionFor(bossId)
    local p = math.max(0, math.min(1, cue.power or 0.5))
    stats[cue.kind] = (stats[cue.kind] or 0) + 1
    if cue.kind == "hit" then
        doShake(r.shake.hit * (0.5 + 0.5 * p), r.shake.hitDur)
        doLight(r.light.hit * (0.5 + 0.5 * p), r.light.hitDur)
        doDebris(r.hit, p)
    elseif cue.kind == "drop" then
        if clock - lastAt.drop < REACT.COOLDOWN.drop then
            doShake(r.shake.hit, r.shake.hitDur)
            doLight(r.light.hit, r.light.hitDur)
            return
        end
        lastAt.drop = clock
        lastAt.shake = -99
        doShake(r.shake.drop * (0.6 + 0.4 * p), r.shake.dropDur)
        doLight(r.light.drop * (0.6 + 0.4 * p), r.light.dropDur)
        if not reduced() then
            lastAt.debris = clock
            stats.debris = stats.debris + startRain(r.drop, p)
        end
        doBreath(p)
    elseif cue.kind == "swell" then
        doLight(r.light.swell * p, math.max(0.5, cue.dur or 1))
        if r.swell and not reduced() then
            swell.left = cue.dur or 2
            swell.rate = (r.swell[2] or 2) * (0.5 + 0.5 * p)
            swell.style = REACT.STYLES[r.swell[1]]
            swell.acc = 0
        end
    end
end

function MusicReact.reset()
    tracker, trackerKey = nil, nil
    active = false
    swell.left, swell.acc = 0, 0
    shake.time, shake.dur, shake.amp = 0, 0, 0
    rain.left, rain.total, rain.acc, rain.list, rain.n = 0, 0, 0, nil, 0
    trickle.next = 0
    ambient.acc = 0
    lastAt.shake, lastAt.drop, lastAt.debris, lastAt.breath = -99, -99, -99, -99
    CeilingDebris.clear()
end

function MusicReact.stats() return stats end
function MusicReact.resetStats()
    for k in pairs(stats) do stats[k] = 0 end
end
function MusicReact.isActive() return active end

function MusicReact.update(dt, ctx)
    clock = clock + dt
    CeilingDebris.update(dt)
    if shake.time > 0 then
        shake.time = math.max(0, shake.time - dt)
        if shake.time == 0 then shake.amp, shake.dur = 0, 0 end
    end
    local want = ctx and ctx.fighting and MusicReact.enabled()
    local code = want and currentCode() or nil
    local MD = require("src.systems.MusicDirector")
    if code and not MD.isBossCode(code) then
        code = nil
    end
    local key = code and MusicReact.cueKeyFor(code)
    local data = key and MusicReact.cuesFor(key)
    if not data then
        active = false
        swell.left = 0
        rain.left = 0
        if tracker then tracker:reset() end
        return
    end
    bossId, hall = ctx.bossId, ctx.hall
    if trackerKey ~= key then
        tracker = MusicCues.new(data, loopPoints(code))
        trackerKey = key
    end
    local r = reactionFor(bossId)
    if not active then
        trickle.next = nextTrickle()
        stats.debris = stats.debris + ambientTick(dt, r, true)
    end
    active = true
    tracker:update(position(code), onCue)
    stats.debris = stats.debris + rainTick(dt) + trickleTick(r) + ambientTick(dt, r)
    if swell.left > 0 then
        swell.left = swell.left - dt
        swell.acc = swell.acc + dt * swell.rate
        while swell.acc >= 1 do
            swell.acc = swell.acc - 1
            stats.debris = stats.debris + CeilingDebris.spawn(swell.style, 1, areaFor(hall))
        end
    end
end

function MusicReact.draw(tr)
    CeilingDebris.draw(tr)
end

return MusicReact
