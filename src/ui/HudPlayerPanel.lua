local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local Config = require("src.core.Config")
local ImageCache = require("src.ui.ImageCache")
local IconLoader = require("src.ui.IconLoader")
local ValueEasing = require("src.ui.ValueEasing")

local HudPlayerPanel = {}
HudPlayerPanel.__index = HudPlayerPanel

local PANEL_W, PANEL_H = 200, 72
local PAD = 10
local BAR_H = 8
local HP_BAR_COLOR = { 0.75, 0.18, 0.20, 1 }
local HP_BAR_LOW   = { 0.85, 0.45, 0.10, 1 }

function HudPlayerPanel:new()
    local instance = setmetatable({}, HudPlayerPanel)
    instance.x = 0
    instance.y = 0
    instance.width = PANEL_W
    instance.height = PANEL_H
    instance.animTime = 0
    instance.armorIcon = ImageCache.get("assets/icons/armor.png")
    instance.lastHp = nil
    instance.damageFlash = 0
    instance.disp = {}
    return instance
end

function HudPlayerPanel:update(dt, player)
    self.animTime = self.animTime + dt
    if self.damageFlash > 0 then
        self.damageFlash = math.max(0, self.damageFlash - dt * 3)
    end
    if player then
        ValueEasing.tick(self.disp, "health", player.health or 0, dt, 9)
        ValueEasing.tick(self.disp, "armor", player.armor or 0, dt, 12)
    end
end

function HudPlayerPanel:updatePosition()
    local sh = love.graphics.getHeight()
    self.width = PANEL_W
    self.height = PANEL_H
    self.x = Config.Utils.getResponsiveSize(0.015, 14, "width")
    self.y = sh - self.height - Config.Utils.getResponsiveSize(0.02, 18, "height")
end

local function setColor(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

function HudPlayerPanel:draw(player)
    if not player then return end

    if self.lastHp and player.health < self.lastHp then
        self.damageFlash = 1
    end
    self.lastHp = player.health

    local x, y, w, h = self.x, self.y, self.width, self.height

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + 2, y + 3, w, h, 4, 4)

    setColor(Palette.PARCHMENT_DARK, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    if self.damageFlash > 0 then
        love.graphics.setColor(0.8, 0.15, 0.15, self.damageFlash * 0.35)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    end

    love.graphics.setLineWidth(1)
    setColor(Palette.INK, 1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    setColor(Palette.AGED_GOLD_DARK, 0.8)
    love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4, 3, 3)

    local bodyY = y + 20
    setColor(Palette.AGED_GOLD_DARK, 0.6)
    love.graphics.line(x + PAD, bodyY - 4, x + w - PAD, bodyY - 4)

    local labelFont = FontManager.getResponsiveFont(0.018, 11)
    love.graphics.setFont(labelFont)
    setColor(Palette.AGED_GOLD_LIGHT, 0.95)
    love.graphics.print(
        require("src.i18n.I18n").t("hud.hero", nil, "HEROI"), x + PAD, y + 4)

    local hp = player.health or 0
    local hpDisp = math.floor((self.disp.health or hp) + 0.001)
    local maxHp = player.maxHealth or 100
    local hpPct = math.max(0, math.min(1, hpDisp / maxHp))
    local barColor = hpPct < 0.3 and HP_BAR_LOW or HP_BAR_COLOR

    local hpFont = FontManager.getResponsiveFont(0.035, 24)
    love.graphics.setFont(hpFont)
    local hpText = tostring(hpDisp)
    local maxText = "/" .. maxHp
    local hpTextW = hpFont:getWidth(hpText)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(hpText, x + PAD + 1, bodyY + 1)
    setColor(Palette.PARCHMENT_LIGHT, 1)
    love.graphics.print(hpText, x + PAD, bodyY)
    local maxFont = FontManager.getResponsiveFont(0.018, 12)
    love.graphics.setFont(maxFont)
    love.graphics.setColor(0.75, 0.70, 0.60, 0.85)
    love.graphics.print(maxText, x + PAD + hpTextW + 2, bodyY + 10)

    local barX = x + PAD
    local barY = y + h - PAD - BAR_H
    local barW = w - 2 * PAD - 50
    love.graphics.setColor(0.12, 0.08, 0.05, 0.85)
    love.graphics.rectangle("fill", barX, barY, barW, BAR_H, 2, 2)
    setColor(barColor, 1)
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, BAR_H, 2, 2)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, 2, 2, 2)
    setColor(Palette.INK, 0.8)
    love.graphics.rectangle("line", barX, barY, barW, BAR_H, 2, 2)

    local armor = math.floor((self.disp.armor or player.armor or 0) + 0.001)
    if armor > 0 then
        local badgeCx = x + w - PAD - 22
        local badgeCy = y + h / 2 + 4
        local targetSize = 44

        local capMax = player.maxArmor or 0
        local nearCap = capMax > 0 and armor >= capMax * 0.7
        local atCap = capMax > 0 and armor >= capMax

        local pulse = 0.75 + math.sin(self.animTime * 3) * 0.25
        local halo = atCap and Palette.AGED_GOLD or Palette.STEEL_LIGHT
        love.graphics.setColor(halo[1], halo[2], halo[3], (atCap and 0.45 or 0.30) * pulse)
        love.graphics.circle("fill", badgeCx, badgeCy, targetSize / 2 + 4)

        local shield = IconLoader.get("armor_shield")
        if shield and shield.draw then
            local iconH = (shield.size and shield.size.h) or 64
            local iconW = (shield.size and shield.size.w) or 64
            local scale = IconLoader.computeScale(iconH, targetSize)
            local rm = _G.gameSettings and _G.gameSettings.reducedMotion
            local bob = rm and 0 or math.floor(math.sin(self.animTime * 1.2) * 1)
            local ix = math.floor(badgeCx - (iconW * scale) / 2)
            local iy = math.floor(badgeCy - (iconH * scale) / 2) + bob
            shield.draw(ix, iy, scale)
        else
            setColor(Palette.STEEL, 1)
            love.graphics.circle("fill", badgeCx, badgeCy, targetSize / 2)
            setColor(Palette.INK, 1)
            love.graphics.circle("line", badgeCx, badgeCy, targetSize / 2)
        end

        local armorFont = FontManager.getResponsiveFont(0.028, 20)
        love.graphics.setFont(armorFont)
        local atxt = tostring(armor)
        local atw = armorFont:getWidth(atxt)
        local ath = armorFont:getHeight()
        local tx = badgeCx - atw / 2
        local ty = badgeCy - ath / 2
        FontManager.drawWithOutline(atxt, tx, ty, { 1, 1, 1, 1 }, 0.9)

        if nearCap then
            local capFont = FontManager.getResponsiveFont(0.018, 13)
            love.graphics.setFont(capFont)
            local ctxt = "/" .. tostring(capMax)
            local ctw = capFont:getWidth(ctxt)
            FontManager.drawWithOutline(ctxt,
                badgeCx - ctw / 2, badgeCy + ath / 2 - 2,
                atCap and Palette.AGED_GOLD_LIGHT or { 0.85, 0.85, 0.85, 1 }, 0.9)
            love.graphics.setFont(armorFont)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local StatusTooltip = require("src.ui.StatusTooltip")
