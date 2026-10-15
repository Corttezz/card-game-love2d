local Debug   = require("src.core.Debug")
local Palette = require("src.ui.Palette")

local RevealGlow = {}

RevealGlow.CELL = 2
RevealGlow.LEVELS = 4
RevealGlow.RAYS = 12
RevealGlow.ROT_SPEED = 0.22
RevealGlow.SPARKLES = 14

local shader, tried, whitePx

function RevealGlow.shader()
    if tried then return shader end
    tried = true
    local ok, s = pcall(love.graphics.newShader, "shaders/reveal_stage.glsl")
    if ok then shader = s
    else Debug.warn("[RevealGlow] AVISO: shader do palco falhou: " .. tostring(s)) end
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    whitePx = love.graphics.newImage(data)
    whitePx:setFilter("nearest", "nearest")
    return shader
end

local function rgb(c) return { c[1], c[2], c[3] } end

RevealGlow.drawn = 0

function RevealGlow.halo(cx, cy, r, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    if alpha <= 0.003 or r < 2 then return false end
    local sh = RevealGlow.shader()
    if not sh then return false end
    local motion = opts.motion ~= false
    local t = opts.t or 0
    local size = math.floor(r * 2)
    sh:send("size", { size, size })
    sh:send("cell", opts.cell or RevealGlow.CELL)
    sh:send("levels", opts.levels or RevealGlow.LEVELS)
    sh:send("rays", opts.rays or RevealGlow.RAYS)
    sh:send("rot", motion and t * (opts.rotSpeed or RevealGlow.ROT_SPEED) or 0)
    sh:send("rayOn", (motion and opts.rayOn ~= false) and 1 or 0)
    sh:send("pulse", motion and (0.86 + 0.14 * math.sin(t * 2.4)) or 1)
    sh:send("glowCol", rgb(opts.glow or Palette.AGED_GOLD))
    sh:send("rayCol", rgb(opts.ray or Palette.AGED_GOLD_LIGHT))
    love.graphics.push("all")
    love.graphics.setShader(sh)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(whitePx, math.floor(cx - size / 2), math.floor(cy - size / 2), 0, size, size)
    love.graphics.pop()
    RevealGlow.drawn = RevealGlow.drawn + 1
    return true
end

local function hash(seed, i, k)
    local v = math.sin(i * 127.1 + k * 311.7 + seed * 74.7) * 43758.5453
    return v - math.floor(v)
end

function RevealGlow.sparkles(cx, cy, r, opts)
    opts = opts or {}
    if opts.motion == false then return end
    local alpha = opts.alpha or 1
    if alpha <= 0.003 then return end
    local t, seed = opts.t or 0, opts.seed or 1
    local cell = opts.cell or RevealGlow.CELL
    local base = opts.color or Palette.AGED_GOLD_LIGHT
    local hot = opts.hot or Palette.PARCHMENT_LIGHT
    local inner = opts.inner or 0.42
    local function snap(v) return math.floor(v / cell) * cell end
    love.graphics.push("all")
    for i = 1, opts.count or RevealGlow.SPARKLES do
        local ang = hash(seed, i, 1) * math.pi * 2
        local rad = r * (inner + (0.98 - inner) * hash(seed, i, 2))
        local phase = hash(seed, i, 3) * math.pi * 2
        local speed = 1.6 + hash(seed, i, 4) * 1.8
        local b = math.sin(t * speed + phase)
        if b > 0.45 then
            local x, y = snap(cx + math.cos(ang) * rad), snap(cy + math.sin(ang) * rad)
            Palette.set(b > 0.9 and hot or base, alpha)
            love.graphics.rectangle("fill", x, y, cell, cell)
            if b > 0.8 then
                Palette.set(base, alpha * 0.8)
                love.graphics.rectangle("fill", x - cell, y, cell, cell)
                love.graphics.rectangle("fill", x + cell, y, cell, cell)
                love.graphics.rectangle("fill", x, y - cell, cell, cell)
                love.graphics.rectangle("fill", x, y + cell, cell, cell)
            end
        end
    end
    love.graphics.pop()
end

return RevealGlow
