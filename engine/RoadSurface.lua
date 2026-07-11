-- engine/RoadSurface.lua
-- SÍNTESE da superfície do leito da estrada (v10.1 — Jul/2026). O leito era
-- um PNG tileado replicado ("textura padrão preenchendo tudo, sem
-- profundidade nem desnível" — feedback). Este motor GERA a textura por
-- bioma com engenharia de terreno pixel-art:
--
--   1. CLUSTERS TONAIS  — value-noise FBM periódico escolhe entre 4 tons de
--      terra (nada de tile repetido; variação de baixa frequência real).
--   2. MICRO-RELEVO     — iluminação top-light por cluster: borda superior
--      de um cluster elevado ganha highlight, borda inferior ganha sombra.
--      É isso que dá o "desnível" (a leitura 3D de calombos e depressões).
--   3. SULCOS de RODA   — dois canais verticais contínuos, serpenteando,
--      mais escuros com rim claro (estrada usada de verdade). Como o
--      sampling é CENTRADO no eixo da estrada, os sulcos seguem a curva.
--   4. DESGASTE CENTRAL — faixa do meio mais clara (terra socada por pés).
--   5. SPECKLE          — grãos escuros/claros esparsos (cascalho fino).
--   6. ESPECIAL por bioma:
--        highlands — LAJES de calçamento (Voronoi irregular, juntas escuras,
--                    relevo por laje) — engenharia no LEITO, não decal solto.
--        abyss     — terra RACHADA (juntas Voronoi finas sobre os clusters).
--        frost     — lama congelada com VEIOS de gelo claros.
--        marsh     — lama molhada com BANDAS de brilho úmido.
--        dusk      — húmus com flecos quentes (folhiço triturado).
--
-- A textura tileia nos DOIS eixos (noise em lattice modular) — o scroll
-- vertical da viagem nunca mostra emenda. Gerada 1× por bioma e cacheada.
-- O RoadWear (decals determinísticos) continua por cima, mais esparso.

local RoadSurface = {}

local cache = {}

local W, H = 192, 512   -- texels; ~98 unidades de mundo antes de repetir

-- ----------------------------------------------------------------------------
-- Noise periódico (lattice modular — tileia perfeito nos 2 eixos)
-- ----------------------------------------------------------------------------
local function latHash(i, j, seed)
    local v = math.sin(i * 127.1 + j * 311.7 + seed * 74.7) * 43758.5453
    return v - math.floor(v)
end

-- value noise com período (nx, ny) células
local function vnoise(x, y, nx, ny, seed)
    local gx, gy = x / W * nx, y / H * ny
    local i, j = math.floor(gx), math.floor(gy)
    local fx, fy = gx - i, gy - j
    local ux = fx * fx * (3 - 2 * fx)
    local uy = fy * fy * (3 - 2 * fy)
    local i1, j1 = (i + 1) % nx, (j + 1) % ny
    i, j = i % nx, j % ny
    local a = latHash(i, j, seed)
    local b = latHash(i1, j, seed)
    local c = latHash(i, j1, seed)
    local d = latHash(i1, j1, seed)
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
end

local function fbm(x, y, seed)
    return vnoise(x, y, 8, 20, seed) * 0.62
         + vnoise(x, y, 21, 52, seed + 7) * 0.38
end

local function mulc(c, k) return { c[1] * k, c[2] * k, c[3] * k } end
local function mixc(a, b, k)
    return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k,
             a[3] + (b[3] - a[3]) * k }
end

