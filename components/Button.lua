-- components/Button.lua
-- Botão pixel grimório com mais detalhe ornamental:
--   - Fill base + par de accent stripes (top/bot)
--   - Dual outline (moldura de 2 níveis)
--   - 4 rivets 2×2 gold com highlight 1px (look de placa rebitada)
--   - Ícone opcional auto-escalado pela altura do botão (não vaza)
--   - Hover: stripes pulsantes dourados + underline no texto
--   - Pressed: shift (+1, +1) + fill mais claro
--
-- Estados: normal / hover / pressed / disabled / invisible (só hit area).
-- API retrocompatível com Button:new(x, y, w, h, text, onClick, color?, fontSize?).

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")
local IconLoader  = require("src.ui.IconLoader")
local Debug       = require("src.core.Debug")

local Button = {}
Button.__index = Button

function Button:new(x, y, width, height, text, onClick, color, fontSize)
    local btn = setmetatable({}, Button)
    btn.x = math.floor(x or 0)
    btn.y = math.floor(y or 0)
    btn.width  = math.floor(width  or 180)
    btn.height = math.floor(height or 48)
    btn.text = text or ""
    btn.onClick = onClick or function() end
    btn.hover = false
    btn.pressed = false
    btn.disabled = false
    btn.visible = true
    btn.variant = "default"      -- "default" | "invisible"
    btn.iconHandle = nil
    btn.iconForceScale = nil     -- override opcional (geralmente auto)
    btn.accentColor = color      -- reservado; cores de estado vêm da Palette
    btn.fontSize = fontSize or 14
    btn._hoverTime = 0           -- acumulador pro pulso gold
    return btn
end

function Button:update(dt)
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    local wasHover = self.hover
    self.hover = (not self.disabled)
        and mx >= self.x and mx < self.x + self.width
        and my >= self.y and my < self.y + self.height
    if wasHover ~= self.hover then
        Debug.trace("Button '" .. (self.text or "?") .. "' hover -> " .. tostring(self.hover))
        if self.hover then self._hoverTime = 0 end
    end
    if self.hover then self._hoverTime = (self._hoverTime or 0) + (dt or 0) end
end

-- Retorna a paleta do estado atual. Cinco slots:
--   fill, outlineOuter, outlineInner, stripe, rivet, rivetHi, text, textShadow
local function stateColors(btn)
    if btn.disabled then
        return {
            fill         = Palette.BUTTON_FILL_DISABLED,   -- STEEL
            outlineOuter = Palette.BUTTON_OUTLINE_DISABLED,-- STEEL_LIGHT
            outlineInner = Palette.STEEL,
            stripe       = nil,     -- sem accent quando disabled
            rivet        = nil,
            rivetHi      = nil,
            text         = Palette.BUTTON_TEXT_DISABLED,
            textShadow   = nil,
        }
    elseif btn.pressed and btn.hover then
        return {
            fill         = Palette.PARCHMENT,              -- mid-tone
            outlineOuter = Palette.AGED_GOLD_DARK,
            outlineInner = Palette.PARCHMENT_DARK,
            stripe       = Palette.AGED_GOLD_DARK,
            rivet        = Palette.AGED_GOLD_DARK,
            rivetHi      = Palette.AGED_GOLD,
            text         = Palette.INK,
            textShadow   = Palette.PARCHMENT,
        }
    elseif btn.hover then
        return {
            fill         = Palette.AGED_GOLD,              -- dourado quente
            outlineOuter = Palette.INK,
            outlineInner = Palette.AGED_GOLD_DARK,
            stripe       = Palette.INK,
            rivet        = Palette.INK,
            rivetHi      = Palette.AGED_GOLD_LIGHT,
            text         = Palette.INK,
            textShadow   = Palette.AGED_GOLD_LIGHT,
        }
    else
        return {
            fill         = Palette.BUTTON_FILL,            -- PARCHMENT_DARK
            outlineOuter = Palette.AGED_GOLD,
            outlineInner = Palette.AGED_GOLD_DARK,
            stripe       = Palette.AGED_GOLD_DARK,
            rivet        = Palette.AGED_GOLD,
            rivetHi      = Palette.AGED_GOLD_LIGHT,
            text         = Palette.BUTTON_TEXT,            -- PARCHMENT_LIGHT
            textShadow   = Palette.INK,
        }
    end
