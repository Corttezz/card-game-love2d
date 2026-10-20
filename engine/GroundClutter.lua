local DATA = require("src.data.ground_clutter")
local GrassField = require("engine.GrassField")
local ShadowEngine = require("engine.ShadowEngine")
local Grade = require("engine.SceneGrade")
local Contact = require("engine.ContactShadow")

local GroundClutter = { DATA = DATA, stats = { listed = 0 }, enabled = true }

local pool = {}
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

function GroundClutter.scale(e, t, env)
    local persp = 0.14 + 0.86 * (t ^ 1.65)
    return e.k * env.pixRef * env.screenK * persp
end

function GroundClutter.collect(out, env)
    local st = GroundClutter.stats
    st.listed, st.left, st.right, st.worst, st.roadGap = 0, 0, 0, 0, math.huge
    local list = GroundClutter.enabled and DATA.biomes[env.bid]
    if not list then return 0 end
    local g, w, x, camZ = env.g, env.w, env.x, env.camZ
    local C = DATA.cell
    local relMax = env.relMax
    if env.fork then relMax = math.min(relMax, DATA.forkRelMax) end
    local hand = env.hand
    local n = 0
    for ci = math.floor((camZ + DATA.relMin) / C), math.floor((camZ + relMax) / C) do
        for side = -1, 1, 2 do
            local hs = ci * 2 + (side > 0 and 1 or 0)
            if hash01(hs * 1.37 + 0.11) < DATA.chance then
                local z = (ci + hash01(hs * 3.11 + 0.37)) * C
                local rel = z - camZ
                local t = rel >= DATA.relMin and rel <= relMax and g.tOf(rel)
                if t and t >= DATA.tMin then
                    local e = pick(list, hash01(hs * 5.77 + 0.53))
                    local v = math.floor(hash01(hs * 11.3 + 0.29) * (e.n or 1))
                    local img = env.getSprite(e.kind, v, env.bid)
                    if img then
                        local s = GroundClutter.scale(e, t, env)
                        local iw, ih = img:getWidth(), img:getHeight()
                        local half = env.roadHalfK * w * (0.30 + 0.70 * (t ^ 1.15))
                        local u = DATA.uMin + hash01(hs * 7.13 + 0.71) * (DATA.uMax - DATA.uMin)
                        local px = g.cx + env.wobble(z, t, w) + side * half * u
                        local hw = iw * s * 0.5
                        local pad = w * DATA.edgePad
                        local ok = px - hw > x - pad and px + hw < x + w + pad
                        local py = ok and g.latY(px - g.cx, t)
                        if ok and hand and py - ih * s < hand.y + DATA.handPad
                           and px + hw > hand.x1 and px - hw < hand.x2 then
                            ok = false
                        end
                        if ok and py > g.bottomY + ih * s * 0.25 then ok = false end
                        if ok then
                            n = n + 1
                            local p = pool[n]
                            if not p then p = { clutter = true, kind = "clutter", lane = 0 }; pool[n] = p end
                            local fb = hash01(hs * 9.91 + 0.19) < 0.5 and -1 or 1
                            p.z, p.side, p.bid, p.e, p.img, p.v = z, side, env.bid, e, img, v
                            p.px, p.py, p.s, p.t, p.rel = px, py, s, t, rel
                            p.flip = env.flipToSun(img, env.sunRight, fb)
                            p.ph = hs * 1.7
                            out[#out + 1] = p
                            if side < 0 then st.left = st.left + 1 else st.right = st.right + 1 end
                            st.worst = math.max(st.worst, s / (env.pixRef * env.screenK))
                            st.roadGap = math.min(st.roadGap, math.abs(px - g.cx - env.wobble(z, t, w)) - hw - half)
                        end
                    end
                end
            end
        end
    end
    st.listed = n
    return n
end

function GroundClutter.draw(p, env)
    local e, img, s, t = p.e, p.img, p.s, p.t
    local a = math.min(1, (t - DATA.tMin) / DATA.tFade)
    if a <= 0.01 then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local px, py, flip = math.floor(p.px), math.floor(p.py), p.flip
    if e.solid then
        ShadowEngine.queue(img, px, py - 1, s,
            env.shadowOpts(a * (e.shadowK or 1), flip, 0, env.profile[e.kind]), t)
        Contact.queue(img, px, py, s, t, a, flip)
    end
    local rot = 0
    if e.sway and not env.reduced then
        rot = math.sin(env.time * 2.3 + p.ph) * e.sway
    end
    local c = Grade.color(e.family or "prop", t, col)
    love.graphics.setColor(c[1], c[2], c[3], a)
    local sink = (e.sink or 0) * s
    local fr = not env.reduced and env.frames and env.frames(p.bid, e.kind, p.v)
    love.graphics.draw(fr and env.frameOf(fr, hash01(p.ph)) or img, px, py + sink, rot, s * flip, s, iw / 2, ih)
    ShadowEngine.mask(img, nil, px, py + sink, rot, s * flip, s, iw / 2, ih, 0, t)
    if e.solid then
        GrassField.requireTufts(p.rel - 0.05, px, iw * s * 0.7, 2,
            DATA.cover * ih * s / GrassField.CELL_H)
    end
end

return GroundClutter
