-- src/ui/IconFramesLoader.lua
-- Carrega frames animados de ícones gerados via PixelLab (animate_object v3).
-- Estrutura: assets/sprites/icons_anim/<name>/frame_NNN.png
--            assets/sprites/icons_anim/<name>/meta.lua (opcional: return { fps = N })
-- Pipeline de geração: tools/pixellab_animate_card_icons.py (queue/poll).
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
    -- fps default 8 (loop de 9 frames ≈ 1.1s — idle vivo mas não frenético).
    -- Override por animação via meta.lua no diretório dos frames.
    local fps = 8
    local metaPath = "assets/sprites/icons_anim/" .. name .. "/meta.lua"
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
    cache[name] = handle
    return handle
end

-- v10.6 (perf): SÓ o primeiro frame (frame_000) — barato o suficiente pro
-- render ESTÁTICO da carta na instanciação (idle = frame 0, regra do dono).
-- O set completo (get) fica pra quando a animação é realmente pedida
-- (primeiro hover/inspeção). Sem isso, abrir a Coleção carregava ~9 PNGs
-- e compunha a carta inteira ~9x pra CADA uma das 116 cartas = travada.
local firstCache = {}
function IconFramesLoader.first(name)
    if cache[name] then return cache[name].frames[1] end   -- set completo já em memória
    if firstCache[name] ~= nil then return firstCache[name] or nil end
    if missCache[name] then return nil end
    local dir = "assets/sprites/icons_anim/" .. name
    if not love.filesystem.getInfo(dir, "directory") then
        missCache[name] = true
        return nil
    end
    -- primeiro frame_NNN em ordem (quase sempre frame_000.png)
    local items = love.filesystem.getDirectoryItems(dir)
    table.sort(items)
    for _, f in ipairs(items) do
        if f:match("^frame_%d+%.png$") then
            local ok, img = pcall(love.graphics.newImage, dir .. "/" .. f)
            if ok and img then
                img:setFilter("nearest", "nearest")
                firstCache[name] = img
                return img
            end
            break
        end
    end
    missCache[name] = true
    firstCache[name] = false
    return nil
end

function IconFramesLoader.has(name)
    return IconFramesLoader.get(name) ~= nil
end

function IconFramesLoader.clearCache()
    cache = {}
    missCache = {}
    firstCache = {}
end

return IconFramesLoader
