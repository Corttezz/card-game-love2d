-- src/ui/HudManager.lua
-- Gerenciador principal para todos os painéis de HUD

local HudPlayerPanel = require("src.ui.HudPlayerPanel")
local HudEnemyPanel = require("src.ui.HudEnemyPanel")

local HudManager = {}
HudManager.__index = HudManager

function HudManager:new()
    local instance = setmetatable({}, HudManager)
    
    -- Inicializa os painéis
    instance.playerPanel = HudPlayerPanel:new()
    instance.enemyPanel = HudEnemyPanel:new()
    
    -- Estado geral
    instance.visible = true
    instance.animationTime = 0
    
    -- Configurações de layout
    instance:updateLayout()
    
    return instance
end

function HudManager:update(dt)
    if not self.visible then return end
    
    self.animationTime = self.animationTime + dt
    
    -- Atualiza layout responsivo
    self:updateLayout()
    
    -- Atualiza painéis
    self.playerPanel:update(dt)
    self.enemyPanel:update(dt)
end

function HudManager:updateLayout()
    -- Atualiza posições dos painéis baseado na resolução atual
    self.playerPanel:updatePosition()
    self.enemyPanel:updatePosition()
end

function HudManager:draw(game)
    if not self.visible or not game then return end
    
    -- Salva completamente o estado dos gráficos antes do HUD
    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local oldFont = love.graphics.getFont()
    local oldLineWidth = love.graphics.getLineWidth()
    local oldCanvas = love.graphics.getCanvas()
    
    -- Desenha painel do jogador
    if game.player then
        self.playerPanel:draw(game.player)
    end
    
    -- Desenha painel do inimigo
    if game.enemy then
        self.enemyPanel:draw(game.enemy, game.currentPhase)
    end
    
    -- Força o reset completo do estado dos gráficos após o HUD
    love.graphics.setColor(oldR, oldG, oldB, oldA)
    love.graphics.setFont(oldFont)
    love.graphics.setLineWidth(oldLineWidth)
    love.graphics.setCanvas(oldCanvas)
    
    -- Reset adicional para garantir estado limpo
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

function HudManager:show()
    self.visible = true
end

function HudManager:hide()
    self.visible = false
end

function HudManager:isVisible()
    return self.visible
end

function HudManager:getPlayerPanel()
    return self.playerPanel
end

function HudManager:getEnemyPanel()
    return self.enemyPanel
end

-- Função para animar transições (opcional)
function HudManager:animateIn(duration, callback)
    duration = duration or 0.5
    -- Implementar animação de entrada se necessário
    if callback then callback() end
end

function HudManager:animateOut(duration, callback)
    duration = duration or 0.5
    -- Implementar animação de saída se necessário
    if callback then callback() end
end

return HudManager
