-- src/ui/SpriteAnimation.lua
-- Animacao frame-by-frame de sprites (gerados via pixellab animate_character).
--
-- Layout esperado em disco:
--   assets/sprites/characters/enemies/<id>/animations/<anim>/<dir>/<frame>.png
-- Ex: .../grave_slime/animations/idle/south/0.png, 1.png, 2.png, ...
--
-- Uso:
--   local anim = SpriteAnimation.new("grave_slime", "idle", "south", 8) -- 8fps
--   anim:update(dt)
--   anim:draw(x, y, scale)
--   anim:play("hurt", { onComplete = function() ... end })  -- troca de animacao
--
-- Fallback: se a pasta da animacao nao existe, retorna nil (caller usa sprite
-- estatico via EnemyRenderer antigo).

local SpriteAnimation = {}
SpriteAnimation.__index = SpriteAnimation

-- Cache global: { enemyId = { anim = { dir = { frames = {img1, img2, ...} } } } }
local cache = {}
local missCache = {}

local function enemyKey(id, anim, dir)
    return tostring(id) .. "|" .. tostring(anim) .. "|" .. tostring(dir)
end

-- Raiz em disco por id. Ids simples ("grave_slime") continuam em enemies/
-- (compat). Ids com categoria ("heroes/warrior") resolvem direto sob
-- characters/ — usado pelos heróis da seleção de classe (Jul/2026).
local function basePath(id)
    if tostring(id):find("/", 1, true) then
        return "assets/sprites/characters/" .. id
    end
    return "assets/sprites/characters/enemies/" .. id
end

-- Carrega todos os PNGs de uma pasta em ordem alfabetica. Retorna {img1, img2, ...} ou nil.
local function loadFrames(enemyId, animation, direction)
    local key = enemyKey(enemyId, animation, direction)
    if cache[key] then return cache[key] end
    if missCache[key] then return nil end

    local dir = string.format("%s/animations/%s/%s",
        basePath(enemyId), animation, direction)
    local info = love.filesystem.getInfo(dir)
    if not info or info.type ~= "directory" then
        missCache[key] = true
        return nil
    end

    local files = love.filesystem.getDirectoryItems(dir)
    table.sort(files, function(a, b)
        -- Sort numerico quando filenames sao "0.png", "1.png", "10.png"
        local na = tonumber(a:match("^(%d+)"))
        local nb = tonumber(b:match("^(%d+)"))
        if na and nb then return na < nb end
        return a < b
    end)

    local frames = {}
    for _, file in ipairs(files) do
        if file:match("%.png$") then
            local ok, img = pcall(love.graphics.newImage, dir .. "/" .. file)
            if ok and img then
                img:setFilter("nearest", "nearest")
                table.insert(frames, img)
            end
        end
    end

    if #frames == 0 then
        missCache[key] = true
        return nil
    end

    cache[key] = frames
    return frames
end

-- Cria uma instancia de animacao. fps = frames-por-segundo. loop=true por padrao.
function SpriteAnimation.new(enemyId, animation, direction, fps, opts)
    opts = opts or {}
    local frames = loadFrames(enemyId, animation, direction)
    if not frames then return nil end

    local self = setmetatable({}, SpriteAnimation)
    self.enemyId = enemyId
    self.animation = animation
    self.direction = direction
    self.fps = fps or 8
    self.frameTime = 1 / self.fps
    self.loop = opts.loop ~= false -- default true
    -- Ping-pong (1,2,3,4,3,2,...): elimina o corte do wrap 4→1 nos idles
    -- de 4 frames (análise Jul/2026: ember_imp/abyss_tyrant/blood_duke
    -- tinham descontinuidade 1.4-1.7× a diferença média entre frames).
    self.pingpong = opts.pingpong or false
    self._dir = 1
    self.onComplete = opts.onComplete
    self.frames = frames
    self.currentFrame = 1
    self.elapsed = 0
    self.finished = false
    return self
end

function SpriteAnimation:update(dt)
    if self.finished then return end
    self.elapsed = self.elapsed + dt
    while self.elapsed >= self.frameTime do
        self.elapsed = self.elapsed - self.frameTime
        if self.pingpong and #self.frames > 1 then
            local nxt = self.currentFrame + self._dir
            if nxt > #self.frames then
                self._dir = -1
                nxt = #self.frames - 1
            elseif nxt < 1 then
                self._dir = 1
                nxt = 2
            end
            self.currentFrame = nxt
        else
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.frames then
            if self.loop then
                self.currentFrame = 1
            else
                self.currentFrame = #self.frames
                self.finished = true
                if self.onComplete then self.onComplete() end
                return
            end
        end
        end
    end
end

function SpriteAnimation:draw(x, y, scale, tint)
    local img = self.frames[self.currentFrame]
    if not img then return end
    if tint then
        love.graphics.setColor(tint[1], tint[2], tint[3], tint[4] or 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    local s = scale or 1
    love.graphics.draw(img, math.floor(x), math.floor(y), 0, s, s)
    love.graphics.setColor(1, 1, 1, 1)
end

function SpriteAnimation:getSize()
    local img = self.frames[1]
    if not img then return 0, 0 end
    return img:getWidth(), img:getHeight()
end

function SpriteAnimation:isFinished() return self.finished end
function SpriteAnimation:getFrameCount() return #self.frames end

-- Helper: verifica se uma animacao existe no disco sem carregar.
function SpriteAnimation.exists(enemyId, animation, direction)
    local dir = string.format("%s/animations/%s/%s",
        basePath(enemyId), animation, direction)
    local info = love.filesystem.getInfo(dir)
    if not info or info.type ~= "directory" then return false end
    local files = love.filesystem.getDirectoryItems(dir)
    for _, f in ipairs(files) do
        if f:match("%.png$") then return true end
    end
    return false
end

function SpriteAnimation.clearCache()
    cache = {}
    missCache = {}
end

return SpriteAnimation
