local Sfx = {}

local function audio()
    return _G.audioSystem
end

function Sfx.play(name, opts)
    local a = audio()
    if not a then return end
    if opts then
        a:play(name, opts)
    else
        a:playSound(name)
    end
end

function Sfx.playAt(name, volume, pitch)
    local a = audio()
    local entry = a and a.sources and a.sources[name]
    if not entry then return nil end
    local base = entry.baseVolume or 1
    local gain = base > 0 and volume / base or 0
    local src = a:play(name, { gain = gain, pitch = pitch })
    if not src then return nil end
    return { name = name, src = src, gain = gain, cur = gain }
end

local function ownsVoice(a, v)
    local entry = a and a.sources and a.sources[v.name]
    return entry ~= nil and entry.instGain[v.src] == v.cur and v.src:isPlaying()
end

function Sfx.setVoiceGain(v, k)
    local a = audio()
    if not ownsVoice(a, v) then return false end
    v.cur = v.gain * math.max(0, k)
    a:setInstanceGain(v.name, v.src, v.cur)
    return true
end

function Sfx.stopVoice(v)
    local a = audio()
    if not ownsVoice(a, v) then return end
    v.src:stop()
    a.sources[v.name].instGain[v.src] = nil
end

function Sfx.playWithVariation(name, basePitch, pitchVar, baseVolume, volVar)
    local a = audio()
    if not a then return end
    basePitch = basePitch or 1.0
    pitchVar  = pitchVar  or 0.1
    local pitch = basePitch + (math.random() * 2 - 1) * pitchVar
    local opts = { pitch = pitch }
    if baseVolume then
        volVar = volVar or 0
        opts.volume = baseVolume + (math.random() * 2 - 1) * volVar
    end
    a:play(name, opts)
end

function Sfx.has(name)
    local a = audio()
    return a ~= nil and a.sources ~= nil and a.sources[name] ~= nil
end

function Sfx.playMusic(code, opts)
    local a = audio()
    if a then a:playMusic(code, opts) end
end

function Sfx.stopMusic()
    local a = audio()
    if a then a:stopMusic() end
end

function Sfx.silenceMusic(duration)
    local a = audio()
    if a and a.fadeOutMusic then a:fadeOutMusic(duration) end
end

function Sfx.setMasterVolume(v) local a = audio(); if a then a:setMasterVolume(v) end end
function Sfx.setMusicVolume(v)  local a = audio(); if a then a:setMusicVolume(v)  end end
function Sfx.setSfxVolume(v)    local a = audio(); if a then a:setSFXVolume(v)    end end

function Sfx.getMasterVolume() local a = audio(); return a and a.groups.master or 1 end
function Sfx.getMusicVolume()  local a = audio(); return a and a.groups.music  or 1 end
function Sfx.getSfxVolume()    local a = audio(); return a and a.groups.sfx    or 1 end

function Sfx.fadeMusicOut(duration)
    Sfx.silenceMusic(duration or 0.5)
end

return Sfx
