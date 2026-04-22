-- src/config/SmokeConfig.lua
-- Configurações para o sistema de smoke

local SmokeConfig = {}

-- Configurações padrão (visível mas não distrai — ambiência de arena de combate)
SmokeConfig.DEFAULT = {
    maxParticles = 6,            -- subiu de 4 para dar presença
    spawnRate = 1.5,             -- spawn mais frequente
    minScale = 1.4,
    maxScale = 2.2,
    minOpacity = 0.10,           -- subiu de 0.02 (quase invisível) para 0.10
    maxOpacity = 0.22,           -- subiu de 0.08
    minSpeed = 18,
    maxSpeed = 28,
    windEffect = 0.4,
    fadeInTime = 1.3,
    centerZone = 1.0,
    maxOffscreenDistance = 200
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

-- Presets por ato: cor/densidade tematica (aplicado via ActSystem no futuro)
SmokeConfig.ACT_1_CATACUMBS = {
    maxParticles = 7, spawnRate = 1.4,
    minScale = 1.3, maxScale = 2.0,
    minOpacity = 0.12, maxOpacity = 0.25,
    minSpeed = 15, maxSpeed = 22,
    windEffect = 0.3, fadeInTime = 1.4,
    centerZone = 1.0, maxOffscreenDistance = 200,
    tint = {0.70, 0.65, 0.55}, -- sepia pesado
}

SmokeConfig.ACT_2_TOWER = {
    maxParticles = 5, spawnRate = 1.8,
    minScale = 1.5, maxScale = 2.4,
    minOpacity = 0.08, maxOpacity = 0.18,
    minSpeed = 22, maxSpeed = 34,
    windEffect = 0.6, fadeInTime = 1.0,
    centerZone = 1.0, maxOffscreenDistance = 220,
    tint = {0.55, 0.50, 0.70}, -- violeta/pedra mistica
}

SmokeConfig.ACT_3_ABYSS = {
    maxParticles = 8, spawnRate = 1.0,
    minScale = 1.7, maxScale = 2.8,
    minOpacity = 0.15, maxOpacity = 0.35,
    minSpeed = 12, maxSpeed = 20,
    windEffect = 0.2, fadeInTime = 1.6,
    centerZone = 1.0, maxOffscreenDistance = 260,
    tint = {0.30, 0.20, 0.45}, -- abismal violeta
}

-- Função para obter configuração
function SmokeConfig.getConfig(preset)
    if preset == "intense" then return SmokeConfig.INTENSE
    elseif preset == "subtle" then return SmokeConfig.SUBTLE
    elseif preset == "atmospheric" then return SmokeConfig.ATMOSPHERIC
    elseif preset == "act1" then return SmokeConfig.ACT_1_CATACUMBS
    elseif preset == "act2" then return SmokeConfig.ACT_2_TOWER
    elseif preset == "act3" then return SmokeConfig.ACT_3_ABYSS
    else return SmokeConfig.DEFAULT end
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
