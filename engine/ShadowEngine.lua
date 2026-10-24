local Debug = require("src.core.Debug")
local Contact = require("engine.ContactShadow")

local ShadowEngine = {}

local frame = {
    sunX = 0, w = 1,
    len = 0.5,
    alpha = 0.26,
    stamp = -1,
    alphaK = 1,
    tr = 0.42, tg = 0.42, tb = 0.5,
    cx = 0, cy = 0, R = 1, D = 1, clip = false,
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

local SMEAR = { { 0, 0 } }
local SCALE = 2
ShadowEngine.SCALE = SCALE
ShadowEngine.STEPS = 3
local scratch, batching, batchPrev
local soloAlphaK
local SH = { cv = {}, vT = { 0, 0, 0, 0 }, depth = 1, alpha = 1,
             mq = {}, mn = 0, oq = {}, on = 0, done = {}, odone = {}, mdone = {} }
ShadowEngine.FADE = 0.45
ShadowEngine.SELF_BIAS = 2.5
ShadowEngine.MASK = true

SH.FADE_SRC = [[
uniform float fadeK;
uniform float steps;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 t = Texel(tex, tc);
    float d = floor(clamp(1.0 - tc.y, 0.0, 0.999) * steps) / steps;
    float cov = t.a * color.a * (1.0 - fadeK * color.b * d);
    float on = step(0.004, t.a);
    if (color.g > 0.5) return vec4(0.0, cov, color.r * on, 0.0);
    return vec4(color.r * on, 0.0, 0.0, cov);
}
]]
SH.MASK_SRC = [[
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (Texel(tex, tc).a < 0.5) discard;
    return vec4(color.r, 0.0, 0.0, 1.0);
}
]]
SH.COMP_SRC = [[
uniform Image maskTex;
uniform vec4 tint;
uniform float useMask;
uniform float eps;
uniform float selfBias;
uniform vec2 px;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec4 s = Texel(tex, tc);
    float pa = s.a * tint.a;
    float oa = 0.0;
    if (useMask > 0.5) {
        float m = Texel(maskTex, tc).r;
        float md = max(max(Texel(maskTex, tc + vec2(px.x, 0.0)).r, Texel(maskTex, tc - vec2(px.x, 0.0)).r),
                       max(Texel(maskTex, tc + vec2(0.0, px.y)).r, Texel(maskTex, tc - vec2(0.0, px.y)).r));
        if (max(m, md) > s.r + eps + selfBias) pa = 0.0;
        if (m > s.r + eps) pa = 0.0;
        if (s.g > 0.0 && m > 0.0 && abs(m - s.b) <= eps) oa = s.g;
    }
    float a = 1.0 - (1.0 - pa) * (1.0 - oa);
    return vec4(mix(vec3(1.0), tint.rgb, a), 1.0);
}
]]

local function shaders()
    if SH.ok == nil then
        local ok1, f = pcall(love.graphics.newShader, SH.FADE_SRC)
        local ok2, c = pcall(love.graphics.newShader, SH.COMP_SRC)
        local ok3, m = pcall(love.graphics.newShader, SH.MASK_SRC)
        SH.ok = ok1 and ok2 and ok3
        if SH.ok then
            SH.fade, SH.comp, SH.mask = f, c, m
        else
            Debug.warn("[ShadowEngine] shader de sombra não compilou: "
                .. tostring((not ok1 and f) or (not ok2 and c) or m))
        end
        local fm = love.graphics.getCanvasFormats and love.graphics.getCanvasFormats()
        SH.fmt = (fm and fm.rgba16f) and "rgba16f" or "rgba8"
        SH.eps = (SH.fmt == "rgba16f") and 0.0015 or 0.006
    end
    return SH.ok
end

local function ensureCanvas(key)
    shaders()
    local W, H = love.graphics.getDimensions()
    local cw, ch = math.ceil(W / SCALE), math.ceil(H / SCALE)
    local cv = SH.cv[key]
    if not cv or cv:getWidth() ~= cw or cv:getHeight() ~= ch then
        local fmt = (key == "solo") and "rgba8" or SH.fmt
        cv = love.graphics.newCanvas(cw, ch, { format = fmt })
        cv:setFilter("nearest", "nearest")
        SH.cv[key] = cv
    end
    return cv
end

local function openCanvas(key, shader)
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
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("lighten", "premultiplied")
    love.graphics.scale(1 / SCALE)
    if SH.ok then
        love.graphics.setShader(shader or SH.fade)
        if not shader then
            SH.fade:send("fadeK", ShadowEngine.FADE)
            SH.fade:send("steps", ShadowEngine.STEPS)
        end
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

