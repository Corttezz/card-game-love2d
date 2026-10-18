local Debug = require("src.core.Debug")

local ShadowEngine = {}

local frame = {
    sunX = 0, w = 1,
    len = 0.5,
    alpha = 0.26,
    stamp = -1,
    alphaK = 1,
}
function ShadowEngine.setAlphaK(k) frame.alphaK = k or 1 end
ShadowEngine.stats = { queued = 0 }

function ShadowEngine.setFrame(sunX, w, tod, luma)
    frame.sunX = sunX or 0
    frame.w = math.max(1, w or 1)
    frame.len = 0.55 + 0.45 * math.max(0, math.min(1, tod or 1))
    local l = math.max(0, math.min(1, luma or 1))
    frame.alpha = 0.15 + 0.15 * l
    frame.stamp = love.timer.getTime()
    ShadowEngine.stats.queued = 0
end

function ShadowEngine.isActive()
    return (love.timer.getTime() - frame.stamp) < 0.1
end

local function tipShift(px)
    return math.max(-1, math.min(1, (px - frame.sunX) / (frame.w * 0.5)))
end

function ShadowEngine.tipShiftAt(px)
    if not ShadowEngine.isActive() then return 0 end
    return tipShift(px)
end

local SMEAR = { { -1, 0 }, { 0.7, -0.5 }, { 0.35, 0.55 } }
local SCALE = 3
local scratch, batching, batchPrev
local soloAlphaK

local function ensureScratch()
    local W, H = love.graphics.getDimensions()
    local cw, ch = math.ceil(W / SCALE), math.ceil(H / SCALE)
    if not scratch or scratch:getWidth() ~= cw
       or scratch:getHeight() ~= ch then
        scratch = love.graphics.newCanvas(cw, ch, { format = "rgba8" })
        scratch:setFilter("nearest", "nearest")
    end
end

function ShadowEngine.beginBatch()
    if not ShadowEngine.isActive() or batching then return end
    ensureScratch()
    batchPrev = love.graphics.getCanvas()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setCanvas(scratch)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("lighten", "premultiplied")
    love.graphics.scale(1 / SCALE)
    batching = true
end

function ShadowEngine.endBatch()
    if not batching then return end
    batching = false
    love.graphics.pop()
    love.graphics.setCanvas(batchPrev)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(0, 0, 0, math.min(0.75, frame.alpha * frame.alphaK * (soloAlphaK or 1)))
    soloAlphaK = nil
    love.graphics.draw(scratch, 0, 0, 0, SCALE, SCALE)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
end

local NO_OPTS = {}

local profWarned = {}
local function footprint(opts, feetY, contentH, s, lenMul, margin)
    local baseK = opts.baseK or 0
    local riseK = opts.riseK
    if baseK <= 0 and not riseK then return feetY, 0, nil end
    if contentH <= 0 then
        local k = tostring(opts.baseK) .. "/" .. tostring(riseK)
        if not profWarned[k] then
            profWarned[k] = true
            Debug.warn("[ShadowEngine] perfil de pegada sem contentH (baseK="
                .. k .. ") — projetando a silhueta inteira")
        end
        return feetY, 0, nil
    end
    local baseH = baseK * contentH
    local riseH = riseK and (riseK * contentH) or (contentH - baseH)
    if riseH <= 0 then return false end
    local ay = feetY - baseH * s * 0.5
    return ay, baseH, ay + riseH * s * lenMul + margin
end

local function cutScissor(ay, yCut)
    local y0 = math.floor(ay / SCALE)
    love.graphics.setScissor(0, y0, scratch:getWidth(),
        math.max(1, math.ceil(yCut / SCALE) - y0))
end

function ShadowEngine.sprite(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    opts = opts or NO_OPTS
    local iw, ih = img:getWidth(), img:getHeight()
    local pad = opts.footPad or 0
    local lenK = opts.lenK or 1
    local d = math.max(1.5, iw * s * 0.035)
    local ay, baseH, yCut = footprint(opts, feetY, ih - pad, s,
        frame.len * lenK, d)
    if not ay then return true end
    local solo = not batching
    if solo then ShadowEngine.beginBatch() end
    local shd = tipShift(feetX)
    if yCut then cutScissor(ay, yCut) end
    love.graphics.setColor(1, 1, 1, 1)
    for pi = 1, #SMEAR do
        love.graphics.draw(img,
            math.floor(feetX + SMEAR[pi][1] * d),
            math.floor(ay + SMEAR[pi][2] * d * 0.5), 0,
            s * 1.18 * (opts.flip or 1),
            -s * frame.len * lenK,
            iw / 2, ih - pad - baseH,
            -shd * 0.78, 0)
    end
    if yCut then love.graphics.setScissor() end
    if solo then ShadowEngine.endBatch() end
    return true
end

local silTint = { 1, 1, 1, 1 }
function ShadowEngine.silhouette(feetX, feetY, opts, drawFn)
    if not ShadowEngine.isActive() then return false end
    opts = opts or NO_OPTS
    local d = opts.smear or 4
    local lenK = opts.lenK or 1
    local ay, baseH, yCut = footprint(opts, feetY, opts.contentH or 0, 1,
        frame.len * lenK, d)
    if not ay then return true end
    local solo = not batching
    if solo then
        soloAlphaK = opts.alphaK
        ShadowEngine.beginBatch()
    end
    local shd = tipShift(feetX)
    local wK = opts.widthK or 1
    if yCut then cutScissor(ay, yCut) end
    for pi = 1, #SMEAR do
        love.graphics.push()
        love.graphics.translate(
            math.floor(feetX + SMEAR[pi][1] * d),
            math.floor(ay + SMEAR[pi][2] * d * 0.5))
        love.graphics.shear(shd * 0.78, 0)
        love.graphics.scale(1.18 * wK, -frame.len * lenK)
        if baseH > 0 then love.graphics.translate(0, baseH) end
        love.graphics.setColor(silTint)
        drawFn(silTint)
        love.graphics.pop()
    end
    if yCut then love.graphics.setScissor() end
    if solo then ShadowEngine.endBatch() end
    return true
end

local squeue, squeueN = {}, 0
function ShadowEngine.queue(img, feetX, feetY, s, opts)
    if not img or not ShadowEngine.isActive() then return false end
    squeueN = squeueN + 1
    ShadowEngine.stats.queued = squeueN
    local q = squeue[squeueN]
    if not q then q = {}; squeue[squeueN] = q end
    q.img, q.x, q.y, q.s, q.o = img, feetX, feetY, s, opts
    return true
end

function ShadowEngine.flush()
    if squeueN == 0 then return end
    ShadowEngine.beginBatch()
    for i = 1, squeueN do
        local q = squeue[i]
        ShadowEngine.sprite(q.img, q.x, q.y, q.s, q.o)
        q.img, q.o = nil, nil
    end
    squeueN = 0
    ShadowEngine.endBatch()
end

return ShadowEngine
