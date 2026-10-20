local Data            = require("src.data.boss_cinematics")
local I18n            = require("src.i18n.I18n")
local FontManager     = require("src.ui.FontManager")
local Sfx             = require("src.systems.Sfx")
local SpriteAnimation = require("src.ui.SpriteAnimation")
local EnemyRenderer   = require("src.ui.EnemyRenderer")
local EnemyPoses      = require("src.data.enemy_poses")
local InteriorFX      = require("src.ui.InteriorFX")
local DynaText        = require("src.ui.DynaText")

local BossCinematic = {}

BossCinematic.SKIP_AFTER = 1.0

BossCinematic.INTRO_KINDS = { dark = true, eyes = true, flyby = true, land = true,
                              title = true, hud = true,
                              runes = true, rise = true, whiteout = true, silhouette = true,
                              settle = true, door_burst = true, firewall = true, chains = true,
                              walk_in = true, heartbeat = true, roots = true, eclipse = true,
                              descend = true,
                              omen = true, unveil = true, coronation = true,
                              assemble = true }
BossCinematic.DEATH_KINDS = { slowmo = true, burst = true, desat = true, hold = true,
                              lava = true,
                              crumble = true,
                              dawn = true,
                              trophy = true }

local SOUNDS = {
    bossEyesIgnite     = { "audio/sfx/boss/boss_eyes_ignite.mp3",     0.70 },
    bossEyesRumble     = { "audio/sfx/boss/boss_eyes_rumble.mp3",     0.55, loop = true },
    bossBlinkClick     = { "audio/sfx/boss/boss_blink_click.mp3",     0.60 },
    bossWingPass       = { "audio/sfx/boss/boss_wing_pass.mp3",       0.80 },
    bossLandImpact     = { "audio/sfx/boss/boss_land_impact.mp3",     0.90 },
    bossFeathersSettle = { "audio/sfx/boss/boss_feathers_settle.mp3", 0.55 },
    bossRevealSting    = { "audio/sfx/boss/boss_reveal_sting.mp3",    0.50 },
    bossDeathThud      = { "audio/sfx/boss/boss_death_thud.mp3",      0.85 },
    bossFeatherBurst   = { "audio/sfx/boss/boss_feather_burst.mp3",   0.70 },
    bossHoldAmbience   = { "audio/sfx/boss/boss_hold_ambience.mp3",   0.45, loop = true },
    bossRuneIgnite     = { "audio/sfx/boss/boss_rune_ignite.mp3",      0.65 },
    bossFrostStorm     = { "audio/sfx/boss/boss_frost_storm.mp3",      0.60, loop = true },
    bossFrostShatter   = { "audio/sfx/boss/boss_frost_shatter.mp3",    0.80 },
    bossDoorBurst      = { "audio/sfx/boss/boss_door_burst.mp3",       0.90 },
    bossHellfireWall   = { "audio/sfx/boss/boss_hellfire_wall.mp3",    0.55, loop = true },
    bossChainsRattle   = { "audio/sfx/boss/boss_chains_rattle.mp3",    0.65 },
    bossLavaImplosion  = { "audio/sfx/boss/boss_lava_implosion.mp3",   0.85 },
    bossBlizzard       = { "audio/sfx/boss/boss_blizzard_whiteout.mp3", 0.60, loop = true },
    bossIceCrackle     = { "audio/sfx/boss/boss_ice_crackle.mp3",      0.70 },
    bossHeartbeat      = { "audio/sfx/boss/boss_heartbeat.mp3",        0.80 },
    bossRootsCrawl     = { "audio/sfx/boss/boss_roots_crawl.mp3",      0.55, loop = true },
    bossEmergeTear     = { "audio/sfx/boss/boss_emerge_tear.mp3",      0.85 },
    bossSporeCollapse  = { "audio/sfx/boss/boss_spore_collapse.mp3",   0.80 },
    bossEclipseHum     = { "audio/sfx/boss/boss_eclipse_hum.mp3",      0.55, loop = true },
    bossDescendWings   = { "audio/sfx/boss/boss_descend_wings.mp3",    0.75 },
    bossEclipseBreak   = { "audio/sfx/boss/boss_eclipse_break.mp3",    0.80 },
    bossEclipseOmen    = { "audio/sfx/boss/boss_eclipse_omen.mp3",    0.75 },
    bossEclipseUnveil  = { "audio/sfx/boss/boss_eclipse_unveil.mp3",  0.75 },
    bossCrownTick      = { "audio/sfx/boss/boss_crown_tick.mp3",      0.55 },
    bossEclipseCrown   = { "audio/sfx/boss/boss_eclipse_crown.mp3",   0.90 },
    bossEclipsePhase   = { "audio/sfx/boss/boss_eclipse_phase.mp3",   0.85 },
    bossEclipseFade    = { "audio/sfx/boss/boss_eclipse_fade.mp3",    0.80 },
    colossusAssemble   = { "audio/sfx/boss/colossus_assemble.mp3",     0.80 },
    colossusCrack      = { "audio/sfx/boss/colossus_crack.mp3",        0.85 },
    colossusCrumble    = { "audio/sfx/boss/colossus_crumble.mp3",      0.85 },
    monarchStrike      = { "audio/sfx/boss/monarch_strike.mp3",        0.85 },
    tyrantChainDrag    = { "audio/sfx/boss/tyrant_chain_drag.mp3",     0.70 },
    tyrantChainTaut    = { "audio/sfx/boss/tyrant_chain_taut.mp3",     0.80 },
    tyrantChainSnap    = { "audio/sfx/boss/tyrant_chain_snap.mp3",     0.85 },
    tyrantUnchained    = { "audio/sfx/boss/tyrant_unchained.mp3",      0.85 },
}
local soundsLoaded = false
BossCinematic.SOUNDS = SOUNDS

