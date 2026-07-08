-- engine/LightEngine.lua
-- Motor de iluminação 2D da cena (WorldRoad; futuro: interiores).
-- Plano completo: docs/plan/lighting-engine-v1.md · memória: memory/lighting_engine.md
--
-- PIPELINE (padrão Luven/Stardew, temperado pelas regras de pixel art do projeto):
--   canvas 1/4 res nearest (rgba8) limpo com a cor ambiente do bioma (ALPHA=1 —
--   multiply também multiplica o alpha do destino) → luzes acumuladas com blend
--   "add" (falloff (1-d²)² posterizado em degraus + dither Bayer só nas poças de
--   chão; micro-luzes como sprite radial de 2 degraus, sem shader) → composto
--   sobre a cena com "multiply"/"premultiplied" + setScissor na área do mundo.
--
-- MULTIPLY-ONLY: o lightmap tem teto 1.0 (rgba8) — o motor só escurece em
-- direção ao ambiente e "devolve" a arte original perto das luzes; nunca cria
-- cor acima do que o artista pintou (lição v6/v7: aditivo sobre sprite = franja).
-- ZERO stencil (driver NVIDIA).
--
-- Coordenadas: submits recebem coords de TELA — quem chama de dentro de um
-- transform (room sway / screen shake) converte com love.graphics.transformPoint.
-- O composite desenha com origin(), então lightmap e cena casam por construção.

local LightEngine = {}

LightEngine.SCALE = 4          -- 1 texel de luz = 4px de tela (~pixel lógico)
LightEngine.debugAmbientScale = 1   -- teclas O/P do demo_worldroad (calibração)

local MAX_LIGHTS = 16          -- fila com shader (poças/fontes médias)
local MAX_MICRO  = 64          -- fila de micro-pontos (vagalumes/chamas/janelas)

local canvas                    -- lightmap 1/4 res (lazy, recriado no resize)
local whiteImg                  -- 2x2 branca: quad com UV [0,1] pro shader
local microImg                  -- radial 16x16 com 2 degraus ASSADOS no alpha
local shader                    -- shaders/light_dither.glsl
local occShader                 -- shaders/occluder.glsl (silhueta chapada)
local shaderOk = nil            -- nil = ainda não tentou; false = falhou (no-op)

local queue, microQueue, occQueue = {}, {}, {}
local frameActive = false
local ambient = { 1, 1, 1 }
local time = 0
local enabledOverride = nil     -- setEnabled(true/false); nil = segue settings

local MAX_OCC = 64              -- oclusores por frame (árvores + inimigo)

-- ============================================================================
-- Estado / settings
-- ============================================================================

-- Habilitado se: override setado → override; senão settings persistidos
-- (_G.gameSettings.lighting, backfill default true); senão true (tools).
local function isEnabled()
    if enabledOverride ~= nil then return enabledOverride end
    local gs = _G.gameSettings
    if gs ~= nil and gs.lighting == false then return false end
    return true
end

function LightEngine.setEnabled(v) enabledOverride = v end
function LightEngine.isEnabled() return isEnabled() end

