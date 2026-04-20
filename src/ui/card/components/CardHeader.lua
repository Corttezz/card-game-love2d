-- src/ui/card/components/CardHeader.lua
-- Banner do nome — estandarte ornamentado pixel-perfect.
-- Elementos (esquerda pra direita):
--   [scroll end-cap] [diamond] [banner INK gradient + nome] [diamond] [scroll end-cap]
--
-- Alturas: 16px total.

local Palette     = require("src.ui.Palette")
local PixelCanvas = require("src.ui.PixelCanvas")
local PixelFont   = require("src.ui.PixelFont")
local I18n        = require("src.i18n.I18n")

local CardHeader = {}

-- Banner tem altura adaptativa:
--   - HEIGHT_SINGLE (18): nome cabe em 1 linha com fontes 14/12/10 → preserva
--     máximo de espaço pro art slot.
--   - HEIGHT_WRAP (24): nome precisa de 2 linhas → banner maior pra caber
--     duas linhas em size 10 (2×10=20 dentro de bh=22).
-- `computeHeight(name, w)` decide qual usar. CardFrame chama isso pra saber o
-- top do art slot daquela carta específica.
CardHeader.HEIGHT_SINGLE = 18
CardHeader.HEIGHT_WRAP   = 24
CardHeader.HEIGHT = CardHeader.HEIGHT_SINGLE   -- retrocompat pra quem lê direto

local function fitsSingleLine(name, maxW)
    for _, size in ipairs({ 14, 12, 10 }) do
        if PixelFont.get(size):getWidth(name) <= maxW then return true end
    end
    return false
end

-- Retorna a altura do banner pra este nome (considerando a largura w da carta).
-- Aceita tanto string quanto carta (resolve via I18n se for carta).
function CardHeader.computeHeight(cardOrName, w)
    local maxW = (w - 30) - 16   -- mesma fórmula usada no draw
    local name
    if type(cardOrName) == "table" then
        name = I18n.cardName(cardOrName)
    else
        name = cardOrName or "?"
    end
    if fitsSingleLine(name, maxW) then
        return CardHeader.HEIGHT_SINGLE
    end
    return CardHeader.HEIGHT_WRAP
end

-- ===== Scroll end-cap curvado (5×h, simula extremidade de pergaminho) =====
local function drawScrollEnd(x, y, h, dir)
    -- Forma "curvada": bordas arredondadas, centro mais largo
    -- dir: -1 (aponta p/ esquerda) ou +1 (aponta p/ direita)
    local mid = math.floor((h - 1) / 2)
    for row = 0, h - 1 do
        local dist = math.abs(row - mid)
        -- Extensão do scroll (largura pelo row)
        local ext
        if dist == 0 then ext = 4
        elseif dist == 1 then ext = 4
        elseif dist == 2 then ext = 3
        elseif dist == 3 then ext = 2
        else ext = 1 end

        for col = 0, ext - 1 do
            PixelCanvas.pixel(x + dir * col, y + row, Palette.INK)
        end
        -- Fita dourada por cima
        if col and ext >= 2 then end -- no-op
    end

    -- Sobrescreve com dourado (fita)
    for row = 0, h - 1 do
        local dist = math.abs(row - mid)
        if dist <= 1 then
            -- Centro: gold brilhante
            PixelCanvas.pixel(x + dir * 0, y + row, Palette.AGED_GOLD)
            PixelCanvas.pixel(x + dir * 1, y + row, Palette.AGED_GOLD_LIGHT)
            PixelCanvas.pixel(x + dir * 2, y + row, Palette.AGED_GOLD)
            PixelCanvas.pixel(x + dir * 3, y + row, Palette.AGED_GOLD_DARK)
        elseif dist == 2 then
            PixelCanvas.pixel(x + dir * 0, y + row, Palette.AGED_GOLD_DARK)
            PixelCanvas.pixel(x + dir * 1, y + row, Palette.AGED_GOLD)
        end
    end

    -- Ponta mais clara (curl effect)
    PixelCanvas.pixel(x + dir * 4, y + mid, Palette.AGED_GOLD_LIGHT)
end

-- ===== Diamond separator 3×3 (entre end-cap e banner) =====
local function drawDiamond(cx, cy)
    PixelCanvas.pixel(cx, cy - 1, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx - 1, cy, Palette.AGED_GOLD)
    PixelCanvas.pixel(cx, cy, Palette.AGED_GOLD_LIGHT)
    PixelCanvas.pixel(cx + 1, cy, Palette.AGED_GOLD)
    PixelCanvas.pixel(cx, cy + 1, Palette.AGED_GOLD_DARK)
end