local function composite(cv, aMul, mask)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setBlendMode("multiply", "premultiplied")
    local prevShader = love.graphics.getShader()
    if SH.ok then
        love.graphics.setShader(SH.comp)
        SH.vT[1], SH.vT[2], SH.vT[3], SH.vT[4] = frame.tr, frame.tg, frame.tb, aMul
        SH.comp:send("tint", SH.vT)
        SH.comp:send("useMask", mask and 1 or 0)
        SH.comp:send("eps", SH.eps)
        SH.comp:send("selfBias", ShadowEngine.SELF_BIAS * SH.eps)
        SH.comp:send("maskTex", mask or cv)
        local cw, ch = cv:getDimensions()
        SH.vP = SH.vP or { 0, 0 }
        SH.vP[1], SH.vP[2] = 1 / cw, 1 / ch
        SH.comp:send("px", SH.vP)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setBlendMode("alpha", "premultiplied")
        love.graphics.setColor(0, 0, 0, aMul)
    end
    love.graphics.draw(cv, 0, 0, 0, SCALE, SCALE)
    love.graphics.setShader(prevShader)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function ShadowEngine.beginBatch()
    if not ShadowEngine.isActive() or batching then return end
    SH.depth, SH.alpha = 1, 1
    openCanvas("solo")
end

function ShadowEngine.endBatch()
    if not batching then return end
    local cv = scratch
    closeCanvas()
    composite(cv, math.min(0.75, frame.alpha * frame.alphaK * (soloAlphaK or 1)), nil)
    soloAlphaK = nil
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

local function measuredFoot(img, ih, pad, opts)
    local fp = Contact.footprint(img)
    if not fp or fp.h ~= ih then return ih - pad, nil end
    local rb = math.min(ih - pad, fp.bottom + 1)
    if opts.measure == false then return rb, nil end
    local prof = opts.baseK or opts.riseK
    local pv = math.min(rb, (prof and fp.pivot or fp.footPivot or fp.pivot) + 0.5)
    if rb - pv < 1 then return rb, nil end
    if prof then return rb, nil, pv end
    return rb, pv
end
ShadowEngine.measuredFoot = measuredFoot

