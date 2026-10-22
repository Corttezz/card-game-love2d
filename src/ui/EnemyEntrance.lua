local EE = {}

local Data = require("src.data.enemy_entrances")
local Debug = require("src.core.Debug")
local SpriteAnimation = require("src.ui.SpriteAnimation")
local EnemyPoses = require("src.data.enemy_poses")
local Sfx = require("src.systems.Sfx")

EE.FREEZE_WIN = 1.3
EE.REDUCED_SETTLE = 0.5

local st = nil
local warned = {}
local anchorImgs = {}
local soundsLoaded = false
local quad = nil
local tmpColor = {}
local shadowOpt = {}
local ratImg = nil

EE.lastBounce = false
EE._last = nil
EE._trace = nil

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end
local function easeOutCubic(v) v = 1 - clamp01(v); return 1 - v * v * v end
local function easeOutQuart(v) v = 1 - clamp01(v); return 1 - v * v * v * v end
local function easeInOut(v)
    v = clamp01(v)
    return v * v * (3 - 2 * v)
end
local function easeInQuad(v) v = clamp01(v); return v * v end
local function easeInOutCubic(v)
    v = clamp01(v)
    if v < 0.5 then return 4 * v * v * v end
    local f = 2 * v - 2
    return 1 + f * f * f / 2
end

EE.END_LEAD = 0.12

local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    Debug.warn(msg)
end

function EE.specFor(id)
    return (id and Data.BY_ID[id]) or Data.DEFAULT
end

function EE.isActive() return st ~= nil end
function EE.state() return st end
function EE.relOff() return st and st.pose.relOff or 0 end

local function ensureSounds()
    if soundsLoaded then return end
    soundsLoaded = true
    local a = _G.audioSystem
    if not a or not a.loadSound then return end
    for code, d in pairs(Data.SOUNDS) do
        if not Sfx.has(code) and love.filesystem.getInfo(d[1]) then
            pcall(a.loadSound, a, code, d[1], d[2])
        end
    end
end

local function playFirst(list)
    if not list then return nil end
    ensureSounds()
    for _, code in ipairs(list) do
        local Crow = require("src.systems.CrowSfx")
        if Crow.handles(code) then
            Crow.play(code)
            return code
        end
        if Sfx.has(code) then
            local a = _G.audioSystem
            if a and a.play then
                a:play(code, { pitch = 1 + (love.math.random() * 2 - 1) * 0.05, gain = Data.ENTRANCE_GAIN or 1 })
            end
            return code
        end
    end
    return nil
end

local View = {}
View.__index = View

function View:draw(x, y, s, tint)
    local S = self.st
    local img = S.img
    if not img then return end
    local a = S.alpha
    if tint then
        love.graphics.setColor(tint[1] * S.tintK, tint[2] * S.tintK, tint[3] * S.tintK, (tint[4] or 1) * a)
    else
        love.graphics.setColor(S.tintK, S.tintK, S.tintK, a)
    end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, sy = s, s
    if S.squash ~= 0 then
        local q = S.squash * 0.35
        sx, sy = s * (1 + q), s * (1 - q)
        x = x - iw * s * q * 0.5
        y = y + ih * s * q
    end
    if S.crouch ~= 0 then
        sy = sy * (1 - S.crouch)
        y = y + ih * s * S.crouch
    end
    if S.riseK < 1 then
        local vh = math.max(1, math.floor(ih * S.riseK + 0.5))
        quad = quad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
        quad:setViewport(0, 0, iw, vh, iw, ih)
        love.graphics.draw(img, quad, math.floor(x), math.floor(y + (ih - vh) * sy), 0, sx, sy)
    else
        love.graphics.draw(img, math.floor(x), math.floor(y), 0, sx, sy)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function View:getSize()
    local S = self.st
    local img = S.idleImg or S.img
    if not img then return 0, 0 end
    return img:getWidth(), img:getHeight()
end

function View:update() end
function View:isFinished() return false end
function View:getFrameCount() return 1 end

local function loadClip(id, name)
    if not Data.CLIPS[name] then
        warnOnce(id .. "|" .. name, "[entrada] clipe desconhecido '" .. name .. "' em " .. id)
        return false
    end
    local anim = SpriteAnimation.new(id, name, "south", 10, { loop = false })
    if not anim then
        warnOnce(id .. "|" .. name, "[entrada] " .. id .. " sem clipe '" .. name .. "': usando o idle")
        return false
    end
    return anim
end

local function clipFrame(clip, phase)
    local n = #clip.frames
    local f = 1 + math.floor(clamp01(phase) * (n - 1) + 1e-6)
    if f > n then f = n end
    clip.currentFrame = f
    return clip.frames[f]
end

local function loopFrame(clip, cycles)
    local n = #clip.frames
    if n <= 1 then return clip.frames[1] end
    local fr = cycles - math.floor(cycles)
    local f = 1 + math.floor(fr * (n - 1))
    if f >= n then f = n - 1 end
    clip.currentFrame = f
    return clip.frames[f]
end

local function idleImage(S, dt, freezeAt1, freezeAt)
    local idle = S.idle
    if not idle then
        S.view.currentFrame = 1
        return S.staticImg
    end
    local left = freezeAt and (freezeAt - S.t) or S.left
    if not S.frozen then
        if freezeAt1 and left <= EE.FREEZE_WIN and idle.currentFrame == 1 then
            S.frozen = true
        else
            idle:update(dt)
        end
    end
    S.view.currentFrame = idle.currentFrame
    return idle.frames[idle.currentFrame]
end

local function idleFrame1(S)
    S.frozen = true
    S.view.currentFrame = 1
    return S.idleImg or S.staticImg
end

local function pick(S, mark)
    if S.fired[mark] then return false end
    S.fired[mark] = true
    local spec = S.spec
    if spec.sfx and spec.sfx[mark] then playFirst(spec.sfx[mark]) end
    if spec.fx and spec.fx[mark] then
        for _, name in ipairs(spec.fx[mark]) do EE.fx(name) end
    end
    return true
end

local COLOURS = {
    dust = { { 0.55, 0.42, 0.28, 1 }, { 0.42, 0.32, 0.22, 1 }, { 0.66, 0.55, 0.40, 1 } },
    snow = { { 0.92, 0.96, 1.0, 1 }, { 0.75, 0.85, 0.98, 1 }, { 1, 1, 1, 1 } },
    embers = { { 1.0, 0.55, 0.15, 1 }, { 1.0, 0.3, 0.08, 1 }, { 1.0, 0.85, 0.3, 1 } },
    straw = { { 0.85, 0.72, 0.35, 1 }, { 0.72, 0.58, 0.25, 1 }, { 0.95, 0.85, 0.5, 1 } },
    shards = { { 0.55, 0.55, 0.6, 1 }, { 0.35, 0.35, 0.4, 1 }, { 0.7, 0.7, 0.75, 1 } },
    spores = { { 0.55, 0.75, 0.35, 1 }, { 0.75, 0.85, 0.45, 1 }, { 0.4, 0.6, 0.3, 1 } },
    splash = { { 0.35, 0.45, 0.28, 1 }, { 0.25, 0.32, 0.2, 1 }, { 0.5, 0.6, 0.4, 1 } },
    feathers = { { 1, 1, 1, 1 }, { 0.95, 0.92, 0.85, 1 }, { 0.85, 0.85, 0.9, 1 } },
    dark = { { 0.25, 0.1, 0.35, 1 }, { 0.12, 0.08, 0.2, 1 }, { 0.45, 0.2, 0.5, 1 } },
}
local PHYS = {
    dust = { speed = 70, gravity = 120, life = 0.7, n = 18 },
    snow = { speed = 55, gravity = 40, life = 0.9, n = 18 },
    embers = { speed = 80, gravity = -90, life = 0.8, n = 16 },
    straw = { speed = 85, gravity = 60, life = 0.9, n = 16 },
    shards = { speed = 110, gravity = 180, life = 0.6, n = 14 },
    spores = { speed = 45, gravity = -25, life = 1.2, n = 20 },
    splash = { speed = 95, gravity = 200, life = 0.6, n = 16 },
    feathers = { speed = 40, gravity = 30, life = 1.5, n = 14 },
    dark = { speed = 60, gravity = -20, life = 0.8, n = 16 },
}

