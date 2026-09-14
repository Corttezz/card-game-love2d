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

-- Raiz padrao (icones de carta). Outros consumidores passam a sua -- o
-- voucher da loja usa "assets/sprites/vouchers_anim". Mesmo CONTRATO de
-- pasta (frame_NNN.png + meta.lua opcional), mesma logica de cache e de
-- ausencia: pasta que nao existe devolve nil e quem chama mostra o PNG
-- estatico. Chaves de cache carregam a raiz pra que dois assets de mesmo
-- nome em pastas diferentes nao se confundam.
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
    -- fps default 8 (loop de 9 frames ≈ 1.1s — idle vivo mas não frenético).
    -- Override por animação via meta.lua no diretório dos frames.
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

-- v10.6 (perf): SÓ o primeiro frame (frame_000) — barato o suficiente pro
-- render ESTÁTICO da carta na instanciação (idle = frame 0, regra do dono).
-- O set completo (get) fica pra quando a animação é realmente pedida
-- (primeiro hover/inspeção). Sem isso, abrir a Coleção carregava ~9 PNGs
-- e compunha a carta inteira ~9x pra CADA uma das 116 cartas = travada.
local firstCache = {}
function IconFramesLoader.firstFrom(root, name)
    root = root or DEFAULT_ROOT
    local key = keyOf(root, name)
    if cache[key] then return cache[key].frames[1] end   -- set completo já em memória
    if firstCache[key] ~= nil then return firstCache[key] or nil end
    if missCache[key] then return nil end
    local dir = root .. "/" .. name
    if not love.filesystem.getInfo(dir, "directory") then
        missCache[key] = true
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
    return IconFramesLoader.get(name) ~= nil
end

function IconFramesLoader.clearCache()
    cache = {}
    missCache = {}
    firstCache = {}
end

return IconFramesLoader
