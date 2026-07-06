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
    -- viajante" do Ghost of Tsushima)
    local f1 = math.sin(ph * 0.85 - t * P.gustSpeed)
    local f2 = math.sin(ph * 0.41 - t * P.gustSpeed * 0.737 + 2.4)
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

    local first = math.floor(camZ / Z_CELL)
    local last = math.floor((camZ + ctx.relCrest - 0.8) / Z_CELL)

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
    -- fica estranho"): a versão anterior selecionava fileiras em espaço de
    -- tela relativo (re-embaralhava a seleção a cada frame de viagem) e
    -- espaçava as moitas por passo dependente da profundidade (a moita
    -- DESLIZAVA de lado ao se aproximar). Agora: decimação por potência de
    -- 2 fixa por fileira + moita em fração FIXA da largura.
    local NK = 96                       -- moitas por fileira (fração fixa)
    for ci = last, first, -1 do
        local z = ci * Z_CELL
        local rel = z - camZ
        local t = g.tOf(rel)
        if t and t > 0.03 then
            local persp = g.persp(t)
            local scale = (0.26 + persp * 1.75) * P.heightK
            local ch = scale * CELL_H
            if ch >= 2 then
                -- espaçamento na tela até a fileira vizinha mais próxima
                local t2 = g.tOf(rel - Z_CELL)
                local dy = t2 and (g.latY(0, t2) - g.latY(0, t)) or ch
                -- decimação ESTÁVEL: M só depende da profundidade e ci é
                -- fixo no mundo → cada fileira mantém identidade ao se
                -- aproximar; quando M cai (8→4→2→1) as fileiras novas
                -- entram exatamente onde as vizinhas já se sobrepõem
                local M = 1
                while dy * M < ch * 0.30 and M < 64 do M = M * 2 end
                if ci % M == 0 then
                    local roadC = ctx.roadCenter(z, t)
                    local half = ctx.roadHalf(t)
                    local clear = (ctx.forkActive
                        and rel > (ctx.forkRel or 10) - 1.5)
                        and (half + w * 0.17) or (half * 0.90)
                    -- deriva perspectiva SUAVE pra fora (contínua em t —
                    -- nada de salto) + stretch horizontal pra fechar vãos
                    -- no longe (moita natural < espaçamento da grade)
                    local spread = 0.92 + 0.14 * t
                    local spacing = (w * 1.06 * spread) / NK
                    local baseW = 12 * scale
                    local sxK = math.max(1, spacing / math.max(1, baseW)
                        * 1.25)
                    for k = 0, NK - 1 do
                        local hk = hash(ci * 3 + 1, k * 11 + 2)
                        local lf = (k + (hk - 0.5) * 0.9) / NK - 0.5
                        local pxX = g.cx + lf * w * 1.06 * spread
                        local dRoad = math.abs(pxX - roadC) - clear
                        if dRoad > 0 and math.abs(pxX - g.cx) < w * 0.53 then
                            -- jitter de PROFUNDIDADE fixo por moita (quebra
                            -- as "fileiras de plantação" sem perder a
                            -- ancoragem: zk é do mundo, não da tela)
                            local hz = hash(ci * 13 + 4, k * 17 + 6)
                            local zk = z + (hz - 0.5) * Z_CELL * M * 0.9
                            local tk = g.tOf(zk - camZ) or t
                            local perspK = g.persp(tk)
                            local sK = (0.26 + perspK * 1.75) * P.heightK
                                * (0.80 + hk * 0.45)   -- altura varia
                            local base = g.latY(pxX - g.cx, tk)
                            local nx = (pxX - ctx.x) / w
                            local lean = windAt(nx, zk, t0, P, hk)
                                * (0.5 + hk * 0.5)
                            local ht = hash(ci * 19, k * 7 + 3)
                            local c = (ht < 0.30) and cDark
                                or ((ht < 0.62) and cMid or cLight)
                            local dryK = hash(ci * 5 + 2, k * 3 + 1) * 0.30
                            batch:setColor(
                                math.min(1, c[1] * (1 + dryK * 0.30)),
                                c[2] * (1 - dryK * 0.06),
                                c[3] * (1 - dryK * 0.35), 1)
                            local q = clumpQuads[math.floor(hk * N_CLUMP)
                                % N_CLUMP]
                            local flip = (hash(ci, k) < 0.5) and 1 or -1
                            -- beira da estrada: encolhe SUAVE em vez de
                            -- sumir de repente (o meandro muda o roadC
                            -- conforme a fileira anda — pop visível)
                            local edgeK = math.min(1,
                                dRoad / (6 + 14 * perspK))
                            batch:add(q, math.floor(pxX),
                                math.floor(base + 1), 0,
                                sK * sxK * flip,
                                sK * (1 - math.abs(lean) * 0.12)
                                    * (0.35 + 0.65 * edgeK),
                                CLUMP_W / 2, CELL_H, lean * 0.5, 0)
                        end
                    end
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
                        -- graúda no primeiro plano
                        local scale = (0.22 + persp * 1.85) * P.heightK
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
end

-- limpa recursos GPU (troca de resolução etc.)
function GrassField.clearCache()
    atlasImg, quads, batch = nil, nil, nil
end

return GrassField
