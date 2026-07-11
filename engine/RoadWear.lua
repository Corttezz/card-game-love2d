-- engine/RoadWear.lua
-- Motor de IMPERFEIÇÕES DO SOLO do caminho (v10 — Jul/2026): o leito da
-- estrada era "plano e padronizado" (textura tileada + pedrinhas 2px).
-- Este motor deita DETALHES DETERMINÍSTICOS sobre a terra, por bioma:
--
--   fields    — manchas úmidas, pedras encravadas, palha caída, cascos
--   highlands — restos de CALÇAMENTO (lajes semi-enterradas), musgo
--   abyss     — rachaduras com BRASA viva (micro-luz), chamusco, ossos
--   frost     — bancos de neve invadindo, placas de gelo, pegadas
--   marsh     — POÇAS refletindo o céu, lama arrastada, raízes
--   dusk      — folhas caídas, raízes, pedras
--
-- Princípios (mesma família do GrassField/LuminaireEngine):
--   · DETERMINÍSTICO: feature = f(worldZ, hash) — nada de estado/spawn;
--     a estrada rola e os detalhes rolam junto, sempre os mesmos.
--   · Projeção INJETADA: usa a geometria do domo do WorldRoad (t, latY,
--     persp, roadCenter/roadHalf) — nunca coordenadas próprias.
--   · Stamps em TONS DE CINZA tintados por envColor no draw — o crossfade
--     de bioma lerpa as cores de graça (nada "pipoca" na transição).
--   · SQUASH vertical (~0.55): o stamp DEITA no chão (foreshortening),
--     em vez de parecer adesivo em pé.
--   · Fork: além de FORK_REL o leito é área de escolha — sem detalhe novo.
--
-- Uso (WorldRoad.draw, logo APÓS drawRoad e ANTES da grama):
--   RoadWear.draw(ctx)  com ctx = { geom, x, w, camZ, time, bid, relCrest,
--     roadCenter(z,t), roadHalf(t), tint(name) -> {r,g,b},
--     forkActive, forkRel }

local LightEngine = require("engine.LightEngine")

local RoadWear = {}

-- ----------------------------------------------------------------------------
-- STAMPS procedurais (grayscale + alpha, gerados 1x). Valor = luminância a
-- tintar; alpha esculpe a forma. Pixel-art: formas duras, dither na borda.
-- ----------------------------------------------------------------------------
local stamps = nil

local function put(d, x, y, v, a)
    local w, h = d:getWidth(), d:getHeight()
    if x >= 0 and x < w and y >= 0 and y < h then
        d:setPixel(x, y, v, v, v, a or 1)
    end
end

local function hash01(n)
    local v = math.sin(n * 12.9898) * 43758.5453
    return v - math.floor(v)
end

