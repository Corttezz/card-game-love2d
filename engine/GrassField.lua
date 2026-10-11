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
-- - Out/2026 (perf): lote = QuadMesh (FFI) e o VENTO roda no VERTEX
--   SHADER (GrassField.SHADER_VERTEX — as mesmas fórmulas de windAt/
--   flick/pokeLean, por vértice). Câmera parada = o lote do frame
--   anterior é reusado inteiro (0 Lua por lâmina); 1 draw por fatia.
--
-- SEM stencil, SEM alpha translúcido — pixels opacos na paleta.
--
-- USO (ver WorldRoad):
--   GrassField.draw{ x=, w=, time=, camZ=, geom=g, relCrest=,
--                    roadCenter=fn(z,t), roadHalf=fn(t),
--                    colors={light=,mid=,accent=}, biomeId="fields",
--                    forkActive=false, forkRel=10 }
-- ============================================================================

local GrassField = {}
local QuadMesh = require("engine.QuadMesh")

-- ----------------------------------------------------------------------------
-- PRESETS por bioma: personalidade do capim (densidade, altura, vento).
-- Cores NÃO ficam aqui — vêm do chamador (lerpam no crossfade de bioma).
-- ----------------------------------------------------------------------------
-- v9.7.2 (feedback: "as gramas estão muito estáticas"): vento AMBIENTE
-- ~45% mais forte em todos os biomas (windAmp ×1.45, gustAmp ×1.35,
-- gustSpeed ×1.15) — a vida da grama agora é toda dele, já que a rajada
-- de hover do mouse foi removida. Caráter relativo por bioma preservado
-- (abyss segue o mais parado, highlands o mais ventoso).
GrassField.PRESETS = {
    --                dens  altK  vento gustA gustV dir broad flor
    fields    = { density = 1.00, heightK = 1.00, windAmp = 0.72,
                  gustAmp = 1.50, gustSpeed = 1.50, dir = 1,
                  broad = 0.10, flower = 0.10 },
    highlands = { density = 0.80, heightK = 0.90, windAmp = 1.00,
                  gustAmp = 1.85, gustSpeed = 2.05, dir = -1,
                  broad = 0.08, flower = 0.06 },   -- vento de montanha
    abyss     = { density = 0.55, heightK = 0.80, windAmp = 0.44,
                  gustAmp = 0.82, gustSpeed = 1.05, dir = 1,
                  broad = 0.05, flower = 0.08 },   -- restolho, ar parado
    frost     = { density = 0.50, heightK = 0.70, windAmp = 0.86,
                  gustAmp = 1.60, gustSpeed = 1.85, dir = -1,
                  broad = 0.06, flower = 0.05 },
    marsh     = { density = 1.15, heightK = 1.30, windAmp = 0.64,
                  gustAmp = 1.15, gustSpeed = 1.15, dir = 1,
                  broad = 0.30, flower = 0.09 },   -- juncos altos e pesados
    dusk      = { density = 0.90, heightK = 1.05, windAmp = 0.80,
                  gustAmp = 1.35, gustSpeed = 1.30, dir = -1,
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
-- MOITAS (v7.4, cobertura 100%): células de 16×16 com 8-10 lâminas
-- pré-assadas + base quase sólida — 1 sprite cobre ~5× mais chão que uma
-- lâmina, viabilizando o tapete contínuo sem explodir a contagem
local N_CLUMP = 6
local CLUMP_W = 16
local atlasImg, quads, clumpQuads

local function bakeAtlas()
    if atlasImg then return end
    local n = N_THIN + N_BROAD + 1
    local atlasW = CELL_W * n + CLUMP_W * N_CLUMP
    local id = love.image.newImageData(atlasW, CELL_H)
    local function put(cell, x, y, lum)
        if x >= 0 and x < CELL_W and y >= 0 and y < CELL_H then
            id:setPixel(cell * CELL_W + x, y, lum, lum, lum, 1)
        end
    end
    -- lâminas FINAS: coluna com curva própria, 2px na base, 1px no topo
    for v = 0, N_THIN - 1 do
        local rng = love.math.newRandomGenerator(1000 + v * 37)
        local len = 9 + rng:random(0, 5)                 -- 9-14 px
        local curve = (rng:random() * 2 - 1) * 3.4       -- dobra própria
        -- (±3.4: do quase-reto ao bem vergado — silhuetas variadas)
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
    -- MOITAS: 2 fileiras da base quase sólidas (chão DE capim — é o que
    -- garante o tapete contínuo entre fileiras) + 8-10 lâminas variadas
    -- com brilho individual (profundidade interna baked)
    local clumpX0 = CELL_W * n
    for cv = 0, N_CLUMP - 1 do
        local rng = love.math.newRandomGenerator(3000 + cv * 71)
        local xo = clumpX0 + cv * CLUMP_W
        for x = 0, CLUMP_W - 1 do
            for y = CELL_H - 2, CELL_H - 1 do
                if rng:random() < 0.88 then
                    local lum = 0.34 + rng:random() * 0.14
                    id:setPixel(xo + x, y, lum, lum, lum, 1)
                end
            end
        end
        for _ = 1, 8 + rng:random(0, 2) do
            local bx = rng:random(1, CLUMP_W - 2)
            local len = 6 + rng:random(0, 8)
            local curve = (rng:random() * 2 - 1) * 3.0
            local bright = 0.72 + rng:random() * 0.38   -- lâmina clara/escura
            for i = 0, len - 1 do
                local fy = i / math.max(1, len - 1)
                local y = (CELL_H - 1) - i
                local x = math.floor(bx + curve * fy * fy + 0.5)
                if x >= 0 and x < CLUMP_W and y >= 0 then
                    local lum = (0.44 + 0.16 * math.min(1, fy * 2.5)) * bright
                    if fy > 0.8 then lum = 0.95 * bright end
                    id:setPixel(xo + x, y, math.min(1, lum), math.min(1, lum),
                        math.min(1, lum), 1)
                end
            end
        end
    end
    atlasImg = love.graphics.newImage(id)
    atlasImg:setFilter("nearest", "nearest")
    -- Out/2026: "quad" = UV normalizado {u0, v0, u1, v1} (o lote é um
    -- QuadMesh escrito por FFI — ver engine/QuadMesh.lua), mesmo recorte
    -- do Quad do LÖVE que existia aqui
    quads = {}
    for i = 0, n - 1 do
        quads[i] = { (i * CELL_W) / atlasW, 0, (i * CELL_W + CELL_W) / atlasW, 1 }
    end
    clumpQuads = {}
    for i = 0, N_CLUMP - 1 do
        local x0 = clumpX0 + i * CLUMP_W
        clumpQuads[i] = { x0 / atlasW, 0, (x0 + CLUMP_W) / atlasW, 1 }
    end
end

-- ----------------------------------------------------------------------------
-- LOTE NA GPU (Out/2026, perf): o SpriteBatch "stream" com ~10k
-- batch:add + ~10k setColor por frame (5-8 ms de chamadas C) virou um
-- QuadMesh escrito por FFI com o VENTO NO VERTEX SHADER:
--   - a CPU escreve a lâmina PARADA (vento zero) + os parâmetros do vento
--     dela (hash/fase/amplitude) — as MESMAS fórmulas de antes, só que
--     avaliadas por vértice na GPU (GrassField.SHADER_* abaixo);
--   - com a câmera PARADA (batalha, escolha de caminho) nada da cena da
--     grama muda além do relógio → o lote do frame anterior é REUSADO
--     inteiro: zero Lua por lâmina, só 1 uniform + 1 draw por fatia;
--   - cada FATIA de profundidade (painter do WorldRoad) é um trecho
--     contíguo do buffer (setDrawRange) — a intercalação com as árvores
--     é a mesma, fatia a fatia.
-- Cisalhamento (kx) e encurtamento (sy) são lineares na altura do
-- vértice: X += kx·sx·(ly−oy) e Y −= |lean|·0.16·sy·(ly−oy) — o mesmo
-- Matrix4::setTransformation do SpriteBatch, só que com kx vindo do shader.
-- ----------------------------------------------------------------------------
local ffi = require("ffi")
pcall(ffi.cdef, [[
typedef struct {
    float x, y, u, v;
    uint8_t r, g, b, a;
    float ax, ay, kind;
    float w1, w2, w3, w4;
} gf_vertex_t;
]])
local GF_FORMAT = {
    { "VertexPosition", "float", 2 },
    { "VertexTexCoord", "float", 2 },
    { "VertexColor", "byte", 4 },
    { "GrassArm", "float", 3 },     -- (sx·(ly−oy), sy·(ly−oy), tipo)
    { "GrassWind", "float", 4 },    -- parâmetros do vento (por tipo)
}
-- tipos de sprite (GrassArm.z)
local K_CLUMP, K_CREST, K_BLADE, K_BROAD, K_FLOWER = 0, 1, 2, 3, 4

GrassField.SHADER_VERTEX = [[
uniform float uT;      // relógio do mundo (ctx.time)
uniform vec4 uP;       // gustSpeed, gustAmp, windAmp, dir (preset do bioma)
uniform vec4 uPoke;    // nx, wz, t0, ativo — rajada pontual (pokeAt)
attribute vec3 GrassArm;
attribute vec4 GrassWind;

// windAt da CPU (ver comentário da função Lua windAt — mesma fórmula)
float windAt(float nx, float wz, float t, float pers) {
    float ph = nx * 5.2 + wz * 0.14;
    float phA = nx * 7.5 + wz * 0.23;
    float phB = nx * 3.2 - wz * 0.31 + 1.7;
    float f1 = max(sin(phA * 0.85 - t * uP.x), 0.0);
    float f2 = max(sin(phB * 0.41 - t * uP.x * 0.737 + 2.4), 0.0);
    float gust = f1 * f1 * 0.70 + f2 * f2 * 0.50;
    float tb = t * (1.0 + pers * 0.45) + pers * 7.9;
    float breeze = sin(tb * 1.35 + ph * 3.1) * 0.30
                 + sin(tb * 0.53 + ph * 1.7) * 0.20;
    float curl = sin(ph * 9.3 + t * 2.6) * sin(ph * 3.7 - t * 1.9) * 0.12;
    float jitter = sin(tb * 6.1 + ph * 12.7) * 0.10 * (0.35 + gust);
    float wander = 0.72 + 0.28 * sin(t * 0.083 + ph * 0.11);
    return (breeze + gust * uP.y + curl + jitter) * uP.z * uP.w * wander;
}

// pokeLean da CPU (rajada local amortecida)
float pokeLean(float nx, float wz) {
    if (uPoke.w < 0.5) return 0.0;
    float e = uT - uPoke.z;
    if (e < 0.0 || e >= 0.9) return 0.0;
    float dxr = nx - uPoke.x;
    float dx = dxr * 7.0;
    float dz = (wz - uPoke.y) * 0.6;
    float d2 = dx * dx + dz * dz;
    if (d2 >= 4.0) return 0.0;
    float swell = min(1.0, e * 10.0) * exp(-e * 4.0);
    float side = dxr >= 0.0 ? 1.0 : -1.0;
    return exp(-d2 * 1.3) * swell * side * 1.9;
}

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    float kind = GrassArm.z;
    float kx;
    float squash = 0.0;
    if (kind < 0.5) {
        // moita do tapete: 2 senos com frequência/fase PRÓPRIAS (v7.4.12)
        float hk = GrassWind.x;
        float dz = GrassWind.y;
        kx = (sin(uT * (0.85 + hk * 1.35) + hk * 37.0) * 0.72
            + sin(uT * (1.9 + hk * 2.2) + dz * 53.0) * 0.28) * GrassWind.z;
    } else if (kind < 1.5) {
        // franja da crista
        float hk = GrassWind.x;
        kx = (sin(uT * (0.85 + hk * 1.35) + hk * 41.0) * 0.7
            + sin(uT * (2.0 + hk * 1.7) + hk * 91.0) * 0.3) * GrassWind.z;
    } else {
        float nx = GrassWind.x;
        float wz = GrassWind.y;
        float hb = GrassWind.z;
        float h3 = GrassWind.w;
        float pk = pokeLean(nx, wz);
        float lean;
        if (kind < 3.5) {
            float flex = 0.55 + hb * 0.75;
            float fe = sin(uT * 0.37 + h3 * 41.0);
            float flick = fe > 0.92
                ? ((fe - 0.92) / 0.08) * sin(uT * 11.0 + h3 * 9.0) * 0.45
                : 0.0;
            if (kind < 2.5) {
                lean = windAt(nx, wz, uT, hb) * flex;
            } else {
                // junco largo: INÉRCIA (relógio lento, balanço fundo)
                lean = windAt(nx, wz, uT * 0.62, hb * 0.4) * flex * 1.30;
            }
            lean = lean + (flick + pk) * flex;
            squash = abs(lean) * 0.16;
        } else {
            lean = (windAt(nx, wz, uT + 0.3, 0.0) + pk) * 0.8;   // flor
        }
        kx = lean * 0.55;
    }
    vertex_position.x += kx * GrassArm.x;
    vertex_position.y -= squash * GrassArm.y;
    return transform_projection * vertex_position;
}
]]
GrassField.SHADER_PIXEL = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    return Texel(tex, uv) * color;
}
]]

