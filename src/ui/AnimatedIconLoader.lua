-- src/ui/AnimatedIconLoader.lua
-- Carrega sequência de frames de personagem animado gerado pelo PixelLab.
-- Estrutura esperada:
--   assets/sprites/characters/<name>_dir/animations/<anim-id>/<direction>/frame_NNN.png
-- Pega a direção "south" (default) e todos os frames.
--
-- Uso:
--   local anim = AnimatedIconLoader.get("joker_abyss")   → nil ou { frames, fps, size }
--   local frame = anim:frameAt(t)                         → love.Image (baseado em tempo)

local AnimatedIconLoader = {}

local cache = {}
local missCache = {}

-- Descobre o primeiro animation folder dentro de characters/<name>_dir/animations/
local function findAnimationDir(baseName)
    local animsPath = "assets/sprites/characters/" .. baseName .. "_dir/animations"
    if not love.filesystem.getInfo(animsPath, "directory") then return nil end
    local items = love.filesystem.getDirectoryItems(animsPath)
    for _, item in ipairs(items) do
        local full = animsPath .. "/" .. item .. "/south"
        if love.filesystem.getInfo(full, "directory") then
            return full
        end
    end
    return nil
end

-- Carrega todos os frames disponíveis (frame_000.png, frame_001.png, ...)
local function loadFrames(dir)
    local frames = {}
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
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

local AnimHandle = {}
AnimHandle.__index = AnimHandle

function AnimHandle:frameAt(t)
    if #self.frames == 0 then return nil end
    local idx = math.floor((t or 0) * self.fps) % #self.frames + 1
    return self.frames[idx]
end

-- Retorna handle ou nil se sprite animado não existir
function AnimatedIconLoader.get(name)
    if cache[name] then return cache[name] end
    if missCache[name] then return nil end
    local dir = findAnimationDir(name)
    if not dir then
        missCache[name] = true
        return nil
    end
    local frames = loadFrames(dir)
    if #frames == 0 then
        missCache[name] = true
        return nil
    end
    local handle = setmetatable({
        frames = frames,
        fps = 6,                        -- breathing-idle = lento
        size = { w = frames[1]:getWidth(), h = frames[1]:getHeight() },
    }, AnimHandle)
    cache[name] = handle
    return handle
end

function AnimatedIconLoader.has(name)
    return AnimatedIconLoader.get(name) ~= nil
end

function AnimatedIconLoader.clearCache()
    cache = {}
    missCache = {}
end

return AnimatedIconLoader
