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
    
    -- Desenha informações de economia (ouro)
    -- if game.economySystem then
    --     self:drawEconomyInfo(game)
    -- end
    
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

-- -- Desenha informações de economia (ouro)
-- function HudManager:drawEconomyInfo(game)
--     local width = love.graphics.getWidth()
--     local height = love.graphics.getHeight()
    
--     -- Posição do painel de economia (canto superior direito)
--     local economyWidth = 150
--     local economyHeight = 60
--     local economyX = width - economyWidth - 20
--     local economyY = 20
    
--     -- Background do painel de economia
--     love.graphics.setColor(0.1, 0.1, 0.2, 0.8)
--     love.graphics.rectangle("fill", economyX, economyY, economyWidth, economyHeight, 10)
    
--     -- Borda do painel
--     love.graphics.setColor(1, 1, 0.2, 1) -- Amarelo para ouro
--     love.graphics.rectangle("line", economyX, economyY, economyWidth, economyHeight, 10)
    
--     -- Ícone de ouro (simples)
--     love.graphics.setColor(1, 1, 0.2, 1)
--     love.graphics.circle("fill", economyX + 25, economyY + 30, 8)
    
--     -- Texto do ouro
--     love.graphics.setColor(1, 1, 1, 1)
--     local font = love.graphics.getFont()
--     local goldText = "$" .. game.economySystem.currentGold
--     love.graphics.printf(goldText, economyX + 40, economyY + 20, economyWidth - 50, "left")
    
--     -- Juros para próxima batalha (se houver)
--     local interestGold = game.economySystem:calculateInterest()
--     if interestGold > 0 then
--         love.graphics.setColor(0.8, 0.8, 0.8, 1)
--         local interestText = "+" .. math.floor(interestGold) .. " juros"
--         love.graphics.printf(interestText, economyX + 40, economyY + 40, economyWidth - 50, "left")
--     end
-- end

return HudManager
