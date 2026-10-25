local Debug = require("src.core.Debug")

local AudioManager = {}
AudioManager.__index = AudioManager

local MAX_CLONES_PER_SOUND = 8
local warnedMissing = {}

local function detectWSL2()
    local file = io.open("/proc/version", "r")
    if not file then return false end
    local v = file:read("*all")
    file:close()
    return v:find("microsoft") ~= nil or v:find("WSL2") ~= nil
end

AudioManager.FOCUS_FADE = 0.25

local function nativeLoop(entry)
    return entry.loop and not entry.loopEnd
end

local function validLoopPoints(loopStart, loopEnd)
    return type(loopStart) == "number" and type(loopEnd) == "number"
        and loopStart >= 0 and loopEnd > loopStart
end

local function computeFinalVolume(self, entry)
    local groupVol = self.groups[entry.group] or 1
    local duck = (entry.group == "music") and (self.duckGain or 1) or 1
    return (entry.baseVolume or 1) * groupVol * (self.groups.master or 1) * (self.focusGain or 1) * duck
end

function AudioManager:new(opts)
    opts = opts or {}
    local self = setmetatable({}, AudioManager)

    self.audioAvailable = false
    self.isWSL2 = detectWSL2()

    self.sources = {}

    self.groups = {
        master = opts.masterVolume or 1.0,
        music  = opts.musicVolume  or 0.3,
        sfx    = opts.sfxVolume    or 0.7,
        ambient = opts.ambientVolume or 1.0,
    }

    self.currentMusic = nil
    self.musicCrossfade = nil
    self.focusGain = 1
    self.focusTarget = 1
    self.duckGain = 1
    self.ducks = {}
    self.musicFilter = nil

    self.musicVolume = self.groups.music
    self.sfxVolume   = self.groups.sfx
    self.ambientVolume = self.groups.ambient
    self.volume      = self.groups.master

    self:_initializeAudio()
    return self
end

function AudioManager:_initializeAudio()
    if self.isWSL2 then
        Debug.log("[AudioManager] WSL2 detectado")
    end

    local ok = pcall(function() love.audio.setVolume(1.0) end)
    self.audioAvailable = ok
    if not ok then
        Debug.warn("[AudioManager] AVISO: love.audio indisponível. Áudio será no-op.")
    end
end

function AudioManager:loadSound(code, path, opts)
    if not self.audioAvailable then return nil end

    if type(opts) == "number" then opts = { volume = opts } end
    opts = opts or {}

    local stream = opts.stream
    if stream == nil then
        stream = path:find("music") ~= nil or path:find("ambient") ~= nil
    end

    local sourceType = stream and "stream" or "static"
    local ok, template = pcall(love.audio.newSource, path, sourceType)
    if not ok or not template then
        Debug.warn("[AudioManager] falha ao carregar:", code, path)
        return nil
    end

    local entry = {
        template       = template,
        path           = path,
        baseVolume     = opts.volume or 1.0,
        group          = opts.group or (stream and "music" or "sfx"),
        stream         = stream,
        basePitch      = opts.pitch or 1.0,
        pitchVariation = opts.pitchVariation or 0,
        loop           = opts.loop or false,
        loopStart      = validLoopPoints(opts.loopStart, opts.loopEnd) and opts.loopStart or nil,
        loopEnd        = validLoopPoints(opts.loopStart, opts.loopEnd) and opts.loopEnd or nil,
        instances      = { template },
        instGain       = setmetatable({}, { __mode = "k" }),
    }

    template:setVolume(computeFinalVolume(self, entry))
    template:setPitch(entry.basePitch)
    template:setLooping(nativeLoop(entry))

    self.sources[code] = entry
    return entry
end

function AudioManager:setLoopPoints(code, loopStart, loopEnd)
    local entry = self.sources[code]
    if not entry then return false end
    if validLoopPoints(loopStart, loopEnd) then
        entry.loopStart, entry.loopEnd = loopStart, loopEnd
    else
        entry.loopStart, entry.loopEnd = nil, nil
    end
    for _, src in ipairs(entry.instances) do src:setLooping(nativeLoop(entry)) end
    return entry.loopEnd ~= nil
end

function AudioManager:getLoopPoints(code)
    local entry = self.sources[code]
    if not entry or not entry.loopEnd then return nil end
    return entry.loopStart, entry.loopEnd
end

local function wrapLoopPoints(entry, src)
    local pos = src:tell("seconds")
    if type(pos) ~= "number" or pos < entry.loopEnd then return false end
    local span = entry.loopEnd - entry.loopStart
    src:seek(entry.loopStart + ((pos - entry.loopEnd) % span), "seconds")
    return true
