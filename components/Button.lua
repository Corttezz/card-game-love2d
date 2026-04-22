-- components/Button.lua
-- Botão em estilo "Balatro meets grimoire": retângulo sólido com cantos cortados,
-- emboss 1px (highlight top/left + shadow bottom/right), scale-on-hover,
-- press squish. Mantém a paleta grimório existente + juice_up do engine.
--
-- Refactor baseado em UIBox_button do Balatro (functions/UI_definitions.lua:6376).
-- Substitui a versão antiga com 4 rivets + dual outline + stripes (muito detalhe).
--
-- ESTADOS visuais:
--   normal   → fill base + emboss + shadow
--   hover    → scale 1.05 + fill mais quente + emboss brighter + pulse sutil
--   pressed  → scale 0.96 + shadow reduzida + fill afundada
--   disabled → steel palette + sem emboss + sem hover
--
-- VARIANTS:
--   "clean"     (default)    Look novo Balatro-inspired
--   "ornate"    (legacy)     Rivets + stripes + dual outline (look antigo)
--   "invisible" (hit-only)   Só hit area, sem render
--
-- API compatível com versão anterior (Button:new(x, y, w, h, text, onClick, color?, fontSize?))

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")
local IconLoader  = require("src.ui.IconLoader")
local Debug       = require("src.core.Debug")
local Sfx         = require("src.systems.Sfx")
local Moveable    = require("engine.Moveable")

local Button = {}
Button.__index = Button

-- Default variant pros botões novos. Mude aqui se quiser o look antigo por padrão.
Button.DEFAULT_VARIANT = "clean"

-- Radius do corner cut (em pixels lógicos). Balatro usa r=0.1 (~6-8px numa tela
-- 720p). Em pixel art 2-3 é o sweet spot.
Button.CORNER_RADIUS = 2

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
    btn.variant = Button.DEFAULT_VARIANT
    btn.iconHandle = nil
    btn.iconForceScale = nil
    btn.accentColor = color  -- kind hint; atualmente não altera paleta (legacy arg)
    btn.fontSize = fontSize or 14
    btn._hoverTime = 0

    -- Scale animations (Balatro-style): hover escala pra 1.05, press squish pra 0.96.
    -- Eased exp decay pra não saltar.
    btn._hoverScale = 1.0
    btn._pressScale = 1.0

    -- one_press: bloqueia trigger após 1 click. Usado pra botões que mudam state
    -- (evita duplo click disparando 2x). setOnePress(true) pra ativar.
    btn.onePress = false
    btn._consumed = false

    -- Juice kick (scale/rot bounce) via engine/Moveable.
    Moveable.initJuice(btn)

    return btn
end

function Button:update(dt)
    if not self.visible then return end
    local mx, my = love.mouse.getPosition()
    local wasHover = self.hover
    self.hover = (not self.disabled) and (not self._consumed)
        and mx >= self.x and mx < self.x + self.width
        and my >= self.y and my < self.y + self.height
    if wasHover ~= self.hover then
        Debug.trace("Button '" .. (self.text or "?") .. "' hover -> " .. tostring(self.hover))
        if self.hover then
            self._hoverTime = 0
            Sfx.play("menuHover")
        end
    end
    if self.hover then self._hoverTime = (self._hoverTime or 0) + (dt or 0) end

    -- Scale animations via exp decay (consistente com Card/JokerSlot).
    local targetHover = self.hover and not self.disabled and 1.05 or 1.0
    local targetPress = (self.pressed and self.hover) and 0.96 or 1.0
    local easeK = 1 - math.exp(-14 * (dt or 0))
    self._hoverScale = self._hoverScale + (targetHover - self._hoverScale) * easeK
    self._pressScale = self._pressScale + (targetPress - self._pressScale) * easeK

    Moveable.updateJuice(self, dt or 0)
end

-- ============ state palette ============

