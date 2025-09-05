-- src/systems/SmokeSystemExample.lua
-- Exemplos de uso do sistema de smoke

local SmokeSystem = require("src.systems.SmokeSystem")
local SmokeConfig = require("src.config.SmokeConfig")

-- Exemplo 1: Uso básico
local function basicUsage()
    local smoke = SmokeSystem:new()
    
    -- Aplica configuração padrão
    SmokeConfig.applyToSystem(smoke, "default")
    
    -- No love.update(dt)
    smoke:update(dt)
    
    -- No love.draw()
    smoke:draw()
end

-- Exemplo 2: Mudança dinâmica de presets
local function dynamicPresets()
    local smoke = SmokeSystem:new()
    
    -- Começa sutil
    SmokeConfig.applyToSystem(smoke, "subtle")
    
    -- Em momentos especiais, aumenta intensidade
    if isBossFight then
        SmokeConfig.applyToSystem(smoke, "intense")
    elseif isCutscene then
        SmokeConfig.applyToSystem(smoke, "atmospheric")
    else
        SmokeConfig.applyToSystem(smoke, "default")
    end
end

-- Exemplo 3: Configuração personalizada
local function customConfig()
    local smoke = SmokeSystem:new()
    
    -- Configuração personalizada para momentos dramáticos
    local dramaticConfig = {
        maxParticles = 20,
        spawnRate = 0.3,
        minOpacity = 0.08,
        maxOpacity = 0.20,
        minSpeed = 10,
        maxSpeed = 25,
        windEffect = 0.8
    }
    
    smoke:setConfig(dramaticConfig)
end

-- Exemplo 4: Controle por eventos
local function eventBasedControl()
    local smoke = SmokeSystem:new()
    
    -- Evento: Jogador toma dano
    function onPlayerDamaged()
        SmokeConfig.applyToSystem(smoke, "intense")
        -- Volta ao normal após 3 segundos
        love.timer.after(3, function()
            SmokeConfig.applyToSystem(smoke, "default")
        end)
    end
    
    -- Evento: Vitória
    function onVictory()
        SmokeConfig.applyToSystem(smoke, "atmospheric")
        -- Desliga após 5 segundos
        love.timer.after(5, function()
            smoke:clear()
        end)
    end
end

-- Exemplo 5: Sistema de transições
local function transitionSystem()
    local smoke = SmokeSystem:new()
    
    -- Transição suave entre presets
    function transitionToPreset(targetPreset, duration)
        local currentConfig = smoke.config
        local targetConfig = SmokeConfig.getConfig(targetPreset)
        
        -- Interpolação suave
        local t = 0
        local timer = love.timer.newTimer()
        
        timer:every(0.016, function() -- 60 FPS
            t = t + 0.016 / duration
            
            if t >= 1 then
                -- Aplica configuração final
                SmokeConfig.applyToSystem(smoke, targetPreset)
                timer:stop()
            else
                -- Interpolação
                local interpolated = {}
                for key, value in pairs(targetConfig) do
                    if type(value) == "number" then
                        interpolated[key] = currentConfig[key] + (value - currentConfig[key]) * t
                    else
                        interpolated[key] = value
                    end
                end
                smoke:setConfig(interpolated)
            end
        end)
    end
    
    -- Uso: transição suave para preset intenso em 2 segundos
    transitionToPreset("intense", 2.0)
end

-- Exemplo 6: Sistema de camadas
local function layeredSmoke()
    local backgroundSmoke = SmokeSystem:new()
    local foregroundSmoke = SmokeSystem:new()
    
    -- Background: sempre sutil
    SmokeConfig.applyToSystem(backgroundSmoke, "subtle")
    
    -- Foreground: muda conforme situação
    SmokeConfig.applyToSystem(foregroundSmoke, "default")
    
    -- No love.draw()
    backgroundSmoke:draw()  -- Desenha primeiro (atrás)
    -- ... desenha outros elementos do jogo
    foregroundSmoke:draw()  -- Desenha por último (na frente)
end

-- Exemplo 7: Debug e monitoramento
local function debugSystem()
    local smoke = SmokeSystem:new()
    
    -- Função para mostrar estatísticas na tela
    function drawSmokeStats()
        local stats = smoke:getStats()
        local info = string.format(
            "Smoke: %d/%d partículas | %d texturas",
            stats.activeParticles,
            stats.maxParticles,
            stats.texturesLoaded
        )
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(info, 10, 10)
    end
    
    -- No love.draw()
    drawSmokeStats()
end

-- Exemplo 8: Sistema de qualidade adaptativa
local function adaptiveQuality()
    local smoke = SmokeSystem:new()
    
    -- Detecta FPS e ajusta qualidade
    local fpsHistory = {}
    local targetFPS = 60
    
    function updateAdaptiveQuality()
        local currentFPS = love.timer.getFPS()
        table.insert(fpsHistory, currentFPS)
        
        -- Mantém apenas os últimos 10 FPS
        if #fpsHistory > 10 then
            table.remove(fpsHistory, 1)
        end
        
        -- Calcula FPS médio
        local avgFPS = 0
        for _, fps in ipairs(fpsHistory) do
            avgFPS = avgFPS + fps
        end
        avgFPS = avgFPS / #fpsHistory
        
        -- Ajusta qualidade baseado no FPS
        if avgFPS < targetFPS * 0.8 then
            -- FPS baixo: reduz qualidade
            SmokeConfig.applyToSystem(smoke, "subtle")
        elseif avgFPS > targetFPS * 0.95 then
            -- FPS bom: pode aumentar qualidade
            SmokeConfig.applyToSystem(smoke, "default")
        end
    end
    
    -- No love.update(dt)
    updateAdaptiveQuality()
end

return {
    basicUsage = basicUsage,
    dynamicPresets = dynamicPresets,
    customConfig = customConfig,
    eventBasedControl = eventBasedControl,
    transitionSystem = transitionSystem,
    layeredSmoke = layeredSmoke,
    debugSystem = debugSystem,
    adaptiveQuality = adaptiveQuality
}
