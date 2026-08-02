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
    miniCards       = {},          -- array de {x, y, tx, ty, scale, alpha, rot}
    flashAlpha      = 0,
    skipped         = false,
    bgAlpha         = 0,           -- fade-in do background

    -- v2 "sintonizando o canal" (docs/plan/menu-crt-v2.md):
    staticAlpha     = 0,           -- chuvisco resolvendo na cena

    -- v6: energia arcana (plasma mascarado sobre a câmara) + título letra-a-letra
    sealCharge      = 0,           -- 0..1 carga do selo (entalhes acendendo)
    titleLetters    = {},          -- { {ch, alpha, scale}, ... }
}

-- Tamanhos lógicos (em pixels da janela; LÖVE escala automaticamente).
local LOADING_BAR = { w = 320, h = 18, pad = 2 }
local MINI_SIZE   = { w = 56, h = 84 }
local NUM_MINI    = 22

-- Diagonal ratio do spawn radius das mini-cartas (baseado em max(W,H)).
-- 0.7 = bordas extremas, faz o voo parecer "vindo de longe".
local SPAWN_RADIUS_RATIO = 0.7

-- ============== Fundo "PAREDE-SELO" (v9, Jul/2026) ==============
-- Feedback do dono consolidado: nada de plasma do Balatro por cima, nada de
-- partículas/glow de motor, nada de elemento que implore animação. Composição:
--   1. PAREDE-SELO pixel art (frame_00: pedra escura + selo entalhado, estática
--      por natureza — sem tochas/fogo) = o fundo.
--   2. CARGA DO SELO (boot_seal_glow.glsl): a PRÓPRIA arte redesenhada em
--      blend aditivo — só os entalhes/inlay dentro do disco acendem; respira,
--      pulsa por carta absorvida (flare) e estoura no flash. O glow É a arte.
local bg = {
    dir = "assets/sprites/scenes/boot_anim",
    chamber = nil, loaded = false, glowShader = nil,
}

-- ÂNCORA NA ARTE (pixels da imagem 256×192). A arte é a NOITE DO GRIMOIRE
-- (v10, PixelLab): colinas + silhueta do castelo + LUA dourada. A lua é o
-- coração: destino das cartas e o que "carrega" (halo respira/pulsa).
-- Centro do DISCO medido com threshold alto (o centroide anterior misturava
-- estrelas): (179, 40); raio útil ~30 (disco + halo) — as cartas caem DENTRO
-- da lua (feedback: "centralizar pra ficar realmente dentro").
local SIGIL_IX, SIGIL_IY = 179, 40
local SEAL_RADIUS_IMG = 30   -- raio do halo em px da imagem

-- Converte pixel da arte → tela, usando o transform do último draw (cover).
-- A âncora fica COLADA na arte em qualquer resolução/aspect.
local function chamberAnchor(ix, iy)
    if bg._s then
        return bg._tx + ix * bg._s, bg._ty + iy * bg._s
    end
    local W, H = love.graphics.getDimensions()
    return W * 0.5, H * 0.5   -- fallback sem arte (selo centrado)
end

-- Pulso de absorção do selo (0..1, decai): alimenta o uniform `flare` do
-- shader — a energia clareia POR DENTRO. Nada é desenhado por cima da arte
-- (os anéis/glows/partículas antigos saíram — feedback: "ridículo").
local sigil = { flare = 0 }

local function bumpSigil()
    sigil.flare = math.min(1, sigil.flare + 0.30)
end

local function updateSigil(dt)
    sigil.flare = math.max(0, sigil.flare - dt * 1.6)
end

