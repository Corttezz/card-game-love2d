local biomesData = require("src.data.biomes")
local Sfx = require("src.systems.Sfx")
local LightEngine = require("engine.LightEngine")
local ShadowEngine = require("engine.ShadowEngine")
local LuminaireEngine = require("engine.LuminaireEngine")
local RoadWear = require("engine.RoadWear")
local RoadSurface = require("engine.RoadSurface")
local QuadMesh = require("engine.QuadMesh")
local WeatherEngine = require("engine.WeatherEngine")
local Config = require("src.core.Config")
local EnemyEmissives = require("src.data.enemy_emissives")
local GrassField = require("engine.GrassField")
local Scene = {
    Grade = require("engine.SceneGrade"),
    Contact = require("engine.ContactShadow"),
    Var = require("engine.PropVariation"),
    Clutter = require("engine.GroundClutter"),
    Cut = require("engine.GroundCut"),
}

local PropCut = {
    data = require("src.data.world_props"),
    px = setmetatable({}, { __mode = "k" }),
    quad = setmetatable({}, { __mode = "k" }),
    vis = setmetatable({}, { __mode = "k" }),
    sizeK = setmetatable({}, { __mode = "k" }),
    lit = setmetatable({}, { __mode = "k" }),
    texel = setmetatable({}, { __mode = "k" }),
    kinds = { tree = true, pine = true, deadtree = true, bush = true },
    nv = {}, EMPTY = {},
    anim = { fps = 5, pingpong = true }, frames = {},
    animKinds = { tree = true, pine = true, deadtree = true, bush = true, rock = true,
                  flowers = true, tuft = true, grass = true, reeds = true, blooms = true,
                  embers = true },
    animFps = { abyss = { embers = 2.5, deadtree = 3 } },
    v4 = { 0, 1, 0, 0 }, v3 = { 0, 0, 0 }, td = {},
    STRIP_W = 400,
}
function PropCut.flipToSun(img, sunRight, fallback)
    local lit = PropCut.lit[img]
    if not lit then return fallback end
    return (lit == (sunRight and 1 or -1)) and 1 or -1
end
function PropCut.nvar(bid, kind)
    local byBid = PropCut.nv[bid]
    if not byBid then byBid = {}; PropCut.nv[bid] = byBid end
    local n = byBid[kind]
    if not n then
        n = (PropCut.data.variants or PropCut.EMPTY)[bid .. "_" .. kind] or 3
        byBid[kind] = n
    end
    return n
end
function PropCut.depthShader()
    if PropCut.sh == nil then
        local ok, sh = pcall(love.graphics.newShader, "shaders/tree_depth.glsl")
        PropCut.sh = ok and sh or false
        if not ok then
            require("src.core.Debug").warn("[worldroad] shader de profundidade das árvores não compilou: "
                .. tostring(sh))
        end
    end
    return PropCut.sh
end
function PropCut.beginDepth(img, t)
    local td = Scene.Grade.treeDepth(t, PropCut.td)
    if not td then return nil end
    local sh = PropCut.depthShader()
    if not sh then return nil end
    local prev = love.graphics.getShader()
    local v4 = PropCut.v4
    v4[1], v4[2], v4[3], v4[4] = td.lift, td.sat, td.lod, td.vol
    sh:send("depth", v4)
    local stamp = Scene.Grade.stamp()
    if PropCut.fogStamp ~= stamp then
        PropCut.fogStamp = stamp
        local v3 = PropCut.v3
        v3[1], v3[2], v3[3] = Scene.Grade.treeHaze()
        sh:send("fog", v3)
    end
    if PropCut.texelImg ~= img then
        PropCut.texelImg = img
        local tx = PropCut.texel[img]
        if not tx then
            tx = { 1 / img:getWidth(), 1 / img:getHeight() }
            PropCut.texel[img] = tx
        end
        sh:send("texel", tx)
    end
    love.graphics.setShader(sh)
    return prev or false
end
function PropCut.endDepth(prev)
    if prev ~= nil then love.graphics.setShader(prev or nil) end
end
function PropCut.nearK(t)
    return math.min(1, math.max(0, (t - 0.3) / 0.3))
end
PropCut.CREST = { t = 0.15, k = 0.70, kinds = { tree = true, pine = true, deadtree = true } }
PropCut.PIX = { ref = 2.08, cap = 2.0, fade = 0.88, knee = 0.80 }
function PropCut.capS(rawS, screenK)
    local c = PropCut.PIX
    local L = c.cap * c.ref * screenK
    local kn = c.knee * L
    if rawS <= kn then return rawS end
    local span = L - kn
    return kn + span * (1 - math.exp(-(rawS - kn) / span))
end
function PropCut.nearFade(rawS, screenK, soft)
    local c = PropCut.PIX
    local r = rawS / (c.cap * c.ref * screenK)
    if not soft then return r <= 1 and 1 or 0 end
    if r <= c.fade then return 1 end
    local k = math.min(1, (r - c.fade) / (1 - c.fade))
    return 1 - k * k * (3 - 2 * k)
end
function PropCut.crestK(kind, t)
    local c = PropCut.CREST
    if not c.kinds[kind] then return 1 end
    local k = math.min(1, math.max(0, (t or 0) / c.t))
    return c.k + (1 - c.k) * k
end
function PropCut.cutFor(ih, cut)
    if cut == nil then
        cut = math.floor(ih * PropCut.data.SINK_DEFAULT_FRAC + 0.5)
    end
    return math.max(0, math.min(cut, math.floor(ih * PropCut.data.SINK_MAX_FRAC)))
end
function PropCut.cutOf(img, kind)
    if not PropCut.kinds[kind] then return 0 end
    return PropCut.cutFor(img:getHeight(), PropCut.px[img])
end
function PropCut.groundCut(data, name)
    local kind = name:match("^%a+_(%a+)_%d+$")
    if not kind then return data, nil end
    local cut = PropCut.kinds[kind] and PropCut.cutFor(data:getHeight(), PropCut.data.sink[name]) or nil
    if not PropCut.kinds[kind] and not Scene.Cut.FLAT_KINDS[kind] then return data, nil end
    local cd = data:clone()
    if Scene.Cut.prepare(cd, name, kind, cut) > 0 then return cd, cut end
    cd:release()
    return data, cut
end
function PropCut.get(img, kind)
    if not PropCut.kinds[kind] then return nil, img:getHeight() end
    local q = PropCut.quad[img]
    if q == nil then
        local iw, ih = img:getWidth(), img:getHeight()
        local cut = PropCut.cutOf(img, kind)
        q = cut > 0 and love.graphics.newQuad(0, 0, iw, ih - cut, iw, ih) or false
        PropCut.quad[img] = q
        PropCut.vis[img] = ih - cut
    end
    return q or nil, PropCut.vis[img]
end
function PropCut.mask(img, kind, x, y, rot, sx, sy, kx, t)
    local q, ihv = PropCut.get(img, kind)
    ShadowEngine.mask(img, q, x, y, rot, sx, sy, img:getWidth() / 2, ihv, kx or 0, t)
end
function PropCut.occlude(img, kind, x, y, sx, sy, t, occ)
    local q, ihv = PropCut.get(img, kind)
    ShadowEngine.occlude(img, q, x, y, sx, sy, img:getWidth() / 2, ihv, t,
        occ.k, occ.down, occ.side)
end
function PropCut.draw(img, kind, x, y, rot, sx, sy, kx, fimg)
    local q, ihv = PropCut.get(img, kind)
    local iw = img:getWidth()
    if q then
        love.graphics.draw(fimg or img, q, x, y, rot, sx, sy, iw / 2, ihv, kx or 0, 0)
    else
        love.graphics.draw(fimg or img, x, y, rot, sx, sy, iw / 2, ihv, kx or 0, 0)
    end
end

local WorldRoad = {}
WorldRoad.PropCut = PropCut

local CREST_RATIO   = 0.40
local DOME_R_FACTOR = 1.6
local REL_CREST     = 26
local EMERGE_BAND   = 9
local T_POW         = 1.35
local ROAD_HALF     = 0.15
local PROP_SPACING  = 1.05
local UNIT_PX       = 0.115
local BLEND_DURATION = 2.2

WorldRoad.ROAD_EDGE = 0.80
WorldRoad.POST_JAG = 0.08
function WorldRoad.postLateral(halfR, bid)
    return halfR * (1 + WorldRoad.POST_JAG + 2 * LuminaireEngine.edgeGap(bid))
end
WorldRoad.BATTLE_REL      = 9
WorldRoad.BATTLE_REL_NEAR = 9
WorldRoad.BATTLE_REL_FAR  = 16.5
WorldRoad.TRAVEL_DISTANCE = 20
WorldRoad.TRAVEL_DURATION = 6.5
local SEGMENT_LEN = WorldRoad.TRAVEL_DISTANCE * 8

local KIND_SIZE = {
    tree = 6.3, pine = 6.7, deadtree = 5.9, fence = 1.55, sign = 1.7,
    bush = 1.35, rock = 1.05, flowers = 0.7, stump = 0.9, ruin = 2.9,
    tuft = 0.5, lantern = 1.9, brazier = 1.25,
}

WorldRoad.SHADOW_PROFILE = {
    rock     = { baseK = 0.30, lenK = 0.48 },
    stump    = { baseK = 0.35, lenK = 0.60 },
    bush     = { baseK = 0.35, lenK = 0.55 },
    flowers  = { baseK = 0.55, lenK = 0.45 },
    tuft     = { baseK = 0.50, lenK = 0.45 },
    mushroom = { baseK = 0.25, lenK = 0.60 },
    crystal  = { baseK = 0.30, lenK = 0.55 },
    fissure  = { baseK = 1.00, riseK = 0 },
    landmark_chest = { baseK = 0.30, lenK = 0.42 },
    landmark_rest           = { baseK = 0.22, riseK = 0.17 },
    highlands_landmark_rest = { baseK = 0.22, riseK = 0.20, lenK = 0.60 },
    abyss_landmark_rest     = { baseK = 0.25, riseK = 0.19 },
    frost_landmark_rest     = { baseK = 0.25, riseK = 0.24 },
    marsh_landmark_rest     = { baseK = 0.25, riseK = 0.17 },
    dusk_landmark_rest      = { baseK = 0.25, riseK = 0.28, lenK = 0.60 },
}

local function kindSize(kind, bid)
    local d = bid and LuminaireEngine.def(bid, kind)
    return d and d.size or KIND_SIZE[kind] or 1.0
end

local BIOME_BY_ID = {}
for _, b in ipairs(biomesData) do BIOME_BY_ID[b.id] = b end

local ENV_FIELDS = {
    "skyTop", "skyHorizon", "cloud", "hillsFar", "hillsNear",
    "grassA", "grassB", "roadA", "roadB", "roadEdge", "fog",
}

WorldRoad._time = 0
WorldRoad._camZ = 0
WorldRoad._segBase = 0
WorldRoad._segBasePrev = 0
WorldRoad._entry = nil
WorldRoad._ambient = {}
WorldRoad._smoke = {}
WorldRoad._castleTop = nil
WorldRoad._lumBoxes = {}
WorldRoad._lumBoxN = 0
WorldRoad._birds = {}
WorldRoad._birdTimer = 3
WorldRoad._critters = {}
WorldRoad._biomeIndex = 1
WorldRoad._prevBiomeIndex = nil
WorldRoad._travel = nil
WorldRoad._encounter = nil
WorldRoad._props = {}
WorldRoad._clouds = {}
WorldRoad._spriteCache = {}
WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
WorldRoad._blend = nil

local function rawBiome(idx)
    local n = #biomesData
    return biomesData[(((idx or WorldRoad._biomeIndex) - 1) % n) + 1]
end

WorldRoad._timeOfDay = 1
WorldRoad._timeOfDayTarget = 1

function WorldRoad.setTimeOfDay(t, instant)
    t = math.max(0, math.min(1, t or 1))
    WorldRoad._timeOfDayTarget = t
    if instant then WorldRoad._timeOfDay = t end
end

local function lerpColor3(a, b, t)
    return { a[1] + (b[1] - a[1]) * t,
             a[2] + (b[2] - a[2]) * t,
             a[3] + (b[3] - a[3]) * t }
end

local function biomeLightAmbient(b, tod)
    local day = b.lightDay or b.lightAmbient or { 1, 1, 1 }
    local night = b.lightNight or b.lightAmbient or { 1, 1, 1 }
    return lerpColor3(day, night, tod)
end

local function currentLightAmbient()
    local tod = WorldRoad._timeOfDay
    local cur = biomeLightAmbient(rawBiome(), tod)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        t = t * t * (3 - 2 * t)
        local prev = biomeLightAmbient(rawBiome(WorldRoad._prevBiomeIndex), tod)
        return lerpColor3(prev, cur, t)
    end
    return cur
end

local function copyColor(c) return { c[1], c[2], c[3], c[4] } end

local function envColor(field)
    local target = rawBiome()[field]
    local bl = WorldRoad._blend
    if not bl then return target end
    local from = bl.from[field]
    if not from then return target end
    local t = math.min(1, bl.t / bl.duration)
    t = t * t * (3 - 2 * t)
    return {
        from[1] + (target[1] - from[1]) * t,
        from[2] + (target[2] - from[2]) * t,
        from[3] + (target[3] - from[3]) * t,
        (from[4] or 1) + ((target[4] or 1) - (from[4] or 1)) * t,
    }
end

local function domeGeom(x, y, w, h)
    local crestY = math.floor(y + h * CREST_RATIO)
    local bottomY = y + h
    local R = w * DOME_R_FACTOR
    local cx = x + w / 2
    local cy = crestY + R

    local g = {}
    g.crestApexY = crestY
    g.bottomY = bottomY
    g.cx = cx
    g.R = R
    g.y = y
    g.h = h
    function g.crestYAt(px)
        local dx = px - cx
        local under = R * R - dx * dx
        if under <= 0 then return bottomY end
        return cy - math.sqrt(under)
    end
    function g.tOf(rel)
        local t = 1 - rel / REL_CREST
        if t < 0 then return nil end
        return math.min(1, t) ^ T_POW
    end
    function g.persp(t)
        return 0.14 + 0.86 * (t ^ 1.65)
    end
    function g.latY(dx, t)
        local d = (bottomY - crestY) * t
        local rr = R - d
        local under = rr * rr - dx * dx
        if under <= 0 then return bottomY + 40 end
        return (crestY + R) - math.sqrt(under)
    end
    function g.scaleAt(size, t, ih)
        local targetPx = size * (h * UNIT_PX * 1.25) * g.persp(t)
        return math.max(0.35, targetPx / ih)
    end
    return g
end
WorldRoad.domeGeom = domeGeom

local ffi = require("ffi")
local contentRect = setmetatable({}, { __mode = "k" })
local function scanContentRect(img, path, data)
    if contentRect[img] ~= nil then return end
    if not data then
        local ok, d = pcall(love.image.newImageData, path)
        if not ok or not d then contentRect[img] = false; return end
        data = d
    end
    local w, h = data:getWidth(), data:getHeight()
    local px = data:getFormat() == "rgba8"
        and ffi.cast("const uint8_t*", data:getFFIPointer()) or nil
    local x0, y0, x1, y1
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local opaque
            if px then
                opaque = px[(y * w + x) * 4 + 3] >= 153
            else
                local _, _, _, a = data:getPixel(x, y)
                opaque = a >= 0.6
            end
            if opaque then
                if not x0 or x < x0 then x0 = x end
                if not x1 or x > x1 then x1 = x end
                if not y0 then y0 = y end
                y1 = y
            end
        end
    end
    contentRect[img] = x0 and { x0 = x0, y0 = y0, x1 = x1, y1 = y1 } or false
end

local function tryLoadPng(name)
    local path = "assets/sprites/world/" .. name .. ".png"
    if not love.filesystem.getInfo(path) then return nil end
    local okd, data = pcall(love.image.newImageData, path)
    if not okd or not data then return nil end
    local cdata, cut = PropCut.groundCut(data, name)
    local ok, img = pcall(love.graphics.newImage, cdata)
    if cdata ~= data then cdata:release() end
    if not ok or not img then return nil end
    img:setFilter("nearest", "nearest")
    scanContentRect(img, path, data)
    Scene.Contact.scan(img, data, cut)
    Scene.Contact.setFootRows(img, PropCut.data.footRows[name])
    PropCut.px[img] = PropCut.data.sink[name]
    PropCut.sizeK[img] = PropCut.data.sizeK[name]
    PropCut.lit[img] = PropCut.data.lit and PropCut.data.lit[name] or nil
    return img
end

