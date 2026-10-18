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
}

local PropCut = {
    data = require("src.data.world_props"),
    px = setmetatable({}, { __mode = "k" }),
    quad = setmetatable({}, { __mode = "k" }),
    vis = setmetatable({}, { __mode = "k" }),
    sizeK = setmetatable({}, { __mode = "k" }),
    kinds = { tree = true, pine = true, deadtree = true, bush = true },
}
function PropCut.cutOf(img, kind)
    if not PropCut.kinds[kind] then return 0 end
    local ih = img:getHeight()
    local cut = PropCut.px[img]
    if cut == nil then
        cut = math.floor(ih * PropCut.data.SINK_DEFAULT_FRAC + 0.5)
    end
    return math.max(0, math.min(cut, math.floor(ih * PropCut.data.SINK_MAX_FRAC)))
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
function PropCut.draw(img, kind, x, y, rot, sx, sy, kx)
    local q, ihv = PropCut.get(img, kind)
    local iw = img:getWidth()
    if q then
        love.graphics.draw(img, q, x, y, rot, sx, sy, iw / 2, ihv, kx or 0, 0)
    else
        love.graphics.draw(img, x, y, rot, sx, sy, iw / 2, ihv, kx or 0, 0)
    end
end

local WorldRoad = {}

local CREST_RATIO   = 0.40
local DOME_R_FACTOR = 1.6
local REL_CREST     = 26
local EMERGE_BAND   = 9
local T_POW         = 1.35
local ROAD_HALF     = 0.15
local PROP_SPACING  = 1.05
local UNIT_PX       = 0.115
local BLEND_DURATION = 2.2

WorldRoad.BATTLE_REL      = 9
WorldRoad.BATTLE_REL_NEAR = 9
WorldRoad.BATTLE_REL_FAR  = 16.5
WorldRoad.TRAVEL_DISTANCE = 20
WorldRoad.TRAVEL_DURATION = 6.5
local SEGMENT_LEN = WorldRoad.TRAVEL_DISTANCE * 8