end

-- Calcula escala do ícone pra caber na altura do botão.
-- - Matriz 16×16 → scale inteiro (IconLoader força floor).
-- - PNG (geralmente 64×64) → scale pode ser fracional (love.graphics.draw aceita;
--   nearest filter mantém crisp).
-- Target: ícone fica ~55% da altura do botão, cap em 32px.
-- Retorna (scale, rendered_w, rendered_h).
local function autoIconScale(btn)
    if not btn.iconHandle then return 1, 0, 0 end
    local baseW = btn.iconHandle.size.w
    local baseH = btn.iconHandle.size.h
    if btn.iconForceScale then
        local s = btn.iconForceScale
        return s, baseW * s, baseH * s
    end

    local targetH = math.min(40, math.max(14, math.floor(btn.height * 0.65)))
    local scale
    if btn.iconHandle.kind == "matrix" then
        -- inteiro obrigatório (senão drawBitmapScaled arredonda pra 1)
        scale = math.max(1, math.floor(targetH / baseH))
    else
        -- PNG: fracional OK
        scale = targetH / baseH
        if scale <= 0 then scale = 1 end
    end
    return scale, baseW * scale, baseH * scale
end

-- Acha o maior tamanho de fonte (<= desired) que deixa `text` caber em `maxWidth`.
-- Piso em 8 pra evitar texto ilegível.
local function fitFontSize(text, desiredSize, maxWidth)
    if not text or text == "" or maxWidth <= 0 then return desiredSize end
    local size = math.max(8, math.floor(desiredSize))
    while size > 8 do
        local font = FontManager.getFont(size)
        if font:getWidth(text) <= maxWidth then return size end
        size = size - 1
    end
    return 8
end

