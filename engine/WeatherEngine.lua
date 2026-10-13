-- engine/WeatherEngine.lua
-- ============================================================================
-- WEATHERENGINE — clima com PROFUNDIDADE de verdade no domo (v2, Out/2026)
-- ============================================================================
-- A grama mostrou o vento no CHÃO; aqui o mesmo vento aparece no AR. Neve,
-- chuva, cinza, folhas, sementes e VAGALUMES vivem em COORDENADAS DE MUNDO
-- (lateral normalizada, z absoluto, altura acima do chão) e são projetados
-- pela mesma geometria do domo que os props:
--   - tamanho e velocidade de queda na tela ∝ persp(t) (paralaxe real);
--   - cada partícula CAI até a latitude dela (g.latY) e POUSA ali;
--   - o desenho entra no PAINTER por profundidade (REGRA DE PROFUNDIDADE do
--     WorldRoad): flushTo(rel) junto com as fatias de grama; além da crista
--     desenha ANTES do domo e some atrás da curva do mundo;
--   - o VENTO é o GrassField.windAt — a MESMA rajada que deita o capim
--     empurra a neve e inclina a chuva.
--
-- v2 (feedback do dono: "pixels grandes demais, chuva grossa, POLUINDO"):
--   - tudo FINO: medida em pixel de TELA (1 px até 1440p), chuva = risco de
--     1 px com alpha baixo, neve quase toda 1 px. Clima é TEXTURA, não ruído
--     (Hollow Knight/Ori: partícula ambiente é sutil e some no contraste;
--     o que se nota é a VIDA, não o pontilhado);
--   - densidade pela CHEGADA AO CASTELO: calma no começo do ato, pico perto
--     do chefe (uma curva só: intensityFor(progress)); tempestade e raio só
--     na parte final;
--   - VAGALUMES: 1 px com micro-luz do LightEngine acendendo o capim
--     embaixo, piscando em ciclo próprio, densidade pela NOITE (luma do
--     ambiente); variante por bioma (amarelo quente, fogo-fátuo verde,
--     cisco claro, cristal de gelo, faísca azul);
--   - estado pro SOM (audioState): intensidade, tempestade, rajada, noite,
--     trovão pendente pela distância do raio, vagalume perto acendendo.
--
-- TEMPESTADE: o relâmpago é polilinha de PIXELS desenhada ATRÁS da silhueta
-- frontal das montanhas; o clarão é o AMBIENTE do lightmap subindo até
-- ~branco — multiply-only, o clarão só DEVOLVE a arte (doutrina de luz).
-- Raio longe = fino, curto, clarão fraco, trovão tardio e baixo.
--
-- ACESSIBILIDADE: reducedMotion corta a densidade e DESLIGA clarão/raio
-- (risco fotossensível). ≤2 pulsos por raio, ≥5 s entre raios.
--
-- PERF: 1 QuadMesh (FFI) por frame, ~1 draw por fatia de profundidade;
-- sem closures nem love.graphics.* nos laços. Não toca no cache da grama.
-- ============================================================================

local WeatherEngine = {}
local QuadMesh = require("engine.QuadMesh")
local GrassField = require("engine.GrassField")

local floor, min, max, sin, abs = math.floor, math.min, math.max, math.sin, math.abs
local c8 = QuadMesh.c8

