-- src/ui/IconFramesLoader.lua
-- Carrega frames animados de ícones gerados via PixelLab /animate-with-text.
-- Estrutura: assets/sprites/icons_anim/<name>/frame_NNN.png
--
-- Uso:
--   local anim = IconFramesLoader.get("dagger")
--   if anim then local frame = anim:frameAt(t) end

local IconFramesLoader = {}

local cache = {}
local missCache = {}

local function loadFrames(name)
    local dir = "assets/sprites/icons_anim/" .. name
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

function IconFramesLoader.get(name)
    if cache[name] then return cache[name] end
    if missCache[name] then return nil end
    local frames = loadFrames(name)
    if not frames or #frames == 0 then
        missCache[name] = true
        return nil
    end
    local handle = setmetatable({
        frames = frames,
        fps = 2,  -- sutil — 0.5s por frame, cycle completo de 2s
        size = { w = frames[1]:getWidth(), h = frames[1]:getHeight() },
    }, Handle)
    cache[name] = handle
    return handle
end

function IconFramesLoader.has(name)
    return IconFramesLoader.get(name) ~= nil
end

function IconFramesLoader.clearCache()
    cache = {}
    missCache = {}
end

return IconFramesLoader
