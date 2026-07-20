-- src/scenes/BootScene.lua
-- Splash + loading bar inicial. Inspirado em balatro-source/game.lua:1373-1515
-- (Game:splash_screen) mas escala mais minimalista — 12 cartas em vez de 200,
-- e usamos o PNG de splash como background em vez de vortex shader.
--
-- Fases internas:
--   "loading" (~0.5s) — barra de progresso pixel sépia, fade-in.
--   "splash"  (~3.0s) — burst central + carta materializa/dissolve + cascade
--                       de 12 mini-cartas + flash final + transição menu.
--   "done"            — terminou, BootScene para de desenhar.
--
-- Skippable: qualquer keypress/click pula direto pro menu (clear_queue("boot")
-- + onComplete).
--
-- Uso:
--   BootScene.init({ onComplete = function() currentState = "menu" end })
--   BootScene.update(dt) / BootScene.draw() / BootScene.keypressed(key)

local Palette         = require("src.ui.Palette")
local PixelCanvas     = require("src.ui.PixelCanvas")
local FontManager     = require("src.ui.FontManager")
local SceneBackground = require("src.ui.SceneBackground")
local I18n            = require("src.i18n.I18n")
local Sfx             = require("src.systems.Sfx")
local FlashShader     = require("src.ui.FlashShader")
local ParticlesManager = require("engine.ParticlesManager")
local CardBack        = require("src.ui.CardBack")
local TvOsd           = require("src.ui.TvOsd")

local BootScene = {}

-- ============== Estado ==============

local QUEUE = "boot"

local state = {
    phase           = "loading",  -- "loading" | "splash" | "done"
    loadingProgress = 0,
    loadingTime     = 0,
    onComplete      = nil,

    -- Splash
    splashTime      = 0,
    centerCard      = nil,        -- {x, y, w, h, alpha, scale, rot, dissolve}
    miniCards       = {},          -- array de {x, y, tx, ty, scale, alpha, rot}
    flashAlpha      = 0,
    skipped         = false,
    bgAlpha         = 0,           -- fade-in do background

    -- v2 "sintonizando o canal" (docs/plan/menu-crt-v2.md):
    staticAlpha     = 0,           -- chuvisco resolvendo na cena

    -- v6: energia arcana (plasma mascarado sobre a câmara) + título letra-a-letra
    plasmaAlpha     = 0,           -- 0..1 alpha da camada de energia
    titleLetters    = {},          -- { {ch, alpha, scale}, ... }
}

-- Tamanhos lógicos (em pixels da janela; LÖVE escala automaticamente).
local LOADING_BAR = { w = 320, h = 18, pad = 2 }
local CARD_SIZE   = { w = 96, h = 144 }
local MINI_SIZE   = { w = 56, h = 84 }
local NUM_MINI    = 22

-- Diagonal ratio do spawn radius das mini-cartas (baseado em max(W,H)).
-- 0.7 = bordas extremas, faz o voo parecer "vindo de longe".
local SPAWN_RADIUS_RATIO = 0.7

-- ============== Fundo em CAMADAS (v6, Jul/2026) ==============
-- Feedback do dono: o pixel art TEM que ser o fundo (com vida), e a energia
-- deve ser BASEADA no Balatro mas com a nossa cara. Composição:
--   1. CÂMARA ritual pixel art (frame_00, estática — sem flicker) = o fundo.
--   2. ENERGIA ARCANA (boot_splash.glsl): plasma sépia MASCARADO no miolo,
--      em volta do sigilo — swirl lento ouro+brasa, some nas bordas.
--   3. BRASAS subindo dos braseiros (procedural, quadradinhos pixel).
local bg = {
    dir = "assets/sprites/scenes/boot_anim",
    chamber = nil, loaded = false, shader = nil,
    offset = 12.0,   -- vort_offset fixo (varia o padrão do plasma)
}
local PLASMA_C1 = { 0.90, 0.70, 0.26, 1 }   -- ouro arcano
local PLASMA_C2 = { 0.66, 0.20, 0.10, 1 }   -- brasa-sangue

