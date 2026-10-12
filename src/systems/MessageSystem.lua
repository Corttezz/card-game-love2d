local Config = require("src.core.Config")

local MessageSystem = {}
MessageSystem.__index = MessageSystem

function MessageSystem:new()
    local instance = setmetatable({}, MessageSystem)
    instance.messages = {}
    instance.maxMessages = Config.Game.MAX_MESSAGES
    instance.messageDuration = Config.Game.MESSAGE_DURATION -- 3 segundos
    return instance
end

function MessageSystem:addMessage(text, type)
    type = type or "info"
    local message = {
        text = text,
        type = type,
        duration = self.messageDuration,
        alpha = 1.0,
        y = 0
    }
    
    table.insert(self.messages, message)
    
    -- Remove mensagens antigas se exceder o limite
    if #self.messages > self.maxMessages then
        table.remove(self.messages, 1)
    end
end

function MessageSystem:update(dt)
    for i = #self.messages, 1, -1 do
        local message = self.messages[i]
        message.duration = message.duration - dt
        
        -- Animação de fade out
        if message.duration < 1.0 then
            message.alpha = message.duration
        end
        
        -- Remove mensagens expiradas
        if message.duration <= 0 then
            table.remove(self.messages, i)
        end
    end
end

-- Cor de destaque por tipo (filete da placa). Paleta do grimório, não RGB
-- cru: o azul/verde saturados de antes eram outro dialeto na mesma tela.
local function accentFor(kind)
    local Palette = require("src.ui.Palette")
    if kind == "error" then return Palette.lighten(Palette.BLOOD, 0.35)
    elseif kind == "warning" then return Palette.AGED_GOLD_LIGHT
    elseif kind == "success" then return Palette.lighten(Palette.MOSS, 0.45)
    elseif kind == "info" then return Palette.STEEL_LIGHT
    end
    return Palette.PARCHMENT_LIGHT
end
MessageSystem.accentFor = accentFor

-- Geometria dos toasts para a janela atual (pura: o teste/captura confere).
-- ZONA: coluna esquerda, do pé do quadro de coringas (31.8% da altura — era
-- o y=244 fixo em 768) até o topo da zona da mão (62%). Escala com a altura
-- como pausa/fim de run; o texto QUEBRA dentro da placa em vez de correr
-- pela tela (antes: texto cru 12px em x=10, sem fundo, ilegível sobre o
-- cenário claro).
function MessageSystem:layout()
    local FontManager = require("src.ui.FontManager")
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local u = math.max(1, math.min(1.75, sh / 768))
    local font = FontManager.getFont(math.floor(10 * u + 0.5))
    local padX, padY, gap = math.floor(10 * u), math.floor(6 * u), math.floor(6 * u)
    local x = math.floor(10 * u)
    local w = math.floor(math.min(sw * 0.30, 320 * u))
    local zoneTop, zoneBottom = math.floor(sh * 0.318), math.floor(sh * 0.62)
    local lh = math.floor(font:getHeight() * 1.5)
    local out, y = {}, zoneTop
    -- mais NOVAS embaixo (ordem de chegada); se a zona encher, as mais
    -- antigas saem primeiro (ficam fora do layout, não por cima da mão)
    local items = {}
    for i, m in ipairs(self.messages) do
        local _, lines = font:getWrap(tostring(m.text), w - padX * 2 - 4)
        items[i] = { m = m, lines = lines, h = padY * 2 + #lines * lh }
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
    local Palette = require("src.ui.Palette")
    local plates, font = self:layout()
    love.graphics.setFont(font)
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    for _, p in ipairs(plates) do
        local m = p.m
        local a = m.alpha
        -- entrada: desliza da borda nos primeiros 0,18s (só movimento —
        -- com reducedMotion aparece no lugar, a informação é a mesma)
        local age = self.messageDuration - m.duration
        local slide = (reduced or age >= 0.18) and 0 or math.floor((1 - age / 0.18) * -24)
        local x = p.x + slide
        Palette.set(Palette.INK, 0.86 * a)
        love.graphics.rectangle("fill", x, p.y, p.w, p.h, 3, 3)
        Palette.set(Palette.AGED_GOLD_DARK, 0.9 * a)
        love.graphics.rectangle("line", x + 0.5, p.y + 0.5, p.w - 1, p.h - 1, 3, 3)
        Palette.set(accentFor(m.type), a)
        love.graphics.rectangle("fill", x + 2, p.y + 3, 3, p.h - 6)
        local ty = p.y + p.padY
        for _, line in ipairs(p.lines) do
            Palette.set(Palette.INK, 0.8 * a)
            love.graphics.print(line, x + p.padX + 4 + 1, ty + 1)
            Palette.set(Palette.PARCHMENT_LIGHT, a)
            love.graphics.print(line, x + p.padX + 4, ty)
            ty = ty + p.lh
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Legado (consumidores antigos pediam a cor RGB por tipo).
function MessageSystem:getColorByType(kind)
    return accentFor(kind)
end

return MessageSystem
