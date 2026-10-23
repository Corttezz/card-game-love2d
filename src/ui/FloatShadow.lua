local Debug = require("src.core.Debug")

local FloatShadow = {}

FloatShadow.ENABLED = true
FloatShadow.FLAT = 0.12
FloatShadow.MIN_ROWS = 8
FloatShadow.WIDE = 1.06
FloatShadow.ALPHA = 0.72
FloatShadow.BACK = 0.55
FloatShadow.BOB_SIZE = 0.07
FloatShadow.BOB_ALPHA = 0.16
FloatShadow.HOVER_SIZE = 1.6
FloatShadow.HIGH_FADE = 2.5
FloatShadow.LIGHT_SHIFT = 0.30
FloatShadow.PASSES = 4
FloatShadow.TAPER = 0.65
FloatShadow.CORE_W = 0.62
FloatShadow.CORE_H = 0.62
FloatShadow.CORE_ALPHA = 0.50
FloatShadow.FALLBACK_TINT = { 0.22, 0.18, 0.24 }

local S = { cv = nil, cw = 0, ch = 0, tint = { 0, 0, 0, 0 }, last = nil, rec = {} }

S.MASK_SRC = [[
uniform vec4 band;
uniform float taper;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (Texel(tex, tc).a < 0.5) discard;
    float v = clamp((sc.y - band.y) / max(band.w, 1.0), 0.0, 1.0) * 2.0 - 1.0;
    float lens = sqrt(max(0.0, 1.0 - v * v));
    if (abs(sc.x - band.x) > band.z * (1.0 - taper + taper * lens)) discard;
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

local function stamp(img, iw, top, wx, ky, y0, contentW, contentH, off)
    S.vBand = S.vBand or { 0, 0, 0, 0 }
    S.vBand[1], S.vBand[2] = math.floor(S.cw / 2) + (off or 0) * wx, y0
    S.vBand[3], S.vBand[4] = math.max(1, contentW * wx / 2 + 0.5), math.max(1, contentH * ky)
    S.mask:send("band", S.vBand)
    S.mask:send("taper", FloatShadow.TAPER)
    local n = math.max(1, math.min(FloatShadow.PASSES, math.ceil(1 / math.max(ky, 1e-3) / 1.5)))
    for j = 0, n - 1 do
        love.graphics.push()
        love.graphics.translate(math.floor(S.cw / 2), y0)
        love.graphics.scale(wx, ky)
        love.graphics.draw(img, -iw / 2, -top - j / (n * ky))
        love.graphics.pop()
    end
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
    local sizeK, alphaK = FloatShadow.breath(o.liftK or 0, o.hover or 0, o.bob or 0)
    local flat = math.max(FloatShadow.FLAT, FloatShadow.MIN_ROWS / contentH)
    local k = flat * sizeK
    local wide = FloatShadow.WIDE * sizeK * (o.widthK or 1)
    local cw = math.ceil(iw * FloatShadow.WIDE * 1.2) + 4
    local ch = 2 * (math.ceil(contentH * flat * 1.2) + 4)
    local cv = canvasFor(cw, ch)

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
    love.graphics.setColor(1, 1, 1, 1)
    local half = math.ceil(contentH * flat * 1.2) + 4
    local contentW = math.max(1, math.min(iw, o.contentW or iw))
    stamp(img, iw, top, wide, k, 1, contentW, contentH, o.contentOff)
    local ck = k * FloatShadow.CORE_H
    local coreY = 1 + math.floor((contentH * k - contentH * ck) / 2 + 0.5)
    stamp(img, iw, top, wide * FloatShadow.CORE_W, ck, half + coreY, contentW, contentH, o.contentOff)
    love.graphics.setCanvas(prevCanvas)
    love.graphics.pop()

    local s = o.scale or 1
    local rows = contentH * k
    local Hs = rows * s
    local x0 = math.floor(o.x - math.floor(S.cw / 2) * s + 0.5)
    local y0 = math.floor(o.groundY - FloatShadow.BACK * Hs - s + 0.5)
    local r, g, b = FloatShadow.tint()
    local a = math.min(0.9, FloatShadow.ALPHA * alphaK * fade * (o.alphaK or 1))
    S.tint[1], S.tint[2], S.tint[3], S.tint[4] = r, g, b, a
    love.graphics.setShader(S.comp)
    S.comp:send("tint", S.tint)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    S.qA = S.qA or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    S.qB = S.qB or love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    S.qA:setViewport(0, 0, S.cw, half, S.cw, S.ch)
    S.qB:setViewport(0, half, S.cw, half, S.cw, S.ch)
    love.graphics.draw(cv, S.qA, x0, y0, 0, s, s)
    S.tint[4] = math.min(0.9, FloatShadow.CORE_ALPHA * alphaK * fade * (o.alphaK or 1))
    S.comp:send("tint", S.tint)
    love.graphics.draw(cv, S.qB, x0, y0, 0, s, s)
    love.graphics.setShader(prevShader)
    love.graphics.setBlendMode(bm, am)
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    love.graphics.setColor(1, 1, 1, 1)
    local L = S.rec
    L.x, L.y0, L.h, L.w = o.x, y0, math.ceil(rows + 2) * s, iw * wide * s
    L.alpha, L.sizeK, L.groundY = a, sizeK, o.groundY
    S.last = L
    return true
end

function FloatShadow.getLast() return S.last end

return FloatShadow