end

local function acquireInstance(self, entry)
    for _, src in ipairs(entry.instances) do
        if not src:isPlaying() then return src end
    end

    if #entry.instances >= MAX_CLONES_PER_SOUND then
        local stolen = entry.instances[1]
        stolen:stop()
        return stolen
    end

    if entry.stream then
        entry.template:stop()
        return entry.template
    end

    local clone = entry.template:clone()
    clone:setLooping(nativeLoop(entry))
    table.insert(entry.instances, clone)
    return clone
end

function AudioManager:play(code, opts)
    if not self.audioAvailable then return nil end
    local entry = self.sources[code]
    if not entry then
        if not warnedMissing[code] then
            warnedMissing[code] = true
            Debug.warn("[AudioManager] AVISO: som não carregado:", code)
        end
        return nil
    end

    opts = opts or {}
    local src = acquireInstance(self, entry)
    entry.instGain[src] = opts.gain

    local pitch = opts.pitch or entry.basePitch
    if entry.pitchVariation > 0 then
        local jitter = (math.random() * 2 - 1) * entry.pitchVariation
        pitch = pitch + jitter
    end
    src:setPitch(pitch)

    local saved = entry.baseVolume
    if opts.volume ~= nil then entry.baseVolume = opts.volume end
    src:setVolume(computeFinalVolume(self, entry) * (opts.gain or 1))
    entry.baseVolume = saved

    if opts.loop ~= nil then src:setLooping(opts.loop and not entry.loopEnd) end

    local ok = pcall(function() src:play() end)
    if not ok then
        Debug.warn("[AudioManager] falha ao tocar:", code)
        return nil
    end

    return src
end

function AudioManager:setInstanceGain(code, src, g)
    local entry = self.sources[code]
    if not entry or not src then return end
    entry.instGain[src] = g
    src:setVolume(computeFinalVolume(self, entry) * (g or 1))
end

function AudioManager:playSound(name)
    return self:play(name) ~= nil
end

local function crossfadeGain(cf, code)
    local p = math.min(1, (cf.t or 0) / (cf.duration or 1))
    if cf.to == code then return p end
    if cf.from == code then return (cf.fromGain or 1) * (1 - p) end
    return 0
end

local function stopOrphans(self, keep, keep2)
    for outroCode, outroEntry in pairs(self.sources) do
        if outroEntry.group == "music"
            and outroCode ~= keep and outroCode ~= keep2
            and outroEntry.template and outroEntry.template:isPlaying() then
            outroEntry.template:stop()
            Debug.log("[AudioManager] faixa orfa parada: " .. tostring(outroCode))
        end
    end
end

function AudioManager:playMusic(code, opts)
    if not self.audioAvailable then return false end
    opts = opts or {}

    if self.currentMusic == code then
        local entry = self.sources[code]
        if entry and entry.template and not entry.template:isPlaying() then
            entry.loop = true
            entry.template:setLooping(nativeLoop(entry))
            entry.template:play()
        end
        return true
    end

    local entry = self.sources[code]
    if not entry then
        Debug.warn("[AudioManager] música não carregada:", code)
        return false
    end

    entry.loop = true
    entry.template:setLooping(nativeLoop(entry))

    local fadeDuration = opts.fadeDuration or 0
    local cf0 = self.musicCrossfade
    if not self.currentMusic and cf0 and cf0.to == nil and cf0.from and self.sources[cf0.from] then
        local dur = fadeDuration > 0 and fadeDuration or 1.0
        local g = crossfadeGain(cf0, cf0.from)
        if cf0.from == code then
            self.musicCrossfade = { from = nil, to = code, t = g * dur, duration = dur }
        else
            stopOrphans(self, code, cf0.from)
            self.musicCrossfade = { from = cf0.from, to = code, t = 0, duration = dur, fromGain = g }
            entry.template:setVolume(0)
            entry.template:play()
        end
        self.currentMusic = code
        return true
    end

    local atual = self.currentMusic
    stopOrphans(self, code, atual)

    if self.currentMusic and self.sources[self.currentMusic] then
        self.musicCrossfade = {
            from = self.currentMusic,
            to = code,
            t = 0,
            duration = fadeDuration > 0 and fadeDuration or 1.0,
        }
        entry.template:setVolume(0)
        entry.template:play()
    elseif fadeDuration > 0 then
        self.musicCrossfade = {
            from = nil,
            to = code,
            t = 0,
            duration = fadeDuration,
        }
        entry.template:setVolume(0)
        entry.template:play()
    else
        entry.template:setVolume(computeFinalVolume(self, entry))
        entry.template:play()
    end

    self.currentMusic = code
    return true
