-- components/EventScreen.lua
-- Narrativa: titulo + corpo + 2-4 opcoes. Executa option.apply(game) e fecha.
--
-- F4 do UI Overhaul (docs/plan/ui-ux-overhaul-v1.md): cena real de fundo
-- (path_event), painel grimório (Panel9) com ILUSTRAÇÃO do evento
-- (assets/sprites/ui/event_<id>.png, geradas via PixelLab) e opções dentro
-- do painel — no lugar do miolo vazio da tela antiga (nota D+ no
-- levantamento).

local EventScreen = {}
EventScreen.__index = EventScreen

local FontManager      = require("src.ui.FontManager")
local Palette          = require("src.ui.Palette")
local Button           = require("components.Button")
local Panel9           = require("src.ui.Panel9")
local SceneBackground  = require("src.ui.SceneBackground")
local HintBar          = require("src.ui.HintBar")

local illustrationCache = {}

local function getIllustration(eventId)
    if not eventId then return nil end
    if illustrationCache[eventId] ~= nil then
        return illustrationCache[eventId] or nil
    end
    local path = "assets/sprites/ui/event_" .. eventId .. ".png"
    if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            illustrationCache[eventId] = img
            return img
        end
    end
    illustrationCache[eventId] = false
    return nil
end

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

function EventScreen:resize()
    if self.visible then self:buildButtons() end
end

-- Geometria do painel (compartilhada entre build e draw).
function EventScreen:panelRect()
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local pw = math.min(620, math.floor(sw * 0.78))
    local ph = math.min(600, math.floor(sh * 0.88))
    local px = math.floor((sw - pw) / 2)
    local py = math.floor((sh - ph) / 2)
    return px, py, pw, ph
end

function EventScreen:buildButtons()
    self.buttons = {}
    if not self.event then return end
    local px, py, pw, ph = self:panelRect()
    local opts = self.event.options or {}
    local btnW = pw - 120
    local btnH = 46
    local spacing = 10
    -- opções ancoradas no RODAPÉ do painel (ilustração+texto ficam em cima)
    local startY = py + ph - 40 - (#opts) * (btnH + spacing)
    for i, opt in ipairs(opts) do
        local y = startY + (i - 1) * (btnH + spacing)
        local x = math.floor(px + (pw - btnW) / 2)
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
        local btn = Button:new(x, y, btnW, btnH, opt.label, onClick, nil, 10)
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

    -- Cena real de encruzilhada misteriosa (cover-fit + véu)
    local drawn = SceneBackground.draw("path_event", sw, sh, 0.40)
    if not drawn then
        love.graphics.setColor(0.06, 0.05, 0.07, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
    love.graphics.setColor(1, 1, 1, 1)

    local px, py, pw, ph = self:panelRect()
    Panel9.draw("panel_main", px, py, pw, ph)

    -- Titulo em INK sobre o pergaminho
    local titleFont = FontManager.getFont(20)
    love.graphics.setFont(titleFont)
    Palette.set(Palette.INK)
    local title = (self.event and self.event.title) or ""
    love.graphics.print(title,
        math.floor(px + pw / 2 - titleFont:getWidth(title) / 2), py + 40)

    -- Área útil entre o título e as opções (pro conteúdo centralizar)
    local opts = (self.event and self.event.options) or {}
    local buttonsTop = py + ph - 40 - (#opts) * (46 + 10)
    local areaTop = py + 80
    local areaH = buttonsTop - areaTop - 16

    -- ILUSTRAÇÃO do evento (moldura interna escura; 128×96 @2x = 256×192)
    local img = getIllustration(self.event and self.event.id)
    local bodyFont = FontManager.getFont(10)
    local bodyText = (self.event and self.event.body) or ""
    local _, bodyLines = bodyFont:getWrap(bodyText, pw - 120)
    local bodyH = #bodyLines * bodyFont:getHeight() * 1.1

    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local s = math.min(2, (pw - 200) / iw)
        local dw, dh = iw * s, ih * s
        -- centraliza o bloco ilustração+texto na área útil
        local blockH = dh + 28 + bodyH
        local contentY = math.floor(areaTop + math.max(0, (areaH - blockH) / 2))
        local ix = math.floor(px + pw / 2 - dw / 2)
        Panel9.draw("panel_inner", ix - 10, contentY - 8, dw + 20, dh + 16, {
            fill = { 0.10, 0.08, 0.06, 0.95 },
        })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(img, ix, contentY, 0, s, s)
        love.graphics.setFont(bodyFont)
        Palette.set(Palette.INK)
        love.graphics.printf(bodyText, px + 60, contentY + dh + 28,
            pw - 120, "center")
    else
        -- sem ilustração: corpo CENTRALIZADO verticalmente (a tela antiga
        -- deixava um vazio enorme de pergaminho)
        local contentY = math.floor(areaTop + math.max(0, (areaH - bodyH) / 2))
        love.graphics.setFont(bodyFont)
        Palette.set(Palette.INK)
        love.graphics.printf(bodyText, px + 60, contentY, pw - 120, "center")
    end

    -- Botoes (opções)
    for _, b in ipairs(self.buttons) do b:draw() end

    -- Feedback apos escolha
    if self.resultText then
        local rf = FontManager.getFont(12)
        love.graphics.setFont(rf)
        Palette.set(Palette.MOSS)
        love.graphics.print(self.resultText,
            math.floor(px + pw / 2 - rf:getWidth(self.resultText) / 2),
            py + ph - 90)
    end

    HintBar.draw("Clique numa opcao OU pressione 1-" ..
        math.max(1, #(self.event and self.event.options or {})) ..
        " · a escolha e definitiva")

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
