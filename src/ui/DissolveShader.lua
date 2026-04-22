-- src/ui/DissolveShader.lua
-- Wrapper do shaders/dissolve.glsl. Faz uma imagem "queimar" gradualmente
-- com uma mask de noise field + borda colorida (burn colours).
--
-- Uso canônico em Card:draw (já integrado se self.dissolve > 0):
--   DissolveShader.apply(cardImage, dissolve, burnColors)
--   love.graphics.draw(cardImage, x, y, ...)
--   DissolveShader.clear()
--
-- Ou direto:
--   DissolveShader.draw(image, x, y, dissolveAmount, burnColors)
--
-- dissolve = 0 → carta visível normal
-- dissolve = 0.5 → meio queimada, borda de queima no meio
-- dissolve = 1 → sumiu totalmente
--
-- burnColors: {c1, c2} — cada c = {r, g, b, a} em [0..1]. Default: laranja/vermelho.

local DissolveShader = {}

local shader
local loaded = false

-- Defaults: queima quente estilo papel pegando fogo
local DEFAULT_BURN_1 = {1.0, 0.55, 0.05, 1.0}  -- laranja vivo
local DEFAULT_BURN_2 = {0.85, 0.12, 0.02, 1.0} -- vermelho escuro

function DissolveShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/dissolve.glsl")
    if not ok then
        print("[DissolveShader] falha ao carregar shaders/dissolve.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function DissolveShader.isAvailable()
    return loaded
end

-- Seta o shader como ativo e envia uniforms. Chame antes do love.graphics.draw
-- e DissolveShader.clear() depois.
function DissolveShader.apply(image, dissolve, burnColors, isShadow)
    if not loaded then return false end
    dissolve = math.max(0, math.min(1, dissolve or 0))
    burnColors = burnColors or {DEFAULT_BURN_1, DEFAULT_BURN_2}

    love.graphics.setShader(shader)
    shader:send("dissolve", dissolve)
    shader:send("time", love.timer.getTime())

    local w = image:getWidth()
    local h = image:getHeight()
    -- texture_details: (offset_x, offset_y, size_x, size_y) em unidades UV
    -- do atlas; pra textura inteira, offset=0 e size=w,h em pixels.
    shader:send("texture_details", {0, 0, w, h})
    shader:send("image_details", {w, h})

    local c1 = burnColors[1] or DEFAULT_BURN_1
    local c2 = burnColors[2] or {0, 0, 0, 0} -- sem c2 = sem banda secundária
    shader:send("burn_colour_1", c1)
    shader:send("burn_colour_2", c2)
    shader:send("shadow", isShadow and true or false)
    return true
end

function DissolveShader.clear()
    love.graphics.setShader()
end

-- Helper all-in-one: apply → draw → clear.
function DissolveShader.draw(image, x, y, dissolve, burnColors, r, sx, sy, ox, oy)
    if not DissolveShader.apply(image, dissolve, burnColors) then
        love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    DissolveShader.clear()
end

-- Paletas canônicas por tipo de carta (mesma filosofia do Balatro).
-- Use em Card:start_dissolve(DissolveShader.palette("attack"))
function DissolveShader.palette(kind)
    local palettes = {
        attack    = {{0.85, 0.12, 0.02, 1.0}, {1.0, 0.55, 0.05, 1.0}},  -- vermelho/laranja
        defense   = {{0.25, 0.45, 0.85, 1.0}, {0.70, 0.85, 1.00, 1.0}}, -- azul/ciano
        joker     = {{1.0, 0.85, 0.20, 1.0},  {0.85, 0.55, 0.10, 1.0}}, -- dourado
        effect    = {{0.35, 0.80, 0.35, 1.0}, {0.85, 1.00, 0.60, 1.0}}, -- verde
        booster   = {{0.55, 0.30, 0.85, 1.0}, {0.95, 0.65, 0.95, 1.0}}, -- roxo/magenta
        exhaust   = {{0.10, 0.10, 0.10, 1.0}, {0.40, 0.20, 0.20, 1.0}}, -- preto/cinza
        default   = {{0.65, 0.45, 0.15, 1.0}, {0.90, 0.75, 0.35, 1.0}}, -- sépia
    }
    return palettes[kind] or palettes.default
end

return DissolveShader
