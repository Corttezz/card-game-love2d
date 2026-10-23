local Debug = require("src.core.Debug")

local FloatShadow = {}

FloatShadow.ENABLED = true
FloatShadow.DEPTH = 0.20
FloatShadow.DEPTH_W = 0.10
FloatShadow.DEPTH_MAX = 0.24
FloatShadow.MIN_ROWS = 10
FloatShadow.WIDE = 1.06
FloatShadow.ALPHA = 0.74
FloatShadow.GAP = 0.40
FloatShadow.FRONT = 0.35
FloatShadow.BOB_SIZE = 0.07
FloatShadow.BOB_ALPHA = 0.16
FloatShadow.HOVER_SIZE = 1.6
FloatShadow.HIGH_FADE = 2.5
FloatShadow.LIGHT_SHIFT = 0.30
FloatShadow.MASS_POW = 0.35
FloatShadow.ROUND = 0.80
FloatShadow.RAG = 1.4
FloatShadow.CORE_K = 0.55
FloatShadow.CORE_MASS = 0.35
FloatShadow.CORE_ALPHA = 0.50
FloatShadow.FALLBACK_TINT = { 0.22, 0.18, 0.24 }

local S = { cv = nil, cw = 0, ch = 0, tint = { 0, 0, 0, 0 }, last = nil, rec = {} }

S.MASK_SRC = [[
uniform vec2 vRange;
uniform vec4 band;
uniform vec4 shape;
uniform float texelU;
uniform float bend;
vec2 massAt(Image tex, float u) {
    float m = 0.0;
    float low = 0.0;
    for (int i = 0; i < 40; i++) {
        float k = (float(i) + 0.5) / 40.0;
        float on = step(0.5, Texel(tex, vec2(u, mix(vRange.x, vRange.y, k))).a);
        m += on;
        low = max(low, on * k);
    }
    return vec2(m / 40.0, low);
}
float hash(float x) { return fract(sin(x * 12.9898) * 43758.5453); }
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float u = tc.x;
    vec2 a = massAt(tex, u - texelU);
    vec2 b = massAt(tex, u);
    vec2 c = massAt(tex, u + texelU);
    float m = 0.25 * a.x + 0.5 * b.x + 0.25 * c.x;
    float low = max(b.y, 0.5 * (a.y + c.y));
    if (m < shape.w) discard;
    float xn = (sc.x - band.x) / max(band.z, 1.0);
    float lens = sqrt(max(0.0, 1.0 - xn * xn));
    float d = band.w * pow(m, shape.x) * (1.0 - shape.y + shape.y * lens);
    float rag = (hash(floor(sc.x / 3.0)) - 0.5) * shape.z;
    float back = d * 0.8 + rag;
    float front = d * mix(0.30, 1.20, smoothstep(0.45, 1.0, low)) + rag;
    float y = sc.y - (band.y + bend * xn * xn);
    if (y < -back || y > front) discard;
    return vec4(1.0);
}
]]
S.COMP_SRC = [[
uniform vec4 tint;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float m = step(0.5, Texel(tex, tc).a);
    return vec4(mix(vec3(1.0), tint.rgb, tint.a * m), 1.0);
}
]]

local function shaders()
    if S.ok == nil then
        local ok1, m = pcall(love.graphics.newShader, S.MASK_SRC)
        local ok2, c = pcall(love.graphics.newShader, S.COMP_SRC)
        S.ok = ok1 and ok2
        if S.ok then
            S.mask, S.comp = m, c
        else
            Debug.warn("[FloatShadow] shader da sombra de voo não compilou: "
                .. tostring((not ok1 and m) or c))
        end
    end
    return S.ok
end

local function canvasFor(cw, ch)
    if not S.cv or S.cw < cw or S.ch < ch then
        S.cw, S.ch = math.max(cw, S.cw), math.max(ch, S.ch)
        S.cv = love.graphics.newCanvas(S.cw, S.ch)
        S.cv:setFilter("nearest", "nearest")
    end
    return S.cv
end

local function stamp(img, iw, ih, top, bottom, wide, rows, y0, cyRow, halfW, halfD, off, bendRows, massMin)
    S.vR = S.vR or { 0, 0 }
    S.vR[1], S.vR[2] = top / ih, bottom / ih
    S.vBand = S.vBand or { 0, 0, 0, 0 }
    S.vBand[1], S.vBand[2] = math.floor(S.cw / 2) + (off or 0) * wide, y0 + cyRow
    S.vBand[3], S.vBand[4] = halfW, halfD
    S.vShape = S.vShape or { 0, 0, 0, 0 }
    S.vShape[1], S.vShape[2], S.vShape[3], S.vShape[4] = FloatShadow.MASS_POW, FloatShadow.ROUND, FloatShadow.RAG, massMin
    S.mask:send("vRange", S.vR)
    S.mask:send("band", S.vBand)
    S.mask:send("shape", S.vShape)
    S.mask:send("texelU", 1 / iw)
    S.mask:send("bend", bendRows)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(S.cw / 2) - iw * wide / 2, y0, 0, wide, rows / ih)
end