local function makeStamps()
    local S = {}

    -- MANCHA irregular (úmida/chamuscada/lama): blob 26×10 com borda dither
    do
        local w, h = 26, 10
        local d = love.image.newImageData(w, h)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local nx = (x - w / 2) / (w / 2)
                local ny = (y - h / 2) / (h / 2)
                local r = nx * nx + ny * ny
                local n = hash01(x * 7 + y * 13)
                if r < 0.55 or (r < 1.0 and n > r) then
                    put(d, x, y, 0.5 + n * 0.12, 1)
                end
            end
        end
        S.patch = love.graphics.newImage(d)
    end

    -- PEDRA encravada 7×5: topo claro, corpo médio, base escura (volume)
    do
        local d = love.image.newImageData(7, 5)
        local rows = { "0111100", "1222210", "1222221", "0122210", "0011100" }
        local V = { [0] = nil, [1] = 0.42, [2] = 0.66 }
        for y = 1, 5 do
            for x = 1, 7 do
                local c = tonumber(rows[y]:sub(x, x))
                if V[c] then put(d, x - 1, y - 1, y <= 2 and math.min(1, V[c] * 1.3) or V[c], 1) end
            end
        end
        S.stone = love.graphics.newImage(d)
    end

    -- CLUSTER de 3 seixos 12×5
    do
        local d = love.image.newImageData(12, 5)
        local pts = { { 1, 2, 3, 2 }, { 6, 0, 2, 2 }, { 9, 2, 3, 3 } }
        for _, p in ipairs(pts) do
            for y = p[2], math.min(4, p[2] + p[4] - 1) do
                for x = p[1], math.min(11, p[1] + p[3] - 1) do
                    put(d, x, y, y == p[2] and 0.72 or 0.5, 1)
                end
            end
        end
        S.stones = love.graphics.newImage(d)
    end

    -- LAJE de calçamento 10×7 (retângulo lascado, junta escura em volta)
    do
        local d = love.image.newImageData(10, 7)
        for y = 0, 6 do
            for x = 0, 9 do
                local edge = x == 0 or y == 0 or x == 9 or y == 6
                local chip = hash01(x * 31 + y * 17) > 0.92
                if not chip then
                    if edge then put(d, x, y, 0.30, 1)
                    else put(d, x, y, y <= 1 and 0.74 or 0.58, 1) end
                end
            end
        end
        S.cobble = love.graphics.newImage(d)
    end

    -- RACHADURA 20×6 (linha quebrada; abyss tinta com brasa + micro-luz)
    do
        local d = love.image.newImageData(20, 6)
        local y = 2
        for x = 0, 19 do
            put(d, x, y, 0.9, 1)
            if hash01(x * 7) > 0.62 then y = math.max(0, math.min(5, y + (hash01(x * 3) > 0.5 and 1 or -1))) end
            if hash01(x * 11) > 0.8 then put(d, x, y + 1, 0.6, 1) end
        end
        S.crack = love.graphics.newImage(d)
    end

    -- POÇA 20×8: aro escuro + espelho claro no miolo (reflexo do céu)
    do
        local w, h = 20, 8
        local d = love.image.newImageData(w, h)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local nx = (x - w / 2) / (w / 2)
                local ny = (y - h / 2) / (h / 2)
                local r = nx * nx + ny * ny
                if r < 1.0 then
                    if r > 0.62 then put(d, x, y, 0.22, 1)          -- aro lama
                    else put(d, x, y, 0.85, 1) end                   -- espelho
                end
            end
        end
        S.puddle = love.graphics.newImage(d)
    end

    -- FOLHAS caídas 14×8: salpicos 1-2px
    do
        local d = love.image.newImageData(14, 8)
        for k = 1, 14 do
            local x = math.floor(hash01(k * 13) * 13)
            local y = math.floor(hash01(k * 29) * 7)
            put(d, x, y, 0.55 + hash01(k * 7) * 0.35, 1)
            if hash01(k * 5) > 0.6 then put(d, x + 1, y, 0.5, 1) end
        end
        S.leaves = love.graphics.newImage(d)
    end

    -- BANCO DE NEVE 24×9: blob claro com dither de borda
    do
        local w, h = 24, 9
        local d = love.image.newImageData(w, h)
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local nx = (x - w / 2) / (w / 2)
                local ny = (y - h / 2) / (h / 2)
                local r = nx * nx + ny * ny
                local n = hash01(x * 3 + y * 19)
                if r < 0.5 or (r < 1.0 and n > r * 0.9) then
                    put(d, x, y, 0.88 + n * 0.12, 1)
                end
            end
        end
        S.snow = love.graphics.newImage(d)
    end

    -- PEGADAS 16×6: pares de 2×1 alternando (trilha diagonal)
    do
        local d = love.image.newImageData(16, 6)
        for k = 0, 3 do
            local x = k * 4
            local y = (k % 2 == 0) and 1 or 3
            put(d, x, y, 0.35, 1); put(d, x + 1, y, 0.35, 1)
        end
        S.prints = love.graphics.newImage(d)
    end

    -- PALHA 10×4: 3 traços claros diagonais
    do
        local d = love.image.newImageData(10, 4)
        for k = 0, 2 do
            local x0 = k * 3
            put(d, x0, 2, 0.8, 1); put(d, x0 + 1, 1, 0.85, 1)
            put(d, x0 + 2, 1, 0.8, 1)
        end
        S.straw = love.graphics.newImage(d)
    end

    -- RAIZ 22×5 cruzando: linha ondulada grossa escura com nó
    do
        local d = love.image.newImageData(22, 5)
        local y = 2
        for x = 0, 21 do
            put(d, x, y, 0.3, 1)
            put(d, x, y + 1, 0.22, 1)
            if hash01(x * 17) > 0.7 then y = math.max(0, math.min(3, y + (hash01(x * 9) > 0.5 and 1 or -1))) end
            if x == 11 then put(d, x, y - 1, 0.38, 1) end   -- nó
        end
        S.root = love.graphics.newImage(d)
    end

    -- OSSO 8×3: lasca clara com pontas
    do
        local d = love.image.newImageData(8, 3)
        for x = 1, 6 do put(d, x, 1, 0.85, 1) end
        put(d, 0, 0, 0.8, 1); put(d, 0, 2, 0.8, 1)
        put(d, 7, 0, 0.8, 1); put(d, 7, 2, 0.8, 1)
        S.bone = love.graphics.newImage(d)
    end

    for _, img in pairs(S) do img:setFilter("nearest", "nearest") end
    return S
