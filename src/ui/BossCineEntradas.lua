-- Passos extras das entradas de chefe (Lich da Torre e Tirano do Abismo).
-- Vive à parte do BossCinematic: ele liga a API com Ent.bind e chama enter/update/draw.
local InteriorFX = require("src.ui.InteriorFX")

local Ent = {}

Ent.KINDS = { snuff = true, moon = true, sigil = true, tomb = true, glass = true, wisps = true,
              skull_wake = true, erupt = true, rumble = true, drop = true,
              frostrim = true, heart_wake = true, bog = true, bog_rise = true,
              heart_glow = true, cocoon = true, sap_drop = true, sap_grow = true }

local A = nil
local E = {}
local bits = {}
local splashes = {}
local imgs = {}
local hallImgs = {}
local lightShader, shaderTried = nil, false
local lightQuad = nil

local FADE = 1.2
local ICE    = { 0.62, 0.86, 1.00 }
local ICE_HI = { 0.90, 0.97, 1.00 }
local VIOLET = { 0.66, 0.48, 1.00 }
local WARM   = { 1.00, 0.74, 0.40 }
local LAVA   = { 1.00, 0.46, 0.12 }
local LAVA_HI = { 1.00, 0.86, 0.42 }
local GREEN   = { 0.50, 1.00, 0.32 }
local SAP     = { 0.80, 1.00, 0.50 }
local BARK    = { 0.15, 0.11, 0.07 }
local BARK_HI = { 0.32, 0.26, 0.14 }
local MUD     = { 0.22, 0.19, 0.10 }
local MONARCH = "assets/sprites/characters/enemies/winter_monarch/"
local lastW, lastH = 960, 540
local dataCache = {}

function Ent.bind(api) A = api end

local function clamp01(x) return math.max(0, math.min(1, x)) end
local function lerp(a, b, k) return a + (b - a) * k end
local function smooth(k) return k * k * (3 - 2 * k) end
local function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function rnd(a, b) return a + love.math.random() * (b - a) end
local function shake(i, d)
    if _G.triggerShake and not A.reduced() then _G.triggerShake(i, d) end
end

local function H(hx, hy)
    local st = A.stage()
    local tr = st and st.tr
    if not tr then return hx, hy end
    return tr.ox + hx * tr.scale, tr.oy + hy * tr.scale
end
local function hs()
    local st = A.stage()
    return (st and st.tr and st.tr.scale) or 2
end

local function image(name)
    local id = A.bossId()
    local path = name:find("/", 1, true) and name
        or ("assets/sprites/characters/enemies/" .. tostring(id) .. "/entrance/" .. name .. ".png")
    if imgs[path] == nil then
        if love.filesystem.getInfo(path) then
            local im = love.graphics.newImage(path)
            im:setFilter("nearest", "nearest")
            imgs[path] = im
        else
            require("src.core.Debug").warn("[BossCineEntradas] sem sprite " .. path .. " — só brilho")
            imgs[path] = false
        end
    end
    return imgs[path] or nil
end

local function hallImage(hall)
    if hallImgs[hall] == nil then
        local p = "assets/sprites/scenes/castle_hall_" .. tostring(hall) .. ".png"
        if love.filesystem.getInfo(p) then
            local im = love.graphics.newImage(p)
            im:setFilter("nearest", "nearest")
            hallImgs[hall] = im
        else
            hallImgs[hall] = false
        end
    end
    return hallImgs[hall] or nil
end

-- Luz que "fura" a escuridão: redesenha um pedaço do salão numa elipse,
-- em degraus com dither 2x2 no pixel da arte (sem gradiente liso, sem retângulo).
local LIGHT_GLSL = [[
extern vec2 tex;
extern vec4 ell;
extern float steps;
vec4 effect(vec4 col, Image t, vec2 uv, vec2 sc) {
    vec2 hp = floor(uv * tex);
    vec2 d = (hp + 0.5 - ell.xy) / ell.zw;
    float q = 1.0 - dot(d, d);
    if (q <= 0.0) discard;
    float x2 = mod(hp.x, 2.0);
    float y2 = mod(hp.y, 2.0);
    float b = (2.0 * x2 + 3.0 * y2 - 4.0 * x2 * y2) / 4.0;
    float k = clamp(floor(q * steps + b) / steps, 0.0, 1.0);
    vec4 c = Texel(t, uv);
    return vec4(c.rgb * col.rgb, c.a * col.a * k);
}
]]
local function ensureShader()
    if shaderTried then return lightShader end
    shaderTried = true
    local ok, sh = pcall(love.graphics.newShader, LIGHT_GLSL)
    if ok then lightShader = sh else
        require("src.core.Debug").warn("[BossCineEntradas] shader de luz falhou: " .. tostring(sh))
    end
    return lightShader
end

local function reveal(cx, cy, rx, ry, a, tint, z)
    if a <= 0.01 then return end
    local st = A.stage()
    local tr = st and st.tr
    local img = st and hallImage(st.hall)
    tint = tint or { 1, 1, 1 }
    local sh = ensureShader()
    if not (img and tr and sh) then
        local x, y = H(cx, cy)
        A.glowBlob(x, y, rx * 2 * hs(), ry * 2 * hs(), tint, a * 0.35, 1)
        return
    end
    local iw, ih = img:getDimensions()
    local x0, y0 = math.max(0, math.floor(cx - rx)), math.max(0, math.floor(cy - ry))
    local x1, y1 = math.min(iw, math.ceil(cx + rx)), math.min(ih, math.ceil(cy + ry))
    if x1 <= x0 or y1 <= y0 then return end
    lightQuad = lightQuad or love.graphics.newQuad(0, 0, 1, 1, iw, ih)
    lightQuad:setViewport(x0, y0, x1 - x0, y1 - y0, iw, ih)
    love.graphics.setShader(sh)
    sh:send("tex", { iw, ih })
    sh:send("ell", { cx, cy, rx, ry })
    sh:send("steps", 4)
    love.graphics.setColor(tint[1], tint[2], tint[3], math.min(1, a))
    z = z or 1
    love.graphics.draw(img, lightQuad, tr.ox + (cx + (x0 - cx) * z) * tr.scale, tr.oy + (cy + (y0 - cy) * z) * tr.scale,
        0, tr.scale * z, tr.scale * z)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

local function feet()
    local st = A.stage()
    if not (st and st.bbox) then return nil end
    local _, _, s = A.footInfo()
    return st.bbox.cx, (st.cy or st.bbox.bottomY), s or hs(), st.bbox
end

local function fadeK(e)
    if not e or not e.fade then return 1 end
    return 1 - clamp01(e.fade / (e.fadeDur or FADE))
end

local function startFade(e, dur)
    if e and not e.fade then e.fade = 0; e.fadeDur = dur or FADE end
end

