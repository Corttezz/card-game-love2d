-- src/ui/PixelCanvas.lua
-- Primitivas de desenho pixel-perfect.
-- Toda arte procedural do jogo passa por aqui para garantir nearest-neighbor,
-- ausência de anti-aliasing e posições inteiras.
--
-- Uso típico:
--   local canvas = PixelCanvas.new(64, 96)
--   PixelCanvas.beginDraw(canvas)
--   PixelCanvas.fill(Palette.BG_DEEP)
--   PixelCanvas.drawBitmap(sword16, 0, 0, { [1]=Palette.ORANGE, [2]=Palette.YELLOW })
--   PixelCanvas.endDraw()
--   -- canvas agora é uma love Image (Canvas é drawable).

local Palette = require("src.ui.Palette")

local PixelCanvas = {}

-- ===== Setup =====

-- Chame uma vez em love.load (ou no início do módulo que cria canvases).
-- Garante filtro nearest em tudo que for criado a partir daqui.
function PixelCanvas.enableNearest()
    love.graphics.setDefaultFilter("nearest", "nearest", 0)
end

-- ===== Criação =====

-- Cria um canvas w×h pronto para receber pixel art.
function PixelCanvas.new(w, h)
    local c = love.graphics.newCanvas(w, h)
    c:setFilter("nearest", "nearest")
    return c
end

-- Estado anterior salvo entre begin/endDraw (cor + canvas + blend mode).
local _savedState = {}

-- Prepara o ambiente para desenhar num canvas (salva estado).
function PixelCanvas.beginDraw(canvas, clear)
    _savedState.canvas = love.graphics.getCanvas()
    _savedState.r, _savedState.g, _savedState.b, _savedState.a = love.graphics.getColor()
    _savedState.blend = { love.graphics.getBlendMode() }

    love.graphics.setCanvas(canvas)
    if clear ~= false then
        love.graphics.clear(0, 0, 0, 0)
    end
    -- alpha blend padrão para camadas compostas
    love.graphics.setBlendMode("alpha")
end

-- Restaura estado anterior.
function PixelCanvas.endDraw()
    love.graphics.setCanvas(_savedState.canvas)
    love.graphics.setColor(_savedState.r, _savedState.g, _savedState.b, _savedState.a)
    love.graphics.setBlendMode(unpack(_savedState.blend))
end

-- ===== Primitivas (sempre em coordenadas inteiras) =====

-- Um único pixel na cor dada.
function PixelCanvas.pixel(x, y, color)
    Palette.set(color)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), 1, 1)
end

-- Preenche o canvas atual inteiro (use dentro de beginDraw).
function PixelCanvas.fill(color)
    Palette.set(color)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getCanvas():getWidth(), love.graphics.getCanvas():getHeight())
end

-- Retângulo sólido.
function PixelCanvas.rect(x, y, w, h, color)
    Palette.set(color)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
end

-- Retângulo com outline de 1px (outline desenhado por dentro, pra não vazar).
function PixelCanvas.rectOutline(x, y, w, h, color)
    Palette.set(color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    -- 4 linhas em vez de setLineWidth (evita problemas com filter)
    love.graphics.rectangle("fill", x, y, w, 1)           -- top
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)   -- bottom
    love.graphics.rectangle("fill", x, y, 1, h)           -- left
    love.graphics.rectangle("fill", x + w - 1, y, 1, h)   -- right
end

-- Retângulo com preenchimento + outline (border no 1º arg, preenchimento no 2º).
function PixelCanvas.rectFramed(x, y, w, h, fill, outline)
    PixelCanvas.rect(x + 1, y + 1, w - 2, h - 2, fill)
    PixelCanvas.rectOutline(x, y, w, h, outline)
end

