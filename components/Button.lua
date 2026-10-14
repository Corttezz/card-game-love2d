local Debug = require("src.core.Debug")

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local FontManager = require("src.ui.FontManager")
local IconLoader  = require("src.ui.IconLoader")
local Debug       = require("src.core.Debug")
local Sfx         = require("src.systems.Sfx")
local Moveable    = require("engine.Moveable")

local Button = {}
Button.__index = Button

Button.DEFAULT_VARIANT = "clean"

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
    btn.accentColor = color
    btn.fontSize = fontSize or 14
    btn._hoverTime = 0

    btn._hoverScale = 1.0
    btn._pressScale = 1.0

    btn.onePress = false
    btn._consumed = false

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
        if self.hover then
            self._hoverTime = 0
            if self.variant ~= "invisible" then
                Sfx.playWithVariation("menuHover", 1.0, 0.12)
            end
            Moveable.juice_up(self, 0.05, 0.03)
        end
    end
    if self.hover then
        self._hoverTime = (self._hoverTime or 0) + (dt or 0)
        require("src.ui.CursorManager").request("hand")
    end

    local targetHover = self.hover and not self.disabled and 1.05 or 1.0
    local targetPress = (self.pressed and self.hover) and 0.96 or 1.0
    local easeK = 1 - math.exp(-14 * (dt or 0))
    self._hoverScale = self._hoverScale + (targetHover - self._hoverScale) * easeK
    self._pressScale = self._pressScale + (targetPress - self._pressScale) * easeK

    Moveable.updateJuice(self, dt or 0)
end

local SCHEMES = {
    green = {
        fill       = {0.20, 0.55, 0.25, 1},
        fillHi     = {0.45, 0.78, 0.40, 1},
        fillLo     = {0.10, 0.32, 0.15, 1},
        border     = {0.05, 0.18, 0.08, 1},
        text       = {1, 1, 1, 1},
        textShadow = {0.05, 0.18, 0.08, 1},
        shadow     = {0, 0, 0, 0.55},
        hoverFill  = {0.30, 0.72, 0.35, 1},
    },
    red = {
        fill       = {0.55, 0.18, 0.18, 1},
        fillHi     = {0.78, 0.32, 0.32, 1},
        fillLo     = {0.32, 0.06, 0.06, 1},
        border     = {0.18, 0.04, 0.04, 1},
        text       = {1, 1, 1, 1},
        textShadow = {0.18, 0.04, 0.04, 1},
        shadow     = {0, 0, 0, 0.55},
        hoverFill  = {0.72, 0.28, 0.28, 1},
    },
}

local function stateColors(btn)
    if btn.colorScheme and SCHEMES[btn.colorScheme] then
        local sc = SCHEMES[btn.colorScheme]
        if btn.disabled or btn._consumed then
            return {
                fill = Palette.BUTTON_FILL_DISABLED,
                fillHi = Palette.STEEL_LIGHT, fillLo = Palette.STEEL,
                border = Palette.BUTTON_OUTLINE_DISABLED,
                text = Palette.BUTTON_TEXT_DISABLED,
                textShadow = nil, shadow = sc.shadow,
            }
        elseif btn.pressed and btn.hover then
            return {
                fill = sc.fillLo, fillHi = sc.fill, fillLo = sc.fillHi,
                border = sc.border, text = sc.text,
                textShadow = sc.textShadow, shadow = nil,
            }
        elseif btn.hover then
            return {
                fill = sc.hoverFill, fillHi = sc.fillHi, fillLo = sc.fillLo,
                border = sc.border, text = sc.text,
                textShadow = sc.textShadow, shadow = sc.shadow,
            }
        else
            return {
                fill = sc.fill, fillHi = sc.fillHi, fillLo = sc.fillLo,
                border = sc.border, text = sc.text,
                textShadow = sc.textShadow, shadow = sc.shadow,
            }
        end
    end

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
            fillHi     = Palette.AGED_GOLD_DARK,
            fillLo     = Palette.PARCHMENT_LIGHT,
            border     = Palette.AGED_GOLD_DARK,
            text       = Palette.INK,
            textShadow = Palette.PARCHMENT_LIGHT,
            shadow     = nil,
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
            fillLo     = Palette.PARCHMENT_DARK,
            border     = Palette.AGED_GOLD,
            text       = Palette.BUTTON_TEXT,
            textShadow = Palette.INK,
            shadow     = Palette.BUTTON_SHADOW,
        }
    end
end

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

local MIN_FONT = 8
local utf8 = require("utf8")

