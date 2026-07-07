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
    quads = {}
    for i = 0, n - 1 do
        quads[i] = love.graphics.newQuad(i * CELL_W, 0, CELL_W, CELL_H,
            atlasW, CELL_H)
    end
    clumpQuads = {}
    for i = 0, N_CLUMP - 1 do
        clumpQuads[i] = love.graphics.newQuad(clumpX0 + i * CLUMP_W, 0,
            CLUMP_W, CELL_H, atlasW, CELL_H)
    end
end

local batch
local rowCache = {}   -- estáticos por fileira do tapete (podado por janela)
local lastCamZ        -- detecta câmera em movimento (broto desligado)
-- diagnóstico (prova magenta + log de LOD): cacheado no load — os.getenv
-- por moita custava 7.8k chamadas C/frame
local GF_DEBUG = os.getenv("GF_DEBUG")

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
    local gust = (f1 > 0 and f1 * f1 or 0) * 0.70
               + (f2 > 0 and f2 * f2 or 0) * 0.50
    -- (2) brisa local no TEMPO PRÓPRIO da lâmina
    local tb = t * (1 + (pers or 0) * 0.45) + (pers or 0) * 7.9
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
local SLOTS = 12           -- tentativas de tufo por célula (6 por lado)

function GrassField.draw(ctx)
    if GrassField.disabled then return end   -- A/B de benchmark
    bakeAtlas()
    if not batch then
        batch = love.graphics.newSpriteBatch(atlasImg, 8192, "stream")
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
    -- 3º tom (sombra): lâminas na sombra das vizinhas — profundidade de
    -- moita real (2 tons alternados liam como padrão artificial)
    local cDark = { cMid[1] * 0.68, cMid[2] * 0.68, cMid[3] * 0.68 }

    -- até QUASE a crista (-0.05, não -0.8): o corte antigo deixava uma
    -- faixa careca que a geometria da esfera AMPLIFICA nas laterais
    -- (t 0..0.03 = ~15px no centro, 40-100px nas bordas em tela larga —
    -- "o final da esfera sem grama", feedback com print ultrawide)
    -- câmera em movimento? (viagem/convergência — broto desligado)
    local camMoving = lastCamZ ~= nil
        and math.abs(camZ - lastCamZ) > 1e-4
    lastCamZ = camZ

    local first = math.floor(camZ / Z_CELL)
    local last = math.floor((camZ + ctx.relCrest - 0.05) / Z_CELL)

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
    -- poda do cache: fileiras fora da janela da câmera
    for kci in pairs(rowCache) do
        if kci < first or kci > last then rowCache[kci] = nil end
    end
    local WSTEP = 8                     -- passo da grade de vento (moitas)
    local wsamples = {}
    for ci = last, first, -1 do
        local z = ci * Z_CELL
        local rel = z - camZ
        local t = g.tOf(rel)
        if t and t > 0.002 then
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
                        table.sort(rc.order, function(a, b)
                            return rc[a].key < rc[b].key
                        end)
                        rowCache[ci] = rc
                    end
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    local clear = (ctx.forkActive
                        and rel > (ctx.forkRel or 10) - 1.5)
                        and (half + w * 0.17) or (half * 0.90)
                    local spread = 0.92 + 0.14 * t
                    local spanW = w * 1.06 * spread
                    local spacing = spanW / NK
                    local baseW = 12 * scale
                    local sxK = math.max(1, spacing / math.max(1, baseW)
                        * 1.25)
                    -- grade de vento da fileira (13 amostras + lerp)
                    for si = 0, NK, WSTEP do
                        local sx2 = g.cx + (si / NK - 0.5) * spanW
                        wsamples[si] = windAt((sx2 - ctx.x) / w, z, t0, P, 0)
                    end
                    local lastKey = -1
                    for oi = 1, NK do
                        local k = rc.order[oi]
                        local e = rc[k]
                        local pxX = g.cx + e.lf * spanW
                        local dRoad = math.abs(pxX - roadC) - clear
                        if dRoad > 0 and math.abs(pxX - g.cx) < w * 0.53 then
                            -- jitter FIXO (×3, não ×M): atrelado ao M, a
                            -- moita dava um pulo de profundidade quando o
                            -- LOD trocava de nível durante a viagem
                            local zk = z + e.dz * Z_CELL * 3
                            local tk = g.tOf(zk - camZ) or t
                            local perspK = g.persp(tk)
                            local sK = (0.26 + perspK * 1.75) * P.heightK
                            local base = g.latY(pxX - g.cx, tk)
                            local s0 = k - (k % WSTEP)
                            local f = (k - s0) / WSTEP
                            local w0 = wsamples[s0]
                            local w1 = wsamples[s0 + WSTEP] or w0
                            -- v7.4.9: FASE PESSOAL por moita (1 sin) — a
                            -- grade por fileira dava só amplitude
                            -- individual e a fileira inteira dobrava em
                            -- sincronia ("clareia tudo em conjunto")
                            local lean = (w0 + (w1 - w0) * f)
                                * (0.5 + e.hk * 0.5)
                                + math.sin(t0 * (1.1 + e.hk)
                                    + e.hk * 21) * 0.09 * P.windAmp
                            if GF_DEBUG then
                                batch:setColor(1, 0, 1, 1)   -- prova magenta
                                lastKey = -1
                            elseif e.key ~= lastKey then
                                lastKey = e.key
                                local c = (e.tone == 3) and cDark
                                    or ((e.tone == 2) and cMid or cLight)
                                batch:setColor(
                                    math.min(1, c[1] * e.dr),
                                    c[2] * e.dg, c[3] * e.db, 1)
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
                            batch:add(e.q, math.floor(pxX),
                                math.floor(base + 1), 0,
                                sK * sxK * e.flip,
                                sK * e.hMul
                                    * (0.35 + 0.65 * edgeK) * gk,
                                CLUMP_W / 2, CELL_H, lean * 0.5, 0)
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
    do
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
                    local lean = windAt((px - ctx.x) / w,
                        camZ + ctx.relCrest, t0, P, hk) * (0.5 + hk * 0.5)
                    local ht = hash(k * 29 + 3, 57)
                    local c = (ht < 0.45) and cDark or cMid
                    batch:setColor(c[1], c[2], c[3], 1)
                    local sC = scaleC * (0.75 + hk * 0.5)
                    batch:add(clumpQuads[math.floor(hk * N_CLUMP) % N_CLUMP],
                        math.floor(px), math.floor(cy + 3), 0,
                        sC * ((ht < 0.5) and 1 or -1), sC,
                        CLUMP_W / 2, CELL_H, lean * 0.5, 0)
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
                if t and t > 0.18 then
                    -- fork: os braços da estrada varrem a faixa central —
                    -- capim some do trecho bifurcado enquanto o fork existe
                    if not (ctx.forkActive and rel > (ctx.forkRel or 10) - 1.5) then
                    local h2 = hash(ci, slot * 13 + 5)
                    local h3 = hash(ci, slot * 29 + 11)
                    local side = (slot % 2 == 0) and -1 or 1
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    -- da beira da estrada (levemente POR CIMA da borda —
                    -- grama invade o caminho) até a LARGURA TODA do campo
                    local pxX = roadC + side * (half * 0.94
                        + w * (0.004 + h2 * 0.52) * (0.45 + 0.55 * t))
                    if math.abs(pxX - g.cx) < w * 0.52 then
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
                            -- FLICK do tufo: impulso raro e curto (bicho/
                            -- lufada pontual) — sacode e assenta
                            local fe = math.sin(t0 * 0.37 + h3 * 41)
                            local flick = (fe > 0.92)
                                and ((fe - 0.92) / 0.08)
                                    * math.sin(t0 * 11 + h3 * 9) * 0.45
                                or 0
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
                                -- física: raiz fixa, ponta balança;
                                -- flexível ∝ altura; encurta ao dobrar.
                                -- Junco largo tem INÉRCIA: relógio mais
                                -- lento e balanço mais fundo (peso real)
                                local flex = 0.55 + hb * 0.75
                                local lean
                                if broad then
                                    lean = windAt(nx, z, t0 * 0.62, P,
                                        hb * 0.4) * flex * 1.30
                                else
                                    lean = windAt(nx, z, t0, P, hb) * flex
                                end
                                lean = lean + flick * flex
                                local kx = lean * 0.55
                                local sy = s * (1 - math.abs(lean) * 0.16)
                                -- tom em 3 níveis por lâmina (sombra /
                                -- meia-luz / luz) — moita com profundidade;
                                -- o gradiente raiz→ponta vem do atlas
                                local ht = hash(ci * 17 + bi, slot * 23 + 2)
                                local c = (ht < 0.25) and cDark
                                    or ((ht < 0.55) and cMid or cLight)
                                -- seco puxa pro amarelo (R sobe, B cai)
                                batch:setColor(
                                    math.min(1, c[1] * (1 + dryK * 0.30)),
                                    c[2] * (1 - dryK * 0.06),
                                    c[3] * (1 - dryK * 0.35), 1)
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
    GrassField._lastCount = batch:getCount()   -- instrumentação (bench)
end

-- limpa recursos GPU (troca de resolução etc.)
function GrassField.clearCache()
    atlasImg, quads, clumpQuads, batch = nil, nil, nil, nil
    rowCache = {}
    lastCamZ = nil
end

return GrassField
