-- engine/AudioManager.lua
-- Gerencia reprodução de SFX e música. Inspirado em
-- balatro-source/engine/sound_manager.lua.
--
-- Diferenças vs Balatro:
--   - Síncrono (sem love.thread).
--   - Polifonia automática: cada SFX mantém pool de Source clones; instâncias
--     ociosas são reaproveitadas, e quando todas estão tocando, clona uma nova.
--   - Modulação por grupo (master/music/sfx) aplicada em update(), não em
--     loadSound() — permite mudar volume em runtime sem reload.
--   - API mantém compatibilidade com o AudioSystem antigo (loadSound, playSound,
--     setMusicVolume, setSFXVolume, setVolume, isAudioAvailable, getStatus,
--     printStatus, loadBackgroundMusic, playBackgroundMusic, stopBackgroundMusic,
--     campos .musicVolume / .sfxVolume / .volume).

local AudioManager = {}
AudioManager.__index = AudioManager

local DEFAULT_GROUP = "sfx"
local MAX_CLONES_PER_SOUND = 8 -- evita explosão de polifonia em loops descontrolados.

local function detectWSL2()
    local file = io.open("/proc/version", "r")
    if not file then return false end
    local v = file:read("*all")
    file:close()
    return v:find("microsoft") ~= nil or v:find("WSL2") ~= nil
end

-- Volume final de uma source = base_volume * group_volume * master.
local function computeFinalVolume(self, entry)
    local groupVol = self.groups[entry.group] or 1
    return (entry.baseVolume or 1) * groupVol * (self.groups.master or 1)
end

-- ============== Lifecycle ==============

function AudioManager:new(opts)
    opts = opts or {}
    local self = setmetatable({}, AudioManager)

    self.audioAvailable = false
    self.isWSL2 = detectWSL2()

    -- Estrutura central: por code, mantém template (1ª source) + entry com
    -- pool de clones ativos.
    -- self.sources[code] = {
    --   template = Source, baseVolume, group, stream, basePitch, pitchVariation,
    --   instances = { Source, Source, ... }   -- inclui template como [1]
    -- }
    self.sources = {}

    -- Volumes por grupo. Tudo em [0,1].
    self.groups = {
        master = opts.masterVolume or 1.0,
        music  = opts.musicVolume  or 0.3,
        sfx    = opts.sfxVolume    or 0.7,
    }

    -- Music tracking: nome do code da música atualmente tocando + alvo de
    -- crossfade (nil = sem fade em curso).
    self.currentMusic = nil
    self.musicCrossfade = nil   -- { from = code, to = code, t = 0, duration = 1 }

    -- Compat: campos públicos lidos por SettingsMenu.
    self.musicVolume = self.groups.music
    self.sfxVolume   = self.groups.sfx
    self.volume      = self.groups.master

    self:_initializeAudio()
    return self
end

function AudioManager:_initializeAudio()
    print("[AudioManager] Inicializando...")
    if self.isWSL2 then
        print("[AudioManager] WSL2 detectado")
    end

    -- Tenta acessar love.audio. Se falhar, marca como indisponível.
    local ok = pcall(function() love.audio.setVolume(1.0) end)
    self.audioAvailable = ok
    if not ok then
        print("[AudioManager] AVISO: love.audio indisponível. Áudio será no-op.")
    end
end

-- ============== Loading ==============

-- Carrega um SFX/música. opts = { volume=1, group="sfx", stream=false,
--                                   pitch=1, pitchVariation=0 }
function AudioManager:loadSound(code, path, opts)
    if not self.audioAvailable then return nil end

    -- Permite chamada legada: loadSound(code, path, volumeNumber)
    if type(opts) == "number" then opts = { volume = opts } end
    opts = opts or {}

    local stream = opts.stream
    if stream == nil then
        stream = path:find("music") ~= nil or path:find("ambient") ~= nil
    end

    local sourceType = stream and "stream" or "static"
    local ok, template = pcall(love.audio.newSource, path, sourceType)
    if not ok or not template then
        print("[AudioManager] falha ao carregar:", code, path)
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
        instances      = { template },
    }

    template:setVolume(computeFinalVolume(self, entry))
    template:setPitch(entry.basePitch)
    template:setLooping(entry.loop)

    self.sources[code] = entry
    return entry
end

-- ============== Playback ==============

-- Procura instância ociosa no pool; clona se necessário (até MAX_CLONES_PER_SOUND).
local function acquireInstance(self, entry)
    for _, src in ipairs(entry.instances) do
        if not src:isPlaying() then return src end
    end

    if #entry.instances >= MAX_CLONES_PER_SOUND then
        -- Se passou do limite, reusa a primeira (corta a mais antiga). Padrão
        -- consistente com voice-stealing em engines de áudio.
        local stolen = entry.instances[1]
        stolen:stop()
        return stolen
    end

    -- Streams (música) não devem ser clonadas — clone() de stream é caro e
    -- raramente é o que se quer (música simultânea é crossfade, não polifonia).
    if entry.stream then
        entry.template:stop()
        return entry.template
    end

    local clone = entry.template:clone()
    clone:setLooping(entry.loop)
    table.insert(entry.instances, clone)
    return clone
end