local seq = nil
local stage = nil
local dark = 0
local darkEase = nil
local eyes = nil
local fly = nil
local title = nil
local slowmo = nil
local desat = nil
local bossHidden = false
local hudHidden = false
local landed = false
local mist = nil
local mistGustDir = 1
local hit = nil
local edge = nil
local loops = {}
local sfxQueue = {}
local spawnMist
local DEFAULT_PALETTE = {
    body = { 0.22, 0.13, 0.38 }, glow = { 0.58, 0.36, 0.98 }, ember = { 1.00, 0.50, 0.16 },
    flash = { 0.72, 0.52, 1.00 }, ghost = { 0.56, 0.46, 0.86 }, rim = { 0.62, 0.50, 0.95 },
    particle = { 0.20, 0.16, 0.32 }, particle2 = { 0.58, 0.50, 0.90 },
}
local PAL = DEFAULT_PALETTE
local fx = {}
local flakes = {}
local ownAnims = {}
local deathFor = nil
local T3 = { bond = nil, free = nil, BT = require("src.ui.BossTokens") }
local eclipse = nil
local crownCard = nil
local hallEyes = nil
local flyAnim = nil
local flyAnimId = nil
local feathers, dust, crows, wind = {}, {}, {}, {}
local dummy = nil
local worldCanvas = nil
local desatShader = nil
local desatTried = false
local warnedKind = {}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function clamp01(x) return math.max(0, math.min(1, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function smooth(k) return k * k * (3 - 2 * k) end

local function loadSounds()
    if soundsLoaded then return end
    soundsLoaded = true
    require("src.systems.CrowSfx").load()
    local a = _G.audioSystem
    if not a or not a.loadSound then return end
    for code, spec in pairs(SOUNDS) do
        if not Sfx.has(code) and love.filesystem.getInfo(spec[1]) then
            a:loadSound(code, spec[1], { volume = spec[2], loop = spec.loop or false })
        end
    end
end

local function playLoop(code)
    if loops[code] then return end
    local a = _G.audioSystem
    if not a or not Sfx.has(code) then return end
    local src = a:play(code, { loop = true })
    if src then loops[code] = src end
end
local function stopLoop(code)
    local src = loops[code]
    if src then pcall(src.stop, src) end
    loops[code] = nil
end
local function stopAllLoops()
    for code in pairs(loops) do stopLoop(code) end
end
local function queueSfx(delay, code, fallback, pitch)
    sfxQueue[#sfxQueue + 1] = { t = delay, code = code, fallback = fallback, pitch = pitch }
end

local function play(code, fallback, pitch, pitchVar)
    local Crow = require("src.systems.CrowSfx")
    if Crow.handles(code) then
        Crow.play(code)
        return
    end
    local name = Sfx.has(code) and code or fallback
    if not name then return end
    if pitch then
        Sfx.playWithVariation(name, pitch, pitchVar or 0)
    else
        Sfx.play(name)
    end
end

function BossCinematic.data(id)
    return id and Data[id] or nil
end

function BossCinematic.hasIntro(id)
    local d = Data[id]
    return d ~= nil and d.intro ~= nil and #d.intro > 0
end

function BossCinematic.hasDeath(id)
    local d = Data[id]
    return d ~= nil and d.death ~= nil and #d.death > 0
end

function BossCinematic.duration(steps)
    local s = 0
    for _, st in ipairs(steps or {}) do s = s + (st.dur or 0) end
    return s
end

function BossCinematic.validate(id)
    local d = Data[id]
    local errs = {}
    if not d then return { "sem dados pra " .. tostring(id) } end
    local function check(list, kinds, label)
        for i, st in ipairs(list or {}) do
            if not kinds[st.kind] then
                errs[#errs + 1] = ("%s.%s[%d]: kind desconhecido '%s'"):format(id, label, i, tostring(st.kind))
            end
            if st.dur ~= nil and (type(st.dur) ~= "number" or st.dur < 0) then
                errs[#errs + 1] = ("%s.%s[%d]: dur invalido"):format(id, label, i)
            end
        end
    end
    check(d.intro, BossCinematic.INTRO_KINDS, "intro")
    check(d.introReduced, BossCinematic.INTRO_KINDS, "introReduced")
    check(d.death, BossCinematic.DEATH_KINDS, "death")
    check(d.deathReduced, BossCinematic.DEATH_KINDS, "deathReduced")
    return errs
end

local function clearFx()
    feathers, dust, crows, wind = {}, {}, {}, {}
end

local function finish()
    require("src.ui.BossTrophy").stop()
    seq = nil
    dark = 0
    darkEase = nil
    eyes = nil
    fly = nil
    title = nil
    slowmo = nil
    desat = nil
    bossHidden = false
    hudHidden = false
    mist = nil
    hit = nil
    edge = nil
    crownCard = nil
    hallEyes = nil
    fx = {}
    flakes = {}
    sfxQueue = {}
    stopAllLoops()
    EnemyRenderer.setTimeScale(1)
end

function BossCinematic.reset()
    finish()
    clearFx()
    landed = false
    deathFor = nil
    T3.bond, T3.free, T3.seenWith = nil, nil, nil
    stage = nil
    eclipse = nil
    if InteriorFX.setEclipse then InteriorFX.setEclipse(0, 0) end
end

local function copySteps(list)
    local out = {}
    for i, st in ipairs(list) do
        local c = {}
        for k, v in pairs(st) do c[k] = v end
        out[i] = c
    end
    return out
end

local function begin(phase, steps, bossId, reduced, data)
    loadSounds()
    seq = { phase = phase, steps = copySteps(steps), idx = 1, stepT = 0, t = 0,
            bossId = bossId, reduced = reduced }
    local pal = data and data.palette or (Data[bossId] and Data[bossId].palette)
    PAL = setmetatable(pal or {}, { __index = DEFAULT_PALETTE })
    fx = {}
    flakes = {}
end

BossCinematic.GENERIC = {
    intro = {
        { kind = "dark",  dur = 0.70, to = 0.60 },
        { kind = "land",  dur = 0.55, shake = 8, dust = 10, crows = 0 },
        { kind = "title", dur = 1.80 },
        { kind = "hud",   dur = 0 },
    },
    introReduced = {
        { kind = "dark",  dur = 0.35, to = 0.45 },
        { kind = "land",  dur = 0.40, shake = 3, dust = 4, crows = 0 },
        { kind = "title", dur = 1.30 },
        { kind = "hud",   dur = 0 },
    },
    palette = {
        body = { 0.12, 0.10, 0.14 }, glow = { 0.70, 0.64, 0.52 }, ember = { 0.90, 0.68, 0.36 },
        flash = { 0.82, 0.76, 0.64 }, ghost = { 0.60, 0.56, 0.50 }, rim = { 0.72, 0.66, 0.54 },
        particle = { 0.30, 0.26, 0.22 }, particle2 = { 0.62, 0.56, 0.46 },
    },
}

function BossCinematic.startIntro(game)
    local e = game and game.enemy
    local id = e and e.spriteId
    if not (e and e.isBoss and id) then return false end
    local d = Data[id]
    if d and not BossCinematic.hasIntro(id) then d = nil end
    if d then
        for _, err in ipairs(BossCinematic.validate(id)) do
            require("src.core.Debug").warn("[BossCinematic] " .. err)
        end
    else
        require("src.core.Debug").warn("[BossCinematic] chefe sem roteiro próprio: " .. tostring(id) .. " — entrada genérica")
        d = BossCinematic.GENERIC
    end
    local reduced = reducedMotion()
    local steps = (reduced and d.introReduced) or d.intro
    finish()
    clearFx()
    landed = false
    deathFor = nil
    eclipse = nil
    begin("intro", steps, id, reduced, d)
    T3.bond = nil
    dark = 0.86
    bossHidden = true
    hudHidden = true
    spawnMist()
    return true
end

function BossCinematic.startDeath(game)
    local e = game and game.enemy
    local id = e and e.spriteId
    if not (e and e.isBoss and BossCinematic.hasDeath(id)) then return false end
    if deathFor == e then return false end
    deathFor = e
    local d = Data[id]
    local reduced = reducedMotion()
    local steps = (reduced and d.deathReduced) or d.death
    steps = require("src.ui.BossTrophy").withTrophy(steps, game, reduced)
    if seq then finish() end
    begin("death", steps, id, reduced)
    return true
end

function BossCinematic.markDeathSeen(game)
    local e = game and game.enemy
    if e then deathFor = e end
end

function BossCinematic.isActive() return seq ~= nil end
function BossCinematic.phase() return seq and seq.phase or nil end
function BossCinematic.hidesBoss() return seq ~= nil and bossHidden end
BossCinematic.CRUMBLE_FADE = 0.7
function BossCinematic.bossAlpha()
    local cr = fx.crumble
    if not (cr and cr.fadeT) then return 1 end
    return math.max(0, math.min(1, cr.fadeT / BossCinematic.CRUMBLE_FADE))
end
function BossCinematic.hidesHud() return seq ~= nil and hudHidden end
function BossCinematic.hidesHand() return seq ~= nil end
function BossCinematic.holdsEnd() return seq ~= nil and seq.phase == "death" end
function BossCinematic.lockInput() return seq ~= nil end
function BossCinematic.elapsed() return seq and seq.t or 0 end
function BossCinematic.canSkip()
    return seq ~= nil and seq.t >= BossCinematic.SKIP_AFTER
end
function BossCinematic.darkness() return dark end

function BossCinematic._debug()
    return { seq = seq, dark = dark, eyes = eyes, fly = fly, title = title,
             slowmo = slowmo, desat = desat, landed = landed,
             mist = mist, hit = hit, edge = edge, loops = loops, fx = fx,
             eclipse = eclipse, crown = crownCard, hallEyes = hallEyes,
             bond = T3.bond, free = T3.free, crowList = crows,
             feathers = #feathers, dust = #dust, crows = #crows, wind = #wind }
end

function BossCinematic.skip()
    if not BossCinematic.canSkip() then return false end
    if seq.phase == "intro" then
        landed = true
        EnemyRenderer.triggerArrival()
    end
    finish()
    return true
end

function BossCinematic.setStage(st) stage = st end

local WIND_COLOR    = { 0.78, 0.74, 0.90 }
local EYE_CORE      = { 1.00, 0.78, 0.32 }
local EYE_HALO      = { 1.00, 0.46, 0.10 }

local function px()
    local s = (stage and stage.foot and stage.foot.scale) or (stage and stage.tr and stage.tr.scale) or 2
    return math.max(2, math.floor(s + 0.5))
end

local function spawnFeather(x, y, vx, vy, kind)
    kind = kind or "feather"
    feathers[#feathers + 1] = {
        x = x, y = y, vx = vx, vy = vy, kind = kind,
        rot = love.math.random() * math.pi, rotV = (love.math.random() - 0.5) * 6,
        sway = love.math.random() * math.pi * 2,
        life = 1.4 + love.math.random() * 1.2, max = 0,
        light = love.math.random() < 0.35,
        float = (kind == "ember" or kind == "spore" or kind == "ash"),
    }
    local f = feathers[#feathers]
    f.max = f.life
end

local function spawnDust(x, groundY, n, spread)
    for i = 1, n do
        local side = (i % 2 == 0) and 1 or -1
        dust[#dust + 1] = {
            x = x + side * (6 + love.math.random() * spread * 0.4),
            y = groundY,
            vx = side * (60 + love.math.random() * 120),
            vy = -(30 + love.math.random() * 70),
            life = 0.45 + love.math.random() * 0.35, max = 0,
        }
        dust[#dust].max = dust[#dust].life
    end
end

local function spawnCrows(x, y, n, speed)
    local sw = (stage and stage.bbox and stage.bbox.width or 120) * 0.9
    local sh = (stage and stage.bbox and stage.bbox.height or 200) * 0.4
    for i = 1, n do
        local a = -math.pi * (0.15 + 0.7 * ((i - 0.5) / n)) + (love.math.random() - 0.5) * 0.3
        local sp = speed * (0.75 + love.math.random() * 0.5)
        crows[#crows + 1] = {
            x = x + (love.math.random() - 0.5) * sw, y = y + (love.math.random() - 0.5) * sh,
            vx = math.cos(a) * sp, vy = math.sin(a) * sp,
            h1 = love.math.random(), life = 2.4, max = 2.4,
            face = (math.cos(a) >= 0) and 1 or -1,
            sprite = require("src.ui.BossAura").crowSpriteDir(seq and seq.bossId),
        }
    end
end

local function spawnWind(x, y, dirX, len, thick)
    wind[#wind + 1] = { x = x, y = y, len = len, vx = dirX * (720 + love.math.random() * 420),
                        life = 0.22 + love.math.random() * 0.16, max = 0, thick = thick }
    wind[#wind].max = wind[#wind].life
end

local function updateFx(dt)
    for i = #feathers, 1, -1 do
        local f = feathers[i]
        f.life = f.life - dt
        f.sway = f.sway + dt * 4.5
        if f.float then
            f.vy = f.vy - 18 * dt
        else
            f.vy = math.min(f.vy + 55 * dt, 48)
        end
        f.vx = f.vx * (1 - 1.6 * dt) + math.sin(f.sway) * 22 * dt
        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt
        f.rot = f.rot + f.rotV * dt
        if f.life <= 0 or (stage and f.y > (stage.h or 1e9) + 20) then table.remove(feathers, i) end
    end
    for i = #dust, 1, -1 do
        local d = dust[i]
        d.life = d.life - dt
        d.x = d.x + d.vx * dt
        d.vx = d.vx * (1 - 3 * dt)
        d.y = d.y + d.vy * dt
        d.vy = d.vy + 220 * dt
        if d.life <= 0 then table.remove(dust, i) end
    end
    for i = #crows, 1, -1 do
        local c = crows[i]
        c.life = c.life - dt
        c.vy = c.vy - 60 * dt
        c.x = c.x + c.vx * dt
        c.y = c.y + c.vy * dt
        if c.life <= 0 or c.y < -60 then table.remove(crows, i) end
    end
    for i = #wind, 1, -1 do
        local w = wind[i]
        w.life = w.life - dt
        w.x = w.x + w.vx * dt
        if w.life <= 0 then table.remove(wind, i) end
    end
end

local BAYER4 = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
local function bayer(x, y)
    return (BAYER4[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16
end
local function hash2(x, y)
    local n = math.sin(x * 127.1 + y * 311.7) * 43758.5453
    return n - math.floor(n)
end
local function vnoise(x, y)
    local xi, yi = math.floor(x), math.floor(y)
    local xf, yf = x - xi, y - yi
    local u, v = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    local a, b = hash2(xi, yi), hash2(xi + 1, yi)
    local c, d = hash2(xi, yi + 1), hash2(xi + 1, yi + 1)
    return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v
end
local function fbm(x, y)
    return 0.55 * vnoise(x, y) + 0.30 * vnoise(x * 2.1 + 5.2, y * 2.1 + 1.3)
        + 0.15 * vnoise(x * 4.3 + 9.1, y * 4.3 + 3.7)
end

local fogImgs = nil
local FOG_W, FOG_H = 72, 36
local function ensureFog()
    if fogImgs then return fogImgs end
    fogImgs = {}
    for i = 1, 3 do
        local data = love.image.newImageData(FOG_W, FOG_H)
        for y = 0, FOG_H - 1 do
            for x = 0, FOG_W - 1 do
                local n = fbm(x / FOG_W * 3 + i * 7.3, y / FOG_H * 2 + i * 3.1)
                local dx, dy = (x + 0.5) / FOG_W * 2 - 1, (y + 0.5) / FOG_H * 2 - 1
                local r = math.sqrt(dx * dx + dy * dy * 1.3)
                local v = n * math.max(0, math.min(1, 1.35 - r * 1.1))
                local th = bayer(x, y) * 0.18
                local a = 0
                if v > 0.50 + th then a = 1
                elseif v > 0.35 + th then a = 0.66
                elseif v > 0.22 + th then a = 0.33 end
                data:setPixel(x, y, 1, 1, 1, a)
            end
        end
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        fogImgs[i] = img
    end
    return fogImgs
end

spawnMist = function()
    ensureFog()
    mist = { puffs = {}, a = 0, target = 0, speed = 1 }
    local function puff(layer, n)
        for _ = 1, n do
            local far = (layer == 1)
            mist.puffs[#mist.puffs + 1] = {
                layer = layer,
                x = -60 + love.math.random() * 480,
                y = (far and 70 or 110) + love.math.random() * (far and 110 or 120),
                vx = (far and 2 or 4) * (love.math.random() < 0.5 and -1 or 1) * (0.6 + love.math.random() * 0.8),
                s = (far and 0.9 or 1.3) + love.math.random() * 0.6,
                a = (layer == 3) and 0.22 or (far and 0.42 or 0.56),
                img = 1 + love.math.random(0, 2),
                flip = love.math.random() < 0.5,
                ember = love.math.random() < 0.22,
                bob = love.math.random() * 6.28,
            }
        end
    end
    puff(1, 9)
    puff(2, 10)
    puff(3, 5)
end

local function mistTarget(target, secs)
    if not mist then return end
    mist.target = target
    mist.speed = 1 / math.max(0.05, secs or 1)
end

local function updateMist(dt)
    if not mist then return end
    if mist.a < mist.target then mist.a = math.min(mist.target, mist.a + dt * mist.speed)
    elseif mist.a > mist.target then mist.a = math.max(mist.target, mist.a - dt * mist.speed) end
    if reducedMotion() then return end
    local g = InteriorFX.gustLevel() * mistGustDir
    for _, pf in ipairs(mist.puffs) do
        local par = (pf.layer == 1) and 0.5 or ((pf.layer == 2) and 1 or 1.7)
        pf.x = pf.x + (pf.vx + g * 230) * par * dt
        pf.bob = pf.bob + dt * 0.7
        if pf.x > 430 then pf.x = -90 elseif pf.x < -100 then pf.x = 420 end
    end
end

local mistCanvas, posterShader, posterTried = nil, nil, false
local function ensurePoster(w, h)
    if not posterTried then
        posterTried = true
        local ok, sh = pcall(love.graphics.newShader, "shaders/posterize.glsl")
        if ok then posterShader = sh else
            require("src.core.Debug").warn("[BossCinematic] shaders/posterize.glsl não carregou: " .. tostring(sh)
                .. " — névoa sem degraus")
        end
    end
    if not posterShader then return nil end
    if not mistCanvas or mistCanvas:getWidth() ~= w or mistCanvas:getHeight() ~= h then
        local ok, c = pcall(love.graphics.newCanvas, w, h)
        if not ok then return nil end
        mistCanvas = c
        mistCanvas:setFilter("nearest", "nearest")
    end
    return mistCanvas
end

local drawMistRaw
local function drawMist(layers)
    if not mist or mist.a <= 0.01 or not stage or not stage.tr then return end
    local w, h = stage.w or love.graphics.getWidth(), stage.h or love.graphics.getHeight()
    local canvas = ensurePoster(w, h)
    if not canvas then return drawMistRaw(layers) end
    local prev = love.graphics.getCanvas()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setScissor()
    drawMistRaw(layers)
    love.graphics.pop()
    if prev then love.graphics.setCanvas(prev) else love.graphics.setCanvas() end
    posterShader:send("levels", 4)
    posterShader:send("block", px())
    love.graphics.setShader(posterShader)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setShader()
end

drawMistRaw = function(layers)
    local tr = stage.tr
    local S = tr.scale
    local imgs = ensureFog()
    for _, pf in ipairs(mist.puffs) do
        if layers[pf.layer] then
            local img = imgs[pf.img]
            local sx = pf.s * S * (pf.flip and -1 or 1)
            local sy = pf.s * S
            local x = tr.ox + math.floor(pf.x + (pf.flip and FOG_W * pf.s or 0)) * S
            local y = tr.oy + math.floor(pf.y + math.sin(pf.bob) * 3) * S
            local a = pf.a * mist.a
            love.graphics.setColor(PAL.body[1], PAL.body[2], PAL.body[3], a)
            love.graphics.draw(img, x, y, 0, sx, sy)
            love.graphics.setBlendMode("add")
            local gc = pf.ember and PAL.ember or PAL.glow
            love.graphics.setColor(gc[1], gc[2], gc[3], a * (pf.ember and 0.22 or 0.30))
            love.graphics.draw(img, x, y, 0, sx, sy)
            love.graphics.setBlendMode("alpha")
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function glowBlob(cx, cy, w, h, color, a, idx)
    local img = ensureFog()[idx or 1]
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], a)
    love.graphics.draw(img, math.floor(cx - w / 2), math.floor(cy - h / 2), 0, w / FOG_W, h / FOG_H)
    love.graphics.setBlendMode("alpha")
end

local RING_STYLES = {
    ice    = { { 0.78, 0.94, 1.00 }, { 0.42, 0.78, 1.00 } },
    frost  = { { 0.90, 0.97, 1.00 }, { 0.62, 0.86, 1.00 } },
    lava   = { { 1.00, 0.52, 0.12 }, { 1.00, 0.86, 0.38 } },
    spores = { { 0.55, 0.86, 0.32 }, { 0.86, 0.96, 0.52 } },
    petal  = { { 0.96, 0.46, 0.76 }, { 0.74, 0.32, 0.92 } },
}
local function startHit(cx, cy, ring)
    if ring and not RING_STYLES[ring] then
        require("src.core.Debug").warn("[BossCinematic] land.ring desconhecido: " .. tostring(ring) .. " — paleta do chefe")
    end
    hit = { t = 0, dur = 0.60, cx = cx, cy = cy, ring = ring and RING_STYLES[ring] or nil }
    if not reducedMotion() then
        local okC, CRT = pcall(require, "src.ui.CRTShader")
        if okC and CRT.jolt then CRT.jolt(0.16) end
    end
end

function BossCinematic.worldZoom()
    if not hit or reducedMotion() then return nil end
    local k = clamp01(hit.t / 0.32)
    if k >= 1 then return nil end
    return 1 + 0.06 * math.sin(math.pi * k), hit.cx, hit.cy
end

local heartVig = nil
local HV_W, HV_H = 192, 108
local function ensureHeartVignette()
    if heartVig then return heartVig end
    local data = love.image.newImageData(HV_W, HV_H)
    for y = 0, HV_H - 1 do
        for x = 0, HV_W - 1 do
            local dx, dy = (x + 0.5) / HV_W * 2 - 1, (y + 0.5) / HV_H * 2 - 1
            local r = math.sqrt(dx * dx + dy * dy * 1.15)
            local v = clamp01((r - 0.62) / 0.5)
            v = v * v
            local q = math.floor(v * 4 + bayer(x, y) * 0.9) / 4
            data:setPixel(x, y, 1, 1, 1, math.min(1, q))
        end
    end
    heartVig = love.graphics.newImage(data)
    heartVig:setFilter("nearest", "nearest")
    return heartVig
end

local function drawScreenFx()
    local hf = BossCinematic.heartFlash and BossCinematic.heartFlash() or 0
    if hf > 0.01 then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local img = ensureHeartVignette()
        love.graphics.setColor(PAL.flash[1], PAL.flash[2], PAL.flash[3], hf * 1.6)
        love.graphics.draw(img, 0, 0, 0, w / img:getWidth(), h / img:getHeight())
        love.graphics.setColor(1, 1, 1, 1)
    end
    if not hit then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local t = hit.t
    local reduced = reducedMotion()
    local uk = require("src.ui.UiScale").activeK()
    local cx, cy = hit.cx / uk, hit.cy / uk
    local P = math.max(2, math.floor(2 * uk + 0.5))
    if not reduced then
        local fa = (t < 0.06) and 0.55 or ((t < 0.13) and 0.30 or ((t < 0.22) and 0.12 or 0))
        if fa > 0 then
            love.graphics.setColor(PAL.flash[1], PAL.flash[2], PAL.flash[3], fa)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
        for ring = 0, 1 do
            local rt = t - ring * 0.08
            if rt > 0 then
                local k = clamp01(rt / hit.dur)
                local r = easeOut(k) * w * 0.55
                local a = 1 - k
                local col = hit.ring and hit.ring[ring + 1]
                    or ((ring == 0) and PAL.ember or PAL.flash)
                local n = math.max(24, math.floor(2 * math.pi * r / P))
                for i = 0, n - 1 do
                    if bayer(i, ring + math.floor(i / 4)) < a then
                        local ang = i / n * math.pi * 2
                        local bx = math.floor((cx + math.cos(ang) * r) / P) * P
                        local by = math.floor((cy + math.sin(ang) * r * 0.78) / P) * P
                        love.graphics.setColor(col[1], col[2], col[3], 0.85)
                        love.graphics.rectangle("fill", bx, by, P, P)
                    end
                end
            end
        end
    end
    local va = (1 - clamp01(t / hit.dur)) * (reduced and 0.35 or 0.6)
    if va > 0.02 then
        for i, bw in ipairs({ 48, 28, 12 }) do
            love.graphics.setColor(0.05, 0.02, 0.08, va * (0.18 * i))
            local b = math.floor(bw * uk)
            love.graphics.rectangle("fill", 0, 0, w, b)
            love.graphics.rectangle("fill", 0, h - b, w, b)
            love.graphics.rectangle("fill", 0, 0, b, h)
            love.graphics.rectangle("fill", w - b, 0, b, h)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function ownAnim(clip, dur)
    local id = seq and seq.bossId
    if not id then return nil end
    local key = id .. "/" .. tostring(clip)
    if ownAnims[key] then return ownAnims[key] end
    local a
    if clip and SpriteAnimation.exists(id, clip, "south") then
        a = SpriteAnimation.new(id, clip, "south", 10, { loop = false })
        if dur and a then
            a.fps = math.max(2, a:getFrameCount() / dur)
            a.frameTime = 1 / a.fps
        end
    else
        local spec = EnemyPoses.get and EnemyPoses.get(id) or nil
        a = SpriteAnimation.new(id, "idle", "south", (spec and spec.idle and spec.idle.fps) or 8)
    end
    ownAnims[key] = a
    return a
end

local function footInfo()
    if not (stage and stage.foot and stage.foot.drawX) then return nil end
    return stage.foot.drawX, stage.foot.drawY, stage.foot.scale
end

local function drawOwn(anim, x, y, s, tint, rimA)
    if not anim then return end
    anim:draw(x, y, s, tint or { 1, 1, 1, 1 })
    if rimA and rimA > 0 then
        love.graphics.setBlendMode("add")
        anim:draw(x, y, s, { PAL.rim[1], PAL.rim[2], PAL.rim[3], rimA })
        love.graphics.setBlendMode("alpha")
    end
end

local function dotRing(cx, cy, r, ry, P, col, a)
    local n = math.max(16, math.floor(2 * math.pi * r / P))
    for i = 0, n - 1 do
        if bayer(i, math.floor(i / 4)) < a then
            local ang = i / n * math.pi * 2
            love.graphics.setColor(col[1], col[2], col[3], 0.9)
            love.graphics.rectangle("fill", math.floor((cx + math.cos(ang) * r) / P) * P,
                math.floor((cy + math.sin(ang) * ry) / P) * P, P, P)
        end
    end
end

local RUNE_GLYPHS = {
    { ".#.", "###", ".#.", "#.#", "#.#" }, { "#.#", ".#.", "###", ".#.", "#.#" },
    { "###", "#..", "##.", "#..", "###" }, { ".#.", "#.#", ".#.", "#.#", ".#." },
    { "#.#", "###", "#.#", ".#.", ".#." },
}

local function drawRunes()
    local r = fx.runes
    if not r or not stage or not stage.bbox then return end
    local P = px()
    local B = math.max(P, math.floor(((stage.tr and stage.tr.scale) or 4) * 1.6 + 0.5))
    local cx, cy = stage.bbox.cx, (stage.cy or stage.bbox.bottomY)
    local rx = math.max(80, (stage.bbox.width or 120) * 1.1)
    local ry = rx * 0.22
    for i = 1, r.n do
        local lit = clamp01((r.t - (i - 1) * r.dur / r.n) / 0.25)
        if lit > 0 then
            local ang = -math.pi / 2 + (i - 1) / r.n * math.pi * 2
            local gx = math.floor((cx + math.cos(ang) * rx) / B) * B
            local gy = math.floor((cy + math.sin(ang) * ry) / B) * B
            local glyph = RUNE_GLYPHS[1 + (i - 1) % #RUNE_GLYPHS]
            local pulse = 0.75 + 0.25 * math.sin(r.t * 6 + i)
            glowBlob(gx, gy, 14 * B, 9 * B, PAL.glow, 0.60 * lit * pulse, 1 + i % 3)
            glowBlob(gx, gy, 7 * B, 5 * B, PAL.ember, 0.35 * lit * pulse, 3)
            for row = 1, 5 do
                for col = 1, 3 do
                    if glyph[row]:sub(col, col) == "#" then
                        love.graphics.setColor(PAL.ember[1], PAL.ember[2], PAL.ember[3], lit)
                        love.graphics.rectangle("fill", gx + (col - 2) * B, gy + (row - 3) * B, B, B)
                    end
                end
            end
        end
    end
    local all = clamp01((r.t - r.dur) / 0.4 + 1)
    if r.t > r.dur * 0.9 then
        local breathe = 0.8 + 0.2 * math.sin(r.t * 4)
        dotRing(cx, cy, rx, ry, P, PAL.glow, 0.75 * all * breathe)
        dotRing(cx, cy, rx + 3 * P, ry + 2 * P, P, PAL.ember, 0.35 * all * breathe)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawRise(w, h)
    local r = fx.riser
    local dx, dy, s = footInfo()
    if not r or not dx or not r.anim then return end
    local k = clamp01(r.t / r.dur)
    local e = easeOut(k)
    local iw, ih = r.anim:getSize()
    local sw, sh = iw * s, ih * s
    local x = dx
    local y = dy + sh * (1 - e)
    local floorY = math.floor((stage.cy or (dy + sh)) + 2)
    glowBlob(x + sw / 2, y + sh * 0.5, sw * 1.7, sh * 1.1, PAL.glow, 0.35 * e, 2)
    for i = -2, 2 do
        glowBlob(x + sw / 2 + i * sw * 0.22, floorY - 6, sw * 0.5, sh * 0.16, PAL.glow,
            0.28 * (0.7 + 0.3 * math.sin(r.t * 13 + i)), 1 + (i + 2) % 3)
    end
    local sx, sy, sww, shh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, 0, w, floorY)
    drawOwn(r.anim, x, y, s, { 1, 1, 1, 1 }, 0.25 * (1 - e) + 0.08)
    if sx then love.graphics.setScissor(sx, sy, sww, shh) else love.graphics.setScissor() end
end

local function drawWalk(w, h)
    local wk = fx.walker
    local dx, dy, s = footInfo()
    if not wk or not dx or not wk.anim then return end
    local k = clamp01(wk.t / wk.dur)
    local e = smooth(k)
    local iw, ih = wk.anim:getSize()
    local sk = s * (0.58 + 0.42 * e)
    local bodyCx = stage.bbox and stage.bbox.cx or (dx + iw * s / 2)
    local backY = stage.backY or ((stage.cy or dy + ih * s) - ih * s * 0.25)
    local groundY = lerp(backY, stage.cy or (dy + ih * s), e)
    local padBelow = (dy + ih * s) - (stage.cy or (dy + ih * s))
    local x = bodyCx - (bodyCx - dx) * (sk / s)
    local y = groundY + padBelow * (sk / s) - ih * sk
    love.graphics.setColor(0, 0, 0, 0.35 * e)
    love.graphics.ellipse("fill", bodyCx, groundY, iw * sk * 0.3, math.max(3, iw * sk * 0.05))
    glowBlob(bodyCx, y + ih * sk * 0.6, iw * sk * 1.5, ih * sk * 0.9, PAL.glow, 0.22, 2)
    wk.pos = { x = x, y = y, s = sk }
    drawOwn(wk.anim, x, y, sk, { 0.7 + 0.3 * e, 0.7 + 0.3 * e, 0.7 + 0.3 * e, 1 }, 0.12)
end

local function drawDescend(w, h)
    local d = fx.desc
    local dx, dy, s = footInfo()
    if not d or not dx or not d.anim then return end
    local k = clamp01(d.t / d.dur)
    local e = smooth(k)
    local tr = stage.tr
    local iw, ih = d.anim:getSize()
    local sw, sh = iw * s, ih * s
    local x0 = (tr and (tr.ox + d.u * 400 * tr.scale) or (w * d.u)) - sw / 2
    local y0 = (tr and (tr.oy + d.v * 256 * tr.scale) or (h * d.v)) - sh * 0.5
    local x, y = lerp(x0, dx, e), lerp(y0, dy, e) + math.sin(d.t * 2.2) * 3
    local lit = d.backlit and (0.08 + 0.92 * e) or 1
    glowBlob(x + sw / 2, y + sh * 0.5, sw * 1.9, sh * 1.3, PAL.glow, 0.30 * (1 - e * 0.5), 1)
    drawOwn(d.anim, x, y, s, { lit, lit, lit, 1 }, 0.3 * (1 - e) + 0.05)
end

local function enterSilhouette(st)
    local id = seq.bossId
    local walk
    if st.clip and SpriteAnimation.exists(id, st.clip, "south") then
        walk = SpriteAnimation.new(id, st.clip, "south", st.fps or 9)
    else
        if st.clip then require("src.core.Debug").warn("[BossCinematic] silhouette: clip '" .. tostring(st.clip) .. "' ausente — idle") end
        walk = ownAnim(nil, nil)
    end
    local dur = math.max(0.3, st.dur or 1.2)
    local strikeAt = st.strike and math.min(st.strike, dur - 0.2) or nil
    local sil = { t = 0, dur = dur, anim = walk, far = st.far or 0.4,
                  strikeAt = strikeAt, struck = false, hitDelay = st.hitDelay or 0.35 }
    if strikeAt and st.strikeClip then
        if SpriteAnimation.exists(id, st.strikeClip, "south") then
            sil.strikeAnim = SpriteAnimation.new(id, st.strikeClip, "south", 10, { loop = false })
            local n = sil.strikeAnim:getFrameCount()
            sil.strikeAnim.fps = math.max(4, n / math.max(0.3, dur - strikeAt))
            sil.strikeAnim.frameTime = 1 / sil.strikeAnim.fps
        else
            require("src.core.Debug").warn("[BossCinematic] silhouette: strikeClip '" .. tostring(st.strikeClip) .. "' ausente — bate no idle")
        end
    end
    fx.sil = sil
end

local function updateSilhouette(dt)
    local si = fx.sil
    if not si then return end
    si.t = si.t + dt
    local striking = si.strikeAt and si.t >= si.strikeAt
    if striking and si.strikeAnim then si.strikeAnim:update(dt)
    elseif si.anim then si.anim:update(dt) end
    if striking and not si.struck and si.t >= si.strikeAt + si.hitDelay then
        si.struck = true
        if stage and stage.bbox then
            local gx, gy = stage.bbox.cx, stage.cy or stage.bbox.bottomY
            startHit(gx, stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.6, "frost")
            for _ = 1, (seq.reduced and 6 or 14) do
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120) * 0.8, gy - 4,
                    (love.math.random() - 0.5) * 90, -60 - love.math.random() * 90, "shard")
            end
        end
        if _G.triggerShake then _G.triggerShake(seq.reduced and 4 or 11, 0.35) end
        play("monarchStrike", "bossIceCrackle")
        InteriorFX.gust(1.0, 0.6)
    end
end

local function drawSilhouette(w, h)
    local si = fx.sil
    local dx, dy, s = footInfo()
    if not si or not dx then return end
    local striking = si.strikeAt and si.t >= si.strikeAt
    local anim = (striking and si.strikeAnim) or si.anim
    if not anim then return end
    local P = px()
    local a = smooth(clamp01(si.t / 0.35))
    local walkDur = si.strikeAt or si.dur
    local e = smooth(clamp01(si.t / walkDur))
    local iw, ih = anim:getSize()
    local sk = s * lerp(si.far, 1, e)
    local bodyCx = stage.bbox and stage.bbox.cx or (dx + iw * s / 2)
    local backY = stage.backY or ((stage.cy or dy + ih * s) - ih * s * 0.25)
    local groundY = lerp(backY, stage.cy or (dy + ih * s), e)
    local padBelow = (dy + ih * s) - (stage.cy or (dy + ih * s))
    local x = bodyCx - (bodyCx - dx) * (sk / s)
    local y = groundY + padBelow * (sk / s) - ih * sk
    if not striking then x = x + math.sin(si.t * 3) * 2 * (0.4 + 0.6 * e) end
    x, y = math.floor(x), math.floor(y)
    local cold = { 0.70, 0.86, 1.00, a }
    for _, off in ipairs({ { -P, 0 }, { P, 0 }, { 0, -P }, { 0, P } }) do
        anim:draw(x + off[1], y + off[2], sk, cold)
    end
    anim:draw(x, y, sk, { 0.02, 0.03, 0.06, a })
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawFirewall(w, h)
    local f = fx.fire
    if not f or not stage or not stage.tr then return end
    local tr = stage.tr
    local env = math.min(clamp01(f.t / 0.4), clamp01((f.total - f.t) / 0.5))
    if env <= 0 then return end
    local S = tr.scale
    local n = 14
    for i = 0, n do
        local xa = (i / n) * 400
        local fl = 0.6 + 0.4 * math.sin(f.t * 9 + i * 1.7) * math.sin(f.t * 5.3 + i)
        local hh = f.h * 256 * (0.6 + 0.4 * fl)
        local x = tr.ox + xa * S
        local y = tr.oy + (f.v * 256 - hh * 0.5) * S
        glowBlob(x, y, 48 * S, hh * S, PAL.ember, 0.55 * env * fl, 1 + i % 3)
        glowBlob(x, y + hh * 0.3 * S, 30 * S, hh * 0.5 * S, { 1, 0.85, 0.4 }, 0.35 * env * fl, 3)
    end
    glowBlob(w / 2, tr.oy + (f.v * 256 + 30) * S, w * 1.1, 40 * S, PAL.ember, 0.25 * env, 2)
end

local frame0Cache = {}
local function spriteFrame0(id)
    if frame0Cache[id] ~= nil then return frame0Cache[id] or nil end
    local dir = "assets/sprites/characters/enemies/" .. tostring(id) .. "/animations/idle/south"
    local files = love.filesystem.getDirectoryItems(dir)
    table.sort(files, function(a, b)
        local na, nb = tonumber(a:match("^(%d+)")), tonumber(b:match("^(%d+)"))
        if na and nb then return na < nb end
        return a < b
    end)
    local first
    for _, f in ipairs(files) do if f:match("%.png$") then first = f; break end end
    local okD, data = false, nil
    if first then okD, data = pcall(love.image.newImageData, dir .. "/" .. first) end
    if not (okD and data) then
        require("src.core.Debug").warn("[BossCinematic] sem quadro 0 do idle em " .. dir .. " — sem pedaços")
        frame0Cache[id] = false
        return nil
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    frame0Cache[id] = { img = img, data = data, iw = data:getWidth(), ih = data:getHeight() }
    return frame0Cache[id]
end

local function spritePieces(id, B)
    local f0 = spriteFrame0(id)
    if not f0 then return nil end
    local pieces = {}
    local top, bottom = f0.ih, 0
    for by = 0, f0.ih - 1, B do
        for bx = 0, f0.iw - 1, B do
            local w, h = math.min(B, f0.iw - bx), math.min(B, f0.ih - by)
            local has = false
            for y = by, by + h - 1 do
                for x = bx, bx + w - 1 do
                    local _, _, _, a = f0.data:getPixel(x, y)
                    if a > 0.1 then has = true; break end
                end
                if has then break end
            end
            if has then
                pieces[#pieces + 1] = { qx = bx, qy = by, w = w, h = h,
                    quad = love.graphics.newQuad(bx, by, w, h, f0.iw, f0.ih) }
                if by < top then top = by end
                if by + h > bottom then bottom = by + h end
            end
        end
    end
    for _, p in ipairs(pieces) do
        p.row = (p.qy + p.h * 0.5 - top) / math.max(1, bottom - top)
    end
    return pieces, f0
end

local function startRoots(st)
    local n = st.n or 6
    fx.roots = { t = 0, dur = math.max(0.3, st.dur or 1.2), list = {} }
    local tr = stage and stage.tr
    local mouths = (st.from == "walls") and stage and stage.hall
        and InteriorFX.HALLS[stage.hall] and InteriorFX.HALLS[stage.hall].rootMouths or nil
    if st.from == "walls" and not mouths then
        require("src.core.Debug").warn("[BossCinematic] roots from=walls: salão sem rootMouths — saindo de (u,v)")
    end
    local bx0, bx1, by0, by1
    if st.grasp and stage and stage.bbox and tr then
        local b = stage.bbox
        local wdt = (b.width or 120) * 0.55
        bx0 = (b.cx - wdt / 2 - tr.ox) / tr.scale
        bx1 = (b.cx + wdt / 2 - tr.ox) / tr.scale
        by0 = (b.topY + (b.bottomY - b.topY) * 0.15 - tr.oy) / tr.scale
        by1 = (b.bottomY - (b.bottomY - b.topY) * 0.15 - tr.oy) / tr.scale
    end
    for i = 1, n do
        local ox, oy
        if mouths then
            local m = mouths[1 + (i - 1) % #mouths]
            ox, oy = m[1] + (love.math.random() - 0.5) * 6, m[2]
        else
            ox, oy = (st.u or 0.5) * 400, (st.v or 0.62) * 256
        end
        local tx, ty
        if bx0 then
            tx = lerp(bx0, bx1, (i - 0.5) / n) + (love.math.random() - 0.5) * 8
            ty = lerp(by0, by1, love.math.random())
        else
            tx = 20 + (i - 0.5) / n * 360 + (love.math.random() - 0.5) * 30
            ty = 236 + love.math.random() * 16
        end
        local pts = { { ox, oy } }
        local twigs = {}
        local cx, cy = ox, oy
        local total = math.sqrt((tx - ox) ^ 2 + (ty - oy) ^ 2)
        local walked = 0
        local guard = 0
        while walked < total - 6 and guard < 40 do
            guard = guard + 1
            local seg = 12 + love.math.random() * 8
            local remain = total - walked
            if remain - seg < 8 then seg = remain end
            local ang = math.atan2(ty - cy, tx - cx) + (love.math.random() - 0.5) * 0.9
            cx, cy = cx + math.cos(ang) * seg, cy + math.sin(ang) * seg
            walked = walked + seg
            pts[#pts + 1] = { cx, cy }
            if love.math.random() < 0.45 and #pts > 2 then
                local ta = ang + (love.math.random() < 0.5 and 1 or -1) * (0.9 + love.math.random() * 0.6)
                twigs[#twigs + 1] = { at = #pts, len = 4 + love.math.random() * 5, ang = ta }
            end
        end
        pts[#pts] = { tx, ty }
        fx.roots.list[i] = { pts = pts, twigs = twigs, side = (ox < 200) and -1 or 1 }
    end
    playLoop("bossRootsCrawl")
end

local ROOT_A, ROOT_B, ROOT_EDGE = { 0.09, 0.14, 0.08 }, { 0.13, 0.20, 0.11 }, { 0.25, 0.39, 0.18 }

local function rootBrush(tr, x, y, nx, ny, wcells, lightSide, tipK)
    local S = tr.scale
    local cell = math.ceil(S)
    local half = (wcells - 1) / 2
    for i = 0, wcells - 1 do
        local ax = math.floor(x + nx * (i - half))
        local ay = math.floor(y + ny * (i - half))
        local col
        local edgeIdx = (lightSide > 0) and (wcells - 1) or 0
        if i == edgeIdx and wcells >= 2 then
            col = ROOT_EDGE
        elseif (ax + ay) % 2 == 0 then
            col = ROOT_A
        else
            col = ROOT_B
        end
        if tipK and tipK > 0 then
            col = { lerp(col[1], PAL.glow[1], tipK), lerp(col[2], PAL.glow[2], tipK), lerp(col[3], PAL.glow[3], tipK) }
        end
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.rectangle("fill", math.floor(tr.ox + ax * S), math.floor(tr.oy + ay * S), cell, cell)
    end
end

local function drawRoots()
    local r = fx.roots
    if not r or not stage or not stage.tr then return end
    local tr = stage.tr
    local k = clamp01(r.t / r.dur)
    if r.retractT then k = k * (1 - smooth(clamp01(r.retractT / 0.7))) end
    if k <= 0 then return end
    for _, root in ipairs(r.list) do
        local nseg = #root.pts - 1
        local grown = k * nseg
        local lightSide = -(root.side or 1)
        for i = 1, nseg do
            local segK = clamp01(grown - (i - 1))
            if segK > 0 then
                local a, b = root.pts[i], root.pts[i + 1]
                local ex, ey = lerp(a[1], b[1], segK), lerp(a[2], b[2], segK)
                local dx, dy = b[1] - a[1], b[2] - a[2]
                local L = math.max(0.001, math.sqrt(dx * dx + dy * dy))
                local nx, ny = -dy / L, dx / L
                local steps = math.max(1, math.floor(L * segK + 0.5))
                for st2 = 0, steps do
                    local q = st2 / math.max(1, steps)
                    local along = ((i - 1) + segK * q) / nseg
                    local wcells = math.floor(lerp(5, 2, along) + 0.5)
                    if (st2 <= 1 or st2 >= steps - 1) and i > 1 then wcells = wcells + 1 end
                    local tipK = (along > 0.88) and (along - 0.88) / 0.12 or 0
                    rootBrush(tr, lerp(a[1], ex, q), lerp(a[2], ey, q), nx, ny, wcells, lightSide, tipK)
                end
            end
        end
        for _, tw in ipairs(root.twigs or {}) do
            if grown >= tw.at - 1 then
                local o = root.pts[tw.at]
                local tx2, ty2 = math.cos(tw.ang), math.sin(tw.ang)
                for st2 = 0, math.floor(tw.len) do
                    rootBrush(tr, o[1] + tx2 * st2, o[2] + ty2 * st2, -ty2, tx2,
                        (st2 < tw.len * 0.5) and 2 or 1, lightSide, 0)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function enterAssemble(st)
    local id = seq.bossId
    local pieces, f0 = spritePieces(id, st.block or 5)
    local dur = math.max(0.6, st.dur or 2.4)
    if not pieces then
        require("src.core.Debug").warn("[BossCinematic] assemble: sem sprite pra " .. tostring(id) .. " — o chefe aparece no land")
        fx.asm = { t = 0, dur = dur, pieces = {}, flight = 0.5, arrived = 0 }
        return
    end
    local flight = math.min(0.6, dur * 0.3)
    local asm = { t = 0, dur = dur, pieces = pieces, f0 = f0, flight = flight, arrived = 0 }
    for _, p in ipairs(pieces) do
        p.t0 = (1 - p.row) * (dur - flight) * 0.9 + love.math.random() * (dur - flight) * 0.1
        p.ax = 60 + love.math.random() * 280
        p.ay = 206 + love.math.random() * 42
        p.lift = 16 + love.math.random() * 50
    end
    fx.asm = asm
    play("colossusAssemble", "bossEmergeTear")
    queueSfx(dur * 0.6, "bossEmergeTear", nil, 0.85)
    InteriorFX.gust(0.5, dur)
    if _G.triggerShake and not seq.reduced then _G.triggerShake(3, dur) end
end

local function drawAssemble()
    local a = fx.asm
    local dx, dy, s = footInfo()
    if not a or not a.f0 or not dx or not stage.tr then return end
    local tr = stage.tr
    local P = px()
    local k = clamp01(a.t / a.dur)
    local iw, ih = a.f0.iw, a.f0.ih
    glowBlob(dx + iw * s / 2, dy + ih * s * (1 - 0.45 * k), iw * s * 1.4,
        math.max(10, ih * s * 0.8 * k), PAL.glow, 0.22 * k, 2)
    local img = a.f0.img
    local arrived = 0
    for _, p in ipairs(a.pieces) do
        local tk = (a.t - p.t0) / a.flight
        if tk >= 1 then
            arrived = arrived + 1
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, p.quad, dx + p.qx * s, dy + p.qy * s, 0, s, s)
        elseif tk > 0 then
            local e = smooth(tk)
            local sx = tr.ox + p.ax * tr.scale
            local sy = tr.oy + p.ay * tr.scale
            local tx, ty = dx + p.qx * s, dy + p.qy * s
            local x = lerp(sx, tx, e)
            local y = lerp(sy, ty, e) - math.sin(math.pi * e) * p.lift * (s / 2)
            x, y = math.floor(x / P) * P, math.floor(y / P) * P
            local lit = 0.45 + 0.55 * e
            love.graphics.setColor(lit, lit, lit, 0.6 + 0.4 * e)
            love.graphics.draw(img, p.quad, x, y, 0, s, s)
            if not seq.reduced then
                love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], 0.4 * (1 - e))
                love.graphics.rectangle("fill", math.floor(lerp(sx, x, 0.88) / P) * P,
                    math.floor(lerp(sy, y, 0.88) / P) * P, P, P)
            end
        end
    end
    a.arrived = arrived
    love.graphics.setColor(1, 1, 1, 1)
end

local function startCracks(gx, gy, wdt)
    local list = {}
    local n = 7
    for i = 1, n do
        local ang = (i - 0.5) / n * math.pi * 2 + (love.math.random() - 0.5) * 0.5
        local len = wdt * (0.35 + love.math.random() * 0.45)
        local pts = { { gx, gy } }
        local x, y = gx, gy
        local segs = 5 + love.math.random(0, 3)
        for sgi = 1, segs do
            local a2 = ang + (love.math.random() - 0.5) * 0.9
            x = x + math.cos(a2) * len / segs
            y = y + math.sin(a2) * len / segs * 0.42
            pts[#pts + 1] = { x, y }
        end
        list[i] = { pts = pts, delay = love.math.random() * 0.12 }
    end
    fx.cracks = { t = 0, list = list, grow = 0.45 }
end

local function drawCracks()
    local c = fx.cracks
    if not c then return end
    local P = px()
    local fade = c.fadeT and (1 - clamp01(c.fadeT / 2.4)) or 1
    if fade <= 0 then return end
    for _, cr in ipairs(c.list) do
        local nseg = #cr.pts - 1
        local grown = clamp01((c.t - cr.delay) / c.grow) * nseg
        for i = 1, nseg do
            local segK = clamp01(grown - (i - 1))
            if segK > 0 then
                local a, b = cr.pts[i], cr.pts[i + 1]
                local ex, ey = lerp(a[1], b[1], segK), lerp(a[2], b[2], segK)
                local steps = math.max(2, math.floor(math.max(math.abs(ex - a[1]), math.abs(ey - a[2])) / P + 1))
                for st2 = 0, steps do
                    local q = st2 / steps
                    local bx = math.floor(lerp(a[1], ex, q) / P) * P
                    local by = math.floor(lerp(a[2], ey, q) / P) * P
                    love.graphics.setColor(0.02, 0.03, 0.02, 0.95 * fade)
                    love.graphics.rectangle("fill", bx, by, P, P)
                    if i <= 2 then love.graphics.rectangle("fill", bx, by + P, P, P) end
                    if st2 % 2 == 0 then
                        love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], 0.55 * fade)
                        love.graphics.rectangle("fill", bx, by + ((i <= 2) and 2 or 1) * P, P, P)
                    end
                end
                if segK < 1 then
                    love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], 0.7 * fade)
                    love.graphics.rectangle("fill", math.floor(ex / P) * P, math.floor(ey / P) * P, P, P)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function enterCrumble(st)
    local id = seq.bossId
    local pieces, f0 = spritePieces(id, st.block or 5)
    local dx, dy, s = footInfo()
    if not (pieces and dx) then
        require("src.core.Debug").warn("[BossCinematic] crumble: sem sprite/palco pra " .. tostring(id) .. " — morte sem pedaços")
        return
    end
    bossHidden = true
    local dur = math.max(0.8, st.dur or 2.4)
    local delay = math.min(st.delay or 0.6, dur * 0.4)
    local groundY = (stage.cy or (dy + f0.ih * s))
    local cx = dx + f0.iw * s / 2
    local cr = { t = 0, dur = dur, delay = delay, pieces = pieces, f0 = f0, s = s,
                 groundY = groundY, thuds = 0 }
    for _, p in ipairs(pieces) do
        p.t0 = delay + p.row * (dur - delay) * 0.5 + love.math.random() * 0.15
        p.x, p.y = dx + p.qx * s, dy + p.qy * s
        p.vx = (love.math.random() - 0.5) * 70
        p.vy = -20 - love.math.random() * 40
        local off = (p.x + p.w * s / 2 - cx) / math.max(1, f0.iw * s / 2)
        p.ground = groundY - (1 - math.min(1, math.abs(off))) * f0.ih * s * 0.12 * love.math.random()
        p.state = "held"
        p.bounced = false
    end
    fx.crumble = cr
    if st.roots ~= false then
        startRoots({ from = "walls", n = st.roots or 6, dur = math.max(0.2, delay), grasp = true })
    end
    queueSfx(delay, "colossusCrumble", "bossSporeCollapse")
    if _G.triggerShake and not seq.reduced then _G.triggerShake(4, 0.3) end
end

local function updateCrumble(dt)
    local cr = fx.crumble
    if not cr then return end
    cr.t = cr.t + dt
    if cr.t >= cr.delay and fx.roots and not fx.roots.retractT then fx.roots.retractT = 0 end
    local s = cr.s
    for _, p in ipairs(cr.pieces) do
        if p.state == "held" and cr.t >= p.t0 then p.state = "fall" end
        if p.state == "fall" then
            p.vy = p.vy + 900 * dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            if p.y + p.h * s >= p.ground then
                p.y = p.ground - p.h * s
                if not p.bounced and p.vy > 140 then
                    p.bounced = true
                    p.vy = -p.vy * 0.22
                    p.vx = p.vx * 0.5
                else
                    p.state = "rest"
                    p.vx, p.vy = 0, 0
                    if not reducedMotion() and love.math.random() < 0.35 then
                        spawnFeather(p.x + p.w * s / 2, p.y, (love.math.random() - 0.5) * 30,
                            -20 - love.math.random() * 40, "spore")
                    end
                    if cr.thuds < 5 and love.math.random() < 0.08 then
                        cr.thuds = cr.thuds + 1
                        play("sceneStoneThud", nil, 0.6 + love.math.random() * 0.2, 0)
                    end
                end
            end
        end
    end
    if cr.fadeT then cr.fadeT = cr.fadeT + dt end
end

local function drawCrumble()
    local cr = fx.crumble
    if not cr then return end
    local P = px()
    local s = cr.s
    local fade = cr.fadeT and (1 - clamp01(cr.fadeT / BossCinematic.CRUMBLE_FADE)) or 1
    if fade <= 0 then return end
    local img = cr.f0.img
    for _, p in ipairs(cr.pieces) do
        local lit = (p.state == "held") and 1 or 0.78
        local x, y = p.x, p.y
        if p.state ~= "held" then x, y = math.floor(x / P) * P, math.floor(y / P) * P end
        love.graphics.setColor(lit, lit, lit, fade)
        love.graphics.draw(img, p.quad, x, y, 0, s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function T3.chained(id)
    local spec = id and T3.BT.spec(id)
    return spec ~= nil and spec.layout == "chains"
end

function T3.updateBond(dt, game, ctx)
    local b = T3.bond
    if b then
        b.t = b.t + dt
        if b.tautT then b.tautT = b.tautT + dt end
        local slack = (b.state == "drag") and 0.30 or 0
        if b.state == "taut" and b.tautT and b.tautT < 0.5 then
            slack = 0.22 * (1 - b.tautT / 0.5) * math.abs(math.cos(b.tautT * 20))
        end
        if not seq and (b.state ~= "taut" or (b.tautT or 0) >= 0.5) then
            slack = 0
            T3.bond = nil
        end
        T3.BT.setSlack(b.id, slack)
    end
    local e = game and game.enemy
    local id = e and e.spriteId
    if not (ctx and ctx.inHall and e and e.isBoss and T3.chained(id)) then
        T3.free = nil
        return
    end
    if seq and seq.phase == "intro" then return end
    local intact = T3.BT.chainState(id).intact
    local dead = (game and game._deathHandled) or ((e.health or 1) <= 0)
    if T3.free and T3.free.enemy ~= e then T3.free = nil end
    if intact > 0 then
        T3.free = nil
    elseif not T3.free then
        local fresh = T3.seenWith == e and (T3.seenIntact or 0) > 0
        T3.free = { enemy = e, t = fresh and 0 or 10 }
        if fresh and not dead then
            play("tyrantUnchained", "enemyBuffRoar")
            if _G.triggerShake then _G.triggerShake(12, 0.5) end
            InteriorFX.gust(1.0, 1.0)
            if _G.jiggleScreen and not reducedMotion() then _G.jiggleScreen(0.8) end
        end
    end
    T3.seenWith, T3.seenIntact = e, intact
    if T3.free then
        T3.free.t = T3.free.t + dt
        if not dead and stage and stage.bbox and not reducedMotion() and love.math.random() < dt * 6 then
            local bb = stage.bbox
            spawnFeather(bb.cx + (love.math.random() - 0.5) * (bb.width or 120) * 1.3,
                (stage.cy or bb.bottomY) - love.math.random() * 6,
                (love.math.random() - 0.5) * 30, -40 - love.math.random() * 60, "ember")
        end
    end
end

function T3.drawBond()
    local b = T3.bond
    local wk = fx.walker
    if not (b and bossHidden and wk and wk.pos and wk.anim and stage and stage.tr) then return end
    local iw, ih = wk.anim:getSize()
    T3.BT.drawChainsAt(b.id, {
        x = wk.pos.x, y = wk.pos.y, scale = wk.pos.s, iw = iw, ih = ih,
        groundY = wk.pos.y + ih * wk.pos.s, clip = wk.clip, frame = wk.anim.currentFrame,
        hallTr = stage.tr,
    })
end

function T3.drawLooseAura()
    local f = T3.free
    if not (f and stage and stage.bbox) then return end
    local e = f.enemy
    if e and (e.health or 1) <= 0 then return end
    local k = smooth(clamp01(f.t / 0.8))
    local bb = stage.bbox
    local pulse = 0.8 + 0.2 * math.sin(f.t * 5)
    local w, h = (bb.width or 120) * 2.2, (bb.bottomY - bb.topY) * 1.3
    glowBlob(bb.cx, bb.topY + (bb.bottomY - bb.topY) * 0.55, w, h, PAL.glow, 0.30 * k * pulse, 2)
    glowBlob(bb.cx, bb.bottomY - 4, w * 0.8, h * 0.25, PAL.ember, 0.35 * k * pulse, 1)
end

local function drawEclipse(w, h)
    local e = fx.ecl
    if not e or not stage or not stage.tr then return end
    local tr = stage.tr
    local P = px()
    local k = clamp01(e.t / e.dur)
    local cx = tr.ox + e.u * 400 * tr.scale
    local cy = tr.oy + e.v * 256 * tr.scale
    local r = 14 * tr.scale * (1 + 0.15 * math.sin(e.t * 3))
    love.graphics.setColor(0.02, 0.0, 0.04, 0.9 * smooth(k))
    love.graphics.circle("fill", cx, cy, r * 0.95, 24)
    dotRing(cx, cy, r + 2 * P, r + 2 * P, P, PAL.glow, 0.85 * smooth(k))
    dotRing(cx, cy, r + 6 * P, r + 5 * P, P, PAL.flash, 0.4 * smooth(k) * (0.6 + 0.4 * math.sin(e.t * 7)))
    glowBlob(cx, cy, r * 6, r * 4, PAL.glow, 0.35 * smooth(k), 2)
end

local function drawWhiteout()
    local wo = fx.white
    if not wo then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local level = wo.peak * smooth(clamp01(wo.t / (wo.dur * 0.5)))
    if wo.fade then level = level * (1 - smooth(clamp01(wo.fade.t / wo.fade.dur))) end
    wo.level = level
    if level <= 0.01 then return end
    local q = math.min(0.72, math.floor(level * 5) / 5)
    love.graphics.setColor(0.90, 0.95, 1.0, q)
    love.graphics.rectangle("fill", 0, 0, w, h)
    local imgs = ensureFog()
    local t = wo.t
    local gw = w * 0.42
    local gh = gw * (FOG_H / FOG_W)
    for layer = 1, 2 do
        local speed = (layer == 1) and 520 or 760
        local rows = (layer == 1) and 4 or 3
        for row = 0, rows - 1 do
            local y = h * (row + 0.5) / rows - gh / 2 + math.sin(t * 2.1 + row + layer) * gh * 0.15
            local off = (t * speed + row * gw * 0.47 + layer * 131) % (gw * 1.1)
            for i = -1, math.ceil(w / (gw * 1.1)) + 1 do
                local x = i * gw * 1.1 - off
                local img = imgs[1 + (i + row + layer) % 3]
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(0.62, 0.78, 0.96, 0.22 * level)
                love.graphics.draw(img, math.floor(x), math.floor(y), 0, gw / FOG_W, gh / FOG_H)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, 0.16 * level)
                love.graphics.draw(img, math.floor(x + gw * 0.3), math.floor(y + gh * 0.2), 0,
                    gw / FOG_W * 0.8, gh / FOG_H * 0.8)
            end
        end
    end
    love.graphics.setBlendMode("alpha")
    local P = px()
    for _, fl in ipairs(flakes) do
        local bx, by = math.floor(fl.x / P) * P, math.floor(fl.y / P) * P
        love.graphics.setColor(0.55, 0.72, 0.92, 0.85)
        love.graphics.rectangle("fill", bx, by, 3 * P, P)
        love.graphics.setColor(0.92, 0.97, 1.0, 0.95)
        love.graphics.rectangle("fill", bx, by, P, P)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BossCinematic.heartFlash()
    local hb = fx.heart
    if not hb then return 0 end
    local ph = (hb.t * hb.rate) % 1
    return math.max(0, 1 - ph * 4) * 0.28
end

local function flyPos(f, k, w, h)
    local tr = stage and stage.tr
    local iw, ih = 0, 0
    if flyAnim then iw, ih = flyAnim:getSize() end
    local s = ((stage and stage.foot and stage.foot.scale) or 2) * (f.land and 1 or (f.scale or 1))
    local sw, sh = iw * s, ih * s
    local yArt = tr and (tr.oy + f.v * 256 * tr.scale) or (h * f.v)
    local x0 = (f.from == "left") and (-sw - w * 0.05) or (w + w * 0.05)
    local x1 = (f.from == "left") and (w + w * 0.05) or (-sw - w * 0.05)
    local y0 = yArt - sh * 0.5
    local y1 = y0
    if f.land and stage and stage.foot and stage.foot.drawX then
        x1 = stage.foot.drawX
        y1 = stage.foot.drawY
    end
    local e = f.land and (1 - (1 - k) ^ 2.4) or k
    local x = lerp(x0, x1, e)
    local y = lerp(y0, y1, e) + math.sin(math.pi * e) * (f.arc or 0) * h
    return x, y, sw, sh, s
end

local function remainingDuration(fromIdx)
    local s = 0
    for i = fromIdx, #seq.steps do s = s + (seq.steps[i].dur or 0) end
    return s
end

local function ensureFlyAnim(id)
    if flyAnim and flyAnimId == id then return end
    flyAnimId = id
    if SpriteAnimation.exists(id, "dive", "south") then
        flyAnim = SpriteAnimation.new(id, "dive", "south", 14)
        return
    end
    local spec = EnemyPoses.get and EnemyPoses.get(id) or nil
    local fps = (spec and spec.idle and spec.idle.fps) or 8
    flyAnim = SpriteAnimation.new(id, "idle", "south", fps * 2.6)
end

local function bossClip(name, fps)
    local id = seq and seq.bossId
    if not id or not name then return false end
    if EnemyRenderer.hasClip and EnemyRenderer.hasClip(id, name) then
        EnemyRenderer.playClip(name, fps)
        return true
    end
    return false
end

local QUEEN_ID = "eclipse_queen"
local GOLD   = { 0.96, 0.80, 0.42 }
local MAGENTA = { 0.92, 0.28, 0.78 }
local ASH_GRAY = { 0.62, 0.58, 0.60 }
local WARM = { 1.0, 0.86, 0.62 }

local function ensureEclipse()
    if not eclipse then
        eclipse = { level = 0, cur = 0, dawn = 0, t = 0, nextGaze = 6 + love.math.random() * 5,
                    gaze = nil, lastPhase = 0, active = false }
    end
    return eclipse
end

function BossCinematic.eclipseLevel() return eclipse and eclipse.cur or 0 end
function BossCinematic.eclipseDawn() return eclipse and eclipse.dawn or 0 end
function BossCinematic._debugGaze()
    local e = ensureEclipse()
    e.gaze = { t = 0, dur = 1.6 }
end

local function eclipseCenter()
    local tr = stage and stage.tr
    if not tr then return nil end
    return tr.ox + 0.5 * 400 * tr.scale, tr.oy + 0.2266 * 256 * tr.scale, 14 * tr.scale
end

local function drawBrokenHalo(cx, cy, r, ry, P, col, a, t, seed)
    local n = math.max(14, math.floor(2 * math.pi * r / P))
    for i = 0, n - 1 do
        local h = hash2(i + (seed or 0), 3.7)
        if h > 0.32 and bayer(i, math.floor(i / 3)) < a then
            local ang = i / n * math.pi * 2 + (t or 0) * 0.35
            local bx = math.floor((cx + math.cos(ang) * r) / P) * P
            local by = math.floor((cy + math.sin(ang) * ry) / P) * P
            love.graphics.setColor(col[1], col[2], col[3], 0.9)
            love.graphics.rectangle("fill", bx, by, P, P)
            if math.sin(ang) > 0.2 and h > 0.78 then
                local drip = 1 + math.floor(((t or 0) * 1.5 + h * 7) % 3)
                for d = 1, drip do
                    love.graphics.setColor(col[1] * 0.8, col[2] * 0.5, col[3] * 0.8, 0.9 * (1 - d / 4))
                    love.graphics.rectangle("fill", bx, by + d * P, P, P)
                end
            end
        end
    end
end

local function drawIris(cx, cy, r, P, open, t)
    if open <= 0.02 then return end
    local w = math.max(P, math.floor(r * 0.22 / P) * P)
    local hh = math.floor(r * 1.2 * open / P) * P
    if hh < P then return end
    local saccade = math.floor(t * 0.7) % 3 - 1
    local track = math.floor(1.8 * math.sin(t * 0.6) + saccade * 0.7 + 0.5)
    local px0 = math.floor((cx + track * P * 1.5) / P) * P - w / 2
    local py0 = math.floor(cy / P) * P - hh / 2
    glowBlob(cx, cy, r * 2.2, r * 2.2, MAGENTA, 0.35 * open, 2)
    love.graphics.setColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], 0.95)
    love.graphics.rectangle("fill", px0, py0, w, hh)
    love.graphics.setColor(1.0, 0.78, 0.95, 0.95)
    love.graphics.rectangle("fill", px0 + w / 2 - P / 2, py0 + hh * 0.3, P, math.max(P, hh * 0.2))
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawEclipseClosing(k, t, irisOpen)
    local cx, cy, r = eclipseCenter()
    if not cx then return end
    local P = px()
    local rr = r * (0.9 + 0.5 * k)
    if k > 0.01 then
        love.graphics.setColor(0.02, 0.0, 0.04, 0.92 * k)
        love.graphics.circle("fill", cx, cy, rr, 28)
        local breathe = 0.85 + 0.15 * math.sin(t * 2.4)
        drawBrokenHalo(cx, cy, rr + 2 * P, rr + 2 * P, P, PAL.glow, 0.85 * k * breathe, t, 1)
        drawBrokenHalo(cx, cy, rr + 6 * P, rr + 5 * P, P, PAL.flash, 0.45 * k * breathe, -t * 0.6, 9)
        glowBlob(cx, cy, rr * 6, rr * 4, PAL.glow, 0.30 * k, 2)
    end
    drawIris(cx, cy, rr, P, irisOpen or 0, t)
end

local function drawBigShadow(anim, bodyCx, floorY, s, a)
    if not anim or not anim.frames then return end
    local img = anim.frames[anim.currentFrame]
    if not img then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, sy = s * 1.6, s * 0.55
    local rx, ry = math.floor(bodyCx - iw * sx / 2), math.floor(floorY + ih * sy)
    love.graphics.setColor(PAL.body[1] * 0.5, PAL.body[2] * 0.3, PAL.body[3] * 0.6, a)
    love.graphics.draw(img, rx, ry, 0, sx, -sy)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], a * 0.55)
    love.graphics.draw(img, rx, ry, 0, sx, -sy)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local STRAY_EYES = {
    { u = 0.445, v = 0.19, at = 0.25, gap = 2.5, size = 1 },
    { u = 0.555, v = 0.42, at = 0.55, gap = 2.0, size = 1 },
    { u = 0.465, v = 0.52, at = 0.85, gap = 1.5, size = 0.7 },
    { u = 0.540, v = 0.12, at = 1.05, gap = 3.0, size = 1.3 },
    { u = 0.425, v = 0.36, at = 1.30, gap = 1.8, size = 0.8 },
    { u = 0.575, v = 0.27, at = 1.50, gap = 2.2, size = 1 },
}
local function spawnHallEyes(omenDur)
    local n = 20 + love.math.random(0, 20)
    hallEyes = { list = {}, t = 0, turned = false, turnAt = omenDur - 0.35, close = nil }
    for i = 1, n do
        local zone = love.math.random()
        local u, v
        if zone < 0.38 then u, v = 0.02 + love.math.random() * 0.33, 0.10 + love.math.random() * 0.58
        elseif zone < 0.76 then u, v = 0.65 + love.math.random() * 0.33, 0.10 + love.math.random() * 0.58
        else u, v = 0.08 + love.math.random() * 0.84, 0.01 + love.math.random() * 0.08 end
        hallEyes.list[i] = { u = u, v = v, openAt = 0.3 + love.math.random() * (omenDur - 0.9),
                             gap = 1 + love.math.random(0, 1), size = 1 + love.math.random(0, 1),
                             look = love.math.random(0, 2) - 1, blink = love.math.random() * 7 }
    end
end
local function drawHallEyes()
    local he = hallEyes
    local tr = stage and stage.tr
    if not he or not tr then return end
    local P = px()
    local t = he.t
    local closeK = he.close and smooth(clamp01(he.close / 0.3)) or 0
    if closeK >= 1 then return end
    local flash = (he.flash or 0) > 0
    for i, e in ipairs(he.list) do
        local age = t - e.openAt
        local rows = (age < 0) and 0 or ((age < 0.09) and 1 or 2)
        if closeK > 0 then rows = (closeK < 0.5) and math.min(rows, 1) or 0 end
        local blink = (math.floor((t * 2 + e.blink)) % 9 == 0) and 1 or 2
        rows = math.min(rows, blink)
        if rows > 0 then
            local B = P
            local W = (e.size >= 2) and 4 or 3
            local ex = tr.ox + e.u * 400 * tr.scale
            local ey = tr.oy + e.v * 256 * tr.scale
            local gap = (W + 1 + e.gap) * B
            local pupilCol = he.turned and math.floor((W - 1) / 2) or math.max(0, math.min(W - 1, 1 + e.look))
            local hh = rows * B
            local yTop = math.floor(ey / B) * B - (rows == 2 and B or 0)
            if flash then
                glowBlob(ex, ey, gap * 2.6, B * 8, { 1, 0.9, 1 }, 0.75, 1 + i % 3)
            else
                glowBlob(ex, ey, gap * 2.2, B * 5, MAGENTA, 0.28, 1 + i % 3)
            end
            for side = -1, 1, 2 do
                local x0 = math.floor((ex + side * gap / 2) / B) * B - math.floor(W / 2) * B
                love.graphics.setColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], 0.95)
                love.graphics.rectangle("fill", x0 - 1, yTop - 1, W * B + 2, hh + 2)
                love.graphics.setColor(1.0, 0.86, 0.97, 1)
                love.graphics.rectangle("fill", x0, yTop, W * B, hh)
                love.graphics.setColor(0.10, 0.01, 0.12, 1)
                love.graphics.rectangle("fill", x0 + pupilCol * B, yTop, B, hh)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawStrayEyes(t, fade)
    local tr = stage and stage.tr
    if not tr or fade <= 0.01 then return end
    local P = px()
    for i, e in ipairs(STRAY_EYES) do
        local open = clamp01((t - e.at) / 0.35)
        local blink = (math.floor((t * 3 + i * 1.3)) % 7 == 0) and 0.2 or 1
        local a = open * fade * blink
        if a > 0.02 then
            local B = math.max(P, math.floor(2 * P * e.size + 0.5))
            local ex = tr.ox + e.u * 400 * tr.scale
            local ey = tr.oy + e.v * 256 * tr.scale
            local gap = e.gap * B * 2
            glowBlob(ex, ey, gap * 2.6, B * 7, MAGENTA, 0.45 * a, 1 + i % 3)
            for side = -1, 1, 2 do
                local x0 = math.floor((ex + side * gap / 2) / B) * B - B
                local y0 = math.floor(ey / B) * B
                love.graphics.setColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], a)
                love.graphics.rectangle("fill", x0, y0, 3 * B, 2 * B)
                love.graphics.setColor(0.08, 0.01, 0.10, a)
                love.graphics.rectangle("fill", x0 + B, y0, B, 2 * B)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawOmen(w, h)
    local o = fx.omen
    if not o or not stage or not stage.tr then return end
    local k = clamp01(o.t / o.dur)
    local stepK = math.floor(k * o.steps + 1e-6) / o.steps
    local irisOpen = (o.t > o.dur * 0.45) and smooth(clamp01((o.t - o.dur * 0.45) / 0.5)) or 0
    if seq and seq.reduced then irisOpen = (o.t > o.dur * 0.4) and 1 or 0 end
    drawEclipseClosing(0.25 + 0.75 * stepK, o.t, irisOpen)
    local tr = stage.tr
    local cover = stepK * 0.85
    if cover > 0.01 then
        love.graphics.setColor(0.04, 0.01, 0.06, cover)
        love.graphics.rectangle("fill", tr.ox + 160 * tr.scale, tr.oy - 4 * tr.scale, 80 * tr.scale, 196 * tr.scale)
        love.graphics.setColor(0.04, 0.01, 0.06, cover * 0.7)
        love.graphics.rectangle("fill", tr.ox + 148 * tr.scale, tr.oy + 192 * tr.scale, 104 * tr.scale, 70 * tr.scale)
    end
