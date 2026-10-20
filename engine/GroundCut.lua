local ffi = require("ffi")

local GroundCut = {}

GroundCut.CFG = {
    depthK = 0.4, depthMin = 2, depthMax = 5,
    stepMin = 2, stepMax = 3, wobble = 0.35,
    flatDepth = 2, flatRun = 6, alphaMin = 153,
}

GroundCut.FLAT_KINDS = {
    rock = true, stump = true, shrine = true, runestone = true, roots = true,
    drift = true, reeds = true, grass = true, ruin = true, sign = true,
    mushroom = true, crystal = true,
}

function GroundCut.seedOf(name)
    local h = 5381
    for i = 1, #name do h = (h * 33 + name:byte(i)) % 2147483647 end
    return h
end

local function opaqueAt(data, px, w, x, y)
    if px then return px[(y * w + x) * 4 + 3] >= GroundCut.CFG.alphaMin end
    local _, _, _, a = data:getPixel(x, y)
    return a * 255 >= GroundCut.CFG.alphaMin
end

local function ptr(data)
    return data:getFormat() == "rgba8" and ffi.cast("uint8_t*", data:getFFIPointer()) or nil
end

function GroundCut.bottomRow(data)
    local w, h = data:getWidth(), data:getHeight()
    local px = ptr(data)
    for y = h - 1, 0, -1 do
        for x = 0, w - 1 do
            if opaqueAt(data, px, w, x, y) then return y end
        end
    end
    return -1
end

function GroundCut.longestRun(data, row)
    local w = data:getWidth()
    if row < 0 or row >= data:getHeight() then return 0 end
    local px = ptr(data)
    local run, best = 0, 0
    for x = 0, w - 1 do
        if opaqueAt(data, px, w, x, row) then
            run = run + 1
            if run > best then best = run end
        else
            run = 0
        end
    end
    return best
end

function GroundCut.depthFor(cut)
    local c = GroundCut.CFG
    return math.max(c.depthMin, math.min(c.depthMax, math.floor(cut * c.depthK + 0.5)))
end

function GroundCut.profile(w, seed, depth)
    local c = GroundCut.CFG
    local rng = love.math.newRandomGenerator(seed)
    local d = {}
    local wob = rng:random(0, 1)
    for x = 0, w - 1 do
        if rng:random() < c.wobble then wob = 1 - wob end
        d[x] = wob
    end
    local x = rng:random(0, c.stepMin)
    while x < w do
        local hgt = rng:random(math.min(2, depth), depth)
        if hgt > d[x] then d[x] = hgt end
        local l = hgt - 1 - rng:random(0, 1)
        if x > 0 and l > d[x - 1] then d[x - 1] = l end
        local r = hgt - 2
        if x + 1 < w and r > d[x + 1] then d[x + 1] = r end
        x = x + rng:random(c.stepMin, c.stepMax)
    end
    return d
end

function GroundCut.apply(data, cutRow, seed, depth)
    local w, h = data:getWidth(), data:getHeight()
    if cutRow <= 0 or cutRow > h or depth < 1 then return 0 end
    local d = GroundCut.profile(w, seed, depth)
    local px = ptr(data)
    local cleared = 0
    local zone = cutRow - 2 - depth
    local bases = {}
    for x = 0, w - 1 do
        local base = false
        for y = cutRow - 1, math.max(0, zone), -1 do
            if opaqueAt(data, px, w, x, y) then base = y + 1; break end
        end
        bases[x] = base
    end
    local runA, touch = nil, false
    for x = 0, w do
        local b = x < w and bases[x]
        if b and not runA then runA, touch = x, false end
        if b and b == cutRow and d[x] == 0 then touch = true end
        if not b and runA then
            if not touch then
                local best, bx = nil, nil
                for xx = runA, x - 1 do
                    local v = bases[xx]
                    if not best or v > best then best, bx = v, xx end
                end
                d[bx] = 0
            end
            runA = nil
        end
    end
    for x = 0, w - 1 do
        local base = bases[x]
        for k = 1, base and d[x] or 0 do
            local y = base - k
            if y >= 0 then
                if px then
                    local i = (y * w + x) * 4 + 3
                    if px[i] > 0 then px[i] = 0; cleared = cleared + 1 end
                else
                    local r, g, b, a = data:getPixel(x, y)
                    if a > 0 then data:setPixel(x, y, r, g, b, 0); cleared = cleared + 1 end
                end
            end
        end
    end
    return cleared
end

function GroundCut.clearBelow(data, row)
    local w, h = data:getWidth(), data:getHeight()
    local px = ptr(data)
    local cleared = 0
    for y = math.max(0, row), h - 1 do
        for x = 0, w - 1 do
            if px then
                local i = (y * w + x) * 4 + 3
                if px[i] > 0 then px[i] = 0; cleared = cleared + 1 end
            else
                local r, g, b, a = data:getPixel(x, y)
                if a > 0 then data:setPixel(x, y, r, g, b, 0); cleared = cleared + 1 end
            end
        end
    end
    return cleared
end

function GroundCut.prepare(data, name, kind, cut)
    if cut and cut > 0 then
        local h = data:getHeight()
        local n = GroundCut.apply(data, h - cut, GroundCut.seedOf(name), GroundCut.depthFor(cut))
        return n + GroundCut.clearBelow(data, h - cut), h - cut
    end
    if not GroundCut.FLAT_KINDS[kind] then return 0 end
    local bottom = GroundCut.bottomRow(data)
    if bottom < 0 or GroundCut.longestRun(data, bottom) < GroundCut.CFG.flatRun then return 0 end
    return GroundCut.apply(data, bottom + 1, GroundCut.seedOf(name), GroundCut.CFG.flatDepth), bottom + 1
end

return GroundCut
