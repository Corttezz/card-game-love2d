-- components/GameUI.lua
local Button = require("components.Button")
local JokerSlot = require("components.JokerSlot")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local VisualEffects = require("src.ui.VisualEffects")
local ParticleSystem = require("src.systems.ParticleSystem")
local HudManager = require("src.ui.HudManager")

local GameUI = {}
GameUI.__index = GameUI

function GameUI:new()
    local instance = setmetatable({}, GameUI)
    instance.visible = true
    instance.animationTime = 0
    
    -- Botão de voltar ao menu
    local buttonWidth = Config.Utils.getResponsiveSize(0.12, 120, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(0.05, 40, "height")
    local buttonX = Config.Utils.getResponsiveSize(0.02, 20, "width")
    local buttonY = Config.Utils.getResponsiveSize(0.02, 20, "height")
    
    instance.backToMenuButton = Button:new(
        buttonX, buttonY, buttonWidth, buttonHeight,
        "← Menu", function() end, Theme.Colors.ERROR, 16
    )
    
    -- Cria slots de joker
    instance.jokerSlots = {}
    instance:createJokerSlots()
    
    -- Inicializa o novo sistema de HUD
    instance.hudManager = HudManager:new()
    
    return instance
end

function GameUI:createJokerSlots()
    local width = love.graphics.getWidth()
    local slotSize = Config.Utils.getResponsiveSize(0.06, 60, "width") -- Slots menores
    local spacing = Config.Utils.getResponsiveSize(0.015, 15, "width") -- Espaçamento menor
    local totalWidth = (slotSize * Config.Game.MAX_JOKER_SLOTS) + (spacing * (Config.Game.MAX_JOKER_SLOTS - 1))
    local startX = (width - totalWidth) / 2
    local startY = Config.Utils.getResponsiveSize(0.08, 80, "height") -- Posicionado no topo
    
    for i = 1, Config.Game.MAX_JOKER_SLOTS do
        local x = startX + (i - 1) * (slotSize + spacing)
        self.jokerSlots[i] = JokerSlot:new(x, startY, slotSize)
    end
end

function GameUI:update(dt)
    if not self.visible then return end
    
    self.animationTime = self.animationTime + dt
    
    -- Atualiza posições dos elementos
    self:updatePositions()
    
    -- Atualiza botão
    self.backToMenuButton:update(dt)
    
    -- Atualiza slots de joker
    for _, slot in ipairs(self.jokerSlots) do
        slot:update(dt)
    end
    
    -- Atualiza o novo sistema de HUD
    self.hudManager:update(dt)
    
    -- Atualiza sistema de partículas
    ParticleSystem.Manager:update(dt)
end

function GameUI:updatePositions()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Botão de voltar ao menu
    local buttonWidth = Config.Utils.getResponsiveSize(0.12, 120, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(0.05, 40, "height")
    local buttonX = Config.Utils.getResponsiveSize(0.02, 20, "width")
    local buttonY = Config.Utils.getResponsiveSize(0.02, 20, "height")
    
    self.backToMenuButton:setPosition(buttonX, buttonY)
    self.backToMenuButton.width = buttonWidth
    self.backToMenuButton.height = buttonHeight
    
    -- Atualiza posições dos slots de joker
    local slotSize = Config.Utils.getResponsiveSize(0.06, 60, "width") -- Slots menores
    local spacing = Config.Utils.getResponsiveSize(0.015, 15, "width") -- Espaçamento menor
    local totalWidth = (slotSize * Config.Game.MAX_JOKER_SLOTS) + (spacing * (Config.Game.MAX_JOKER_SLOTS - 1))
    local startX = (width - totalWidth) / 2
    local startY = Config.Utils.getResponsiveSize(0.08, 80, "height") -- Posicionado no topo
    
    for i, slot in ipairs(self.jokerSlots) do
        local x = startX + (i - 1) * (slotSize + spacing)
        slot.x = x
        slot.y = startY
        slot.size = slotSize
    end
end

function GameUI:draw(game)
    if not self.visible then return end
    
    -- Desenha o botão de voltar ao menu
    self.backToMenuButton:draw()
    
    -- Desenha informações do jogo no topo
    --self:drawGameInfo(game)
    
    -- Jokers agora são desenhados como cartas no main.lua (Balatro style)
    -- self:drawJokerSlots(game)
    
    -- Desenha o novo sistema de HUD (substitui drawPlayerInfo e drawEnemyInfo)
    self.hudManager:draw(game)
    
    -- Desenha sistema de partículas
    ParticleSystem.Manager:draw()
end

function GameUI:drawGameInfo(game)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Container de informações do jogo (topo central)
    local infoWidth = Config.Utils.getResponsiveSize(0.4, 400, "width")
    local infoHeight = Config.Utils.getResponsiveSize(0.08, 80, "height")
    local infoX = (width - infoWidth) / 2
    local infoY = Config.Utils.getResponsiveSize(0.05, 50, "height")
    
    -- Background do container com efeito de vidro
    VisualEffects.Utils.drawGlassRectangle(
        infoX, infoY, infoWidth, infoHeight, 15,
        {0.1, 0.1, 0.15, 1}, 0.6
    )
    
    -- Borda animada
    local borderColor = VisualEffects.Utils.interpolateColors(
        {1, 0.8, 0.2, 1},
        {1, 1, 0.6, 1},
        math.sin(self.animationTime * 2) * 0.5 + 0.5
    )
    
    VisualEffects.Utils.drawAnimatedBorder(
        infoX, infoY, infoWidth, infoHeight, 15,
        borderColor, self.animationTime, 1.5
    )
    
    -- Fonte para informações
    local infoFont = FontManager.getResponsiveFont(0.025, 20, "height")
    
    -- Fase atual com efeitos
    local phaseText = "FASE " .. (game.currentPhase or 1)
    VisualEffects.Utils.drawTextWithEffects(
        phaseText, infoX + 20, infoY + 15, infoFont,
        {1, 1, 1, 1}, {0, 0, 0, 0.8}, {1, 0.8, 0.2, 1}, 0.3
    )
    
    -- Pontuação com efeitos
    local scoreText = "PONTUAÇÃO: " .. (game.score or 0)
    local scoreWidth = infoFont:getWidth(scoreText)
    VisualEffects.Utils.drawTextWithEffects(
        scoreText, infoX + infoWidth - scoreWidth - 20, infoY + 15, infoFont,
        {1, 1, 1, 1}, {0, 0, 0, 0.8}, {1, 0.8, 0.2, 1}, 0.3
    )
    
    -- Turno atual com efeitos
    local turnText = "TURNO: " .. (game.turn == "player" and "JOGADOR" or "INIMIGO")
    local turnWidth = infoFont:getWidth(turnText)
    VisualEffects.Utils.drawTextWithEffects(
        turnText, infoX + (infoWidth - turnWidth) / 2, infoY + 45, infoFont,
        {1, 1, 1, 1}, {0, 0, 0, 0.8}, {1, 0.8, 0.2, 1}, 0.3
    )
    
    -- Partículas de energia
    VisualEffects.Particles.energyParticles(
        infoX + infoWidth/2, infoY + infoHeight/2, 3,
        {1, 0.8, 0.2, 0.6}, self.animationTime
    )
end

function GameUI:drawJokerSlots(game)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Título dos slots de joker com efeitos avançados (no topo)
    local titleFont = FontManager.getResponsiveFont(0.03, 24, "height")
    local titleText = "SLOTS DE JOKER"
    local titleWidth = titleFont:getWidth(titleText)
    local titleX = (width - titleWidth) / 2
    local titleY = Config.Utils.getResponsiveSize(0.02, 20, "height") -- Título no topo
    
    -- Glow do título
    VisualEffects.Utils.drawTextWithEffects(
        titleText, titleX, titleY, titleFont,
        {1, 0.8, 0.2, 1}, {0, 0, 0, 0.8}, {1, 1, 0.6, 1}, 0.8
    )
    
    -- Container dos slots com efeito de vidro avançado (no topo) - SEM BORDAS
    local slotsContainerWidth = Config.Utils.getResponsiveSize(0.6, 600, "width") -- Container menor
    local slotsContainerHeight = Config.Utils.getResponsiveSize(0.12, 120, "height") -- Altura reduzida
    local slotsContainerX = (width - slotsContainerWidth) / 2
    local slotsContainerY = Config.Utils.getResponsiveSize(0.06, 60, "height") -- Container no topo
    
    -- Background com gradiente radial (sem bordas)
    VisualEffects.Utils.drawRadialGradient(
        slotsContainerX, slotsContainerY, slotsContainerWidth, slotsContainerHeight,
        {0.1, 0.1, 0.15, 0.8}, {0.05, 0.05, 0.08, 0.9}
    )
    
    -- REMOVIDO: Borda com efeito de energia (sem bordas)
    
    -- Desenha os slots individuais
    for i, slot in ipairs(self.jokerSlots) do
        -- Atualiza o joker no slot se existir
        if game.jokerSlots[i] then
            slot:setJoker(game.jokerSlots[i])
        else
            slot:removeJoker()
        end
        
        slot:draw()
    end
    
    -- Partículas de energia ao redor do container
    VisualEffects.Particles.energyParticles(
        slotsContainerX + slotsContainerWidth/2, slotsContainerY + slotsContainerHeight/2, 6,
        {1, 0.8, 0.2, 0.4}, self.animationTime
    )
end

-- FUNÇÃO REMOVIDA: drawPlayerInfo - substituída pelo HudManager
-- function GameUI:drawPlayerInfo(game)
--     -- Esta função foi substituída pelo novo sistema de HUD componetizado
--     -- Veja HudPlayerPanel para a nova implementação
-- end

-- FUNÇÃO REMOVIDA: drawEnemyInfo - substituída pelo HudManager
-- function GameUI:drawEnemyInfo(game)
--     -- Esta função foi substituída pelo novo sistema de HUD componetizado
--     -- Veja HudEnemyPanel para a nova implementação
-- end

-- FUNÇÃO REMOVIDA: drawAdvancedStatusBar - substituída pelos HudPanels
-- function GameUI:drawAdvancedStatusBar(label, current, max, x, y, width, height, color)
--     -- Esta função foi substituída pelo sistema de barras dos HudPanels
-- end

function GameUI:isBackToMenuClicked(x, y)
    return self.backToMenuButton.hover
end

function GameUI:show()
    self.visible = true
end

function GameUI:hide()
    self.visible = false
end

return GameUI
