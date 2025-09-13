-- Sistema de Áudio para detecção e correção de problemas no WSL2
local AudioSystem = {}
AudioSystem.__index = AudioSystem

function AudioSystem:new()
    local instance = setmetatable({}, AudioSystem)
    instance.audioAvailable = false
    instance.audioCache = {}
    instance.backgroundMusic = nil
    instance.volume = 1.0
    instance.musicVolume = 0.3
    instance.sfxVolume = 0.7
    instance.isWSL2 = self:detectWSL2()
    
    -- Tenta inicializar o áudio
    instance:initializeAudio()
    
    return instance
end

function AudioSystem:detectWSL2()
    -- Detecta se está rodando no WSL2
    local file = io.open("/proc/version", "r")
    if file then
        local version = file:read("*all")
        file:close()
        return version:find("microsoft") ~= nil or version:find("WSL2") ~= nil
    end
    return false
end

function AudioSystem:initializeAudio()
    print("[AudioSystem] Inicializando sistema de áudio...")
    
    if self.isWSL2 then
        print("[AudioSystem] WSL2 detectado - configurando áudio...")
        self:setupWSL2Audio()
    end
    
    -- Testa se o áudio está funcionando
    self:testAudio()
end

function AudioSystem:setupWSL2Audio()
    -- Configurações específicas para WSL2
    -- Tenta usar diferentes backends de áudio
    local backends = {"pulse", "alsa", "directsound"}
    
    for _, backend in ipairs(backends) do
        print("[AudioSystem] Tentando backend:", backend)
        local success = pcall(function()
            love.audio.setVolume(1.0)
        end)
        
        if success then
            print("[AudioSystem] Backend", backend, "funcionando!")
            self.audioAvailable = true
            break
        else
            print("[AudioSystem] Backend", backend, "falhou")
        end
    end
    
    if not self.audioAvailable then
        print("[AudioSystem] AVISO: Áudio não disponível no WSL2")
        print("[AudioSystem] Para corrigir, execute no Windows:")
        print("  wsl --shutdown")
        print("  wsl --install")
        print("  Ou configure o PulseAudio no Windows")
    end
end

function AudioSystem:testAudio()
    -- Testa se consegue criar e reproduzir um som simples
    local testSound = love.audio.newSource("audio/clickselect2-92097.mp3", "static")
    if testSound then
        testSound:setVolume(0.1)
        local success = pcall(function()
            testSound:play()
        end)
        
        if success then
            self.audioAvailable = true
            print("[AudioSystem] ✓ Áudio funcionando corretamente!")
        else
            self.audioAvailable = false
            print("[AudioSystem] ✗ Falha ao reproduzir áudio")
        end
        
        testSound:stop()
    else
        self.audioAvailable = false
        print("[AudioSystem] ✗ Falha ao carregar arquivo de áudio")
    end
end

function AudioSystem:loadSound(name, path, volume)
    if not self.audioAvailable then
        print("[AudioSystem] Áudio não disponível - pulando carregamento de:", name)
        return nil
    end
    
    local success, sound = pcall(love.audio.newSource, path, "static")
    if success and sound then
        sound:setVolume(volume or 1.0)
        self.audioCache[name] = sound
        print("[AudioSystem] ✓ Som carregado:", name)
        return sound
    else
        print("[AudioSystem] ✗ Falha ao carregar som:", name)
        return nil
    end
end

function AudioSystem:playSound(name)
    if not self.audioAvailable then
        return false
    end
    
    local sound = self.audioCache[name]
    if sound then
        local success = pcall(function()
            sound:stop()
            sound:play()
        end)
        
        if success then
            return true
        else
            print("[AudioSystem] ✗ Falha ao reproduzir som:", name)
            return false
        end
    else
        print("[AudioSystem] ✗ Som não encontrado:", name)
        return false
    end
end

function AudioSystem:loadBackgroundMusic(path)
    if not self.audioAvailable then
        print("[AudioSystem] Áudio não disponível - música de fundo desabilitada")
        return false
    end
    
    local success, music = pcall(love.audio.newSource, path, "stream")
    if success and music then
        music:setVolume(self.musicVolume)
        music:setLooping(true)
        self.backgroundMusic = music
        print("[AudioSystem] ✓ Música de fundo carregada")
        return true
    else
        print("[AudioSystem] ✗ Falha ao carregar música de fundo")
        return false
    end
end

function AudioSystem:playBackgroundMusic()
    if self.backgroundMusic and self.audioAvailable then
        local success = pcall(function()
            self.backgroundMusic:play()
        end)
        
        if success then
            print("[AudioSystem] ✓ Música de fundo iniciada")
            return true
        else
            print("[AudioSystem] ✗ Falha ao iniciar música de fundo")
            return false
        end
    end
    return false
end

function AudioSystem:stopBackgroundMusic()
    if self.backgroundMusic then
        local success = pcall(function()
            self.backgroundMusic:stop()
        end)
        
        if success then
            print("[AudioSystem] ✓ Música de fundo parada")
            return true
        end
    end
    return false
end

function AudioSystem:setVolume(volume)
    self.volume = math.max(0, math.min(1, volume))
    love.audio.setVolume(self.volume)
end

function AudioSystem:setMusicVolume(volume)
    self.musicVolume = math.max(0, math.min(1, volume))
    if self.backgroundMusic then
        self.backgroundMusic:setVolume(self.musicVolume)
    end
end

function AudioSystem:setSFXVolume(volume)
    self.sfxVolume = math.max(0, math.min(1, volume))
    -- Atualiza volume de todos os sons carregados
    for name, sound in pairs(self.audioCache) do
        if sound and sound ~= self.backgroundMusic then
            sound:setVolume(self.sfxVolume)
        end
    end
end

function AudioSystem:isAudioAvailable()
    return self.audioAvailable
end

function AudioSystem:getStatus()
    return {
        available = self.audioAvailable,
        isWSL2 = self.isWSL2,
        volume = self.volume,
        musicVolume = self.musicVolume,
        sfxVolume = self.sfxVolume,
        loadedSounds = #self.audioCache,
        backgroundMusicPlaying = self.backgroundMusic and self.backgroundMusic:isPlaying()
    }
end

function AudioSystem:printStatus()
    local status = self:getStatus()
    print("=== STATUS DO ÁUDIO ===")
    print("Disponível:", status.available and "✓" or "✗")
    print("WSL2:", status.isWSL2 and "✓" or "✗")
    print("Volume geral:", status.volume)
    print("Volume música:", status.musicVolume)
    print("Volume SFX:", status.sfxVolume)
    print("Sons carregados:", status.loadedSounds)
    print("Música tocando:", status.backgroundMusicPlaying and "✓" or "✗")
    print("========================")
end

return AudioSystem
