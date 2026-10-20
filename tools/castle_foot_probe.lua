local P = {}

P.BIOMES = { "fields", "highlands", "abyss", "frost", "marsh", "dusk" }
P.RES = { { 1920, 1080 }, { 1366, 768 }, { 3440, 1440 } }
P.TOP = 80

local DIR = "assets/sprites/world/"
local cache = {}

local function files(bid)
    local out = { DIR .. bid .. "_castle.png" }
    for _, sub in ipairs({ bid .. "_castle", bid .. "_castle_door" }) do
        for i = 0, 255 do
            local p = DIR .. "anim/" .. sub .. "/" .. i .. ".png"
            if not love.filesystem.getInfo(p) then break end
            out[#out + 1] = p
        end
    end
    return out
end

function P.scan(bid)
    if cache[bid] then return cache[bid] end
    local iw, ih, gap
    local list = files(bid)
    for _, f in ipairs(list) do
        local d = love.image.newImageData(f)
        local w, h = d:getDimensions()
        if not iw then
            iw, ih, gap = w, h, {}
            for c = 1, w do gap[c] = -1 end
        end
        assert(w == iw and h == ih, f .. " tamanho diferente do castelo base")
        for c = 1, w do
            for y = h - 1, 0, -1 do
                local _, _, _, a = d:getPixel(c - 1, y)
                if a > 0 then
                    local gg = h - 1 - y
                    if gg > gap[c] then gap[c] = gg end
                    break
                end
            end
        end
        d:release()
    end
    local n = iw
    local left, right = {}, {}
    local m = math.huge
    for c = 1, n do
        if gap[c] >= 0 then m = math.min(m, gap[c]) end
        left[c] = m
    end
    m = math.huge
    for c = n, 1, -1 do
        if gap[c] >= 0 then m = math.min(m, gap[c]) end
        right[c] = m
    end
    local filled = {}
    for c = 1, n do
        filled[c] = gap[c] >= 0 and math.max(left[c], right[c]) or -1
    end
    cache[bid] = { iw = iw, ih = ih, gap = filled, frames = #list }
    return cache[bid]
end

function P.crestAt(W, H, top, px)
    local h = H - top
    local crestY = math.floor(top + h * 0.40)
    local R = W * 1.6
    local dx = px - W / 2
    local under = R * R - dx * dx
    if under <= 0 then return top + h end
    return crestY + R - math.sqrt(under)
end

function P.exposure(ct, W, H, top, bid, crestFn)
    local f = P.scan(bid or ct.bid)
    local s = ct.s
    local x0 = ct.drawX or math.floor(ct.cx - f.iw * s / 2)
    local y0 = ct.drawY or math.floor(ct.baseY - f.ih * s)
    local worst, cols, at = -math.huge, 0, nil
    for c = 1, f.iw do
        local gc = f.gap[c]
        if gc >= 0 then
            local foot = y0 + (f.ih - gc) * s
            local xa, xb = x0 + (c - 1) * s, x0 + c * s
            local k = crestFn and math.max(crestFn(xa), crestFn(xb))
                or math.max(P.crestAt(W, H, top, xa), P.crestAt(W, H, top, xb))
            local above = k - foot
            if above > 0 then cols = cols + 1 end
            if above > worst then worst, at = above, c end
        end
    end
    return worst, cols, at
end

return P
