local Debug = require("src.core.Debug")

local LightEngine = {}

LightEngine.SCALE = 4
LightEngine.COVER_ERODE_PX = 0
LightEngine.POOL_WOBBLE = 0.14
LightEngine.debugAmbientScale = 1
LightEngine.debugNoLights = false

local MAX_LIGHTS = 28
local MAX_MICRO  = 64

local canvas
local whiteImg
local microImg
local shader
local occShader
local coverShader
local coverCanvas
local softCanvas
local maskCanvas
local shaderOk = nil

local queue, microQueue, occQueue = {}, {}, {}
local pool = { e = {}, m = {}, ne = 0, nm = 0, lights = {}, entries = {}, fc = { 0, 0, 0 }, ms = { 1, 1 }, white = { 1, 1, 1 }, ls = { 1, 1 } }
local frameActive = false
local ambient = { 1, 1, 1 }
local time = 0
local enabledOverride = nil

local MAX_OCC = 64

local function isEnabled()
    if enabledOverride ~= nil then return enabledOverride end
    local gs = _G.gameSettings
    if gs ~= nil and gs.lighting == false then return false end
    return true
end

function LightEngine.setEnabled(v) enabledOverride = v end
function LightEngine.isEnabled() return isEnabled() end

local function lumaOf(c) return 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3] end

function LightEngine.ambientLuma()
    if not isEnabled() then return 1 end
    return lumaOf(ambient)
end

function LightEngine.ambientColor()
    return ambient[1], ambient[2], ambient[3]
end

function LightEngine.update(dt)
    time = time + dt
end

local function ensureResources()
    local W, H = love.graphics.getDimensions()
    local S = LightEngine.SCALE
    local cw, ch = math.ceil(W / S), math.ceil(H / S)
    if not canvas or canvas:getWidth() ~= cw or canvas:getHeight() ~= ch then
        canvas = love.graphics.newCanvas(cw, ch, { format = "rgba8" })
        canvas:setFilter("nearest", "nearest")
        coverCanvas = love.graphics.newCanvas(cw, ch, { format = "rgba8" })
        coverCanvas:setFilter("nearest", "nearest")
        local fmts = love.graphics.getCanvasFormats and love.graphics.getCanvasFormats() or {}
        softCanvas = love.graphics.newCanvas(cw, ch, { format = fmts.rgba16f and "rgba16f" or "rgba8" })
        softCanvas:setFilter("linear", "linear")
    end
    if not maskCanvas or maskCanvas:getWidth() ~= W or maskCanvas:getHeight() ~= H then
        maskCanvas = love.graphics.newCanvas(W, H, { format = "rgba8" })
        maskCanvas:setFilter("nearest", "nearest")
    end
    if not whiteImg then
        local d = love.image.newImageData(2, 2)
        d:mapPixel(function() return 1, 1, 1, 1 end)
        whiteImg = love.graphics.newImage(d)
        whiteImg:setFilter("nearest", "nearest")
    end
    if not microImg then
        local d = love.image.newImageData(32, 32)
        d:mapPixel(function(px, py)
            local dx, dy = (px - 15.5) / 15.5, (py - 15.5) / 15.5
            local u = 1 - (dx * dx + dy * dy)
            if u <= 0 then return 0, 0, 0, 0 end
            return 1, 1, 1, math.min(1, 1.6 * u ^ 1.3)
        end)
        microImg = love.graphics.newImage(d)
        microImg:setFilter("linear", "linear")
    end
    if shaderOk == nil then
        local ok, sh = pcall(function()
            return love.graphics.newShader("shaders/light_dither.glsl")
        end)
        if ok and sh then
            shader = sh
            shaderOk = true
        else
            shaderOk = false
            Debug.warn("[LightEngine] shader light_dither falhou: " .. tostring(sh)
                .. " — luzes grandes caem no fallback de micro-sprite")
        end
        local ok2, sh2 = pcall(function()
            return love.graphics.newShader("shaders/occluder.glsl")
        end)
        if ok2 and sh2 then occShader = sh2 end
        local ok3, sh3 = pcall(function()
            return love.graphics.newShader("shaders/light_cover.glsl")
        end)
        if ok3 and sh3 then
            coverShader = sh3
        else
            Debug.warn("[LightEngine] shader light_cover falhou: " .. tostring(sh3))
        end
    end
