-- components/AchievementsScreen.lua
-- Galeria de conquistas (F4 do gameplay-overhaul-v1): overlay com as 20
-- conquistas em 2 colunas — desbloqueadas em dourado, bloqueadas esmaecidas
-- (condição sempre visível, estilo StS: a conquista é um objetivo, não um
-- segredo). Abre pelo botão Conquistas do menu; ESC/clique-fora fecha.

local AchievementsScreen = {}
AchievementsScreen.__index = AchievementsScreen

local FontManager       = require("src.ui.FontManager")
local Palette           = require("src.ui.Palette")
local Panel9            = require("src.ui.Panel9")
local HintBar           = require("src.ui.HintBar")
local IconLoader        = require("src.ui.IconLoader")
local AchievementSystem = require("src.systems.AchievementSystem")
local Sfx               = require("src.systems.Sfx")

function AchievementsScreen:new()
    local instance = setmetatable({}, AchievementsScreen)
    instance.visible = false
    instance.onClose = nil
    instance.entries = {}
    return instance
end

function AchievementsScreen:show(onClose)
    self.visible = true
    self.onClose = onClose
    self.entries = AchievementSystem.all()
    Sfx.play("menuOpen")
end

function AchievementsScreen:hide()
    self.visible = false
    local cb = self.onClose
    self.onClose = nil
    Sfx.play("menuClose")
    if cb then cb() end
end

function AchievementsScreen:isVisible() return self.visible end
function AchievementsScreen:update(dt) end
function AchievementsScreen:resize() end

function AchievementsScreen:keypressed(key)
    if not self.visible then return false end
    if key == "escape" then self:hide() end
    return true
end

function AchievementsScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(880, math.floor(sw * 0.90))
    local ph = math.min(660, math.floor(sh * 0.90))
    return math.floor((sw - pw) / 2), math.floor((sh - ph) / 2), pw, ph
end

function AchievementsScreen:mousepressed(x, y, button)
    return self.visible
end

function AchievementsScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    local px, py, pw, ph = self:panelRect()
    if x < px or x > px + pw or y < py or y > py + ph then
        self:hide()
    end
    return true
end

function AchievementsScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    love.graphics.setColor(0.04, 0.03, 0.02, 0.78)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    -- Header: título + progresso n/total.
    local unlocked, total = AchievementSystem.countUnlocked()
    local tf = FontManager.getFont(18)
    love.graphics.setFont(tf)
    Palette.set(Palette.INK)
    love.graphics.print("CONQUISTAS", px + 36, py + 30)
    local cf = FontManager.getFont(11)
    love.graphics.setFont(cf)
    Palette.set(Palette.RUST)
    local progress = unlocked .. " / " .. total
    love.graphics.print(progress,
        px + pw - 36 - cf:getWidth(progress), py + 34)

    -- Grid 2 colunas.
    local cols = 2
    local gutter = 18
    local rowH = 50
    local innerX = px + 30
    local innerW = pw - 60
    local colW = math.floor((innerW - gutter) / cols)
    local topY = py + 68

    local nameFont = FontManager.getFont(11)
    local descFont = FontManager.getFont(8)

    for i, e in ipairs(self.entries) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = innerX + col * (colW + gutter)
        local y = topY + row * rowH
        if y + rowH <= py + ph - 40 then
            -- fundo da célula (desbloqueada = leve tint dourado)
            if e.unlocked then
                love.graphics.setColor(0.28, 0.20, 0.08, 0.55)
            else
                love.graphics.setColor(0, 0, 0, 0.32)
            end
            love.graphics.rectangle("fill", x, y, colW, rowH - 6, 4, 4)
            if e.unlocked then
                Palette.set(Palette.AGED_GOLD)
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", x, y, colW, rowH - 6, 4, 4)
            end

            -- ícone (esmaecido quando bloqueada)
            local icon = IconLoader.get(e.icon or "star")
            if icon and icon.draw and icon.size then
                local sc = 28 / icon.size.w
                if e.unlocked then
                    love.graphics.setColor(1, 1, 1, 1)
                else
                    love.graphics.setColor(0.45, 0.42, 0.38, 0.8)
                end
                icon.draw(x + 8, y + math.floor((rowH - 6 - 28) / 2), sc)
            end

            -- name/desc com FIT na célula (design system Jul/2026): textos
            -- longos vazavam pra coluna vizinha e pra fora do painel.
            local TextFit = require("src.ui.TextFit")
            local cellTextW = colW - 44 - 8
            if e.unlocked then
                Palette.set(Palette.AGED_GOLD_LIGHT)
            else
                Palette.set(Palette.PARCHMENT_DARK)
            end
            TextFit.print(e.name, x + 44, y + 7, { size = 11, maxW = cellTextW, minSize = 9 })

            if e.unlocked then
                Palette.set(Palette.PARCHMENT)
            else
                -- Condição SEMPRE legível (StS: conquista é objetivo, não
                -- segredo) — só menos brilhante que as desbloqueadas.
                love.graphics.setColor(0.72, 0.66, 0.55, 1)
            end
            TextFit.print(e.desc, x + 44, y + 25, { size = 8, maxW = cellTextW })
        end
    end

    HintBar.draw("ESC ou clique fora fecha")
    love.graphics.setColor(1, 1, 1, 1)
end

return AchievementsScreen