local function fitText(text, desiredSize, maxWidth)
    if not text or text == "" or maxWidth <= 0 then
        return text or "", desiredSize
    end
    local size = math.max(MIN_FONT, math.floor(desiredSize))
    while size >= MIN_FONT do
        local font = FontManager.getFont(size)
        if font:getWidth(text) <= maxWidth then return text, size end
        if size == MIN_FONT then break end
        size = size - 1
    end
    local font = FontManager.getFont(MIN_FONT)
    local ell = "..."
    local ellW = font:getWidth(ell)
    local out = ""
    for _, code in utf8.codes(text) do
        local ch = utf8.char(code)
        if font:getWidth(out .. ch) + ellW > maxWidth then break end
        out = out .. ch
    end
    return out .. ell, MIN_FONT
end

function Button:draw()
    if not self.visible then return end
    if not self.disabled and not self._consumed then
        require("src.ui.NavCursor").target(self, self.x, self.y, self.width, self.height)
    end
    if self.variant == "invisible" then return end
    if self.variant == "tv" then
        return self:_drawTv()
    end
    return self:_drawClean()
end

function Button:_drawTv()
    local x, y, w, h = self.x, self.y, self.width, self.height
    local hovered = self.hover and not self.disabled and not self._consumed
    local pressing = self.pressed and hovered

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
    if pressing then x, y = x + 1, y + 1 end

    local AMBER    = { 1.00, 0.72, 0.22 }
    local AMBER_HI = { 1.00, 0.82, 0.38 }
    local AMBER_LO = { 0.86, 0.55, 0.12 }

    if hovered then
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", x + 3, y + 3, w, h)
        love.graphics.setColor(AMBER_HI[1], AMBER_HI[2], AMBER_HI[3], 1)
        love.graphics.rectangle("fill", x, y, w, math.floor(h / 2))
        love.graphics.setColor(AMBER_LO[1], AMBER_LO[2], AMBER_LO[3], 1)
        love.graphics.rectangle("fill", x, y + math.floor(h / 2), w, math.ceil(h / 2))
        love.graphics.setColor(0.10, 0.07, 0.04, 0.9)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    else
        love.graphics.setColor(0.05, 0.04, 0.03, self.disabled and 0.35 or 0.55)
        love.graphics.rectangle("fill", x, y, w, h)
        local d = self.disabled and 0.35 or 0.85
        love.graphics.setColor(AMBER[1] * 0.6, AMBER[2] * 0.6, AMBER[3] * 0.6, d)
        love.graphics.rectangle("fill", x, y, 3, h)
        love.graphics.setColor(AMBER[1] * 0.5, AMBER[2] * 0.5, AMBER[3] * 0.5, 0.45)
        love.graphics.rectangle("fill", x, y + h - 1, w, 1)
    end

    local iconScale, iconPxW, iconPxH = autoIconScale(self)
    local iconGap = (self.iconHandle and self.text ~= "") and 10 or 0
    local padX = 18
    local drawText, fontSize = fitText(self.text, self.fontSize,
        w - padX * 2 - iconPxW - iconGap)
    local font = FontManager.getFont(fontSize)
    love.graphics.setFont(font)
    local textHeight = font:getHeight()
    local cursorX = x + padX
    local textY = y + math.floor((h - textHeight) / 2)

    if self.iconHandle then
        local iconY = y + math.floor((h - iconPxH) / 2)
        love.graphics.setColor(1, 1, 1, self.disabled and 0.4 or 1)
        self.iconHandle.draw(cursorX, iconY, iconScale)
        cursorX = cursorX + iconPxW + iconGap
    end

    if drawText ~= "" then
        if hovered then
            love.graphics.setColor(0.12, 0.08, 0.04, 1)
            love.graphics.print(drawText, cursorX, textY)
        else
            local pa = self.disabled and 0.4 or 1
            love.graphics.setColor(0, 0, 0, 0.8 * pa)
            love.graphics.print(drawText, cursorX + 1, textY + 1)
            love.graphics.setColor(0.92, 0.86, 0.72, pa)
            love.graphics.print(drawText, cursorX, textY)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    if needsTransform then love.graphics.pop() end
end

