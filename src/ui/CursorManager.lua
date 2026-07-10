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

-- Paleta de células das matrizes (16×16):
--   . transparente | I ink | G ouro | L ouro claro | D ouro escuro
local COLORS = {
    I = Palette.INK,
    G = Palette.AGED_GOLD,
    L = Palette.AGED_GOLD_LIGHT,
    D = Palette.AGED_GOLD_DARK,
}

-- Seta clássica chunky: outline ink, corpo ouro, fio de luz na borda esquerda
local ARROW = {
    "I...............",
    "II..............",
    "ILI.............",
    "ILGI............",
    "ILGGI...........",
    "ILGGGI..........",
    "ILGGGGI.........",
    "ILGGGGGI........",
    "ILGGGGGGI.......",
    "ILGGGIIIII......",
    "ILGIDGGI........",
    "ILI.IDGGI.......",
    "II...IDGGI......",
    "I.....IDGGI.....",
    ".......IGGI.....",
    "........II......",
}

-- Mão apontando (hover em clicável): indicador estendido, punho fechado
local HAND = {
    "......II........",
    ".....ILGI.......",
    ".....ILGI.......",
    ".....ILGI.......",
    ".....ILGI.......",
    ".....ILGIIII....",
    ".....ILGIGGIII..",
    ".II..ILGGGGGGGI.",
    "ILGI.ILGGGGGGGI.",
    "ILGGIILGGGGGGGI.",
    ".ILGGGLGGGGGGGI.",
    ".ILGGGGGGGGGGDI.",
    "..ILGGGGGGGGGDI.",
    "..ILGGGGGGGGDI..",
    "...IGGGGGGGGDI..",
    "....IIIIIIIII...",
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

function CursorManager.load()
    if loaded then return end
    images.arrow = { img = buildImage(ARROW), hx = 0, hy = 0 }   -- ponta da seta
    images.hand  = { img = buildImage(HAND),  hx = 7, hy = 0 }   -- ponta do dedo
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
    -- escala responsiva (janela 768 de altura → 2×), sempre inteira (pixel)
    local s = math.max(1, math.floor(love.graphics.getHeight() / 384 + 0.5))
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