-- Retorna {fill, fillHi, fillLo, border, text, textShadow, shadow} pro estado atual.
--   fillHi = emboss top/left (highlight)
--   fillLo = emboss bottom/right (sombra interna)
local function stateColors(btn)
    if btn.disabled or btn._consumed then
        return {
            fill       = Palette.BUTTON_FILL_DISABLED,
            fillHi     = Palette.STEEL_LIGHT,
            fillLo     = Palette.STEEL,
            border     = Palette.BUTTON_OUTLINE_DISABLED,
            text       = Palette.BUTTON_TEXT_DISABLED,
            textShadow = nil,
            shadow     = Palette.BUTTON_SHADOW,
        }
    elseif btn.pressed and btn.hover then
        return {
            fill       = Palette.PARCHMENT_DARK,
            fillHi     = Palette.AGED_GOLD_DARK, -- emboss invertida no pressed (look "afundado")
            fillLo     = Palette.PARCHMENT_LIGHT,
            border     = Palette.AGED_GOLD_DARK,
            text       = Palette.INK,
            textShadow = Palette.PARCHMENT_LIGHT,
            shadow     = nil,  -- sem shadow quando pressed (botão "afunda")
        }
    elseif btn.hover then
        return {
            fill       = Palette.AGED_GOLD,
            fillHi     = Palette.AGED_GOLD_LIGHT,
            fillLo     = Palette.AGED_GOLD_DARK,
            border     = Palette.INK,
            text       = Palette.INK,
            textShadow = Palette.AGED_GOLD_LIGHT,
            shadow     = Palette.BUTTON_SHADOW,
        }
    else
        return {
            fill       = Palette.BUTTON_FILL,
            fillHi     = Palette.PARCHMENT_LIGHT,
            fillLo     = Palette.PARCHMENT_DARK, -- dupla certeza de ter o dark pra emboss
            border     = Palette.AGED_GOLD,
            text       = Palette.BUTTON_TEXT,
            textShadow = Palette.INK,
            shadow     = Palette.BUTTON_SHADOW,
        }
    end
end

-- ============ helpers ============

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
        scale = math.max(1, math.floor(targetH / baseH))
    else
        scale = targetH / baseH
        if scale <= 0 then scale = 1 end
    end
    return scale, baseW * scale, baseH * scale
end

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

-- ============ draw ============

function Button:draw()
    if not self.visible then return end
    if self.variant == "invisible" then return end
    if self.variant == "ornate" then
        return self:_drawOrnate()
    end
    return self:_drawClean()
end

