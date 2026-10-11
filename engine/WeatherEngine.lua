-- engine/WeatherEngine.lua
-- ============================================================================
-- WEATHERENGINE — clima com PROFUNDIDADE de verdade no domo (v1, Out/2026)
-- ============================================================================
-- A grama mostrou o vento no CHÃO; aqui o mesmo vento aparece no AR. Neve,
-- chuva, cinza, folhas e sementes vivem em COORDENADAS DE MUNDO (lateral
-- normalizada, z absoluto, altura acima do chão) e são projetadas pela
-- mesma geometria do domo que os props:
--   - tamanho e velocidade de queda na tela ∝ persp(t) (paralaxe real: a
--     neve do fundo quase para, a da frente despenca grande);
--   - cada partícula CAI até a latitude dela (g.latY) e POUSA ali — floco
--     assenta e some no capim, gota abre uma coroa de 2 pixels;
--   - o desenho entra no PAINTER por profundidade (REGRA DE PROFUNDIDADE do
--     WorldRoad): o WorldRoad chama flushTo(rel) junto com as fatias de
--     grama, então árvore mais perto cobre o floco, floco mais perto cobre
--     a árvore. O que está além da crista desenha ANTES do domo e some
--     atrás da curva do mundo;
--   - o VENTO é o GrassField.windAt — a MESMA rajada que deita o capim
--     empurra a neve e inclina a chuva (coerência é o que vende o efeito);
--   - o mundo andando (viagem) traz as partículas pra cima de você: elas
--     moram em z de mundo, não na tela.
--
-- TEMPESTADE (bioma com storm): intensidade respira num ciclo longo; no
-- pico cai raio — o relâmpago é um polígono de PIXELS (2px, sem alpha
-- liso) desenhado ATRÁS da silhueta frontal das montanhas, e o clarão é o
-- AMBIENTE do lightmap subindo até ~branco. O LightEngine é multiply-only:
-- o clarão só DEVOLVE a arte original (nunca pinta por cima — doutrina de
-- luz, memory/lighting_engine.md). Antes dele a tempestade escurece o
-- ambiente, e é esse contraste que faz o raio "acender o mundo".
--
-- ACESSIBILIDADE: reducedMotion corta a densidade (~35%) e DESLIGA clarão,
-- raio e trovão (flash é risco fotossensível). Dois pulsos por raio no
-- máximo e ≥5 s entre raios — abaixo de 3 flashes/s (WCAG 2.3.1).
--
-- PERF: 1 QuadMesh (FFI) por frame, ~1 draw por fatia de profundidade;
-- sem closures nem love.graphics.* nos laços. Não toca no cache da grama.
--
-- USO (ver WorldRoad):
--   WeatherEngine.update(dt, { biomeId=, camZ=, time=, windP=GrassField preset })
--   WeatherEngine.beginFrame{ geom=g, x=, w=, camZ=, time=, relCrest=, tPow= }
--   WeatherEngine.flushTo(relLow)   -- dentro das fatias de grama
--   WeatherEngine.flushAll()        -- primeiro plano, depois dos props
--   WeatherEngine.drawSky(g, x, w)  -- raio (entre nuvens e montanhas da frente)
--   amb = WeatherEngine.modulateAmbient(amb)   -- antes do LightEngine.beginFrame
-- ============================================================================

local WeatherEngine = {}
local QuadMesh = require("engine.QuadMesh")
local GrassField = require("engine.GrassField")

local floor, min, max, sin, abs = math.floor, math.min, math.max, math.sin, math.abs
local c8 = QuadMesh.c8

