local PackBurst = {}
PackBurst.__index = PackBurst

PackBurst.MAX_BITS = 260
PackBurst.FRAG_COLS = 4
PackBurst.FRAG_ROWS = 5

function PackBurst.new(theme)
    local self = setmetatable({}, PackBurst)
    self.theme = theme
    self.bits = {}
    self.frags = {}
    self.acc = 0
    self.rng = love.math.newRandomGenerator(7331)
    return self
end

function PackBurst:clear()
    self.bits, self.frags, self.acc = {}, {}, 0
end

function PackBurst:count()
    return #self.bits + #self.frags
end

function PackBurst:_colour(i)
    local th = self.theme
    local pick = i % 3
    if pick == 0 then return th.accent end
    if pick == 1 then return th.glow end
    return th.titleHi
end

function PackBurst:_add(b)
    if #self.bits >= PackBurst.MAX_BITS then table.remove(self.bits, 1) end
    self.bits[#self.bits + 1] = b
end

function PackBurst:charge(dt, rate, x, y, w, h)
    self.acc = self.acc + dt * rate
    local r = self.rng
    while self.acc >= 1 do
        self.acc = self.acc - 1
        local side = r:random(1, 4)
        local px, py, nx, ny
        if side == 1 then px, py, nx, ny = x + r:random() * w, y, 0, -1
        elseif side == 2 then px, py, nx, ny = x + r:random() * w, y + h, 0, 1
        elseif side == 3 then px, py, nx, ny = x, y + r:random() * h, -1, 0
        else px, py, nx, ny = x + w, y + r:random() * h, 1, 0 end
        local sp = 50 + r:random() * 70
        self:_add({
            x = px, y = py,
            vx = nx * sp + (r:random() - 0.5) * 30, vy = ny * sp - 20,
            age = 0, life = 0.35 + r:random() * 0.25, size = 2,
            col = self:_colour(r:random(0, 2)), drag = 3, grav = 0,
        })
    end
end

function PackBurst:burst(cx, cy, scale)
    local d = self.theme.debris or {}
    local r = self.rng
    local n = math.max(44, (d.count or 16) * 3)
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + (r:random() - 0.5) * 0.5
        local sp = (d.speed or 240) * (0.8 + r:random() * 1.1) * (scale or 1)
        self:_add({
            x = cx, y = cy,
            vx = math.cos(ang) * sp, vy = math.sin(ang) * sp * 0.8 - 60,
            age = 0, life = (d.life or 0.9) * (0.8 + r:random() * 0.8),
            size = (r:random() < 0.35) and 6 or 3,
            col = self:_colour(i), drag = 2.4, grav = (d.gravity or 400) * 0.8,
        })
    end
end

function PackBurst:strip(img, cx, cy, s, rows)
    if not img or rows <= 0 then return end
    local iw, ih = img:getWidth(), img:getHeight()
    local r = self.rng
    self.frags[#self.frags + 1] = {
        quad = love.graphics.newQuad(0, 0, iw, rows, iw, ih),
        img = img, qw = iw, qh = rows, s = s,
        x = cx, y = cy + (rows * 0.5 - ih * 0.5) * s,
        vx = 90 + r:random() * 60, vy = -620,
        rot = 0, spin = 4 + r:random() * 3,
        age = 0, life = 0.9, grav = 1300,
    }
end

function PackBurst:tear(img, cx, cy, s, top)
    if not img then return end
    top = top or 0
    local iw, ih = img:getWidth(), img:getHeight()
    local C, R = PackBurst.FRAG_COLS, PackBurst.FRAG_ROWS
    local qw, qh = math.floor(iw / C), math.floor((ih - top) / R)
    local r = self.rng
    for row = 0, R - 1 do
        for col = 0, C - 1 do
            local qx, qy = col * qw, top + row * qh
            local fx = (qx + qw * 0.5) - iw * 0.5
            local fy = (qy + qh * 0.5) - ih * 0.5
            local len = math.sqrt(fx * fx + fy * fy) + 1
            local sp = 160 + r:random() * 240
            self.frags[#self.frags + 1] = {
                quad = love.graphics.newQuad(qx, qy, qw, qh, iw, ih),
                img = img, qw = qw, qh = qh, s = s,
                x = cx + fx * s, y = cy + fy * s,
                vx = fx / len * sp + (r:random() - 0.5) * 60,
                vy = fy / len * sp * 0.7 - 140 - r:random() * 120,
                rot = 0, spin = (r:random() - 0.5) * 9,
                age = 0, life = 0.75 + r:random() * 0.35,
            }
        end
    end
end

function PackBurst:update(dt)
    for i = #self.bits, 1, -1 do
        local b = self.bits[i]
        b.age = b.age + dt
        if b.age >= b.life then
            table.remove(self.bits, i)
        else
            local damp = math.exp(-(b.drag or 0) * dt)
            b.vx = b.vx * damp
            b.vy = b.vy * damp + (b.grav or 0) * dt
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
        end
    end
    for i = #self.frags, 1, -1 do
        local f = self.frags[i]
        f.age = f.age + dt
        if f.age >= f.life then
            f.quad:release()
            table.remove(self.frags, i)
        else
            f.vy = f.vy + (f.grav or 1100) * dt
            f.vx = f.vx * math.exp(-0.8 * dt)
            f.x = f.x + f.vx * dt
            f.y = f.y + f.vy * dt
            f.rot = f.rot + f.spin * dt
        end
    end
end

function PackBurst:drawFragments()
    for _, f in ipairs(self.frags) do
        local p = f.age / f.life
        local a = p < 0.6 and 1 or (1 - (p - 0.6) / 0.4)
        local rot = math.floor(f.rot / (math.pi / 8) + 0.5) * (math.pi / 8)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.draw(f.img, f.quad, math.floor(f.x), math.floor(f.y), rot,
            f.s, f.s, f.qw * 0.5, f.qh * 0.5)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PackBurst:drawBits()
    for _, b in ipairs(self.bits) do
        local p = b.age / b.life
        local a = p < 0.5 and 1 or (1 - (p - 0.5) * 2)
        local c = b.col or { 1, 1, 1 }
        local s = b.size
        love.graphics.setColor(c[1], c[2], c[3], a)
        love.graphics.rectangle("fill", math.floor(b.x / 3) * 3, math.floor(b.y / 3) * 3, s, s)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PackBurst