local KIND_SIZE = {
    tree = 4.6, pine = 5.0, deadtree = 4.2, fence = 1.55, sign = 1.7,
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
    dusk_landmark_rest      = { baseK = 0.17, riseK = 0.20, lenK = 0.60 },
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
    local ok, img = pcall(love.graphics.newImage, data)
    if not ok or not img then return nil end
    img:setFilter("nearest", "nearest")
    scanContentRect(img, path, data)
    Scene.Contact.scan(img, data)
    PropCut.px[img] = PropCut.data.sink[name]
    PropCut.sizeK[img] = PropCut.data.sizeK[name]
    return img
end

local function readAnimFrames(key)
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
            if okd and data then ok, im = pcall(love.graphics.newImage, data) end
            if ok and im then
                im:setFilter("nearest", "nearest")
                scanContentRect(im, path, data)
                Scene.Contact.scan(im, data)
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
    local LUM_STEP = 7
    local LUM_JIT  = 2.5
    WorldRoad._nextLumZ = WorldRoad._nextLumZ or {
        [-1] = z + LUM_STEP * (0.15 + rng:random() * 0.20),
        [1]  = z + LUM_STEP * (0.60 + rng:random() * 0.25),
    }
    local lumCat = LuminaireEngine.catalog(b.id)
    if noLum then
        if LuminaireEngine.isLuminaire(p.kind) then
            p.kind = TREE_KIND[b.id] or "tree"
        end
    elseif next(lumCat) then
        local nextZ = WorldRoad._nextLumZ[p.side] or z
        if z >= nextZ then
            local nearBias = (z - (WorldRoad._camZ or 0)) < 9
            local function w(d)
                local base = d.weight or 0.5
                if nearBias and d.roadside then base = base * 3 end
                return base
            end
            local tot = 0
            local lumOrder = kindOrder(lumCat)
            for i = 1, #lumOrder do tot = tot + w(lumCat[lumOrder[i]]) end
            local r2 = rng:random() * tot
            for i = 1, #lumOrder do
                local kind = lumOrder[i]
                r2 = r2 - w(lumCat[kind])
                if r2 <= 0 then p.kind = kind; break end
            end
            WorldRoad._nextLumZ[p.side] = z + LUM_STEP + rng:random() * LUM_JIT
            if require("src.core.Release").isDev() and os.getenv("GF_DEBUG") then
                require("src.core.Debug").log(string.format("[lum] FIRE side=%+d z=%.1f rel=%.1f kind=%s next=%.1f",
                    p.side, z, z - (WorldRoad._camZ or 0), p.kind,
                    WorldRoad._nextLumZ[p.side]))
            end
            local other = -p.side
            local oNext = WorldRoad._nextLumZ[other] or z
            local lo, hi = z + LUM_STEP * 0.45, z + LUM_STEP * 0.65
            if oNext < lo then WorldRoad._nextLumZ[other] = lo
            elseif oNext > hi then WorldRoad._nextLumZ[other] = hi end
        elseif LuminaireEngine.isLuminaire(p.kind) then
            p.kind = TREE_KIND[b.id] or "tree"
        end
    end
    local ldef = LuminaireEngine.def(b.id, p.kind)
    local lane = (ldef and ldef.lane) or KIND_LANE[p.kind] or KIND_LANE.default
    p.lane = lane[1] + rng:random() * (lane[2] - lane[1])
    p.variant = rng:random(0, 2)
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
    WorldRoad._sideBal = 0
    WorldRoad._nextLumZ = nil
    local b = rawBiome()
    local z = 0.5
    while z < REL_CREST + EMERGE_BAND do
        for side = -1, 1, 2 do
            if WorldRoad._rng:random() < 0.9 then
                local p = {}
                rollProp(p, z + WorldRoad._camZ
                    + WorldRoad._rng:random() * 0.5, side)
                table.insert(WorldRoad._props, p)
                resolveOverlap(p)
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
    if opts.encounter and (opts.encounter.img or opts.encounter.anim) then
        local e = opts.encounter
        WorldRoad._encounter = {
            anim = e.anim, img = e.img, iw = e.iw, ih = e.ih,
            targetScale = e.targetScale or 4,
            spriteId = e.spriteId,
            offX = e.offX, footPad = e.footPad,
            framePads = e.framePads, footSink = e.footSink,
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
WorldRoad.ENEMY_SCREEN_GROWTH = 1.4
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
    landmark_miniboss = 3.8,
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
    frost_landmark_rest     = 3,  marsh_landmark_rest = 5,
    dusk_landmark_rest      = 4,
    highlands_landmark_battle = 0, frost_landmark_battle = 0,
    highlands_landmark_elite  = 2, frost_landmark_elite  = 1,
    marsh_landmark_elite      = 5, dusk_landmark_elite  = 0,
    abyss_landmark_elite      = 2, landmark_elite        = 2,
}
local LANDMARK_LIGHT = {
    landmark_rest  = { color = { 1.00, 0.62, 0.28 }, radiusK = 0.55, intensity = 0.55 },
    landmark_elite = { color = { 0.72, 0.38, 1.00 }, radiusK = 0.45, intensity = 0.50 },
    landmark_shop  = { color = { 1.00, 0.72, 0.38 }, radiusK = 0.30, intensity = 0.45 },
    landmark_event = { color = { 0.45, 0.80, 1.00 }, radiusK = 0.30, intensity = 0.45 },
    landmark_miniboss = { color = { 1.00, 0.45, 0.25 }, radiusK = 0.40, intensity = 0.50 },
}
local LANDMARK_SMOKE = {
    landmark_shop = { xf = 0.325, yf = 0.02 },
    highlands_landmark_shop = { xf = 0.233, yf = 0.00 },
    abyss_landmark_shop     = { xf = 0.230, yf = 0.00, color = { 0.72, 0.64, 0.58 } },
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
LMG.tint4 = { 1, 1, 1, 1 }

local function drawLandmarkSmoke(key, px, py, iw, ih, s, alpha)
    local sm = lmCfg(LANDMARK_SMOKE, key)
    if not sm or ih * s < 46 then return end
    local mx = px + (sm.xf - 0.5) * iw * s
    local my = py - ih * s + sm.yf * ih * s
    local rise = ih * s * 0.52
    local cr, cg, cb = 0.80, 0.77, 0.72
    if sm.color then cr, cg, cb = sm.color[1], sm.color[2], sm.color[3] end
    for k = 0, 2 do
        local p = (WorldRoad._time * 0.30 + k * 0.333) % 1
        local a = alpha * 0.40 * math.min(1, p * 5) * (1 - p)
        if a > 0.01 then
            local puffX = mx + math.sin(WorldRoad._time * 0.8 + k * 2.1 + p * 2.6)
                * (0.8 + p * 3.2) * s + p * 2.5 * s
            local puffY = my - p * rise
            local sz = math.max(2, (1.1 + p * 2.8) * s)
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

local function submitLandmarkLight(key, px, py, iw, ih, s, rel, seed, alphaK)
    local L = lmCfg(LANDMARK_LIGHT, key)
    if not L or not LightEngine.submitMicro then return end
    alphaK = alphaK or 1
    if alphaK <= 0.05 then return end
    local anc = LuminaireEngine.anchor("landmark", key, 0,
        "assets/sprites/world/" .. key .. ".png")
    local ax, ay = (anc and anc.ax) or 0.5, (anc and anc.ay) or 0.45
    local fx = px + (ax - 0.5) * iw * s
    local fy = py - ih * s * (1 - ay)
    local time = love.timer.getTime()
    local sd = (seed or 0) % 1000
    local n = love.math.noise(time * 1.4, sd) * 0.75
        + love.math.noise(time * 4.0, sd + 37.2) * 0.25
    local fxT, fyT = love.graphics.transformPoint(fx, fy)
    local fi = 0.86 + 0.14 * n
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

    if #WorldRoad._props == 0 then populate() end

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
        if k >= 1 then
            WorldRoad._travel = nil
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

    for _, p in ipairs(WorldRoad._props) do
        if not p.ghost and p.z - WorldRoad._camZ < -3.5 then
            local wasWall = p.wall
            rollProp(p, WorldRoad._camZ + REL_CREST + EMERGE_BAND * 0.6
                        + WorldRoad._rng:random() * 2, p.side, wasWall)
            if wasWall then makeWall(p) end
            resolveOverlap(p)
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
    if not cel then return end
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

local function sunShadowDir(g, x, w, px)
    local cel = rawBiome().celestial
    local sunX = cel and (x + cel.xr * w) or g.cx
    return math.max(-1, math.min(1, (px - sunX) / (w * 0.5)))
end

local function ridge(seed, i)
    return math.sin(i * 0.7 + seed) * 0.5 + math.sin(i * 0.23 + seed * 2.3) * 0.35
         + math.sin(i * 1.7 + seed * 0.7) * 0.15
end

local function stripTransform(g, x, w, camZ, iw, ih)
    local sx = math.max(w / iw, (g.crestApexY - g.y + 70) / ih)
    local yTop = math.floor(g.crestApexY - ih * sx + math.min(70, ih * sx * 0.22))
    local tileW = iw * sx
    local off = (camZ * 2.5 * sx) % (tileW * 2)
    return sx, yTop, tileW, off
end

local function drawStripTiles(img, x, sx, yTop, tileW, off)
    for k = -1, 2 do
        local tx = x - off + k * tileW
        if (k % 2 == 0) then
            love.graphics.draw(img, math.floor(tx), yTop, 0, sx, sx)
        else
            love.graphics.draw(img, math.floor(tx + tileW), yTop, 0, -sx, sx)
        end
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
            local tx = x - off + k * tileW
            local dx = (k % 2 == 0) and math.floor(tx) or math.floor(tx + tileW)
            local sxx = (k % 2 == 0) and sx or -sx
            if flipped then
                love.graphics.draw(img, dx, yb + stripH, 0, sxx, -sx)
            else
                love.graphics.draw(img, dx, yb, 0, sxx, sx)
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
        local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)
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
    local sx, yTop, tileW, off = stripTransform(g, x, w, camZ, iw, ih)
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
    fields = 3.2, highlands = 3.2, abyss = 3.4,
    frost = 2.6, marsh = 3.2, dusk = 3.0,
}
local CASTLE_SINK_EXTRA = {
    fields = 0.06, frost = 0.07, marsh = 0.06, dusk = 0.06,
}
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
    local refW = math.min(w, g.h * 1.5)
    local baseScale = (refW * 0.155) / 218
    local growth = CASTLE_APPROACH[bid] or 3.2
    local s = baseScale * (1.0 + (progress ^ 1.4) * growth)
    local cx = g.cx
    local sinkExtra = (CASTLE_SINK_EXTRA[bid] or 0) * progress
    local baseY = g.crestYAt(cx)
        + ih * s * (0.03 + 0.20 * (1 - progress) + sinkExtra)
    if alpha >= 1 then
        local ra = envColor("roadA")
        local crest2 = g.crestYAt(cx)
        love.graphics.setColor(ra[1] * 0.92, ra[2] * 0.92, ra[3] * 0.92, 0.85)
        love.graphics.ellipse("fill", cx, crest2 + 2,
            iw * s * 0.34, 5 + 9 * progress)
        local shd = sunShadowDir(g, x, w, cx)
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.ellipse("fill", cx + shd * iw * s * 0.20
            + (shd == 0 and iw * s * 0.10 or 0), crest2 + 3,
            iw * s * 0.28, 4 + 7 * progress)
    end

    local cc = Scene.Grade.color("castle", 0.6 + 0.4 * progress, LMG.c)
    love.graphics.setColor(cc[1], cc[2], cc[3], alpha)
    love.graphics.draw(img, math.floor(cx - iw * s / 2),
        math.floor(baseY - ih * s), 0, s, s)

    if alpha >= 1 then
        WorldRoad._castleTop = {
            x = cx + iw * s * 0.18,
            y = baseY - ih * s * 0.82,
            s = s,
            progress = progress,
        }
        WorldRoad._castleBaseHalf = iw * s * 0.44
        GrassField.requireTufts(REL_CREST - 0.1, cx, iw * s * 0.9, 6,
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

local function drawCastle(g, x, w, camZ)
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
    if WorldRoad._fork then return end
    for _, p in ipairs(WorldRoad._props) do
        local rel = p.z - camZ
        local fadeA = propFadeK(p)
        if fadeA > 0.01 and rel > REL_CREST and rel <= REL_CREST + EMERGE_BAND then
            local em = 1 - (rel - REL_CREST) / EMERGE_BAND
            local pxX = g.cx + p.side * w * (0.11 + p.lane * 0.38)
            local edef = LuminaireEngine.def(p.bid, p.kind)
            if edef and edef.roadside then
                pxX = g.cx + p.side * (ROAD_HALF * w * 0.30)
                    * (1.05 + p.lane * 1.2)
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
                    * (PropCut.sizeK[img] or 1)
                local s = g.scaleAt(size, 0, ih)
                local px2 = pxX - (lumAnc.offX or 0) * s * lumFlip
                local sink = (1 - em) * ih * s
                local baseY = crest + sink
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
                    * (PropCut.sizeK[img] or 1)
                local s = g.scaleAt(size, 0, ih)
                local _, ihv = PropCut.get(img, p.kind)
                local sink = (1 - em) * ihv * s
                if p.cluster then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cimg = getSprite(p.kind, (p.variant + ci) % 3, p.bid)
                        if cimg then
                            local cs = s * (0.5 + 0.13 * ci)
                            local ccrest = g.crestYAt(pxX + off) or crest
                            local _, cihv = PropCut.get(cimg, p.kind)
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                            love.graphics.setColor(cc[1] * 0.6, cc[2] * 0.6, cc[3] * 0.6, fadeA)
                            PropCut.draw(cimg, p.kind, math.floor(pxX + off),
                                math.floor(ccrest + (1 - em) * cihv * cs), 0, cs, cs)
                        end
                    end
                end
                local cb = Scene.Grade.color(Scene.Grade.familyOf(p.kind), 0, LMG.c)
                love.graphics.setColor(cb[1] * 0.66, cb[2] * 0.66, cb[3] * 0.66, fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX),
                    math.floor(crest + sink), 0, s, s)
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
    local c = Scene.Grade.color("ground", 0.5, LMG.c)
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    ds.qm:draw(0, ds.count, tex.img)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDome(g, x, y, w)
    local grassA = envColor("grassA")
    local grassB = envColor("grassB")
    local gc = Scene.Grade.color("ground", 0.5, LMG.c)
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
    local gc = Scene.Grade.color("ground", 0.5, LMG.c)
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
    return true
