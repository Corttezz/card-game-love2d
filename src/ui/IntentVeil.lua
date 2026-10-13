-- src/ui/IntentVeil.lua
-- Véu de névoa desenhado SOBRE o box do intent quando a visibilidade não é
-- cheia (src/systems/IntentVisibility.lua). É a metade de UI da leitura: a
-- outra metade é o mundo (o WeatherEngine engrossa a nevasca pelo mesmo
-- estado). O véu existe porque o "?" sozinho lê como bug de dado; com bruma
-- correndo por cima, lê como clima.
--
-- Estilo: bruma em PIXEL de arte (textura de ruído 64x32 em nearest, duas
-- camadas correndo em sentidos opostos, quantizadas em passos de 2 px),
-- tingida pela cor do bioma. Nada de gradiente liso.
--
-- Transições: a opacidade persegue o alvo do nível (~0,25 s). Quando o véu
-- CAI (carta de Revelar, clareira), um aro claro pisca uma vez — o jogador
-- precisa ver que a leitura voltou, não só perceber depois.
--
--   IntentVeil.draw(x, y, w, h, level, color, key)
--   IntentVeil.alphaFor(level)        -- alvo por nível (fonte única)
--   IntentVeil.reset()

local IntentVeil = {}

local ALPHA = { full = 0, type_only = 0.52, hidden = 0.78 }
IntentVeil.ALPHA = ALPHA

local TEX_W, TEX_H = 64, 32
local img = nil
local quadA, quadB = nil, nil

-- ruído de valor com hash inteiro (sem love.math.noise: queremos pixel duro)
local function hash(x, y)
    local n = x * 374761393 + y * 668265263
    n = (n % 4294967296)
    n = (n * 1274126177) % 4294967296
    return (n % 1000) / 1000
end
local function vnoise(x, y)
    local xi, yi = math.floor(x), math.floor(y)
    local fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    local a, b = hash(xi, yi), hash(xi + 1, yi)
    local c, d = hash(xi, yi + 1), hash(xi + 1, yi + 1)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
end

local function build()
    local data = love.image.newImageData(TEX_W, TEX_H)
    for y = 0, TEX_H - 1 do
        for x = 0, TEX_W - 1 do
            -- tileável no eixo X (período = TEX_W), aberto em Y
            local u = x / TEX_W
            local n = 0.55 * vnoise(u * 6, y / 9) + 0.30 * vnoise(u * 13 + 7, y / 5 + 3)
                + 0.15 * vnoise(u * 27 + 2, y / 3 + 9)
            -- costura X: mistura com a amostra deslocada um período
            local n2 = 0.55 * vnoise((u + 1) * 6, y / 9) + 0.30 * vnoise((u + 1) * 13 + 7, y / 5 + 3)
                + 0.15 * vnoise((u + 1) * 27 + 2, y / 3 + 9)
            n = n * (1 - u) + n2 * u
            -- posteriza em 4 degraus: bruma de pixel art, não gradiente
            local a = math.floor(math.max(0, (n - 0.35) / 0.45) * 4 + 0.5) / 4
            data:setPixel(x, y, 1, 1, 1, math.min(1, a))
        end
    end
    img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "clamp")
    quadA = love.graphics.newQuad(0, 0, TEX_W * 3, TEX_H, TEX_W, TEX_H)
    quadB = love.graphics.newQuad(0, 0, TEX_W * 3, TEX_H, TEX_W, TEX_H)
end

-- estado de transição por chave (o inimigo): opacidade corrente + flash
local states = setmetatable({}, { __mode = "k" })
-- O estado NASCE no alvo: o véu de um anúncio já encoberto aparece inteiro
-- no 1º quadro (capturas de um quadro só e a chegada do inimigo); só as
-- TROCAS de nível são eased.
local function stateFor(key, target)
    key = key or IntentVeil
    local s = states[key]
    if not s then
        s = { a = target or 0, t = love.timer.getTime(), flash = 0 }
        states[key] = s
    end
    return s
end

function IntentVeil.alphaFor(level)
    return ALPHA[level] or 0
end

function IntentVeil.reset()
    states = setmetatable({}, { __mode = "k" })
end

-- Opacidade corrente do véu de `key` (0 = sem véu). Pra testes e pra quem
-- quer saber se há névoa visível sobre o box.
function IntentVeil.currentAlpha(key)
    local s = states[key or IntentVeil]
    return s and s.a or 0
end

function IntentVeil.draw(x, y, w, h, level, color, key)
    local target = ALPHA[level] or 0
    local s = stateFor(key, target)
    local now = love.timer.getTime()
    local dt = math.min(0.1, math.max(0, now - s.t))
    s.t = now
    local rm = _G.gameSettings and _G.gameSettings.reducedMotion
    -- caiu de um nível encoberto pra cheio: pisca o aro (a leitura voltou)
    if target < s.a - 0.25 and s.flash <= 0 then s.flash = 0.45 end
    s.a = s.a + (target - s.a) * math.min(1, dt * 4)
    if math.abs(s.a - target) < 0.01 then s.a = target end
    s.flash = math.max(0, s.flash - dt)

    if s.a <= 0.01 and s.flash <= 0 then return end
    if not img then build() end
    color = color or { 0.8, 0.85, 0.95 }

    -- recorta ao box (cantos arredondados do EnemyHud ficam por conta da
    -- margem de 2 px)
    love.graphics.push("all")
    love.graphics.setScissor(math.floor(x + 2), math.floor(y + 2), math.floor(w - 4), math.floor(h - 4))
    if s.a > 0.01 then
        local sy = h / TEX_H
        -- duas camadas, sentidos opostos, deslocamento quantizado em 2 px
        local k = rm and 0 or 1
        local offA = math.floor((now * 9 * k) % TEX_W / 2) * 2
        local offB = math.floor((now * 5 * k) % TEX_W / 2) * 2
        love.graphics.setColor(color[1], color[2], color[3], s.a * 0.85)
        love.graphics.draw(img, quadA, x - TEX_W + offA - (offA % 2), y, 0, 1, sy)
        love.graphics.setColor(color[1] * 0.9 + 0.1, color[2] * 0.9 + 0.1, color[3] * 0.9 + 0.1, s.a * 0.6)
        love.graphics.draw(img, quadB, x - TEX_W * 2 + (TEX_W - offB), y + 3, 0, 1, sy * 0.9)
        -- lavagem uniforme: a bruma também baixa o contraste do que está atrás
        love.graphics.setColor(color[1], color[2], color[3], s.a * 0.28)
        love.graphics.rectangle("fill", x, y, w, h)
    end
    love.graphics.setScissor()
    if s.flash > 0 then
        local f = s.flash / 0.45
        love.graphics.setColor(1, 1, 0.96, 0.85 * f)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 1, y - 1, w + 2, h + 2, 5, 5)
    end
    love.graphics.pop()
end

return IntentVeil
