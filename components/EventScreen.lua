-- components/EventScreen.lua
-- Narrativa: titulo + corpo + 2-4 opcoes. Executa option.apply(game) e fecha.

local EventScreen = {}
EventScreen.__index = EventScreen

local FontManager      = require("src.ui.FontManager")
local Palette          = require("src.ui.Palette")
local Button           = require("components.Button")
local BackgroundLoader = require("src.ui.card.BackgroundLoader")

function EventScreen:new()
    local instance = setmetatable({}, EventScreen)
    instance.visible = false
    instance.event = nil
    instance.game = nil
    instance.onClose = nil
    instance.buttons = {}
    instance.resultText = nil
    instance.resultTimer = 0
    return instance
end

function EventScreen:show(event, game, onClose)
    self.visible = true
    self.event = event
    self.game = game
    self.onClose = onClose
    self.resultText = nil
    self.resultTimer = 0
    self:buildButtons()
end

function EventScreen:hide()
    self.visible = false
    self.event = nil
    self.buttons = {}
end

function EventScreen:isVisible() return self.visible end

function EventScreen:buildButtons()
    self.buttons = {}
    if not self.event then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local opts = self.event.options or {}
    local btnW = math.min(420, math.floor(sw * 0.7))
    local btnH = 52
    local spacing = 12
    local totalH = (#opts) * (btnH + spacing)
    local startY = math.floor(sh * 0.55)
    for i, opt in ipairs(opts) do
        local y = startY + (i - 1) * (btnH + spacing)
        local x = math.floor((sw - btnW) / 2)
        local onClick = function()
            local feedback
            if opt.apply then
                local ok, res = pcall(opt.apply, self.game)
                if ok then feedback = res end
            end
            self.resultText = feedback or "Voce segue em frente."
            self.resultTimer = 1.8
            -- Limpa botoes enquanto feedback e exibido (impede duplo-click)
            self.buttons = {}
        end
        local btn = Button:new(x, y, btnW, btnH, opt.label, onClick)
        table.insert(self.buttons, btn)
    end
end

function EventScreen:update(dt)
    if not self.visible then return end
    for _, b in ipairs(self.buttons) do b:update(dt) end
    if self.resultTimer > 0 then
        self.resultTimer = self.resultTimer - dt
        if self.resultTimer <= 0 then
            local cb = self.onClose
            self:hide()
            if cb then cb() end
        end
    end
end

function EventScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Dim background + overlay arcano pra evento ter atmosfera misteriosa
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local tex = BackgroundLoader.get("arcane")
    if tex then
        love.graphics.setColor(0.6, 0.4, 0.9, 0.12)
        local tw, th = tex:getWidth(), tex:getHeight()
        love.graphics.draw(tex, love.graphics.newQuad(0, 0, sw, sh, tw, th), 0, 0)
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- Painel central (pergaminho)
    local panelW = math.min(640, sw * 0.8)
    local panelH = math.min(560, sh * 0.85)
    local px = math.floor((sw - panelW) / 2)
    local py = math.floor((sh - panelH) / 2)
    love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
                           Palette.PARCHMENT_DARK[3], 0.95)
    love.graphics.rectangle("fill", px, py, panelW, panelH, 6, 6)
    love.graphics.setColor(Palette.INK)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, panelW, panelH, 6, 6)
    love.graphics.setColor(Palette.AGED_GOLD)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", px + 4, py + 4, panelW - 8, panelH - 8, 4, 4)

    -- Titulo
    local titleFont = FontManager.getResponsiveFont(0.035, 24)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    local title = (self.event and self.event.title) or ""
    local tw = titleFont:getWidth(title)
    love.graphics.print(title, math.floor((sw - tw) / 2), py + 22)

    -- Corpo
    local bodyFont = FontManager.getResponsiveFont(0.022, 16)
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2],
                           Palette.PARCHMENT_LIGHT[3], 1)
    local bodyY = py + 70
    love.graphics.printf((self.event and self.event.body) or "",
        px + 30, bodyY, panelW - 60, "center")

    -- Botoes
    for _, b in ipairs(self.buttons) do b:draw() end

    -- Feedback apos escolha
    if self.resultText then
        local rf = FontManager.getResponsiveFont(0.026, 18)
        love.graphics.setFont(rf)
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
        local rw = rf:getWidth(self.resultText)
        love.graphics.print(self.resultText,
            math.floor((sw - rw) / 2), math.floor(sh * 0.82))
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function EventScreen:mousepressed(x, y, button)
    if not self.visible then return false end
    -- Button trata via onClick no update/release; delegamos
    return true
end

function EventScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    for _, b in ipairs(self.buttons) do
        if b.hover and not b.disabled then
            b.onClick()
            return true
        end
    end
    return false
end

function EventScreen:keypressed(key)
    if not self.visible then return false end
    if key == "1" or key == "2" or key == "3" or key == "4" then
        local i = tonumber(key)
        local btn = self.buttons[i]
        if btn and btn.onClick then btn.onClick() end
        return true
    end
    return false
end

return EventScreen