function Button:draw()
    if not self.visible then return end
    if self.variant == "invisible" then return end

    local x, y, w, h = self.x, self.y, self.width, self.height
    local t = love.timer.getTime()

    -- Pressed gera shift (+1,+1)
    local dx, dy = 0, 0
    if self.pressed and self.hover and not self.disabled then
        dx, dy = 1, 1
    end

    local c = stateColors(self)

    -- Sombra pixel atrás do botão (dither25 à direita e abaixo).
    -- Some quando pressed (simula o botão "afundando na placa").
    if not (self.pressed and self.hover) and not self.disabled then
        PixelCanvas.dither25(x + 3, y + h,     w - 3, 3,     Palette.BUTTON_SHADOW)
        PixelCanvas.dither25(x + w, y + 3,     3,     h - 3, Palette.BUTTON_SHADOW)
    end

    -- Fill interior
    PixelCanvas.rect(x + dx + 1, y + dy + 1, w - 2, h - 2, c.fill)

    -- Accent stripes (topo e base) — simula placa ornamentada de grimório
    if c.stripe and h >= 20 then
        PixelCanvas.rect(x + dx + 6, y + dy + 4,     w - 12, 1, c.stripe)
        PixelCanvas.rect(x + dx + 6, y + dy + h - 5, w - 12, 1, c.stripe)
    end

    -- Dual outline (moldura de 2 níveis pra aprofundar a silhueta)
    PixelCanvas.rectOutline(x + dx, y + dy, w, h, c.outlineOuter)
    if w >= 8 and h >= 8 then
        PixelCanvas.rectOutline(x + dx + 2, y + dy + 2, w - 4, h - 4, c.outlineInner)
    end

    -- 4 rivets 2×2 com highlight de 1px em branco dourado
    if c.rivet and w >= 16 and h >= 16 then
        PixelCanvas.rect(x + dx + 4,     y + dy + 4,     2, 2, c.rivet)
        PixelCanvas.rect(x + dx + w - 6, y + dy + 4,     2, 2, c.rivet)
        PixelCanvas.rect(x + dx + 4,     y + dy + h - 6, 2, 2, c.rivet)
        PixelCanvas.rect(x + dx + w - 6, y + dy + h - 6, 2, 2, c.rivet)
        if c.rivetHi then
            PixelCanvas.pixel(x + dx + 4,     y + dy + 4,     c.rivetHi)
            PixelCanvas.pixel(x + dx + w - 5, y + dy + 4,     c.rivetHi)
            PixelCanvas.pixel(x + dx + 4,     y + dy + h - 5, c.rivetHi)
            PixelCanvas.pixel(x + dx + w - 5, y + dy + h - 5, c.rivetHi)
        end
    end

    -- Hover: pulso dourado sutil nas stripes (brilho vivo)
    if self.hover and not self.disabled and h >= 20 then
        local pulse = 0.4 + math.sin(t * 4 + self._hoverTime) * 0.4  -- 0..0.8
        local hc = Palette.AGED_GOLD_LIGHT
        love.graphics.setColor(hc[1], hc[2], hc[3], pulse)
        love.graphics.rectangle("fill", x + dx + 6, y + dy + 4,     w - 12, 1)
        love.graphics.rectangle("fill", x + dx + 6, y + dy + h - 5, w - 12, 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Ícone: auto-scale primeiro (precisa pra saber quanto espaço sobra pro texto)
    local iconScale, iconPxW, iconPxH = autoIconScale(self)
    local iconGap = (self.iconHandle and self.text ~= "") and 8 or 0

    -- Área útil horizontal (descontando padding dos rivets e o ícone).
    local innerPadX = 14
    local textAvailW = math.max(1, w - innerPadX * 2 - iconPxW - iconGap)

    -- Auto-shrink: se o texto no tamanho pedido não cabe, reduz até caber
    local fontSize = fitFontSize(self.text, self.fontSize, textAvailW)
    local font = FontManager.getFont(fontSize)
    love.graphics.setFont(font)
    local textWidth  = self.text ~= "" and font:getWidth(self.text) or 0
    local textHeight = font:getHeight()

    local contentW = iconPxW + iconGap + textWidth
    local cursorX  = x + dx + math.floor((w - contentW) / 2)
    local textY    = y + dy + math.floor((h - textHeight) / 2)

    if self.iconHandle then
        local iconY = y + dy + math.floor((h - iconPxH) / 2)
        self.iconHandle.draw(cursorX, iconY, iconScale)
        cursorX = cursorX + iconPxW + iconGap
    end

    if textWidth > 0 then
        -- Sombra de texto 1px pra dar relevo
        if c.textShadow then
            local s = c.textShadow
            love.graphics.setColor(s[1], s[2], s[3], 1)
            love.graphics.print(self.text, cursorX + 1, textY + 1)
        end
        love.graphics.setColor(c.text[1], c.text[2], c.text[3], 1)
        love.graphics.print(self.text, cursorX, textY)

        -- Hover extra: underline dourado sob o texto
        if self.hover and not self.disabled then
            local u = Palette.AGED_GOLD_LIGHT
            love.graphics.setColor(u[1], u[2], u[3], 0.9)
            love.graphics.rectangle("fill", cursorX, textY + textHeight, textWidth, 1)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Button:mousepressed(mx, my, buttonId)
    if not self.visible or self.disabled then return end
    if buttonId == 1 and self.hover then
        self.pressed = true
    end
end

function Button:mousereleased(mx, my, buttonId)
    if not self.visible or self.disabled then return end
    if buttonId == 1 and self.pressed then
        if self.onClick then
            Debug.log("Button clicked: " .. (self.text or "?"))
            self.onClick()
        else
            Debug.warn("Button sem onClick: " .. (self.text or "?"))
        end
    end
    self.pressed = false
end

-- API retrocompatível
function Button:setEnabled(enabled)  self.disabled = not enabled end
function Button:setVisible(visible)  self.visible = visible end
function Button:setText(newText)     self.text = newText or "" end
function Button:setPosition(nx, ny)
    self.x = math.floor(nx)
    self.y = math.floor(ny)
end

-- Extensões
function Button:setVariant(v) self.variant = v or "default" end

-- setIcon(name)              -> auto-scale pela altura do botão
-- setIcon(name, scale)       -> força um scale inteiro (ex: 1, 2, 3)
-- setIcon(nil)               -> remove o ícone
function Button:setIcon(name, forceScale)
    if not name then
        self.iconHandle = nil
        self.iconForceScale = nil
    else
        self.iconHandle = IconLoader.get(name)
        self.iconForceScale = forceScale   -- nil = auto
    end
end

return Button