-- ----------------------------------------------------------------------------
-- PRESETS por bioma. Unidades:
--   count  = partículas vivas na intensidade 1
--   fall   = queda em fração da ALTURA da área por segundo, a persp 1
--   size   = px do floco a persp 1 numa área de 768 px de altura
--   windK  = quanto a rajada do capim empurra (lateral normalizada/s)
--   land   = segundos pousado antes de sumir
--   fg     = fração no PRIMEIRO PLANO (na frente de tudo, maior)
-- ----------------------------------------------------------------------------
WeatherEngine.PRESETS = {
    -- campos: sementes de dente-de-leão e pólen soltos nas rajadas — leve,
    -- quase só deriva (a rajada LEVANTA a semente)
    fields = { kind = "seed", count = 96, fall = 0.035, fallVar = 0.5,
               size = 2.6, windK = 0.20, land = 1.6, fg = 0.10, lift = 0.05,
               colors = { { 0.98, 0.96, 0.88 }, { 0.93, 0.90, 0.76 } } },
    -- colinas: noite de TEMPESTADE — chuva fina que engrossa e raio no pico
    highlands = { kind = "rain", count = 560, fall = 1.75, fallVar = 0.25,
               size = 7, windK = 0.10, land = 0.16, fg = 0.05,
               colors = { { 0.70, 0.74, 0.92 }, { 0.82, 0.85, 0.98 } },
               alpha = 0.78,
               storm = { period = 70, base = 0.30, peak = 1.0, phase = 0.42,
                         lightning = true, dark = 0.24 } },
    -- abismo: cinza caindo + brasas SUBINDO do chão rachado
    abyss = { kind = "ash", count = 400, fall = 0.075, fallVar = 0.5,
               size = 2.0, windK = 0.10, land = 1.2, fg = 0.06,
               colors = { { 0.72, 0.66, 0.62 }, { 0.55, 0.50, 0.50 },
                          { 0.86, 0.80, 0.74 } },
               rise = { count = 46, fall = -0.11, size = 1,
                        colors = { { 1.00, 0.55, 0.18 }, { 1.00, 0.78, 0.30 } } } },
    -- geleira: NEVE em três profundidades; rajada forte estica o floco
    frost = { kind = "snow", count = 1100, fall = 0.10, fallVar = 0.45,
               size = 2.6, windK = 0.17, land = 1.4, fg = 0.06,
               colors = { { 0.95, 0.97, 1.00 }, { 0.84, 0.89, 0.98 } },
               storm = { period = 55, base = 0.55, peak = 1.0, phase = 0.10,
                         dark = 0.06 } },
    -- pântano: garoa constante, relâmpago raro e distante
    marsh = { kind = "rain", count = 380, fall = 1.35, fallVar = 0.25,
               size = 5, windK = 0.07, land = 0.16, fg = 0.04,
               colors = { { 0.82, 0.90, 0.76 }, { 0.92, 0.96, 0.86 } },
               alpha = 0.74,
               storm = { period = 90, base = 0.45, peak = 0.85, phase = 0.70,
                         lightning = true, dark = 0.12 } },
    -- crepúsculo: folhas de outono girando nas rajadas
    dusk = { kind = "leaf", count = 130, fall = 0.06, fallVar = 0.4,
               size = 3, windK = 0.22, land = 2.2, fg = 0.10,
               colors = { { 0.88, 0.48, 0.20 }, { 0.78, 0.30, 0.22 },
                          { 0.92, 0.70, 0.30 } } },
}

-- folha solta de árvore numa rajada (emitLeaf) — preset auxiliar
local LEAF_SHED = { kind = "leaf", fall = 0.07, fallVar = 0.4, size = 3,
                    windK = 0.24, land = 1.8, fg = 0, colors = { { 1, 1, 1 } } }
local MAX_SHED = 28

-- ----------------------------------------------------------------------------
-- estado
-- ----------------------------------------------------------------------------
local P = {}               -- partículas (tabelas reaproveitadas)
local nP = 0
local rng = love.math.newRandomGenerator(9173)
local geo = nil            -- último frame projetado (pra nascer no topo)
local cur = nil            -- preset do bioma atual
local curId = nil
local prefill = true       -- 1º frame de um bioma: já nasce cheio
local overrideI = nil      -- tools/teste: intensidade fixa
local time = 0
local strike = nil         -- raio em curso
local nextStrike = 6
local thunderAt = nil
local qm = nil
local relS, qEnd = {}, {}
local nS, cursorK = 0, 0
local fgStart = 0          -- índice (em order) do 1º do primeiro plano
local microN = 0
local lastCtx = nil

WeatherEngine.disabled = false
WeatherEngine.stats = { particles = 0, quads = 0, flushes = 0 }

