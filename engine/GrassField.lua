-- engine/GrassField.lua
-- ============================================================================
-- GRASSFIELD — motor dedicado de vegetação rasteira (v1, Jul/2026)
-- ============================================================================
-- A BASE do cenário: lâminas de capim individuais cobrindo o terreno todo,
-- com física de vento fluida e paleta/comportamento por bioma.
--
-- TÉCNICA (pesquisa Jul/2026):
-- - Vento em 3 CAMADAS (sistema da Guerrilla/Horizon, adaptado pra 2D):
--   (1) frente de RAJADA viajando pelo campo (onda espacial que se move),
--   (2) BRISA local (senos por posição de mundo — cada tufo tem fase própria),
--   (3) JITTER de ponta (tremor rápido de baixa amplitude, cresce na rajada).
-- - Lâmina = sprite com CISALHAMENTO (kx) e pivô na RAIZ: base fixa no chão,
--   ponta desloca kx·altura (GPU Gems cap.7 / fórmula clássica de sway).
-- - Rajada também ENCURTA a lâmina (sy reduz com |lean|) — projeção 2D do
--   dobrar, truque de pixel art (Defold forum).
-- - Ponta mais clara que o corpo: BAKED no atlas em tons de cinza; o tint
--   por bioma colore corpo e ponta de uma vez (1 setColor por lâmina).
-- - TUDO num SpriteBatch: ~2000 lâminas = 1 draw call.
--
-- SEM stencil, SEM mesh, SEM alpha translúcido — pixels opacos na paleta.
--
-- USO (ver WorldRoad):
--   GrassField.draw{ x=, w=, time=, camZ=, geom=g, relCrest=,
--                    roadCenter=fn(z,t), roadHalf=fn(t),
--                    colors={light=,mid=,accent=}, biomeId="fields",
--                    forkActive=false, forkRel=10 }
-- ============================================================================

local GrassField = {}

-- ----------------------------------------------------------------------------
-- PRESETS por bioma: personalidade do capim (densidade, altura, vento).
-- Cores NÃO ficam aqui — vêm do chamador (lerpam no crossfade de bioma).
-- ----------------------------------------------------------------------------
GrassField.PRESETS = {
    --                dens  altK  vento gustA gustV dir broad flor
    fields    = { density = 1.00, heightK = 1.00, windAmp = 0.50,
                  gustAmp = 1.10, gustSpeed = 1.30, dir = 1,
                  broad = 0.10, flower = 0.10 },
    highlands = { density = 0.80, heightK = 0.90, windAmp = 0.70,
                  gustAmp = 1.40, gustSpeed = 1.80, dir = -1,
                  broad = 0.08, flower = 0.06 },   -- vento de montanha
    abyss     = { density = 0.55, heightK = 0.80, windAmp = 0.30,
                  gustAmp = 0.60, gustSpeed = 0.90, dir = 1,
                  broad = 0.05, flower = 0.08 },   -- restolho, ar parado
    frost     = { density = 0.50, heightK = 0.70, windAmp = 0.60,
                  gustAmp = 1.20, gustSpeed = 1.60, dir = -1,
                  broad = 0.06, flower = 0.05 },
    marsh     = { density = 1.15, heightK = 1.30, windAmp = 0.45,
                  gustAmp = 0.85, gustSpeed = 1.00, dir = 1,
                  broad = 0.30, flower = 0.09 },   -- juncos altos e pesados
    dusk      = { density = 0.90, heightK = 1.05, windAmp = 0.55,
                  gustAmp = 1.00, gustSpeed = 1.10, dir = -1,
                  broad = 0.12, flower = 0.12 },
}
local DEFAULT_PRESET = GrassField.PRESETS.fields

-- ----------------------------------------------------------------------------
-- ATLAS de lâminas (gerado 1x): tons de CINZA pra tintar por bioma.
-- Corpo 0.60, raiz 0.45 (aterra), ponta 1.0 (pega luz) — o tint único
-- por lâmina produz o gradiente raiz-escura→ponta-clara de graça.
-- ----------------------------------------------------------------------------
local CELL_W, CELL_H = 8, 16
local N_THIN, N_BROAD = 6, 2   -- variantes finas + largas (junco/folha)
local FLOWER_CELL = N_THIN + N_BROAD           -- índice da célula de flor
local atlasImg, quads