-- play(code, opts) — opts override por chamada:
--   { volume, pitch, loop, group }
function AudioManager:play(code, opts)
    if not self.audioAvailable then return nil end
    local entry = self.sources[code]
    if not entry then
        print("[AudioManager] som não carregado:", code)
        return nil
    end

    opts = opts or {}
    local src = acquireInstance(self, entry)

    -- Pitch com variação opcional (útil em SFX repetitivos: sword, click).
    local pitch = opts.pitch or entry.basePitch
    if entry.pitchVariation > 0 then
        local jitter = (math.random() * 2 - 1) * entry.pitchVariation
        pitch = pitch + jitter
    end
    src:setPitch(pitch)

    -- Volume: opt.volume sobrescreve baseVolume só para este play.
    local saved = entry.baseVolume
    if opts.volume ~= nil then entry.baseVolume = opts.volume end
    src:setVolume(computeFinalVolume(self, entry))
    entry.baseVolume = saved

    if opts.loop ~= nil then src:setLooping(opts.loop) end

    local ok = pcall(function() src:play() end)
    if not ok then
        print("[AudioManager] falha ao tocar:", code)
        return nil
    end

    return src
end

-- Compat com a API antiga (Sfx.play -> playSound).
function AudioManager:playSound(name)
    return self:play(name) ~= nil
end

-- ============== Music ==============

-- Toca uma música em loop. Se já há música tocando, faz crossfade.
function AudioManager:playMusic(code, opts)
    if not self.audioAvailable then return false end
    opts = opts or {}

    if self.currentMusic == code then
        -- Já tocando essa música; só garante que está playing.
        local entry = self.sources[code]
        if entry and entry.template and not entry.template:isPlaying() then
            entry.template:setLooping(true)
            entry.template:play()
        end
        return true
    end

    -- Inicia nova música.
    local entry = self.sources[code]
    if not entry then
        print("[AudioManager] música não carregada:", code)
        return false
    end

    entry.loop = true
    entry.template:setLooping(true)

    local fadeDuration = opts.fadeDuration or 0
    if self.currentMusic and self.sources[self.currentMusic] then
        -- Crossfade entre duas músicas.
        self.musicCrossfade = {
            from = self.currentMusic,
            to = code,
            t = 0,
            duration = fadeDuration > 0 and fadeDuration or 1.0,
        }
        entry.template:setVolume(0)
        entry.template:play()
    elseif fadeDuration > 0 then
        -- Fade-in do silêncio. Reusa o crossfade (from=nil, só fade-in do "to").
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
    if not self.currentMusic then return end
    local entry = self.sources[self.currentMusic]
    if entry and entry.template then entry.template:stop() end
    self.currentMusic = nil
    self.musicCrossfade = nil
end

-- Compat: API antiga assumia 1 música única em self.backgroundMusic.
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

-- ============== Volumes ==============

function AudioManager:setGroupVolume(group, value)
    value = math.max(0, math.min(1, value))
    self.groups[group] = value
    -- Mantém campos de compat sincronizados.
    if group == "master" then self.volume = value end
    if group == "music"  then self.musicVolume = value end
    if group == "sfx"    then self.sfxVolume = value end
end

function AudioManager:setMasterVolume(v) self:setGroupVolume("master", v) end
function AudioManager:setMusicVolume(v)  self:setGroupVolume("music",  v) end
function AudioManager:setSFXVolume(v)    self:setGroupVolume("sfx",    v) end

-- Compat: setVolume = master.
function AudioManager:setVolume(v) self:setGroupVolume("master", v) end

-- ============== Update loop ==============

-- Re-aplica volumes em todas instâncias ativas e processa crossfade de música.
-- Também faz cleanup lazy de clones que terminaram.
function AudioManager:update(dt)
    if not self.audioAvailable then return end

    -- Crossfade de música.
    if self.musicCrossfade then
        local cf = self.musicCrossfade
        cf.t = cf.t + dt
        local progress = math.min(1, cf.t / cf.duration)

        local fromEntry = self.sources[cf.from]
        local toEntry   = self.sources[cf.to]

        if fromEntry and fromEntry.template then
            fromEntry.template:setVolume(computeFinalVolume(self, fromEntry) * (1 - progress))
        end
        if toEntry and toEntry.template then
            toEntry.template:setVolume(computeFinalVolume(self, toEntry) * progress)
        end

        if progress >= 1 then
            if fromEntry and fromEntry.template then fromEntry.template:stop() end
            self.musicCrossfade = nil
        end
    end

    -- Atualiza volumes de todas instâncias ativas (caso volume de grupo mudou).
    for code, entry in pairs(self.sources) do
        local final = computeFinalVolume(self, entry)
        local i = 1
        while i <= #entry.instances do
            local src = entry.instances[i]
            if src:isPlaying() then
                -- Música em crossfade tem volume gerenciado acima; pular.
                if not (self.musicCrossfade and (code == self.musicCrossfade.from or code == self.musicCrossfade.to)) then
                    src:setVolume(final)
                end
                i = i + 1
            else
                -- Mantém template (i==1) sempre; clones ociosos podem ser
                -- removidos pra liberar memória — mas só se passaram muitas
                -- instâncias. Pra simplicidade, mantemos pool inteiro.
                i = i + 1
            end
        end
    end
end

-- ============== Stop ==============

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

-- ============== Status / Debug ==============

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
    print("=== STATUS DO ÁUDIO ===")
    print("Disponível:", s.available and "✓" or "✗")
    print("WSL2:", s.isWSL2 and "✓" or "✗")
    print("Master:", s.master)
    print("Música:", s.music)
    print("SFX:", s.sfx)
    print("Sons carregados:", s.loadedSounds)
    print("Vozes ativas:", s.activeVoices)
    print("Música atual:", s.currentMusic or "(nenhuma)")
    print("========================")
end

return AudioManager
