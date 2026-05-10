-- src/ui/DynaText.lua
-- Texto Balatro-style: cada letra com offset/rot animado individualmente.
-- Port de engine/text.lua:DynaText do Balatro source (não copia matemática
-- exata — refeito pra ficar copyright-safe e usar fontes love2d).
--
-- Features:
--   • pop_in: cascata de entrada das letras (delay por índice).
--   • bump:   cada letra oscila Y em sin(rate * time + 200*k).
--   • float:  oscilação sustentada (mais sutil que bump).
--   • rotate: cada letra recebe pequena rotação alternada (idle wobble).
--   • pulse:  scale pulse ocasional (chamado externamente).
--   • quiver: tremor aleatório (medo/glitch).
--   • colours: ciclo entre cores (alterna por letra ou ao longo do tempo).
--
-- Uso:
--   local dt = DynaText.new({
--       text = "Pacote Padrão",
--       fontSize = 22,
--       bump = true, rotate = true, pop_in = 0.4,
--       colours = { {1,0.85,0.2,1} },
--       shadow = true,
--   })
--   dt:update(dt)        -- avança timer interno
--   dt:draw(x, y)        -- renderiza centralizado em (x, y)

local DynaText = {}
DynaText.__index = DynaText

local FontManager = require("src.ui.FontManager")
local utf8 = require("utf8")

-- Cria uma instância. Config opcional aceita:
--   text         (string)              — obrigatório
--   fontSize     (number)               default 16
--   bump         (bool)                 default false   — oscilação Y forte
--   bump_rate    (number)               default 2.666
--   bump_amount  (number)               default 1.0
--   float        (bool)                 default false   — oscilação Y sutil sustentada
--   rotate       (bool)                 default false   — wobble de rotação
--   pop_in       (number, segundos)     default 0       — duração da cascata; 0 = sem pop_in
--   pop_in_rate  (number)               default 3       — multiplica velocidade da cascata
--   spacing      (number)               default 1       — px extras entre letras
--   colours      (array de {r,g,b,a})   default {{1,1,1,1}}  — ciclo
--   colour_cycle (number, seg)          default 0       — 0 = primeira cor sempre
--   shadow       (bool)                 default false   — sombra preta atrás
--   align        ("left"|"center"|"right") default "center"
function DynaText.new(config)
    local d = setmetatable({}, DynaText)
    d.text = tostring(config.text or "")
    d.fontSize = config.fontSize or 16
    d.bump = config.bump or false
    d.bump_rate = config.bump_rate or 2.666
    d.bump_amount = config.bump_amount or 1.0
    d.float = config.float or false
    d.rotate = config.rotate or false
    d.pop_in = config.pop_in or 0
    d.pop_in_rate = config.pop_in_rate or 3
    d.spacing = config.spacing or 1
    d.colours = config.colours or {{1,1,1,1}}
    d.colour_cycle = config.colour_cycle or 0
    d.shadow = config.shadow or false
    d.align = config.align or "center"

    d.timer = 0           -- segundos desde criação
    d.popped_in = (d.pop_in <= 0)  -- true se já passou da fase de pop_in
    d.pulse_timer = 0     -- ativado por :pulse(amt)
    d.pulse_amt = 0
    d.quiver_amt = 0      -- ativado por :setQuiver(amt)
    d._shouldDraw = true

    return d
end

function DynaText:update(dt)
    self.timer = self.timer + dt
    if not self.popped_in and self.timer >= self.pop_in then
        self.popped_in = true
    end
    if self.pulse_timer > 0 then
        self.pulse_timer = math.max(0, self.pulse_timer - dt)
    end
end

-- Dispara um pulse: scale momentâneo > 1 que decai.
function DynaText:pulse(amt, duration)
    self.pulse_amt = amt or 0.5
    self.pulse_timer = duration or 0.3
    self._pulseTotal = self.pulse_timer
end

-- Tremor aleatório (use 0..1).
function DynaText:setQuiver(amt)
    self.quiver_amt = math.max(0, math.min(1, amt or 0))
end

function DynaText:setText(newText)
    self.text = tostring(newText or "")
    self._chars = nil  -- invalida cache de codepoints UTF-8
end

-- Itera codepoints UTF-8: retorna { ch1, ch2, ... } onde cada ch é uma string
-- 1-codepoint (multi-byte preservado). Necessário pra acentos PT-BR (ã, é, ó).
local function utf8codes(s)
    local result = {}
    for _, c in utf8.codes(s) do
        table.insert(result, utf8.char(c))
    end
    return result
end

