local Debug = require("src.core.Debug")

local IconFramesLoader = {}

local DEFAULT_ROOT = "assets/sprites/icons_anim"

local cache = {}
local missCache = {}

local function keyOf(root, name)
    return root .. "/" .. tostring(name)
end

local function loadFrames(root, name)
    local dir = root .. "/" .. name
    if not love.filesystem.getInfo(dir, "directory") then return nil end
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    local frames = {}
    for _, f in ipairs(items) do
        if f:match("^frame_%d+%.png$") then
            local ok, img = pcall(love.graphics.newImage, dir .. "/" .. f)
            if ok and img then
                img:setFilter("nearest", "nearest")
                frames[#frames + 1] = img
            end
        end
    end
    return frames
end

local Handle = {}
Handle.__index = Handle

function Handle:frameAt(t)
    if #self.frames == 0 then return nil end
    local idx = math.floor((t or 0) * self.fps) % #self.frames + 1
    return self.frames[idx]
end

function IconFramesLoader.getFrom(root, name)
    root = root or DEFAULT_ROOT
    local key = keyOf(root, name)
    if cache[key] then return cache[key] end
    if missCache[key] then return nil end
    local frames = loadFrames(root, name)
    if not frames or #frames == 0 then
        missCache[key] = true
        return nil
    end
    local fps = 8
    local metaPath = root .. "/" .. name .. "/meta.lua"
    if love.filesystem.getInfo(metaPath) then
        local ok, chunk = pcall(love.filesystem.load, metaPath)
        if ok and chunk then
            local okM, meta = pcall(chunk)
            if okM and type(meta) == "table" and tonumber(meta.fps) then
                fps = tonumber(meta.fps)
            end
        end
    end
    local handle = setmetatable({
        frames = frames,
        fps = fps,
        size = { w = frames[1]:getWidth(), h = frames[1]:getHeight() },
    }, Handle)
    cache[key] = handle
    return handle
end

function IconFramesLoader.get(name)
    return IconFramesLoader.getFrom(DEFAULT_ROOT, name)
end

local firstCache = {}
function IconFramesLoader.firstFrom(root, name)
    root = root or DEFAULT_ROOT
    local key = keyOf(root, name)
    if cache[key] then return cache[key].frames[1] end
    if firstCache[key] ~= nil then return firstCache[key] or nil end
    if missCache[key] then return nil end
    local dir = root .. "/" .. name
    if not love.filesystem.getInfo(dir, "directory") then
        missCache[key] = true
        return nil
    end
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    for _, f in ipairs(items) do
        if f:match("^frame_%d+%.png$") then
            local ok, img = pcall(love.graphics.newImage, dir .. "/" .. f)
            if ok and img then
                img:setFilter("nearest", "nearest")
                firstCache[key] = img
                return img
            end
            break
        end
    end
    missCache[key] = true
    firstCache[key] = false
    return nil
end

function IconFramesLoader.first(name)
    return IconFramesLoader.firstFrom(DEFAULT_ROOT, name)
end

function IconFramesLoader.has(name)
    local key = keyOf(DEFAULT_ROOT, name)
    if cache[key] then return true end
    return IconFramesLoader.firstFrom(DEFAULT_ROOT, name) ~= nil
end

local pending = {}
function IconFramesLoader.getIncremental(name, perCall)
    local key = keyOf(DEFAULT_ROOT, name)
    if cache[key] then return cache[key] end
    if missCache[key] then return nil end
    perCall = perCall or 2
    local p = pending[key]
    if not p then
        local dir = DEFAULT_ROOT .. "/" .. name
        if not love.filesystem.getInfo(dir, "directory") then
            missCache[key] = true
            return nil
        end
        local items = love.filesystem.getDirectoryItems(dir)
        table.sort(items)
        local files = {}
        for _, f in ipairs(items) do
            if f:match("^frame_%d+%.png$") then files[#files + 1] = dir .. "/" .. f end
        end
        p = { files = files, frames = {}, i = 0 }
        pending[key] = p
    end
    local n = 0
    while p.i < #p.files and n < perCall do
        p.i = p.i + 1
        n = n + 1
        local ok, img = pcall(love.graphics.newImage, p.files[p.i])
        if ok and img then
            img:setFilter("nearest", "nearest")
            p.frames[#p.frames + 1] = img
        else
            Debug.warn("[IconFramesLoader] falha carregando " .. tostring(p.files[p.i]))
        end
    end
    if p.i < #p.files then return nil end
    pending[key] = nil
    if #p.frames == 0 then missCache[key] = true; return nil end
    local fps = 8
    local metaPath = DEFAULT_ROOT .. "/" .. name .. "/meta.lua"
    if love.filesystem.getInfo(metaPath) then
        local ok, chunk = pcall(love.filesystem.load, metaPath)
        if ok and chunk then
            local okM, meta = pcall(chunk)
            if okM and type(meta) == "table" and tonumber(meta.fps) then
                fps = tonumber(meta.fps)
            end
        end
    end
    local handle = setmetatable({
        frames = p.frames, fps = fps,
        size = { w = p.frames[1]:getWidth(), h = p.frames[1]:getHeight() },
    }, Handle)
    cache[key] = handle
    return handle
end

function IconFramesLoader.clearCache()
    cache = {}
    missCache = {}
    firstCache = {}
    pending = {}
end

return IconFramesLoader