-- ÂNCORAS NA ARTE da câmara (pixels da imagem 256×192). v7: o SIGILO é o
-- CORAÇÃO da entrada — a energia emana dele, as cartas voam PRA DENTRO dele
-- e ele reage (pulso + flare + anéis por carta absorvida). Braseiros ganham
-- chama viva. Feedback do dono: "as cartas estão indo para nada".
local SIGIL_IX, SIGIL_IY = 128, 64
local BRAZIERS_IMG = { { 33, 60 }, { 223, 60 } }

-- Converte pixel da arte → tela, usando o transform do último draw (cover).
-- As âncoras ficam COLADAS na arte em qualquer resolução/aspect.
local function chamberAnchor(ix, iy)
    if bg._s then
        return bg._tx + ix * bg._s, bg._ty + iy * bg._s
    end
    local W, H = love.graphics.getDimensions()
    return W * 0.5, H * 0.34   -- fallback sem arte
end

-- Estado reativo do sigilo: flare (0..1, decai) + anéis de absorção.
local sigil = { flare = 0, rings = {} }

local function bumpSigil()
    sigil.flare = math.min(1, sigil.flare + 0.32)
    table.insert(sigil.rings, { r = 12, a = 0.55 })
end

local function updateSigil(dt)
    sigil.flare = math.max(0, sigil.flare - dt * 1.6)
    for i = #sigil.rings, 1, -1 do
        local rg = sigil.rings[i]
        rg.r = rg.r + 240 * dt
        rg.a = rg.a - 1.8 * dt
        if rg.a <= 0 then table.remove(sigil.rings, i) end
    end
end

local function loadBg()
    if bg.loaded then return end
    bg.loaded = true
    local ok, sh = pcall(love.graphics.newShader, "shaders/boot_splash.glsl")
    if ok then bg.shader = sh else print("[boot] boot_splash falhou: " .. tostring(sh)) end
    local p = bg.dir .. "/frame_00.png"
    if love.filesystem.getInfo(p) then
        local ok2, img = pcall(love.graphics.newImage, p)
        if ok2 then img:setFilter("nearest", "nearest"); bg.chamber = img end
    end
end

-- Camada 1: a câmara pixel art (SEMPRE — é o background). Guarda o transform
-- do cover em bg._tx/_ty/_s pras âncoras (sigilo/braseiros) colarem na arte.
local function drawChamberBG()
    local W, H = love.graphics.getDimensions()
    if bg.chamber then
        local iw, ih = bg.chamber:getDimensions()
        local s = math.max(W / iw, H / ih)
        local tx = math.floor((W - iw * s) / 2)
        local ty = math.floor((H - ih * s) / 2)
        bg._tx, bg._ty, bg._s = tx, ty, s
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bg.chamber, tx, ty, 0, s, s)
    else
        bg._s = nil
        if not SceneBackground.draw("splash", W, H, 0.55) then
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 1)
            love.graphics.rectangle("fill", 0, 0, W, H)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Camada 2: energia arcana ANCORADA NO SIGILO (alpha via state.plasmaAlpha).
local function drawPlasmaBG(t, alpha)
    if not bg.shader or (alpha or 0) < 0.01 then return end
    local W, H = love.graphics.getDimensions()
    local gx, gy = chamberAnchor(SIGIL_IX, SIGIL_IY)
    local diag = math.sqrt(W * W + H * H)
    love.graphics.setShader(bg.shader)
    bg.shader:send("time", t)
    bg.shader:send("vort_speed", 0.6)     -- lento, majestoso (não o ritmo do Balatro)
    bg.shader:send("colour_1", PLASMA_C1)
    bg.shader:send("colour_2", PLASMA_C2)
    bg.shader:send("mid_flash", 0)
    bg.shader:send("vort_offset", bg.offset)
    bg.shader:send("center_off", { (gx - 0.5 * W) / diag, (gy - 0.5 * H) / diag })
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Camada 2b: GLOW reativo do sigilo + anéis de absorção (um por carta
-- engolida) — o "pra onde as cartas estão indo" fica visível e responde.
local function drawSigilGlow()
    local gx, gy = chamberAnchor(SIGIL_IX, SIGIL_IY)
    local H = love.graphics.getHeight()
    local k = H / 768
    local t = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 1.7)
    local prev = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    local base = 0.05 + 0.06 * pulse + 0.38 * sigil.flare
    for i = 3, 1, -1 do
        love.graphics.setColor(0.95, 0.74, 0.30, base / i)
        love.graphics.circle("fill", gx, gy,
            (58 + i * 30) * k * (1 + 0.18 * sigil.flare), 32)
    end
    for _, rg in ipairs(sigil.rings) do
        love.graphics.setColor(0.98, 0.85, 0.45, rg.a)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", gx, gy, rg.r * k, 32)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode(prev)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Camada 2c: VIDA na arte — chamas dos braseiros tremulando + poça de luz