local function readAnimFrames(key, light)
    local dir = "assets/sprites/world/anim/" .. key
    local info = love.filesystem.getInfo(dir)
    if not info or info.type ~= "directory" then return nil end
    local files = love.filesystem.getDirectoryItems(dir)
    table.sort(files, function(a, b)
        local na = tonumber(a:match("^(%d+)"))
        local nb = tonumber(b:match("^(%d+)"))
        if na and nb then return na < nb end
        return a < b
    end)
    local frames = {}
    for _, f in ipairs(files) do
        if f:match("%.png$") then
            local path = dir .. "/" .. f
            local okd, data = pcall(love.image.newImageData, path)
            local ok, im = false, nil
            if okd and data then
                local cdata = light and PropCut.groundCut(data, key) or data
                ok, im = pcall(love.graphics.newImage, cdata)
                if cdata ~= data then cdata:release() end
            end
            if ok and im then
                im:setFilter("nearest", "nearest")
                if not light then
                    scanContentRect(im, path, data)
                    Scene.Contact.scan(im, data)
                    Scene.Contact.setFootRows(im, PropCut.data.footRows[key])
                end
                frames[#frames + 1] = im
            end
        end
    end
    return #frames > 1 and frames or nil
end

local lumFramesCache = {}
local function luminaireFrames(bid, kind, variant)
    local key = bid .. "_" .. kind .. "_" .. variant
    local hit = lumFramesCache[key]
    if hit ~= nil then return hit or nil end
    local frames = readAnimFrames(key)
    if not frames and variant ~= 0 then
        frames = luminaireFrames(bid, kind, 0)
    end
    lumFramesCache[key] = frames or false
    return frames
end

function PropCut.treeFrames(bid, kind, variant)
    if not PropCut.animKinds[kind] then return nil end
    local key = bid .. "_" .. kind .. "_" .. variant
    local hit = PropCut.frames[key]
    if hit ~= nil then return hit or nil end
    local frames = readAnimFrames(key, true)
    if frames then
        local base = WorldRoad._spriteCache[key]
        for i = #frames, 1, -1 do
            local f = frames[i]
            if base and (f:getWidth() ~= base:getWidth() or f:getHeight() ~= base:getHeight()) then
                require("src.core.Debug").warn(("[worldroad] quadro %d de %s com tamanho diferente da base: ignorado")
                    :format(i - 1, key))
                table.remove(frames, i)
            end
        end
        if #frames < 2 then frames = nil end
    end
    if frames then
        local byBid = PropCut.animFps[bid]
        frames.fps = byBid and byBid[kind] or nil
    end
    PropCut.frames[key] = frames or false
    return frames
end

function PropCut.frameOf(frames, phase)
    local a = PropCut.anim
    local n = #frames
    local period = a.pingpong and (2 * n - 2) or n
    local k = math.floor((WorldRoad._time * (frames.fps or a.fps) + phase * period) % period)
    if k >= n then k = period - k end
    return frames[k + 1]
end

local lumPathCache = {}
local function luminairePath(bid, kind, variant)
    local key = bid .. "|" .. kind .. "|" .. tostring(variant)
    local hit = lumPathCache[key]
    if hit ~= nil then return hit or nil end
    local found = false
    local p1 = "assets/sprites/world/" .. bid .. "_" .. kind .. "_"
        .. variant .. ".png"
    if love.filesystem.getInfo(p1) then
        found = p1
    else
        local p0 = "assets/sprites/world/" .. bid .. "_" .. kind .. "_0.png"
        if love.filesystem.getInfo(p0) then found = p0 end
    end
    lumPathCache[key] = found
    return found or nil
end

function WorldRoad.postCenter(bid, kind, side, s, halfR, variant)
    local d = LuminaireEngine.def(bid, kind)
    local anc = LuminaireEngine.anchor(bid, kind, variant or 0, luminairePath(bid, kind, variant or 0))
    local flip = 1
    if d and d.face and d.face ~= 0 then
        flip = ((side < 0 and 1 or -1) == d.face) and 1 or -1
    end
    local inner
    if anc.cL then
        if side < 0 then inner = flip == 1 and anc.cR or -anc.cL
        else inner = flip == 1 and anc.cL or -anc.cR end
    else
        inner = (anc.offX or 0) * flip
    end
    local cx = side * WorldRoad.postLateral(halfR, bid) - inner * s
    return cx, flip, inner * s, cx + inner * s
end

local function px(data, x, y, c, w, h)
    if x >= 0 and x < w and y >= 0 and y < h then
        data:setPixel(x, y, c[1], c[2], c[3], c[4] or 1)
    end
end

local function blob(data, cx, cy, rx, ry, c, w, h, rng)
    for yy = math.floor(cy - ry), math.ceil(cy + ry) do
        for xx = math.floor(cx - rx), math.ceil(cx + rx) do
            local dx = (xx - cx) / rx
            local dy = (yy - cy) / ry
            local d = dx * dx + dy * dy
            if d <= 1 then
                if d < 0.82 or rng:random() > 0.35 then
                    px(data, xx, yy, c, w, h)
                end
            end
        end
    end
end

local function vline(data, x, y1, y2, c, w, h)
    for y = y1, y2 do px(data, x, y, c, w, h) end
end

local function hline(data, x1, x2, y, c, w, h)
    for x = x1, x2 do px(data, x, y, c, w, h) end
end

local function fillRect(data, x1, y1, x2, y2, c, w, h)
    for y = y1, y2 do hline(data, x1, x2, y, c, w, h) end
end

local function outline(data, w, h, dark)
    local marks = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a == 0 then
                for _, d in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
                    local nx, ny = x + d[1], y + d[2]
                    if nx >= 0 and nx < w and ny >= 0 and ny < h then
                        local _, _, _, na = data:getPixel(nx, ny)
                        if na > 0 then marks[#marks + 1] = { x, y }; break end
                    end
                end
            end
        end
    end
    for _, m in ipairs(marks) do
        data:setPixel(m[1], m[2], dark[1] * 0.4, dark[2] * 0.4, dark[3] * 0.4, 1)
    end
end

local function toImage(data)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    Scene.Contact.scan(img, data)
    return img
end

local function makeTree(b, variant, rng)
    local w, h = 26, 40
    local data = love.image.newImageData(w, h)
    local trunkW = 3 + (variant % 2)
    fillRect(data, math.floor(w / 2 - trunkW / 2), h - 14,
             math.floor(w / 2 + trunkW / 2), h - 1, b.trunk, w, h)
    blob(data, w / 2, h - 22, 10 + variant % 3, 8, b.canopyDark, w, h, rng)
    blob(data, w / 2 - 2, h - 28, 8, 7, b.canopy, w, h, rng)
    blob(data, w / 2 + 1, h - 33, 6, 5, b.canopy, w, h, rng)
    for _ = 1, 14 do
        local xx = math.floor(w / 2 - 5 + rng:random(0, 6))
        local yy = math.floor(h - 36 + rng:random(0, 6))
        px(data, xx, yy, { b.canopy[1] * 1.35, b.canopy[2] * 1.35, b.canopy[3] * 1.35 }, w, h)
    end
    outline(data, w, h, b.canopyDark)
    return toImage(data)
end

local function makePine(b, variant, rng)
    local w, h = 22, 42
    local data = love.image.newImageData(w, h)
    fillRect(data, w / 2 - 1, h - 10, w / 2 + 1, h - 1, b.trunk, w, h)
    local tiers = { { y = h - 10, rw = 9 }, { y = h - 18, rw = 7 },
                    { y = h - 26, rw = 5 }, { y = h - 33, rw = 3 } }
    for ti, tier in ipairs(tiers) do
        local c = (ti % 2 == 0) and b.canopy or b.canopyDark
        for row = 0, 7 do
            local half = math.max(1, tier.rw - row)
            hline(data, math.floor(w / 2 - half), math.floor(w / 2 + half),
                  tier.y - row, c, w, h)
        end
    end
    px(data, math.floor(w / 2), h - 41, b.canopy, w, h)
    outline(data, w, h, b.canopyDark)
    return toImage(data)
end

local function makeDeadTree(b, variant, rng)
    local w, h = 24, 38
    local data = love.image.newImageData(w, h)
    local dark = { b.trunk[1] * 0.7, b.trunk[2] * 0.7, b.trunk[3] * 0.7 }
    vline(data, math.floor(w / 2), h - 26, h - 1, b.trunk, w, h)
    vline(data, math.floor(w / 2) + 1, h - 26, h - 1, dark, w, h)
    local dirs = { { -1, 6 + variant }, { 1, 9 }, { -1, 14 }, { 1, 17 + variant } }
    for _, gg in ipairs(dirs) do
        local sx = math.floor(w / 2)
        local sy = h - 26 + gg[2] - 12
        for i = 0, 6 do
            px(data, sx + gg[1] * i, sy - i, b.trunk, w, h)
        end
    end
    outline(data, w, h, dark)
    return toImage(data)
end

local function makeBush(b, variant, rng)
    local w, h = 18, 12
    local data = love.image.newImageData(w, h)
    blob(data, w / 2 - 3, h - 5, 5, 4, b.bushDark, w, h, rng)
    blob(data, w / 2 + 3, h - 5, 5, 4, b.bushDark, w, h, rng)
    blob(data, w / 2, h - 7, 5 + variant % 2, 4, b.bush, w, h, rng)
    outline(data, w, h, b.bushDark)
    return toImage(data)
end

local function makeRock(b, variant, rng)
    local w, h = 16, 11
    local data = love.image.newImageData(w, h)
    blob(data, w / 2, h - 4, 6 + variant % 2, 4, b.rockDark, w, h, rng)
    blob(data, w / 2 - 1, h - 6, 4, 3, b.rock, w, h, rng)
    outline(data, w, h, b.rockDark)
    return toImage(data)
end

local function makeStump(b, variant, rng)
    local w, h = 12, 10
    local data = love.image.newImageData(w, h)
    fillRect(data, 2, 3, w - 3, h - 1, b.trunk, w, h)
    local light = { b.trunk[1] * 1.5, b.trunk[2] * 1.5, b.trunk[3] * 1.4 }
    fillRect(data, 2, 2, w - 3, 4, light, w, h)
    hline(data, 4, w - 5, 3, b.trunk, w, h)
    outline(data, w, h, { b.trunk[1] * 0.6, b.trunk[2] * 0.6, b.trunk[3] * 0.6 })
    return toImage(data)
end

local function makeFence(b, variant, rng)
    local w, h = 30, 14
    local data = love.image.newImageData(w, h)
    local wood = { b.trunk[1] * 1.2, b.trunk[2] * 1.2, b.trunk[3] * 1.1 }
    local dark = { b.trunk[1] * 0.7, b.trunk[2] * 0.7, b.trunk[3] * 0.7 }
    for _, postX in ipairs({ 3, 15, 27 }) do
        fillRect(data, postX - 1, 2, postX, h - 1, wood, w, h)
    end
    hline(data, 1, w - 2, 5, dark, w, h)
    hline(data, 1, w - 2, 6, wood, w, h)
    hline(data, 1, w - 2, 10, dark, w, h)
    hline(data, 1, w - 2, 11, wood, w, h)
    outline(data, w, h, dark)
    return toImage(data)
end

local function makeSign(b, variant, rng)
    local w, h = 16, 20
    local data = love.image.newImageData(w, h)
    local wood = { b.trunk[1] * 1.2, b.trunk[2] * 1.2, b.trunk[3] * 1.1 }
    local dark = { b.trunk[1] * 0.6, b.trunk[2] * 0.6, b.trunk[3] * 0.6 }
    vline(data, w / 2, 6, h - 1, wood, w, h)
    vline(data, w / 2 + 1, 6, h - 1, dark, w, h)
    fillRect(data, 2, 2, w - 3, 8, wood, w, h)
    hline(data, 4, w - 5, 4, dark, w, h)
    hline(data, 4, w - 7, 6, dark, w, h)
    outline(data, w, h, dark)
    return toImage(data)
end

local function makeFlowers(b, variant, rng)
    local w, h = 16, 8
    local data = love.image.newImageData(w, h)
    for _ = 1, 4 + (variant % 3) do
        local fx = 1 + rng:random(0, w - 3)
        local fy = h - 2 - rng:random(0, 2)
        px(data, fx, fy, b.bushDark, w, h)
        px(data, fx, fy - 1, b.accent, w, h)
        px(data, fx + 1, fy - 1, { b.accent[1] * 1.25, b.accent[2] * 1.25, b.accent[3] * 1.25 }, w, h)
    end
    return toImage(data)
end

local function makeRuin(b, variant, rng)
    local w, h = 18, 26
    local data = love.image.newImageData(w, h)
    local topY = 4 + (variant % 3) * 3
    fillRect(data, 5, topY, 12, h - 1, b.rock, w, h)
    fillRect(data, 11, topY, 12, h - 1, b.rockDark, w, h)
    for xx = 5, 12 do
        if rng:random() < 0.5 then px(data, xx, topY - 1, b.rock, w, h) end
    end
    fillRect(data, 3, h - 4, 14, h - 1, b.rockDark, w, h)
    vline(data, 8, topY + 4, topY + 9, b.rockDark, w, h)
    outline(data, w, h, b.rockDark)
    return toImage(data)
end

local function makeTuft(b, variant, rng)
    local w, h = 10, 7
    local data = love.image.newImageData(w, h)
    for _ = 1, 4 + variant do
        local fx = 1 + rng:random(0, w - 3)
        local blades = rng:random(2, 3)
        for i = 0, blades do
            vline(data, fx + i, h - 2 - rng:random(1, 3), h - 1, b.bush, w, h)
        end
    end
    return toImage(data)
end

local function makeCastle(b, rng)
    local w, h = 90, 120
    local data = love.image.newImageData(w, h)
    local lm, lmD = b.landmark, b.landmarkDark
    fillRect(data, 28, 34, 61, h - 1, lm, w, h)
    fillRect(data, 54, 34, 61, h - 1, lmD, w, h)
    fillRect(data, 38, 8, 51, 40, lm, w, h)
    for i = 0, 7 do
        hline(data, 38 + i, 51 - i, 8 - 0 + i, { 0.25, 0.15, 0.18 }, w, h)
    end
    fillRect(data, 14, 44, 27, h - 1, lm, w, h)
    fillRect(data, 62, 44, 75, h - 1, lm, w, h)
    fillRect(data, 23, 44, 27, h - 1, lmD, w, h)
    fillRect(data, 71, 44, 75, h - 1, lmD, w, h)
    for i = 0, 3 do
        fillRect(data, 14 + i * 4, 40, 15 + i * 4, 43, lm, w, h)
        fillRect(data, 62 + i * 4, 40, 63 + i * 4, 43, lm, w, h)
    end
    local amber = { 0.92, 0.72, 0.32 }
    fillRect(data, 43, 18, 46, 23, amber, w, h)
    fillRect(data, 18, 52, 21, 56, amber, w, h)
    fillRect(data, 66, 52, 69, 56, amber, w, h)
    fillRect(data, 42, 50, 45, 55, amber, w, h)
    fillRect(data, 33, 70, 36, 75, amber, w, h)
    fillRect(data, 40, h - 18, 49, h - 1, { 0.2, 0.13, 0.08 }, w, h)
    outline(data, w, h, lmD)
    return toImage(data)
end

local function makeCloud(variant, rng)
    local w, h = 42, 14
    local data = love.image.newImageData(w, h)
    local c = { 0.86, 0.83, 0.78 }
    blob(data, w * 0.35, h * 0.6, 10, 4, c, w, h, rng)
    blob(data, w * 0.6, h * 0.5, 12 - variant % 3, 5, c, w, h, rng)
    blob(data, w * 0.78, h * 0.65, 7, 3, c, w, h, rng)
    return toImage(data)
end

local function makeLantern(b, variant, rng)
    local w, h = 20, 46
    local data = love.image.newImageData(w, h)
    local wood = b.trunk
    local woodD = { wood[1] * 0.7, wood[2] * 0.7, wood[3] * 0.7 }
    fillRect(data, 8, 12, 10, h - 1, wood, w, h)
    vline(data, 10, 12, h - 1, woodD, w, h)
    fillRect(data, 8, 10, 17, 11, wood, w, h)
    px(data, 16, 12, woodD, w, h)
    px(data, 16, 13, woodD, w, h)
    fillRect(data, 12, 14, 19, 28, { 0.16, 0.12, 0.09 }, w, h)
    fillRect(data, 13, 16, 18, 26, { 1.0, 0.55, 0.18 }, w, h)
    fillRect(data, 14, 18, 17, 24, { 1.0, 0.78, 0.35 }, w, h)
    fillRect(data, 15, 20, 16, 22, { 1.0, 0.93, 0.70 }, w, h)
    hline(data, 13, 18, 15, { 0.22, 0.16, 0.11 }, w, h)
    hline(data, 13, 18, 27, { 0.22, 0.16, 0.11 }, w, h)
    outline(data, w, h, woodD)
    return toImage(data)
end

local function makeBrazier(b, variant, rng)
    local w, h = 18, 30
    local data = love.image.newImageData(w, h)
    local rock, rockD = b.rock, b.rockDark
    fillRect(data, 5, 12, 12, h - 1, rock, w, h)
    vline(data, 12, 12, h - 1, rockD, w, h)
    hline(data, 5, 12, 13, rockD, w, h)
    fillRect(data, 3, 9, 14, 11, rock, w, h)
    hline(data, 3, 14, 11, rockD, w, h)
    blob(data, 8.5, 6, 4, 4, { 1.0, 0.45, 0.12 }, w, h, rng)
    blob(data, 8.5, 6, 2.6, 2.8, { 1.0, 0.72, 0.25 }, w, h, rng)
    px(data, 8, 5, { 1.0, 0.92, 0.60 }, w, h)
    px(data, 9, 5, { 1.0, 0.92, 0.60 }, w, h)
    outline(data, w, h, rockD)
    return toImage(data)
end

local function makeLuminaireGeneric(b, kind, variant, rng)
    local def = LuminaireEngine.def(b.id, kind)
    local c = def and def.light.color or { 1.0, 0.6, 0.25 }
    local w, h = 20, 34
    local data = love.image.newImageData(w, h)
    local rock, rockD = b.rock, b.rockDark
    fillRect(data, 6, 16, 13, h - 1, rock, w, h)
    vline(data, 13, 16, h - 1, rockD, w, h)
    fillRect(data, 4, 13, 15, 15, rock, w, h)
    blob(data, 9.5, 9, 5, 4.5,
        { c[1] * 0.85, c[2] * 0.85, c[3] * 0.85 }, w, h, rng)
    blob(data, 9.5, 9, 3, 3, c, w, h, rng)
    local hi = { math.min(1, c[1] + 0.4), math.min(1, c[2] + 0.4),
                 math.min(1, c[3] + 0.4) }
    px(data, 9, 8, hi, w, h)
    px(data, 10, 8, hi, w, h)
    outline(data, w, h, rockD)
    return toImage(data)
end

local MAKERS = {
    tree = makeTree, pine = makePine, deadtree = makeDeadTree,
    bush = makeBush, rock = makeRock, stump = makeStump,
    fence = makeFence, sign = makeSign, flowers = makeFlowers,
    ruin = makeRuin, tuft = makeTuft,
    lantern = makeLantern, brazier = makeBrazier,
}

local function getSprite(kind, variant, bid)
    local key
    if kind == "cloud" then
        key = "cloud_" .. variant
    elseif kind == "castle" then
        key = (bid or rawBiome().id) .. "_castle"
    elseif kind == "mountains" then
        key = (bid or rawBiome().id) .. "_mountains"
    elseif kind == "mountains_front" then
        key = (bid or rawBiome().id) .. "_mountains_front"
    else
        key = (bid or rawBiome().id) .. "_" .. kind .. "_" .. variant
    end
    if WorldRoad._spriteCache[key] then return WorldRoad._spriteCache[key] end

    local img = tryLoadPng(key)
    if not img and kind ~= "cloud" and kind ~= "castle"
       and kind ~= "mountains" and variant ~= 0 then
        img = tryLoadPng((bid or rawBiome().id) .. "_" .. kind .. "_0")
    end
    if not img then
        local rng = love.math.newRandomGenerator(#key * 7919 + variant * 131)
        local b = BIOME_BY_ID[bid] or rawBiome()
        if kind == "cloud" then
            img = makeCloud(variant, rng)
        elseif kind == "castle" then
            img = makeCastle(b, rng)
        elseif kind == "mountains" or kind == "mountains_front" then
            img = false
        elseif MAKERS[kind] then
            img = MAKERS[kind](b, variant, rng)
        else
            img = makeLuminaireGeneric(b, kind, variant, rng)
        end
    end
    WorldRoad._spriteCache[key] = img
    return img
end
WorldRoad._getSprite = getSprite

function WorldRoad.propVariants(bid, kind) return PropCut.nvar(bid, kind) end
function WorldRoad.treeDepthShader() return PropCut.depthShader() end
function WorldRoad.treeAnim(bid, kind, variant, phase)
    local base = getSprite(kind, variant, bid)
    local fr = PropCut.treeFrames(bid, kind, variant)
    if not fr then return nil, base end
    return fr, base, phase and PropCut.frameOf(fr, phase) or nil
end
WorldRoad.TREE_ANIM = PropCut.anim

function WorldRoad.propCutInfo(kind, variant, bid)
    local img = getSprite(kind, variant or 0, bid)
    if not img then return nil end
    local cut = PropCut.cutOf(img, kind)
    return cut, img:getHeight() - cut, img:getHeight()
end

local KIND_LANE = {
    fence = { 0.02, 0.14 }, sign = { 0.03, 0.18 },
    flowers = { 0.0, 0.85 }, tuft = { 0.0, 1.0 },
    lantern = { 0.0, 0.08 }, brazier = { 0.01, 0.12 },
    default = { 0.05, 1.0 },
}

local TREE_KIND = { fields = "tree", highlands = "pine", abyss = "deadtree",
                    frost = "pine", marsh = "deadtree", dusk = "tree" }

local TREEISH = { tree = true, pine = true, deadtree = true }
local function kindMult(kind)
    if TREEISH[kind] then return 3.5 end
    if LuminaireEngine.isLuminaire(kind) then return 1.0 end
    return 0.5
end
local kindOrderCache = setmetatable({}, { __mode = "k" })
local function kindOrder(weights)
    local list = kindOrderCache[weights]
    if not list then
        list = {}
        for kind in pairs(weights) do list[#list + 1] = kind end
        table.sort(list)
        kindOrderCache[weights] = list
    end
    return list
end
local function pickKind(b, rng)
    local weights = b.propWeights
    local order = kindOrder(weights)
    local total = 0
    for i = 1, #order do
        local kind = order[i]
        total = total + weights[kind] * kindMult(kind)
    end
    total = total + 0.7
    local r = rng:random() * total
    if r > total - 0.7 then return "tuft" end
    for i = 1, #order do
        local kind = order[i]
        r = r - weights[kind] * kindMult(kind)
        if r <= 0 then return kind end
    end
    return TREE_KIND[b.id] or "tree"
end

local function rollProp(p, z, forcedSide, noLum)
    local b = rawBiome()
    local rng = WorldRoad._rng
    p.z = z
    WorldRoad._uid = (WorldRoad._uid or 0) + 1
    p.uid = WorldRoad._uid
    p.kind = pickKind(b, rng)
    if forcedSide then
        p.side = forcedSide
    else
        local SIDE_W = { tree = 1, pine = 1, deadtree = 1, ruin = 1,
                         fence = 0.7, sign = 0.7 }
        local bal = WorldRoad._sideBal or 0
        local pLeft = math.min(0.85, math.max(0.15, 0.5 - bal * 0.16))
        p.side = rng:random() < pLeft and -1 or 1
        WorldRoad._sideBal = bal + p.side * (SIDE_W[p.kind] or 0.35)
    end
    local LUM_STEP = LuminaireEngine.roadStep(b.id)
    local LUM_JIT  = 2.5
    WorldRoad._nextLumZ = WorldRoad._nextLumZ or {
        [-1] = z + LUM_STEP * (0.15 + rng:random() * 0.20),
        [1]  = z + LUM_STEP * (0.60 + rng:random() * 0.25),
    }
    local roadKind = LuminaireEngine.roadKind(b.id)
    local pdef = LuminaireEngine.def(b.id, p.kind)
    if pdef and (pdef.roadside or noLum) then
        p.kind = TREE_KIND[b.id] or "tree"
    end
    if roadKind and not noLum then
        local nextZ = WorldRoad._nextLumZ[p.side] or z
        local verdict = WorldRoad.lumPlanVerdict(p, z, roadKind, b.id)
        for _, q in ipairs(WorldRoad._props) do
            local qd = q ~= p and not q.ghost and LuminaireEngine.def(q.bid, q.kind)
            if qd and qd.roadside and math.abs(q.z - z) < (q.side == p.side and LUM_STEP * 0.75 or WorldRoad.LUM_PLAN.oppGap) then
                verdict = "skip"
            end
        end
        if verdict ~= "skip" and (z >= nextZ or verdict == "force") then
            p.kind = roadKind
            WorldRoad._nextLumZ[p.side] = z + LUM_STEP + rng:random() * LUM_JIT
            local other = -p.side
            local oNext = WorldRoad._nextLumZ[other] or z
            local lo, hi = z + LUM_STEP * 0.45, z + LUM_STEP * 0.65
            if oNext < lo then WorldRoad._nextLumZ[other] = lo
            elseif oNext > hi then WorldRoad._nextLumZ[other] = hi end
        end
    end
    local ldef = LuminaireEngine.def(b.id, p.kind)
    local lane = (ldef and ldef.lane) or KIND_LANE[p.kind] or KIND_LANE.default
    p.lane = lane[1] + rng:random() * (lane[2] - lane[1])
    if ldef and ldef.roadside then p.lane = LuminaireEngine.ROAD_LANE end
    p.variant = rng:random(0, PropCut.nvar(b.id, p.kind) - 1)
    p.bid = b.id
    p.big = 1
    p.cluster = nil
    p.jitter = rng:random() * 2 - 1
    if (p.kind == "tree" or p.kind == "pine" or p.kind == "deadtree")
       and rng:random() < 0.45 then
        p.lane = 0.72 + rng:random() * 0.26
        p.big = 1.2 + rng:random() * 0.25
    end
    if (p.kind == "tree" or p.kind == "pine" or p.kind == "deadtree"
        or p.kind == "bush") and rng:random() < 0.45 then
        p.cluster = rng:random(1, 2)
        WorldRoad._sideBal = (WorldRoad._sideBal or 0)
            + p.side * 0.55 * p.cluster
    end
    p.flown = nil
    p.forkHide = nil
    p.perched = nil
    if p.kind == "fence" and rng:random() < 0.55 then
        p.perched = rng:random(1, 2)
    end
end

local function resolveOverlap(p)
    if p.kind == "fence" then
        for _, o in ipairs(WorldRoad._props) do
            if o ~= p and not o.ghost and o.kind == "fence"
               and math.abs(o.z - p.z) < 8 then
                p.kind = "bush"
                local lane = KIND_LANE.default
                p.lane = lane[1] + WorldRoad._rng:random() * (lane[2] - lane[1])
                return
            end
        end
        return
    end
    local BIG = { tree = true, pine = true, deadtree = true, ruin = true }
    if not BIG[p.kind] then return end
    for _ = 1, 4 do
        local clash = false
        for _, o in ipairs(WorldRoad._props) do
            if o ~= p and not o.ghost and BIG[o.kind] and o.side == p.side
               and math.abs(o.z - p.z) < 2.2
               and math.abs(o.lane - p.lane) < 0.22 then
                clash = true
                break
            end
        end
        if not clash then return end
        local lane = KIND_LANE[p.kind] or KIND_LANE.default
        p.lane = lane[1] + WorldRoad._rng:random() * (lane[2] - lane[1])
        p.z = p.z + (WorldRoad._rng:random() - 0.5) * 1.4
    end
end

local function makeWall(p)
    local rng = WorldRoad._rng
    p.wall = true
    p.kind = TREE_KIND[p.bid] or "tree"
    local n = PropCut.nvar(p.bid, p.kind)
    local wv = WorldRoad._wallVar
    if not wv then wv = {}; WorldRoad._wallVar = wv end
    if n > 1 and p.variant == wv[p.side] then
        p.variant = (p.variant + 1 + rng:random(0, n - 2)) % n
    end
    wv[p.side] = p.variant
    p.lane = 0.2 + rng:random() * 0.6
    p.big = 1 + rng:random() * 0.3
    p.cluster = rng:random() < 0.5 and rng:random(1, 2) or nil
    p.perched = nil
end

local SWAP_FADE   = 0.42
local SWAP_SPREAD = 1.30
local GHOST_FIELDS = { "z", "side", "kind", "variant", "bid", "lane",
                       "big", "cluster", "jitter", "wall" }

local function propFadeK(p)
    local t = p.swapT
    if not t then return 1 end
    local k = (t - p.swapDelay) / p.swapDur
    if k <= 0 then return p.ghost and 1 or 0 end
    if k >= 1 then return p.ghost and 0 or 1 end
    k = k * k * (3 - 2 * k)
    return p.ghost and (1 - k) or k
end

local function swapPropsToBiome(camZ)
    local props = WorldRoad._props
    if not props or #props == 0 then return end
    local reduced = _G.gameSettings and _G.gameSettings.reducedMotion
    for i = #props, 1, -1 do
        if props[i].ghost then table.remove(props, i) end
    end
    local order = {}
    for _, p in ipairs(props) do order[#order + 1] = p end
    table.sort(order, function(a, c) return a.z < c.z end)
    WorldRoad._nextLumZ = nil
    local FAR_REL = REL_CREST + EMERGE_BAND
    local ghosts = {}
    for _, p in ipairs(order) do
        local rel = p.z - camZ
        if rel >= 0 then
            local k = math.min(1, rel / FAR_REL)
            local delay = SWAP_SPREAD * (1 - k) ^ 1.4
            local dur = SWAP_FADE * (1 + 0.6 * (1 - k))
            if not reduced then
                local gh = {}
                for _, f in ipairs(GHOST_FIELDS) do gh[f] = p[f] end
                gh.ghost = true
                gh._pokeT, gh._leafFx = p._pokeT, p._leafFx
                gh.swapT, gh.swapDelay, gh.swapDur = 0, delay, dur
                ghosts[#ghosts + 1] = gh
            end
            local wasWall = p.wall
            rollProp(p, p.z, p.side, wasWall)
            if wasWall then makeWall(p) end
            resolveOverlap(p)
            PropCut.clearLane(p)
            p._pokeT, p._leafFx, p._scareBirds = nil, nil, nil
            if reduced then
                p.swapT, p.swapDelay, p.swapDur = nil, nil, nil
            else
                p.swapT, p.swapDelay, p.swapDur = 0, delay, dur
            end
        end
    end
    for _, gh in ipairs(ghosts) do props[#props + 1] = gh end
end

local function populate()
    WorldRoad._props = {}
    WorldRoad._populateFrame = WorldRoad._drawFrame or 0
    WorldRoad._sideBal = 0
    WorldRoad._nextLumZ = nil
    local b = rawBiome()
    if WorldRoad._plan then WorldRoad._reservePosts(WorldRoad._plan, true) end
    local z = 0.5
    while z < REL_CREST + EMERGE_BAND do
        for side = -1, 1, 2 do
            if WorldRoad._rng:random() < 0.9 then
                local p = {}
                rollProp(p, z + WorldRoad._camZ
                    + WorldRoad._rng:random() * 0.5, side)
                table.insert(WorldRoad._props, p)
                resolveOverlap(p)
                PropCut.clearLane(p)
            end
        end
        z = z + PROP_SPACING / math.max(0.2, b.propDensity)
            + WorldRoad._rng:random() * 0.9
    end
    local zt = 1.2
    while zt < REL_CREST + EMERGE_BAND do
        for side = -1, 1, 2 do
            local p = {}
            rollProp(p, zt + WorldRoad._camZ
                + WorldRoad._rng:random() * 0.5, side, true)
            makeWall(p)
            table.insert(WorldRoad._props, p)
            resolveOverlap(p)
            PropCut.clearLane(p)
        end
        zt = zt + 0.95 + WorldRoad._rng:random() * 0.4
    end
    WorldRoad._clouds = {}
    for _ = 1, 4 do
        table.insert(WorldRoad._clouds, {
            xr = WorldRoad._rng:random(),
            yr = 0.07 + WorldRoad._rng:random() * 0.33,
            speed = 2.6 + WorldRoad._rng:random() * 2.6,
            scale = 0.85 + WorldRoad._rng:random() * 0.55,
            phase = WorldRoad._rng:random() * 6.28,
            variant = 0,
        })
    end
    for _ = 1, 3 do
        table.insert(WorldRoad._clouds, {
            xr = WorldRoad._rng:random(),
            yr = 0.05 + WorldRoad._rng:random() * 0.20,
            speed = 1.2 + WorldRoad._rng:random() * 1.3,
            scale = 0.45 + WorldRoad._rng:random() * 0.30,
            phase = WorldRoad._rng:random() * 6.28,
            variant = 0,
            far = true,
        })
    end
end

function WorldRoad.setBiome(n)
    local idx = math.max(1, n or 1)
    if idx ~= WorldRoad._biomeIndex then
        local from = {}
        for _, f in ipairs(ENV_FIELDS) do from[f] = copyColor(envColor(f)) end
        WorldRoad._prevBiomeIndex = WorldRoad._biomeIndex
        WorldRoad._biomeIndex = idx
        WorldRoad._blend = { from = from, t = 0, duration = BLEND_DURATION }
        WorldRoad._segBasePrev = WorldRoad._segBase
        WorldRoad._segBase = WorldRoad._camZ
        require("src.ui.CastleDrift").reset()
        swapPropsToBiome(WorldRoad._camZ)
    end
end

function WorldRoad.enterCastle(opts)
    opts = opts or {}
    local bid = rawBiome().id
    WorldRoad._entry = {
        phase = "door", t = 0,
        doorK = 0, fade = 0,
        sound = (bid == "abyss" or bid == "dusk")
            and "castleGateMagic" or "castleGateOpen",
        onComplete = opts.onComplete,
    }
    Sfx.play(WorldRoad._entry.sound)
end

function WorldRoad.isEntering()
    return WorldRoad._entry ~= nil
end

function WorldRoad.entryFade()
    local e = WorldRoad._entry
    return e and e.fade or 0
end

function WorldRoad.travel(opts)
    opts = opts or {}
    local dist = opts.distance or WorldRoad.TRAVEL_DISTANCE
    WorldRoad._travel = {
        from = WorldRoad._camZ,
        dist = dist,
        t = 0,
        duration = opts.duration or WorldRoad.TRAVEL_DURATION,
        onComplete = opts.onComplete,
    }
    WorldRoad.planStop(WorldRoad._camZ + dist,
        opts.encounter and (opts.encounter.img or opts.encounter.anim) and true)
    if opts.encounter and (opts.encounter.img or opts.encounter.anim) then
        local e = opts.encounter
        WorldRoad._encounter = {
            anim = e.anim, img = e.img, iw = e.iw, ih = e.ih,
            targetScale = e.targetScale or 4,
            spriteId = e.spriteId,
            offX = e.offX, footPad = e.footPad,
            framePads = e.framePads, footSink = e.footSink,
            shadowBaseK = e.shadowBaseK, shadowRiseK = e.shadowRiseK,
            contentH = e.contentH, shadow = e.shadow,
            z = WorldRoad._camZ + dist + WorldRoad.BATTLE_REL,
        }
    else
        WorldRoad._encounter = nil
    end
end

function WorldRoad.isTraveling()
    return WorldRoad._travel ~= nil
end

local function roadWobble(worldZ, t, w)
    return (math.sin(worldZ * 0.11) * 0.5
        + math.sin(worldZ * 0.30 + 2.1) * 0.32
        + math.sin(worldZ * 0.71 + 0.7) * 0.18)
        * w * 0.045 * (0.28 + 0.72 * t)
end

function WorldRoad.setBattleEnemyDraw(fn, baseY)
    WorldRoad._enemyDraw = fn
    WorldRoad._enemyBaseY = baseY
end

function WorldRoad.getRoadAnchor(rel, x, y, w, h)
    local g = domeGeom(x, y, w, h)
    local t = g.tOf(rel) or 0
    local sy = g.crestApexY + (g.bottomY - g.crestApexY) * t
    local wob = roadWobble(WorldRoad._camZ + rel, t, w)
    return math.floor(g.cx + wob), math.floor(sy)
end

WorldRoad.ENEMY_SIZE_REF_REL = 9
WorldRoad.ENEMY_SIZE_PERSP   = 0.6
function WorldRoad.battleSizeK(rel)
    local g = domeGeom(0, 0, 1, 1)
    local t = g.tOf(rel or WorldRoad.BATTLE_REL) or 0
    local t0 = g.tOf(WorldRoad.ENEMY_SIZE_REF_REL) or t
    return (g.persp(t) / g.persp(t0)) ^ WorldRoad.ENEMY_SIZE_PERSP
end

WorldRoad.ENEMY_SCREEN_BASE_H = 716
WorldRoad.ENEMY_SCREEN_GROWTH = 1.05
WorldRoad.ENEMY_SCREEN_MAX_K = 2.6
function WorldRoad.enemyScreenK(areaH)
    if not areaH then return 1 end
    local base = WorldRoad.ENEMY_SCREEN_BASE_H
    local k = 1 + math.max(0, areaH - base) / base * WorldRoad.ENEMY_SCREEN_GROWTH
    return math.min(WorldRoad.ENEMY_SCREEN_MAX_K, k)
end

function WorldRoad.battleRelFor(x, y, w, h, footLimitY)
    local g = domeGeom(x, y, w, h)
    local span = g.bottomY - g.crestApexY
    local near, far = WorldRoad.BATTLE_REL_NEAR, WorldRoad.BATTLE_REL_FAR
    if span <= 0 or not footLimitY then return near end
    local t = (footLimitY - g.crestApexY) / span
    if t >= (g.tOf(near) or 1) then return near end
    if t <= 0 then return far end
    local rel = REL_CREST * (1 - t ^ (1 / T_POW))
    return math.max(near, math.min(far, rel))
end

function WorldRoad.setHandZone(x1, x2, y)
    local hz = WorldRoad._handZone or {}
    hz.x1, hz.x2, hz.y = x1, x2, y
    WorldRoad._handZone = hz
end

function WorldRoad.setBattleRel(rel)
    WorldRoad.BATTLE_REL = rel or WorldRoad.BATTLE_REL_NEAR
end

local function easeInOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local f = 2 * t - 2
    return 1 + f * f * f / 2
end

local LANDMARK_FOR_TYPE = {
    battle = "landmark_battle", elite = "landmark_elite",
    mini_boss = "landmark_miniboss", boss = "landmark_battle",
    rest = "landmark_rest", shop = "landmark_shop",
    event = "landmark_event", treasure = "landmark_chest",
}
local LANDMARK_SIZE = {
    landmark_battle = 3.4, landmark_elite = 4.4, landmark_rest = 3.6,
    landmark_shop = 5.2, landmark_event = 5.0, landmark_chest = 2.6,
    landmark_miniboss = 3.8, highlands_landmark_battle = 4.0,
}
local landmarkCache = {}
local function getLandmark(key)
    if landmarkCache[key] ~= nil then return landmarkCache[key] or nil end
    local img = tryLoadPng(key)
    landmarkCache[key] = img or false
    return img
end

local LANDMARK_ANIM = {
    landmark_rest   = { fps = 10, hoverFpsK = 1.8 },
    landmark_battle = { fps = 8, pingpong = true, hoverFpsK = 1.7 },
    landmark_elite  = { fps = 9, hoverFpsK = 1.6 },
    landmark_event  = { fps = 7, pingpong = true, hoverFpsK = 1.6 },
    landmark_shop   = { fps = 6, pingpong = true, hoverAnim = "landmark_shop_hover" },
    abyss_landmark_rest      = { fps = 10, pingpong = true, hoverFpsK = 1.8 },
    abyss_landmark_elite     = { fps = 9,  pingpong = true, hoverFpsK = 1.6 },
    highlands_landmark_elite = { fps = 9,  pingpong = true, hoverFpsK = 1.6 },
    frost_landmark_elite     = { fps = 9,  pingpong = true, hoverFpsK = 1.6 },
    dusk_landmark_elite      = { fps = 9,  pingpong = true, hoverFpsK = 1.6 },
    fields_castle    = { fps = 8, pingpong = true },
    highlands_castle = { fps = 5, pingpong = true },
    abyss_castle     = { fps = 9, pingpong = true },
    frost_castle     = { fps = 6, pingpong = true },
    marsh_castle     = { fps = 6, pingpong = true },
    dusk_castle      = { fps = 8, pingpong = true },
}
local LANDMARK_HOVER_SOUND = {
    landmark_rest   = "forkHoverFire",
    landmark_shop   = "forkHoverDoor",
    landmark_battle = "forkHoverFlag",
    landmark_elite  = "forkHoverElite",
    landmark_event  = "forkHoverTent",
    landmark_miniboss = "forkHoverElite",
}
local LANDMARK_SHADOW_PAD = {
    landmark_shop = 3, landmark_event = 3, landmark_chest = 2,
    highlands_landmark_shop = 4,  abyss_landmark_shop = 11,
    frost_landmark_shop     = 6,  marsh_landmark_shop = 3,
    dusk_landmark_shop      = 2,
    highlands_landmark_event = 2, abyss_landmark_event = 1,
    frost_landmark_event     = 3, marsh_landmark_event = 5,
    dusk_landmark_event      = 3,
    highlands_landmark_rest = 1,  abyss_landmark_rest = 5,
    frost_landmark_rest     = 1,  marsh_landmark_rest = 1,
    dusk_landmark_rest      = 1,
    highlands_landmark_battle = 0, frost_landmark_battle = 0,
    highlands_landmark_elite  = 2, frost_landmark_elite  = 1,
    marsh_landmark_elite      = 1, dusk_landmark_elite  = 1,
    abyss_landmark_elite      = 2, landmark_elite        = 2,
}
WorldRoad.LANDMARK_SHADOW_PAD, WorldRoad.LANDMARK_SIZE = LANDMARK_SHADOW_PAD, LANDMARK_SIZE
local LANDMARK_LIGHT = {
    landmark_rest  = { color = { 1.00, 0.62, 0.28 }, radiusK = 0.95, intensity = 0.85 },
    landmark_elite = { color = { 0.72, 0.38, 1.00 }, radiusK = 0.45, intensity = 0.50 },
    landmark_shop  = { color = { 1.00, 0.72, 0.38 }, radiusK = 0.30, intensity = 0.45 },
    landmark_event = { color = { 0.45, 0.80, 1.00 }, radiusK = 0.30, intensity = 0.45 },
    landmark_miniboss = { color = { 1.00, 0.45, 0.25 }, radiusK = 0.40, intensity = 0.50 },
}
local LANDMARK_SMOKE = {
    landmark_shop = { xf = 0.675, yf = 0.02 },
    highlands_landmark_shop = { xf = 0.233, yf = 0.00 },
    abyss_landmark_shop     = { xf = 0.770, yf = 0.00, color = { 0.72, 0.64, 0.58 } },
    frost_landmark_shop     = { xf = 0.339, yf = 0.00, color = { 0.42, 0.44, 0.49 } },
    marsh_landmark_shop     = { xf = 0.739, yf = 0.02, color = { 0.72, 0.74, 0.62 } },
    dusk_landmark_shop      = { xf = 0.212, yf = 0.00, color = { 0.38, 0.32, 0.28 } },
}

local LANDMARK_GENERIC_BIOME = "fields"
local function landmarkFamily(key)
    if not key then return nil end
    return key:match("(landmark_.+)$") or key
end
local function lmCfg(tbl, key)
    if not key then return nil end
    local v = tbl[key]
    if v ~= nil then return v end
    return tbl[landmarkFamily(key)]
end

local landmarkKeyCache = {}
local landmarkKeyWarned = {}
local function landmarkHoverAnimKey(key)
    local a = lmCfg(LANDMARK_ANIM, key)
    if not (a and a.hoverAnim) then return nil end
    local bid = key:match("^(.-)_landmark_")
    if bid then
        local k = bid .. "_" .. a.hoverAnim
        if love.filesystem.getInfo("assets/sprites/world/anim/" .. k) then
            return k
        end
    end
    return a.hoverAnim
end

local function landmarkKeyFor(nodeType, bid)
    local base = LANDMARK_FOR_TYPE[tostring(nodeType)]
    if not base then return nil end
    bid = bid or rawBiome().id
    local ck = bid .. "|" .. base
    local hit = landmarkKeyCache[ck]
    if hit then return hit end

    if bid == LANDMARK_GENERIC_BIOME then
        landmarkKeyCache[ck] = base
        return base
    end

    local key = bid .. "_" .. base
    local faltou = nil
    if not love.filesystem.getInfo("assets/sprites/world/" .. key .. ".png") then
        faltou = key .. ".png"
    else
        local a = LANDMARK_ANIM[base]
        if a and a.hoverAnim
            and not love.filesystem.getInfo(
                "assets/sprites/world/anim/" .. bid .. "_" .. a.hoverAnim) then
            faltou = "anim/" .. bid .. "_" .. a.hoverAnim .. "/"
        end
    end
    if faltou then
        if not landmarkKeyWarned[ck] then
            landmarkKeyWarned[ck] = true
            require("src.core.Debug").warn(("[worldroad] bioma '%s' sem arte própria de %s (falta %s) — usando o lugar genérico")
                :format(bid, base, faltou))
        end
        key = base
    end
    landmarkKeyCache[ck] = key
    return key
end

local landmarkFramesCache = {}
local function landmarkFrames(key)
    local hit = landmarkFramesCache[key]
    if hit ~= nil then return hit or nil end
    local frames = readAnimFrames(key)
    landmarkFramesCache[key] = frames or false
    return frames
end

local function landmarkFrameAt(key, ft)
    local fr = landmarkFrames(key)
    if not fr then return nil end
    local a = lmCfg(LANDMARK_ANIM, key)
    if a and a.pingpong then
        local period = 2 * #fr - 2
        local k = math.floor(ft % period)
        if k >= #fr then k = period - k end
        return fr[k + 1]
    end
    return fr[1 + math.floor(ft % #fr)]
end

local function landmarkFrame(key, seed)
    local fr = landmarkFrames(key)
    if not fr then return nil end
    local a = lmCfg(LANDMARK_ANIM, key)
    local period = (a and a.pingpong) and (2 * #fr - 2) or #fr
    return landmarkFrameAt(key,
        WorldRoad._time * ((a and a.fps) or 8) + (seed or 0) % period)
end

local LMG = { NO_CRITTERS = {}, ORIG_H = {
    abyss_landmark_battle = 68, abyss_landmark_elite = 83, abyss_landmark_event = 87,
    abyss_landmark_rest = 52, abyss_landmark_shop = 86,
    dusk_landmark_battle = 69, dusk_landmark_elite = 80, dusk_landmark_event = 86,
    dusk_landmark_rest = 53, dusk_landmark_shop = 84,
    frost_landmark_battle = 63, frost_landmark_elite = 83, frost_landmark_event = 85,
    frost_landmark_shop = 82,
    highlands_landmark_battle = 71, highlands_landmark_elite = 80,
    highlands_landmark_event = 86, highlands_landmark_rest = 54, highlands_landmark_shop = 80,
    landmark_battle = 69, landmark_chest = 54, landmark_elite = 85, landmark_event = 90,
    landmark_miniboss = 89, landmark_shop = 87,
    marsh_landmark_battle = 68, marsh_landmark_elite = 83, marsh_landmark_event = 88,
    marsh_landmark_rest = 51, marsh_landmark_shop = 86,
} }
WorldRoad.LANDMARK_ORIG_H = LMG.ORIG_H
function LMG.refH(key, ih) return LMG.ORIG_H[key] or ih end
LMG.c = {}
LMG.fc = {}
LMG.pvCopy = { windPhase = 0, canopy = 0, trunk = 0 }
LMG.tint4 = { 1, 1, 1, 1 }
LMG.LIGHT_SHOP_GLOW = { 1.00, 0.72, 0.38 }
LMG.EMBERS = { color = { 1.00, 0.62, 0.22 }, count = 3 }
LMG.SELF_LIGHT = { 1.00, 0.90, 0.74 }
LMG.SHADE = { 0.42, 0.42, 0.50 }
LMG.PASS_FADE = { 0.88, 1.08 }
LMG.Base = require("src.ui.LandmarkBase")
function LMG.selfLight(lmk, px, py, iw, ih, s, rel, alphaK)
    if not lmk or not lmk.selfLight or lmk.selfLight <= 0 or alphaK <= 0.05 then return end
    local gx, gy = love.graphics.transformPoint(px, py - ih * s * 0.45)
    LightEngine.submit({
        x = gx, y = gy, radius = math.max(iw, ih) * s * 0.75, sy = 0.8,
        color = LMG.SELF_LIGHT, intensity = lmk.selfLight * alphaK,
        dither = true, ditherAmt = 0.22, levels = 6, z = rel,
    })
end

local function drawLandmarkSmoke(key, px, py, iw, ih, s, alpha, thin)
    local sm = lmCfg(LANDMARK_SMOKE, key)
    local xf, yf, k0 = nil, nil, 1
    if sm then
        xf, yf = sm.xf, sm.yf
    elseif thin then
        local anc = LuminaireEngine.anchor("landmark", key, 0,
            "assets/sprites/world/" .. key .. ".png")
        xf, yf = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.4
        k0 = 0.5
    end
    if not xf or ih * s < 46 * k0 then return end
    local mx = px + (xf - 0.5) * iw * s
    local my = py - ih * s + yf * ih * s
    local rise = ih * s * 0.52 * (thin and 0.8 or 1)
    local cr, cg, cb = 0.80, 0.77, 0.72
    if sm and sm.color then cr, cg, cb = sm.color[1], sm.color[2], sm.color[3] end
    for k = 0, 2 do
        local p = (WorldRoad._time * 0.30 + k * 0.333) % 1
        local a = alpha * 0.40 * k0 * math.min(1, p * 5) * (1 - p)
        if a > 0.01 then
            local puffX = mx + math.sin(WorldRoad._time * 0.8 + k * 2.1 + p * 2.6)
                * (0.8 + p * 3.2) * s + p * 2.5 * s
            local puffY = my - p * rise
            local sz = math.max(2, (1.1 + p * 2.8) * s * k0)
            love.graphics.setColor(cr, cg, cb, a)
            love.graphics.rectangle("fill", math.floor(puffX - sz / 2),
                math.floor(puffY - sz / 2), sz, sz)
            love.graphics.setColor(cr * 0.92, cg * 0.92, cb * 0.92, a * 0.85)
            love.graphics.rectangle("fill", math.floor(puffX - sz * 0.85),
                math.floor(puffY - sz * 0.15), math.max(1, sz * 0.6), math.max(1, sz * 0.6))
            love.graphics.rectangle("fill", math.floor(puffX + sz * 0.35),
                math.floor(puffY - sz * 0.65), math.max(1, sz * 0.55), math.max(1, sz * 0.55))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function submitLandmarkLight(key, px, py, iw, ih, s, rel, seed, alphaK, lmk)
    local L = lmCfg(LANDMARK_LIGHT, key)
    if not L or not LightEngine.submitMicro then return end
    alphaK = alphaK or 1
    if alphaK <= 0.05 then return end
    if lmk and (lmk.lanternGlow == false or lmk.runeFlicker == false) then return end
    if lmk and lmk.windowGlow then
        local gx, gy = love.graphics.transformPoint(px, py + 2)
        LightEngine.submit({
            x = gx, y = gy, radius = iw * s * 0.5 * lmk.windowGlow.spread, sy = 0.35,
            color = LMG.LIGHT_SHOP_GLOW, intensity = lmk.windowGlow.alpha * alphaK,
            dither = true, ditherAmt = 0.28, levels = 6, seed = seed, z = rel,
        })
    end
    local anc = LuminaireEngine.anchor("landmark", key, 0,
        "assets/sprites/world/" .. key .. ".png")
    local ax, ay = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.45
    local fx = px + (ax - 0.5) * iw * s
    local fy = py - ih * s * (1 - ay)
    local time = love.timer.getTime()
    local sd = (seed or 0) % 1000
    local n = love.math.noise(time * 1.4, sd) * 0.75
        + love.math.noise(time * 4.0, sd + 37.2) * 0.25
    if lmk and lmk.runeFlicker then
        n = love.math.noise(time * 0.7, sd) * 0.65
            + love.math.noise(time * 2.1, sd + 53.7) * 0.35
    end
    local fxT, fyT = love.graphics.transformPoint(fx, fy)
    local fi = 0.86 + 0.14 * n
    if lmk and lmk.pulse and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
        fi = fi * (1 + lmk.pulse * math.sin(time * 2.3 + sd))
    end
    local fr = 0.88 + 0.18 * n
    local r = iw * s * L.radiusK
    LightEngine.submit({
        x = fxT, y = fyT, radius = r * 1.5 * fr,
        color = L.color, intensity = L.intensity * 0.55 * fi * alphaK,
        dither = true, ditherAmt = 0.28, levels = 8,
        seed = sd, z = rel,
    })
    LightEngine.submitMicro(fxT, fyT, r * 0.45 * fr,
        L.color, L.intensity * fi * alphaK, rel)
end

WorldRoad._hitScene = {}
local POKE_SOUND = {
    tree = "sceneRustle", pine = "sceneRustle", bush = "sceneRustle",
    deadtree = "sceneWoodKnock", fence = "sceneWoodKnock",
    totem = "sceneWoodKnock",
    lantern = "sceneLampCreak",
    brazier = "forkHoverFire", firepit = "forkHoverFire",
    torch = "forkHoverFire", fissure = "forkHoverFire",
    shrine = "sceneStoneThud", runestone = "sceneStoneThud",
    crystal = "forkHoverTent", mushroom = "sceneRustle",
    cloud = "sceneCloudPoof",
}
local POKE_SOUND_BIOME = {
    fields = { lantern = "sceneLampWood" },
    marsh  = { lantern = "sceneLampWood" },
    dusk   = { lantern = "sceneLampWood" },
}
local POKE_AMP = {
    tree = 0.085, pine = 0.085, bush = 0.11, deadtree = 0.06,
    tuft = 0.17, flowers = 0.15, fence = 0.045, totem = 0.05,
    shrine = 0.03, runestone = 0.03, crystal = 0.05, mushroom = 0.12,
    lantern = 0.05, brazier = 0.04, torch = 0.05, firepit = 0.03,
    fissure = 0.02,
}

local function pokeRot(p)
    local t0 = p._pokeT
    if not t0 then return 0 end
    local e = WorldRoad._time - t0
    if e >= 1.3 then p._pokeT = nil; return 0 end
    return math.sin(e * 16) * (POKE_AMP[p.kind] or 0.05)
        * math.exp(-e * 3.4)
end

local function drawLeafFx(p, bx, by, iw, ih, s)
    local fx = p._leafFx
    if not fx then return end
    local e = WorldRoad._time - fx.t0
    if e >= 1.6 then p._leafFx = nil; return end
    local a = math.min(1, (1.6 - e) * 2.2)
    for k = 1, #fx do
        local lf = fx[k]
        local lx = bx + (lf.dx + math.sin(e * 2.8 + lf.ph) * 0.05) * iw * s
        local ly = by - (lf.dy - e * lf.spd) * ih * s
        if ly < by + 2 then
            local sz = math.max(1, math.floor(1.6 * s + 0.5))
            love.graphics.setColor(lf.c[1], lf.c[2], lf.c[3], a * 0.9)
            love.graphics.rectangle("fill", math.floor(lx), math.floor(ly), sz, sz)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function spawnLeafFx(p)
    local gA = envColor("grassA")
    local dead = (p.kind == "deadtree")
    local fx = { t0 = WorldRoad._time }
    for k = 1, 5 do
        local r1, r2, r3 = math.random(), math.random(), math.random()
        fx[k] = {
            dx = (r1 - 0.5) * 0.55,
            dy = 0.45 + r2 * 0.35,
            ph = r3 * 6.28,
            spd = 0.30 + r1 * 0.22,
            c = dead and { 0.42, 0.33, 0.20 }
                or { math.min(1, gA[1] * 1.35), math.min(1, gA[2] * 1.30),
                     math.min(1, gA[3] * 1.10) },
        }
    end
    p._leafFx = fx
end

function WorldRoad.pokeSceneAt(mx, my)
    local hs = WorldRoad._hitScene
    for i = #hs, 1, -1 do
        local b = hs[i]
        if mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2 then
            b.ref._pokeT = WorldRoad._time
            if b.kind == "tree" or b.kind == "pine" or b.kind == "bush"
               or b.kind == "deadtree" then
                spawnLeafFx(b.ref)
            end
            if b.kind == "fence" and b.ref.perched and not b.ref.flown then
                b.ref._scareBirds = true
            end
            local byBid = b.ref.bid and POKE_SOUND_BIOME[b.ref.bid]
            local snd = (byBid and byBid[b.kind]) or POKE_SOUND[b.kind]
            if snd then
                Sfx.playWithVariation(snd,
                    b.kind == "mushroom" and 0.72 or 1.0, 0.08)
            end
            return true
        end
    end
    return false
end

local function submitLandmarkOccluder(img, px, py, iw, ih, s, rel)
    local oxT, oyT = love.graphics.transformPoint(px - iw * s / 2, py - ih * s)
    LightEngine.submitOccluder({
        z = rel,
        flatColor = Scene.Grade.flatColor("landmark", {}),
        img = img, x = oxT, y = oyT, sx = s, sy = s,
        bx = oxT, by = oyT, w = iw * s, h = ih * s,
    })
end

local prewarmTick

function WorldRoad.update(dt)
    WorldRoad._time = WorldRoad._time + dt
    prewarmTick()

    if #WorldRoad._props == 0 then
        populate()
        local f = WorldRoad._fork
        if f and not f.converge then
            LMG.layoutMarks(f)
            LMG.clearFreshCover(f)
        end
    end

    local encA = WorldRoad._encounter
    if encA and encA.anim and WorldRoad._travel then
        encA.anim:update(dt)
    end

    local f = WorldRoad._fork
    if f then
        f.animIn = math.min(1, (f.animIn or 0) + dt * 2.2)
        if f.chosenPulse and f.chosenPulse > 0 then
            f.chosenPulse = math.max(0, f.chosenPulse - dt)
        end
        local c = f.converge
        if c then
            c.t = c.t + dt
            local k = math.min(1, c.t / c.duration)
            c.k = easeInOutCubic(k)
            WorldRoad._camZ = c.z0 + c.dist * c.k
            if k >= 1 then
                local node = f.nodes[f.chosen]
                local key = node and landmarkKeyFor(node.type)
                if key then
                    local a = lmCfg(LANDMARK_ANIM, key)
                    local fps = (a and a.fps) or 8
                    local animT = ((f._animT and f._animT[f.chosen]) or 0)
                        + f.chosen * 3.7
                    WorldRoad._landmark = {
                        key = key, z = f.markZ,
                        size = lmCfg(LANDMARK_SIZE, key) or 2.0,
                        phase = animT - WorldRoad._time * fps,
                    }
                end
                local cb, idx = f.onChosen, f.chosen
                WorldRoad._fork = nil
                if cb then cb(node, idx) end
            end
        else
            local mx, my = love.mouse.getPosition()
            f.hover = WorldRoad.forkHitTest(mx, my)
            if f.hover then
                require("src.ui.CursorManager").request("hand")
            end
        end
        f._animT = f._animT or {}
        f._hoverK = f._hoverK or {}
        for i = 1, f.n do
            local node = f.nodes[i]
            local key = node and landmarkKeyFor(node.type)
            local a = key and lmCfg(LANDMARK_ANIM, key)
            local hov = (f.hover == i and not f.converge)
            if a then
                f._animT[i] = (f._animT[i] or 0)
                    + dt * a.fps * (hov and (a.hoverFpsK or 1) or 1)
            end
            local hk = f._hoverK[i] or 0
            f._hoverK[i] = math.min(1, math.max(0, hk + dt * (hov and 2.6 or -3.2)))
        end
        if f.hover ~= f._hoverPrev then
            if f.hover and not f.converge then
                local node = f.nodes[f.hover]
                local key = node and landmarkKeyFor(node.type)
                local snd = key and lmCfg(LANDMARK_HOVER_SOUND, key)
                if snd then Sfx.playWithVariation(snd, 1.0, 0.06) end
            end
            f._hoverPrev = f.hover
        end
    end

    do
        local en = WorldRoad._entry
        if en then
            en.t = en.t + dt
            if en.phase == "door" then
                en.doorK = math.min(1, en.t / 1.4)
                if en.doorK >= 1 then en.phase = "fade"; en.t = 0 end
            elseif en.phase == "fade" then
                en.fade = math.min(1, en.t / 0.9)
                if en.fade >= 1 then
                    local cb = en.onComplete
                    WorldRoad._entry = nil
                    if cb then cb() end
                end
            end
        end
    end

    LightEngine.update(dt)

    do
        local tod, tgt = WorldRoad._timeOfDay, WorldRoad._timeOfDayTarget
        if tod ~= tgt then
            local step = 0.30 * dt
            if math.abs(tgt - tod) <= step then
                WorldRoad._timeOfDay = tgt
            else
                WorldRoad._timeOfDay = tod + (tgt > tod and step or -step)
            end
        end
    end

    local bl = WorldRoad._blend
    if bl then
        bl.t = bl.t + dt
        if bl.t >= bl.duration then
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
        end
    end

    local tr = WorldRoad._travel
    if tr then
        tr.t = tr.t + dt
        local k = math.min(1, tr.t / tr.duration)
        WorldRoad._camZ = tr.from + tr.dist * easeInOutCubic(k)
        if WorldRoad._encounter then
            WorldRoad._encounter.z = tr.from + tr.dist + WorldRoad.BATTLE_REL
        end
        if k >= 1 then
            WorldRoad._travel = nil
            local enc = WorldRoad._encounter
            if enc and enc.anim then
                require("src.ui.EnemyRenderer")._handoff = enc.anim
            end
            WorldRoad._encounter = nil
            if tr.onComplete then tr.onComplete() end
        end
    end

    for i = #WorldRoad._props, 1, -1 do
        local p = WorldRoad._props[i]
        if p.swapT then
            p.swapT = p.swapT + dt
            if p.swapT >= p.swapDelay + p.swapDur then
                if p.ghost then
                    table.remove(WorldRoad._props, i)
                else
                    p.swapT, p.swapDelay, p.swapDur = nil, nil, nil
                end
            end
        end
    end

    for i = #WorldRoad._props, 1, -1 do
        local p = WorldRoad._props[i]
        if p.reserved and p.z - WorldRoad._camZ < -7 then table.remove(WorldRoad._props, i) end
    end
    for _, p in ipairs(WorldRoad._props) do
        local rd = not p.ghost and LuminaireEngine.def(p.bid, p.kind)
        if not p.ghost and p.z - WorldRoad._camZ < ((rd and rd.roadside) and -7 or -3.5) then
            local wasWall = p.wall
            rollProp(p, WorldRoad._camZ + REL_CREST + EMERGE_BAND * 0.6
                        + WorldRoad._rng:random() * 2, p.side, wasWall)
            if wasWall then makeWall(p) end
            resolveOverlap(p)
            PropCut.clearLane(p)
        end
    end

    local travelPush = tr and 0.004 or 0
    for _, c in ipairs(WorldRoad._clouds) do
        c.xr = c.xr - (c.speed / 1000 + travelPush) * dt * 10
        if c.xr < -0.2 then c.xr = 1.15 end
    end

    do
        local bid = rawBiome().id
        local walked = math.max(0, WorldRoad._camZ - (WorldRoad._segBase or 0))
        WeatherEngine.update(dt, {
            biomeId = bid, camZ = WorldRoad._camZ, time = WorldRoad._time,
            windP = GrassField.PRESETS[bid],
            progress = math.min(1, walked / SEGMENT_LEN),
            luma = LightEngine.ambientLuma(),
        })
        local wa = require("src.systems.WeatherAudio")
        local st = WeatherEngine.audioState()
        wa.update(dt, st)
        if st.blink then wa.fireflyBlink(st.blink) end
    end

    local ct = WorldRoad._castleTop
    if ct and ct.progress > 0.55 and #WorldRoad._smoke < 14
       and WorldRoad._rng:random() < 0.10 then
        table.insert(WorldRoad._smoke, {
            x = ct.x, y = ct.y,
            vx = 4 + WorldRoad._rng:random() * 6,
            vy = -(9 + WorldRoad._rng:random() * 7),
            size = (2 + WorldRoad._rng:random(0, 2)) * math.max(0.6, ct.s),
            life = 2.2 + WorldRoad._rng:random() * 1.4,
            maxLife = 3.6,
            phase = WorldRoad._rng:random() * 6.28,
        })
    end
    for i = #WorldRoad._smoke, 1, -1 do
        local sp = WorldRoad._smoke[i]
        sp.x = sp.x + (sp.vx + math.sin(WorldRoad._time * 1.3 + sp.phase) * 4) * dt
        sp.y = sp.y + sp.vy * dt
        sp.size = sp.size + 2.4 * dt
        sp.life = sp.life - dt
        if sp.life <= 0 then table.remove(WorldRoad._smoke, i) end
    end

    WorldRoad._birdTimer = WorldRoad._birdTimer - dt
    if WorldRoad._birdTimer <= 0 and #WorldRoad._birds == 0 then
        WorldRoad._birdTimer = 9 + WorldRoad._rng:random() * 14
        local dir = WorldRoad._rng:random() < 0.5 and 1 or -1
        local baseY = 0.10 + WorldRoad._rng:random() * 0.16
        local n = WorldRoad._rng:random(3, 5)
        for i = 1, n do
            table.insert(WorldRoad._birds, {
                xr = (dir == 1 and -0.05 or 1.05) - dir * i * 0.022,
                yr = baseY + (i % 2) * 0.018 + WorldRoad._rng:random() * 0.01,
                dir = dir,
                speed = 0.052 + WorldRoad._rng:random() * 0.014,
                phase = WorldRoad._rng:random() * 6.28,
            })
        end
    end
    for i = #WorldRoad._birds, 1, -1 do
        local bd = WorldRoad._birds[i]
        bd.xr = bd.xr + bd.dir * bd.speed * dt
        if bd.vyr then
            bd.yr = bd.yr + bd.vyr * dt
            bd.vyr = bd.vyr + 0.09 * dt
            if bd.vyr > -0.01 then bd.vyr = nil end
        end
        if bd.xr < -0.12 or bd.xr > 1.12 or bd.yr < -0.12 or bd.yr > 1.8 then
            table.remove(WorldRoad._birds, i)
        end
    end

    local glowBio = LightEngine.ambientLuma() < 0.75
    local crCap = glowBio and 14 or 6
    local crRate = glowBio and 0.05 or 0.02
    if #WorldRoad._critters < crCap and WorldRoad._rng:random() < crRate then
        local xr
        if WorldRoad._rng:random() < 0.12 then
            xr = 0.06 + WorldRoad._rng:random() * 0.88
        else
            local side = WorldRoad._rng:random() < 0.5 and -1 or 1
            xr = 0.5 + side * (0.17 + WorldRoad._rng:random() * 0.30)
        end
        table.insert(WorldRoad._critters, {
            xr = xr,
            yr = 0.42 + WorldRoad._rng:random() * 0.48,
            phase = WorldRoad._rng:random() * 6.28,
            drift = (WorldRoad._rng:random() - 0.5) * 0.014,
            life = 12 + WorldRoad._rng:random() * 10,
        })
    end
    for i = #WorldRoad._critters, 1, -1 do
        local cr = WorldRoad._critters[i]
        cr.xr = cr.xr + cr.drift * dt
            + math.sin(WorldRoad._time * 2.7 + cr.phase) * 0.012 * dt
        cr.life = cr.life - dt
        if cr.life <= 0 or cr.xr < 0 or cr.xr > 1 then
            table.remove(WorldRoad._critters, i)
        end
    end
end

local skyTopColorCache = {}
local function mountainsSkyColor(bid)
    if skyTopColorCache[bid] ~= nil then return skyTopColorCache[bid] end
    local path = "assets/sprites/world/" .. bid .. "_mountains.png"
    local color = false
    if love.filesystem.getInfo(path) then
        local ok, data = pcall(love.image.newImageData, path)
        if ok and data then
            local cx = math.floor(data:getWidth() / 2)
            for yy = 1, math.min(30, data:getHeight() - 1) do
                local r, gg, b, a = data:getPixel(cx, yy)
                if a > 0.9 and (r + gg + b) > 0.45 then
                    color = { r, gg, b }
                    break
                end
            end
        end
    end
    skyTopColorCache[bid] = color
    return color
end

local function drawSky(g, x, y, w)
    local skyH = g.crestApexY - y + 40

    local baked = mountainsSkyColor(rawBiome().id)
    local bl = WorldRoad._blend
    if baked and bl and WorldRoad._prevBiomeIndex then
        local prevBaked = mountainsSkyColor(rawBiome(WorldRoad._prevBiomeIndex).id)
        if prevBaked then
            local t = math.min(1, bl.t / bl.duration)
            baked = {
                prevBaked[1] + (baked[1] - prevBaked[1]) * t,
                prevBaked[2] + (baked[2] - prevBaked[2]) * t,
                prevBaked[3] + (baked[3] - prevBaked[3]) * t,
            }
        end
    end
    if baked then
        local bandH = 8
        local bands = math.ceil(skyH / bandH)
        for i = 0, bands do
            local t = i / bands
            local f = 1 + t * 0.06
            love.graphics.setColor(baked[1] * f, baked[2] * f, baked[3] * f, 1)
            love.graphics.rectangle("fill", x, y + i * bandH, w, bandH)
        end
        return
    end

    local top = envColor("skyTop")
    local hor = envColor("skyHorizon")
    local tR = top[1] + (hor[1] - top[1]) * 0.35
    local tG = top[2] + (hor[2] - top[2]) * 0.35
    local tB = top[3] + (hor[3] - top[3]) * 0.35
    local bandH = 8
    local bands = math.ceil(skyH / bandH)
    for i = 0, bands do
        local t = i / bands
        love.graphics.setColor(
            tR + (hor[1] - tR) * t,
            tG + (hor[2] - tG) * t,
            tB + (hor[3] - tB) * t, 1)
        love.graphics.rectangle("fill", x, y + i * bandH, w, bandH)
    end
end

local function drawCelestialOf(g, x, y, w, bid, alpha)
    local b = BIOME_BY_ID[bid] or rawBiome()
    local cel = b.celestial
    if not cel or cel.painted then return end
    local cx = x + cel.xr * w
    local cy = y + cel.yr * (g.crestApexY - y)
    local c = cel.color
    love.graphics.setColor(c[1], c[2], c[3], 0.10 * alpha)
    love.graphics.circle("fill", cx, cy, cel.r * 2.1)
    love.graphics.setColor(c[1], c[2], c[3], 0.16 * alpha)
    love.graphics.circle("fill", cx, cy, cel.r * 1.45)
    love.graphics.setColor(c[1], c[2], c[3], 0.95 * alpha)
    love.graphics.circle("fill", cx, cy, cel.r)
    if cel.kind == "moon" then
        love.graphics.setColor(c[1] * 0.72, c[2] * 0.72, c[3] * 0.78, 0.9 * alpha)
        love.graphics.circle("fill", cx - cel.r * 0.28, cy - cel.r * 0.12, cel.r * 0.22)
        love.graphics.circle("fill", cx + cel.r * 0.30, cy + cel.r * 0.30, cel.r * 0.16)
        love.graphics.circle("fill", cx + cel.r * 0.12, cy - cel.r * 0.42, cel.r * 0.12)
    end
end

local function drawCelestial(g, x, y, w)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawCelestialOf(g, x, y, w, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
        drawCelestialOf(g, x, y, w, rawBiome().id, t)
    else
        drawCelestialOf(g, x, y, w, rawBiome().id, 1)
    end
end

local function drawBirds(g, x, y, w)
    local skyH = g.crestApexY - y
    for _, bd in ipairs(WorldRoad._birds) do
        local bx = x + bd.xr * w
        local by = y + bd.yr * skyH + math.sin(WorldRoad._time * 2.2 + bd.phase) * 3
        local up = math.sin(WorldRoad._time * 9 + bd.phase) > 0
        local wy = up and -2 or 0
        love.graphics.setColor(0.12, 0.10, 0.10, 0.85)
        love.graphics.rectangle("fill", math.floor(bx - 4), math.floor(by + wy), 3, 1)
        love.graphics.rectangle("fill", math.floor(bx + 2), math.floor(by + wy), 3, 1)
        love.graphics.rectangle("fill", math.floor(bx - 1), math.floor(by), 2, 2)
    end
end

local hazeShader, hazeShaderTried
local function getHazeShader()
    if hazeShaderTried then return hazeShader end
    hazeShaderTried = true
    local ok, sh = pcall(love.graphics.newShader, "shaders/haze.glsl")
    if ok then hazeShader = sh end
    return hazeShader
end

local CLOUD_HAZE = 0.42

local function normTint(t)
    local m = math.max(t[1], t[2], t[3])
    if m <= 0.001 then return 1, 1, 1 end
    return t[1] / m, t[2] / m, t[3] / m
end

local function drawClouds(g, x, y, w)
    local tint = envColor("cloud")
    local sw = math.sqrt(w / 1024)
    local tr, tg, tb = normTint(tint)
    local sky = mountainsSkyColor(rawBiome().id) or envColor("skyHorizon")
    local hz = getHazeShader()
    for _, c in ipairs(WorldRoad._clouds) do
        local img = getSprite("cloud", c.variant)
        if img then
            local a = math.min(1, (tint[4] or 0.5) + 0.35) * (c.far and 0.7 or 1)
            local s = c.scale * sw
            local bob = math.sin(WorldRoad._time * 0.35 + (c.phase or 0)) * 4
            local cx2 = math.floor(x + c.xr * w)
            local cy2 = math.floor(y + c.yr * (g.crestApexY - y) * 0.8 + bob)
            local iw2, ih2 = img:getWidth(), img:getHeight()
            local sq = 1
            if c._pokeT then
                local e = WorldRoad._time - c._pokeT
                if e < 1.1 then
                    sq = 1 + math.sin(e * 13) * 0.10 * math.exp(-e * 3)
                else c._pokeT = nil end
            end
            local dx2 = cx2 + math.floor(iw2 * s / 2)
            local dy2 = cy2 + math.floor(ih2 * s / 2)
            love.graphics.setColor(tr, tg, tb, a)
            love.graphics.draw(img, dx2, dy2,
                0, s * sq, s / sq, iw2 / 2, ih2 / 2)
            if hz and sky then
                love.graphics.setShader(hz)
                hz:send("hazeColor", { sky[1], sky[2], sky[3] })
                love.graphics.setColor(1, 1, 1, a * CLOUD_HAZE)
                love.graphics.draw(img, dx2, dy2,
                    0, s * sq, s / sq, iw2 / 2, ih2 / 2)
                love.graphics.setShader()
            end
            local hsn = WorldRoad._hitScene
            hsn[#hsn + 1] = { x1 = cx2, y1 = cy2, x2 = cx2 + iw2 * s,
                              y2 = cy2 + ih2 * s, ref = c, kind = "cloud" }
        end
    end
end

local _gradV, _gradH
local function gradTex()
    if not _gradV then
        local n = 256
        local idv = love.image.newImageData(1, n)
        for i = 0, n - 1 do
            idv:setPixel(0, i, 1, 1, 1, 1 - i / (n - 1))
        end
        _gradV = love.graphics.newImage(idv)
        _gradV:setFilter("linear", "linear")
        local idh = love.image.newImageData(n, 1)
        for i = 0, n - 1 do
            idh:setPixel(i, 0, 1, 1, 1, 1 - i / (n - 1))
        end
        _gradH = love.graphics.newImage(idh)
        _gradH:setFilter("linear", "linear")
    end
    return _gradV, _gradH
end

function PropCut.sunXr(bid)
    local b = (bid and BIOME_BY_ID[bid]) or rawBiome()
    local cel = b.celestial
    if not cel then return nil end
    if not (cel.painted and cel.drift) then return cel.xr end
    local base = (b.id == rawBiome().id) and WorldRoad._segBase or WorldRoad._segBasePrev
    local p = ((WorldRoad._camZ or 0) - (base or 0)) / (SEGMENT_LEN - WorldRoad.TRAVEL_DISTANCE)
    return cel.xr + cel.drift * (1 - 2 * math.max(0, math.min(1, p)))
end
WorldRoad.sunXr = PropCut.sunXr

local function sunShadowDir(g, x, w, px)
    local xr = PropCut.sunXr()
    local sunX = xr and (x + xr * w) or g.cx
    return math.max(-1, math.min(1, (px - sunX) / (w * 0.5)))
end

local function ridge(seed, i)
    return math.sin(i * 0.7 + seed) * 0.5 + math.sin(i * 0.23 + seed * 2.3) * 0.35
         + math.sin(i * 1.7 + seed * 0.7) * 0.15
end

local function stripTransform(g, x, w, camZ, iw, ih, bid)
    local cel = bid and (BIOME_BY_ID[bid] or PropCut.EMPTY).celestial
    local sx = math.max(w / math.max(iw, PropCut.STRIP_W), (g.crestApexY - g.y + 70) / ih)
    local yTop = math.floor(g.crestApexY - ih * sx + math.min(70, ih * sx * 0.22))
    local tileW = iw * sx
    local off = (cel and cel.painted) and (cel.painted * tileW - PropCut.sunXr(bid) * w)
        or (camZ * 2.5 * sx) % tileW
    return sx, yTop, tileW, off
end

local function drawStripTiles(img, x, sx, yTop, tileW, off)
    for k = -1, 2 do
        love.graphics.draw(img, math.floor(x - off + k * tileW), yTop, 0, sx, sx)
    end
end

local function drawStripMirrorBelow(img, x, sx, yTop, tileW, off, bottomY)
    local ih = img:getHeight()
    local stripH = ih * sx
    local seamY = math.floor(yTop + stripH)
    local b = 0
    local yb = seamY
    while yb < bottomY and b < 6 do
        local flipped = (b % 2 == 0)
        for k = -1, 2 do
            local dx = math.floor(x - off + k * tileW)
            if flipped then
                love.graphics.draw(img, dx, yb + stripH, 0, sx, -sx)
            else
                love.graphics.draw(img, dx, yb, 0, sx, sx)
            end
        end
        yb = yb + stripH
        b = b + 1
    end
    return yb
end

local function drawMountainsOf(g, x, w, camZ, bid, alpha)
    if _G.WR_DEBUG then require("src.core.Debug").trace("[WR] mountainsOf bid=" .. tostring(bid) .. " a=" .. alpha) end
    local img = getSprite("mountains", 0, bid)
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih, bid)
        local c = Scene.Grade.color("mountain", 0, LMG.c)
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        drawStripTiles(img, x, sx, yTop, tileW, off)
        drawStripMirrorBelow(img, x, sx, yTop, tileW, off, g.bottomY)
        return true
    end
    return false
end

local function drawMountains(g, x, w, camZ)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        local curOk = drawMountainsOf(g, x, w, camZ, rawBiome().id, 1)
        local prevOk = drawMountainsOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
        if prevOk or curOk then return end
    else
        if drawMountainsOf(g, x, w, camZ, rawBiome().id, 1) then return end
    end

    local img = getSprite("mountains", 0)
    if img then
        local iw, ih = img:getWidth(), img:getHeight()
        local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        drawStripTiles(img, x, sx, yTop, tileW, off)
    else
        for layer = 1, 2 do
            local color = layer == 1 and envColor("hillsFar") or envColor("hillsNear")
            local par = layer == 1 and 1.2 or 2.6
            local amp = layer == 1 and 26 or 16
            local base = layer == 1 and 30 or 14
            love.graphics.setColor(color[1], color[2], color[3], 1)
            for sx = 0, w - 1, 4 do
                local i = (sx + camZ * par) * 0.05
                local hgt = base + (ridge(layer * 3.7, i) * 0.5 + 0.5) * amp
                love.graphics.rectangle("fill", x + sx, g.crestApexY - hgt, 4, hgt + 20)
            end
        end
    end
end

local function drawMountainsFrontOf(g, x, w, camZ, bid, alpha)
    local img = getSprite("mountains_front", 0, bid)
    if _G.WR_DEBUG then require("src.core.Debug").trace("[WR] frontOf bid=" .. tostring(bid) .. " a=" .. alpha .. " img=" .. tostring(img ~= nil and img ~= false)) end
    if not img then return false end
    local iw, ih = img:getWidth(), img:getHeight()
    local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih, bid)
    local c = Scene.Grade.color("mountain", 0, LMG.c)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    drawStripTiles(img, x, sx, yTop, tileW, off)
    return true
end

local function drawMountainsFront(g, x, w, camZ)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawMountainsFrontOf(g, x, w, camZ, rawBiome().id, 1)
        drawMountainsFrontOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id, 1 - t)
    else
        drawMountainsFrontOf(g, x, w, camZ, rawBiome().id, 1)
    end
end

local CASTLE_APPROACH = {
    fields = 2.9, highlands = 2.9, abyss = 3.1,
    frost = 2.3, marsh = 2.9, dusk = 2.7,
    far = 1.3,
}
local CASTLE_SINK_EXTRA = {
    fields = 0.06, frost = 0.07, marsh = 0.06, dusk = 0.06,
}
function WorldRoad.castleScale(g, w, bid, progress)
    local refW = math.min(w, g.h * 1.5)
    return (refW * 0.155) / 218 * (CASTLE_APPROACH.far + (progress ^ 1.4) * (CASTLE_APPROACH[bid] or 2.9))
end
function WorldRoad.castleBaseY(g, bid, cx, s, iw, ih, progress)
    local baseY = g.crestYAt(cx) + ih * s * (0.03 + 0.20 * (1 - progress) + (CASTLE_SINK_EXTRA[bid] or 0) * progress)
    local foot = require("src.ui.CastleFoot").limit(g, bid, cx, s, iw, ih)
    return (foot and foot > baseY) and foot or baseY
end
local function drawCastleOf(g, x, w, camZ, bid, alpha, segBase)
    local walked = math.max(0, camZ - (segBase or WorldRoad._segBase or 0))
    local progress = math.min(1, walked / SEGMENT_LEN)
    local img = getSprite("castle", 0, bid)
    if not img then return false end
    img = landmarkFrame(bid .. "_castle", (bid:byte(1) + #bid) * 0.7) or img
    do
        local en = WorldRoad._entry
        if en and en.doorK and en.doorK > 0.02 then
            local dfr = landmarkFrames(bid .. "_castle_door")
            if dfr then
                img = dfr[1 + math.floor(math.min(1, en.doorK) * (#dfr - 1) + 0.5)]
            end
        end
    end
    local iw, ih = img:getWidth(), img:getHeight()
    local s = WorldRoad.castleScale(g, w, bid, progress)
    local cx = g.cx
    if segBase == WorldRoad._segBase then
        cx = cx + require("src.ui.CastleDrift").offset(camZ, progress, w)
    end
    local baseY = WorldRoad.castleBaseY(g, bid, cx, s, iw, ih, progress)
    local lmc = Scene.Grade.cfg("landmarks").castle
    if alpha >= 1 and lmc and lmc.hillShadow then
        local crest2 = g.crestYAt(cx)
        local ry = math.max(2, (3 + 7 * progress) * g.h / 768)
        Scene.Contact.queueDisc(cx, crest2 + ry, iw * s * 0.42, ry,
            Scene.Grade.cfg("contact").alpha * 0.55, 0.01)
    end

    local cc = Scene.Grade.color("castle", 0.35 + 0.65 * progress, LMG.c)
    love.graphics.setColor(cc[1], cc[2], cc[3], alpha)
    love.graphics.draw(img, math.floor(cx - iw * s / 2),
        math.floor(baseY - ih * s), 0, s, s)
    if alpha >= 1 and lmc and lmc.lowFog and progress > 0.55 then
        WeatherEngine.drawLowFog(cx - iw * s * 0.6, baseY - ih * s * 0.12, iw * s * 1.2,
            ih * s * 0.12 + 4, Scene.Grade.cfg("lowFog"), (progress - 0.55) / 0.45 * 0.8)
    end

    if alpha >= 1 then
        WorldRoad._castleTop = {
            x = cx + iw * s * 0.18,
            y = baseY - ih * s * 0.82,
            s = s,
            progress = progress,
            h = ih * s, w = iw * s, baseY = baseY, cx = cx,
            bid = bid, iw = iw, ih = ih, drawX = math.floor(cx - iw * s / 2),
            drawY = math.floor(baseY - ih * s),
        }
        WorldRoad._castleBaseHalf = iw * s * 0.44
        GrassField.requireTufts(REL_CREST - 0.1, cx, iw * s * 1.06, 8,
            (ih * s * 0.05) / GrassField.CELL_H)

        local LW = Config.Lighting.WINDOW
        local bio = BIOME_BY_ID[bid]
        local wins = (bio and bio.lightWindows) or LW.anchors
        local wcol = (bio and bio.lightWindowColor) or LW.color
        local time = love.timer.getTime()
        for wi, a in ipairs(wins) do
            local wx = cx - iw * s / 2 + a[1] * iw * s
            local wy = baseY - ih * s + a[2] * ih * s
            local tx, ty = love.graphics.transformPoint(wx, wy)
            local sd = wi * 37.7
            local n = love.math.noise(time * 1.4, sd) * 0.75
                + love.math.noise(time * 4.0, sd + 37.2) * 0.25
            local fi = 0.86 + 0.14 * n
            local fr = 0.88 + 0.18 * n
            local r = LW.radiusK * iw * s
            LightEngine.submit({
                x = tx, y = ty, radius = r * 1.6 * fr,
                color = wcol, intensity = LW.intensity * 0.55 * fi,
                dither = true, ditherAmt = 0.28, levels = 8,
                seed = sd, z = 999,
            })
            LightEngine.submitMicro(tx, ty, r * 0.45 * fr, wcol,
                LW.intensity * fi, 999)
        end
    end
    return true
end

LMG.GLUE = { dRel = 5.0, gap = 0.008, halfW = 70, laneMax = 2.4, behind = 1.5 }
WorldRoad.GLUE = LMG.GLUE

function LMG.lumPrepass(g, w, camZ)
    WorldRoad._lumBoxN = 0
    local screenK = WorldRoad.enemyScreenK(g.h)
    for _, p in ipairs(WorldRoad._props) do
        local d = not p.ghost and LuminaireEngine.def(p.bid, p.kind)
        local tP = d and d.roadside and g.tOf(p.z - camZ)
        if tP and tP > 0.3 then
            local img = getSprite(p.kind, p.variant, p.bid)
            if img then
                local size = kindSize(p.kind, p.bid) * (p.big or 1) * (PropCut.sizeK[img] or 1)
                local sc = g.scaleAt(size, tP, img:getHeight())
                if PropCut.nearFade(sc, screenK, true) > 0 then
                    local halfR = ROAD_HALF * w * (0.30 + 0.70 * (tP ^ 1.15))
                    local px = g.cx + WorldRoad.postCenter(p.bid, p.kind, p.side, sc, halfR, p.variant)
                        + roadWobble(p.z, tP, w)
                    local py = g.latY(px - g.cx, tP)
                    local n = WorldRoad._lumBoxN + 1
                    local lbx = WorldRoad._lumBoxes[n] or {}
                    WorldRoad._lumBoxes[n] = lbx
                    lbx.x1, lbx.x2 = px - img:getWidth() * sc * 0.5, px + img:getWidth() * sc * 0.5
                    lbx.y1, lbx.y2 = py - img:getHeight() * sc, py
                    WorldRoad._lumBoxN = n
                end
            end
        end
    end
end

local function drawCastle(g, x, w, camZ)
    LMG.lumPrepass(g, w, camZ)
    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawCastleOf(g, x, w, camZ, rawBiome().id, 1, WorldRoad._segBase)
        drawCastleOf(g, x, w, camZ, rawBiome(WorldRoad._prevBiomeIndex).id,
            1 - t, WorldRoad._segBasePrev)
    else
        drawCastleOf(g, x, w, camZ, rawBiome().id, 1, WorldRoad._segBase)
    end

    for _, sp in ipairs(WorldRoad._smoke) do
        local a = math.min(1, sp.life / 1.4) * 0.42
        local sz = sp.size
        love.graphics.setColor(0.80, 0.77, 0.72, a)
        love.graphics.rectangle("fill", math.floor(sp.x - sz / 2),
            math.floor(sp.y - sz / 2), sz, sz)
        love.graphics.setColor(0.74, 0.71, 0.66, a * 0.85)
        love.graphics.rectangle("fill", math.floor(sp.x - sz * 0.9),
            math.floor(sp.y - sz * 0.1), math.max(1, sz * 0.6), math.max(1, sz * 0.6))
        love.graphics.rectangle("fill", math.floor(sp.x + sz * 0.35),
            math.floor(sp.y - sz * 0.7), math.max(1, sz * 0.55), math.max(1, sz * 0.55))
    end
end

local function drawEncounterBehind(g, x, w, camZ)
    local e = WorldRoad._encounter
    if not e or not WorldRoad._travel then return end
    local rel = e.z - camZ
    if rel <= REL_CREST then return end
    if rel > REL_CREST + EMERGE_BAND then return end

    local em = 1 - (rel - REL_CREST) / EMERGE_BAND
    local cx = g.cx + roadWobble(e.z, 0, w)
    local crest = g.crestYAt(cx)
    local tBattle = g.tOf(WorldRoad.BATTLE_REL) or 0.3
    local s = e.targetScale * WorldRoad.battleSizeK() * WorldRoad.enemyScreenK(g.h)
        * (g.persp(0) / math.max(0.01, g.persp(tBattle)))
    cx = cx - math.floor((e.offX or 0) * s)
    local feetY = crest + e.ih * s * (1 - em) * 0.95
    love.graphics.setColor(1, 1, 1, 1)
    local bx0 = math.floor(cx - e.iw * s / 2)
    local by0 = math.floor(feetY - e.ih * s)
        + math.floor((e.footPad or 0) * s)
    if e.anim then
        e.anim:draw(bx0, by0, s)
    else
        love.graphics.draw(e.img, bx0, by0, 0, s, s)
    end
end

local function drawPropsBehind(g, x, w, camZ)
    for _, p in ipairs(WorldRoad._props) do
        local rel = p.z - camZ
        local fadeA = propFadeK(p) * PropCut.hideK(p)
        local roadLum = LuminaireEngine.def(p.bid, p.kind)
        roadLum = roadLum and roadLum.roadside
        if WorldRoad._fork and not roadLum and not PropCut.kinds[p.kind] then fadeA = 0 end
        if fadeA > 0.01 and rel > REL_CREST and rel <= REL_CREST + EMERGE_BAND then
            local em = 1 - (rel - REL_CREST) / EMERGE_BAND
            local pxX = g.cx + p.side * w * (0.11 + p.lane * 0.38)
            local edef = LuminaireEngine.def(p.bid, p.kind)
            if edef and edef.roadside then
                pxX = g.cx + p.side * WorldRoad.postLateral(ROAD_HALF * w * 0.30, p.bid) + roadWobble(p.z, 0, w)
            end
            local crest = g.crestYAt(pxX)
            local img = getSprite(p.kind, p.variant, p.bid)
            if edef and crest and img and math.abs(pxX - g.cx) < w * 0.26 then
                local lumAnc = LuminaireEngine.anchor(p.bid, p.kind, p.variant,
                    luminairePath(p.bid, p.kind, p.variant))
                local lumFlip = 1
                if edef.face and edef.face ~= 0 then
                    local want = p.side < 0 and 1 or -1
                    lumFlip = (want == edef.face) and 1 or -1
                end
                local fr = luminaireFrames(p.bid, p.kind, p.variant)
                if fr then
                    local ph = (p.z * 7.31) % #fr
                    img = fr[1 + math.floor((WorldRoad._time * 10 + ph) % #fr)]
                end
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1) * PropCut.crestK(p.kind, 0)
                local s = g.scaleAt(size, 0, ih)
                local ct = WorldRoad._castleTop
                if ct and not roadLum then
                    fadeA = fadeA * math.min(1, math.max(0, (math.abs(pxX - ct.cx) - ct.w * 0.5) / (ct.w * 0.24)))
                end
                local px2, pin = pxX - (lumAnc.offX or 0) * s * lumFlip, (lumAnc.offX or 0) * s * lumFlip
                if edef.roadside then
                    local pcx
                    pcx, lumFlip, pin = WorldRoad.postCenter(p.bid, p.kind, p.side, s, ROAD_HALF * w * 0.30, p.variant)
                    px2 = g.cx + pcx + roadWobble(p.z, 0, w)
                end
                local sink = (1 - em) * ih * s
                local baseY = crest + sink
                if WorldRoad._trace then
                    WorldRoad._trace(p, px2 + pin, baseY, fadeA, 0, "behind", ih * s, iw * s,
                        g.cx + roadWobble(p.z, 0, w), ROAD_HALF * w * 0.30)
                end
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind, true), 0, LMG.c)
                love.graphics.setColor(cb[1] * 0.7, cb[2] * 0.7, cb[3] * 0.7, fadeA)
                love.graphics.draw(img, math.floor(px2), math.floor(baseY),
                    0, s * lumFlip, s, iw / 2, ih)
                local flameTopY = baseY - ih * s * (1 - (lumAnc.ay or 0.3))
                if flameTopY > crest - ih * s and flameTopY < baseY then
                    local ax = lumAnc.ax or 0.5
                    if lumFlip < 0 then ax = 1 - ax end
                    local fx = px2 + (ax - 0.5) * iw * s
                    local fxT, fyT = love.graphics.transformPoint(fx, flameTopY)
                    local gxT, gyT = love.graphics.transformPoint(fx, baseY)
                    LuminaireEngine.submit(p.bid, p.kind, {
                        fx = fxT, fy = fyT, gx = gxT, gy = gyT,
                        sh = ih * s, t = 0, rel = rel, seed = p.z,
                        flameH = math.max(8, gyT - fyT), capR = g.h * 0.30,
                        alphaK = fadeA,
                    })
                end
                love.graphics.setColor(1, 1, 1, 1)
                goto continue_emerge
            end
            if crest and img and math.abs(pxX - g.cx) < w * 0.26 then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1) * PropCut.crestK(p.kind, 0)
                local s = g.scaleAt(size, 0, ih)
                local isTree = (p.kind == "tree" or p.kind == "pine"
                    or p.kind == "deadtree" or p.kind == "bush")
                local vflip, vtR, vtG, vtB = 1, 1, 1, 1
                if isTree then
                    local pv = Scene.Var.of(p.z, p.kind, Scene.Grade.cfg("trees"))
                    s = s * pv.scale
                    vflip, vtR, vtG, vtB = pv.flip, pv.tintR, pv.tintG, pv.tintB
                end
                local _, ihv = PropCut.get(img, p.kind)
                local sink = (1 - em) * ihv * s
                if WorldRoad._traceVeg and isTree then WorldRoad._traceVeg(p, fadeA, pxX, crest, iw * s, ih * s, 0, "behind", em) end
                if p.cluster and isTree then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cimg = getSprite(p.kind, (p.variant + ci) % PropCut.nvar(p.bid, p.kind), p.bid)
                        if cimg then
                            local cvv = Scene.Var.of(p.z + ci * 17.3, p.kind, Scene.Grade.cfg("trees"))
                            local cs = s * (0.5 + 0.13 * ci) * cvv.scale
                            local ccrest = g.crestYAt(pxX + off) or crest
                            local _, cihv = PropCut.get(cimg, p.kind)
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                            love.graphics.setColor(math.min(1, cc[1] * 0.6 * cvv.tintR),
                                math.min(1, cc[2] * 0.6 * cvv.tintG),
                                math.min(1, cc[3] * 0.6 * cvv.tintB), fadeA)
                            local cprev = PropCut.beginDepth(cimg, 0)
                            PropCut.draw(cimg, p.kind, math.floor(pxX + off),
                                math.floor(ccrest + (1 - em) * cihv * cs), 0, cs * cvv.flip, cs)
                            PropCut.endDepth(cprev)
                        end
                    end
                end
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                love.graphics.setColor(math.min(1, cb[1] * 0.66 * vtR), math.min(1, cb[2] * 0.66 * vtG),
                    math.min(1, cb[3] * 0.66 * vtB), fadeA)
                local bprev = nil
                if isTree then bprev = PropCut.beginDepth(img, 0) end
                PropCut.draw(img, p.kind, math.floor(pxX),
                    math.floor(crest + sink), 0, s * vflip, s)
                PropCut.endDepth(bprev)
            end
        end
        ::continue_emerge::
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local GROUND_TEX_W, GROUND_TEX_H = 128, 96
local GROUND_TEX_SCALE = 5

local groundTexCache = {}
local function getGroundTexture(bid)
    if groundTexCache[bid] then return groundTexCache[bid] end
    local b = BIOME_BY_ID[bid] or rawBiome()
    local tw, th = GROUND_TEX_W, GROUND_TEX_H
    local data = love.image.newImageData(tw, th)
    local rng = love.math.newRandomGenerator(#bid * 3313)
    local base = b.grassA
    local dark = b.grassB
    local light = { b.grassA[1] * 1.14, b.grassA[2] * 1.14, b.grassA[3] * 1.08 }
    for yy = 0, th - 1 do
        for xx = 0, tw - 1 do
            data:setPixel(xx, yy, base[1], base[2], base[3], 1)
        end
    end
    local mid = { (base[1] + dark[1]) / 2, (base[2] + dark[2]) / 2, (base[3] + dark[3]) / 2 }
    local accent = b.accent or light
    local accentDim = { accent[1] * 0.55 + base[1] * 0.45,
                        accent[2] * 0.55 + base[2] * 0.45,
                        accent[3] * 0.55 + base[3] * 0.45 }
    local function clump(cx, cy, r, c, holes)
        for dy = -r, r do
            for dx = -r, r do
                if dx * dx + dy * dy <= r * r and rng:random() > (holes or 0.3) then
                    data:setPixel((cx + dx) % tw, (cy + dy) % th, c[1], c[2], c[3], 1)
                end
            end
        end
    end
    for _ = 1, 7 do
        clump(rng:random(0, tw - 1), rng:random(0, th - 1), rng:random(9, 14), mid, 0.45)
    end
    for _ = 1, 22 do
        clump(rng:random(0, tw - 1), rng:random(0, th - 1), rng:random(3, 7), dark)
    end
    for _ = 1, 16 do
        clump(rng:random(0, tw - 1), rng:random(0, th - 1), rng:random(2, 5), light)
    end
    for _ = 1, 150 do
        local c = rng:random() < 0.5 and dark or light
        data:setPixel(rng:random(0, tw - 1), rng:random(0, th - 1), c[1], c[2], c[3], 1)
    end
    for _ = 1, 16 do
        local ax, ay = rng:random(1, tw - 2), rng:random(1, th - 2)
        data:setPixel(ax, ay, accentDim[1], accentDim[2], accentDim[3], 1)
        if rng:random() < 0.5 then
            data:setPixel(ax + 1, ay, accentDim[1] * 1.15, accentDim[2] * 1.15, accentDim[3] * 1.1, 1)
        end
    end
    for _ = 1, 26 do
        local bx2, by2 = rng:random(0, tw - 1), rng:random(1, th - 1)
        data:setPixel(bx2, by2,
            math.min(1, light[1] * 1.08), math.min(1, light[2] * 1.08), light[3], 1)
        data:setPixel(bx2, by2 - 1,
            math.min(1, light[1] * 1.16), math.min(1, light[2] * 1.16),
            math.min(1, light[3] * 1.05), 1)
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    img:setWrap("repeat", "repeat")
    groundTexCache[bid] = { img = img, quad = love.graphics.newQuad(0, 0, 1, 1, tw, th) }
    return groundTexCache[bid]
end

local GROUND_V_DENSITY = 4.8
local domeSlots = {}
local function drawDomeTexOf(g, x, w, bid, alpha, slot)
    local tex = getGroundTexture(bid)
    local ds = domeSlots[slot]
    if not ds then
        ds = { qm = QuadMesh.new(4096) }
        domeSlots[slot] = ds
    end
    local camZ = WorldRoad._camZ
    if ds.camZ ~= camZ or ds.x ~= x or ds.w ~= w or ds.cx ~= g.cx
       or ds.top ~= g.crestApexY or ds.bottom ~= g.bottomY or ds.R ~= g.R
       or ds.tex ~= tex then
        ds.camZ, ds.x, ds.w, ds.cx = camZ, x, w, g.cx
        ds.top, ds.bottom, ds.R = g.crestApexY, g.bottomY, g.R
        ds.tex = tex
        WorldRoad._domeBuilds = (WorldRoad._domeBuilds or 0) + 1
        local qm = ds.qm
        qm:reset()
        local domeTop = g.crestApexY
        local H = g.bottomY - domeTop
        local step = 3
        local TW, TH = GROUND_TEX_W, GROUND_TEX_H
        for sy = 0, H - 1, step do
            local t = sy / H
            local tn = math.min(1, (sy + step) / H)
            local rel = REL_CREST * (1 - t ^ (1 / T_POW))
            local relNext = REL_CREST * (1 - tn ^ (1 / T_POW))
            local worldZ = camZ + rel
            local dv = math.min(20, math.max(0.05, (rel - relNext) * GROUND_V_DENSITY))
            local v = (worldZ * GROUND_V_DENSITY) % GROUND_TEX_H
            local hs = GROUND_TEX_SCALE * (0.44 + 1.06 * t)
            local syK = (step + 1) / dv
            local v0, v1 = v / TH, (v + dv) / TH
            local SEG = (t < 0.3) and 8 or 32
            for segX = x, x + w - 1, SEG do
                local segW = math.min(SEG, x + w - segX)
                local dxMid = (segX + segW / 2) - g.cx
                local segY = g.latY(dxMid, t)
                if segY < g.bottomY + 30 then
                    local vx, vw = (segX - g.cx) / hs, segW / hs
                    qm:rect(segX, math.floor(segY), hs * vw, syK * dv,
                        vx / TW, v0, (vx + vw) / TW, v1, 1, 1, 1, 1)
                end
            end
        end
        ds.count = qm.n
        qm:upload(0, qm.n)
    end
    local c = Scene.Grade.color("ground", 1, LMG.c)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    ds.qm:draw(0, ds.count, tex.img)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDome(g, x, y, w)
    local grassA = envColor("grassA")
    local grassB = envColor("grassB")
    local gc = Scene.Grade.color("ground", 1, LMG.c)
    local gr, gg, gb = gc[1], gc[2], gc[3]

    love.graphics.setColor(grassB[1] * 0.78 * gr, grassB[2] * 0.78 * gg, grassB[3] * 0.78 * gb, 1)
    love.graphics.circle("fill", g.cx, g.crestApexY + g.R, g.R, 256)

    local bl = WorldRoad._blend
    if bl and WorldRoad._prevBiomeIndex then
        local t = math.min(1, bl.t / bl.duration)
        drawDomeTexOf(g, x, w, rawBiome(WorldRoad._prevBiomeIndex).id, 1, 1)
        drawDomeTexOf(g, x, w, rawBiome().id, t, 2)
    else
        drawDomeTexOf(g, x, w, rawBiome().id, 1, 1)
    end

    do
        local phiEdge = math.asin(math.min(1, (w / 2) / g.R))
        love.graphics.setColor(grassA[1] * gr, grassA[2] * gg, grassA[3] * gb, 1)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", "open", g.cx, g.crestApexY + g.R, g.R - 1,
            -math.pi / 2 - phiEdge, -math.pi / 2 + phiEdge, 256)
        love.graphics.setLineWidth(1)
    end

    local bandH = (g.bottomY - g.crestApexY) * 0.22
    local phiMax = math.acos(math.max(-1, 1 - bandH / g.R))
    phiMax = math.min(phiMax, math.asin(math.min(1, w * 0.26 / g.R)))
    love.graphics.setColor(grassA[1] * 1.16 * gr, grassA[2] * 1.16 * gg, grassA[3] * 1.10 * gb, 0.85)
    love.graphics.setLineWidth(4)
    love.graphics.arc("line", "open", g.cx, g.crestApexY + g.R, g.R - 2,
        -math.pi / 2 - phiMax, -math.pi / 2 + phiMax)
    love.graphics.setLineWidth(1)
end

local function drawTerrainDetail(g, x, w, camZ)
    local gA = envColor("grassA")
    local gB = envColor("grassB")
    local gc = Scene.Grade.color("ground", 1, LMG.c)
    local dark  = { gB[1] * 0.70 * gc[1], gB[2] * 0.70 * gc[2], gB[3] * 0.70 * gc[3] }
    local light = { math.min(1, gA[1] * 1.45) * gc[1], math.min(1, gA[2] * 1.40) * gc[2],
                    math.min(1, gA[3] * 1.25) * gc[3] }

    local CELL_R = 3.1
    for ci = math.floor(camZ / CELL_R),
             math.floor((camZ + REL_CREST) / CELL_R) do
        local h1 = ((ci * 40787) % 1021) / 1021
        if h1 < 0.5 then
            local z = ci * CELL_R + h1 * 2.2
            local rel = z - camZ
            local t = g.tOf(rel)
            if t and t > 0.16 and t < 0.9 then
                local h2 = ((ci * 69497) % 1013) / 1013
                local side = (ci % 2 == 0) and -1 or 1
                local roadC = g.cx + roadWobble(z, t, w)
                local half = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
                local cxr = roadC + side * (half + w * (0.03 + h2 * 0.22)
                    * (0.35 + 0.65 * t))
                local halfW = w * (0.04 + h2 * 0.06) * (0.35 + 0.65 * t)
                local px2 = math.max(1, math.floor(2 * g.persp(t) + 0.5))
                local bump = math.max(2, math.floor(4 * g.persp(t) + 0.5))
                for dxx = -halfW, halfW, 3 do
                    local edge = 1 - (math.abs(dxx) / halfW) ^ 2
                    if edge > 0.2 then
                        local yy = math.floor(g.latY(cxr + dxx - g.cx, t)
                            - bump * edge)
                        love.graphics.setColor(light[1], light[2], light[3], 1)
                        love.graphics.rectangle("fill", math.floor(cxr + dxx),
                            yy, 3, math.max(1, px2))
                        love.graphics.setColor(dark[1], dark[2], dark[3], 1)
                        love.graphics.rectangle("fill", math.floor(cxr + dxx),
                            yy + px2, 3, px2)
                    end
                end
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local roadTileCache = {}
local function getRoadTile(bid)
    local hit = roadTileCache[bid]
    if hit ~= nil then return hit or nil end
    local img = tryLoadPng("road_dirt_" .. bid) or tryLoadPng("road_dirt")
    if img then
        img:setWrap("repeat", "repeat")
        roadTileCache[bid] = img
    else
        roadTileCache[bid] = false
    end
    return img
end
local RD_V_DENSITY = 5.2

local FORK_REL    = 10
local MARK_REL    = 17.5
local ARRIVE_REL  = 7.5
local FORK_SPREAD = 0.15

PropCut.KEEP = { margin = 0.012, castleT = 0.36, castleFoot = 0.02, castleCore = 0.07,
                 markHalf = 0.36, markTop = 0.92, varMax = 1.1, step = 0.75, jit = 0.05 }
function PropCut.castleNeed(p, kind, variant, big)
    local K = PropCut.KEEP
    local g, w = LMG.planGeom()
    local need = -1
    local cast = getSprite("castle", 0, p.bid)
    local img = getSprite(kind, variant, p.bid)
    if not (cast and img) then return need end
    local base = (math.min(w, g.h * 1.5) * 0.155) / 218
    local growth = CASTLE_APPROACH[p.bid] or 2.9
    local seg = WorldRoad._segBase or 0
    local CD = require("src.ui.CastleDrift")
    local _, ihv = PropCut.get(img, kind)
    local size = kindSize(kind, p.bid) * big * (PropCut.sizeK[img] or 1)
    local rel = REL_CREST + EMERGE_BAND
    while rel > 0 do
        local t = g.tOf(rel) or 0
        if t > K.castleT then break end
        local prog = math.min(1, math.max(0, (p.z - rel - seg) / SEGMENT_LEN))
        local cs = base * (CASTLE_APPROACH.far + prog ^ 1.4 * growth)
        local ch = cast:getHeight() * cs
        local cBase = g.crestYAt(g.cx) + ch * (0.03 + 0.20 * (1 - prog) + (CASTLE_SINK_EXTRA[p.bid] or 0) * prog)
        local ts = g.scaleAt(size * PropCut.crestK(kind, t), t, img:getHeight()) * K.varMax
        local top = (rel >= REL_CREST and g.crestYAt(g.cx) or g.latY(0, t)) - ihv * ts
        if top < cBase - ch * K.castleFoot then
            local hb = (K.castleCore * cast:getWidth() * cs + 0.15 * img:getWidth() * ts) / w + CD.MAX * CD.envelope(prog) + K.margin
            need = math.max(need, (hb - 0.11 - 0.38 * t) / 0.38)
        end
        rel = rel - K.step
    end
    return need
end
function PropCut.vegBox(p, camZ, g, w, out)
    local img = getSprite(p.kind, p.variant, p.bid)
    local rel = p.z - camZ
    local t = g.tOf(rel)
    if not img or not t then return nil end
    local K = PropCut.KEEP
    local _, ihv = PropCut.get(img, p.kind)
    local s = PropCut.capS(g.scaleAt(kindSize(p.kind, p.bid) * (p.big or 1) * (PropCut.sizeK[img] or 1)
        * PropCut.crestK(p.kind, t), t, img:getHeight()), WorldRoad.enemyScreenK(g.h))
        * Scene.Var.of(p.z, p.kind, Scene.Grade.cfg("trees")).scale
    local over = math.max(0, -rel)
    local x = g.cx + p.side * w * (0.11 + 0.38 * t + over * 0.09 + p.lane * 0.38)
    local y = g.latY(x - g.cx, t) + over * g.h * 0.13
    out = out or {}
    out.x1, out.x2 = x - img:getWidth() * s * K.markHalf, x + img:getWidth() * s * K.markHalf
    out.y1, out.y2 = y - ihv * s * K.markTop, y
    return out
end
function PropCut.clearLane(p)
    if p.ghost or not PropCut.kinds[p.kind] then return end
    local need = PropCut.castleNeed(p, p.kind, p.variant, p.big or 1)
    if p.lane < need then p.lane = need + WorldRoad._rng:random() * PropCut.KEEP.jit end
    local f = WorldRoad._fork
    if f and f.offK and not f.converge and p.z - (WorldRoad._camZ or 0) > REL_CREST then
        local g, w = LMG.planGeom()
        PropCut.forkHideOne(p, f, g, w, WorldRoad._camZ, true)
    end
end

LMG.PLAN = { midLo = 6.9, midHi = 12.3, midPick = 9.0, sameGap = 5, oppGap = 2.5,
             skipLo = FORK_REL + 3, skipHi = MARK_REL + 1, pushLo = FORK_REL - 1.5,
             nearLo = -3, nearHi = 6.0, battleNext = MARK_REL - ARRIVE_REL + 20,
             bands = { { lo = 6.1, hi = 12.5, battle = true, haveLo = 6.0, haveHi = 12.5 },
                       { lo = 18.6, hi = 19.5, haveLo = 13.5, haveHi = 20.5 },
                       { lo = 33.6, hi = 42.5, haveLo = 33.5, haveHi = 42.5 } } }
WorldRoad.LUM_PLAN = LMG.PLAN

function WorldRoad.planStop(stopZ, battle)
    WorldRoad._plan = { stop = stopZ, battle = battle and true or false }
    WorldRoad._reservePosts(WorldRoad._plan)
end

LMG.RESERVE = { spawnRel = REL_CREST + EMERGE_BAND, step = 0.4 }
function WorldRoad._reservePosts(pl, free)
    local b = rawBiome()
    local kind = LuminaireEngine.roadKind(b.id)
    if not kind or not WorldRoad._props or (#WorldRoad._props == 0 and not free) or not WorldRoad._rng then return end
    for _, band in ipairs(LMG.PLAN.bands) do
        if pl.battle or not band.battle then
            local have = false
            for _, q in ipairs(WorldRoad._props) do
                local qd = not q.ghost and LuminaireEngine.def(q.bid, q.kind)
                local qr = q.z - pl.stop
                if qd and qd.roadside and qr >= band.haveLo and qr <= band.haveHi then have = true end
            end
            local zLo = free and pl.stop + band.lo or math.max(pl.stop + band.lo, WorldRoad._camZ + LMG.RESERVE.spawnRel + 0.05)
            if not have and zLo <= pl.stop + band.hi then
                local first = WorldRoad._rng:random() < 0.5 and -1 or 1
                local placed = false
                for pass = 1, 2 do
                for _, side in ipairs({ first, -first }) do
                    local z = zLo
                    while not placed and z <= pl.stop + band.hi do
                        local p = { kind = kind, bid = b.id, side = side, z = z, lane = LuminaireEngine.ROAD_LANE,
                                    variant = 0, big = 1, jitter = 0, reserved = true }
                        local crowded = false
                        for _, q in ipairs(WorldRoad._props) do
                            local qd = not q.ghost and LuminaireEngine.def(q.bid, q.kind)
                            if qd and qd.roadside and math.abs(q.z - z) < (q.side == side
                               and LuminaireEngine.roadStep(b.id) * 0.75 or LMG.PLAN.oppGap) then
                                crowded = true
                            end
                        end
                        if (pass == 2 or not crowded) and WorldRoad.lumPlanVerdict(p, z, kind, b.id) ~= "skip" then
                            WorldRoad._uid = (WorldRoad._uid or 0) + 1
                            p.uid = WorldRoad._uid
                            WorldRoad._props[#WorldRoad._props + 1] = p
                            placed = true
                        end
                        z = z + LMG.RESERVE.step
                    end
                    if placed then break end
                end
                if placed then break end
                end
            end
        end
    end
end

function LMG.planGeom()
    local r = WorldRoad._lastRect
    if r then return domeGeom(r.x, r.y, r.w, r.h), r.w end
    local W, H = love.graphics.getDimensions()
    return domeGeom(0, 80, W, H - 80), W
end

function LMG.lumFits(p, z, kind, pl, bid)
    local g, w = LMG.planGeom()
    local G, P = LMG.GLUE, LMG.PLAN
    local img = getSprite(kind, 0, bid)
    if not img then return true end
    local size = kindSize(kind, bid)
    local rel = z - pl.stop
    for _, dk in ipairs(LMG.BATTLE_CAMS) do
        local cam = pl.stop + dk
        local relC = z - cam
        if (dk > 0 or pl.battle) and relC > -7 and relC < WorldRoad.BATTLE_REL + G.dRel then
            local relE = WorldRoad.BATTLE_REL
            local tE = g.tOf(relE)
            local box = tE and WorldRoad.postBox(bid, kind, p.side, z, cam, g, w, LMG.glueBox)
            if box then
                LMG.glueBox = box
                local ehw = G.halfW * WorldRoad.enemyScreenK(g.h) * WorldRoad.battleSizeK(relE)
                local ex = g.cx + roadWobble(cam + relE, tE, w)
                local eb = g.latY(0, tE)
                local m = G.gap * w
                local gq = LMG.glueQ or {}
                LMG.glueQ = gq
                gq.bid, gq.kind, gq.side, gq.z = bid, kind, p.side, z
                local B = WorldRoad._postBase(gq, cam, g, w, LMG.glueBase)
                LMG.glueBase = B
                local px1, px2 = box.x1, box.x2
                if B then px1, px2 = B.x1, B.x2 end
                local touch = px1 < ex + ehw + m and px2 > ex - ehw - m and box.y1 < eb and box.y2 > eb - ehw * 2.6
                if touch and relC < relE + G.behind then return false end
            end
        end
    end
    for _, dk in ipairs(LMG.FORK_CAMS) do
        local rf = rel - dk
        local tf = g.tOf(rf)
        if tf and rf > FORK_REL - 0.5 and rf < P.skipHi then
            local k = math.min(1, math.max(0, (rf - FORK_REL) / (MARK_REL - FORK_REL)))
            k = k * k * (3 - 2 * k)
            local hf = ROAD_HALF * w * (0.30 + 0.70 * (tf ^ 1.15))
            local wob = roadWobble(z, tf, w)
            local sf = g.scaleAt(size, tf, img:getHeight())
            local _, _, _, footX = WorldRoad.postCenter(bid, kind, p.side, sf, hf)
            local anc = LuminaireEngine.anchor(bid, kind, 0, luminairePath(bid, kind, 0))
            local fw = ((anc.fR or 2) - (anc.fL or -2)) * sf
            local a = math.abs(footX + wob - wob * 0.5)
            local b = a + fw
            local half = hf * (1 - 0.22 * k) * (1 + WorldRoad.POST_JAG)
            local c = FORK_SPREAD * w * k
            if a < half or (a < c + half and b > c - half) then return false end
        end
    end
    return true
end
LMG.FORK_CAMS = { 0, MARK_REL - ARRIVE_REL, 2 * (MARK_REL - ARRIVE_REL), MARK_REL - ARRIVE_REL + 20 }
LMG.BATTLE_CAMS = { 0, MARK_REL - ARRIVE_REL + 20 }

function WorldRoad.postBox(bid, kind, side, z, camZ, g, w, out)
    local img = getSprite(kind, 0, bid)
    if not img then return nil end
    local rel = z - camZ
    local t = g.tOf(rel)
    if not t or t < 0 then return nil end
    local over = math.max(0, -rel)
    local iw, ih = img:getWidth(), img:getHeight()
    local s = g.scaleAt(kindSize(kind, bid) * (PropCut.sizeK[img] or 1) * PropCut.crestK(kind, t), t, ih)
    local halfR = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
    local wob = roadWobble(z, t, w)
    local sy = g.latY(side * WorldRoad.postLateral(halfR, bid) + wob, t) + over * g.h * 0.13
    local pcx, flip = WorldRoad.postCenter(bid, kind, side, s, halfR, 0)
    local px = g.cx + pcx + wob
    local anc = LuminaireEngine.anchor(bid, kind, 0, luminairePath(bid, kind, 0))
    local base = sy + (anc.footPad or 0) * s
    local _, ihv = PropCut.get(img, kind)
    local cr = contentRect[img]
    out = out or {}
    if cr then
        local rx0, rx1 = (cr.x0 - iw * 0.5) * s * flip, (cr.x1 + 1 - iw * 0.5) * s * flip
        out.x1, out.x2 = px + math.min(rx0, rx1), px + math.max(rx0, rx1)
        out.y1, out.y2 = base + (cr.y0 - ihv) * s, base + (math.min(cr.y1 + 1, ihv) - ihv) * s
    else
        out.x1, out.x2, out.y1, out.y2 = px - iw * s * 0.5, px + iw * s * 0.5, base - ihv * s, base
    end
    out.rel, out.t = rel, t
    return out
end

LMG.MARK_SLOT = { margin = 18, label = 30, labelHalf = 64 }
function LMG.markExtent(g, bid, w, relX)
    local tM = g.tOf(relX or MARK_REL)
    if not tM then return nil end
    local key = bid .. "|" .. w .. "|" .. g.h .. "|" .. (relX or MARK_REL)
    local c = LMG.extCache or {}
    LMG.extCache = c
    if c[key] then return c[key] end
    local S = LMG.MARK_SLOT
    local hw, hh = S.labelHalf, 0
    for ty in pairs(LANDMARK_FOR_TYPE) do
        local k = landmarkKeyFor(ty, bid)
        local img = k and getLandmark(k)
        if img then
            local sc = g.scaleAt(lmCfg(LANDMARK_SIZE, k) or 2.0, tM, LMG.refH(k, img:getHeight()))
            hw = math.max(hw, img:getWidth() * sc * 0.5)
            hh = math.max(hh, img:getHeight() * sc)
        end
    end
    c[key] = { hw = hw, hh = hh, t = tM }
    return c[key]
end

function LMG.markSlotOk(p, z, kind, bid, cam)
    local rel = z - cam
    if rel >= MARK_REL or rel <= -7 then return true end
    local g, w = LMG.planGeom()
    local E = LMG.markExtent(g, bid, w)
    local box = E and WorldRoad.postBox(bid, kind, p.side, z, cam, g, w, LMG.slotBox)
    if not box then return true end
    LMG.slotBox = box
    LMG.cand = LMG.cand or {}
    local c = LMG.cand
    c.bid, c.kind, c.side, c.z = bid, kind, p.side, z
    E.bid = bid
    if not LMG.centerClear(g, w, E, cam, LMG.slotBox, rel) then return false end
    return LMG.marksFeasible(g, w, E, cam, p, c)
end

function LMG.centerClear(g, w, E, cam, box, rel)
    local G, S = LMG.GLUE, LMG.MARK_SLOT
    local relE = WorldRoad.BATTLE_REL
    local ehw = G.halfW * WorldRoad.enemyScreenK(g.h) * WorldRoad.battleSizeK(relE)
    local A = LMG.markExtent(g, E.bid, w, ARRIVE_REL)
    if not A then return true end
    local objs = LMG.CC or { {}, {} }
    LMG.CC = objs
    objs[1][1], objs[1][2], objs[1][3] = ARRIVE_REL, A.hw, A.hh
    objs[2][1], objs[2][2], objs[2][3] = relE, ehw, ehw * 2.6
    for _, o in ipairs(objs) do
        local t = g.tOf(o[1])
        if t and rel < o[1] + G.behind then
            local ox = g.cx + roadWobble(cam + o[1], t, w)
            local oy = g.latY(0, t)
            local hw = o[2] + S.margin
            if box.x1 < ox + hw and box.x2 > ox - hw and box.y1 < oy + S.margin and box.y2 > oy - o[3] - S.margin then
                return false
            end
        end
    end
    return true
end

LMG.DIRS = { 0, -1, 1 }
function LMG.marksFeasible(g, w, E, cam, self, cand)
    local F, S = LMG.MARK_FIT, LMG.MARK_SLOT
    local MF = LMG.MF or { boxP = {}, baseP = {}, boxes = {}, bases = {}, placed = {}, pl = {} }
    LMG.MF = MF
    local boxes, bases = MF.boxes, MF.bases
    local nb, nB = 0, 0
    local function add(q)
        local rel = q.z - cam
        if rel < MARK_REL and rel > -7 then
            local o = WorldRoad.postBox(q.bid, q.kind, q.side, q.z, cam, g, w, MF.boxP[nb + 1] or {})
            if o then nb = nb + 1; MF.boxP[nb] = o; boxes[nb] = o end
        end
        if rel > FORK_REL then
            local o = WorldRoad._postBase(q, cam, g, w, MF.baseP[nB + 1] or {})
            if o then nB = nB + 1; MF.baseP[nB] = o; bases[nB] = o end
        end
    end
    for _, q in ipairs(WorldRoad._props) do
        local d = q ~= self and not q.ghost and LuminaireEngine.def(q.bid, q.kind)
        if d and d.roadside then add(q) end
    end
    add(cand)
    for i = nb + 1, #boxes do boxes[i] = nil end
    for i = nB + 1, #bases do bases[i] = nil end
    local tM = E.t
    local hw = E.hw + S.margin
    local wobM = roadWobble(cam + MARK_REL, tM, w) * 0.5
    local placed, np = MF.placed, 0
    for i = #placed, 1, -1 do placed[i] = nil end
    for _, d in ipairs(LMG.DIRS) do
        local k0 = d * FORK_SPREAD
        local n = math.floor(0.25 / F.step + 0.5)
        local found = false
        for j = 0, 2 * n do
            local k = k0 + (j % 2 == 0 and 1 or -1) * math.floor((j + 1) / 2) * F.step
            if (d == 0 and math.abs(k) <= F.centerMax) or (d ~= 0 and k * d >= F.sideMin and k * d <= 0.40) then
                local off = k * w + wobM
                local py = g.latY(off, tM)
                local x1, x2 = g.cx + off - hw, g.cx + off + hw
                local y1, y2 = py - E.hh - S.label - S.margin, py + S.margin
                local ok = true
                for _, q in ipairs(boxes) do
                    if q.x1 < x2 and q.x2 > x1 and q.y1 < y2 and q.y2 > y1 then ok = false break end
                end
                if ok then
                    for _, q in ipairs(placed) do
                        if q[1] < x2 and q[2] > x1 then ok = false break end
                    end
                end
                if ok then
                    for _, B in ipairs(bases) do
                        local kk = math.min(1, math.max(0, (B.rel - FORK_REL) / (MARK_REL - FORK_REL)))
                        kk = kk * kk * (3 - 2 * kk)
                        local cc = g.cx + B.wob * 0.5 + k * w * kk
                        local h = B.hf * (1 - 0.22 * kk) + B.jag
                        if B.x1 < cc + h and B.x2 > cc - h then ok = false break end
                    end
                end
                if ok then
                    np = np + 1
                    local pe = MF.pl[np] or {}
                    MF.pl[np] = pe
                    pe[1], pe[2] = x1, x2
                    placed[np] = pe
                    found = true
                    break
                end
            end
        end
        if not found then return false end
    end
    return true
end

function WorldRoad.lumPlanVerdict(p, z, kind, bid)
    local pl = WorldRoad._plan
    if not pl then return nil end
    local P = LMG.PLAN
    local rel = z - pl.stop
    local relN = rel - (MARK_REL - ARRIVE_REL)
    if (rel > P.skipLo and rel < P.skipHi) or (relN > P.skipLo and relN < P.skipHi)
       or (rel > P.nearLo and rel < P.nearHi) then
        return "skip"
    end
    if not LMG.lumFits(p, z, kind, pl, bid) then return "skip" end
    for _, dk in ipairs(LMG.FORK_CAMS) do
        if not LMG.markSlotOk(p, z, kind, bid, pl.stop + dk) then return "skip" end
    end
    for _, b in ipairs(P.bands) do
        if rel >= b.lo and rel <= b.hi and (pl.battle or not b.battle) then
            for _, q in ipairs(WorldRoad._props) do
                local qd = q ~= p and not q.ghost and LuminaireEngine.def(q.bid, q.kind)
                if qd and qd.roadside then
                    local qr = q.z - pl.stop
                    if qr >= b.haveLo and qr <= b.haveHi then return nil end
                    if math.abs(q.z - z) < (q.side == p.side and P.sameGap or P.oppGap) then return nil end
                end
            end
            return "force"
        end
    end
    return nil
end

function WorldRoad.showFork(nodes, onChosen)
    if not nodes or #nodes == 0 then return false end
    WorldRoad._landmark = nil
    local n = math.min(3, #nodes)
    local dirs = (n == 1) and { 0 } or (n == 2) and { -1, 1 } or { -1, 0, 1 }
    WorldRoad._fork = {
        nodes = nodes, n = n, dirs = dirs,
        animIn = 0, hover = nil, chosen = nil, converge = nil,
        onChosen = onChosen,
        markZ = WorldRoad._camZ + MARK_REL,
        markBoxes = {},
    }
    LMG.layoutMarks(WorldRoad._fork)
    LMG.clearFreshCover(WorldRoad._fork)
    PropCut.forkHideAll(WorldRoad._fork, false)
    return true
end

function LMG.clearFreshCover(f)
    local placed = f and f._placed
    if not placed or #placed == 0 then return end
    if (WorldRoad._drawFrame or 0) - (WorldRoad._populateFrame or 0) > 20 then return end
    local g, w = LMG.planGeom()
    local camZ = WorldRoad._camZ
    PropCut.forkHideAll(f, true)
    local box = LMG.freshBox or {}
    LMG.freshBox = box
    local function covers(q, z)
        local b = WorldRoad.postBox(q.bid, q.kind, q.side, z, camZ, g, w, box)
        if not b then return false end
        for _, m in ipairs(placed) do
            if b.x1 < m.x2 and b.x2 > m.x1 and b.y1 < m.y2 and b.y2 > m.y1 then return true end
        end
        return false
    end
    for i = #WorldRoad._props, 1, -1 do
        local q = WorldRoad._props[i]
        local d = not q.ghost and LuminaireEngine.def(q.bid, q.kind)
        local rel = q.z - camZ
        if d and d.roadside and rel < MARK_REL and rel > -7 and covers(q, q.z) then
            local moved = false
            local z0 = q.z
            for dz = 0.5, 24, 0.5 do
                local z = z0 - dz
                if z - camZ <= -7 then break end
                if not covers(q, z) then
                    q.z = z
                    if not WorldRoad._postBaseOnRoad(q) then moved = true break end
                    q.z = z0
                end
            end
            if not moved then table.remove(WorldRoad._props, i) end
        end
    end
end

LMG.MARK_FIT = { step = 0.004, reach = 0.12, sideMin = 0.08, centerMax = 0.07, margin = 18, label = 26,
                 samples = { 0 } }
function LMG.layoutMarks(f)
    local g, w = LMG.planGeom()
    if not g.tOf(MARK_REL) then return end
    local F = LMG.MARK_FIT
    local camZ = WorldRoad._camZ
    local dist = MARK_REL - ARRIVE_REL
    local postsAt, vegAt = {}, {}
    for si, c in ipairs(F.samples) do
        local cam = camZ + dist * c
        local list, veg = {}, {}
        for _, p in ipairs(WorldRoad._props) do
            local d = not p.ghost and LuminaireEngine.def(p.bid, p.kind)
            local rel = p.z - cam
            if d and d.roadside and rel < MARK_REL - dist * c and rel > -7 then
                list[#list + 1] = WorldRoad.postBox(p.bid, p.kind, p.side, p.z, cam, g, w, {})
            elseif not d and not p.ghost and not p.clutter and PropCut.kinds[p.kind]
               and rel < MARK_REL - dist * c and rel > -3 then
                local vb = PropCut.vegBox(p, cam, g, w, {})
                if vb then veg[#veg + 1] = vb end
            end
        end
        postsAt[si], vegAt[si] = list, veg
    end
    local bases, nearB, farB = {}, {}, {}
    for _, p in ipairs(WorldRoad._props) do
        local d = not p.ghost and LuminaireEngine.def(p.bid, p.kind)
        if d and d.roadside and p.z - camZ > FORK_REL then
            bases[#bases + 1] = WorldRoad._postBase(p, camZ, g, w, {})
        elseif not d and not p.ghost and not p.clutter and PropCut.kinds[p.kind] then
            local rel = p.z - camZ
            local t = rel > FORK_REL and rel < REL_CREST + EMERGE_BAND and (g.tOf(rel) or 0)
            if t and t >= 0 then
                local cxp = g.cx + p.side * w * (0.11 + 0.38 * t + (p.lane or 0) * 0.38)
                local hb = 10 * (0.30 + 0.70 * t)
                local tgt = rel < MARK_REL + 1 and nearB or farB
                tgt[#tgt + 1] = { x1 = cxp - hb, x2 = cxp + hb, rel = rel, t = t,
                    hf = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15)), wob = roadWobble(p.z, t, w),
                    jag = 5 * (0.30 + 0.70 * t) + 7 * (0.35 + 0.65 * t) }
            end
        end
    end
    local tier
    local function clearOf(list, k, n)
        for _, B in ipairs(list) do
            local kk = math.min(1, math.max(0, (B.rel - FORK_REL) / (MARK_REL - FORK_REL)))
            kk = kk * kk * (3 - 2 * kk)
            local hm = (n > 1) and (1 - 0.22 * kk) or 1
            local c = g.cx + B.wob * 0.5 + k * w * kk
            local h = B.hf * hm + B.jag
            if B.x1 < c + h and B.x2 > c - h then return false end
        end
        return true
    end
    local function baseClear(k, n)
        return clearOf(bases, k, n) and clearOf(nearB, k, n) and (tier > 1 or clearOf(farB, k, n))
    end
    local font = require("src.ui.FontManager").getFont(13)
    local placed, offK = {}, {}
    local function boxAt(i, k, c)
        local node = f.nodes[i]
        local key = node and landmarkKeyFor(node.type) or "landmark_battle"
        local img = getLandmark(key or "landmark_battle")
        if not img then return nil end
        local relM = MARK_REL - dist * c
        local tM = g.tOf(relM)
        if not tM then return nil end
        local s = g.scaleAt(lmCfg(LANDMARK_SIZE, key) or 2.0, tM, LMG.refH(key, img:getHeight()))
        local label = WorldRoad.forkLabel(node) or ""
        local hw = math.max(img:getWidth() * s, font:getWidth(label) + 16) * 0.5 + F.margin
        local kk = math.min(1, math.max(0, (relM - FORK_REL) / (MARK_REL - FORK_REL)))
        kk = kk * kk * (3 - 2 * kk)
        local off = k * w * kk * (1 - c) + roadWobble(camZ + MARK_REL, tM, w) * 0.5
        local py = g.latY(off, tM)
        return { x1 = g.cx + off - hw, x2 = g.cx + off + hw,
                 y1 = py - img:getHeight() * s - F.label - F.margin, y2 = py + F.margin }
    end
    local function hits(b, si)
        for _, q in ipairs(postsAt[si]) do
            if q.x1 < b.x2 and q.x2 > b.x1 and q.y1 < b.y2 and q.y2 > b.y1 then return true end
        end
        if tier < 3 then
            for _, q in ipairs(vegAt[si]) do
                if q.x1 < b.x2 and q.x2 > b.x1 and q.y1 < b.y2 and q.y2 > b.y1 then return true end
            end
        end
        return false
    end
    local function fits(i, k)
        if not baseClear(k, f.n) then return nil end
        local b = boxAt(i, k, 0)
        if not b or hits(b, 1) then return nil end
        for _, q in ipairs(placed) do
            if q.x1 < b.x2 and q.x2 > b.x1 then return nil end
        end
        for si = 2, #F.samples do
            local bc = boxAt(i, k, F.samples[si])
            if bc and hits(bc, si) then return nil end
        end
        return b
    end
    local order = {}
    for i = 1, f.n do if f.dirs[i] == 0 then order[#order + 1] = i end end
    for i = 1, f.n do if f.dirs[i] ~= 0 then order[#order + 1] = i end end
    local n = math.floor(0.25 / F.step + 0.5)
    local strained
    for tr = 1, 3 do
        tier, strained = tr, false
        for q = #placed, 1, -1 do placed[q] = nil end
        for _, i in ipairs(order) do
            local d = f.dirs[i]
            local k0 = d * FORK_SPREAD
            local best, bestBox = k0, nil
            for j = 0, 2 * n do
                local k = k0 + (j % 2 == 0 and 1 or -1) * math.floor((j + 1) / 2) * F.step
                if (d == 0 and math.abs(k) <= F.centerMax) or (d ~= 0 and k * d >= F.sideMin) then
                    local b = fits(i, k)
                    if b then best, bestBox = k, b; break end
                end
            end
            for pass = 1, 2 do
                if bestBox then break end
                if pass == 2 then strained = true end
                for j = 1, math.floor(0.84 / F.step) do
                    local k = k0 + (j % 2 == 0 and 1 or -1) * math.floor((j + 1) / 2) * F.step
                    if math.abs(k) <= 0.42 and (pass == 2 or baseClear(k, f.n)) then
                        local b = boxAt(i, k, 0)
                        local free = b and not hits(b, 1)
                        if free then
                            for _, q in ipairs(placed) do
                                if q.x1 < b.x2 and q.x2 > b.x1 then free = false break end
                            end
                        end
                        if free then best, bestBox = k, b; break end
                    end
                end
            end
            if not bestBox then strained = true end
            if tr == 3 and not bestBox then require("src.core.Debug").warn("WorldRoad: marco sem lugar livre de poste") end
            offK[i] = best
            placed[#placed + 1] = bestBox or boxAt(i, best, 0)
        end
        if not strained then break end
    end
    f.offK = offK
    f._placed = placed
    f._tier = tier
end

function WorldRoad.isForkActive()
    return WorldRoad._fork ~= nil
end

local function forkOffset(f, i, rel, w, settled)
    local k = (rel - FORK_REL) / (MARK_REL - FORK_REL)
    k = math.min(1, math.max(0, k))
    k = k * k * (3 - 2 * k)
    local off = (f.offK and f.offK[i] or f.dirs[i] * FORK_SPREAD) * w * k
    if f.converge then
        local c = f.converge.k or 0
        if i == f.chosen then off = off * (1 - c)
        else off = off * (1 + c * 2.5) end
    end
    return off
end

local function forkAlpha(f, i)
    if not f.converge or i == f.chosen then return 1 end
    return math.max(0, 1 - (f.converge.k or 0) * 1.6)
end

PropCut.HIDE = { dur = 0.22, roadPad = 0.02 }
function PropCut.hideK(p)
    local h = p.forkHide
    if not h then return 1 end
    return math.max(0, 1 - ((WorldRoad._time or 0) - h) / PropCut.HIDE.dur)
end
function PropCut.forkHideOne(p, f, g, w, camZ, now)
    if p.forkHide or p.ghost or p.clutter or not PropCut.kinds[p.kind] then return end
    local rel = p.z - camZ
    local hide = false
    if rel < MARK_REL and rel > -3 and f._placed then
        local b = PropCut.vegBox(p, camZ, g, w, PropCut.hideBox)
        PropCut.hideBox = b or PropCut.hideBox
        if b then
            for _, m in ipairs(f._placed) do
                if b.x1 < m.x2 and b.x2 > m.x1 and b.y1 < m.y2 and b.y2 > m.y1 then hide = true break end
            end
        end
    end
    if not hide and rel > FORK_REL - 1.5 and rel <= REL_CREST + EMERGE_BAND and f.n > 1 then
        local t = g.tOf(rel) or 0
        local x = g.cx + p.side * w * (0.11 + 0.38 * t + p.lane * 0.38)
        local halfRF = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
        for i = 1, f.n do
            if f.dirs[i] ~= 0 and math.abs(x - (g.cx + forkOffset(f, i, rel, w))) < halfRF * 0.78 + PropCut.HIDE.roadPad * w then
                hide = true
            end
        end
    end
    if hide then p.forkHide = (WorldRoad._time or 0) - (now and 10 or 0) end
end
function PropCut.forkHideAll(f, now)
    if not f or not f.offK or f.converge then return end
    local g, w = LMG.planGeom()
    local camZ = WorldRoad._camZ
    for _, p in ipairs(WorldRoad._props) do PropCut.forkHideOne(p, f, g, w, camZ, now) end
end

function WorldRoad._postBase(q, camZ, g, w, out)
    local rel = q.z - camZ
    local t = g.tOf(rel)
    if not t or t < 0 or rel < -1 then return nil end
    local img = getSprite(q.kind, 0, q.bid)
    if not img then return nil end
    local s = g.scaleAt(kindSize(q.kind, q.bid) * (PropCut.sizeK[img] or 1) * PropCut.crestK(q.kind, t), t, img:getHeight())
    local hf = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
    local pcx, flip = WorldRoad.postCenter(q.bid, q.kind, q.side, s, hf, 0)
    local anc = LuminaireEngine.anchor(q.bid, q.kind, 0, luminairePath(q.bid, q.kind, 0))
    local fa, fb = (anc.fL or -2) * s * flip, (anc.fR or 2) * s * flip
    local wob = roadWobble(q.z, t, w)
    out = out or {}
    out.x1 = g.cx + pcx + wob + math.min(fa, fb)
    out.x2 = g.cx + pcx + wob + math.max(fa, fb)
    out.t, out.rel, out.hf, out.wob = t, rel, hf, wob
    out.jag = 5 * (0.30 + 0.70 * t) + 7 * (0.35 + 0.65 * t)
    return out
end

function WorldRoad._planGeo() return (LMG.planGeom()) end
function WorldRoad._postBaseOnRoad(q)
    local g, w = LMG.planGeom()
    local B = WorldRoad._postBase(q, WorldRoad._camZ, g, w, LMG.baseTmp)
    if not B then return false end
    LMG.baseTmp = B
    local x1, x2, rel, hf, jag, wob = B.x1, B.x2, B.rel, B.hf, B.jag, B.wob
    local f = WorldRoad._fork
    if f and rel > FORK_REL then
        local kk = math.min(1, math.max(0, (rel - FORK_REL) / (MARK_REL - FORK_REL)))
        kk = kk * kk * (3 - 2 * kk)
        local hm = (f.n > 1) and (1 - 0.22 * kk) or 1
        for i = 1, f.n do
            if forkAlpha(f, i) * (f.animIn or 1) > 0.25 then
                local c = g.cx + wob * 0.5 + forkOffset(f, i, rel, w)
                local h = hf * hm + jag
                if x1 < c + h and x2 > c - h then return true, i end
            end
        end
        return false
    end
    local c = g.cx + wob
    return x1 < c + hf + jag and x2 > c - hf - jag, 0
end

local _grassCtx, _grassCtxFrame, _grassFork
local function drawGrass(g, x, w, camZ, relFrom, relTo)
    if _grassCtxFrame ~= WorldRoad._time then
        _grassCtxFrame = WorldRoad._time
        local gA = envColor("grassA")
        local b = rawBiome()
        local acc = b.accent or { 0.7, 0.6, 0.3 }
        local lum = (gA[1] + gA[2] + gA[3]) / 3
        local lk = 1.30 + math.max(0, 0.42 - lum) * 1.6
        _grassFork = { cs = {}, ws = {} }
        local gc = Scene.Grade.color("grass", 1, LMG.c)
        local vis = WorldRoad.roadVis()
        _grassCtx = {
            x = x, w = w,
            time = WorldRoad._time,
            camZ = camZ,
            geom = g,
            relCrest = REL_CREST,
            roadCenter = function(z, t)
                return g.cx + roadWobble(z, t, w)
            end,
            roadHalf = function(t)
                return ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15)) * vis
            end,
            roadCenters = function(z, t)
                local f = WorldRoad._fork
                if not f then return nil end
                local rel = z - WorldRoad._camZ
                if rel <= FORK_REL then return nil end
                local wob = roadWobble(z, t, w) * 0.5
                local cs, ws = _grassFork.cs, _grassFork.ws
                for i = 1, f.n do
                    cs[i] = g.cx + forkOffset(f, i, rel, w) + wob
                    ws[i] = forkAlpha(f, i) * (f.animIn or 1)
                end
                for i = f.n + 1, #cs do cs[i] = nil; ws[i] = nil end
                if (f.animIn or 1) < 1 then
                    cs[f.n + 1] = g.cx + wob * 2
                    ws[f.n + 1] = 1 - f.animIn
                end
                return cs, WorldRoad.forkArmK(f, rel), ws
            end,
            roadEdgeOff = WorldRoad.roadEdgeOff,
            colors = {
                mid   = { gA[1] * 0.98 * gc[1], gA[2] * 0.98 * gc[2], gA[3] * 0.98 * gc[3] },
                light = { math.min(1, gA[1] * lk) * gc[1],
                          math.min(1, gA[2] * lk * 0.97) * gc[2],
                          math.min(1, gA[3] * lk * 0.88) * gc[3] },
                accent = { acc[1] * gc[1], acc[2] * gc[2], acc[3] * gc[3] },
            },
            biomeId = b.id,
            forkActive = WorldRoad._fork ~= nil,
            forkRel = FORK_REL,
            castleGapHalf = WorldRoad._castleBaseHalf,
            castleGapX = WorldRoad._castleTop and WorldRoad._castleTop.cx,
        }
        local ra = envColor("roadA")
        local rg = Scene.Grade.color("road", 1, LMG.c)
        _grassCtx.colors.dirt = { ra[1] * rg[1], ra[2] * rg[2], ra[3] * rg[3] }
    end
    _grassCtx.relFrom = relFrom
    _grassCtx.relTo = relTo
    _grassCtx.frame = WorldRoad._drawFrame
    local f = WorldRoad._fork
    _grassCtx.forkSig = f and (f.n * 1e7 + (f.chosen or 0) * 1e6
        + (f.converge and f.converge.k or 0) * 1e3 + (f.animIn or 0)) or 0
    GrassField.draw(_grassCtx)
end

function WorldRoad.forkHitTest(mx, my)
    local f = WorldRoad._fork
    if not f then return nil end
    for i = 1, f.n do
        local b = f.markBoxes[i]
        if b and mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2 then
            return i
        end
    end
    return nil
end

function WorldRoad.forkMousePressed(mx, my)
    local f = WorldRoad._fork
    if not f then return false end
    if f.converge then return true end
    local i = WorldRoad.forkHitTest(mx, my)
    if i then
        f.chosen = i
        f.hover = i
        f.converge = { t = 0, k = 0, duration = 2.4,
                       z0 = WorldRoad._camZ, dist = MARK_REL - ARRIVE_REL }
        Sfx.play("cardSelect")
        local node = f.nodes[i]
        local nt = node and node.type
        local fights = nt == "battle" or nt == "elite" or nt == "mini_boss"
        WorldRoad.planStop(WorldRoad._camZ + MARK_REL - ARRIVE_REL
            + ((fights or nt == "boss") and WorldRoad.TRAVEL_DISTANCE or 0), fights)
        require("src.ui.CastleDrift").pick(f.dirs[i], WorldRoad._camZ, MARK_REL - ARRIVE_REL
            + ((fights or nt == "boss") and WorldRoad.TRAVEL_DISTANCE or 0), nt == "boss")
        if node then
            local key = landmarkKeyFor(node.type)
            local img = key and getLandmark(key)
            if img then
                f.chosenPulse = 0.35
            end
        end
    else
        WorldRoad.pokeSceneAt(mx, my)
    end
    return true
end

WorldRoad.SHAPE = { wander = 0.15, wanderF = 0.19, bayF = 0.55, bayT = 0.68, bay = 0.13,
                    narrowT = 0.24, narrow = 0.16 }
function WorldRoad.valueNoise(u, seed)
    local i = math.floor(u)
    local f = u - i
    f = f * f * (3 - 2 * f)
    local a = math.sin((i * 1.731 + seed) * 12.9898) * 43758.5453
    local b = math.sin(((i + 1) * 1.731 + seed) * 12.9898) * 43758.5453
    a, b = a - math.floor(a), b - math.floor(b)
    return a + (b - a) * f
end
function WorldRoad.roadWidthK(z, side)
    local S = WorldRoad.SHAPE
    local sd = side < 0 and 11.3 or 29.7
    local VN = WorldRoad.valueNoise
    local k = (VN(z * S.wanderF, sd) * 0.65 + VN(z * S.wanderF * 2.3, sd + 5.1) * 0.35 - 0.5) * 2 * S.wander
    local nb = VN(z * S.bayF, sd + 17.9)
    if nb > S.bayT then k = k + (nb - S.bayT) / (1 - S.bayT) * S.bay end
    local nn = VN(z * S.bayF * 1.3, sd + 41.3)
    if nn < S.narrowT then k = k - (S.narrowT - nn) / S.narrowT * S.narrow end
    return math.min(0.12, k)
end

function WorldRoad.roadEdgeOff(z, t, side, half)
    local amp = 5 * (0.30 + 0.70 * t)
    local e
    if side < 0 then
        e = -(math.sin(z * 0.55) * 0.6 + math.sin(z * 0.21 + 1.4) * 0.4) * amp
    else
        e = (math.sin(z * 0.47 + 3.1) * 0.6 + math.sin(z * 0.17 + 4.2) * 0.4) * amp
    end
    local u = z * 2.3
    local i = math.floor(u)
    local f = u - i
    f = f * f * (3 - 2 * f)
    local k = side < 0 and 13 or 19
    local h0 = math.sin((i * k + 7) * 12.9898) * 43758.5453
    local h1 = math.sin(((i + 1) * k + 7) * 12.9898) * 43758.5453
    h0, h1 = h0 - math.floor(h0), h1 - math.floor(h1)
    e = e + (h0 + (h1 - h0) * f - 0.5) * 9 * (0.35 + 0.65 * t)
    if half then e = e + half * WorldRoad.roadWidthK(z, side) end
    return e
end

WorldRoad.BITE = { cell = 44, amp = 2.4, ampT = 1.2, notchCell = 10, notch = 0.32, notchPx = 5 }
function WorldRoad.edgeBite(z, t, side)
    local B = WorldRoad.BITE
    local k = side < 0 and 7.31 or 3.17
    local c = math.floor(z * B.cell)
    local h = math.sin((c * 1.618 + k) * 12.9898) * 43758.5453
    h = h - math.floor(h)
    local v = (h - 0.5) * 2 * (B.amp + B.ampT * t)
    local n = math.floor(z * B.notchCell)
    local hn = math.sin((n * 2.399 + k * 3) * 78.233) * 43758.5453
    hn = hn - math.floor(hn)
    if hn < B.notch then
        v = v + B.notchPx * (0.9 + t) * (hn < B.notch * 0.5 and 1 or -1)
    end
    return v
end

function WorldRoad.roadVis()
    local P = GrassField.PRESETS[rawBiome().id]
    return 1 - 0.12 * math.min(1, (P and P.carpet) or 1)
end
function WorldRoad.forkArmK(f, rel)
    if not f or f.n <= 1 then return 1 end
    local kk = math.min(1, math.max(0, (rel - FORK_REL) / 2.5))
    return 1 - 0.22 * kk * kk * (3 - 2 * kk)
end

local function drawRoad(g, x, w, camZ)
    local roadA = envColor("roadA")
    local roadB = envColor("roadB")
    local roadEdge = envColor("roadEdge")
    local cx = g.cx
    local crest = g.crestYAt(cx)
    local groundH = g.bottomY - crest
    local fork = WorldRoad._fork

    local step = 2
    local vis = WorldRoad.roadVis()
    local qm = WorldRoad._roadQM
    if not qm then
        qm = QuadMesh.new(8192)
        WorldRoad._roadQM = qm
    end
    qm:reset()
    local UNTEX = QuadMesh.UNTEXTURED
    local function rect(rx, ry, rw, rh, r, gg, bb, aa)
        qm:rect(rx, ry, rw, rh, UNTEX, 0, UNTEX, 0, r, gg, bb, aa)
    end
    local tileUsed = nil
    local function hash(n)
        local v = math.sin(n * 12.9898) * 43758.5453
        return v - math.floor(v)
    end
    local lastDecoRow = nil
    local t, rel, worldZ, half0, eL, eR, rowId, blend, m
    local newRow
    local biomeNow = rawBiome()
    local tile = RoadSurface.get(biomeNow.id, biomeNow)
        or getRoadTile(biomeNow.id)
    local tw, th, dv, v, hs
    if tile then tw, th = tile:getWidth(), tile:getHeight() end

    local function paintRow(cxRow, halfMul, aMul, decorate, bright, wk)
        wk = wk or 1
        local half = half0 * halfMul * wk
        eL = WorldRoad.roadEdgeOff(worldZ, t, -1, half0 * halfMul)
        eR = WorldRoad.roadEdgeOff(worldZ, t, 1, half0 * halfMul)
        local xL = math.floor(cxRow - half - (eL + WorldRoad.edgeBite(worldZ, t, -1)) * wk)
        local xR = math.floor(cxRow + half + (eR + WorldRoad.edgeBite(worldZ, t, 1)) * wk)

        local SEG = 16
        for segX = xL, xR - 1, SEG do
            local segW = math.min(SEG, xR - segX)
            local dxMid = (segX + segW / 2) - cx
            local segY = math.floor(g.latY(dxMid, t))
            if tile then
                local vx = (segX - cxRow) / hs + tw * 0.5
                local vw = segW / hs
                local tm = (0.95 + blend * 0.08) * bright
                qm:rect(segX, segY, hs * vw, ((step + 1.5) / dv) * dv,
                    vx / tw, v / th, (vx + vw) / tw, (v + dv) / th,
                    tm, tm, tm, aMul)
            else
                rect(segX, segY, segW, step + 1.5,
                    (roadA[1] + (roadB[1] - roadA[1]) * blend) * m * bright,
                    (roadA[2] + (roadB[2] - roadA[2]) * blend) * m * bright,
                    (roadA[3] + (roadB[3] - roadA[3]) * blend) * m * bright, aMul)
            end
        end

        if not decorate then return end

        if newRow then
            for k = 1, 2 do
                local hpos = hash(rowId * 31 + k * 17)
                if hpos > 0.35 then
                    local px2 = xL + math.floor(hpos * (xR - xL))
                    local sz = math.max(2, math.floor((1 + hash(rowId + k) * 2) * (0.4 + 0.6 * t) * 2))
                    local py2 = math.floor(g.latY(px2 - cx, t))
                    if hash(rowId * 3 + k) > 0.5 then
                        rect(px2, py2, sz, sz, roadEdge[1], roadEdge[2], roadEdge[3], 0.5 * aMul)
                    else
                        rect(px2, py2, sz, sz, roadA[1] * 1.2, roadA[2] * 1.2, roadA[3] * 1.15, 0.6 * aMul)
                    end
                end
            end
        end

        if t > 0.18 then
            local VN = WorldRoad.valueNoise
            local rutW = math.max(1, math.floor(2.2 * g.persp(t) + 0.5))
            local ra = math.min(1, (t - 0.18) * 2.2) * 0.42 * aMul
            for sd = -1, 1, 2 do
                local wear = VN(worldZ * 0.9, sd * 7.7 + 3.1)
                if wear > 0.28 then
                    local rdx = half * (0.40 + (VN(worldZ * 0.35, sd * 5.3) - 0.5) * 0.10)
                    local rx = math.floor(cxRow + sd * rdx)
                    rect(rx, math.floor(g.latY(rx - cx, t)), rutW, step,
                        roadEdge[1], roadEdge[2], roadEdge[3], ra * math.min(1, (wear - 0.28) * 4))
                end
            end
        end

        local yL = math.floor(g.latY(xL - cx, t))
        local yR = math.floor(g.latY(xR - cx, t))
        if hash(rowId * 5 + 2) > 0.25 then
            rect(xL - 2, yL, 2, step, roadEdge[1], roadEdge[2], roadEdge[3], 0.85 * aMul)
        end
        if hash(rowId * 11 + 4) > 0.25 then
            rect(xR, yR, 2, step, roadEdge[1], roadEdge[2], roadEdge[3], 0.85 * aMul)
        end
        if newRow and hash(rowId * 17 + 9) > 0.72 then
            local ps = math.max(2, math.floor(3.5 * g.persp(t)))
            local side = hash(rowId * 23 + 3) > 0.5 and 1 or -1
            local px2 = side > 0 and (xR + 3 + math.floor(hash(rowId * 29) * 8 * g.persp(t)))
                                  or (xL - 5 - math.floor(hash(rowId * 29) * 8 * g.persp(t)))
            rect(px2, math.floor(g.latY(px2 - cx, t)), ps, math.max(step, ps - 1),
                roadA[1] * 1.25, roadA[2] * 1.22, roadA[3] * 1.15, 0.9 * aMul)
        end

        if newRow then
            local ga2 = envColor("grassA")
            for k = 1, 3 do
                local hh = hash(rowId * 53 + k * 7)
                local dd = math.floor(hh * hh * 12 * g.persp(t)) + 2
                local sz2 = math.max(1, math.floor(2 * g.persp(t)))
                local sideK = (hash(rowId * 59 + k) > 0.5) and 1 or -1
                local bx = sideK > 0 and (xR + dd) or (xL - dd - sz2)
                rect(bx, math.floor(g.latY(bx - cx, t)), sz2, sz2,
                    roadA[1], roadA[2], roadA[3], (1 - hh * 0.6) * 0.5 * aMul)
                local gx2 = sideK > 0 and (xR - 2 - dd) or (xL + dd)
                if gx2 > xL + 2 and gx2 < xR - 2 - sz2 then
                    rect(gx2, math.floor(g.latY(gx2 - cx, t)), sz2, sz2,
                        ga2[1], ga2[2], ga2[3], 0.32 * aMul)
                end
            end
        end

        if newRow and hash(rowId * 41 + 5) > 0.45 then
            local ga = envColor("grassA")
            local gs = hash(rowId * 43 + 1) > 0.5 and 1 or -1
            local gx = gs > 0 and (xR - 2 - math.floor(hash(rowId * 47) * 6))
                               or (xL + math.floor(hash(rowId * 47) * 6))
            local gy = math.floor(g.latY(gx - cx, t))
            local gsz = math.max(1, math.floor(2 * g.persp(t)))
            rect(gx, gy, gsz + 1, gsz, ga[1] * 1.3, ga[2] * 1.3, ga[3] * 1.15, 0.85 * aMul)
            rect(gx + gs, gy - gsz, gsz, gsz, ga[1] * 1.3, ga[2] * 1.3, ga[3] * 1.15, 0.85 * aMul)
        end
    end

    for sy = 0, groundH - 1, step do
        t = sy / groundH
        rel = REL_CREST * (1 - t ^ (1 / T_POW))
        worldZ = camZ + rel

        half0 = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15)) * vis
        rowId = math.floor(worldZ * 2.3)
        blend = hash(math.floor(worldZ / 1.9) * 3 + math.floor(t * 5))
        m = 0.97 + hash(rowId) * 0.04
        if tile then
            tileUsed = tile
            local tn2 = math.min(1, (sy + step) / groundH)
            local relN = REL_CREST * (1 - tn2 ^ (1 / T_POW))
            dv = math.min(16, math.max(0.05, (rel - relN) * RD_V_DENSITY))
            v = (worldZ * RD_V_DENSITY) % th
            hs = 4.4 * (0.35 + 0.65 * t)
        end
        newRow = rowId ~= lastDecoRow
        if newRow then lastDecoRow = rowId end

        local wob = roadWobble(worldZ, t, w)

        if fork and rel > FORK_REL then
            local hm = WorldRoad.forkArmK(fork, rel)
            for i = 1, fork.n do
                local aMul = forkAlpha(fork, i) * math.max(0.001, fork.animIn or 1)
                if aMul > 0.02 then
                    local bright = (fork.hover == i and not fork.converge) and 1.14 or 1
                    paintRow(cx + wob * 0.5 + forkOffset(fork, i, rel, w),
                        hm, aMul, i == 1, bright, aMul)
                end
            end
            if (fork.animIn or 1) < 1 then
                paintRow(cx + wob, 1, 1 - fork.animIn, false, 1, 1 - fork.animIn)
            end
        else
            paintRow(cx + wob, 1, 1, true, 1)
        end
    end
    if qm.n > 0 then
        qm:upload(0, qm.n)
        local prevShader = love.graphics.getShader()
        love.graphics.setShader(QuadMesh.untexturedShader())
        local rc = Scene.Grade.color("road", 1, LMG.c)
        love.graphics.setColor(rc[1], rc[2], rc[3], 1)
        qm:draw(0, qm.n, tileUsed)
        love.graphics.setShader(prevShader)
    end
end

WorldRoad._forkLabelCache = { locale = nil, byType = {} }
function WorldRoad.forkLabel(node)
    if not node then return "?" end
    local MapManager = require("src.systems.MapManager")
    if node.type and MapManager.NODE_META and MapManager.NODE_META[node.type] then
        local cache = WorldRoad._forkLabelCache
        local loc = require("src.i18n.I18n").getLocale()
        if loc ~= cache.locale then cache.locale, cache.byType = loc, {} end
        local c = cache.byType[node.type]
        if not c then
            c = { MapManager.labelFor(node.type), MapManager.descFor(node.type) }
            cache.byType[node.type] = c
        end
        return c[1], c[2]
    end
    return node.label or tostring(node.type or "?"), node.desc
end

local function drawForkMarks(g, x, w, camZ)
    local f = WorldRoad._fork
    if not f or not f._geo then return end
    local FontManager = require("src.ui.FontManager")
    for i = 1, f.n do
        local node = f.nodes[i]
        local geo = f._geo[i]
        if geo and not f.converge then
            local px, py = geo.px, geo.py
            local ihs = geo.ih * geo.s
            local aMul = geo.aMul
            local label, desc = WorldRoad.forkLabel(node)
            local font = FontManager.getFont(13)
            love.graphics.setFont(font)
            local tw2 = font:getWidth(label)
            local pw, ph = tw2 + 16, 20
            local pxc = px - pw / 2
            local pyc = py - ihs - 26
            love.graphics.setColor(0.09, 0.07, 0.05, 0.88 * aMul)
            love.graphics.rectangle("fill", pxc, pyc, pw, ph, 6, 6)
            love.graphics.setColor(0.55, 0.44, 0.24, 0.9 * aMul)
            love.graphics.rectangle("line", pxc, pyc, pw, ph, 6, 6)
            love.graphics.setColor(0.92, 0.82, 0.58, aMul)
            love.graphics.print(label, math.floor(pxc + 8), math.floor(pyc + 3))
            if geo.hovered and desc and desc ~= "" then
                local font2 = FontManager.getFont(11)
                love.graphics.setFont(font2)
                local dw = font2:getWidth(desc)
                local dx2 = px - dw / 2 - 8
                local dy2 = pyc - 22
                love.graphics.setColor(0.09, 0.07, 0.05, 0.82 * aMul)
                love.graphics.rectangle("fill", dx2, dy2, dw + 16, 18, 5, 5)
                love.graphics.setColor(0.85, 0.78, 0.62, aMul)
                love.graphics.print(desc, math.floor(dx2 + 8), math.floor(dy2 + 3))
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

WorldRoad._pools = { sh = {}, shN = 0, occ = {}, occN = 0 }
local function shadowOpts(alphaK, flip, footPad, prof)
    local P = WorldRoad._pools
    P.shN = P.shN + 1
    local o = P.sh[P.shN]
    if not o then o = {}; P.sh[P.shN] = o end
    o.alphaK, o.flip, o.footPad = alphaK, flip, footPad
    if prof then
        o.baseK, o.riseK, o.lenK = prof.baseK, prof.riseK, prof.lenK
    else
        o.baseK, o.riseK, o.lenK = nil, nil, nil
    end
    return o
end

LMG.cEnv = { profile = WorldRoad.SHADOW_PROFILE }
function LMG.clutterEnv(g, x, w, camZ)
    local e = LMG.cEnv
    e.g, e.x, e.w, e.camZ = g, x, w, camZ
    e.bid = rawBiome().id
    e.time = WorldRoad._time
    e.reduced = (_G.gameSettings and _G.gameSettings.reducedMotion) or false
    e.getSprite, e.wobble, e.shadowOpts = getSprite, roadWobble, shadowOpts
    e.roadHalfK = ROAD_HALF
    e.screenK = WorldRoad.enemyScreenK(g.h)
    e.pixRef = PropCut.PIX.ref
    e.flipToSun = PropCut.flipToSun
    e.frames, e.frameOf = PropCut.treeFrames, PropCut.frameOf
    e.sunRight = sunShadowDir(g, x, w, g.cx) < 0
    e.relMax = REL_CREST * (1 - Scene.Clutter.DATA.tMin ^ (1 / T_POW))
    e.fork = WorldRoad._fork ~= nil
    e.hand = WorldRoad._enemyDraw and WorldRoad._handZone or nil
    return e
end

local function drawCrestFog(g, x, w)
    local fog = envColor("fog")
    local fogLimitY = g.crestApexY + (g.bottomY - g.crestApexY) * 0.22
    local gv = gradTex()
    local halfW = w * 0.30
    for sx = 0, w - 1, 6 do
        local cy = g.crestYAt(x + sx)
        local dx = math.abs((x + sx) - g.cx)
        if cy < fogLimitY and dx < halfW then
            local fade = 1 - (dx / halfW) ^ 2
            love.graphics.setColor(fog[1], fog[2], fog[3],
                (fog[4] or 0.5) * 0.42 * fade)
            love.graphics.draw(gv, x + sx, cy, 0, 6, 16 / 256)
        end
    end
end

local propZDesc = function(a, c) return a.z > c.z end
WorldRoad._lists = { far = {}, near = {}, behind = {}, front = {} }
local function clearList(t) for i = #t, 1, -1 do t[i] = nil end end
local function occluderSlot()
    local P = WorldRoad._pools
    P.occN = P.occN + 1
    local o = P.occ[P.occN]
    if not o then o = {}; P.occ[P.occN] = o end
    o.fn = nil
    return o
end
local hitPool = {}
local function hitSlot(idx)
    local e = hitPool[idx]
    if not e then e = {}; hitPool[idx] = e end
    e.s = nil
    return e
end
local lumArg = {}

local function drawProps(g, x, w, camZ)
    table.sort(WorldRoad._props, propZDesc)
    WorldRoad._pools.shN, WorldRoad._pools.occN = 0, 0

    local farPass = WorldRoad._lists.far
    local nearPass = WorldRoad._lists.near
    clearList(farPass)
    clearList(nearPass)
    for _, p in ipairs(WorldRoad._props) do
        local rel0 = p.z - camZ
        local t0 = g.tOf(rel0)
        if t0 and t0 < 0.25 then farPass[#farPass + 1] = p
        else nearPass[#nearPass + 1] = p end
    end
    if Scene.Clutter.collect(nearPass, LMG.clutterEnv(g, x, w, camZ)) > 0 then
        table.sort(nearPass, propZDesc)
    end

    local grassRel = REL_CREST + 2
    local function flushGrassTo(relLow)
        if relLow < grassRel - 0.35 or relLow <= -1 then
            drawGrass(g, x, w, camZ, relLow, grassRel)
            grassRel = relLow
            WeatherEngine.flushTo(relLow)
        end
    end

    local fkMarks = nil
    do
        local f = WorldRoad._fork
        if f then
            local relM = f.markZ - camZ
            local tM = g.tOf(relM)
            if tM and tM >= 0 then
                fkMarks = { f = f, rel = relM, t = tM, drawn = false }
            elseif f._geo then
                for i = 1, f.n do f._geo[i] = nil; f.markBoxes[i] = nil end
            end
        end
    end
    local lmMark = nil
    do
        local lm = WorldRoad._landmark
        if lm then
            local relL = lm.z - camZ
            if relL < -3 then
                WorldRoad._landmark = nil
            else
                local tL = g.tOf(relL)
                if relL < 0 then tL = (1 - relL / REL_CREST) ^ T_POW end
                if tL and tL >= 0 then
                    lmMark = WorldRoad._lmMark or {}
                    WorldRoad._lmMark = lmMark
                    lmMark.rel, lmMark.t, lmMark.lm, lmMark.drawn = relL, tL, lm, false
                end
            end
        end
    end
    local encMark = nil
    do
        local e = WorldRoad._encounter
        if e and WorldRoad._travel and e.z - camZ <= REL_CREST and g.tOf(e.z - camZ) then
            encMark = LMG.encMark or {}
            LMG.encMark = encMark
            encMark.rel, encMark.drawn = e.z - camZ, false
        end
    end
    local function drawEncounterNow()
        encMark.drawn = true
        flushGrassTo(encMark.rel)
        WeatherEngine.flushTo(encMark.rel)
        ShadowEngine.endFrame(Scene.Contact.drawAcc)
        Scene.Contact.endFrame()
        LMG.drawEncounterFront(g, x, w, camZ)
    end
    local function drawChosenLandmark()
        local lm, rel, t = lmMark.lm, lmMark.rel, lmMark.t
        local aL = math.max(0, math.min(1, (LMG.PASS_FADE[2] - t) / (LMG.PASS_FADE[2] - LMG.PASS_FADE[1])))
        lmMark.a = aL
        if aL <= 0.01 then return end
        local img = getLandmark(lm.key)
        if not img then return end
        img = landmarkFrame(lm.key, lm.phase or lm.z) or img
        local iw, ih = img:getWidth(), img:getHeight()
        local s = g.scaleAt(lm.size or 2.0, t, LMG.refH(lm.key, ih))
        local py = g.latY(0, t)
        local lx = g.cx + roadWobble(lm.z, t, w)
        lmMark.h, lmMark.w, lmMark.py, lmMark.px = ih * s, iw * s, py, lx
        LMG.Base.under(lm.key, lx, py, iw, s, t, aL, Scene.Grade.color("landmark", t, LMG.c), rel, g)
        local shPad = Scene.Contact.padOf(img) or lmCfg(LANDMARK_SHADOW_PAD, lm.key) or 0
        local shY = py - 1 - shPad * s
        if not ShadowEngine.sprite(img, lx, shY, s,
            shadowOpts(aL, nil, shPad, lmCfg(WorldRoad.SHADOW_PROFILE, lm.key))) then
            love.graphics.setColor(0, 0, 0, 0.22 * aL)
            love.graphics.ellipse("fill",
                lx + sunShadowDir(g, x, w, lx) * iw * s * 0.14,
                shY, iw * s * 0.30, math.max(2, 4 * g.persp(t)))
            love.graphics.setColor(1, 1, 1, 1)
        end
        local lmk = Scene.Grade.cfg("landmarks")[lm.key:match("landmark_(%a+)$") or ""]
        if lmk and lmk.scorch then
            Scene.Contact.scorch(lx, shY, iw * s, t, lmk.scorch.radius, lmk.scorch.alpha * aL)
        end
        Scene.Contact.queue(img, lx, shY, s, t, aL, 1)
        local lc = Scene.Grade.color("landmark", t, LMG.c)
        love.graphics.setColor(lc[1], lc[2], lc[3], aL)
        local kxF = 0
        if lmk and lmk.flagWave and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
            local wP = GrassField.PRESETS[rawBiome().id]
            local gw = wP and GrassField.windAt((lx - x) / w, lm.z, WorldRoad._time, wP, 0) or 0
            kxF = -gw * 0.035 + math.sin(WorldRoad._time * 2.4) * 0.02
        end
        WorldRoad._flagKx = kxF
        love.graphics.draw(img, math.floor(lx), math.floor(py), 0, s, s, iw / 2, ih, kxF, 0)
        ShadowEngine.mask(img, nil, math.floor(lx), math.floor(py), 0, s, s, iw / 2, ih, kxF, t)
        LMG.Base.over(lm.key, lx, py, iw, LMG.refH(lm.key, ih), s, t, aL, lc)
        love.graphics.setColor(1, 1, 1, 1)
        if not (lmk and lmk.smoke == "thin" and _G.gameSettings and _G.gameSettings.reducedMotion) then
            drawLandmarkSmoke(lm.key, lx, py, iw, ih, s, aL, lmk and lmk.smoke == "thin")
        end
        submitLandmarkLight(lm.key, lx, py, iw, ih, s, rel, lm.z, aL, lmk)
        LMG.selfLight(lmk, lx, py, iw, ih, s, rel, aL)
        if lmk and lmk.embers and aL > 0.5 and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
            local anc = LuminaireEngine.anchor("landmark", lm.key, 0,
                "assets/sprites/world/" .. lm.key .. ".png")
            local ax, ay = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.45
            LuminaireEngine.drawEmbersSpec(LMG.EMBERS, lx + (ax - 0.5) * iw * s,
                py - ih * s * (1 - ay), ih * s, lm.z)
        end
        if lmk and lmk.dust and aL > 0.5 and not (_G.gameSettings and _G.gameSettings.reducedMotion)
           and love.math.random() < lmk.dust.rate / 60 then
            local ra = envColor("roadA")
            local halfF = ROAD_HALF * (0.30 + 0.70 * (t ^ 1.15))
            WeatherEngine.emitDust((lx - g.cx) / w + (love.math.random() - 0.5) * halfF * 1.6,
                lm.z, t, 0.01,
                { math.min(1, ra[1] * 1.4), math.min(1, ra[2] * 1.35), math.min(1, ra[3] * 1.2) },
                lmk.dust.alpha)
        end
        submitLandmarkOccluder(img, lx, py, iw, ih, s, rel)
        local oc2 = Scene.Grade.cfg("occlusion")
        local th = oc2.baseCover * ih * s / GrassField.CELL_H
        GrassField.requireTufts(rel - 0.05, lx, iw * s * 0.3, oc2.tuftsMin, th * 0.8)
        GrassField.requireTufts(rel - 0.05, lx - iw * s * 0.36, iw * s * 0.28, oc2.tuftsMax, th * 1.3)
        GrassField.requireTufts(rel - 0.05, lx + iw * s * 0.36, iw * s * 0.28, oc2.tuftsMax, th * 1.3)
        WorldRoad._landmarkDrawnAt = GrassField.stats.builds + GrassField.stats.replays
    end
    local function drawForkPhysical()
        local f, relM, tM = fkMarks.f, fkMarks.rel, fkMarks.t
        f._geo = f._geo or {}
        for i = 1, f.n do
            local node = f.nodes[i]
            local key = node and landmarkKeyFor(node.type)
                or "landmark_battle"
            local img = getLandmark(key or "landmark_battle")
            local aMul = forkAlpha(f, i)
            if img and aMul > 0.02 then
                local animT = f._animT and f._animT[i]
                img = (animT and landmarkFrameAt(key, animT + i * 3.7)
                    or landmarkFrame(key, i * 3.7)) or img
                local hoverK = (f._hoverK and f._hoverK[i]) or 0
                local aDef = lmCfg(LANDMARK_ANIM, key)
                if hoverK > 0.02 and aDef and aDef.hoverAnim then
                    local hfr = landmarkFrames(landmarkHoverAnimKey(key))
                    if hfr then
                        img = hfr[1 + math.floor(hoverK * (#hfr - 1) + 0.5)]
                    end
                end
                local offX = forkOffset(f, i, relM, w, true)
                    + roadWobble(camZ + relM, tM, w) * 0.5
                local px = g.cx + offX
                local py = g.latY(offX, tM)
                local iw, ih = img:getWidth(), img:getHeight()
                local size = lmCfg(LANDMARK_SIZE, key) or 2.0
                local s = g.scaleAt(size, tM, LMG.refH(key, ih))
                s = s * (0.7 + 0.3 * f.animIn)
                if f.chosen == i and f.chosenPulse and f.chosenPulse > 0 then
                    s = s * (1 + f.chosenPulse * 0.25)
                end
                local hovered = (f.hover == i and not f.converge)
                LMG.Base.under(key, px, py, iw, s, tM, aMul, Scene.Grade.color("landmark", tM, LMG.c), relM, g)
                local shPad = Scene.Contact.padOf(img) or lmCfg(LANDMARK_SHADOW_PAD, key) or 0
                local shY = py - 1 - shPad * s
                if not ShadowEngine.sprite(img, px, shY, s,
                    shadowOpts(aMul, nil, shPad,
                        lmCfg(WorldRoad.SHADOW_PROFILE, key))) then
                    love.graphics.setColor(0, 0, 0, 0.22 * aMul)
                    love.graphics.ellipse("fill",
                        px + sunShadowDir(g, x, w, px) * iw * s * 0.14,
                        shY, iw * s * 0.30, math.max(2, 4 * g.persp(tM)))
                end
                local lmk = Scene.Grade.cfg("landmarks")[key:match("landmark_(%a+)$") or ""]
                if lmk and lmk.scorch then
                    Scene.Contact.scorch(px, shY, iw * s, tM,
                        lmk.scorch.radius, lmk.scorch.alpha * aMul)
                end
                Scene.Contact.queue(img, px, shY, s, tM, aMul, 1)
                local br = hovered and 1.10 or 1
                local lc = Scene.Grade.color("landmark", tM, LMG.c)
                love.graphics.setColor(math.min(1, lc[1] * br), math.min(1, lc[2] * br),
                    math.min(1, lc[3] * br), aMul)
                LMG.lcH = LMG.lcH or {}
                LMG.lcH[1], LMG.lcH[2], LMG.lcH[3] = math.min(1, lc[1] * br), math.min(1, lc[2] * br), math.min(1, lc[3] * br)
                local kxF = 0
                if lmk and lmk.flagWave and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
                    local wP = GrassField.PRESETS[rawBiome().id]
                    local gw = wP and GrassField.windAt((px - x) / w, camZ + relM, WorldRoad._time, wP, 0) or 0
                    kxF = -gw * 0.035 + math.sin(WorldRoad._time * 2.4 + i) * 0.02
                end
                WorldRoad._flagKx = kxF
                love.graphics.draw(img, math.floor(px), math.floor(py), 0, s, s, iw / 2, ih, kxF, 0)
                ShadowEngine.mask(img, nil, math.floor(px), math.floor(py), 0, s, s, iw / 2, ih, kxF, tM)
                LMG.Base.over(key, px, py, iw, LMG.refH(key, ih), s, tM, aMul, LMG.lcH)
                if not (lmk and lmk.smoke == "thin" and _G.gameSettings and _G.gameSettings.reducedMotion) then
                    drawLandmarkSmoke(key, px, py, iw, ih, s, aMul, lmk and lmk.smoke == "thin")
                end
                submitLandmarkLight(key, px, py, iw, ih, s, relM,
                    i * 31.7, aMul * (hovered and 1.4 or 1), lmk)
                LMG.selfLight(lmk, px, py, iw, ih, s, relM, aMul * (hovered and 1.3 or 1))
                if lmk and lmk.embers and aMul > 0.5 and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
                    local anc = LuminaireEngine.anchor("landmark", key, 0,
                        "assets/sprites/world/" .. key .. ".png")
                    local ax, ay = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.45
                    LuminaireEngine.drawEmbersSpec(LMG.EMBERS, px + (ax - 0.5) * iw * s,
                        py - ih * s * (1 - ay), ih * s, i * 7.7)
                end
                if lmk and lmk.dust and not (_G.gameSettings and _G.gameSettings.reducedMotion)
                   and love.math.random() < lmk.dust.rate / 60 then
                    local ra = envColor("roadA")
                    local halfF = ROAD_HALF * (0.30 + 0.70 * (tM ^ 1.15))
                    WeatherEngine.emitDust((px - g.cx) / w + (love.math.random() - 0.5) * halfF * 1.6,
                        camZ + relM, tM, 0.01,
                        { math.min(1, ra[1] * 1.4), math.min(1, ra[2] * 1.35), math.min(1, ra[3] * 1.2) },
                        lmk.dust.alpha)
                end
                if aMul > 0.6 then
                    submitLandmarkOccluder(img, px, py, iw, ih, s, relM)
                end
                do
                    local oc2 = Scene.Grade.cfg("occlusion")
                    local hsh = (i * 0.618) % 1
                    GrassField.requireTufts(relM - 0.05, px, iw * s * 0.8,
                        oc2.tuftsMin + math.floor(hsh * (oc2.tuftsMax - oc2.tuftsMin + 1)),
                        oc2.baseCover * ih * s * aMul / GrassField.CELL_H)
                end
                f._geo[i] = { px = px, py = py, s = s, iw = iw, ih = ih,
                              aMul = aMul, hovered = hovered }
                local grow = 14
                f.markBoxes[i] = {
                    x1 = px - iw * s / 2 - grow, y1 = py - ih * s - grow - 16,
                    x2 = px + iw * s / 2 + grow, y2 = py + grow,
                }
            else
                f._geo[i] = nil
                f.markBoxes[i] = nil
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    local function drawList(list)
    for _, p in ipairs(list) do
        local rel = p.z - camZ
        local t = g.tOf(rel)
        if t and t >= 0 then
            if fkMarks and not fkMarks.drawn and rel < fkMarks.rel then
                flushGrassTo(fkMarks.rel)
                drawForkPhysical()
                fkMarks.drawn = true
            end
            if lmMark and not lmMark.drawn and rel < lmMark.rel then
                flushGrassTo(lmMark.rel)
                drawChosenLandmark()
                lmMark.drawn = true
            end
            if encMark and not encMark.drawn and rel < encMark.rel then drawEncounterNow() end
            flushGrassTo(rel)
            local over = math.max(0, -rel)
            local inner = 0.11 + 0.38 * t + over * 0.09
            local lateral = p.side * w * (inner + p.lane * 0.38)
            local rdef = LuminaireEngine.def(p.bid, p.kind)
            local roadHalf = nil
            if rdef and rdef.roadside then
                roadHalf = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
                lateral = p.side * WorldRoad.postLateral(roadHalf, p.bid) + roadWobble(p.z, t, w)
            end
            local pxX = g.cx + lateral
            local sy = g.latY(pxX - g.cx, t) + over * g.h * 0.13

            if p.clutter then Scene.Clutter.draw(p, LMG.cEnv) end
            local img = not p.clutter and getSprite(p.kind, p.variant, p.bid) or nil
            local fadeA = propFadeK(p) * PropCut.hideK(p)
            local roadLum = rdef and rdef.roadside
            if img and not roadLum and not PropCut.kinds[p.kind] then
                local ct = WorldRoad._castleTop
                if ct and t < 0.36 then
                    local kx = math.min(1, math.max(0, (math.abs(pxX - ct.cx) - ct.w * 0.5) / (ct.w * 0.24)))
                    fadeA = fadeA * (1 - (1 - math.min(1, math.max(0, (t - 0.24) / 0.12))) * (1 - kx))
                end
            end
            if fadeA <= 0.01 then img = nil end

            if img and not roadLum and not PropCut.kinds[p.kind] and WorldRoad._fork and rel > FORK_REL - 1.5 then
                local f2 = WorldRoad._fork
                local halfRF = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
                local halfCorr = halfRF * (f2.n > 1 and 0.78 or 1)
                for bi = 1, f2.n do
                    if f2.dirs[bi] ~= 0 then
                        local bc = g.cx + forkOffset(f2, bi, rel, w)
                        local inK = 1 - math.min(1, math.max(0,
                            (math.abs(pxX - bc) - halfCorr) / math.max(halfRF * 0.15, w * 0.05)))
                        local bk = forkAlpha(f2, bi) * (f2.animIn or 1)
                        if f2.converge and bi == f2.chosen then bk = 1 - (f2.converge.k or 0) end
                        fadeA = fadeA * (1 - inK * bk)
                    end
                end
                if fadeA <= 0.01 then img = nil end
            end
            if WorldRoad._trace and rdef and not img then
                WorldRoad._trace(p, pxX, sy, 0, t, "front")
            end

            if img then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1) * PropCut.crestK(p.kind, t)
                local s = g.scaleAt(size, t, ih)
                if not roadLum then s = PropCut.capS(s, WorldRoad.enemyScreenK(g.h)) end
                local isTree = (p.kind == "tree" or p.kind == "pine"
                    or p.kind == "deadtree" or p.kind == "bush")
                local reduced = (_G.gameSettings and _G.gameSettings.reducedMotion) or false
                local vflip, vtR, vtG, vtB = 1, 1, 1, 1
                local pv = nil
                if isTree then
                    pv = Scene.Var.of(p.z, p.kind, Scene.Grade.cfg("trees"))
                    s = s * pv.scale
                    vflip, vtR, vtG, vtB = pv.flip, pv.tintR, pv.tintG, pv.tintB
                    vflip = PropCut.flipToSun(img, sunShadowDir(g, x, w, g.cx) < 0, vflip)
                    local pvc = LMG.pvCopy
                    pvc.windPhase, pvc.canopy, pvc.trunk = pv.windPhase, pv.canopy, pv.trunk
                    pv = pvc
                end
                if WorldRoad._traceVeg and isTree then WorldRoad._traceVeg(p, fadeA, pxX, sy, iw * s, select(2, PropCut.get(img, p.kind)) * s, t, "front", 1) end

                local lumDef = LuminaireEngine.def(p.bid, p.kind)
                local lumAnc, lumSink, lumFlip = nil, 0, 1
                if lumDef then
                    lumAnc = LuminaireEngine.anchor(p.bid, p.kind, p.variant,
                        luminairePath(p.bid, p.kind, p.variant))
                    local pin = 0
                    if roadHalf then
                        local pcx
                        pcx, lumFlip, pin = WorldRoad.postCenter(p.bid, p.kind, p.side, s, roadHalf, p.variant)
                        pxX = g.cx + pcx + roadWobble(p.z, t, w)
                    else
                        if lumDef.face and lumDef.face ~= 0 then
                            local want = p.side < 0 and 1 or -1
                            lumFlip = (want == lumDef.face) and 1 or -1
                        end
                        pxX = pxX - (lumAnc.offX or 0) * s * lumFlip
                        pin = (lumAnc.offX or 0) * s * lumFlip
                    end
                    lumSink = (lumAnc.footPad or 0) * s
                    if WorldRoad._trace then
                        WorldRoad._trace(p, pxX + pin, sy, fadeA, t, "front", ih * s, iw * s,
                            g.cx + roadWobble(p.z, t, w), roadHalf)
                    end
                    local fr = luminaireFrames(p.bid, p.kind, p.variant)
                    if fr then
                        local ph = (p.z * 7.31) % #fr
                        img = fr[1 + math.floor(
                            (WorldRoad._time * 10 + ph) % #fr)]
                        iw, ih = img:getWidth(), img:getHeight()
                    end
                end

                local _, ihv = PropCut.get(img, p.kind)
                local gw = 0
                if isTree and not reduced then
                    local wP = GrassField.PRESETS[p.bid or rawBiome().id]
                    if wP then
                        gw = GrassField.windAt((pxX - x) / w, p.z, WorldRoad._time, wP, 0)
                        if gw * gw > 1.6 and p.kind ~= "deadtree" and t > 0.25
                           and WorldRoad._rng:random() < 0.035 then
                            local gA = envColor("grassA")
                            WeatherEngine.emitLeaf((pxX - g.cx) / w
                                + (WorldRoad._rng:random() - 0.5) * iw * s * 0.5 / w,
                                p.z, t, ih * s * 0.62 / (g.persp(t) * g.h),
                                { math.min(1, gA[1] * 1.35), math.min(1, gA[2] * 1.3),
                                  math.min(1, gA[3] * 1.1) })
                        end
                    end
                end
                local stiff = (p.kind == "bush") and 0.030
                    or (p.kind == "deadtree" and 0.014 or 0.022)

                if p.cluster and isTree then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cx2 = pxX + off
                        local cy2 = g.latY(cx2 - g.cx, t)
                        local cvar = (p.variant + ci) % PropCut.nvar(p.bid, p.kind)
                        local cimg = getSprite(p.kind, cvar, p.bid)
                        if cimg then
                            local cvv = Scene.Var.of(p.z + ci * 17.3, p.kind, Scene.Grade.cfg("trees"))
                            local cs = s * (0.5 + 0.13 * ci) * cvv.scale
                            local cflip = PropCut.flipToSun(cimg, sunShadowDir(g, x, w, g.cx) < 0, cvv.flip)
                            local crot, ckx = Scene.Var.sway(cvv, WorldRoad._time, gw, stiff, reduced)
                            local tsh = Scene.Grade.cfg("shadow").tree
                            ShadowEngine.queue(cimg, cx2, cy2 - 1, cs,
                                shadowOpts(0.8 * fadeA * (tsh and tsh.alphaK or 1), cflip,
                                    PropCut.cutOf(cimg, p.kind),
                                    WorldRoad.SHADOW_PROFILE[p.kind]
                                        or Scene.Grade.cfg("shadow").tree), t)
                            local cnk = PropCut.nearK(t)
                            Scene.Contact.queue(cimg, cx2, cy2, cs, t, 0.8 * fadeA * (0.35 + 0.65 * cnk), cflip)
                            local csh = p.kind ~= "bush" and cnk > 0 and Scene.Grade.cfg("shadow").canopy
                            if csh then
                                local crx = cimg:getWidth() * cs * csh.width
                                Scene.Contact.queueDisc(cx2 + sunShadowDir(g, x, w, cx2) * crx * csh.shift,
                                    cy2 - 1, crx, crx * csh.flat * (0.5 + 0.5 * t), csh.alpha * 0.8 * fadeA * cnk, t)
                            end
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), t, LMG.c)
                            love.graphics.setColor(math.min(1, cc[1] * 0.88 * cvv.tintR),
                                math.min(1, cc[2] * 0.88 * cvv.tintG),
                                math.min(1, cc[3] * 0.88 * cvv.tintB), fadeA)
                            local cfr = (not reduced) and PropCut.treeFrames(p.bid, p.kind, cvar) or nil
                            local cprev = PropCut.beginDepth(cimg, t)
                            PropCut.draw(cimg, p.kind, math.floor(cx2),
                                math.floor(cy2), crot, cs * cflip, cs, ckx * cflip,
                                cfr and PropCut.frameOf(cfr, cvv.windPhase / 6.2832) or nil)
                            PropCut.endDepth(cprev)
                            PropCut.mask(cimg, p.kind, math.floor(cx2),
                                math.floor(cy2), crot, cs * cflip, cs, ckx * cflip, t)
                        end
                    end
                end

                if p.kind == "fence" then
                    for fi = 1, (t >= 0.35 and 2 or 0) do
                        local fz = p.z + fi * 1.7
                        local ft = g.tOf(fz - camZ)
                        if ft and ft >= 0 then
                            local flat = p.side * w
                                * ((0.11 + 0.38 * ft) + p.lane * 0.38)
                            local fx = g.cx + flat
                            local fy = g.latY(fx - g.cx, ft)
                            local fs = g.scaleAt((KIND_SIZE.fence or 1) * (p.big or 1), ft, ih)
                            ShadowEngine.queue(img, fx, fy - 1, fs,
                                shadowOpts(0.85 * fadeA), ft)
                            Scene.Contact.queue(img, fx, fy, fs, ft, 0.85 * fadeA, 1)
                            local fc = Scene.Grade.color("prop", ft, LMG.c)
                            love.graphics.setColor(fc[1] * 0.94, fc[2] * 0.94, fc[3] * 0.94, fadeA)
                            love.graphics.draw(img, math.floor(fx), math.floor(fy),
                                0, fs, fs, iw / 2, ih)
                            ShadowEngine.mask(img, nil, math.floor(fx), math.floor(fy),
                                0, fs, fs, iw / 2, ih, 0, ft)
                        end
                    end
                end

                local aFade = math.min(1, 0.72 + t * 1.1)
                local tsh = isTree and Scene.Grade.cfg("shadow").tree or nil
                if not ShadowEngine.queue(img, pxX, sy - 1, s,
                    shadowOpts(aFade * fadeA * (tsh and tsh.alphaK or 1), lumFlip * vflip,
                        lumAnc and lumAnc.footPad or PropCut.cutOf(img, p.kind),
                        WorldRoad.SHADOW_PROFILE[p.kind]
                            or (isTree and Scene.Grade.cfg("shadow").tree or nil)), t) then
                    local shd = sunShadowDir(g, x, w, pxX)
                    love.graphics.setColor(0, 0, 0, 0.20 * aFade * fadeA)
                    love.graphics.ellipse("fill",
                        pxX + shd * iw * s * 0.16, sy - 1,
                        iw * s * 0.24, math.max(2, 4 * g.persp(t)))
                end
                local nk = isTree and PropCut.nearK(t) or 1
                if p.kind ~= "tuft" and p.kind ~= "flowers" then
                    Scene.Contact.queue(img, pxX, sy, s, t, fadeA * (0.35 + 0.65 * nk), lumFlip * vflip)
                end
                if isTree and p.kind ~= "bush" and nk > 0 and Scene.Grade.cfg("shadow").canopy then
                    local cs = Scene.Grade.cfg("shadow").canopy
                    local rx = iw * s * cs.width
                    Scene.Contact.queueDisc(pxX + sunShadowDir(g, x, w, pxX) * rx * cs.shift,
                        sy - 1, rx, rx * cs.flat * (0.5 + 0.5 * t), cs.alpha * aFade * fadeA * nk, t)
                end

                local rot = 0
                local gustKx = 0
                local sink2 = lumSink
                if pv then
                    rot, gustKx = Scene.Var.sway(pv, WorldRoad._time, gw, stiff, reduced)
                elseif p.kind == "tuft" or p.kind == "flowers" then
                    rot = math.sin(WorldRoad._time * 2.3 + p.z * 1.4) * 0.055
                end
                rot = rot + pokeRot(p)

                if lumDef then
                    local la = lumArg
                    la.gx = pxX + ((lumFlip < 0 and 1 - (lumAnc.ax or 0.5) or (lumAnc.ax or 0.5)) - 0.5) * iw * s
                    la.gy, la.t, la.seed, la.capR, la.alphaK = sy, t, p.z, g.h * 0.30, fadeA
                    la.flameH = math.max(8, ih * s * (1 - (lumAnc.ay or 0.3)) - sink2)
                    LuminaireEngine.drawPool(p.bid, p.kind, la)
                end

                local pc = Scene.Grade.color(Scene.Grade.familyOf(p.kind, lumDef ~= nil), t, LMG.c)
                love.graphics.setColor(math.min(1, pc[1] * vtR), math.min(1, pc[2] * vtG),
                    math.min(1, pc[3] * vtB), fadeA)
                local dprev = nil
                local tfr = (not reduced) and PropCut.treeFrames(p.bid, p.kind, p.variant) or nil
                if isTree then dprev = PropCut.beginDepth(img, t) end
                PropCut.draw(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                    rot, s * lumFlip * vflip, s, gustKx * lumFlip * vflip,
                    tfr and PropCut.frameOf(tfr, pv and pv.windPhase / 6.2832
                        or Scene.Clutter.hash01(p.z * 0.731)) or nil)
                PropCut.endDepth(dprev)
                PropCut.mask(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                    rot, s * lumFlip * vflip, s, gustKx * lumFlip * vflip, t)
                if isTree and fadeA >= 0.5 then
                    local occ = Scene.Grade.cfg("trees").selfShade
                    if occ then
                        PropCut.occlude(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                            s * lumFlip * vflip, s, t, occ)
                    end
                end
                if p.kind ~= "tuft" and p.kind ~= "flowers" and p.kind ~= "fence"
                   and fadeA >= 0.5 then
                    local oc2 = Scene.Grade.cfg("occlusion")
                    local isTree = (p.kind == "tree" or p.kind == "pine"
                        or p.kind == "deadtree" or p.kind == "bush")
                    local hsh = (p.z * 7.31) % 1
                    local nT = isTree and (2 + math.floor(hsh * 2))
                        or (oc2.tuftsMin + math.floor(hsh * (oc2.tuftsMax - oc2.tuftsMin + 1)))
                    local hpx = oc2.baseCover * ihv * s * (isTree and 0.6 or 1)
                        * (oc2.tuftScale[1] + hsh * (oc2.tuftScale[2] - oc2.tuftScale[1]))
                    GrassField.requireTufts(rel - 0.05, pxX, iw * s * 0.8, nT,
                        hpx / GrassField.CELL_H)
                end

                if not p.ghost and p.kind ~= "tuft" and p.kind ~= "flowers" then
                    local hsn = WorldRoad._hitScene
                    local cr = contentRect[img]
                    local bx1, by1, bx2, by2
                    if cr then
                        local flip = (lumFlip or 1) * vflip
                        local rx0 = (cr.x0 - iw * 0.5) * s * flip
                        local rx1 = (cr.x1 + 1 - iw * 0.5) * s * flip
                        bx1 = pxX + math.min(rx0, rx1)
                        bx2 = pxX + math.max(rx0, rx1)
                        by1 = sy + sink2 + (cr.y0 - ihv) * s
                        by2 = sy + sink2 + (math.min(cr.y1 + 1, ihv) - ihv) * s
                    else
                        bx1, by1 = pxX - iw * s * 0.5, sy + sink2 - ihv * s
                        bx2, by2 = pxX + iw * s * 0.5, sy + sink2
                    end
                    local hidx = #hsn + 1
                    local he = hitSlot(hidx)
                    he.x1, he.y1, he.x2, he.y2 = bx1, by1, bx2, by2
                    he.ref, he.kind, he.s = p, p.kind, s
                    hsn[hidx] = he
                end
                drawLeafFx(p, pxX, sy + sink2, iw, ih, s)

                if fadeA >= 0.5
                   and (p.kind == "tree" or p.kind == "pine"
                        or p.kind == "deadtree" or p.kind == "bush") then
                    local oxT, oyT = love.graphics.transformPoint(
                        pxX, sy + sink2)
                    local oc = occluderSlot()
                    oc.fc = oc.fc or {}
                    oc.z = rel
                    oc.flatColor = Scene.Grade.flatColor("tree", oc.fc)
                    oc.img, oc.x, oc.y, oc.rot = img, oxT, oyT, rot
                    oc.sx, oc.sy, oc.ox, oc.oy = s * vflip, s, iw / 2, ihv
                    oc.bx, oc.by = oxT - iw * s / 2, oyT - ihv * s
                    oc.w, oc.h = iw * s, ih * s
                    LightEngine.submitOccluder(oc)
                end

                if lumDef then
                    local sh2 = ih * s
                    local ax = lumAnc.ax or 0.5
                    if lumFlip < 0 then ax = 1 - ax end
                    local fx = pxX + (ax - 0.5) * iw * s
                    local fy = sy + sink2 - sh2 * (1 - (lumAnc.ay or 0.3))
                    if p._pokeT then
                        fx = fx + rot * ((sy + sink2) - fy)
                    end
                    local fxT, fyT = love.graphics.transformPoint(fx, fy)
                    local gxT, gyT = love.graphics.transformPoint(fx, sy)
                    local la = lumArg
                    la.fx, la.fy, la.gx, la.gy = fxT, fyT, gxT, gyT
                    la.sh, la.t, la.rel, la.seed = sh2, t, rel, p.z
                    la.flameH = math.max(8, gyT - fyT)
                    la.capR = g.h * 0.30
                    la.alphaK = fadeA
                    LuminaireEngine.submit(p.bid, p.kind, la)
                    if fadeA >= 0.5 then
                        LuminaireEngine.drawEmbers(p.bid, p.kind, fx, fy, sh2, p.z)
                    end
                end

                if p.kind == "fence" and p.perched and not p.flown then
                    local railY = sy - ih * s * 0.82
                    for bi = 1, p.perched do
                        local bx = pxX + (bi == 1 and -0.22 or 0.24) * iw * s
                        love.graphics.setColor(0.14, 0.11, 0.10, 1)
                        love.graphics.rectangle("fill", math.floor(bx), math.floor(railY - 3), 3, 3)
                        love.graphics.rectangle("fill", math.floor(bx + 2), math.floor(railY - 5), 2, 2)
                    end
                    if rel < 6.5 or p._scareBirds then
                        p.flown = true
                        local skyH = g.crestApexY - g.y
                        for bi = 1, p.perched do
                            table.insert(WorldRoad._birds, {
                                xr = (pxX - x) / w,
                                yr = (sy - ih * s - g.y) / skyH,
                                dir = p.side >= 0 and 1 or -1,
                                speed = 0.07 + WorldRoad._rng:random() * 0.02,
                                phase = WorldRoad._rng:random() * 6.28,
                                vyr = -(0.28 + WorldRoad._rng:random() * 0.12),
                            })
                        end
                    end
                end
            end
        end
    end
    end

    drawCrestFog(g, x, w)
    local enemyFn = WorldRoad._enemyDraw
    if not enemyFn then drawList(farPass) end
    if enemyFn then
        local et = g.tOf(WorldRoad.BATTLE_REL)
        local baseY = (et and g.latY(0, et)) or WorldRoad._enemyBaseY or 1e9
        local behind, front = WorldRoad._lists.behind, WorldRoad._lists.front
        clearList(behind)
        clearList(front)
        for _, p in ipairs(farPass) do
            local pt = g.tOf(p.z - camZ)
            local py = pt and pt >= 0 and g.latY(0, pt) or -1e9
            if py >= baseY - 2 then front[#front + 1] = p
            else behind[#behind + 1] = p end
        end
        for _, p in ipairs(nearPass) do
            local pt = g.tOf(p.z - camZ)
            local py = pt and pt >= 0 and g.latY(0, pt) or -1e9
            if py >= baseY - 2 then front[#front + 1] = p
            else behind[#behind + 1] = p end
        end
        if require("src.core.Release").isDev() and os.getenv("GF_DEBUG") then
            require("src.core.Debug").log(string.format("[depth] baseY=%.0f  front=%d behind=%d",
                baseY, #front, #behind))
            for _, p in ipairs(front) do
                local pt = g.tOf(p.z - camZ)
                require("src.core.Debug").log(string.format("  FRONT %s rel=%.1f py=%.0f",
                    p.kind, p.z - camZ, pt and g.latY(0, pt) or -1))
            end
        end
        drawList(behind)
        WeatherEngine.flushTo(WorldRoad.BATTLE_REL)
        ShadowEngine.endFrame(Scene.Contact.drawAcc)
        Scene.Contact.endFrame()
        enemyFn()
        WorldRoad._enemyDraw = nil
        drawList(front)
    else
        drawList(nearPass)
    end
    if fkMarks and not fkMarks.drawn then
        flushGrassTo(fkMarks.rel)
        drawForkPhysical()
        fkMarks.drawn = true
    end
    if lmMark and not lmMark.drawn then
        flushGrassTo(lmMark.rel)
        drawChosenLandmark()
        lmMark.drawn = true
    end
    if encMark and not encMark.drawn then drawEncounterNow() end
    flushGrassTo(-1)
    ShadowEngine.endFrame(Scene.Contact.drawAcc)
    Scene.Contact.endFrame()
end

function LMG.drawEncounterFront(g, x, w, camZ)
    local e = WorldRoad._encounter
    if not e or not WorldRoad._travel then return end
    local rel = e.z - camZ
    if rel > REL_CREST then return end
    local t = g.tOf(rel)
    if not t then return end

    local cx = g.cx + roadWobble(e.z, t, w)
    local sy = g.crestApexY + (g.bottomY - g.crestApexY) * t
    local tBattle = g.tOf(WorldRoad.BATTLE_REL) or 0.3
    local k = math.min(1.02, g.persp(t) / math.max(0.01, g.persp(tBattle)))
    local s = e.targetScale * WorldRoad.battleSizeK() * WorldRoad.enemyScreenK(g.h) * k
    cx = cx - math.floor((e.offX or 0) * s)
    local pad = e.footPad or 0
    if e.framePads and e.anim and e.framePads[e.anim.currentFrame] then
        pad = e.framePads[e.anim.currentFrame]
    end
    local sink = (e.footSink or 0) * math.min(1, k)
    local footY = pad * s + sink
    local es = e.shadow or LMG.NO_CRITTERS
    local lift, shX = 0, cx
    if es.floating then
        local ER = require("src.ui.EnemyRenderer")
        local now = love.timer.getTime()
        lift = -ER.poseOffsetY(e.spriteId, e.ih * s, now, 0)
        shX = cx + ShadowEngine.tipShiftAt(cx) * lift * 0.55
        cx = cx + ER.poseOffsetX(e.spriteId, e.ih * s, now, 0)
        shX = shX + ER.poseOffsetX(e.spriteId, e.ih * s, now, 0)
    end
    local dx0 = math.floor(cx - e.iw * s / 2)
    local dy0 = sy - e.ih * s + footY - lift
    if WorldRoad._traceEnemy then WorldRoad._traceEnemy(dx0, dy0, "encounter") end
    if e.anim then
        local drawn = ShadowEngine.silhouette(shX, sy - 1 + lift * 0.16, { smear = e.iw * s * 0.035 * (es.smearK or 1),
                widthK = es.widthK, lenK = es.lenK, alphaK = es.alphaK,
                baseK = e.shadowBaseK, riseK = e.shadowRiseK,
                contentH = (e.contentH or (e.ih - pad)) * s },
            function(tint)
                e.anim:draw(-(e.iw * s) / 2, -(e.ih * s) + footY, s, tint)
            end)
        if drawn and es.footL and es.footR and not es.floating then
            require("src.ui.EnemyRenderer").drawFootContact(
                cx + ((es.footL + es.footR + 1) / 2 - es.mw / 2) * s,
                (es.footR - es.footL + 1) * s, sy - 1, s, 1)
        end
    else
        ShadowEngine.sprite(e.img, cx, sy - 1, s,
            { alphaK = 0.9, footPad = e.footPad,
              baseK = e.shadowBaseK, riseK = e.shadowRiseK })
    end
    if e.anim then
        require("src.ui.EnemyRenderer").drawRim(function(ox, oy) e.anim:draw(dx0 + ox, dy0 + oy, s) end, cx, s)
    end
    local ec = Scene.Grade.color("enemy", t, LMG.c)
    local t4 = LMG.tint4
    t4[1], t4[2], t4[3], t4[4] = ec[1], ec[2], ec[3], 1
    love.graphics.setColor(ec[1], ec[2], ec[3], 1)
    if e.anim then
        e.anim:draw(dx0, dy0, s, t4)
    else
        love.graphics.draw(e.img, dx0, dy0, 0, s, s)
    end

    local oxT, oyT = love.graphics.transformPoint(dx0, dy0)
    local flatColor = Scene.Grade.flatColor("enemy", LMG.fc)
    if e.anim then
        LightEngine.submitOccluder({
            z = rel + 6, flatColor = flatColor, bx = oxT, by = oyT, w = e.iw * s, h = e.ih * s,
            fn = function()
                local r, g2, b, a = love.graphics.getColor()
                e.anim:draw(oxT, oyT, s, { r, g2, b, a })
            end,
        })
    else
        LightEngine.submitOccluder({
            z = rel + 6, flatColor = flatColor, img = e.img, x = oxT, y = oyT, sx = s, sy = s,
            bx = oxT, by = oyT, w = e.iw * s, h = e.ih * s,
        })
    end

    local anchors = e.spriteId and EnemyEmissives[e.spriteId]
    if anchors then
        local pulse = 0.90 + 0.10 * math.sin(WorldRoad._time * 1.1)
        for ai, a in ipairs(anchors) do
            LightEngine.submitMicro(
                oxT + a.xr * e.iw * s, oyT + a.yr * e.ih * s,
                a.r * e.ih * s, a.color,
                (a.intensity or 0.35) * 0.8 * pulse, rel)
        end
    end
end

WorldRoad._profState = {}
local function _profMark(name)
    local P = WorldRoad._prof
    if not P then return end
    love.graphics.flushBatch()
    local ps = WorldRoad._profState
    local now = love.timer.getTime()
    local kb = collectgarbage("count")
    if name ~= "start" and ps.t then
        P[name] = (P[name] or 0) + (now - ps.t) * 1000
        P["kb " .. name] = (P["kb " .. name] or 0) + (kb - ps.kb)
    end
    ps.t, ps.kb = now, kb
end

WorldRoad._drawFrame = 0
function WorldRoad.draw(x, y, w, h, actNumber)
    _profMark("start")
    WorldRoad._drawFrame = WorldRoad._drawFrame + 1
    if actNumber then WorldRoad.setBiome(actNumber) end

    local g = domeGeom(x, y, w, h)

    local lr = WorldRoad._lastRect or {}
    lr.x, lr.y, lr.w, lr.h = x, y, w, h
    WorldRoad._lastRect = lr
    local hs = WorldRoad._hitScene
    for i = #hs, 1, -1 do hs[i] = nil end

    local amb = WeatherEngine.modulateAmbient(currentLightAmbient())
    local bk = 1
    if WorldRoad._blend then
        local k = math.min(1, WorldRoad._blend.t / WorldRoad._blend.duration)
        bk = k * k * (3 - 2 * k)
    end
    LightEngine.beginFrame(amb)
    Scene.Grade.begin(rawBiome().id, WorldRoad._timeOfDay,
        WorldRoad._blend and WorldRoad._prevBiomeIndex
            and rawBiome(WorldRoad._prevBiomeIndex).id or nil,
        bk, amb)
    Scene.Grade.setDepth(g.tOf(WorldRoad.BATTLE_REL) or 1)

    do
        local xr = PropCut.sunXr()
        local sunX = xr and (x + xr * w) or g.cx
        ShadowEngine.setFrame(sunX, w, WorldRoad._timeOfDay,
            LightEngine.ambientLuma())
        LuminaireEngine.setTimeOfDay(WorldRoad._timeOfDay)
    end
    Scene.Contact.setFrame(Scene.Grade.cfg("contact"), Scene.Grade.shadowTint())
    ShadowEngine.setAlphaK(Scene.Grade.cfg("shadow").alphaK)
    ShadowEngine.FADE = Scene.Grade.cfg("shadow").fade or 0.45

    local gb0 = envColor("grassB")
    local g0 = Scene.Grade.color("ground", 1, LMG.c)
    love.graphics.setColor(gb0[1] * 0.78 * g0[1], gb0[2] * 0.78 * g0[2], gb0[3] * 0.78 * g0[3], 1)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.push()
    local swCx, swCy = x + w / 2, y + h / 2
    love.graphics.translate(
        swCx + math.sin(WorldRoad._time * 0.23) * 1.5,
        swCy + math.cos(WorldRoad._time * 0.19) * 1.1)
    love.graphics.rotate(0.0012 * math.sin(WorldRoad._time * 0.3))
    love.graphics.scale(1.006, 1.006)
    love.graphics.translate(-swCx, -swCy)
    do
        local ccx, ccy = love.graphics.transformPoint(g.cx, g.crestApexY + g.R)
        local ex = love.graphics.transformPoint(g.cx + 1000, g.crestApexY + g.R)
        local k = (ex - ccx) / 1000
        local D = (g.bottomY - g.crestApexY) * k
        ShadowEngine.setClip(ccx, ccy, g.R * k, D)
        local shc = Scene.Grade.cfg("shadow").color or LMG.SHADE
        ShadowEngine.setTint(shc[1], shc[2], shc[3])
    end

    WeatherEngine.beginFrame({ geom = g, x = x, w = w, camZ = WorldRoad._camZ,
        relCrest = REL_CREST, tPow = T_POW })
    GrassField.beginFrame()
    WeatherEngine.setClip(ShadowEngine.getClip())

    _profMark('pre')
    drawSky(g, x, y, w)
    drawCelestial(g, x, y, w)
    drawMountains(g, x, w, WorldRoad._camZ)
    drawClouds(g, x, y, w)
    do
        local lf = Scene.Grade.cfg("lowFog")
        local bandH = math.floor(h * lf.height)
        WeatherEngine.drawLowFog(x, g.crestApexY - bandH, w, bandH + 6, lf, 1)
    end
    WeatherEngine.drawSky(g, x, w)
    drawMountainsFront(g, x, w, WorldRoad._camZ)
    drawBirds(g, x, y, w)

    _profMark('sky')
    do
        local fogc = envColor("fog")
        local gv = gradTex()
        local hazeBot = g.crestApexY + 10
        love.graphics.setColor(fogc[1], fogc[2], fogc[3], 0.16)
        love.graphics.draw(gv, x, hazeBot, 0, w, -(hazeBot - y) / 256)
        for sx = 0, w - 1, 6 do
            local cy = g.crestYAt(x + sx)
            if cy > hazeBot then
                love.graphics.rectangle("fill", x + sx, hazeBot, 6, cy - hazeBot)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    do
        local fogc = envColor("fog")
        local bandH = math.floor(h * 0.11)
        local gv = gradTex()
        local cyF = g.crestApexY - bandH * 0.5 + 6
        love.graphics.setColor(fogc[1], fogc[2], fogc[3], 0.26)
        love.graphics.draw(gv, x, cyF, 0, w, -bandH * 0.5 / 256)
        love.graphics.draw(gv, x, cyF, 0, w, bandH * 0.5 / 256)
        love.graphics.setColor(1, 1, 1, 1)
    end

    _profMark('haze')
    drawCastle(g, x, w, WorldRoad._camZ)
    drawEncounterBehind(g, x, w, WorldRoad._camZ)
    drawPropsBehind(g, x, w, WorldRoad._camZ)
    WeatherEngine.flushTo(REL_CREST)
    _profMark('castle')
    drawDome(g, x, y, w)
    _profMark('dome')
    drawTerrainDetail(g, x, w, WorldRoad._camZ)
    _profMark('terrain')
    drawRoad(g, x, w, WorldRoad._camZ)
    _profMark('road')
    do
        local gg = g
        RoadWear.draw({
            geom = gg, x = x, w = w, camZ = WorldRoad._camZ,
            time = WorldRoad._time,
            bid = rawBiome().id,
            relCrest = REL_CREST,
            roadCenter = function(z, t) return gg.cx + roadWobble(z, t, w) end,
            roadHalf = function(t)
                return ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15)) * 0.82
            end,
            tint = envColor,
            forkActive = WorldRoad._fork ~= nil,
            forkRel = FORK_REL,
        })
    end
    _profMark('roadwear')

    do
        local b = rawBiome()
        local acc = b.accent or { 0.8, 0.7, 0.4 }
        local crc = Scene.Grade.color("critter", 0.7, LMG.c)
        local ar, ag, ab = acc[1] * crc[1], acc[2] * crc[2], acc[3] * crc[3]
        local glow = LightEngine.ambientLuma() < 0.75
        local skipGlow = glow and WeatherEngine.hasFireflies(b.id)
        for _, cr in ipairs(skipGlow and LMG.NO_CRITTERS or WorldRoad._critters) do
            local cxr = x + cr.xr * w
            local cyy = g.latY(cxr - g.cx, cr.yr)
                - 14 - math.sin(WorldRoad._time * 3.1 + cr.phase) * 6
            local a = math.min(1, cr.life / 2)
            if glow then
                local depth = 0.45 + 0.55 * cr.yr
                local blink = 0.5 + 0.5 * math.sin(WorldRoad._time * 2.2 + cr.phase * 3)
                love.graphics.setColor(ar, ag, ab, 0.16 * blink * a)
                love.graphics.circle("fill", cxr, cyy, 4 * depth + 1)
                love.graphics.setColor(ar * 1.2, ag * 1.2, ab * 1.1, 0.9 * blink * a)
                love.graphics.rectangle("fill", math.floor(cxr), math.floor(cyy), 2, 2)
                local fx2, fy2 = love.graphics.transformPoint(cxr, cyy)
                LightEngine.submitMicro(fx2, fy2,
                    Config.Lighting.FIREFLY.radius * depth, acc,
                    Config.Lighting.FIREFLY.intensity * blink * a)
            else
                local flap = math.sin(WorldRoad._time * 11 + cr.phase) > 0
                love.graphics.setColor(ar, ag, ab, 0.9 * a)
                love.graphics.rectangle("fill", math.floor(cxr), math.floor(cyy), 2, 2)
                if flap then
                    love.graphics.rectangle("fill", math.floor(cxr - 2), math.floor(cyy - 1), 2, 1)
                    love.graphics.rectangle("fill", math.floor(cxr + 2), math.floor(cyy - 1), 2, 1)
                end
            end
        end
    end

    _profMark('critters')
    drawProps(g, x, w, WorldRoad._camZ)
    WeatherEngine.flushAll()

    _profMark('props')
    love.graphics.pop()


    if WorldRoad._travel then
        local enc = WorldRoad._encounter
        if enc then
            love.graphics.setColor(0.55, 0.1, 0.1, 0.045)
        else
            love.graphics.setColor(0.9, 0.62, 0.25, 0.04)
        end
        love.graphics.rectangle("fill", x, y, w, h)
    end

    local gradH = math.floor(h * 0.20)
    local gv, gh2 = gradTex()
    love.graphics.setColor(0, 0, 0, 0.32)
    love.graphics.draw(gv, x, g.bottomY, 0, w, -gradH / 256)

    local vw = math.floor(w * 0.055)
    love.graphics.setColor(0, 0, 0, 0.16)
    love.graphics.draw(gh2, x, y, 0, vw / 256, h)
    love.graphics.draw(gh2, x + w, y, 0, -vw / 256, h)

    _profMark('front')
    love.graphics.setColor(1, 1, 1, 1)
end

function WorldRoad.drawLightComposite(x, y, w, h)
    LightEngine.composite(x, y, w, h)
end

function WorldRoad.drawForkOverlay(x, y, w, h)
    local g = domeGeom(x, y, w, h)
    drawForkMarks(g, x, w, WorldRoad._camZ)
end

function WorldRoad.drawOverlays(x, y, w, h)
    WorldRoad.drawLightComposite(x, y, w, h)
    WorldRoad.drawForkOverlay(x, y, w, h)
end

function WorldRoad.resetRun()
    WorldRoad._rng:setSeed(0xC0FFEE)
    WorldRoad._camZ = 0
    WorldRoad._segBase = 0
    WorldRoad._segBasePrev = nil
    WorldRoad._biomeIndex = 1
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._blend = nil
    WorldRoad._travel = nil
    WorldRoad._entry = nil
    WorldRoad._encounter = nil
    WorldRoad._fork = nil
    WorldRoad._wallVar = nil
    WorldRoad._landmark = nil
    WorldRoad._enemyDraw = nil
    WorldRoad._enemyBaseY = nil
    WorldRoad._nextLumZ = nil
    require("src.ui.CastleDrift").reset()
    WorldRoad.planStop(WorldRoad.TRAVEL_DISTANCE, true)
    WorldRoad._timeOfDay = 1
    WorldRoad._timeOfDayTarget = 1
    WorldRoad._props = {}
    WorldRoad._clouds = {}
    WeatherEngine.reset()
end

function WorldRoad.restoreProgress(actNumber, floorInAct)
    WorldRoad.resetRun()
    WorldRoad._biomeIndex = math.max(1, actNumber or 1)
    WorldRoad._segBase = 0
    WorldRoad._camZ = math.max(0, (floorInAct or 1) - 1) * WorldRoad.TRAVEL_DISTANCE
    WorldRoad.planStop(WorldRoad._camZ, true)
    local prog = math.min(1, math.max(0, ((floorInAct or 1) - 1) / 7)) ^ 1.35
    WorldRoad._timeOfDay = 0.62 + 0.38 * prog
    WorldRoad._timeOfDayTarget = WorldRoad._timeOfDay
end

WorldRoad.PREWARM_BUDGET = 0.002
local prewarm = { done = {}, co = nil, bid = nil }
local PREWARM_NODE_TYPES = { "battle", "elite", "rest", "shop", "event", "treasure" }

local function prewarmJobs(idx)
    local b = rawBiome(idx)
    local bid = b.id
    local y = coroutine.yield
    getGroundTexture(bid); y()
    RoadSurface.get(bid, b, 16); y()
    getSprite("mountains", 0, bid); y()
    mountainsSkyColor(bid); y()
    getSprite("mountains_front", 0, bid); y()
    getSprite("castle", 0, bid); y()
    landmarkFrames(bid .. "_castle"); y()
    landmarkFrames(bid .. "_castle_door"); y()
    local kinds = {}
    for _, k in ipairs(kindOrder(b.propWeights)) do kinds[#kinds + 1] = k end
    kinds[#kinds + 1] = TREE_KIND[bid] or "tree"
    kinds[#kinds + 1] = "tuft"
    for _, kind in ipairs(kinds) do
        for v = 0, PropCut.nvar(bid, kind) - 1 do
            getSprite(kind, v, bid)
            PropCut.treeFrames(bid, kind, v)
            y()
        end
    end
    for _, e in ipairs(Scene.Clutter.entries(bid) or PropCut.EMPTY) do
        for v = 0, (e.n or 1) - 1 do getSprite(e.kind, v, bid); PropCut.treeFrames(bid, e.kind, v) end
        y()
    end
    PropCut.depthShader(); y()
    local lumCat = LuminaireEngine.catalog(bid)
    for _, kind in ipairs(kindOrder(lumCat)) do
        for v = 0, 2 do
            getSprite(kind, v, bid)
            luminaireFrames(bid, kind, v)
            LuminaireEngine.anchor(bid, kind, v, luminairePath(bid, kind, v))
            y()
        end
    end
    for _, nt in ipairs(PREWARM_NODE_TYPES) do
        local key = landmarkKeyFor(nt, bid)
        if key then
            getLandmark(key)
            landmarkFrames(key)
            local hk = landmarkHoverAnimKey(key)
            if hk then landmarkFrames(hk) end
            y()
        end
    end
end

prewarmTick = function(budget, baseIdx)
    budget = budget or WorldRoad.PREWARM_BUDGET
    if budget <= 0 then return end
    local base = baseIdx or WorldRoad._biomeIndex
    local cur = rawBiome(base).id
    local target
    if not prewarm.done[cur] then
        target = base
    else
        local nxt = rawBiome(base + 1).id
        if not prewarm.done[nxt] then target = base + 1 end
    end
    if not target then return end
    local bid = rawBiome(target).id
    if prewarm.bid ~= bid or not prewarm.co then
        prewarm.bid = bid
        prewarm.co = coroutine.create(prewarmJobs)
        prewarm.arg = target
    end
    local t0 = love.timer.getTime()
    repeat
        local ok, err = coroutine.resume(prewarm.co, prewarm.arg)
        if not ok then
            require("src.core.Debug").warn(("[worldroad] pré-aquecimento do bioma '%s' falhou: %s")
                :format(bid, tostring(err)))
            prewarm.done[bid], prewarm.co = true, nil
            return
        end
        if coroutine.status(prewarm.co) == "dead" then
            prewarm.done[bid], prewarm.co = true, nil
            return
        end
    until love.timer.getTime() - t0 >= budget
end
WorldRoad.prewarmTick = prewarmTick
function WorldRoad.isPrewarmed(idx)
    return prewarm.done[rawBiome(idx).id] == true
end

function WorldRoad.clearCache()
    WorldRoad._spriteCache = {}
    WorldRoad._quadCache = {}
    lumFramesCache = {}
    PropCut.frames = {}
    prewarm.done, prewarm.co, prewarm.bid = {}, nil, nil
    require("engine.GrassField").clearCache()
    WeatherEngine.reset()
    WorldRoad._props = {}
    WorldRoad._clouds = {}
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._encounter = nil
    WorldRoad._nextLumZ = nil
    WorldRoad._fork = nil
    WorldRoad._landmark = nil
end

return WorldRoad
