local Debug = require("src.core.Debug")

local RadialGlow = require("src.ui.RadialGlow")

local ClassEmblem = {}

ClassEmblem.PATH = "assets/sprites/emblems/"
ClassEmblem.CANVAS = 128
ClassEmblem.IDS = { "warrior", "mage", "rogue" }

local images = {}
local states = {}
local shader, shaderTried = nil, false

local function measure(data)
    local w, h = data:getDimensions()
    local top, bottom, left, right = h, -1, w, -1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > 0.08 then
                if y < top then top = y end
                if y > bottom then bottom = y end
                if x < left then left = x end
                if x > right then right = x end
            end
        end
    end
    local tipX, n = 0, 0
    for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, math.max(0, bottom))
        if a > 0.08 then tipX = tipX + x; n = n + 1 end
    end
    tipX = n > 0 and (tipX / n) or w / 2
    return { top = top, bottom = bottom, left = left, right = right,
             tipX = tipX, tipY = bottom }
end

function ClassEmblem.get(id)
    if images[id] ~= nil then return images[id] end
    local path = ClassEmblem.PATH .. tostring(id) .. ".png"
    if not love.filesystem.getInfo(path) then
        Debug.warn("[ClassEmblem] AVISO: emblema ausente: " .. path)
        images[id] = false
        return false
    end
    local okD, data = pcall(love.image.newImageData, path)
    if not okD or not data then
        Debug.warn("[ClassEmblem] AVISO: falha ao ler " .. path .. ": " .. tostring(data))
        images[id] = false
        return false
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    local meta = measure(data)
    meta.img = img
    images[id] = meta
    return meta
end

local engravings = {}
function ClassEmblem.engraving(id)
    if engravings[id] ~= nil then return engravings[id] end
    local path = ClassEmblem.PATH .. tostring(id) .. ".png"
    local okD, src = pcall(love.image.newImageData, path)
    if not okD or not src then
        Debug.warn("[ClassEmblem] AVISO: gravura sem fonte: " .. path)
        engravings[id] = false
        return false
    end
    local w, h = src:getDimensions()
    local out = love.image.newImageData(w, h)
    local function alphaAt(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return 0 end
        local _, _, _, a = src:getPixel(x, y)
        return a
    end
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r, g, b, a = src:getPixel(x, y)
            if a > 0.08 then
                local lum = 0.299 * r + 0.587 * g + 0.114 * b
                local edge = alphaAt(x - 1, y) <= 0.08 or alphaAt(x + 1, y) <= 0.08
                    or alphaAt(x, y - 1) <= 0.08 or alphaAt(x, y + 1) <= 0.08
                local on = edge or lum < 0.22
                    or (lum < 0.42 and (x + y) % 2 == 0)
                    or (lum < 0.55 and x % 2 == 0 and y % 2 == 0)
                if on then out:setPixel(x, y, 1, 1, 1, 1) end
            end
        end
    end
    local img = love.graphics.newImage(out)
    img:setFilter("nearest", "nearest")
    engravings[id] = img
    return img
end

local SHADER_SRC = [[
extern number sweep;
extern number bandW;
extern number strength;
extern vec3 tint;
extern number lumLo;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 p = Texel(tex, uv);
    float lum = dot(p.rgb, vec3(0.299, 0.587, 0.114));
    float m = smoothstep(lumLo, lumLo + 0.30, lum);
    float band = 1.0;
    if (bandW > 0.0) {
        float d = uv.x * 0.5 + uv.y - sweep;
        band = step(abs(d), bandW);
    }
    return vec4(tint * color.rgb, p.a * m * band * strength * color.a);
}
]]

local function getShader()
    if shaderTried then return shader end
    shaderTried = true
    local ok, s = pcall(love.graphics.newShader, SHADER_SRC)
    if ok then
        shader = s
    else
        Debug.warn("[ClassEmblem] AVISO: shader de brilho não compilou — emblemas sem brilho: " .. tostring(s))
    end
    return shader
end

local function stateOf(id)
    local s = states[id]
    if not s then
        s = { t = 0, drops = {}, dropTimer = 0.15, dropFlip = false }
        states[id] = s
    end
    return s
