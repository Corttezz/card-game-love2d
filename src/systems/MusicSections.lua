local Debug = require("src.core.Debug")

local MusicSections = {}

MusicSections.DIR = "audio/music/boss"
MusicSections.MAIN = { "a", "b", "c" }
MusicSections.FINAL = { "f1", "f2" }
MusicSections.OPENING = "a"
MusicSections.FINAL_AT = 0.5
MusicSections.XFADE = 1.5
MusicSections.LEAD = 0.25
MusicSections.VOLUME = 0.6

MusicSections.BPM = {
    carrion_king = 96,
    tower_lich = 84,
    abyss_tyrant = 120,
    winter_monarch = 108,
    rot_colossus = 78,
    eclipse_queen = 66,
}

local catalog = {}
local byCode = {}
local st = {}
local rng = love.math.newRandomGenerator(9157)

local IS_FINAL = {}
for _, s in ipairs(MusicSections.FINAL) do IS_FINAL[s] = true end

function MusicSections.codeFor(trackCode, sec)
    return trackCode .. ":" .. sec
end

function MusicSections.fileFor(id, sec)
    return MusicSections.DIR .. "/" .. id .. "/" .. sec .. ".mp3"
end

function MusicSections.scan(bossTracks)
    catalog, byCode, st = {}, {}, {}
    local n = 0
    for id, trackCode in pairs(bossTracks or {}) do
        local entry = { id = id, track = trackCode, main = {}, final = {}, path = {} }
        local function add(list, sec)
            local path = MusicSections.fileFor(id, sec)
            if love.filesystem.getInfo(path) then
                list[#list + 1] = sec
                entry.path[sec] = path
                byCode[MusicSections.codeFor(trackCode, sec)] = { track = trackCode, sec = sec }
                n = n + 1
            end
        end
        for _, sec in ipairs(MusicSections.MAIN) do add(entry.main, sec) end
        for _, sec in ipairs(MusicSections.FINAL) do add(entry.final, sec) end
        if #entry.main + #entry.final > 0 then catalog[trackCode] = entry end
    end
    return n
end

function MusicSections.has(trackCode)
    return catalog[trackCode] ~= nil
end

function MusicSections.sections(trackCode)
    local e = catalog[trackCode]
    if not e then return {} end
    local out = {}
    for _, s in ipairs(e.main) do out[#out + 1] = s end
    for _, s in ipairs(e.final) do out[#out + 1] = s end
    return out
end

function MusicSections.trackOf(code)
    local info = code and byCode[code]
    if info then return info.track end
    return code
end

function MusicSections.sectionOf(code)
    local info = code and byCode[code]
    return info and info.sec or nil
end

function MusicSections.isFinal(sec)
    return IS_FINAL[sec] == true
end

function MusicSections.nextSection(trackCode, prev, final)
    local e = catalog[trackCode]
    if not e then return nil end
    local function without(list)
        local out = {}
        for _, s in ipairs(list) do if s ~= prev then out[#out + 1] = s end end
        return out
    end
    local pool = without(final and e.final or e.main)
    if #pool == 0 then pool = without(final and e.main or e.final) end
    if #pool == 0 then return prev end
    return pool[rng:random(1, #pool)]
end

function MusicSections.first(trackCode, final)
    local e = catalog[trackCode]
    if not e then return nil end
    if not final and e.path[MusicSections.OPENING] then return MusicSections.OPENING end
    return MusicSections.nextSection(trackCode, nil, final)
end

MusicSections.hpProbe = nil
function MusicSections.hpFraction()
    if MusicSections.hpProbe then return MusicSections.hpProbe() end
    local g = _G.game
    local e = g and g.enemy
    if not e or not e.isBoss or not e.maxHealth or e.maxHealth <= 0 then return nil end
    return math.max(0, e.health or 0) / e.maxHealth
end

local function ensureLoaded(a, e)
    for sec, path in pairs(e.path) do
        local code = MusicSections.codeFor(e.track, sec)
        if not a.sources[code] then
            a:loadSound(code, path, {
                volume = MusicSections.VOLUME, group = "music", stream = true, loop = true,
            })
        end
    end
end

local function start(a, e, sec, fade)
    local code = MusicSections.codeFor(e.track, sec)
    if not a.sources[code] then return nil end
    Debug.log(string.format("[Musica] chefe %s: secao %s%s", e.id, sec,
        st.final and " (fase final)" or ""))
    a:playMusic(code, { fadeDuration = fade })
    st.track, st.sec, st.lastPos, st.pendingFinal = e.track, sec, 0, false
    st.history = st.history or {}
    st.history[#st.history + 1] = sec
    return code
end

function MusicSections.drive(trackCode, fade)
    local e = catalog[trackCode]
    local a = _G.audioSystem
    if not e or not a or not a.sources or (a.isAudioAvailable and not a:isAudioAvailable()) then
        return nil
    end
    ensureLoaded(a, e)

    local hp = MusicSections.hpFraction()
    local cur = a.currentMusic
    local info = cur and byCode[cur]
    if not info or info.track ~= trackCode then
        st = { final = hp ~= nil and hp <= MusicSections.FINAL_AT }
        return start(a, e, MusicSections.first(trackCode, st.final), fade or MusicSections.XFADE)
    end

    if not st.final and hp and hp <= MusicSections.FINAL_AT then
        st.final = true
        st.pendingFinal = not IS_FINAL[info.sec]
    end
    if a.musicCrossfade then
        st.lastPos = 0
        return cur
    end

    local src = a.sources[cur] and a.sources[cur].template
    if not src then return cur end
    local pos, dur = src:tell(), src:getDuration()
    local last = st.lastPos or 0
    local bar = 240 / (MusicSections.BPM[e.id] or 100)
    local switch = false
    if st.pendingFinal then
        switch = math.floor(pos / bar) ~= math.floor(last / bar) or pos < last
    end
    if dur and dur > 0 and pos >= dur - MusicSections.XFADE - MusicSections.LEAD then switch = true end
    if pos < last - 1 then switch = true end
    st.lastPos = pos
    if not switch then return cur end
    local nxt = MusicSections.nextSection(trackCode, info.sec, st.final)
    if not nxt or nxt == info.sec then
        st.pendingFinal = false
        return cur
    end
    return start(a, e, nxt, MusicSections.XFADE) or cur
end

function MusicSections._state() return st end

function MusicSections._reset()
    st = {}
    rng = love.math.newRandomGenerator(9157)
end

return MusicSections
