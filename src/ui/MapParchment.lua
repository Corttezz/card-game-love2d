local Debug = require("src.core.Debug")
local Ink   = require("src.ui.RunJournalInk")

local MapParchment = {}

MapParchment.RELIEF_AMP = 4.5
MapParchment.INK_WEAR   = 0.38
MapParchment.CACHE_MAX  = 3
MapParchment.SHADOW     = { 0.08, 0.06, 0.05 }

local genShader, inkShader, white
local tried, ready = false, false
local cache, order = {}, {}
local inkCanvas

function MapParchment.ensure()
    if tried then return ready end
    tried = true
    if not (love and love.graphics and love.graphics.newShader) then return false end
    local ok1, s1 = pcall(love.graphics.newShader, "shaders/map_parchment.glsl")
    local ok2, s2 = pcall(love.graphics.newShader, "shaders/map_relief.glsl")
    if not (ok1 and ok2) then
        Debug.warn("[MapParchment] shader do pergaminho indisponível: " .. tostring(ok1 and s2 or s1))
        return false
    end
    genShader, inkShader = s1, s2
    local id = love.image.newImageData(1, 1)
    id:setPixel(0, 0, 1, 1, 1, 1)
    white = love.graphics.newImage(id)
    ready = true
    return true
end

function MapParchment.isReady() return ready end

local function send(sh, name, ...)
    if sh:hasUniform(name) then sh:send(name, ...) end
end

local function rgb(c) return { c[1], c[2], c[3] } end

local function render(w, h, mode)
    local cv = love.graphics.newCanvas(w, h)
    cv:setFilter("linear", "linear")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setShader(genShader)
    send(genShader, "mode", mode)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(white, 0, 0, 0, w, h)
    love.graphics.setShader()
    love.graphics.setCanvas()
    return cv
end

function MapParchment.folds(w, h, seed)
    local hash = Ink.hash
    return {
        w * (0.31 + hash(seed, 81) * 0.05),
        w * (0.60 + hash(seed, 82) * 0.06),
        h * (0.46 + hash(seed, 83) * 0.08),
    }
end

function MapParchment.stains(w, h, seed)
    local hash = Ink.hash
    local out = {}
    for k = 1, 4 do
        out[k] = {
            hash(seed, 90, k) * w,
            hash(seed, 91, k) * h,
            40 + hash(seed, 92, k) * math.min(170, w * 0.12),
            k <= 3 and (0.55 + hash(seed, 93, k) * 0.45) or 0,
        }
    end
    return out
end

function MapParchment.sheet(w, h, seed)
    if not MapParchment.ensure() then return nil end
    w, h = math.max(8, math.floor(w)), math.max(8, math.floor(h))
    seed = math.floor(seed or 0)
    local key = w .. "x" .. h .. ":" .. seed
    if cache[key] then return cache[key] end

    love.graphics.push("all")
    love.graphics.setScissor()
    love.graphics.origin()
    send(genShader, "size", { w, h })
    send(genShader, "seed", seed % 997)
    send(genShader, "folds", MapParchment.folds(w, h, seed))
    send(genShader, "stains", unpack(MapParchment.stains(w, h, seed)))
    send(genShader, "paper_light", rgb(Ink.PAPER_LIGHT))
    send(genShader, "paper_base", rgb(Ink.PAPER))
    send(genShader, "paper_dark", rgb(Ink.PAPER_DARK))
    send(genShader, "rim_color", rgb(Ink.PAPER_RIM))
    local s = { color = render(w, h, 0), relief = render(w, h, 1), w = w, h = h }
    love.graphics.pop()

    cache[key] = s
    order[#order + 1] = key
    if #order > MapParchment.CACHE_MAX then
        local old = table.remove(order, 1)
        local o = cache[old]
        cache[old] = nil
        if o then
            o.color:release()
            o.relief:release()
        end
    end
    return s
end

function MapParchment.clear()
    for _, key in ipairs(order) do
        local o = cache[key]
        if o then
            o.color:release()
            o.relief:release()
        end
    end
    cache, order = {}, {}
end

function MapParchment.drawSheet(s, x, y)
    local c = MapParchment.SHADOW
    love.graphics.setColor(c[1], c[2], c[3], 0.28)
    love.graphics.draw(s.color, x + 8, y + 10)
    love.graphics.setColor(c[1], c[2], c[3], 0.5)
    love.graphics.draw(s.color, x + 3, y + 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(s.color, x, y)
end

function MapParchment.beginInk()
    if not ready then return false end
    local w, h = require("src.ui.UiScale").realDimensions()
    local target = love.graphics.getCanvas()
    if target then w, h = target:getDimensions() end
    if not inkCanvas or inkCanvas:getWidth() ~= w or inkCanvas:getHeight() ~= h then
        if inkCanvas then inkCanvas:release() end
        inkCanvas = love.graphics.newCanvas(w, h)
        inkCanvas:setFilter("linear", "linear")
    end
    love.graphics.push("all")
    love.graphics.setCanvas(inkCanvas)
    love.graphics.clear(0, 0, 0, 0)
    return true
end

function MapParchment.fade(x, y, w, h, fromTop)
    love.graphics.push("all")
    love.graphics.setBlendMode("multiply", "premultiplied")
    for k = 0, h - 1 do
        local f = 1 - 0.9 * (1 - k / h)
        love.graphics.setColor(f, f, f, f)
        love.graphics.rectangle("fill", x, fromTop and (y + k) or (y + h - 1 - k), w, 1)
    end
    love.graphics.pop()
end

function MapParchment.endInk(s, x, y)
    love.graphics.pop()
    local x1, y1 = love.graphics.transformPoint(x, y)
    local x2, y2 = love.graphics.transformPoint(x + s.w, y + s.h)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setShader(inkShader)
    send(inkShader, "relief", s.relief)
    send(inkShader, "sheet", { x1, y1, x2 - x1, y2 - y1 })
    send(inkShader, "ink_px", { inkCanvas:getWidth(), inkCanvas:getHeight() })
    send(inkShader, "amp", MapParchment.RELIEF_AMP)
    send(inkShader, "wear", MapParchment.INK_WEAR)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(inkCanvas, 0, 0)
    love.graphics.pop()
end

return MapParchment
