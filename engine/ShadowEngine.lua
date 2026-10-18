local Debug = require("src.core.Debug")

local ShadowEngine = {}

local frame = {
    sunX = 0, w = 1,
    len = 0.5,
    alpha = 0.26,
    stamp = -1,
    alphaK = 1,
    tr = 0, tg = 0, tb = 0,
    cx = 0, cy = 0, R = 1, D = 1, clip = false,
    bandUsed = false,
}
function ShadowEngine.setTint(r, g, b) frame.tr, frame.tg, frame.tb = r or 0, g or 0, b or 0 end
function ShadowEngine.getClip() return frame.cx, frame.cy, frame.R, frame.D end
function ShadowEngine.setClip(cx, cy, R, D)
    frame.cx, frame.cy, frame.R, frame.D = cx, cy, R, math.max(1, D)
    frame.clip = true
end
function ShadowEngine.setAlphaK(k) frame.alphaK = k or 1 end
ShadowEngine.stats = { queued = 0 }

function ShadowEngine.setFrame(sunX, w, tod, luma)
    frame.sunX = sunX or 0
    frame.w = math.max(1, w or 1)
    frame.len = 0.55 + 0.45 * math.max(0, math.min(1, tod or 1))
    local l = math.max(0, math.min(1, luma or 1))
    frame.alpha = 0.15 + 0.15 * l
    frame.stamp = love.timer.getTime()
    frame.clip = false
    frame.bandUsed = false
    ShadowEngine.stats.queued = 0
    ShadowEngine.stats.bands = 0
end

function ShadowEngine.isActive()
    return (love.timer.getTime() - frame.stamp) < 0.1
end

local function tipShift(px)
    return math.max(-1, math.min(1, (px - frame.sunX) / (frame.w * 0.5)))
end

function ShadowEngine.tipShiftAt(px)
    if not ShadowEngine.isActive() then return 0 end
    return tipShift(px)
end

local SMEAR = { { -1, 0 }, { 0.7, -0.5 }, { 0.35, 0.55 } }
local SCALE = 3
local scratch, batching, batchPrev
local soloAlphaK
local SH = { cv = {}, quad = nil, vC = { 0, 0 }, vB = { 0, 0 }, vT = { 0, 0, 0, 0 }, yMin = 1e9, yMax = -1e9, xMin = 1e9, xMax = -1e9, pLo = nil, pHi = nil,
            bx0 = {}, by0 = {}, bx1 = {}, by1 = {}, bn = 0 }
ShadowEngine.FADE = 0.6

SH.FADE_SRC = [[
uniform float fadeK;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 c = Texel(tex, tc) * color;
    float d = clamp(1.0 - tc.y, 0.0, 1.0);
    float f = 1.0 - fadeK * d;
    return vec4(c.rgb * f, c.a * f);
}
]]
SH.COMP_SRC = [[
uniform vec2 C;
uniform float R;
uniform float D;
uniform vec2 band;
uniform vec4 tint;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float t = (R - distance(sc, C)) / D;
    if (t < band.x || t >= band.y) discard;
    float a = Texel(tex, tc).a * tint.a;
    return vec4(tint.rgb * a, a);
}
]]

local function shaders()
    if SH.ok == nil then
        local ok1, f = pcall(love.graphics.newShader, SH.FADE_SRC)
        local ok2, c = pcall(love.graphics.newShader, SH.COMP_SRC)
        SH.ok = ok1 and ok2
        if SH.ok then
            SH.fade, SH.comp = f, c
        else
            Debug.warn("[ShadowEngine] shader de sombra não compilou: " .. tostring(ok1 and c or f))
        end
    end
    return SH.ok
end

local function ensureCanvas(key)
    local W, H = love.graphics.getDimensions()
    local cw, ch = math.ceil(W / SCALE), math.ceil(H / SCALE)
    local cv = SH.cv[key]
    if not cv or cv:getWidth() ~= cw or cv:getHeight() ~= ch then
        cv = love.graphics.newCanvas(cw, ch, { format = "rgba8" })
        cv:setFilter("nearest", "nearest")
        SH.cv[key] = cv
    end
    return cv