end

function WorldRoad.isForkActive()
    return WorldRoad._fork ~= nil
end

local function forkOffset(f, i, rel, w)
    local k = (rel - FORK_REL) / (MARK_REL - FORK_REL)
    k = math.min(1, math.max(0, k))
    k = k * k * (3 - 2 * k)
    local off = f.dirs[i] * FORK_SPREAD * w * k * f.animIn
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
        local gc = Scene.Grade.color("grass", 0.5, LMG.c)
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
                return ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
            end,
            roadCenters = function(z, t)
                local f = WorldRoad._fork
                if not f then return nil end
                local rel = z - WorldRoad._camZ
                if rel <= FORK_REL - 1.5 then return nil end
                local wob = roadWobble(z, t, w) * 0.5
                local cs, ws = _grassFork.cs, _grassFork.ws
                for i = 1, f.n do
                    cs[i] = g.cx + forkOffset(f, i, rel, w) + wob
                    ws[i] = forkAlpha(f, i)
                end
                for i = f.n + 1, #cs do cs[i] = nil; ws[i] = nil end
                return cs, (f.n > 1 and 0.78 or 1), ws
            end,
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
        }
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

local function drawRoad(g, x, w, camZ)
    local roadA = envColor("roadA")
    local roadB = envColor("roadB")
    local roadEdge = envColor("roadEdge")
    local cx = g.cx
    local crest = g.crestYAt(cx)
    local groundH = g.bottomY - crest
    local fork = WorldRoad._fork

    local step = 2
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
    local t, rel, worldZ, half0, edgeAmp, eL, eR, rowId, blend, m
    local newRow
    local biomeNow = rawBiome()
    local tile = RoadSurface.get(biomeNow.id, biomeNow)
        or getRoadTile(biomeNow.id)
    local tw, th, dv, v, hs
    if tile then tw, th = tile:getWidth(), tile:getHeight() end

    local function paintRow(cxRow, halfMul, aMul, decorate, bright)
        local half = half0 * halfMul
        local jag = 14 * (0.35 + 0.65 * t)
        local jL = (hash(rowId * 13 + 7) - 0.5) * jag
        local jR = (hash(rowId * 19 + 3) - 0.5) * jag
        local xL = math.floor(cxRow - half + eL + jL)
        local xR = math.floor(cxRow + half + eR + jR)

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

        if t > 0.45 then
            local rutA = (t - 0.45) * 0.5
            local rutW = math.max(1, math.floor(2 * g.persp(t)))
            local rdx = half * 0.42
            local ra = rutA * 0.5 * aMul
            rect(math.floor(cxRow - rdx),
                math.floor(g.latY(cxRow - rdx - cx, t)), rutW, step,
                roadEdge[1], roadEdge[2], roadEdge[3], ra)
            rect(math.floor(cxRow + rdx),
                math.floor(g.latY(cxRow + rdx - cx, t)), rutW, step,
                roadEdge[1], roadEdge[2], roadEdge[3], ra)
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

        half0 = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
        edgeAmp = 5 * (0.30 + 0.70 * t)
        eL = (math.sin(worldZ * 0.55) * 0.6 + math.sin(worldZ * 0.21 + 1.4) * 0.4) * edgeAmp
        eR = (math.sin(worldZ * 0.47 + 3.1) * 0.6 + math.sin(worldZ * 0.17 + 4.2) * 0.4) * edgeAmp
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
            local kk = (rel - FORK_REL) / (MARK_REL - FORK_REL)
            kk = math.min(1, math.max(0, kk))
            kk = kk * kk * (3 - 2 * kk)
            local hm = (fork.n > 1) and (1 - 0.22 * kk) or 1
            for i = 1, fork.n do
                local aMul = forkAlpha(fork, i)
                if aMul > 0.02 then
                    local bright = (fork.hover == i and not fork.converge) and 1.14 or 1
                    paintRow(cx + wob * 0.5 + forkOffset(fork, i, rel, w),
                        hm, aMul, i == 1, bright)
                end
            end
        else
            paintRow(cx + wob, 1, 1, true, 1)
        end
    end
    if qm.n > 0 then
        qm:upload(0, qm.n)
        local prevShader = love.graphics.getShader()
        love.graphics.setShader(QuadMesh.untexturedShader())
        local rc = Scene.Grade.color("road", 0.5, LMG.c)
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
                if tL and tL >= 0 then
                    lmMark = WorldRoad._lmMark or {}
                    WorldRoad._lmMark = lmMark
                    lmMark.rel, lmMark.t, lmMark.lm, lmMark.drawn = relL, tL, lm, false
                end
            end
        end
    end
    local function drawChosenLandmark()
        local lm, rel, t = lmMark.lm, lmMark.rel, lmMark.t
        local img = getLandmark(lm.key)
        if not img then return end
        img = landmarkFrame(lm.key, lm.phase or lm.z) or img
        local iw, ih = img:getWidth(), img:getHeight()
        local s = g.scaleAt(lm.size or 2.0, t, LMG.refH(lm.key, ih))
        local py = g.latY(0, t)
        local lx = g.cx + roadWobble(lm.z, t, w)
        local shPad = lmCfg(LANDMARK_SHADOW_PAD, lm.key) or 0
        local shY = py - 1 - shPad * s
        if not ShadowEngine.sprite(img, lx, shY, s,
            shadowOpts(nil, nil, shPad, lmCfg(WorldRoad.SHADOW_PROFILE, lm.key))) then
            love.graphics.setColor(0, 0, 0, 0.22)
            love.graphics.ellipse("fill",
                lx + sunShadowDir(g, x, w, lx) * iw * s * 0.14,
                shY, iw * s * 0.30, math.max(2, 4 * g.persp(t)))
            love.graphics.setColor(1, 1, 1, 1)
        end
        local lmk = Scene.Grade.cfg("landmarks")[lm.key:match("landmark_(%a+)$") or ""]
        if lmk and lmk.scorch then
            Scene.Contact.scorch(lx, shY, iw * s, t, lmk.scorch.radius, lmk.scorch.alpha)
        end
        Scene.Contact.queue(img, lx, shY, s, t, 1, 1)
        local lc = Scene.Grade.color("landmark", t, LMG.c)
        love.graphics.setColor(lc[1], lc[2], lc[3], 1)
        love.graphics.draw(img, math.floor(lx - iw * s / 2), math.floor(py - ih * s), 0, s, s)
        love.graphics.setColor(1, 1, 1, 1)
        drawLandmarkSmoke(lm.key, lx, py, iw, ih, s, 1)
        submitLandmarkLight(lm.key, lx, py, iw, ih, s, rel, lm.z)
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
                local offX = forkOffset(f, i, relM, w)
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
                local shPad = lmCfg(LANDMARK_SHADOW_PAD, key) or 0
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
                love.graphics.draw(img, math.floor(px - iw * s / 2),
                    math.floor(py - ih * s), 0, s, s)
                drawLandmarkSmoke(key, px, py, iw, ih, s, aMul)
                submitLandmarkLight(key, px, py, iw, ih, s, relM,
                    i * 31.7, aMul * (hovered and 1.4 or 1))
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
            flushGrassTo(rel)
            local over = math.max(0, -rel)
            local inner = 0.11 + 0.38 * t + over * 0.09
            local lateral = p.side * w * (inner + p.lane * 0.38)
            local rdef = LuminaireEngine.def(p.bid, p.kind)
            if rdef and rdef.roadside then
                local halfR = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
                lateral = p.side * (halfR * (1.05 + p.lane * 1.2)
                    + over * w * 0.09)
            end
            local pxX = g.cx + lateral
            local sy = g.latY(pxX - g.cx, t) + over * g.h * 0.13

            local img = getSprite(p.kind, p.variant, p.bid)
            local fadeA = propFadeK(p)
            if fadeA <= 0.01 then img = nil end

            if img and WorldRoad._fork and rdef and rdef.roadside
               and rel < FORK_REL + 2 then
                img = nil
            end
            if img and WorldRoad._fork and rel > FORK_REL - 1.5 then
                local f2 = WorldRoad._fork
                local halfCorr = ROAD_HALF * w * (0.30 + 0.70 * (t ^ 1.15))
                    * (f2.n > 1 and 0.78 or 1)
                for bi = 1, f2.n do
                    local bc = g.cx + forkOffset(f2, bi, rel, w)
                    if math.abs(pxX - bc) < halfCorr + w * 0.045 then
                        img = nil
                        break
                    end
                end
            end

            if img then
                local iw, ih = img:getWidth(), img:getHeight()
                local size = kindSize(p.kind, p.bid) * (p.big or 1)
                    * (PropCut.sizeK[img] or 1)
                local s = g.scaleAt(size, t, ih)

                local lumDef = LuminaireEngine.def(p.bid, p.kind)
                local lumAnc, lumSink, lumFlip = nil, 0, 1
                if lumDef then
                    lumAnc = LuminaireEngine.anchor(p.bid, p.kind, p.variant,
                        luminairePath(p.bid, p.kind, p.variant))
                    if lumDef.face and lumDef.face ~= 0 then
                        local want = p.side < 0 and 1 or -1
                        lumFlip = (want == lumDef.face) and 1 or -1
                    end
                    pxX = pxX - (lumAnc.offX or 0) * s * lumFlip
                    lumSink = (lumAnc.footPad or 0) * s
                    local fr = luminaireFrames(p.bid, p.kind, p.variant)
                    if fr then
                        local ph = (p.z * 7.31) % #fr
                        img = fr[1 + math.floor(
                            (WorldRoad._time * 10 + ph) % #fr)]
                        iw, ih = img:getWidth(), img:getHeight()
                    end
                end

                local _, ihv = PropCut.get(img, p.kind)

                if p.cluster and (p.kind == "tree" or p.kind == "pine"
                                  or p.kind == "deadtree" or p.kind == "bush") then
                    for ci = 1, p.cluster do
                        local off = p.side
                            * (0.85 * ci + math.abs(p.jitter) * 0.45) * iw * s
                            + p.jitter * 10
                        local cx2 = pxX + off
                        local cy2 = g.latY(cx2 - g.cx, t)
                        local cs = s * (0.5 + 0.13 * ci)
                        local cvar = (p.variant + ci) % 3
                        local cimg = getSprite(p.kind, cvar, p.bid)
                        if cimg then
                            ShadowEngine.queue(cimg, cx2, cy2 - 1, cs,
                                shadowOpts(0.8 * fadeA, nil,
                                    PropCut.cutOf(cimg, p.kind),
                                    WorldRoad.SHADOW_PROFILE[p.kind]))
                            Scene.Contact.queue(cimg, cx2, cy2, cs, t, 0.8 * fadeA, 1)
                            local cc = Scene.Grade.color(Scene.Grade.familyOf(p.kind), t, LMG.c)
                            love.graphics.setColor(cc[1] * 0.88, cc[2] * 0.88, cc[3] * 0.88, fadeA)
                            PropCut.draw(cimg, p.kind, math.floor(cx2),
                                math.floor(cy2), 0, cs, cs)
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
                                shadowOpts(0.85 * fadeA))
                            Scene.Contact.queue(img, fx, fy, fs, ft, 0.85 * fadeA, 1)
                            local fc = Scene.Grade.color("prop", ft, LMG.c)
                            love.graphics.setColor(fc[1] * 0.94, fc[2] * 0.94, fc[3] * 0.94, fadeA)
                            love.graphics.draw(img, math.floor(fx), math.floor(fy),
                                0, fs, fs, iw / 2, ih)
                        end
                    end
                end

                local aFade = math.min(1, 0.72 + t * 1.1)
                if not ShadowEngine.queue(img, pxX, sy - 1, s,
                    shadowOpts(aFade * fadeA, lumFlip,
                        lumAnc and lumAnc.footPad or PropCut.cutOf(img, p.kind),
                        WorldRoad.SHADOW_PROFILE[p.kind])) then
                    local shd = sunShadowDir(g, x, w, pxX)
                    love.graphics.setColor(0, 0, 0, 0.20 * aFade * fadeA)
                    love.graphics.ellipse("fill",
                        pxX + shd * iw * s * 0.16, sy - 1,
                        iw * s * 0.24, math.max(2, 4 * g.persp(t)))
                end
                if p.kind ~= "tuft" and p.kind ~= "flowers" then
                    Scene.Contact.queue(img, pxX, sy, s, t, fadeA, lumFlip)
                end

                local rot = 0
                local gustKx = 0
                local sink2 = lumSink
                if p.kind == "tree" or p.kind == "pine"
                   or p.kind == "deadtree" or p.kind == "bush" then
                    rot = math.sin(WorldRoad._time * 1.15 + p.z * 0.7) * 0.018
                    local wP = GrassField.PRESETS[p.bid or rawBiome().id]
                    if wP and not (_G.gameSettings and _G.gameSettings.reducedMotion) then
                        local gw = GrassField.windAt((pxX - x) / w, p.z,
                            WorldRoad._time, wP, 0)
                        local stiff = (p.kind == "bush") and 0.030
                            or (p.kind == "deadtree" and 0.014 or 0.022)
                        gustKx = -gw * stiff
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
                elseif p.kind == "tuft" or p.kind == "flowers" then
                    rot = math.sin(WorldRoad._time * 2.3 + p.z * 1.4) * 0.055
                end
                rot = rot + pokeRot(p)

                local pc = Scene.Grade.color(Scene.Grade.familyOf(p.kind, lumDef ~= nil), t, LMG.c)
                love.graphics.setColor(pc[1], pc[2], pc[3], fadeA)
                PropCut.draw(img, p.kind, math.floor(pxX), math.floor(sy + sink2),
                    rot, s * lumFlip, s, gustKx * lumFlip)
                if p.kind ~= "tuft" and p.kind ~= "flowers" and p.kind ~= "fence"
                   and fadeA >= 0.5 then
                    local oc2 = Scene.Grade.cfg("occlusion")
                    local isTree = (p.kind == "tree" or p.kind == "pine"
                        or p.kind == "deadtree" or p.kind == "bush")
                    local hsh = (p.z * 7.31) % 1
                    local nT = isTree and (1 + math.floor(hsh * 2))
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
                        local flip = lumFlip or 1
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
                    he.ref, he.kind = p, p.kind
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
                    oc.sx, oc.sy, oc.ox, oc.oy = s, s, iw / 2, ihv
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
    drawList(farPass)
    local enemyFn = WorldRoad._enemyDraw
    if enemyFn then
        local et = g.tOf(WorldRoad.BATTLE_REL)
        local baseY = (et and g.latY(0, et)) or WorldRoad._enemyBaseY or 1e9
        local behind, front = WorldRoad._lists.behind, WorldRoad._lists.front
        clearList(behind)
        clearList(front)
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
    flushGrassTo(-1)
    ShadowEngine.flush()
    Scene.Contact.flush()
end

local function drawEncounterFront(g, x, w, camZ)
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
    local dx0 = math.floor(cx - e.iw * s / 2)
    local dy0 = sy - e.ih * s + footY
    if e.anim then
        ShadowEngine.silhouette(cx, sy - 1, { smear = e.iw * s * 0.035,
                baseK = e.shadowBaseK, riseK = e.shadowRiseK,
                contentH = (e.contentH or (e.ih - pad)) * s },
            function(tint)
                e.anim:draw(-(e.iw * s) / 2, -(e.ih * s) + footY, s, tint)
            end)
    else
        ShadowEngine.sprite(e.img, cx, sy - 1, s,
            { alphaK = 0.9, footPad = e.footPad,
              baseK = e.shadowBaseK, riseK = e.shadowRiseK })
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
        local cel = rawBiome().celestial
        local sunX = cel and (x + cel.xr * w) or g.cx
        ShadowEngine.setFrame(sunX, w, WorldRoad._timeOfDay,
            LightEngine.ambientLuma())
    end
    Scene.Contact.setFrame(Scene.Grade.cfg("contact"), Scene.Grade.shadowTint())

    local gb0 = envColor("grassB")
    local g0 = Scene.Grade.color("ground", 0.5, LMG.c)
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

    WeatherEngine.beginFrame({ geom = g, x = x, w = w, camZ = WorldRoad._camZ,
        relCrest = REL_CREST, tPow = T_POW })
    GrassField.beginFrame()

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

    drawEncounterFront(g, x, w, WorldRoad._camZ)

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
    WorldRoad._landmark = nil
    WorldRoad._enemyDraw = nil
    WorldRoad._enemyBaseY = nil
    WorldRoad._nextLumZ = nil
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
        for v = 0, 2 do getSprite(kind, v, bid); y() end
    end
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