end

function LightEngine.beginFrame(amb)
    if not isEnabled() or not amb then
        frameActive = false
        return
    end
    local k = LightEngine.debugAmbientScale
    ambient[1] = math.min(1, (amb[1] or 1) * k)
    ambient[2] = math.min(1, (amb[2] or 1) * k)
    ambient[3] = math.min(1, (amb[3] or 1) * k)
    for i = #queue, 1, -1 do queue[i] = nil end
    for i = #microQueue, 1, -1 do microQueue[i] = nil end
    for i = #occQueue, 1, -1 do occQueue[i] = nil end
    pool.ne, pool.nm = 0, 0
    frameActive = true
end

function LightEngine.submit(spec)
    if not frameActive or LightEngine.debugNoLights then return end
    local inten = spec.intensity or 1
    local radius = spec.radius or 100
    if spec.flicker == "fire" then
        local seed = (spec.seed or 0) % 1000
        local n = love.math.noise(time * 1.8, seed) * 0.7
            + love.math.noise(time * 8.0, seed + 37.2) * 0.3
        radius = radius * (0.88 + 0.24 * n)
        inten = inten * (0.85 + 0.15 * n)
    elseif spec.flicker == "pulse" then
        inten = inten * (0.88 + 0.12 * math.sin(time * 1.7 + (spec.seed or 0)))
    end
    pool.ne = pool.ne + 1
    local entry = pool.e[pool.ne] or {}
    pool.e[pool.ne] = entry
    entry.x, entry.y, entry.r = spec.x, spec.y, radius
    entry.color = spec.color or pool.white
    entry.i = inten
    entry.dither = spec.dither and 1 or 0
    entry.ditherAmt = spec.ditherAmt or 1.0
    entry.levels = spec.levels or 4
    entry.z = spec.z or -1
    entry.sy = spec.sy or 1
    entry.seed = ((spec.seed or (spec.x or 0) * 0.37 + (spec.y or 0) * 0.11) % 97) * 0.731
    if #queue < MAX_LIGHTS then
        queue[#queue + 1] = entry
    else
        local wi, ww = nil, entry.r * entry.i
        for qi, q in ipairs(queue) do
            local qw = q.r * q.i
            if qw < ww then wi, ww = qi, qw end
        end
        if wi then queue[wi] = entry end
    end
end

function LightEngine.submitMicro(x, y, radius, color, intensity, z, bodyOnly)
    if not frameActive or LightEngine.debugNoLights then return end
    if #microQueue >= MAX_MICRO then return end
    pool.nm = pool.nm + 1
    local m = pool.m[pool.nm] or { micro = true }
    pool.m[pool.nm] = m
    m.x, m.y, m.r = x, y, radius or 8
    m.color, m.i = color or pool.white, intensity or 1
    m.z = z or -1
    m.bodyOnly = bodyOnly and true or nil
    microQueue[#microQueue + 1] = m
end

function LightEngine.submitOccluder(o)
    if not frameActive then return end
    if #occQueue >= MAX_OCC then return end
    occQueue[#occQueue + 1] = o
end

function LightEngine.tintCompensate(r, g, b)
    if not frameActive then return r, g, b end
    local k = math.min(1 / 0.55, 1 / math.max(0.55, lumaOf(ambient)))
    return math.min(1, r * k), math.min(1, g * k), math.min(1, b * k)
end

function LightEngine._entryOrder(a, b)
    if a.z ~= b.z then return a.z > b.z end
    return (a.occ and 0 or 1) < (b.occ and 0 or 1)
end

local LS = { sh = nil, bm = nil }
local function useShader(sh)
    if LS.sh ~= sh then
        love.graphics.setShader(sh)
        LS.sh = sh
    end
end
local function useBlend(m)
    if LS.bm ~= m then
        love.graphics.setBlendMode(m, "alphamultiply")
        LS.bm = m
    end
end

local function drawOccluder(e, S, cr, cg, cb)
    useBlend("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    if occShader then
        useShader(occShader)
        local fc = pool.fc
        if LS.fr ~= cr or LS.fg ~= cg or LS.fb ~= cb then
            fc[1], fc[2], fc[3] = cr, cg, cb
            occShader:send("flatColor", fc)
            LS.fr, LS.fg, LS.fb = cr, cg, cb
        end
    else
        useShader(nil)
        love.graphics.setColor(cr, cg, cb, 1)
    end
    local d = e.cover and S * 0.375 or 0
    local r0 = e.cover and -1 or 0
    for oy = r0, -r0 do
        for ox = r0, -r0 do
            if e.fn then
                love.graphics.push()
                love.graphics.scale(1 / S)
                love.graphics.translate(ox * d, oy * d)
                e.fn()
                love.graphics.pop()
            else
                love.graphics.draw(e.img, (e.x + ox * d) / S, (e.y + oy * d) / S, e.rot or 0,
                    (e.sx or 1) / S, (e.sy or e.sx or 1) / S,
                    e.ox or 0, e.oy or 0)
            end
        end
    end
end

local function drawLight(e, S, snap)
    local mw = microImg and microImg:getWidth() or 32
    local ww = whiteImg and whiteImg:getWidth() or 2
    local lx, ly = e.x / S, e.y / S
    if snap then lx, ly = math.floor(lx), math.floor(ly) end
    useBlend("add")
    if e.micro or not shaderOk then
        useShader(nil)
        local sc = (e.r * 2 / S) / mw
        love.graphics.setColor(e.color[1] * e.i, e.color[2] * e.i,
            e.color[3] * e.i, 1)
        love.graphics.draw(microImg, lx, ly, 0, sc, sc * (e.micro and 1 or (e.sy or 1)), mw / 2, mw / 2)
        return
    end
    if LS.sh ~= shader then
        useShader(shader)
        shader:send("wobbleK", LightEngine.POOL_WOBBLE)
        LS.gain = nil
    end
    local r, g, b = e.color[1] * e.i, e.color[2] * e.i, e.color[3] * e.i
    local gn = math.max(1, r, g, b)
    if LS.gain ~= gn then
        shader:send("gain", gn)
        LS.gain = gn
    end
    local wf = (e.sy or 1) < 0.9 and 0.5 or 0
    love.graphics.setColor(r / gn, g / gn, b / gn, wf + math.min(1, math.max(0, (e.seed or 0) / 71)) * 0.49)
    local sc = (e.r * 2 / S) / ww
    love.graphics.draw(whiteImg, lx, ly, 0, sc, sc * (e.sy or 1), ww / 2, ww / 2)
end

local function drawEntries(entries, target, mode, useCover)
    local S = LightEngine.SCALE
    love.graphics.setCanvas(target)
    if mode == "soft" then
        love.graphics.clear(0, 0, 0, 0)
    else
        love.graphics.clear(ambient[1], ambient[2], ambient[3], 1)
    end
    love.graphics.setShader()
    love.graphics.setBlendMode("add", "alphamultiply")
    LS.sh, LS.bm, LS.fr = nil, "add", nil
    local n = #entries
    local i = 1
    while i <= n do
        local e = entries[i]
        if not e.occ and mode ~= "hard" then
            local j = i
            while j + 1 <= n and not entries[j + 1].occ do j = j + 1 end
            for pass = 1, 2 do
                for q = i, j do
                    local l = entries[q]
                    local isMicro = (l.micro or not shaderOk) and true or false
                    if (pass == 1) == (not isMicro)
                       and not (l.micro and l.bodyOnly and useCover and mode ~= "all") then
                        drawLight(l, S, mode == "all")
                    end
                end
            end
            i = j + 1
        else
            i = i + 1
        end
        if e.occ then
            if e.cover and useCover and mode ~= "all" then
            elseif mode == "soft" then
                if e.hitL then drawOccluder(e, S, 0, 0, 0) end
            else
                local cr, cg, cb = ambient[1], ambient[2], ambient[3]
                if e.flatColor then
                    cr, cg, cb = e.flatColor[1], e.flatColor[2], e.flatColor[3]
                elseif e.lift then
                    cr = math.min(1, cr * e.lift)
                    cg = math.min(1, cg * e.lift)
                    cb = math.min(1, cb * e.lift)
                end
                drawOccluder(e, S, cr, cg, cb)
            end
        end
    end
    love.graphics.setShader()
    love.graphics.setBlendMode("add", "alphamultiply")
    LS.sh, LS.bm = nil, "add"
end

function LightEngine.composite(x, y, w, h)
    if not frameActive then return end
    frameActive = false
    if lumaOf(ambient) > 0.985 and ambient[1] > 0.97 and ambient[2] > 0.97
       and ambient[3] > 0.97 and #queue == 0 and #microQueue == 0 then
        return
    end
    ensureResources()

    local prevCanvas = love.graphics.getCanvas()
    local S = LightEngine.SCALE

    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setShader()

    local lights, entries = pool.lights, pool.entries
    for i = #lights, 1, -1 do lights[i] = nil end
    for i = #entries, 1, -1 do entries[i] = nil end
    for _, l in ipairs(queue) do lights[#lights + 1] = l end
    for _, m in ipairs(microQueue) do lights[#lights + 1] = m end
    for _, l in ipairs(lights) do entries[#entries + 1] = l end
    local nCover = 0
    for _, o in ipairs(occQueue) do
        local hit = false
        for _, l in ipairs(lights) do
            if l.z > o.z then
                local cx2 = math.max(o.bx, math.min(l.x, o.bx + o.w))
                local cy2 = math.max(o.by, math.min(l.y, o.by + o.h))
                local dx, dy = l.x - cx2, l.y - cy2
                if dx * dx + dy * dy <= l.r * l.r then hit = true; break end
            end
        end
        o.hitL = hit
        if hit or o.lift or o.flatColor then
            o.occ = true
            entries[#entries + 1] = o
            if o.cover then nCover = nCover + 1 end
        end
    end
    table.sort(entries, LightEngine._entryOrder)

    local useCover = nCover > 0 and coverShader ~= nil
    if coverShader then
        drawEntries(entries, canvas, "hard", useCover)
        drawEntries(entries, softCanvas, "soft", useCover)
    else
        drawEntries(entries, canvas, "all", false)
    end
    if useCover then
        drawEntries(entries, coverCanvas, "all", true)
        love.graphics.setCanvas(maskCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setBlendMode("alpha", "alphamultiply")
        love.graphics.setColor(1, 1, 1, 1)
        if occShader then
            love.graphics.setShader(occShader)
            occShader:send("flatColor", pool.white)
            LS.fr = nil
        end
        for _, e in ipairs(entries) do
            if e.occ and e.cover then
                if e.fn then
                    e.fn()
                else
                    love.graphics.draw(e.img, e.x, e.y, e.rot or 0, e.sx or 1, e.sy or e.sx or 1, e.ox or 0, e.oy or 0)
                end
            end
        end
        love.graphics.setShader()
    end

    love.graphics.setCanvas(prevCanvas)
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor(x, y, w, h)
    if coverShader then
        love.graphics.setShader(coverShader)
        coverShader:send("softLm", softCanvas)
        coverShader:send("coverOn", useCover and 1 or 0)
        local ls = pool.ls
        ls[1], ls[2] = softCanvas:getWidth(), softCanvas:getHeight()
        coverShader:send("lmSize", ls)
    end
    if useCover then
        coverShader:send("occLm", coverCanvas)
        coverShader:send("occMask", maskCanvas)
        local ms = pool.ms
        ms[1], ms[2] = maskCanvas:getWidth(), maskCanvas:getHeight()
        coverShader:send("maskSize", ms)
        coverShader:send("erodePx", LightEngine.COVER_ERODE_PX)
    end
    love.graphics.draw(canvas, 0, 0, 0, S, S)
    love.graphics.setShader()

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function LightEngine._lastEntry() return queue[#queue] end
function LightEngine._entryAt(i) return queue[i] end
function LightEngine.queued() return #queue end
function LightEngine._maskCanvas() return maskCanvas end
function LightEngine.microQueued() return #microQueue end
function LightEngine._microAt(i) return microQueue[i] end

return LightEngine
