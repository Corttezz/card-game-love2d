local Debug = require("src.core.Debug")
local QuadMesh = require("engine.QuadMesh")
local ffi = require("ffi")

local ContactShadow = {}

ContactShadow.stats = { contacts = 0, scorch = 0, quads = 0 }

local foot = setmetatable({}, { __mode = "k" })
local warned = setmetatable({}, { __mode = "k" })
local frame = { alpha = 0.55, height = 0.035, spread = 1.08, dither = true,
                r = 0.2, g = 0.15, b = 0.25 }
local queue, qn = {}, 0
local qm

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

local function band(q, fp)
    local s, fl = q.s, q.flip
    local hpx = math.max(1, math.floor(frame.height * fp.w * s * (0.55 + 0.45 * q.t) + 0.5))
    local a = frame.alpha * q.a * (0.6 + 0.4 * q.t)
    local r, g, b = frame.r * 0.35, frame.g * 0.35, frame.b * 0.35
    local u = unit()
    local y0 = math.floor(q.y)
    local h2 = math.max(1, math.floor(hpx * 0.5 + 0.5))
    for i = 1, #fp.spans do
        local sp = fp.spans[i]
        local cxs = (sp[1] + sp[2] + 1) * 0.5 - fp.w * 0.5
        local wd = math.max(1, math.floor((sp[2] - sp[1] + 1) * frame.spread * s + 0.5))
        local x0 = math.floor(q.x + fl * cxs * s - wd * 0.5)
        qm:rect(x0, y0, wd, hpx, 0, 0, 1, 1, r, g, b, a)
        local inset = math.floor(wd * (0.12 + 0.10 * hash01(sp[1] * 3.1 + sp[2])) + 0.5)
        local w2 = wd - 2 * inset
        if w2 >= 1 then
            qm:rect(x0 + inset, y0 + hpx, w2, h2, 0, 0, 1, 1, r, g, b, a * 0.55)
        end
        if frame.dither and wd > 3 * u then
            qm:rect(x0 - u, y0, u, math.max(1, hpx - u), 0, 0, 1, 1, r, g, b, a * 0.45)
            qm:rect(x0 + wd, y0, u, math.max(1, hpx - u), 0, 0, 1, 1, r, g, b, a * 0.45)
        end
    end
end

function ContactShadow.flush()
    if qn == 0 then return end
    qm = qm or QuadMesh.new(2048)
    qm:reset()
    for i = 1, qn do
        local q = queue[i]
        local fp = foot[q.img]
        if fp then band(q, fp) end
        q.img = nil
    end
    qn = 0
    if qm.n > 0 then
        qm:upload(0, qm.n)
        love.graphics.setColor(1, 1, 1, 1)
        qm:draw(0, qm.n)
    end
    ContactShadow.stats.quads = qm.n
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
