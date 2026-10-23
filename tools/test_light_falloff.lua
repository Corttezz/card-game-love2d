local TK = require("tools.testkit")
local M = {}

local W, H = 1920, 1080
M.MAX_STEP = 2.5
M.MAX_RISE = 1.5
M.SLOPE_K = 2

local function patchDims(w, h)
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return w end
    love.graphics.getHeight = function() return h end
    love.graphics.getDimensions = function() return w, h end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
end

local function luma(d, x, y)
    local r, g, b = d:getPixel(x, y)
    return (0.299 * r + 0.587 * g + 0.114 * b) * 255
end

local function profile(d, cx, cy, dx, dy, len)
    local v = {}
    for k = 0, len do
        local x, y = math.floor(cx + dx * k + 0.5), math.floor(cy + dy * k + 0.5)
        if x < 0 or y < 0 or x >= W or y >= H then break end
        v[#v + 1] = luma(d, x, y)
    end
    local worst, rise = 0, 0
    for k = 2, #v do
        local st = v[k] - v[k - 1]
        local a, b = math.max(1, k - 6), math.min(#v, k + 5)
        local slope = math.abs(v[b] - v[a]) / math.max(1, b - a)
        worst = math.max(worst, math.abs(st) - M.SLOPE_K * slope)
        rise = math.max(rise, st)
    end
    return worst, rise, (v[1] or 0) - (v[#v] or 0)
end

local function lightmapPool(LightEngine, cv, x, y, r, sy, seed)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.62, 0.60, 0.56, 1)
    LightEngine.beginFrame({ 0.40, 0.42, 0.50 })
    LightEngine.submit({ x = x, y = y, radius = r, sy = sy, color = { 0.55, 0.70, 1.00 },
        intensity = 1.0, dither = true, ditherAmt = 0.28, levels = 8, seed = seed, z = 3 })
    LightEngine.composite(0, 0, W, H)
    love.graphics.setCanvas()
    return cv:newImageData()
end

local function emitPool(Lum, cv, x, y)
    love.graphics.setCanvas(cv)
    love.graphics.clear(0.10, 0.10, 0.12, 1)
    Lum.drawPool("highlands", "brazier", { gx = x, gy = y, flameH = 260, t = 1, seed = 5,
        capR = 1e9, alphaK = 1, tod = 1 })
    love.graphics.setCanvas()
    return cv:newImageData()
end

function M.run()
    local t = TK.new("Borda da luz: queda suave, sem degrau em bloco (1080p)")
    local LightEngine = require("engine.LightEngine")
    local Lum = require("engine.LuminaireEngine")
    local restore = patchDims(W, H)
    LightEngine.setEnabled(true)
    local cv = love.graphics.newCanvas(W, H)
    local ok, err = pcall(function()
        local cases = {
            { 960, 760, 300, 0.35, 3 }, { 701.6, 513.3, 160, 0.35, 11 },
            { 1500, 300, 90, 1.0, 7 }, { 400, 900, 420, 0.30, 23 },
        }
        for _, c in ipairs(cases) do
            local d = lightmapPool(LightEngine, cv, c[1], c[2], c[3], c[4], c[5])
            local tag = string.format("poca r=%d sy=%.2f", c[3], c[4])
            local rays = { { 1, 0, c[3] * 1.1 }, { -1, 0, c[3] * 1.1 },
                { 0, 1, c[3] * c[4] * 1.1 }, { 0.7071, 0.7071 * c[4], c[3] * 1.1 } }
            for ri, ray in ipairs(rays) do
                local worst, rise, drop = profile(d, c[1], c[2], ray[1], ray[2], ray[3])
                t:check(string.format("%s raio %d: degrau acima da rampa local %.2f <= %.1f", tag, ri, worst, M.MAX_STEP),
                    worst <= M.MAX_STEP)
                t:check(string.format("%s raio %d: queda monotona (subida %.2f <= %.1f)", tag, ri, rise, M.MAX_RISE),
                    rise <= M.MAX_RISE)
                t:check(string.format("%s raio %d: a poca aparece (centro - borda %.1f > 15)", tag, ri, drop),
                    drop > 15)
            end
            d:release()
        end
        local d = emitPool(Lum, cv, 960, 700)
        for ri, ray in ipairs({ { 1, 0, 260 }, { -1, 0, 260 }, { 0, 1, 120 } }) do
            local worst, rise, drop = profile(d, 960, 700, ray[1], ray[2], ray[3])
            t:check(string.format("poca emissiva raio %d: degrau %.2f <= %.1f", ri, worst, M.MAX_STEP), worst <= M.MAX_STEP)
            t:check(string.format("poca emissiva raio %d: queda monotona (subida %.2f)", ri, rise), rise <= M.MAX_RISE)
            t:check(string.format("poca emissiva raio %d: aparece (%.1f > 10)", ri, drop), drop > 10)
        end
        d:release()
    end)
    LightEngine.setEnabled(nil)
    cv:release()
    restore()
    t:check("sem erro" .. (ok and "" or (": " .. tostring(err))), ok)
    return t:done()
end

return M