-- Pedaços de sprite que voam (gelo do túmulo, vitral, rochas).
local function addBit(b)
    b.rot = b.rot or 0
    b.rv = b.rv or 0
    b.life = b.life or 1.2
    b.max = b.life
    b.g = b.g or 700
    b.grow = b.grow or 0
    b.k = 1
    bits[#bits + 1] = b
end

local function shatterImage(img, cx, bottomY, s, cell, speed, opts)
    opts = opts or {}
    local iw, ih = img:getDimensions()
    local x0, y0 = cx - iw * s / 2, bottomY - ih * s
    local data = opts.data
    for gy = 0, ih - 1, cell do
        for gx = 0, iw - 1, cell do
            local w, h = math.min(cell, iw - gx), math.min(cell, ih - gy)
            local keep = true
            if data then
                local px_, py_ = math.min(iw - 1, gx + math.floor(w / 2)), math.min(ih - 1, gy + math.floor(h / 2))
                local _, _, _, al = data:getPixel(px_, py_)
                keep = al > 0.3
            end
            if keep then
                local bx = x0 + (gx + w / 2) * s
                local by = y0 + (gy + h / 2) * s
                local dx, dy = bx - cx, by - (bottomY - ih * s * 0.5)
                local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                local sp = speed * rnd(0.5, 1.2)
                addBit({ img = img, quad = love.graphics.newQuad(gx, gy, w, h, iw, ih),
                         ox = w / 2, oy = h / 2, x = bx, y = by, s = s,
                         vx = dx / len * sp + rnd(-40, 40), vy = dy / len * sp * 0.7 - rnd(80, 220),
                         rv = rnd(-8, 8), life = rnd(0.8, 1.5), g = opts.g or 900,
                         grow = opts.grow or 0, over = opts.over })
            end
        end
    end
end

local ROCKS = { "rock_chunk", "rock_chunk_2", "rock_chunk_3", "rock_chunk_4" }
local function rockImage()
    return image(ROCKS[love.math.random(1, #ROCKS)]) or image("rock_chunk")
end

local function rocks(cx, cy, n, spread, s)
    for _ = 1, n do
        local rimg = rockImage()
        local a = -math.pi * rnd(0.08, 0.92)
        local sp = rnd(220, 520)
        addBit({ img = rimg, x = cx + rnd(-spread, spread) * 0.3, y = cy - rnd(0, 10),
                 ox = rimg and rimg:getWidth() / 2 or 0, oy = rimg and rimg:getHeight() / 2 or 0,
                 s = s * rnd(0.45, 0.8), vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                 rv = rnd(-10, 10), life = rnd(0.9, 1.4), g = 1200, rock = true })
    end
end

local function splash(x, y, s, delay, sx, kind)
    splashes[#splashes + 1] = { x = x, y = y, s = s, sx = sx or 1, t = -(delay or 0), dur = 0.75, kind = kind }
end

local function crackSet(n, w, h)
    local list = {}
    for _ = 1, n do
        local x, y = rnd(0.3, 0.7) * w, rnd(0.25, 0.75) * h
        local pts = { { x, y } }
        local ang = rnd(0, math.pi * 2)
        for _ = 1, 5 + love.math.random(0, 3) do
            ang = ang + rnd(-0.9, 0.9)
            x = math.max(4, math.min(w - 4, x + math.cos(ang) * rnd(5, 11)))
            y = math.max(4, math.min(h - 4, y + math.sin(ang) * rnd(5, 11)))
            pts[#pts + 1] = { x, y }
        end
        list[#list + 1] = pts
    end
    return list
end

local function drawPixelLine(x1, y1, x2, y2, P)
    local dx, dy = x2 - x1, y2 - y1
    local n = math.max(1, math.floor(math.max(math.abs(dx), math.abs(dy)) / P))
    for i = 0, n do
        local x = math.floor((x1 + dx * i / n) / P) * P
        local y = math.floor((y1 + dy * i / n) / P) * P
        love.graphics.rectangle("fill", x, y, P, P)
    end
end

----------------------------------------------------------------------------
-- entrar nos passos
----------------------------------------------------------------------------

local function enterSnuff(st)
    local stg = A.stage()
    local cfg = InteriorFX.HALLS[(stg and stg.hall) or 2]
    local fl = (cfg and cfg.flames) or {}
    local order = {}
    for i = 1, #fl do order[i] = i end
    table.sort(order, function(a, b)
        return math.abs(fl[a][1] + fl[a][3] / 2 - 200) > math.abs(fl[b][1] + fl[b][3] / 2 - 200)
    end)
    local dur = math.max(0.3, st.dur or 1.4)
    local list = {}
    for n, i in ipairs(order) do
        local f = fl[i]
        list[#list + 1] = { cx = f[1] + f[3] / 2, cy = f[2] + f[4] * 0.5,
                            rx = math.max(f[3], 16) * 1.15, ry = math.max(f[4], 16) * 1.35,
                            outAt = dur * (0.30 + 0.55 * (n - 1) / math.max(1, #order - 1)),
                            seed = i * 1.7 }
    end
    E.snuff = { t = 0, dur = dur, list = list }
    A.darkTo(st.to or 0.95, dur)
end

local function enterSigil(st)
    local dur = math.max(0.4, st.dur or 1.4)
    local n = st.n or 4
    local ign = {}
    for i = 1, n do
        ign[i] = 0.25 + (i - 1) * (dur - 0.4) / n
        A.queueSfx(ign[i], "bossRuneIgnite", "orbChannel", 0.85 + i * 0.07)
    end
    E.sigil = { t = 0, dur = dur, n = n, ign = ign }
    A.play("bossRuneIgnite", "orbChannel", 0.6, 0)
    A.mist(1, 1.0)
end

local function enterTomb(st)
    local dur = math.max(0.6, st.dur or 1.8)
    local tomb = { t = 0, dur = dur, rise = 0.34, hits = { 0.50, 0.66, 0.82 }, done = 0,
                   cracks = { crackSet(2, 96, 160), crackSet(3, 96, 160), crackSet(4, 96, 160) } }
    E.tomb = tomb
    A.play("bossIceCrackle", nil, 0.62, 0)
    A.queueSfx(0.05, "sceneStoneThud", nil, 0.7)
    shake(4, dur * tomb.rise)
    local fx_, fy, _, bb = feet()
    if fx_ then A.spawnDust(fx_, fy, 10, bb.width or 120) end
end

local function burstTomb()
    local tb = E.tomb
    if not tb then return end
    local img = image("ice_tomb")
    local fx_, fy, s = feet()
    if img and fx_ then
        local ok, data = pcall(love.image.newImageData,
            "assets/sprites/characters/enemies/" .. tostring(A.bossId()) .. "/entrance/ice_tomb.png")
        shatterImage(img, fx_, fy + 4 * s, s, 12, 360, { data = ok and data or nil, g = 950 })
    end
    E.tomb = nil
    A.play("bossFrostShatter", "impactIce")
    A.queueSfx(0.06, "impactIce", nil, 0.8)
end

local function enterGlass(st)
    E.glass = { t = 0, dur = math.max(0.4, st.dur or 1.0), at = st.burst or 0.45 }
    A.play("bossIceCrackle", nil, 1.15, 0)
    A.queueSfx(0.22, "bossIceCrackle", nil, 1.35)
    shake(3, E.glass.dur * E.glass.at)
end

local function burstGlass()
    local g = E.glass
    if not g or g.burst then return end
    g.burst = true
    g.hole = 0
    local stg = A.stage()
    local img = stg and hallImage(stg.hall)
    local s = hs()
    if img then
        local iw, ih = img:getDimensions()
        local wx, wy = H(200, 60)
        for gy = 10, 122, 8 do
            for gx = 174, 222, 7 do
                local bx, by = H(gx + 3.5, gy + 4)
                local dx, dy = bx - wx, by - wy
                addBit({ img = img, quad = love.graphics.newQuad(gx, gy, 7, 8, iw, ih), ox = 3.5, oy = 4,
                         x = bx, y = by, s = s, vx = dx * rnd(1.2, 2.6) + rnd(-60, 60),
                         vy = dy * rnd(0.6, 1.4) + rnd(-180, 40), rv = rnd(-9, 9),
                         life = rnd(0.7, 1.1), g = 620, grow = rnd(0.4, 1.1), glass = true })
            end
        end
    end
    local wx, wy = H(200, 66)
    A.startHit(wx, wy, "frost")
    shake(10, 0.45)
    InteriorFX.gust(1.0, 1.3)
    A.play("shopCrystalShatter", "bossFrostShatter")
    A.play("bossFrostShatter", nil, 1.25, 0)
    A.mist(0.9, 0.6)
end

local function enterSkull(st)
    E.skull = { t = 0, dur = math.max(0.6, st.dur or 1.6), eyesAt = st.eyes or 0.3, lavaAt = st.lava or 0.68 }
    A.playLoop("bossEyesRumble")
    shake(2, E.skull.dur)
    A.mist(1, 1.0)
end

local function enterErupt(st)
    local dur = math.max(0.6, st.dur or 1.9)
    local pop = st.pop or 0.38
    E.erupt = { t = 0, dur = dur, popAt = dur * pop, anim = A.ownAnim(st.clip, dur * (1 - pop)),
                clip = st.clip }
    local fx_, fy, _, bb = feet()
    if fx_ then A.startCracks(fx_, fy, (bb.width or 120) * 1.3) end
    A.play("bossEmergeTear", "sceneStoneThud", 0.75, 0)
    shake(3, dur * pop)
end

local function popErupt()
    local er = E.erupt
    if not er or er.popped then return end
    er.popped = true
    local fx_, fy, s, bb = feet()
    if not fx_ then return end
    local wdt = bb.width or 120
    E.crater = { t = 0 }
    splash(fx_, fy + 2 * s, s * 1.2, 0, 1)
    splash(fx_ - wdt * 0.42, fy + 3 * s, s * 0.8, 0.07, -1)
    splash(fx_ + wdt * 0.42, fy + 3 * s, s * 0.8, 0.11, 1)
    rocks(fx_, fy, 16, wdt, s)
    for _ = 1, 30 do
        local a = -math.pi * rnd(0.1, 0.9)
        local sp = rnd(120, 360)
        A.spawnFeather(fx_ + rnd(-0.4, 0.4) * wdt, fy - rnd(0, 12), math.cos(a) * sp, math.sin(a) * sp, "ember")
    end
    A.startHit(fx_, fy - 20 * s, "lava")
    shake(14, 0.55)
    A.play("bossLavaImplosion", "impactFire")
    A.queueSfx(0.04, "impactFire", nil, 0.7)
    A.darkTo(0.5, 0.35)
    if A.bondDrag() then A.queueSfx(0.25, "tyrantChainDrag", "bossChainsRattle") end
end

local function enterRumble(st)
    E.rumble = { t = 0, dur = math.max(0.4, st.dur or 1.5), next = 0.05, every = st.every or 0.32 }
    A.playLoop("bossEyesRumble")
    A.mist(1, 1.0)
end

local function enterDrop(st)
    E.drop = { t = 0, dur = math.max(0.2, st.dur or 0.45), anim = A.ownAnim(st.clip, nil) }
    A.play("bossWingPass", "sceneRustle", 0.55, 0)
    A.bondDrag()
end

local function landDrop()
    local fx_, fy, s, bb = feet()
    E.drop = nil
    if not fx_ then return end
    local wdt = bb.width or 120
    E.crater = { t = 0 }
    splash(fx_ - wdt * 0.5, fy + 2 * s, s * 0.9, 0.02, -1)
    splash(fx_ + wdt * 0.5, fy + 2 * s, s * 0.9, 0.05, 1)
    splash(fx_, fy + 4 * s, s * 0.7, 0.12, 1)
    rocks(fx_, fy, 20, wdt, s)
    A.queueSfx(0.02, "impactFire", nil, 0.6)
end

----------------------------------------------------------------------------
-- Monarca do Inverno: geada nas bordas, espinhos de gelo no golpe
----------------------------------------------------------------------------

local FROST_PATH = MONARCH .. "mechanic/frost_corner.png"
local SPIKE_PATH = MONARCH .. "entrance/ice_spike.png"
local PATCH_PATH = MONARCH .. "entrance/frost_patch.png"

local function imageData(path)
    if dataCache[path] == nil then
        local ok, d = pcall(love.image.newImageData, path)
        dataCache[path] = ok and d or false
    end
    return dataCache[path] or nil
end

-- A arte do canto nasce no canto de baixo-esquerda; espelha para os outros três.
local function frostCorners(w, h)
    return { { 0, h, 1, 1 }, { w, h, -1, 1 }, { 0, 0, 1, -1 }, { w, 0, -1, -1 } }
end

local function frostScale(fr, ih, w, h)
    local k = easeOut(clamp01(fr.t / fr.grow))
    k = math.floor(k * 8 + 0.5) / 8
    return math.min(w, h) * 0.36 / ih * (0.25 + 0.75 * k)
end

-- Do disco de geada fica só o gelo (estrela e rachaduras); a pedra vira transparente.
local patchImg = nil
local function iceOnlyPatch()
    if patchImg == nil then
        patchImg = false
        local d = imageData(PATCH_PATH)
        if d then
            local c = d:clone()
            c:mapPixel(function(_, _, r, g, b, al)
                if b > r + 0.08 and (r + g + b) / 3 > 0.45 then return r, g, b, al end
                return r, g, b, 0
            end)
            patchImg = love.graphics.newImage(c)
            patchImg:setFilter("nearest", "nearest")
        end
    end
    return patchImg or nil
end

local function enterFrostRim(st)
    E.frost = { t = 0, life = st.life or 6, grow = math.max(0.3, st.grow or 3.0) }
    A.play("bossIceCrackle", nil, 1.25, 0)
    A.queueSfx(0.7, "bossIceCrackle", nil, 1.05)
    A.queueSfx(1.4, "bossIceCrackle", nil, 0.9)
end

local function shatterFrost()
    local fr = E.frost
    if not fr then return end
    E.frost = nil
    local img = image(FROST_PATH)
    if not img then return end
    local data = imageData(FROST_PATH)
    local iw, ih = img:getDimensions()
    local w, h = lastW, lastH
    local sc = frostScale(fr, ih, w, h)
    local cell = A.reduced() and 16 or 8
    for _, c in ipairs(frostCorners(w, h)) do
        for gy = 0, ih - 1, cell do
            for gx = 0, iw - 1, cell do
                local cw, ch = math.min(cell, iw - gx), math.min(cell, ih - gy)
                local keep = true
                if data then
                    local _, _, _, al = data:getPixel(math.min(iw - 1, gx + math.floor(cw / 2)),
                        math.min(ih - 1, gy + math.floor(ch / 2)))
                    keep = al > 0.3
                end
                if keep then
                    local bx = c[1] + (gx + cw / 2) * sc * c[3]
                    local by = c[2] + (gy + ch / 2 - ih) * sc * c[4]
                    local dx, dy = bx - w / 2, by - h / 2
                    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                    local sp = rnd(260, 620)
                    addBit({ img = img, quad = love.graphics.newQuad(gx, gy, cw, ch, iw, ih),
                             ox = cw / 2, oy = ch / 2, x = bx, y = by, s = sc, fx = c[3], fy = c[4],
                             vx = dx / len * sp, vy = dy / len * sp - rnd(0, 80), rv = rnd(-9, 9),
                             life = rnd(0.5, 0.9), g = 500, over = true, ice = true })
                end
            end
        end
    end
end

-- O golpe do cajado: a geada estoura e um anel de espinhos de gelo brota em volta dele.
function Ent.strike()
    if not A then return end
    shatterFrost()
    local fx_, fy, s, bb = feet()
    if not fx_ then return end
    local wdt = bb.width or 120
    local n = A.reduced() and 6 or 16
    local list, tries = {}, 0
    while #list < n and tries < n * 8 do
        tries = tries + 1
        local r = love.math.random()
        local ang = rnd(0, math.pi * 2)
        local rx = wdt * (0.62 + 0.75 * r)
        local x, y = fx_ + math.cos(ang) * rx, fy + math.sin(ang) * rx * 0.2
        local front = y > fy
        if not (front and math.abs(x - fx_) < wdt * 0.55) then
            list[#list + 1] = { x = x, y = y, front = front, delay = 0.02 + r * 0.32,
                                sc = s * rnd(0.75, 1.25) * (1.1 - 0.35 * r),
                                flip = (love.math.random() < 0.5) and -1 or 1 }
        end
    end
    table.sort(list, function(a, b) return a.y < b.y end)
    E.spikes = { t = 0, list = list }
    E.patch = { t = 0 }
    E.flare = { t = 0 }
    E.boom = { t = 0 }
    A.darkTo(0.15, 0.45)
    A.play("iceSpikes", "impactIce", 1.0, 0.05)
    A.queueSfx(0.10, "bossFrostShatter", nil, 1.0)
    A.queueSfx(0.22, "bossIceCrackle", nil, 0.9)
end

local function breakSpikes()
    local sp = E.spikes
    if not sp or sp.broken then return end
    sp.broken = true
    local img = image(SPIKE_PATH)
    local data = imageData(SPIKE_PATH)
    local cell = A.reduced() and 16 or 8
    for _, k in ipairs(sp.list) do
        if img and k.up then shatterImage(img, k.x, k.y, k.sc, cell, 240, { data = data, g = 900, over = k.front }) end
        A.spawnFeather(k.x, k.y - 10, rnd(-80, 80), rnd(-200, -80), "shard")
    end
    A.play("bossFrostShatter", "impactIce", 0.9, 0)
    A.play("shopCrystalShatter", nil, 0.8, 0.05)
    shake(6, 0.3)
end

----------------------------------------------------------------------------
-- Colosso Podre: o coração acorda, veias de raiz, poço de lama
----------------------------------------------------------------------------

local HEART = { 200, 115 }
-- pontos no salão (px da arte) e, por último, o deslocamento no pé (em larguras do chefe)
local VEINS = {
    { { 186, 168 }, { 168, 196 }, -0.25 },
    { { 214, 168 }, { 234, 196 }, 0.25 },
    { { 92, 126 }, { 96, 178 }, { 130, 214 }, -0.45 },
    { { 308, 126 }, { 304, 178 }, { 270, 214 }, 0.45 },
    { { 200, 172 }, 0 },
}

local function veinPath(pts, seed, wobMax)
    local out = { { pts[1][1], pts[1][2], 0 } }
    local total = 0
    for i = 2, #pts do
        local ax, ay = pts[i - 1][1], pts[i - 1][2]
        local bx, by = pts[i][1], pts[i][2]
        local dx, dy = bx - ax, by - ay
        local len = math.max(1, math.sqrt(dx * dx + dy * dy))
        local n = math.max(2, math.floor(len / 10))
        local nx, ny = -dy / len, dx / len
        for j = 1, n do
            local q = j / n
            local wob = (j < n) and math.sin(q * math.pi * 2 + seed + i) * math.min(wobMax, len * 0.06) or 0
            local x, y = ax + dx * q + nx * wob, ay + dy * q + ny * wob
            local lx, ly = out[#out][1], out[#out][2]
            total = total + math.sqrt((x - lx) ^ 2 + (y - ly) ^ 2)
            out[#out + 1] = { x, y, total }
        end
    end
    return out, total
end

local function pathAt(v, d)
    local p = v.pts
    if d <= 0 then return p[1][1], p[1][2] end
    for i = 2, #p do
        if p[i][3] >= d then
            local a, b = p[i - 1], p[i]
            local q = (d - a[3]) / math.max(0.001, b[3] - a[3])
            return lerp(a[1], b[1], q), lerp(a[2], b[2], q)
        end
    end
    return p[#p][1], p[#p][2]
end

local function buildVeins()
    local fx_, fy, _, bb = feet()
    local wdt = (bb and bb.width) or 120
    local list = {}
    for vi, def in ipairs(VEINS) do
        local pts = {}
        for i = 1, #def - 1 do
            local x, y = H(def[i][1], def[i][2])
            pts[#pts + 1] = { x, y }
        end
        if fx_ then pts[#pts + 1] = { fx_ + def[#def] * wdt, fy } end
        local path, len = veinPath(pts, vi * 1.7, 6 * hs())
        list[#list + 1] = { pts = path, len = len }
    end
    return list
end

local function enterHeartWake(st)
    local dur = math.max(0.5, st.dur or 2.4)
    local beats = {}
    for i, b in ipairs({ 0.10, 0.78, 1.30, 1.70, 2.02, 2.28 }) do beats[i] = b * dur / 2.4 end
    E.heart = { t = 0, dur = dur, beats = beats, i = 1, last = -9, nextSlow = dur + 0.4,
                veins = buildVeins(), pulses = {}, n = 0 }
    A.playLoop("bossRootsCrawl")
    InteriorFX.pulseBoost(2.2, dur)
    A.mist(1, 1)
end

local function heartBeat(hw)
    hw.n = hw.n + 1
    hw.last = hw.t
    local n = math.min(6, hw.n)
    A.play("bossHeartbeat", nil, 0.85 + 0.04 * n, 0)
    shake(1.5 + n * 0.6, 0.15)
    if not A.reduced() then
        local x, y = H(HEART[1], HEART[2])
        for _ = 1, 5 do A.spawnFeather(x + rnd(-20, 20), y + rnd(-24, 24), rnd(-40, 40), rnd(-40, 10), "spore") end
    end
    for _, v in ipairs(hw.veins) do hw.pulses[#hw.pulses + 1] = { v = v, t = 0 } end
end

local BUBBLES = { { -0.30, -0.05 }, { 0.18, -0.12 }, { 0.34, 0.06 }, { -0.12, 0.10 }, { 0.02, -0.02 }, { -0.40, 0.08 } }

local function enterBog(st)
    local dur = math.max(0.3, st.dur or 1.2)
    local bubbles = {}
    for i, b in ipairs(BUBBLES) do bubbles[i] = { u = b[1], v = b[2], t = -rnd(0.2, 1.0), dur = rnd(0.35, 0.6) } end
    E.bog = { t = 0, grow = math.min(dur * 0.7, 0.9), bubbles = bubbles, glug = 0 }
    A.play("bossEmergeTear", "sceneStoneThud", 0.55, 0)
    A.play("mudSplash", "shopPotionBubble", 0.8, 0.05)
    shake(4, dur * 0.6)
    local fx_, fy = feet()
    if fx_ then A.spawnDust(fx_, fy, 6, 120) end
end

local function enterBogRise(st)
    local dur = math.max(0.5, st.dur or 2.3)
    E.rise = { t = 0, dur = dur, anim = A.ownAnim(st.clip, dur), drip = 0, splash = 0.25 }
    A.play("bogRise", "bossEmergeTear", 0.9, 0)
    A.darkTo(0.62, 0.8)
    A.queueSfx(0.6, "leechRise", nil, 0.85)
    shake(3, dur)
    local fx_, fy, s, bb = feet()
    if fx_ then
        local wdt = bb.width or 120
        splash(fx_, fy + 2 * s, s * 1.1, 0, 1, "mud")
        splash(fx_ - wdt * 0.38, fy + 3 * s, s * 0.8, 0.08, -1, "mud")
        splash(fx_ + wdt * 0.38, fy + 3 * s, s * 0.8, 0.14, 1, "mud")
    end
end

local function riseGeom(r)
    local dx, dy, s = A.footInfo()
    if not (dx and r.anim) then return nil end
    local st = A.stage()
    local _, ih = r.anim:getSize()
    local sh = ih * s
    local k = clamp01(r.t / r.dur)
    local y = dy + sh * 0.95 * (1 - smooth(k)) + math.sin(r.t * 7) * 3 * s * (1 - k)
    local floorY = math.floor((st.cy or (dy + sh)) + 3 * s)
    local bg = E.bog
    if bg then
        -- Corte na mesma linha da borda da poça (ver lipCut): sobe de dentro da lama.
        local _, fy, s2 = feet()
        if fy then
            local g = easeOut(clamp01(bg.t / bg.grow))
            local ps = s2 * 1.15 * (0.12 + 0.88 * g) * (0.6 + 0.4 * fadeK(bg))
            floorY = math.floor(math.floor(fy + 2 * s2) - 3 * ps) + math.floor(2 * s)
        end
    end
    return dx, y, s, floorY, k
end

local function popRise()
    E.rise = nil
    E.lip = { t = 0 }
    local fx_, fy, s, bb = feet()
    if not fx_ then return end
    local wdt = bb.width or 120
    splash(fx_ - wdt * 0.3, fy + 2 * s, s * 0.9, 0, -1, "mud")
    splash(fx_ + wdt * 0.3, fy + 2 * s, s * 0.9, 0.05, 1, "mud")
    for _ = 1, (A.reduced() and 6 or 18) do
        local a = -math.pi * rnd(0.1, 0.9)
        local sp = rnd(160, 380)
        addBit({ x = fx_ + rnd(-0.4, 0.4) * wdt, y = fy - rnd(0, 10), vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                 life = 1.2, g = 1100, mud = true, nodust = true, floor = fy + 4 * s, s = s })
    end
    A.play("mudSplash", "shopPotionBubble", 0.7, 0)
end

----------------------------------------------------------------------------
-- Colosso Podre, entradas novas: coração nítido, casulo de raízes, gota de seiva
----------------------------------------------------------------------------

local HEART_C = { 202, 112 }
local HEART_R = { 48, 62 }
local HEART_TIP = { 192, 166 }
local COCOON = "root_cocoon"
-- raízes que correm pelo chão até o pé (px da arte; por último o deslocamento em larguras)
local CROOTS = {
    { { 24, 254 }, { 86, 240 }, -0.32 },
    { { 376, 254 }, { 314, 240 }, 0.32 },
    { { 104, 208 }, { 146, 222 }, -0.16 },
    { { 296, 208 }, { 254, 222 }, 0.16 },
    { { 150, 256 }, -0.05 },
    { { 250, 256 }, 0.05 },
}

-- Mesmo recorte do salão que reveal(), mas sem dither: o coração fica nítido.
local CLEAR_GLSL = [[
extern vec2 tex;
extern vec4 ell;
vec4 effect(vec4 col, Image t, vec2 uv, vec2 sc) {
    vec2 hp = floor(uv * tex);
    vec2 d = (hp + 0.5 - ell.xy) / ell.zw;
    float q = 1.0 - dot(d, d);
    if (q <= 0.0) discard;
    float k = clamp(q * 2.5, 0.0, 1.0);
    vec4 c = Texel(t, uv);
    return vec4(c.rgb * col.rgb, c.a * col.a * k);
}
]]
local clearShader, clearTried = nil, false
local function hallLit(cx, cy, rx, ry, a, tint, add)
    if a <= 0.01 then return end
    local st = A.stage()
    local tr = st and st.tr
    local img = st and hallImage(st.hall)
    if not clearTried then
        clearTried = true
        local ok, sh = pcall(love.graphics.newShader, CLEAR_GLSL)
        if ok then clearShader = sh else
            require("src.core.Debug").warn("[BossCineEntradas] shader do coração falhou: " .. tostring(sh))
        end
    end
    if not (img and tr and clearShader) then return end
    local iw, ih = img:getDimensions()
    local x0, y0 = math.max(0, math.floor(cx - rx)), math.max(0, math.floor(cy - ry))
    local x1, y1 = math.min(iw, math.ceil(cx + rx)), math.min(ih, math.ceil(cy + ry))
    if x1 <= x0 or y1 <= y0 then return end
    lightQuad = lightQuad or love.graphics.newQuad(0, 0, 1, 1, iw, ih)
    lightQuad:setViewport(x0, y0, x1 - x0, y1 - y0, iw, ih)
    love.graphics.setShader(clearShader)
    clearShader:send("tex", { iw, ih })
    clearShader:send("ell", { cx, cy, rx, ry })
    tint = tint or { 1, 1, 1 }
    if add then love.graphics.setBlendMode("add") end
    love.graphics.setColor(tint[1], tint[2], tint[3], math.min(1, a))
    love.graphics.draw(img, lightQuad, tr.ox + x0 * tr.scale, tr.oy + y0 * tr.scale, 0, tr.scale, tr.scale)
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local function backOut(k)
    local c1 = 1.4
    local q = k - 1
    return 1 + (c1 + 1) * q * q * q + c1 * q * q
end

-- coração do salão: acende nítido e bate (as outras peças pulsam junto)
local function enterHeartGlow(st)
    local dur = math.max(0.5, st.dur or 1.6)
    local list = st.fast and { 0.10, 0.55, 0.90, 1.15, 1.36, 1.55 } or { 0.15, 0.85, 1.35 }
    local base = st.fast and 1.8 or 1.6
    local beats = {}
    for i, b in ipairs(list) do beats[i] = b * dur / base end
    E.hg = { t = 0, beats = beats, i = 1, last = -9, n = 0, nextAt = dur + 0.2, every = 0.75 }
    InteriorFX.pulseBoost(2.0, dur)
    A.mist(0.25, 1)
end

local function hgBeat(hg)
    hg.n = hg.n + 1
    hg.last = hg.t
    local n = math.min(6, hg.n)
    A.play("bossHeartbeat", nil, 0.85 + 0.04 * n, 0)
    shake(1 + n * 0.5, 0.14)
    if not A.reduced() then
        local x, y = H(HEART_C[1], HEART_C[2])
        local s = hs()
        for _ = 1, 4 do
            A.spawnFeather(x + rnd(-15, 15) * s, y + rnd(-15, 15) * s, rnd(-30, 30), rnd(-30, 10), "spore")
        end
    end
end

local function hgEnv()
    local hg = E.hg
    if not hg then return 0 end
    return math.max(0, 1 - (hg.t - hg.last) / 0.35)
end

local function buildFloorRoots(defs)
    local fx_, fy, _, bb = feet()
    local wdt = (bb and bb.width) or 120
    local list = {}
    for vi, def in ipairs(defs) do
        local pts = {}
        for i = 1, #def - 1 do
            local x, y = H(def[i][1], def[i][2])
            pts[#pts + 1] = { x, y }
        end
        if fx_ then pts[#pts + 1] = { fx_ + def[#def] * wdt, fy } end
        local path, len = veinPath(pts, vi * 2.3, 5 * hs())
        list[#list + 1] = { pts = path, len = len }
    end
    return list
end

local function drawRootList(list, grow, a, env)
    if a <= 0.01 then return end
    local P = A.px()
    for _, v in ipairs(list) do
        local upto = v.len * grow
        local pts = {}
        for d = 0, upto, P do
            local x, y = pathAt(v, d)
            local th = math.max(2, math.floor(lerp(6, 3, d / math.max(1, v.len)) + 0.5))
            pts[#pts + 1] = { math.floor(x / P) * P, math.floor(y / P) * P, th }
        end
        love.graphics.setColor(0.03, 0.03, 0.02, a)
        for _, p in ipairs(pts) do love.graphics.rectangle("fill", p[1] - P, p[2] - P, (p[3] + 2) * P, (p[3] + 1) * P) end
        love.graphics.setColor(BARK[1], BARK[2], BARK[3], a)
        for _, p in ipairs(pts) do love.graphics.rectangle("fill", p[1], p[2] - P, p[3] * P, p[3] * P) end
        love.graphics.setColor(BARK_HI[1], BARK_HI[2], BARK_HI[3], a)
        for i, p in ipairs(pts) do
            if p[3] > 2 and i % 2 == 0 then love.graphics.rectangle("fill", p[1], p[2] - P, P, P) end
        end
        local core = 0.25 + 0.6 * env
        love.graphics.setColor(GREEN[1] * core, GREEN[2] * core, GREEN[3] * core, a)
        for i, p in ipairs(pts) do
            if p[3] > 1 and i % 3 == 0 then love.graphics.rectangle("fill", p[1] + P, p[2], P, P) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local cocBottom = nil
local function cocoonPath()
    return "assets/sprites/characters/enemies/" .. tostring(A.bossId()) .. "/entrance/" .. COCOON .. ".png"
end
local function cocoonBase(img)
    if cocBottom then return cocBottom end
    local iw, ih = img:getDimensions()
    cocBottom = ih - 1
    local data = imageData(cocoonPath())
    if data then
        for y = ih - 1, 0, -1 do
            local hit = false
            for x = 0, iw - 1 do
                local _, _, _, al = data:getPixel(x, y)
                if al > 0.3 then hit = true; break end
            end
            if hit then cocBottom = y; break end
        end
    end
    return cocBottom
end

local function enterCocoon(st)
    local dur = math.max(0.8, st.dur or 3.0)
    E.coc = { t = 0, dur = dur, rise = math.min(0.6, dur * 0.2), grow = math.min(0.8, dur * 0.27),
              roots = buildFloorRoots(CROOTS), creak = 0, dustT = 0 }
    A.playLoop("bossRootsCrawl")
    A.darkTo(0.72, 0.8)
end

local function cocGeom(c)
    local img = image(COCOON)
    local fx_, fy, s = feet()
    if not (img and fx_) then return nil end
    local ob = cocoonBase(img)
    local k = clamp01((c.t - c.rise) / c.grow)
    if k <= 0 then return img, fx_, fy, 0, 0, ob, 0 end
    local env = hgEnv()
    local sc = s * 1.2
    local sx = sc * (0.70 + 0.30 * easeOut(k)) * (1 + 0.035 * env)
    local sy = sc * backOut(k) * (1 - 0.02 * env)
    local x = fx_
    local q = clamp01((c.t - (c.dur - 0.7)) / 0.7)
    if q > 0 and not A.reduced() then
        local P = A.px()
        x = x + ((love.math.random() < 0.5) and -1 or 1) * P * math.floor(q * 2 + 0.5)
    end
    return img, x, fy + 2 * s, sx, sy, ob, k
end

local function drawCocoon()
    local c = E.coc
    if not c then return end
    local P = A.px()
    local env = hgEnv()
    drawRootList(c.roots, easeOut(clamp01(c.t / c.rise)), 1, env)
    local img, x, y, sx, sy, ob, k = cocGeom(c)
    if not img or k <= 0 then return end
    local iw = img:getWidth()
    x, y = math.floor(x / P) * P, math.floor(y)
    local crack = clamp01((c.t - (c.dur - 0.7)) / 0.7)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, x, y, 0, sx, sy, iw / 2, ob + 1)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], (0.10 + 0.45 * env + 0.40 * crack) * k)
    love.graphics.draw(img, x, y, 0, sx, sy, iw / 2, ob + 1)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local function burstCocoon()
    local c = E.coc
    E.coc = nil
    A.stopLoop("bossRootsCrawl")
    if not c then return end
    E.croots = { roots = c.roots }
    c.t = c.dur
    local img, x, y, sx, sy, ob = cocGeom(c)
    if img and sx > 0 then
        local ih = img:getHeight()
        shatterImage(img, x, y + (ih - 1 - ob) * sy, sx, A.reduced() and 16 or 8, 420,
            { data = imageData(cocoonPath()), g = 1000 })
    end
    E.gflash = { t = 0 }
    local fx_, fy, s, bb = feet()
    if fx_ then
        local wdt = bb.width or 120
        for _ = 1, (A.reduced() and 8 or 26) do
            A.spawnFeather(fx_ + rnd(-0.4, 0.4) * wdt, fy - rnd(20, 120) * s, rnd(-160, 160), rnd(-200, -40), "spore")
        end
        A.spawnDust(fx_, fy, 14, wdt)
    end
    A.play("bossEmergeTear", "sceneStoneThud", 0.8, 0)
    A.play("mudSplash", nil, 0.85, 0.03)
    shake(9, 0.4)
    A.setHidden(false)
    A.setLanded(true)
end

-- gota de seiva: nasce na ponta do coração, cai e vira poça
local function enterSapDrop(st)
    local dur = math.max(0.6, st.dur or 1.5)
    local x0, y0 = H(HEART_TIP[1], HEART_TIP[2])
    E.sap = { t = 0, dur = dur, form = dur * 0.5, x0 = x0, y0 = y0, x = x0, y = y0, hang = 0, trail = {} }
    A.play("shopPotionBubble", nil, 0.5, 0)
    A.queueSfx(dur * 0.35, "shopPotionBubble", nil, 0.42)
end

local function drawDropAt(x, y, R, tail, P, a)
    local cx, cy = math.floor(x / P) * P, math.floor(y / P) * P
    for j = -R, R do
        local hw = math.floor(math.sqrt(R * R - j * j) + 0.5)
        love.graphics.setColor(0.08, 0.24, 0.05, a)
        love.graphics.rectangle("fill", cx - (hw + 1) * P, cy + j * P, (2 * hw + 2) * P, P)
        love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], a)
        love.graphics.rectangle("fill", cx - hw * P, cy + j * P, 2 * hw * P, P)
    end
    for j = 1, tail do
        local hw = math.floor(R * (1 - j / (tail + 1)) + 0.5)
        love.graphics.setColor(0.08, 0.24, 0.05, a)
        love.graphics.rectangle("fill", cx - (hw + 1) * P, cy - (R + j) * P, (2 * hw + 2) * P, P)
        if hw > 0 then
            love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], a)
            love.graphics.rectangle("fill", cx - hw * P, cy - (R + j) * P, 2 * hw * P, P)
        end
    end
    love.graphics.setColor(SAP[1], SAP[2], SAP[3], a)
    love.graphics.rectangle("fill", cx - math.max(1, math.floor(R / 2)) * P, cy - math.max(1, math.floor(R / 2)) * P, P, P)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSap()
    local sp = E.sap
    if not sp then return end
    local P = A.px()
    local s = hs()
    local R, tail
    if sp.t <= sp.form then
        local k = sp.t / sp.form
        R = 2 + math.floor(4 * easeOut(k) + 0.5)
        tail = math.floor(R * (0.5 + 1.2 * k) + 0.5)
        local top = math.floor(sp.y0 / P) * P
        local bot = math.floor((sp.y - (R + tail) * P) / P) * P
        if bot > top then
            love.graphics.setColor(GREEN[1], GREEN[2], GREEN[3], 1)
            love.graphics.rectangle("fill", math.floor(sp.x / P) * P, top, P, bot - top)
        end
    else
        R, tail = 6, 7
    end
    for i, p in ipairs(sp.trail) do
        love.graphics.setColor(SAP[1], SAP[2], SAP[3], 0.8 * (1 - i / (#sp.trail + 1)))
        love.graphics.rectangle("fill", math.floor(p[1] / P) * P, math.floor(p[2] / P) * P, P, P)
    end
    A.glowBlob(sp.x, sp.y, 26 * s, 26 * s, GREEN, 0.3, 1)
    drawDropAt(sp.x, sp.y, R, tail, P, 1)
end

local function splatSap()
    E.sap = nil
    local fx_, fy, s = feet()
    if not fx_ then return end
    splash(fx_, fy + 2 * s, s * 0.9, 0, 1, "sap")
    E.pud = { t = 0, bub = 0 }
    E.gflash = { t = 0, small = true }
    A.play("mudSplash", "shopPotionBubble", 0.95, 0)
    A.play("bossEmergeTear", nil, 0.55, 0.05)
    shake(6, 0.25)
    for _ = 1, (A.reduced() and 5 or 14) do
        local ang = -math.pi * rnd(0.1, 0.9)
        local spd = rnd(140, 320)
        addBit({ x = fx_ + rnd(-8, 8), y = fy - 4, vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
                 life = 1.0, g = 1100, mud = true, sap = true, nodust = true, floor = fy + 6 * s, s = s })
    end
end

local function drawPuddle()
    local pd = E.pud
    if not pd then return end
    local fx_, fy, s, bb = feet()
    if not fx_ then return end
    local P = A.px()
    local a = fadeK(pd)
    local g = easeOut(clamp01(pd.t / 0.5))
    local rx = (bb.width or 120) * (0.12 + 0.30 * g)
    local ry = math.max(P, rx * 0.18)
    local cx, cy = math.floor(fx_ / P) * P, math.floor((fy + 2 * s) / P) * P
    A.glowBlob(cx, cy, rx * 2.2, ry * 4, GREEN, (0.06 + 0.08 * hgEnv()) * a, 2)
    local R = math.max(1, math.floor(ry / P))
    for j = -R, R do
        local f = math.sqrt(math.max(0, 1 - (j / (R + 0.5)) ^ 2))
        local hw = math.floor(rx / P * f + 0.5) + (((j * 7) % 3 == 0) and 1 or 0)
        love.graphics.setColor(0.03, 0.08, 0.02, a)
        love.graphics.rectangle("fill", cx - hw * P, cy + j * P, 2 * hw * P, P)
        local hw2 = math.max(0, hw - 2)
        love.graphics.setColor(0.09, 0.22, 0.05, a)
        love.graphics.rectangle("fill", cx - hw2 * P, cy + j * P, 2 * hw2 * P, P)
        if j == -R + 1 and hw2 > 2 then
            love.graphics.setColor(SAP[1], SAP[2], SAP[3], 0.8 * a)
            for i = -hw2 + 1, hw2 - 2, 3 do love.graphics.rectangle("fill", cx + i * P, cy + j * P, P, P) end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- o colosso cresce de dentro da seiva: silhueta verde que estica e ganha cor
local function enterSapGrow(st)
    local dur = math.max(0.8, st.dur or 2.6)
    E.grow = { t = 0, dur = dur, anim = A.ownAnim(st.clip or "idle", dur), drip = 0, glug = 0 }
    A.play("bogRise", "bossEmergeTear", 0.85, 0)
    A.queueSfx(dur * 0.45, "leechRise", nil, 0.8)
    A.darkTo(0.6, 1.0)
    shake(2, dur)
end

local function growGeom(g)
    local dx, dy, s = A.footInfo()
    if not (dx and g.anim) then return nil end
    local iw, ih = g.anim:getSize()
    local k = clamp01(g.t / g.dur)
    local ky = backOut(clamp01(k / 0.8))
    local kx = 0.45 + 0.55 * smooth(clamp01(k / 0.7))
    local wob = math.sin(g.t * 10) * 0.06 * (1 - k)
    return dx, dy, s, iw, ih, math.max(0.02, kx + wob), math.max(0.02, ky - wob * 0.5), k
end

local function drawGrow()
    local g = E.grow
    if not (g and g.anim) then return end
    local dx, dy, s, iw, ih, kx, ky, k = growGeom(g)
    if not dx then return end
    local px_, py_ = dx + iw * s / 2, dy + ih * s
    local r = smooth(clamp01((k - 0.62) / 0.38))
    local env = hgEnv()
    local tint = { lerp(0.10, 1, r), lerp(0.30, 1, r), lerp(0.08, 1, r), 1 }
    A.glowBlob(px_, py_ - ih * s * ky * 0.45, iw * s * kx * 1.5, ih * s * ky * 1.2, GREEN,
        (0.16 + 0.2 * env) * (1 - r * 0.6), 1)
    love.graphics.push()
    love.graphics.translate(px_, py_)
    love.graphics.scale(kx, ky)
    love.graphics.translate(-px_, -py_)
    A.drawOwn(g.anim, dx, dy, s, tint, (0.45 + 0.3 * env) * (1 - r))
    love.graphics.pop()
end

local function popGrow()
    E.grow = nil
    E.gflash = { t = 0 }
    local fx_, fy, s, bb = feet()
    if fx_ then
        local wdt = bb.width or 120
        splash(fx_ - wdt * 0.35, fy + 2 * s, s * 0.9, 0, -1, "sap")
        splash(fx_ + wdt * 0.35, fy + 2 * s, s * 0.9, 0.05, 1, "sap")
        for _ = 1, (A.reduced() and 6 or 20) do
            local ang = -math.pi * rnd(0.1, 0.9)
            local spd = rnd(160, 380)
            addBit({ x = fx_ + rnd(-0.4, 0.4) * wdt, y = fy - rnd(20, 160) * s * 0.5, vx = math.cos(ang) * spd,
                     vy = math.sin(ang) * spd, life = 1.2, g = 1100, mud = true, sap = true, nodust = true,
                     floor = fy + 4 * s, s = s })
        end
    end
    A.play("mudSplash", "shopPotionBubble", 0.75, 0)
    A.setHidden(false)
    A.setLanded(true)
end

local function drawHeartGlow()
    local hg = E.hg
    if not hg then return end
    local a = fadeK(hg)
    local env = hgEnv()
    local base = smooth(clamp01(hg.t / 0.6))
    local hx, hy = H(HEART_C[1], HEART_C[2])
    local s = hs()
    A.glowBlob(hx, hy, 110 * s, 130 * s, GREEN, (0.05 + 0.14 * env) * a * base, 1)
    hallLit(HEART_C[1], HEART_C[2], HEART_R[1], HEART_R[2], (0.8 + 0.2 * env) * a * base)
    hallLit(HEART_C[1], HEART_C[2], HEART_R[1], HEART_R[2], (0.12 + 0.55 * env) * a * base, { 0.55, 1.0, 0.45 }, true)
end

local function drawCRoots()
    local cr = E.croots
    if not cr then return end
    drawRootList(cr.roots, 1, fadeK(cr), hgEnv())
end

local function drawGFlash(w, h)
    local f = E.gflash
    if not f then return end
    local k = clamp01(f.t / 0.5)
    local fx_, fy, s = feet()
    if not fx_ then return end
    local m = f.small and 0.5 or 1
    A.glowBlob(fx_, fy - 50 * s * m, w * (0.22 + 0.3 * k) * m, h * (0.25 + 0.25 * k) * m, SAP, 0.45 * (1 - k), 1)
end

function Ent.enter(st)
    local k = st.kind
    if k == "snuff" then enterSnuff(st)
    elseif k == "moon" then
        E.moon = { t = 0, rise = math.max(0.2, st.dur or 0.8), beam = st.beam ~= false,
                   window = st.window ~= false }
        A.play("bossEclipseUnveil", "orbChannel", 1.3, 0)
        A.mist(0.8, 0.8)
    elseif k == "sigil" then enterSigil(st)
    elseif k == "tomb" then enterTomb(st)
    elseif k == "glass" then enterGlass(st)
    elseif k == "wisps" then
        E.wisps = { t = 0, life = st.life or 2.0, n = st.n or 6, out = 0.9 }
        A.play("orbChannel", nil, 0.65, 0)
    elseif k == "skull_wake" then enterSkull(st)
    elseif k == "erupt" then enterErupt(st)
    elseif k == "rumble" then enterRumble(st)
    elseif k == "drop" then enterDrop(st)
    elseif k == "frostrim" then enterFrostRim(st)
    elseif k == "heart_wake" then enterHeartWake(st)
    elseif k == "bog" then enterBog(st)
    elseif k == "bog_rise" then enterBogRise(st)
    elseif k == "heart_glow" then enterHeartGlow(st)
    elseif k == "cocoon" then enterCocoon(st)
    elseif k == "sap_drop" then enterSapDrop(st)
    elseif k == "sap_grow" then enterSapGrow(st)
    end
end

function Ent.exit(st)
    local k = st.kind
    if k == "tomb" then burstTomb()
    elseif k == "glass" then burstGlass()
    elseif k == "erupt" then
        popErupt()
        E.erupt = nil
        A.setHidden(false)
        A.setLanded(true)
    elseif k == "rumble" then
        E.rumble = nil
        A.stopLoop("bossEyesRumble")
    elseif k == "drop" then
        landDrop()
        A.setHidden(false)
        A.setLanded(true)
    elseif k == "skull_wake" then
        A.stopLoop("bossEyesRumble")
    elseif k == "heart_wake" then
        A.stopLoop("bossRootsCrawl")
    elseif k == "bog_rise" then
        popRise()
        A.setHidden(false)
        A.setLanded(true)
    elseif k == "cocoon" then burstCocoon()
    elseif k == "sap_drop" then splatSap()
    elseif k == "sap_grow" then popGrow()
    end
end

-- Chamado em todo passo, inclusive os antigos (land/title encerram os efeitos daqui).
function Ent.onStep(st)
    if st.kind == "land" then
        if E.snuff then E.snuff.relight = 0 end
        if E.sigil then E.sigil.flash = 0; startFade(E.sigil, 0.9) end
        if E.moon then startFade(E.moon, 1.6) end
        if E.skull then startFade(E.skull, 1.4) end
        if E.heart then E.heart.stop = true end
        if E.hg then E.hg.stop = true end
        A.stopLoop("bossEyesRumble")
    elseif st.kind == "title" then
        if E.crater then startFade(E.crater, 1.8) end
        if E.wisps then startFade(E.wisps, 0.6) end
        if E.spikes then E.spikes.breakAt = E.spikes.t + 0.45 end
        if E.patch then startFade(E.patch, 2.0) end
        if E.bog then startFade(E.bog, 1.4) end
        if E.heart then startFade(E.heart, 1.4) end
        if E.hg then startFade(E.hg, 1.4) end
        if E.pud then startFade(E.pud, 1.4) end
        if E.croots then startFade(E.croots, 1.2) end
    end
end

----------------------------------------------------------------------------
-- update
----------------------------------------------------------------------------

local function tickFade(name, dt)
    local e = E[name]
    if e and e.fade then
        e.fade = e.fade + dt
        if e.fade >= (e.fadeDur or FADE) then E[name] = nil end
    end
end

local function updateColossus(dt, reduced)
    local hg = E.hg
    if hg then
        hg.t = hg.t + dt
        if not hg.stop then
            if hg.i <= #hg.beats and hg.t >= hg.beats[hg.i] then
                hg.i = hg.i + 1
                hgBeat(hg)
            elseif hg.i > #hg.beats and hg.t >= hg.nextAt then
                local c = E.coc
                local every = c and lerp(0.65, 0.3, clamp01(c.t / c.dur)) or hg.every
                hg.nextAt = hg.t + every
                hgBeat(hg)
            end
        end
        tickFade("hg", dt)
    end
    local c = E.coc
    if c then
        c.t = c.t + dt
        local fx_, fy, s, bb = feet()
        if fx_ and c.t < c.rise and not reduced then
            c.dustT = c.dustT - dt
            if c.dustT <= 0 then
                c.dustT = 0.08
                for _, v in ipairs(c.roots) do
                    local x, y = pathAt(v, v.len * easeOut(clamp01(c.t / c.rise)))
                    A.spawnDust(x, y, 1, 10)
                end
            end
        end
        if c.t >= c.rise and not c.grew then
            c.grew = true
            A.play("bossEmergeTear", "sceneStoneThud", 0.6, 0)
            shake(5, 0.3)
            if fx_ then A.spawnDust(fx_, fy, 10, (bb and bb.width) or 120) end
        end
        if c.t >= c.rise + c.grow then
            c.creak = c.creak - dt
            if c.creak <= 0 then
                local q = clamp01((c.t - (c.dur - 0.7)) / 0.7)
                c.creak = lerp(0.45, 0.16, q)
                A.play("colossusCrack", "sceneStoneThud", rnd(0.85, 1.05) + 0.25 * q, 0)
                if fx_ and not reduced then
                    for _ = 1, 2 + math.floor(4 * q) do
                        A.spawnFeather(fx_ + rnd(-30, 30) * s, fy - rnd(30, 130) * s, rnd(-60, 60), rnd(-90, -20), "spore")
                    end
                end
            end
        end
    end
    if E.croots then tickFade("croots", dt) end
    local sp = E.sap
    if sp then
        sp.t = sp.t + dt
        if sp.t > sp.form then
            local fx_, fy = feet()
            if fx_ then
                local q = clamp01((sp.t - sp.form) / math.max(0.05, sp.dur - sp.form))
                table.insert(sp.trail, 1, { sp.x, sp.y })
                if #sp.trail > 8 then table.remove(sp.trail) end
                sp.x = lerp(sp.x0, fx_, smooth(q))
                sp.y = lerp(sp.y0, fy, q * q)
            end
        else
            local k = sp.t / sp.form
            sp.y = sp.y0 + hs() * (2 + 10 * easeOut(k))
        end
    end
    local pd = E.pud
    if pd then
        pd.t = pd.t + dt
        pd.bub = pd.bub - dt
        if pd.bub <= 0 and not pd.fade then
            pd.bub = rnd(0.25, 0.5)
            local fx_, fy, s, bb = feet()
            if fx_ and not reduced then
                A.spawnFeather(fx_ + rnd(-0.4, 0.4) * (bb.width or 120), fy, rnd(-8, 8), rnd(-50, -25), "spore")
            end
        end
        tickFade("pud", dt)
    end
    local g = E.grow
    if g then
        g.t = g.t + dt
        if g.anim then g.anim:update(dt) end
        g.drip = g.drip - dt
        if g.drip <= 0 then
            g.drip = rnd(0.08, 0.18)
            local dx, dy, s, iw, ih, kx, ky = growGeom(g)
            if dx and not reduced then
                local px_, py_ = dx + iw * s / 2, dy + ih * s
                addBit({ x = px_ + rnd(-0.3, 0.3) * iw * s * kx, y = py_ - rnd(0.2, 0.9) * ih * s * ky,
                         vx = rnd(-20, 20), vy = rnd(0, 40), life = 1.0, g = 900, mud = true, sap = true,
                         nodust = true, floor = py_ + 2 * s, s = s })
            end
        end
        g.glug = g.glug - dt
        if g.glug <= 0 then
            g.glug = rnd(0.35, 0.6)
            A.play("shopPotionBubble", nil, rnd(0.45, 0.6), 0)
        end
    end
    if E.gflash then
        E.gflash.t = E.gflash.t + dt
        if E.gflash.t >= 0.5 then E.gflash = nil end
    end
end

local function updateExtra(dt, reduced)
    updateColossus(dt, reduced)
    local fr = E.frost
    if fr then
        fr.t = fr.t + dt
        if fr.t >= fr.life then startFade(fr, 0.8) end
        tickFade("frost", dt)
    end
    local sp = E.spikes
    if sp then
        sp.t = sp.t + dt
        for _, k in ipairs(sp.list) do
            if not k.up and sp.t >= k.delay then
                k.up = true
                local h = 64 * k.sc
                if not reduced then
                    for _ = 1, 4 do
                        A.spawnFeather(k.x + rnd(-8, 8), k.y - rnd(0.2, 0.8) * h, rnd(-60, 60), rnd(-160, -60), "shard")
                    end
                end
                A.spawnDust(k.x, k.y, 3, 24)
            end
        end
        if sp.breakAt and sp.t >= sp.breakAt then breakSpikes(); E.spikes = nil end
    end
    if E.patch then E.patch.t = E.patch.t + dt; tickFade("patch", dt) end
    if E.flare then E.flare.t = E.flare.t + dt; if E.flare.t >= 1.8 then E.flare = nil end end
    if E.boom then E.boom.t = E.boom.t + dt; if E.boom.t >= 0.45 then E.boom = nil end end
    local hw = E.heart
    if hw then
        hw.t = hw.t + dt
        if hw.i <= #hw.beats then
            if hw.t >= hw.beats[hw.i] then hw.i = hw.i + 1; heartBeat(hw) end
        elseif not hw.stop and not hw.fade and hw.t >= hw.nextSlow then
            hw.nextSlow = hw.t + 0.75
            heartBeat(hw)
        end
        for i = #hw.pulses, 1, -1 do
            local p = hw.pulses[i]
            p.t = p.t + dt
            if p.t > 0.8 then table.remove(hw.pulses, i) end
        end
        tickFade("heart", dt)
    end
    local bg = E.bog
    if bg then
        bg.t = bg.t + dt
        bg.glug = bg.glug - dt
        local fx_, fy, s = feet()
        for _, b in ipairs(bg.bubbles) do
            b.t = b.t + dt
            if b.t >= b.dur then
                b.t = -rnd(0.15, 0.6)
                b.dur = rnd(0.35, 0.6)
                if fx_ and not bg.fade then
                    local ps = s * 1.15
                    A.spawnFeather(fx_ + b.u * 128 * ps, fy + 2 * s + b.v * 48 * ps - 4, rnd(-15, 15), rnd(-70, -30), "spore")
                    if bg.glug <= 0 then bg.glug = 0.18; A.play("shopPotionBubble", nil, rnd(0.55, 0.85), 0) end
                end
            end
        end
        tickFade("bog", dt)
    end
    local r = E.rise
    if r then
        r.t = r.t + dt
        if r.anim then r.anim:update(dt) end
        local dx, y, s, floorY = riseGeom(r)
        local fx_, fy, _, bb = feet()
        if dx and fx_ then
            local wdt = bb.width or 120
            r.drip = r.drip - dt
            if not reduced and r.drip <= 0 and y < floorY - 10 then
                r.drip = rnd(0.04, 0.09)
                local vis = floorY - y
                addBit({ x = fx_ + rnd(-0.4, 0.4) * wdt, y = y + vis * rnd(0.1, 0.7), vx = rnd(-30, 30), vy = rnd(-40, 20),
                         life = 1.0, g = 900, mud = true, nodust = true, floor = floorY, s = s })
            end
            r.splash = r.splash - dt
            if r.splash <= 0 then
                r.splash = rnd(0.28, 0.42)
                splash(fx_ + rnd(-0.35, 0.35) * wdt, fy + 3 * s, s * rnd(0.5, 0.75), 0,
                    (love.math.random() < 0.5) and -1 or 1, "mud")
                A.play("shopPotionBubble", nil, rnd(0.6, 0.8), 0)
            end
        end
    end
    if E.lip then E.lip.t = E.lip.t + dt; if E.lip.t >= 0.6 then E.lip = nil end end
end

function Ent.update(dt)
    if not A then return end
    local reduced = A.reduced()
    updateExtra(dt, reduced)
    local sn = E.snuff
    if sn then
        sn.t = sn.t + dt
        for _, c in ipairs(sn.list) do
            if not c.out and sn.t >= c.outAt then
                c.out = sn.t
                A.play("sceneCloudPoof", nil, rnd(0.75, 0.95), 0)
                local x, y = H(c.cx, c.cy - c.ry * 0.3)
                for _ = 1, 7 do A.spawnFeather(x + rnd(-6, 6), y, rnd(-12, 12), rnd(-50, -22), "ash") end
            end
        end
        if sn.relight then
            sn.relight = sn.relight + dt
            if sn.relight >= 0.9 then E.snuff = nil end
        end
    end
    if E.moon then
        local m = E.moon
        m.t = m.t + dt
        local fx_, fy = feet()
        if m.beam and fx_ and not reduced and love.math.random() < dt * 9 then
            local p = love.math.random()
            local wx, wy = H(200, 110)
            A.spawnFeather(lerp(wx, fx_, p) + rnd(-20, 20), lerp(wy, fy, p), rnd(-8, 8), rnd(6, 18), "spore")
        end
        tickFade("moon", dt)
    end
    if E.sigil then
        local sg = E.sigil
        sg.t = sg.t + dt
        if sg.flash then sg.flash = sg.flash + dt end
        tickFade("sigil", dt)
    end
    if E.tomb then
        local tb = E.tomb
        tb.t = tb.t + dt
        local k = tb.t / tb.dur
        while tb.done < #tb.hits and k >= tb.hits[tb.done + 1] do
            tb.done = tb.done + 1
            A.play("bossIceCrackle", nil, 0.95 + tb.done * 0.12, 0)
            if tb.done == #tb.hits then A.queueSfx(0.05, "impactIce", nil, 1.1) end
            shake(3 + tb.done * 2, 0.22)
            local fx_, fy, s = feet()
            if fx_ then
                for _ = 1, 5 + tb.done * 3 do
                    A.spawnFeather(fx_ + rnd(-30, 30) * s, fy - rnd(30, 140) * s,
                        rnd(-140, 140), rnd(-160, -40), "shard")
                end
            end
        end
    end
    if E.glass then
        local g = E.glass
        g.t = g.t + dt
        if not g.burst and g.t >= g.dur * g.at then burstGlass() end
        if g.hole then g.hole = g.hole + dt end
        if g.burst and A.landed() then startFade(g, 1.4) end
        tickFade("glass", dt)
    end
    if E.wisps then
        local wp = E.wisps
        wp.t = wp.t + dt
        if wp.t >= wp.life then startFade(wp, wp.out) end
        tickFade("wisps", dt)
    end
    if E.skull then
        local sk = E.skull
        sk.t = sk.t + dt
        local k = sk.t / sk.dur
        if not sk.eyes and k >= sk.eyesAt then
            sk.eyes = sk.t
            A.play("bossEyesIgnite", nil)
            shake(5, 0.25)
        end
        if not sk.lava and k >= sk.lavaAt then
            sk.lava = sk.t
            A.play("bossLavaImplosion", "impactFire", 0.8, 0)
            shake(8, 0.5)
            InteriorFX.gust(0.8, 0.8)
            local x, y = H(200, 108)
            for _ = 1, 22 do
                A.spawnFeather(x + rnd(-14, 14), y, rnd(-120, 120), rnd(-180, -40), "ember")
            end
        end
        tickFade("skull", dt)
    end
    if E.erupt then
        local er = E.erupt
        er.t = er.t + dt
        if not er.popped then
            local fx_, fy, _, bb = feet()
            if fx_ and not reduced then
                local k = er.t / er.popAt
                if love.math.random() < dt * (6 + 30 * k) then
                    A.spawnFeather(fx_ + rnd(-0.5, 0.5) * (bb.width or 120) * k, fy - rnd(0, 6),
                        rnd(-25, 25), rnd(-120, -50), "ember")
                end
            end
            if er.t >= er.popAt then popErupt() end
        elseif er.anim then
            er.anim:update(dt)
        end
    end
    if E.crater then
        E.crater.t = E.crater.t + dt
        local fx_, fy, _, bb = feet()
        if fx_ and not reduced and love.math.random() < dt * 8 * fadeK(E.crater) then
            A.spawnFeather(fx_ + rnd(-0.45, 0.45) * (bb.width or 120), fy - rnd(0, 4),
                rnd(-15, 15), rnd(-70, -30), "ember")
        end
        tickFade("crater", dt)
    end
    if E.rumble then
        local rb = E.rumble
        rb.t = rb.t + dt
        if rb.t >= rb.next then
            rb.next = rb.next + rb.every * rnd(0.75, 1.25)
            rb.flash = rb.t
            A.play("sceneStoneThud", nil, rnd(0.55, 0.8), 0)
            shake(4 + 4 * (rb.t / rb.dur), 0.22)
            local s = hs()
            for _ = 1, 3 + math.floor(3 * rb.t / rb.dur) do
                local rimg = rockImage()
                local x, y = H(rnd(40, 360), rnd(-12, 0))
                local _, floorY = H(0, rnd(200, 240))
                addBit({ img = rimg, x = x, y = y, ox = rimg and rimg:getWidth() / 2 or 0,
                         oy = rimg and rimg:getHeight() / 2 or 0, s = s * rnd(0.35, 0.7),
                         vx = rnd(-20, 20), vy = rnd(40, 160), rv = rnd(-6, 6), life = 1.6,
                         g = 1100, rock = true, floor = floorY })
            end
        end
        if not reduced and love.math.random() < dt * 30 then
            local x, y = H(rnd(20, 380), -4)
            A.spawnFeather(x, y, rnd(-10, 10), rnd(30, 80), "ash")
        end
    end
    if E.drop then
        E.drop.t = E.drop.t + dt
        if E.drop.anim then E.drop.anim:update(dt) end
    end
    for i = #bits, 1, -1 do
        local b = bits[i]
        b.vy = b.vy + b.g * dt
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.rot = b.rot + b.rv * dt
        b.life = b.life - dt
        if b.grow > 0 then b.k = b.k + b.grow * dt end
        if b.floor and b.y >= b.floor then
            if not b.nodust then A.spawnDust(b.x, b.floor, 3, 30) end
            b.life = 0
        end
        if b.life <= 0 then table.remove(bits, i) end
    end
    for i = #splashes, 1, -1 do
        local sp = splashes[i]
        sp.t = sp.t + dt
        if sp.t >= sp.dur then table.remove(splashes, i) end
    end
end

function Ent.reset()
    E = {}
    bits = {}
    splashes = {}
end

----------------------------------------------------------------------------
-- desenho
----------------------------------------------------------------------------

local function drawSnuff()
    local sn = E.snuff
    if not sn then return end
    local s = hs()
    local tm = love.timer.getTime()
    for _, c in ipairs(sn.list) do
        local x, y = H(c.cx, c.cy)
        if not c.out then
            local fl = 0.86 + 0.14 * math.sin(tm * 11 + c.seed) * math.sin(tm * 7.3 + c.seed * 2)
            reveal(c.cx, c.cy, c.rx, c.ry, 0.95 * fl, { 1, 0.92, 0.80 })
            A.glowBlob(x, y, c.rx * 3.2 * s, c.ry * 2.6 * s, WARM, 0.30 * fl, 1 + math.floor(c.seed) % 3)
        else
            local k = 1 - clamp01((sn.t - c.out) / 0.45)
            if k > 0 then
                reveal(c.cx, c.cy, c.rx * 0.7, c.ry * 0.7, 0.6 * k, { 1, 0.55, 0.35 })
                A.glowBlob(x, y, c.rx * 1.6 * s, c.ry * 1.4 * s, LAVA, 0.35 * k, 2)
            end
        end
        if sn.relight then
            local k = math.sin(clamp01(sn.relight / 0.9) * math.pi)
            A.glowBlob(x, y, c.rx * 3.6 * s, c.ry * 3.0 * s, WARM, 0.45 * k, 3)
        end
    end
end

local function moonK()
    local m = E.moon
    if not m then return 0 end
    local tm = love.timer.getTime()
    return smooth(clamp01(m.t / m.rise)) * fadeK(m) * (0.92 + 0.08 * math.sin(tm * 3.1))
end

local function drawMoon()
    local m = E.moon
    if not m then return end
    local k = moonK()
    local s = hs()
    if m.window then
        reveal(200, 69, 34, 68, 0.95 * k, { 0.72, 0.86, 1.0 })
        reveal(142, 78, 18, 44, 0.55 * k, { 0.66, 0.80, 1.0 })
        reveal(258, 78, 18, 44, 0.55 * k, { 0.66, 0.80, 1.0 })
    end
    local mx, my = H(200, 52)
    A.glowBlob(mx, my, 90 * s, 90 * s, ICE, 0.42 * k, 1)
    A.glowBlob(mx, my, 34 * s, 34 * s, ICE_HI, 0.55 * k, 2)
    if m.beam then
        local fx_, fy, _, bb = feet()
        if fx_ then
            local bk = k * (0.85 + 0.15 * math.sin(love.timer.getTime() * 5.3))
            local wx, wy = H(200, 112)
            for i = 0, 9 do
                local p = i / 9
                local x, y = lerp(wx, fx_, p), lerp(wy, fy - 10 * s, p)
                A.glowBlob(x, y, lerp(26, (bb.width or 120) / s * 0.9, p) * s, 34 * s, ICE, 0.22 * bk, 1 + i % 3)
            end
            A.glowBlob(fx_, fy, (bb.width or 120) * 1.8, 22 * s, ICE_HI, 0.30 * bk, 2)
        end
    end
end

local function drawGlassHole()
    local g = E.glass
    if not g then return end
    local s = hs()
    local tm = love.timer.getTime()
    if not g.burst then
        local k = clamp01(g.t / (g.dur * g.at))
        local flick = (0.6 + 0.4 * math.abs(math.sin(tm * 23))) * k
        reveal(200, 69, 34, 68, 0.9 * flick, { 0.78, 0.70, 1.0 })
        local wx, wy = H(200, 69)
        A.glowBlob(wx, wy, 80 * s, 150 * s, VIOLET, 0.35 * flick, 1)
        return
    end
    -- buraco do vitral: céu de noite com a lua, em pixel
    local a = fadeK(g)
    local P = math.max(1, math.floor(s + 0.5))
    local x0, y0 = H(176, 12)
    local x1, y1 = H(224, 128)
    love.graphics.setColor(0.03, 0.04, 0.10, 0.96 * a)
    love.graphics.rectangle("fill", math.floor(x0), math.floor(y0 + 24 * s), math.floor(x1 - x0), math.floor(y1 - y0 - 24 * s))
    love.graphics.arc("fill", math.floor((x0 + x1) / 2), math.floor(y0 + 24 * s), math.floor((x1 - x0) / 2), math.pi, math.pi * 2, 12)
    local mx, my = H(200, 50)
    love.graphics.setColor(0.86, 0.94, 1.0, a)
    love.graphics.circle("fill", math.floor(mx), math.floor(my), math.floor(13 * s), 16)
    love.graphics.setColor(0.70, 0.82, 0.95, a)
    love.graphics.rectangle("fill", math.floor(mx - 5 * s), math.floor(my - 3 * s), 3 * P, 3 * P)
    love.graphics.rectangle("fill", math.floor(mx + 3 * s), math.floor(my + 4 * s), 2 * P, 2 * P)
    for i = 1, 7 do
        local sx_, sy_ = H(180 + (i * 37) % 40, 70 + (i * 53) % 52)
        local tw = 0.5 + 0.5 * math.sin(tm * 4 + i)
        love.graphics.setColor(0.9, 0.95, 1, a * tw)
        love.graphics.rectangle("fill", math.floor(sx_ / P) * P, math.floor(sy_ / P) * P, P, P)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSigil(front)
    local sg = E.sigil
    if not sg then return end
    local fx_, fy, s = feet()
    if not fx_ then return end
    local a = fadeK(sg)
    local tm = love.timer.getTime()
    local appear = easeOut(clamp01(sg.t / 0.4))
    local img = image("sigil")
    local sc = s * 0.95 * (0.6 + 0.4 * appear)
    if not front then
        if img then
            local iw, ih = img:getDimensions()
            love.graphics.setColor(0.45, 0.45, 0.55, appear * a)
            love.graphics.draw(img, math.floor(fx_), math.floor(fy), 0, sc, sc, iw / 2, ih / 2)
            love.graphics.setBlendMode("add")
            local lit = 0
            for i = 1, sg.n do if sg.t >= sg.ign[i] then lit = lit + 1 end end
            local pulse = (0.35 + 0.45 * lit / sg.n) * (0.8 + 0.2 * math.sin(tm * 6))
            love.graphics.setColor(VIOLET[1], VIOLET[2], VIOLET[3], pulse * appear * a)
            love.graphics.draw(img, math.floor(fx_), math.floor(fy), 0, sc, sc, iw / 2, ih / 2)
            love.graphics.setBlendMode("alpha")
        end
        A.glowBlob(fx_, fy, 150 * sc, 60 * sc, VIOLET, 0.35 * appear * a, 2)
        if sg.t < 0.35 then
            A.glowBlob(fx_, fy, 200 * s, 90 * s, ICE_HI, 0.6 * (1 - sg.t / 0.35), 3)
        end
        if sg.flash then
            local k = 1 - clamp01(sg.flash / 0.5)
            A.glowBlob(fx_, fy - 40 * s, 260 * s, 200 * s, ICE_HI, 0.7 * k, 1)
        end
    end
    -- runas em órbita: atrás quando sin < 0, na frente quando >= 0
    local rx = 128 * sc * 0.6
    local ry = rx * 0.28
    local lift = 26 * s * smooth(clamp01(sg.t / sg.dur))
    local spread = sg.flash and (1 + sg.flash * 2.2) or 1
    for i = 1, sg.n do
        local ang = sg.t * 1.5 + (i - 1) * math.pi * 2 / sg.n
        local depth = math.sin(ang)
        if (depth >= 0) == (front == true) then
            local x = fx_ + math.cos(ang) * rx * spread
            local y = fy - 8 * s - lift + depth * ry * spread + math.sin(tm * 2 + i) * 2 * s
            local rimg = image("assets/sprites/characters/enemies/tower_lich/mechanic/rune_" .. ((i - 1) % 4) .. ".png")
            local lit = sg.t >= sg.ign[i]
            local la = lit and 1 or 0.35
            local rs = s * 0.9 * (0.85 + 0.15 * depth)
            if lit then
                local since = sg.t - sg.ign[i]
                A.glowBlob(x, y, 46 * s, 46 * s, VIOLET, (0.45 + 0.5 * math.max(0, 1 - since * 3)) * a, 1 + i % 3)
            end
            if rimg then
                local iw, ih = rimg:getDimensions()
                love.graphics.setColor(la, la, la, appear * a)
                love.graphics.draw(rimg, math.floor(x), math.floor(y), 0, rs, rs, iw / 2, ih / 2)
                if lit then
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(ICE_HI[1], ICE_HI[2], ICE_HI[3], 0.35 * a)
                    love.graphics.draw(rimg, math.floor(x), math.floor(y), 0, rs, rs, iw / 2, ih / 2)
                    love.graphics.setBlendMode("alpha")
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawTomb(w)
    local tb = E.tomb
    if not tb then return end
    local fx_, fy, s = feet()
    local img = image("ice_tomb")
    if not fx_ then return end
    local tm = love.timer.getTime()
    local k = tb.t / tb.dur
    local up = easeOut(clamp01(k / tb.rise))
    local floorY = math.floor(fy + 4 * s)
    local iw, ih = 96, 160
    if img then iw, ih = img:getDimensions() end
    local x = fx_ - iw * s / 2
    local y = fy + 4 * s - ih * s * up
    local glow = 0.18 + 0.22 * tb.done + 0.1 * math.sin(tm * 9)
    A.glowBlob(fx_, y + ih * s * 0.5, iw * s * 1.8, ih * s * 1.1, ICE, (0.25 + 0.1 * tb.done) * up, 1)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, 0, w, floorY)
    if img then
        love.graphics.setColor(0.9, 0.95, 1, 1)
        love.graphics.draw(img, math.floor(x), math.floor(y), 0, s, s)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(ICE[1], ICE[2], ICE[3], glow)
        love.graphics.draw(img, math.floor(x), math.floor(y), 0, s, s)
        love.graphics.setBlendMode("alpha")
    end
    local P = math.max(1, math.floor(s + 0.5))
    for lvl = 1, tb.done do
        for _, pts in ipairs(tb.cracks[lvl]) do
            for j = 1, #pts - 1 do
                love.graphics.setColor(ICE_HI[1], ICE_HI[2], ICE_HI[3], 0.95)
                drawPixelLine(x + pts[j][1] * s, y + pts[j][2] * s, x + pts[j + 1][1] * s, y + pts[j + 1][2] * s, P)
            end
        end
    end
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    if tb.done > 0 then
        A.glowBlob(fx_, y + ih * s * 0.45, iw * s * 0.9, ih * s * 0.7, ICE_HI, 0.12 * tb.done, 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawWisps(front)
    local wp = E.wisps
    if not wp then return end
    local img = image("wisp")
    local st = A.stage()
    local bb = st and st.bbox
    if not bb then return end
    local s = hs()
    local _, _, bs = A.footInfo()
    bs = bs or s
    local p = smooth(clamp01(wp.t / wp.life))
    local sx_, sy_ = H(200, 56)
    local cx = lerp(sx_, bb.cx, p)
    local cy = lerp(sy_, bb.topY + (bb.bottomY - bb.topY) * 0.5, p)
    local a = fadeK(wp) * smooth(clamp01(wp.t / 0.4))
    local out = wp.fade and (1 + wp.fade * 3) or 1
    local rx = (bb.width or 120) * 0.75 * out
    local ry = rx * 0.32
    for i = 1, wp.n do
        local ang = wp.t * 2.3 + (i - 1) * math.pi * 2 / wp.n
        local depth = math.sin(ang)
        if (depth >= 0) == (front == true) then
            local x = cx + math.cos(ang) * rx
            local y = cy + depth * ry + math.sin(wp.t * 3 + i * 1.3) * 10 * s - (i % 3 - 1) * 18 * s
            local sc = bs * 0.7 * (0.85 + 0.2 * depth)
            A.glowBlob(x, y, 40 * sc, 40 * sc, ICE, 0.35 * a, 1 + i % 3)
            if img then
                local iw, ih = img:getDimensions()
                local dir = -math.sin(ang) >= 0 and 1 or -1
                love.graphics.setColor(1, 1, 1, a * (0.75 + 0.25 * depth))
                love.graphics.draw(img, math.floor(x), math.floor(y), 0, sc * dir, sc, iw / 2, ih / 2)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSkull()
    local sk = E.skull
    if not sk then return end
    local s = hs()
    local tm = love.timer.getTime()
    local a = fadeK(sk)
    local k = clamp01(sk.t / sk.dur)
    local throb = 0.75 + 0.25 * math.sin(tm * 7)
    reveal(200, 72, 50, 46, math.min(1, k * 1.6) * 0.6 * throb * a, { 1, 0.58, 0.42 })
    if sk.eyes then
        local e = easeOut(clamp01((sk.t - sk.eyes) / 0.25)) * a
        local fl = 0.85 + 0.15 * math.sin(tm * 17)
        for _, ex in ipairs({ 185, 215 }) do
            local x, y = H(ex, 57)
            A.glowBlob(x, y, 30 * s, 22 * s, LAVA, 0.75 * e * fl, 1)
            A.glowBlob(x, y, 10 * s, 7 * s, LAVA_HI, 0.95 * e * fl, 2)
        end
        if sk.t - sk.eyes < 0.3 then
            local x, y = H(200, 57)
            A.glowBlob(x, y, 120 * s, 50 * s, LAVA_HI, 0.6 * (1 - (sk.t - sk.eyes) / 0.3) * a, 3)
        end
    end
    if sk.lava then
        local e = easeOut(clamp01((sk.t - sk.lava) / 0.35)) * a
        local surge = 0.8 + 0.2 * math.sin(tm * 9)
        reveal(200, 140, 22, 52, 0.95 * e * surge, { 1, 0.9, 0.75 })
        reveal(143, 164, 22, 28, 0.8 * e * surge, { 1, 0.85, 0.7 })
        reveal(257, 164, 22, 28, 0.8 * e * surge, { 1, 0.85, 0.7 })
        local x, y = H(200, 140)
        A.glowBlob(x, y, 60 * s, 120 * s, LAVA, 0.5 * e * surge, 1)
        local mx, my = H(200, 106)
        A.glowBlob(mx, my, 50 * s, 24 * s, LAVA_HI, 0.7 * e * surge, 2)
    end
end

local function drawRumble()
    local rb = E.rumble
    if not (rb and rb.flash) then return end
    local s = hs()
    local k = 1 - clamp01((rb.t - rb.flash) / 0.35)
    local grow = 0.4 + 0.6 * clamp01(rb.t / rb.dur)
    if k <= 0 then return end
    reveal(200, 120, 40, 70, 0.75 * k * grow, { 1, 0.6, 0.4 })
    local x, y = H(200, 106)
    A.glowBlob(x, y, 90 * s, 50 * s, LAVA, 0.45 * k * grow, 1)
    for _, ex in ipairs({ 185, 215 }) do
        local ex_, ey = H(ex, 57)
        A.glowBlob(ex_, ey, 16 * s, 12 * s, LAVA_HI, 0.8 * k * grow, 2)
    end
end

local function drawCrater()
    local cr = E.crater
    if not cr then return end
    local fx_, fy, s = feet()
    if not fx_ then return end
    local a = fadeK(cr)
    local pop = easeOut(clamp01(cr.t / 0.18))
    local img = image("crater")
    local tm = love.timer.getTime()
    A.glowBlob(fx_, fy, 220 * s, 60 * s, LAVA, 0.45 * a * (0.85 + 0.15 * math.sin(tm * 6)), 1)
    if img then
        local iw, ih = img:getDimensions()
        local sc = s * (0.7 + 0.3 * pop)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(img, math.floor(fx_), math.floor(fy + 2 * s), 0, sc, sc, iw / 2, ih / 2)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(LAVA[1], LAVA[2], LAVA[3], 0.3 * a * (0.7 + 0.3 * math.sin(tm * 8)))
        love.graphics.draw(img, math.floor(fx_), math.floor(fy + 2 * s), 0, sc, sc, iw / 2, ih / 2)
        love.graphics.setBlendMode("alpha")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawEruptPre()
    local er = E.erupt
    if not er or er.popped then return end
    local fx_, fy, s, bb = feet()
    if not fx_ then return end
    local k = clamp01(er.t / er.popAt)
    local tm = love.timer.getTime()
    local fl = 0.8 + 0.2 * math.sin(tm * 21)
    A.glowBlob(fx_, fy, (bb.width or 120) * (0.6 + 1.4 * k), 30 * s * (0.5 + k), LAVA, 0.65 * k * fl, 1)
    A.glowBlob(fx_, fy - 4 * s, (bb.width or 120) * 0.6 * k, 12 * s, LAVA_HI, 0.6 * k * fl, 2)
end

local function drawEruptActor(w)
    local er = E.erupt
    if not (er and er.popped and er.anim) then return end
    local dx, dy, s = A.footInfo()
    local st = A.stage()
    if not dx then return end
    local k = clamp01((er.t - er.popAt) / math.max(0.05, er.dur - er.popAt))
    local e = easeOut(k)
    local _, ih = er.anim:getSize()
    local sh = ih * s
    local y = dy + sh * 0.85 * (1 - e)
    local floorY = math.floor((st.cy or (dy + sh)) + 3 * s)
    local hot = 1 - e
    A.drawBondAt(dx, y, s, er.anim, er.clip)
    local sx, sy, sw, shh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, 0, w, floorY)
    A.drawOwn(er.anim, dx, y, s, { 1, 1 - 0.45 * hot, 1 - 0.7 * hot, 1 }, 0.45 * hot + 0.06)
    if sx then love.graphics.setScissor(sx, sy, sw, shh) else love.graphics.setScissor() end
end

local function drawDropActor()
    local dp = E.drop
    if not (dp and dp.anim) then return end
    local dx, dy, s = A.footInfo()
    if not dx then return end
    local iw, ih = dp.anim:getSize()
    local sh = ih * s
    local fx_, fy = feet()
    local k = clamp01(dp.t / dp.dur)
    local y0 = -sh - 30
    local function yAt(q) return lerp(y0, dy, q * q) end
    -- sombra crescendo no chão
    if fx_ then
        love.graphics.setColor(0, 0, 0, 0.45 * k)
        love.graphics.ellipse("fill", math.floor(fx_), math.floor(fy), iw * s * 0.35 * (0.4 + 0.6 * k), math.max(3, iw * s * 0.06))
        A.glowBlob(fx_, fy, iw * s * 1.4, 26 * s, LAVA, 0.35 * k, 2)
    end
    local P = math.max(1, math.floor(s + 0.5))
    local y = yAt(k)
    for i = 1, 6 do
        local lx = dx + iw * s * (0.15 + 0.7 * ((i * 0.37) % 1))
        local len = (120 + 60 * (i % 3)) * k
        love.graphics.setColor(LAVA_HI[1], LAVA_HI[2], LAVA_HI[3], 0.35)
        love.graphics.rectangle("fill", math.floor(lx / P) * P, math.floor(y - len), P, math.floor(len))
    end
    for g = 3, 1, -1 do
        local q = math.max(0, k - g * 0.07)
        if q > 0 then
            love.graphics.setBlendMode("add")
            dp.anim:draw(dx, yAt(q), s, { LAVA[1], LAVA[2] * 0.6, LAVA[3] * 0.4, 0.28 / g })
            love.graphics.setBlendMode("alpha")
        end
    end
    A.drawBondAt(dx, y, s, dp.anim, nil)
    A.drawOwn(dp.anim, dx, y, s, { 1, 1, 1, 1 }, 0.2)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSplashes()
    for _, sp in ipairs(splashes) do
        if sp.t >= 0 then
            local sapK = sp.kind == "sap"
            local mud = sp.kind == "mud" or sapK
            local img = image(mud and "mud_splash" or "lava_splash")
            local col = mud and GREEN or LAVA
            local k = sp.t / sp.dur
            local sy = easeOut(clamp01(k * 3))
            local a = 1 - clamp01((k - 0.45) / 0.55)
            if img then
                local iw, ih = img:getDimensions()
                if sapK then love.graphics.setColor(0.40, 0.78, 0.30, a)
                elseif mud then love.graphics.setColor(0.62, 0.66, 0.40, a) else love.graphics.setColor(1, 1, 1, a) end
                love.graphics.draw(img, math.floor(sp.x), math.floor(sp.y), 0, sp.s * sp.sx, sp.s * sy, iw / 2, ih)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(col[1], col[2], col[3], (sapK and 0.35 or mud and 0.12 or 0.4) * a)
                love.graphics.draw(img, math.floor(sp.x), math.floor(sp.y), 0, sp.s * sp.sx, sp.s * sy, iw / 2, ih)
                love.graphics.setBlendMode("alpha")
            else
                A.glowBlob(sp.x, sp.y - 30 * sp.s, 60 * sp.s, 70 * sp.s * sy, col, 0.6 * a, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawBits(over)
    local P = A.px()
    over = over or false
    for _, b in ipairs(bits) do
        if (b.over or false) == over then
            local a = clamp01(b.life / b.max * 2)
            local x, y = math.floor(b.x / P) * P, math.floor(b.y / P) * P
            local rot = math.floor(b.rot / (math.pi / 8) + 0.5) * (math.pi / 8)
            if b.img then
                local sc = b.s * b.k
                local sx, sy = sc * (b.fx or 1), sc * (b.fy or 1)
                love.graphics.setColor(1, 1, 1, a)
                if b.quad then
                    love.graphics.draw(b.img, b.quad, x, y, rot, sx, sy, b.ox, b.oy)
                    local glow = (b.glass and VIOLET) or (b.ice and ICE) or nil
                    if glow then
                        love.graphics.setBlendMode("add")
                        love.graphics.setColor(glow[1], glow[2], glow[3], 0.35 * a)
                        love.graphics.draw(b.img, b.quad, x, y, rot, sx, sy, b.ox, b.oy)
                        love.graphics.setBlendMode("alpha")
                    end
                else
                    love.graphics.draw(b.img, x, y, rot, sx, sy, b.ox, b.oy)
                end
            elseif b.rock then
                love.graphics.push()
                love.graphics.translate(x, y)
                love.graphics.rotate(rot)
                love.graphics.setColor(0.16, 0.10, 0.09, a)
                love.graphics.rectangle("fill", -2 * P, -P, 4 * P, 3 * P)
                love.graphics.setColor(LAVA[1], LAVA[2], LAVA[3], a)
                love.graphics.rectangle("fill", P, -P, P, P)
                love.graphics.pop()
            elseif b.mud and b.sap then
                love.graphics.setColor(0.16, 0.42, 0.10, a)
                love.graphics.rectangle("fill", x - P, y - P, 2 * P, 2 * P)
                love.graphics.setColor(SAP[1], SAP[2], SAP[3], a)
                love.graphics.rectangle("fill", x - P, y - P, P, P)
            elseif b.mud then
                love.graphics.setColor(MUD[1], MUD[2], MUD[3], a)
                love.graphics.rectangle("fill", x - P, y - P, 2 * P, 2 * P)
                love.graphics.setColor(GREEN[1] * 0.6, GREEN[2] * 0.6, GREEN[3] * 0.4, a)
                love.graphics.rectangle("fill", x - P, y - P, P, P)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawFrostRim(w, h)
    local fr = E.frost
    if not fr then return end
    local img = image(FROST_PATH)
    if not img then return end
    local _, ih = img:getDimensions()
    local sc = frostScale(fr, ih, w, h)
    local a = fadeK(fr) * clamp01(fr.t / 0.25)
    local pulse = 0.18 + 0.12 * math.sin(fr.t * 5)
    for _, c in ipairs(frostCorners(w, h)) do
        love.graphics.setColor(1, 1, 1, a * 0.92)
        love.graphics.draw(img, c[1], c[2], 0, sc * c[3], sc * c[4], 0, ih)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(ICE[1], ICE[2], ICE[3], a * pulse)
        love.graphics.draw(img, c[1], c[2], 0, sc * c[3], sc * c[4], 0, ih)
        love.graphics.setBlendMode("alpha")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawSpikes(front)
    local sp = E.spikes
    if not sp then return end
    local img = image(SPIKE_PATH)
    local P = A.px()
    local tremble = sp.breakAt and sp.t > sp.breakAt - 0.3
    for _, k in ipairs(sp.list) do
        if k.front == front and k.up then
            local age = sp.t - k.delay
            local q = clamp01(age / 0.14)
            local sy = easeOut(q) * (1 + 0.22 * math.sin(q * math.pi))
            local hot = 1 - clamp01(age / 0.5)
            local x, y = math.floor(k.x), math.floor(k.y)
            if tremble then x = x + love.math.random(-1, 1) * P end
            if img then
                local iw, ih = img:getDimensions()
                A.glowBlob(x, y - ih * k.sc * 0.4 * sy, iw * k.sc * 2.2, ih * k.sc * 1.2 * sy, ICE, 0.16 + 0.4 * hot, 1)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, x, y, 0, k.sc * k.flip, k.sc * sy, iw / 2, ih)
                if hot > 0 then
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(ICE_HI[1], ICE_HI[2], ICE_HI[3], 0.8 * hot)
                    love.graphics.draw(img, x, y, 0, k.sc * k.flip, k.sc * sy, iw / 2, ih)
                    love.graphics.setBlendMode("alpha")
                end
            else
                A.glowBlob(x, y - 30 * k.sc, 20 * k.sc, 60 * k.sc * sy, ICE_HI, 0.8, 1)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPatch()
    local pt = E.patch
    if not pt then return end
    local fx_, fy, s = feet()
    if not fx_ then return end
    local g = easeOut(clamp01(pt.t / 0.35))
    local a = fadeK(pt)
    local img = iceOnlyPatch()
    A.glowBlob(fx_, fy, 170 * s * g, 44 * s * g, ICE, 0.35 * a, 2)
    if img then
        local iw, ih = img:getDimensions()
        local sc = s * 1.1 * g
        love.graphics.setColor(1, 1, 1, 0.95 * a)
        love.graphics.draw(img, math.floor(fx_), math.floor(fy + 2 * s), 0, sc, sc, iw / 2, ih / 2)
        love.graphics.setBlendMode("add")
        love.graphics.setColor(ICE[1], ICE[2], ICE[3], 0.3 * a)
        love.graphics.draw(img, math.floor(fx_), math.floor(fy + 2 * s), 0, sc, sc, iw / 2, ih / 2)
        love.graphics.setBlendMode("alpha")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- As chamas do salão viram fogo-frio azul por um instante.
local function drawFlare()
    local fl = E.flare
    if not fl then return end
    local k = 1 - clamp01(fl.t / 1.8)
    if k <= 0 then return end
    local stg = A.stage()
    local cfg = InteriorFX.HALLS[(stg and stg.hall) or 2]
    local s = hs()
    for _, f in ipairs((cfg and cfg.flames) or {}) do
        local cx, cy = f[1] + f[3] / 2, f[2] + f[4] * 0.5
        reveal(cx, cy, 34, 30, 0.9 * k, ICE)
        local x, y = H(cx, cy)
        A.glowBlob(x, y, 60 * s, 50 * s, ICE, 0.5 * k, 1)
    end
end

local function drawBoom(w, h)
    local b = E.boom
    if not b then return end
    local k = clamp01(b.t / 0.45)
    local fx_, fy, s = feet()
    if not fx_ then return end
    A.glowBlob(fx_, fy - 30 * s, w * (0.6 + 0.8 * k), h * (0.35 + 0.5 * k), ICE_HI, 0.7 * (1 - k), 1)
end

local function drawHeartWake()
    local hw = E.heart
    if not hw then return end
    local a = fadeK(hw)
    local env = math.max(0, 1 - (hw.t - hw.last) / 0.35)
    local base = clamp01(hw.t / 0.6)
    reveal(HEART[1], HEART[2], 46, 62, (0.30 + 0.35 * base + 0.35 * env) * a, { 0.75, 1.0, 0.65 }, 1 + 0.07 * env)
    local hx, hy = H(HEART[1], HEART[2])
    local s = hs()
    A.glowBlob(hx, hy, 110 * s * (1 + 0.15 * env), 130 * s * (1 + 0.15 * env), GREEN, (0.12 + 0.3 * env) * a, 1)
    local P = A.px()
    local grow = easeOut(clamp01(hw.t / (hw.dur * 0.85)))
    for _, v in ipairs(hw.veins) do
        local upto = v.len * grow
        local pts = {}
        for d = 0, upto, P do
            local x, y = pathAt(v, d)
            local th = math.max(1, math.floor(lerp(3, 1, d / math.max(1, v.len)) + 0.5))
            pts[#pts + 1] = { math.floor(x / P) * P, math.floor(y / P) * P, th }
        end
        love.graphics.setColor(0.04, 0.03, 0.02, a)
        for _, p in ipairs(pts) do love.graphics.rectangle("fill", p[1] - P, p[2] - P, (p[3] + 2) * P, (p[3] + 2) * P) end
        love.graphics.setColor(BARK[1], BARK[2], BARK[3], a)
        for _, p in ipairs(pts) do love.graphics.rectangle("fill", p[1], p[2], p[3] * P, p[3] * P) end
        local core = 0.35 + 0.5 * env
        for i, p in ipairs(pts) do
            if p[3] > 1 then
                love.graphics.setColor(BARK_HI[1], BARK_HI[2], BARK_HI[3], a)
                love.graphics.rectangle("fill", p[1], p[2], P, P)
                love.graphics.setColor(GREEN[1] * core, GREEN[2] * core, GREEN[3] * core, a)
                love.graphics.rectangle("fill", p[1] + P, p[2] + P, P, P)
            end
            if i % 8 == 0 then A.glowBlob(p[1], p[2], 22 * s, 16 * s, GREEN, (0.06 + 0.12 * env) * a, 1) end
        end
    end
    for _, p in ipairs(hw.pulses) do
        local q = p.t / 0.55
        local reach = p.v.len * grow
        if q <= 1 then
            local d = reach * q
            local x, y = pathAt(p.v, d)
            A.glowBlob(x, y, 26 * s, 26 * s, GREEN, 0.55 * a, 1)
            for j = 0, 3 do
                local tx, ty = pathAt(p.v, d - j * P * 2)
                love.graphics.setColor(SAP[1], SAP[2], SAP[3], a * (1 - j * 0.25))
                love.graphics.rectangle("fill", math.floor(tx / P) * P, math.floor(ty / P) * P, 2 * P, 2 * P)
            end
        else
            local x, y = pathAt(p.v, reach)
            A.glowBlob(x, y, 40 * s, 20 * s, GREEN, 0.5 * (1 - (q - 1) / 0.45) * a, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function bogGeom(bg)
    local fx_, fy, s = feet()
    if not fx_ then return nil end
    local g = easeOut(clamp01(bg.t / bg.grow))
    local a = fadeK(bg)
    local ps = s * 1.15 * (0.12 + 0.88 * g) * (0.6 + 0.4 * a)
    return math.floor(fx_), math.floor(fy + 2 * s), ps, g, a
end

local function drawBubbles(bg, cx, cy, ps, g, a, cut)
    local P = A.px()
    for _, b in ipairs(bg.bubbles) do
        if b.t > 0 and g > 0.6 then
            local q = b.t / b.dur
            local r = math.max(P, math.floor((1 + 2 * q) * ps / 1.2))
            local bx = math.floor((cx + b.u * 128 * ps) / P) * P
            local by = math.floor((cy + b.v * 48 * ps) / P) * P
            if not cut or by >= cut then
                love.graphics.setColor(MUD[1] * 1.6, MUD[2] * 1.8, MUD[3] * 1.2, a)
                love.graphics.rectangle("fill", bx - r, by - 2 * r, 2 * r, 2 * r)
                love.graphics.setColor(SAP[1], SAP[2], SAP[3], 0.8 * a)
                love.graphics.rectangle("fill", bx - r + P, by - 2 * r + P, P, P)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawBog()
    local bg = E.bog
    if not bg then return end
    local cx, cy, ps, g, a = bogGeom(bg)
    if not cx then return end
    local img = image("bog_pool")
    A.glowBlob(cx, cy, 128 * ps * 1.5, 48 * ps * 1.4, GREEN, (0.22 + 0.1 * math.sin(bg.t * 6)) * a, 2)
    if img then
        local iw, ih = img:getDimensions()
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(img, cx, cy, 0, ps, ps, iw / 2, ih / 2)
    end
    drawBubbles(bg, cx, cy, ps, g, a)
end

local function drawRise(w)
    local r = E.rise
    if not (r and r.anim) then return end
    local dx, y, s, floorY, k = riseGeom(r)
    if not dx then return end
    local mud = 1 - smooth(k)
    local tint = { lerp(1, 0.42, mud), lerp(1, 0.50, mud), lerp(1, 0.26, mud), 1 }
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, 0, w, floorY)
    A.drawOwn(r.anim, dx, math.floor(y), s, tint, 0.10 + 0.3 * mud)
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
end

-- Borda da frente: a metade de baixo da poça redesenhada na frente dele,
-- então ele sobe "de dentro" da lama (e o corte reto some).
local function lipCut(cy, ps)
    return math.floor(cy - 3 * ps)
end

local function drawLip()
    local a
    if E.rise then a = 1 elseif E.lip then a = 1 - clamp01(E.lip.t / 0.6) else return end
    local bg = E.bog
    if a <= 0 or not bg then return end
    local cx, cy, ps, g, ba = bogGeom(bg)
    local img = image("bog_pool")
    if not (cx and img) then return end
    local iw, ih = img:getDimensions()
    local cut = lipCut(cy, ps)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.intersectScissor(0, cut, lastW * 2, lastH * 2)
    love.graphics.setColor(1, 1, 1, a * ba)
    love.graphics.draw(img, cx, cy, 0, ps, ps, iw / 2, ih / 2)
    if sx then love.graphics.setScissor(sx, sy, sw, sh) else love.graphics.setScissor() end
    drawBubbles(bg, cx, cy, ps, g, a * ba, cut)
end

-- Fundo: depois da escuridão, antes do chefe.
function Ent.drawBack(w, h)
    if not A then return end
    drawSnuff()
    drawGlassHole()
    drawMoon()
    drawSkull()
    drawRumble()
    drawCrater()
    drawEruptPre()
    drawSigil(false)
    drawFlare()
    drawHeartWake()
    drawBog()
    drawHeartGlow()
    drawCRoots()
    drawPuddle()
    drawPatch()
    drawSpikes(false)
end

-- Atores: o chefe ainda escondido desenhado por nós (túmulo, erupção, queda).
function Ent.drawActors(w, h)
    if not A then return end
    drawWisps(false)
    drawTomb(w)
    drawEruptActor(w)
    drawDropActor()
    drawRise(w)
    drawCocoon()
    drawGrow()
    drawSap()
end

-- Frente: tudo que passa na frente do chefe.
function Ent.drawFront()
    if not A then return end
    drawSigil(true)
    drawWisps(true)
    drawLip()
    drawSplashes()
    drawBits(false)
end

-- Por cima de tudo (depois da silhueta): geada nas bordas, espinhos da frente, cacos.
function Ent.drawOver(w, h)
    if not A then return end
    lastW, lastH = w, h
    drawFrostRim(w, h)
    drawSpikes(true)
    drawBits(true)
    drawBoom(w, h)
    drawGFlash(w, h)
end

return Ent