end

local function drawUnveil(w, h)
    local u = fx.unveil
    local dx, dy, s = footInfo()
    if not u or not dx or not u.anim then return end
    local tr = stage.tr
    local k = clamp01(u.t / u.dur)
    local iw, ih = u.anim:getSize()
    local sw, sh = iw * s, ih * s
    local x = (tr and (tr.ox + u.u * 400 * tr.scale) or (w * u.u)) - sw / 2
    local y = (tr and (tr.oy + u.v * 256 * tr.scale) or (h * u.v)) - sh * 0.5 + math.sin(u.t * 1.6) * 2
    local bodyCx = x + sw / 2
    local appear = smooth(clamp01(k / 0.3))
    local lit = smooth(clamp01((k - 0.55) / 0.4)) * 0.10
    local rim = 0.15 + 0.55 * smooth(clamp01((k - 0.4) / 0.4))
    drawEclipseClosing(1, u.t + 10, 0)
    drawStrayEyes(u.t, 1 - smooth(clamp01((k - 0.6) / 0.25)))
    local floorY = stage.cy or (dy + sh)
    drawBigShadow(u.anim, bodyCx, floorY, s, 0.55 * appear)
    glowBlob(bodyCx, y + sh * 0.5, sw * 2.0, sh * 1.4, PAL.glow, 0.28 * appear, 1)
    local P = px()
    love.graphics.setBlendMode("add")
    for _, off in ipairs({ { -P, 0 }, { P, 0 }, { 0, -P }, { 0, P } }) do
        u.anim:draw(x + off[1], y + off[2], s, { PAL.rim[1], PAL.rim[2], PAL.rim[3], rim * appear * 0.8 })
    end
    love.graphics.setBlendMode("alpha")
    u.anim:draw(x, y, s, { 0.03 + lit, 0.01 + lit * 0.6, 0.05 + lit, appear })
    local halo = smooth(clamp01((k - 0.7) / 0.3))
    if halo > 0.02 then
        drawBrokenHalo(bodyCx, y + sh * 0.14, sw * 0.22, sw * 0.08, px(), GOLD, 0.8 * halo, u.t, 5)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local utf8lib = require("utf8")
