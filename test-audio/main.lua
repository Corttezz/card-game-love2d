-- test-audio.lua
-- Script de teste para verificar problemas de áudio no WSL2

local AudioDiagnosticSystem = require("src.systems.AudioDiagnosticSystem")
local RobustAudioSystem = require("src.systems.RobustAudioSystem")

function love.load()
    print("=== TESTE DE ÁUDIO ===")
    
    -- Teste 1: Diagnóstico completo
    local diagnostic = AudioDiagnosticSystem:new()
    local audioWorking = diagnostic:runDiagnostics()
    diagnostic:printRecommendations()
    
    print("\n=== TESTE DO SISTEMA ROBUSTO ===")
    
    -- Teste 2: Sistema robusto
    local audioSystem = RobustAudioSystem:new()
    audioSystem:printStatus()
    
    -- Teste 3: Carregar e tocar sons
    print("\n=== TESTANDO SONS ===")
    audioSystem:loadSound("test1", "audio/clickselect2-92097.mp3", 0.5)
    audioSystem:loadSound("test2", "audio/deckStart.mp3", 0.3)
    
    -- Toca sons após 1 segundo
    love.timer.sleep(1)
    print("Tocando som 1...")
    audioSystem:playSound("test1")
    
    love.timer.sleep(1)
    print("Tocando som 2...")
    audioSystem:playSound("test2")
    
    print("\n=== TESTE CONCLUÍDO ===")
    print("Pressione ESC para sair")
end

function love.draw()
    love.graphics.print("Teste de Áudio - Verifique o console", 10, 10)
    love.graphics.print("Pressione ESC para sair", 10, 30)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