local function loadBg()
    if bg.loaded then return end
    bg.loaded = true
    local ok, sh = pcall(love.graphics.newShader, "shaders/boot_seal_glow.glsl")
    if ok then bg.glowShader = sh
    else print("[boot] boot_seal_glow falhou: " .. tostring(sh)) end
    local okT, shT = pcall(love.graphics.newShader, "shaders/boot_star_twinkle.glsl")
    if okT then bg.twinkleShader = shT
    else print("[boot] boot_star_twinkle falhou: " .. tostring(shT)) end
    local okV, shV = pcall(love.graphics.newShader, "shaders/boot_moon_vortex.glsl")
    if okV then bg.vortexShader = shV
    else print("[boot] boot_moon_vortex falhou: " .. tostring(shV)) end
    local p = bg.dir .. "/frame_00.png"
    if love.filesystem.getInfo(p) then
        local ok2, img = pcall(love.graphics.newImage, p)
        if ok2 then img:setFilter("nearest", "nearest"); bg.chamber = img end
    end
    -- Nuvens em PARALLAX (opcional — v10 "noite do Grimoire"): camada com
    -- transparência que desliza devagar sobre o céu. Se o PNG não existe
    -- (arte ainda não gerada), o fundo funciona sem nuvens.
    local pc = bg.dir .. "/clouds.png"
    if love.filesystem.getInfo(pc) then
        local ok3, img = pcall(love.graphics.newImage, pc)
        if ok3 then img:setFilter("nearest", "nearest"); bg.clouds = img end
    end
end

-- Camada 1b: nuvens deslizando em 2 profundidades (animação clássica de
-- pixel art — suave por natureza, zero flicker). A arte tem margens vazias,
-- então o wrap horizontal não mostra emenda. Velocidades em px da ARTE por
-- segundo (bem lentas — céu noturno, não vendaval).
local function drawClouds()
    if not bg.clouds or not bg._s then return end
    local t = love.timer.getTime()
    local s = bg._s
    local layerW = bg.clouds:getWidth() * s
    local W = love.graphics.getWidth()
    -- Offsets medidos da arte: conteúdo das nuvens vive em y 23..103 do canvas
    -- 256×128 → iy -16/-2 coloca as duas camadas na faixa do CÉU (as nuvens
    -- cruzam a lua de vez em quando — clássico de noite; borda inferior da
    -- camada 2 encosta de leve nos cumes a alpha baixo, lê como névoa).
    for _, L in ipairs({
        { spd = 2.2, iy = -16, a = 0.75, flip = false },
        { spd = 3.8, iy = -2,  a = 0.45, flip = true },
    }) do
        local x0 = -((t * L.spd * s) % layerW)
        local y = bg._ty + L.iy * s
        love.graphics.setColor(1, 1, 1, L.a)
        for k = 0, 1 + math.ceil(W / layerW) do
            local x = x0 + k * layerW
            if L.flip then
                love.graphics.draw(bg.clouds, x + layerW, y, 0, -s, s)
            else
                love.graphics.draw(bg.clouds, x, y, 0, s, s)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
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

-- Camada 1c: CINTILAÇÃO das estrelas (v11) — cada estrela pisca no próprio
-- ritmo (shader boot_star_twinkle, aditivo sobre a própria arte). Lua e
-- colinas excluídas no shader. Pergunta do dono ("dá pra animar os pontinhos?")
-- respondida: dá, e é isto.
local function drawStarTwinkle()
    if not bg.chamber or not bg.twinkleShader or not bg._s then return end
    local gx, gy = chamberAnchor(SIGIL_IX, SIGIL_IY)
    local prev = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    love.graphics.setShader(bg.twinkleShader)
    bg.twinkleShader:send("t", love.timer.getTime())
    bg.twinkleShader:send("moon_center", { gx, gy })
    bg.twinkleShader:send("moon_radius", SEAL_RADIUS_IMG * bg._s)
    bg.twinkleShader:send("art_off", { bg._tx, bg._ty })
    bg.twinkleShader:send("art_scale", bg._s)
    bg.twinkleShader:send("sky_limit", 84.0)   -- y da arte onde começam as colinas
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg.chamber, bg._tx, bg._ty, 0, bg._s, bg._s)
    love.graphics.setShader()
    love.graphics.setBlendMode(prev)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Camada 1d: REDEMOINHO NA LUA (v12) — os PRÓPRIOS pixels do disco giram
