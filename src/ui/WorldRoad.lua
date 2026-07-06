-- src/ui/WorldRoad.lua
-- V4 "CIRCLE LAND" — o mundo é um DOMO (disco-terra gigante), fiel à mecânica
-- real do Path of Kings (APK: CircleLandController + GameObjects Circle/Sphere).
--
-- GEOMETRIA:
--   O chão é um círculo de raio R (~2.2× a largura) com centro ABAIXO da tela.
--   O topo do círculo é a CRISTA CURVA: crestY(px) = cy - sqrt(R² - (px-cx)²).
--   Avançar = o disco "gira": conteúdo (tijolos da estrada, tufos, props)
--   flui da crista pra base acelerando (t^p), crescendo em escala.
--
-- PAINTER'S ORDER (oclusão de graça, sem stencil):
--   céu → nuvens → montanhas parallax → CASTELO (cresce c/ progresso, base
--   sempre atrás do domo) → INIMIGO emergindo (meio-corpo atrás da curva) →
--   PREENCHIMENTO DO DOMO → estrada de tijolos → props do lado de cá.
--
-- SEM herói (primeira pessoa implícita: vemos só inimigos e cenário).
--
-- ESCALA COERENTE por tipo (KIND_SIZE, unidades de mundo): árvore ~3.4× arbusto.
--
-- Arte: PNG do PixelLab em assets/sprites/world/<nome>.png tem prioridade
-- (clouds/castle/mountains/bricks/tufts + props por bioma); fallback procedural.
--
-- API (inalterada p/ GameplayScene):
--   update(dt) / draw(x,y,w,h,actNumber) / travel{distance,duration,onComplete,
--   encounter} / isTraveling() / setBiome(n) / getRoadAnchor(rel,x,y,w,h) /
--   BATTLE_REL / TRAVEL_DISTANCE / TRAVEL_DURATION / clearCache()
--
-- Plano: docs/plan/worldroad-sphere-v4.md · Memória: memory/worldroad_scene.md

local biomesData = require("src.data.biomes")
local Sfx = require("src.systems.Sfx")

local WorldRoad = {}

-- ============================================================================
-- TUNING
-- ============================================================================
local CREST_RATIO   = 0.40   -- y do topo do domo (fração da altura da área)
local DOME_R_FACTOR = 1.6    -- raio do domo (menor = mundo mais "redondo",
                             -- sag da crista ≈ 0.08w — referência é bem curva)
local REL_CREST     = 26     -- distância de mundo em que algo está NA crista
local EMERGE_BAND   = 9      -- faixa de rel além da crista onde o corpo emerge
local T_POW         = 1.35   -- aceleração crista→base (o "giro" do disco)
local ROAD_HALF     = 0.15   -- meia-largura da estrada na base (fração de w)
local BRICK_LEN     = 0.72   -- comprimento de uma fileira de tijolos (mundo)
local PROP_SPACING  = 1.05  -- denso: cenário COMPLETO (feedback: "sentimento
                            -- de que tem todo um cenário já pronto"; ciclo 19
                            -- baixou de 1.45 — "poucas coisas espalhadas")
local UNIT_PX       = 0.115  -- 1 unidade de mundo em px = UNIT_PX × altura da área
local BLEND_DURATION = 2.2

WorldRoad.BATTLE_REL      = 9    -- perto de nós (ref: inimigo no terço de
                                 -- baixo, SEPARADO do castelo na crista)
-- ciclo 24 (feedback): viagem mais CALMA — menos distância e mais tempo
-- ("as coisas vão muito rápido, o inimigo chega muito rápido")
-- ciclo 26: mais lenta ainda (5.0→6.5s pra mesma distância)
WorldRoad.TRAVEL_DISTANCE = 20
WorldRoad.TRAVEL_DURATION = 6.5
local SEGMENT_LEN = WorldRoad.TRAVEL_DISTANCE * 8   -- 8 andares por bioma/trecho

-- Tamanho de mundo por tipo. REGRA DE OURO (feedback Jul/2026): árvore perto
-- da câmera TEM que ser maior que o inimigo (~255px) — árvore menor que
-- monstro quebra a escala do mundo. tree 3.8 → ~375px na base.
-- (Jul/2026, ciclo 19): +~25% geral — a maioria dos props visíveis vive em
-- t≈0.3-0.5 onde persp derruba pra ~30%; com os valores antigos tudo ficava
-- miúdo (feedback: "os tamanhos estão pequenos").
local KIND_SIZE = {
    tree = 4.6, pine = 5.0, deadtree = 4.2, fence = 1.55, sign = 1.7,
    bush = 1.35, rock = 1.05, flowers = 0.7, stump = 0.9, ruin = 2.9,
    tuft = 0.5,
}

-- Índice id → dados crus do bioma
local BIOME_BY_ID = {}
for _, b in ipairs(biomesData) do BIOME_BY_ID[b.id] = b end

local ENV_FIELDS = {
    "skyTop", "skyHorizon", "cloud", "hillsFar", "hillsNear",
    "grassA", "grassB", "roadA", "roadB", "roadEdge", "fog",
}

-- ============================================================================
-- ESTADO
-- ============================================================================
WorldRoad._time = 0
WorldRoad._camZ = 0
WorldRoad._ambient = {}          -- partículas ambientais por bioma
WorldRoad._smoke = {}            -- fumaça da chaminé do castelo (quando perto)
WorldRoad._castleTop = nil       -- {x, y, s} setado no drawCastleOf
WorldRoad._birds = {}            -- bando de pássaros cruzando o céu
WorldRoad._birdTimer = 3         -- primeiro bando cedo (validação vê)
WorldRoad._critters = {}         -- borboletas/vagalumes rasantes na grama
WorldRoad._biomeIndex = 1
WorldRoad._prevBiomeIndex = nil
WorldRoad._travel = nil
WorldRoad._encounter = nil        -- { img, iw, ih, scaleK, z }
WorldRoad._props = {}
WorldRoad._clouds = {}
WorldRoad._spriteCache = {}
WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
WorldRoad._blend = nil

local function rawBiome(idx)
    local n = #biomesData
    return biomesData[(((idx or WorldRoad._biomeIndex) - 1) % n) + 1]
end

local function copyColor(c) return { c[1], c[2], c[3], c[4] } end

local function envColor(field)
    local target = rawBiome()[field]
    local bl = WorldRoad._blend
    if not bl then return target end
    local from = bl.from[field]
    if not from then return target end
    local t = math.min(1, bl.t / bl.duration)
    t = t * t * (3 - 2 * t)
    return {
        from[1] + (target[1] - from[1]) * t,
        from[2] + (target[2] - from[2]) * t,
        from[3] + (target[3] - from[3]) * t,
        (from[4] or 1) + ((target[4] or 1) - (from[4] or 1)) * t,
    }
end

-- ============================================================================
-- GEOMETRIA DO DOMO
-- ============================================================================
-- Retorna funções de geometria pro frame corrente (dependem de x,y,w,h).
local function domeGeom(x, y, w, h)
    local crestY = math.floor(y + h * CREST_RATIO)
    local bottomY = y + h
    local R = w * DOME_R_FACTOR
    local cx = x + w / 2
    local cy = crestY + R            -- centro do círculo, bem abaixo da tela

    local g = {}
    g.crestApexY = crestY
    g.bottomY = bottomY
    g.cx = cx
    g.R = R
    g.y = y
    g.h = h
    -- y da borda do domo num px horizontal (a CRISTA CURVA)
    function g.crestYAt(px)
        local dx = px - cx
        local under = R * R - dx * dx
        if under <= 0 then return bottomY end
        return cy - math.sqrt(under)
    end
    -- rel (distância de mundo) → t de progressão 0..1 (0=crista, 1=base)
    function g.tOf(rel)
        local t = 1 - rel / REL_CREST
        if t < 0 then return nil end            -- ainda atrás da curva
        return math.min(1, t) ^ T_POW
    end
    -- PERSPECTIVA ÚNICA: todo tamanho no mundo passa por essa curva.
    -- Longe (t=0) = 10% do tamanho; perto (t=1) = 100%, com crescimento
    -- acelerado no fim (t^1.65) — profundidade REAL, não linear.
    function g.persp(t)
        return 0.14 + 0.86 * (t ^ 1.65)
    end
    -- LATITUDE VERDADEIRA da esfera: y de qualquer ponto do chão em
    -- (offset lateral dx, profundidade-fração t). Antes o Y interpolava
    -- linearmente pro fundo PLANO da tela — o campo próximo achatava e
    -- parecia "curvatura contrária". Agora tudo deita na circunferência:
    -- círculo de latitude com raio (R - d) e mesmo centro do domo.
    function g.latY(dx, t)
        local d = (bottomY - crestY) * t
        local rr = R - d
        local under = rr * rr - dx * dx
        if under <= 0 then return bottomY + 40 end
        return (crestY + R) - math.sqrt(under)
    end
    -- escala de um objeto com worldSize `size` no t dado
    function g.scaleAt(size, t, ih)
        local targetPx = size * (h * UNIT_PX * 1.25) * g.persp(t)
        return math.max(0.35, targetPx / ih)
    end
    return g
end

-- ============================================================================
-- SPRITES (PNG PixelLab prioridade; fallback procedural)
-- ============================================================================
local function tryLoadPng(name)
    local path = "assets/sprites/world/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then return nil end
    img:setFilter("nearest", "nearest")
    return img
end

local function px(data, x, y, c, w, h)
    if x >= 0 and x < w and y >= 0 and y < h then
        data:setPixel(x, y, c[1], c[2], c[3], c[4] or 1)
    end
end

local function blob(data, cx, cy, rx, ry, c, w, h, rng)
    for yy = math.floor(cy - ry), math.ceil(cy + ry) do
        for xx = math.floor(cx - rx), math.ceil(cx + rx) do
            local dx = (xx - cx) / rx
            local dy = (yy - cy) / ry
            local d = dx * dx + dy * dy
            if d <= 1 then
                if d < 0.82 or rng:random() > 0.35 then
                    px(data, xx, yy, c, w, h)
                end
            end
        end
    end
end

local function vline(data, x, y1, y2, c, w, h)
    for y = y1, y2 do px(data, x, y, c, w, h) end
end

local function hline(data, x1, x2, y, c, w, h)
    for x = x1, x2 do px(data, x, y, c, w, h) end
end

local function fillRect(data, x1, y1, x2, y2, c, w, h)
    for y = y1, y2 do hline(data, x1, x2, y, c, w, h) end
end