local function splitChars(s)
    local out = {}
    for _, c in utf8lib.codes(s) do out[#out + 1] = utf8lib.char(c) end
    return out
end

local function drawCrownCard(w, h)
    local c = crownCard
    if not c then return end
    local a
    if c.t < 0.2 then a = smooth(c.t / 0.2)
    elseif c.t > c.dur - 0.5 then a = 1 - smooth(clamp01((c.t - (c.dur - 0.5)) / 0.5))
    else a = 1 end
    local uk = require("src.ui.UiScale").activeK()
    local P = math.max(2, math.floor(2 * uk + 0.5))
    local cy = math.floor(h * 0.79)
    love.graphics.setColor(0.03, 0.01, 0.05, 0.80 * a)
    love.graphics.rectangle("fill", 0, cy - c.size * 1.1, w, c.size * 2.7)
    love.graphics.setColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], 0.55 * a)
    love.graphics.rectangle("fill", 0, cy - c.size * 1.1, w, P)
    love.graphics.rectangle("fill", 0, cy + c.size * 1.6 - P, w, P)
    local font = FontManager.getFont(c.size)
    love.graphics.setFont(font)
    local total = font:getWidth(c.name)
    local x = math.floor(w / 2 - total / 2)
    local shown = math.min(#c.chars, math.floor(c.t / c.cadence))
    for i = 1, shown do
        local ch = c.chars[i]
        local age = c.t - i * c.cadence
        local pop = smooth(clamp01(age / 0.14))
        local dy = (1 - pop) * -6 * uk
        local la = a * pop
        love.graphics.setColor(MAGENTA[1], MAGENTA[2], MAGENTA[3], 0.85 * la)
        love.graphics.print(ch, x + P, cy + dy + P)
        love.graphics.setColor(GOLD[1], GOLD[2], GOLD[3], la)
        love.graphics.print(ch, x, cy + dy)
        x = x + font:getWidth(ch)
    end
    local hr = c.size * 1.25
    local hx = total / 2 + hr + c.size * 0.7
    local ha = a * smooth(clamp01((c.t - 0.3) / 0.5))
    drawBrokenHalo(w / 2 - hx, cy + c.size * 0.5, hr, hr * 0.45, P, GOLD, 0.8 * ha, c.t, 21)
    drawBrokenHalo(w / 2 + hx, cy + c.size * 0.5, hr, hr * 0.45, P, GOLD, 0.8 * ha, -c.t, 33)
    local nameDone = #c.chars * c.cadence
    if c.epithet ~= "" and c.t > nameDone + 0.25 then
        local ef = FontManager.getFont(math.max(12, math.floor(c.size * 0.42)))
        love.graphics.setFont(ef)
        local echars = c.echars
        local etot = ef:getWidth(c.epithet)
        local ex = math.floor(w / 2 - etot / 2)
        local ey = cy + c.size * 1.0
        local eshown = math.min(#echars, math.floor((c.t - nameDone - 0.25) / (c.cadence * 0.6)))
        for i = 1, eshown do
            local ch = echars[i]
            love.graphics.setColor(0, 0, 0, 0.7 * a)
            love.graphics.print(ch, ex + 1, ey + 1)
            love.graphics.setColor(1.0, 0.70, 0.92, a)
            love.graphics.print(ch, ex, ey)
            ex = ex + ef:getWidth(ch)
        end
    end
    if c.flashT then
        local ft = c.flashT
        local fa = (ft < 0.06) and 0.5 or ((ft < 0.14) and 0.28 or ((ft < 0.24) and 0.10 or 0))
        if fa > 0 then
            love.graphics.setColor(PAL.flash[1], PAL.flash[2], PAL.flash[3], fa)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPhaseShift()
    local ps = fx.phaseShift
    if not ps then return end
    local k = clamp01(ps.t / ps.dur)
    local cx, cy, r = eclipseCenter()
    if not cx then return end
    local P = px()
    local env = 1 - k
    drawBrokenHalo(cx, cy, r * (1.6 + 1.6 * easeOut(k)) + 2 * P, r * (1.4 + 1.4 * easeOut(k)), P,
        PAL.flash, 0.9 * env, ps.t, 44)
    glowBlob(cx, cy, r * 9 * (0.5 + k), r * 6 * (0.5 + k), PAL.glow, 0.45 * env, 3)
end

local function drawDawnV2(w, h)
    local d = fx.dawn
    local e = eclipse
    if not d or not stage or not stage.tr or not e then return end
    local tr = stage.tr
    local k = smooth(clamp01(d.t / d.dur))
    local cx, cy, r = eclipseCenter()
    local P = px()
    local open = clamp01(k * 1.3)
    if open > 0.02 then
        love.graphics.setColor(WARM[1], WARM[2], WARM[3], 0.95)
        local n = math.max(16, math.floor(2 * math.pi * r / P))
        for i = 0, n - 1 do
            local ang = i / n * math.pi * 2
            if math.cos(ang) > 1 - 2 * open then
                for rr = 0, r, P do
                    local bx = math.floor((cx + math.cos(ang) * rr) / P) * P
                    local by = math.floor((cy + math.sin(ang) * rr) / P) * P
                    if bayer(bx / P, by / P) < 0.5 + open * 0.5 then
                        love.graphics.rectangle("fill", bx, by, P, P)
                    end
                end
            end
        end
    end
    local bands = 5
    local lit = math.floor(k * bands + 1e-6)
    for b = 0, lit - 1 do
        local y0 = tr.oy + (b / bands) * 200 * tr.scale
        local hh = (1 / bands) * 200 * tr.scale
        glowBlob(cx, y0 + hh / 2, 90 * tr.scale, hh * 1.6, WARM, 0.22 * (1 - b * 0.08), 1 + b % 3)
    end
    glowBlob(cx, cy, r * 7 * (0.6 + 0.4 * k), r * 5 * (0.6 + 0.4 * k), WARM, 0.45 * k, 1)
    glowBlob(cx, cy, r * 3.2, r * 2.6, { 1, 0.95, 0.85 }, 0.55 * k, 3)
    if stage.bbox then
        local by = (stage.cy or stage.bbox.bottomY)
        glowBlob(stage.bbox.cx, by, (stage.bbox.width or 120) * 2.2, 40 * tr.scale, WARM, 0.25 * k, 2)
    end
end

local function queenEnter(st)
    local kind = st.kind
    if kind == "omen" then
        fx.omen = { t = 0, dur = math.max(0.3, st.dur or 3.5), steps = st.steps or 4, nextStep = 1 }
        ensureEclipse().active = true
        spawnHallEyes(fx.omen.dur)
        queueSfx(math.max(0.1, fx.omen.dur - 0.35), "bossBlinkClick", nil, 0.6)
        darkEase = { from = dark, to = st.to or 0.80, t = 0, dur = fx.omen.dur }
        play("bossEclipseOmen", nil)
        playLoop("bossEclipseHum")
        mistTarget(1, fx.omen.dur * 0.8)
        for i = 1, fx.omen.steps do
            queueSfx(i * fx.omen.dur / (fx.omen.steps + 0.5), "bossBlinkClick", nil, 0.7 + i * 0.05)
        end
        return true
    elseif kind == "unveil" then
        fx.unveil = { t = 0, dur = math.max(0.4, st.dur or 3.0), u = st.u or 0.5, v = st.v or 0.3,
                      anim = ownAnim(st.clip or "unveil", st.dur) }
        play("bossEclipseUnveil", nil)
        InteriorFX.gust(0.5, fx.unveil.dur)
        if _G.triggerShake and not seq.reduced then _G.triggerShake(2, fx.unveil.dur) end
        return true
    elseif kind == "coronation" then
        mistTarget(0.25, 1.6)
        bossClip(st.clip or "crown", 8)
        local id = seq.bossId
        local name = I18n.t("boss_cinematics." .. id .. ".name", nil,
            I18n.t("end_screen.enemy." .. id, nil, id))
        local epithet = I18n.t("boss_cinematics." .. id .. ".epithet", nil, "")
        local h = love.graphics.getHeight()
        local size = math.max(26, math.min(64, math.floor(h * 0.058)))
        local up = require("src.i18n.TextCase").upper(name)
        crownCard = { t = 0, dur = st.dur or 4, name = up, epithet = epithet, size = size,
                      chars = splitChars(up), echars = splitChars(epithet),
                      cadence = seq.reduced and 0.035 or (st.cadence or 0.085),
                      shown = 0, stung = false, flashT = nil }
        return true
    end
    return false
end

local function queenExit(st)
    if st.kind == "omen" then fx.omen = nil end
    if st.kind == "coronation" then hallEyes = nil end
    if st.kind == "unveil" then
        fx.unveil = nil
        if not (seq.steps[seq.idx + 1] and seq.steps[seq.idx + 1].kind == "descend") then
            bossHidden = false
            landed = true
        end
    end
    if st.kind == "coronation" then crownCard = nil end
end

local function queenDawnStart(st)
    if not (seq and seq.bossId == QUEEN_ID) then return end
    local e = ensureEclipse()
    e.active = true
    e.dawnEase = { t = 0, dur = math.max(0.5, fx.dawn and fx.dawn.dur or 2) }
    play("bossEclipseFade", nil)
    stopLoop("bossEclipseHum")
end

local function startPhaseShift()
    fx.phaseShift = { t = 0, dur = 1.4 }
    play("bossEclipsePhase", nil)
    if _G.triggerShake and not reducedMotion() then _G.triggerShake(10, 0.4) end
    InteriorFX.gust(0.8, 0.8)
    if stage and stage.tr and not reducedMotion() then
        local cx, cy = eclipseCenter()
        for _ = 1, 16 do
            spawnFeather(cx + (love.math.random() - 0.5) * 60 * px(), cy + (love.math.random() - 0.5) * 20,
                (love.math.random() - 0.5) * 50, 20 + love.math.random() * 40, "petal")
        end
    end
end

local function queenUpdate(dt, game, ctx)
    local en = game and game.enemy
    local isQueen = en and en.spriteId == QUEEN_ID and ctx and ctx.inHall
    if isQueen then
        local e = ensureEclipse()
        e.active = true
        e.t = e.t + dt
        local phase = en._phaseIdx or 0
        if phase > e.lastPhase and e.lastPhase >= 0 and en.health and en.health > 0 then
            startPhaseShift()
        end
        e.lastPhase = phase
        e.level = (phase > 0) and 1 or 0
        if en.health and en.health <= 0 and e.dawn <= 0 and not e.dawnEase and (deathFor == en) then
            e.dawn = 1
        end
        if not seq and e.dawn <= 0 and not reducedMotion() then
            e.nextGaze = e.nextGaze - dt
            if e.nextGaze <= 0 and not e.gaze then
                e.gaze = { t = 0, dur = 1.6 }
                e.nextGaze = 7 + love.math.random() * 6
            end
        end
    end
    if not eclipse then return end
    local e = eclipse
    if e.gaze then
        e.gaze.t = e.gaze.t + dt
        if e.gaze.t >= e.gaze.dur then e.gaze = nil end
    end
    if e.dawnEase then
        e.dawnEase.t = e.dawnEase.t + dt
        e.dawn = math.max(e.dawn, smooth(clamp01(e.dawnEase.t / e.dawnEase.dur)))
        if e.dawnEase.t >= e.dawnEase.dur then e.dawnEase = nil; e.dawn = 1 end
    end
    e.cur = e.cur + (e.level - e.cur) * math.min(1, dt * 1.5)
    if InteriorFX.setEclipse then InteriorFX.setEclipse(e.cur, e.dawn) end
    if fx.omen then
        local o = fx.omen
        o.t = o.t + dt
    end
    if hallEyes then
        local he = hallEyes
        he.t = he.t + dt
        if not he.turned and he.t >= he.turnAt then he.turned = true; he.flash = 2 end
        if he.flash and he.flash > 0 then he.flash = he.flash - 1 end
        if fx.unveil and not he.close and fx.unveil.t > fx.unveil.dur * 0.6 then he.close = 0 end
        if he.close then he.close = he.close + dt end
    end
    if fx.unveil then
        fx.unveil.t = fx.unveil.t + dt
        if fx.unveil.anim then fx.unveil.anim:update(dt) end
        if stage and stage.tr and not reducedMotion() and love.math.random() < 0.35 then
            local cx, cy = eclipseCenter()
            spawnFeather(cx + (love.math.random() - 0.5) * 50 * px(), cy + 10 * px(),
                (love.math.random() - 0.5) * 20, 25 + love.math.random() * 30, "ash_fall")
        end
    end
    if fx.phaseShift then
        fx.phaseShift.t = fx.phaseShift.t + dt
        if fx.phaseShift.t >= fx.phaseShift.dur then fx.phaseShift = nil end
    end
    if crownCard then
        local c = crownCard
        c.t = c.t + dt
        local shown = math.min(#c.chars, math.floor(c.t / c.cadence))
        if shown > c.shown then
            for i = c.shown + 1, shown do
                play("bossCrownTick", nil, math.min(1.6, 0.85 + i * 0.045), 0)
            end
            c.shown = shown
            if shown == #c.chars and not c.stung then
                c.stung = true
                c.flashT = 0
                play("bossEclipseCrown", "bossRevealSting")
                if _G.triggerShake and not seq.reduced then _G.triggerShake(6, 0.3) end
                if not seq.reduced then
                    local okC, CRT = pcall(require, "src.ui.CRTShader")
                    if okC and CRT.jolt then CRT.jolt(0.10) end
                end
            end
        end
        if c.flashT then c.flashT = c.flashT + dt end
    end
    if fx.dawn and seq and seq.bossId == QUEEN_ID and stage and stage.bbox
        and not reducedMotion() then
        local wdt = (stage.bbox.width or 120)
        for _ = 1, 2 do
            if love.math.random() < 0.6 then
                spawnFeather(stage.bbox.cx + (love.math.random() - 0.5) * wdt,
                    (stage.cy or stage.bbox.bottomY) - love.math.random() * 40,
                    (love.math.random() - 0.5) * 30, -45 - love.math.random() * 70, "ash")
            end
        end
    end
end

local function queenDrawBack(w, h)
    if not (eclipse and eclipse.active) then return end
    local e = eclipse
    drawOmen(w, h)
    drawHallEyes()
    if not seq and e.dawn <= 0 then
        local gazeOpen = 0
        if e.gaze then
            local g = e.gaze
            gazeOpen = math.min(smooth(clamp01(g.t / 0.3)), smooth(clamp01((g.dur - g.t) / 0.3)))
        end
        if e.cur > 0.02 or gazeOpen > 0 then
            drawEclipseClosing(e.cur, e.t, gazeOpen)
        end
    end
    drawPhaseShift()
    drawUnveil(w, h)
    if crownCard and crownCard.flashT and stage.bbox then
        local env = 1 - clamp01(crownCard.flashT / 1.6)
        if env > 0.02 then
            drawEclipseClosing(0.9 * env, crownCard.t + 20, 0)
            local bb = stage.bbox
            local hy = bb.topY + (bb.bottomY - bb.topY) * 0.10
            local rr = (bb.width or 120) * (0.22 + 0.10 * (1 - env))
            drawBrokenHalo(bb.cx, hy, rr, rr * 0.32, px(), GOLD, 0.9 * env, crownCard.flashT * 3, 13)
            drawBrokenHalo(bb.cx, hy, rr * 1.35, rr * 0.45, px(), MAGENTA, 0.6 * env, -crownCard.flashT * 2, 17)
            glowBlob(bb.cx, hy, rr * 4, rr * 2, GOLD, 0.35 * env, 2)
        end
    end
    if seq and seq.bossId == QUEEN_ID then drawDawnV2(w, h) end
end

local function queenDrawFront()
    if not (eclipse and eclipse.active and stage and stage.bbox) then return end
    local e = eclipse
    if e.cur > 0.05 and e.dawn <= 0 and not bossHidden and landed then
        local bb = stage.bbox
        local hx = bb.cx
        local hy = bb.topY + (bb.bottomY - bb.topY) * 0.10
        drawBrokenHalo(hx, hy, (bb.width or 120) * 0.22, (bb.width or 120) * 0.07, px(),
            MAGENTA, 0.75 * e.cur, e.t, 7)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function queenDrawUI(w, h)
    drawCrownCard(w, h)
end

local function enterStep(st)
    local kind = st.kind
    if queenEnter(st) then
    elseif kind == "dark" then
        darkEase = { from = dark, to = st.to or 0, t = 0, dur = math.max(0.01, st.dur or 0.3) }
    elseif kind == "eyes" then
        eyes = { u = st.u or 0.5, v = st.v or 0.4, size = st.size or 0.05,
                 blinks = st.blinks or {}, blinked = {}, t = 0, dur = st.dur or 2,
                 track = st.track ~= false }
        mistTarget(1, 1.2)
        play("bossEyesIgnite", nil)
        playLoop("bossEyesRumble")
    elseif kind == "flyby" then
        eyes = nil
        ensureFlyAnim(seq.bossId)
        fly = { from = st.from or "left", v = st.v or 0.4, ghosts = st.ghosts or 2,
                arc = st.arc or 0, land = st.land, lights = st.lights,
                scale = st.scale or 1, near = (st.scale or 1) > 1.2,
                t = 0, dur = math.max(0.05, st.dur or 0.5), startDark = dark, trail = {} }
        if st.lights then
            darkEase = { from = dark, to = st.lights, t = 0, dur = fly.dur }
        end
        mistGustDir = (fly.from == "left") and 1 or -1
        InteriorFX.gust(1.0, fly.dur + 0.35)
        edge = { side = fly.from, t = 0, dur = fly.dur + 0.25, out = (fly.from == "left") and "right" or "left" }
        stopLoop("bossEyesRumble")
        play("bossWingPass", "sceneRustle", (fly.near and 0.78 or 0.95) + love.math.random() * 0.12, 0)
        if st.caw then play("crowCine") end
    elseif kind == "land" then
        fly = nil
        fx.runes = nil
        if fx.roots and not fx.roots.retractT then fx.roots.retractT = 0 end
        if st.cracks and stage and stage.bbox then
            startCracks(stage.bbox.cx, stage.cy or stage.bbox.bottomY, stage.bbox.width or 120)
        end
        bossHidden = false
        landed = true
        if T3.bond and T3.bond.state == "drag" then
            T3.bond.state = "taut"; T3.bond.tautT = 0
            queueSfx(0.05, "tyrantChainTaut", "bossChainsRattle")
        end
        darkEase = { from = dark, to = 0, t = 0, dur = math.max(0.15, (st.dur or 0.5) * 0.6) }
        mistTarget(0.35, 0.45)
        edge = nil
        EnemyRenderer.triggerArrival()
        if st.clip ~= false then bossClip(st.clip or "land", 12) end
        if _G.triggerShake and (st.shake or 0) > 0 then _G.triggerShake(st.shake, 0.38) end
        if _G.jiggleScreen and not seq.reduced then _G.jiggleScreen(1.0) end
        play(st.sound or "bossLandImpact", "bootImpact")
        local crowsN = st.crows or 5
        if crowsN > 0 then
            queueSfx(0.45, "bossFeathersSettle", nil)
            queueSfx(0.15, "crowFlock", nil)
        end
        if st.after then queueSfx(st.afterDelay or 0.4, st.after, nil) end
        if stage and stage.bbox then
            local gx = stage.bbox.cx
            local gy = stage.cy or stage.bbox.bottomY
            spawnDust(gx, gy, st.dust or 12, stage.bbox.width or 120)
            local body = stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.45
            if crowsN > 0 then spawnCrows(gx, body, crowsN, 260) end
            if st.hit ~= false then startHit(gx, body, st.ring) end
            for _ = 1, (st.burst or 12) do
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120),
                    body + (love.math.random() - 0.5) * 40,
                    (love.math.random() - 0.5) * 60, -20 + love.math.random() * 10, st.particle)
            end
        end
        InteriorFX.gust(0.6, 0.5)
    elseif kind == "title" then
        mistTarget(0, 1.6)
        if fx.cracks then fx.cracks.fadeT = 0 end
        if st.clip ~= false then bossClip(st.clip or "roar", 10) end
        play("bossRevealSting", "enemyBuffRoar")
        local id = seq.bossId
        local name = I18n.t("boss_cinematics." .. id .. ".name", nil,
            I18n.t("end_screen.enemy." .. id, nil, id))
        local epithet = I18n.t("boss_cinematics." .. id .. ".epithet", nil, "")
        local h = love.graphics.getHeight()
        local size = math.max(26, math.min(64, math.floor(h * 0.058)))
        title = { t = 0, dur = st.dur or 2, name = name, epithet = epithet, size = size,
                  dyna = DynaText.new({
                      text = require("src.i18n.TextCase").upper(name),
                      fontSize = size, pop_in = 0.32, pop_in_rate = 3.2,
                      bump = not seq.reduced, bump_phase = 0.42, bump_amount = 0.28,
                      bump_rate = 2.2,
                      colours = { { 0.95, 0.82, 0.52, 1 } }, shadow = true,
                  }) }
    elseif kind == "hud" then
        hudHidden = false
    elseif kind == "slowmo" then
        slowmo = { scale = st.scale or 0.35, dur = st.dur or 1.2, release = st.release or 0.3, t = 0 }
        play("bossDeathThud", nil, 0.9, 0.05)
    elseif kind == "burst" then
        local pk = st.particle or "feather"
        play(st.sound or "bossFeatherBurst", nil)
        if (st.crows or 0) > 0 then queueSfx(0.12, "crowCine", nil) end
        if stage and stage.bbox then
            local gx = stage.bbox.cx
            local body = stage.bbox.topY + (stage.bbox.bottomY - stage.bbox.topY) * 0.42
            for _ = 1, (st.feathers or st.n or 16) do
                local a = love.math.random() * math.pi * 2
                local sp = 60 + love.math.random() * 160
                spawnFeather(gx + (love.math.random() - 0.5) * (stage.bbox.width or 120) * 0.6,
                    body + (love.math.random() - 0.5) * (stage.bbox.height or 200) * 0.5,
                    math.cos(a) * sp, math.sin(a) * sp * 0.6 - 40, pk)
            end
            if (st.crows or 0) > 0 then spawnCrows(gx, body, st.crows, 200) end
        end
    elseif kind == "desat" then
        desat = { peak = st.peak or 0.7, rise = st.rise or 0.4, fall = st.fall or 1.2,
                  total = remainingDuration(seq.idx), t = 0 }
    elseif kind == "hold" then
        playLoop("bossHoldAmbience")
    elseif kind == "lava" then
        fx.lava = { t = 0, dur = math.max(0.5, remainingDuration(seq.idx)), bubble = 0 }
    elseif kind == "dawn" then
        fx.dawn = { t = 0, dur = math.max(0.5, remainingDuration(seq.idx)),
                    u = st.u or 0.5, v = st.v or 0.23 }
        queenDawnStart(st)
    elseif kind == "runes" then
        fx.runes = { n = st.n or 5, t = 0, dur = math.max(0.3, st.dur or 1.5) }
        mistTarget(1, 1.0)
        for i = 1, fx.runes.n do
            queueSfx((i - 1) * fx.runes.dur / fx.runes.n, "bossRuneIgnite", "orbChannel", 0.9 + i * 0.05)
        end
    elseif kind == "rise" then
        fx.riser = { t = 0, dur = math.max(0.3, st.dur or 1.4), anim = ownAnim(st.clip, st.dur) }
        if st.storm then playLoop(st.storm) end
        InteriorFX.gust(0.8, fx.riser.dur)
        if _G.triggerShake then _G.triggerShake(4, fx.riser.dur) end
    elseif kind == "whiteout" then
        fx.white = { t = 0, dur = math.max(0.3, st.dur or 1.8), peak = st.peak or 0.9 }
        playLoop("bossBlizzard")
        InteriorFX.gust(1.0, st.dur or 1.8)
        mistTarget(0.8, 0.8)
    elseif kind == "silhouette" then
        enterSilhouette(st)
    elseif kind == "settle" then
        if fx.white then fx.white.fade = { t = 0, dur = math.max(0.2, st.dur or 0.8) } end
        fx.sil = nil
        bossHidden = false
        landed = true
        stopLoop("bossBlizzard")
        mistTarget(0.3, st.dur or 0.8)
        play("bossIceCrackle", nil)
    elseif kind == "door_burst" then
        local tr = stage and stage.tr
        local gx = tr and (tr.ox + (st.u or 0.5) * 400 * tr.scale) or (stage and stage.w or 960) / 2
        local gy = tr and (tr.oy + (st.v or 0.5) * 256 * tr.scale) or (stage and stage.h or 540) / 2
        startHit(gx, gy)
        if _G.triggerShake then _G.triggerShake(st.shake or 18, 0.45) end
        play("bossDoorBurst", "castleGateMagic")
        darkEase = { from = dark, to = st.lights or 0.35, t = 0, dur = 0.4 }
        mistTarget(0.9, 0.5)
        for _ = 1, (st.debris or 16) do
            local a = -math.pi * (0.1 + 0.8 * love.math.random())
            local sp = 120 + love.math.random() * 260
            spawnFeather(gx + (love.math.random() - 0.5) * 60, gy + (love.math.random() - 0.5) * 40,
                math.cos(a) * sp, math.sin(a) * sp, "shard")
        end
        for _ = 1, 14 do
            spawnFeather(gx + (love.math.random() - 0.5) * 80, gy + (love.math.random() - 0.5) * 60,
                (love.math.random() - 0.5) * 80, -40 - love.math.random() * 60, "ember")
        end
    elseif kind == "firewall" then
        fx.fire = { t = 0, total = (st.dur or 1.4) + (st.hold or 0), v = st.v or 0.6, h = st.h or 0.3 }
        playLoop("bossHellfireWall")
        InteriorFX.gust(0.7, fx.fire.total)
    elseif kind == "chains" then
        T3.bond = (stage and stage.hall and T3.chained(seq.bossId))
            and { id = seq.bossId, state = "drag", t = 0 } or nil
        if T3.bond then play("tyrantChainDrag", "bossChainsRattle") end
    elseif kind == "walk_in" then
        fx.walker = { t = 0, dur = math.max(0.4, st.dur or 1.8), anim = ownAnim(st.clip, st.dur), clip = st.clip,
                      stomp = st.stomp, nextStomp = st.stomp or 1e9 }
        if st.sound then play(st.sound, nil) end
    elseif kind == "heartbeat" then
        fx.heart = { t = 0, dur = (st.dur or 1.6) + (st.hold or 0), rate = st.rate or 2.0, nextBeat = 0 }
        if InteriorFX.pulseBoost then InteriorFX.pulseBoost(st.boost or 2.0, fx.heart.dur) end
        mistTarget(1, 1.0)
    elseif kind == "roots" then
        startRoots(st)
    elseif kind == "assemble" then
        enterAssemble(st)
    elseif kind == "crumble" then
        enterCrumble(st)
    elseif kind == "eclipse" then
        fx.ecl = { t = 0, dur = math.max(0.3, st.dur or 1.6), u = st.u or 0.5, v = st.v or 0.23 }
        darkEase = { from = dark, to = st.to or 0.9, t = 0, dur = fx.ecl.dur }
        playLoop("bossEclipseHum")
        mistTarget(1, 1.2)
    elseif kind == "trophy" then
        require("src.ui.BossTrophy").start(st, stage, seq.reduced)
    elseif kind == "descend" then
        fx.desc = { t = 0, dur = math.max(0.4, st.dur or 1.8), u = st.u or 0.5, v = st.v or 0.2,
                    backlit = st.backlit ~= false, anim = ownAnim(st.clip, st.dur) }
        play("bossDescendWings", nil)
        if st.lights then darkEase = { from = dark, to = st.lights, t = 0, dur = fx.desc.dur } end
    else
        if not warnedKind[kind or "nil"] then
            warnedKind[kind or "nil"] = true
            require("src.core.Debug").warn("[BossCinematic] passo desconhecido '" .. tostring(kind) .. "' — pulado")
        end
    end
end

local function exitStep(st)
    queenExit(st)
    if st.kind == "trophy" then require("src.ui.BossTrophy").stop() end
    if st.kind == "eyes" then eyes = nil; stopLoop("bossEyesRumble") end
    if st.kind == "flyby" then
        if st.land then
            if not (seq.steps[seq.idx + 1] and seq.steps[seq.idx + 1].kind == "land") then
                bossHidden = false
                landed = true
            end
        end
        fly = nil
    end
    if st.kind == "title" then title = nil end
    if st.kind == "rise" then
        fx.riser = nil; bossHidden = false; landed = true
        if st.storm then stopLoop(st.storm) end
    end
    if st.kind == "walk_in" then fx.walker = nil; bossHidden = false; landed = true end
    if st.kind == "assemble" then fx.asm = nil; bossHidden = false; landed = true end
    if st.kind == "crumble" then
        bossHidden = false
        if fx.crumble then fx.crumble.fadeT = 0 end
    end
    if st.kind == "descend" then fx.desc = nil; bossHidden = false; landed = true
        stopLoop("bossEclipseHum") end
    if st.kind == "roots" then stopLoop("bossRootsCrawl") end
    if st.kind == "firewall" and (st.hold or 0) == 0 then fx.fire = nil; stopLoop("bossHellfireWall") end
end

function BossCinematic.update(dt, game, ctx)
    ctx = ctx or {}
    if not dummy and love.graphics and love.graphics.newCanvas then
        local ok, c = pcall(love.graphics.newCanvas, 4, 4)
        if ok then dummy = c end
    end

    if game and game.enemy and game.enemy.isBoss and game._deathHandled
        and ctx.inHall and not (seq and seq.phase == "death") then
        BossCinematic.startDeath(game)
    end

    if seq then
        seq.t = seq.t + dt
        local remaining = dt
        while seq and seq.idx <= #seq.steps do
            local st = seq.steps[seq.idx]
            if not st._entered then
                st._entered = true
                enterStep(st)
                if not seq then break end
            end
            local dur = st.dur or 0
            local need = dur - seq.stepT
            if remaining >= need then
                remaining = remaining - need
                seq.stepT = 0
                exitStep(st)
                seq.idx = seq.idx + 1
            else
                seq.stepT = seq.stepT + remaining
                break
            end
        end
        if seq and seq.idx > #seq.steps then finish() end
    end
    require("src.ui.BossTrophy").update(dt)

    if darkEase then
        darkEase.t = darkEase.t + dt
        local k = clamp01(darkEase.t / darkEase.dur)
        dark = lerp(darkEase.from, darkEase.to, smooth(k))
        if k >= 1 then darkEase = nil end
    end
    if eyes then
        eyes.t = eyes.t + dt
        for i, bt in ipairs(eyes.blinks) do
            if not eyes.blinked[i] and eyes.t >= bt then
                eyes.blinked[i] = true
                play("bossBlinkClick", nil, 0.9 + love.math.random() * 0.2, 0)
            end
        end
    end
    for i = #sfxQueue, 1, -1 do
        local q = sfxQueue[i]
        q.t = q.t - dt
        if q.t <= 0 then
            play(q.code, q.fallback, q.pitch, 0)
            table.remove(sfxQueue, i)
        end
    end
    if edge then
        edge.t = edge.t + dt
        if edge.t >= edge.dur then edge = nil end
    end
    if fly then
        fly.t = fly.t + dt
        if flyAnim then flyAnim:update(dt) end
        if stage then
            local x, y, sw, sh = flyPos(fly, clamp01(fly.t / fly.dur), stage.w, stage.h)
            local tr = fly.trail
            tr[#tr + 1] = { x = x, y = y, t = fly.t }
            if #tr > 12 then table.remove(tr, 1) end
            local dirX = (fly.from == "left") and 1 or -1
            local backX = (dirX > 0) and x or (x + sw)
            if not seq.reduced then
                local nW = fly.near and 7 or 5
                for _ = 1, nW do
                    local wx = x + love.math.random() * sw
                    spawnWind(wx, y + sh * (0.1 + love.math.random() * 0.8), -dirX,
                        (60 + love.math.random() * 160) * (fly.scale or 1), fly.near)
                end
                if love.math.random() < 0.5 then
                    spawnFeather(backX + (love.math.random() - 0.5) * sw * 0.3,
                        y + sh * (0.3 + love.math.random() * 0.4),
                        -dirX * (40 + love.math.random() * 80), 10 + love.math.random() * 30)
                end
            end
        end
    end
    if title then
        title.t = title.t + dt
        title.dyna:update(dt)
    end
    if slowmo then
        slowmo.t = slowmo.t + dt
        local k
        if slowmo.t < slowmo.dur then
            k = slowmo.scale
        else
            local r = clamp01((slowmo.t - slowmo.dur) / math.max(0.01, slowmo.release))
            k = lerp(slowmo.scale, 1, smooth(r))
            if r >= 1 then slowmo = nil end
        end
        EnemyRenderer.setTimeScale(k)
    elseif not seq then
        EnemyRenderer.setTimeScale(1)
    end
    if desat then
        desat.t = desat.t + dt
        if desat.t >= desat.total then desat = nil end
    end

    if fx.runes then fx.runes.t = fx.runes.t + dt end
    if fx.riser then
        local r = fx.riser
        r.t = r.t + dt
        if r.anim then r.anim:update(dt) end
        if stage and stage.bbox and not reducedMotion() then
            local n = (r.t < r.dur * 0.6) and 3 or 1
            local gy = stage.cy or stage.bbox.bottomY
            local wdt = (stage.bbox.width or 120) * 0.9
            for _ = 1, n do
                spawnFeather(stage.bbox.cx + (love.math.random() - 0.5) * wdt, gy - love.math.random() * 8,
                    (love.math.random() - 0.5) * 70, -60 - love.math.random() * 120, "ember")
            end
        end
    end
    updateSilhouette(dt)
    if fx.white then
        fx.white.t = fx.white.t + dt
        if fx.white.fade then
            fx.white.fade.t = fx.white.fade.t + dt
            if fx.white.fade.t >= fx.white.fade.dur then fx.white = nil end
        end
        if fx.white and stage and not reducedMotion() then
            for _ = 1, 3 do
                flakes[#flakes + 1] = { x = love.math.random() * stage.w, y = -8,
                    vx = -120 - love.math.random() * 160, vy = 160 + love.math.random() * 200, life = 2 }
            end
        end
    end
    for i = #flakes, 1, -1 do
        local fl = flakes[i]
        fl.x = fl.x + fl.vx * dt; fl.y = fl.y + fl.vy * dt; fl.life = fl.life - dt
        if fl.life <= 0 or (stage and (fl.y > stage.h or fl.x < -20)) then table.remove(flakes, i) end
    end
    if fx.fire then
        fx.fire.t = fx.fire.t + dt
        if stage and not reducedMotion() and love.math.random() < 0.5 and stage.tr then
            local tr = stage.tr
            spawnFeather(tr.ox + love.math.random() * 400 * tr.scale,
                tr.oy + fx.fire.v * 256 * tr.scale, (love.math.random() - 0.5) * 30,
                -60 - love.math.random() * 80, "ember")
        end
        if fx.fire.t >= fx.fire.total then fx.fire = nil; stopLoop("bossHellfireWall") end
    end
    if fx.walker then
        local wk = fx.walker
        wk.t = wk.t + dt
        if wk.anim then wk.anim:update(dt) end
        if wk.stomp and wk.t >= wk.nextStomp then
            wk.nextStomp = wk.nextStomp + wk.stomp
            if _G.triggerShake then _G.triggerShake(7, 0.2) end
            play("sceneStoneThud", nil, 0.8, 0.1)
        end
    end
    if fx.heart then
        local hb = fx.heart
        hb.t = hb.t + dt
        if hb.t >= hb.nextBeat then
            hb.nextBeat = hb.nextBeat + 1 / hb.rate
            play("bossHeartbeat", nil, 0.95, 0.05)
            if _G.triggerShake and not reducedMotion() then _G.triggerShake(3, 0.12) end
        end
        if hb.t >= hb.dur then fx.heart = nil end
    end
    if fx.roots then
        fx.roots.t = fx.roots.t + dt
        if fx.roots.retractT then
            fx.roots.retractT = fx.roots.retractT + dt
            if fx.roots.retractT >= 0.7 then fx.roots = nil; stopLoop("bossRootsCrawl") end
        end
    end
    if fx.asm then
        local a = fx.asm
        a.t = a.t + dt
        if stage and stage.bbox and not reducedMotion() and love.math.random() < dt * 5 then
            local b = stage.bbox
            spawnFeather(b.cx + (love.math.random() - 0.5) * (b.width or 120) * 0.6,
                b.bottomY - (b.bottomY - b.topY) * clamp01(a.t / a.dur) * love.math.random(),
                (love.math.random() - 0.5) * 30, -20 - love.math.random() * 40, "spore")
        end
    end
    if fx.cracks then
        fx.cracks.t = fx.cracks.t + dt
        if fx.cracks.fadeT then
            fx.cracks.fadeT = fx.cracks.fadeT + dt
            if fx.cracks.fadeT >= 2.4 then fx.cracks = nil end
        end
    end
    if fx.crumble then
        updateCrumble(dt)
        if fx.crumble.fadeT and fx.crumble.fadeT >= BossCinematic.CRUMBLE_FADE then fx.crumble = nil end
    end
    if fx.ecl then fx.ecl.t = fx.ecl.t + dt end
    if fx.dawn then fx.dawn.t = fx.dawn.t + dt end
    if fx.lava then
        local lv = fx.lava
        lv.t = lv.t + dt
        lv.bubble = lv.bubble + dt
        if stage and stage.bbox and not reducedMotion() and lv.bubble > 0.09 then
            lv.bubble = 0
            local k = clamp01(lv.t / lv.dur)
            local wdt = (stage.bbox.width or 120) * (0.4 + 0.8 * k)
            spawnFeather(stage.bbox.cx + (love.math.random() - 0.5) * wdt,
                (stage.cy or stage.bbox.bottomY) - love.math.random() * 6,
                (love.math.random() - 0.5) * 30, -30 - love.math.random() * 60, "ember")
        end
    end
    if fx.desc then fx.desc.t = fx.desc.t + dt; if fx.desc.anim then fx.desc.anim:update(dt) end end
    updateMist(dt)
    T3.updateBond(dt, game, ctx)
    queenUpdate(dt, game, ctx)
    if hit then
        hit.t = hit.t + dt
        if hit.t >= hit.dur then hit = nil end
    end
    updateFx(dt)
end

function BossCinematic.desatAmount()
    if not desat then return 0 end
    local t = desat.t
    local up = clamp01(t / math.max(0.01, desat.rise))
    local downStart = math.max(desat.rise, desat.total - desat.fall)
    local down = (t > downStart) and clamp01((t - downStart) / math.max(0.01, desat.fall)) or 0
    return desat.peak * smooth(up) * (1 - smooth(down))
end

function BossCinematic.measure(drawFn)
    if not dummy then return nil end
    local prev = love.graphics.getCanvas()
    love.graphics.setCanvas(dummy)
    local ok, res = pcall(drawFn)
    if prev then love.graphics.setCanvas(prev) else love.graphics.setCanvas() end
    love.graphics.setColor(1, 1, 1, 1)
    if not ok then
        require("src.core.Debug").warn("[BossCinematic] medição falhou: " .. tostring(res))
        return nil
    end
    return res
end

local function ensureDesatShader()
    if desatShader or desatTried then return desatShader end
    desatTried = true
    local ok, sh = pcall(love.graphics.newShader, "shaders/desat.glsl")
    if ok then desatShader = sh else
        require("src.core.Debug").warn("[BossCinematic] shaders/desat.glsl não carregou: " .. tostring(sh)
            .. " — morte sem dessaturação")
    end
    return desatShader
end

local worldPrev = nil
function BossCinematic.beginWorldPass()
    local amt = BossCinematic.desatAmount()
    if amt <= 0.005 then return false end
    if not ensureDesatShader() then return false end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if not worldCanvas or worldCanvas:getWidth() ~= w or worldCanvas:getHeight() ~= h then
        local ok, c = pcall(love.graphics.newCanvas, w, h)
        if not ok then return false end
        worldCanvas = c
        worldCanvas:setFilter("nearest", "nearest")
    end
    worldPrev = love.graphics.getCanvas()
    love.graphics.setCanvas(worldCanvas)
    love.graphics.clear(0, 0, 0, 1)
    return true
end

function BossCinematic.endWorldPass()
    if worldPrev then love.graphics.setCanvas(worldPrev) else love.graphics.setCanvas() end
    worldPrev = nil
    desatShader:send("amount", BossCinematic.desatAmount())
    love.graphics.setShader(desatShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(worldCanvas, 0, 0)
    love.graphics.setShader()
end

local EYE_ROWS = {
    "...######...",
    ".##iiiiii##.",
    "#iiccccccii#",
    "#icc....cci#",
    "#iiccccccii#",
    ".##iiiiii##.",
    "...######...",
}
local EYE_RIM  = { 0.72, 0.26, 0.06 }
local EYE_IRIS = { 1.00, 0.58, 0.14 }
local function drawEyes(w, h)
    if not eyes or not stage or not stage.tr then return end
    local tr = stage.tr
    local B = math.max(2, math.floor(eyes.size * 256 * tr.scale / 12 + 0.5))
    local ex = tr.ox + eyes.u * 400 * tr.scale
    local ey = tr.oy + eyes.v * 256 * tr.scale
    local t = eyes.t
    local open = smooth(clamp01(t / 0.6))
    for _, bt in ipairs(eyes.blinks) do
        local d = math.abs(t - bt)
        if d < 0.12 then open = math.min(open, d / 0.12) end
    end
    local closing = eyes.dur - t
    if closing < 0.18 then open = math.min(open, clamp01(closing / 0.18)) end
    local rows = math.floor(open * 7 + 0.5)
    if rows <= 0 then return end
    local glow = 0.80 + 0.20 * math.sin(t * 7.3)
    local track = 0
    if eyes.track then
        local saccade = math.floor(t * 0.9) % 3 - 1
        track = math.floor(1.6 * math.sin(t * 0.8) + saccade * 0.6 + 0.5)
        track = math.max(-2, math.min(2, track))
    end
    local gap = 17 * B
    local ew, eh = 12 * B, 7 * B
    local lo = 4 - math.floor((rows - 1) / 2)
    local hi = 4 + math.floor(rows / 2)
    for side = -1, 1, 2 do
        local cx = math.floor(ex + side * gap / 2)
        local x0, y0 = cx - ew / 2, ey - eh / 2
        local ha = 0.6 * glow * (rows / 7)
        glowBlob(cx, ey, ew * 3.0, eh * 3.2, EYE_HALO, ha * 0.5, 1 + (side + 1) / 2)
        glowBlob(cx, ey, ew * 1.7, eh * 1.9, EYE_CORE, ha * 0.4, 3)
        if not reducedMotion() then
            for k = 0, 2 do
                local rise = ((t * 22 + k * 11) % 34)
                local wob = math.sin(t * 9 + k * 2.1) * 2 * B
                glowBlob(cx + wob, ey - eh * 0.6 - rise, ew * (0.9 - k * 0.15), eh * 0.5,
                    EYE_HALO, ha * 0.22 * (1 - rise / 34), 1 + k)
            end
        end
        for r = lo, hi do
            local line = EYE_ROWS[r]
            for c = 1, 12 do
                local ch = line:sub(c, c)
                if ch ~= "." then
                    local col
                    if ch == "#" then col = EYE_RIM
                    elseif ch == "i" then col = EYE_IRIS
                    else col = EYE_CORE end
                    love.graphics.setColor(col[1], col[2] * (0.9 + 0.1 * glow), col[3], 1)
                    love.graphics.rectangle("fill", x0 + (c - 1) * B, y0 + (r - 1) * B, B, B)
                end
            end
        end
        local pc = 6 + track
        love.graphics.setColor(0.22, 0.04, 0.02, 1)
        for r = math.max(lo, 2), math.min(hi, 6) do
            love.graphics.rectangle("fill", x0 + (pc - 1) * B, y0 + (r - 1) * B, 2 * B, B)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local EYE_ANCHORS = { { 0.435, 0.24 }, { 0.545, 0.24 } }

local function drawFly(w, h)
    if not fly or not flyAnim or not stage then return end
    local k = clamp01(fly.t / fly.dur)
    local x, y, sw, sh, s = flyPos(fly, k, w, h)
    local tr = fly.trail
    local n = fly.ghosts or 0
    for i = 1, #tr, 2 do
        local p = tr[i]
        local a = 0.26 * (i / #tr)
        local col = (i % 6 == 1) and PAL.ember or PAL.glow
        glowBlob(p.x + sw * 0.5, p.y + sh * 0.5, sw * 1.15, sh * 0.75, col, a, 1 + i % 3)
    end
    love.graphics.setBlendMode("add")
    local lag = fly.near and 1 or 2
    for g = n, 1, -1 do
        local p = tr[#tr - g * lag]
        if p then
            local a = (fly.near and 0.5 or 0.55) * (1 - (g - 1) / math.max(1, n))
            flyAnim:draw(p.x, p.y, s, { PAL.ghost[1] + 0.15, PAL.ghost[2] + 0.1, PAL.ghost[3] + 0.15, a })
        end
    end
    local P = math.max(1, math.floor(s + 0.5))
    for _, off in ipairs({ { -P, 0 }, { P, 0 }, { 0, -P }, { 0, P } }) do
        flyAnim:draw(x + off[1], y + off[2], s, { PAL.rim[1], PAL.rim[2], PAL.rim[3], 0.32 })
    end
    love.graphics.setBlendMode("alpha")
    flyAnim:draw(x, y, s, { 1, 0.98, 1.04, 1 })
    love.graphics.setBlendMode("add")
    flyAnim:draw(x, y, s, { 0.55, 0.45, 0.80, 0.22 })
    love.graphics.setBlendMode("alpha")
    local glow = 0.8 + 0.2 * math.sin(fly.t * 23)
    for _, e in ipairs(EYE_ANCHORS) do
        local ex = x + e[1] * sw
        local ey = y + e[2] * sh
        glowBlob(ex, ey, 10 * P, 6 * P, EYE_HALO, 0.6 * glow, 2)
        glowBlob(ex, ey, 5 * P, 3 * P, EYE_CORE, 0.9 * glow, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawEdge(w, h)
    if not edge or reducedMotion() then return end
    local k = clamp01(edge.t / edge.dur)
    local env = (k < 0.35) and (k / 0.35) or (1 - (k - 0.35) / 0.65)
    local a = 0.30 * math.max(0, env)
    local side = (k < 0.5) and edge.side or edge.out
    local cx = (side == "left") and (w * 0.04) or (w * 0.96)
    for i = 0, 3 do
        glowBlob(cx + (love.math.random() - 0.5) * 8, h * (0.15 + i * 0.23),
            w * 0.22, h * 0.34, PAL.glow, a * (0.8 + 0.2 * math.sin(edge.t * 31 + i)), 1 + i % 3)
    end
end

local function drawWind()
    local P = px()
    for _, wv in ipairs(wind) do
        local k = wv.life / wv.max
        local th = wv.thick and 2 * P or P
        local len = math.floor(wv.len * (0.4 + 0.6 * k) / P) * P
        local x0 = (wv.vx < 0) and (wv.x - len) or wv.x
        local y = math.floor(wv.y / P) * P
        local seg = math.max(P, math.floor(len / 3 / P) * P)
        for i = 0, 2 do
            local a = (0.75 - i * 0.22) * k
            love.graphics.setColor(WIND_COLOR[1], WIND_COLOR[2], WIND_COLOR[3], a)
            local sx = (wv.vx < 0) and (x0 + len - (i + 1) * seg) or (x0 + i * seg)
            love.graphics.rectangle("fill", math.floor(sx), y, seg, th)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawFeathers()
    local P = px()
    for _, f in ipairs(feathers) do
        local a = clamp01(f.life / f.max * 1.6)
        local c = f.light and PAL.particle2 or PAL.particle
        local kind = f.kind or "feather"
        if kind == "ember" or kind == "spore" then
            local col = (kind == "ember") and PAL.ember or PAL.glow
            love.graphics.setColor(col[1], col[2], col[3], a)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), P, P)
            if kind == "ember" then
                love.graphics.setBlendMode("add")
                love.graphics.setColor(col[1], col[2], col[3], a * 0.35)
                love.graphics.rectangle("fill", math.floor(f.x) - P, math.floor(f.y) - P, 3 * P, 3 * P)
                love.graphics.setBlendMode("alpha")
            end
        elseif kind == "ash" or kind == "ash_fall" then
            local q = 1 - clamp01(f.life / f.max)
            local gr, gg, gb = lerp(PAL.particle[1], 0.62, q), lerp(PAL.particle[2], 0.58, q), lerp(PAL.particle[3], 0.60, q)
            love.graphics.setColor(gr, gg, gb, a)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), 2 * P, 2 * P)
            love.graphics.setColor(lerp(PAL.glow[1], 0.85, q), lerp(PAL.glow[2], 0.82, q), lerp(PAL.glow[3], 0.84, q), a * 0.8)
            love.graphics.rectangle("fill", math.floor(f.x) + (f.light and P or 0), math.floor(f.y), P, P)
        elseif kind == "petal" then
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), 2 * P, 2 * P)
            love.graphics.setColor(PAL.glow[1], PAL.glow[2], PAL.glow[3], a * 0.8)
            love.graphics.rectangle("fill", math.floor(f.x), math.floor(f.y), P, P)
        else
            love.graphics.setColor(c[1], c[2], c[3], a)
            love.graphics.push()
            love.graphics.translate(math.floor(f.x), math.floor(f.y))
            love.graphics.rotate(f.rot)
            if kind == "shard" then
                love.graphics.rectangle("fill", -P, -P * 0.5, P, P)
                love.graphics.rectangle("fill", 0, -P * 0.5, P, P)
            else
                love.graphics.rectangle("fill", -P * 1.5, -P * 0.5, P, P)
                love.graphics.rectangle("fill", -P * 0.5, -P * 0.5, P, P)
                love.graphics.rectangle("fill", P * 0.5, -P * 0.5, P, P)
            end
            love.graphics.pop()
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDust()
    local P = px()
    for _, d in ipairs(dust) do
        local a = clamp01(d.life / d.max)
        love.graphics.setColor(0.62, 0.56, 0.48, 0.6 * a)
        local n = (a > 0.5) and 2 or 1
        love.graphics.rectangle("fill", math.floor(d.x), math.floor(d.y) - P * n, P * n, P * n)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function BossCinematic.crowDraw(c)
    local BossAura = require("src.ui.BossAura")
    local frames = c.sprite and BossAura.crowFrames(c.sprite)
    if not frames then return nil end
    local still = reducedMotion()
    local age = c.max - c.life
    local fi = still and 1 or BossAura.crowFrameIndex(frames, age, c.h1, "flee")
    return frames, fi, BossAura.crowScale(px()), clamp01(c.life / c.max * 1.4)
