local Debug = require("src.core.Debug")
local Config = require("src.core.Config")

local MessageSystem = {}
MessageSystem.__index = MessageSystem

function MessageSystem:new()
    local instance = setmetatable({}, MessageSystem)
    instance.messages = {}
    instance.maxMessages = Config.Game.MAX_MESSAGES
    instance.messageDuration = Config.Game.MESSAGE_DURATION
    return instance
end

function MessageSystem:addMessage(text, type)
    if text == nil or text == "" then return end
    type = type or "info"
    for i, m in ipairs(self.messages) do
        if m.text == text then
            table.remove(self.messages, i)
            break
        end
    end
    local message = {
        text = text,
        type = type,
        duration = self.messageDuration,
        alpha = 1.0,
        y = 0
    }

    table.insert(self.messages, message)

    while #self.messages > self.maxMessages do
        table.remove(self.messages, 1)
    end
end

function MessageSystem:update(dt)
    for i = #self.messages, 1, -1 do
        local message = self.messages[i]
        message.duration = message.duration - dt

        if message.duration < 1.0 then
            message.alpha = message.duration
        end

        if message.duration <= 0 then
            table.remove(self.messages, i)
        end
    end
end

local warnedKind = {}
local function accentFor(kind)
    local Palette = require("src.ui.Palette")
    if kind == "error" or kind == "danger" then return Palette.TOAST_DANGER
    elseif kind == "warning" then return Palette.TOAST_WARN
    elseif kind == "success" then return Palette.TOAST_GOOD
    elseif kind == "gold" then return Palette.TOAST_GOLD
    elseif kind == "arcane" then return Palette.TOAST_ARCANE
    elseif kind == "info" then return Palette.TOAST_INFO
    end
    if not warnedKind[kind] then
        warnedKind[kind] = true
        Debug.warn("[MessageSystem] AVISO: tipo de aviso desconhecido: " .. tostring(kind))
    end
    return Palette.PARCHMENT_LIGHT
end
MessageSystem.accentFor = accentFor

function MessageSystem:layout()
    local FontManager = require("src.ui.FontManager")
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local u = math.max(1, math.min(1.75, sh / 768))
    local font = FontManager.getFont(math.floor(10 * u + 0.5))
    local padX, padY, gap = math.floor(2 * u), math.floor(2 * u), math.floor(4 * u)
    local x = math.floor(14 * u)
    local w = math.floor(math.min(sw * 0.30, 320 * u))
    local zoneTop, zoneBottom = math.floor(sh * 0.318), math.floor(sh * 0.62)
    local okGS, GS = pcall(require, "src.scenes.GameplayScene")
    if okGS and GS.jokerFrameRect then
        local okR, _, jy, _, jh = pcall(GS.jokerFrameRect)
        if okR and jy and jh then zoneTop = math.max(zoneTop, math.floor(jy + jh + 8)) end
    end
    local lh = math.floor(font:getHeight() * 1.35)
    local out, y = {}, zoneTop
    local items = {}
    local wrapW = w - padX * 2 - 4
    for i, m in ipairs(self.messages) do
        if m._wrapFont ~= font or m._wrapW ~= wrapW then
            local _, lines = font:getWrap(tostring(m.text), wrapW)
            m._wrapFont, m._wrapW, m._lines = font, wrapW, lines
        end
        items[i] = { m = m, lines = m._lines, h = padY * 2 + #m._lines * lh }
    end
    local total = 0
    for _, it in ipairs(items) do total = total + it.h + gap end
    local first = 1
    while total - gap > zoneBottom - zoneTop and first < #items do
        total = total - items[first].h - gap
        first = first + 1
    end
    for i = first, #items do
        local it = items[i]
        out[#out + 1] = { m = it.m, lines = it.lines, x = x, y = y, w = w, h = it.h,
            padX = padX, padY = padY, lh = lh }
        y = y + it.h + gap
    end
    return out, font, { x = x, y = zoneTop, w = w, h = zoneBottom - zoneTop }
end

function MessageSystem:draw()
    if #self.messages == 0 then return end
    local Palette = require("src.ui.Palette")
    local plates, font = self:layout()
    love.graphics.setFont(font)
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    local o = math.max(1, math.floor(font:getHeight() / 12 + 0.5))
    for _, p in ipairs(plates) do
        local m = p.m
        local a = m.alpha
        local age = self.messageDuration - m.duration
        local e = (reduced or age >= 0.18) and 1 or (age / 0.18)
        local x = p.x + p.padX - math.floor((1 - e) * math.min(10, p.x))
        a = a * (0.35 + 0.65 * e)
        local c = accentFor(m.type)
        local ty = p.y + p.padY
        for _, line in ipairs(p.lines) do
            Palette.set(Palette.INK, 0.9 * a)
            for dx = -o, o, o do
                for dy = -o, o, o do
                    if dx ~= 0 or dy ~= 0 then love.graphics.print(line, x + dx, ty + dy) end
                end
            end
            love.graphics.print(line, x + o, ty + o * 2)
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.print(line, x, ty)
            ty = ty + p.lh
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MessageSystem:getColorByType(kind)
    return accentFor(kind)
end

return MessageSystem
