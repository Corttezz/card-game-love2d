-- src/config/SmokeConfig.lua
-- Configurações para o sistema de smoke

local SmokeConfig = {}

-- Configurações padrão (smokes médias e distribuídas)
SmokeConfig.DEFAULT = {
    maxParticles = 4,            -- Número máximo de partículas (muito reduzido)
    spawnRate = 2.0,             -- Taxa de spawn (segundos) - Mais lento
    minScale = 1.2,              -- Escala mínima (reduzida)
    maxScale = 2.0,              -- Escala máxima (reduzida)
    minOpacity = 0.02,           -- Opacidade mínima (muito sutil)
    maxOpacity = 0.08,           -- Opacidade máxima (ainda sutil)
    minSpeed = 15,               -- Velocidade mínima (pixels/segundo) - Reduzida
    maxSpeed = 25,               -- Velocidade máxima (pixels/segundo) - Reduzida
    windEffect = 0.3,            -- Efeito de vento (pixels/segundo) - Reduzido
    fadeInTime = 1.5,            -- Tempo para aparecer (segundos) - Mais lento
    centerZone = 1.0,            -- Zona da tela (100% - toda a tela)
    maxOffscreenDistance = 200   -- Distância máxima fora da tela
}

-- Configuração para efeito mais intenso
SmokeConfig.INTENSE = {
    maxParticles = 6,
    spawnRate = 1.0,
    minScale = 1.5,
    maxScale = 2.5,
    minOpacity = 0.05,
    maxOpacity = 0.15,
    minSpeed = 20,
    maxSpeed = 35,
    windEffect = 0.5,
    fadeInTime = 1.0,
    centerZone = 1.0,
    maxOffscreenDistance = 250
}

-- Configuração para efeito muito sutil
SmokeConfig.SUBTLE = {
    maxParticles = 2,
    spawnRate = 3.0,
    minScale = 0.8,
    maxScale = 1.5,
    minOpacity = 0.01,
    maxOpacity = 0.04,
    minSpeed = 10,
    maxSpeed = 20,
    windEffect = 0.2,
    fadeInTime = 2.0,
    centerZone = 1.0,
    maxOffscreenDistance = 150
}

-- Configuração para efeito atmosférico
SmokeConfig.ATMOSPHERIC = {
    maxParticles = 5,
    spawnRate = 1.5,
    minScale = 1.4,
    maxScale = 2.2,
    minOpacity = 0.015,
    maxOpacity = 0.06,
    minSpeed = 18,
    maxSpeed = 28,
    windEffect = 0.4,
    fadeInTime = 1.3,
    centerZone = 1.0,
    maxOffscreenDistance = 180
}

-- Função para obter configuração
function SmokeConfig.getConfig(preset)
    if preset == "intense" then
        return SmokeConfig.INTENSE
    elseif preset == "subtle" then
        return SmokeConfig.SUBTLE
    elseif preset == "atmospheric" then
        return SmokeConfig.ATMOSPHERIC
    else
        return SmokeConfig.DEFAULT
    end
end

-- Função para aplicar configuração ao sistema
function SmokeConfig.applyToSystem(smokeSystem, preset)
    if smokeSystem then
        local config = SmokeConfig.getConfig(preset)
        smokeSystem:setConfig(config)
        print("Smoke config aplicada:", preset)
    end
end

-- Função para listar presets disponíveis
function SmokeConfig.listPresets()
    return {
        "default",      -- Padrão (sutil)
        "subtle",       -- Muito sutil
        "atmospheric",  -- Atmosférico
        "intense"       -- Intenso
    }
end

return SmokeConfig