-- Novo draw: rounded + emboss + scale-hover + shadow animada.
function Button:_drawClean()
    local x, y, w, h = self.x, self.y, self.width, self.height
    local c = stateColors(self)
    local r = Button.CORNER_RADIUS

    -- Combina scale de hover + press + juice. Transform wrap centralizado no botão.
    local scale = self._hoverScale * self._pressScale * Moveable.scaleFactor(self)
    local rot = Moveable.rotOffset(self)
    local needsTransform = scale ~= 1 or rot ~= 0

    if needsTransform then
        love.graphics.push()
        love.graphics.translate(x + w / 2, y + h / 2)
        love.graphics.scale(scale, scale)
        love.graphics.rotate(rot)
        love.graphics.translate(-(x + w / 2), -(y + h / 2))
    end

    -- ===== SHADOW (drop shadow abaixo + direita) =====
    if c.shadow and not self.disabled then
        local sdx, sdy = 3, 3
        PixelCanvas.rectRounded(x + sdx, y + sdy, w, h, r, { c.shadow[1], c.shadow[2], c.shadow[3], 0.45 })
    end

    -- ===== FILL principal =====
    PixelCanvas.rectRounded(x, y, w, h, r, c.fill)

    -- ===== EMBOSS (top/left highlight) =====
    -- 1px horizontal no topo + 1px vertical na esquerda. Cria look 3D.
    if c.fillHi then
        Palette.set(c.fillHi)
        -- Top edge (excluindo cantos cortados)
        love.graphics.rectangle("fill", x + r, y + 1, w - 2 * r, 1)
        -- Left edge
        love.graphics.rectangle("fill", x + 1, y + r, 1, h - 2 * r)
        -- Pequeno highlight diagonal no canto top-left
        if r > 0 then
            love.graphics.rectangle("fill", x + r, y + 1, 1, 1)
            love.graphics.rectangle("fill", x + 1, y + r, 1, 1)
        end
    end

    -- ===== EMBOSS (bottom/right shadow) =====
    if c.fillLo then
        Palette.set(c.fillLo)
        love.graphics.rectangle("fill", x + r, y + h - 2, w - 2 * r, 1)
        love.graphics.rectangle("fill", x + w - 2, y + r, 1, h - 2 * r)
    end

    -- ===== BORDER outline com cantos cortados =====
    PixelCanvas.rectRoundedOutline(x, y, w, h, r, c.border)

    -- ===== HOVER PULSE sutil =====
    if self.hover and not self.disabled and not self._consumed then
        local pulse = 0.2 + math.sin(love.timer.getTime() * 3 + self._hoverTime) * 0.15
        local hc = Palette.AGED_GOLD_LIGHT
        love.graphics.setColor(hc[1], hc[2], hc[3], pulse)
        -- Glow line logo abaixo do top edge
        love.graphics.rectangle("fill", x + r + 1, y + 2, w - 2 * r - 2, 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- ===== ICON + TEXT =====
    local iconScale, iconPxW, iconPxH = autoIconScale(self)
    local iconGap = (self.iconHandle and self.text ~= "") and 8 or 0
    local innerPadX = 12
    local textAvailW = math.max(1, w - innerPadX * 2 - iconPxW - iconGap)
    local fontSize = fitFontSize(self.text, self.fontSize, textAvailW)
    local font = FontManager.getFont(fontSize)
    love.graphics.setFont(font)
    local textWidth = self.text ~= "" and font:getWidth(self.text) or 0
    local textHeight = font:getHeight()
    local contentW = iconPxW + iconGap + textWidth
    local cursorX = x + math.floor((w - contentW) / 2)
    local textY = y + math.floor((h - textHeight) / 2)

    if self.iconHandle then
        local iconY = y + math.floor((h - iconPxH) / 2)
        self.iconHandle.draw(cursorX, iconY, iconScale)
        cursorX = cursorX + iconPxW + iconGap
    end

    if textWidth > 0 then
        if c.textShadow then
            Palette.set(c.textShadow)
            love.graphics.print(self.text, cursorX + 1, textY + 1)
        end
        Palette.set(c.text)
        love.graphics.print(self.text, cursorX, textY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if needsTransform then love.graphics.pop() end
end

-- Look antigo (rivets + dual outline + stripes). Mantido como opt-in via variant.
function Button:_drawOrnate()
    local x, y, w, h = self.x, self.y, self.width, self.height
    local t = love.timer.getTime()

    local dx, dy = 0, 0
    if self.pressed and self.hover and not self.disabled then
        dx, dy = 1, 1
    end

    local c = stateColors(self)

    local juiceScale = Moveable.scaleFactor(self)
    local juiceRot = Moveable.rotOffset(self)
    local needsTransform = juiceScale ~= 1 or juiceRot ~= 0
    if needsTransform then
        love.graphics.push()
        love.graphics.translate(x + w / 2, y + h / 2)
        love.graphics.scale(juiceScale, juiceScale)
        love.graphics.rotate(juiceRot)
        love.graphics.translate(-(x + w / 2), -(y + h / 2))
    end

    if not (self.pressed and self.hover) and not self.disabled then
        PixelCanvas.dither25(x + 3, y + h,     w - 3, 3,     Palette.BUTTON_SHADOW)
        PixelCanvas.dither25(x + w, y + 3,     3,     h - 3, Palette.BUTTON_SHADOW)
    end

    PixelCanvas.rect(x + dx + 1, y + dy + 1, w - 2, h - 2, c.fill)

    -- Stripes
    if c.border and h >= 20 then
        PixelCanvas.rect(x + dx + 6, y + dy + 4,     w - 12, 1, c.fillLo or c.border)
        PixelCanvas.rect(x + dx + 6, y + dy + h - 5, w - 12, 1, c.fillLo or c.border)
    end

    -- Dual outline
    PixelCanvas.rectOutline(x + dx, y + dy, w, h, c.border)
    if w >= 8 and h >= 8 then
        PixelCanvas.rectOutline(x + dx + 2, y + dy + 2, w - 4, h - 4, c.fillLo or c.border)
    end

    -- Rivets
    if c.fillLo and w >= 16 and h >= 16 then
        PixelCanvas.rect(x + dx + 4,     y + dy + 4,     2, 2, c.fillLo)
        PixelCanvas.rect(x + dx + w - 6, y + dy + 4,     2, 2, c.fillLo)
        PixelCanvas.rect(x + dx + 4,     y + dy + h - 6, 2, 2, c.fillLo)
        PixelCanvas.rect(x + dx + w - 6, y + dy + h - 6, 2, 2, c.fillLo)
        if c.fillHi then
            PixelCanvas.pixel(x + dx + 4,     y + dy + 4,     c.fillHi)
            PixelCanvas.pixel(x + dx + w - 5, y + dy + 4,     c.fillHi)
            PixelCanvas.pixel(x + dx + 4,     y + dy + h - 5, c.fillHi)
            PixelCanvas.pixel(x + dx + w - 5, y + dy + h - 5, c.fillHi)
        end
    end

    local iconScale, iconPxW, iconPxH = autoIconScale(self)
    local iconGap = (self.iconHandle and self.text ~= "") and 8 or 0
    local innerPadX = 14
    local textAvailW = math.max(1, w - innerPadX * 2 - iconPxW - iconGap)
    local fontSize = fitFontSize(self.text, self.fontSize, textAvailW)
    local font = FontManager.getFont(fontSize)
    love.graphics.setFont(font)
    local textWidth = self.text ~= "" and font:getWidth(self.text) or 0
    local textHeight = font:getHeight()
    local contentW = iconPxW + iconGap + textWidth
    local cursorX = x + dx + math.floor((w - contentW) / 2)
    local textY = y + dy + math.floor((h - textHeight) / 2)

    if self.iconHandle then
        local iconY = y + dy + math.floor((h - iconPxH) / 2)
        self.iconHandle.draw(cursorX, iconY, iconScale)
        cursorX = cursorX + iconPxW + iconGap
    end
    if textWidth > 0 then
        if c.textShadow then
            Palette.set(c.textShadow)
            love.graphics.print(self.text, cursorX + 1, textY + 1)
        end
        Palette.set(c.text)
        love.graphics.print(self.text, cursorX, textY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if needsTransform then love.graphics.pop() end
end

-- ============ input ============

function Button:mousepressed(mx, my, buttonId)
    if not self.visible or self.disabled or self._consumed then return end
    if buttonId == 1 and self.hover then
        self.pressed = true
    end
end

function Button:mousereleased(mx, my, buttonId)
    if not self.visible or self.disabled or self._consumed then return end
    if buttonId == 1 and self.pressed then
        if self.onClick then
            Debug.log("Button clicked: " .. (self.text or "?"))
            Sfx.play("buttonClick")
            Moveable.juice_up(self, 0.22, 0.05)
            if self.onePress then self._consumed = true end
            self.onClick()
        else
            Debug.warn("Button sem onClick: " .. (self.text or "?"))
        end
    end
    self.pressed = false
end

-- ============ API ============

function Button:setEnabled(enabled)  self.disabled = not enabled end
function Button:setVisible(visible)  self.visible = visible end
function Button:setText(newText)     self.text = newText or "" end
function Button:setPosition(nx, ny)
    self.x = math.floor(nx)
    self.y = math.floor(ny)
end

function Button:setVariant(v) self.variant = v or Button.DEFAULT_VARIANT end

-- Ativa one_press: após primeiro click, botão fica "consumed" (disabled visual,
-- não responde mais). Ideal pra botões que iniciam transição de state.
function Button:setOnePress(enabled)
    self.onePress = enabled and true or false
    if not enabled then self._consumed = false end
end

-- Reset one_press (útil ao reexibir button após navegação).
function Button:resetConsumed() self._consumed = false end

function Button:setIcon(name, forceScale)
    if not name then
        self.iconHandle = nil
        self.iconForceScale = nil
    else
        self.iconHandle = IconLoader.get(name)
        self.iconForceScale = forceScale
    end
end

return Button