end

local function drawCrows()
    local BossAura = require("src.ui.BossAura")
    for _, c in ipairs(crows) do
        local frames, fi, S, a = BossCinematic.crowDraw(c)
        if frames then
            BossAura.drawCrowSprite(frames, fi, c.x, c.y, c.face, 0, S, a, true)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDawn(w, h)
    local d = fx.dawn
    if not d or not stage or not stage.tr then return end
    local tr = stage.tr
    local k = smooth(clamp01(d.t / d.dur))
    local cx = tr.ox + d.u * 400 * tr.scale
    local cy = tr.oy + d.v * 256 * tr.scale
    local r = 14 * tr.scale
    local warm = { 1.0, 0.86, 0.62 }
    glowBlob(cx, cy, r * 7 * (0.6 + 0.4 * k), r * 5 * (0.6 + 0.4 * k), warm, 0.45 * k, 1)
    glowBlob(cx, cy, r * 3.2, r * 2.6, { 1, 0.95, 0.85 }, 0.55 * k, 3)
    if stage.bbox then
        local by = (stage.cy or stage.bbox.bottomY)
        for i = 0, 3 do
            local q = (i + 0.5) / 4
            glowBlob(lerp(cx, stage.bbox.cx, q), lerp(cy, by, q), r * (2 + i), r * 2.2, warm,
                0.16 * k * (1 - i * 0.15), 1 + i % 3)
        end
    end
