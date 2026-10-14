local Debug = require("src.core.Debug")

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

local QUEUE = "boot"

local state = {
    phase           = "loading",
    loadingProgress = 0,
    loadingTime     = 0,
    onComplete      = nil,

    splashTime      = 0,
    miniCards       = {},
    flashAlpha      = 0,
    skipped         = false,
    bgAlpha         = 0,

    staticAlpha     = 0,

    sealCharge      = 0,
    titleLetters    = {},
}

local MINI_SIZE   = { w = 56, h = 84 }
local NUM_MINI    = 34

local PHYS = {
    pullG     = 2.6e6,
    pullPow   = 1.25,
    drag      = 0.35,
    captureR  = 0.55,
    maxLife   = 3.2,
    chiralCCW = 0.82,
    lifeMin   = 1.05, lifeMax = 1.75,
}
local SHARDS_ON_ABSORB = true

local rng = love.math.newRandomGenerator(1)
local function rnd(a, b)
    if a == nil then return rng:random() end
    return a + (b - a) * rng:random()
end

local bg = {
    dir = "assets/sprites/scenes/boot_anim",
    chamber = nil, loaded = false, glowShader = nil,
}

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
        local qx = math.floor(sh.x / px) * px
        local qy = math.floor(sh.y / px) * px
        local c = sh.tone > 0.5 and g or pl
        love.graphics.setColor(c[1], c[2], c[3], (1 - k) * 0.95)
        love.graphics.rectangle("fill", qx, qy, px, px)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local SIGIL_IX, SIGIL_IY = 179, 40
local SEAL_RADIUS_IMG = 30

local function chamberAnchor(ix, iy)
    if bg._s then
        return bg._tx + ix * bg._s, bg._ty + iy * bg._s
    end
    local W, H = love.graphics.getDimensions()
    return W * 0.5, H * 0.5
end

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
    else Debug.warn("[boot] boot_seal_glow falhou: " .. tostring(sh)) end
    local okT, shT = pcall(love.graphics.newShader, "shaders/boot_star_twinkle.glsl")
    if okT then bg.twinkleShader = shT
    else Debug.warn("[boot] boot_star_twinkle falhou: " .. tostring(shT)) end
    local okV, shV = pcall(love.graphics.newShader, "shaders/boot_moon_vortex.glsl")
    if okV then bg.vortexShader = shV
    else Debug.warn("[boot] boot_moon_vortex falhou: " .. tostring(shV)) end
    local p = bg.dir .. "/frame_00.png"
    if love.filesystem.getInfo(p) then
        local ok2, img = pcall(love.graphics.newImage, p)
        if ok2 then img:setFilter("nearest", "nearest"); bg.chamber = img end
    end
    local pc = bg.dir .. "/clouds.png"
    if love.filesystem.getInfo(pc) then
        local ok3, img = pcall(love.graphics.newImage, pc)
        if ok3 then img:setFilter("nearest", "nearest"); bg.clouds = img end
    end
end

local function drawClouds()
    if not bg.clouds or not bg._s then return end
    local t = love.timer.getTime()
    local s = bg._s
    local layerW = bg.clouds:getWidth() * s
    local W = love.graphics.getWidth()
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
    bg.twinkleShader:send("sky_limit", 84.0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg.chamber, bg._tx, bg._ty, 0, bg._s, bg._s)
    love.graphics.setShader()
    love.graphics.setBlendMode(prev)
    love.graphics.setColor(1, 1, 1, 1)
end

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
    state.seed = callbacks.seed or tonumber(os.getenv("BOOT_SEED"))
        or (os.time() + math.floor((love.timer.getTime() * 1000) % 100000))
    state.absorbed = 0
    rng:setSeed(state.seed)
    Debug.log(("[boot] semente do redemoinho: %d"):format(state.seed))

    if _G.EventManager then
        _G.EventManager.parallelEase(state, "bgAlpha", 1, 0.4, "smooth", QUEUE)
    else
        state.bgAlpha = 1
    end

    local intro = callbacks.intro
    if intro == nil then intro = not _G.HEADLESS_TOOL end
    if intro then
        state.phase = "intro"
        if callbacks.onIntroStart then callbacks.onIntroStart() end
        IntroTube.init({ onDone = function()
            state.phase = "loading"
            BootScene._tubeOn()
        end })
    else
        BootScene._tubeOn()
    end
end

function BootScene._tubeOn()
    if state.onTubeOn then state.onTubeOn() end
    Sfx.play("bootTvPowerOn")
end

local function liveCenter()
    return love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
end