local function lumaOf(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end

-- Luminância do ambiente do frame corrente (0..1) — usado pra gatear
-- vagalumes/efeitos "de escuro" no WorldRoad.
function LightEngine.ambientLuma()
    if not isEnabled() then return 1 end
    return lumaOf(ambient)
end

function LightEngine.update(dt)
    time = time + dt
end

-- ============================================================================
-- Recursos (criados 1x; canvas recriado lazily no resize — padrão CRTShader)
-- ============================================================================

local function ensureResources()
    local W, H = love.graphics.getDimensions()
    local S = LightEngine.SCALE
    local cw, ch = math.ceil(W / S), math.ceil(H / S)
    if not canvas or canvas:getWidth() ~= cw or canvas:getHeight() ~= ch then
        canvas = love.graphics.newCanvas(cw, ch, { format = "rgba8" })
        canvas:setFilter("nearest", "nearest")
    end
    if not whiteImg then
        local d = love.image.newImageData(2, 2)
        d:mapPixel(function() return 1, 1, 1, 1 end)
        whiteImg = love.graphics.newImage(d)
        whiteImg:setFilter("nearest", "nearest")
    end
    if not microImg then
        -- radial 16x16 com 2 degraus assados NO ALPHA (rgb branco): com blend
        -- add+alphamultiply o que soma é rgb*alpha → núcleo cheio + anel 45%
        local d = love.image.newImageData(16, 16)
        d:mapPixel(function(px, py)
            local dx, dy = (px - 7.5) / 7.5, (py - 7.5) / 7.5
            local d2 = dx * dx + dy * dy
            if d2 <= 0.30 then return 1, 1, 1, 1 end
            if d2 <= 1.00 then return 1, 1, 1, 0.45 end
            return 0, 0, 0, 0
        end)
        microImg = love.graphics.newImage(d)
        microImg:setFilter("nearest", "nearest")
    end
    if shaderOk == nil then
        local ok, sh = pcall(function()
            return love.graphics.newShader("shaders/light_dither.glsl")
        end)
        if ok and sh then
            shader = sh
            shaderOk = true
        else
            shaderOk = false
            print("[LightEngine] shader light_dither falhou: " .. tostring(sh)
                .. " — luzes grandes caem no fallback de micro-sprite")
        end
        -- shader de oclusor: silhueta CHAPADA (só alpha) — corrige o
        -- esmagamento (sprite × sprite) que escurecia monstro/árvores
        local ok2, sh2 = pcall(function()
            return love.graphics.newShader("shaders/occluder.glsl")
        end)
        if ok2 and sh2 then occShader = sh2 end
    end
end

-- ============================================================================
-- Frame de luz
-- ============================================================================

-- ambient = {r,g,b} JÁ lerpado pelo crossfade de bioma (envColor).
function LightEngine.beginFrame(amb)
    if not isEnabled() or not amb then
        frameActive = false
        return
    end
    local k = LightEngine.debugAmbientScale
    ambient[1] = math.min(1, (amb[1] or 1) * k)
    ambient[2] = math.min(1, (amb[2] or 1) * k)
    ambient[3] = math.min(1, (amb[3] or 1) * k)
    for i = #queue, 1, -1 do queue[i] = nil end
    for i = #microQueue, 1, -1 do microQueue[i] = nil end
    for i = #occQueue, 1, -1 do occQueue[i] = nil end
    frameActive = true
end

-- Luz com shader (poça de chão / fonte média).
-- spec = { x, y, radius, color={r,g,b}, intensity=0..1, dither=bool,
--          levels=n (default 4; 2 pra luz pequena/horizonte),
--          flicker=nil|"fire"|"pulse", seed=n }
function LightEngine.submit(spec)
    if not frameActive then return end
    local inten = spec.intensity or 1
    local radius = spec.radius or 100
    if spec.flicker == "fire" then
        -- noise 2 oitavas (contínuo, orgânico) — nunca random puro
        local seed = (spec.seed or 0) % 1000
        local n = love.math.noise(time * 1.8, seed) * 0.7
            + love.math.noise(time * 8.0, seed + 37.2) * 0.3
        radius = radius * (0.88 + 0.24 * n)
        inten = inten * (0.85 + 0.15 * n)
    elseif spec.flicker == "pulse" then
        inten = inten * (0.88 + 0.12 * math.sin(time * 1.7 + (spec.seed or 0)))
    end
    local entry = {
        x = spec.x, y = spec.y, r = radius,
        color = spec.color or { 1, 1, 1 },
        i = inten,
        dither = spec.dither and 1 or 0,
        ditherAmt = spec.ditherAmt or 1.0,
        levels = spec.levels or 4,
        -- profundidade (rel de mundo): luzes mais FUNDAS são desenhadas
        -- primeiro e podem ser ocluídas por silhuetas mais próximas.
        -- Default -1 = coladas na câmera (nunca ocluídas).
        z = spec.z or -1,
    }
    if #queue < MAX_LIGHTS then
        queue[#queue + 1] = entry
    else
        -- overflow: substitui a luz mais fraca (raio×intensidade), nunca
        -- descarta por ordem de submit (política do plano §5.3)
        local wi, ww = nil, entry.r * entry.i
        for qi, q in ipairs(queue) do
            local qw = q.r * q.i
            if qw < ww then wi, ww = qi, qw end
        end
        if wi then queue[wi] = entry end
    end
end

-- Micro-luz: ponto raio 4-12px sem shader (vagalume/chama/janela).
-- O "glow" É o de-escurecimento local — halo pequeno sobre fundo escuro.
function LightEngine.submitMicro(x, y, radius, color, intensity, z)
    if not frameActive then return end
    if #microQueue >= MAX_MICRO then return end
    microQueue[#microQueue + 1] = {
        x = x, y = y, r = radius or 8,
        color = color or { 1, 1, 1 }, i = intensity or 1,
        z = z or -1, micro = true,
    }
end

-- OCLUSOR por silhueta (pedido do usuário: luz atrás de um corpo não vaza
-- por cima dele — monstro na frente do portão, árvore na frente da poça).
-- A silhueta do sprite é desenhada NO LIGHTMAP com a cor ambiente, na ordem
-- de profundidade: luzes mais fundas (z maior) → silhueta → luzes mais
-- próximas. Bloqueio pixel-perfeito, zero stencil; uma lanterna na FRENTE
-- do corpo continua iluminando ele.
-- o = { z,                       -- profundidade (rel); oclui luzes com z maior
--       bx, by, w, h,            -- bounds na tela (culling)
--       img, x, y, rot, sx, sy, ox, oy   -- sprite (coords de TELA)
--       OU fn = function() ... end }     -- draw custom (anim do inimigo)
function LightEngine.submitOccluder(o)
    if not frameActive then return end
    if #occQueue >= MAX_OCC then return end
    occQueue[#occQueue + 1] = o
end

-- Tint compensado p/ superfícies difusas desenhadas antes do composite
-- (SÓ acentos pontuais — nunca sprites inteiros). Fator ÚNICO por luma
-- (nunca por canal — preserva matiz), teto 1/0.55.
function LightEngine.tintCompensate(r, g, b)
    if not frameActive then return r, g, b end
    local k = math.min(1 / 0.55, 1 / math.max(0.55, lumaOf(ambient)))
    return math.min(1, r * k), math.min(1, g * k), math.min(1, b * k)
end

-- Composite: desenha o lightmap e multiplica sobre a região (x,y,w,h).
-- GUARD: sem beginFrame neste frame (interiores, caminho esquecido) = no-op.
function LightEngine.composite(x, y, w, h)
    if not frameActive then return end
    frameActive = false
    -- ambiente ~branco e nenhuma luz: frame idêntico, pula tudo (aceite F0)
    if lumaOf(ambient) > 0.985 and ambient[1] > 0.97 and ambient[2] > 0.97
       and ambient[3] > 0.97 and #queue == 0 and #microQueue == 0 then
        return
    end
    ensureResources()

    local prevCanvas = love.graphics.getCanvas()
    local S = LightEngine.SCALE

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()

    -- 1) lightmap: ambiente + PAINTER de luzes/oclusores por profundidade.
    -- Ordem: z DESC (fundo primeiro). Luz funda → silhueta oclusora →
    -- luz próxima: a silhueta apaga (volta ao ambiente) a luz que vinha
    -- de trás dela; luzes na frente ainda a iluminam.
    love.graphics.setCanvas(canvas)
    love.graphics.clear(ambient[1], ambient[2], ambient[3], 1)

    -- culling de oclusores: só entra quem tem alguma luz MAIS FUNDA
    -- encostando no seu retângulo (senão pintar ambiente sobre ambiente)
    local lights = {}
    for _, l in ipairs(queue) do lights[#lights + 1] = l end
    for _, m in ipairs(microQueue) do lights[#lights + 1] = m end
    local entries = {}
    for _, l in ipairs(lights) do entries[#entries + 1] = l end
    for _, o in ipairs(occQueue) do
        local hit = false
        -- testa SÓ contra luzes (oclusores já aceitos não têm raio)
        for _, l in ipairs(lights) do
            if l.z > o.z then
                local cx2 = math.max(o.bx, math.min(l.x, o.bx + o.w))
                local cy2 = math.max(o.by, math.min(l.y, o.by + o.h))
                local dx, dy = l.x - cx2, l.y - cy2
                if dx * dx + dy * dy <= l.r * l.r then hit = true; break end
            end
        end
        -- oclusor com lift SEMPRE pinta (levanta o dono mesmo sem luz atrás)
        if hit or o.lift then o.occ = true; entries[#entries + 1] = o end
    end
    table.sort(entries, function(a, b)
        if a.z ~= b.z then return a.z > b.z end
        -- mesmo z: oclusor primeiro (luz no mesmo plano não é bloqueada)
        return (a.occ and 0 or 1) < (b.occ and 0 or 1)
    end)

    local mw = microImg and microImg:getWidth() or 16
    local ww = whiteImg and whiteImg:getWidth() or 2
    love.graphics.setBlendMode("add", "alphamultiply")
    for _, e in ipairs(entries) do
        if e.occ then
            -- silhueta CHAPADA: o shader usa SÓ o alpha da textura e pinta
            -- cor flat (ambiente, ou ambiente×lift). ANTES desenhava o
            -- sprite com setColor → multiplicava ambiente × cor-do-sprite,
            -- e o multiply final virava sprite² (partes escuras do monstro/
            -- árvore esmagavam pra quase preto). setColor branco: com o
            -- shader a cor vem do uniform `flat`.
            love.graphics.setBlendMode("alpha", "alphamultiply")
            local cr, cg, cb = ambient[1], ambient[2], ambient[3]
            if e.lift then
                cr = math.min(1, cr * e.lift)
                cg = math.min(1, cg * e.lift)
                cb = math.min(1, cb * e.lift)
            end
            love.graphics.setColor(1, 1, 1, 1)
            if occShader then
                love.graphics.setShader(occShader)
                occShader:send("flat", { cr, cg, cb })
            else
                love.graphics.setShader()
                love.graphics.setColor(cr, cg, cb, 1)  -- fallback (bug antigo)
            end
            if e.fn then
                love.graphics.push()
                love.graphics.scale(1 / S)
                e.fn()
                love.graphics.pop()
            else
                love.graphics.draw(e.img, e.x / S, e.y / S, e.rot or 0,
                    (e.sx or 1) / S, (e.sy or e.sx or 1) / S,
                    e.ox or 0, e.oy or 0)
            end
            love.graphics.setShader()
            love.graphics.setBlendMode("add", "alphamultiply")
        elseif e.micro then
            love.graphics.setShader()
            local sc = (e.r * 2 / S) / mw
            love.graphics.setColor(e.color[1] * e.i, e.color[2] * e.i,
                e.color[3] * e.i, 1)
            love.graphics.draw(microImg, math.floor(e.x / S),
                math.floor(e.y / S), 0, sc, sc, mw / 2, mw / 2)
        else
            if shaderOk then
                love.graphics.setShader(shader)
                shader:send("levels", e.levels)
                shader:send("useDither", e.dither)
                shader:send("ditherAmt", e.ditherAmt)
                shader:send("intensity", e.i)
                love.graphics.setColor(e.color[1], e.color[2], e.color[3], 1)
                local sc = (e.r * 2 / S) / ww
                love.graphics.draw(whiteImg, math.floor(e.x / S),
                    math.floor(e.y / S), 0, sc, sc, ww / 2, ww / 2)
            else
                -- fallback sem shader: sprite radial (2 degraus, sem dither)
                love.graphics.setShader()
                local sc = (e.r * 2 / S) / mw
                love.graphics.setColor(e.color[1] * e.i, e.color[2] * e.i,
                    e.color[3] * e.i, 1)
                love.graphics.draw(microImg, math.floor(e.x / S),
                    math.floor(e.y / S), 0, sc, sc, mw / 2, mw / 2)
            end
        end
    end
    love.graphics.setShader()

    -- 2) composição multiply/premultiplied sobre a cena (recortada à área)
    love.graphics.setCanvas(prevCanvas)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor(x, y, w, h)
    love.graphics.draw(canvas, 0, 0, 0, S, S)

    love.graphics.pop()   -- restaura blend/scissor/shader/cor/transform
    love.graphics.setColor(1, 1, 1, 1)
end

return LightEngine