end

local function openCanvas(key, clear)
    local cv = ensureCanvas(key)
    scratch = cv
    batchPrev = love.graphics.getCanvas()
    SH.prevShader = love.graphics.getShader()
    SH.bm, SH.am = love.graphics.getBlendMode()
    SH.sx, SH.sy, SH.sw, SH.sh = love.graphics.getScissor()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(cv)
    if clear then love.graphics.clear(0, 0, 0, 0) end
    love.graphics.setBlendMode("lighten", "premultiplied")
    love.graphics.scale(1 / SCALE)
    if shaders() then
        love.graphics.setShader(SH.fade)
        SH.fade:send("fadeK", ShadowEngine.FADE)
        SH.fadeK = ShadowEngine.FADE
    end
    batching = true
end

local function closeCanvas()
    batching = false
    love.graphics.pop()
    love.graphics.setCanvas(batchPrev)
    love.graphics.setShader(SH.prevShader)
    love.graphics.setBlendMode(SH.bm or "alpha", SH.am or "alphamultiply")
    if SH.sx then
        love.graphics.setScissor(SH.sx, SH.sy, SH.sw, SH.sh)
    else
        love.graphics.setScissor()
    end
end

local function composite(cv, tLo, tHi, alphaK)
    local a = math.min(0.75, frame.alpha * frame.alphaK * (alphaK or 1))
    local W, H = love.graphics.getDimensions()
    local y0, y1 = 0, H
    if frame.clip and tLo > -1e8 then
        local rLo = frame.R - frame.D * math.max(-1, tLo)
        local rHi = frame.R - frame.D * math.min(4, tHi)
        y0 = frame.cy - rLo
        local half = math.max(frame.cx, W - frame.cx)
        local under = rHi * rHi - half * half
        y1 = under > 0 and (frame.cy - math.sqrt(under)) or H
        y0 = math.max(0, math.floor(y0 / SCALE) * SCALE, math.floor(SH.yMin / SCALE) * SCALE)
        y1 = math.min(H, math.ceil(y1 / SCALE + 1) * SCALE, math.ceil(SH.yMax / SCALE + 1) * SCALE)
        if y1 <= y0 then return end
    end
    SH.quad = SH.quad or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    local cw, ch = cv:getDimensions()
    SH.quad:setViewport(0, y0 / SCALE, cw, (y1 - y0) / SCALE, cw, ch)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode("alpha", "premultiplied")
    local prevShader = love.graphics.getShader()
    if shaders() then
        love.graphics.setShader(SH.comp)
        SH.vC[1], SH.vC[2] = frame.cx, frame.cy
        SH.comp:send("C", SH.vC)
        SH.comp:send("R", frame.R)
        SH.comp:send("D", frame.D)
        if frame.clip then
            SH.vB[1], SH.vB[2] = tLo, tHi
        else
            SH.vB[1], SH.vB[2] = -1e9, 1e9
        end
        SH.comp:send("band", SH.vB)
        SH.vT[1], SH.vT[2], SH.vT[3], SH.vT[4] = frame.tr, frame.tg, frame.tb, a
        SH.comp:send("tint", SH.vT)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0, 0, 0, a)
    end
    love.graphics.draw(cv, SH.quad, 0, y0, 0, SCALE, SCALE)
    love.graphics.setShader(prevShader)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function ShadowEngine.beginBatch()
    if not ShadowEngine.isActive() or batching then return end
    openCanvas("solo", true)
end

function ShadowEngine.endBatch()
    if not batching then return end
    local cv = scratch
    closeCanvas()
    local wasClip = frame.clip
    frame.clip = false
    composite(cv, -1e9, 1e9, soloAlphaK)
    frame.clip = wasClip
    soloAlphaK = nil
end