local function burst(name, k)
    if not st or st.red or not st.scrX then return end
    local cfg = PHYS[name]
    if not cfg then return end
    local ok, PM = pcall(require, "engine.ParticlesManager")
    if not ok then return end
    local uk = require("src.ui.UiScale").k()
    PM.spawn(st.scrX / uk, (st.scrY - 6) / uk, 0, 0, {
        timer = 0.012, lifespan = cfg.life, scale = 0.38, speed = cfg.speed * (k or 1),
        colours = COLOURS[name], pulse_max = math.floor(cfg.n * (k or 1) + 0.5),
        vel_variation = 0.7, gravity = cfg.gravity, layer = 7,
    })
end

local wx = { rain = 0, blizzard = 0, ff = 0, dim = 0 }
local wxTgt = { rain = 0, blizzard = 0, ff = 0, dim = 0 }
local wxAmb = { 1, 1, 1 }
local wxLast = nil
EE.WX_RATE = 1 / 0.7
EE.WX_RAIN = 0.5
EE.WX_DIM = 0.45

local function wxTick(dt)
    local any = false
    for k, v in pairs(wx) do
        local t = wxTgt[k]
        if v < t then v = math.min(t, v + dt * EE.WX_RATE)
        elseif v > t then v = math.max(t, v - dt * EE.WX_RATE) end
        wx[k] = v
        if v > 0 then any = true end
    end
    local WeatherEngine = require("engine.WeatherEngine")
    local boost = math.max(wx.rain, wx.blizzard)
    if boost > 0 then
        WeatherEngine.setIntensityOverride(nil)
        local base = WeatherEngine.intensity()
        WeatherEngine.setIntensityOverride(math.min(1, base + EE.WX_RAIN * boost))
    elseif wxLast and wxLast > 0 then
        WeatherEngine.setIntensityOverride(nil)
    end
    wxLast = boost
    WeatherEngine.ffMute = wx.ff
    return any
end

function EE.wxSet(name, v)
    if wxTgt[name] == nil then return end
    wxTgt[name] = v
end

function EE.wxClear()
    for k in pairs(wxTgt) do wxTgt[k] = 0 end
end

function EE.wx(name) return wx[name] or 0 end

function EE.dimAmbient(amb)
    if not st then
        local dt = love.timer and love.timer.getDelta() or 1 / 60
        wxTick(math.min(dt, 0.1))
    end
    if wx.dim <= 0 then return amb end
    local k = 1 - EE.WX_DIM * wx.dim
    wxAmb[1], wxAmb[2], wxAmb[3] = (amb[1] or 1) * k, (amb[2] or 1) * k, (amb[3] or 1) * k
    return wxAmb
end

local WX_FX = { rain = "rain", blizzard = "blizzard", fireflies = "ff", dim = "dim" }

function EE.fx(name, k)
    if not st then return end
    if COLOURS[name] then burst(name, k); return end
    if WX_FX[name] then
        if not st.red or name == "fireflies" or name == "dim" then wxTgt[WX_FX[name]] = 1 end
        return
    end
    if st.red then return end
    if name == "shake1" then
        require("src.systems.ScreenShake").trigger(3, 0.18)
    elseif name == "shake2" then
        require("src.systems.ScreenShake").trigger(6, 0.28)
    elseif name == "grass" or name == "gust" then
        local WorldRoad = require("src.ui.WorldRoad")
        local r = WorldRoad._lastRect
        if r and st.footX then
            require("engine.GrassField").pokeAt((st.footX - r.x) / math.max(1, r.w), st.enc.z, WorldRoad._time)
        end
    elseif name == "crows" then
        local WorldRoad = require("src.ui.WorldRoad")
        local r = WorldRoad._lastRect
        if r and st.footX then
            for i = 1, 3 do
                table.insert(WorldRoad._birds, {
                    xr = (st.footX - r.x) / math.max(1, r.w) + (i - 2) * 0.03,
                    yr = 0.55 + i * 0.04,
                    dir = (i % 2 == 0) and 1 or -1,
                    speed = 0.08 + i * 0.01,
                    phase = i * 2.1,
                    vyr = -(0.30 + i * 0.05),
                })
            end
        end
    elseif name == "lightning" then
        local WorldRoad = require("src.ui.WorldRoad")
        local r = WorldRoad._lastRect
        local xr = (r and st.footX) and (st.footX - r.x) / math.max(1, r.w) or 0.5
        pcall(require("engine.WeatherEngine").strike, xr + st.side * 0.18, 0.35)
    end
end

local function sideX(g, w, t, side, extra)
    return side * (0.15 * w * (0.30 + 0.70 * (t ^ 1.15)) * 1.18 + extra)
end
EE.sideX = sideX

function EE.dxPx(e, g, w, t, s)
    if not st then return 0 end
    local px = 0
    if st.sideFrac ~= 0 then
        px = px + st.sideFrac * sideX(g, w, t, st.side, st.anchorHalfW * s)
    end
    if st.offFrac ~= 0 then
        px = px + st.offFrac * st.side * (w * 0.5 + e.iw * s * 0.5 + 16)
    end
    return px + st.dxK * e.ih * s
end

local DEFAULT_POSE = { relOff = 0, hidden = false, liftK = 0, shadowA = 1, alpha = 1 }
function EE.pose(e)
    if not st or st.enc ~= e then return DEFAULT_POSE end
    return st.pose
end

function EE.notePos(cx, sy, s, rel)
    if not st then return end
    st.footX, st.footY, st.scale, st.rel = cx, sy, s, rel
    st.scrX, st.scrY = love.graphics.transformPoint(cx, sy)
end

local ANCHOR_SIZE = {
    pole = { 56, 116 }, mist = { 128, 64 }, perch = { 120, 56 }, circle = { 136, 44 },
    sigil = { 136, 44 }, plinth = { 112, 52 }, crack = { 136, 48 }, pit = { 140, 60 },
    blot = { 120, 120 }, snowmound = { 120, 70 }, snowbump = { 140, 40 }, mud = { 140, 48 },
    pool = { 140, 48 }, mushrooms = { 120, 56 }, grave = { 140, 44 }, icespike = { 48, 120 },
    shadepool = { 72, 28 },
}
EE.ANCHOR_SIZE = ANCHOR_SIZE
EE.TALL_ANCHORS = { pole = true, perch = true, plinth = true, snowmound = true, mushrooms = true, icespike = true }
EE.CONTACT_ANCHORS = { mud = true, pool = true, grave = true, snowbump = true, shadepool = true, pit = true, crack = true }
EE.POKE_FX = { pole = "straw", perch = "shards", plinth = "shards", snowmound = "snow", icespike = "snow",
    mushrooms = "spores", snowbump = "snow", mud = "splash", pool = "splash", grave = "dust", pit = "dust",
    crack = "embers", shadepool = "dark", circle = "dark", sigil = "embers" }
EE.POKE_SFX = { pole = "sceneWoodKnock", perch = "sceneStoneThud", plinth = "sceneStoneThud", snowmound = "sceneCloudPoof",
    icespike = "impactIce", mushrooms = "sceneRustle", snowbump = "sceneCloudPoof", mud = "impactPoison",
    pool = "impactPoison", grave = "sceneStoneThud", pit = "sceneStoneThud", crack = "impactFire", shadepool = "impactDark",
    circle = "impactArcane", sigil = "impactArcane" }

function EE.poke(p, mx, my)
    local src = p.front and p.ref or p
    if not src then return end
    src._pokeT = require("src.ui.WorldRoad")._time
    local fxName = EE.POKE_FX[src.name]
    local cfg = fxName and PHYS[fxName]
    if cfg and not reducedMotion() then
        local ok, PM = pcall(require, "engine.ParticlesManager")
        if ok then
            local uk = require("src.ui.UiScale").k()
            PM.spawn(mx / uk, my / uk, 0, 0, {
                timer = 0.012, lifespan = cfg.life, scale = 0.38, speed = cfg.speed * 0.6,
                colours = COLOURS[fxName], pulse_max = math.floor(cfg.n * 0.5 + 0.5),
                vel_variation = 0.7, gravity = cfg.gravity, layer = 7,
            })
        end
    end
    local snd = EE.POKE_SFX[src.name]
    if snd and Sfx.has(snd) then Sfx.playWithVariation(snd, 1.0, 0.08) end
end

local function px(x, y, w, h) love.graphics.rectangle("fill", x, y, w, h) end

