local SpriteAnimation = {}
SpriteAnimation.__index = SpriteAnimation

local cache = {}
local missCache = {}

local function enemyKey(id, anim, dir)
    return tostring(id) .. "|" .. tostring(anim) .. "|" .. tostring(dir)
end

local function basePath(id)
    if tostring(id):find("/", 1, true) then
        return "assets/sprites/characters/" .. id
    end
    return "assets/sprites/characters/enemies/" .. id
end

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
    self.loop = opts.loop ~= false
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