-- Mede largura total (sem animação) pra alinhamento.
function DynaText:_measure(font)
    local w = 0
    self._chars = self._chars or utf8codes(self.text)
    for _, ch in ipairs(self._chars) do
        w = w + font:getWidth(ch) + self.spacing
    end
    return w
end

-- Pulse curve: 1 + amt * sin(pi * t/duration) — sobe e desce em quadrante.
function DynaText:_currentPulse()
    if self.pulse_timer <= 0 or not self._pulseTotal then return 0 end
    local t = 1 - (self.pulse_timer / self._pulseTotal)
    return self.pulse_amt * math.sin(math.pi * t)
end

-- Desenha centralizado em (centerX, centerY) (ou alinhado conforme `align`).
function DynaText:draw(centerX, centerY)
    if not self._shouldDraw then return end

    local font = FontManager.getFont(self.fontSize)
    love.graphics.setFont(font)

    local fontH = font:getHeight()
    local totalW = self:_measure(font)

    -- X de início baseado no alinhamento. Cada letra avança W + spacing.
    local startX
    if self.align == "left" then
        startX = centerX
    elseif self.align == "right" then
        startX = centerX - totalW
    else
        startX = centerX - totalW * 0.5
    end

    local pulseFactor = self:_currentPulse()
    local globalScale = 1 + pulseFactor

    local prevR, prevG, prevB, prevA = love.graphics.getColor()

    local cursorX = startX
    self._chars = self._chars or utf8codes(self.text)
    local nChars = #self._chars
    for i = 1, nChars do
        local ch = self._chars[i]
        local letterW = font:getWidth(ch)

        -- Pop-in: enquanto não popped_in, letras aparecem em cascata.
        local visible = true
        local popScale = 1
        if not self.popped_in then
            local letterDelay = (i - 1) / math.max(1, nChars * self.pop_in_rate)
            local progress = (self.timer - letterDelay) / math.max(0.001, self.pop_in)
            if progress < 0 then
                visible = false
            elseif progress < 1 then
                -- back-out elastic
                local p = progress - 1
                popScale = 1 + 1.70158 * p * p * p + 2.70158 * p * p
            else
                popScale = 1
            end
        end

        if visible then
            local yOff = 0
            local rotOff = 0

            if self.bump then
                -- Cada letra defasada por k. Curva: max(0, (5+rate)*sin(rate*t + 200*k) - 3 - rate)
                -- O max(0, ...) faz a letra ficar em "0" parte do tempo e pular pra cima episodicamente.
                local sinWave = (5 + self.bump_rate) * math.sin(self.bump_rate * self.timer + 200 * i) - 3 - self.bump_rate
                yOff = yOff - self.bump_amount * 7 * math.max(0, sinWave)
            end

            if self.float then
                yOff = yOff + 2 + math.sin(2.666 * self.timer + 200 * i) * 2
            end

            if self.rotate then
                rotOff = math.sin(1.7 * self.timer + i * 0.8) * 0.06
                -- Direção alternada por letra dá look "marcha animada".
                if i % 2 == 0 then rotOff = -rotOff end
            end

            if self.quiver_amt > 0 then
                yOff = yOff + (math.random() - 0.5) * 2 * self.quiver_amt * 4
                rotOff = rotOff + (math.random() - 0.5) * self.quiver_amt * 0.15
            end

            -- Cor: cicla entre self.colours por tempo OU por letra.
            local colourIdx = 1
            if #self.colours > 1 then
                if self.colour_cycle > 0 then
                    colourIdx = ((math.floor(self.timer / self.colour_cycle)) % #self.colours) + 1
                else
                    colourIdx = ((i - 1) % #self.colours) + 1
                end
            end
            local c = self.colours[colourIdx]

            -- Sombra primeiro (offset 1,1).
            if self.shadow then
                love.graphics.setColor(0, 0, 0, 0.5 * (c[4] or 1))
                love.graphics.push()
                love.graphics.translate(cursorX + letterW * 0.5 + 1, centerY + yOff + 1)
                love.graphics.rotate(rotOff)
                love.graphics.scale(popScale * globalScale, popScale * globalScale)
                love.graphics.print(ch, -letterW * 0.5, -fontH * 0.5)
                love.graphics.pop()
            end

            -- Letra principal.
            love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
            love.graphics.push()
            love.graphics.translate(cursorX + letterW * 0.5, centerY + yOff)
            love.graphics.rotate(rotOff)
            love.graphics.scale(popScale * globalScale, popScale * globalScale)
            love.graphics.print(ch, -letterW * 0.5, -fontH * 0.5)
            love.graphics.pop()
        end

        cursorX = cursorX + letterW + self.spacing
    end

    love.graphics.setColor(prevR, prevG, prevB, prevA)
end

return DynaText