local function reduced()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function smooth(a, b, x)
    local t = min(1, max(0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
end

-- ----------------------------------------------------------------------------
-- intensidade (0..1) do clima do bioma: tempestade respira num ciclo longo
-- ----------------------------------------------------------------------------
local function intensityOf(pr, t)
    if overrideI then return overrideI end
    local st = pr and pr.storm
    if not st then return 1 end
    local ph = ((t / st.period) + (st.phase or 0)) % 1
    local env = smooth(0.10, 0.32, ph) * (1 - smooth(0.62, 0.86, ph))
    return st.base + (st.peak - st.base) * env
end

function WeatherEngine.intensity()
    return cur and intensityOf(cur, time) or 0
end

-- escuridão da tempestade (0..1): só acima do nível base do clima
function WeatherEngine.storm()
    local st = cur and cur.storm
    if not st then return 0 end
    local i = intensityOf(cur, time)
    return max(0, (i - st.base) / max(0.01, st.peak - st.base))
end

-- ----------------------------------------------------------------------------
-- espalhamento lateral por profundidade: longe converge pro centro
-- ----------------------------------------------------------------------------
local function spread(t) return 0.55 + 0.45 * t end

local function tOfRel(rel, relCrest, tPow)
    local t = 1 - rel / relCrest
    if t < 0 then return 0, true end
    return min(1, t) ^ tPow, false
end

-- (re)nasce uma partícula. fresh = preenchimento inicial (altura aleatória)
local function spawn(p, pr, camZ, fresh, isRise)
    local g = geo
    p.pr = pr
    p.tint = nil
    p.rise = isRise or false
    p.st = 0
    p.lt = 0
    p.ph = rng:random() * 6.2832
    p.ci = rng:random(1, #(isRise and pr.rise.colors or pr.colors))
    p.fg = (not isRise) and rng:random() < (pr.fg or 0)
    local relCrest, tPow = g.relCrest, g.tPow
    local t, rel
    if p.fg then
        t = 1; rel = 0.4 + rng:random() * 0.6
    elseif (not isRise) and rng:random() < 0.16 then
        -- além da crista: cai ATRÁS da curva do mundo (some no domo)
        rel = relCrest + rng:random() * 7; t = 0
    else
        t = rng:random()
        rel = relCrest * (1 - t ^ (1 / tPow))
    end
    p.z = camZ + rel
    local half = 0.53 / spread(t)
    p.lx = (rng:random() * 2 - 1) * half
    local fv = pr.fallVar or 0
    local fall = isRise and pr.rise.fall or pr.fall
    p.vf = fall * (1 + (rng:random() * 2 - 1) * fv)
    if isRise then
        p.hg = 0
    else
        -- altura que põe o nascimento logo acima do topo da área
        local dx = p.lx * g.w * spread(t)
        local gy = g.latY(dx, t)
        local top = (gy - g.y + 12) / (g.persp(t) * g.h)
        if p.fg then top = top * 1.02 end
        p.hg = fresh and rng:random() * top or top * (1 + rng:random() * 0.08)
    end
end

-- ----------------------------------------------------------------------------
-- UPDATE: simulação em coordenadas de mundo
-- ----------------------------------------------------------------------------
function WeatherEngine.update(dt, ctx)
    local _t0 = love.timer.getTime()
    lastCtx = ctx
    time = ctx.time or (time + dt)
    if WeatherEngine.disabled then nP = 0; return end
    local id = ctx.biomeId
    if id ~= curId then
        curId = id
        cur = WeatherEngine.PRESETS[id]
        strike, thunderAt = nil, nil
        nextStrike = time + 4 + rng:random() * 4
    end
    local camZ = ctx.camZ or 0
    local windP = ctx.windP or GrassField.PRESETS[id] or GrassField.PRESETS.fields
    local rm = reduced()

    -- quantas partículas este frame quer (intensidade × acessibilidade)
    local I = cur and intensityOf(cur, time) or 0
    local want = cur and floor(cur.count * I * (rm and 0.35 or 1) + 0.5) or 0
    local wantRise = (cur and cur.rise) and floor(cur.rise.count * (rm and 0.35 or 1)) or 0

    if geo then
        local relCrest = geo.relCrest
        -- conta vivas por tipo
        local nMain, nRise = 0, 0
        for i = 1, nP do
            local p = P[i]
            if p.pr == cur then
                if p.rise then nRise = nRise + 1 else nMain = nMain + 1 end
            end
        end
        -- avança
        local i = 1
        while i <= nP do
            local p = P[i]
            local pr = p.pr
            local dead = false
            local rel = p.z - camZ
            if rel < -0.6 then
                dead = true
            elseif p.st == 1 then
                p.lt = p.lt - dt
                if p.lt <= 0 then dead = true end
            else
                local t = tOfRel(rel, relCrest, geo.tPow)
                local nx = 0.5 + p.lx * spread(t)
                local wind = GrassField.windAt(nx, p.z, time, windP, p.ph * 0.16)
                local kind = pr.kind
                local sway = 0
                if kind == "snow" or kind == "ash" then
                    sway = sin(time * 1.3 + p.ph) * 0.020
                elseif kind == "leaf" or kind == "seed" then
                    sway = sin(time * 2.1 + p.ph) * 0.035
                end
                p.lx = p.lx + (wind * pr.windK + sway) * dt
                p.wind = wind
                local vf = p.vf
                if pr.lift and wind * wind > 0.5 then
                    vf = vf - pr.lift * (wind * wind - 0.5)   -- rajada LEVANTA
                end
                p.hg = p.hg - vf * dt
                -- borda lateral: dá a volta (densidade constante)
                local half = 0.56 / spread(t)
                if p.lx > half then p.lx = p.lx - 2 * half
                elseif p.lx < -half then p.lx = p.lx + 2 * half end
                if p.rise then
                    -- brasa: sobe até sair do topo
                    local dx = p.lx * geo.w * spread(t)
                    local gy = geo.latY(dx, t)
                    if gy - p.hg * geo.persp(t) * geo.h < geo.y - 6 then dead = true end
                elseif p.hg <= 0 then
                    if rel > relCrest or p.fg then
                        dead = true            -- atrás da curva / 1º plano: sem pouso
                    else
                        p.hg = 0; p.st = 1; p.lt = pr.land or 0.5
                    end
                end
            end
            if dead then
                local stillWanted
                if p.shed then
                    stillWanted = false
                elseif p.pr ~= cur then
                    stillWanted = false
                elseif p.rise then
                    stillWanted = nRise <= wantRise
                else
                    stillWanted = nMain <= want
                end
                if stillWanted and not prefill then
                    spawn(p, cur, camZ, false, p.rise)
                    i = i + 1
                else
                    if p.pr == cur then
                        if p.rise then nRise = nRise - 1 else nMain = nMain - 1 end
                    end
                    P[i] = P[nP]; P[nP] = p; nP = nP - 1
                end
            else
                i = i + 1
            end
        end
        -- completa o que falta (nasce no topo; 1º frame do bioma = cheio)
        if cur then
            local budget = prefill and 100000 or max(4, floor(want * dt * 0.8))
            while nMain < want and budget > 0 do
                nP = nP + 1
                local p = P[nP] or {}
                P[nP] = p
                p.shed = false
                spawn(p, cur, camZ, prefill, false)
                nMain = nMain + 1
                budget = budget - 1
            end
            while nRise < wantRise do
                nP = nP + 1
                local p = P[nP] or {}
                P[nP] = p
                p.shed = false
                spawn(p, cur, camZ, prefill, true)
                if prefill then p.hg = rng:random() * 0.6 end
                nRise = nRise + 1
            end
            prefill = false
        end
    end

    -- RAIO: só no pico da tempestade, nunca com reducedMotion
    local st = cur and cur.storm
    if st and st.lightning and not rm then
        if not strike and time >= nextStrike then
            if WeatherEngine.storm() > 0.55 then
                WeatherEngine.strike()
            else
                nextStrike = time + 1.5
            end
        end
    end
    if strike and time - strike.t0 > 0.9 then strike = nil end
    if thunderAt and time >= thunderAt then
        -- trovão atrasado demais (cena ficou parada no meio) não toca solto
        local late = time - thunderAt > 1.0
        thunderAt = nil
        local Sfx = require("src.systems.Sfx")
        if late then
            -- nada: o raio que o originou já passou faz tempo
        elseif Sfx.has("thunder") then
            Sfx.playWithVariation("thunder", 1.0, 0.12)
        elseif not WeatherEngine._warnedThunder and _G.audioSystem then
            WeatherEngine._warnedThunder = true
            print("[WeatherEngine] som 'thunder' não registrado — raio sem trovão")
        end
    end
    WeatherEngine.stats.particles = nP
    WeatherEngine.stats.msUpdate = (love.timer.getTime() - _t0) * 1000
end

-- dispara um raio agora (tools/teste chamam direto). Polilinha de pixels
-- por deslocamento de ponto médio, em coordenadas NORMALIZADAS (resize-safe)
function WeatherEngine.strike(xr)
    local pts = { { xr or (0.12 + rng:random() * 0.76), 0 } }
    local n = 14
    local x = pts[1][1]
    for k = 1, n do
        x = x + (rng:random() * 2 - 1) * 0.022
        pts[#pts + 1] = { x, k / n }
    end
    -- 1-2 galhos curtos
    local branches = {}
    for b = 1, rng:random(1, 2) do
        local from = rng:random(4, n - 4)
        local bx, by = pts[from][1], pts[from][2]
        local dir = rng:random() < 0.5 and -1 or 1
        local br = { { bx, by } }
        for k = 1, rng:random(3, 5) do
            bx = bx + dir * (0.010 + rng:random() * 0.016)
            by = by + 1 / n * (0.6 + rng:random() * 0.5)
            br[#br + 1] = { bx, by }
        end
        branches[b] = br
    end
    strike = { t0 = time, pts = pts, branches = branches }
    nextStrike = time + 5 + rng:random() * 7
    thunderAt = time + 0.5 + rng:random() * 1.1
end

-- envelope do clarão: dois pulsos e decaimento (0..1)
local function flashAt(e)
    if e < 0 then return 0 end
    if e < 0.06 then return 1 end
    if e < 0.12 then return 0.22 end
    if e < 0.19 then return 0.85 end
    return 0.85 * math.exp(-(e - 0.19) * 7)
end
WeatherEngine._flashAt = flashAt

function WeatherEngine.flash()
    if not strike or reduced() or WeatherEngine.disabled then return 0 end
    return flashAt(time - strike.t0)
end

-- ambiente do lightmap: tempestade escurece, raio devolve a arte. NUNCA
-- passa de 1 (multiply-only — o clarão não pinta, só tira a sombra)
local _amb = { 1, 1, 1 }
function WeatherEngine.modulateAmbient(amb)
    if WeatherEngine.disabled or not cur then return amb end
    local st = cur.storm
    local dk = st and (st.dark or 0) * WeatherEngine.storm() or 0
    local f = WeatherEngine.flash() * 0.92
    for k = 1, 3 do
        local a = (amb[k] or 1) * (1 - dk)
        local tgt = (k == 3) and 1.0 or 0.96
        _amb[k] = min(1, a + (tgt - a) * f)
    end
    return _amb
end

-- ----------------------------------------------------------------------------
-- PROJEÇÃO + LOTE do frame (ordenado do fundo pra frente)
-- ----------------------------------------------------------------------------

-- prova de cobertura: WeatherEngine.debugMagenta = true pinta tudo de
-- magenta e engorda 4px (floco claro no céu claro some na captura — foi
-- assim que se viu que o v1 estava desenhando, só pequeno demais)
WeatherEngine.debugMagenta = false
local function quad(x, y, w, h, R, G, B, A)
    if WeatherEngine.debugMagenta then R, G, B, A, w, h = 1, 0, 1, 1, w + 4, h + 4 end
    qm:rect(x, y, w, h, 0, 0, 1, 1, R, G, B, A)
end

function WeatherEngine.beginFrame(f)
    local g = f.geom
    geo = geo or {}
    geo.y, geo.h, geo.w, geo.x = g.y, g.h, f.w, f.x
    geo.latY, geo.persp, geo.cx = g.latY, g.persp, g.cx
    geo.relCrest, geo.tPow = f.relCrest, f.tPow
    -- 1º frame com geometria: o bioma já nasce com o clima cheio (o update
    -- anterior não sabia onde é o topo da tela)
    if prefill and cur and lastCtx then WeatherEngine.update(0, lastCtx) end
    nS, cursorK, fgStart, microN = 0, 0, 0, 0
    if WeatherEngine.disabled or nP == 0 then return end
    qm = qm or QuadMesh.new(1024)
    qm:reset()
    local camZ, relCrest, tPow = f.camZ, f.relCrest, f.tPow
    local w, h = f.w, g.h
    local hk = h / 768
    -- PIXEL DE ARTE: a cena é pixel art ampliada (~3-4 px de tela por pixel
    -- da arte). Partícula mede e anda nessa grade — floco de 1px de tela lia
    -- como poeira de monitor, não como neve do mundo.
    local u = max(1, floor(h / 250 + 0.5))

    -- chave de ordenação (1º plano vai pro fim, atrás da crista pro começo)
    for i = 1, nP do
        local p = P[i]
        p.sortRel = p.fg and -100 or (p.z - camZ)
    end
    -- INSERÇÃO sobre a própria lista viva: de um frame pro outro ela já
    -- está quase ordenada (só quem renasceu muda de lugar) — O(n + trocas),
    -- ~5× mais barato que table.sort com 1100 flocos (medido 0.40 → ~0.08 ms)
    local _t1 = love.timer.getTime()
    for i = 2, nP do
        local p = P[i]
        local key = p.sortRel
        local j = i - 1
        while j >= 1 and P[j].sortRel < key do
            P[j + 1] = P[j]
            j = j - 1
        end
        P[j + 1] = p
    end
    local order = P
    WeatherEngine.stats.msSort = (love.timer.getTime() - _t1) * 1000

    local LightEngine = package.loaded["engine.LightEngine"]
    for k = 1, nP do
        local p = order[k]
        local pr = p.pr
        local rel = p.z - camZ
        local t, behind = tOfRel(rel, relCrest, tPow)
        local ps = g.persp(t)
        local dx = p.lx * w * spread(t)
        local gx = g.cx + dx
        local gy = behind and g.crestYAt(gx) or g.latY(dx, t)
        local py = gy - p.hg * ps * h
        -- origem na GRADE de pixel de arte (tudo abaixo mede em pixels de arte)
        local px = floor(gx / u) * u
        py = floor(py / u) * u
        local col = (p.rise and pr.rise.colors or pr.colors)[p.ci] or pr.colors[1]
        local cr, cg, cb = col[1], col[2], col[3]
        if p.tint then cr, cg, cb = p.tint[1], p.tint[2], p.tint[3] end
        local fgk = p.fg and 1.6 or 1
        local n = max(1, floor((p.rise and pr.rise.size or pr.size) * ps * fgk + 0.5))
        -- longe perde contraste (perspectiva atmosférica, como os props)
        local A = 1
        if behind then A = 0.55 elseif t < 0.25 then A = 0.70 + t * 1.2 end
        local kind = p.rise and "ember" or pr.kind
        local wind = p.wind or 0

        if p.st == 1 then
            -- POUSADO
            local life = p.lt / max(0.01, pr.land or 0.5)
            if kind == "rain" then
                -- coroa: 2 quadros (abre e espalha), 1 pixel de arte por gota
                local e = 1 - life
                local A2 = (pr.alpha or 0.8) * (e < 0.5 and 1 or 0.6) * A
                local off = (e < 0.5) and 1 or 2
                quad(px - (off + 1) * u, py - off * u, u, u, cr, cg, cb, A2)
                quad(px + off * u, py - off * u, u, u, cr, cg, cb, A2)
                if e < 0.5 then quad(px - u, py - u, 2 * u, u, cr, cg, cb, A2 * 0.8) end
            else
                local fade = min(1, life * 3)
                local lw = (kind == "leaf") and n + 1 or n
                quad(px, py - u, lw * u, u, cr * 0.92, cg * 0.92, cb * 0.92, A * fade)
            end
        elseif kind == "rain" then
            -- risco inclinado pelo vento (quad cisalhado: degrau de pixels)
            local len = max(2, floor(pr.size * ps * fgk + 0.5)) * u
            local kx = -wind * 0.30
            local R, G, B, AA = c8(cr), c8(cg), c8(cb), c8((pr.alpha or 0.8) * A)
            qm:sprite(px, py, 1, 1, 0, len, kx, u, len, 0, 0, 1, 1, R, G, B, AA)
        elseif kind == "snow" or kind == "ash" then
            if n >= 3 then
                -- floco em "+" (pixel art, não disco)
                quad(px - u, py - 2 * u, 3 * u, u, cr, cg, cb, A)
                quad(px, py - 3 * u, u, 3 * u, cr, cg, cb, A)
            else
                quad(px, py - n * u, n * u, n * u, cr, cg, cb, A)
            end
            -- rajada forte: rastro horizontal (o vento VISÍVEL no ar)
            local aw = abs(wind)
            if aw > 0.95 then
                local tl = max(1, floor(n * (aw - 0.6) * 1.8)) * u
                if wind > 0 then
                    quad(px - tl, py - u, tl, u, cr, cg, cb, A * 0.55)
                else
                    quad(px + n * u, py - u, tl, u, cr, cg, cb, A * 0.55)
                end
            end
        elseif kind == "leaf" then
            -- folha GIRANDO: alterna deitada / de pé / de quina
            local spin = sin(time * 4.2 + p.ph * 3)
            if spin > 0.45 then
                quad(px, py - u, (n + 1) * u, u, cr, cg, cb, A)
                quad(px + u, py - 2 * u, u, u, cr * 0.72, cg * 0.72, cb * 0.72, A)
            elseif spin < -0.45 then
                quad(px, py - (n + 1) * u, u, (n + 1) * u, cr, cg, cb, A)
            else
                quad(px, py - u, u, u, cr, cg, cb, A)
                quad(px + u, py - 2 * u, u, u, cr, cg, cb, A)
            end
        elseif kind == "seed" then
            -- semente: miolo escuro + penacho em cruz
            if n >= 2 then
                quad(px - u, py - 2 * u, 3 * u, u, cr, cg, cb, A * 0.9)
                quad(px, py - 3 * u, u, 2 * u, cr, cg, cb, A * 0.9)
            end
            quad(px, py - u, u, u, cr * 0.72, cg * 0.68, cb * 0.55, A)
        elseif kind == "ember" then
            local fl = 0.65 + 0.35 * sin(time * 9 + p.ph * 5)
            quad(px, py - n * u, n * u, n * u, min(1, cr * fl + 0.1), cg * fl, cb * fl, 1)
            -- brasa é emissiva: micro-luz (não clareia arte — de-escurece)
            if LightEngine and microN < 12 then
                microN = microN + 1
                local sx, sy = love.graphics.transformPoint(px, py)
                LightEngine.submitMicro(sx, sy, 5 * max(0.5, ps) * hk + 2,
                    col, 0.45 * fl, -1)
            end
        end
        nS = nS + 1
        relS[nS] = p.sortRel
        qEnd[nS] = qm.n
        if p.fg and fgStart == 0 then fgStart = nS end
    end
    qm:upload(0, qm.n)
    WeatherEngine.stats.msBuild = (love.timer.getTime() - _t1) * 1000
    WeatherEngine.stats.quads = qm.n
    WeatherEngine.stats.flushes = 0
end

-- desenha tudo que está MAIS LONGE que relLow e ainda não foi desenhado
function WeatherEngine.flushTo(relLow)
    if nS == 0 or cursorK >= nS then return end
    local k2 = cursorK
    while k2 < nS and relS[k2 + 1] >= relLow do k2 = k2 + 1 end
    if k2 == cursorK then return end
    local from = cursorK > 0 and qEnd[cursorK] or 0
    local to = qEnd[k2]
    cursorK = k2
    if to > from then
        love.graphics.setColor(1, 1, 1, 1)
        qm:draw(from, to - from)
        WeatherEngine.stats.flushes = WeatherEngine.stats.flushes + 1
    end
end

function WeatherEngine.flushAll()
    WeatherEngine.flushTo(-math.huge)
end

-- ----------------------------------------------------------------------------
-- RAIO no céu — chamado ENTRE as nuvens e a silhueta frontal das montanhas
-- (os picos cobrem o pé do raio: profundidade real, sem stencil)
-- ----------------------------------------------------------------------------
local function boltLine(pts, x, w, yTop, yBot, thick, r, g, b, a)
    local lastX, lastY
    for k = 1, #pts do
        local bx = floor(x + pts[k][1] * w)
        local by = floor(yTop + pts[k][2] * (yBot - yTop))
        if lastX then
            -- degrau de pixels entre os pontos (Bresenham grosso, sem AA)
            local steps = max(abs(bx - lastX), abs(by - lastY))
            for s = 0, steps, max(1, floor(thick / 2)) do
                local u = steps > 0 and s / steps or 0
                love.graphics.setColor(r, g, b, a)
                love.graphics.rectangle("fill",
                    floor(lastX + (bx - lastX) * u), floor(lastY + (by - lastY) * u),
                    thick, thick)
            end
        end
        lastX, lastY = bx, by
    end
end

function WeatherEngine.drawSky(g, x, w)
    if not strike or reduced() or WeatherEngine.disabled then return end
    local e = time - strike.t0
    if e > 0.30 then return end
    local on = flashAt(e) > 0.5
    if not on then return end
    local yTop = g.y
    local yBot = g.crestApexY - g.h * 0.02
    local th = max(2, floor(g.h / 360))
    -- halo de 1 passo em volta (cor da paleta fria, opaco) + núcleo branco
    boltLine(strike.pts, x, w, yTop, yBot, th + 2, 0.62, 0.66, 0.98, 1)
    for _, br in ipairs(strike.branches) do
        boltLine(br, x, w, yTop, yBot, max(1, th - 1) + 1, 0.62, 0.66, 0.98, 1)
    end
    boltLine(strike.pts, x, w, yTop, yBot, th, 1, 1, 1, 1)
    for _, br in ipairs(strike.branches) do
        boltLine(br, x, w, yTop, yBot, max(1, th - 1), 0.95, 0.96, 1, 1)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ----------------------------------------------------------------------------
-- folha arrancada de uma árvore pela rajada (WorldRoad chama no slot do prop)
-- dxFrac = (x na tela − centro)/w ; hFrac = altura da copa em fração de h a
-- persp 1 ; t = profundidade do prop
-- ----------------------------------------------------------------------------
function WeatherEngine.emitLeaf(dxFrac, z, t, hFrac, color)
    if WeatherEngine.disabled or reduced() or not geo then return end
    local shed = 0
    for i = 1, nP do if P[i].shed then shed = shed + 1 end end
    if shed >= MAX_SHED then return end
    nP = nP + 1
    local p = P[nP] or {}
    P[nP] = p
    p.pr = LEAF_SHED
    p.shed = true
    p.rise = false
    p.st, p.lt = 0, 0
    p.fg = false
    p.ph = rng:random() * 6.2832
    p.ci = 1
    p.z = z
    p.lx = dxFrac / spread(t)
    p.hg = hFrac
    p.vf = LEAF_SHED.fall * (0.7 + rng:random() * 0.6)
    p.tint = p.tint or {}
    p.tint[1], p.tint[2], p.tint[3] = color[1], color[2], color[3]
end

function WeatherEngine.reset()
    for i = 1, nP do P[i].tint = nil end
    nP = 0
    prefill = true
    strike, thunderAt = nil, nil
    curId, cur = nil, nil
    geo = nil
end

-- tools/teste: intensidade fixa (nil = ciclo natural)
function WeatherEngine.setIntensityOverride(v) overrideI = v end

function WeatherEngine.count() return nP end
-- teste/ferramenta: partículas vivas (leitura apenas)
function WeatherEngine._particles() return P, nP end
-- quantas partículas montadas neste frame ainda NÃO foram desenhadas (o
-- WorldRoad tem que chegar a 0 — senão algum floco ficou fora do painter)
function WeatherEngine.undrawn() return nS - cursorK end
function WeatherEngine.built() return nS end
function WeatherEngine.isStriking() return strike ~= nil end

return WeatherEngine
