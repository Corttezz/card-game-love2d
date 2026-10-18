local Debug = require("src.core.Debug")
local ffi = require("ffi")

local ContactShadow = {}

ContactShadow.stats = { contacts = 0, scorch = 0, quads = 0 }

local foot = setmetatable({}, { __mode = "k" })
local warned = setmetatable({}, { __mode = "k" })
local frame = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true,
                r = 0.2, g = 0.15, b = 0.25 }
local queue, qn = {}, 0
local discs, dn = {}, 0
local clip = { on = false, cx = 0, cy = 0, R = 1, D = 1, vC = { 0, 0 }, vB = { 0, 0 }, pLo = nil, pHi = nil }
local CLIP_SRC = [[
uniform vec2 C;
uniform float R;
uniform float D;
uniform vec2 band;
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float t = (R - distance(sc, C)) / D;
    if (t < band.x || t >= band.y) discard;
    return Texel(tex, tc) * color;
}
]]
local clipShader

local function rect(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y, w, h)
end

function ContactShadow.setClip(cx, cy, R, D)
    clip.on, clip.cx, clip.cy, clip.R, clip.D = true, cx, cy, R, math.max(1, D)
end

local function tAt(x, y)
    local dx, dy = x - clip.cx, y - clip.cy
    return (clip.R - math.sqrt(dx * dx + dy * dy)) / clip.D
end

local function hash01(n)
    local v = math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - math.floor(v)
end