end

-- ----------------------------------------------------------------------------
-- CATÁLOGO por bioma: cada feature = { stamp, cada (unidades de z entre
-- instâncias), tint (chave/fórmula de cor), alpha, uMax (fração da meia-
-- largura), scaleK, ember (micro-luz abyss) }.
-- tint: função (ctx) -> {r,g,b} — derivada do envColor pra lerpar no
-- crossfade de bioma.
-- ----------------------------------------------------------------------------
local function mul(c, k) return { c[1] * k, c[2] * k, c[3] * k } end

RoadWear.CATALOG = {
    fields = {
        { stamp = "patch",  cada = 3.2, alpha = 0.50, uMax = 0.75, scaleK = 1.1,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.72) end },
        { stamp = "stone",  cada = 4.5, alpha = 1.0, uMax = 0.8,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.25) end },
        { stamp = "straw",  cada = 5.0, alpha = 1.0, uMax = 0.7,
          tint = function(cx2) return { 0.82, 0.70, 0.38 } end },
        { stamp = "prints", cada = 6.5, alpha = 0.55, uMax = 0.45,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.6) end },
        { stamp = "stones", cada = 7.0, alpha = 0.95, uMax = 0.85,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.1) end },
    },
    highlands = {
        { stamp = "cobble", cada = 2.2, alpha = 0.95, uMax = 0.8, scaleK = 1.15,
          tint = function(cx2) return mul(cx2.tint("roadB"), 1.15) end },
        { stamp = "cobble", cada = 3.4, alpha = 0.9, uMax = 0.75,
          tint = function(cx2) return mul(cx2.tint("roadA"), 1.05) end },
        { stamp = "leaves", cada = 5.5, alpha = 0.7, uMax = 0.7,   -- musgo
          tint = function(cx2) return mul(cx2.tint("grassA"), 1.15) end },
        { stamp = "stone",  cada = 5.0, alpha = 1.0, uMax = 0.85,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.3) end },
    },
    abyss = {
        { stamp = "crack",  cada = 3.0, alpha = 0.95, uMax = 0.7, scaleK = 1.2,
          ember = true,
          tint = function(cx2) return { 1.0, 0.42, 0.12 } end },
        { stamp = "patch",  cada = 3.5, alpha = 0.6, uMax = 0.8, scaleK = 1.2,  -- chamusco
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.45) end },
        { stamp = "bone",   cada = 6.0, alpha = 0.9, uMax = 0.75,
          tint = function(cx2) return { 0.78, 0.72, 0.60 } end },
        { stamp = "stone",  cada = 5.5, alpha = 1.0, uMax = 0.85,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.2) end },
    },
    frost = {
        { stamp = "snow",   cada = 2.6, alpha = 0.85, uMax = 0.9, scaleK = 1.25,
          tint = function(cx2) return { 0.88, 0.92, 1.0 } end },
        { stamp = "patch",  cada = 4.0, alpha = 0.5, uMax = 0.7,   -- gelo
          tint = function(cx2) return { 0.62, 0.75, 0.95 } end },
        { stamp = "prints", cada = 4.5, alpha = 0.7, uMax = 0.5,
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.55) end },
        { stamp = "stone",  cada = 6.5, alpha = 1.0, uMax = 0.8,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.15) end },
    },
    marsh = {
        { stamp = "puddle", cada = 2.8, alpha = 0.9, uMax = 0.7, scaleK = 1.25,
          tint = function(cx2) return mul(cx2.tint("fog"), 1.35) end },
        { stamp = "patch",  cada = 3.2, alpha = 0.6, uMax = 0.85, scaleK = 1.15,  -- lama
          tint = function(cx2) return mul(cx2.tint("roadA"), 0.55) end },
        { stamp = "root",   cada = 5.0, alpha = 0.9, uMax = 0.9, scaleK = 1.2,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 0.9) end },
        { stamp = "leaves", cada = 6.0, alpha = 0.7, uMax = 0.7,   -- junco caído
          tint = function(cx2) return mul(cx2.tint("grassA"), 0.9) end },
    },
    dusk = {
        { stamp = "leaves", cada = 2.4, alpha = 0.9, uMax = 0.85, scaleK = 1.2,
          tint = function(cx2) return { 0.78, 0.38, 0.25 } end },
        { stamp = "leaves", cada = 3.6, alpha = 0.8, uMax = 0.75,
          tint = function(cx2) return { 0.72, 0.52, 0.22 } end },
        { stamp = "root",   cada = 5.5, alpha = 0.85, uMax = 0.85, scaleK = 1.1,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 0.85) end },
        { stamp = "stone",  cada = 6.0, alpha = 1.0, uMax = 0.8,
          tint = function(cx2) return mul(cx2.tint("roadEdge"), 1.2) end },
    },
}