end

function BossCinematic.drawBack()
    local w = (stage and stage.w) or love.graphics.getWidth()
    local h = (stage and stage.h) or love.graphics.getHeight()
    if dark > 0.002 then
        love.graphics.setColor(0.01, 0.005, 0.01, dark)
        love.graphics.rectangle("fill", 0, 0, w, h)
    end
    if not stage then return end
    drawMist({ [1] = true })
    drawRoots()
    drawRunes()
    drawFirewall(w, h)
    drawEclipse(w, h)
    if not (seq and seq.bossId == QUEEN_ID) then drawDawn(w, h) end
    queenDrawBack(w, h)
    drawEyes(w, h)
    drawMist({ [2] = true })
    T3.drawLooseAura()
    drawWalk(w, h)
    T3.drawBond()
    drawAssemble()
    drawRise(w, h)
    drawDescend(w, h)
    drawWind()
    drawFly(w, h)
    drawEdge(w, h)
    if seq and seq.phase == "intro" then drawFeathers() end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawLavaPool()
    local lv = fx.lava
    if not lv or not stage or not stage.bbox then return end
    local k = smooth(clamp01(lv.t / lv.dur))
    local cx = stage.bbox.cx
    local cy = (stage.cy or stage.bbox.bottomY)
    local wdt = (stage.bbox.width or 120) * (0.5 + 1.1 * k)
    local hgt = (stage.bbox.height or 200) * (0.08 + 0.22 * k)
    local fl = 0.85 + 0.15 * math.sin(lv.t * 9)
    glowBlob(cx, cy - hgt * 0.15, wdt * 1.3, hgt * 1.6, PAL.glow, 0.45 * k * fl, 1)
    glowBlob(cx, cy - hgt * 0.2, wdt, hgt, PAL.ember, 0.55 * k * fl, 2)
    glowBlob(cx + math.sin(lv.t * 3) * wdt * 0.1, cy - hgt * 0.25, wdt * 0.5, hgt * 0.6,
        { 1, 0.92, 0.6 }, 0.35 * k * fl, 3)