local function bakeAtlas()
    if atlasImg then return end
    local n = N_THIN + N_BROAD + 1
    local id = love.image.newImageData(CELL_W * n, CELL_H)
    local function put(cell, x, y, lum)
        if x >= 0 and x < CELL_W and y >= 0 and y < CELL_H then
            id:setPixel(cell * CELL_W + x, y, lum, lum, lum, 1)
        end
    end
    -- lâminas FINAS: coluna com curva própria, 2px na base, 1px no topo
    for v = 0, N_THIN - 1 do
        local rng = love.math.newRandomGenerator(1000 + v * 37)
        local len = 9 + rng:random(0, 5)                 -- 9-14 px
        local curve = (rng:random() * 2 - 1) * 2.6       -- dobra própria
        for i = 0, len - 1 do
            local fy = i / (len - 1)                     -- 0 raiz → 1 ponta
            local y = (CELL_H - 1) - i
            local x = math.floor(3.5 + curve * fy * fy + 0.5)
            local lum = 0.45 + 0.15 * math.min(1, fy * 3) -- raiz escura
            if fy > 0.78 then lum = 1.0 end               -- ponta clara
            put(v, x, y, lum)
            if fy < 0.45 then put(v, x + 1, y, lum) end   -- base 2px
        end
    end
    -- lâminas LARGAS (junco/folha): 3-4px de base, mais curvas
    for b = 0, N_BROAD - 1 do
        local v = N_THIN + b
        local rng = love.math.newRandomGenerator(2000 + b * 53)
        local len = 12 + rng:random(0, 3)
        local curve = (b == 0 and 1 or -1) * (2.2 + rng:random() * 1.4)
        for i = 0, len - 1 do
            local fy = i / (len - 1)
            local y = (CELL_H - 1) - i
            local x = math.floor(3 + curve * fy * fy + 0.5)
            local wdt = fy < 0.35 and 3 or (fy < 0.7 and 2 or 1)
            local lum = 0.42 + 0.16 * math.min(1, fy * 2.5)
            if fy > 0.82 then lum = 1.0 end
            for dx = 0, wdt - 1 do put(v, x + dx, y, lum) end
        end
    end
    -- FLOR: haste 1px + botão 3×3 no topo (tintada com a cor de ACENTO)
    do
        local v = FLOWER_CELL
        for i = 0, 8 do put(v, 3, (CELL_H - 1) - i, 0.55) end
        for dy = -1, 1 do
            for dx = -1, 1 do
                local lum = (dx == 0 and dy == 0) and 1.0 or 0.82
                put(v, 3 + dx, (CELL_H - 10) + dy, lum)
            end
        end
    end
    atlasImg = love.graphics.newImage(id)
    atlasImg:setFilter("nearest", "nearest")
    quads = {}
    for i = 0, n - 1 do
        quads[i] = love.graphics.newQuad(i * CELL_W, 0, CELL_W, CELL_H,
            CELL_W * n, CELL_H)
    end
end

local batch

-- ----------------------------------------------------------------------------
-- VENTO em 3 camadas. Fase espacial vem da POSIÇÃO DE MUNDO (nx = fração
-- horizontal da tela, wz = z absoluto do mundo) — a frente de rajada
-- ATRAVESSA o campo e o mundo rolando faz o vento "fluir" na viagem.
-- Retorna lean normalizado [-1..1]-ish (multiplicado por windAmp).
-- ----------------------------------------------------------------------------
local function windAt(nx, wz, t, P)
    local ph = nx * 5.2 + wz * 0.14
    -- (1) frente de rajada viajante: vales calmos, cristas fortes
    local front = math.sin(ph * 0.85 - t * P.gustSpeed)
    local gust = front > 0 and front * front or 0
    -- (2) brisa local: 2 senos dessincronizados por posição
    local breeze = math.sin(t * 1.35 + ph * 3.1) * 0.30
                 + math.sin(t * 0.53 + ph * 1.7) * 0.20
    -- (3) jitter de ponta: tremor rápido, cresce dentro da rajada
    local jitter = math.sin(t * 6.1 + ph * 12.7) * 0.10 * (0.35 + gust)
    return (breeze + gust * P.gustAmp + jitter) * P.windAmp * P.dir
end
GrassField.windAt = windAt   -- exposto pra outros sistemas (props, futuro)

-- hash determinístico [0,1) — população estateless (mundo-ancorada, sem
-- spawn/reciclagem: as lâminas "existem" onde a janela da câmera olha)
local function hash(a, b)
    local v = math.sin(a * 127.1 + b * 311.7) * 43758.5453
    return v - math.floor(v)
end

