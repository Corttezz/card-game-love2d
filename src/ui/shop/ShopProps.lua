local Debug = require("src.core.Debug")

local ImageCache = require("src.ui.ImageCache")
local Palette    = require("src.ui.Palette")
local Sfx        = require("src.systems.Sfx")

local ShopProps = {}

ShopProps.ASSETS = {
    lantern  = "assets/sprites/shop/lantern.png",
    diceCup  = "assets/sprites/shop/dice_cup.png",
    dieFaces = "assets/sprites/shop/die_faces.png",
    moth     = "assets/sprites/shop/moth.png",
    cobweb   = "assets/sprites/shop/cobweb.png",
    saleTag  = "assets/sprites/shop/price_tag_sale.png",
}

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) and true or false
end

local sheets = {}
local warned = {}

local function sheet(key, fw, fh)
    local s = sheets[key]
    if s then return s end
    local path = ShopProps.ASSETS[key]
    local img = ImageCache.tryGet(path)
    if not img then
        if not warned[key] then
            warned[key] = true
            Debug.warn("[ShopProps] asset ausente: " .. tostring(path) .. " (prop '" .. key .. "' não desenha)")
        end
        return nil
    end
    img:setFilter("nearest", "nearest")
    local iw, ih = img:getDimensions()
    fw, fh = fw or iw, fh or ih
    local n = math.max(1, math.floor(iw / fw))
    if iw % fw ~= 0 or ih ~= fh then
        Debug.warn(("[ShopProps] %s tem %dx%d, esperado múltiplo de %dx%d"):format(path, iw, ih, fw, fh))
    end
    local quads = {}
    for i = 1, n do
        quads[i] = love.graphics.newQuad((i - 1) * fw, 0, fw, fh, iw, ih)
    end
    s = { img = img, quads = quads, n = n, fw = fw, fh = fh }
    sheets[key] = s
    return s
end

local function drawFrame(s, i, x, y, scale, r, ox, oy)
    i = math.max(1, math.min(s.n, i))
    love.graphics.draw(s.img, s.quads[i], x, y, r or 0, scale, scale, ox or 0, oy or 0)
end