-- do sigilo no piso. Flicker QUANTIZADO em passos de 1/8s pra ler como pixel
-- art (não glow smooth de motor 3D).
local function drawChamberLife()
    local H = love.graphics.getHeight()
    local k = H / 768
    local t = love.timer.getTime()
    local qt = math.floor(t * 8) / 8
    local prev = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    for i, b in ipairs(BRAZIERS_IMG) do
        local bx, by = chamberAnchor(b[1], b[2])
        local flick = 0.5 + 0.5 * math.sin(qt * 37.7 + i * 13.1)
                                * math.sin(qt * 17.3 + i * 5.7)
        love.graphics.setColor(0.95, 0.55, 0.18, 0.10 + 0.10 * flick)
        love.graphics.circle("fill", bx, by, (30 + 8 * flick) * k, 24)
        love.graphics.setColor(0.99, 0.80, 0.30, 0.10 + 0.08 * (1 - flick))
        love.graphics.circle("fill", bx, by - 6 * k, (16 + 5 * (1 - flick)) * k, 24)
    end
    -- poça de luz do sigilo no piso (pulsa junto; flare ilumina o salão)
    local gx = chamberAnchor(SIGIL_IX, SIGIL_IY)
    local pulse = 0.5 + 0.5 * math.sin(t * 1.7)
    love.graphics.push()
    love.graphics.translate(gx, H * 0.80)
    love.graphics.scale(1, 0.28)
    love.graphics.setColor(0.95, 0.74, 0.30,
        0.05 + 0.05 * pulse + 0.22 * sigil.flare)
    love.graphics.circle("fill", 0, 0, 190 * k, 32)
    love.graphics.pop()
    love.graphics.setBlendMode(prev)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Camada 3: BRASAS subindo (dos braseiros da câmara + ambiente). Quadradinhos
-- pixel dourados/rubros com flicker — dá vida ao pixel art sem flicker de IA.
-- Coords normalizadas (0..1); RNG cosmético = math.random (regra do projeto).
local embers = { list = {}, spawnT = 0 }

local function updateEmbers(dt)
    embers.spawnT = embers.spawnT - dt
    if embers.spawnT <= 0 and #embers.list < 36 then
        embers.spawnT = 0.10
        local e = {
            sway = math.random() * 6.28,
            spd  = 0.05 + math.random() * 0.06,
            size = (math.random() < 0.3) and 2 or 1,
            life = 0,
            warm = math.random() < 0.72,
        }
        if math.random() < 0.6 then
            -- nasce num dos braseiros da câmara (x≈0.12 / 0.88, y≈0.38)
            local left = math.random() < 0.5
            e.x = (left and 0.12 or 0.88) + (math.random() - 0.5) * 0.05
            e.y = 0.40 + math.random() * 0.06
        else
            -- ambiente: sobe do chão
            e.x = 0.15 + math.random() * 0.7
            e.y = 1.02
        end
        table.insert(embers.list, e)
    end
    for i = #embers.list, 1, -1 do
        local e = embers.list[i]
        e.life = e.life + dt
        e.y = e.y - e.spd * dt
        if e.y < -0.03 then table.remove(embers.list, i) end
    end
end

