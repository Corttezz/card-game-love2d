local Debug = require("src.core.Debug")
local Palette = require("src.ui.Palette")
local Ink = require("src.ui.RunJournalInk")
local FontManager = require("src.ui.FontManager")

local B = {}

local hash = Ink.hash

B.INK = Palette.INK
B.RED = Palette.BLOOD
B.SEPIA = Palette.lerp(Palette.INK, Palette.PARCHMENT_DARK, 0.45)
B.FADED = Palette.lerp(Palette.PARCHMENT_DARK, Palette.PARCHMENT, 0.35)
B.WAX = {
    elite = { Palette.STEEL, Palette.lighten(Palette.STEEL, 0.35), Palette.darken(Palette.STEEL, 0.5) },
    miniboss = { Palette.AGED_GOLD_DARK, Palette.AGED_GOLD, Palette.darken(Palette.AGED_GOLD_DARK, 0.5) },
    boss = { Palette.BLOOD, Palette.lighten(Palette.BLOOD, 0.3), Palette.BLOOD_DARK },
}
B.GLYPH = { elite = "elite", miniboss = "mini_boss", boss = "boss" }

local function reduced()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) == true
end
B.reduced = reduced

function B.prewarm()
    Ink.paper(8, 8, 0)
end

function B.paper(w, h, seed)
    return Ink.paper(w, h, seed)
end

function B.frame(x, y, w, h, seed, color, alpha, opts)
    opts = opts or {}
    local wob = opts.wobble or 0.9
    local o = { wobble = wob, weight = opts.weight }
    Ink.line(x, y, x + w, y + (hash(seed, 1) - 0.5) * 2, color, alpha, seed + 1, o)
    Ink.line(x + w, y, x + w + (hash(seed, 2) - 0.5) * 2, y + h, color, alpha, seed + 2, o)
    Ink.line(x + w, y + h, x, y + h + (hash(seed, 3) - 0.5) * 2, color, alpha, seed + 3, o)
    Ink.line(x, y + h, x + (hash(seed, 4) - 0.5) * 2, y, color, alpha, seed + 4, o)
    if opts.overshoot then
        local s = opts.overshoot
        Ink.line(x - s, y, x, y, color, alpha * 0.8, seed + 5, { wobble = 0.3 })
        Ink.line(x + w, y + h, x + w + s, y + h + 1, color, alpha * 0.8, seed + 6, { wobble = 0.3 })
        Ink.line(x + w, y - s, x + w, y, color, alpha * 0.8, seed + 7, { wobble = 0.3 })
        Ink.line(x, y + h, x, y + h + s, color, alpha * 0.8, seed + 8, { wobble = 0.3 })
    end
end

function B.corners(x, y, w, h, color, alpha, seed, len)
    len = len or 8
    local pts = { { x, y, 1, 1 }, { x + w, y, -1, 1 }, { x, y + h, 1, -1 }, { x + w, y + h, -1, -1 } }
    for i, p in ipairs(pts) do
        local cx, cy, sx, sy = p[1], p[2], p[3], p[4]
        Ink.line(cx + sx * 3, cy + sy * 3, cx + sx * len, cy + sy * 3, color, alpha, seed + i * 11, { wobble = 0.3 })
        Ink.line(cx + sx * 3, cy + sy * 3, cx + sx * 3, cy + sy * len, color, alpha, seed + i * 13, { wobble = 0.3 })
        Ink.px(cx + sx * 5, cy + sy * 5, color, alpha, 2, 2)
    end
end

function B.tape(cx, cy, w, h, slant, seed)
    local tw, th = w or 26, h or 9
    local col = Palette.lerp(Palette.PARCHMENT_LIGHT, Palette.PARCHMENT, 0.5)
    local edge = Palette.PARCHMENT_DARK
    for i = 0, tw - 1 do
        local off = math.floor((i - tw / 2) * (slant or 0) + 0.5)
        local top = (hash(seed, i, 1) < 0.25) and 1 or 0
        local bot = (hash(seed, i, 2) < 0.25) and 1 or 0
        Ink.px(cx - tw / 2 + i, cy - th / 2 + off + top, col, 0.92, 1, th - top - bot)
        Ink.px(cx - tw / 2 + i, cy - th / 2 + off + top, edge, 0.7)
        Ink.px(cx - tw / 2 + i, cy + th / 2 + off - bot - 1, edge, 0.7)
        if hash(seed, i, 3) < 0.3 then Ink.px(cx - tw / 2 + i, cy + off, edge, 0.25) end
    end