-- ----------------------------------------------------------------------------
-- VORONOI periódico (lajes/rachaduras): retorna d2-d1 (junta quando pequeno)
-- e o id da célula mais próxima (tom da laje). Métrica levemente retangular
-- (lajes assentadas, não bolhas).
-- ----------------------------------------------------------------------------
local function voronoi(x, y, nx, ny, seed, ky)
    local gx, gy = x / W * nx, y / H * ny
    local ci, cj = math.floor(gx), math.floor(gy)
    local d1, d2, id = 1e9, 1e9, 0
    for dj = -1, 1 do
        for di = -1, 1 do
            local i, j = ci + di, cj + dj
            local wi, wj = i % nx, j % ny
            local jx = latHash(wi, wj, seed) * 0.7 + 0.15
            local jy = latHash(wi, wj, seed + 3) * 0.7 + 0.15
            local dx = (i + jx) - gx
            local dy = (j + jy) - gy
            -- ky > 1 achata a célula na vertical: o leito é esticado ao
            -- longo da profundidade pela perspectiva, então célula baixa
            -- na textura lê ~quadrada no chão (v10.1.2 anti-esticado).
            local d = math.max(math.abs(dx) * 1.0, math.abs(dy) * (ky or 0.78))
            if d < d1 then d2 = d1; d1 = d; id = wi * 131 + wj
            elseif d < d2 then d2 = d end
        end
    end
    return (d2 - d1), id
end