-- (forte no miolo, zero na borda: emenda invisível com a arte parada).
-- Justifica a sucção das cartas: a lua é um portal se agitando. t = tempo
-- do splash (bounded); strength = carga + flare.
local function drawMoonVortex(t, strength)
    if not bg.chamber or not bg.vortexShader or not bg._s then return end
    if (strength or 0) < 0.02 then return end
    local iw, ih = bg.chamber:getDimensions()
    love.graphics.setShader(bg.vortexShader)
    bg.vortexShader:send("t", t or 0)
    bg.vortexShader:send("moon_uv", { SIGIL_IX / iw, SIGIL_IY / ih })
    bg.vortexShader:send("tex_size", { iw, ih })
    bg.vortexShader:send("radius_px", SEAL_RADIUS_IMG)
    bg.vortexShader:send("strength", math.min(1, strength))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg.chamber, bg._tx, bg._ty, 0, bg._s, bg._s)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Camada 2: CARGA DO SELO (v9). O plasma derivado do Balatro FOI EMBORA
-- ("o efeito que fica em cima ainda não tá bom"). No lugar: a PRÓPRIA ARTE
-- redesenhada em blend aditivo com o shader boot_seal_glow — só os pixels
-- claros (entalhes/inlay) dentro do disco do selo acendem. O glow É a arte:
-- pixel-nativo, sem material estranho por cima.
local function drawSealCharge(strength)
    if not bg.chamber or not bg.glowShader or (strength or 0) < 0.01 then return end
    if not bg._s then return end
    local gx, gy = chamberAnchor(SIGIL_IX, SIGIL_IY)
    local prev = love.graphics.getBlendMode()
    love.graphics.setBlendMode("add")
    love.graphics.setShader(bg.glowShader)
    bg.glowShader:send("center", { gx, gy })
    bg.glowShader:send("radius", SEAL_RADIUS_IMG * bg._s)
    bg.glowShader:send("strength", math.min(1, strength))
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg.chamber, bg._tx, bg._ty, 0, bg._s, bg._s)
    love.graphics.setShader()
    love.graphics.setBlendMode(prev)
    love.graphics.setColor(1, 1, 1, 1)
end