local function fadeFor(feetY, lenPx, feetX, halfW)
    if feetY < SH.yMin then SH.yMin = feetY end
    if feetY + lenPx + 8 > SH.yMax then SH.yMax = feetY + lenPx + 8 end
    if feetX then
        local hw = (halfW or 0) + lenPx * 0.8 + 8
        if feetX - hw < SH.xMin then SH.xMin = feetX - hw end
        if feetX + hw > SH.xMax then SH.xMax = feetX + hw end
    end
    local want = feetX and ShadowEngine.FADE or 0
    if batching and SH.ok and love.graphics.getShader() == SH.fade and SH.fadeK ~= want then
        SH.fade:send("fadeK", want)
        SH.fadeK = want
    end
end

local NO_OPTS = {}

local profWarned = {}
local function footprint(opts, feetY, contentH, s, lenMul, margin)
    local baseK = opts.baseK or 0
    local riseK = opts.riseK
    if baseK <= 0 and not riseK then return feetY, 0, nil end
    if contentH <= 0 then
        local k = tostring(opts.baseK) .. "/" .. tostring(riseK)
        if not profWarned[k] then
            profWarned[k] = true
            Debug.warn("[ShadowEngine] perfil de pegada sem contentH (baseK="
                .. k .. ") — projetando a silhueta inteira")
        end
        return feetY, 0, nil
    end
    local baseH = baseK * contentH
    local riseH = riseK and (riseK * contentH) or (contentH - baseH)
    if riseH <= 0 then return false end
    local ay = feetY - baseH * s * 0.5
    return ay, baseH, ay + riseH * s * lenMul + margin
end

local function cutScissor(ay, yCut)
    local y0 = math.floor(ay / SCALE)
    love.graphics.setScissor(0, y0, scratch:getWidth(),
        math.max(1, math.ceil(yCut / SCALE) - y0))
end