-- ----------------------------------------------------------------------------
-- BAKE por bioma. pal = tabela do bioma (roadA/roadB/roadEdge).
-- ----------------------------------------------------------------------------
local function bake(bid, pal)
    local roadA = pal.roadA or { 0.45, 0.33, 0.20 }
    local roadB = pal.roadB or mulc(roadA, 0.86)
    local edge  = pal.roadEdge or mulc(roadA, 0.45)
    -- 4 tons de terra: escuro → claro
    local tones = {
        mulc(roadB, 0.90), roadB, roadA, mulc(roadA, 1.14),
    }
    local seed = 0
    for i = 1, #bid do seed = seed + bid:byte(i) end

    local d = love.image.newImageData(W, H)
    local idx = {}          -- índice tonal por pixel (pro passe de relevo)
    local slab = bid == "highlands"
    local cracked = bid == "abyss"

    -- PASSE 1: campo tonal (clusters FBM) ou lajes (Voronoi)
    for y = 0, H - 1 do
        idx[y] = {}
        for x = 0, W - 1 do
            local n = fbm(x, y, seed)
            local ti
            if n < 0.38 then ti = 1
            elseif n < 0.52 then ti = 2
            elseif n < 0.70 then ti = 3
            else ti = 4 end
            if slab then
                -- lajes: tom POR CÉLULA + juntas escuras (idx 0). v10.1.2:
                -- MAIS lajes (9×16→14×36) e mais curtas (ky 1.35) — antes
                -- ficavam grandes/esticadas ("muito esticado"). Junta mais
                -- fina (0.085→0.055) pra pedra menor não virar só junta.
                local dj, id = voronoi(x, y, 14, 36, seed + 11, 1.35)
                if dj < 0.055 then ti = 0
                else
                    ti = 2 + math.floor(latHash(id % 97, math.floor(id / 97), seed) * 2.4)
                    ti = math.min(4, ti)
                    -- erosão nos cantos da laje (noise come a borda)
                    if dj < 0.11 and n > 0.74 then ti = 0 end
                end
            elseif cracked then
                -- terra rachada: craquelure FINA (células menores, junta
                -- de 1 texel — v10.1.1: 0.045 lia como "placas soltas")
                local dj = voronoi(x, y, 18, 40, seed + 23)
                if dj < 0.026 then ti = 0 end
            end
            idx[y][x] = ti
        end
    end

    -- PASSE 2: cor + MICRO-RELEVO (top-light: borda de cima do cluster mais
    -- alto = highlight; borda de baixo = sombra) + sulcos + desgaste + grão
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local ti = idx[y][x]
            local c
            if ti == 0 then
                c = { edge[1], edge[2], edge[3] }
            else
                c = { tones[ti][1], tones[ti][2], tones[ti][3] }
                -- relevo: vizinho de CIMA mais baixo → sou topo de calombo
                local up = idx[(y - 1) % H][x]
                local dn = idx[(y + 1) % H][x]
                -- v10.1.2: relevo MAIS SUTIL (1.17/0.84 → 1.10/0.90) — o
                -- contraste forte lia como "linhas demais"
                if up < ti then c = mulc(c, 1.10) end
                if dn < ti then c = mulc(c, 0.90) end
                -- lajes: topo de laje pega mais luz (leitura de pedra)
                if slab and up == 0 then c = mulc(c, 1.13) end
                if slab and dn == 0 then c = mulc(c, 0.88) end
            end

            local u = x / W   -- 0..1, centro da ESTRADA em 0.5
            -- SULCOS de roda: canais em ±0.21 serpenteando com y
            if not slab then
                -- v10.1.2: sulcos MAIS SUTIS (calha 0.20→0.11, rim 1.06→
                -- 1.03) — os riscos verticais liam como "linha esticada",
                -- principalmente na neve
                local wob = math.sin(y / H * math.pi * 6) * 0.018
                for s = -1, 1, 2 do
                    local du = math.abs(u - (0.5 + s * 0.21 + wob * s))
                    if du < 0.028 then
                        local k = 1 - du / 0.028
                        c = mulc(c, 1 - 0.11 * k)          -- calha escura
                    elseif du < 0.044 then
                        c = mulc(c, 1.03)                   -- rim claro
                    end
                end
                -- DESGASTE central: terra socada mais clara (com noise)
                local dc = math.abs(u - 0.5)
                if dc < 0.13 then
                    c = mulc(c, 1 + 0.07 * (1 - dc / 0.13)
                        * (0.6 + 0.4 * vnoise(x, y, 4, 10, seed + 31)))
                end
            end

            -- ESPECIAIS por bioma
            if bid == "frost" then
                -- v10.1.2: gelo em MANCHINHAS quebradas, não veios longos.
                -- Antes era iso-contorno contínuo (10×24) que a perspectiva
                -- esticava em riscos ("muito esticado"). Agora: contorno de
                -- alta freq vertical (12×64 = curto) CORTADO por um segundo
                -- noise (dash) + mix mais fraco (0.55→0.30).
                local r = vnoise(x, y, 12, 64, seed + 41)
                local dash = vnoise(x, y, 20, 30, seed + 47)
                if math.abs(r - 0.5) < 0.020 and dash > 0.5 then
                    c = mixc(c, { 0.72, 0.80, 0.95 }, 0.30)
                end
            elseif bid == "marsh" then
                -- bandas de brilho úmido (sheen horizontal lento)
                local sh = math.sin((y / H) * math.pi * 14 + fbm(x, y, seed + 5) * 3)
                if sh > 0.75 then c = mulc(c, 1.10) end
                c = mixc(c, { 0.16, 0.18, 0.10 }, 0.10)   -- verdete de lodo
            elseif bid == "dusk" then
                -- flecos de folhiço triturado
                if latHash(x, y, seed + 51) > 0.965 then
                    c = mixc(c, { 0.66, 0.36, 0.20 }, 0.8)
                end
            end

            -- SPECKLE fino (cascalho): grão escuro 2%, claro 1.2%
            local g1 = latHash(x, y, seed + 61)
            if g1 > 0.980 then c = mulc(c, 0.70)
            elseif g1 < 0.012 then c = mulc(c, 1.24) end

            d:setPixel(x, y, math.min(1, c[1]), math.min(1, c[2]),
                math.min(1, c[3]), 1)
        end
    end

    local img = love.graphics.newImage(d)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    return img
end

-- pal = tabela de cores do bioma (rawBiome() do WorldRoad serve direto)
function RoadSurface.get(bid, pal)
    local hit = cache[bid]
    if hit then return hit end
    local ok, img = pcall(bake, bid, pal or {})
    if not ok or not img then return nil end
    cache[bid] = img
    return img
end

function RoadSurface.clear() cache = {} end

return RoadSurface
