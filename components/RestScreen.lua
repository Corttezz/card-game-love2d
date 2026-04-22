-- components/RestScreen.lua
-- Descanso: escolhe entre curar 30% maxHP ou forjar (upgrade) uma carta do deck.
-- Forge: marca card com `upgraded` na run (runManager.currentRun.upgraded[cardId]++).

local RestScreen = {}
RestScreen.__index = RestScreen

local FontManager      = require("src.ui.FontManager")
local Palette          = require("src.ui.Palette")
local Button           = require("components.Button")
local BackgroundLoader = require("src.ui.card.BackgroundLoader")
local Sfx              = require("src.systems.Sfx")

function RestScreen:new()
    local instance = setmetatable({}, RestScreen)
    instance.visible = false
    instance.game = nil
    instance.onClose = nil
    instance.mode = "choose" -- "choose" | "forge"
    instance.buttons = {}
    instance.cardList = {}
    instance.resultText = nil
    instance.resultTimer = 0
    return instance
end

function RestScreen:show(game, onClose)
    self.visible = true
    self.game = game
    self.onClose = onClose
    self.mode = "choose"
    self.resultText = nil
    self.resultTimer = 0
    self:buildChooseButtons()
end

function RestScreen:hide()
    self.visible = false
    self.buttons = {}
    self.cardList = {}
end

function RestScreen:isVisible() return self.visible end

function RestScreen:buildChooseButtons()
    self.buttons = {}
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local btnW = 260
    local btnH = 56
    local y = math.floor(sh * 0.55)
    local spacing = 24

    local healBtn = Button:new(
        math.floor(sw / 2 - btnW - spacing / 2), y, btnW, btnH,
        "Descansar (+30% HP)",
        function() self:doHeal() end
    )
    local forgeBtn = Button:new(
        math.floor(sw / 2 + spacing / 2), y, btnW, btnH,
        "Forjar Carta",
        function() self:enterForgeMode() end
    )
    table.insert(self.buttons, healBtn)
    table.insert(self.buttons, forgeBtn)
end

function RestScreen:doHeal()
    local amt = math.floor(self.game.player.maxHealth * 0.30)
    self.game.player:heal(amt)
    self.resultText = "Curou " .. amt .. " HP."
    self.resultTimer = 1.5
    self.buttons = {}
    Sfx.play("restComplete")
end

function RestScreen:enterForgeMode()
    self.mode = "forge"
    self.buttons = {}
    self.cardList = {}
    local run = self.game.runManager.currentRun
    if not run then return end
    local seen = {}
    for _, id in ipairs(run.currentDeck) do
        if not seen[id] then
            seen[id] = true
            table.insert(self.cardList, id)
        end
    end

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local perRow = 4
    local btnW = math.floor((sw * 0.8) / perRow) - 10
    local btnH = 44
    local startX = math.floor(sw * 0.1)
    local startY = math.floor(sh * 0.35)

    for i, cardId in ipairs(self.cardList) do
        local col = (i - 1) % perRow
        local row = math.floor((i - 1) / perRow)
        local x = startX + col * (btnW + 10)
        local y = startY + row * (btnH + 8)
        local upgraded = run.upgraded and run.upgraded[cardId] or 0
        local label = cardId .. (upgraded > 0 and (" +" .. upgraded) or "")
        local btn = Button:new(x, y, btnW, btnH, label, function()
            self:doForge(cardId)
        end)
        table.insert(self.buttons, btn)
    end

    -- Botao voltar
    local back = Button:new(
        math.floor(sw / 2 - 80), math.floor(sh * 0.85), 160, 44, "Voltar",
        function() self:show(self.game, self.onClose) end
    )
    table.insert(self.buttons, back)
end

function RestScreen:doForge(cardId)
    local run = self.game.runManager.currentRun
    if not run then return end
    run.upgraded = run.upgraded or {}
    run.upgraded[cardId] = (run.upgraded[cardId] or 0) + 1
    self.resultText = "Forjou: " .. cardId .. " (+" .. run.upgraded[cardId] .. ")"
    self.resultTimer = 1.5
    self.buttons = {}
end

function RestScreen:update(dt)
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

function RestScreen:draw()
    if not self.visible then return end
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()

    -- Dimming mais suave pro gameplay atras aparecer como ambiente.
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Overlay quente de acampamento (tint avermelhado de fogueira).
    local tex = BackgroundLoader.get("fire")
    if tex then
        love.graphics.setColor(1, 0.6, 0.3, 0.10)
        local tw, th = tex:getWidth(), tex:getHeight()
        love.graphics.draw(tex, love.graphics.newQuad(0, 0, sw, sh, tw, th), 0, 0)
    end
    love.graphics.setColor(1, 1, 1, 1)

    local titleFont = FontManager.getResponsiveFont(0.045, 32)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
    local title = self.mode == "forge" and "Forjar — escolha uma carta" or "Acampamento"
    local tw = titleFont:getWidth(title)
    love.graphics.print(title, math.floor((sw - tw) / 2), math.floor(sh * 0.12))

    local subFont = FontManager.getResponsiveFont(0.022, 16)
    love.graphics.setFont(subFont)
    love.graphics.setColor(Palette.PARCHMENT_LIGHT)
    local sub = self.mode == "forge" and "Clique em uma carta para aprimora-la." or
        "Descanse para recuperar HP ou forje uma carta em seu deck."
    local sw2 = subFont:getWidth(sub)
    love.graphics.print(sub, math.floor((sw - sw2) / 2), math.floor(sh * 0.22))

    for _, b in ipairs(self.buttons) do b:draw() end

    if self.resultText then
        local rf = FontManager.getResponsiveFont(0.026, 18)
        love.graphics.setFont(rf)
        love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
        local rw = rf:getWidth(self.resultText)
        love.graphics.print(self.resultText,
            math.floor((sw - rw) / 2), math.floor(sh * 0.80))
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function RestScreen:mousepressed(x, y, button) return self.visible end

function RestScreen:mousereleased(x, y, button)
    if not self.visible then return false end
    for _, b in ipairs(self.buttons) do
        if b.hover and not b.disabled then
            b.onClick()
            return true
        end
    end
    return false
end

function RestScreen:keypressed(key)
    return false
end

return RestScreen