local qm
local shader
local frameId_          -- frame atual (ctx.frame, ou ctx.time)
-- CACHE do lote: válido enquanto a "cena da grama" não muda (tudo menos o
-- relógio, que é uniform). frameMode = "replay" (reusa trechos gravados)
-- ou "build" (gera e grava). cacheable cai pra false se algo no frame
-- depende do tempo na CPU (broto nascendo) ou se as fatias mudaram.
local cache = { valid = false, slices = {} }
local frameMode, sliceIdx, cacheable = "build", 0, false
-- contadores (trava de regressão tools/test_perf_budget): fatias
-- REUSADAS × CONSTRUÍDAS e sprites escritos pela CPU desde o último reset
GrassField.stats = { replays = 0, builds = 0, sprites = 0 }
function GrassField.resetStats()
    local st = GrassField.stats
    st.replays, st.builds, st.sprites = 0, 0, 0
end
local cDark = { 0, 0, 0 }   -- reusado (era 1 tabela nova por fatia)
local rowCache = {}   -- estáticos por fileira do tapete (podado por janela)
local lastCamZ        -- detecta câmera em movimento (broto desligado)
local lastTime        -- frame atual (múltiplas chamadas/frame — v7.5)
local camMovingFrame = false
-- diagnóstico (prova magenta + log de LOD): cacheado no load — os.getenv
-- por moita custava 7.8k chamadas C/frame
local GF_DEBUG = require("src.core.Release").isDev() and os.getenv("GF_DEBUG")  -- nunca no pacote

