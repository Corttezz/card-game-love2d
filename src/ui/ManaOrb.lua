local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local Config = require("src.core.Config")
local ValueEasing = require("src.ui.ValueEasing")

local ManaOrb = {}
ManaOrb.__index = ManaOrb

local RADIUS = 44

function ManaOrb:new()
    local instance = setmetatable({}, ManaOrb)
    instance.x = 0
    instance.y = 0
    instance.radius = RADIUS
    instance.animTime = 0
    instance.lastMana = nil
    instance.spendFlash = 0
    instance.gainFlash = 0
    instance.disp = {}
    return instance
end

function ManaOrb:update(dt, player)
    self.animTime = self.animTime + dt
    if self.spendFlash > 0 then self.spendFlash = math.max(0, self.spendFlash - dt * 4) end
    if self.gainFlash > 0 then self.gainFlash = math.max(0, self.gainFlash - dt * 2) end
    if player then
        ValueEasing.tick(self.disp, "mana", player.mana or 0, dt, 12)
    end
end

function ManaOrb:updatePosition()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    self.x = sw - Config.Utils.getResponsiveSize(0.05, 50, "width")
    self.y = sh - Config.Utils.getResponsiveSize(0.06, 55, "height")
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

function ManaOrb:draw(player)
    if not player then return end
    local actual = player.mana or 0
    local cur = self.disp.mana or actual
    local maxMana = player.maxMana or 3

    if self.lastMana ~= nil then
        if actual < self.lastMana then
            self.spendFlash = 1
        elseif actual > self.lastMana then
            self.gainFlash = 1
        end
    end
    self.lastMana = actual

    local cx, cy = self.x, self.y
    local r = self.radius

    do
        local mx, my = love.mouse.getPosition()
        local dx, dy = mx - cx, my - cy
        if dx * dx + dy * dy <= r * r then
            require("src.ui.StatusTooltip").show("mana", mx, my,
                { stacks = math.floor(actual), duration = maxMana })
        end
    end

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.ellipse("fill", cx, cy + r + 2, r * 0.8, 4)

    local availability = (cur > 0) and 1 or 0.35
    local pulse = 0.75 + math.sin(self.animTime * 2.5) * 0.25
    love.graphics.setColor(0.30, 0.55, 0.95, 0.25 * pulse * availability)
    love.graphics.circle("fill", cx, cy, r + 8)

    if self.spendFlash > 0 then
        love.graphics.setColor(0.9, 0.2, 0.2, self.spendFlash * 0.5)
        love.graphics.circle("fill", cx, cy, r + 4)
    elseif self.gainFlash > 0 then
        love.graphics.setColor(0.4, 0.9, 1.0, self.gainFlash * 0.35)
        love.graphics.circle("fill", cx, cy, r + 4)
    end

    love.graphics.setColor(0.05, 0.08, 0.18, 0.98)
    love.graphics.circle("fill", cx, cy, r)

    local manaPct = math.max(0, math.min(1, cur / maxMana))
    if manaPct > 0 then
        love.graphics.setColor(0.20, 0.42, 0.92, 0.90 * availability)
        love.graphics.circle("fill", cx, cy, r * (0.55 + 0.25 * manaPct))

        love.graphics.setColor(0.75, 0.90, 1.0, 0.55 * availability)
        love.graphics.circle("fill", cx - r * 0.25, cy - r * 0.35, r * 0.18)
    end

    setColor(Palette.AGED_GOLD_DARK, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", cx, cy, r)
    setColor(Palette.AGED_GOLD, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, r - 2)

    setColor(Palette.INK, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, r + 2)
    love.graphics.setLineWidth(1)

    local bigFont = FontManager.getResponsiveFont(0.04, 26)
    local smallFont = FontManager.getResponsiveFont(0.025, 14)

    local curTxt = tostring(math.floor(cur + 0.001))
    love.graphics.setFont(bigFont)
    local bw = bigFont:getWidth(curTxt)
    local bh = bigFont:getHeight()

    local maxTxt = "/" .. maxMana
    love.graphics.setFont(smallFont)
    local sw2 = smallFont:getWidth(maxTxt)
    local sh2 = smallFont:getHeight()

    local gap = 3
    local blockH = bh + gap + sh2
    local topY = math.floor(cy - blockH / 2)

    love.graphics.setFont(bigFont)
    local numTx = math.floor(cx - bw / 2)
    FontManager.drawWithOutline(curTxt, numTx, topY, { 1, 1, 1, 1 }, 0.9, true)

    love.graphics.setFont(smallFont)
    local maxY = topY + bh + gap
    local maxTx = math.floor(cx - sw2 / 2)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.print(maxTxt, maxTx + 1, maxY + 1)
    love.graphics.setColor(0.80, 0.92, 1.0, 1)
    love.graphics.print(maxTxt, maxTx, maxY)

    love.graphics.setColor(1, 1, 1, 1)
end

return ManaOrb