function CardHeader.draw(w, cardName)
    local h = CardHeader.computeHeight(cardName, w)
    -- Banner flush com o topo da carta (by=0) pra subir o título.
    local bx, by = 15, 0
    local bw, bh = w - 30, h

    -- Sombra externa embaixo do banner
    PixelCanvas.rect(bx + 1, by + bh, bw, 1, { 0, 0, 0, 0.5 })

    -- Banner gradient (3 faixas verticais: top mais claro, mid ink, bottom mais escuro)
    PixelCanvas.rect(bx, by, bw, bh, Palette.INK)
    -- Top highlight line (gold_dark pra "engrave")
    PixelCanvas.hline(bx + 1, by + 1, bw - 2, Palette.AGED_GOLD_DARK)
    -- Bottom shadow line
    PixelCanvas.hline(bx + 1, by + bh - 2, bw - 2, { 0, 0, 0, 0.8 })

    -- Bordas duplas (ouro + sombra)
    PixelCanvas.rectOutline(bx, by, bw, bh, Palette.AGED_GOLD)

    -- Scroll end-caps nas extremidades
    drawScrollEnd(bx - 1, by, bh, -1)
    drawScrollEnd(bx + bw, by, bh, 1)

    -- Diamonds separadores entre scroll e texto
    drawDiamond(bx + 3, by + math.floor(bh / 2))
    drawDiamond(bx + bw - 4, by + math.floor(bh / 2))

    -- Detalhe: pequenos brilho pontos ao longo do topo do banner
    for i = 0, 2 do
        local px = bx + 8 + i * math.floor((bw - 16) / 3)
        PixelCanvas.pixel(px, by, Palette.AGED_GOLD_LIGHT)
    end

    -- Nome: tenta 14 → 12 → 10 em linha única; se nada couber, faz wrap
    -- respeitando fronteira de palavra (nunca quebra no meio). Se uma palavra
    -- individual ainda não couber, reduz a fonte até caber ou trunca.
    local utf8 = require("utf8")
    local name = cardName or "?"
    local maxW = bw - 16

    -- Helper: trunca por codepoint (não por byte, pra não quebrar UTF-8)
    local function truncate(s, f)
        local out = s
        local suffix = "."
        while f:getWidth(out) > maxW and utf8.len(out) > 1 do
            local cutAt = utf8.offset(out, -1)
            if not cutAt then break end
            out = out:sub(1, cutAt - 1) .. suffix
            suffix = ""
        end
        return out
    end

    -- Word-wrap que NUNCA quebra uma palavra ao meio. Retorna lista de linhas.
    -- Se alguma palavra isolada exceder maxW, ela vai pra própria linha
    -- (overflow handleado depois shrinkando fonte ou truncando).
    local function wordWrap(text, f)
        local words = {}
        for w in text:gmatch("%S+") do table.insert(words, w) end
        if #words == 0 then return { text } end
        local result, current = {}, ""
        for _, word in ipairs(words) do
            local try = current == "" and word or (current .. " " .. word)
            if f:getWidth(try) <= maxW then
                current = try
            else
                if current ~= "" then table.insert(result, current) end
                current = word
            end
        end
        if current ~= "" then table.insert(result, current) end
        return result
    end

    -- Testa se todas as linhas cabem em maxW (palavra sozinha pode exceder)
    local function allFit(wrappedLines, f)
        for _, line in ipairs(wrappedLines) do
            if f:getWidth(line) > maxW then return false end
        end
        return true
    end

    -- 1) Tenta linha única 14 → 12 → 10
    local font, lines
    for _, size in ipairs({ 14, 12, 10 }) do
        local f = PixelFont.get(size)
        if f:getWidth(name) <= maxW then
            font, lines = f, { name }
            break
        end
    end

    -- 2) Não cabe em 1 linha → tenta wrap 2 linhas em 10, depois 9, 8, 7
    --    (respeitando fronteiras de palavra)
    if not font then
        for _, size in ipairs({ 10, 9, 8, 7 }) do
            local f = PixelFont.get(size)
            local wrapped = wordWrap(name, f)
            if #wrapped == 1 and f:getWidth(wrapped[1]) <= maxW then
                -- Caiu pra 1 linha no tamanho menor
                font, lines = f, wrapped
                break
            elseif #wrapped == 2 and allFit(wrapped, f) then
                font, lines = f, wrapped
                break
            end
        end
    end

    -- 3) Último recurso: fonte muito pequena. Nome tem palavra única maior que
    --    o banner — tenta encolher até caber, ou trunca por codepoint.
    if not font then
        for _, size in ipairs({ 8, 7, 6 }) do
            local f = PixelFont.get(size)
            if f:getWidth(name) <= maxW then
                font, lines = f, { name }
                break
            end
        end
    end
    if not font then
        -- Realmente cabeçudo: trunca em 2 linhas no size 7
        font = PixelFont.get(7)
        local wrapped = wordWrap(name, font)
        if #wrapped >= 2 then
            lines = { truncate(wrapped[1], font), truncate(wrapped[2], font) }
        else
            lines = { truncate(name, font) }
        end
    end

    love.graphics.setFont(font)
    local singleLine = #lines == 1
    -- Linha única: usa altura padrão da fonte. Multi-linha: comprime o leading
    -- em 3px pra aproximar as linhas (getHeight inclui line gap interno do TTF
    -- que fica feio em banners tight).
    local lineH = singleLine and font:getHeight() or (font:getHeight() - 3)
    local totalH = lineH * #lines
    local startY = by + math.floor((bh - totalH) / 2)

    for i, line in ipairs(lines) do
        local tw = font:getWidth(line)
        local tx = bx + math.floor((bw - tw) / 2)
        local ty = startY + (i - 1) * lineH

        -- Linha única: outline preto 8-direções + triple-pass gold (bold/engrave)
        if singleLine then
            love.graphics.setColor(0, 0, 0, 1)
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        love.graphics.print(line, tx + dx, ty + dy)
                    end
                end
            end
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
            love.graphics.print(line, tx, ty)
            love.graphics.setColor(Palette.AGED_GOLD_DARK)
            love.graphics.print(line, tx, ty + 1)
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
            love.graphics.print(line, tx, ty)
        else
            -- 2 linhas em 16px tight: 1px drop shadow + gold (sem outline 8-dir)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.print(line, tx + 1, ty + 1)
            love.graphics.setColor(Palette.AGED_GOLD_LIGHT)
            love.graphics.print(line, tx, ty)
        end
    end
end

return CardHeader