function Button:_drawClean()
    local x, y, w, h = self.x, self.y, self.width, self.height
    local c = stateColors(self)
    local r = Button.CORNER_RADIUS

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

    local pressing = self.pressed and self.hover and not self.disabled
    local shadowDist = pressing and 0 or 3
    local fillNudge = pressing and 1 or 0

    if c.shadow and not self.disabled and shadowDist > 0 then
        PixelCanvas.rectRounded(x + shadowDist, y + shadowDist, w, h, r, { c.shadow[1], c.shadow[2], c.shadow[3], 0.45 })
    end

    x = x + fillNudge
    y = y + fillNudge

    PixelCanvas.rectRounded(x, y, w, h, r, c.fill)

    if c.fillHi then
        love.graphics.setColor(c.fillHi[1], c.fillHi[2], c.fillHi[3], 0.16)
        love.graphics.rectangle("fill", x + r, y + 2,
            w - 2 * r, math.floor(h * 0.45))
    end
    if c.fillLo then
        love.graphics.setColor(c.fillLo[1], c.fillLo[2], c.fillLo[3], 0.26)
        love.graphics.rectangle("fill", x + r, y + h - 2 - math.floor(h * 0.22),
            w - 2 * r, math.floor(h * 0.22))
    end

    if c.fillHi then
        Palette.set(c.fillHi)
        love.graphics.rectangle("fill", x + r, y + 1, w - 2 * r, 1)
        love.graphics.rectangle("fill", x + 1, y + r, 1, h - 2 * r)
        if r > 0 then
            love.graphics.rectangle("fill", x + r, y + 1, 1, 1)
            love.graphics.rectangle("fill", x + 1, y + r, 1, 1)
        end
    end

    if c.fillLo then
        Palette.set(c.fillLo)
        love.graphics.rectangle("fill", x + r, y + h - 2, w - 2 * r, 1)
        love.graphics.rectangle("fill", x + w - 2, y + r, 1, h - 2 * r)
    end

    PixelCanvas.rectRoundedOutline(x, y, w, h, r, c.border)
    PixelCanvas.rectRoundedOutline(x + 2, y + 2, w - 4, h - 4, math.max(0, r - 1),
        { c.border[1] * 0.55, c.border[2] * 0.55, c.border[3] * 0.55, 0.8 })

    if self.hover and not self.disabled and not self._consumed then
        local pulse = 0.2 + math.sin(love.timer.getTime() * 3 + self._hoverTime) * 0.15
        local hc = Palette.AGED_GOLD_LIGHT
        love.graphics.setColor(hc[1], hc[2], hc[3], pulse)
        love.graphics.rectangle("fill", x + r + 1, y + 2, w - 2 * r - 2, 1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local iconScale, iconPxW, iconPxH = autoIconScale(self)
    local iconGap = (self.iconHandle and self.text ~= "") and 8 or 0
    local innerPadX = 12
    local textAvailW = math.max(1, w - innerPadX * 2 - iconPxW - iconGap)
    local drawText, fontSize = fitText(self.text, self.fontSize, textAvailW)
    local font = FontManager.getFont(fontSize)
    love.graphics.setFont(font)
    local textWidth = drawText ~= "" and font:getWidth(drawText) or 0
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
            love.graphics.print(drawText, cursorX + 1, textY + 1)
        end
        Palette.set(c.text)
        love.graphics.print(drawText, cursorX, textY)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if needsTransform then love.graphics.pop() end
end

function Button:mousepressed(mx, my, buttonId)
    if not self.visible or self.disabled or self._consumed then return false end
    if buttonId == 1 and self.hover then
        self.pressed = true
        return true
    end
    return false
end

function Button:mousereleased(mx, my, buttonId)
    if not self.visible or self.disabled or self._consumed then return false end
    if buttonId == 1 and self.pressed then
        if self.onClick then
            Sfx.playWithVariation("buttonClick", 1.0, 0.08)
            Moveable.juice_up(self, 0.22, 0.05)
            if _G.jiggleScreen then _G.jiggleScreen(0.3) end
            if self.onePress then self._consumed = true end
            self.onClick()
        else
            Debug.warn("Button sem onClick: " .. (self.text or "?"))
        end
        self.pressed = false
        return true
    end
    self.pressed = false
    return false
end

function Button:setEnabled(enabled)  self.disabled = not enabled end
function Button:setVisible(visible)  self.visible = visible end
function Button:setColorScheme(scheme) self.colorScheme = scheme end
function Button:setText(newText)     self.text = newText or "" end
function Button:setPosition(nx, ny)
    self.x = math.floor(nx)
    self.y = math.floor(ny)
end

function Button:setVariant(v) self.variant = v or Button.DEFAULT_VARIANT end

function Button:setOnePress(enabled)
    self.onePress = enabled and true or false
    if not enabled then self._consumed = false end
end

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