function ShadowEngine.sprite(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    opts = opts or NO_OPTS
    local iw, ih = img:getWidth(), img:getHeight()
    local pad = opts.footPad or 0
    local lenK = opts.lenK or 1
    local d = math.max(1.5, iw * s * 0.035)
    local ay, baseH, yCut = footprint(opts, feetY, ih - pad, s,
        frame.len * lenK, d)
    if not ay then return true end
    local solo = not batching
    if solo then ShadowEngine.beginBatch() end
    local shd = tipShift(feetX)
    if yCut then cutScissor(ay, yCut) end
    fadeFor(ay, (ih - pad - baseH) * s * frame.len * lenK, feetX, iw * s * 0.6)
    love.graphics.setColor(1, 1, 1, 1)
    for pi = 1, #SMEAR do
        love.graphics.draw(img,
            math.floor(feetX + SMEAR[pi][1] * d),
            math.floor(ay + SMEAR[pi][2] * d * 0.5), 0,
            s * 1.18 * (opts.flip or 1),
            -s * frame.len * lenK,
            iw / 2, ih - pad - baseH,
            -shd * 0.78, 0)
    end
    if yCut then love.graphics.setScissor() end
    if solo then ShadowEngine.endBatch() end
    return true
end

local silTint = { 1, 1, 1, 1 }
function ShadowEngine.silhouette(feetX, feetY, opts, drawFn)
    if not ShadowEngine.isActive() then return false end
    opts = opts or NO_OPTS
    local d = opts.smear or 4
    local lenK = opts.lenK or 1
    local ay, baseH, yCut = footprint(opts, feetY, opts.contentH or 0, 1,
        frame.len * lenK, d)
    if not ay then return true end
    local solo = not batching
    if solo then
        soloAlphaK = opts.alphaK
        ShadowEngine.beginBatch()
    end
    local shd = tipShift(feetX)
    local wK = opts.widthK or 1
    if yCut then cutScissor(ay, yCut) end
    fadeFor(ay, (opts.contentH or 0) * frame.len * lenK, nil, nil)
    for pi = 1, #SMEAR do
        love.graphics.push()
        love.graphics.translate(
            math.floor(feetX + SMEAR[pi][1] * d),
            math.floor(ay + SMEAR[pi][2] * d * 0.5))
        love.graphics.shear(shd * 0.78, 0)
        love.graphics.scale(1.18 * wK, -frame.len * lenK)
        if baseH > 0 then love.graphics.translate(0, baseH) end
        love.graphics.setColor(silTint)
        drawFn(silTint)
        love.graphics.pop()
    end
    if yCut then love.graphics.setScissor() end
    if solo then ShadowEngine.endBatch() end
    return true
end

local squeue, squeueN = {}, 0
function ShadowEngine.queue(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    squeueN = squeueN + 1
    ShadowEngine.stats.queued = squeueN
    local q = squeue[squeueN]
    if not q then q = {}; squeue[squeueN] = q end
    q.img, q.x, q.y, q.s, q.o = img, feetX, feetY, s, opts
    local lenPx = img:getHeight() * s * frame.len * ((opts and opts.lenK) or 1)
    local hw = img:getWidth() * s * 0.6 + 6
    local tip = -tipShift(feetX) * 0.78 * lenPx
    local n = SH.bn + 1
    SH.bn = n
    SH.bx0[n] = feetX - hw + math.min(0, tip)
    SH.bx1[n] = feetX + hw + math.max(0, tip)
    SH.by0[n], SH.by1[n] = feetY - 4, feetY + lenPx + 8
    return true
end

local sdone = 0

local function drawPending()
    if sdone >= squeueN then return end
    openCanvas("acc", not frame.bandUsed)
    frame.bandUsed = true
    for i = sdone + 1, squeueN do
        local q = squeue[i]
        ShadowEngine.sprite(q.img, q.x, q.y, q.s, q.o)
        q.img, q.o = nil, nil
    end
    sdone = squeueN
    closeCanvas()
end

function ShadowEngine.commit()
    if not SH.pLo then return end
    drawPending()
    composite(SH.cv.acc, SH.pLo, SH.pHi)
    ShadowEngine.stats.bands = (ShadowEngine.stats.bands or 0) + 1
    SH.pLo, SH.pHi = nil, nil
end

function ShadowEngine.flushBand(tLo, tHi)
    if not ShadowEngine.isActive() then return end
    if not frame.bandUsed and sdone >= squeueN then return end
    if not SH.pLo then SH.pLo = tLo end
    SH.pHi = tHi
end

local function pendingStrip()
    if not frame.clip then return -1e9, 1e9 end
    local W = love.graphics.getDimensions()
    local rLo = frame.R - frame.D * math.max(-1, SH.pLo)
    local rHi = frame.R - frame.D * math.min(4, SH.pHi)
    local half = math.max(frame.cx, W - frame.cx)
    local under = rHi * rHi - half * half
    return frame.cy - rLo, under > 0 and (frame.cy - math.sqrt(under)) or 1e9
end

function ShadowEngine.guard(x0, y0, x1, y1)
    if not SH.pLo then return end
    local sy0, sy1 = pendingStrip()
    if y0 < sy0 then y0 = sy0 end
    if y1 > sy1 then y1 = sy1 end
    if y1 < y0 then return end
    for i = 1, SH.bn do
        if x1 >= SH.bx0[i] and x0 <= SH.bx1[i] and y1 >= SH.by0[i] and y0 <= SH.by1[i] then
            ShadowEngine.commit()
            return
        end
    end
end

function ShadowEngine.endFrame()
    ShadowEngine.commit()
    SH.xMin, SH.xMax = 1e9, -1e9
    SH.bn = 0
    squeueN, sdone = 0, 0
    frame.bandUsed = false
    SH.yMin, SH.yMax = 1e9, -1e9
end

function ShadowEngine.flush()
    if squeueN == 0 then return end
    local wasClip = frame.clip
    frame.clip = false
    frame.bandUsed = false
    drawPending()
    composite(SH.cv.acc, -1e9, 1e9)
    frame.clip = wasClip
    squeueN, sdone = 0, 0
    frame.bandUsed = false
end

return ShadowEngine
