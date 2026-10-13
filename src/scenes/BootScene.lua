-- src/scenes/BootScene.lua
-- Splash + loading bar inicial. Inspirado em balatro-source/game.lua:1373-1515
-- (Game:splash_screen) mas escala mais minimalista — 12 cartas em vez de 200,
-- e usamos o PNG de splash como background em vez de vortex shader.
--
-- Fases internas:
--   "intro"   (~5s)   — ABERTURA (Out/2026, IntroTube): página de pergaminho
--                       com o televisor pequeno datilografando o título;
--                       mergulha no tubo e só então o CRT de tela cheia liga
--                       (callbacks.onTubeOn). Desligada em tools/testes
--                       (callbacks.intro = false, default sob HEADLESS_TOOL).
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
local FontManager     = require("src.ui.FontManager")
local SceneBackground = require("src.ui.SceneBackground")
local I18n            = require("src.i18n.I18n")
local Sfx             = require("src.systems.Sfx")
local FlashShader     = require("src.ui.FlashShader")
local CardBack        = require("src.ui.CardBack")
local TvOsd           = require("src.ui.TvOsd")
local IntroTube       = require("src.scenes.IntroTube")

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
local MINI_SIZE   = { w = 56, h = 84 }
local NUM_MINI    = 34

-- v14 (Out/2026, dono: "as cartas entram coordenadas demais, pouco
-- aleatórias"): o redemoinho deixou de ser uma curva paramétrica igual pra
-- todas (stagger fixo 0.075 s, ângulos em cadeia i·0.7, mesmo expoente) e
-- virou FÍSICA por carta, SEMEADA por boot:
--   • nascimento em rajadas (intervalos exponenciais + pausas ocasionais);
--   • lançamento tangencial com velocidade/quiralidade/entrada próprias;
--   • atração da lua ∝ 1/r^PULL_POW + arrasto → espiral que aperta sozinha,
--     cada carta com a sua (algumas passam raspando, outras caem reto);
--   • giro próprio amortecido somado à tangente; escala própria;
--   • leve OVERSHOOT: a carta passa um pouco do centro antes de ser puxada
--     de volta e absorvida (nada de colapso seco no ponto);
--   • absorção solta LASCAS na grade de pixels da arte (4-7 quadradinhos
--     do tamanho de 1 px da arte, vida curta) — pixel-nativo, sem glow.
-- A semente é guardada em state.seed (log no console; BOOT_SEED força).
local PHYS = {
    pullG     = 2.6e6,   -- força da lua (px/s² · r^pow) — escala com a tela
    pullPow   = 1.25,    -- expoente do falloff (1 = gravidade 2D, >1 aperta)
    drag      = 0.35,    -- arrasto longe (1/s); perto da lua sobe ×3.5
    captureR  = 0.55,    -- fração do raio da lua onde a carta é absorvida
    maxLife   = 3.2,     -- teto de voo (s) — nenhuma carta fica orbitando
    chiralCCW = 0.82,    -- fração que gira no sentido "da maioria"
    -- ENVELOPE: a física dá o giro orgânico; a chegada é GARANTIDA por um
    -- raio-teto r ≤ r0·(1 − u^pw) (u = idade/vida, pw sorteado por carta).
    -- Sem isso uma carta lançada rápido demais orbita ou foge da tela.
    lifeMin   = 1.05, lifeMax = 1.75,
}
local SHARDS_ON_ABSORB = true

-- RNG do boot (independente do RNG da run e do cosmético global).
local rng = love.math.newRandomGenerator(1)
local function rnd(a, b)
    if a == nil then return rng:random() end
    return a + (b - a) * rng:random()
end

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

-- Lascas da absorção: { x, y, vx, vy, age, life, tone }
local shards = {}
local function spawnShards(x, y, n)
    if not SHARDS_ON_ABSORB then return end
    local px = bg._s or 4
    for _ = 1, n do
        local a = rnd(0, math.pi * 2)
        local v = rnd(40, 130) * px / 4
        shards[#shards + 1] = {
            x = x, y = y, vx = math.cos(a) * v, vy = math.sin(a) * v,
            age = 0, life = rnd(0.22, 0.45), tone = rnd(),
        }
    end
end
local function updateShards(dt)
    for i = #shards, 1, -1 do
        local sh = shards[i]
        sh.age = sh.age + dt
        sh.x, sh.y = sh.x + sh.vx * dt, sh.y + sh.vy * dt
        sh.vx, sh.vy = sh.vx * (1 - 2.5 * dt), sh.vy * (1 - 2.5 * dt)
        if sh.age >= sh.life then table.remove(shards, i) end
    end
end
local function drawShards()
    if #shards == 0 then return end
    local px = bg._s or 4
    local g = Palette.AGED_GOLD_LIGHT
    local pl = Palette.PARCHMENT_LIGHT
    for _, sh in ipairs(shards) do
        local k = sh.age / sh.life
        -- na grade da arte: floor pra múltiplo do pixel da arte
        local qx = math.floor(sh.x / px) * px
        local qy = math.floor(sh.y / px) * px
        local c = sh.tone > 0.5 and g or pl
        love.graphics.setColor(c[1], c[2], c[3], (1 - k) * 0.95)
        love.graphics.rectangle("fill", qx, qy, px, px)
    end
    love.graphics.setColor(1, 1, 1, 1)
end



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
    state.onTubeOn        = callbacks.onTubeOn
    sigil.flare           = 0
    shards                = {}
    -- semente do boot: muda a cada abertura; BOOT_SEED (tools) fixa
    state.seed = callbacks.seed or tonumber(os.getenv("BOOT_SEED"))
        or (os.time() + math.floor((love.timer.getTime() * 1000) % 100000))
    state.absorbed = 0
    rng:setSeed(state.seed)
    print(("[boot] semente do redemoinho: %d"):format(state.seed))

    -- Background fade-in (não-bloqueante para não travar o resto).
    if _G.EventManager then
        _G.EventManager.parallelEase(state, "bgAlpha", 1, 0.4, "smooth", QUEUE)
    else
        state.bgAlpha = 1
    end

    -- ABERTURA antes da sintonia: página + televisor pequeno (IntroTube).
    -- Quando ela mergulha no tubo, o CRT de tela cheia LIGA (onTubeOn:
    -- main.lua reabilita o shader e dispara powerOn) e o loading começa.
    local intro = callbacks.intro
    if intro == nil then intro = not _G.HEADLESS_TOOL end
    if intro then
        state.phase = "intro"
        if callbacks.onIntroStart then callbacks.onIntroStart() end
        IntroTube.init({ onDone = function()
            state.phase = "loading"
            -- mergulho completo = o tubo já está aceso na tela (continuidade
            -- pixel a pixel); pulo/reducedMotion = liga do apagão como sempre
            BootScene._tubeOn(IntroTube.endedWithDive and IntroTube.endedWithDive() or false)
        end })
    else
        BootScene._tubeOn(false)
    end
end

-- A TV LIGANDO: som + warm-up do CRT (main.lua passa onTubeOn com o
-- CRTShader.powerOn(1.8): ponto → linha → abre → assenta). `seamless` =
-- veio do mergulho da abertura: o CRT liga já aceso, sem apagão.
function BootScene._tubeOn(seamless)
    if state.onTubeOn then state.onTubeOn(seamless and true or false) end
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
    -- v14: NASCIMENTO EM RAJADAS (intervalo exponencial, média 0.07 s, com
    -- pausa ocasional) — nada de metrônomo. Quiralidade da maioria sorteada
    -- por boot; cada carta recebe lançamento, giro e escala próprios.
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    local chir = rng:random() < 0.5 and 1 or -1
    local tSpawn = 1.80
    local lastSpawn = tSpawn
    local nCards = reduced and 0 or NUM_MINI
    for i = 1, nCards do
        if i > 1 then
            local gap = -math.log(1 - rng:random() * 0.98) * 0.07
            if rng:random() < 0.10 then gap = gap + rnd(0.18, 0.32) end
            tSpawn = tSpawn + math.min(0.45, gap)
        end
        lastSpawn = tSpawn
        local delay = tSpawn
        -- sorteios FORA do callback: a ordem dos eventos não muda a semente
        local angle0 = rnd(0, math.pi * 2)
        local side = (rng:random() < PHYS.chiralCCW) and chir or -chir
        local tang = rnd(0.55, 1.0)        -- quão tangencial é o lançamento
        local speedK = rnd(0.75, 1.25)
        local life = rnd(PHYS.lifeMin, PHYS.lifeMax)
        local envPow = rnd(1.3, 2.1)
        local spinV = rnd(-2.6, 2.6)
        local scale0 = rnd(0.82, 1.18)
        local sizeK = rnd(0.9, 1.12)
        local pitch = 0.85 + rnd(0, 0.5)
        EM.parallel(delay, function()
            local W, H = love.graphics.getWidth(), love.graphics.getHeight()
            local sx, sy = chamberAnchor(SIGIL_IX, SIGIL_IY)
            -- nasce logo além da borda da tela na direção do próprio ângulo
            local dx, dy = math.cos(angle0), math.sin(angle0)
            local margin = 70
            local tExit = math.huge
            if dx > 1e-6 then tExit = math.min(tExit, (W + margin - sx) / dx)
            elseif dx < -1e-6 then tExit = math.min(tExit, (-margin - sx) / dx) end
            if dy > 1e-6 then tExit = math.min(tExit, (H + margin - sy) / dy)
            elseif dy < -1e-6 then tExit = math.min(tExit, (-margin - sy) / dy) end
            if tExit == math.huge then tExit = math.max(W, H) * 0.7 end
            local r0 = tExit + 10
            local K = H / 768   -- a física escala com a tela
            -- velocidade inicial: tangente (quiralidade) + componente pra dentro
            local v0 = (170 + 160 * speedK) * K
            local tx, ty = -dy * side, dx * side
            local ix, iy = -dx, -dy
            local mc = {
                x = sx + dx * r0, y = sy + dy * r0,
                vx = (tx * tang + ix * (1 - tang) * 0.8) * v0,
                vy = (ty * tang + iy * (1 - tang) * 0.8) * v0,
                r0 = r0, K = K, life = life, envPow = envPow,
                spin = rnd(0, math.pi * 2) * 0.15, spinV = spinV,
                scale0 = scale0, sizeK = sizeK,
                rot = 0, scale = 0, alpha = 0, fadeMul = 1,
                age = 0, passed = false,
                trail = {}, _trailT = 0, _alive = true,
            }
            table.insert(state.miniCards, mc)
            EM.parallelEase(mc, "alpha", 1.0, 0.15, "smooth", QUEUE)
            Sfx.play("cardDraw", { pitch = pitch, volume = 0.42 })
        end, QUEUE)
    end
    -- fim da cascade: último nascimento + voo típico (~1.5 s)
    local tCascadeEnd = lastSpawn + 1.50

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
                if reduced then L.scale = 1
                else EM.parallelEase(L, "scale", 1.0, 0.30, "back_out", QUEUE) end
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
        if reduced then sigil.flare = 1; Sfx.play("bootImpact"); return end
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
    if state.phase == "intro" then IntroTube.update(dt) return end

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

        -- v14 FÍSICA por carta (ver PHYS): atração da lua + arrasto +
        -- giro amortecido. Coords ABSOLUTAS (a âncora da lua é lida por
        -- frame — resize não quebra). Absorção = raio de captura ou teto.
        local sx, sy = chamberAnchor(SIGIL_IX, SIGIL_IY)
        local moonR = SEAL_RADIUS_IMG * (bg._s or 4)
        local capR = moonR * PHYS.captureR
        for i = #state.miniCards, 1, -1 do
            local mc = state.miniCards[i]
            mc.age = mc.age + dt
            local K = mc.K or 1
            local ddx, ddy = sx - mc.x, sy - mc.y
            local r = math.sqrt(ddx * ddx + ddy * ddy)
            local rr = math.max(r, moonR * 0.6)
            -- atração ∝ 1/r^pow (K² porque força é px/s²)
            local a = PHYS.pullG * K * K / (rr ^ PHYS.pullPow)
            mc.vx = mc.vx + (ddx / math.max(r, 1)) * a * dt
            mc.vy = mc.vy + (ddy / math.max(r, 1)) * a * dt
            -- arrasto (mais forte perto da lua: a espiral aperta e assenta)
            local dr = PHYS.drag * (1 + 2.5 * math.max(0, 1 - r / (moonR * 3)))
            mc.vx = mc.vx * math.max(0, 1 - dr * dt)
            mc.vy = mc.vy * math.max(0, 1 - dr * dt)
            mc.x, mc.y = mc.x + mc.vx * dt, mc.y + mc.vy * dt
            -- ENVELOPE de chegada: raio-teto cai com u^pw; se a física
            -- deixou a carta além dele, ela é puxada radialmente pro teto
            -- (o giro fica, a chegada é garantida)
            local u = math.min(1, mc.age / mc.life)
            local rEnv = mc.r0 * (1 - u ^ mc.envPow)
            local ex, ey = sx - mc.x, sy - mc.y
            local rNow = math.sqrt(ex * ex + ey * ey)
            if rNow > rEnv and rNow > 1 then
                local k = rEnv / rNow
                mc.x, mc.y = sx - ex * k, sy - ey * k
                -- mata a componente radial pra fora (sem "elástico")
                local nx, ny = ex / rNow, ey / rNow
                local vr = mc.vx * nx + mc.vy * ny
                if vr < 0 then mc.vx, mc.vy = mc.vx - vr * nx, mc.vy - vr * ny end
            end
            r = rNow
            if r < moonR * 1.2 then mc.passed = true end

            -- orientação: surfa a velocidade + giro próprio amortecido
            mc.spinV = mc.spinV * math.max(0, 1 - 0.9 * dt)
            mc.spin = mc.spin + mc.spinV * dt
            local head = math.atan2(mc.vy, mc.vx) + math.pi / 2
            mc.rot = head + mc.spin

            -- escala: pop-in nos primeiros 0.12 s, depois encolhe com o raio
            local pop = math.min(1, mc.age / 0.12)
            pop = pop * pop * (3 - 2 * pop)
            local rk = math.min(1, r / (mc.r0 * 0.6))
            mc.scale = pop * mc.scale0 * (0.22 + 0.78 * rk ^ 0.8)

            -- fade final DENTRO do disco (some na luz, não no ar)
            mc.fadeMul = r < moonR and math.max(0.15, r / moonR) or 1

            -- Rastro de FÓSFORO (ghosting CRT): pose a cada ~30 ms, 5 fantasmas
            mc._trailT = mc._trailT + dt
            if mc._trailT >= 0.03 then
                mc._trailT = 0
                table.insert(mc.trail, 1, { x = mc.x, y = mc.y, rot = mc.rot, scale = mc.scale })
                if #mc.trail > 5 then table.remove(mc.trail) end
            end

            -- ABSORVIDA: dentro do raio de captura (ou teto de voo — nenhuma
            -- carta fica orbitando a lua pra sempre)
            if r < capR or mc.age >= mc.life + 0.4 or mc.age >= PHYS.maxLife then
                mc._alive = false
                table.remove(state.miniCards, i)
                state.absorbed = (state.absorbed or 0) + 1
                bumpSigil()
                spawnShards(sx, sy, math.floor(rnd(4, 8)))
            end
        end
        updateShards(dt)
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
    -- são visivelmente absorvidas por ele, que responde com flare + anéis
    -- (o alvo é lido por quem move cada carta, via chamberAnchor).

    -- Mini-cartas primeiro (z-order: ficam atrás da central). Coords em polar
    -- (angle, distFrom) a partir do selo — âncora live, resize não quebra.
    -- Cada carta arrasta um rastro de FÓSFORO (ghosting CRT): fantasmas da
    -- pose recente com alpha decaindo — velho primeiro, carta por cima.
    for _, mc in ipairs(state.miniCards) do
        -- 5 fantasmas com falloff acentuado: o velho quase some — o rastro
        -- lê como arco de luz na espiral, não como carta duplicada.
        local ghostA = { 0.26, 0.17, 0.11, 0.06, 0.035 }
        local cw, ch = MINI_SIZE.w * (mc.sizeK or 1), MINI_SIZE.h * (mc.sizeK or 1)
        for gi = #mc.trail, 1, -1 do
            local g = mc.trail[gi]
            drawCardShape(g.x, g.y, cw, ch,
                mc.alpha * mc.fadeMul * (ghostA[gi] or 0.03),
                g.scale * 0.97, g.rot, 0)
        end
        drawCardShape(mc.x, mc.y, cw, ch, mc.alpha * mc.fadeMul, mc.scale, mc.rot, 0)
    end
    -- lascas da absorção (grade da arte), por cima das cartas
    love.graphics.setShader()
    drawShards()

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
    if state.phase == "intro" then IntroTube.draw() return end

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
    if state.phase == "intro" then IntroTube.skip() end
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
    shards = {}
    -- SYNC (feedback): mata qualquer SFX de boot (raio/rumble/impacto) ANTES do
    -- menu + música entrarem — o barulho de raio vazava pro menu. stopGroup só
    -- corta o grupo "sfx"; a música (grupo "music") não é afetada.
    if _G.audioSystem and _G.audioSystem.stopGroup then
        _G.audioSystem:stopGroup("sfx")
    end
    if state.onComplete then state.onComplete() end
end

-- Pular na abertura pula SÓ a abertura (cai na sintonia); pular de novo
-- pula o boot inteiro.
function BootScene.keypressed(_)
    if state.phase == "intro" then IntroTube.skip() return end
    if state.phase ~= "done" then BootScene.skip() end
end

function BootScene.mousepressed(_, _, _)
    if state.phase == "intro" then IntroTube.skip() return end
    if state.phase ~= "done" then BootScene.skip() end
end

function BootScene.resize()
    if IntroTube.resize then IntroTube.resize() end
end

function BootScene.isDone() return state.phase == "done" end
function BootScene.seed() return state.seed end
function BootScene.cardsInFlight() return #state.miniCards end
function BootScene.absorbedCount() return state.absorbed or 0 end
function BootScene.cardPositions()
    local out = {}
    for i, mc in ipairs(state.miniCards) do out[i] = { mc.x, mc.y, mc.rot, mc.scale } end
    return out
end
function BootScene.splashTime() return state.splashTime end
function BootScene.phase() return state.phase end

return BootScene
