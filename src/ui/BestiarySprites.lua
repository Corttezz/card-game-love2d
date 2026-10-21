local Debug = require("src.core.Debug")

local BestiarySprites = {}

BestiarySprites.BUDGET_SECS = 0.0025
BestiarySprites.MAX_PER_FRAME = 6
BestiarySprites.clock = love.timer.getTime

local sets = {}
local wantNow, wantNowSet = {}, {}
local background = {}

local function reduced()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) == true
end

local function idleDir(id)
    return "assets/sprites/characters/enemies/" .. id .. "/animations/idle/south"
end

local function listFrames(id)
    local dir = idleDir(id)
    local info = love.filesystem.getInfo(dir)
    local files = {}
    if info and info.type == "directory" then
        for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
            if f:match("^%d+%.png$") then files[#files + 1] = dir .. "/" .. f end
        end
        table.sort(files, function(a, b)
            return tonumber(a:match("(%d+)%.png$")) < tonumber(b:match("(%d+)%.png$"))
        end)
    end
    if #files == 0 then
        local still = "assets/sprites/characters/enemies/" .. id .. "/south.png"
        if love.filesystem.getInfo(still) then files[1] = still end
    end
    return files
end

local function alphaBox(data)
    local w, h = data:getDimensions()
    local okF, ffi = pcall(require, "ffi")
    local ptr
    if okF and data.getFFIPointer and data:getFormat() == "rgba8" then
        local okP, p = pcall(data.getFFIPointer, data)
        if okP and p then ptr = ffi.cast("uint8_t*", p) end
    end
    local x0, y0, x1, y1 = w, h, -1, -1
    for y = 0, h - 1 do
        local row = y * w
        for x = 0, w - 1 do
            local a
            if ptr then a = ptr[(row + x) * 4 + 3] else
                local _, _, _, fa = data:getPixel(x, y)
                a = fa * 255
            end
            if a > 16 then
                if x < x0 then x0 = x end
                if x > x1 then x1 = x end
                if y < y0 then y0 = y end
                if y > y1 then y1 = y end
            end
        end
    end
    if x1 < 0 then return { x = 0, y = 0, w = w, h = h } end
    return { x = x0, y = y0, w = x1 - x0 + 1, h = y1 - y0 + 1 }
end

local function ensureSet(id)
    local s = sets[id]
    if s then return s end
    s = { id = id, files = listFrames(id), frames = {}, loaded = 0 }
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local okSpec, fps, opts = pcall(EnemyRenderer._idleSpec, id)
    s.fps = (okSpec and fps) or 6
    s.pingpong = okSpec and opts and opts.pingpong or false
    if #s.files == 0 then
        s.missing = true
        Debug.warn("[BestiarySprites] sem sprite de idle para " .. tostring(id))
    end
    sets[id] = s
    return s
end

local function loadOne(s)
    local i = s.loaded + 1
    local path = s.files[i]
    if not path then return false end
    s.loaded = i
    if i == 1 then
        local okD, data = pcall(love.image.newImageData, path)
        if not okD then
            Debug.warn("[BestiarySprites] falha ao ler " .. path)
            s.missing = true
            return true
        end
        s.box = alphaBox(data)
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        s.frames[1] = img
        s.fw, s.fh = img:getDimensions()
    else
        local okI, img = pcall(love.graphics.newImage, path)
        if okI and img then
            img:setFilter("nearest", "nearest")
            s.frames[i] = img
        else
            Debug.warn("[BestiarySprites] falha ao ler " .. path)
            s.files[i] = nil
        end
    end
    return true
end

local function needs(s, all)
    if s.missing then return false end
    if s.loaded == 0 then return true end
    return all and s.loaded < #s.files
end

function BestiarySprites.want(id, all)
    if reduced() then all = false end
    local s = ensureSet(id)
    if not needs(s, all) then return end
    local key = id .. (all and "+" or "")
    if wantNowSet[key] then return end
    wantNowSet[key] = true
    wantNow[#wantNow + 1] = { s = s, all = all }
end

function BestiarySprites.prefetch(id, all)
    background[#background + 1] = { id = id, all = all }
end

function BestiarySprites.pump(budget)
    budget = budget or BestiarySprites.BUDGET_SECS
    local t0 = BestiarySprites.clock()
    local n = 0
    local function spent()
        local dt = BestiarySprites.clock() - t0
        return n >= BestiarySprites.MAX_PER_FRAME or (dt >= 0 and dt >= budget)
    end
    for pass = 1, 2 do
        for _, w in ipairs(wantNow) do
            local all = pass == 2 and w.all
            while needs(w.s, all) and not spent() do
                if not loadOne(w.s) then break end
                n = n + 1
            end
            if spent() then break end
        end
        if spent() then break end
    end
    wantNow, wantNowSet = {}, {}
    local i = 1
    while i <= #background and not spent() do
        local b = background[i]
        local s = ensureSet(b.id)
        local all = b.all and not reduced()
        if needs(s, all) then
            loadOne(s)
            n = n + 1
        else
            i = i + 1
        end
    end
    for _ = 1, i - 1 do table.remove(background, 1) end
    return n
end

function BestiarySprites.pendingCount()
    return #background
end

function BestiarySprites.get(id)
    return ensureSet(id)
end

function BestiarySprites.frameAt(id, t)
    local s = ensureSet(id)
    local first = s.frames[1]
    if not first then return nil, s end
    if reduced() or s.loaded < #s.files then return first, s, 1 end
    local n = #s.files
    if n <= 1 then return first, s, 1 end
    local step = math.floor((t or 0) * s.fps)
    local idx
    if s.pingpong then
        local period = 2 * (n - 1)
        local k = step % period
        idx = (k < n) and (k + 1) or (period - k + 1)
    else
        idx = (step % n) + 1
    end
    return s.frames[idx] or first, s, idx
end

function BestiarySprites.isReady(id, all)
    local s = ensureSet(id)
    if s.missing then return true end
    if all and not reduced() then return s.loaded >= #s.files end
    return s.loaded >= 1
end

function BestiarySprites._reset()
    for _, s in pairs(sets) do
        for _, img in pairs(s.frames) do if img.release then img:release() end end
    end
    sets, wantNow, wantNowSet, background = {}, {}, {}, {}
end

return BestiarySprites
