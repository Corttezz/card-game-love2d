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
local BootFX          = require("src.ui.BootFX")

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
    titleAlpha      = 0,           -- título do jogo (surge no auge da cascade)
    titleScale      = 0.9,

    -- v2 "sintonizando o canal" (docs/plan/menu-crt-v2.md):
    staticAlpha     = 0,           -- chuvisco resolvendo na cena
    titleGlitchT    = 0,           -- glitch de sinal RGB no título

    -- v3 "vórtice": 0..1 = quanto o buraco no centro está aberto (BootFX).
    vortex          = 0,
}

-- Tamanhos lógicos (em pixels da janela; LÖVE escala automaticamente).
local LOADING_BAR = { w = 320, h = 18, pad = 2 }
local CARD_SIZE   = { w = 96, h = 144 }
local MINI_SIZE   = { w = 56, h = 84 }
local NUM_MINI    = 22

-- Diagonal ratio do spawn radius das mini-cartas (baseado em max(W,H)).
-- 0.7 = bordas extremas, faz o voo parecer "vindo de longe".
local SPAWN_RADIUS_RATIO = 0.7

-- ============== Fundo animado (PixelLab, Jul/2026) ==============
-- Câmara ritual 256×192 animada em loop (chamas/sigilo/brasas). Frames em
-- assets/sprites/scenes/boot_anim/*.png (ordem alfabética) + meta.lua opcional
-- ({ fps = N }). 256×192 → 4× exato pra 1024×768 (pixels nítidos). Fallback:
-- splash.png estático (SceneBackground) se a pasta não existir.
local bootAnim = {
    dir = "assets/sprites/scenes/boot_anim",
    frames = nil, fps = 9, t = 0, loaded = false,
    shader = nil,   -- boot_warp.glsl (swirl/pinch de sucção do fundo)
}

local function loadBootAnim()
    if bootAnim.loaded then return end
    bootAnim.loaded = true
    if not love.filesystem.getInfo(bootAnim.dir) then return end
    local metaPath = bootAnim.dir .. "/meta.lua"
    if love.filesystem.getInfo(metaPath) then
        local ok, chunk = pcall(love.filesystem.load, metaPath)
        if ok and chunk then
            local okm, m = pcall(chunk)
            if okm and type(m) == "table" and m.fps then bootAnim.fps = m.fps end
        end
    end
    local frames = {}
    for _, f in ipairs(love.filesystem.getDirectoryItems(bootAnim.dir)) do
        if f:match("%.png$") then
            local ok, img = pcall(love.graphics.newImage, bootAnim.dir .. "/" .. f)
            if ok and img then
                img:setFilter("nearest", "nearest")   -- pixel art nítido no upscale
                frames[#frames + 1] = { name = f, img = img }
            end
        end
    end
    table.sort(frames, function(a, b) return a.name < b.name end)
    if #frames > 0 then
        bootAnim.frames = {}
        for _, e in ipairs(frames) do bootAnim.frames[#bootAnim.frames + 1] = e.img end
        bootAnim.frames[1]:setWrap("clamp", "clamp")   -- evita borda repetida no warp
    end
    -- shader de sucção (opcional — cai pro draw plano se falhar)
    local ok, sh = pcall(love.graphics.newShader, "shaders/boot_warp.glsl")
    if ok then bootAnim.shader = sh end
end

-- Desenha o fundo cover-fit (preenche a tela). Retorna false se não há asset.
-- v3 (feedback do dono): o loop de frames "piscava/quebrava" (cada frame do
-- PixelLab é redesenhado pela IA → shimmer). Agora usa um ÚNICO frame ESTÁVEL
-- como base (sem flicker); a vida vem do BootFX (vórtice procedural).
local function drawBootAnimBG(alpha, warp, warpT)
    if not bootAnim.frames or #bootAnim.frames == 0 then return false end
    warp = warp or 0
    local W, H = love.graphics.getDimensions()
    local img = bootAnim.frames[1]                  -- base estática (frame_00)
    local iw, ih = img:getDimensions()
    -- ZOOM sutil cresce com o warp (dolly-in pro buraco, reforça a sucção)
    local zoom = 1 + 0.12 * warp
    local scale = math.max(W / iw, H / ih) * zoom   -- cover + zoom
    local dw, dh = iw * scale, ih * scale
    -- WARP de sucção (swirl+pinch) — a própria pedra roda/contrai pro centro
    if bootAnim.shader and warp > 0.001 then
        love.graphics.setShader(bootAnim.shader)
        bootAnim.shader:send("intensity", math.min(1, warp))
        bootAnim.shader:send("t", warpT or 0)
    end
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(img, math.floor((W - dw) / 2), math.floor((H - dh) / 2), 0, scale, scale)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    return true
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
    state.titleAlpha      = 0
    state.titleScale      = 0.9
    state.staticAlpha     = 0
    state.titleGlitchT    = 0
    state.onComplete      = callbacks.onComplete
    bootAnim.t            = 0

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
    state.vortex = 0
    BootFX.reset()

    -- SINTONIA: o canal ancora — chuvisco forte resolvendo na cena.
    state.staticAlpha = 0.85
    if _G.EventManager then
        _G.EventManager.parallelEase(state, "staticAlpha", 0, 0.55, "smooth", QUEUE)
    else
        state.staticAlpha = 0
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
        local cx, cy = liveCenter()
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

    -- 0.85s: a PEDRA racha — o vórtice começa a abrir no centro (rumble grave).
    EM.parallel(0.85, function()
        Sfx.play("bootVortex")
        EM.parallelEase(state, "vortex", 0.40, 0.85, "smooth", QUEUE)
    end, QUEUE)

    -- 1.10s: a carta central é SUGADA pro buraco (dissolve + encolhe pro centro).
    EM.parallel(1.10, function()
        EM.parallelEase(state.centerCard, "dissolve", 1.0, 0.4, "smooth",  QUEUE)
        EM.parallelEase(state.centerCard, "alpha",    0.0, 0.4, "smooth",  QUEUE)
        EM.parallelEase(state.centerCard, "scale",    0.1, 0.4, "ease_in", QUEUE)
    end, QUEUE)

    -- 1.30s: ELETRICIDADE crackla e o buraco cresce mais.
    EM.parallel(1.30, function()
        Sfx.play("bootElectric")
        EM.parallelEase(state, "vortex", 0.72, 1.2, "smooth", QUEUE)
    end, QUEUE)

    -- 1.40s+: cascade de 16 mini-cartas, staggered 0.06s = 0.96s spawn window.
    -- Cada uma:
    --   - Coords em POLAR (angle, distFrom) — cx/cy lidos live no draw,
    --     resize não quebra centralização.
    --   - Voa com ease_OUT (decelera ao chegar) — feel de "pousando" no centro,
    --     contraste com ease_in que fazia a chegada parecer arrombada.
    --   - Tumble rotation (rotSpeed) durante voo — cartas giram orgânicamente.
    --   - Scale curve com pop: cresce 0→1 nos primeiros 70% do voo, depois
    --     colapsa 1→0 nos últimos 30% (sucção pro centro). Computado em update.
    --   - Lifespan ligeiramente variado por carta (0.55..0.65) — não pousam todas
    --     no mesmo frame.
    -- 1.35s: WHOOSH grave da massa de cartas convergindo — dá corpo sonoro
    -- que os cardDraw individuais (pitched) sozinhos não dão.
    EM.parallel(1.35, function() Sfx.play("bootCardWhoosh") end, QUEUE)

    for i = 1, NUM_MINI do
        local delay = 1.40 + (i - 1) * 0.07
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

    -- 2.10s: título do jogo materializa sob a carta central — com GLITCH
    -- de sinal (2 cópias RGB deslocadas por ~0.15s, depois assenta).
    EM.parallel(2.10, function()
        EM.parallelEase(state, "titleAlpha", 1.0, 0.45, "smooth",   QUEUE)
        EM.parallelEase(state, "titleScale", 1.0, 0.45, "back_out", QUEUE)
        state.titleGlitchT = 0.15
    end, QUEUE)

    -- 3.00s: o buraco escancara (vórtice no máximo). SEM tocar eletricidade
    -- aqui — o SFX de raio é curto e já tocou em 1.30 (o de 3.00 vazava pro
    -- menu). O clímax sonoro é o bootImpact do flash.
    EM.parallel(3.00, function()
        EM.parallelEase(state, "vortex", 1.0, 0.6, "smooth", QUEUE)
    end, QUEUE)

    -- 3.65s: PEAK — flash + impacto grave + screen-shake forte (o "selo
    -- mágico assentando"). Punch estilo Balatro.
    EM.parallel(3.65, function()
        if FlashShader and FlashShader.trigger then
            FlashShader.trigger(1.0, 0.45)
        else
            state.flashAlpha = 1.0
            EM.parallelEase(state, "flashAlpha", 0, 0.45, "smooth", QUEUE)
        end
        Sfx.play("bootImpact")
        if _G.triggerShake then _G.triggerShake(10, 0.4) end
        -- o buraco IMPLODE sob o flash (colapsa rápido pro nada)
        EM.parallelEase(state, "vortex", 0.0, 0.4, "ease_in", QUEUE)
    end, QUEUE)

    -- 4.25s: transição pro menu (depois do flash desbotar).
    EM.parallel(4.25, function() BootScene._finish() end, QUEUE)
end

-- ============== Update / Draw ==============

function BootScene.update(dt)
    if state.phase == "done" then return end

    bootAnim.t = bootAnim.t + dt   -- fundo animado corre em todas as fases

    if state.phase == "loading" then
        state.loadingTime = state.loadingTime + dt
        local t = math.min(1, state.loadingTime / 0.5)
        state.loadingProgress = t

        if t >= 1 then
            startSplashSequence()
        end
    elseif state.phase == "splash" then
        state.splashTime = state.splashTime + dt
        BootFX.update(dt, state.vortex)   -- vórtice procedural (buraco/eletricidade/brasas)

        -- Atualiza mini-cartas: tumble rotation + scale curve não-monotônica
        -- (pop-in → hold → collapse). Coords absolutas são derivadas no draw
        -- via liveCenter() + polar (angle, distFrom).
        -- glitch de sinal do título decai
        if state.titleGlitchT > 0 then
            state.titleGlitchT = math.max(0, state.titleGlitchT - dt)
        end

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

            -- Mini-cartas que terminaram a vida saem do array (cleanup).
            if mc.age >= mc.lifespan then
                mc._alive = false
                table.remove(state.miniCards, i)
            end
        end
    end
end

local function drawBackground()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    loadBootAnim()
    -- 1º: fundo (câmara ritual PixelLab) com WARP de sucção dirigido por
    -- state.vortex — a pedra roda/contrai pro buraco. 0.9 pra dar contraste
    -- ao primeiro plano.
    local hadScene = drawBootAnimBG(0.9, state.vortex, state.splashTime)
    -- Fallback: splash estático → menu → ink.
    if not hadScene then
        hadScene = SceneBackground.draw("splash", W, H, 0.55)
    end
    if not hadScene then
        if not SceneBackground.draw("menu", W, H, 0.65) then
            love.graphics.setColor(Palette.INK[1], Palette.INK[2], Palette.INK[3], 1)
            love.graphics.rectangle("fill", 0, 0, W, H)
        end
    end

    -- Fade-in mask (escurece o que tem por baixo enquanto bgAlpha sobe).
    if state.bgAlpha < 1 then
        love.graphics.setColor(0, 0, 0, 1 - state.bgAlpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    love.graphics.setColor(1, 1, 1, 1)
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
    local cx, cy = liveCenter()

    -- VÓRTICE procedural ATRÁS das cartas (elas voam pra DENTRO do buraco).
    -- baseRadius relativo à tela; state.vortex 0..1 dirige a abertura.
    BootFX.draw(cx, cy, math.min(W, H) * 0.34, state.vortex)

    -- Mini-cartas primeiro (z-order: ficam atrás da central). Coords vêm
    -- de polar (angle, distFrom) → screen — cx/cy são live, então resize
    -- mid-anim mantém centralização.
    for _, mc in ipairs(state.miniCards) do
        local x = cx + math.cos(mc.angle) * mc.distFrom
        local y = cy + math.sin(mc.angle) * mc.distFrom
        drawCardShape(x, y, MINI_SIZE.w, MINI_SIZE.h, mc.alpha, mc.scale, mc.rot, 0)
    end

    -- Carta central por cima. Posição = sempre liveCenter.
    if state.centerCard then
        local c = state.centerCard
        drawCardShape(cx, cy, CARD_SIZE.w, CARD_SIZE.h, c.alpha, c.scale, c.rot, c.dissolve)
    end

    -- Título do jogo (surge no auge da cascade, back_out pop).
    if state.titleAlpha > 0.02 then
        -- CardBack pode deixar o DissolveShader ativo (carta central termina
        -- em dissolve=1) — sem reset as letras saem corroídas/escuras.
        love.graphics.setShader()
        local font = FontManager.getFont(math.min(44, math.floor(H * 0.075)))
        love.graphics.setFont(font)
        local title = I18n.t("menu.title")
        local tw = font:getWidth(title)
        love.graphics.push()
        love.graphics.translate(cx, math.floor(H * 0.72))
        love.graphics.scale(state.titleScale, state.titleScale)
        -- Outline ink 4-direções (contraste sobre o piso claro) + face dourada.
        love.graphics.setColor(0, 0, 0, 0.85 * state.titleAlpha)
        for _, o in ipairs({ {2, 0}, {-2, 0}, {0, 2}, {0, -2}, {3, 3} }) do
            love.graphics.print(title, -tw / 2 + o[1], o[2])
        end
        -- GLITCH de sinal: cópias R/C deslocadas enquanto o sinal assenta
        if state.titleGlitchT > 0 then
            local gk = state.titleGlitchT / 0.15
            local off = 3 + math.floor(love.timer.getTime() * 60) % 2 * 2
            love.graphics.setColor(1, 0.2, 0.2, 0.55 * gk * state.titleAlpha)
            love.graphics.print(title, -tw / 2 - off, 0)
            love.graphics.setColor(0.2, 1, 1, 0.55 * gk * state.titleAlpha)
            love.graphics.print(title, -tw / 2 + off, 0)
        end
        local g = Palette.AGED_GOLD_LIGHT
        local pulse = 1 + 0.08 * math.sin(state.splashTime * 3)
        love.graphics.setColor(math.min(1, g[1] * pulse), math.min(1, g[2] * pulse),
            g[3], state.titleAlpha)
        love.graphics.print(title, -tw / 2, 0)
        love.graphics.pop()
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
    state.vortex = 0
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