end

function AudioManager:stopMusic()
    if not self.currentMusic then
        local cf = self.musicCrossfade
        local e = cf and cf.from and self.sources[cf.from]
        if e and e.template then e.template:stop() end
        self.musicCrossfade = nil
        return
    end
    local entry = self.sources[self.currentMusic]
    if entry and entry.template then entry.template:stop() end
    self.currentMusic = nil
    self.musicCrossfade = nil
end

function AudioManager:fadeOutMusic(duration)
    if not self.audioAvailable then return false end
    local code = self.currentMusic
    if not code or not self.sources[code] then
        self.currentMusic = nil
        return false
    end
    local cf = self.musicCrossfade
    local g = 1
    if cf and cf.to == code then
        g = crossfadeGain(cf, code)
        local old = cf.from and self.sources[cf.from]
        if old and old.template then old.template:stop() end
    end
    duration = duration or 0
    self.musicCrossfade = { from = code, to = nil, t = 0,
                            duration = duration > 0 and duration or 1.0, fromGain = g }
    self.currentMusic = nil
    return true
end

function AudioManager:loadBackgroundMusic(path)
    self:loadSound("__bgmusic", path, { volume = self.groups.music, stream = true, loop = true, group = "music" })
    return self.sources["__bgmusic"] ~= nil
end

function AudioManager:playBackgroundMusic()
    return self:playMusic("__bgmusic")
end

function AudioManager:stopBackgroundMusic()
    if self.currentMusic == "__bgmusic" then self:stopMusic() end
end

function AudioManager:setGroupVolume(group, value)
    value = math.max(0, math.min(1, value))
    self.groups[group] = value
    if group == "master" then self.volume = value end
    if group == "music"  then self.musicVolume = value end
    if group == "sfx"    then self.sfxVolume = value end
    if group == "ambient" then self.ambientVolume = value end
end

function AudioManager:setMasterVolume(v) self:setGroupVolume("master", v) end
function AudioManager:setMusicVolume(v)  self:setGroupVolume("music",  v) end
function AudioManager:setSFXVolume(v)    self:setGroupVolume("sfx",    v) end
function AudioManager:setAmbientVolume(v) self:setGroupVolume("ambient", v) end

function AudioManager:setVolume(v) self:setGroupVolume("master", v) end

function AudioManager:setFocused(focused)
    self.focusTarget = focused and 1 or 0
end

local function advanceFocusGain(self, dt)
    local target = self.focusTarget or 1
    local gain = self.focusGain or 1
    if gain == target then return end
    local step = dt / AudioManager.FOCUS_FADE
    if gain < target then
        gain = math.min(target, gain + step)
    else
        gain = math.max(target, gain - step)
    end
    self.focusGain = gain
end

local function duckEnvelope(d)
    local t = d.t
    if t < d.attack then
        local k = d.attack > 0 and (t / d.attack) or 1
        return d.from + (d.gain - d.from) * k
    end
    if d.releaseAt == nil then return d.gain end
    local r = t - d.releaseAt
    if r <= 0 then return d.gain end
    if r >= d.release then return 1 end
    local base = d.releaseFrom or d.gain
    return base + (1 - base) * (r / d.release)
end

function AudioManager:duck(key, gain, attack, hold, release)
    local cur = self.ducks[key]
    local from = cur and duckEnvelope(cur) or 1
    self.ducks[key] = {
        gain = math.max(0, math.min(1, gain or 0.5)), from = from, t = 0,
        attack = attack or 0.15, release = release or 0.8,
        releaseAt = (hold ~= nil and hold ~= math.huge) and ((attack or 0.15) + hold) or nil,
    }
end

function AudioManager:holdDuck(key, gain, attack)
    local cur = self.ducks[key]
    if cur and cur.releaseAt == nil and cur.gain == gain then return end
    self:duck(key, gain, attack, nil, nil)
end

function AudioManager:releaseDuck(key, release)
    local d = self.ducks[key]
    if not d then return end
    if d.releaseAt ~= nil and d.releaseAt <= d.t then return end
    d.releaseFrom = duckEnvelope(d)
    d.attack = math.min(d.attack, d.t)
    d.releaseAt = d.t
    d.release = release or d.release or 0.8
end

function AudioManager:isDucked(key)
    if key then return self.ducks[key] ~= nil end
    return next(self.ducks) ~= nil
