local HallAnim = {}

local FLAME_LUMA = 0.50
local LAVA_LUMA  = 0.45
local FLAME_FRAMES = 8
local FLOW_PERIOD  = 24
local FLOW_FPS     = 14
local FLAME_FPS    = 10

local function luma(r, g, b) return 0.3 * r + 0.59 * g + 0.11 * b end

local function hash1(n)
    local v = math.sin(n * 91.345 + 17.17) * 43758.5453
    return v - math.floor(v)
end

local function buildFlame(src, r, palette)
    local x0, y0, w, h = r[1], r[2], r[3], r[4]
    local iw, ih = src:getWidth(), src:getHeight()
    local function get(x, y)
        if x < 0 or y < 0 or x >= iw or y >= ih then return 0, 0, 0, 0 end
        return src:getPixel(x, y)
    end
    local function isFlame(cr, cg, cb)
        if not palette then return luma(cr, cg, cb) > FLAME_LUMA end
        local R, G, B = math.floor(cr * 255 + 0.5), math.floor(cg * 255 + 0.5), math.floor(cb * 255 + 0.5)
        for _, c in ipairs(palette) do
            if c[1] == R and c[2] == G and c[3] == B then return true end
        end
        return false
    end
    local bg = {}
    for y = 0, h - 1 do
        local sr, sg, sb, n = 0, 0, 0, 0
        for x = 0, w - 1 do
            local cr, cg, cb = get(x0 + x, y0 + y)
            if not isFlame(cr, cg, cb) and luma(cr, cg, cb) <= FLAME_LUMA * 0.7 then
                sr, sg, sb, n = sr + cr, sg + cg, sb + cb, n + 1
            end
        end
        if n > 0 then bg[y] = { sr / n, sg / n, sb / n } else bg[y] = bg[y - 1] or { 0.1, 0.05, 0.05 } end
    end
    local atlas = love.image.newImageData(w * FLAME_FRAMES, h)
    for f = 0, FLAME_FRAMES - 1 do
        local ph = f / FLAME_FRAMES * 2 * math.pi
        for y = 0, h - 1 do
            local v = 1 - y / (h - 1)
            local dx = math.floor(math.sin(ph + y * 0.55) * 1.6 * v ^ 1.2 + 0.5)
            for x = 0, w - 1 do
                local dy = math.floor((math.sin(ph * 2 + x * 0.9) * 0.5 + 0.5) * 1.6 * v + 0.5)
                local sr, sg, sb = get(x0 + x - dx, y0 + y + dy)
                local ox, oy = f * w + x, y
                if isFlame(sr, sg, sb) then
                    atlas:setPixel(ox, oy, sr, sg, sb, 1)
                else
                    local cr, cg, cb = get(x0 + x, y0 + y)
                    if isFlame(cr, cg, cb) then
                        local c = bg[y]
                        atlas:setPixel(ox, oy, c[1], c[2], c[3], 1)
                    end
                end
            end
        end
    end
    return atlas
end

local function buildFlow(src, r)
    local x0, y0, w, h = r[1], r[2], r[3], r[4]
    local atlas = love.image.newImageData(w * FLOW_PERIOD, h)
    local mask, phase = {}, {}
    for x = 0, w - 1 do
        phase[x] = math.floor(hash1(x0 + x) * FLOW_PERIOD)
        mask[x] = {}
        for y = 0, h - 1 do
            local cr, cg, cb = src:getPixel(x0 + x, y0 + y)
            mask[x][y] = luma(cr, cg, cb) > LAVA_LUMA
        end
    end
    for f = 0, FLOW_PERIOD - 1 do
        for x = 0, w - 1 do
            for y = 0, h - 1 do
                if mask[x][y] then
                    local v = ((y - f + phase[x]) % FLOW_PERIOD) / FLOW_PERIOD
                    local ox = f * w + x
                    if v < 0.16 then
                        atlas:setPixel(ox, y, 1.00, 0.88, 0.48, 0.45)
                    elseif v > 0.55 and v < 0.66 then
                        atlas:setPixel(ox, y, 0.55, 0.08, 0.02, 0.40)
                    end
                end
            end
        end
    end
    return atlas
end

local function toImage(data)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

function HallAnim.build(src, cfg)
    local anim = cfg.anim
    if not anim then return nil end
    local st = { flames = {}, flows = {}, shimmer = anim.shimmer or {} }
    if anim.flameFrames then
        for i, r in ipairs(cfg.flames) do
            st.flames[i] = { r = r, img = toImage(buildFlame(src, r, anim.flamePalette)), off = i * 3 }
        end
    end
    for i, r in ipairs(anim.flows or {}) do
        st.flows[i] = { r = r, img = toImage(buildFlow(src, r)), off = i * 7 }
    end
    if #st.shimmer > 0 then
        st.art = toImage(src)
    end
    st.quad = love.graphics.newQuad(0, 0, 1, 1, 1, 1)
    return st
end

function HallAnim.draw(st, tr, time)
    if not st then return end
    local s, ox, oy = tr.scale, tr.ox, tr.oy
    local q = st.quad
    love.graphics.setColor(1, 1, 1, 1)

    if st.art then
        local aw, ah = st.art:getDimensions()
        for _, r in ipairs(st.shimmer) do
            for y = r[2], r[2] + r[4] - 1 do
                local dx = math.floor(math.sin(time * 4.2 + y * 0.9) * 0.9
                    + math.sin(time * 2.3 + y * 0.37) * 0.4 + 0.5)
                if dx ~= 0 then
                    q:setViewport(r[1], y, r[3], 1, aw, ah)
                    love.graphics.draw(st.art, q, ox + (r[1] + dx) * s, oy + y * s, 0, s, s)
                end
            end
        end
    end

    for _, fl in ipairs(st.flames) do
        local r = fl.r
        local f = math.floor(time * FLAME_FPS + fl.off) % FLAME_FRAMES
        q:setViewport(f * r[3], 0, r[3], r[4], fl.img:getDimensions())
        love.graphics.draw(fl.img, q, ox + r[1] * s, oy + r[2] * s, 0, s, s)
    end

    for _, fw in ipairs(st.flows) do
        local r = fw.r
        local f = math.floor(time * FLOW_FPS + fw.off) % FLOW_PERIOD
        q:setViewport(f * r[3], 0, r[3], r[4], fw.img:getDimensions())
        love.graphics.draw(fw.img, q, ox + r[1] * s, oy + r[2] * s, 0, s, s)
    end
end

return HallAnim
