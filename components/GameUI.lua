-- components/GameUI.lua
local JokerSlot = require("components.JokerSlot")
local Config = require("src.core.Config")
local ParticleSystem = require("src.systems.ParticleSystem")
local HudManager = require("src.ui.HudManager")

local GameUI = {}
GameUI.__index = GameUI

function GameUI:new()
    local instance = setmetatable({}, GameUI)
    instance.visible = true
    instance.animationTime = 0

    instance.jokerSlots = {}
    instance:createJokerSlots()

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

function GameUI:update(dt, game)
    if not self.visible then return end

    self.animationTime = self.animationTime + dt

    for _, slot in ipairs(self.jokerSlots) do
        slot:update(dt)
    end

    self.hudManager:update(dt, game)
    ParticleSystem.Manager:update(dt)
end

function GameUI:updatePositions()
    local width = love.graphics.getWidth()

    local slotSize = Config.Utils.getResponsiveSize(0.06, 60, "width")
    local spacing = Config.Utils.getResponsiveSize(0.015, 15, "width")
    local totalWidth = (slotSize * Config.Game.MAX_JOKER_SLOTS) + (spacing * (Config.Game.MAX_JOKER_SLOTS - 1))
    local startX = (width - totalWidth) / 2
    local startY = Config.Utils.getResponsiveSize(0.08, 80, "height")

    for i, slot in ipairs(self.jokerSlots) do
        slot.x = startX + (i - 1) * (slotSize + spacing)
        slot.y = startY
        slot.size = slotSize
    end
end

function GameUI:draw(game)
    if not self.visible then return end

    self.hudManager:draw(game)
    ParticleSystem.Manager:draw()
end

function GameUI:show()
    self.visible = true
end

function GameUI:hide()
    self.visible = false
end

return GameUI
