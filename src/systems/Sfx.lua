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