end

ClassEmblem.EMBLEM_REF = { warrior = 124, rogue = 124, mage = 96 }

function ClassEmblem.scaleFor(id, boxH, boxW)
    local m = ClassEmblem.get(id)
    local contentH = m and (m.bottom - m.top + 1) or ClassEmblem.CANVAS
    local contentW = m and (m.right - m.left + 1) or ClassEmblem.CANVAS
    local ref = ClassEmblem.EMBLEM_REF[id]
    if ref then contentH = math.max(contentH, ref) end
    local s = boxH / contentH
    if boxW then s = math.min(s, boxW / contentW) end
    s = math.floor(s * 4) / 4
    return math.max(0.5, s)
end

function ClassEmblem.update(dt, hovered)
    for _, id in ipairs(ClassEmblem.IDS) do
        local s = stateOf(id)
        local h = hovered and hovered[id] or 0
        s.t = s.t + dt * (1 + 0.6 * h)
        if id == "rogue" then
            s.dropTimer = s.dropTimer - dt * (1 + 1.2 * h)
            if s.dropTimer <= 0 then
                s.dropTimer = 0.75 + math.random() * 0.45
                s.dropFlip = not s.dropFlip
                table.insert(s.drops, {
                    t = 0, y = 0, vy = 0,
                    poison = s.dropFlip,
                    dx = (math.random() < 0.5) and 0 or 1,
                })
            end
            for i = #s.drops, 1, -1 do
                local d = s.drops[i]
                d.t = d.t + dt
                if d.t > 0.45 then
                    d.vy = d.vy + 150 * dt
                    d.y = d.y + d.vy * dt
                end
                if d.y > 34 then table.remove(s.drops, i) end
            end
        end
    end
end

local function drawShadow(cx, y, w, alpha)
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.ellipse("fill", math.floor(cx), math.floor(y), w, math.max(2, w * 0.18))
end

