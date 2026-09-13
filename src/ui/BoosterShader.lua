-- src/ui/BoosterShader.lua
-- Wrapper do shaders/booster.glsl. Aplica textura iridescente azul-prata
-- animada sobre uma imagem de carta — usado em "cartas seladas" / pacotes.
--
-- Uso:
--   BoosterShader.apply(image, phase, dissolve)                 -- arco-íris neutro
--   BoosterShader.apply(image, phase, dissolve, sheen, amount)  -- tingido
--   love.graphics.draw(image, ...)
--   BoosterShader.clear()
--
-- phase: number (fase da animação iridescente; passe love.timer.getTime()
--        pra animação contínua, ou um valor fixo pra freeze)
-- dissolve: 0..1 — combina com dissolve mask (opcional, default 0)
-- sheen: {r,g,b} — cor dominante do TIPO de pacote (PackThemes.<kind>.glow).
--        Sem ela os 5 pacotes brilham idênticos e a identidade da arte se
--        perde no arco-íris genérico.
-- amount: 0..1 — quanto a iridescência é puxada pro sheen (default 0 =
--        comportamento original, pra não mudar quem chamava com 3 args).

local BoosterShader = {}

local shader
local loaded = false
local hasSheen = false   -- o GLSL carregado expõe os uniforms de tint?

local WHITE = {1, 1, 1}

function BoosterShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/booster.glsl")
    if not ok then
        print("[BoosterShader] falha ao carregar shaders/booster.glsl: " .. tostring(s))
        return false
    end
    shader = s
    loaded = true
    -- Uniform ausente (shader antigo / compilador removeu) faria `send` dar
    -- erro em TODO frame — checa uma vez e decide aqui.
    hasSheen = (s.hasUniform ~= nil)
        and s:hasUniform("sheen") and s:hasUniform("sheen_amt")
    -- Só avisa na ANOMALIA. O silêncio aqui já custou caro uma vez: um erro de
    -- compilação no GLSL derruba o shader inteiro e o sleeve degrada calado pra
    -- "sem foil", que é difícil de distinguir de "foil sutil demais".
    if not hasSheen then
        print("[BoosterShader] AVISO: shader sem os uniforms de sheen — o foil "
            .. "vai sair no arco-íris genérico, sem a cor do tipo de pacote.")
    end
    return true
end

function BoosterShader.isAvailable()
    return loaded
end

function BoosterShader.apply(image, phase, dissolve, sheen, amount)
    if not loaded then return false end
    love.graphics.setShader(shader)
    shader:send("booster", {phase or love.timer.getTime(), 0})
    shader:send("dissolve", dissolve or 0)
    shader:send("time", love.timer.getTime())
    shader:send("texture_details", {0, 0, image:getWidth(), image:getHeight()})
    shader:send("image_details", {image:getWidth(), image:getHeight()})
    shader:send("burn_colour_1", {0, 0, 0, 0})
    shader:send("burn_colour_2", {0, 0, 0, 0})
    shader:send("shadow", false)
    if hasSheen then
        shader:send("sheen", sheen or WHITE)
        shader:send("sheen_amt", amount or 0)
    end
    return true
end

function BoosterShader.clear()
    love.graphics.setShader()
end

function BoosterShader.draw(image, x, y, phase, dissolve, r, sx, sy, ox, oy)
    if not BoosterShader.apply(image, phase, dissolve) then
        love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
        return
    end
    love.graphics.draw(image, x, y, r or 0, sx or 1, sy or 1, ox or 0, oy or 0)
    BoosterShader.clear()
end

return BoosterShader