-- ----------------------------------------------------------------------------
-- DRAW: para cada feature do catálogo, instancia determinística por
-- "slot" de z (floor(worldZ / cada) + salt). Projeção pela geometria do
-- domo injetada; squash vertical pra deitar no chão.
-- ----------------------------------------------------------------------------
-- Knob global de densidade (1 = catálogo cru; subir = mais detalhe).
-- Calibrado visualmente: 1.6 preenche sem virar entulho.
RoadWear.DENSITY = 1.6

function RoadWear.draw(ctx)
    stamps = stamps or makeStamps()
    local cat = RoadWear.CATALOG[ctx.bid]
    if not cat then return end
    local g = ctx.geom
    local camZ = ctx.camZ

    for fi, f in ipairs(cat) do
        local img = stamps[f.stamp]
        if img then
            local iw, ih = img:getWidth(), img:getHeight()
            local tintC = f.tint(ctx)
            local salt = fi * 7919
            local cada = f.cada / RoadWear.DENSITY
            -- slots de z que caem na janela visível
            local s0 = math.floor(camZ / cada)
            local s1 = math.floor((camZ + ctx.relCrest) / cada)
            for slot = s0, s1 do
                local h1 = hash01(slot * 12.9898 + salt)
                -- jitter de z DENTRO do slot (quebra o ritmo de grade)
                local wz = (slot + 0.15 + h1 * 0.7) * cada
                local rel = wz - camZ
                -- fork: além da bifurcação o leito é área de escolha
                local skip = ctx.forkActive and rel > (ctx.forkRel - 1)
                local t = (not skip) and g.tOf(rel) or nil
                if t and t >= 0.10 and t <= 1 then
                    local h2 = hash01(slot * 78.233 + salt)
                    local h3 = hash01(slot * 37.719 + salt)
                    local cxr = ctx.roadCenter(wz, t)
                    local half = ctx.roadHalf(t)
                    local u = (h2 * 2 - 1) * (f.uMax or 0.7)
                    local px = cxr + u * half
                    local py = g.latY(px - g.cx, t)
                    -- escala pela perspectiva (mesma régua dos props) +
                    -- SQUASH vertical: o stamp deita no chão
                    local sc = (0.70 + 2.6 * t) * (f.scaleK or 1)
                    local sy2 = sc * 0.55
                    local flip = h3 > 0.5 and -1 or 1
                    local aDist = math.min(1, (t - 0.06) * 4)   -- fade no fundo
                    love.graphics.setColor(tintC[1], tintC[2], tintC[3],
                        (f.alpha or 0.8) * aDist)
                    love.graphics.draw(img, math.floor(px), math.floor(py),
                        0, sc * flip, sy2, iw / 2, ih / 2)
                    -- brasas da rachadura (abyss): a fissura ILUMINA de leve
                    if f.ember and LightEngine.submitMicro then
                        LightEngine.submitMicro(px, py, 9 * sc * 0.4,
                            { 1.0, 0.45, 0.15 },
                            0.30 + 0.12 * math.sin(ctx.time * 1.7 + slot),
                            rel)
                    end
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return RoadWear