end

function B.seal(cx, cy, r, tier, seed)
    local w = B.WAX[tier]
    if not w then return end
    local base, hi, dark = w[1], w[2], w[3]
    for yy = -r - 2, r + 2 do
        for xx = -r - 2, r + 2 do
            local a = math.atan2(yy, xx)
            local rr = r + math.sin(a * 5 + hash(seed, 1) * 6) * 1.2 + math.sin(a * 9 + hash(seed, 2) * 6) * 0.8
            local d = math.sqrt(xx * xx + yy * yy)
            if d <= rr then
                local c = base
                if d > rr - 1.5 then
                    c = dark
                elseif xx + yy < -r * 0.6 and d > r * 0.45 then
                    c = hi
                end
                Ink.px(cx + xx, cy + yy, c, 1)
            end
        end
    end
    Ink.ring(cx, cy, math.max(3, r - 4), dark, 0.75, seed + 3)
    local g = B.GLYPH[tier]
    if g then
        local sc = r >= 15 and 2 or 1
        Ink.glyph(g, cx + 1, cy + 1, sc, dark, 0.8, seed)
        Ink.glyph(g, cx, cy, sc, hi, 0.95, seed)
    end
end

function B.shadow(cx, cy, w, alpha)
    local hw = math.max(4, math.floor(w / 2))
    for row = 0, 4 do
        local k = 1 - row * 0.2
        local rw = math.floor(hw * math.sqrt(math.max(0, k)))
        local a = (alpha or 1) * (0.32 - row * 0.05)
        love.graphics.setColor(B.INK[1], B.INK[2], B.INK[3], a)
        love.graphics.rectangle("fill", math.floor(cx - rw), math.floor(cy - 2 + row), rw * 2, 1)
        if row > 0 then
            love.graphics.rectangle("fill", math.floor(cx - rw * 0.8), math.floor(cy - 2 - row), math.floor(rw * 1.6), 1)
        end
    end
end

function B.hatchGround(x, y, w, seed, color, alpha)
    Ink.line(x, y, x + w, y + (hash(seed, 9) - 0.5) * 2, color, alpha, seed, { wobble = 0.6 })
    local n = math.floor(w / 7)
    for i = 1, n do
        local hx = x + i * 7 + math.floor(hash(seed, i) * 3)
        if hash(seed, i, 4) < 0.7 then
            Ink.line(hx, y + 2, hx - 3, y + 5, color, alpha * 0.7, seed + i, { wobble = 0.2 })
        end
    end
end

function B.tally(x, y, n, color, alpha, seed, h)
    h = h or 9
    local cx = x
    local full = math.min(n, 20)
    for i = 1, full do
        local inGroup = (i - 1) % 5
        if inGroup == 4 then
            Ink.line(cx - 19, y + h - 2, cx - 1, y + 1, color, alpha, seed + i, { wobble = 0.3 })
            cx = cx + 6
        else
            Ink.line(cx, y, cx + (hash(seed, i) - 0.5) * 2, y + h, color, alpha, seed + i, { wobble = 0.3, weight = 2 })
            cx = cx + 5
        end
    end
    return cx - x
end

local engraveShader, shaderTried
local ENGRAVE = [[
extern vec3 ink;
extern float strength;
float bayer(vec2 p) {
    vec2 q = mod(floor(p), 4.0);
    float a = mod(q.x + q.y * 2.0, 4.0);
    float b = mod(q.x * 2.0 + q.y * 3.0 + floor(q.y * 0.5), 4.0);
    return (a * 4.0 + b + 0.5) / 16.0;
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 p = Texel(tex, uv);
    float l = dot(p.rgb, vec3(0.299, 0.587, 0.114));
    float d = clamp((0.92 - l) * strength, 0.0, 1.0);
    float ex = min(min(uv.x, 1.0 - uv.x) * 6.0, 1.0);
    float ey = min((1.0 - uv.y) * 8.0, 1.0);
    d = d * ex * ey;
    float lv = floor(d * 4.0 + bayer(sc)) / 4.0;
    return vec4(ink, p.a * lv * color.a);
}
]]

function B.engraveShader()
    if shaderTried then return engraveShader end
    shaderTried = true
    local ok, s = pcall(love.graphics.newShader, ENGRAVE)
    if ok then engraveShader = s else Debug.warn("[BestiaryInk] gravura nao compilou: " .. tostring(s)) end
    return engraveShader
end