-- ----------------------------------------------------------------------------
-- PRESETS por bioma. Unidades:
--   count  = partículas vivas na intensidade 1 (perto do castelo)
--   fall   = queda em fração da ALTURA da área por segundo, a persp 1
--   size   = px de TELA a persp 1 numa área de 1000 px (chuva: comprimento)
--   windK  = quanto a rajada do capim empurra (lateral normalizada/s)
--   land   = segundos pousado antes de sumir
--   fg     = fração no PRIMEIRO PLANO (na frente de tudo, um pouco maior)
--   ff     = vagalumes { count (noite cheia), style, color, radius, light }
-- ----------------------------------------------------------------------------
WeatherEngine.PRESETS = {
    -- campos: sementes soltas nas rajadas + vagalumes AMARELOS ao anoitecer
    fields = { kind = "seed", count = 34, fall = 0.035, fallVar = 0.5,
               size = 2.2, windK = 0.20, land = 1.6, fg = 0.06, lift = 0.05,
               colors = { { 0.98, 0.96, 0.88 }, { 0.93, 0.90, 0.76 } },
               ff = { count = 30, style = "wander", color = { 1.00, 0.86, 0.36 },
                      radius = 8, light = 0.55 } },
    -- colinas: chuva fina que engrossa perto do castelo, raio no fim do ato
    highlands = { kind = "rain", count = 420, fall = 1.75, fallVar = 0.25,
               size = 34, windK = 0.10, land = 0.16, fg = 0.03,
               colors = { { 0.82, 0.86, 1.00 }, { 0.92, 0.94, 1.00 } },
               alpha = 0.60,
               storm = { period = 70, phase = 0.42, lightning = true, dark = 0.24 },
               ff = { count = 8, style = "wander", color = { 0.70, 0.84, 1.00 },
                      radius = 6, light = 0.40 } },
    -- abismo: cinza fina caindo + brasas SUBINDO do chão rachado
    abyss = { kind = "ash", count = 130, fall = 0.075, fallVar = 0.5,
               size = 1.8, windK = 0.10, land = 1.2, fg = 0.04,
               colors = { { 0.72, 0.66, 0.62 }, { 0.55, 0.50, 0.50 },
                          { 0.86, 0.80, 0.74 } },
               rise = { count = 22, fall = -0.11, size = 1.2,
                        colors = { { 1.00, 0.55, 0.18 }, { 1.00, 0.78, 0.30 } } } },
    -- geleira: neve fina em três profundidades; nevasca perto do castelo
    frost = { kind = "snow", count = 640, fall = 0.10, fallVar = 0.45,
               size = 3.4, windK = 0.17, land = 1.4, fg = 0.04,
               colors = { { 0.95, 0.97, 1.00 }, { 0.84, 0.89, 0.98 } },
               storm = { period = 55, phase = 0.10, dark = 0.06 },
               -- bruma de tela da névoa de intenção (fogHook): branco-gelo
               hazeColor = { 0.88, 0.93, 1.00 },
               ff = { count = 14, style = "sparkle", color = { 0.84, 0.94, 1.00 },
                      radius = 5, light = 0.35 } },
    -- pântano: garoa, fogos-fátuos VERDES, relâmpago raro no fim
    marsh = { kind = "rain", count = 190, fall = 1.35, fallVar = 0.25,
               size = 26, windK = 0.07, land = 0.16, fg = 0.02,
               colors = { { 0.88, 0.94, 0.82 }, { 0.96, 0.98, 0.92 } },
               alpha = 0.50,
               storm = { period = 90, phase = 0.70, lightning = true, dark = 0.12 },
               ff = { count = 20, style = "wisp", color = { 0.62, 1.00, 0.46 },
                      radius = 9, light = 0.50 } },
    -- crepúsculo: folhas girando nas rajadas + ciscos claros flutuando
    dusk = { kind = "leaf", count = 46, fall = 0.06, fallVar = 0.4,
               size = 2.4, windK = 0.22, land = 2.2, fg = 0.06,
               colors = { { 0.88, 0.48, 0.20 }, { 0.78, 0.30, 0.22 },
                          { 0.92, 0.70, 0.30 } },
               -- bruma de tela da névoa de intenção (fogHook): violeta
               hazeColor = { 0.62, 0.50, 0.70 },
               ff = { count = 18, style = "mote", color = { 1.00, 0.86, 0.66 },
                      radius = 6, light = 0.40 } },
}

-- folha solta de árvore numa rajada (emitLeaf) — preset auxiliar
local LEAF_SHED = { kind = "leaf", fall = 0.07, fallVar = 0.4, size = 2,
                    windK = 0.24, land = 1.8, fg = 0, colors = { { 1, 1, 1 } } }
local MAX_SHED = 20
local RETIRE_FADE = 6       -- s pra um clima aposentado sumir (troca de bioma)
local MAX_AGE = 75          -- s de vida máxima de qualquer partícula
local MAX_MICRO = 24        -- micro-luzes do clima por frame (o LightEngine tem 64)
local MAX_FF_POOLS = 6      -- poças de vagalume por frame (o LightEngine tem 28 —
                            -- as das luminárias ganham na política "mais fraca sai")

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
local overrideP = nil      -- tools/teste: progresso até o castelo fixo
local progress = 0         -- 0 = começo do ato, 1 = porta do castelo
local night = 0            -- 0 = dia, 1 = noite (pela luma do ambiente)
local time = 0
local strike = nil         -- raio em curso
local nextStrike = 6
local thunderAt, thunderDist = nil, 0
local pendingThunder = nil -- distância do trovão pronto pra tocar (audioState)
local pendingBlink = nil   -- vagalume perto acendeu (audioState)
local qm = nil
local relS, qEnd = {}, {}
local nS, cursorK = 0, 0
local microN = 0
local poolN = 0
local lastCtx = nil
local windP = GrassField.PRESETS.fields
local camZ0 = 0

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
-- A CURVA ÚNICA: intensidade pela chegada ao castelo (0..1)
-- ----------------------------------------------------------------------------
-- começo do ato = 12% (céu quase limpo), porta do castelo = 100%
function WeatherEngine.intensityFor(prog)
    return 0.12 + 0.88 * (smooth(0, 1, prog) ^ 1.3)
end
-- tempestade só no trecho final (e respirando num ciclo longo)
local function stormFor(pr, prog, t)
    local st = pr and pr.storm
    if not st then return 0 end
    local ph = ((t / st.period) + (st.phase or 0)) % 1
    local breath = 0.75 + 0.25 * sin(ph * 6.2832)
    return smooth(0.60, 0.92, prog) * breath
end

local function curProgress() return overrideP or progress end