end

function AudioManager:clearDucks()
    self.ducks = {}
    self.duckGain = 1
end

local function advanceDucks(self, dt)
    local g = 1
    for key, d in pairs(self.ducks) do
        d.t = d.t + dt
        local e = duckEnvelope(d)
        if d.releaseAt ~= nil and d.t >= d.releaseAt + d.release then
            self.ducks[key] = nil
        elseif e < g then
            g = e
        end
    end
    self.duckGain = g
end

local warnedFilter = false
function AudioManager:setMusicFilter(highgain)
    if highgain ~= nil then highgain = math.max(0.05, math.min(1, highgain)) end
    if highgain == 1 then highgain = nil end
    self.musicFilter = highgain
end

local function applyFilter(self, entry, src)
    local want = self.musicFilter
    if entry.filterOn == want and src == entry.filterSrc then return end
    local ok = pcall(function()
        if want then
            src:setFilter({ type = "lowpass", volume = 1, highgain = want })
        else
            src:setFilter()
        end
    end)
    if not ok and not warnedFilter then
        warnedFilter = true
        Debug.warn("[AudioManager] filtro passa-baixa indisponivel nesta saida de audio")
    end
    entry.filterOn, entry.filterSrc = want, src
end

function AudioManager:update(dt)
    if not self.audioAvailable then return end

    advanceFocusGain(self, dt)
    advanceDucks(self, dt)

    if self.musicCrossfade then
        local cf = self.musicCrossfade
        cf.t = cf.t + dt
        local progress = math.min(1, cf.t / cf.duration)

        local fromEntry = self.sources[cf.from]
        local toEntry   = self.sources[cf.to]

        if fromEntry and fromEntry.template then
            fromEntry.template:setVolume(computeFinalVolume(self, fromEntry) * (cf.fromGain or 1) * (1 - progress))
        end
        if toEntry and toEntry.template then
            toEntry.template:setVolume(computeFinalVolume(self, toEntry) * progress)
        end

        if progress >= 1 then
            if fromEntry and fromEntry.template then fromEntry.template:stop() end
            self.musicCrossfade = nil
        end
    end

    for code, entry in pairs(self.sources) do
        local final = computeFinalVolume(self, entry)
        local i = 1
        while i <= #entry.instances do
            local src = entry.instances[i]
            if src:isPlaying() then
                if entry.loopEnd then wrapLoopPoints(entry, src) end
                if entry.group == "music" then applyFilter(self, entry, src) end
                if not (self.musicCrossfade and (code == self.musicCrossfade.from or code == self.musicCrossfade.to)) then
                    src:setVolume(final * (entry.instGain[src] or 1))
                end
                i = i + 1
            else
                i = i + 1
            end
        end
    end
end

function AudioManager:stopAll()
    for _, entry in pairs(self.sources) do
        for _, src in ipairs(entry.instances) do
            if src:isPlaying() then src:stop() end
        end
    end
    self.currentMusic = nil
    self.musicCrossfade = nil
end

function AudioManager:stopGroup(group)
    for _, entry in pairs(self.sources) do
        if entry.group == group then
            for _, src in ipairs(entry.instances) do
                if src:isPlaying() then src:stop() end
            end
        end
    end
end

function AudioManager:isAudioAvailable() return self.audioAvailable end

function AudioManager:getStatus()
    local loaded = 0
    local active = 0
    for _, entry in pairs(self.sources) do
        loaded = loaded + 1
        for _, src in ipairs(entry.instances) do
            if src:isPlaying() then active = active + 1 end
        end
    end
    return {
        available    = self.audioAvailable,
        isWSL2       = self.isWSL2,
        master       = self.groups.master,
        music        = self.groups.music,
        sfx          = self.groups.sfx,
        loadedSounds = loaded,
        activeVoices = active,
        currentMusic = self.currentMusic,
    }
end

function AudioManager:printStatus()
    local s = self:getStatus()
    Debug.log("=== STATUS DO ÁUDIO ===")
    Debug.log("Disponível:", s.available and "✓" or "✗")
    Debug.log("WSL2:", s.isWSL2 and "✓" or "✗")
    Debug.log("Master:", s.master)
    Debug.log("Música:", s.music)
    Debug.log("SFX:", s.sfx)
    Debug.log("Sons carregados:", s.loadedSounds)
    Debug.log("Vozes ativas:", s.activeVoices)
    Debug.log("Música atual:", s.currentMusic or "(nenhuma)")
    Debug.log("========================")
end

return AudioManager