function ClassEmblem.draw(id, cx, cy, boxH, opts)
    opts = opts or {}
    local m = ClassEmblem.get(id)
    if not m then return false end
    local hover = opts.hover or 0
    local flash = opts.flash or 0
    local st = stateOf(id)
    local t = st.t

    local s = ClassEmblem.scaleFor(id, boxH, opts.boxW)
    local cw = (m.right - m.left + 1)
    local ch = (m.bottom - m.top + 1)
    local ox = math.floor(cx - (m.left + cw / 2) * s)
    local oy = math.floor(cy - (m.top + ch / 2) * s)
    local bob = 0
    if id == "mage" and not opts.locked then
        bob = math.floor(math.sin(t * 1.7) * 3 * s + 0.5)
    end
    local footY = oy + (m.bottom + 1) * s
    local img = m.img

    if opts.locked then
        drawShadow(cx, footY + 2, cw * s * 0.36, 0.30)
        love.graphics.setColor(0.34, 0.29, 0.26, 1)
        love.graphics.draw(img, ox, oy, 0, s, s)
        local chains = ClassEmblem.get("locked_chains")
        if chains then
            local cs = ClassEmblem.scaleFor("locked_chains", boxH * 0.80, opts.boxW)
            local ccw = chains.right - chains.left + 1
            local cch = chains.bottom - chains.top + 1
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(chains.img,
                math.floor(cx - (chains.left + ccw / 2) * cs),
                math.floor(cy - (chains.top + cch / 2) * cs), 0, cs, cs)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return true
    end

    local sh = getShader()

    if id == "mage" then
        local k = 1 + bob / (8 * s)
        drawShadow(cx, footY + 6 * s, cw * s * 0.30 * k, 0.28)
    else
        drawShadow(cx, footY + 1, cw * s * 0.40, 0.32)
    end

    local glow = RadialGlow.get()
    love.graphics.setBlendMode("add")
    if id == "mage" then
        local pulse = 0.5 + 0.5 * math.sin(t * 2.4)
        love.graphics.setColor(0.45, 0.35, 0.85, 0.16 + 0.14 * pulse + 0.15 * hover)
        local r = ch * s * 0.9
        love.graphics.draw(glow, cx, oy + bob + (m.top + ch * 0.4) * s, 0,
            r / 64, r / 64, 64, 64)
    elseif hover > 0.01 then
        local col = (id == "rogue") and { 0.35, 0.55, 0.20 } or { 1, 0.62, 0.28 }
        love.graphics.setColor(col[1], col[2], col[3], 0.20 * hover)
        local r = ch * s * 0.75
        love.graphics.draw(glow, cx, cy, 0, r / 64, r / 64, 64, 64)
    end
    love.graphics.setBlendMode("alpha")

    local tint = opts.tint or { 1, 1, 1 }
    love.graphics.setColor(tint[1], tint[2], tint[3], 1)
    love.graphics.draw(img, ox, oy + bob, 0, s, s)

    if sh then
        love.graphics.setBlendMode("add")
        love.graphics.setShader(sh)
        if id == "warrior" or id == "rogue" then
            local period = (id == "rogue") and 2.6 or 3.4
            local ph = (t % period) / period
            if ph < 0.35 then
                sh:send("sweep", -0.25 + (ph / 0.35) * 1.9)
                sh:send("bandW", (id == "rogue") and 0.028 or 0.035)
                sh:send("strength", 0.75 + 0.25 * hover)
                sh:send("tint", (id == "rogue") and { 0.80, 0.92, 1.0 } or { 1.0, 0.92, 0.75 })
                sh:send("lumLo", 0.35)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, ox, oy, 0, s, s)
            end
        elseif id == "mage" then
            local pulse = 0.5 + 0.5 * math.sin(t * 2.4)
            sh:send("sweep", 0)
            sh:send("bandW", 0)
            sh:send("strength", 0.10 + 0.22 * pulse + 0.12 * hover)
            sh:send("tint", { 0.75, 0.65, 1.0 })
            sh:send("lumLo", 0.30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, ox, oy + bob, 0, s, s)
        end
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha")
    end

    if id == "mage" then
        local ocx = cx
        local ocy = oy + bob + (m.top + ch * 0.42) * s
        local rx, ry = cw * s * 0.62, ch * s * 0.20
        local px = math.max(1, math.floor(s + 0.5))
        for i = 1, 3 do
            local a = t * 1.3 + i * (math.pi * 2 / 3)
            local x = ocx + math.cos(a) * rx
            local y = ocy + math.sin(a) * ry
            local front = math.sin(a) > 0
            love.graphics.setColor(0.85, 0.80, 1.0, front and 0.95 or 0.40)
            love.graphics.rectangle("fill", math.floor(x), math.floor(y), px, px)
        end
    end

    if id == "rogue" then
        for _, d in ipairs(st.drops) do
            local a = 1 - math.max(0, (d.y - 18) / 16)
            local grow = math.min(1, d.t / 0.45)
            local gw = 2 * s
            local gh = ((d.t < 0.45) and (1 + 2 * grow) or 3) * s
            local x = math.floor(ox + (m.tipX - 1 + d.dx * 0.5) * s)
            local y = math.floor(oy + (m.tipY + 1 + d.y) * s)
            love.graphics.setColor(0.05, 0.03, 0.03, a * 0.9)
            love.graphics.rectangle("fill", x - 1, y - 1, math.ceil(gw) + 2, math.ceil(gh) + 2)
            if d.poison then
                love.graphics.setColor(0.50, 0.66, 0.22, a)
            else
                love.graphics.setColor(0.70, 0.10, 0.10, a)
            end
            love.graphics.rectangle("fill", x, y, math.ceil(gw), math.ceil(gh))
            love.graphics.setColor(1, 1, 1, a * 0.45)
            love.graphics.rectangle("fill", x, y, math.max(1, math.floor(s * 0.75)), math.max(1, math.floor(s * 0.75)))
        end
    end

    if flash > 0.02 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, flash * 0.85)
        love.graphics.draw(img, ox, oy + bob, 0, s, s)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.setColor(1, 1, 1, 1)
    return true
end

return ClassEmblem