function ShadowEngine.sprite(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    opts = opts or NO_OPTS
    local iw, ih = img:getWidth(), img:getHeight()
    local pad = opts.footPad or 0
    local lenK = opts.lenK or 1
    local d = math.max(1.5, iw * s * 0.035)
    local rb, pv, pvP = measuredFoot(img, ih, pad, opts)
    feetY = feetY + (rb - (ih - pad)) * s
    local ay, baseH, yCut
    if pv then
        ay, baseH, yCut = feetY - (rb - pv) * s, rb - pv, 1e9
    else
        ay, baseH, yCut = footprint(opts, feetY, ih - pad, s,
            frame.len * lenK, d)
        if ay and pvP and yCut and baseH > 0 and rb - pvP <= baseH then
            local up = ay - (feetY - (rb - pvP) * s)
            if up > 0 then ay, yCut, baseH = ay - up, yCut - up, rb - pvP end
        end
    end
    if not ay then return true end
    if Contact.footprint(img) then
        local snap = ay - math.floor(ay / SCALE) * SCALE
        ay = ay - snap
        if yCut then yCut = yCut - snap end
    end
    pad = ih - rb
    local solo = not batching
    if solo then ShadowEngine.beginBatch() end
    local shd = tipShift(feetX)
    if yCut then cutScissor(ay, yCut) end
    love.graphics.setColor(SH.depth, 0, 1, SH.alpha)
    for pi = 1, #SMEAR do
        love.graphics.draw(img,
            math.floor(feetX + SMEAR[pi][1] * d),
            math.floor(ay + SMEAR[pi][2] * d * 0.5), 0,
            s * 1.18 * (opts.flip or 1),
            -s * frame.len * lenK,
            iw / 2, ih - pad - baseH,
            -shd * 0.78 * (opts.flip or 1), 0)
    end
    if yCut then love.graphics.setScissor() end
    if solo then ShadowEngine.endBatch() end
    return true
end

local silTint = { 1, 0, 0, 1 }
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
function ShadowEngine.queue(img, feetX, feetY, s, opts, t)
    if not img or not ShadowEngine.isActive() then return false end
    squeueN = squeueN + 1
    ShadowEngine.stats.queued = squeueN
    local q = squeue[squeueN]
    if not q then q = {}; squeue[squeueN] = q end
    q.img, q.x, q.y, q.s, q.o, q.t = img, feetX, feetY, s, opts, t or 1
    return true
end

function ShadowEngine.mask(img, quad, x, y, r, sx, sy, ox, oy, kx, t)
    if not img or not ShadowEngine.isActive() then return end
    local n = SH.mn + 1
    SH.mn = n
    local e = SH.mq[n]
    if not e then e = {}; SH.mq[n] = e end
    e.img, e.quad, e.x, e.y, e.r = img, quad, x, y, r or 0
    e.sx, e.sy, e.ox, e.oy, e.kx, e.t = sx, sy, ox or 0, oy or 0, kx or 0, t or 1
end

function ShadowEngine.maskRect(x0, y0, x1, y1, t)
    if not ShadowEngine.isActive() then return end
    local n = SH.mn + 1
    SH.mn = n
    local e = SH.mq[n]
    if not e then e = {}; SH.mq[n] = e end
    e.img, e.quad = nil, nil
    e.x, e.y, e.sx, e.sy, e.t = x0, y0, x1 - x0, y1 - y0, t or 1
end

function ShadowEngine.occlude(img, quad, x, y, sx, sy, ox, oy, t, k, down, side)
    if not img or not ShadowEngine.isActive() or (k or 0) <= 0 then return end
    local n = SH.on + 1
    SH.on = n
    local e = SH.oq[n]
    if not e then e = {}; SH.oq[n] = e end
    local h = (quad and select(4, quad:getViewport()) or img:getHeight()) * math.abs(sy)
    local w = img:getWidth() * math.abs(sx)
    local away = tipShift(x)
    e.img, e.quad = img, quad
    e.x = x + (away >= 0 and 1 or -1) * math.min(1, math.abs(away) * 2) * (side or 0) * w
    e.y = y + (down or 0) * h
    e.sx, e.sy, e.ox, e.oy, e.t, e.k = sx, sy, ox, oy, t or 1, k
end

local function drawMask(e)
    love.graphics.setColor(e.t, 0, 0, 1)
    if not e.img then
        love.graphics.rectangle("fill", e.x, e.y, e.sx, e.sy)
    elseif e.quad then
        love.graphics.draw(e.img, e.quad, e.x, e.y, e.r, e.sx, e.sy, e.ox, e.oy, e.kx, 0)
    else
        love.graphics.draw(e.img, e.x, e.y, e.r, e.sx, e.sy, e.ox, e.oy, e.kx, 0)
    end
end

local function drawOcc(e)
    love.graphics.setColor(e.t, 1, 1, e.k)
    if e.quad then
        love.graphics.draw(e.img, e.quad, e.x, e.y, 0, e.sx, e.sy, e.ox, e.oy)
    else
        love.graphics.draw(e.img, e.x, e.y, 0, e.sx, e.sy, e.ox, e.oy)
    end
end

local function grouped(list, n, done, key, fn)
    for i = 1, n do done[i] = false end
    for i = 1, n do
        if not done[i] then
            local k = list[i][key]
            for j = i, n do
                if not done[j] and list[j][key] == k then
                    done[j] = true
                    fn(list[j])
                end
            end
        end
    end
end

local function drawQueued(q)
    SH.depth = q.t - ShadowEngine.SELF_BIAS * (SH.eps or 0.006)
    SH.alpha = math.min(0.75, frame.alpha * frame.alphaK * ((q.o and q.o.alphaK) or 1))
    ShadowEngine.sprite(q.img, q.x, q.y, q.s, q.o)
    q.img, q.o = nil, nil
end

function ShadowEngine.endFrame(extraFn)
    local any = squeueN > 0 or SH.on > 0 or extraFn ~= nil
    if any and ShadowEngine.isActive() then
        openCanvas("acc")
        SH.alpha = math.min(0.75, frame.alpha * frame.alphaK)
        grouped(squeue, squeueN, SH.done, "img", drawQueued)
        grouped(SH.oq, SH.on, SH.odone, "img", drawOcc)
        if extraFn then extraFn() end
        closeCanvas()
        local mask = nil
        if ShadowEngine.MASK and SH.mn > 0 and SH.ok then
            openCanvas("mask", SH.mask)
            grouped(SH.mq, SH.mn, SH.mdone, "img", drawMask)
            closeCanvas()
            mask = SH.cv.mask
        end
        composite(SH.cv.acc, 1, mask)
        ShadowEngine.stats.bands = (ShadowEngine.stats.bands or 0) + 1
    end
    for i = 1, SH.on do SH.oq[i].img, SH.oq[i].quad = nil, nil end
    for i = 1, SH.mn do SH.mq[i].img, SH.mq[i].quad = nil, nil end
    for i = 1, squeueN do squeue[i].img, squeue[i].o = nil, nil end
    squeueN, SH.mn, SH.on = 0, 0, 0
    SH.depth, SH.alpha = 1, 1
end

function ShadowEngine.flush()
    ShadowEngine.endFrame()
end

return ShadowEngine