-- ----------------------------------------------------------------------------
-- VENTO em 3 camadas. Fase espacial vem da POSIÇÃO DE MUNDO (nx = fração
-- horizontal da tela, wz = z absoluto do mundo) — a frente de rajada
-- ATRAVESSA o campo e o mundo rolando faz o vento "fluir" na viagem.
-- Retorna lean normalizado [-1..1]-ish (multiplicado por windAmp).
-- ----------------------------------------------------------------------------
-- pers ∈ [0,1]: PERSONALIDADE da lâmina — relógio próprio (frequência e
-- fase individuais). Vizinhas nunca dançam em bloco (GoT: params por
-- lâmina; paper Real Time Animated Grass: variação dentro do cluster).
local function windAt(nx, wz, t, P, pers)
    local ph = nx * 5.2 + wz * 0.14
    -- (1) DUAS frentes de rajada com velocidades INCOMENSURÁVEIS — a
    -- interferência nunca se repete (versão barata do "noise de magnitude
    -- viajante" do Ghost of Tsushima).
    -- v7.4.9: fases espaciais DIAGONAIS E CRUZADAS (uma ↘, outra ↗) —
    -- com a fase dominada por wz a frente virava LINHA HORIZONTAL
    -- subindo pela tela (feedback: "uma linha de pixels atravessa o
    -- gramado até o fim da esfera")
    local phA = nx * 7.5 + wz * 0.23
    local phB = nx * 3.2 - wz * 0.31 + 1.7
    local f1 = math.sin(phA * 0.85 - t * P.gustSpeed)
    local f2 = math.sin(phB * 0.41 - t * P.gustSpeed * 0.737 + 2.4)
    -- (Out/2026: max(f,0)² ≡ (f>0 and f² or 0), sem desvio — ver QuadMesh.c8)
    local f1p, f2p = math.max(f1, 0), math.max(f2, 0)
    local gust = (f1p * f1p) * 0.70
               + (f2p * f2p) * 0.50
    -- (2) brisa local no TEMPO PRÓPRIO da lâmina
    pers = pers or 0
    local tb = t * (1 + pers * 0.45) + pers * 7.9
    local breeze = math.sin(tb * 1.35 + ph * 3.1) * 0.30
                 + math.sin(tb * 0.53 + ph * 1.7) * 0.20
    -- (3) REDEMOINHOS: alta frequência espacial transversal (vorticles
    -- do GoT em 2D) — tremores localizados que giram pelo campo
    local curl = math.sin(ph * 9.3 + t * 2.6)
               * math.sin(ph * 3.7 - t * 1.9) * 0.12
    -- (4) jitter de ponta: tremor rápido, cresce dentro da rajada
    local jitter = math.sin(tb * 6.1 + ph * 12.7) * 0.10 * (0.35 + gust)
    -- (5) o vento RESPIRA: intensidade global deriva em ~20s
    local wander = 0.72 + 0.28 * math.sin(t * 0.083 + ph * 0.11)
    return (breeze + gust * P.gustAmp + curl + jitter)
           * P.windAmp * P.dir * wander
end
GrassField.windAt = windAt   -- exposto pra outros sistemas (props, futuro)

-- ----------------------------------------------------------------------------
-- v9.7: RAJADA DO MOUSE (mapa interativo) — sopro local e amortecido nas
-- lâminas perto do cursor. Vive FORA do windAt: os call sites passam
-- relógios ESCALADOS pro windAt (junco 0.62×, flor +0.3) e o envelope da
-- rajada precisa do tempo REAL do ctx.
-- ----------------------------------------------------------------------------
GrassField._poke = nil
function GrassField.pokeAt(nx, wz, t)
    GrassField._poke = { nx = nx, wz = wz, t0 = t }
end
-- (pokeLean mora no SHADER_VERTEX — uniform uPoke; Out/2026)

-- (v7.4.12: windCalm REMOVIDO — até a "brisa calma" era um campo espacial
-- compartilhado: a fase variava tão devagar em profundidade que fileiras
-- vizinhas respiravam em sincronia = a "linha seguindo padrão" do 4º
-- feedback. O tapete agora usa osciladores 100% INDEPENDENTES por moita:
-- nenhum termo compartilhado entre duas moitas quaisquer.)

-- hash determinístico [0,1) — população estateless (mundo-ancorada, sem
-- spawn/reciclagem: as lâminas "existem" onde a janela da câmera olha)
-- ordenação da fileira por balde de cor (ver PASSE A)
local sortRow
local function byRowKey(a, b) return sortRow[a].key < sortRow[b].key end

local function hash(a, b)
    local v = math.sin(a * 127.1 + b * 311.7) * 43758.5453
    return v - math.floor(v)
end

-- Escreve 1 sprite PARADO (vento zero) + parâmetros do vento. Equivale a
-- SpriteBatch:add(quad, x, y, 0, sx, sy, ox, oy, kx=0) com a cor (R,G,B)
-- em bytes; o shader soma kx·arm.x e −squash·arm.y por vértice.
local function emit(x, y, sx, sy, ox, oy, qw, qh, q, R, G, B,
                    kind, w1, w2, w3, w4)
    local i = qm:alloc()
    local vt = qm.v
    local xl, xr = x - ox * sx, x + (qw - ox) * sx
    local dT, dB = -oy, qh - oy
    local yT, yB = y + sy * dT, y + sy * dB
    local axT, axB = sx * dT, sx * dB
    local ayT, ayB = sy * dT, sy * dB
    local u0, v0, u1, v1 = q[1], q[2], q[3], q[4]
    local p = vt[i]
    p.x, p.y, p.u, p.v = xl, yT, u0, v0
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axT, ayT, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
    p = vt[i + 1]
    p.x, p.y, p.u, p.v = xl, yB, u0, v1
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axB, ayB, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
    p = vt[i + 2]
    p.x, p.y, p.u, p.v = xr, yT, u1, v0
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axT, ayT, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
    p = vt[i + 3]
    p.x, p.y, p.u, p.v = xr, yB, u1, v1
    p.r, p.g, p.b, p.a = R, G, B, 255
    p.ax, p.ay, p.kind = axB, ayB, kind
    p.w1, p.w2, p.w3, p.w4 = w1, w2, w3, w4
end

-- chave da "cena da grama" (tudo que muda a geometria/cor escrita pela
-- CPU). Comparada campo a campo, sem alocar.
local KEY_N = 22
local keyNow, keyPrev = {}, {}
local function fillKey(k, ctx)
    local g, c = ctx.geom, ctx.colors
    k[1], k[2], k[3], k[4] = ctx.camZ, ctx.x, ctx.w, ctx.relCrest
    k[5], k[6], k[7], k[8] = g.cx, g.crestApexY, g.bottomY, g.R
    k[9], k[10], k[11] = c.light[1], c.light[2], c.light[3]
    k[12], k[13], k[14] = c.mid[1], c.mid[2], c.mid[3]
    k[15], k[16], k[17] = c.accent[1], c.accent[2], c.accent[3]
    k[18] = ctx.biomeId
    k[19] = ctx.castleGapHalf or 0
    k[20] = ctx.forkSig or 0
    k[21] = ctx.roadCenters and 1 or 0
    k[22] = GF_DEBUG and 1 or 0
end
local function sameKey()
    for i = 1, KEY_N do
        if keyNow[i] ~= keyPrev[i] then return false end
    end
    return true
end

-- ----------------------------------------------------------------------------
-- DRAW: popula o batch (mundo-ancorado, determinístico) e desenha.
-- ----------------------------------------------------------------------------
local Z_CELL = 0.26        -- passo de célula em z (mundo)
local SLOTS = 12           -- tentativas de tufo por célula (6 por lado)

function GrassField.draw(ctx)
    if GrassField.disabled then return end   -- A/B de benchmark
    bakeAtlas()
    if not qm then
        qm = QuadMesh.new(16384, { ctype = "gf_vertex_t", format = GF_FORMAT })
        shader = love.graphics.newShader(GrassField.SHADER_PIXEL,
            GrassField.SHADER_VERTEX)
    end
    local P = GrassField.PRESETS[ctx.biomeId] or DEFAULT_PRESET
    local relFrom = ctx.relFrom or -1
    local relTo = ctx.relTo or (ctx.relCrest + 2)

    -- ---- início de FRAME: decide replay × build, uniforms do vento
    local frameId = ctx.frame or ctx.time
    if frameId ~= frameId_ then
        -- o frame que acabou pode virar cache (se nada nele dependeu do
        -- relógio na CPU e as fatias foram todas gravadas)
        if frameMode == "build" then
            cache.valid = cacheable
            keyPrev, keyNow = keyNow, keyPrev
        end
        frameId_ = frameId
        fillKey(keyNow, ctx)
        if cache.valid and sameKey() then
            frameMode = "replay"
        else
            frameMode = "build"
            cache.valid = false
            for i = #cache.slices, 1, -1 do cache.slices[i] = nil end
            qm:reset()
            cacheable = not GF_DEBUG
        end
        sliceIdx = 0
        shader:send("uT", ctx.time)
        shader:send("uP", { P.gustSpeed, P.gustAmp, P.windAmp, P.dir })
        local pk = GrassField._poke
        if pk then
            shader:send("uPoke", { pk.nx, pk.wz, pk.t0, 1 })
        else
            shader:send("uPoke", { 0, 0, 0, 0 })
        end
    end
    sliceIdx = sliceIdx + 1
    if frameMode == "replay" then
        local sl = cache.slices[sliceIdx]
        if sl and sl[1] == relFrom and sl[2] == relTo then
            if sl[4] > 0 then
                local prev = love.graphics.getShader()
                love.graphics.setShader(shader)
                love.graphics.setColor(1, 1, 1, 1)
                qm:draw(sl[3], sl[4], atlasImg)
                love.graphics.setShader(prev)
            end
            GrassField._lastCount = sl[4]
            GrassField.stats.replays = GrassField.stats.replays + 1
            return
        end
        -- fatias mudaram (prop novo, fork...): o resto do frame é build e
        -- ele não vira cache (faltam as fatias de antes no registro)
        frameMode = "build"
        cache.valid = false
        cacheable = false
        qm:reset()
    end
    local sliceStart = qm.n
    -- cor corrente do lote em bytes (equivalente ao batch:setColor)
    local cR, cG, cB = 255, 255, 255
    local c8 = QuadMesh.c8

    local g = ctx.geom
    local t0 = ctx.time
    local camZ = ctx.camZ
    local w = ctx.w
    local cLight = ctx.colors.light
    local cMid = ctx.colors.mid
    local cAcc = ctx.colors.accent
    -- 3º tom (sombra): lâminas na sombra das vizinhas — profundidade de
    -- moita real (2 tons alternados liam como padrão artificial)
    cDark[1], cDark[2], cDark[3] = cMid[1] * 0.68, cMid[2] * 0.68, cMid[3] * 0.68

    -- até QUASE a crista (-0.05, não -0.8): o corte antigo deixava uma
    -- faixa careca que a geometria da esfera AMPLIFICA nas laterais
    -- (t 0..0.03 = ~15px no centro, 40-100px nas bordas em tela larga —
    -- "o final da esfera sem grama", feedback com print ultrawide)
    -- v7.5: JANELA de profundidade — o WorldRoad chama draw() várias
    -- vezes por frame, intercalando fatias de grama entre as árvores
    -- (painter real: capim na frente do pé da árvore COBRE o pé)
    -- câmera em movimento? (viagem/convergência — broto desligado).
    -- Detecção POR FRAME (ctx.time): com múltiplas chamadas por frame,
    -- comparar camZ por chamada daria "parado" da 2ª fatia em diante
    if ctx.time ~= lastTime then
        camMovingFrame = lastCamZ ~= nil
            and math.abs(camZ - lastCamZ) > 1e-4
        lastCamZ = camZ
        lastTime = ctx.time
        -- poda do cache 1x por frame (janela COMPLETA da câmera — as
        -- fatias usam janelas parciais e podariam fileiras vivas)
        local wf = math.floor(camZ / Z_CELL)
        local wl = math.floor((camZ + ctx.relCrest) / Z_CELL)
        for kci in pairs(rowCache) do
            if kci < wf or kci > wl then rowCache[kci] = nil end
        end
    end
    local camMoving = camMovingFrame

    -- v7.5 (perf): range de células LIMITADO à janela da fatia — sem
    -- isso cada uma das ~dezenas de fatias/frame varria o campo inteiro
    -- (17ms/frame; com o corte, volta ao custo de ~1 passada)
    local first = math.floor((camZ + math.max(0, relFrom)) / Z_CELL)
    local last = math.floor(
        (camZ + math.min(ctx.relCrest - 0.05, relTo)) / Z_CELL)

    -- ========================================================================
    -- PASSE A (v7.4): TAPETE 100% — fileiras de MOITAS de trás pra frente
    -- (painter: cada fileira cobre o chão da anterior; a base quase sólida
    -- da moita garante continuidade). LOD em ESPAÇO DE TELA: só desenha
    -- fileira quando o Y na tela avançou ~40% da altura da moita — no
    -- longe (fileiras comprimidas) pula quase todas de graça. No longe as
    -- moitas também ESTICAM na horizontal (detalhe é sub-pixel; menos
    -- sprites pra cobrir a mesma largura).
    -- ========================================================================
    -- TUDO ancorado no MUNDO (v7.4.1 — feedback: "movimentando pra frente
    -- fica estranho"): decimação por potência de 2 fixa por fileira +
    -- moita em fração FIXA da largura (nada re-embaralha nem desliza).
    -- v7.4.2 (perf): dados estáticos por fileira em CACHE (os 6 hashes por
    -- moita custavam 1 sin cada, TODO frame) + vento amostrado em grade
    -- grossa com lerp (espacialmente suave; a moita só modula amplitude —
    -- personalidade fina fica nos ACENTOS). Corte medido: ~4.0→~1.5ms.
    local NK = 96                       -- moitas por fileira (fração fixa)
    -- (poda do cache movida pro bloco 1x-por-frame lá em cima — v7.5)
    for ci = last, first, -1 do
        local z = ci * Z_CELL
        local rel = z - camZ
        local t = g.tOf(rel)
        if t and t > 0.002 and rel > relFrom and rel <= relTo then
            local persp = g.persp(t)
            local scale = (0.26 + persp * 1.75) * P.heightK
            local ch = scale * CELL_H
            if ch >= 2 then
                local t2 = g.tOf(rel - Z_CELL)
                local dy = t2 and (g.latY(0, t2) - g.latY(0, t)) or ch
                -- v7.4.8: folga calculada pro PIOR CASO (moita rasteira,
                -- 0.60×) — com 0.30 o vão entre fileiras ficava mais alto
                -- que a rasteira e o chão vazava ("mais buracos")
                local M = 1
                while dy * M < ch * 0.22 and M < 64 do M = M * 2 end
                if GF_DEBUG then
                    print(string.format(
                        "ci=%d rel=%.2f t=%.4f dy=%.2f ch=%.2f M=%d draw=%s",
                        ci, rel, t, dy, ch, M, tostring(ci % M == 0)))
                end
                if ci % M == 0 then
                    -- estáticos da fileira (mundo-fixos): calcula 1x
                    local rc = rowCache[ci]
                    if not rc then
                        -- born: fileira recém-criada BROTA do chão (v7.4.5)
                        -- — mas SÓ com a câmera parada (entrada de cena).
                        -- v7.4.7 (feedback: "no demo, viajando, o fundo
                        -- fica liso"): em viagem o LOD promove fileiras
                        -- SEM PARAR no terço final — todas mid-broto =
                        -- careca permanente. Em movimento a fileira nova
                        -- entra em tamanho cheio (nasce atrás das
                        -- vizinhas sobrepostas — o pop é invisível).
                        rc = { order = {},
                               born = camMoving and -1e9 or t0 }
                        for k = 0, NK - 1 do
                            local hk = hash(ci * 3 + 1, k * 11 + 2)
                            local ht = hash(ci * 19, k * 7 + 3)
                            -- seco QUANTIZADO em 3 níveis (permite agrupar
                            -- por cor: 3 tons × 3 secos = 9 baldes/fileira)
                            local dq = math.floor(
                                hash(ci * 5 + 2, k * 3 + 1) * 2.999)
                            local dryK = dq * 0.15
                            local tone = (ht < 0.30) and 3
                                or ((ht < 0.62) and 2 or 1)
                            local lf = (k + (hk - 0.5) * 0.9) / NK - 0.5
                            -- v7.4.6: 3 ALTURAS com sorteio PONDERADO pela
                            -- distância da estrada (rasteira na beira do
                            -- caminho → alta na parede de floresta; pesos
                            -- deslizam, sorteio continua aleatório).
                            -- |lf| é estático → o tier NUNCA muda em
                            -- movimento (threshold dinâmico faria a moita
                            -- trocar de altura no meio da viagem)
                            local df = math.min(1, math.max(0,
                                (math.abs(lf) - 0.055) / 0.30))
                            local pSmall = 0.62 - 0.47 * df
                            local pTall = 0.08 + 0.57 * df
                            local hr = hash(ci * 41 + 8, k * 23 + 5)
                            local hr2 = hash(ci * 43 + 2, k * 31 + 9)
                            -- piso da rasteira = 0.60: abaixo disso ela
                            -- fica mais baixa que o vão entre fileiras e
                            -- fura o tapete (altura muda SÓ pra cima da
                            -- linha de cobertura, nunca pra baixo dela)
                            local hMul
                            if hr < pSmall then
                                hMul = 0.60 + hr2 * 0.18      -- bem pequena
                            elseif hr > 1 - pTall then
                                hMul = 1.30 + hr2 * 0.50      -- bem alta
                            else
                                hMul = 0.88 + hr2 * 0.30      -- média
                            end
                            rc[k] = {
                                hk = hk,
                                lf = lf,
                                hMul = hMul,
                                tone = tone,
                                key = tone * 4 + dq,
                                dr = 1 + dryK * 0.30,
                                dg = 1 - dryK * 0.06,
                                db = 1 - dryK * 0.35,
                                q = clumpQuads[math.floor(hk * N_CLUMP)
                                    % N_CLUMP],
                                flip = (hash(ci, k) < 0.5) and 1 or -1,
                                dz = (hash(ci * 13 + 4, k * 17 + 6) - 0.5)
                                    * 0.9,
                            }
                            rc.order[k + 1] = k
                        end
                        -- ordem por COR (dentro da fileira a profundidade
                        -- é a mesma — pintar por balde não muda a imagem):
                        -- setColor só quando o balde troca (~9/fileira em
                        -- vez de 96) — chamada C é o custo dominante
                        -- comparador fixo (closure criada no laço aborta
                        -- o trace do JIT — Out/2026)
                        sortRow = rc
                        table.sort(rc.order, byRowKey)
                        sortRow = nil
                        rowCache[ci] = rc
                    end
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    -- v7.4.15: na encruzilhada valida contra CADA braço —
                    -- a clareira única (half + 0.17w) deixava o miolo
                    -- entre os caminhos e o entorno carecas
                    local centers, armK
                    if ctx.roadCenters then
                        centers, armK = ctx.roadCenters(z, t)
                    end
                    local clear = half * 0.90 * (centers and (armK or 1) or 1)
                    local spread = 0.92 + 0.14 * t
                    local spanW = w * 1.06 * spread
                    local spacing = spanW / NK
                    local baseW = 12 * scale
                    local sxK = math.max(1, spacing / math.max(1, baseW)
                        * 1.25)
                    local lastKey = -1
                    for oi = 1, NK do
                        local k = rc.order[oi]
                        local e = rc[k]
                        local pxX = g.cx + e.lf * spanW
                        local dRoad
                        if centers then
                            dRoad = 1e9
                            for a = 1, #centers do
                                local dd = math.abs(pxX - centers[a])
                                if dd < dRoad then dRoad = dd end
                            end
                            dRoad = dRoad - clear
                        else
                            dRoad = math.abs(pxX - roadC) - clear
                        end
                        if dRoad > 0 and math.abs(pxX - g.cx) < w * 0.53 then
                            -- jitter FIXO (×3, não ×M): atrelado ao M, a
                            -- moita dava um pulo de profundidade quando o
                            -- LOD trocava de nível durante a viagem
                            local zk = z + e.dz * Z_CELL * 3
                            local tk = g.tOf(zk - camZ) or t
                            local perspK = g.persp(tk)
                            local sK = (0.26 + perspK * 1.75) * P.heightK
                            local base = g.latY(pxX - g.cx, tk)
                            -- v7.4.12 (pedido direto: "randomize tudo,
                            -- nada faz a mesma coisa ao mesmo tempo"):
                            -- oscilador INDEPENDENTE por moita — 2 senos
                            -- em frequências próprias + fase própria +
                            -- amplitude própria. ZERO termo compartilhado
                            -- entre moitas = impossível formar linha.
                            -- (vento: GPU — amplitude da moita vai no
                            -- atributo; fases/frequências saem de hk/dz)
                            local amp = (0.14 + math.abs(e.dz) * 0.26)
                                * P.windAmp * P.dir * 0.5 * e.flip
                            if GF_DEBUG then
                                cR, cG, cB = 255, 0, 255   -- prova magenta
                                lastKey = -1
                            elseif e.key ~= lastKey then
                                lastKey = e.key
                                local c = (e.tone == 3) and cDark
                                    or ((e.tone == 2) and cMid or cLight)
                                cR = c8(math.min(1, c[1] * e.dr))
                                cG = c8(c[2] * e.dg)
                                cB = c8(c[3] * e.db)
                            end
                            local edgeK = math.min(1,
                                dRoad / (6 + 14 * perspK))
                            -- BROTO com stagger por moita: cresce do chão
                            -- em ~0.6-1.3s (calmo, "nascendo de verdade")
                            local age = t0 - rc.born
                            local gk = 1
                            if age < 1.4 then
                                gk = math.min(1, age / (0.6 + e.hk * 0.7))
                                gk = gk * gk * (3 - 2 * gk)
                                -- broto é animação de CPU: frame não cacheia
                                cacheable = false
                            end
                            -- hMul só na ALTURA: rasteira estreita
                            -- furaria o tapete (largura cobre o chão).
                            -- v7.4.10: SEM encurtamento por |lean| no
                            -- tapete — a mudança de escala re-amostrava o
                            -- sprite (nearest) e as fileiras ESCURAS da
                            -- base ganhavam/perdiam 1px em ONDA coerente
                            -- com a rajada ("varredura escurecendo a base
                            -- das gramas linha por linha", 2º feedback).
                            -- O balanço fica só no cisalhamento (kx), que
                            -- desloca pixels sem re-amostrar altura.
                            -- v7.4.13: kx × flip — a escala negativa do
                            -- espelho invertia TAMBÉM o cisalhamento:
                            -- metade das moitas dobrava pro lado oposto
                            -- do próprio lean ("um conjunto se mexe pra
                            -- esquerda, outro pra diagonal direita")
                            emit(math.floor(pxX),
                                math.floor(base + 1),
                                sK * sxK * e.flip,
                                sK * e.hMul
                                    * (0.35 + 0.65 * edgeK) * gk,
                                CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                                e.q, cR, cG, cB,
                                K_CLUMP, e.hk, e.dz, amp, 0)
                        end
                    end
                end
            end
        end
    end

    -- ========================================================================
    -- PASSE A2 (v7.4.4): FRANJA DA CRISTA — fileira de moitas sentadas NA
    -- curva do horizonte, silhueta contra o céu ("o fim do mundo tem
    -- capim"). Mata de vez a careca da borda, que a geometria da esfera
    -- amplifica nas laterais. ESTÁTICA como a treeline (anel
    -- "infinitamente longe": o mundo rolando não a move). O inimigo
    -- emergindo é desenhado ANTES do domo → sobe POR TRÁS do capim.
    -- ========================================================================
    if relTo > ctx.relCrest then
        local scaleC = (0.26 + g.persp(0.01) * 1.75) * P.heightK
        local stepC = math.max(6, 12 * scaleC * 0.7)
        local roadC = ctx.roadCenter(camZ + ctx.relCrest - 0.2, 0.01)
        local halfC = ctx.roadHalf(0.01)
        local cgap = ctx.castleGapHalf or 0
        for k = 0, math.floor(w / stepC) do
            local hk = hash(k * 13 + 7, 91)
            local px = ctx.x + k * stepC + (hk - 0.5) * stepC
            if math.abs(px - roadC) > halfC + 4
               and math.abs(px - g.cx) > cgap then
                local cy = g.crestYAt(px)
                if cy < g.bottomY - 6 then
                    -- v7.4.12: oscilador independente também aqui — a
                    -- franja é literalmente uma LINHA; com vento
                    -- compartilhado ela pulsava em conjunto na crista
                    -- (vento: GPU, tipo K_CREST)
                    local ht = hash(k * 29 + 3, 57)
                    local c = (ht < 0.45) and cDark or cMid
                    local sC = scaleC * (0.75 + hk * 0.5)
                    local flipC = (ht < 0.5) and 1 or -1
                    local q = clumpQuads[math.floor(hk * N_CLUMP) % N_CLUMP]
                    local ampC = (0.15 + hk * 0.2) * P.windAmp * P.dir
                        * 0.5 * flipC
                    emit(math.floor(px), math.floor(cy + 3),
                        sC * flipC, sC, CLUMP_W / 2, CELL_H, CLUMP_W, CELL_H,
                        q, c8(c[1]), c8(c[2]), c8(c[3]),
                        K_CREST, hk, 0, ampC, 0)
                end
            end
        end
    end

    -- ========================================================================
    -- PASSE B: ACENTOS — lâminas individuais + juncos + flores POR CIMA do
    -- tapete (movimento fino visível, flick, inércia — a "vida" da grama)
    -- ========================================================================
    for ci = first, last do
        -- MANCHAS de crescimento: grama real cresce em patches, não em
        -- distribuição uniforme — modulação espacial lenta da densidade
        local patch = 0.5 + 0.5 * math.sin(ci * 0.31)
        for slot = 0, SLOTS - 1 do
            local h1 = hash(ci, slot * 7 + 1)
            -- acento é TEMPERO (o tapete do passe A já cobre o chão):
            -- densidade menor, e só onde a lâmina individual é legível
            if h1 < (0.34 + 0.24 * patch) * P.density then
                local z = ci * Z_CELL + h1 * Z_CELL
                local rel = z - camZ
                local t = g.tOf(rel)
                if t and t > 0.18 and rel > relFrom and rel <= relTo then
                    local h2 = hash(ci, slot * 13 + 5)
                    local h3 = hash(ci, slot * 29 + 11)
                    local side = (slot % 2 == 0) and -1 or 1
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    -- da beira da estrada (levemente POR CIMA da borda —
                    -- grama invade o caminho) até a LARGURA TODA do campo
                    local pxX = roadC + side * (half * 0.94
                        + w * (0.004 + h2 * 0.52) * (0.45 + 0.55 * t))
                    -- v7.4.15: na encruzilhada o acento só some se cair
                    -- DENTRO de um braço (antes: sumia da região inteira)
                    local armBlock = false
                    if ctx.roadCenters then
                        local cs, aK = ctx.roadCenters(z, t)
                        if cs then
                            local ha = half * 0.94 * (aK or 1)
                            for a = 1, #cs do
                                if math.abs(pxX - cs[a]) < ha then
                                    armBlock = true
                                    break
                                end
                            end
                        end
                    end
                    if not armBlock
                       and math.abs(pxX - g.cx) < w * 0.52 then
                        local base = g.latY(pxX - g.cx, t)
                        local persp = g.persp(t)
                        local nx = (pxX - ctx.x) / w
                        -- TUFO: menos lâminas no longe (vira pontinho),
                        -- 3-6 no campo — cada uma com flexibilidade,
                        -- variante, fase e tom próprios
                        local nb = (t < 0.22) and (2 + math.floor(h3 * 2))
                            or (4 + math.floor(h3 * 4))
                        -- escala MAIS perspectiva: minúscula na crista,
                        -- graúda no primeiro plano.
                        -- v7.4.5: rampa ESPACIAL de nascimento — o acento
                        -- CRESCE conforme se aproxima (t 0.18→0.28) em vez
                        -- de popar em tamanho cheio numa linha fixa da
                        -- tela (feedback: "grama surgindo do nada"; agora
                        -- tem o mesmo "vir vindo" gradual das árvores)
                        local ramp = math.min(1, (t - 0.18) / 0.10)
                        ramp = ramp * ramp * (3 - 2 * ramp)
                        -- v7.4.6: tier de altura ponderado pela distância
                        -- da estrada (h2 É a distância do sorteio lateral)
                        local dfA = math.min(1, h2 * 1.8)
                        local pSmallA = 0.62 - 0.47 * dfA
                        local pTallA = 0.08 + 0.57 * dfA
                        local hrA = hash(ci * 47 + 6, slot * 37 + 13)
                        local hMulA
                        if hrA < pSmallA then
                            hMulA = 0.45 + h3 * 0.2
                        elseif hrA > 1 - pTallA then
                            hMulA = 1.30 + h3 * 0.5
                        else
                            hMulA = 0.82 + h3 * 0.34
                        end
                        local scale = (0.22 + persp * 1.85) * P.heightK
                            * ramp * hMulA
                        if scale * CELL_H >= 1.6 then
                            -- FLICK do tufo (impulso raro e curto — bicho/
                            -- lufada pontual): no shader, por h3
                            -- tom SECO/VIÇOSO por tufo (campos reais têm
                            -- manchas amareladas — GoT: variação por área)
                            local dryK = hash(ci * 7, slot * 3 + 9) * 0.30
                            for bi = 0, nb - 1 do
                                local hb = hash(ci * 31 + slot, bi * 17 + 3)
                                local hv = hash(ci * 53 + bi, slot * 19 + 7)
                                local broad = hv < P.broad
                                local vquad = broad
                                    and (N_THIN + math.floor(hb * N_BROAD))
                                    or math.floor(hv * N_THIN)
                                local s = scale * (0.72 + hb * 0.55)
                                local bx = pxX + (bi - nb / 2)
                                    * (1.6 + persp * 2.2) + hb * 3
                                -- física (raiz fixa, ponta balança,
                                -- flexível ∝ altura, encurta ao dobrar,
                                -- junco com INÉRCIA): no shader, a partir
                                -- de nx/z/hb/h3 — ver SHADER_VERTEX
                                -- tom em 3 níveis por lâmina (sombra /
                                -- meia-luz / luz) — moita com profundidade;
                                -- o gradiente raiz→ponta vem do atlas
                                local ht = hash(ci * 17 + bi, slot * 23 + 2)
                                local c = (ht < 0.25) and cDark
                                    or ((ht < 0.55) and cMid or cLight)
                                -- seco puxa pro amarelo (R sobe, B cai)
                                emit(math.floor(bx), math.floor(base + 1),
                                    s, s, CELL_W / 2, CELL_H, CELL_W, CELL_H,
                                    quads[vquad],
                                    c8(math.min(1, c[1] * (1 + dryK * 0.30))),
                                    c8(c[2] * (1 - dryK * 0.06)),
                                    c8(c[3] * (1 - dryK * 0.35)),
                                    broad and K_BROAD or K_BLADE,
                                    nx, z, hb, h3)
                            end
                            -- flor/broto na cor de acento do bioma (a
                            -- "vida" do campo — dourado/brasa/cristal...)
                            if h3 > 1 - P.flower and t > 0.25 then
                                emit(math.floor(pxX + h2 * 4 - 2),
                                    math.floor(base + 1),
                                    scale * 0.9, scale * 0.9,
                                    CELL_W / 2, CELL_H, CELL_W, CELL_H,
                                    quads[FLOWER_CELL],
                                    c8(cAcc[1]), c8(cAcc[2]), c8(cAcc[3]),
                                    K_FLOWER, nx, z, 0, h3)
                            end
                        end
                    end
                end
            end
        end
    end

    local count = qm.n - sliceStart
    if count > 0 then
        qm:upload(sliceStart, qm.n)
        local prev = love.graphics.getShader()
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        qm:draw(sliceStart, count, atlasImg)
        love.graphics.setShader(prev)
    end
    local sl = cache.slices[sliceIdx]
    if not sl then
        sl = {}
        cache.slices[sliceIdx] = sl
    end
    sl[1], sl[2], sl[3], sl[4] = relFrom, relTo, sliceStart, count
    GrassField._lastCount = count   -- instrumentação (bench)
    local st = GrassField.stats
    st.builds, st.sprites = st.builds + 1, st.sprites + count
end

-- limpa recursos GPU (troca de resolução etc.)
function GrassField.clearCache()
    atlasImg, quads, clumpQuads, qm, shader = nil, nil, nil, nil, nil
    frameId_, frameMode, cacheable = nil, "build", false
    cache = { valid = false, slices = {} }
    rowCache = {}
    lastCamZ = nil
end

return GrassField