local function drawEmbers()
    local W, H = love.graphics.getDimensions()
    local t = love.timer.getTime()
    local px = math.max(2, math.floor(H / 256))   -- 1 "pixel" da arte 4×
    for _, e in ipairs(embers.list) do
        local x = (e.x + 0.018 * math.sin(t * 0.9 + e.sway)) * W
        local flick = 0.55 + 0.45 * math.sin(t * 3.2 + e.sway * 2)
        local a = math.min(1, e.life * 2.5) * 0.55 * flick
        if e.warm then
            love.graphics.setColor(0.95, 0.72, 0.28, a)
        else
            love.graphics.setColor(0.78, 0.30, 0.14, a)
        end
        local s = e.size * px
        love.graphics.rectangle("fill", math.floor(x), math.floor(e.y * H), s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============== Init ==============

function BootScene.init(callbacks)
    callbacks = callbacks or {}
    state.phase           = "loading"
    state.loadingProgress = 0
    state.loadingTime     = 0
    state.splashTime      = 0
    state.miniCards       = {}
    state.flashAlpha      = 0
    state.skipped         = false
    state.bgAlpha         = 0
    state.staticAlpha     = 0
    state.plasmaAlpha     = 0
    state.titleLetters    = {}
    state.onComplete      = callbacks.onComplete
    embers.list           = {}
    embers.spawnT         = 0
    sigil.flare           = 0
    sigil.rings           = {}

    -- Background fade-in (não-bloqueante para não travar o resto).
    if _G.EventManager then
        _G.EventManager.parallelEase(state, "bgAlpha", 1, 0.4, "smooth", QUEUE)
    else
        state.bgAlpha = 1
    end

    -- SOM: a TV LIGANDO — casa com o warm-up do CRTShader.powerOn(1.8) disparado
    -- em main.lua no mesmo instante (ponto → linha → abre → assenta).
    Sfx.play("bootTvPowerOn")
end

-- ============== Splash sequence ==============

-- Centro da tela LIVE (recalculado a cada chamada — resiliente a resize).
local function liveCenter()
    return love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
end

local function startSplashSequence()
    state.phase = "splash"
    state.splashTime = 0

    -- SINTONIA: o canal ancora — chuvisco forte resolvendo na cena.
    state.staticAlpha = 0.85
    if _G.EventManager then
        _G.EventManager.parallelEase(state, "staticAlpha", 0, 0.55, "smooth", QUEUE)
        -- Energia arcana desperta DEVAGAR em volta do sigilo (2s de fade).
        _G.EventManager.parallelEase(state, "plasmaAlpha", 0.9, 2.0, "smooth", QUEUE)
    else
        state.staticAlpha = 0
        state.plasmaAlpha = 0.9
    end

    -- Título letra-a-letra (pedido do dono): pré-quebra em codepoints UTF-8.
    state.titleLetters = {}
    do
        local utf8 = require("utf8")
        local title = I18n.t("menu.title")
        for _, cp in utf8.codes(title) do
            table.insert(state.titleLetters,
                { ch = utf8.char(cp), alpha = 0, scale = 1.8 })
        end
    end

    -- Carta central: SEM x/y armazenados — sempre desenhada em liveCenter()
    -- pra acompanhar resize da janela. Só anima alpha/scale/dissolve.
    state.centerCard = {
        scale = 0.3, alpha = 0, rot = 0,
        dissolve = 0,
    }

    local EM = _G.EventManager
    if not EM then
        BootScene.skip()
        return
    end

    -- Burst de partículas no centro inicial. ParticlesManager spawn é
    -- one-shot: as partículas vão divergir do ponto de spawn, então mesmo
    -- com resize o burst em si fica coerente (parte de onde estava).
    do
        local cx, cy = chamberAnchor(SIGIL_IX, SIGIL_IY)   -- burst NO sigilo
        ParticlesManager.spawn(cx, cy, 0, 0, {
            timer = 0.02,
            lifespan = 1.0,
            scale = 0.5,
            speed = 140,
            colours = {
                {0.95, 0.78, 0.32, 1},  -- AGED_GOLD_LIGHT
                {0.78, 0.62, 0.20, 1},  -- AGED_GOLD
                {0.55, 0.42, 0.12, 1},  -- AGED_GOLD_DARK
            },
            pulse_max = 24,
            vel_variation = 0.6,
            layer = 8,
        })
    end

    -- IMPORTANTE: tudo abaixo usa parallel/parallelEase porque queremos
    -- timeline ABSOLUTO (vários eventos simultâneos), não sequencial.

    -- 0.10s: carta central materializa (alpha + back_out scale pop).
    EM.parallel(0.10, function()
        EM.parallelEase(state.centerCard, "alpha", 1.0, 0.4, "smooth",   QUEUE)
        EM.parallelEase(state.centerCard, "scale", 1.0, 0.5, "back_out", QUEUE)
    end, QUEUE)

    -- 0.50s: impacto sonoro.
    EM.parallel(0.50, function() Sfx.play("deckStart") end, QUEUE)

    -- 1.40s: a carta central DISSOLVE e é sugada pro centro (buildup grave,
    -- estilo Balatro: magic_crumple + splash_buildup).
    EM.parallel(1.40, function()
        EM.parallelEase(state.centerCard, "dissolve", 1.0, 0.5, "smooth",  QUEUE)
        EM.parallelEase(state.centerCard, "alpha",    0.0, 0.5, "smooth",  QUEUE)
        EM.parallelEase(state.centerCard, "scale",    0.1, 0.5, "ease_in", QUEUE)
        Sfx.play("bootVortex")
    end, QUEUE)

    -- 1.70s+: cascade de mini-cartas, staggered 0.08s (janela ~1.7s — mais
    -- CALMA que antes; feedback: "extremamente rápido"). Cada uma:
    --   - Coords em POLAR (angle, distFrom) — cx/cy lidos live no draw.
    --   - Voa com ease_OUT (decelera ao chegar), espiral orgânica.
    --   - Scale pop-in → collapse no centro (sucção). Computado em update.
    -- 1.65s: WHOOSH grave da massa de cartas convergindo.
    EM.parallel(1.65, function() Sfx.play("bootCardWhoosh") end, QUEUE)

    for i = 1, NUM_MINI do
        local delay = 1.70 + (i - 1) * 0.08
        EM.parallel(delay, function()
            local W, H = love.graphics.getWidth(), love.graphics.getHeight()
            local angle = math.random() * math.pi * 2
            local radius = math.max(W, H) * SPAWN_RADIUS_RATIO

            local mc = {
                angle    = angle,
                -- v2: ESPIRAL — o ângulo anima junto com a distância
                -- (antes o voo era linha reta radial; espiral é orgânico)
                angleSpeed = (math.random() < 0.5 and -1 or 1)
                    * (1.0 + math.random() * 1.4),      -- rad/s de órbita
                distFrom = radius,
                rot      = math.random() * math.pi * 2,
                rotSpeed = (math.random() - 0.5) * 8,   -- rad/s tumble
                alpha    = 0,
                scale    = 0,
                age      = 0,
                lifespan = 0.55 + math.random() * 0.10, -- 0.55..0.65
                _alive   = true,
            }
            table.insert(state.miniCards, mc)

            -- Distância vai de radius → 0 com ease_OUT (decelera ao pousar).
            EM.parallelEase(mc, "distFrom", 0, mc.lifespan, "ease_out", QUEUE)
            -- Alpha sobe rápido nos primeiros 0.12s (fade-in).
            EM.parallelEase(mc, "alpha", 1.0, 0.12, "smooth", QUEUE)

            -- Scale curve é computada em BootScene.update (não-monotônica:
            -- pop in → hold → collapse). Não dá pra fazer com ease único.

            local pitch = 0.85 + i * 0.022
            Sfx.play("cardDraw", { pitch = pitch, volume = 0.42 })
        end, QUEUE)
    end
    -- fim da cascade: último spawn + voo (~0.65s)
    local tCascadeEnd = 1.70 + (NUM_MINI - 1) * 0.08 + 0.70

    -- TÍTULO LETRA-A-LETRA (feedback do dono): cada letra "carimba" na tela
    -- com pop back_out + tick sonoro em pitch crescente. Começa DEPOIS da
    -- cascade assentar — nada de atropelar.
    local T_TITLE = tCascadeEnd + 0.25
    local nLetters = #state.titleLetters
    for i = 1, nLetters do
        EM.parallel(T_TITLE + (i - 1) * 0.09, function()
            local L = state.titleLetters[i]
            if L then
                EM.parallelEase(L, "alpha", 1.0, 0.15, "smooth",   QUEUE)
                EM.parallelEase(L, "scale", 1.0, 0.30, "back_out", QUEUE)
                if L.ch ~= " " then
                    Sfx.play("cardDraw", { pitch = 0.9 + i * 0.035, volume = 0.35 })
                end
            end
        end, QUEUE)
    end
    local tTitleEnd = T_TITLE + nLetters * 0.09

    -- RESPIRO: título completo pousado, energia girando — segura ~1s antes
    -- do clímax (feedback: "já muda direto pro menu, isso está errado").
    local tFlash = tTitleEnd + 1.0
    EM.parallel(tFlash, function()
        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(1.0, 0.5)
        else
            state.flashAlpha = 1.0
            EM.parallelEase(state, "flashAlpha", 0, 0.5, "smooth", QUEUE)
        end
        Sfx.play("bootImpact")
        if _G.triggerShake then _G.triggerShake(7, 0.35) end
    end, QUEUE)

    -- transição pro menu (depois do flash desbotar).
    EM.parallel(tFlash + 0.60, function() BootScene._finish() end, QUEUE)
end

-- ============== Update / Draw ==============

function BootScene.update(dt)
    if state.phase == "done" then return end

    updateEmbers(dt)   -- brasas vivem em todas as fases (o cenário respira)
    updateSigil(dt)    -- flare decai + anéis de absorção expandem

    if state.phase == "loading" then
        state.loadingTime = state.loadingTime + dt
        local t = math.min(1, state.loadingTime / 0.5)
        state.loadingProgress = t

        if t >= 1 then
            startSplashSequence()
        end
    elseif state.phase == "splash" then
        state.splashTime = state.splashTime + dt

        -- Atualiza mini-cartas: tumble rotation + scale curve não-monotônica
        -- (pop-in → hold → collapse). Coords absolutas são derivadas no draw
        -- via liveCenter() + polar (angle, distFrom).
        for i = #state.miniCards, 1, -1 do
            local mc = state.miniCards[i]
            mc.age = mc.age + dt
            mc.rot = mc.rot + dt * mc.rotSpeed
            -- espiral: órbita desacelera conforme chega no centro
            if mc.angleSpeed then
                local closeness = 1 - math.min(1, mc.age / mc.lifespan)
                mc.angle = mc.angle + dt * mc.angleSpeed * (0.4 + 0.6 * closeness)
            end

            local t2 = math.min(1, mc.age / mc.lifespan)
            -- Curva: 0 → 1 em t∈[0, 0.65] (pop-in fast), 1 → 0 em t∈[0.65, 1] (collapse).
            if t2 < 0.65 then
                local k = t2 / 0.65
                mc.scale = k * k * (3 - 2 * k)  -- smoothstep pop-in
            else
                local k = (t2 - 0.65) / 0.35
                mc.scale = 1 - (k * k * (3 - 2 * k))  -- smoothstep collapse
            end

            -- Mini-carta chegou: ABSORVIDA pelo sigilo — flare + anel de
            -- absorção (o destino responde; feedback "indo para nada").
            if mc.age >= mc.lifespan then
                mc._alive = false
                table.remove(state.miniCards, i)
                bumpSigil()
            end
        end
    end
end

local function drawBackground()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    loadBg()
    -- CAMADAS: câmara pixel art (sempre) → energia emanando do sigilo (splash)
    -- → glow reativo do sigilo → chamas/luz do piso → brasas subindo.
    drawChamberBG()
    if state.phase == "splash" then
        drawPlasmaBG(state.splashTime, state.plasmaAlpha)
    end
    drawSigilGlow()
    drawChamberLife()
    drawEmbers()

    -- Fade-in mask (escurece o que tem por baixo enquanto bgAlpha sobe).
    if state.bgAlpha < 1 then
        love.graphics.setColor(0, 0, 0, 1 - state.bgAlpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Preview do fundo completo pro tool de validação (screenshot_bootfx):
-- desenha todas as camadas num instante t, com flare forçado.
function BootScene.previewBackground(t, plasmaAlpha, flare)
    loadBg()
    sigil.flare = flare or 0
    drawChamberBG()
    if plasmaAlpha and plasmaAlpha > 0.01 then drawPlasmaBG(t, plasmaAlpha) end
    drawSigilGlow()
    drawChamberLife()
end

local function drawLoadingBar()
    -- v2: a "carga" é a TV SINTONIZANDO — label + barra de segmentos OSD
    -- verde-fósforo (mesma linguagem do volume de TV velha).
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local segs, segW, gap = 16, 16, 3
    local barW = segs * (segW + gap) - gap
    local x = math.floor((W - barW) / 2)
    local y = math.floor(H * 0.62)

    local label = I18n.t("boot.loading")
    TvOsd.text(label, math.floor((W - TvOsd.textWidth(label, 14)) / 2),
        y - 28, state.bgAlpha, 14)
    TvOsd.segmentBar(x, y, state.loadingProgress,
        { segments = segs, segW = segW, segH = 14, gap = gap,
          alpha = state.bgAlpha })

    -- chuvisco leve enquanto sintoniza (resolve quando o splash abre)
    TvOsd.staticNoise(0.25 * state.bgAlpha)
end

-- Wrapper sobre src/ui/CardBack. Aplica ambient breathing (mesma lógica do
-- ambient tilt de Card.lua) — cada carta com fase única baseada em posição,
-- evitando sincronia. Sem mouse hover (cartas voando rápido).
local function drawCardShape(x, y, w, h, alpha, scale, rot, dissolveAmount)
    local t = love.timer.getTime()
    -- Tilts em TILT_RANGE units (radianos). 0.04 ≈ 30% de TILT_RANGE = sutil.
    local tiltX = math.sin(t * 1.4 + x * 0.07) * 0.04
    local tiltY = math.cos(t * 1.0 + y * 0.07) * 0.025

    CardBack.draw(x, y, w, h, {
        alpha               = alpha,
        scale               = scale,
        rot                 = rot,
        dissolve            = dissolveAmount,
        tiltX               = tiltX,
        tiltY               = tiltY,
        hoverStrength       = 0,
        liftOffset          = 0,
        perspectiveRotation = 0,
    })
end

local function drawSplash()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local cx, _ = liveCenter()
    -- v7: o DESTINO das cartas é o SIGILO (não o centro vazio da tela) — elas
    -- são visivelmente absorvidas por ele, que responde com flare + anéis.
    local sx, sy = chamberAnchor(SIGIL_IX, SIGIL_IY)

    -- Mini-cartas primeiro (z-order: ficam atrás da central). Coords em polar
    -- (angle, distFrom) a partir do sigilo — âncora live, resize não quebra.
    for _, mc in ipairs(state.miniCards) do
        local x = sx + math.cos(mc.angle) * mc.distFrom
        local y = sy + math.sin(mc.angle) * mc.distFrom
        drawCardShape(x, y, MINI_SIZE.w, MINI_SIZE.h, mc.alpha, mc.scale, mc.rot, 0)
    end

    -- Carta central por cima, pairando NA FRENTE do sigilo (é ele quem a
    -- dissolve e absorve).
    if state.centerCard then
        local c = state.centerCard
        drawCardShape(sx, sy, CARD_SIZE.w, CARD_SIZE.h, c.alpha, c.scale, c.rot, c.dissolve)
    end

    -- TÍTULO LETRA-A-LETRA: cada letra carimba com pop próprio (alpha/scale
    -- individuais, animados pela timeline). Outline ink + face dourada com
    -- pulse dessincronizado por letra.
    if #state.titleLetters > 0 then
        -- CardBack pode deixar o DissolveShader ativo (carta central termina
        -- em dissolve=1) — sem reset as letras saem corroídas/escuras.
        love.graphics.setShader()
        local font = FontManager.getFont(math.min(44, math.floor(H * 0.075)))
        love.graphics.setFont(font)
        local fh = font:getHeight()
        local totalW = 0
        for _, L in ipairs(state.titleLetters) do
            L.w = font:getWidth(L.ch)
            totalW = totalW + L.w
        end
        local x = cx - totalW / 2
        local baseY = math.floor(H * 0.72)
        local g = Palette.AGED_GOLD_LIGHT
        for i, L in ipairs(state.titleLetters) do
            if L.alpha > 0.02 then
                love.graphics.push()
                love.graphics.translate(x + L.w / 2, baseY + fh / 2)
                love.graphics.scale(L.scale, L.scale)
                local ox, oy = -L.w / 2, -fh / 2
                love.graphics.setColor(0, 0, 0, 0.85 * L.alpha)
                for _, o in ipairs({ {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {3, 3} }) do
                    love.graphics.print(L.ch, ox + o[1], oy + o[2])
                end
                local pulse = 1 + 0.06 * math.sin(state.splashTime * 3 + i * 0.7)
                love.graphics.setColor(math.min(1, g[1] * pulse),
                    math.min(1, g[2] * pulse), g[3], L.alpha)
                love.graphics.print(L.ch, ox, oy)
                love.graphics.pop()
            end
            x = x + L.w
        end
    end

    -- Flash overlay manual (caso FlashShader não estivesse disponível).
    if state.flashAlpha > 0 then
        love.graphics.setColor(1, 1, 1, state.flashAlpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function drawSkipHint()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local font = FontManager.getFont(10)
    love.graphics.setFont(font)
    local label = I18n.t("boot.skip_hint")

    -- Pulse sutil pra atrair olhar mas não distrair.
    local pulse = 0.5 + math.sin(love.timer.getTime() * 2) * 0.2
    Palette.set(Palette.PARCHMENT_DARK)
    love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2], Palette.PARCHMENT_DARK[3], pulse)
    love.graphics.print(label, math.floor((W - font:getWidth(label)) / 2), H - 28)
    love.graphics.setColor(1, 1, 1, 1)
end

function BootScene.draw()
    if state.phase == "done" then return end

    drawBackground()

    if state.phase == "loading" then
        drawLoadingBar()
    elseif state.phase == "splash" then
        drawSplash()
        -- CHUVISCO da sintonia por cima do programa (resolve em ~0.55s)
        TvOsd.staticNoise(state.staticAlpha)
        drawSkipHint()
    end

    -- Tag de canal do aparelho (OSD canto sup-dir, como TV real)
    do
        local W = love.graphics.getWidth()
        local tag = "AV-1"
        TvOsd.text(tag, W - TvOsd.textWidth(tag) - 26, 20, 0.9 * state.bgAlpha)
    end

    -- Versão no canto inferior-esquerdo (identidade "produto de verdade").
    do
        local Config = require("src.core.Config")
        local f = FontManager.getFont(9)
        love.graphics.setFont(f)
        local pd = Palette.PARCHMENT_DARK
        love.graphics.setColor(pd[1], pd[2], pd[3], 0.6 * state.bgAlpha)
        love.graphics.print("v" .. (Config.VERSION or "?"),
            12, love.graphics.getHeight() - 22)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============== Skip / finish ==============

function BootScene.skip()
    if state.phase == "done" then return end
    state.skipped = true
    if _G.EventManager then _G.EventManager.clear(QUEUE) end
    BootScene._finish()
end

function BootScene._finish()
    state.phase = "done"
    state.miniCards = {}
    state.centerCard = nil
    state.flashAlpha = 0
    state.titleLetters = {}
    embers.list = {}
    sigil.flare = 0
    sigil.rings = {}
    -- SYNC (feedback): mata qualquer SFX de boot (raio/rumble/impacto) ANTES do
    -- menu + música entrarem — o barulho de raio vazava pro menu. stopGroup só
    -- corta o grupo "sfx"; a música (grupo "music") não é afetada.
    if _G.audioSystem and _G.audioSystem.stopGroup then
        _G.audioSystem:stopGroup("sfx")
    end
    if state.onComplete then state.onComplete() end
end

function BootScene.keypressed(_)
    if state.phase ~= "done" then BootScene.skip() end
end

function BootScene.mousepressed(_, _, _)
    if state.phase ~= "done" then BootScene.skip() end
end

function BootScene.isDone() return state.phase == "done" end

return BootScene