end

function BossCinematic.drawFront()
    if not stage then return end
    drawMist({ [3] = true })
    drawLavaPool()
    drawCracks()
    drawCrumble()
    drawDust()
    if not (seq and seq.phase == "intro") then drawFeathers() end
    drawCrows()
    queenDrawFront()
    drawWhiteout()
    drawSilhouette(stage.w, stage.h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function titleAlpha()
    if not title then return 0 end
    local t, d = title.t, title.dur
    if t < 0.25 then return smooth(t / 0.25) end
    if t > d - 0.45 then return 1 - smooth(clamp01((t - (d - 0.45)) / 0.45)) end
    return 1
end

function BossCinematic.drawUI()
    drawScreenFx()
    if not seq then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if title then
        local a = titleAlpha()
        local cy = math.floor(h * 0.80)
        local lineW = math.floor(w * 0.34)
        love.graphics.setColor(0.07, 0.05, 0.04, 0.72 * a)
        love.graphics.rectangle("fill", 0, cy - title.size * 1.05, w, title.size * 2.55)
        love.graphics.setColor(0.72, 0.58, 0.32, 0.9 * a)
        local ly = cy + title.size * 0.75
        love.graphics.rectangle("fill", math.floor(w / 2 - lineW / 2), ly, lineW, 2)
        for side = -1, 1, 2 do
            local gx = math.floor(w / 2 + side * (lineW / 2 + 10))
            love.graphics.polygon("fill", gx, ly - 3, gx + 4, ly + 1, gx, ly + 5, gx - 4, ly + 1)
        end
        love.graphics.setColor(1, 1, 1, a)
        title.dyna.colours[1][4] = a
        title.dyna:draw(w / 2, cy)
        if title.epithet ~= "" then
            local ea = a * smooth(clamp01((title.t - 0.35) / 0.3))
            local font = FontManager.getFont(math.max(12, math.floor(title.size * 0.42)))
            love.graphics.setFont(font)
            local tw = font:getWidth(title.epithet)
            local ty = ly + 8
            love.graphics.setColor(0, 0, 0, 0.7 * ea)
            love.graphics.print(title.epithet, math.floor(w / 2 - tw / 2) + 1, ty + 1)
            love.graphics.setColor(0.95, 0.58, 0.45, ea)
            love.graphics.print(title.epithet, math.floor(w / 2 - tw / 2), ty)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    queenDrawUI(w, h)
    require("src.ui.BossTrophy").draw()
    if BossCinematic.canSkip() then
        local k = clamp01((seq.t - BossCinematic.SKIP_AFTER) / 0.4)
        local NavCursor = require("src.ui.NavCursor")
        local dev = NavCursor.device and NavCursor.device() or "mouse"
        local glyph = (dev == "pad") and NavCursor.PAD_LABEL.confirm
            or NavCursor.KEY_LABEL.confirm
        local text = I18n.t("boss_cinematics.skip", { key = glyph }, "")
        local font = FontManager.getFont(math.max(10, math.floor(h * 0.016)))
        love.graphics.setFont(font)
        local tw = font:getWidth(text)
        local x, y = w - tw - 18, h - font:getHeight() - 14
        love.graphics.setColor(0, 0, 0, 0.6 * k)
        love.graphics.print(text, x + 1, y + 1)
        love.graphics.setColor(0.85, 0.78, 0.62, 0.75 * k)
        love.graphics.print(text, x, y)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

BossCinematic.overlay = {
    ownsNavigation = true,
    isVisible = function() return seq ~= nil end,
    hide = function() BossCinematic.reset() end,
}
function BossCinematic.overlay:keypressed(key)
    if key == "escape" then
        if _G.togglePauseMenu then _G.togglePauseMenu() end
        return true
    end
    if key == "return" or key == "kpenter" or key == "space" then
        BossCinematic.skip()
        return true
    end
    return false
end
function BossCinematic.overlay:mousepressed(_, _, button)
    if button == 1 then BossCinematic.skip() end
    return true
end
function BossCinematic.overlay:mousereleased() return true end
function BossCinematic.overlay:wheelmoved() return true end

return BossCinematic
