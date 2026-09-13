-- tools/preview_button_border.lua
-- Comparação controlada da borda do Button: versão ANTIGA (traço interno
-- quadrado em meio-pixel) vs ATUAL (traço interno seguindo a curva, em pixel
-- inteiro). Nasceu da queixa "o botão Resgatar tem uma borda estranha".
--
-- Desenha as duas na MESMA tela, nos 3 estados que mudam a paleta (normal /
-- hover / disabled), e amplia 6x com nearest — a única forma honesta de julgar
-- 1px de borda (memory/card_feel §v3.1: validar por PIXEL, não por código).
--
-- Roda: love . preview_button_border
-- Saída: button_border_cmp.png no diretório de save do LÖVE.

local M = {}

local Button      = require("components.Button")
local PixelCanvas = require("src.ui.PixelCanvas")
local Palette     = require("src.ui.Palette")

local ZOOM = 6
local BW, BH = 150, 34

-- Reprodução FIEL do traço interno como era antes do fix (Button.lua:451-454
-- no commit anterior): rectangle("line") QUADRADO, ancorado em .5.
local function drawLegacyInner(x, y, w, h, border)
    love.graphics.setColor(border[1] * 0.55, border[2] * 0.55, border[3] * 0.55, 0.8)
    love.graphics.rectangle("line", x + 2.5, y + 2.5, w - 5, h - 5)
    love.graphics.setColor(1, 1, 1, 1)
end

function M.run()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.i18n.I18n").init()

    local states = { "normal", "hover", "disabled" }
    local cellW, cellH = BW + 16, BH + 16
    local canvas = love.graphics.newCanvas(cellW * 2 + 24, cellH * #states + 24)
    canvas:setFilter("nearest", "nearest")

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.09, 0.075, 0.06, 1)

    for i, state in ipairs(states) do
        local y = 12 + (i - 1) * cellH + 8
        for col = 1, 2 do
            local x = 12 + (col - 1) * cellW + 8
            local btn = Button:new(x, y, BW, BH, state:upper(), function() end, nil, 10)
            btn.hover    = (state == "hover")
            btn.disabled = (state == "disabled")
            btn:draw()
            -- Coluna 1 = ANTES: repinta o traço interno legado por cima. A
            -- borda nova fica embaixo, mas o legado é mais claro e grosso, e
            -- é exatamente a camada em disputa — é ela que se quer comparar.
            if col == 1 then
                local c = { Palette.AGED_GOLD[1], Palette.AGED_GOLD[2], Palette.AGED_GOLD[3] }
                if state == "disabled" then c = { 0.35, 0.32, 0.28 } end
                drawLegacyInner(math.floor(x), math.floor(y), BW, BH, c)
            end
        end
    end
    love.graphics.setCanvas()

    -- Amplia com nearest pra inspeção 1:ZOOM.
    local W, H = canvas:getWidth() * ZOOM, canvas:getHeight() * ZOOM
    local big = love.graphics.newCanvas(W, H)
    big:setFilter("nearest", "nearest")
    love.graphics.setCanvas(big)
    love.graphics.clear(0.09, 0.075, 0.06, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0, 0, ZOOM, ZOOM)
    love.graphics.setCanvas()

    big:newImageData():encode("png", "button_border_cmp.png")
    print("[preview_button_border] ANTES = coluna esquerda | DEPOIS = coluna direita")
    print("[preview_button_border] button_border_cmp.png")
    love.event.quit()
    return true
end

return M
