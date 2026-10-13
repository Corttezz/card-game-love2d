-- src/ui/HoloShader.lua
-- Wrapper do shader holográfico para cartas (rare/legendary).
-- Aplicado seletivamente: ao desenhar uma carta com effect="holo" ou "glow" raro,
-- chama HoloShader.draw(image, x, y, strength).

local HoloShader = {}

local shader
local loaded = false

function HoloShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/holo.glsl")
    if not ok then
        print("[HoloShader] falha ao carregar shaders/holo.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    return true
end

function HoloShader.isAvailable()
    return loaded
end

-- Desenha uma imagem aplicando o reflexo com a intensidade dada.
-- Uso: HoloShader.draw(cardCanvas, x, y, 0.5, 0, 1, 1, 0, 0, { kind = 1, anim = hover })
--   opts.kind: 0 = rara (prata-azulado), 1 = lendária (dourado prismático)
--   opts.anim: 0..1 — a faixa de varredura só existe/move com anim > 0
--              (hover/selecionada); em repouso a carta é ESTÁTICA.
-- strength < 0.005 desenha a carta crua (sem shader): pixel-a-pixel igual.
function HoloShader.draw(image, x, y, strength, rotation, sx, sy, ox, oy, opts)
    strength = math.max(0, math.min(1, strength or 0.5))
    if not loaded or strength < 0.005 then
        love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    local anim = opts and opts.anim or 0
    love.graphics.setShader(shader)
    shader:send("time", anim > 0 and love.timer.getTime() or 0)
    shader:send("strength", strength)
    shader:send("kind", opts and opts.kind or 1)
    shader:send("anim", math.max(0, math.min(1, anim)))
    shader:send("cardSize", { image:getWidth(), image:getHeight() })
    love.graphics.draw(image, x, y, rotation or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    love.graphics.setShader()
end

-- Força do reflexo por raridade/gate (fonte ÚNICA pra Card:draw e testes):
-- rara 0 → 0.25 no hover; lendária 0.08 em repouso → 0.5 no hover.
HoloShader.REST = { glow = 0, holo = 0.08 }
HoloShader.FULL = { glow = 0.25, holo = 0.5 }
function HoloShader.strengthFor(fx, gate)
    local rest, full = HoloShader.REST[fx] or 0, HoloShader.FULL[fx] or 0
    gate = math.max(0, math.min(1, gate or 0))
    return rest + (full - rest) * gate
end

return HoloShader