-- (v8: drawSigilGlow/drawChamberLife/embers REMOVIDOS — feedback do dono:
-- "tire essas partículas de faísca e de luz, está ficando bem ridículo".
-- v9: o plasma boot_splash.glsl também saiu — resposta visual = carga do selo.)

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
    state.sealCharge      = 0
    state.titleLetters    = {}
    state.onComplete      = callbacks.onComplete
    sigil.flare           = 0

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
        -- O selo CARREGA devagar (entalhes acendendo ao longo de 2s).
        _G.EventManager.parallelEase(state, "sealCharge", 1.0, 2.0, "smooth", QUEUE)
    else
        state.staticAlpha = 0
        state.sealCharge = 1.0
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

    local EM = _G.EventManager
    if not EM then
        BootScene.skip()
        return
    end

    -- IMPORTANTE: tudo abaixo usa parallel/parallelEase porque queremos
    -- timeline ABSOLUTO (vários eventos simultâneos), não sequencial.
    --
    -- v11 (feedback do dono): SEM carta central — a cena abre CONTEMPLATIVA
    -- (~1.8s só de noite: estrelas cintilando, nuvens andando, lua acordando)
    -- antes de qualquer carta. Nada "já começa dentro da lua".

    -- 1.50s: a LUA desperta (rumble grave — o portal vai abrir).
    EM.parallel(1.50, function() Sfx.play("bootVortex") end, QUEUE)

    -- 1.80s+: REDEMOINHO de cartas na lua, staggered 0.08s (janela ~1.7s).
    --   - Coords em POLAR (angle, distFrom) a partir do centro da lua.
    --   - Voa com ease_OUT (decelera ao chegar); TODAS orbitam no MESMO
    --     sentido e aceleram perto do centro → lê como furacão/redemoinho
    --     entrando na lua (não espirais aleatórias).
    --   - Scale pop-in → collapse no centro (sucção). Computado em update.
    -- 1.75s: WHOOSH grave da massa de cartas convergindo.
    EM.parallel(1.75, function() Sfx.play("bootCardWhoosh") end, QUEUE)

    -- v13 REDEMOINHO DE VERDADE (feedback: "não está tão bom, precisa ser
    -- mais bem feito"). O voo antigo era um ease radial com ~1 rad de arco:
    -- lia como riscos retos convergindo. Agora a cinemática é de DRENO:
    --   • raio: r = R·(1 − u^1.7) — parte lenta e majestosa, ACELERA ao
    --     cair (matéria despencando no portal), não o contrário;
    --   • giro: θ = θ0 + swirl·u^2.2 — o enrolar APERTA perto da lua
    --     (quase todo o arco acontece no mergulho final);
    --   • braços de GALÁXIA: cartas em cadeia (θ0 = base + i·0.7), não
    --     ângulos aleatórios — o fluxo lê como correnteza entrando;
    --   • orientação: a carta SURFA a tangente da espiral (rot = θ+90°
    --     com wobble sutil), nada de tumble aleatório;
    --   • escala/alpha: pop-in no nascimento, encolhe com o raio, e o
    --     fade final acontece DENTRO do disco (some na luz, não no ar).
    local armBase = math.random() * math.pi * 2
    for i = 1, NUM_MINI do
        local delay = 1.80 + (i - 1) * 0.09
        EM.parallel(delay, function()
            local W, H = love.graphics.getWidth(), love.graphics.getHeight()
            -- v13.1: raio ~0.42 da tela — o voo INTEIRO acontece em cena
            -- (0.7 deixava as cartas fora da tela na maior parte da vida;
            -- a cena ficava esparsa — revisão por captura)
            local radius = math.max(W, H) * 0.42

            local mc = {
                angle0   = armBase + i * 0.7 + (math.random() - 0.5) * 0.18,
                swirl    = math.pi * (1.5 + math.random() * 0.5),
                radius   = radius * (0.90 + math.random() * 0.18),
                angle    = 0,      -- derivado no update (θ0 + swirl·u^2.2)
                dist     = radius,
                rot      = 0,      -- derivado (tangente da espiral)
                wobble   = math.random() * math.pi * 2,
                alpha    = 0,
                fadeMul  = 1,
                scale    = 0,
                age      = 0,
                lifespan = 1.05 + math.random() * 0.30, -- voo com pompa
                trail    = {},   -- rastro de fósforo (ghosting CRT)
                _trailT  = 0,
                _alive   = true,
            }
            mc.angle = mc.angle0
            table.insert(state.miniCards, mc)

            -- Alpha sobe nos primeiros 0.15s (materializa na borda).
            EM.parallelEase(mc, "alpha", 1.0, 0.15, "smooth", QUEUE)

            local pitch = 0.85 + i * 0.022
            Sfx.play("cardDraw", { pitch = pitch, volume = 0.42 })
        end, QUEUE)
    end
    -- fim da cascade: último spawn + voo mais longo (~1.35s)
    local tCascadeEnd = 1.80 + (NUM_MINI - 1) * 0.09 + 1.40

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
        sigil.flare = 1   -- o selo estoura junto com o flash (conexão)
    end, QUEUE)

    -- transição pro menu (depois do flash desbotar).
    EM.parallel(tFlash + 0.60, function() BootScene._finish() end, QUEUE)
end

-- ============== Update / Draw ==============