-- ----------------------------------------------------------------------------
-- DRAW: popula o batch (mundo-ancorado, determinístico) e desenha.
-- ----------------------------------------------------------------------------
local Z_CELL = 0.26        -- passo de célula em z (mundo)
local SLOTS = 6            -- tentativas de tufo por célula (3 por lado)

function GrassField.draw(ctx)
    bakeAtlas()
    if not batch then
        batch = love.graphics.newSpriteBatch(atlasImg, 4096, "stream")
    end
    batch:clear()

    local g = ctx.geom
    local P = GrassField.PRESETS[ctx.biomeId] or DEFAULT_PRESET
    local t0 = ctx.time
    local camZ = ctx.camZ
    local w = ctx.w
    local cLight = ctx.colors.light
    local cMid = ctx.colors.mid
    local cAcc = ctx.colors.accent

    local first = math.floor(camZ / Z_CELL)
    local last = math.floor((camZ + ctx.relCrest - 2.5) / Z_CELL)
    for ci = first, last do
        for slot = 0, SLOTS - 1 do
            local h1 = hash(ci, slot * 7 + 1)
            if h1 < 0.58 * P.density then
                local z = ci * Z_CELL + h1 * Z_CELL
                local rel = z - camZ
                local t = g.tOf(rel)
                -- t<0.12: sub-pixel, não desenha (o longe é textura)
                if t and t > 0.12 then
                    -- fork: os braços da estrada varrem a faixa central —
                    -- capim some do trecho bifurcado enquanto o fork existe
                    if not (ctx.forkActive and rel > (ctx.forkRel or 10) - 1.5) then
                    local h2 = hash(ci, slot * 13 + 5)
                    local h3 = hash(ci, slot * 29 + 11)
                    local side = (slot % 2 == 0) and -1 or 1
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    -- da beira da estrada (levemente POR CIMA da borda —
                    -- grama invade o caminho) até o campo aberto
                    local pxX = roadC + side * (half * 0.94
                        + w * (0.004 + h2 * 0.40) * (0.35 + 0.65 * t))
                    if math.abs(pxX - g.cx) < w * 0.52 then
                        local base = g.latY(pxX - g.cx, t)
                        local persp = g.persp(t)
                        local nx = (pxX - ctx.x) / w
                        -- TUFO: 3-6 lâminas, cada uma com flexibilidade,
                        -- variante, fase e tom próprios
                        local nb = 3 + math.floor(h3 * 4)
                        local scale = (0.55 + persp * 1.55) * P.heightK
                        if scale * CELL_H >= 2 then
                            for bi = 0, nb - 1 do
                                local hb = hash(ci * 31 + slot, bi * 17 + 3)
                                local hv = hash(ci * 53 + bi, slot * 19 + 7)
                                local vquad = (hv < P.broad)
                                    and (N_THIN + math.floor(hb * N_BROAD))
                                    or math.floor(hv * N_THIN)
                                local s = scale * (0.72 + hb * 0.55)
                                local bx = pxX + (bi - nb / 2)
                                    * (1.6 + persp * 2.2) + hb * 3
                                -- física: raiz fixa, ponta balança;
                                -- flexível ∝ altura; encurta ao dobrar
                                local flex = 0.55 + hb * 0.75
                                local lean = windAt(nx, z, t0 + hb * 0.6, P)
                                    * flex
                                local kx = lean * 0.55
                                local sy = s * (1 - math.abs(lean) * 0.16)
                                -- tom: alterna meia-luz/luz (leitura em
                                -- qualquer paleta); raiz→ponta vem do atlas
                                local c = (bi % 2 == 0) and cMid or cLight
                                batch:setColor(c[1], c[2], c[3], 1)
                                batch:add(quads[vquad],
                                    math.floor(bx), math.floor(base + 1),
                                    0, s, sy, CELL_W / 2, CELL_H, kx, 0)
                            end
                            -- flor/broto na cor de acento do bioma (a
                            -- "vida" do campo — dourado/brasa/cristal...)
                            if h3 > 1 - P.flower and t > 0.25 then
                                local lean = windAt(nx, z, t0 + 0.3, P) * 0.8
                                batch:setColor(cAcc[1], cAcc[2], cAcc[3], 1)
                                batch:add(quads[FLOWER_CELL],
                                    math.floor(pxX + h2 * 4 - 2),
                                    math.floor(base + 1),
                                    0, scale * 0.9, scale * 0.9,
                                    CELL_W / 2, CELL_H, lean * 0.55, 0)
                            end
                        end
                    end
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
end

-- limpa recursos GPU (troca de resolução etc.)
function GrassField.clearCache()
    atlasImg, quads, batch = nil, nil, nil
end

return GrassField