local function startSplashSequence()
    state.phase = "splash"
    state.splashTime = 0

    state.staticAlpha = 0.85
    if _G.EventManager then
        _G.EventManager.parallelEase(state, "staticAlpha", 0, 0.55, "smooth", QUEUE)
        _G.EventManager.parallelEase(state, "sealCharge", 1.0, 2.0, "smooth", QUEUE)
    else
        state.staticAlpha = 0
        state.sealCharge = 1.0
    end

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

    EM.parallel(1.50, function() Sfx.play("bootVortex") end, QUEUE)

    EM.parallel(1.75, function() Sfx.play("bootCardWhoosh") end, QUEUE)

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
        local angle0 = rnd(0, math.pi * 2)
        local side = (rng:random() < PHYS.chiralCCW) and chir or -chir
        local tang = rnd(0.55, 1.0)
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
            local dx, dy = math.cos(angle0), math.sin(angle0)
            local margin = 70
            local tExit = math.huge
            if dx > 1e-6 then tExit = math.min(tExit, (W + margin - sx) / dx)
            elseif dx < -1e-6 then tExit = math.min(tExit, (-margin - sx) / dx) end
            if dy > 1e-6 then tExit = math.min(tExit, (H + margin - sy) / dy)
            elseif dy < -1e-6 then tExit = math.min(tExit, (-margin - sy) / dy) end
            if tExit == math.huge then tExit = math.max(W, H) * 0.7 end
            local r0 = tExit + 10
            local K = H / 768
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
    local tCascadeEnd = lastSpawn + 1.50

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
        sigil.flare = 1
    end, QUEUE)

    EM.parallel(tFlash + 0.60, function() BootScene._finish() end, QUEUE)
end

function BootScene.update(dt)
    if state.phase == "done" then return end
    if state.phase == "intro" then IntroTube.update(dt) return end

    updateSigil(dt)

    if state.phase == "loading" then
        state.loadingTime = state.loadingTime + dt
        local t = math.min(1, state.loadingTime / 0.5)
        state.loadingProgress = t

        if t >= 1 then
            startSplashSequence()
        end
    elseif state.phase == "splash" then
        state.splashTime = state.splashTime + dt

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
            local a = PHYS.pullG * K * K / (rr ^ PHYS.pullPow)
            mc.vx = mc.vx + (ddx / math.max(r, 1)) * a * dt
            mc.vy = mc.vy + (ddy / math.max(r, 1)) * a * dt
            local dr = PHYS.drag * (1 + 2.5 * math.max(0, 1 - r / (moonR * 3)))
            mc.vx = mc.vx * math.max(0, 1 - dr * dt)
            mc.vy = mc.vy * math.max(0, 1 - dr * dt)
            mc.x, mc.y = mc.x + mc.vx * dt, mc.y + mc.vy * dt
            local u = math.min(1, mc.age / mc.life)
            local rEnv = mc.r0 * (1 - u ^ mc.envPow)
            local ex, ey = sx - mc.x, sy - mc.y
            local rNow = math.sqrt(ex * ex + ey * ey)
            if rNow > rEnv and rNow > 1 then
                local k = rEnv / rNow
                mc.x, mc.y = sx - ex * k, sy - ey * k
                local nx, ny = ex / rNow, ey / rNow
                local vr = mc.vx * nx + mc.vy * ny
                if vr < 0 then mc.vx, mc.vy = mc.vx - vr * nx, mc.vy - vr * ny end
            end
            r = rNow
            if r < moonR * 1.2 then mc.passed = true end

            mc.spinV = mc.spinV * math.max(0, 1 - 0.9 * dt)
            mc.spin = mc.spin + mc.spinV * dt
            local head = math.atan2(mc.vy, mc.vx) + math.pi / 2
            mc.rot = head + mc.spin

            local pop = math.min(1, mc.age / 0.12)
            pop = pop * pop * (3 - 2 * pop)
            local rk = math.min(1, r / (mc.r0 * 0.6))
            mc.scale = pop * mc.scale0 * (0.22 + 0.78 * rk ^ 0.8)

            mc.fadeMul = r < moonR and math.max(0.15, r / moonR) or 1

            mc._trailT = mc._trailT + dt
            if mc._trailT >= 0.03 then
                mc._trailT = 0
                table.insert(mc.trail, 1, { x = mc.x, y = mc.y, rot = mc.rot, scale = mc.scale })
                if #mc.trail > 5 then table.remove(mc.trail) end
            end

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
    drawChamberBG()
    drawStarTwinkle()
    if state.phase == "splash" then
        drawMoonVortex(state.splashTime,
            state.sealCharge * 0.75 + 0.5 * sigil.flare)
    end
    drawClouds()
    if state.phase == "splash" then
        local breath = 0.34 + 0.14 * math.sin(love.timer.getTime() * 1.8)
        drawSealCharge(state.sealCharge * breath + 0.66 * sigil.flare)
    end

    if state.bgAlpha < 1 then
        love.graphics.setColor(0, 0, 0, 1 - state.bgAlpha)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

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

    TvOsd.staticNoise(0.25 * state.bgAlpha)
end

local function drawCardShape(x, y, w, h, alpha, scale, rot, dissolveAmount)
    local t = love.timer.getTime()
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

    for _, mc in ipairs(state.miniCards) do
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
    love.graphics.setShader()
    drawShards()

    if #state.titleLetters > 0 then
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
        TvOsd.staticNoise(state.staticAlpha)
        drawSkipHint()
    end

    do
        local W = love.graphics.getWidth()
        local tag = "AV-1"
        TvOsd.text(tag, W - TvOsd.textWidth(tag) - 26, 20, 0.9 * state.bgAlpha)
    end

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
    if _G.audioSystem and _G.audioSystem.stopGroup then
        _G.audioSystem:stopGroup("sfx")
    end
    if state.onComplete then state.onComplete() end
end

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