local function paintAnchor(name, w, h)
    local g = love.graphics
    if name == "pole" then
        g.setColor(0.36, 0.25, 0.15, 1); px(24, 6, 8, h - 6)
        g.setColor(0.45, 0.32, 0.2, 1); px(26, 6, 3, h - 6)
        g.setColor(0.36, 0.25, 0.15, 1); px(8, 26, 40, 7)
        g.setColor(0.22, 0.15, 0.1, 1); px(8, 31, 40, 2); px(30, 6, 2, h - 6)
    elseif name == "mist" then
        for i = 1, 5 do
            g.setColor(0.45, 0.42, 0.5, 0.18 + 0.08 * i)
            g.ellipse("fill", w * (0.2 + 0.15 * i) % w, h * 0.65, w * 0.26, h * 0.3)
        end
    elseif name == "perch" or name == "plinth" then
        g.setColor(0.38, 0.38, 0.42, 1); g.ellipse("fill", w / 2, h - 10, w / 2 - 4, 10)
        g.setColor(0.52, 0.52, 0.56, 1); px(8, 10, w - 16, h - 22)
        g.setColor(0.62, 0.62, 0.66, 1); px(8, 10, w - 16, 6)
        g.setColor(0.3, 0.3, 0.34, 1); px(8, h - 16, w - 16, 5)
    elseif name == "circle" or name == "sigil" then
        local c = name == "circle" and { 0.6, 0.3, 0.9 } or { 1.0, 0.35, 0.2 }
        g.setColor(c[1], c[2], c[3], 0.9); g.setLineWidth(3)
        g.ellipse("line", w / 2, h / 2, w / 2 - 4, h / 2 - 4)
        g.ellipse("line", w / 2, h / 2, w / 2 - 16, h / 2 - 10)
        for i = 0, 7 do
            local a = i / 8 * 6.2832
            px(w / 2 + math.cos(a) * (w / 2 - 10) - 2, h / 2 + math.sin(a) * (h / 2 - 7) - 2, 4, 4)
        end
        g.setLineWidth(1)
    elseif name == "crack" then
        g.setColor(0.12, 0.08, 0.08, 1); g.ellipse("fill", w / 2, h / 2, w / 2 - 2, h / 2 - 2)
        g.setColor(1.0, 0.45, 0.1, 1)
        px(10, h / 2 - 2, w - 20, 4); px(w / 2 - 14, h / 2 - 10, 5, 20); px(w / 2 + 18, h / 2 - 8, 4, 16)
    elseif name == "pit" then
        g.setColor(0.3, 0.26, 0.24, 1); g.ellipse("fill", w / 2, h / 2, w / 2 - 2, h / 2 - 2)
        g.setColor(0.05, 0.04, 0.05, 1); g.ellipse("fill", w / 2, h / 2 + 2, w / 2 - 12, h / 2 - 10)
    elseif name == "blot" then
        for i = 1, 4 do
            g.setColor(0.05, 0.02, 0.08, 0.25)
            g.ellipse("fill", w / 2, h / 2, (w / 2) * (1 - i * 0.18), (h / 2) * (1 - i * 0.18))
        end
    elseif name == "snowmound" or name == "snowbump" then
        g.setColor(0.72, 0.8, 0.9, 1); g.ellipse("fill", w / 2, h - 8, w / 2 - 2, 8)
        g.setColor(0.9, 0.95, 1.0, 1); g.arc("fill", w / 2, h - 8, w / 2 - 4, math.pi, 2 * math.pi)
        if name == "snowmound" then g.setColor(0.8, 0.88, 0.96, 1); g.arc("fill", w / 2, h - 8, w / 2 - 4, math.pi * 1.25, math.pi * 1.75) end
    elseif name == "mud" or name == "pool" then
        local c = name == "mud" and { 0.32, 0.24, 0.16 } or { 0.12, 0.22, 0.16 }
        g.setColor(c[1], c[2], c[3], 1); g.ellipse("fill", w / 2, h / 2, w / 2 - 2, h / 2 - 2)
        g.setColor(c[1] * 1.5, c[2] * 1.5, c[3] * 1.5, 1); g.ellipse("fill", w / 2 - 20, h / 2 - 6, 18, 5)
    elseif name == "mushrooms" then
        for i = 0, 2 do
            local mx, mh = 20 + i * 40, 28 + (i % 2) * 14
            g.setColor(0.85, 0.82, 0.7, 1); px(mx - 5, h - mh, 10, mh)
            g.setColor(0.75, 0.2, 0.15, 1); g.arc("fill", mx, h - mh + 4, 18, math.pi, 2 * math.pi)
            g.setColor(0.95, 0.9, 0.8, 1); px(mx - 10, h - mh - 6, 4, 4); px(mx + 4, h - mh - 10, 4, 4)
        end
    elseif name == "grave" then
        g.setColor(0.3, 0.2, 0.12, 1); g.ellipse("fill", w / 2, h / 2, w / 2 - 2, h / 2 - 2)
        g.setColor(0.42, 0.3, 0.18, 1)
        for i = 0, 6 do px(14 + i * 18, h / 2 - 6 + (i % 2) * 8, 10, 6) end
    elseif name == "icespike" then
        g.setColor(0.7, 0.88, 1.0, 1); g.polygon("fill", 6, h, w - 6, h, w / 2 + 4, 0)
        g.setColor(0.9, 0.97, 1.0, 1); g.polygon("fill", 14, h, w / 2 - 2, h, w / 2 - 2, 20)
    elseif name == "shadepool" then
        g.setColor(0.08, 0.04, 0.12, 1); g.ellipse("fill", w / 2, h / 2, w / 2 - 2, h / 2 - 2)
        g.setColor(0.3, 0.12, 0.4, 1); g.ellipse("fill", w / 2, h / 2, w / 2 - 14, h / 2 - 8)
    end
end

function EE.anchorImage(id, name)
    local key = tostring(id) .. "|" .. tostring(name)
    local hit = anchorImgs[key]
    if hit ~= nil then return hit or nil end
    local path = Data.ANCHOR_DIR .. tostring(id) .. "_anchor.png"
    local img, data = nil, nil
    if love.filesystem.getInfo(path) then
        local okd, d = pcall(love.image.newImageData, path)
        if okd and d then
            local ok, im = pcall(love.graphics.newImage, d)
            if ok and im then img, data = im, d end
        end
    end
    if not img then
        local sz = ANCHOR_SIZE[name]
        if sz then
            local cv = love.graphics.newCanvas(sz[1], sz[2])
            love.graphics.push("all")
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 0)
            paintAnchor(name, sz[1], sz[2])
            love.graphics.setCanvas()
            love.graphics.pop()
            local d = cv:newImageData()
            local ok, im = pcall(love.graphics.newImage, d)
            cv:release()
            if ok and im then img, data = im, d end
        end
    end
    if img then
        img:setFilter("nearest", "nearest")
        require("engine.ContactShadow").scan(img, data, nil)
    end
    anchorImgs[key] = img or false
    return img
end

EE.ANCHOR_FPS = 5
EE.ANCHOR_SHADOW_A = 1.0
EE.ANCHOR_SHADOW_BASE = nil

local pendSh, pendN = {}, 0
function EE.deferShadow(img, x, y, s, t, opts, contactA)
    pendN = pendN + 1
    local q = pendSh[pendN]
    if not q then q = {}; pendSh[pendN] = q end
    q.img, q.x, q.y, q.s, q.t, q.o, q.ca = img, x, y, s, t, opts, contactA
end

function EE.flushShadows()
    if pendN == 0 then return end
    local SE = require("engine.ShadowEngine")
    local CS = require("engine.ContactShadow")
    for i = 1, pendN do
        local q = pendSh[i]
        if q.o then SE.queue(q.img, q.x, q.y - 1, q.s, q.o, q.t) end
        if q.ca then CS.queue(q.img, q.x, q.y, q.s, q.t, q.ca, 1) end
        q.img, q.o = nil, nil
    end
    pendN = 0
end

function EE.drawBehindAnchors(g, x, w, camZ, band, crest)
    local WorldRoad = require("src.ui.WorldRoad")
    for _, p in ipairs(WorldRoad._props) do
        if p.anchor and not p.front then
            local rel = p.z - camZ
            if rel > crest and rel <= crest + band then
                EE.drawProp(p, g, x, w, 0, rel, camZ, 1 - (rel - crest) / band)
            end
        end
    end
end
EE.MIST_ALPHA = 0.7
EE.MIST_FOG = 0.3
EE.MIST_VEIL = 0.75
EE.MIST_BODY_TINT = 0.45

