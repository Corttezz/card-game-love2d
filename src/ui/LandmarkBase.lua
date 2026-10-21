local Debug = require("src.core.Debug")
local LightEngine = require("engine.LightEngine")
local LuminaireEngine = require("engine.LuminaireEngine")
local Contact = require("engine.ContactShadow")
local ShadowEngine = require("engine.ShadowEngine")
local SceneGrade = require("engine.SceneGrade")
local GrassField = require("engine.GrassField")

local LandmarkBase = {}
LandmarkBase.DATA = require("src.data.landmark_bases")
LandmarkBase.stats = { draws = 0, parts = 0, last = nil }

local cache = {}
local warned = {}
local emit = { ok = nil, sh = nil, img = nil }
local box = { x1 = 0, y1 = 0, x2 = 0, y2 = 0, key = nil, n = 0 }
local shOpts = { alphaK = 1, flip = 1, footPad = 0 }
local vegCol = {}
local padCol = {}
local propCol = {}
LandmarkBase.box = box

local function load(name)
    local hit = cache[name]
    if hit ~= nil then return hit or nil end
    local path = name:match("^world:") and ("assets/sprites/world/" .. name:sub(7) .. ".png")
        or (LandmarkBase.DATA.dir .. name .. ".png")
    if not love.filesystem.getInfo(path) then
        cache[name] = false
        if not warned[name] then
            warned[name] = true
            Debug.warn("[LandmarkBase] sem arte: " .. path)
        end
        return nil
    end
    local data = love.image.newImageData(path)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    Contact.scan(img, data)
    data:release()
    cache[name] = img
    return img
end
LandmarkBase.load = load

function LandmarkBase.parse(key)
    if type(key) ~= "string" then return nil end
    local fam = key:match("landmark_(%a+)$")
    if not fam or not LandmarkBase.DATA.family[fam] then return nil end
    local bid = key:match("^(%a+)_landmark_") or "fields"
    local code = LandmarkBase.DATA.biomes[bid]
    if not code then return nil end
    return fam, code
end

function LandmarkBase.has(key)
    local fam, code = LandmarkBase.parse(key)
    return fam ~= nil and load(code .. "_" .. (LandmarkBase.DATA.family[fam].pad or "pad")) ~= nil
end

local function grow(x1, y1, x2, y2)
    if box.n == 0 then
        box.x1, box.y1, box.x2, box.y2 = x1, y1, x2, y2
    else
        if x1 < box.x1 then box.x1 = x1 end
        if y1 < box.y1 then box.y1 = y1 end
        if x2 > box.x2 then box.x2 = x2 end
        if y2 > box.y2 then box.y2 = y2 end
    end
    box.n = box.n + 1
end

local function flatK(t)
    return 0.62 + 0.38 * math.min(1, math.max(0, t or 1))
end

local function emitShader()
    if emit.ok == nil then
        local ok, sh = pcall(love.graphics.newShader, "shaders/light_emit.glsl")
        emit.ok = ok and sh and true or false
        emit.sh = emit.ok and sh or nil
        if not emit.ok then Debug.warn("[LandmarkBase] light_emit falhou: " .. tostring(sh)) end
        local d = love.image.newImageData(2, 2)
        d:mapPixel(function() return 1, 1, 1, 1 end)
        emit.img = love.graphics.newImage(d)
    end
    return emit.sh
end

local function drawPool(P, color, gx, gy, r, alpha)
    local E = LuminaireEngine.EMIT
    if not E.on or not LightEngine.isEnabled() then return end
    local dayK = LuminaireEngine.dayK()
    if dayK <= 0 then return end
    local sh = emitShader()
    if not sh then return end
    local inten = E.intensity * P.intensity * dayK * alpha
    if r < 2 or inten <= 0.01 then return end
    local pr, pg, pb, pa = love.graphics.getColor()
    local bm, am = love.graphics.getBlendMode()
    local prev = love.graphics.getShader()
    love.graphics.setShader(sh)
    sh:send("levels", E.levels)
    sh:send("cell", E.cell)
    sh:send("intensity", inten)
    sh:send("upK", E.upK)
    love.graphics.setBlendMode("add", "alphamultiply")
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.draw(emit.img, math.floor(gx), math.floor(gy), 0, r, r * (P.sy or 0.35), 1, 1)
    love.graphics.setShader(prev)
    love.graphics.setBlendMode(bm, am)
    love.graphics.setColor(pr, pg, pb, pa)
end

local function geo(key, F, px, iw, s)
    local W = iw * s
    local door = LandmarkBase.DATA.door[key] or 0.5
    return W, px + (door - 0.5) * W
end

LandmarkBase.CLEAR = { halfK = 0.80, rim = 0.25, step = 0.04, maxBack = 4 }

local function clearGrass(g, rel, cx, frontY, halfW, alpha)
    if not g or not rel or alpha <= 0.02 then return end
    local C = LandmarkBase.CLEAR
    local lo = rel
    local dx = cx - g.cx
    while lo > rel - C.maxBack do
        local t = g.tOf(lo - C.step)
        if not t or t >= 1 then break end
        lo = lo - C.step
        if g.latY(dx, t) >= frontY then break end
    end
    GrassField.requireClearing(lo, rel + 0.02, cx, halfW * C.halfK * math.min(1, alpha), C.rim)
end
LandmarkBase._clearGrass = clearGrass