-- NÉVOA DE INTENÇÃO (Out/2026): quando o intent do inimigo está encoberto,
-- o clima da tela ENGROSSA pra que a leitura venha do mundo, não de um
-- interruptor de UI. O estado decide e o clima acompanha (o relógio do clima
-- é visual e não pode ser a regra — src/systems/IntentVisibility.lua).
-- `fogHook` é instalado por quem sabe o estado e devolve 0..1 de intensidade
-- extra; `veilCur` persegue esse alvo a 4/s (~0,5 s pra 85%: quando a vez
-- volta ao jogador, depois dos beats de upkeep/compra, a bruma já fechou).
-- O mesmo valor é a opacidade da BRUMA DE TELA (drawHaze, no flushAll): "?"
-- no HUD nunca aparece sobre céu limpo — renderedFog() é o que a trava mede.
WeatherEngine.fogHook = nil
local veilCur = 0
local VEIL_CHASE = 4.0
local HAZE_ALPHA = 0.72      -- opacidade da bruma a veilCur = 1 (type_only ≈ 0.32, hidden ≈ 0.54)
local function veilBoost() return veilCur end
function WeatherEngine.veilBoost() return veilCur end
function WeatherEngine.renderedFog() return veilCur end

local function intensityOf(pr)
    if overrideI then return overrideI end
    return min(1, WeatherEngine.intensityFor(curProgress()) + veilBoost())
end

function WeatherEngine.intensity()
    return cur and intensityOf(cur) or 0
end

function WeatherEngine.storm()
    if not cur or not cur.storm then return 0 end
    if overrideI then return smooth(0.6, 0.95, overrideI) end
    -- a névoa oculta também fecha a tempestade (nevasca: rastro na rajada,
    -- `dark`) — nunca acima de 1
    return min(1, max(stormFor(cur, curProgress(), time), veilBoost()))
end