local CLASS_CHIP_ICONS = { warrior = "sword_great", mage = "orb", rogue = "dagger" }

function HudPlayerPanel:drawPassiveChip(game)
    if not game or not game.selectedClass then return end
    local icon = IconLoader.get(CLASS_CHIP_ICONS[game.selectedClass] or "star")
    local chip = 30
    local cx = self.x + self.width + 8
    local cy = self.y + self.height - chip

    local glow = 0
    if game._passiveFlashT then
        local dt = love.timer.getTime() - game._passiveFlashT
        if dt < 1.0 then glow = 1.0 - dt end
    end

    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", cx + 2, cy + 2, chip, chip, 5, 5)
    setColor(Palette.PARCHMENT_DARK, 0.95)
    love.graphics.rectangle("fill", cx, cy, chip, chip, 5, 5)
    if glow > 0 then
        love.graphics.setColor(1, 0.85, 0.30, 0.45 * glow)
        love.graphics.rectangle("fill", cx, cy, chip, chip, 5, 5)
    end
    setColor(glow > 0 and Palette.AGED_GOLD_LIGHT or Palette.AGED_GOLD, 1)
    love.graphics.setLineWidth(glow > 0 and 2 or 1)
    love.graphics.rectangle("line", cx, cy, chip, chip, 5, 5)

    if icon and icon.draw and icon.size then
        local s = 24 / icon.size.w
        love.graphics.setColor(1, 1, 1, 1)
        icon.draw(math.floor(cx + (chip - icon.size.w * s) / 2),
            math.floor(cy + (chip - (icon.size.h or icon.size.w) * s) / 2), s)
    end

    require("src.ui.NavCursor").target("hud:passive", cx, cy, chip, chip)
    local mx, my = love.mouse.getPosition()
    if mx >= cx and mx <= cx + chip and my >= cy and my <= cy + chip then
        StatusTooltip.show("passive_" .. game.selectedClass, mx, my)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return HudPlayerPanel