function LandmarkBase.under(key, px, py, iw, s, t, alpha, col, rel, g)
    box.n, box.key = 0, nil
    local fam, code = LandmarkBase.parse(key)
    if not fam or alpha <= 0.01 then return false end
    local F = LandmarkBase.DATA.family[fam]
    local pad = load(code .. "_" .. (F.pad or "pad"))
    if not pad then return false end
    box.key = key
    local tint = LandmarkBase.DATA.tint[code]
    local W, doorX = geo(key, F, px, iw, s)
    local fk = flatK(t)
    local pw, ph = pad:getWidth(), pad:getHeight()
    local sx = s
    local sy = sx * fk
    local cx = px + F.padX * W
    local bottom = py + F.padFront * s * fk
    local pc = (LandmarkBase.DATA.famTint[fam] or {})[code] or tint.pad
    col = SceneGrade.color("road", t, padCol)
    love.graphics.setColor(col[1] * pc[1], col[2] * pc[2], col[3] * pc[3], alpha)
    love.graphics.draw(pad, math.floor(cx), math.floor(bottom), 0, sx, sy, pw / 2, ph)
    grow(cx - pw * sx / 2, bottom - ph * sy, cx + pw * sx / 2, bottom)
    clearGrass(g, rel, cx, bottom, pw * sx / 2, alpha)
    local path = F.path ~= false and load(code .. "_" .. (F.path or "path"))
    if path then
        local aw, ah = path:getWidth(), path:getHeight()
        local qx = s
        local qy = qx * fk
        local pb = py + F.pathFront * s * fk
        local tc = tint.path
        love.graphics.setColor(col[1] * tc[1], col[2] * tc[2], col[3] * tc[3], alpha)
        love.graphics.draw(path, math.floor(doorX), math.floor(pb), 0, qx, qy, aw / 2, ah)
        grow(doorX - aw * qx / 2, pb - ah * qy, doorX + aw * qx / 2, pb)
    end
    local em = LandmarkBase.DATA.embers[code]
    if em and alpha > 0.5 and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
        local hw = pw * sx * 0.40
        LuminaireEngine.drawEmbersSpec(em, cx - hw, bottom - ph * sy * 0.3, W * 0.5, cx * 0.37)
        LuminaireEngine.drawEmbersSpec(em, cx + hw, bottom - ph * sy * 0.4, W * 0.5, cx * 0.71)
    end
    local P = F.pool
    if P then
        drawPool(P, LandmarkBase.DATA.poolColor[key] or P.color, doorX, py + F.padFront * s * fk * 0.35,
            W * P.radiusK, alpha)
    end
    love.graphics.setColor(1, 1, 1, 1)
    LandmarkBase.stats.draws = LandmarkBase.stats.draws + 1
    return true
end

local function drawProp(img, x, y, s, t, alpha, col, flip)
    local w, h = img:getWidth(), img:getHeight()
    local pad = Contact.padOf(img) or 0
    local fy = y + pad * s
    shOpts.alphaK, shOpts.flip, shOpts.footPad = alpha, flip, pad
    ShadowEngine.sprite(img, x, y - 1, s, shOpts)
    Contact.queue(img, x, y - 1, s, t, alpha, flip)
    love.graphics.setColor(col[1], col[2], col[3], alpha)
    love.graphics.draw(img, math.floor(x), math.floor(fy), 0, s * flip, s, w / 2, h)
    ShadowEngine.mask(img, nil, math.floor(x), math.floor(fy), 0, s * flip, s, w / 2, h, 0, t)
    grow(x - w * s / 2, fy - h * s, x + w * s / 2, fy)
    LandmarkBase.stats.parts = LandmarkBase.stats.parts + 1
end

function LandmarkBase.over(key, px, py, iw, ih, s, t, alpha, col)
    local fam, code = LandmarkBase.parse(key)
    if not fam or alpha <= 0.01 or box.key ~= key then return false end
    local F = LandmarkBase.DATA.family[fam]
    local W, doorX = geo(key, F, px, iw, s)
    local fk = flatK(t)
    local veg = F.veg and load(code .. "_veg")
    if veg then
        local vc = SceneGrade.color(SceneGrade.familyOf("bush"), t, vegCol)
        local vw = veg:getWidth()
        for i, v in ipairs(F.veg) do
            local vs = s
            local vx = px + v[1] * W
            local dir = v[1] < 0 and -1 or 1
            local need = vw * vs / 2 + W * 0.10
            if math.abs(vx - doorX) < need then vx = doorX + dir * need end
            drawProp(veg, vx, py + v[2] * s * fk, vs, t, alpha, vc, dir)
        end
    end
    for _, p in ipairs(LandmarkBase.DATA.props[key] or F.props) do
        local img = load(code .. "_" .. p[1])
        local tp = LandmarkBase.DATA.tint[code].props
        if img and tp then
            propCol[1], propCol[2], propCol[3] = math.min(1, col[1] * tp[1]), math.min(1, col[2] * tp[2]), math.min(1, col[3] * tp[3])
        end
        if img then
            local ps = s
            local vx = px + p[2] * W
            local dir = p[2] < 0 and -1 or 1
            local need = img:getWidth() * ps / 2 + W * 0.08
            if math.abs(vx - doorX) < need then vx = doorX + dir * need end
            drawProp(img, vx, py + p[3] * s * fk, ps, t, alpha, tp and propCol or col, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    return true
end

function LandmarkBase.clearCache()
    for k, v in pairs(cache) do
        if v then v:release() end
        cache[k] = nil
    end
end

return LandmarkBase
