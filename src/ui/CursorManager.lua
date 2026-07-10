-- src/ui/CursorManager.lua
-- Cursor CUSTOMIZADO pixel-art (estilo grimório — ouro envelhecido + tinta).
-- O cursor do SO é escondido (love.mouse.setVisible(false) no load) e o
-- sprite desenha por software no FIM do love.draw, DENTRO da cena CRT —
-- assim ele sofre o warp/scanline do tubo junto com o mundo (Balatro).
--
-- Estados:
--   "arrow" (default) — seta dourada com outline ink
--   "hand"            — mão apontando (hover em qualquer clicável)
-- Quem sabe do hover PEDE o estado por frame: CursorManager.request("hand")
-- (Button/Card/fork chamam no update). draw() consome e reseta pro default.
-- Pressionado (mouse down): desloca 1px e escurece de leve — feedback tátil.

local Palette = require("src.ui.Palette")

local CursorManager = {}

local images = {}          -- name -> { img, hx, hy }  (hotspot em px da arte)
local want = "arrow"       -- estado pedido neste frame
local loaded = false

-- Paleta de células das matrizes (24×26):
--   . transparente | I ink | B osso (corpo) | L luz quente | D sombra | G ouro
local COLORS = {
    I = Palette.INK,
    B = Palette.PARCHMENT_LIGHT,        -- corpo osso/pergaminho (alto contraste)
    L = { 1.0, 0.957, 0.839 },          -- highlight quente (borda topo/esquerda)
    D = { 0.659, 0.541, 0.306 },        -- sombra do corpo (borda base/direita)
    G = Palette.AGED_GOLD,              -- punho da manopla
}

-- Seta clássica RASTERIZADA POR POLÍGONO (arestas matematicamente retas —
-- a v1 era desenhada à mão e saía torta). Hipotenusa 45° exata, borda
-- esquerda vertical, rabo simétrico. Outline ink 1 célula + anel de trim:
-- luz no topo/esquerda, sombra na base/direita (leitura de volume Balatro).
local ARROW = {
    "........................",
    "..I.....................",
    ".ILI....................",
    ".ILLI...................",
    ".ILBLI..................",
    ".ILBBLI.................",
    ".ILBBBLI................",
    ".ILBBBBLI...............",
    ".ILBBBBBLI..............",
    ".ILBBBBBBLI.............",
    ".ILBBBBBBBLI............",
    ".ILBBBBBBBBLI...........",
    ".ILBBBBBBBBBLI..........",
    ".ILBBBBBBBBBBLI.........",
    ".ILBBBBBBBDDDDLI........",
    ".ILBBBDBBDIIIII.........",
    ".ILBBDILBBLI............",
    ".ILBDI.ILBDI............",
    ".ILDI..ILBDI............",
    ".ILI...ILBBLI...........",
    "..I.....ILBDI...........",
    "........ILBDLI..........",
    ".........ILII...........",
    "..........I.............",
    "........................",
    "........................",
}

-- Mão apontando (hover): indicador vertical reto, nós dos dedos dobrados,
-- vinco do polegar, e PUNHO DE MANOPLA dourado com rebites (sabor Slay the
-- Spire, paleta grimório).
local HAND = {
    "........II..............",
    ".......ILBI.............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDI............",
    ".......ILBDIIIIIIIII....",
    ".......ILBIBBDIIBBDI....",
    "......ILBBBBBBBBBBBBDI..",
    ".....ILBBBBBBBBBBBBBBDI.",
    ".....ILBDBBBBBBBBBBBBDI.",
    ".....ILBBDBBBBBBBBBBBDI.",
    ".....ILBBBDBBBBBBBBBBDI.",
    "......ILBBBBBBBBBBBBDI..",
    "......ILBBBBBBBBBBBBDI..",
    ".....IIIIIIIIIIIIIIIIII.",
    "....ILGGGGGGGGGGGGGGGGDI",
    "....ILGLGGGGLGGGGLGGGGDI",
    "....ILDDDDDDDDDDDDDDDDDI",
    ".....IIIIIIIIIIIIIIIIII.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
}

local function buildImage(matrix)
    local h = #matrix
    local wdt = #matrix[1]
    local data = love.image.newImageData(wdt, h)
    for y = 1, h do
        local row = matrix[y]
        for x = 1, wdt do
            local ch = row:sub(x, x)
            local c = COLORS[ch]
            if c then
                data:setPixel(x - 1, y - 1, c[1], c[2], c[3], 1)
            end
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

-- Carrega cursor de PNG (arte PixelLab) com hotspot por CONTEÚDO: a ponta
-- do dedo/seta = centro da primeira linha com pixel opaco. Retorna nil se
-- o arquivo não existe (caller cai na matriz).
local function loadPng(path)
    if not love.filesystem.getInfo(path) then return nil end
    local ok, data = pcall(love.image.newImageData, path)
    if not ok or not data then return nil end
    local w, h = data:getWidth(), data:getHeight()
    local hx, hy = math.floor(w / 2), 0
    for y = 0, h - 1 do
        local minX, maxX = nil, nil
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.5 then
                minX = minX or x
                maxX = x
            end
        end
        if minX then
            hx, hy = math.floor((minX + maxX) / 2), y
            break
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return { img = img, hx = hx, hy = hy }
end

function CursorManager.load()
    if loaded then return end
    images.arrow = { img = buildImage(ARROW), hx = 2, hy = 1 }   -- ponta da seta
    -- Estado "hand" DESATIVADO a pedido (Jul/2026: "deixa só o cursor
    -- normal"). Os request("hand") dos clicáveis viram no-op (o guard de
    -- request ignora estado não registrado). Pra reativar, descomente:
    -- images.hand = loadPng("assets/sprites/ui/cursor_hand.png")
    --     or { img = buildImage(HAND), hx = 9, hy = 0 }
    love.mouse.setVisible(false)
    loaded = true
end

-- Componentes clicáveis pedem o estado do frame (Button/Card/fork hover).
function CursorManager.request(name)
    if images[name] then want = name end
end

function CursorManager.draw()
    if not loaded then return end
    -- sem foco do mouse na janela: não desenha (o SO mostra o cursor dele)
    if love.window and love.window.hasMouseFocus
       and not love.window.hasMouseFocus() then
        want = "arrow"
        return
    end
    local mx, my = love.mouse.getPosition()
    local spec = images[want] or images.arrow
    want = "arrow"   -- consome o pedido; próximo frame re-pede
    -- escala responsiva (janela 768 de altura → 1.5×; 1080p → 2×), em meios
    -- passos — feedback "diminuir um pouco": 2× cheio ficava grande demais.
    -- O warp do CRT suaviza o meio-pixel do 1.5×.
    local s = math.max(1, math.floor(love.graphics.getHeight() / 256 + 0.5) / 2)
    local pressed = love.mouse.isDown(1)
    local off = pressed and s or 0        -- afunda 1 célula ao clicar
    local k = pressed and 0.86 or 1
    -- sombra dura 1 célula (leitura sobre qualquer fundo)
    love.graphics.setColor(0, 0, 0, 0.35)
    love.graphics.draw(spec.img, math.floor(mx - spec.hx * s + s + off),
        math.floor(my - spec.hy * s + s + off), 0, s, s)
    love.graphics.setColor(k, k, k, 1)
    love.graphics.draw(spec.img, math.floor(mx - spec.hx * s + off),
        math.floor(my - spec.hy * s + off), 0, s, s)
    love.graphics.setColor(1, 1, 1, 1)
end

return CursorManager