function FloatShadow.breath(liftK, hover, bob)
    local b = 0
    if bob and bob > 0 then b = (liftK - hover) / bob end
    b = math.max(-1.5, math.min(1.5, b))
    local sizeK = (1 - FloatShadow.HOVER_SIZE * math.max(0, liftK))
        * (1 - FloatShadow.BOB_SIZE * b)
    local alphaK = (1 - FloatShadow.BOB_ALPHA * b)
        * math.max(0.25, 1 - FloatShadow.HIGH_FADE * math.max(0, liftK - hover - (bob or 0)))
    return math.max(0.3, sizeK), math.max(0.2, alphaK)
end

function FloatShadow.tint()
    local SE = require("engine.ShadowEngine")
    if SE.isActive() and SE.getTint then return SE.getTint() end
    local SceneGrade = require("engine.SceneGrade")
    if SceneGrade.isActive() then return SceneGrade.shadowTint() end
    local t = FloatShadow.FALLBACK_TINT
    return t[1], t[2], t[3]
end

function FloatShadow.draw(img, o)
    S.last = nil
    if not FloatShadow.ENABLED or not img or not o then return false end
    local fade = o.fade or 1
    if fade <= 0 then return false end
    if not shaders() then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local bottom = ih - (o.footPad or 0)
    local contentH = math.max(1, math.min(bottom, o.contentH or bottom))
    local top = bottom - contentH
    local s = o.scale or 1
    local sizeK, alphaK = FloatShadow.breath(o.liftK or 0, o.hover or 0, o.bob or 0)
    local depth = math.max(FloatShadow.DEPTH, FloatShadow.MIN_ROWS / contentH)
    local contentW = math.max(1, math.min(iw, o.contentW or iw))
    local halfD = math.min(contentH * FloatShadow.DEPTH_MAX, math.max(contentH * depth * 0.5, contentW * FloatShadow.DEPTH_W)) * sizeK
    local wide = FloatShadow.WIDE * sizeK * (o.widthK or 1)
    local halfW = math.max(1, contentW * wide / 2)
    local bendRows = 0
    if o.groundR and o.groundR > 0 then
        local hw = halfW * s
        bendRows = math.min(12, hw * hw / (2 * o.groundR) / s)
    end
    local maxHalfD = contentH * FloatShadow.DEPTH_MAX * 1.25
    local band = math.ceil(2 * maxHalfD + FloatShadow.RAG + 14) + 4
    local cyRow = math.floor(band / 2 - 6)
    local cw = math.ceil(iw * FloatShadow.WIDE * 1.2) + 4
    local cv = canvasFor(cw, band * 2)

    local prevCanvas = love.graphics.getCanvas()
    local prevShader = love.graphics.getShader()
    local bm, am = love.graphics.getBlendMode()
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(S.mask)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    stamp(img, iw, ih, top, bottom, wide, band, 0, cyRow, halfW, halfD, o.contentOff, bendRows, 0.03)
    stamp(img, iw, ih, top, bottom, wide, band, band, cyRow, halfW * 0.85,
        halfD * FloatShadow.CORE_K, o.contentOff, bendRows, FloatShadow.CORE_MASS)
    love.graphics.setCanvas(prevCanvas)
    love.graphics.pop()

    local hoverPx = (o.hover or 0) * ih * s
    local halfDpx = halfD * s
    local cy = o.groundY + FloatShadow.FRONT * halfDpx
    cy = math.max(cy, o.groundY - (1 - FloatShadow.GAP) * hoverPx + halfDpx)
    if o.maxY and cy + halfDpx * 0.9 > o.maxY then
        cy = math.max(o.maxY - halfDpx * 0.9, o.groundY - halfDpx * 0.4)
    end
    local x0 = math.floor(o.x - math.floor(S.cw / 2) * s + 0.5)
    local y0 = math.floor(cy - cyRow * s + 0.5)
    local r, g, b = FloatShadow.tint()
    local a = math.min(0.9, FloatShadow.ALPHA * alphaK * fade * (o.alphaK or 1))
    S.tint[1], S.tint[2], S.tint[3], S.tint[4] = r, g, b, a
    love.graphics.setShader(S.comp)
    S.comp:send("tint", S.tint)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    S.qA = S.qA or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    S.qB = S.qB or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    S.qA:setViewport(0, 0, S.cw, band, S.cw, S.ch)
    S.qB:setViewport(0, band, S.cw, band, S.cw, S.ch)
    love.graphics.draw(cv, S.qA, x0, y0, 0, s, s)
    S.tint[4] = math.min(0.9, FloatShadow.CORE_ALPHA * alphaK * fade * (o.alphaK or 1))
    S.comp:send("tint", S.tint)
    love.graphics.draw(cv, S.qB, x0, y0, 0, s, s)
    love.graphics.setShader(prevShader)
    love.graphics.setBlendMode(bm, am)
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    love.graphics.setColor(1, 1, 1, 1)
    local L = S.rec
    L.x, L.cy, L.halfD, L.w = o.x, cy, halfDpx, halfW * 2 * s
    L.alpha, L.sizeK, L.groundY, L.bend = a, sizeK, o.groundY, bendRows * s
    S.last = L
    return true
end

function FloatShadow.getLast() return S.last end

return FloatShadow
