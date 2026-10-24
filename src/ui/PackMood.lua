local PackMood = {}
PackMood.__index = PackMood

PackMood.CELL = 3
PackMood.UNIT = 3
PackMood.LEVELS = 9

local BAYER = {
    { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 },
}

local function bayer(x, y)
    return (BAYER[(y % 4) + 1][(x % 4) + 1] + 0.5) / 16
end

local function hash(i, salt)
    local v = math.sin(i * 12.9898 + (salt or 0) * 78.233) * 43758.5453
    return v - math.floor(v)
end

function PackMood.new(theme)
    local self = setmetatable({}, PackMood)
    self.theme = theme
    self.mood = theme and theme.mood or {
        top = { 0.06, 0.05, 0.04 }, bottom = { 0.2, 0.15, 0.1 },
        motes = "dust", count = 30, colours = { { 0.9, 0.8, 0.6 } },
    }
    self.t = 0
    self.meteor = nil
    self.nextMeteor = 1.4
    self.motes = {}
    local n = self.mood.count or 30
    for i = 1, n do
        self.motes[i] = {
            x = hash(i, 1), y = hash(i, 2),
            sp = 0.4 + hash(i, 3) * 0.6,
            ph = hash(i, 4) * math.pi * 2,
            c = 1 + math.floor(hash(i, 5) * #self.mood.colours) % #self.mood.colours,
            big = hash(i, 6) > 0.8,
        }
    end
    return self
end

function PackMood:resize()
    if self.image then self.image:release() end
    self.image, self.iw, self.ih = nil, nil, nil
end

function PackMood:_build(w, h)
    local cell = PackMood.CELL
    local cols, rows = math.ceil(w / cell), math.ceil(h / cell)
    local data = love.image.newImageData(cols, rows)
    local top, bot = self.mood.top, self.mood.bottom
    local L = PackMood.LEVELS - 1
    for y = 0, rows - 1 do
        local t = y / math.max(1, rows - 1)
        t = t * t * (3 - 2 * t)
        for x = 0, cols - 1 do
            local side = math.abs(x / math.max(1, cols - 1) - 0.5) * 2
            local lv = t * L
            local lo = math.floor(lv)
            local step = (bayer(x, y) < lv - lo) and lo + 1 or lo
            local k = step / L
            local dark = 1
            if side > 0.55 then
                local s = (side - 0.55) / 0.45 * 4
                local lo2 = math.floor(s)
                local st = (bayer(x + 2, y + 1) < s - lo2) and lo2 + 1 or lo2
                dark = 1 - 0.07 * st
            end
            data:setPixel(x, y,
                (top[1] + (bot[1] - top[1]) * k) * dark,
                (top[2] + (bot[2] - top[2]) * k) * dark,
                (top[3] + (bot[3] - top[3]) * k) * dark, 1)
        end
    end
    local img = love.graphics.newImage(data)
    data:release()
    img:setFilter("nearest", "nearest")
    self.image, self.iw, self.ih = img, w, h
end

function PackMood:update(dt, still)
    self.t = self.t + dt
    if still then return end
    local kind = self.mood.motes
    for _, m in ipairs(self.motes) do
        if kind == "dust" then
            m.y = m.y - dt * 0.018 * m.sp
            m.x = m.x + math.sin(self.t * 0.7 + m.ph) * dt * 0.006
        elseif kind == "confetti" then
            m.y = m.y + dt * 0.05 * m.sp
            m.x = m.x + math.sin(self.t * 1.6 + m.ph) * dt * 0.02
        elseif kind == "sparks" then
            m.y = m.y - dt * 0.028 * m.sp
        elseif kind == "wisps" then
            m.y = m.y - dt * 0.035 * m.sp
            m.x = m.x + math.sin(self.t * 1.1 + m.ph) * dt * 0.01
        end
        if m.y < -0.05 then m.y = m.y + 1.1 end
        if m.y > 1.05 then m.y = m.y - 1.1 end
        if m.x < 0 then m.x = m.x + 1 end
        if m.x > 1 then m.x = m.x - 1 end
    end
    if kind == "stars" then
        if self.meteor then
            self.meteor.age = self.meteor.age + dt
            if self.meteor.age > 0.7 then self.meteor = nil end
        else
            self.nextMeteor = self.nextMeteor - dt
            if self.nextMeteor <= 0 then
                local i = math.floor(self.t * 10)
                self.meteor = { x = 0.35 + hash(i, 7) * 0.6, y = 0.05 + hash(i, 8) * 0.3, age = 0 }
                self.nextMeteor = 2.2 + hash(i, 9) * 1.6
            end
        end
    end
end

local function sq(x, y, s)
    love.graphics.rectangle("fill", x, y, s, s)
end

function PackMood:drawBackground(alpha)
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    if not self.image or self.iw ~= w or self.ih ~= h then self:_build(w, h) end
    love.graphics.setColor(1, 1, 1, alpha or 1)
    love.graphics.draw(self.image, 0, 0, 0, PackMood.CELL, PackMood.CELL)
end

function PackMood:drawMotes(alpha, still)
    alpha = alpha or 1
    if alpha <= 0.01 then return end
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local u = PackMood.UNIT
    local kind = self.mood.motes
    local cols = self.mood.colours
    local function snap(v) return math.floor(v / u) * u end
    for i, m in ipairs(self.motes) do
        local c = cols[m.c]
        local x, y = snap(m.x * w), snap(m.y * h)
        local a = alpha
        if kind == "dust" then
            a = a * (0.35 + 0.45 * m.sp)
            love.graphics.setColor(c[1], c[2], c[3], a)
            sq(x, y, m.big and u * 2 or u)
        elseif kind == "confetti" then
            local flip = still and 0 or math.floor((self.t * 6 * m.sp + m.ph) % 2)
            love.graphics.setColor(c[1], c[2], c[3], a * 0.85)
            if flip == 0 then
                love.graphics.rectangle("fill", x, y, u * 2, u)
            else
                love.graphics.rectangle("fill", x, y, u, u * 2)
            end
        elseif kind == "sparks" then
            local tw = still and 1 or (math.sin(self.t * 3 * m.sp + m.ph) > -0.2 and 1 or 0.35)
            love.graphics.setColor(c[1], c[2], c[3], a * 0.8 * tw)
            sq(x, y, u)
            if m.big then
                sq(x - u, y, u); sq(x + u, y, u); sq(x, y - u, u); sq(x, y + u, u)
            end
        elseif kind == "stars" then
            local lv = still and 2 or (math.floor(self.t * 4 + i * 1.7) % 5)
            local tw = (lv == 0) and 0.3 or ((lv == 1) and 0.6 or 1)
            love.graphics.setColor(c[1], c[2], c[3], a * tw * (0.5 + 0.5 * m.sp))
            sq(x, y, u)
            if m.big and tw > 0.9 then
                love.graphics.setColor(c[1], c[2], c[3], a * 0.45)
                sq(x - u, y, u); sq(x + u, y, u); sq(x, y - u, u); sq(x, y + u, u)
            end
        elseif kind == "wisps" then
            for k = 0, 3 do
                love.graphics.setColor(c[1], c[2], c[3], a * (0.55 - k * 0.13) * m.sp)
                sq(x, y + k * u, u)
            end
        end
    end
    if self.meteor and not still then
        local mt = self.meteor
        local p = mt.age / 0.7
        local hx, hy = (mt.x - p * 0.35) * w, (mt.y + p * 0.2) * h
        local c = cols[1]
        for k = 0, 6 do
            love.graphics.setColor(c[1], c[2], c[3], alpha * (1 - p) * (1 - k / 7))
            sq(snap(hx + k * u * 1.75), snap(hy - k * u), u)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PackMood
