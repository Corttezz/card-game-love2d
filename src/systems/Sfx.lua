-- src/systems/Sfx.lua
-- Facade único pra _G.audioSystem (instância de AudioManager).
-- Mantém compatibilidade total com a API antiga (Sfx.play("name")) e expõe
-- novos helpers de música/volume sem forçar consumers a tocar audioSystem direto.

local Sfx = {}

local function audio()
    return _G.audioSystem
end

-- ============== Playback ==============

-- Toca um SFX por nome. opts = { volume, pitch, loop }.
-- O AudioManager já é no-op gracioso quando áudio indisponível.
function Sfx.play(name, opts)
    local a = audio()
    if not a then return end
    if opts then
        a:play(name, opts)
    else
        a:playSound(name)
    end
end

-- Toca SFX com pitch/volume aleatórios em torno de um centro. Replica o
-- pattern do Balatro (engine/text.lua:201) que evita fadiga auditiva em sons
-- repetidos (hover, click). pitchVar e volVar são amplitudes simétricas.
-- Ex: Sfx.playWithVariation("hoverCard", 0.95, 0.15, 0.4, 0.05) →
--     pitch ∈ [0.80, 1.10], volume ∈ [0.35, 0.45].
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

-- Um som com esse código está registrado? (feel v2: JokerProcFx decide entre
-- assinatura do joker e o jokerTick genérico sem disparar warning de missing).
function Sfx.has(name)
    local a = audio()
    return a ~= nil and a.sources ~= nil and a.sources[name] ~= nil
end

-- ============== Music ==============

function Sfx.playMusic(code, opts)
    local a = audio()
    if a then a:playMusic(code, opts) end
end

function Sfx.stopMusic()
    local a = audio()
    if a then a:stopMusic() end
end

-- ============== Volume groups ==============

function Sfx.setMasterVolume(v) local a = audio(); if a then a:setMasterVolume(v) end end
function Sfx.setMusicVolume(v)  local a = audio(); if a then a:setMusicVolume(v)  end end
function Sfx.setSfxVolume(v)    local a = audio(); if a then a:setSFXVolume(v)    end end

function Sfx.getMasterVolume() local a = audio(); return a and a.groups.master or 1 end
function Sfx.getMusicVolume()  local a = audio(); return a and a.groups.music  or 1 end
function Sfx.getSfxVolume()    local a = audio(); return a and a.groups.sfx    or 1 end

-- Fade out da música atual em `duration` segundos e depois para. Usa
-- EventManager.parallelEase pra interpolar o group volume sem bloquear outras
-- filas; restaura volume original depois.
function Sfx.fadeMusicOut(duration)
    local a = audio()
    if not a then return end
    duration = duration or 0.5

    local EM = _G.EventManager
    if not EM then
        a:stopMusic()
        return
    end

    local restoreTo = a.groups.music
    EM.parallelEase(a.groups, "music", 0, duration, "smooth", "music_fade")
    EM.parallel(duration + 0.05, function()
        a:stopMusic()
        a.groups.music = restoreTo  -- restaura pra próxima música começar no volume certo
        a.musicVolume  = restoreTo
    end, "music_fade")
end

return Sfx
