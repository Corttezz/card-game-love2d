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

-- Aviso VAZIO não existe (dono: "não toastar resultado zero"). O mesmo texto
-- repetido não empilha: o aviso que já está na tela renova e vira o mais novo.
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
    
    -- Remove mensagens antigas se exceder o limite
    while #self.messages > self.maxMessages do
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

-- Cor do TEXTO por tipo (dono, Out/2026: "coloque cores diferentes como
-- era antes"): ouro = dinheiro, verde = cura/ganho, vermelho = perigo,
-- laranja = aviso de regra, azul = informação, violeta = orbe/magia.
local function accentFor(kind)
    local Palette = require("src.ui.Palette")
    if kind == "error" or kind == "danger" then return Palette.TOAST_DANGER
    elseif kind == "warning" then return Palette.TOAST_WARN
    elseif kind == "success" then return Palette.TOAST_GOOD
    elseif kind == "gold" then return Palette.TOAST_GOLD
    elseif kind == "arcane" then return Palette.TOAST_ARCANE
    elseif kind == "info" then return Palette.TOAST_INFO
    end
    print("[MessageSystem] tipo de aviso desconhecido: " .. tostring(kind))
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
    -- sem placa: o respiro é só o do contorno do texto
    local padX, padY, gap = math.floor(2 * u), math.floor(2 * u), math.floor(4 * u)
    -- mesma margem esquerda do quadro de coringas logo acima (frameX = 14)
    local x = math.floor(14 * u)
    local w = math.floor(math.min(sw * 0.30, 320 * u))
    local zoneTop, zoneBottom = math.floor(sh * 0.318), math.floor(sh * 0.62)
    -- nunca por cima do quadro de coringas (tela baixa — Steam Deck com a
    -- escala de UI em 125% — o quadro passa dos 31.8% da altura)
    local okGS, GS = pcall(require, "src.scenes.GameplayScene")
    if okGS and GS.jokerFrameRect then
        local okR, _, jy, _, jh = pcall(GS.jokerFrameRect)
        if okR and jy and jh then zoneTop = math.max(zoneTop, math.floor(jy + jh + 8)) end
    end
    local lh = math.floor(font:getHeight() * 1.35)
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

-- Texto colorido com contorno de tinta (8 direções), SEM placa: a placa
-- escura de antes pesava a coluna e apagava a cor do tipo.
function MessageSystem:draw()
    local Palette = require("src.ui.Palette")
    local plates, font = self:layout()
    love.graphics.setFont(font)
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    local o = math.max(1, math.floor(font:getHeight() / 12 + 0.5))
    for _, p in ipairs(plates) do
        local m = p.m
        local a = m.alpha
        -- entrada: desliza nos primeiros 0,18s DENTRO da margem; fade junto.
        -- Com reducedMotion aparece no lugar, a informação é a mesma.
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

-- Legado (consumidores antigos pediam a cor RGB por tipo).
function MessageSystem:getColorByType(kind)
    return accentFor(kind)
end

return MessageSystem