function ContactShadow.scan(img, data)
    local hit = foot[img]
    if hit ~= nil then return hit or nil end
    if not data then foot[img] = false; return nil end
    local w, h = data:getWidth(), data:getHeight()
    local px = data:getFormat() == "rgba8"
        and ffi.cast("const uint8_t*", data:getFFIPointer()) or nil
    local low = {}
    local maxRow = -1
    for x = 0, w - 1 do
        local lr = -1
        for y = h - 1, 0, -1 do
            local opaque
            if px then
                opaque = px[(y * w + x) * 4 + 3] >= 153
            else
                local _, _, _, a = data:getPixel(x, y)
                opaque = a >= 0.6
            end
            if opaque then lr = y; break end
        end
        low[x] = lr
        if lr > maxRow then maxRow = lr end
    end
    if maxRow < 0 then foot[img] = false; return nil end
    local spans = {}
    local a = nil
    for x = 0, w - 1 do
        local touch = low[x] >= 0 and low[x] >= maxRow - 1
        if touch and not a then a = x end
        if not touch and a then
            spans[#spans + 1] = { a, x - 1 }
            a = nil
        end
    end
    if a then spans[#spans + 1] = { a, w - 1 } end
    local fp = { spans = spans, bottom = maxRow, w = w, h = h }
    foot[img] = fp
    return fp
end

function ContactShadow.footprint(img)
    local f = foot[img]
    return f or nil
end

function ContactShadow.setFrame(cfg, r, g, b)
    if cfg then
        frame.alpha = cfg.alpha or frame.alpha
        frame.height = cfg.height or frame.height
        frame.spread = cfg.spread or frame.spread
        frame.dither = cfg.dither ~= false
    end
    frame.r, frame.g, frame.b = r or frame.r, g or frame.g, b or frame.b
    ContactShadow.stats.contacts, ContactShadow.stats.scorch = 0, 0
end

function ContactShadow.queue(img, x, y, s, t, alpha, flip)
    local fp = foot[img]
    if not fp then
        if fp == nil and not warned[img] then
            warned[img] = true
            Debug.warn("[ContactShadow] imagem sem pegada medida (scan não rodou): sem faixa de contato")
        end
        return false
    end
    qn = qn + 1
    local q = queue[qn]
    if not q then q = {}; queue[qn] = q end
    q.img, q.x, q.y, q.s, q.t = img, x, y, s, t or 1
    q.a, q.flip = alpha or 1, flip or 1
    ContactShadow.stats.contacts = ContactShadow.stats.contacts + 1
    return true
end

function ContactShadow.queued() return qn end

local function unit()
    local _, H = love.graphics.getDimensions()
    return math.max(1, math.floor(H / 250 + 0.5))
end

function ContactShadow.queueDisc(x, y, rx, ry, alpha)
    if rx ~= rx or ry ~= ry or rx < 1 or ry < 1 then return end
    dn = dn + 1
    local d = discs[dn]
    if not d then d = {}; discs[dn] = d end
    d.x, d.y, d.rx, d.ry, d.a = x, y, rx, ry, alpha or 0.4
end

local function disc(d)
    local u = unit()
    local r, g, b = frame.r * 0.35, frame.g * 0.35, frame.b * 0.35
    local rows = math.max(1, math.floor(d.ry / u))
    for row = -rows, rows do
        local f = row / (rows + 0.5)
        local ff = 1 - f * f
        local half = d.rx * math.sqrt(math.max(0, ff))
        half = half * (0.9 + 0.1 * hash01(d.x * 0.13 + row * 7.3))
        local wd = math.floor(half * 2 + 0.5)
        if wd >= 1 then
            rect(math.floor(d.x - half), math.floor(d.y + row * u), wd, u,
                r, g, b, d.a * (ff ^ 0.7))
        end
    end
end


local function band(q, fp)
    local s, fl = q.s, q.flip
    local hpx = math.max(1, math.floor(frame.height * fp.w * s * (0.55 + 0.45 * q.t) + 0.5))
    local a = frame.alpha * q.a * (0.6 + 0.4 * q.t)
    local r, g, b = frame.r * 0.35, frame.g * 0.35, frame.b * 0.35
    local u = unit()
    local y0 = math.floor(q.y)
    for i = 1, #fp.spans do
        local sp = fp.spans[i]
        local cxs = (sp[1] + sp[2] + 1) * 0.5 - fp.w * 0.5
        local wd = math.max(1, math.floor((sp[2] - sp[1] + 1) * frame.spread * s + 0.5))
        local x0 = math.floor(q.x + fl * cxs * s - wd * 0.5)
        local hs = math.max(1, math.min(hpx, math.floor(wd * 0.35 + 0.5)))
        local h2s = math.max(1, math.floor(hs * 0.5 + 0.5))
        rect(x0, y0, wd, hs, r, g, b, a)
        local inset = math.floor(wd * (0.12 + 0.10 * hash01(sp[1] * 3.1 + sp[2])) + 0.5)
        local w2 = wd - 2 * inset
        if w2 >= 1 then
            rect(x0 + inset, y0 + hs, w2, h2s, r, g, b, a * 0.55)
        end
        if frame.dither and wd > 3 * u then
            rect(x0 - u, y0, u, math.max(1, hs - u), r, g, b, a * 0.45)
            rect(x0 + wd, y0, u, math.max(1, hs - u), r, g, b, a * 0.45)
        end
    end
end

local function drawAll(tLo, tHi)
    local any = false
    for i = 1, dn do
        local d = discs[i]
        if not tLo or (tAt(d.x, d.y + d.ry) >= tLo and tAt(d.x, d.y - d.ry) < tHi) then
            disc(d)
            any = true
        end
    end
    for i = 1, qn do
        local q = queue[i]
        local fp = foot[q.img]
        if fp then
            local reach = frame.height * fp.w * q.s * 2 + 4
            if not tLo or (tAt(q.x, q.y + reach) >= tLo and tAt(q.x, q.y) < tHi) then
                band(q, fp)
                any = true
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return any
end

local function drawBand(tLo, tHi)
    if (qn == 0 and dn == 0) or not clip.on then return end
    if clipShader == nil then
        local ok, sh = pcall(love.graphics.newShader, CLIP_SRC)
        clipShader = ok and sh or false
        if not ok then Debug.warn("[ContactShadow] shader de recorte não compilou: " .. tostring(sh)) end
    end
    if not clipShader then return end
    local hit = false
    for i = 1, dn do
        local d = discs[i]
        if tAt(d.x, d.y + d.ry) >= tLo and tAt(d.x, d.y - d.ry) < tHi then hit = true; break end
    end
    if not hit then
        for i = 1, qn do
            local q = queue[i]
            local fp = foot[q.img]
            if fp and tAt(q.x, q.y + frame.height * fp.w * q.s * 2 + 4) >= tLo and tAt(q.x, q.y) < tHi then
                hit = true
                break
            end
        end
    end
    if not hit then return end
    local prev = love.graphics.getShader()
    love.graphics.setShader(clipShader)
    clip.vC[1], clip.vC[2] = clip.cx, clip.cy
    clipShader:send("C", clip.vC)
    clipShader:send("R", clip.R)
    clipShader:send("D", clip.D)
    clip.vB[1], clip.vB[2] = tLo, tHi
    clipShader:send("band", clip.vB)
    drawAll(tLo, tHi)
    love.graphics.setShader(prev)
end

function ContactShadow.flushBand(tLo, tHi)
    if not clip.on then return end
    if not clip.pLo then clip.pLo = tLo end
    clip.pHi = tHi
end

function ContactShadow.commit()
    if not clip.pLo then return end
    drawBand(clip.pLo, clip.pHi)
    clip.pLo, clip.pHi = nil, nil
end

function ContactShadow.guard(x0, y0, x1, y1)
    if not clip.pLo then return end
    for i = 1, qn do
        local q = queue[i]
        if q.x >= x0 - 60 and q.x <= x1 + 60 and q.y >= y0 and q.y <= y1 + 30 then
            ContactShadow.commit()
            return
        end
    end
    for i = 1, dn do
        local d = discs[i]
        if d.x + d.rx >= x0 and d.x - d.rx <= x1 and d.y + d.ry >= y0 and d.y - d.ry <= y1 then
            ContactShadow.commit()
            return
        end
    end
end

function ContactShadow.endFrame()
    ContactShadow.commit()
    for i = 1, qn do queue[i].img = nil end
    qn, dn = 0, 0
    clip.on = false
end

function ContactShadow.flush()
    if qn == 0 and dn == 0 then return end
    local n0 = qn
    drawAll(nil, nil)
    for i = 1, qn do queue[i].img = nil end
    qn, dn = 0, 0
    ContactShadow.stats.quads = n0
end

function ContactShadow.scorch(x, y, wPx, t, radiusK, alpha)
    local rx = math.max(2, (wPx or 2) * 0.5 * (radiusK or 1))
    local ry = math.max(1, rx * 0.38 * (0.55 + 0.45 * (t or 1)))
    local u = unit()
    local r, g, b = frame.r * 0.22, frame.g * 0.18, frame.b * 0.20
    local seed = math.floor(x * 0.37 + y * 1.91)
    local rows = math.max(1, math.floor(ry / u))
    local a0 = alpha or 0.5
    for row = -rows, rows do
        local f = row / (rows + 0.5)
        local ff = 1 - f * f
        local half = rx * math.sqrt(math.max(0, ff))
        half = half * (0.88 + 0.12 * hash01(seed + row * 7.3))
        local yy = math.floor(y + row * u)
        local a = a0 * (ff ^ 0.6)
        local xl = math.floor(x - half)
        local wd = math.max(1, math.floor(half * 2 + 0.5))
        love.graphics.setColor(r, g, b, a)
        love.graphics.rectangle("fill", xl, yy, wd, u)
        if half > 2 * u then
            local nl = (hash01(seed + row * 3.7) < 0.5) and 1 or 2
            local nr = (hash01(seed + row * 5.9) < 0.5) and 1 or 2
            love.graphics.setColor(r, g, b, a * 0.4)
            love.graphics.rectangle("fill", xl - nl * u, yy, nl * u, u)
            love.graphics.rectangle("fill", xl + wd, yy, nr * u, u)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    ContactShadow.stats.scorch = ContactShadow.stats.scorch + 1
end

return ContactShadow
