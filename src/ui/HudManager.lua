local HudPlayerPanel = require("src.ui.HudPlayerPanel")
local ManaOrb = require("src.ui.ManaOrb")
local PlayerBuffPills = require("src.ui.PlayerBuffPills")
local OrbRow = require("src.ui.OrbRow")

local HudManager = {}
HudManager.__index = HudManager

function HudManager:new()
    local instance = setmetatable({}, HudManager)

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
    OrbRow.update(dt, game)
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
        if self.playerPanel.drawPassiveChip then
            self.playerPanel:drawPassiveChip(game)
        end
        self.playerBuffPills:draw(
            game.player,
            self.playerPanel.x,
            self.playerPanel.y,
            self.playerPanel.width,
            game
        )
        OrbRow.draw(game, self.playerPanel.x, self.playerPanel.y)
        self.manaOrb:draw(game.player)

        local Tutorial = require("src.systems.Tutorial")
        local pp, mo = self.playerPanel, self.manaOrb
        Tutorial.anchor("player_panel", pp.x, pp.y, pp.width, pp.height)
        if mo.x and mo.radius then
            Tutorial.anchor("mana", mo.x - mo.radius, mo.y - mo.radius, mo.radius * 2, mo.radius * 2)
        end
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

return HudManager
