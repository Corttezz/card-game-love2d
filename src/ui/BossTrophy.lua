local Data        = require("src.data.boss_trophy")
local BossJokers  = require("src.systems.BossJokers")
local Sfx         = require("src.systems.Sfx")
local I18n        = require("src.i18n.I18n")
local FontManager = require("src.ui.FontManager")

local BossTrophy = {}

local tr = nil

local function clamp01(x) return math.max(0, math.min(1, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function easeOutCubic(k) return 1 - (1 - k) ^ 3 end
local function easeOutQuart(k) return 1 - (1 - k) ^ 4 end

local function sfx(code, fallback)
    local name = (code and Sfx.has(code)) and code or fallback
    if name and Sfx.has(name) then Sfx.play(name) end
end

function BossTrophy.themeFor(bossId)
    return Data.themes[bossId] or Data.default
end

function BossTrophy.stepFor(game, reduced)
    local e = game and game.enemy
    if not (e and e.isBoss) then return nil end
    local run = game.runManager and game.runManager.currentRun
    local cardId = BossJokers.offerForBoss(run, e.spriteId)
    if not cardId then return nil end
    local base = reduced and Data.stepReduced or Data.step
    return { kind = "trophy", dur = base.dur, card = cardId, boss = e.spriteId }
end

function BossTrophy.withTrophy(steps, game, reduced)
    local st = BossTrophy.stepFor(game, reduced)
    if not st then return steps end
    local out = {}
    for i, s in ipairs(steps or {}) do out[i] = s end
    out[#out + 1] = st
    return out
end

local function screen()
    return love.graphics.getWidth(), love.graphics.getHeight()
end

local function pixel(h)
    return math.max(2, math.floor(h / 240))
end

function BossTrophy.start(st, stage, reduced)
    local w, h = screen()
    local kx = (stage and stage.w and stage.w > 0) and (w / stage.w) or 1
    local ky = (stage and stage.h and stage.h > 0) and (h / stage.h) or 1
    local inst = nil
    local ok, CardDatabase = pcall(require, "src.systems.CardDatabase")
    if ok and CardDatabase then
        local cd = CardDatabase:getCard(st.card)
        if cd then
            local okI, made = pcall(function() return CardDatabase:createCardInstance(cd) end)
            if okI then inst = made end
        end
    end
    local ox, oy = w * 0.5, h * 0.62
    local bb = stage and stage.bbox
    if bb and bb.cx then
        ox = (stage.cx or bb.cx) * kx
        oy = ((bb.bottomY or oy / ky) - (bb.height or 0) * 0.35) * ky
    elseif stage and stage.cx then
        ox, oy = stage.cx * kx, (stage.cy or oy / ky) * ky
    end
    tr = {
        card = st.card, boss = st.boss, inst = inst, theme = BossTrophy.themeFor(st.boss),
        t = 0, dur = st.dur or Data.step.dur, reduced = reduced and true or false,
        ox = ox, oy = oy, tx = w * Data.target.x, ty = h * Data.target.y,
        w = w, h = h, px = pixel(h),
        parts = {}, spawnAcc = 0, revealed = false, rings = {}, angle = 0,
    }
    if tr.reduced then
        tr.revealed = true
        tr.revealT = 0
    else
        sfx(tr.theme.riseSound, "bossWingPass")
    end
end

function BossTrophy.stop()
    tr = nil
end

function BossTrophy.isActive() return tr ~= nil end

local function phaseOf()
    if not tr then return nil end
    local T = Data.timing
    local dur = tr.dur
    if tr.t >= dur - T.fade then return "fade" end
    if tr.reduced then return "stopped" end
    if tr.t < T.delay then return "emerge" end
    if tr.t < T.delay + T.rise then return "rise" end
    if tr.t < T.delay + T.rise + T.settle then return "settle" end
    return "stopped"
end

function BossTrophy.state()
    if not tr then return nil end
    local ph = phaseOf()
    return {
        card = tr.card, boss = tr.boss, phase = ph, angle = tr.angle,
        spinning = (ph == "rise" or ph == "settle"), revealed = tr.revealed,
        reduced = tr.reduced, x = tr.x, y = tr.y, scale = tr.scale,
        particles = #tr.parts,
    }
end

local function spawn(x, y, burst)
    local th = tr.theme
    local kind = th.particle
    local c = th.colors[love.math.random(1, #th.colors)]
    local a = love.math.random() * math.pi * 2
    local sp = burst and (90 + love.math.random() * 220) or (20 + love.math.random() * 60)
    local p = { x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                life = 0, max = 0.9 + love.math.random() * 1.1, c = c, kind = kind,
                sz = love.math.random(1, 2), sway = love.math.random() * 6 }
    if kind == "ember" or kind == "spore" then
        p.vy = p.vy - (burst and 60 or 50)
    elseif kind == "feather" or kind == "snow" or kind == "petal" then
        p.vy = p.vy * 0.6 + (burst and -40 or 10)
    end
    tr.parts[#tr.parts + 1] = p
end

local function cardPose()
    local T = Data.timing
    local k = 1
    if not tr.reduced then
        k = clamp01((tr.t - T.delay) / T.rise)
    end
    local e = easeOutCubic(k)
    local x = lerp(tr.ox, tr.tx, e)
    local arc = math.sin(k * math.pi) * tr.h * 0.05
    local y = lerp(tr.oy, tr.ty, e) - arc
    local scale = lerp(Data.startScale, 1, easeOutCubic(k))
    local angle = 0
    if not tr.reduced then
        local spinK = clamp01((tr.t - T.delay) / (T.rise + T.settle))
        angle = Data.spin.turns * math.pi * 2 * easeOutQuart(spinK)
    end
    local ph = phaseOf()
    if ph == "stopped" or ph == "fade" then
        local since = tr.t - (tr.reduced and 0 or (T.delay + T.rise + T.settle))
        y = y + math.sin(since * 2.2) * tr.h * 0.006
    end
    return x, y, scale, angle
end

function BossTrophy.update(dt)
    if not tr then return end
    tr.t = tr.t + dt
    local x, y, scale, angle = cardPose()
    tr.x, tr.y, tr.scale, tr.angle = x, y, scale, angle
    local ph = phaseOf()
    if not tr.reduced then
        if ph == "emerge" or ph == "rise" or ph == "settle" then
            tr.spawnAcc = tr.spawnAcc + dt * tr.theme.rate
            while tr.spawnAcc >= 1 do
                tr.spawnAcc = tr.spawnAcc - 1
                local r = tr.h * Data.cardH * 0.5 * scale
                local a = love.math.random() * math.pi * 2
                spawn(x + math.cos(a) * r * 0.8, y + math.sin(a) * r, false)
            end
        end
        if (ph == "stopped" or ph == "fade") and not tr.revealed then
            tr.revealed = true
            tr.revealT = tr.t
            for _ = 1, tr.theme.burst do spawn(x, y, true) end
            tr.rings[#tr.rings + 1] = { t = 0, dur = 0.6 }
            tr.rings[#tr.rings + 1] = { t = -0.12, dur = 0.7 }
            sfx("bossRevealSting", nil)
            sfx("jokerSig_" .. tostring(tr.card), "jokerTick")
            local ok, CRT = pcall(require, "src.ui.CRTShader")
            if ok and CRT and CRT.jolt then pcall(CRT.jolt, 0.35) end
        end
        for i = #tr.parts, 1, -1 do
            local p = tr.parts[i]
            p.life = p.life + dt
            if p.life >= p.max then
                table.remove(tr.parts, i)
            else
                local drag = 1 - math.min(0.9, dt * 1.6)
                p.vx = p.vx * drag
                p.vy = p.vy * drag
                if p.kind == "ember" or p.kind == "spore" then
                    p.vy = p.vy - 30 * dt
                elseif p.kind == "feather" or p.kind == "petal" or p.kind == "snow" then
                    p.vy = p.vy + 28 * dt
                    p.vx = p.vx + math.sin(p.life * 5 + p.sway) * 40 * dt
                elseif p.kind == "shard" then
                    p.vy = p.vy + 60 * dt
                end
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
            end
        end
        for i = #tr.rings, 1, -1 do
            local r = tr.rings[i]
            r.t = r.t + dt
            if r.t >= r.dur then table.remove(tr.rings, i) end
        end
    end
end

local function snap(v, px) return math.floor(v / px + 0.5) * px end

local function drawGlow(x, y, r, color, a)
    local px = tr.px
    love.graphics.setBlendMode("add")
    for i = 3, 1, -1 do
        love.graphics.setColor(color[1], color[2], color[3], a * (0.16 + 0.10 * (3 - i)))
        love.graphics.circle("fill", snap(x, px), snap(y, px), snap(r * (0.55 + 0.32 * i), px), 24)
    end
    love.graphics.setBlendMode("alpha")
end

local function drawRays(x, y, r, color, a)
    local n = 10
    local spin = tr.t * 0.35
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], a)
    for i = 1, n do
        local ang = spin + i * (math.pi * 2 / n)
        local half = 0.07
        local x1 = x + math.cos(ang - half) * r * 2.4
        local y1 = y + math.sin(ang - half) * r * 2.4
        local x2 = x + math.cos(ang + half) * r * 2.4
        local y2 = y + math.sin(ang + half) * r * 2.4
        love.graphics.polygon("fill", x, y, x1, y1, x2, y2)
    end
    love.graphics.setBlendMode("alpha")
end

local function drawParts()
    local px = tr.px
    for _, p in ipairs(tr.parts) do
        local k = p.life / p.max
        local a = (k < 0.15) and (k / 0.15) or (1 - (k - 0.15) / 0.85)
        love.graphics.setColor(p.c[1], p.c[2], p.c[3], a)
        local s = px * p.sz
        local x, y = snap(p.x, px), snap(p.y, px)
        if p.kind == "feather" then
            love.graphics.rectangle("fill", x, y, s * 2, s)
        elseif p.kind == "shard" then
            love.graphics.rectangle("fill", x, y, s, s * 2)
        else
            love.graphics.rectangle("fill", x, y, s, s)
        end
    end
end

local function drawCard(x, y, scale, angle, alpha)
    local cardH = tr.h * Data.cardH * scale
    local cw, ch = 96, 144
    local k = cardH / ch
    local cosA = math.cos(angle)
    local sx = k * math.max(0.04, math.abs(cosA))
    local front = cosA >= 0
    local img = nil
    if front and tr.inst then
        local okF, CardFrame = pcall(require, "src.ui.CardFrame")
        if okF and CardFrame and CardFrame.displayImage then img = CardFrame.displayImage(tr.inst) end
        img = img or tr.inst.image
    end
    local shade = 0.55 + 0.45 * math.abs(cosA)
    love.graphics.setColor(0, 0, 0, 0.45 * alpha)
    love.graphics.rectangle("fill", x - cw * sx / 2 + tr.px * 2, y - cardH / 2 + tr.px * 3,
        cw * sx, cardH)
    if img then
        love.graphics.setColor(shade, shade, shade, alpha)
        love.graphics.draw(img, x, y, 0, sx * cw / img:getWidth(), k * ch / img:getHeight(),
            img:getWidth() / 2, img:getHeight() / 2)
    else
        local okB, CardBack = pcall(require, "src.ui.CardBack")
        local back = okB and CardBack and CardBack.getImage and CardBack.getImage() or nil
        love.graphics.setColor(shade, shade, shade, alpha)
        if back then
            love.graphics.draw(back, x, y, 0, sx * cw / back:getWidth(), k * ch / back:getHeight(),
                back:getWidth() / 2, back:getHeight() / 2)
        else
            love.graphics.rectangle("fill", x - cw * sx / 2, y - cardH / 2, cw * sx, cardH)
        end
    end
    return cardH
end

function BossTrophy.draw()
    if not tr or not tr.x then return end
    local T = Data.timing
    local ph = phaseOf()
    local alpha = 1
    if ph == "fade" then alpha = 1 - clamp01((tr.t - (tr.dur - T.fade)) / T.fade) end
    if tr.reduced then alpha = alpha * clamp01(tr.t / T.reducedIn) end
    if ph == "emerge" then
        local k = clamp01(tr.t / T.delay)
        drawGlow(tr.ox, tr.oy, tr.h * 0.05 * (0.5 + k), tr.theme.glow, 0.8 * k)
        drawParts()
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local x, y, scale, angle = tr.x, tr.y, tr.scale, tr.angle
    local r = tr.h * Data.cardH * 0.5 * scale
    local rk = tr.revealed and clamp01((tr.t - (tr.revealT or 0)) / 0.35) or 0
    if not tr.reduced then
        drawRays(x, y, r, tr.theme.ray, (0.05 + 0.08 * rk) * alpha)
    end
    drawGlow(x, y, r * (1 + 0.25 * rk), tr.theme.glow, (0.55 + 0.35 * rk) * alpha)
    drawParts()
    local cardH = drawCard(x, y, scale, angle, alpha)
    for _, ring in ipairs(tr.rings) do
        if ring.t > 0 then
            local k = ring.t / ring.dur
            love.graphics.setBlendMode("add")
            love.graphics.setColor(tr.theme.ray[1], tr.theme.ray[2], tr.theme.ray[3], (1 - k) * 0.8)
            love.graphics.setLineWidth(tr.px)
            love.graphics.circle("line", snap(x, tr.px), snap(y, tr.px), snap(r * (1 + k * 1.8), tr.px), 32)
            love.graphics.setLineWidth(1)
            love.graphics.setBlendMode("alpha")
        end
    end
    if tr.revealed then
        local na = alpha * clamp01((tr.t - (tr.revealT or 0) - 0.1) / 0.3)
        local name = I18n.cardName(tr.card)
        local font = FontManager.getFont(math.max(12, math.floor(tr.h * 0.028)))
        love.graphics.setFont(font)
        local tw = font:getWidth(name)
        local tx = math.floor(x - tw / 2)
        local ty = math.floor(y + cardH / 2 + tr.h * 0.025)
        love.graphics.setColor(0.06, 0.04, 0.03, 0.75 * na)
        love.graphics.rectangle("fill", tx - 12, ty - 6, tw + 24, font:getHeight() + 12)
        love.graphics.setColor(0, 0, 0, na)
        love.graphics.print(name, tx + 1, ty + 1)
        love.graphics.setColor(0.95, 0.80, 0.42, na)
        love.graphics.print(name, tx, ty)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return BossTrophy