local function outline(data, w, h, dark)
    local marks = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a == 0 then
                for _, d in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
                    local nx, ny = x + d[1], y + d[2]
                    if nx >= 0 and nx < w and ny >= 0 and ny < h then
                        local _, _, _, na = data:getPixel(nx, ny)
                        if na > 0 then marks[#marks + 1] = { x, y }; break end
                    end
                end
            end
        end
    end
    for _, m in ipairs(marks) do
        data:setPixel(m[1], m[2], dark[1] * 0.4, dark[2] * 0.4, dark[3] * 0.4, 1)
    end
end

local function toImage(data)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

local function makeTree(b, variant, rng)
    local w, h = 26, 40
    local data = love.image.newImageData(w, h)
    local trunkW = 3 + (variant % 2)
    fillRect(data, math.floor(w / 2 - trunkW / 2), h - 14,
             math.floor(w / 2 + trunkW / 2), h - 1, b.trunk, w, h)
    blob(data, w / 2, h - 22, 10 + variant % 3, 8, b.canopyDark, w, h, rng)
    blob(data, w / 2 - 2, h - 28, 8, 7, b.canopy, w, h, rng)
    blob(data, w / 2 + 1, h - 33, 6, 5, b.canopy, w, h, rng)
    for _ = 1, 14 do
        local xx = math.floor(w / 2 - 5 + rng:random(0, 6))
        local yy = math.floor(h - 36 + rng:random(0, 6))
        px(data, xx, yy, { b.canopy[1] * 1.35, b.canopy[2] * 1.35, b.canopy[3] * 1.35 }, w, h)
    end
    outline(data, w, h, b.canopyDark)
    return toImage(data)
end

local function makePine(b, variant, rng)
    local w, h = 22, 42
    local data = love.image.newImageData(w, h)
    fillRect(data, w / 2 - 1, h - 10, w / 2 + 1, h - 1, b.trunk, w, h)
    local tiers = { { y = h - 10, rw = 9 }, { y = h - 18, rw = 7 },
                    { y = h - 26, rw = 5 }, { y = h - 33, rw = 3 } }
    for ti, tier in ipairs(tiers) do
        local c = (ti % 2 == 0) and b.canopy or b.canopyDark
        for row = 0, 7 do
            local half = math.max(1, tier.rw - row)
            hline(data, math.floor(w / 2 - half), math.floor(w / 2 + half),
                  tier.y - row, c, w, h)
        end
    end
    px(data, math.floor(w / 2), h - 41, b.canopy, w, h)
    outline(data, w, h, b.canopyDark)
    return toImage(data)
end

local function makeDeadTree(b, variant, rng)
    local w, h = 24, 38
    local data = love.image.newImageData(w, h)
    local dark = { b.trunk[1] * 0.7, b.trunk[2] * 0.7, b.trunk[3] * 0.7 }
    vline(data, math.floor(w / 2), h - 26, h - 1, b.trunk, w, h)
    vline(data, math.floor(w / 2) + 1, h - 26, h - 1, dark, w, h)
    local dirs = { { -1, 6 + variant }, { 1, 9 }, { -1, 14 }, { 1, 17 + variant } }
    for _, gg in ipairs(dirs) do
        local sx = math.floor(w / 2)
        local sy = h - 26 + gg[2] - 12
        for i = 0, 6 do
            px(data, sx + gg[1] * i, sy - i, b.trunk, w, h)
        end
    end
    outline(data, w, h, dark)
    return toImage(data)
end

local function makeBush(b, variant, rng)
    local w, h = 18, 12
    local data = love.image.newImageData(w, h)
    blob(data, w / 2 - 3, h - 5, 5, 4, b.bushDark, w, h, rng)
    blob(data, w / 2 + 3, h - 5, 5, 4, b.bushDark, w, h, rng)
    blob(data, w / 2, h - 7, 5 + variant % 2, 4, b.bush, w, h, rng)
    outline(data, w, h, b.bushDark)
    return toImage(data)
end

local function makeRock(b, variant, rng)
    local w, h = 16, 11
    local data = love.image.newImageData(w, h)
    blob(data, w / 2, h - 4, 6 + variant % 2, 4, b.rockDark, w, h, rng)
    blob(data, w / 2 - 1, h - 6, 4, 3, b.rock, w, h, rng)
    outline(data, w, h, b.rockDark)
    return toImage(data)
end

local function makeStump(b, variant, rng)
    local w, h = 12, 10
    local data = love.image.newImageData(w, h)
    fillRect(data, 2, 3, w - 3, h - 1, b.trunk, w, h)
    local light = { b.trunk[1] * 1.5, b.trunk[2] * 1.5, b.trunk[3] * 1.4 }
    fillRect(data, 2, 2, w - 3, 4, light, w, h)
    hline(data, 4, w - 5, 3, b.trunk, w, h)
    outline(data, w, h, { b.trunk[1] * 0.6, b.trunk[2] * 0.6, b.trunk[3] * 0.6 })
    return toImage(data)
end

local function makeFence(b, variant, rng)
    local w, h = 30, 14
    local data = love.image.newImageData(w, h)
    local wood = { b.trunk[1] * 1.2, b.trunk[2] * 1.2, b.trunk[3] * 1.1 }
    local dark = { b.trunk[1] * 0.7, b.trunk[2] * 0.7, b.trunk[3] * 0.7 }
    for _, postX in ipairs({ 3, 15, 27 }) do
        fillRect(data, postX - 1, 2, postX, h - 1, wood, w, h)
    end
    hline(data, 1, w - 2, 5, dark, w, h)
    hline(data, 1, w - 2, 6, wood, w, h)
    hline(data, 1, w - 2, 10, dark, w, h)
    hline(data, 1, w - 2, 11, wood, w, h)
    outline(data, w, h, dark)
    return toImage(data)
end

local function makeSign(b, variant, rng)
    local w, h = 16, 20
    local data = love.image.newImageData(w, h)
    local wood = { b.trunk[1] * 1.2, b.trunk[2] * 1.2, b.trunk[3] * 1.1 }
    local dark = { b.trunk[1] * 0.6, b.trunk[2] * 0.6, b.trunk[3] * 0.6 }
    vline(data, w / 2, 6, h - 1, wood, w, h)
    vline(data, w / 2 + 1, 6, h - 1, dark, w, h)
    fillRect(data, 2, 2, w - 3, 8, wood, w, h)
    hline(data, 4, w - 5, 4, dark, w, h)
    hline(data, 4, w - 7, 6, dark, w, h)
    outline(data, w, h, dark)
    return toImage(data)
end

local function makeFlowers(b, variant, rng)
    local w, h = 16, 8
    local data = love.image.newImageData(w, h)
    for _ = 1, 4 + (variant % 3) do
        local fx = 1 + rng:random(0, w - 3)
        local fy = h - 2 - rng:random(0, 2)
        px(data, fx, fy, b.bushDark, w, h)
        px(data, fx, fy - 1, b.accent, w, h)
        px(data, fx + 1, fy - 1, { b.accent[1] * 1.25, b.accent[2] * 1.25, b.accent[3] * 1.25 }, w, h)
    end
    return toImage(data)
end

local function makeRuin(b, variant, rng)
    local w, h = 18, 26
    local data = love.image.newImageData(w, h)
    local topY = 4 + (variant % 3) * 3
    fillRect(data, 5, topY, 12, h - 1, b.rock, w, h)
    fillRect(data, 11, topY, 12, h - 1, b.rockDark, w, h)
    for xx = 5, 12 do
        if rng:random() < 0.5 then px(data, xx, topY - 1, b.rock, w, h) end
    end
    fillRect(data, 3, h - 4, 14, h - 1, b.rockDark, w, h)
    vline(data, 8, topY + 4, topY + 9, b.rockDark, w, h)
    outline(data, w, h, b.rockDark)
    return toImage(data)
end

local function makeTuft(b, variant, rng)
    local w, h = 10, 7
    local data = love.image.newImageData(w, h)
    for _ = 1, 4 + variant do
        local fx = 1 + rng:random(0, w - 3)
        local blades = rng:random(2, 3)
        for i = 0, blades do
            vline(data, fx + i, h - 2 - rng:random(1, 3), h - 1, b.bush, w, h)
        end
    end
    return toImage(data)
end

-- Castelo procedural (fallback do PixelLab <biome>_castle.png)
local function makeCastle(b, rng)
    local w, h = 90, 120
    local data = love.image.newImageData(w, h)
    local lm, lmD = b.landmark, b.landmarkDark
    -- corpo central
    fillRect(data, 28, 34, 61, h - 1, lm, w, h)
    fillRect(data, 54, 34, 61, h - 1, lmD, w, h)
    -- torre central alta + telhado
    fillRect(data, 38, 8, 51, 40, lm, w, h)
    for i = 0, 7 do
        hline(data, 38 + i, 51 - i, 8 - 0 + i, { 0.25, 0.15, 0.18 }, w, h)
    end
    -- torres laterais
    fillRect(data, 14, 44, 27, h - 1, lm, w, h)
    fillRect(data, 62, 44, 75, h - 1, lm, w, h)
    fillRect(data, 23, 44, 27, h - 1, lmD, w, h)
    fillRect(data, 71, 44, 75, h - 1, lmD, w, h)
    -- ameias
    for i = 0, 3 do
        fillRect(data, 14 + i * 4, 40, 15 + i * 4, 43, lm, w, h)
        fillRect(data, 62 + i * 4, 40, 63 + i * 4, 43, lm, w, h)
    end
    -- janelas acesas
    local amber = { 0.92, 0.72, 0.32 }
    fillRect(data, 43, 18, 46, 23, amber, w, h)
    fillRect(data, 18, 52, 21, 56, amber, w, h)
    fillRect(data, 66, 52, 69, 56, amber, w, h)
    fillRect(data, 42, 50, 45, 55, amber, w, h)
    fillRect(data, 33, 70, 36, 75, amber, w, h)
    -- portão
    fillRect(data, 40, h - 18, 49, h - 1, { 0.2, 0.13, 0.08 }, w, h)
    outline(data, w, h, lmD)
    return toImage(data)
end

-- Nuvem procedural neutra (fallback de cloud_N.png do PixelLab)
local function makeCloud(variant, rng)
    local w, h = 42, 14
    local data = love.image.newImageData(w, h)
    local c = { 0.86, 0.83, 0.78 }
    blob(data, w * 0.35, h * 0.6, 10, 4, c, w, h, rng)
    blob(data, w * 0.6, h * 0.5, 12 - variant % 3, 5, c, w, h, rng)
    blob(data, w * 0.78, h * 0.65, 7, 3, c, w, h, rng)
    return toImage(data)
end

local MAKERS = {
    tree = makeTree, pine = makePine, deadtree = makeDeadTree,
    bush = makeBush, rock = makeRock, stump = makeStump,
    fence = makeFence, sign = makeSign, flowers = makeFlowers,
    ruin = makeRuin, tuft = makeTuft,
}

-- getSprite: nuvens/tijolos são neutros (sem bid); resto por bioma.
local function getSprite(kind, variant, bid)
    local key
    if kind == "cloud" then
        key = "cloud_" .. variant
    elseif kind == "castle" then
        key = (bid or rawBiome().id) .. "_castle"
    elseif kind == "mountains" then
        key = (bid or rawBiome().id) .. "_mountains"
    elseif kind == "mountains_front" then
        key = (bid or rawBiome().id) .. "_mountains_front"
    else
        key = (bid or rawBiome().id) .. "_" .. kind .. "_" .. variant
    end
    if WorldRoad._spriteCache[key] then return WorldRoad._spriteCache[key] end

    local img = tryLoadPng(key)
    -- fallback pra VARIANTE 0 do PNG: se o tipo tem arte PixelLab, ela SEMPRE
    -- vence o procedural (misturar arte rica com procedural tosco denuncia)
    if not img and kind ~= "cloud" and kind ~= "castle"
       and kind ~= "mountains" and variant ~= 0 then
        img = tryLoadPng((bid or rawBiome().id) .. "_" .. kind .. "_0")
    end
    if not img then
        local rng = love.math.newRandomGenerator(#key * 7919 + variant * 131)
        local b = BIOME_BY_ID[bid] or rawBiome()
        if kind == "cloud" then
            img = makeCloud(variant, rng)
        elseif kind == "castle" then
            img = makeCastle(b, rng)
        elseif kind == "mountains" or kind == "mountains_front" then
            img = false   -- sem fallback de imagem; drawMountains desenha ridge
            -- (mountains_front sem PNG = bioma sem oclusão de nuvem, ex. marsh)
        else
            img = MAKERS[kind](b, variant, rng)
        end
    end
    WorldRoad._spriteCache[key] = img
    return img
end

-- ============================================================================
-- MUNDO: props em distância + reciclagem
-- ============================================================================
-- Lanes (ciclo 21 — CUNHA): lane agora é fração [0,1] DENTRO da cunha
-- permitida (triângulo da lateral do castelo até o canto de baixo da tela,
-- igual à referência do APK). 0 = colado na diagonal interna, 1 = borda.
-- O corredor central (estrada + grama ao redor) fica SEMPRE limpo.
local KIND_LANE = {
    fence = { 0.02, 0.14 }, sign = { 0.03, 0.18 },
    flowers = { 0.0, 0.85 }, tuft = { 0.0, 1.0 },
    default = { 0.05, 1.0 },
}

-- Espécie de árvore dominante por bioma (treeline + reciclagem de wall)
local TREE_KIND = { fields = "tree", highlands = "pine", abyss = "deadtree",
                    frost = "pine", marsh = "deadtree", dusk = "tree" }

-- ciclo 22 (feedback): "árvores muitas vezes, o resto poucas" — árvores
-- pesam ×3.5 no sorteio, todo o resto ×0.5 (tufo quase some: 2.5→0.7)
local TREEISH = { tree = true, pine = true, deadtree = true }
local function pickKind(b, rng)
    local total = 0
    for kind, wgt in pairs(b.propWeights) do
        total = total + wgt * (TREEISH[kind] and 3.5 or 0.5)
    end
    total = total + 0.7
    local r = rng:random() * total
    if r > total - 0.7 then return "tuft" end
    for kind, wgt in pairs(b.propWeights) do
        r = r - wgt * (TREEISH[kind] and 3.5 or 0.5)
        if r <= 0 then return kind end
    end
    return TREE_KIND[b.id] or "tree"
end

local function rollProp(p, z, forcedSide)
    local b = rawBiome()
    local rng = WorldRoad._rng
    p.z = z
    p.kind = pickKind(b, rng)
    -- LADO: populate agora spawna nos DOIS lados por passo (ciclo 21 —
    -- cunhas cheias e simétricas por construção). O saldo _sideBal fica
    -- pros spawns avulsos durante a viagem.
    if forcedSide then
        p.side = forcedSide
    else
        local SIDE_W = { tree = 1, pine = 1, deadtree = 1, ruin = 1,
                         fence = 0.7, sign = 0.7 }
        local bal = WorldRoad._sideBal or 0
        local pLeft = math.min(0.85, math.max(0.15, 0.5 - bal * 0.16))
        p.side = rng:random() < pLeft and -1 or 1
        WorldRoad._sideBal = bal + p.side * (SIDE_W[p.kind] or 0.35)
    end
    local lane = KIND_LANE[p.kind] or KIND_LANE.default
    p.lane = lane[1] + rng:random() * (lane[2] - lane[1])
    p.variant = rng:random(0, 2)
    p.bid = b.id
    p.big = 1
    p.cluster = nil
    p.jitter = rng:random() * 2 - 1   -- usado pelo offset dos clusters
    -- MOLDURA LATERAL (lição dos painéis do PoK): ~30% dos props grandes vão
    -- pras bordas da tela, maiores — emolduram o corredor visual até o castelo
    if (p.kind == "tree" or p.kind == "pine" or p.kind == "deadtree")
       and rng:random() < 0.45 then
        p.lane = 0.72 + rng:random() * 0.26
        p.big = 1.2 + rng:random() * 0.25
    end
    -- CLUSTER: ~45% da vegetação vem em grupo de 2-3 (natural, não solto)
    if (p.kind == "tree" or p.kind == "pine" or p.kind == "deadtree"
        or p.kind == "bush") and rng:random() < 0.45 then
        p.cluster = rng:random(1, 2)
        -- ciclo 20: cluster multiplica a MASSA VISUAL do lado — sem contar
        -- as companheiras no saldo, um "grupo de 3" pesava como 1 árvore e
        -- a tela desequilibrava mesmo com o sorteio balanceado
        WorldRoad._sideBal = (WorldRoad._sideBal or 0)
            + p.side * 0.55 * p.cluster
    end
    -- AVES pousadas em cercas (~55%): voam quando você chega perto
    p.flown = nil
    p.perched = nil
    if p.kind == "fence" and rng:random() < 0.55 then
        p.perched = rng:random(1, 2)
    end
end

-- ANTI-EMPILHAMENTO: rejeita spawn que cai em cima de outro prop grande
-- (mesmo lado, lane próxima, z próximo) — re-rola lane/lado até 4 tentativas
local function resolveOverlap(p)
    -- CERCAS têm zona de exclusividade GLOBAL (uma linha de cerca a cada
    -- 8+ unidades, qualquer lado): cerca é marco raro da estrada, não
    -- entulho — 2 props de cerca juntos viravam "ferro-velho" de 6 cercas
    if p.kind == "fence" then
        for _, o in ipairs(WorldRoad._props) do
            if o ~= p and o.kind == "fence" and math.abs(o.z - p.z) < 8 then
                p.kind = "bush"   -- rebaixa pra arbusto (mantém densidade)
                local lane = KIND_LANE.default
                p.lane = lane[1] + WorldRoad._rng:random() * (lane[2] - lane[1])
                return
            end
        end
        return
    end
    local BIG = { tree = true, pine = true, deadtree = true, ruin = true }
    if not BIG[p.kind] then return end
    for _ = 1, 4 do
        local clash = false
        for _, o in ipairs(WorldRoad._props) do
            if o ~= p and BIG[o.kind] and o.side == p.side
               and math.abs(o.z - p.z) < 2.2
               and math.abs(o.lane - p.lane) < 0.22 then
                clash = true
                break
            end
        end
        if not clash then return end
        -- ciclo 21: mantém o LADO (spawn agora é simétrico por construção)
        -- e re-rola posição dentro da cunha: lane nova + nudge em z
        local lane = KIND_LANE[p.kind] or KIND_LANE.default
        p.lane = lane[1] + WorldRoad._rng:random() * (lane[2] - lane[1])
        p.z = p.z + (WorldRoad._rng:random() - 0.5) * 1.4
    end
end

-- Transforma um prop em membro da PAREDE de árvores (treeline da cunha):
-- espécie dominante do bioma, lane no miolo da cunha, maior, 50% cluster
local function makeWall(p)
    local rng = WorldRoad._rng
    p.wall = true
    p.kind = TREE_KIND[p.bid] or "tree"
    p.lane = 0.2 + rng:random() * 0.6
    p.big = 1 + rng:random() * 0.3
    p.cluster = rng:random() < 0.5 and rng:random(1, 2) or nil
    p.perched = nil
end

local function populate()
    WorldRoad._props = {}
    WorldRoad._sideBal = 0
    local b = rawBiome()
    local z = 0.5
    while z < REL_CREST + EMERGE_BAND do
        -- ciclo 21: spawn nos DOIS lados por passo (90% cada) — cunhas
        -- laterais cheias ("preencha quase tudo") e simétricas por construção
        for side = -1, 1, 2 do
            if WorldRoad._rng:random() < 0.9 then
                local p = {}
                rollProp(p, z + WorldRoad._camZ
                    + WorldRoad._rng:random() * 0.5, side)
                table.insert(WorldRoad._props, p)
                resolveOverlap(p)
            end
        end
        z = z + PROP_SPACING / math.max(0.2, b.propDensity)
            + WorldRoad._rng:random() * 0.9
    end
    -- TREELINE (ciclo 21, ref APK): parede CONTÍNUA de árvores nas cunhas —
    -- o sorteio misto acima gasta muito em prop pequeno, então sem essa
    -- passada garantida ficavam buracos na moldura de floresta.
    -- p.wall = true: a reciclagem preserva a identidade (ciclo 22 — sem
    -- isso a parede dissolvia em tufos conforme o jogador viajava)
    local zt = 1.2
    while zt < REL_CREST + EMERGE_BAND do
        for side = -1, 1, 2 do
            local p = {}
            rollProp(p, zt + WorldRoad._camZ
                + WorldRoad._rng:random() * 0.5, side)
            makeWall(p)
            table.insert(WorldRoad._props, p)
            resolveOverlap(p)
        end
        zt = zt + 0.95 + WorldRoad._rng:random() * 0.4
    end
    -- v5.8 (feedback): nuvens SEMPRE pequenas e ao fundo — nada de bolha
    -- gigante colada na câmera. Drift lento + bob senoidal (phase) pra
    -- não ficarem estáticas. v5.10 (feedback): menos nuvens, banda mais
    -- ALTA no céu, e só cloud_0 (cloud_1 foi apagada do jogo).
    WorldRoad._clouds = {}
    for _ = 1, 4 do
        table.insert(WorldRoad._clouds, {
            xr = WorldRoad._rng:random(),
            yr = 0.07 + WorldRoad._rng:random() * 0.33,
            speed = 1.6 + WorldRoad._rng:random() * 1.8,
            scale = 0.85 + WorldRoad._rng:random() * 0.55,
            phase = WorldRoad._rng:random() * 6.28,
            variant = 0,
        })
    end
    -- camada DISTANTE de nuvens (menores e mais lentas ainda —
    -- segunda profundidade no céu = fundo mais rico sem poluir)
    for _ = 1, 3 do
        table.insert(WorldRoad._clouds, {
            xr = WorldRoad._rng:random(),
            yr = 0.05 + WorldRoad._rng:random() * 0.20,
            speed = 0.7 + WorldRoad._rng:random() * 0.9,
            scale = 0.45 + WorldRoad._rng:random() * 0.30,
            phase = WorldRoad._rng:random() * 6.28,
            variant = 0,
            far = true,
        })
    end
end

-- ============================================================================
-- API
-- ============================================================================
function WorldRoad.setBiome(n)
    local idx = math.max(1, n or 1)
    if idx ~= WorldRoad._biomeIndex then
        local from = {}
        for _, f in ipairs(ENV_FIELDS) do from[f] = copyColor(envColor(f)) end
        WorldRoad._prevBiomeIndex = WorldRoad._biomeIndex
        WorldRoad._biomeIndex = idx
        WorldRoad._blend = { from = from, t = 0, duration = BLEND_DURATION }
    end
end

function WorldRoad.travel(opts)
    opts = opts or {}
    local dist = opts.distance or WorldRoad.TRAVEL_DISTANCE
    WorldRoad._travel = {
        from = WorldRoad._camZ,
        dist = dist,
        t = 0,
        duration = opts.duration or WorldRoad.TRAVEL_DURATION,
        onComplete = opts.onComplete,
    }
    if opts.encounter and opts.encounter.img then
        local e = opts.encounter
        WorldRoad._encounter = {
            img = e.img, iw = e.iw, ih = e.ih,
            targetScale = e.targetScale or 4,
            z = WorldRoad._camZ + dist + WorldRoad.BATTLE_REL,
        }
    else
        WorldRoad._encounter = nil
    end
end

function WorldRoad.isTraveling()
    return WorldRoad._travel ~= nil
end

-- Âncora na estrada (centro) pro rel dado — usada pelo inimigo de batalha.
-- MEANDRO da estrada (v5.2, feedback: "caminho retinho, precisa de
-- imperfeições"): 3 senos em frequências diferentes — curvas largas +
-- ondulação local. Depende do worldZ ABSOLUTO: objetos ancorados numa
-- posição do mundo veem o mesmo desvio que a fileira da estrada ali.
local function roadWobble(worldZ, t, w)
    return (math.sin(worldZ * 0.11) * 0.5
        + math.sin(worldZ * 0.30 + 2.1) * 0.32
        + math.sin(worldZ * 0.71 + 0.7) * 0.18)
        * w * 0.045 * (0.28 + 0.72 * t)
end

function WorldRoad.getRoadAnchor(rel, x, y, w, h)
    local g = domeGeom(x, y, w, h)
    local t = g.tOf(rel) or 0
    local sy = g.crestApexY + (g.bottomY - g.crestApexY) * t
    local wob = roadWobble(WorldRoad._camZ + rel, t, w)
    return math.floor(g.cx + wob), math.floor(sy)
end

local function easeInOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local f = 2 * t - 2
    return 1 + f * f * f / 2
end

-- MARCOS DO FORK (declarados ANTES do update — bug ciclo 41: eram locais
-- do fim do arquivo e update() não os enxergava → crash ao escolher).
-- Tamanhos GRANDES (feedback: "são realmente lugares, maiores que árvores")
local LANDMARK_FOR_TYPE = {
    battle = "landmark_battle", elite = "landmark_elite",
    mini_boss = "landmark_battle", boss = "landmark_battle",
    rest = "landmark_rest", shop = "landmark_shop",
    event = "landmark_event", treasure = "landmark_chest",
}
local LANDMARK_SIZE = {
    landmark_battle = 3.4, landmark_elite = 4.4, landmark_rest = 3.6,
    landmark_shop = 5.2, landmark_event = 5.0, landmark_chest = 2.6,
}
local landmarkCache = {}
local function getLandmark(key)
    if landmarkCache[key] ~= nil then return landmarkCache[key] or nil end
    local img = tryLoadPng(key)
    landmarkCache[key] = img or false
    return img
end

function WorldRoad.update(dt)
    WorldRoad._time = WorldRoad._time + dt

    if #WorldRoad._props == 0 then populate() end

    -- FORK (v5): entrada + hover + convergência
    local f = WorldRoad._fork
    if f then
        f.animIn = math.min(1, (f.animIn or 0) + dt * 2.2)
        if f.chosenPulse and f.chosenPulse > 0 then
            f.chosenPulse = math.max(0, f.chosenPulse - dt)
        end
        local c = f.converge
        if c then
            c.t = c.t + dt
            local k = math.min(1, c.t / c.duration)
            c.k = easeInOutCubic(k)
            WorldRoad._camZ = c.z0 + c.dist * c.k
            if k >= 1 then
                local node = f.nodes[f.chosen]
                local key = node and LANDMARK_FOR_TYPE[tostring(node.type)]
                if key then
                    WorldRoad._landmark = {
                        key = key, z = f.markZ,
                        size = LANDMARK_SIZE[key] or 2.0,
                    }
                end
                local cb, idx = f.onChosen, f.chosen
                WorldRoad._fork = nil
                if cb then cb(node, idx) end
            end
        else
            local mx, my = love.mouse.getPosition()
            f.hover = WorldRoad.forkHitTest(mx, my)
        end
    end

    local bl = WorldRoad._blend
    if bl then
        bl.t = bl.t + dt
        if bl.t >= bl.duration then
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
        end
    end

    local tr = WorldRoad._travel
    if tr then
        tr.t = tr.t + dt
        local k = math.min(1, tr.t / tr.duration)
        WorldRoad._camZ = tr.from + tr.dist * easeInOutCubic(k)
        if k >= 1 then
            WorldRoad._travel = nil
            WorldRoad._encounter = nil   -- handoff: EnemyRenderer assume
            if tr.onComplete then tr.onComplete() end
        end
    end

    -- Reciclagem: passou da base → renasce atrás da crista. Preserva o
    -- LADO (simetria eterna) e a identidade de PAREDE (ciclo 22 — sem isso
    -- a treeline dissolvia em props pequenos conforme o jogador viajava)
    for _, p in ipairs(WorldRoad._props) do
        -- -3.5 (era -0.5): dá tempo do slide-out do ciclo 25 tirar o prop
        -- da tela por completo antes de reciclar
        if p.z - WorldRoad._camZ < -3.5 then
            local wasWall = p.wall
            rollProp(p, WorldRoad._camZ + REL_CREST + EMERGE_BAND * 0.6
                        + WorldRoad._rng:random() * 2, p.side)
            if wasWall then makeWall(p) end
            resolveOverlap(p)
        end
    end

    local travelPush = tr and 0.004 or 0
    for _, c in ipairs(WorldRoad._clouds) do
        c.xr = c.xr - (c.speed / 1000 + travelPush) * dt * 10
        if c.xr < -0.2 then c.xr = 1.15 end
    end

    -- PARTÍCULAS AMBIENTAIS por bioma (folha/neve/brasa/esporo): a camada
    -- de vida que faz o mundo respirar. Spawn contínuo, cap 36.
    local amb = rawBiome().ambient
    if amb and #WorldRoad._ambient < 36 and WorldRoad._rng:random() < amb.rate then
        local rising = amb.style == "ember"
        table.insert(WorldRoad._ambient, {
            xr = WorldRoad._rng:random(),
            yr = rising and (0.75 + WorldRoad._rng:random() * 0.25)
                 or (-0.05 - WorldRoad._rng:random() * 0.1),
            vy = (rising and -1 or 1) * (0.028 + WorldRoad._rng:random() * 0.03),
            phase = WorldRoad._rng:random() * 6.28,
            size = WorldRoad._rng:random(2, 3),
            life = 1,
            style = amb.style,
            color = amb.color,
        })
    end
    for i = #WorldRoad._ambient, 1, -1 do
        local a = WorldRoad._ambient[i]
        a.yr = a.yr + a.vy * dt
        a.xr = a.xr + math.sin(WorldRoad._time * 1.6 + a.phase) * 0.018 * dt
            - (tr and 0.010 or 0.004) * dt
        if a.yr > 1.08 or a.yr < -0.12 or a.xr < -0.05 or a.xr > 1.05 then
            table.remove(WorldRoad._ambient, i)
        end
    end

    -- FUMAÇA DA CHAMINÉ do castelo: só quando perto (progress > 0.55) —
    -- "tem alguém lá" esperando você chegar
    local ct = WorldRoad._castleTop
    if ct and ct.progress > 0.55 and #WorldRoad._smoke < 14
       and WorldRoad._rng:random() < 0.10 then
        table.insert(WorldRoad._smoke, {
            x = ct.x, y = ct.y,
            vx = 4 + WorldRoad._rng:random() * 6,
            vy = -(9 + WorldRoad._rng:random() * 7),
            size = (2 + WorldRoad._rng:random(0, 2)) * math.max(0.6, ct.s),
            life = 2.2 + WorldRoad._rng:random() * 1.4,
            maxLife = 3.6,
            phase = WorldRoad._rng:random() * 6.28,
        })
    end
    for i = #WorldRoad._smoke, 1, -1 do
        local sp = WorldRoad._smoke[i]
        sp.x = sp.x + (sp.vx + math.sin(WorldRoad._time * 1.3 + sp.phase) * 4) * dt
        sp.y = sp.y + sp.vy * dt
        sp.size = sp.size + 2.4 * dt          -- expande subindo
        sp.life = sp.life - dt
        if sp.life <= 0 then table.remove(WorldRoad._smoke, i) end
    end

    -- PÁSSAROS: bando ocasional cruzando o céu (vida acima do horizonte)
    WorldRoad._birdTimer = WorldRoad._birdTimer - dt
    if WorldRoad._birdTimer <= 0 and #WorldRoad._birds == 0 then
        WorldRoad._birdTimer = 9 + WorldRoad._rng:random() * 14
        local dir = WorldRoad._rng:random() < 0.5 and 1 or -1
        local baseY = 0.10 + WorldRoad._rng:random() * 0.16
        local n = WorldRoad._rng:random(3, 5)
        for i = 1, n do
            table.insert(WorldRoad._birds, {
                xr = (dir == 1 and -0.05 or 1.05) - dir * i * 0.022,
                yr = baseY + (i % 2) * 0.018 + WorldRoad._rng:random() * 0.01,
                dir = dir,
                speed = 0.052 + WorldRoad._rng:random() * 0.014,
                phase = WorldRoad._rng:random() * 6.28,
            })
        end
    end
    for i = #WorldRoad._birds, 1, -1 do
        local bd = WorldRoad._birds[i]
        bd.xr = bd.xr + bd.dir * bd.speed * dt
        -- arco de decolagem (aves que estavam pousadas): sobe e nivela
        if bd.vyr then
            bd.yr = bd.yr + bd.vyr * dt
            bd.vyr = bd.vyr + 0.09 * dt
            if bd.vyr > -0.01 then bd.vyr = nil end
        end
        if bd.xr < -0.12 or bd.xr > 1.12 or bd.yr < -0.12 or bd.yr > 1.8 then
            table.remove(WorldRoad._birds, i)
        end
    end

    -- CRITTERS: borboletas/vagalumes rasantes sobre a grama (vida no chão)
    if #WorldRoad._critters < 6 and WorldRoad._rng:random() < 0.02 then
        table.insert(WorldRoad._critters, {
            xr = 0.06 + WorldRoad._rng:random() * 0.88,
            yr = 0.55 + WorldRoad._rng:random() * 0.34,
            phase = WorldRoad._rng:random() * 6.28,
            drift = (WorldRoad._rng:random() - 0.5) * 0.014,
            life = 12 + WorldRoad._rng:random() * 10,
        })
    end
    for i = #WorldRoad._critters, 1, -1 do
        local cr = WorldRoad._critters[i]
        cr.xr = cr.xr + cr.drift * dt
            + math.sin(WorldRoad._time * 2.7 + cr.phase) * 0.012 * dt
        cr.life = cr.life - dt
        if cr.life <= 0 or cr.xr < 0 or cr.xr > 1 then
            table.remove(WorldRoad._critters, i)
        end
    end
end

-- ============================================================================
-- RENDER
-- ============================================================================
-- Cor do topo do strip de montanhas (o céu BAKED no PNG) — cacheada por bioma.
-- O céu procedural preenche a área acima do strip com ESSA cor → emenda
-- invisível (era o "retângulo escuro": sépia procedural vs azul do PNG).
local skyTopColorCache = {}
local function mountainsSkyColor(bid)
    if skyTopColorCache[bid] ~= nil then return skyTopColorCache[bid] end
    local path = "assets/sprites/world/" .. bid .. "_mountains.png"
    local color = false
    if love.filesystem.getInfo(path) then
        local ok, data = pcall(love.image.newImageData, path)
        if ok and data then
            -- desce a coluna central até achar um pixel OPACO e CLARO —
            -- pula outline/borda escura do topo do strip (bug: céu preto)
            local cx = math.floor(data:getWidth() / 2)
            for yy = 1, math.min(30, data:getHeight() - 1) do
                local r, gg, b, a = data:getPixel(cx, yy)
                if a > 0.9 and (r + gg + b) > 0.45 then
                    color = { r, gg, b }
                    break
                end
            end
        end
    end
    skyTopColorCache[bid] = color
    return color
end

local function drawSky(g, x, y, w)
    local skyH = g.crestApexY - y + 40   -- desce um pouco além da crista (o domo cobre)

    local baked = mountainsSkyColor(rawBiome().id)
    -- crossfade da cor do céu na troca de bioma (sem salto escuro)
    local bl = WorldRoad._blend
    if baked and bl and WorldRoad._prevBiomeIndex then
        local prevBaked = mountainsSkyColor(rawBiome(WorldRoad._prevBiomeIndex).id)
        if prevBaked then
            local t = math.min(1, bl.t / bl.duration)
            baked = {
                prevBaked[1] + (baked[1] - prevBaked[1]) * t,
                prevBaked[2] + (baked[2] - prevBaked[2]) * t,
                prevBaked[3] + (baked[3] - prevBaked[3]) * t,
            }
        end
    end
    if baked then
        -- casa com o céu do PNG das montanhas: cor chapada + leve clareada
        -- nas bandas de baixo (chunky 8px)
        local bandH = 8
        local bands = math.ceil(skyH / bandH)
        for i = 0, bands do
            local t = i / bands
            local f = 1 + t * 0.06
            love.graphics.setColor(baked[1] * f, baked[2] * f, baked[3] * f, 1)
            love.graphics.rectangle("fill", x, y + i * bandH, w, bandH)
        end
        return
    end

    -- fallback procedural (sem PNG): gradiente sépia SEM faixa escura no topo
    local top = envColor("skyTop")
    local hor = envColor("skyHorizon")
    local tR = top[1] + (hor[1] - top[1]) * 0.35
    local tG = top[2] + (hor[2] - top[2]) * 0.35
    local tB = top[3] + (hor[3] - top[3]) * 0.35
    local bandH = 8
    local bands = math.ceil(skyH / bandH)
    for i = 0, bands do
        local t = i / bands
        love.graphics.setColor(
            tR + (hor[1] - tR) * t,
            tG + (hor[2] - tG) * t,
            tB + (hor[3] - tB) * t, 1)
        love.graphics.rectangle("fill", x, y + i * bandH, w, bandH)
    end
end

-- Sol/lua do bioma (identidade do céu; nuvens passam NA FRENTE)
local function drawCelestialOf(g, x, y, w, bid, alpha)
    local b = BIOME_BY_ID[bid] or rawBiome()
    local cel = b.celestial
    if not cel then return end
    local cx = x + cel.xr * w
    local cy = y + cel.yr * (g.crestApexY - y)
    local c = cel.color
    -- halo suave (2 anéis)
    love.graphics.setColor(c[1], c[2], c[3], 0.10 * alpha)
    love.graphics.circle("fill", cx, cy, cel.r * 2.1)
    love.graphics.setColor(c[1], c[2], c[3], 0.16 * alpha)
    love.graphics.circle("fill", cx, cy, cel.r * 1.45)
    -- disco
    love.graphics.setColor(c[1], c[2], c[3], 0.95 * alpha)
    love.graphics.circle("fill", cx, cy, cel.r)
    -- lua: disco cheio + CRATERAS (crescente via disco-de-céu deixava anel
    -- fantasma quando a cor amostrada não batia com o gradiente local)
    if cel.kind == "moon" then
        love.graphics.setColor(c[1] * 0.72, c[2] * 0.72, c[3] * 0.78, 0.9 * alpha)
        love.graphics.circle("fill", cx - cel.r * 0.28, cy - cel.r * 0.12, cel.r * 0.22)
        love.graphics.circle("fill", cx + cel.r * 0.30, cy + cel.r * 0.30, cel.r * 0.16)
        love.graphics.circle("fill", cx + cel.r * 0.12, cy - cel.r * 0.42, cel.r * 0.12)
    end
end

local function drawCelestial(g, x, y, w)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawCelestialOf(g, x, y, w, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
        drawCelestialOf(g, x, y, w, rawBiome().id, t)
    else
        drawCelestialOf(g, x, y, w, rawBiome().id, 1)
    end
end

-- Pássaros: silhuetas "^" com batida de asa (2 frames por seno)
local function drawBirds(g, x, y, w)
    local skyH = g.crestApexY - y
    for _, bd in ipairs(WorldRoad._birds) do
        local bx = x + bd.xr * w
        local by = y + bd.yr * skyH + math.sin(WorldRoad._time * 2.2 + bd.phase) * 3
        local up = math.sin(WorldRoad._time * 9 + bd.phase) > 0
        local wy = up and -2 or 0
        love.graphics.setColor(0.12, 0.10, 0.10, 0.85)
        -- asas (2 traços) + corpo
        love.graphics.rectangle("fill", math.floor(bx - 4), math.floor(by + wy), 3, 1)
        love.graphics.rectangle("fill", math.floor(bx + 2), math.floor(by + wy), 3, 1)
        love.graphics.rectangle("fill", math.floor(bx - 1), math.floor(by), 2, 2)
    end
end

local function drawClouds(g, x, y, w)
    local tint = envColor("cloud")
    -- escala acompanha (raiz da) largura da tela: no ultrawide o strip é
    -- gigante — nuvem em px fixo sumiria; no 4:3 não estoura
    local sw = math.sqrt(w / 1024)
    for _, c in ipairs(WorldRoad._clouds) do
        local img = getSprite("cloud", c.variant)
        if img then
            local a = math.min(1, (tint[4] or 0.5) + 0.35) * (c.far and 0.7 or 1)
            local s = c.scale * sw
            -- bob vertical suave (v5.8): mesma ideia do sway das árvores —
            -- viva, mas sem sair do lugar
            local bob = math.sin(WorldRoad._time * 0.35 + (c.phase or 0)) * 2.5
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.draw(img, math.floor(x + c.xr * w),
                math.floor(y + c.yr * (g.crestApexY - y) * 0.8 + bob), 0, s, s)
        end
    end
end

-- v6.1: texturas de gradiente reutilizáveis — rampa de alpha de 256
-- passos (invisível a olho) que mata o banding das faixas de rects
-- (névoa de distância, vinhetas). Cor final = textura * setColor, então
-- a MESMA textura serve pra qualquer cor/alpha. Deliberadamente Image
-- (caminho GL mais batido do projeto) e não Mesh — o driver NVIDIA da
-- máquina é frágil (histórico 0xC00000FD).
local _gradV, _gradH
local function gradTex()
    if not _gradV then
        local n = 256
        local idv = love.image.newImageData(1, n)
        for i = 0, n - 1 do
            idv:setPixel(0, i, 1, 1, 1, 1 - i / (n - 1))   -- alpha 1 topo -> 0 base
        end
        _gradV = love.graphics.newImage(idv)
        _gradV:setFilter("linear", "linear")
        local idh = love.image.newImageData(n, 1)
        for i = 0, n - 1 do
            idh:setPixel(i, 0, 1, 1, 1, 1 - i / (n - 1))   -- alpha 1 esq -> 0 dir
        end
        _gradH = love.graphics.newImage(idh)
        _gradH:setFilter("linear", "linear")
    end
    return _gradV, _gradH
end

-- v6.4: glow radial gerado 1x (falloff (1-d²)² — luz suave sem shader).
local _glowImg
local function glowTex()
    if not _glowImg then
        local n = 128
        local id = love.image.newImageData(n, n)
        local c = (n - 1) / 2
        for yy = 0, n - 1 do
            for xx = 0, n - 1 do
                local d = math.sqrt((xx - c) ^ 2 + (yy - c) ^ 2) / c
                local a = math.max(0, 1 - d * d)
                id:setPixel(xx, yy, 1, 1, 1, a * a)
            end
        end
        _glowImg = love.graphics.newImage(id)
        _glowImg:setFilter("linear", "linear")
    end
    return _glowImg
end

-- v6.4: intensidade do glow das janelas por bioma (forte nos escuros,
-- discreto nos claros — luz acesa de dia existe, mas não domina)
local CASTLE_GLOW_K = {
    fields = 0.45, highlands = 0.85, abyss = 1.0,
    frost = 0.5, marsh = 0.9, dusk = 1.0,
}

-- v6.3: direção da luz da cena = posição do astro do bioma. Sombras de
-- contato deslocam CONTRA o sol (coerência global barata, mesma ideia do
-- shadow_parrallax do Balatro). Retorna deslocamento normalizado [-1,1].
local function sunShadowDir(g, x, w, px)
    local cel = rawBiome().celestial
    local sunX = cel and (x + cel.xr * w) or g.cx
    return math.max(-1, math.min(1, (px - sunX) / (w * 0.5)))
end

local function ridge(seed, i)
    return math.sin(i * 0.7 + seed) * 0.5 + math.sin(i * 0.23 + seed * 2.3) * 0.35
         + math.sin(i * 1.7 + seed * 0.7) * 0.15
end

-- Transform do strip gigante (v5.7): escala COVER + tiling espelhado.
-- COMPARTILHADO entre o strip base e a camada frontal (mountains_front) —
-- as duas precisam alinhar pixel-perfect pra oclusão de nuvem funcionar.
local function stripTransform(g, x, w, camZ, iw, ih)
    local sx = math.max(w / iw, (g.crestApexY - g.y + 70) / ih)
    local yTop = math.floor(g.crestApexY - ih * sx + math.min(70, ih * sx * 0.22))
    local tileW = iw * sx
    local off = (camZ * 2.5 * sx) % (tileW * 2)
    return sx, yTop, tileW, off
end

local function drawStripTiles(img, x, sx, yTop, tileW, off)
    for k = -1, 2 do
        local tx = x - off + k * tileW
        if (k % 2 == 0) then
            love.graphics.draw(img, math.floor(tx), yTop, 0, sx, sx)
        else
            love.graphics.draw(img, math.floor(tx + tileW), yTop, 0, -sx, sx)
        end
    end
end

-- v5.9.4 (feedback): abaixo do strip, o PRÓPRIO strip INTEIRO de cabeça
-- pra baixo, emendado na última linha de ARTE BOA — "é como se fosse uma
-- continuação da parte debaixo do principal mas de cabeça para baixo".
-- O rodapé chapado (degradê pra preto assado pela geração) foi CROPADO
-- dos PNGs na fonte (scratchpad/crop_strip_footer.py, Jul/2026) — a
-- última linha do strip é arte boa, então o espelho é o strip inteiro.
local function drawStripMirrorBelow(img, x, sx, yTop, tileW, off, bottomY)
    local ih = img:getHeight()
    local stripH = ih * sx
    local seamY = math.floor(yTop + stripH)   -- fim da arte do strip
    local b = 0
    local yb = seamY
    while yb < bottomY and b < 6 do
        local flipped = (b % 2 == 0)   -- 1º bloco: espelho; depois ping-pong
        for k = -1, 2 do
            local tx = x - off + k * tileW
            local dx = (k % 2 == 0) and math.floor(tx) or math.floor(tx + tileW)
            local sxx = (k % 2 == 0) and sx or -sx
            if flipped then
                love.graphics.draw(img, dx, yb + stripH, 0, sxx, -sx)
            else
                love.graphics.draw(img, dx, yb, 0, sxx, sx)
            end
        end
        yb = yb + stripH
        b = b + 1
    end
    return yb
end

-- Desenha montanhas de UM bioma com alpha (usado pro crossfade no blend)
local function drawMountainsOf(g, x, w, camZ, bid, alpha)
    if _G.WR_DEBUG then print("[WR] mountainsOf bid=" .. tostring(bid) .. " a=" .. alpha) end
    local img = getSprite("mountains", 0, bid)
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        -- v5.7 (feedback): o background é GIGANTE — uma peça em escala COVER
        -- (máximo entre largura e a altura que alcança o topo do frame)
        -- preenchendo o céu inteiro com a arte do PNG (nada de céu chapado
        -- "fake" + sol duplicado de tiling). Nuvens/pássaros agora desenham
        -- POR CIMA dele (reordenado no draw). Só largura vazava o céu
        -- procedural em 4:3 (faixa roxa/listra no full3).
        local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)
        love.graphics.setColor(1, 1, 1, alpha)
        drawStripTiles(img, x, sx, yTop, tileW, off)
        -- v5.9.4 (feedback): strip inteiro espelhado verticalmente abaixo
        -- da última linha de arte — continuação de cabeça pra baixo
        drawStripMirrorBelow(img, x, sx, yTop, tileW, off, g.bottomY)
        return true
    end
    return false
end

local function drawMountains(g, x, w, camZ)
    -- crossfade na troca de bioma: NOVO por baixo a 100%, VELHO por cima
    -- esvaindo (1-t) — se o velho for mais alto, a sobra dele TAMBÉM esvai
    -- (na ordem antiga o céu baked do velho ficava como faixa fixa)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        local curOk = drawMountainsOf(g, x, w, camZ, rawBiome().id, 1)
        local prevOk = drawMountainsOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
        if prevOk or curOk then return end
    else
        if drawMountainsOf(g, x, w, camZ, rawBiome().id, 1) then return end
    end

    local img = getSprite("mountains", 0)
    if img then
        -- fallback genérico: mesma regra GIGANTE/cover do drawMountainsOf (v5.7)
        local iw, ih = img:getWidth(), img:getHeight()
        local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        drawStripTiles(img, x, sx, yTop, tileW, off)
    else
        -- fallback: 2 camadas de silhueta
        for layer = 1, 2 do
            local color = layer == 1 and envColor("hillsFar") or envColor("hillsNear")
            local par = layer == 1 and 1.2 or 2.6
            local amp = layer == 1 and 26 or 16
            local base = layer == 1 and 30 or 14
            love.graphics.setColor(color[1], color[2], color[3], 1)
            for sx = 0, w - 1, 4 do
                local i = (sx + camZ * par) * 0.05
                local hgt = base + (ridge(layer * 3.7, i) * 0.5 + 0.5) * amp
                love.graphics.rectangle("fill", x + sx, g.crestApexY - hgt, 4, hgt + 20)
            end
        end
    end
end

-- CAMADA FRONTAL das montanhas (v5.8): a silhueta extraída do próprio
-- strip (<bid>_mountains_front.png, céu transparente) redesenhada por cima
-- das nuvens com o MESMO transform — nuvem em movimento passa ATRÁS dos
-- picos sem stencil. Bioma sem PNG frontal (marsh) = sem oclusão.
local function drawMountainsFrontOf(g, x, w, camZ, bid, alpha)
    local img = getSprite("mountains_front", 0, bid)
    if _G.WR_DEBUG then print("[WR] frontOf bid=" .. tostring(bid) .. " a=" .. alpha .. " img=" .. tostring(img ~= nil and img ~= false)) end
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)
    if _G.WR_TINT then love.graphics.setColor(1, 0, 0, alpha)
    else love.graphics.setColor(1, 1, 1, alpha) end
    drawStripTiles(img, x, sx, yTop, tileW, off)
    return true
end

local function drawMountainsFront(g, x, w, camZ)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawMountainsFrontOf(g, x, w, camZ, rawBiome().id, 1)
        drawMountainsFrontOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
    else
        drawMountainsFrontOf(g, x, w, camZ, rawBiome().id, 1)
    end
end

-- Castelo-destino: atrás do domo, centro da crista, escala por progresso.
local function drawCastleOf(g, x, w, camZ, bid, alpha)
    local progress = (camZ % SEGMENT_LEN) / SEGMENT_LEN
    local img = getSprite("castle", 0, bid)
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    -- APROXIMAÇÃO (feedback v5): o castelo se aproxima de verdade — escala
    -- 1.0 → 4.2 ao longo do trecho (antes 1.0→2.5, "nem dava pra ver o
    -- portão"). Crescimento acelera no fim (progress^1.4): os últimos
    -- andares são a chegada dramática, portão dominante.
    -- v5.5: escala pelo MENOR entre largura e altura×1.5 — em tela larga o
    -- castelo escalado por w ficava gigante e cortado no topo
    local refW = math.min(w, g.h * 1.5)
    local baseScale = (refW * 0.155) / iw
    local s = baseScale * (1.0 + (progress ^ 1.4) * 3.2)
    local cx = g.cx
    -- afundamento DIMINUI chegando: no fim só 3% da altura fica atrás da
    -- crista — o PORTÃO (base do sprite) sobe e fica totalmente visível
    local baseY = g.crestYAt(cx) + ih * s * (0.03 + 0.20 * (1 - progress))
    -- PÁTIO de terra no pé do castelo (v5.4, feedback "castelo parece
    -- colado"): elipse na cor da estrada onde ela encontra o portão —
    -- o castelo assenta num terreno batido, não numa grama lisa
    if alpha >= 1 then
        local ra = envColor("roadA")
        local crest2 = g.crestYAt(cx)
        love.graphics.setColor(ra[1] * 0.92, ra[2] * 0.92, ra[3] * 0.92, 0.85)
        love.graphics.ellipse("fill", cx, crest2 + 2,
            iw * s * 0.34, 5 + 9 * progress)
        -- v6.3: sombra direcional do castelo (contra o sol do bioma)
        local shd = sunShadowDir(g, x, w, cx)
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.ellipse("fill", cx + shd * iw * s * 0.20
            + (shd == 0 and iw * s * 0.10 or 0), crest2 + 3,
            iw * s * 0.28, 4 + 7 * progress)
    end

    -- v6.3: RIM LIGHT — cópia aditiva na cor do astro deslocada 2px em
    -- direção ao sol POR BAIXO do sprite: sobra um contorno de luz de
    -- 1-2px na borda iluminada (rim barato, sem shader)
    local cel = (BIOME_BY_ID[bid] or rawBiome()).celestial
    if cel then
        local sunX = x + cel.xr * w
        local rdx = math.max(-1, math.min(1, (sunX - cx) / (w * 0.4)))
        local sc = cel.color
        love.graphics.setBlendMode("add")
        love.graphics.setColor(sc[1], sc[2], sc[3], 0.28 * alpha)
        love.graphics.draw(img, math.floor(cx - iw * s / 2 + rdx * 2),
            math.floor(baseY - ih * s - 1), 0, s, s)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(img, math.floor(cx - iw * s / 2),
        math.floor(baseY - ih * s), 0, s, s)

    -- v6.4: LUZ DAS JANELAS — glow aditivo quente pulsando sobre o corpo
    -- do castelo + um foco menor no portão (as janelas acesas do sprite
    -- ganham halo de verdade; intensidade por bioma)
    if alpha >= 1 then
        local gk = CASTLE_GLOW_K[bid] or 0.8
        local gi = glowTex()
        local pulse = 0.86 + 0.14 * math.sin(WorldRoad._time * 1.7)
        love.graphics.setBlendMode("add")
        local gw = iw * s * 1.25
        love.graphics.setColor(1.0, 0.72, 0.38, 0.11 * gk * pulse)
        love.graphics.draw(gi, cx - gw / 2, baseY - ih * s * 0.52 - gw / 2,
            0, gw / 128, gw / 128)
        local gw2 = iw * s * 0.55
        love.graphics.setColor(1.0, 0.62, 0.26, 0.18 * gk * pulse)
        love.graphics.draw(gi, cx - gw2 / 2, baseY - ih * s * 0.10 - gw2 / 2,
            0, gw2 / 128, gw2 / 128)
        love.graphics.setBlendMode("alpha")
    end

    -- topo do castelo (pra fumaça da chaminé) — só no passe principal
    if alpha >= 1 then
        WorldRoad._castleTop = {
            x = cx + iw * s * 0.18,           -- chaminé à direita do centro
            y = baseY - ih * s * 0.82,
            s = s,
            progress = progress,
        }
    end
    return true
end

local function drawCastle(g, x, w, camZ)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawCastleOf(g, x, w, camZ, rawBiome().id, 1)
        drawCastleOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
    else
        drawCastleOf(g, x, w, camZ, rawBiome().id, 1)
    end

    -- fumaça da chaminé (atrás do domo, junto com o castelo)
    -- v6.6: halo suave + núcleo pixel (quadrado chapado lia como protótipo)
    local gi = glowTex()
    for _, sp in ipairs(WorldRoad._smoke) do
        local a = math.min(1, sp.life / 1.4) * 0.30
        local d = sp.size * 2.6
        love.graphics.setColor(0.78, 0.75, 0.70, a * 0.55)
        love.graphics.draw(gi, sp.x - d / 2, sp.y - d / 2, 0, d / 128, d / 128)
        love.graphics.setColor(0.80, 0.77, 0.72, a)
        love.graphics.rectangle("fill", math.floor(sp.x - sp.size / 2),
            math.floor(sp.y - sp.size / 2), sp.size, sp.size)
    end
end

-- Inimigo emergindo de trás da curva (desenhado ANTES do preenchimento do
-- domo → o disco oculta o corpo; só a parte acima da crista aparece).
local function drawEncounterBehind(g, x, w, camZ)
    local e = WorldRoad._encounter
    if not e or not WorldRoad._travel then return end
    local rel = e.z - camZ
    if rel <= REL_CREST then return end          -- já cruzou: desenha na frente
    if rel > REL_CREST + EMERGE_BAND then return end

    -- 0 = acabou de aparecer (todo atrás), 1 = na crista
    local em = 1 - (rel - REL_CREST) / EMERGE_BAND
    local cx = g.cx + roadWobble(e.z, 0, w)
    local crest = g.crestYAt(cx)
    -- escala CONTÍNUA com o mundo: mesma persp-normalização do passe frontal
    -- em t=0 (antes era 0.5 fixo → o inimigo ENCOLHIA de repente ao cruzar a
    -- crista e ficava maior que árvore — quebrava a esfera)
    local tBattle = g.tOf(WorldRoad.BATTLE_REL) or 0.3
    local s = e.targetScale * (g.persp(0) / math.max(0.01, g.persp(tBattle)))
    -- pés afundados: sobe conforme emerge
    local feetY = crest + e.ih * s * (1 - em) * 0.95
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(e.img, math.floor(cx - e.iw * s / 2),
        math.floor(feetY - e.ih * s), 0, s, s)
end

-- PROPS EMERGINDO da curvatura (ciclo 23, feedback): árvores e itens na
-- faixa além da crista (REL_CREST..+EMERGE_BAND) desenham ANTES do fill do
-- domo, com a base afundada — o domo tampa a parte de baixo do corpo, igual
-- ao monstro. Antes eles simplesmente pipocavam ao cruzar a crista.
local function drawPropsBehind(g, x, w, camZ)
    -- durante o fork os marcos ocupam a faixa central — emersão pausa
    -- (câmera parada; ninguém percebe e nada nasce em cima dos marcos)
    if WorldRoad._fork then return end
    for _, p in ipairs(WorldRoad._props) do
        local rel = p.z - camZ
        if rel > REL_CREST and rel <= REL_CREST + EMERGE_BAND then
            local em = 1 - (rel - REL_CREST) / EMERGE_BAND
            -- mesma fórmula da cunha em t=0 → continuidade ao cruzar
            local pxX = g.cx + p.side * w * (0.11 + p.lane * 0.38)
            local crest = g.crestYAt(pxX)
            local img = getSprite(p.kind, p.variant, p.bid)
            -- ciclo 30/33: emersão SÓ na faixa central do horizonte. O
            -- clamp por crestYAt (c30) era raso demais — a curva dip é
            -- pequena perto do topo e árvores a 0.4w ainda emergiam nas
            -- laterais (domo pintava faixa de grama POR CIMA das copas,
            -- "sanduíche" com as árvores da frente). Critério certo:
            -- distância HORIZONTAL do centro, como o inimigo na estrada.
            if crest and img and math.abs(pxX - g.cx) < w * 0.26 then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = (KIND_SIZE[p.kind] or 1.0) * (p.big or 1)
                local s = g.scaleAt(size, 0, ih)
                local sink = (1 - em) * ih * s
                -- companheiras de cluster emergem junto (senão pipocam)
                if p.cluster then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cimg = getSprite(p.kind, (p.variant + ci) % 3, p.bid)
                        if cimg then
                            local cs = s * (0.5 + 0.13 * ci)
                            local ccrest = g.crestYAt(pxX + off) or crest
                            love.graphics.setColor(0.6, 0.6, 0.6, 1)
                            love.graphics.draw(cimg,
                                math.floor(pxX + off - cimg:getWidth() * cs / 2),
                                math.floor(ccrest + (1 - em) * cimg:getHeight() * cs
                                    - cimg:getHeight() * cs), 0, cs, cs)
                        end
                    end
                end
                love.graphics.setColor(0.66, 0.66, 0.66, 1)   -- distante/na sombra
                love.graphics.draw(img, math.floor(pxX - iw * s / 2),
                    math.floor(crest + sink - ih * s), 0, s, s)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- TEXTURA DO DOMO: tile seamless por bioma (clumps de 3 tons + pontinhos),
-- baked 1x e cacheada. Rola verticalmente com camZ = a terra GIRANDO.
-- ============================================================================
local GROUND_TEX_W, GROUND_TEX_H = 128, 96
local GROUND_TEX_SCALE = 5          -- px de tela por texel (chunky)
local GROUND_SCROLL = 11            -- px de rolagem por unidade de mundo

local groundTexCache = {}
local function getGroundTexture(bid)
    if groundTexCache[bid] then return groundTexCache[bid] end
    local b = BIOME_BY_ID[bid] or rawBiome()
    local tw, th = GROUND_TEX_W, GROUND_TEX_H
    local data = love.image.newImageData(tw, th)
    local rng = love.math.newRandomGenerator(#bid * 3313)
    local base = b.grassA
    local dark = b.grassB
    local light = { b.grassA[1] * 1.14, b.grassA[2] * 1.14, b.grassA[3] * 1.08 }
    -- base
    for yy = 0, th - 1 do
        for xx = 0, tw - 1 do
            data:setPixel(xx, yy, base[1], base[2], base[3], 1)
        end
    end
    -- V2: 4 tons + acento do bioma + clumps em OITAVAS (grande→pequeno) —
    -- randomização natural: manchas grandes definem regiões, médias quebram,
    -- pequenas dão grão; cores todas da MESMA família (se respeitam)
    local mid = { (base[1] + dark[1]) / 2, (base[2] + dark[2]) / 2, (base[3] + dark[3]) / 2 }
    local accent = b.accent or light
    local accentDim = { accent[1] * 0.55 + base[1] * 0.45,
                        accent[2] * 0.55 + base[2] * 0.45,
                        accent[3] * 0.55 + base[3] * 0.45 }
    local function clump(cx, cy, r, c, holes)
        for dy = -r, r do
            for dx = -r, r do
                if dx * dx + dy * dy <= r * r and rng:random() > (holes or 0.3) then
                    data:setPixel((cx + dx) % tw, (cy + dy) % th, c[1], c[2], c[3], 1)
                end
            end
        end
    end
    -- oitava 1: regiões grandes de tom médio (variação macro suave)
    for _ = 1, 7 do
        clump(rng:random(0, tw - 1), rng:random(0, th - 1), rng:random(9, 14), mid, 0.45)
    end
    -- oitava 2: manchas médias escuras/claras
    for _ = 1, 22 do
        clump(rng:random(0, tw - 1), rng:random(0, th - 1), rng:random(3, 7), dark)
    end
    for _ = 1, 16 do
        clump(rng:random(0, tw - 1), rng:random(0, th - 1), rng:random(2, 5), light)
    end
    -- oitava 3: grão fino
    for _ = 1, 150 do
        local c = rng:random() < 0.5 and dark or light
        data:setPixel(rng:random(0, tw - 1), rng:random(0, th - 1), c[1], c[2], c[3], 1)
    end
    -- acentos do bioma (florzinhas/cristais/brasas espalhados esparsos)
    -- v6.5: 9→16 (a referência tem flores pontuais espalhadas no gramado)
    for _ = 1, 16 do
        local ax, ay = rng:random(1, tw - 2), rng:random(1, th - 2)
        data:setPixel(ax, ay, accentDim[1], accentDim[2], accentDim[3], 1)
        if rng:random() < 0.5 then
            data:setPixel(ax + 1, ay, accentDim[1] * 1.15, accentDim[2] * 1.15, accentDim[3] * 1.1, 1)
        end
    end
    -- v6.5: LÂMINAS de capim — pares verticais claros de 2px (dão fio à
    -- grama; sem eles a textura é só manchas)
    for _ = 1, 26 do
        local bx2, by2 = rng:random(0, tw - 1), rng:random(1, th - 1)
        data:setPixel(bx2, by2,
            math.min(1, light[1] * 1.08), math.min(1, light[2] * 1.08), light[3], 1)
        data:setPixel(bx2, by2 - 1,
            math.min(1, light[1] * 1.16), math.min(1, light[2] * 1.16),
            math.min(1, light[3] * 1.05), 1)
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    groundTexCache[bid] = { img = img, quad = love.graphics.newQuad(0, 0, 1, 1, tw, th) }
    return groundTexCache[bid]
end

-- Preenchimento do DOMO em MODO-7 REAL: linhas horizontais respeitando o
-- círculo (largura de cada linha = corda do círculo naquele y), com TEXELS
-- CRESCENDO conforme se aproximam (profundidade de verdade — antes a textura
-- era escala única e parecia adesivo plano) e V mapeado pela MESMA curva de
-- profundidade dos props (rola coerente com tudo).
-- ⚠️ SEM love.graphics.stencil: a versão com stencil CRASHAVA o driver
-- NVIDIA (0xC00000FD em nvoglv64) e envenenava o OpenGL da máquina inteira.
local GROUND_V_DENSITY = 4.8   -- texels de textura por unidade de mundo
-- Textura do domo em FATIAS DE LATITUDE (igual à estrada): cada linha de
-- profundidade é dividida em segmentos que deitam no arco REAL da esfera —
-- as fileiras do padrão CURVAM pra baixo nas bordas como a crista. Antes as
-- linhas eram horizontais retas e contradiziam o arco da estrada (era o
-- resto da "curvatura contrária" que sobrava no campo próximo).
local function drawDomeTexOf(g, x, w, bid, alpha)
    local tex = getGroundTexture(bid)
    love.graphics.setColor(1, 1, 1, alpha)
    local domeTop = g.crestApexY
    local H = g.bottomY - domeTop
    local step = 3
    for sy = 0, H - 1, step do
        local t = sy / H
        local tn = math.min(1, (sy + step) / H)
        local rel = REL_CREST * (1 - t ^ (1 / T_POW))
        local relNext = REL_CREST * (1 - tn ^ (1 / T_POW))
        local worldZ = WorldRoad._camZ + rel
        local dv = math.min(20, math.max(0.05, (rel - relNext) * GROUND_V_DENSITY))
        local v = (worldZ * GROUND_V_DENSITY) % GROUND_TEX_H
        local hs = GROUND_TEX_SCALE * (0.44 + 1.06 * t)
        -- v5.6: SEG adaptativo — perto da CRISTA (t<0.3), onde a borda da
        -- esfera é visível, fatias de 8px (curva lisa); no corpo, 32px.
        -- Fatias de 32px na borda viravam "retângulos" (feedback: "não é
        -- um círculo perfeito, tem partes retas").
        local SEG = (t < 0.3) and 8 or 32
        for segX = x, x + w - 1, SEG do
            local segW = math.min(SEG, x + w - segX)
            local dxMid = (segX + segW / 2) - g.cx
            local segY = g.latY(dxMid, t)
            if segY < g.bottomY + 30 then
                tex.quad:setViewport((segX - g.cx) / hs, v, segW / hs, dv,
                    GROUND_TEX_W, GROUND_TEX_H)
                love.graphics.draw(tex.img, tex.quad, segX, math.floor(segY), 0,
                    hs, (step + 1) / dv)
            end
        end
    end
end

local function drawDome(g, x, y, w)
    local grassA = envColor("grassA")
    local grassB = envColor("grassB")

    -- fundo chapado (segura o blend de cor por baixo da textura).
    -- ciclo 35: ESCURO (grassB×0.78), não grassA — as fatias de textura
    -- assentam na latitude do CENTRO do segmento e perto da borda lateral
    -- o degrau expõe o círculo-base em escadinha; claro, virava um ARO DE
    -- BRILHO contornando a esfera inteira ("o brilho lá da borda, o final
    -- da esfera", visível em todos os biomas). Escuro, vira sombra de
    -- borda — natural numa esfera.
    love.graphics.setColor(grassB[1] * 0.78, grassB[2] * 0.78, grassB[3] * 0.78, 1)
    love.graphics.circle("fill", g.cx, g.crestApexY + g.R, g.R, 256)

    -- textura rolando (crossfade entre biomas durante o blend)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawDomeTexOf(g, x, w, rawBiome(WorldRoad._prevBiomeIndex).id, 1)
        drawDomeTexOf(g, x, w, rawBiome().id, t)
    else
        drawDomeTexOf(g, x, w, rawBiome().id, 1)
    end

    -- SOMBRAS DE NUVEM: REMOVIDAS (ciclo 26) — as elipses deslizando no
    -- gramado liam como "bolas sem sentido" e, quando passavam sob uma
    -- árvore, como sombra flutuante descolada dela. Nuvem de background
    -- distante não projeta sombra no chão do primeiro plano.

    -- v6.5: FAIXA DE LUZ na crista — o alto do morro pega o sol; a luz
    -- morre descendo pro primeiro plano. Segue a CURVA da crista (colunas)
    -- e usa gradiente por textura (sem banding). Aditiva e bem sutil.
    do
        local gv = gradTex()
        local bandH2 = (g.bottomY - g.crestApexY) * 0.30
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 0.95, 0.80, 0.06)
        for sxx = 0, w - 1, 6 do
            local cyv = g.crestYAt(x + sxx)
            if cyv < g.bottomY then
                love.graphics.draw(gv, x + sxx, cyv + 1, 0, 6, bandH2 / 256)
            end
        end
        love.graphics.setBlendMode("alpha")
    end

    -- v5.6: TAMPA LISA da silhueta — arco exato do círculo por cima da
    -- borda da textura (as fatias escadinham; o arco esconde os degraus
    -- com uma curva contínua na cor do topo do domo). Largura total.
    do
        local phiEdge = math.asin(math.min(1, (w / 2) / g.R))
        love.graphics.setColor(grassA[1], grassA[2], grassA[3], 1)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", "open", g.cx, g.crestApexY + g.R, g.R - 1,
            -math.pi / 2 - phiEdge, -math.pi / 2 + phiEdge, 256)
        love.graphics.setLineWidth(1)
    end

    -- luz sutil da crista (banda clara fina na curva — SEM pontinhos).
    -- ciclo 32: era circle() COMPLETO — o arco descia pelas laterais POR
    -- CIMA das árvores da treeline ("a corzinha da borda aplicada nas
    -- árvores à frente"). Agora é ARCO limitado à faixa central do
    -- horizonte (regra do ciclo 30: lateral é borda do mundo, não crista)
    local bandH = (g.bottomY - g.crestApexY) * 0.22
    local phiMax = math.acos(math.max(-1, 1 - bandH / g.R))
    -- ciclo 33: teto horizontal (curva rasa → o arco por altura alcançava
    -- ~0.54w e ainda tocava as árvores laterais)
    phiMax = math.min(phiMax, math.asin(math.min(1, w * 0.26 / g.R)))
    love.graphics.setColor(grassA[1] * 1.16, grassA[2] * 1.16, grassA[3] * 1.10, 0.85)
    love.graphics.setLineWidth(4)
    love.graphics.arc("line", "open", g.cx, g.crestApexY + g.R, g.R - 2,
        -math.pi / 2 - phiMax, -math.pi / 2 + phiMax)
    love.graphics.setLineWidth(1)
end

-- TREELINE DA CRISTA (referência print 1): fileira de silhuetas de árvore
-- sentadas NA curva do horizonte, emoldurando o mundo. Estáticas (anel
-- "infinitamente longe" do planeta). Pula a zona da estrada e do castelo.
local function drawCrestTreeline(g, x, w)
    local b = rawBiome()
    local roadGapHalf = ROAD_HALF * w * 0.06 + 26
    local castleGapHalf = w * 0.11
    for i = 0, math.floor(w / 58) do
        local sx = x + i * 58 + (i % 3) * 14
        local dx = math.abs(sx - g.cx)
        if dx > roadGapHalf and dx > castleGapHalf then
            local cy = g.crestYAt(sx)
            if cy < g.bottomY - 40 then
                local kind = (i % 4 == 0) and "tree" or "pine"
                local img = getSprite(kind, i % 3, b.id)
                if img then
                    local iw, ih = img:getWidth(), img:getHeight()
                    local s = g.scaleAt(KIND_SIZE[kind] * 0.62, 0.14, ih)
                    love.graphics.setColor(0.72, 0.72, 0.72, 1)   -- levemente na sombra
                    love.graphics.draw(img, math.floor(sx - iw * s / 2),
                        math.floor(cy - ih * s + 3), 0, s, s)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Tile DEDICADO de terra (PixelLab, ciclo 10): base texturizada da estrada.
-- road_dirt_<bid>.png > road_dirt.png > nil (fallback: cores chapadas).
local roadTileCache = {}
local function getRoadTile(bid)
    local hit = roadTileCache[bid]
    if hit ~= nil then return hit or nil end
    local img = tryLoadPng("road_dirt_" .. bid) or tryLoadPng("road_dirt")
    if img then
        img:setWrap("repeat", "repeat")
        roadTileCache[bid] = img
    else
        roadTileCache[bid] = false
    end
    return img
end
local RD_V_DENSITY = 5.2   -- texels por unidade de mundo (rolagem da terra)

-- ============================================================================
-- FORK — A ENCRUZILHADA (v5): a estrada se bifurca em 2-3 braços e cada
-- braço tem um MARCO (landmark PixelLab) dizendo o que o caminho é.
-- Substitui o MapScreen quando estamos na estrada. Contrato: showFork(nodes,
-- onChosen) → clique num braço → convergência (braço vira a estrada central
-- enquanto a câmera avança) → onChosen(node, index).
-- ============================================================================
local FORK_REL    = 10    -- onde a estrada se divide
local MARK_REL    = 17.5  -- onde os marcos ficam
local ARRIVE_REL  = 7.5   -- rel do marco ao fim da convergência (chegada)
local FORK_SPREAD = 0.15  -- afastamento lateral máximo por direção (fração de w)

function WorldRoad.showFork(nodes, onChosen)
    if not nodes or #nodes == 0 then return false end
    -- nova encruzilhada = deixamos o lugar anterior pra trás (feedback:
    -- "depois que seleciona, a opção continua aparecendo na tela")
    WorldRoad._landmark = nil
    local n = math.min(3, #nodes)
    local dirs = (n == 1) and { 0 } or (n == 2) and { -1, 1 } or { -1, 0, 1 }
    WorldRoad._fork = {
        nodes = nodes, n = n, dirs = dirs,
        animIn = 0, hover = nil, chosen = nil, converge = nil,
        onChosen = onChosen,
        markZ = WorldRoad._camZ + MARK_REL,
        markBoxes = {},
    }
    return true
end

function WorldRoad.isForkActive()
    return WorldRoad._fork ~= nil
end

-- offset lateral (px) do braço i na profundidade rel
local function forkOffset(f, i, rel, w)
    local k = (rel - FORK_REL) / (MARK_REL - FORK_REL)
    k = math.min(1, math.max(0, k))
    k = k * k * (3 - 2 * k)                     -- smoothstep
    local off = f.dirs[i] * FORK_SPREAD * w * k * f.animIn
    if f.converge then
        local c = f.converge.k or 0
        if i == f.chosen then off = off * (1 - c)       -- escolhido → centro
        else off = off * (1 + c * 2.5) end              -- outros → cone
    end
    return off
end

-- alpha do braço i (não escolhidos somem durante a convergência)
local function forkAlpha(f, i)
    if not f.converge or i == f.chosen then return 1 end
    return math.max(0, 1 - (f.converge.k or 0) * 1.6)
end

function WorldRoad.forkHitTest(mx, my)
    local f = WorldRoad._fork
    if not f then return nil end
    for i = 1, f.n do
        local b = f.markBoxes[i]
        if b and mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2 then
            return i
        end
    end
    return nil
end

function WorldRoad.forkMousePressed(mx, my)
    local f = WorldRoad._fork
    if not f then return false end
    if f.converge then return true end          -- consome, mas ignora
    local i = WorldRoad.forkHitTest(mx, my)
    if i then
        f.chosen = i
        f.hover = i
        f.converge = { t = 0, k = 0, duration = 2.4,
                       z0 = WorldRoad._camZ, dist = MARK_REL - ARRIVE_REL }
        Sfx.play("cardSelect")
        local node = f.nodes[i]
        if node then
            local key = LANDMARK_FOR_TYPE[tostring(node.type)]
            local img = key and getLandmark(key)
            if img then
                -- juice visual: o marco "responde" à escolha
                f.chosenPulse = 0.35
            end
        end
    end
    return true                                  -- fork ativo consome cliques
end

-- Estrada de terra: faixa do castelo (crista) até a base — tile rolando em
-- modo-7 (quando existe) + manchas orgânicas + sulcos + pedrinhas + bordas.
-- v5: quando o fork está ativo, fileiras além de FORK_REL pintam UMA VEZ POR
-- BRAÇO (centro deslocado + largura menor) — a estrada literalmente se abre.
local function drawRoad(g, x, w, camZ)
    local roadA = envColor("roadA")
    local roadB = envColor("roadB")
    local roadEdge = envColor("roadEdge")
    local cx = g.cx
    local crest = g.crestYAt(cx)
    local groundH = g.bottomY - crest
    local fork = WorldRoad._fork

    local step = 2
    local function hash(n)
        local v = math.sin(n * 12.9898) * 43758.5453
        return v - math.floor(v)
    end
    local lastDecoRow = nil   -- ciclo 29: decoração pontual 1x por faixa
    for sy = 0, groundH - 1, step do
        local t = sy / groundH
        local rel = REL_CREST * (1 - t ^ (1 / T_POW))
        local worldZ = camZ + rel

        local half0 = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
        local edgeAmp = 5 * (0.30 + 0.70 * t)
        local eL = (math.sin(worldZ * 0.55) * 0.6 + math.sin(worldZ * 0.21 + 1.4) * 0.4) * edgeAmp
        local eR = (math.sin(worldZ * 0.47 + 3.1) * 0.6 + math.sin(worldZ * 0.17 + 4.2) * 0.4) * edgeAmp
        local rowId = math.floor(worldZ * 2.3)
        local blend = hash(math.floor(worldZ / 1.9) * 3 + math.floor(t * 5))
        local m = 0.92 + hash(rowId) * 0.10
        local tile = getRoadTile(rawBiome().id)
        local tw, th, dv, v, hs, uOff
        if tile then
            tw, th = tile:getWidth(), tile:getHeight()
            if not WorldRoad._roadQuad or WorldRoad._roadQuadTh ~= th then
                WorldRoad._roadQuad = love.graphics.newQuad(0, 0, 1, 1, tw, th)
                WorldRoad._roadQuadTh = th
            end
            local tn2 = math.min(1, (sy + step) / groundH)
            local relN = REL_CREST * (1 - tn2 ^ (1 / T_POW))
            dv = math.min(16, math.max(0.05, (rel - relN) * RD_V_DENSITY))
            v = (worldZ * RD_V_DENSITY) % th
            hs = 4.4 * (0.35 + 0.65 * t)
            uOff = hash(math.floor(worldZ / 2.5) * 13) * tw
        end
        local newRow = rowId ~= lastDecoRow
        if newRow then lastDecoRow = rowId end

        -- pinta UMA fileira da estrada com centro/largura/alpha/brilho dados
        local function paintRow(cxRow, halfMul, aMul, decorate, bright)
            local half = half0 * halfMul
            -- BORDA SERRADA (ref APK do usuário): degraus irregulares por
            -- faixa de mundo (rowId) — tijolos "saltando" da borda em
            -- escadinha, não linha lisa. É isso que faz parecer caminho real.
            local jag = 14 * (0.35 + 0.65 * t)
            local jL = (hash(rowId * 13 + 7) - 0.5) * jag
            local jR = (hash(rowId * 19 + 3) - 0.5) * jag
            local xL = math.floor(cxRow - half + eL + jL)
            local xR = math.floor(cxRow + half + eR + jR)

            local SEG = 16
            for segX = xL, xR - 1, SEG do
                local segW = math.min(SEG, xR - segX)
                local dxMid = (segX + segW / 2) - cx
                local segY = math.floor(g.latY(dxMid, t))
                if tile then
                    WorldRoad._roadQuad:setViewport((segX - cx) / hs + uOff, v,
                        segW / hs, dv, tw, th)
                    local tm = (0.9 + blend * 0.16) * bright
                    love.graphics.setColor(tm, tm, tm, aMul)
                    -- ciclo 31: overdraw de 1.5px (mata fresta entre latitudes)
                    love.graphics.draw(tile, WorldRoad._roadQuad, segX, segY, 0,
                        hs, (step + 1.5) / dv)
                else
                    love.graphics.setColor(
                        (roadA[1] + (roadB[1] - roadA[1]) * blend) * m * bright,
                        (roadA[2] + (roadB[2] - roadA[2]) * blend) * m * bright,
                        (roadA[3] + (roadB[3] - roadA[3]) * blend) * m * bright, aMul)
                    love.graphics.rectangle("fill", segX, segY, segW, step + 1.5)
                end
            end

            if not decorate then return end

            -- pedrinhas/torrões (ciclo 29: 1x por rowId)
            if newRow then
                for k = 1, 2 do
                    local hpos = hash(rowId * 31 + k * 17)
                    if hpos > 0.35 then
                        local px2 = xL + math.floor(hpos * (xR - xL))
                        local sz = math.max(2, math.floor((1 + hash(rowId + k) * 2) * (0.4 + 0.6 * t) * 2))
                        if hash(rowId * 3 + k) > 0.5 then
                            love.graphics.setColor(roadEdge[1], roadEdge[2], roadEdge[3], 0.5 * aMul)
                        else
                            love.graphics.setColor(roadA[1] * 1.2, roadA[2] * 1.2, roadA[3] * 1.15, 0.6 * aMul)
                        end
                        love.graphics.rectangle("fill", px2,
                            math.floor(g.latY(px2 - cx, t)), sz, sz)
                    end
                end
            end

            -- SULCOS de desgaste (na latitude)
            if t > 0.45 then
                local rutA = (t - 0.45) * 0.5
                local rutW = math.max(1, math.floor(2 * g.persp(t)))
                love.graphics.setColor(roadEdge[1], roadEdge[2], roadEdge[3], rutA * 0.5 * aMul)
                local rdx = half * 0.42
                love.graphics.rectangle("fill", math.floor(cxRow - rdx),
                    math.floor(g.latY(cxRow - rdx - cx, t)), rutW, step)
                love.graphics.rectangle("fill", math.floor(cxRow + rdx),
                    math.floor(g.latY(cxRow + rdx - cx, t)), rutW, step)
            end

            -- bordas quebradas + pedrinha da transição
            local yL = math.floor(g.latY(xL - cx, t))
            local yR = math.floor(g.latY(xR - cx, t))
            if hash(rowId * 5 + 2) > 0.25 then
                love.graphics.setColor(roadEdge[1], roadEdge[2], roadEdge[3], 0.85 * aMul)
                love.graphics.rectangle("fill", xL - 2, yL, 2, step)
            end
            if hash(rowId * 11 + 4) > 0.25 then
                love.graphics.setColor(roadEdge[1], roadEdge[2], roadEdge[3], 0.85 * aMul)
                love.graphics.rectangle("fill", xR, yR, 2, step)
            end
            if newRow and hash(rowId * 17 + 9) > 0.72 then
                local ps = math.max(2, math.floor(3.5 * g.persp(t)))
                local side = hash(rowId * 23 + 3) > 0.5 and 1 or -1
                local px2 = side > 0 and (xR + 3 + math.floor(hash(rowId * 29) * 8 * g.persp(t)))
                                      or (xL - 5 - math.floor(hash(rowId * 29) * 8 * g.persp(t)))
                love.graphics.setColor(roadA[1] * 1.25, roadA[2] * 1.22, roadA[3] * 1.15, 0.9 * aMul)
                love.graphics.rectangle("fill", px2, math.floor(g.latY(px2 - cx, t)), ps, math.max(step, ps - 1))
            end

            -- v6.5: DITHER de transição terra↔grama — salpicos dos dois
            -- lados da borda (denso perto, esparso longe). A emenda vira
            -- meio-tom orgânico em vez de linha serrada dura.
            if newRow then
                local ga2 = envColor("grassA")
                for k = 1, 3 do
                    local hh = hash(rowId * 53 + k * 7)
                    local dd = math.floor(hh * hh * 12 * g.persp(t)) + 2
                    local sz2 = math.max(1, math.floor(2 * g.persp(t)))
                    local sideK = (hash(rowId * 59 + k) > 0.5) and 1 or -1
                    -- terra salpicada na grama (fora da borda)
                    local bx = sideK > 0 and (xR + dd) or (xL - dd - sz2)
                    love.graphics.setColor(roadA[1], roadA[2], roadA[3],
                        (1 - hh * 0.6) * 0.5 * aMul)
                    love.graphics.rectangle("fill", bx,
                        math.floor(g.latY(bx - cx, t)), sz2, sz2)
                    -- grama salpicada na terra (dentro da borda)
                    local gx2 = sideK > 0 and (xR - 2 - dd) or (xL + dd)
                    if gx2 > xL + 2 and gx2 < xR - 2 - sz2 then
                        love.graphics.setColor(ga2[1], ga2[2], ga2[3], 0.32 * aMul)
                        love.graphics.rectangle("fill", gx2,
                            math.floor(g.latY(gx2 - cx, t)), sz2, sz2)
                    end
                end
            end

            -- GRAMA INVADINDO a estrada (v5.4, feedback): fiapos verdes
            -- entrando pelas bordas — transição orgânica terra↔gramado
            if newRow and hash(rowId * 41 + 5) > 0.45 then
                local ga = envColor("grassA")
                local gs = hash(rowId * 43 + 1) > 0.5 and 1 or -1
                local gx = gs > 0 and (xR - 2 - math.floor(hash(rowId * 47) * 6))
                                   or (xL + math.floor(hash(rowId * 47) * 6))
                local gy = math.floor(g.latY(gx - cx, t))
                local gsz = math.max(1, math.floor(2 * g.persp(t)))
                love.graphics.setColor(ga[1] * 1.3, ga[2] * 1.3, ga[3] * 1.15, 0.85 * aMul)
                love.graphics.rectangle("fill", gx, gy, gsz + 1, gsz)
                love.graphics.rectangle("fill", gx + gs, gy - gsz, gsz, gsz)
            end
        end

        -- MEANDRO ORGÂNICO: centro serpenteia (roadWobble compartilhado
        -- com TODAS as âncoras — inimigo, marcos, chegada seguem a curva)
        local wob = roadWobble(worldZ, t, w)

        if fork and rel > FORK_REL then
            -- largura do braço COMEÇA em 100% no ponto do fork e afina
            -- conforme os braços se separam (fix: "quebra fininha" na junção)
            local kk = (rel - FORK_REL) / (MARK_REL - FORK_REL)
            kk = math.min(1, math.max(0, kk))
            kk = kk * kk * (3 - 2 * kk)
            local hm = (fork.n > 1) and (1 - 0.22 * kk) or 1
            for i = 1, fork.n do
                local aMul = forkAlpha(fork, i)
                if aMul > 0.02 then
                    local bright = (fork.hover == i and not fork.converge) and 1.14 or 1
                    paintRow(cx + wob * 0.5 + forkOffset(fork, i, rel, w),
                        hm, aMul, i == 1, bright)
                end
            end
        else
            paintRow(cx + wob, 1, 1, true, 1)
        end
    end
end

-- Marcos do fork: sprites na boca de cada braço + pill com nome (hover:
-- glow + descrição). Boxes de hit são registradas aqui (frame-fresh).
local function drawForkMarks(g, x, w, camZ)
    local f = WorldRoad._fork
    if not f then return end
    local FontManager = require("src.ui.FontManager")
    for i = 1, f.n do
        local node = f.nodes[i]
        local key = node and LANDMARK_FOR_TYPE[tostring(node.type)] or "landmark_battle"
        local img = getLandmark(key or "landmark_battle")
        local rel = f.markZ - camZ
        local t = g.tOf(rel)
        local aMul = forkAlpha(f, i)
        if img and t and aMul > 0.02 then
            local offX = forkOffset(f, i, rel, w)
                + roadWobble(camZ + rel, t, w) * 0.5
            local px = g.cx + offX
            local py = g.latY(offX, t)
            local iw, ih = img:getWidth(), img:getHeight()
            local size = LANDMARK_SIZE[key] or 2.0
            local s = g.scaleAt(size, t, ih)
            -- entrada: cresce com animIn; escolha: pulso
            s = s * (0.7 + 0.3 * f.animIn)
            if f.chosen == i and f.chosenPulse and f.chosenPulse > 0 then
                s = s * (1 + f.chosenPulse * 0.25)
            end
            local hovered = (f.hover == i and not f.converge)

            -- glow no chão sob o marco (hover: mais forte, na cor do bioma)
            local acc = rawBiome().accent or { 0.9, 0.75, 0.4 }
            love.graphics.setColor(acc[1], acc[2], acc[3],
                (hovered and 0.30 or 0.12) * aMul)
            love.graphics.ellipse("fill", px, py, iw * s * 0.7, 7 * g.persp(t) + 3)
            -- sombra (v6.3: direcional contra o sol)
            love.graphics.setColor(0, 0, 0, 0.22 * aMul)
            love.graphics.ellipse("fill",
                px + sunShadowDir(g, x, w, px) * iw * s * 0.14,
                py - 1, iw * s * 0.30, math.max(2, 4 * g.persp(t)))

            local bob = hovered and math.sin(WorldRoad._time * 4) * 2 or 0
            local br = hovered and 1.12 or 1
            love.graphics.setColor(br, br, br, aMul)
            love.graphics.draw(img, math.floor(px - iw * s / 2),
                math.floor(py - ih * s + bob), 0, s, s)

            -- hitbox generosa (marco + respiro)
            local grow = 14
            f.markBoxes[i] = {
                x1 = px - iw * s / 2 - grow, y1 = py - ih * s - grow - 16,
                x2 = px + iw * s / 2 + grow, y2 = py + grow,
            }

            -- PILL com o nome (sempre); hover adiciona a descrição
            if not f.converge then
                local label = (node and node.label) or "?"
                local font = FontManager.getFont(13)
                love.graphics.setFont(font)
                local tw2 = font:getWidth(label)
                local pw, ph = tw2 + 16, 20
                local pxc = px - pw / 2
                local pyc = py - ih * s - 26 + bob
                love.graphics.setColor(0.09, 0.07, 0.05, 0.88 * aMul)
                love.graphics.rectangle("fill", pxc, pyc, pw, ph, 6, 6)
                love.graphics.setColor(0.55, 0.44, 0.24, 0.9 * aMul)
                love.graphics.rectangle("line", pxc, pyc, pw, ph, 6, 6)
                love.graphics.setColor(0.92, 0.82, 0.58, aMul)
                love.graphics.print(label, math.floor(pxc + 8), math.floor(pyc + 3))
                if hovered and node and node.desc then
                    local font2 = FontManager.getFont(11)
                    love.graphics.setFont(font2)
                    local dw = font2:getWidth(node.desc)
                    local dx2 = px - dw / 2 - 8
                    local dy2 = pyc - 22
                    love.graphics.setColor(0.09, 0.07, 0.05, 0.82 * aMul)
                    love.graphics.rectangle("fill", dx2, dy2, dw + 16, 18, 5, 5)
                    love.graphics.setColor(0.85, 0.78, 0.62, aMul)
                    love.graphics.print(node.desc, math.floor(dx2 + 8), math.floor(dy2 + 3))
                end
            end
        else
            f.markBoxes[i] = nil
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Marco "onde chegamos" (pós-convergência): fica plantado no centro da
-- estrada e desliza naturalmente quando a próxima viagem acontecer.
local function drawLandmarkFront(g, x, w, camZ)
    local lm = WorldRoad._landmark
    if not lm then return end
    local rel = lm.z - camZ
    if rel < -3 then WorldRoad._landmark = nil; return end
    local t = g.tOf(rel)
    if not t then return end
    local img = getLandmark(lm.key)
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local s = g.scaleAt(lm.size or 2.0, t, ih)
    local py = g.crestApexY + (g.bottomY - g.crestApexY) * t
    local lx = g.cx + roadWobble(lm.z, t, w)   -- segue a curva da estrada
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.ellipse("fill",
        lx + sunShadowDir(g, x, w, lx) * iw * s * 0.14,
        py - 1, iw * s * 0.30, math.max(2, 4 * g.persp(t)))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(lx - iw * s / 2), math.floor(py - ih * s), 0, s, s)
end

-- Props do lado de cá da crista (crescem descendo o domo)
-- Névoa atmosférica na crista (pesquisa: perspectiva atmosférica — o longe
-- perde contraste e puxa pra cor do céu). Banda fina seguindo a CURVA.
local function drawCrestFog(g, x, w)
    local fog = envColor("fog")
    -- ciclo 28: névoa SÓ na faixa do horizonte (topo da crista). A curva
    -- da crista desce até os cantos da tela, e a névoa seguindo ela pintava
    -- a "borda do mundo" POR CIMA das árvores laterais (feedback dusk)
    local fogLimitY = g.crestApexY + (g.bottomY - g.crestApexY) * 0.22
    local gv = gradTex()
    local halfW = w * 0.30
    for sx = 0, w - 1, 6 do
        local cy = g.crestYAt(x + sx)
        -- ciclo 33: também limita HORIZONTAL (a curva é rasa no topo e o
        -- clamp por altura sozinho deixava a névoa alcançar ~0.6w)
        local dx = math.abs((x + sx) - g.cx)
        if cy < fogLimitY and dx < halfW then
            -- v6.1: gradiente por textura + fade horizontal suave (o corte
            -- seco em 0.30w era um degrau vertical visível)
            local fade = 1 - (dx / halfW) ^ 2
            love.graphics.setColor(fog[1], fog[2], fog[3],
                (fog[4] or 0.5) * 0.42 * fade)
            love.graphics.draw(gv, x + sx, cy, 0, 6, 16 / 256)
        end
    end
end

local function drawProps(g, x, w, camZ)
    table.sort(WorldRoad._props, function(a, c) return a.z > c.z end)

    -- passe 1: props DISTANTES (t < 0.25) — depois recebem a névoa por cima
    -- passe 2: névoa da crista
    -- passe 3: props do meio/perto — nítidos, na frente da névoa
    local farPass = {}
    local nearPass = {}
    for _, p in ipairs(WorldRoad._props) do
        local rel0 = p.z - camZ
        local t0 = g.tOf(rel0)
        if t0 and t0 < 0.25 then farPass[#farPass + 1] = p
        else nearPass[#nearPass + 1] = p end
    end

    local function drawList(list)
    for _, p in ipairs(list) do
        local rel = p.z - camZ
        local t = g.tOf(rel)
        if t and t >= 0 then
            -- CUNHA (ciclo 21, ref APK): zona permitida = triângulo que vai
            -- da lateral do castelo (crista) até o CANTO de baixo da tela.
            -- inner cresce com t → na base só os cantos extremos têm props;
            -- o corredor central da estrada fica sempre limpo.
            -- ciclo 24: funil mais fechado (0.13+0.44t → 0.11+0.38t)
            -- ciclo 25: SAÍDA REAL — depois de passar por você (rel<0) o
            -- prop desliza pra fora pelo canto (acelera pra fora e pra
            -- baixo) em vez de sumir de repente com meia copa na tela
            local over = math.max(0, -rel)
            local inner = 0.11 + 0.38 * t + over * 0.16
            local lateral = p.side * w * (inner + p.lane * 0.38)
            local pxX = g.cx + lateral
            -- Y pela LATITUDE real da esfera (não lerp pro fundo plano)
            local sy = g.latY(pxX - g.cx, t) + over * g.h * 0.20

            local img = getSprite(p.kind, p.variant, p.bid)

            -- CORREDOR DO FORK (feedback: "árvores não podem ocupar os
            -- caminhos"): com a estrada bifurcada, props que caem sobre
            -- QUALQUER braço somem enquanto o fork existe
            if img and WorldRoad._fork and rel > FORK_REL - 1.5 then
                local f2 = WorldRoad._fork
                local halfCorr = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
                    * (f2.n > 1 and 0.78 or 1)
                for bi = 1, f2.n do
                    local bc = g.cx + forkOffset(f2, bi, rel, w)
                    if math.abs(pxX - bc) < halfCorr + w * 0.045 then
                        img = nil
                        break
                    end
                end
            end

            if img then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = (KIND_SIZE[p.kind] or 1.0) * (p.big or 1)
                local s = g.scaleAt(size, t, ih)

                -- CLUSTER natural (feedback: "muito solto"): árvores vêm em
                -- grupos de 2-3, companheiras menores atrás/ao lado — como
                -- vegetação de verdade, não pontos isolados
                if p.cluster and (p.kind == "tree" or p.kind == "pine"
                                  or p.kind == "deadtree" or p.kind == "bush") then
                    -- ciclo 19: offsets antigos (±0.55-0.62×iw, escala ~igual)
                    -- empilhavam 3 árvores no mesmo pixel — agora cada
                    -- companheira afasta ~1 largura pro seu lado, é bem menor
                    -- e apoia no chão da PRÓPRIA latitude (com sombra)
                    for ci = 1, p.cluster do
                        -- só pra FORA (p.side): offset ± deixava a companheira
                        -- interna invadir a estrada (árvore no meio do caminho)
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cx2 = pxX + off
                        local cy2 = g.latY(cx2 - g.cx, t)
                        local cs = s * (0.5 + 0.13 * ci)
                        local cvar = (p.variant + ci) % 3
                        local cimg = getSprite(p.kind, cvar, p.bid)
                        if cimg then
                            love.graphics.setColor(0, 0, 0, 0.16)
                            love.graphics.ellipse("fill",
                                cx2 + sunShadowDir(g, x, w, cx2)
                                    * cimg:getWidth() * cs * 0.16,
                                cy2 - 1,
                                cimg:getWidth() * cs * 0.24,
                                math.max(2, 4 * g.persp(t)))
                            love.graphics.setColor(0.88, 0.88, 0.88, 1)
                            love.graphics.draw(cimg,
                                math.floor(cx2 - cimg:getWidth() * cs / 2),
                                math.floor(cy2 - cimg:getHeight() * cs
                                    + cimg:getHeight() * cs * 0.04),
                                0, cs, cs)
                        end
                    end
                end

                -- CERCA = LINHA de 3 segmentos ao longo da estrada (cerca
                -- solitária "jogada no nada" não existe no mundo real)
                if p.kind == "fence" then
                    -- ciclo 20: espaçamento 0.85→1.7 (em t médio os segmentos
                    -- comprimiam num bolo — "cercas todas juntas"); de longe
                    -- (t<0.35) nem desenha os extras, só o segmento principal
                    for fi = 1, (t >= 0.35 and 2 or 0) do
                        local fz = p.z + fi * 1.7
                        local ft = g.tOf(fz - camZ)
                        if ft and ft >= 0 then
                            local flat = p.side * w
                                * ((0.11 + 0.38 * ft) + p.lane * 0.38)
                            local fx = g.cx + flat
                            local fy = g.latY(fx - g.cx, ft)
                            local fs = g.scaleAt((KIND_SIZE.fence or 1) * (p.big or 1), ft, ih)
                            love.graphics.setColor(0, 0, 0, 0.18)
                            love.graphics.ellipse("fill",
                                fx + sunShadowDir(g, x, w, fx) * iw * fs * 0.14,
                                fy - 1, iw * fs * 0.3, 3)
                            love.graphics.setColor(0.94, 0.94, 0.94, 1)
                            love.graphics.draw(img, math.floor(fx), math.floor(fy),
                                0, fs, fs, iw / 2, ih)
                        end
                    end
                end

                -- SOMBRA elíptica sob o prop (ancora no chão — sem ela o
                -- prop parece adesivo flutuando na esfera)
                -- ciclo 26: 0.34→0.22 — elipse na largura da copa inteira
                -- sobrava pros lados (embaixo de ar) e lia como flutuação;
                -- sombra abraça o TRONCO, não a copa
                local aFade = math.min(1, 0.72 + t * 1.1)
                -- v6.3: sombra desloca CONTRA o sol do bioma (direcional)
                local shd = sunShadowDir(g, x, w, pxX)
                love.graphics.setColor(0, 0, 0, 0.20 * aFade)
                love.graphics.ellipse("fill", pxX + shd * iw * s * 0.16, sy - 1,
                    iw * s * 0.24, math.max(2, 4 * g.persp(t)))

                -- BALANÇO de vento (vegetação viva): rotação sutil no pivô
                -- da base, fase única por prop (p.z)
                local rot = 0
                local sink2 = 0
                if p.kind == "tree" or p.kind == "pine"
                   or p.kind == "deadtree" or p.kind == "bush" then
                    rot = math.sin(WorldRoad._time * 1.15 + p.z * 0.7) * 0.018
                    -- ciclo 27: base ENTERRADA ~4% no gramado — sprites do
                    -- PixelLab às vezes têm a raiz cortada reta na borda do
                    -- canvas; afundar esconde o corte (raiz "sai do chão")
                    sink2 = ih * s * 0.04
                elseif p.kind == "tuft" or p.kind == "flowers" then
                    -- v5.4: capim/flores balançam mais rápido e mais soltos
                    -- que árvores (massa menor) — "grama balançando"
                    rot = math.sin(WorldRoad._time * 2.3 + p.z * 1.4) * 0.055
                end

                -- perspectiva atmosférica + LUZ DO BIOMA: props tomam banho
                -- da cor ambiente (quente no abismo, frio na geleira) — sem
                -- isso parecem adesivos recortados de outro mundo
                -- ciclo 24: aFade só no BRILHO — alpha sempre 1. Alpha
                -- parcial deixava o domo vazar através das árvores longe
                -- (feedback: "as árvores ficam com uma transparência")
                local lt = envColor("fog")
                local mixK = 0.16
                love.graphics.setColor(
                    aFade * ((1 - mixK) + mixK * math.min(1.6, lt[1] * 1.9)),
                    aFade * ((1 - mixK) + mixK * math.min(1.6, lt[2] * 1.9)),
                    aFade * ((1 - mixK) + mixK * math.min(1.6, lt[3] * 1.9)),
                    1)
                love.graphics.draw(img, math.floor(pxX), math.floor(sy + sink2),
                    rot, s, s, iw / 2, ih)

                -- AVES pousadas na cerca: 2 pixels escuros no trilho de cima;
                -- decolam em arco quando você chega perto (rel < 6.5)
                if p.kind == "fence" and p.perched and not p.flown then
                    local railY = sy - ih * s * 0.82
                    for bi = 1, p.perched do
                        local bx = pxX + (bi == 1 and -0.22 or 0.24) * iw * s
                        love.graphics.setColor(0.14, 0.11, 0.10, 1)
                        love.graphics.rectangle("fill", math.floor(bx), math.floor(railY - 3), 3, 3)
                        love.graphics.rectangle("fill", math.floor(bx + 2), math.floor(railY - 5), 2, 2)
                    end
                    if rel < 6.5 then
                        p.flown = true
                        local skyH = g.crestApexY - g.y
                        for bi = 1, p.perched do
                            table.insert(WorldRoad._birds, {
                                xr = (pxX - x) / w,
                                yr = (sy - ih * s - g.y) / skyH,
                                dir = p.side >= 0 and 1 or -1,
                                speed = 0.07 + WorldRoad._rng:random() * 0.02,
                                phase = WorldRoad._rng:random() * 6.28,
                                vyr = -(0.28 + WorldRoad._rng:random() * 0.12),
                            })
                        end
                    end
                end
            end
        end
    end
    end

    -- ciclo 36: névoa ANTES de qualquer árvore. O design antigo (far →
    -- névoa → near) pintava a névoa POR CIMA das árvores distantes — no
    -- dusk (névoa laranja sobre copa roxa) virava franja de brilho
    -- seguindo a borda ("o brilho da borda aparece acima das árvores").
    -- Atmosfera nas árvores longe já existe via aFade (escurecimento).
    drawCrestFog(g, x, w)
    drawList(farPass)
    drawList(nearPass)
end

-- Encounter na frente do domo (cruzou a crista, desce a estrada crescendo)
local function drawEncounterFront(g, x, w, camZ)
    local e = WorldRoad._encounter
    if not e or not WorldRoad._travel then return end
    local rel = e.z - camZ
    if rel > REL_CREST then return end
    local t = g.tOf(rel)
    if not t then return end

    local cx = g.cx + roadWobble(e.z, t, w)   -- inimigo desce a curva
    local sy = g.crestApexY + (g.bottomY - g.crestApexY) * t
    -- escala pela MESMA perspectiva do mundo, normalizada pro handoff:
    -- persp(t)/persp(tBattle) = 1.0 exato no BATTLE_REL (sem pulo)
    local tBattle = g.tOf(WorldRoad.BATTLE_REL) or 0.3
    local k = math.min(1.02, g.persp(t) / math.max(0.01, g.persp(tBattle)))
    local s = e.targetScale * k
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(e.img, math.floor(cx - e.iw * s / 2),
        math.floor(sy - e.ih * s), 0, s, s)
end

function WorldRoad.draw(x, y, w, h, actNumber)
    if actNumber then WorldRoad.setBiome(actNumber) end

    local g = domeGeom(x, y, w, h)

    -- FUNDO DE SEGURANÇA (feedback telas largas): pinta a área inteira na
    -- cor escura do terreno ANTES de tudo — qualquer pixel que as camadas
    -- não cobrirem (cantos extremos além da curvatura, aspect ratios
    -- largos) mostra terra do bioma em vez de PRETO.
    local gb0 = envColor("grassB")
    love.graphics.setColor(gb0[1] * 0.78, gb0[2] * 0.78, gb0[3] * 0.78, 1)
    love.graphics.rectangle("fill", x, y, w, h)

    -- v6.6: ROOM SWAY (padrão update_canvas_juice do Balatro) — a cena
    -- inteira respira: rotação/drift imperceptíveis + zoom de 0.6% pra
    -- cobrir as bordas. Tira o "still frame" sem o jogador perceber o quê.
    love.graphics.push()
    local swCx, swCy = x + w / 2, y + h / 2
    love.graphics.translate(
        swCx + math.sin(WorldRoad._time * 0.23) * 1.5,
        swCy + math.cos(WorldRoad._time * 0.19) * 1.1)
    love.graphics.rotate(0.0012 * math.sin(WorldRoad._time * 0.3))
    love.graphics.scale(1.006, 1.006)
    love.graphics.translate(-swCx, -swCy)

    drawSky(g, x, y, w)
    drawCelestial(g, x, y, w)
    drawMountains(g, x, w, WorldRoad._camZ)
    -- v5.8: nuvens ENTRE o céu do strip e a silhueta frontal das montanhas
    -- (feedback: "as nuvens passam atrás das montanhas") — a camada
    -- mountains_front redesenha só os picos por cima delas.
    drawClouds(g, x, y, w)
    drawMountainsFront(g, x, w, WorldRoad._camZ)
    drawBirds(g, x, y, w)

    -- v6.2: PERSPECTIVA ATMOSFÉRICA — véu na cor da névoa sobre TODO o
    -- plano distante (strip+espelho+nuvens+picos+pássaros), mais forte
    -- perto do horizonte e sumindo no zênite. O longe perde contraste e
    -- puxa pra cor do céu; castelo/props desenham DEPOIS e ficam nítidos.
    do
        local fogc = envColor("fog")
        local gv = gradTex()
        local hazeBot = g.crestApexY + 10
        love.graphics.setColor(fogc[1], fogc[2], fogc[3], 0.16)
        love.graphics.draw(gv, x, hazeBot, 0, w, -(hazeBot - y) / 256)
        -- bordas: a crista desce até os cantos — a faixa entre o ápice e a
        -- curva local também é plano distante (o domo só cobre o centro)
        for sx = 0, w - 1, 6 do
            local cy = g.crestYAt(x + sx)
            if cy > hazeBot then
                love.graphics.rectangle("fill", x + sx, hazeBot, 6, cy - hazeBot)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- NÉVOA DE DISTÂNCIA (v5.4): banda de bruma entre as montanhas e o
    -- mundo — separa os planos (feedback: "neblina entre montanhas e
    -- floresta"). O castelo desenha DEPOIS: mais perto, fura a bruma.
    do
        local fogc = envColor("fog")
        local bandH = math.floor(h * 0.11)
        local gv = gradTex()
        local cyF = g.crestApexY - bandH * 0.5 + 6   -- pico da bruma no centro da banda
        love.graphics.setColor(fogc[1], fogc[2], fogc[3], 0.26)
        -- metade de cima (alpha cresce até o centro) + metade de baixo
        love.graphics.draw(gv, x, cyF, 0, w, -bandH * 0.5 / 256)
        love.graphics.draw(gv, x, cyF, 0, w, bandH * 0.5 / 256)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- v6.6: GOD RAYS — 2 feixes aditivos descendo do céu atrás do castelo,
    -- alpha oscilando devagar (polycount: raios estáticos modelados batem
    -- radial blur em 2D). Intensidade acompanha o glow do bioma.
    do
        local rayK = CASTLE_GLOW_K[rawBiome().id] or 0.8
        local crest = g.crestYAt(g.cx)
        love.graphics.setBlendMode("add")
        for i = 1, 2 do
            local osc = 0.5 + 0.5 * math.sin(WorldRoad._time * 0.3 + i * 2.1)
            local a = (0.028 + 0.034 * osc) * rayK
            local dir = (i == 1) and -1 or 1
            local topX = g.cx + dir * w * 0.045
            local botX = g.cx + dir * w * 0.15
            local rayW = w * 0.035
            love.graphics.setColor(1, 0.92, 0.72, a)
            love.graphics.polygon("fill",
                topX - rayW * 0.35, y,
                topX + rayW * 0.35, y,
                botX + rayW, crest,
                botX - rayW, crest)
        end
        love.graphics.setBlendMode("alpha")
    end

    drawCastle(g, x, w, WorldRoad._camZ)
    drawEncounterBehind(g, x, w, WorldRoad._camZ)
    drawPropsBehind(g, x, w, WorldRoad._camZ)
    drawDome(g, x, y, w)
    drawRoad(g, x, w, WorldRoad._camZ)

    -- ciclo 36: critters e partículas ambientais ANTES dos props — pontos
    -- brilhantes (folha dourada, vagalume) por cima das copas escuras liam
    -- como "brilho saindo das árvores". Partícula é do CAMPO: árvore oclui.

    -- critters rasantes (borboleta de dia, vagalume nos biomas escuros) —
    -- pousados na LATITUDE da esfera, esvoaçando baixinho
    do
        local b = rawBiome()
        local acc = b.accent or { 0.8, 0.7, 0.4 }
        local glow = (b.id == "abyss" or b.id == "marsh" or b.id == "highlands")
        for _, cr in ipairs(WorldRoad._critters) do
            local cxr = x + cr.xr * w
            local cyy = g.latY(cxr - g.cx, cr.yr)
                - 14 - math.sin(WorldRoad._time * 3.1 + cr.phase) * 6
            local a = math.min(1, cr.life / 2)
            if glow then
                -- vagalume: ponto que pisca com halo
                local blink = 0.5 + 0.5 * math.sin(WorldRoad._time * 2.2 + cr.phase * 3)
                love.graphics.setColor(acc[1], acc[2], acc[3], 0.20 * blink * a)
                love.graphics.circle("fill", cxr, cyy, 5)
                love.graphics.setColor(acc[1] * 1.2, acc[2] * 1.2, acc[3] * 1.1, 0.9 * blink * a)
                love.graphics.rectangle("fill", math.floor(cxr), math.floor(cyy), 2, 2)
            else
                -- borboleta: 2px com "asa" alternando
                local flap = math.sin(WorldRoad._time * 11 + cr.phase) > 0
                love.graphics.setColor(acc[1], acc[2], acc[3], 0.9 * a)
                love.graphics.rectangle("fill", math.floor(cxr), math.floor(cyy), 2, 2)
                if flap then
                    love.graphics.rectangle("fill", math.floor(cxr - 2), math.floor(cyy - 1), 2, 1)
                    love.graphics.rectangle("fill", math.floor(cxr + 2), math.floor(cyy - 1), 2, 1)
                end
            end
        end
    end

    -- partículas ambientais (folha/neve/brasa/esporo — atrás dos props)
    for _, a in ipairs(WorldRoad._ambient) do
        local ax = x + a.xr * w
        local ay = y + a.yr * h
        local flicker = a.style == "ember"
            and (0.7 + 0.3 * math.sin(WorldRoad._time * 9 + a.phase)) or 1
        love.graphics.setColor(a.color[1] * flicker, a.color[2] * flicker,
            a.color[3] * flicker, 0.8)
        love.graphics.rectangle("fill", math.floor(ax), math.floor(ay), a.size, a.size)
    end

    drawProps(g, x, w, WorldRoad._camZ)

    -- v6.6: fim do room sway — fork/pills/vinhetas ficam FIXOS (UI
    -- interativa balançando desalinharia os hitboxes do mouse)
    love.graphics.pop()

    -- fork/landmark DEPOIS dos props: marcos e pills são UI interativa —
    -- precisam ser legíveis por cima das copas (exceção consciente à regra
    -- "nada desenha sobre árvores", que vale pra efeitos de campo)
    drawLandmarkFront(g, x, w, WorldRoad._camZ)
    drawForkMarks(g, x, w, WorldRoad._camZ)
    drawEncounterFront(g, x, w, WorldRoad._camZ)

    -- vinheta inferior (mesma linguagem das outras scenes) — gradiente
    -- por textura (v6.1: sem degraus de rect)
    local gradH = math.floor(h * 0.20)
    local gv, gh2 = gradTex()
    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.draw(gv, x, g.bottomY, 0, w, -gradH / 256)

    -- vinheta LATERAL sutil (enquadramento cinematográfico — foco no centro)
    local vw = math.floor(w * 0.055)
    love.graphics.setColor(0, 0, 0, 0.16)
    love.graphics.draw(gh2, x, y, 0, vw / 256, h)
    love.graphics.draw(gh2, x + w, y, 0, -vw / 256, h)

    love.graphics.setColor(1, 1, 1, 1)
end

function WorldRoad.clearCache()
    WorldRoad._spriteCache = {}
    WorldRoad._quadCache = {}
    WorldRoad._props = {}
    WorldRoad._clouds = {}
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._encounter = nil
    WorldRoad._fork = nil
    WorldRoad._landmark = nil
end

return WorldRoad