function ShopProps.missingAssets()
    local out = {}
    for key, path in pairs(ShopProps.ASSETS) do
        local info = love.filesystem.getInfo(path)
        if not info then out[#out + 1] = path end
    end
    table.sort(out)
    return out
end

local dot
local function dotImage()
    if dot then return dot end
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    dot = love.graphics.newImage(data)
    dot:setFilter("nearest", "nearest")
    return dot
end

local Lantern = {}
Lantern.__index = Lantern

Lantern.FW, Lantern.FH = 32, 48
Lantern.FLAME = { x = 15.5, y = 31 }
Lantern.LEVELS = { 0.82, 1.00, 1.14 }
Lantern.HOLDS = { 0.08, 0.12, 0.18, 0.26 }
Lantern.LOOK_STEPS = 2
Lantern.LOOK_PX = 7
Lantern.LOOK_RATE = 4
Lantern.POOL_DY = 30
Lantern.POOL_RX, Lantern.POOL_RY = 34, 19
Lantern.DUST_N = 18
Lantern.DUST_DEPTH = 72
Lantern.AMBER = { 1.00, 0.72, 0.36 }

local function newMote(i)
    local depth = love.math.random() * Lantern.DUST_DEPTH
    return {
        y = depth,
        x = (love.math.random() - 0.5) * 2 * (5 + depth * 0.45),
        speed = 2.5 + love.math.random() * 4.5,
        drift = (love.math.random() - 0.5) * 2.0,
        phase = i * 0.37,
        size = love.math.random() < 0.3 and 2 or 1,
    }
end

function ShopProps.newLantern()
    local l = setmetatable({}, Lantern)
    l.frame = 1
    l.level = 2
    l.hold = 0
    l.lookStep = 0
    l.lookTarget = 0
    l.lookTimer = 0
    l.clock = 0
    l.motes = {}
    for i = 1, Lantern.DUST_N do l.motes[i] = newMote(i) end
    l.batch = love.graphics.newSpriteBatch(dotImage(), Lantern.DUST_N, "stream")
    return l
end

function Lantern:update(dt, lookX)
    self.clock = self.clock + dt
    local target = 0
    if lookX then
        lookX = math.max(-1, math.min(1, lookX))
        target = math.floor(lookX * Lantern.LOOK_STEPS + 0.5)
    end
    self.lookTarget = target
    if reducedMotion() then
        self.frame, self.level = 1, 2
        self.lookStep = target
        return
    end
    if self.lookStep ~= target then
        self.lookTimer = self.lookTimer + dt
        if self.lookTimer >= 1 / Lantern.LOOK_RATE then
            self.lookTimer = 0
            self.lookStep = self.lookStep + (target > self.lookStep and 1 or -1)
        end
    else
        self.lookTimer = 0
    end
    self.hold = self.hold - dt
    if self.hold <= 0 then
        local r = love.math.random()
        self.frame = r < 0.5 and 1 or (r < 0.78 and 2 or 3)
        local lv = love.math.random()
        self.level = lv < 0.6 and 2 or (lv < 0.85 and 1 or 3)
        self.hold = Lantern.HOLDS[love.math.random(#Lantern.HOLDS)]
    end
    for _, m in ipairs(self.motes) do
        m.y = m.y - m.speed * dt
        m.x = m.x + m.drift * dt
        local hw = 5 + math.max(0, m.y) * 0.45
        if m.y < 4 then
            m.y = Lantern.DUST_DEPTH
            m.x = (love.math.random() - 0.5) * 2 * (5 + m.y * 0.45)
        end
        if m.x < -hw then m.x = -hw; m.drift = math.abs(m.drift)
        elseif m.x > hw then m.x = hw; m.drift = -math.abs(m.drift) end
    end
end

function Lantern:intensity()
    return Lantern.LEVELS[self.level] or 1
end

function Lantern:flameAt(x, y, scale)
    return x + (Lantern.FLAME.x - Lantern.FW / 2) * scale, y + Lantern.FLAME.y * scale
end

function Lantern:lightCenter(x, y, scale)
    local fx, fy = self:flameAt(x, y, scale)
    return fx + self.lookStep * Lantern.LOOK_PX * scale,
           fy + Lantern.POOL_DY * scale,
           Lantern.POOL_RX * scale
end

function Lantern:drawLight(x, y, scale, opts)
    scale = scale or 1
    local pool = not (opts and opts.pool == false)
    local k = self:intensity()
    local a = Lantern.AMBER
    local fx, fy = self:flameAt(x, y, scale)
    local cx, cy = self:lightCenter(x, y, scale)
    love.graphics.setBlendMode("add")
    for step = 0, (pool and 2 or -1) do
        local f = 1 - step * 0.30
        love.graphics.setColor(a[1], a[2], a[3], (0.05 + 0.025 * step) * k)
        love.graphics.ellipse("fill", math.floor(cx), math.floor(cy),
            Lantern.POOL_RX * scale * f, Lantern.POOL_RY * scale * f, 24)
    end
    for step = 0, 1 do
        love.graphics.setColor(a[1], a[2] + 0.1, a[3], (0.06 + 0.05 * step) * k)
        love.graphics.circle("fill", math.floor(fx), math.floor(fy), (14 - step * 6) * scale, 16)
    end
    local batch = self.batch
    batch:clear()
    local pulse = math.floor(self.clock * 4) % 2 == 0 and 1 or 0
    for _, m in ipairs(self.motes) do
        local tw = 0.28 + 0.16 * (((math.floor(m.phase * 10) + pulse) % 2))
        batch:setColor(a[1], a[2] + 0.12, a[3] + 0.2, tw * k)
        batch:add(math.floor(fx + m.x * scale), math.floor(fy + m.y * scale), 0,
            m.size * scale, m.size * scale)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
    love.graphics.setBlendMode("alpha")
end

function Lantern:drawSprite(x, y, scale)
    scale = scale or 1
    local s = sheet("lantern", Lantern.FW, Lantern.FH)
    if not s then return end
    love.graphics.setColor(1, 1, 1, 1)
    drawFrame(s, self.frame, math.floor(x - Lantern.FW / 2 * scale), math.floor(y), scale)
end

function Lantern:draw(x, y, scale)
    self:drawLight(x, y, scale)
    self:drawSprite(x, y, scale)
end

ShopProps.lantern = { new = ShopProps.newLantern, flameAt = function(x, y, s)
    return x + (Lantern.FLAME.x - Lantern.FW / 2) * s, y + Lantern.FLAME.y * s
end, Lantern = Lantern }

local DiceCup = {}
DiceCup.__index = DiceCup
DiceCup.FW, DiceCup.FH = 32, 32
DiceCup.DIE = 16
DiceCup.SHAKE_FPS = 11
DiceCup.FRAME_IDLE, DiceCup.FRAME_SHAKE, DiceCup.FRAME_LYING = 1, { 2, 3, 4 }, 5
DiceCup.STATES = { idle = true, shake = true, rolled = true }

function ShopProps.newDiceCup()
    local c = setmetatable({}, DiceCup)
    c.state = "idle"
    c.frame = 1
    c.t = 0
    c.dice = nil
    return c
end

function DiceCup:setState(state, opts)
    if not DiceCup.STATES[state] then
        Debug.warn("[ShopProps] estado de copo desconhecido: " .. tostring(state))
        return
    end
    if state == "rolled" then
        local a = opts and tonumber(opts.a)
        local b = opts and tonumber(opts.b)
        if not a or not b or a < 1 or a > 6 or b < 1 or b > 6 then
            Debug.warn("[ShopProps] rolled sem faces válidas (a=" .. tostring(a) .. ", b=" .. tostring(b) .. ")")
            return
        end
        self.dice = { math.floor(a), math.floor(b) }
    elseif self.state == "rolled" then
        self.dice = nil
    end
    if state == "shake" and self.state ~= "shake" and not reducedMotion() then
        Sfx.play("sceneWoodKnock", { volume = 0.35, pitch = 1.25 })
    end
    self.state = state
    self.t = 0
    self.frame = state == "rolled" and DiceCup.FRAME_LYING or DiceCup.FRAME_IDLE
end

function DiceCup:syncRun(run)
    local ScribeDice = require("src.systems.ScribeDice")
    local st = ScribeDice.state(run)
    if st and st.used and st.dice then
        if self.state ~= "rolled" or not self.dice
            or self.dice[1] ~= st.dice[1] or self.dice[2] ~= st.dice[2] then
            self:setState("rolled", { a = st.dice[1], b = st.dice[2] })
        end
        return true
    end
    if self.state == "rolled" then self:setState("idle") end
    return false
end

function DiceCup:update(dt)
    self.t = self.t + dt
    if self.state == "shake" then
        if reducedMotion() then
            self.frame = DiceCup.FRAME_IDLE
        else
            local i = math.floor(self.t * DiceCup.SHAKE_FPS) % #DiceCup.FRAME_SHAKE + 1
            self.frame = DiceCup.FRAME_SHAKE[i]
        end
    elseif self.state == "rolled" then
        self.frame = DiceCup.FRAME_LYING
    else
        self.frame = DiceCup.FRAME_IDLE
    end
end

function DiceCup:width(scale)
    scale = scale or 1
    if self.state == "rolled" then
        return (DiceCup.FW + 6 + DiceCup.DIE * 2 + 4) * scale
    end
    return DiceCup.FW * scale
end

function DiceCup:draw(x, y, scale, opts)
    scale = scale or 1
    opts = opts or {}
    local slope = opts.slope or 0
    local s = sheet("diceCup", DiceCup.FW, DiceCup.FH)
    if not s then return end
    local cx = math.floor(x - DiceCup.FW / 2 * scale)
    local cy = math.floor(y - DiceCup.FH * scale)
    if (opts.outline or 0) > 0.01 and opts.silhouette then
        love.graphics.setShader(opts.silhouette)
        local c = Palette.PARCHMENT_LIGHT
        love.graphics.setColor(c[1], c[2], c[3], opts.outline)
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            drawFrame(s, self.frame, cx + d[1], cy + d[2], scale)
        end
        love.graphics.setShader()
    end
    love.graphics.setColor(1, 1, 1, 1)
    drawFrame(s, self.frame, cx, cy, scale)
    local show = (self.state == "rolled" and self.dice) and self.dice
        or (opts.idleDie and { opts.idleDie }) or nil
    if show then
        local faces = sheet("dieFaces", DiceCup.DIE, DiceCup.DIE)
        if faces then
            local off = (DiceCup.FW / 2 + 6) * scale
            for i = 1, #show do
                local p = opts.dicePos and opts.dicePos[i]
                local dx, dy
                if p then
                    dx = math.floor(x + p[1] * scale - DiceCup.DIE / 2 * scale)
                    dy = math.floor(y + p[2] * scale + slope * p[1] * scale - DiceCup.DIE * scale)
                else
                    dx = math.floor(x + off)
                    dy = math.floor(y + slope * off - (DiceCup.DIE + 2) * scale)
                end
                love.graphics.setColor(1, 1, 1, 1)
                drawFrame(faces, show[i], dx, dy, scale)
                off = off + (DiceCup.DIE + 4) * scale
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

ShopProps.diceCup = { new = ShopProps.newDiceCup, DiceCup = DiceCup }

local Moth = {}
Moth.__index = Moth
Moth.FW, Moth.FH = 16, 16
Moth.MIN_WAIT, Moth.MAX_WAIT = 20, 40
Moth.SPAN = 110
Moth.SPEED = 46
Moth.FPS = 14
Moth.PERCH = { x = 14, y = 6 }

function ShopProps.newMoth()
    local m = setmetatable({}, Moth)
    m.wait = Moth.MIN_WAIT + love.math.random() * (Moth.MAX_WAIT - Moth.MIN_WAIT)
    m.flying = false
    m.t = 0
    m.dir = 1
    m.frame = 1
    return m
end

function Moth:cross()
    self.flying = true
    self.t = 0
    self.dir = love.math.random() < 0.5 and -1 or 1
end

function Moth:isFlying() return self.flying end

function Moth:update(dt)
    if reducedMotion() then
        self.flying = false
        self.frame = 3
        return
    end
    if self.flying then
        self.t = self.t + dt
        self.frame = math.floor(self.t * Moth.FPS) % 4 + 1
        if self.t * Moth.SPEED > Moth.SPAN * 2 then
            self.flying = false
            self.wait = Moth.MIN_WAIT + love.math.random() * (Moth.MAX_WAIT - Moth.MIN_WAIT)
        end
    else
        self.wait = self.wait - dt
        if self.wait <= 0 then self:cross() end
    end
end

function Moth:draw(fx, fy, scale)
    scale = scale or 1
    local s = sheet("moth", Moth.FW, Moth.FH)
    if not s then return end
    love.graphics.setColor(1, 1, 1, 1)
    if reducedMotion() then
        drawFrame(s, 3, math.floor(fx + Moth.PERCH.x * scale), math.floor(fy + Moth.PERCH.y * scale),
            scale, 0, Moth.FW / 2, Moth.FH / 2)
        return
    end
    if not self.flying then return end
    local d = self.t * Moth.SPEED - Moth.SPAN
    local x = fx + d * self.dir * scale
    local arc = -(1 - (d / Moth.SPAN) ^ 2) * 10
    local zig = math.floor(math.sin(self.t * 9) * 3)
    local y = fy + (arc + zig) * scale
    drawFrame(s, self.frame, math.floor(x), math.floor(y), scale, 0, Moth.FW / 2, Moth.FH / 2)
end

ShopProps.moth = { new = ShopProps.newMoth, Moth = Moth }

ShopProps.cobweb = {}
function ShopProps.cobweb.draw(x, y, scale)
    local s = sheet("cobweb")
    if not s then return end
    love.graphics.setColor(1, 1, 1, 0.9)
    drawFrame(s, 1, math.floor(x), math.floor(y), scale or 1)
    love.graphics.setColor(1, 1, 1, 1)
end

ShopProps.saleTag = { W = 24, H = 16 }
function ShopProps.saleTag.draw(x, y, scale)
    local s = sheet("saleTag")
    if not s then return end
    love.graphics.setColor(1, 1, 1, 1)
    drawFrame(s, 1, math.floor(x), math.floor(y), scale or 1)
end

local S = nil

local function lanternScale(rect)
    return math.max(1, math.floor(math.min(rect.w / Lantern.FW, rect.h / Lantern.FH)))
end

local function lanternHook(rect)
    local sc = lanternScale(rect)
    return math.floor(rect.x + rect.w / 2), math.floor(rect.y + (rect.h - Lantern.FH * sc) / 2), sc
end

function ShopProps.load()
    S = { lantern = ShopProps.newLantern(), cup = ShopProps.newDiceCup(), moth = ShopProps.newMoth() }
    for _, path in ipairs(ShopProps.missingAssets()) do
        Debug.warn("[ShopProps] asset ausente: " .. path)
    end
    return S
end

function ShopProps.update(dt, L, ctx)
    if not S then ShopProps.load() end
    ctx = ctx or {}
    local lookX = nil
    local lr = L and L.lantern
    if lr and ctx.hoverX then
        local fx = lr.x + lr.w / 2
        local span = (L.wall and L.wall.w or love.graphics.getWidth()) / 2
        lookX = math.max(-1, math.min(1, (ctx.hoverX - fx) / math.max(1, span)))
    end
    S.lantern:update(dt, lookX)
    if ctx.run then
        S.cup:syncRun(ctx.run)
    elseif ctx.dice and ctx.dice[1] and ctx.dice[2] then
        if S.cup.state ~= "rolled" or S.cup.dice[1] ~= ctx.dice[1] or S.cup.dice[2] ~= ctx.dice[2] then
            S.cup:setState("rolled", { a = ctx.dice[1], b = ctx.dice[2] })
        end
    elseif S.cup.state == "rolled" then
        S.cup:setState("idle")
    end
    if S.cup.state ~= "rolled" then
        local hov = (ctx.cupHover or ctx.hover or 0) > 0.5
        if hov and S.cup.state ~= "shake" then S.cup:setState("shake")
        elseif not hov and S.cup.state == "shake" then S.cup:setState("idle") end
    end
    S.cup:update(dt)
    S.moth:update(dt)
end

function ShopProps.flameAnchor(rect)
    local hx, hy, sc = lanternHook(rect)
    local l = S and S.lantern
    if l then return l:flameAt(hx, hy, sc) end
    return ShopProps.lantern.flameAt(hx, hy, sc)
end

function ShopProps.lookDx(rect)
    if not S then return 0 end
    local sc = rect and lanternScale(rect) or 1
    return S.lantern.lookStep * Lantern.LOOK_PX * sc
end

function ShopProps.lightLevel()
    return S and S.lantern:intensity() or 1
end

function ShopProps.drawBack(L, ctx)
    if not S then ShopProps.load() end
    if L and L.shelfTop then
        local sc = math.max(1, math.floor(L.shelfTop.h / 96))
        ShopProps.cobweb.draw(L.shelfTop.x + 2, L.shelfTop.y + 2, sc)
    end
    if L and L.lantern then
        local hx, hy, sc = lanternHook(L.lantern)
        S.lantern:drawLight(hx, hy, sc, { pool = false })
    end
end

function ShopProps.drawLantern(rect, ctx)
    if not S then ShopProps.load() end
    local hx, hy, sc = lanternHook(rect)
    S.lantern:drawSprite(hx, hy, sc)
end

function ShopProps.drawDiceCup(rect, ctx)
    if not S then ShopProps.load() end
    ctx = ctx or {}
    local sc = math.max(1, math.floor(rect.h / DiceCup.FH))
    S.cup:draw(math.floor(rect.x + rect.w / 2), math.floor(rect.y + rect.h), sc,
        { slope = ctx.slope, outline = ctx.outline, silhouette = ctx.silhouette,
          dicePos = ctx.dicePos, idleDie = ctx.idleDie })
end

function ShopProps.drawFront(L, ctx)
    if not S then ShopProps.load() end
    if not (L and L.lantern) then return end
    local hx, hy, sc = lanternHook(L.lantern)
    local fx, fy = S.lantern:flameAt(hx, hy, sc)
    S.moth:draw(fx, fy, sc)
end

function ShopProps.scene() return S end

function ShopProps._reset()
    sheets, warned, S = {}, {}, nil
end

return ShopProps
