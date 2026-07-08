-- src/ui/HudManager.lua
-- Gerenciador principal para todos os painéis de HUD

local HudPlayerPanel = require("src.ui.HudPlayerPanel")
local ManaOrb = require("src.ui.ManaOrb")
local PlayerBuffPills = require("src.ui.PlayerBuffPills")

local HudManager = {}
HudManager.__index = HudManager

function HudManager:new()
    local instance = setmetatable({}, HudManager)

    -- Painéis ativos. Enemy panel foi aposentado — HP/intent agora ficam
    -- ancorados no sprite do inimigo via EnemyHud (chamado em main.lua).
    instance.playerPanel = HudPlayerPanel:new()
    instance.manaOrb = ManaOrb:new()
    instance.playerBuffPills = PlayerBuffPills:new()

    instance.visible = true
    instance.animationTime = 0

    instance:updateLayout()

    return instance
end

function HudManager:update(dt, game)
    if not self.visible then return end

    self.animationTime = self.animationTime + dt
    self:updateLayout()

    local player = game and game.player or nil
    self.playerPanel:update(dt, player)
    self.manaOrb:update(dt, player)
    self.playerBuffPills:update(dt)
end

function HudManager:updateLayout()
    self.playerPanel:updatePosition()
    self.manaOrb:updatePosition()
end

function HudManager:draw(game)
    if not self.visible or not game then return end

    local oldR, oldG, oldB, oldA = love.graphics.getColor()
    local oldFont = love.graphics.getFont()
    local oldLineWidth = love.graphics.getLineWidth()
    local oldCanvas = love.graphics.getCanvas()

    if game.player then
        self.playerPanel:draw(game.player)
        -- Chip da passiva de classe (clareza: visível durante o combate)
        if self.playerPanel.drawPassiveChip then
            self.playerPanel:drawPassiveChip(game)
        end
        -- Pills de buff ficam logo acima do player panel (row horizontal).
        -- Passa coords do panel pra alinhamento.
        self.playerBuffPills:draw(
            game.player,
            self.playerPanel.x,
            self.playerPanel.y,
            self.playerPanel.width
        )
        self.manaOrb:draw(game.player)
    end

    love.graphics.setColor(oldR, oldG, oldB, oldA)
    love.graphics.setFont(oldFont)
    love.graphics.setLineWidth(oldLineWidth)
    love.graphics.setCanvas(oldCanvas)
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
