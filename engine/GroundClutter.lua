local DATA = require("src.data.ground_clutter")
local GrassField = require("engine.GrassField")
local ShadowEngine = require("engine.ShadowEngine")
local Grade = require("engine.SceneGrade")
local Contact = require("engine.ContactShadow")
local Var = require("engine.PropVariation")
local LightSpill = require("engine.LightSpill")

local GroundClutter = { DATA = DATA, stats = { listed = 0 }, enabled = true }

local pool = {}
local backPool = {}
local col = {}
local weights = setmetatable({}, { __mode = "k" })

local function hash01(n)
    local v = math.sin(n * 12.9898 + 78.233) * 43758.5453
    return v - math.floor(v)
end
GroundClutter.hash01 = hash01

local function pick(list, r)
    local tot = weights[list]
    if not tot then
        tot = 0
        for i = 1, #list do tot = tot + (list[i].w or 1) end
        weights[list] = tot
    end
    r = r * tot
    for i = 1, #list do
        r = r - (list[i].w or 1)
        if r <= 0 then return list[i] end
    end
    return list[#list]
end

function GroundClutter.entries(bid) return DATA.biomes[bid] end

function GroundClutter.casts(e) return e.solid or e.cast or false end
function GroundClutter.contacts(e) return e.solid or e.contact or false end

function GroundClutter.persp(t)
    return 0.14 + 0.86 * (t ^ 1.65)
end

function GroundClutter.scale(e, t, env)
    return e.k * env.pixRef * env.screenK * GroundClutter.persp(t)
end


local function cell(hs, list, bid, env)
    if hash01(hs * 1.37 + 0.11) >= DATA.chance then return nil end
    local e = pick(list, hash01(hs * 5.77 + 0.53))
    local v = math.floor(hash01(hs * 11.3 + 0.29) * (e.n or 1))
    local img = env.getSprite(e.kind, v, bid)
    return e, v, img
end

local function lateral(hs, z, t, side, env)
    local half = env.roadHalfK * env.w * (0.30 + 0.70 * (t ^ 1.15))
    local u = DATA.uMin + hash01(hs * 7.13 + 0.71) * (DATA.uMax - DATA.uMin)
    return env.g.cx + env.wobble(z, t, env.w) + side * half * u, half
end

local function fill(p, z, side, bid, e, img, v, hs, env)
    local pv = Var.of(hs * 0.913 + 0.37, "clutter", DATA.variation)
    p.z, p.side, p.bid, p.e, p.img, p.v = z, side, bid, e, img, v
    p.variant = bid
    p.ph = hs * 1.7
    p.vs = 1 + (pv.scale - 1) * (e.solid and 1 or 0.6)
    p.tr, p.tg, p.tb = pv.tintR, pv.tintG, pv.tintB
    local fb = hash01(hs * 9.91 + 0.19) < 0.5 and -1 or 1
    p.flip = env.flipToSun(img, env.sunRight, fb)
    p.wph = pv.windPhase
end

local function biomeList(env)
    local L = env._bl or {}
    env._bl = L
    L[1], L[2], L[3], L[4] = env.bid, 1, nil, nil
    if env.bidPrev and env.bidPrev ~= env.bid and (env.bidK or 1) < 1 then
        L[2] = env.bidK
        L[3], L[4] = env.bidPrev, 1 - env.bidK
    end
    return L
end

function GroundClutter.collect(out, env)
    local st = GroundClutter.stats
    st.listed, st.left, st.right, st.worst, st.roadGap = 0, 0, 0, 0, math.huge
    if not GroundClutter.enabled then return 0 end
    local g, w, x, camZ = env.g, env.w, env.x, env.camZ
    local C = DATA.cell
    local relMax = env.relCrest
    local hand = env.hand
    local H = math.max(g.bottomY, love.graphics.getHeight())
    local BL = biomeList(env)
    local n = 0
    for bi = 1, 3, 2 do
        local bid, bk = BL[bi], BL[bi + 1]
        local list = bid and bk and bk > 0.001 and DATA.biomes[bid]
        if list then
            for ci = math.floor((camZ + DATA.relMin) / C), math.floor((camZ + relMax) / C) do
                for side = -1, 1, 2 do
                    local hs = ci * 2 + (side > 0 and 1 or 0)
                    local e, v, img = cell(hs, list, bid, env)
                    if img then
                        local z = (ci + hash01(hs * 3.11 + 0.37)) * C
                        local rel = z - camZ
                        local t = rel >= DATA.relMin and rel <= relMax
                            and (rel >= 0 and g.tOf(rel) or (1 - rel / env.relCrest) ^ env.tPow)
                        if t then
                            local px, half = lateral(hs, z, t, side, env)
                            n = n + 1
                            local p = pool[n]
                            if not p then p = { clutter = true, kind = "clutter", lane = 0 }; pool[n] = p end
                            fill(p, z, side, bid, e, img, v, hs, env)
                            local s = GroundClutter.scale(e, t, env) * p.vs
                            local iw, ih = img:getWidth(), img:getHeight()
                            local hw = iw * s * 0.5
                            local pad = w * DATA.edgePad
                            local py = g.latY(px - g.cx, t)
                            local top = py + (e.sink or 0) * s - ih * s
                            if px + hw < x - pad or px - hw > x + w + pad or top > H + 12 then
                                n = n - 1
                            else
                                local hk = 0
                                if hand and py - ih * s < hand.y + DATA.handPad
                                   and px + hw > hand.x1 and px - hw < hand.x2 then
                                    hk = env.handK or 1
                                end
                                local fz = env.forkK and env.forkK(px, rel, t, hw) or 0
                                local ck = env.castleK and env.castleK(px, t) or 0
                                p.px, p.py, p.s, p.t, p.rel = px, py, s, t, rel
                                p.fk = bk * (1 - fz) * (1 - hk) * (1 - ck)
                                out[#out + 1] = p
                                if t >= DATA.tFore and hk == 0 and top <= g.bottomY + 2 then
                                    if side < 0 then st.left = st.left + 1 else st.right = st.right + 1 end
                                    st.worst = math.max(st.worst, s / (env.pixRef * env.screenK))
                                    st.roadGap = math.min(st.roadGap, math.abs(px - g.cx - env.wobble(z, t, w)) - hw - half)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    st.listed = n
    return n
end

function GroundClutter.collectBehind(out, env)
    if not GroundClutter.enabled then return 0 end
    local g, w, camZ = env.g, env.w, env.camZ
    local C = DATA.cell
    local r0, r1 = env.relCrest, env.relCrest + env.band
    local BL = biomeList(env)
    local n = 0
    for bi = 1, 3, 2 do
        local bid, bk = BL[bi], BL[bi + 1]
        local list = bid and bk and bk > 0.001 and DATA.biomes[bid]
        if list then
            for ci = math.floor((camZ + r0) / C), math.floor((camZ + r1) / C) do
                for side = -1, 1, 2 do
                    local hs = ci * 2 + (side > 0 and 1 or 0)
                    local e, v, img = cell(hs, list, bid, env)
                    if img then
                        local z = (ci + hash01(hs * 3.11 + 0.37)) * C
                        local rel = z - camZ
                        if rel > r0 and rel <= r1 then
                            local px = lateral(hs, z, 0, side, env)
                            if math.abs(px - g.cx) < w * 0.26 then
                                n = n + 1
                                local p = backPool[n]
                                if not p then p = { clutter = true, kind = "clutter", lane = 0 }; backPool[n] = p end
                                fill(p, z, side, bid, e, img, v, hs, env)
                                p.px, p.t, p.rel = px, 0, rel
                                p.s = GroundClutter.scale(e, 0, env) * p.vs
                                p.em = 1 - (rel - r0) / env.band
                                local fz = env.forkK and env.forkK(px, rel, 0, img:getWidth() * p.s * 0.5) or 0
                                local ck = env.castleK and env.castleK(px, 0) or 0
                                p.fk = bk * (1 - fz) * (1 - ck)
                                out[#out + 1] = p
                            end
                        end
                    end
                end
            end
        end
    end
    return n
end

local function setTone(c, p, a)
    love.graphics.setColor(math.min(1, c[1] * p.tr), math.min(1, c[2] * p.tg), math.min(1, c[3] * p.tb), a)
end

function GroundClutter.drawBehind(p, env)
    local e, img, s = p.e, p.img, p.s
    local a = p.fk or 1
    local iw, ih = img:getWidth(), img:getHeight()
    local crest = env.g.crestYAt(p.px)
    local by = crest + ((e.sink or 0) + (1 - p.em) * ih) * s
    if a <= 0.01 then
        if env.seq then env.seq("clutter", p, 0, p.px, by, iw * s, ih * s, 0, crest) end
        return
    end
    local rot = 0
    if e.sway and not env.reduced then
        rot = math.sin(env.time * 2.3 + p.ph + (p.wph or 0)) * e.sway
    end
    local c = Grade.color(e.family or "prop", 0, col)
    setTone(c, p, a)
    local fr = not env.reduced and env.frames and env.frames(p.bid, e.kind, p.v)
    love.graphics.draw(fr and env.frameOf(fr, hash01(p.ph)) or img, math.floor(p.px), math.floor(by),
        rot, s * p.flip, s, iw / 2, ih)
    if env.seq then env.seq("clutter", p, 0, p.px, by, iw * s, ih * s, a, crest) end
end

function GroundClutter.draw(p, env)
    local e, img, s, t = p.e, p.img, p.s, p.t
    local a = p.fk or 1
    local iw, ih = img:getWidth(), img:getHeight()
    local px, py, flip = math.floor(p.px), math.floor(p.py), p.flip
    local sink = (e.sink or 0) * s
    if a <= 0.01 then
        if env.seq then env.seq("clutter", p, 0, px, py + sink, iw * s, ih * s, 0) end
        return
    end
    local shK = math.min(1, t / DATA.shadowT)
    if shK > 0 then
        if GroundClutter.casts(e) then
            ShadowEngine.queue(img, px, py - 1, s,
                env.shadowOpts(a * shK * (e.shadowK or 1), flip, 0, env.profile[e.kind]), t)
        end
        if GroundClutter.contacts(e) then Contact.queue(img, px, py, s, t, a * shK, flip) end
    end
    local rot = 0
    if e.sway and not env.reduced then
        rot = math.sin(env.time * 2.3 + p.ph + (p.wph or 0)) * e.sway
    end
    local c = Grade.color(e.family or "prop", t, col)
    setTone(c, p, a)
    local fr = not env.reduced and env.frames and env.frames(p.bid, e.kind, p.v)
    local spSh = LightSpill.reaches(px, py + sink, iw * s * 0.5, ih * s) and LightSpill.spriteShader()
    local prevSh = spSh and love.graphics.getShader()
    if spSh then love.graphics.setShader(spSh) end
    love.graphics.draw(fr and env.frameOf(fr, hash01(p.ph)) or img, px, py + sink, rot, s * flip, s, iw / 2, ih)
    if spSh then love.graphics.setShader(prevSh) end
    if env.seq then env.seq("clutter", p, 0, px, py + sink, iw * s, ih * s, a) end
    ShadowEngine.mask(img, nil, px, py + sink, rot, s * flip, s, iw / 2, ih, 0, t)
    if e.tufts ~= false and (e.solid or e.tufts) and t >= DATA.tuftT then
        GrassField.requireTufts(p.rel - 0.05, px, iw * s * 0.7, 2,
            DATA.cover * ih * s / GrassField.CELL_H, (p.ph or 0) * 10007 + 3)
    end
end

return GroundClutter