function BootScene.update(dt)
    if state.phase == "done" then return end

    updateSigil(dt)    -- pulso de absorção decai

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
            local u = math.min(1, mc.age / mc.lifespan)

            -- v13 DRENO: raio desaba com u^1.7 (lento no início, DESPENCA
            -- no fim) e o giro aperta com u^2.2 (o arco acontece perto da
            -- lua — enrolar de redemoinho, não deriva constante).
            local rk = 1 - u ^ 1.5
            mc.dist = mc.radius * rk
            mc.angle = mc.angle0 + mc.swirl * (u ^ 2.2)

            -- orientação: SURFA a tangente da espiral + wobble respirando
            mc.rot = mc.angle + math.pi / 2
                + math.sin(mc.age * 3 + mc.wobble) * 0.14

            -- escala: pop-in nos primeiros 12%, depois ENCOLHE com o raio
            -- (afundando no portal); nunca o colapso brusco antigo.
            local pop = math.min(1, u / 0.12)
            pop = pop * pop * (3 - 2 * pop)
            mc.scale = pop * (0.30 + 0.70 * rk ^ 0.9)

            -- fade final DENTRO do disco (últimos 15% — some na luz antes
            -- de "sentar" parada no miolo)
            mc.fadeMul = u > 0.85 and math.max(0, 1 - (u - 0.85) / 0.15) or 1

            -- Rastro de FÓSFORO (ghosting de tubo CRT): amostra a pose a
            -- cada ~30ms, 5 fantasmas — no mergulho final vira um ARCO
            -- luminoso seguindo a espiral.
            mc._trailT = mc._trailT + dt
            if mc._trailT >= 0.03 then
                mc._trailT = 0
                table.insert(mc.trail, 1, { angle = mc.angle, dist = mc.dist,
                    rot = mc.rot, scale = mc.scale })
                if #mc.trail > 5 then table.remove(mc.trail) end
            end

            -- Mini-carta chegou: ABSORVIDA pelo selo — pulso de brilho na
            -- energia (dentro do shader; o destino responde).
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
    -- CAMADAS: paisagem pixel (base) → estrelas cintilando → nuvens em
    -- parallax (passam NA FRENTE das estrelas) → CARGA da lua (halo
    -- respirando + pulso por carta absorvida).
    drawChamberBG()
    drawStarTwinkle()
    if state.phase == "splash" then
        -- redemoinho ANTES das nuvens (elas passam na frente da lua)
        drawMoonVortex(state.splashTime,
            state.sealCharge * 0.75 + 0.5 * sigil.flare)
    end
    drawClouds()
    if state.phase == "splash" then
        local breath = 0.34 + 0.14 * math.sin(love.timer.getTime() * 1.8)
        drawSealCharge(state.sealCharge * breath + 0.66 * sigil.flare)
    end

    -- Fade-in mask (escurece o que tem por baixo enquanto bgAlpha sobe).
    if state.bgAlpha < 1 then
        love.graphics.setColor(0, 0, 0, 1 - state.bgAlpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Preview do fundo completo pro tool de validação (screenshot_bootfx):
-- desenha todas as camadas num instante t, com flare forçado.
function BootScene.previewBackground(t, charge, flare)
    loadBg()
    sigil.flare = flare or 0
    drawChamberBG()
    drawStarTwinkle()
    drawMoonVortex(t, (charge or 0) * 0.75 + 0.5 * sigil.flare)
    drawClouds()
    local breath = 0.34 + 0.14 * math.sin((t or 0) * 1.8)
    drawSealCharge((charge or 0) * breath + 0.66 * sigil.flare)
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
    -- (angle, distFrom) a partir do selo — âncora live, resize não quebra.
    -- Cada carta arrasta um rastro de FÓSFORO (ghosting CRT): fantasmas da
    -- pose recente com alpha decaindo — velho primeiro, carta por cima.
    for _, mc in ipairs(state.miniCards) do
        -- 5 fantasmas com falloff acentuado: o velho quase some — o rastro
        -- lê como arco de luz na espiral, não como carta duplicada.
        local ghostA = { 0.26, 0.17, 0.11, 0.06, 0.035 }
        for gi = #mc.trail, 1, -1 do
            local g = mc.trail[gi]
            local gx = sx + math.cos(g.angle) * g.dist
            local gy = sy + math.sin(g.angle) * g.dist
            drawCardShape(gx, gy, MINI_SIZE.w, MINI_SIZE.h,
                mc.alpha * mc.fadeMul * (ghostA[gi] or 0.03),
                g.scale * 0.97, g.rot, 0)
        end
        local x = sx + math.cos(mc.angle) * mc.dist
        local y = sy + math.sin(mc.angle) * mc.dist
        drawCardShape(x, y, MINI_SIZE.w, MINI_SIZE.h,
            mc.alpha * mc.fadeMul, mc.scale, mc.rot, 0)
    end

    -- (v11: a carta central FOI REMOVIDA — feedback do dono: "pode deixar
    -- direto já no ponto focal da lua". A cena abre contemplativa e o
    -- redemoinho entra sozinho.)

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
    state.flashAlpha = 0
    state.titleLetters = {}
    sigil.flare = 0
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