function EE.anchorFrames(id)
    local key = "frames|" .. tostring(id)
    local hit = anchorImgs[key]
    if hit ~= nil then return hit or nil end
    local list = {}
    local CS = require("engine.ContactShadow")
    for i = 0, 31 do
        local path = Data.ANCHOR_DIR .. tostring(id) .. "_anchor_" .. i .. ".png"
        if not love.filesystem.getInfo(path) then break end
        local okd, d = pcall(love.image.newImageData, path)
        if not okd or not d then break end
        local ok, im = pcall(love.graphics.newImage, d)
        if not ok or not im then break end
        im:setFilter("nearest", "nearest")
        CS.scan(im, d, nil)
        list[#list + 1] = im
    end
    anchorImgs[key] = (#list > 0) and list or false
    return anchorImgs[key] or nil
end

function EE.clearCache()
    anchorImgs = {}
    ratImg = nil
end

local function spawnAnchor(S, opts)
    local anc = S.spec.anchor
    if not anc or anc.veil then return end
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad._uid = (WorldRoad._uid or 0) + 1
    local p = {
        kind = "anchor", anchor = true, entrId = S.id, name = anc.name, at = anc.at or "stage",
        bid = opts.bid, side = (anc.at == "side") and S.side or 0, lane = 0, variant = 0,
        big = 1, jitter = 0, uid = WorldRoad._uid, ts = S.enc.targetScale or 4,
        glow = anc.glow and 0 or nil, grow = anc.grow and 0 or 1, glowColor = anc.glow,
        z = opts.stopZ + WorldRoad.BATTLE_REL + 0.25 + (anc.back or 0), stopZ = opts.stopZ, offX = S.enc.offX or 0,
        back = anc.back or 0,
    }
    local img = EE.anchorImage(S.id, anc.name)
    S.anchorHalfW = img and img:getWidth() * 0.5 or 0
    S.anchorH = img and img:getHeight() or 0
    S.anchorProp = p
    WorldRoad._props[#WorldRoad._props + 1] = p
    if p.side == 0 and p.back == 0 then
        p.straddle = true
        WorldRoad._uid = WorldRoad._uid + 1
        local pf = { kind = "anchor", anchor = true, front = true, ref = p, bid = opts.bid, side = 0, lane = 0,
            variant = 0, big = 1, jitter = 0, uid = WorldRoad._uid, z = p.z - 0.5 }
        S.anchorFront = pf
        WorldRoad._props[#WorldRoad._props + 1] = pf
    end
end

function EE.begin(enc, opts)
    opts = opts or {}
    local id = enc.spriteId
    local spec = EE.specFor(id)
    local red = reducedMotion()
    local rnd = love.math.random()
    local okR, Rng = pcall(require, "src.systems.Rng")
    if okR and Rng.get then
        local okV, v = pcall(function() return Rng.get():random("misc") end)
        if okV and type(v) == "number" then rnd = v end
    end
    local side = spec.side == "left" and -1 or (spec.side == "right" and 1 or (rnd < 0.5 and -1 or 1))
    local delay = (rnd * 7.3) % 1 * 0.25
    local settle = spec.settle or 0
    local extra = spec.extra or 0
    local travelExtra = math.max(0, extra - settle)
    if red then
        travelExtra = 0
        settle = math.min(settle, EE.REDUCED_SETTLE)
    end
    local dur = opts.duration or (Data.BASE + travelExtra)
    local S = {
        id = id, spec = spec, kind = spec.kind, enc = enc, side = side, delay = delay,
        red = red, settle = settle, dur = dur, total = dur + settle,
        t = 0, k = 0, sK = 0, sT = 0, left = dur + settle, tail = dur, stopped = false,
        clips = {}, used = {}, fired = {},
        idle = enc.anim, staticImg = enc.img, img = nil, idleImg = nil,
        alpha = 1, tintK = 1, riseK = 1, frozen = false,
        sideFrac = 0, offFrac = 0, dxK = 0, anchorHalfW = 0, anchorH = 0,
        glowK = 0, veilA = 0, lanternK = 0, columnK = 0, swarmK = 0, rocksK = 0, passK = -1,
        squash = 0, squashT = 0, squashDur = 0.2, squashAmp = 0, pokeT = 0, landed = 0, crouch = 0, pokeSide = 1,
        endFrame1 = false,
        pose = { relOff = 0, hidden = false, liftK = 0, shadowA = 1, alpha = 1 },
    }
    if S.idle then
        S.idleImg = S.idle.frames[1]
        S.idle.currentFrame, S.idle.elapsed, S.idle._dir = 1, 0, 1
    end
    for _, name in ipairs(spec.clips or {}) do
        S.clips[name] = loadClip(id, name)
    end
    S.view = setmetatable({ st = S, currentFrame = 1, enemyId = id, entrance = true }, View)
    S.img = S.idleImg or S.staticImg
    S.stride = EE.strideUnits(enc)
    st = S
    EE.lastBounce = false
    spawnAnchor(S, opts)
    if S.kind == "flanco" and not S.anchorProp then
        S.anchorHalfW = (enc.iw or 96) * 0.45
    end
    return dur, settle
end

function EE.view()
    return st and st.view or nil
end

function EE.reset()
    st = nil
    EE.wxClear()
end

local function squashPulse(S, amp, dur)
    S.squashAmp, S.squashDur, S.squashT = amp, dur, dur
end

local function grassPoke(S, dxFrac)
    if S.red or not S.footX then return end
    local WorldRoad = require("src.ui.WorldRoad")
    local r = WorldRoad._lastRect
    if not r then return end
    require("engine.GrassField").pokeAt((S.footX - r.x) / math.max(1, r.w) + (dxFrac or 0), S.enc.z, WorldRoad._time)
end

EE.WALK_DIST = 10
EE.CHARGE_DIST = 16
EE.SKID = 0.3
EE.CHARGE_SEEN_REL = 24
EE.STRIDE_K = 0.8

function EE.strideUnits(enc)
    local WorldRoad = require("src.ui.WorldRoad")
    local r = WorldRoad._lastRect
    local h = r and r.h or 1000
    local g = WorldRoad.domeGeom(0, 0, r and r.w or 1920, h)
    local tB = g.tOf(WorldRoad.BATTLE_REL) or 0.5
    local unitPx = math.max(1, g.scaleAt(1, tB, 1))
    local bodyPx = (enc.iw or 96) * 0.8 * (enc.targetScale or 2.5)
        * WorldRoad.battleSizeK() * WorldRoad.enemyScreenK(h)
    return math.max(1.2, math.min(6, EE.STRIDE_K * bodyPx / unitPx))
end

local function legCycles(S, dist)
    return math.max(1, math.floor(dist / math.max(0.5, S.stride or 3) + 0.5))
end

local function walkFeel(S, spd, cycles)
    spd = clamp01(spd)
    S.crouch = 0.03 * spd
    if cycles then
        S.pose.liftK = S.pose.liftK + math.abs(math.sin(cycles * math.pi)) * 0.012 * spd
    end
end

local K = {}

function K.andar(S, dt)
    local spec = S.spec
    local walk = S.clips.walk
    local u = clamp01(S.t / math.max(0.01, S.dur - S.lead))
    local D = S.red and 2 or (spec.walkDist or EE.WALK_DIST)
    local f = 1 - (1 - u) * (1 - u)
    S.pose.relOff = D * (1 - f)
    local cyc = legCycles(S, D) * f
    if walk and u < 1 then
        S.img = loopFrame(walk, cyc)
        S.used.walk = true
        S.view.currentFrame = 1
    elseif walk then
        S.img = idleFrame1(S)
        S.endFrame1 = true
    else
        S.img = idleImage(S, dt, true)
    end
    if u < 1 then walkFeel(S, 1 - u, walk and cyc or nil) end
    if S.stopped and S.settle > 0 and not S.fired.settleSq then
        S.fired.settleSq = true
        squashPulse(S, 0.035, 0.22)
    end
    if spec.lantern then
        S.alpha = clamp01(0.22 + S.k * 1.6)
        S.lanternK = clamp01(0.3 + S.k)
    end
    if spec.glow then
        S.glowK = clamp01((1.6 - S.left) / 1.4)
    end
    if spec.steps and not S.red then
        for i = 1, spec.steps do
            local at = 0.5 + (spec.steps - i) * 0.62
            if S.tail <= at then pick(S, "step" .. i) ; if S.fired["step" .. i] and not S.fired["stepfx" .. i] then
                S.fired["stepfx" .. i] = true
                if spec.sfx.step then playFirst(spec.sfx.step) end
                for _, n in ipairs(spec.fx.step or {}) do EE.fx(n, 0.7) end
            end end
        end
    end
    if S.stopped then pick(S, "stop") end
    local p = S.anchorProp
    if p then
        if p.glow then p.glow = S.stopped and clamp01(S.sK * 2) or 0 end
        if S.spec.anchor.grow then p.grow = S.stopped and easeOutCubic(S.sK) or 0 end
    end
end

function K.investida(S, dt)
    local spec = S.spec
    local L = S.red and 3 or (spec.lead or EE.CHARGE_DIST)
    local T = math.max(0.01, S.total - S.lead)
    local us = clamp01(1 - (S.red and 0.15 or EE.SKID) / T)
    local u = clamp01(S.t / T)
    local v = 1 / (us + (1 - us) * 0.5)
    local f
    if u <= us then
        f = v * u
    else
        local x = u - us
        f = v * us + v * x - v * x * x / (2 * math.max(1e-3, 1 - us))
    end
    f = math.min(1, f)
    S.pose.relOff = L * (1 - f)
    local fRun = v * us
    local cyc = legCycles(S, L * fRun) * math.min(1, f / math.max(1e-3, fRun))
    local charge = S.clips.charge
    local skidding = u > us and u < 1
    if charge and u < 1 then
        S.img = loopFrame(charge, cyc)
        S.used.charge = true
        S.view.currentFrame = 1
    elseif charge then
        S.img = idleFrame1(S)
        S.endFrame1 = true
    else
        S.img = idleImage(S, dt, true)
        if u < us then S.pose.liftK = math.abs(math.sin(cyc * math.pi)) * 0.03 end
    end
    if u < us then walkFeel(S, 1, nil) end
    if S.rel and S.rel < EE.CHARGE_SEEN_REL and u < us then pick(S, "charge") end
    if not S.red and u > 0.02 and u < 1 then
        S.trailT = (S.trailT or 0) + dt
        if S.trailT >= (skidding and 0.05 or 0.14) then
            S.trailT = 0
            burst(skidding and "dust" or (spec.trail or "dust"), skidding and 0.55 or 0.3)
        end
    end
    if skidding then
        local sk = (u - us) / math.max(1e-3, 1 - us)
        S.crouch = 0.06 * math.sin(sk * math.pi)
        pick(S, "skid")
    end
    if u >= 1 then
        if pick(S, "stop") and not S.red then squashPulse(S, -0.35, 0.28) end
    end
end

function K.brotar(S, dt)
    local spec = S.spec
    local emerge = S.clips.emerge
    local rise = S.settle > 0 and clamp01(S.sT / (S.settle * 0.75)) or (S.stopped and 1 or 0)
    if emerge then
        S.img = clipFrame(emerge, rise)
        S.used.emerge = true
        S.view.currentFrame = 1
        S.pose.hidden = false
        if rise >= 1 then S.endFrame1 = true end
    else
        S.img = idleFrame1(S)
        S.endFrame1 = true
        S.pose.hidden = not S.stopped
        S.riseK = easeOutCubic(rise)
    end
    S.pose.shadowA = clamp01(0.35 + rise)
    if S.stopped then pick(S, "rise") end
    if spec.hop and S.stopped and not S.red then
        local h = clamp01((S.sKL - 0.6) / 0.4)
        S.pose.liftK = math.sin(h * math.pi) * 0.18
    end
    if S.sK >= 1 then pick(S, "stop") end
    local p = S.anchorProp
    if p and p.glow then p.glow = clamp01(0.4 + S.k * 0.6) end
end

function K.acordar(S, dt)
    local spec = S.spec
    local awaken = S.clips.awaken
    local lift = (spec.anchor and spec.anchor.lift or 0)
    local ih = S.idleImg and S.idleImg:getHeight() or 100
    if not S.stopped then
        S.img = awaken and clipFrame(awaken, 0) or idleFrame1(S)
        if awaken then S.used.awaken = true; S.view.currentFrame = 1 end
        S.tintK = awaken and 1 or (spec.inert == "unlit" and 0.42 or (spec.inert == "stone" and 0.62 or 1))
        if spec.anchor and spec.anchor.at == "side" then
            S.sideFrac = 1
            S.pose.liftK = lift / ih
        end
        if spec.step then S.pose.relOff = spec.step end
        if spec.anchor and spec.anchor.back then S.pose.liftK = lift / ih end
        return
    end
    pick(S, "wake")
    local sK = S.sKL
    local wake = clamp01(sK / 0.5)
    if awaken then
        S.img = clipFrame(awaken, sK)
        S.used.awaken = true
        S.view.currentFrame = 1
        if sK >= 1 then S.endFrame1 = true end
    else
        S.img = idleFrame1(S)
        S.endFrame1 = true
        local base = (spec.inert == "unlit" and 0.42 or (spec.inert == "stone" and 0.62 or 1))
        S.tintK = base + (1 - base) * wake
        if not S.red and wake < 1 then S.dxK = math.sin(S.sT * 48) * 0.012 * (1 - wake) else S.dxK = 0 end
    end
    if spec.glow then S.glowK = easeInOut(sK) end
    if spec.anchor and spec.anchor.at == "side" then
        local L = lift / ih
        if sK < 0.3 then
            S.sideFrac = 1
            S.pose.liftK = L
            S.crouch = 0.08 * easeInOut(sK / 0.3)
        elseif sK < 0.5 then
            S.sideFrac = 1
            local fk = (sK - 0.3) / 0.2
            S.pose.liftK = L * (1 - easeInQuad(fk))
            S.squash = -0.18 * math.sin(fk * math.pi)
        else
            if pick(S, "land") then
                squashPulse(S, 0.45, 0.22)
                burst("dust", 0.6)
            end
            local hk = clamp01((sK - 0.58) / 0.42)
            local h = easeInOut(hk)
            S.sideFrac = 1 - h
            S.pose.liftK = math.sin(h * math.pi) * 0.2
            if hk > 0 and hk < 1 then
                S.squash = -0.22 * math.sin(hk * math.pi)
            elseif hk >= 1 and not S.fired.hopSq then
                S.fired.hopSq = true
                squashPulse(S, 0.4, 0.2)
                burst("dust", 0.5)
            end
        end
    end
    if spec.step then
        local sp = clamp01((sK - 0.4) / 0.6)
        S.pose.relOff = spec.step * (1 - easeOutCubic(sp))
        if spec.anchor and spec.anchor.back then
            local dk = clamp01(sp * 1.6)
            S.pose.liftK = (lift / ih) * (1 - easeInQuad(dk))
            if dk >= 1 and not S.fired.stepSq then
                S.fired.stepSq = true
                squashPulse(S, 0.2, 0.2)
                burst("dust", 0.5)
            end
        end
    end
    if sK >= 1 then
        S.sideFrac, S.pose.liftK, S.pose.relOff, S.dxK, S.tintK = 0, 0, 0, 0, 1
        pick(S, "stop")
    end
end

function K.mergulho(S, dt)
    local spec = S.spec
    local win = S.red and 0.6 or 1.6
    local u0 = S.dur - win
    if S.t < u0 then
        S.pose.hidden = true
        S.img = S.idleImg or S.staticImg
        if spec.passes and not S.red then
            local pw = 2.2
            local p0 = u0 - pw
            S.passK = (S.t >= p0) and clamp01((S.t - p0) / pw) or -1
        end
        return
    end
    S.passK = -1
    S.pose.hidden = false
    pick(S, "start")
    local d = clamp01((S.t - u0) / math.max(0.01, S.total - S.lead - u0))
    local land = S.clips.land
    local swoop = S.clips.swoop or S.clips.descend
    local landing = d >= 0.75
    if landing and land then
        S.img = clipFrame(land, (d - 0.75) / 0.25)
        S.used.land = true
        S.view.currentFrame = 1
        if d >= 1 then S.endFrame1 = true end
    elseif swoop and not landing then
        S.img = loopFrame(swoop, (S.t - u0) * 1.5)
        S.used[S.clips.swoop and "swoop" or "descend"] = true
        S.view.currentFrame = 1
    else
        S.img = idleImage(S, dt, true)
        if landing and d >= 1 then S.img = idleFrame1(S); S.endFrame1 = true end
    end
    local amp = S.red and 1.2 or 3.2
    local fall = 1 - d
    S.pose.liftK = amp * fall * fall
    S.offFrac = (S.red and 0.25 or 0.7) * fall
    if spec.zigzag and not S.red then S.dxK = math.sin(d * math.pi * 5) * 0.22 * fall end
    S.pose.shadowA = 0.25 + 0.75 * d
    if spec.column then S.columnK = 1 - easeInQuad(clamp01((d - 0.6) / 0.4)) end
    if d >= 1 then
        S.pose.liftK, S.offFrac, S.dxK, S.columnK = 0, 0, 0, 0
        S.pose.shadowA = 1
        pick(S, "stop")
    end
end

function K.condensar(S, dt)
    local spec = S.spec
    local win = S.red and 0.4 or 1.2
    local u1 = S.dur - win
    local a = clamp01((S.t - u1) / math.max(0.01, S.total - S.lead - u1))
    if a > 0 then pick(S, "form") end
    local ae = easeInOut(a)
    local form = S.clips.form
    if form then
        S.img = clipFrame(form, a)
        S.used.form = true
        S.view.currentFrame = 1
        if a >= 1 then S.endFrame1 = true end
    else
        S.img = idleImage(S, dt, true)
    end
    S.alpha = ae
    if spec.flicker and ae < 0.9 and not S.red then
        S.alpha = clamp01(ae + math.sin(S.t * 37) * 0.08 * (1 - ae))
    end
    S.pose.shadowA = ae
    S.veilA = (spec.anchor and spec.anchor.veil) and clamp01(S.k * 1.6) * (1 - ae) or 0
    if spec.swarm then
        local sw0 = S.dur - (S.red and 0.6 or (spec.swarmLead or 2.0))
        S.swarmT0, S.swarmT1 = sw0, u1 + (S.red and 0.1 or 0.3)
        S.swarmK = clamp01((S.t - sw0) / math.max(0.01, S.total - S.lead - sw0))
        if S.t >= sw0 then pick(S, "start") end
    elseif S.t >= u1 then
        pick(S, "start")
    end
    local mp = spec.anchor and spec.anchor.mist and S.anchorProp
    if spec.anchor and spec.anchor.mist and a < 1 then
        S.tintK = EE.MIST_BODY_TINT + (1 - EE.MIST_BODY_TINT) * easeInOut(clamp01(a * 1.4 - 0.25))
    end
    if mp then
        mp.mistThick = clamp01(0.35 + S.k * 0.9)
        mp.mistRing = ae
        if S.k > 0.25 then EE.wxSet("ff", 1) end
    end
    if spec.lantern then S.lanternK = clamp01(0.25 + S.k * 0.9) end
    if spec.snow and not S.red and a > 0 and a < 1 then
        S.trailT = (S.trailT or 0) + dt
        if S.trailT >= 0.16 then S.trailT = 0; burst("snow", 0.4) end
    end
    if a >= 1 then
        S.alpha, S.veilA, S.swarmK = 1, 0, 0
        S.pose.shadowA = 1
        pick(S, "stop")
    end
end

function K.flanco(S, dt)
    local spec = S.spec
    local win = S.red and 0.5 or 1.8
    local u0 = S.dur - win
    local fromAnchor = spec.anchor and spec.anchor.at == "side"
    local burrowed = fromAnchor and S.clips.emerge or nil
    if S.t < u0 then
        S.pose.hidden = false
        S.sideFrac = 1
        if burrowed then
            S.img = clipFrame(burrowed, 0)
            S.used.emerge = true
            S.view.currentFrame = 1
        else
            S.img = idleImage(S, dt, true, u0)
        end
        return
    end
    S.pose.hidden = false
    pick(S, "start")
    local howl = S.clips.howl
    local arriveT = (howl and S.settle > 0) and S.dur or (S.total - S.lead)
    local m = clamp01((S.t - u0) / math.max(0.001, arriveT - u0))
    local me = easeInOut(m)
    S.sideFrac = 1 - me
    local fcyc = legCycles(S, spec.flankDist or 4) * me
    if not spec.hops then walkFeel(S, 6 * m * (1 - m), (S.clips.trot or S.clips.crawl) and fcyc or nil) end
    local move = S.clips.trot or S.clips.crawl or S.clips.hop
    local moveName = S.clips.trot and "trot" or (S.clips.crawl and "crawl" or (S.clips.hop and "hop" or nil))
    local settleK = S.sKL
    if howl and m >= 1 then
        S.img = clipFrame(howl, settleK)
        S.used.howl = true
        S.view.currentFrame = 1
        if settleK >= 1 then S.endFrame1 = true end
    elseif burrowed then
        S.img = m < 0.4 and clipFrame(burrowed, m / 0.4) or idleFrame1(S)
        S.used.emerge = true
        S.view.currentFrame = 1
        if m >= 0.4 then S.endFrame1 = true end
    elseif move and m < 1 then
        S.img = loopFrame(move, spec.hops and (m * spec.hops) or fcyc)
        S.used[moveName] = true
        S.view.currentFrame = 1
    elseif move then
        S.img = idleFrame1(S)
        S.endFrame1 = true
    else
        S.img = idleImage(S, dt, true)
    end
    if spec.hops and not S.red then
        local hp = m * spec.hops
        S.pose.liftK = math.abs(math.sin(hp * math.pi)) * 0.32 * (m < 1 and 1 or 0)
        local hi = math.floor(hp)
        if hi >= 1 and hi <= spec.hops and not S.fired["hop" .. hi] then
            S.fired["hop" .. hi] = true
            if spec.sfx.hop then playFirst(spec.sfx.hop) end
            burst("splash", 0.35)
            if hi < spec.hops then squashPulse(S, 0.5, 0.16) end
        end
    end
    if m >= 1 then
        S.sideFrac, S.offFrac, S.pose.liftK = 0, 0, 0
        pick(S, "stop")
    end
end

function K.montar(S, dt)
    local spec = S.spec
    local assemble = S.clips.assemble
    local rw = S.red and 0.4 or 1.5
    local r0 = S.dur - rw
    S.rocksK = assemble and 0 or clamp01((S.t - r0) / rw)
    local rise = S.settle > 0 and clamp01(S.sT / (S.settle * 0.8)) or (S.stopped and 1 or 0)
    if assemble then
        S.img = clipFrame(assemble, rise)
        S.used.assemble = true
        S.view.currentFrame = 1
        S.pose.hidden = false
        if rise >= 1 then S.endFrame1 = true end
    else
        S.img = idleFrame1(S)
        S.endFrame1 = true
        S.pose.hidden = not S.stopped
        S.riseK = easeOutCubic(rise)
        S.rocksA = 1 - S.riseK
    end
    S.pose.shadowA = clamp01(0.3 + rise)
    if S.t >= r0 + rw * 0.5 then pick(S, "mid") end
    if spec.glow then S.glowK = S.stopped and easeInOut(clamp01((S.sKL - 0.6) / 0.4)) or 0 end
    if S.sK >= 1 then pick(S, "stop") end
end

function EE.update(dt, tr)
    local S = st
    if not S or not tr then return false end
    S.t = tr.t
    S.k = clamp01(tr.t / math.max(0.001, tr.duration))
    S.stopped = tr.t >= tr.duration
    S.sT = math.max(0, tr.t - tr.duration)
    S.sK = S.settle > 0 and clamp01(S.sT / S.settle) or (S.stopped and 1 or 0)
    S.lead = math.min(EE.END_LEAD, S.settle > 0 and S.settle * 0.3 or EE.END_LEAD)
    S.sKL = S.settle > 0 and clamp01(S.sT / math.max(0.01, S.settle - S.lead)) or (S.stopped and 1 or 0)
    S.tail = tr.duration - tr.t
    S.left = S.total - tr.t
    S.pose.relOff, S.pose.hidden, S.pose.liftK, S.pose.shadowA = 0, false, 0, 1
    S.alpha, S.tintK, S.riseK, S.crouch, S.squash = 1, 1, 1, 0, 0
    S.sideFrac, S.offFrac, S.dxK = 0, 0, 0
    local fn = K[S.kind] or K.andar
    fn(S, dt)
    if S.squashT > 0 then
        S.squashT = math.max(0, S.squashT - dt)
        S.squash = S.squashAmp * (S.squashT / S.squashDur)
    end
    wxTick(dt)
    S.pose.alpha = S.alpha
    local p = S.anchorProp
    if p then
        local WorldRoad = require("src.ui.WorldRoad")
        p.z = p.stopZ + WorldRoad.BATTLE_REL + 0.25 + (p.back or 0)
        local pf = S.anchorFront
        if pf then pf.z = p.z - 0.5 end
        local present, presentF = false, pf == nil
        for i = 1, #WorldRoad._props do
            local q = WorldRoad._props[i]
            if q == p then present = true end
            if q == pf then presentF = true end
        end
        if not present then WorldRoad._props[#WorldRoad._props + 1] = p end
        if not presentF then WorldRoad._props[#WorldRoad._props + 1] = pf end
    end
    return tr.t >= S.total
end

function EE.finish()
    local S = st
    if not S then return nil end
    local handoff = nil
    if S.endFrame1 or (S.frozen and S.idle and S.idle.currentFrame == 1) then
        local ER = require("src.ui.EnemyRenderer")
        local fps, opts = ER._idleSpec(S.id)
        handoff = SpriteAnimation.new(S.id, "idle", "south", fps, opts)
        S.endFrame1 = true
    else
        handoff = S.idle
    end
    EE.lastBounce = S.spec.bounce and true or false
    EE.wxClear()
    EE._last = {
        id = S.id, kind = S.kind, used = S.used, clips = S.clips, total = S.total, settle = S.settle,
        dur = S.dur, side = S.side, endFrame1 = S.endFrame1, bounce = EE.lastBounce,
        handoffFrame = handoff and handoff.currentFrame or 1, anchor = S.anchorProp,
        footX = S.footX, footY = S.footY,
    }
    st = nil
    return handoff
end

function EE.endsWithLanding()
    return EE.lastBounce
end

EE.RATS = 10
EE.RAT_RUN = 1.3
EE.RAT_QUAD = { 4, 58, 42, 38 }
EE.RAT_RUMP = { cx = 33, cy = 19, rx = 9, ry = 15 }

function EE.ratImage(id)
    if ratImg ~= nil then return ratImg or nil end
    local path = "assets/sprites/characters/enemies/" .. id .. "/animations/form/south/0.png"
    if not love.filesystem.getInfo(path) then
        path = "assets/sprites/characters/enemies/" .. id .. "/animations/idle/south/0.png"
    end
    local ok, src = pcall(love.image.newImageData, path)
    if not ok or not src then ratImg = false; return nil end
    local q, R = EE.RAT_QUAD, EE.RAT_RUMP
    local d = love.image.newImageData(q[3], q[4])
    d:paste(src, 0, 0, q[1], q[2], q[3], q[4])
    local function inside(x, y)
        if x < R.cx then return true end
        local dx, dy = (x - R.cx) / R.rx, (y - R.cy) / R.ry
        return dx * dx + dy * dy <= 1
    end
    for y = 0, q[4] - 1 do
        for x = 0, q[3] - 1 do
            if not inside(x, y) then d:setPixel(x, y, 0, 0, 0, 0) end
        end
    end
    for y = 0, q[4] - 1 do
        for x = R.cx, q[3] - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.5 and (not inside(x + 1, y) or not inside(x, y - 1) or not inside(x, y + 1)) then
                d:setPixel(x, y, 0.09, 0.07, 0.06, 1)
            end
        end
    end
    local okI, img = pcall(love.graphics.newImage, d)
    ratImg = okI and img or false
    if ratImg then ratImg:setFilter("nearest", "nearest") end
    return ratImg or nil
end

EE.RAT_STRIDE_K = 1.2

function EE.drawRats(S, e, g, w, cx, sy, s, t)
    if S.ratRun == nil then
        S.ratRun = SpriteAnimation.exists(S.id, "rat_run", "south")
            and SpriteAnimation.new(S.id, "rat_run", "south", 10, { loop = true }) or false
    end
    local run = S.ratRun
    local src = (not run) and EE.ratImage(S.id) or nil
    if not run and not src then return end
    local Grade = require("engine.SceneGrade")
    local q = run and { 0, 0, run.frames[1]:getWidth(), run.frames[1]:getHeight() } or EE.RAT_QUAD
    local c = Grade.color("enemy", t, tmpColor)
    local n = S.red and 4 or EE.RATS
    local span = math.max(0.1, (S.swarmT1 or S.dur) - S.swarmT0 - EE.RAT_RUN)
    local fade = 1 - S.alpha
    S.ratPoke = S.ratPoke or {}
    for i = 1, n do
        local sd = (i % 2 == 0) and 1 or -1
        local t0 = S.swarmT0 + ((i * 0.618) % 1) * span
        local k = clamp01((S.t - t0) / EE.RAT_RUN)
        if k > 0 then
            local ke = easeOutCubic(k)
            local x0 = g.cx + sd * (w * 0.5 + q[3] * s)
            local spot = ((i * 0.381) % 1 - 0.5) * e.iw * s * 0.6
            local x1 = cx + spot
            local px = x0 + (x1 - x0) * ke
            local arc = math.sin(k * math.pi) * (((i * 0.53) % 1) - 0.5) * e.ih * s * 0.18
            local hop = (k < 1) and math.abs(math.sin(k * math.pi * 7)) * 2.5 * s or 0
            local py = sy + ((i * 0.29) % 1 - 0.5) * 22 * s + arc - hop
            local face = run and sd * -1 or -sd
            local img = src
            if run then
                local nf = #run.frames
                local runPx = math.abs(x1 - x0) * ke
                local cyc = runPx / math.max(1, EE.RAT_STRIDE_K * q[3] * s)
                img = (k < 1) and run.frames[1 + math.floor(cyc * nf) % nf] or run.frames[1]
                face = (sd < 0) and 1 or -1
            end
            love.graphics.setColor(c[1], c[2], c[3], fade)
            love.graphics.draw(img, math.floor(px), math.floor(py), 0, s * face, s, q[3] / 2, q[4])
            if k > 0.35 and not S.ratPoke[i] and S.footX then
                S.ratPoke[i] = true
                local r = require("src.ui.WorldRoad")._lastRect
                if r then grassPoke(S, (px - S.footX) / math.max(1, r.w)) end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function EE.drawUnder(e, g, w, cx, sy, s, t, lift)
    local S = st
    if not S or S.enc ~= e then return end
    local LightEngine = require("engine.LightEngine")
    local Grade = require("engine.SceneGrade")
    local spec = S.spec
    local ih = e.ih * s
    local iw = e.iw * s
    if S.veilA > 0 and spec.anchor then
        local img = EE.anchorImage(S.id, spec.anchor.name)
        if img then
            local vw, vh = img:getWidth() * s, img:getHeight() * s
            local c = Grade.color("enemy", t, tmpColor)
            local vy = sy - vh + (spec.anchor.floats and -lift or 0)
            if spec.anchor.floats then vy = sy - ih * 0.5 - vh * 0.5 - lift end
            love.graphics.setColor(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85, S.veilA)
            love.graphics.draw(img, math.floor(cx - vw / 2), math.floor(vy), 0, s, s)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    if S.passK >= 0 then
        local pk = S.passK
        local sweep = math.sin(pk * math.pi * 2)
        local px0 = cx + sweep * w * 0.55
        local shd = 0.22 * math.sin(pk * math.pi)
        love.graphics.setColor(0, 0, 0, shd)
        love.graphics.ellipse("fill", px0, sy - 2, iw * 0.55, ih * 0.09)
        love.graphics.setColor(1, 1, 1, 1)
    end
    if spec.swarm == "rats" and S.swarmT0 and S.t >= S.swarmT0 and S.alpha < 1 then
        EE.drawRats(S, e, g, w, cx, sy, s, t)
    elseif S.swarmK > 0 and S.img and spec.swarm ~= "rats" then
        local sw = spec.swarm
        local n = sw == "bats" and 9 or 14
        local c = Grade.color("enemy", t, tmpColor)
        for i = 1, n do
            local sd = (i % 2 == 0) and 1 or -1
            local ph = i * 1.7
            local k = clamp01(S.swarmK * 1.25 - (i % 4) * 0.07)
            local ke = easeInOut(k)
            local lane = ((i * 7) % 5 - 2) * 0.09
            local x0 = sd * (w * 0.5 + 40 + (i % 3) * 30) * (1 - ke)
                + sd * lane * iw * ke + math.sin(ph + S.t * 9) * iw * 0.10 * (1 - ke)
            local a = (1 - S.alpha) * 0.95
            if sw == "bats" then
                local y0 = sy - ih * (0.4 + 0.5 * (1 - ke)) + math.sin(S.t * 11 + ph) * ih * 0.06
                love.graphics.setColor(0.08, 0.04, 0.1, a)
                local flap = math.abs(math.sin(S.t * 18 + ph)) * 6 * s * 0.5
                love.graphics.polygon("fill", cx + x0 - 7 * s, y0 - flap, cx + x0, y0 + 2 * s, cx + x0 + 7 * s, y0 - flap, cx + x0, y0 + 5 * s)
            else
                local ms = s * (0.30 + (i % 3) * 0.05)
                local y0 = sy + ((i * 3) % 4 - 1.5) * 3 * s + math.abs(math.sin(ph + S.t * 14)) * -3 * s * (1 - ke)
                love.graphics.setColor(c[1] * 0.45, c[2] * 0.42, c[3] * 0.45, a)
                love.graphics.draw(S.idleImg or S.img, math.floor(cx + x0 - e.iw * ms / 2), math.floor(y0 - e.ih * ms), 0, ms * sd, ms)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    if S.rocksK > 0 and (S.rocksA or 1) > 0.01 then
        local a = S.rocksA or 1
        local c = Grade.color("prop", t, tmpColor)
        for i = 1, 4 do
            local sd = (i % 2 == 0) and 1 or -1
            local ke = easeOutCubic(clamp01(S.rocksK * 1.1 - (i - 1) * 0.04))
            local rx = cx + sd * ((w * 0.5 + 30) * (1 - ke) + (0.08 + (i - 1) * 0.07) * iw * ke)
            local rw2 = (14 + (i % 3) * 4) * s
            local ry = sy - rw2 * 0.45
            love.graphics.setColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.55, a)
            love.graphics.ellipse("fill", rx, ry, rw2, rw2 * 0.7)
            love.graphics.setColor(c[1] * 0.68, c[2] * 0.68, c[3] * 0.72, a)
            love.graphics.ellipse("fill", rx - rw2 * 0.2, ry - rw2 * 0.25, rw2 * 0.5, rw2 * 0.35)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function EE.drawProp(p, g, x, w, t, rel, camZ, em)
    local WorldRoad = require("src.ui.WorldRoad")
    local src = p.front and p.ref or p
    local img = EE.anchorImage(src.entrId, src.name)
    local frames = EE.anchorFrames(src.entrId)
    local fIdx = 1
    if frames then
        fIdx = reducedMotion() and 1
            or (1 + math.floor((WorldRoad._time or 0) * EE.ANCHOR_FPS + (src.z or 0) * 7.31) % #frames)
        img = frames[fIdx]
    end
    if not img then return end
    local Grade = require("engine.SceneGrade")
    local iw, ih = img:getWidth(), img:getHeight()
    if p.front then
        rel = src.z - camZ
        t = g.tOf(rel)
        if not t then return end
    end
    local tB = g.tOf(WorldRoad.BATTLE_REL) or 0.3
    local k = math.min(1.02, g.persp(t) / math.max(0.01, g.persp(tB)))
    local s = src.ts * WorldRoad.battleSizeK() * WorldRoad.enemyScreenK(g.h) * k
    local wob = WorldRoad._roadWobble and WorldRoad._roadWobble(src.z, t, w) or 0
    local pxX = g.cx + wob - math.floor((src.offX or 0) * s)
    local sy
    if src.side ~= 0 then
        pxX = pxX + sideX(g, w, t, src.side, iw * s * 0.5)
        sy = g.latY(pxX - g.cx, t)
    else
        sy = g.crestApexY + (g.bottomY - g.crestApexY) * t
    end
    local alpha = 1
    local f = WorldRoad._fork
    if f and not f.converge then alpha = alpha * (1 - (f.animIn or 1)) end
    if f and f.converge then alpha = 0 end
    local grow = src.grow or 1
    if alpha <= 0.01 or grow <= 0.001 then
        if EE._trace then EE._trace(p, pxX, sy, t, s, 0) end
        return
    end
    local c = Grade.color("prop", t, tmpColor)
    local half = src.straddle and math.floor(ih / 2) or ih
    local behind = em ~= nil
    local sx, sy2 = s, s * grow
    if src.mist then
        local ph = WorldRoad._time or 0
        local thick, ring = src.mistThick or 0.35, src.mistRing or 0
        sx = s * (0.85 + 0.25 * thick) * (1 + 0.12 * ring) * (1 + 0.03 * math.sin(ph * 1.3))
        sy2 = sx * (1 - 0.55 * ring) * (1 + 0.04 * math.sin(ph * 0.9 + 1))
        alpha = alpha * EE.MIST_ALPHA * (0.6 + 0.4 * thick) * (1 - 0.4 * ring)
        local fr, fg, fb = Grade.fogRaw()
        if fr then
            local m = EE.MIST_FOG
            c[1], c[2], c[3] = c[1] * (1 - m) * 0.7 + fr * m, c[2] * (1 - m) * 0.7 + fg * m, c[3] * (1 - m) * 0.7 + fb * m
        end
    end
    if behind then sy = sy + (1 - em) * ih * s * 0.95 end
    local groundY = src.straddle and (sy + (ih - half) * sy2) or sy
    if not p.front and not behind then
        if EE.TALL_ANCHORS[src.name] and grow >= 0.999 then
            local o = src._shOpt or {}
            src._shOpt = o
            o.alphaK, o.flip, o.footPad = EE.ANCHOR_SHADOW_A * alpha, 1, 0
            o.baseK, o.riseK, o.lenK = EE.ANCHOR_SHADOW_BASE, nil, nil
            EE.deferShadow(img, pxX, groundY, s, t, o, 0.8 * alpha)
        elseif EE.CONTACT_ANCHORS[src.name] then
            EE.deferShadow(img, pxX, groundY, s, t, nil, 0.45 * alpha)
        end
    end
    local rot = 0
    local t0 = src._pokeT
    if t0 and not behind then
        local el = WorldRoad._time - t0
        if el >= 1.3 then src._pokeT = nil
        else rot = math.sin(el * 16) * (EE.TALL_ANCHORS[src.name] and 0.05 or 0.012) * math.exp(-el * 3.4) end
    end
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    local y0 = sy - ih * sy2
    if src.straddle and not behind then
        quad = quad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
        y0 = sy - half * sy2
        if p.front then
            quad:setViewport(0, half, iw, ih - half, iw, ih)
            love.graphics.draw(img, quad, math.floor(pxX), math.floor(sy), rot, sx, sy2, iw / 2, 0)
            local rg = src.mistRing or 0
            local veil = src.mist and math.min(1, 4 * rg * (1 - rg) * 1.3) or 0
            if veil > 0.01 then
                local vimg = frames and frames[1 + (fIdx + 1) % #frames] or img
                love.graphics.setColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.6, alpha * EE.MIST_VEIL * veil)
                love.graphics.draw(vimg, math.floor(pxX), math.floor(sy + (ih - half) * sy2), 0,
                    sx * 1.05, sx, iw / 2, ih)
            end
        else
            quad:setViewport(0, 0, iw, half, iw, ih)
            love.graphics.draw(img, quad, math.floor(pxX), math.floor(sy), rot, sx, sy2, iw / 2, half)
        end
    elseif src.straddle then
        love.graphics.draw(img, math.floor(pxX), math.floor(sy), 0, sx, sy2, iw / 2, half)
    else
        love.graphics.draw(img, math.floor(pxX), math.floor(sy), rot, sx, sy2, iw / 2, ih)
    end
    if src.mist and not p.front and not behind and not reducedMotion() then
        local ph = WorldRoad._time or 0
        local thick, ring = src.mistThick or 0.35, src.mistRing or 0
        local u = math.max(1, math.floor(s * 1.5))
        for i = 1, 12 do
            local q = (ph * 0.22 + i * 0.137) % 1
            local hx = ((i * 0.618) % 1 - 0.5) * iw * sx * 0.9 + math.sin(ph * 0.7 + i) * 4 * s
            local a = math.sin(q * math.pi) * 0.55 * thick * (1 - 0.7 * ring) * alpha
            love.graphics.setColor(c[1] * 0.25, c[2] * 0.22, c[3] * 0.3, a)
            love.graphics.rectangle("fill", math.floor(pxX + hx), math.floor(sy - q * ih * s * 1.8), u, u)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    local hsn = WorldRoad._hitScene
    if hsn and not p.front and not behind then
        hsn[#hsn + 1] = { x1 = pxX - iw * sx / 2, y1 = y0, x2 = pxX + iw * sx / 2, y2 = src.straddle and (sy + (ih - half) * sy2) or sy,
            ref = p, kind = "anchor", s = s }
    end
    if EE._trace then EE._trace(p, pxX, sy, behind and 0 or t, s, alpha) end
end

function EE.info()
    if st then
        return {
            id = st.id, kind = st.kind, used = st.used, clips = st.clips, total = st.total, settle = st.settle,
            dur = st.dur, side = st.side, t = st.t, active = true, anchor = st.anchorProp,
        }
    end
    return EE._last
end

function EE.describeClips(id)
    local spec = EE.specFor(id)
    local out = {}
    for _, name in ipairs(spec.clips or {}) do
        out[#out + 1] = name .. (SpriteAnimation.exists(id, name, "south") and "" or " (idle)")
    end
    return table.concat(out, ", ")
end

return EE