local imgCache = {}
function B.image(path)
    local v = imgCache[path]
    if v == nil then
        if love.filesystem.getInfo(path) then
            local ok, img = pcall(love.graphics.newImage, path)
            v = ok and img or false
            if v then v:setFilter("nearest", "nearest") end
        else
            v = false
        end
        if not v then Debug.warn("[BestiaryInk] sem imagem " .. path) end
        imgCache[path] = v
    end
    return v or nil
end

function B.engrave(path, x, y, w, h, alpha, color, strength)
    local img = B.image(path)
    if not img then return false end
    local sh = B.engraveShader()
    local iw, ih = img:getDimensions()
    local s = math.min(w / iw, h / ih)
    local dx = math.floor(x + (w - iw * s) / 2)
    local dy = math.floor(y + (h - ih * s))
    local c = color or B.SEPIA
    if sh then
        love.graphics.setShader(sh)
        sh:send("ink", { c[1], c[2], c[3] })
        sh:send("strength", strength or 1.6)
        love.graphics.setColor(1, 1, 1, alpha or 1)
        love.graphics.draw(img, dx, dy, 0, s, s)
        love.graphics.setShader()
    else
        love.graphics.setColor(c[1], c[2], c[3], (alpha or 1) * 0.35)
        love.graphics.draw(img, dx, dy, 0, s, s)
    end
    return true
end

function B.question(cx, cy, t, size, alpha)
    size = size or 32
    local f = FontManager.getFont(size)
    local wob = reduced() and 0 or math.sin((t or 0) * 1.7) * 0.06
    local bob = reduced() and 0 or math.floor(math.sin((t or 0) * 1.1) * 1.5 + 0.5)
    love.graphics.push()
    love.graphics.translate(math.floor(cx), math.floor(cy) + bob)
    love.graphics.rotate(wob)
    love.graphics.setFont(f)
    local w, h = f:getWidth("?"), f:getHeight()
    love.graphics.setColor(B.SEPIA[1], B.SEPIA[2], B.SEPIA[3], 0.35 * (alpha or 1))
    love.graphics.print("?", -w / 2 + 2, -h / 2 + 2)
    love.graphics.setColor(B.INK[1], B.INK[2], B.INK[3], 0.82 * (alpha or 1))
    love.graphics.print("?", -w / 2, -h / 2)
    love.graphics.pop()
end

function B.alert(cx, cy, t)
    local pulse = reduced() and 1 or (0.75 + 0.25 * math.sin((t or 0) * 3.2))
    local r = 8
    love.graphics.setColor(Palette.PARCHMENT_LIGHT[1], Palette.PARCHMENT_LIGHT[2], Palette.PARCHMENT_LIGHT[3], 0.9)
    love.graphics.circle("fill", math.floor(cx), math.floor(cy), r)
    Ink.begin()
    Ink.ring(math.floor(cx), math.floor(cy), r, B.RED, pulse, 77, 2)
    Ink.flush()
    local f = FontManager.getFont(8)
    love.graphics.setFont(f)
    love.graphics.setColor(B.RED[1], B.RED[2], B.RED[3], pulse)
    love.graphics.print("!", math.floor(cx - f:getWidth("!") / 2) + 1, math.floor(cy - f:getHeight() / 2) + 1)
end

function B.splash(cx, cy, seed)
    local list = {}
    for i = 1, 28 do
        local a = hash(seed, i, 1) * 6.2832
        local sp = 40 + hash(seed, i, 2) * 140
        list[i] = { x = cx, y = cy, vx = math.cos(a) * sp, vy = math.sin(a) * sp * 0.6 - 20,
            life = 0.35 + hash(seed, i, 3) * 0.45, t = 0, size = 1 + math.floor(hash(seed, i, 4) * 3),
            dust = hash(seed, i, 5) < 0.4 }
    end
    return list
end

function B.updateSplash(list, dt)
    if not list then return nil end
    local alive = false
    for _, p in ipairs(list) do
        if p.t < p.life then
            p.t = p.t + dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * (1 - 3 * dt)
            p.vy = p.vy * (1 - 3 * dt) + (p.dust and -10 or 40) * dt
            alive = true
        end
    end
    return alive and list or nil
end

function B.drawSplash(list)
    if not list then return end
    for _, p in ipairs(list) do
        if p.t < p.life then
            local a = 1 - p.t / p.life
            local c = p.dust and Palette.PARCHMENT_LIGHT or B.INK
            love.graphics.setColor(c[1], c[2], c[3], a * (p.dust and 0.7 or 0.85))
            love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
        end
    end
end

return B