-- Retângulo sólido com cantos "cortados" (stepped corners) — silhueta arredondada
-- em pixel art. radius=1 tira 1 pixel de cada canto (plus shape), radius=2 tira
-- 2 pixels, etc. Até 3px fica legal; mais que isso vira losango.
--
-- Implementado como 2 retângulos sobrepostos (horizontal + vertical bar):
--   ████  ← y+r..y+h-r: largura total
--   ██████
--   ██████ ← y+0..y+r: largura w-2r
--   ████
function PixelCanvas.rectRounded(x, y, w, h, radius, color)
    Palette.set(color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    radius = math.max(0, math.min(math.floor(radius or 0), math.floor(math.min(w, h) / 2)))
    if radius <= 0 then
        love.graphics.rectangle("fill", x, y, w, h)
        return
    end
    -- Barra horizontal central (cobre altura total exceto os "cantos" de radius px)
    love.graphics.rectangle("fill", x, y + radius, w, h - 2 * radius)
    -- Barra vertical central (cobre largura total exceto os "cantos")
    love.graphics.rectangle("fill", x + radius, y, w - 2 * radius, h)
    -- Não precisa preencher cantos — as duas barras já cobrem o centro e as bordas.
    -- Resultado: canto cortado quadradinho (stepped), look pixel-perfect.
end

-- Outline com cantos cortados (pair com rectRounded).
function PixelCanvas.rectRoundedOutline(x, y, w, h, radius, color)
    Palette.set(color)
    x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
    radius = math.max(0, math.min(math.floor(radius or 0), math.floor(math.min(w, h) / 2)))
    if radius <= 0 then
        PixelCanvas.rectOutline(x, y, w, h, color)
        return
    end
    -- Top e bottom (horizontais), encolhidos pelos cantos
    love.graphics.rectangle("fill", x + radius, y, w - 2 * radius, 1)
    love.graphics.rectangle("fill", x + radius, y + h - 1, w - 2 * radius, 1)
    -- Left e right (verticais), encolhidos
    love.graphics.rectangle("fill", x, y + radius, 1, h - 2 * radius)
    love.graphics.rectangle("fill", x + w - 1, y + radius, 1, h - 2 * radius)
    -- Pixels diagonais nos cantos (dá o "step" visual)
    for i = 1, radius - 1 do
        -- Corners: cada pixel mais interno do canto é ainda parte do border.
        love.graphics.rectangle("fill", x + radius - i, y + i,             1, 1) -- top-left diag
        love.graphics.rectangle("fill", x + w - radius + i - 1, y + i,     1, 1) -- top-right
        love.graphics.rectangle("fill", x + radius - i, y + h - i - 1,     1, 1) -- bottom-left
        love.graphics.rectangle("fill", x + w - radius + i - 1, y + h - i - 1, 1, 1) -- bot-right
    end
end

-- Linha reta (horizontal ou vertical apenas, pra garantir pixel-perfect).
function PixelCanvas.hline(x, y, len, color)
    PixelCanvas.rect(x, y, len, 1, color)
end

function PixelCanvas.vline(x, y, len, color)
    PixelCanvas.rect(x, y, 1, len, color)
end

-- ===== Bitmap drawing (coração do sistema) =====

-- Desenha uma matriz 2D de índices de cor em (ox, oy).
-- matrix: tabela de tabelas, ex: {{0,1,0},{1,1,1},{0,1,0}}
--   0 = skip (transparente)
--   qualquer outro valor = índice em `palette` (default: Palette.INDEXED)
-- palette: tabela {[1]=color, [2]=color, ...} — default usa Palette.INDEXED
function PixelCanvas.drawBitmap(matrix, ox, oy, palette)
    palette = palette or Palette.INDEXED
    ox = math.floor(ox or 0)
    oy = math.floor(oy or 0)

    for row = 1, #matrix do
        local line = matrix[row]
        for col = 1, #line do
            local idx = line[col]
            if idx and idx ~= 0 then
                local color = palette[idx]
                if color then
                    Palette.set(color)
                    love.graphics.rectangle("fill", ox + col - 1, oy + row - 1, 1, 1)
                end
            end
        end
    end
end

-- Desenha bitmap com escala inteira (útil para "upscale" de um ícone 8×8 em 16×16 por ex).
function PixelCanvas.drawBitmapScaled(matrix, ox, oy, scale, palette)
    palette = palette or Palette.INDEXED
    ox = math.floor(ox or 0)
    oy = math.floor(oy or 0)
    scale = math.max(1, math.floor(scale or 1))

    for row = 1, #matrix do
        local line = matrix[row]
        for col = 1, #line do
            local idx = line[col]
            if idx and idx ~= 0 then
                local color = palette[idx]
                if color then
                    Palette.set(color)
                    love.graphics.rectangle("fill",
                        ox + (col - 1) * scale,
                        oy + (row - 1) * scale,
                        scale, scale)
                end
            end
        end
    end
end

-- ===== Padrões (backgrounds tileáveis) =====

-- Checker 2x2. Útil pra padrões de fundo.
function PixelCanvas.checker(x, y, w, h, colorA, colorB)
    for row = 0, h - 1 do
        for col = 0, w - 1 do
            local c = ((col + row) % 2 == 0) and colorA or colorB
            Palette.set(c)
            love.graphics.rectangle("fill", x + col, y + row, 1, 1)
        end
    end
end

-- Dithering 50% (checker) dentro de um retângulo.
function PixelCanvas.dither50(x, y, w, h, color)
    Palette.set(color)
    for row = 0, h - 1 do
        for col = 0, w - 1 do
            if (col + row) % 2 == 0 then
                love.graphics.rectangle("fill", x + col, y + row, 1, 1)
            end
        end
    end
end

-- Dithering 25% (pontos esparsos).
function PixelCanvas.dither25(x, y, w, h, color)
    Palette.set(color)
    for row = 0, h - 1, 2 do
        for col = 0, w - 1, 2 do
            love.graphics.rectangle("fill", x + col, y + row, 1, 1)
        end
    end
end

return PixelCanvas
