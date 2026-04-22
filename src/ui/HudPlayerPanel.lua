-- src/ui/HudPlayerPanel.lua
-- Painel minimal estilo STS/Balatro: HP grande + barra fina + badge de armor.
-- Sem gradientes de 20 passos, sem glass overlay, sem 3 layers de glow.
-- Paleta sepia/pergaminho consistente com o resto do jogo (Palette.lua).

local FontManager = require("src.ui.FontManager")
local Palette = require("src.ui.Palette")
local Config = require("src.core.Config")
local ImageCache = require("src.ui.ImageCache")
local IconLoader = require("src.ui.IconLoader")

local HudPlayerPanel = {}
HudPlayerPanel.__index = HudPlayerPanel

local PANEL_W, PANEL_H = 200, 72
local PAD = 10
local BAR_H = 8
local HP_BAR_COLOR = { 0.75, 0.18, 0.20, 1 } -- vermelho sangue mais cru
local HP_BAR_LOW   = { 0.85, 0.45, 0.10, 1 } -- laranja quando HP < 30%

function HudPlayerPanel:new()
    local instance = setmetatable({}, HudPlayerPanel)
    instance.x = 0
    instance.y = 0
    instance.width = PANEL_W
    instance.height = PANEL_H
    instance.animTime = 0
    instance.armorIcon = ImageCache.get("assets/icons/armor.png")
    instance.lastHp = nil
    instance.damageFlash = 0 -- 0..1, decai em update
    return instance
end

function HudPlayerPanel:update(dt)
    self.animTime = self.animTime + dt
    if self.damageFlash > 0 then
        self.damageFlash = math.max(0, self.damageFlash - dt * 3)
    end
end

function HudPlayerPanel:updatePosition()
    local sw = love.graphics.getWidth()
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

    -- Dispara flash quando HP cai
    if self.lastHp and player.health < self.lastHp then
        self.damageFlash = 1
    end
    self.lastHp = player.health

    local x, y, w, h = self.x, self.y, self.width, self.height

    -- Sombra suave (1 passo, sem exagero)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.rectangle("fill", x + 2, y + 3, w, h, 4, 4)

    -- Fundo pergaminho escuro flat
    setColor(Palette.PARCHMENT_DARK, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    -- Flash vermelho quando toma dano
    if self.damageFlash > 0 then
        love.graphics.setColor(0.8, 0.15, 0.15, self.damageFlash * 0.35)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    end

    -- Borda tinta (outline)
    love.graphics.setLineWidth(1)
    setColor(Palette.INK, 1)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    -- Borda interna dourada fina
    setColor(Palette.AGED_GOLD_DARK, 0.8)
    love.graphics.rectangle("line", x + 2, y + 2, w - 4, h - 4, 3, 3)

    -- Divisor horizontal
    local bodyY = y + 20
    setColor(Palette.AGED_GOLD_DARK, 0.6)
    love.graphics.line(x + PAD, bodyY - 4, x + w - PAD, bodyY - 4)

    -- ===== HEADER: "HEROI" label =====
    local labelFont = FontManager.getResponsiveFont(0.018, 11)
    love.graphics.setFont(labelFont)
    setColor(Palette.AGED_GOLD_LIGHT, 0.95)
    love.graphics.print("HERÓI", x + PAD, y + 4)

    -- ===== HP: número grande + barra =====
    local hp = player.health or 0
    local maxHp = player.maxHealth or 100
    local hpPct = math.max(0, math.min(1, hp / maxHp))
    local barColor = hpPct < 0.3 and HP_BAR_LOW or HP_BAR_COLOR

    -- Número HP grande (estilo Balatro)
    local hpFont = FontManager.getResponsiveFont(0.035, 24)
    love.graphics.setFont(hpFont)
    local hpText = tostring(hp)
    local maxText = "/" .. maxHp
    local hpTextW = hpFont:getWidth(hpText)
    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(hpText, x + PAD + 1, bodyY + 1)
    -- Número principal
    setColor(Palette.PARCHMENT_LIGHT, 1)
    love.graphics.print(hpText, x + PAD, bodyY)
    -- "/max" menor cinza
    local maxFont = FontManager.getResponsiveFont(0.018, 12)
    love.graphics.setFont(maxFont)
    love.graphics.setColor(0.75, 0.70, 0.60, 0.85)
    love.graphics.print(maxText, x + PAD + hpTextW + 2, bodyY + 10)

    -- Barra HP fina abaixo do número
    local barX = x + PAD
    local barY = y + h - PAD - BAR_H
    local barW = w - 2 * PAD - 50 -- reserva 50px à direita pro badge de armor
    -- Track escura
    love.graphics.setColor(0.12, 0.08, 0.05, 0.85)
    love.graphics.rectangle("fill", barX, barY, barW, BAR_H, 2, 2)
    -- Fill HP
    setColor(barColor, 1)
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, BAR_H, 2, 2)
    -- Highlight sutil no topo da barra
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.rectangle("fill", barX, barY, barW * hpPct, 2, 2, 2)
    -- Outline tinta
    setColor(Palette.INK, 0.8)
    love.graphics.rectangle("line", barX, barY, barW, BAR_H, 2, 2)

    -- ===== ARMOR BADGE (só aparece quando > 0) =====
    -- Usa o shield PNG custom gerado via PixelLab (assets/sprites/icons/armor_shield.png).
    -- Número de armor fica centralizado no shield, com outline preto pra legibilidade.
    local armor = player.armor or 0
    if armor > 0 then
        local badgeCx = x + w - PAD - 22
        local badgeCy = y + h / 2 + 4
        local targetSize = 44 -- tamanho do shield na tela

        -- Halo steel pulsante atrás (feedback de "blocking", mantém do design antigo)
        local pulse = 0.75 + math.sin(self.animTime * 3) * 0.25
        love.graphics.setColor(Palette.STEEL_LIGHT[1], Palette.STEEL_LIGHT[2], Palette.STEEL_LIGHT[3], 0.30 * pulse)
        love.graphics.circle("fill", badgeCx, badgeCy, targetSize / 2 + 4)

        -- Shield PNG custom
        local shield = IconLoader.get("armor_shield")
        if shield and shield.draw then
            local iconH = (shield.size and shield.size.h) or 64
            local iconW = (shield.size and shield.size.w) or 64
            local scale = IconLoader.computeScale(iconH, targetSize)
            local ix = math.floor(badgeCx - (iconW * scale) / 2)
            local iy = math.floor(badgeCy - (iconH * scale) / 2)
            shield.draw(ix, iy, scale)
        else
            -- Fallback: disco steel antigo (caso o PNG não carregue)
            setColor(Palette.STEEL, 1)
            love.graphics.circle("fill", badgeCx, badgeCy, targetSize / 2)
            setColor(Palette.INK, 1)
            love.graphics.circle("line", badgeCx, badgeCy, targetSize / 2)
        end

        -- Número armor centralizado sobre o shield, outline preto pra ler sobre qualquer cor
        local armorFont = FontManager.getResponsiveFont(0.028, 20)
        love.graphics.setFont(armorFont)
        local atxt = tostring(armor)
        local atw = armorFont:getWidth(atxt)
        local ath = armorFont:getHeight()
        local tx = badgeCx - atw / 2
        local ty = badgeCy - ath / 2
        FontManager.drawWithOutline(atxt, tx, ty, { 1, 1, 1, 1 }, 0.9)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return HudPlayerPanel
