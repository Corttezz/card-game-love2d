local Debug = require("src.core.Debug")

local LightSpill = {}

LightSpill.MAX = 8
LightSpill.TIP = { root = 0.85, tip = 1.30 }
LightSpill.GAIN = 1.0
LightSpill.on = true

local P, C = {}, {}
for i = 1, LightSpill.MAX do P[i] = { 0, 0, 1, 1 }; C[i] = { 0, 0, 0, 1 } end
local S = { n = 0, ver = 0, sent = setmetatable({}, { __mode = "k" }), tip = { 0.85, 1.30 } }

LightSpill.GLSL = [[
uniform vec4 uSpP[8];
uniform vec4 uSpC[8];
uniform float uSpN;
uniform vec2 uSpTip;
vec3 lightSpill(vec2 sc, float v) {
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        if (float(i) >= uSpN) break;
        vec4 lp = uSpP[i];
        vec2 p = (sc - lp.xy) / lp.zw;
        if (p.y < 0.0) p.y = p.y * max(uSpC[i].w, 1.0);
        float d2 = dot(p, p);
        if (d2 < 1.0) {
            float a = atan(p.y, p.x + 1e-5);
            float w = 1.0 + 0.10 * (0.55 + 0.25 * sin(3.0 * a + 1.3) + 0.12 * sin(5.0 * a + 4.1) + 0.08 * sin(9.0 * a + 2.2));
            float f = clamp(1.0 - d2 * w * w, 0.0, 1.0);
            acc += uSpC[i].rgb * (f * f);
        }
    }
    return acc * mix(uSpTip.y, uSpTip.x, clamp(v, 0.0, 1.0));
}
]]

LightSpill.SPRITE_PIXEL = LightSpill.GLSL .. [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv) * color;
    c.rgb += lightSpill(sc, uv.y) * step(0.001, c.a);
    return c;
}
]]

function LightSpill.beginFrame()
    S.n = 0
    S.ver = S.ver + 1
end

function LightSpill.count() return S.n end

function LightSpill.add(gx, gy, r, sy, upK, cr, cg, cb)
    if not LightSpill.on or S.n >= LightSpill.MAX or r < 2 then return end
    local k = LightSpill.GAIN
    if cr * k < 0.004 and cg * k < 0.004 and cb * k < 0.004 then return end
    local x0, y0 = love.graphics.transformPoint(gx, gy)
    local x1 = love.graphics.transformPoint(gx + 100, gy)
    local sk = math.abs(x1 - x0) / 100
    S.n = S.n + 1
    local p, c = P[S.n], C[S.n]
    p[1], p[2], p[3], p[4] = x0, y0, r * sk, r * (sy or 0.35) * sk
    c[1], c[2], c[3], c[4] = cr * k, cg * k, cb * k, upK or 1
    S.ver = S.ver + 1
end

function LightSpill.at(i)
    return P[i], C[i]
end

function LightSpill.apply(sh)
    if not sh then return end
    if S.sent[sh] == S.ver then return end
    S.sent[sh] = S.ver
    local n = S.n
    sh:send("uSpN", n)
    if n > 0 then
        S.tip[1], S.tip[2] = LightSpill.TIP.root, LightSpill.TIP.tip
        sh:send("uSpTip", S.tip)
        sh:send("uSpP", unpack(P, 1, n))
        sh:send("uSpC", unpack(C, 1, n))
    end
end

local sprite = { ok = nil, sh = nil }
function LightSpill.spriteShader()
    if S.n == 0 then return nil end
    if sprite.ok == nil then
        local ok, sh = pcall(love.graphics.newShader, LightSpill.SPRITE_PIXEL)
        sprite.ok = ok and sh and true or false
        sprite.sh = sprite.ok and sh or nil
        if not sprite.ok then Debug.warn("[LightSpill] shader de sprite falhou: " .. tostring(sh)) end
    end
    if not sprite.sh then return nil end
    LightSpill.apply(sprite.sh)
    return sprite.sh
end

function LightSpill.reaches(x, y, halfW, h)
    if S.n == 0 then return false end
    local x0, y0 = love.graphics.transformPoint(x - halfW, y - h)
    local x1, y1 = love.graphics.transformPoint(x + halfW, y)
    for i = 1, S.n do
        local p = P[i]
        local up = C[i][4]
        if x1 >= p[1] - p[3] and x0 <= p[1] + p[3]
           and y1 >= p[2] - p[4] / math.max(1, up) and y0 <= p[2] + p[4] then
            return true
        end
    end
    return false
end

return LightSpill