function WeatherEngine.night() return night end

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
-- kindTag: nil = clima, "rise" = brasa subindo, "ff" = vagalume
local function spawn(p, pr, camZ, fresh, kindTag)
    local g = geo
    local isRise, isFF = kindTag == "rise", kindTag == "ff"
    p.pr = pr
    p.tint = nil
    p.rise = isRise
    p.ff = isFF
    p.st = 0
    p.lt = 0
    p.ph = rng:random() * 6.2832
    p.lit = false
    p.age = 0
    p.retire = 0
    local colors = isRise and pr.rise.colors or pr.colors
    p.ci = rng:random(1, #colors)
    p.fg = (kindTag == nil) and rng:random() < (pr.fg or 0)
    local relCrest, tPow = g.relCrest, g.tPow
    local t, rel
    if p.fg then
        t = 1; rel = 0.4 + rng:random() * 0.6
    elseif isFF then
        -- vagalume mora no campo do meio pra frente
        t = 0.25 + rng:random() * 0.75
        rel = relCrest * (1 - t ^ (1 / tPow))
    elseif (not isRise) and rng:random() < 0.16 then
        rel = relCrest + rng:random() * 7; t = 0   -- além da crista
    else
        t = rng:random()
        rel = relCrest * (1 - t ^ (1 / tPow))
    end
    p.z = camZ + rel
    local half = 0.53 / spread(t)
    p.lx = (rng:random() * 2 - 1) * half
    if isFF and rng:random() < 0.88 then
        -- fora da estrada (vive no mato; 12% cruzam o caminho)
        local side = p.lx < 0 and -1 or 1
        p.lx = side * (0.13 + rng:random() * (half - 0.13)) / 1
    end
    if isFF then
        local ff = pr.ff
        p.hg0 = 0.018 + rng:random() * 0.07
        p.hg = p.hg0
        p.vf = 0
        p.life = 9 + rng:random() * 10
        p.life0 = p.life
        p.period = (ff.style == "sparkle") and (1.4 + rng:random() * 1.8)
            or (2.6 + rng:random() * 2.6)
        return
    end
    local fv = pr.fallVar or 0
    local fall = isRise and pr.rise.fall or pr.fall
    p.vf = fall * (1 + (rng:random() * 2 - 1) * fv)
    if isRise then
        p.hg = 0
    else
        local dx = p.lx * g.w * spread(t)
        local gy = g.latY(dx, t)
        local top = (gy - g.y + 12) / (g.persp(t) * g.h)
        if p.fg then top = top * 1.02 end
        p.hg = fresh and rng:random() * top or top * (1 + rng:random() * 0.08)
    end
end

-- brilho do vagalume (0..1) no instante — pura: o draw e o som leem igual
local function ffGlow(p, style)
    local c = ((time / p.period) + p.ph) % 1
    local b
    if style == "sparkle" then
        b = c < 0.14 and sin(3.14159 * c / 0.14) or 0          -- cintilada curta
    elseif style == "wisp" then
        b = 0.45 + 0.55 * (0.5 + 0.5 * sin(c * 6.2832))          -- respira, quase nunca apaga
    elseif style == "mote" then
        b = 0.55 + 0.25 * sin(c * 6.2832)                        -- cisco: brilho mansinho
    else
        b = c < 0.6 and sin(3.14159 * c / 0.6) or 0              -- pisca e apaga
    end
    local life = p.life / max(0.01, p.life0)
    local fade = min(1, (1 - life) * 4) * min(1, life * 4)       -- nasce/morre em fade
    return b * fade
end

local function addParticle(tag, camZ)
    nP = nP + 1
    local p = P[nP] or {}
    P[nP] = p
    p.shed = false
    spawn(p, cur, camZ, prefill, tag)
    return p
end

-- ----------------------------------------------------------------------------
-- UPDATE: simulação em coordenadas de mundo
-- ctx = { biomeId, camZ, time, windP, progress (0..1), luma (ambiente) }
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
    if ctx.progress then progress = min(1, max(0, ctx.progress)) end
    if ctx.luma then
        -- noite pela LUMINÂNCIA do ambiente (o mesmo gate dos vagalumes do
        -- LightEngine): 0.82 = dia claro, 0.55 = noite fechada
        night = smooth(0.82, 0.55, ctx.luma)
    end
    local camZ = ctx.camZ or 0
    camZ0 = camZ
    windP = ctx.windP or GrassField.PRESETS[id] or GrassField.PRESETS.fields
    local rm = reduced()
    -- névoa de intenção: persegue o alvo do hook (ver veilBoost)
    do
        local target = 0
        if WeatherEngine.fogHook then
            local ok, v = pcall(WeatherEngine.fogHook)
            if ok and type(v) == "number" then target = min(1, max(0, v)) end
        end
        veilCur = veilCur + (target - veilCur) * min(1, (dt or 0) * VEIL_CHASE)
        if abs(target - veilCur) < 0.002 then veilCur = target end
    end

    local I = cur and intensityOf(cur) or 0
    local want = cur and floor(cur.count * I * (rm and 0.35 or 1) + 0.5) or 0
    local wantRise = (cur and cur.rise) and floor(cur.rise.count * (0.4 + 0.6 * I)
        * (rm and 0.35 or 1)) or 0
    local wantFF = (cur and cur.ff) and floor(cur.ff.count * night
        * (rm and 0.5 or 1) + 0.5) or 0

    if geo then
        local relCrest = geo.relCrest
        local nMain, nRise, nFF = 0, 0, 0
        for i = 1, nP do
            local p = P[i]
            if p.pr == cur then
                if p.rise then nRise = nRise + 1
                elseif p.ff then nFF = nFF + 1
                else nMain = nMain + 1 end
            end
        end
        local i = 1
        while i <= nP do
            local p = P[i]
            local pr = p.pr
            local dead = false
            local rel = p.z - camZ
            -- APOSENTADORIA determinística: partícula de um preset que saiu de
            -- cena (troca de bioma) esvai em RETIRE_FADE s, e qualquer uma tem
            -- vida máxima — floco atrás da crista caindo devagar podia passar
            -- de 60 s (bug exposto por troca de RNG, Out/2026)
            p.age = (p.age or 0) + dt
            if p.pr ~= cur and not p.shed then p.retire = (p.retire or 0) + dt end
            if (p.retire or 0) >= RETIRE_FADE or p.age >= MAX_AGE then
                dead = true
            elseif rel < -0.6 then
                dead = true
            elseif p.ff then
                -- VAGALUME: vagueia, sobe e desce devagar, a rajada empurra
                p.life = p.life - dt
                if p.life <= 0 then dead = true
                else
                    local t = tOfRel(rel, relCrest, geo.tPow)
                    local nx = 0.5 + p.lx * spread(t)
                    local wind = GrassField.windAt(nx, p.z, time, windP, 0.3)
                    local still = pr.ff.style == "sparkle" and 0.25 or 1
                    p.lx = p.lx + (sin(time * 0.6 + p.ph) * 0.030 + wind * 0.018) * dt * still
                    p.hg = p.hg0 + sin(time * 0.9 + p.ph * 1.7) * 0.012 * still
                    -- som: vagalume PERTO acendendo (borda de subida do brilho)
                    local lit = ffGlow(p, pr.ff.style) > 0.6
                    if lit and not p.lit and t > 0.75 then pendingBlink = t end
                    p.lit = lit
                end
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
                local half = 0.56 / spread(t)
                if p.lx > half then p.lx = p.lx - 2 * half
                elseif p.lx < -half then p.lx = p.lx + 2 * half end
                if p.rise then
                    local dx = p.lx * geo.w * spread(t)
                    local gy = geo.latY(dx, t)
                    if gy - p.hg * geo.persp(t) * geo.h < geo.y - 6 then dead = true end
                elseif p.hg <= 0 then
                    if rel > relCrest or p.fg then
                        dead = true
                    else
                        p.hg = 0; p.st = 1; p.lt = pr.land or 0.5
                    end
                end
            end
            if dead then
                local stillWanted
                if p.shed or p.pr ~= cur then
                    stillWanted = false
                elseif p.rise then
                    stillWanted = nRise <= wantRise
                elseif p.ff then
                    stillWanted = nFF <= wantFF
                else
                    stillWanted = nMain <= want
                end
                if stillWanted and not prefill then
                    spawn(p, cur, camZ, false, p.rise and "rise" or (p.ff and "ff" or nil))
                    i = i + 1
                else
                    if p.pr == cur then
                        if p.rise then nRise = nRise - 1
                        elseif p.ff then nFF = nFF - 1
                        else nMain = nMain - 1 end
                    end
                    P[i] = P[nP]; P[nP] = p; nP = nP - 1
                end
            else
                i = i + 1
            end
        end
        if cur then
            local budget = prefill and 100000 or max(4, floor(want * dt * 0.8))
            while nMain < want and budget > 0 do
                addParticle(nil, camZ); nMain = nMain + 1; budget = budget - 1
            end
            while nRise < wantRise do
                local p = addParticle("rise", camZ)
                if prefill then p.hg = rng:random() * 0.6 end
                nRise = nRise + 1
            end
            -- vagalumes chegam aos poucos (acendem com o anoitecer)
            local ffBudget = prefill and 1000 or 1
            while nFF < wantFF and ffBudget > 0 do
                local p = addParticle("ff", camZ)
                if prefill then p.life = p.life0 * (0.2 + rng:random() * 0.6) end
                nFF = nFF + 1; ffBudget = ffBudget - 1
            end
            prefill = false
        end
    end

    -- RAIO: só com tempestade forte (fim do ato), nunca com reducedMotion
    local st = cur and cur.storm
    if st and st.lightning and not rm then
        if not strike and time >= nextStrike then
            if WeatherEngine.storm() > 0.5 then
                WeatherEngine.strike()
            else
                nextStrike = time + 1.5
            end
        end
    end
    if strike and time - strike.t0 > 0.9 then strike = nil end
    if thunderAt and time >= thunderAt then
        -- trovão atrasado demais (cena parada no meio) não toca solto
        if time - thunderAt <= 1.0 then pendingThunder = thunderDist end
        thunderAt = nil
    end
    WeatherEngine.stats.particles = nP
    WeatherEngine.stats.msUpdate = (love.timer.getTime() - _t0) * 1000
end

-- estado pro WeatherAudio (consome os eventos pendentes)
local _aud = {}
function WeatherEngine.audioState()
    _aud.biomeId = curId
    _aud.intensity = cur and intensityOf(cur) or 0
    _aud.storm = WeatherEngine.storm()
    _aud.night = night
    _aud.rain = (cur and cur.kind == "rain") and _aud.intensity or 0
    _aud.gust = abs(GrassField.windAt(0.5, camZ0 + 8, time, windP, 0))
    _aud.thunder = pendingThunder
    _aud.blink = pendingBlink
    pendingThunder, pendingBlink = nil, nil
    return _aud
end

-- dispara um raio agora (tools/teste chamam direto). dist 0 = em cima,
-- 1 = horizonte. Polilinha de pixels em coordenadas NORMALIZADAS.
function WeatherEngine.strike(xr, dist)
    -- perto é raro (o céu de tempestade é feito de raios distantes)
    dist = dist or (rng:random() ^ 0.6)
    local pts = { { xr or (0.12 + rng:random() * 0.76), 0 } }
    local n = 14
    local x = pts[1][1]
    local jag = 0.022 * (1 - 0.4 * dist)
    for k = 1, n do
        x = x + (rng:random() * 2 - 1) * jag
        pts[#pts + 1] = { x, k / n }
    end
    local branches = {}
    for b = 1, (dist < 0.5) and rng:random(1, 2) or 1 do
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
    strike = { t0 = time, pts = pts, branches = branches, dist = dist }
    nextStrike = time + 5 + rng:random() * 7
    -- som viaja: trovão perto chega quase junto, longe demora e vem baixo
    thunderAt = time + 0.15 + dist * 2.2 + rng:random() * 0.3
    thunderDist = dist
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
    return flashAt(time - strike.t0) * (1 - 0.5 * (strike.dist or 0))
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
-- magenta e engorda 4px (partícula fina some na captura — use pra provar
-- que está desenhando antes de mexer em tamanho)
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
    if prefill and cur and lastCtx then WeatherEngine.update(0, lastCtx) end
    nS, cursorK, microN, poolN = 0, 0, 0, 0
    if WeatherEngine.disabled or nP == 0 then return end
    qm = qm or QuadMesh.new(1024)
    qm:reset()
    local camZ, relCrest, tPow = f.camZ, f.relCrest, f.tPow
    WeatherEngine._sortCamZ = camZ   -- emitLeaf insere na ordem com o mesmo eixo
    local w, h = f.w, g.h
    -- v2: pixel de TELA. 1 px até ~1440p; 2 px só em 4K (fino é a regra)
    local hk = h / 1000
    local u = max(1, floor(h / 900))

    for i = 1, nP do
        local p = P[i]
        p.sortRel = p.fg and -100 or (p.z - camZ)
    end
    -- INSERÇÃO sobre a própria lista viva (quase ordenada frame a frame)
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
    WeatherEngine.stats.msSort = (love.timer.getTime() - _t1) * 1000

    local LightEngine = package.loaded["engine.LightEngine"]
    for k = 1, nP do
        local p = P[k]
        local pr = p.pr
        local rel = p.z - camZ
        local t, behind = tOfRel(rel, relCrest, tPow)
        local ps = g.persp(t)
        local dx = p.lx * w * spread(t)
        local gx = g.cx + dx
        local gy = behind and g.crestYAt(gx) or g.latY(dx, t)
        local px = floor(gx)
        local py = floor(gy - p.hg * ps * h)
        local colors = p.rise and pr.rise.colors or pr.colors
        local col = p.ff and pr.ff.color or colors[p.ci] or colors[1]
        local cr, cg, cb = col[1], col[2], col[3]
        if p.tint then cr, cg, cb = p.tint[1], p.tint[2], p.tint[3] end
        local fgk = p.fg and 1.5 or 1
        local size = p.rise and pr.rise.size or pr.size
        local n = max(1, floor(size * ps * hk * fgk + 0.5))
        -- longe perde contraste (perspectiva atmosférica, como os props)
        local A = 1
        if behind then A = 0.5 elseif t < 0.25 then A = 0.62 + t * 1.5 end
        if (p.retire or 0) > 0 then A = A * max(0, 1 - p.retire / RETIRE_FADE) end
        local kind = p.ff and "ff" or (p.rise and "ember" or pr.kind)
        local wind = p.wind or 0

        if kind == "ff" then
            local b = ffGlow(p, pr.ff.style)
            if b > 0.03 then
                -- núcleo de 1 px + cruz de halo só quando aceso e perto
                quad(px, py - u, u, u, min(1, cr * (0.6 + 0.4 * b) + 0.15 * b),
                    min(1, cg * (0.6 + 0.4 * b) + 0.1 * b), cb * (0.6 + 0.4 * b), min(1, 0.35 + b))
                if b > 0.3 and ps > 0.3 then
                    local ha = min(0.75, (b - 0.3) * 1.1)
                    quad(px - u, py - u, u, u, cr, cg, cb, ha)
                    quad(px + u, py - u, u, u, cr, cg, cb, ha)
                    quad(px, py - 2 * u, u, u, cr, cg, cb, ha)
                    quad(px, py, u, u, cr, cg, cb, ha)
                end
                -- a LUZ é o efeito: micro-luz devolve a cor cheia do núcleo e
                -- os vagalumes de PERTO pousam uma poça no capim embaixo
                -- (mesma linguagem das luminárias: degraus finos + dither leve)
                if LightEngine and b > 0.15 then
                    local sx, sy = love.graphics.transformPoint(px, py)
                    if microN < MAX_MICRO then
                        microN = microN + 1
                        LightEngine.submitMicro(sx, sy, (3 + 4 * ps) * hk + 2,
                            col, min(1, 0.55 + 0.45 * b), -1)
                    end
                    if ps > 0.45 and b > 0.35 and poolN < MAX_FF_POOLS then
                        poolN = poolN + 1
                        local gsx, gsy = love.graphics.transformPoint(px, gy)
                        LightEngine.submit({
                            x = (sx + gsx) * 0.5, y = (sy + gsy) * 0.5 + 2,
                            radius = pr.ff.radius * 8 * ps * hk + 10,
                            color = col, intensity = min(1, pr.ff.light * 2.2 * b),
                            dither = true, ditherAmt = 0.28, levels = 6,
                            z = rel,
                        })
                    end
                end
            end
        elseif p.st == 1 then
            local life = p.lt / max(0.01, pr.land or 0.5)
            if kind == "rain" then
                -- coroa: 2 quadros (abre e espalha), só no campo de perto
                if t > 0.45 then
                    local e = 1 - life
                    local A2 = (pr.alpha or 0.4) * (e < 0.5 and 1.2 or 0.7) * A
                    local off = (e < 0.5) and u or 2 * u
                    quad(px - off - u, py - off, u, u, cr, cg, cb, A2)
                    quad(px + off, py - off, u, u, cr, cg, cb, A2)
                end
            else
                local fade = min(1, life * 3)
                local lw = (kind == "leaf" and n > 1) and n + 1 or n
                quad(px, py - u, lw, u, cr * 0.92, cg * 0.92, cb * 0.92, A * fade)
            end
        elseif kind == "rain" then
            -- risco FINO inclinado pelo vento (quad cisalhado: degrau de pixel)
            local len = max(2, floor(pr.size * ps * hk * fgk + 0.5))
            local kx = -wind * 0.30
            local R, G, B, AA = c8(cr), c8(cg), c8(cb),
                c8((pr.alpha or 0.4) * A * (p.fg and 1.3 or 1))
            qm:sprite(px, py, 1, 1, 0, len, kx, u, len, 0, 0, 1, 1, R, G, B, AA)
        elseif kind == "snow" or kind == "ash" then
            if n >= 3 then
                -- floco em "+" (só o primeiro plano chega aqui)
                quad(px - u, py - 2 * u, 3 * u, u, cr, cg, cb, A)
                quad(px, py - 3 * u, u, 3 * u, cr, cg, cb, A)
            else
                quad(px, py - n, n, n, cr, cg, cb, A)
            end
            -- rajada forte: rastro de 1 px (o vento VISÍVEL no ar)
            local aw = abs(wind)
            if aw > 1.0 and t > 0.4 then
                local tl = max(1, floor((aw - 0.7) * 4 * ps * hk))
                if wind > 0 then
                    quad(px - tl, py - 1, tl, u, cr, cg, cb, A * 0.45)
                else
                    quad(px + n, py - 1, tl, u, cr, cg, cb, A * 0.45)
                end
            end
        elseif kind == "leaf" then
            -- folha GIRANDO: deitada / de pé / ponto
            local spin = sin(time * 4.2 + p.ph * 3)
            if n <= 1 then
                quad(px, py - u, u, u, cr, cg, cb, A)
            elseif spin > 0.45 then
                quad(px, py - u, n + u, u, cr, cg, cb, A)
            elseif spin < -0.45 then
                quad(px, py - n - u, u, n + u, cr, cg, cb, A)
            else
                quad(px, py - n, n, n, cr, cg, cb, A)
            end
        elseif kind == "seed" then
            -- semente: ponto; penacho em cruz só perto
            if n >= 2 then
                quad(px - u, py - 2 * u, 3 * u, u, cr, cg, cb, A * 0.8)
                quad(px, py - 3 * u, u, u, cr, cg, cb, A * 0.8)
            end
            quad(px, py - u, u, u, cr * 0.85, cg * 0.82, cb * 0.7, A)
        elseif kind == "ember" then
            local fl = 0.65 + 0.35 * sin(time * 9 + p.ph * 5)
            quad(px, py - n, n, n, min(1, cr * fl + 0.1), cg * fl, cb * fl, 1)
            if LightEngine and microN < MAX_MICRO then
                microN = microN + 1
                local sx, sy = love.graphics.transformPoint(px, py)
                LightEngine.submitMicro(sx, sy, 4 * max(0.5, ps) * hk + 2,
                    col, 0.40 * fl, -1)
            end
        end
        nS = nS + 1
        relS[nS] = p.sortRel
        qEnd[nS] = qm.n
    end
    qm:upload(0, qm.n)
    WeatherEngine.stats.quads = qm.n
    WeatherEngine.stats.flushes = 0
    WeatherEngine.stats.msBuild = (love.timer.getTime() - _t1) * 1000
    WeatherEngine.stats.unit = u
    WeatherEngine.stats.pools, WeatherEngine.stats.micro = poolN, microN
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

-- ----------------------------------------------------------------------------
-- BRUMA DE TELA da névoa de intenção: bandas de ruído em pixel correndo com o
-- vento por cima do mundo inteiro (na frente do inimigo da estrada, atrás do
-- HUD — o flushAll é o último passe do painter). Tingida pelo `hazeColor` do
-- preset. reducedMotion: parada, nunca ausente (informação, não movimento).
-- ----------------------------------------------------------------------------
local hazeImg, hazeQuad = nil, nil
local HAZE_W, HAZE_H = 128, 48
local function hazeHash(x, y)
    local n = (x * 374761393 + y * 668265263) % 4294967296
    n = (n * 1274126177) % 4294967296
    return (n % 1000) / 1000
end
local function hazeNoise(x, y)
    local xi, yi = floor(x), floor(y)
    local fx, fy = x - xi, y - yi
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    local a, b = hazeHash(xi, yi), hazeHash(xi + 1, yi)
    local c, d = hazeHash(xi, yi + 1), hazeHash(xi + 1, yi + 1)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy
end
local function buildHaze()
    local data = love.image.newImageData(HAZE_W, HAZE_H)
    for y = 0, HAZE_H - 1 do
        for x = 0, HAZE_W - 1 do
            local u = x / HAZE_W
            local function nz(off)
                return 0.55 * hazeNoise((u + off) * 5, y / 11) + 0.30 * hazeNoise((u + off) * 11 + 7, y / 6 + 3)
                    + 0.15 * hazeNoise((u + off) * 23 + 2, y / 3 + 9)
            end
            local n = nz(0) * (1 - u) + nz(1) * u          -- costura X
            -- janela vertical: cada banda some nas bordas (as bandas se
            -- sobrepõem pela metade — sem isso o corte reto entre bandas
            -- lia como retângulos, não como bruma)
            local vwin = sin(3.14159 * (y + 0.5) / HAZE_H)
            -- posterizado em 4 degraus: bruma de pixel art
            local a = floor(max(0, (n * vwin - 0.22) / 0.55) * 4 + 0.5) / 4
            data:setPixel(x, y, 1, 1, 1, min(1, a))
        end
    end
    hazeImg = love.graphics.newImage(data)
    hazeImg:setFilter("nearest", "nearest")
    hazeImg:setWrap("repeat", "clamp")
    hazeQuad = love.graphics.newQuad(0, 0, HAZE_W * 64, HAZE_H, HAZE_W, HAZE_H)
end

local function drawHaze()
    if veilCur <= 0.01 or not geo or not cur then return end
    if not hazeImg then buildHaze() end
    local col = cur.hazeColor or { 0.9, 0.9, 0.95 }
    local x, y, w, h = geo.x, geo.y, geo.w, geo.h
    local a = veilCur * HAZE_ALPHA
    -- pixel de ARTE: a bruma é chunky como a grama, não fina como a neve
    local s = max(2, floor(h / 260))
    local t = reduced() and 0 or time
    local gust = windP and abs(GrassField.windAt(0.5, camZ0 + 6, time, windP, 0)) or 0
    local speed = 14 + 30 * gust
    local bandH = HAZE_H * s
    local step = floor(bandH / 2)              -- bandas sobrepostas pela metade
    local nBands = floor(h / step) + 2
    love.graphics.push("all")
    love.graphics.setScissor(floor(x), floor(y), floor(w), floor(h))
    local drawn = 0
    for i = 0, nBands - 1 do
        local dir = (i % 2 == 0) and 1 or -1
        local off = floor((t * speed * (0.6 + 0.25 * (i % 3)) * dir) % (HAZE_W * s) / s) * s
        local yy = y + i * step - floor(bandH * 0.5)
        -- mais densa embaixo (o chão some primeiro) e nunca cobre o céu alto
        local depthK = 0.45 + 0.55 * min(1, (i + 1) / nBands)
        love.graphics.setColor(col[1], col[2], col[3], a * depthK * (0.75 + 0.25 * ((i * 7) % 3) / 2))
        love.graphics.draw(hazeImg, hazeQuad, x - HAZE_W * s * 2 + off, yy, 0, s, s)
        drawn = drawn + 1
    end
    -- lavagem uniforme: baixa o contraste do que está atrás
    love.graphics.setColor(col[1], col[2], col[3], a * 0.35)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.pop()
    WeatherEngine.stats.hazeBands = drawn
end

function WeatherEngine.flushAll()
    WeatherEngine.flushTo(-math.huge)
    WeatherEngine.stats.hazeBands = 0
    drawHaze()
end

-- ----------------------------------------------------------------------------
-- RAIO no céu — entre as nuvens e a silhueta frontal das montanhas
-- ----------------------------------------------------------------------------
local function boltLine(pts, x, w, yTop, yBot, thick, r, g, b, a)
    local lastX, lastY
    for k = 1, #pts do
        local bx = floor(x + pts[k][1] * w)
        local by = floor(yTop + pts[k][2] * (yBot - yTop))
        if lastX then
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
    if e > 0.30 or flashAt(e) <= 0.5 then return end
    local d = strike.dist or 0
    local yTop = g.y + g.h * 0.03 * d
    -- longe: raio curto, termina alto (cai atrás das montanhas distantes)
    local yBot = g.crestApexY - g.h * (0.02 + 0.10 * d)
    local th = max(1, floor((2 - 1.2 * d) * g.h / 1000 + 0.5))
    if d < 0.5 then
        boltLine(strike.pts, x, w, yTop, yBot, th + 2, 0.62, 0.66, 0.98, 0.9)
    end
    boltLine(strike.pts, x, w, yTop, yBot, th, 1, 1, 1, 1 - 0.35 * d)
    for _, br in ipairs(strike.branches) do
        boltLine(br, x, w, yTop, yBot, max(1, th - 1), 0.92, 0.94, 1, 0.9 - 0.35 * d)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ----------------------------------------------------------------------------
-- folha arrancada de uma árvore pela rajada (WorldRoad chama no slot do prop)
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
    p.age, p.retire = 0, 0
    p.rise, p.ff = false, false
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
    -- A folha nasce DURANTE o draw do WorldRoad (slot da árvore), depois da
    -- ordenação do quadro: entra já na posição certa (fundo → frente) em vez
    -- de ficar no fim com o sortRel velho da tabela reaproveitada — o lote
    -- ficava fora de ordem até o quadro seguinte (test_weather, ordem do
    -- test_all).
    p.sortRel = p.z - (WeatherEngine._sortCamZ or 0)
    local j = nP - 1
    while j >= 1 and (P[j].sortRel or 0) < p.sortRel do
        P[j + 1] = P[j]
        j = j - 1
    end
    P[j + 1] = p
end

function WeatherEngine.hasFireflies(bid)
    local pr = WeatherEngine.PRESETS[bid]
    return pr ~= nil and pr.ff ~= nil
end

function WeatherEngine.reset()
    -- gerador próprio reseedado: run nova (e cena de teste) sempre igual,
    -- não dependente de quantas partículas o processo já sorteou
    rng:setSeed(9173)
    for i = 1, nP do P[i].tint = nil end
    nP = 0
    prefill = true
    strike, thunderAt, pendingThunder, pendingBlink = nil, nil, nil, nil
    curId, cur = nil, nil
    geo = nil
    veilCur = 0
end

-- tools/teste
function WeatherEngine.setIntensityOverride(v) overrideI = v end
function WeatherEngine.setProgressOverride(v) overrideP = v end
function WeatherEngine.count() return nP end
function WeatherEngine.isStriking() return strike ~= nil end
function WeatherEngine._particles() return P, nP end
function WeatherEngine.undrawn() return nS - cursorK end
function WeatherEngine.built() return nS end
WeatherEngine._ffGlow = ffGlow

return WeatherEngine
