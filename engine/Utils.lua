local Utils = {}

function Utils.copy_table(t, keep_mt)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        out[k] = (type(v) == "table") and Utils.copy_table(v, keep_mt) or v
    end
    if keep_mt then setmetatable(out, getmetatable(t)) end
    return out
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Utils.ease_colour(c1, c2, t)
    return {
        Utils.lerp(c1[1] or 0, c2[1] or 0, t),
        Utils.lerp(c1[2] or 0, c2[2] or 0, t),
        Utils.lerp(c1[3] or 0, c2[3] or 0, t),
        Utils.lerp(c1[4] or 1, c2[4] or 1, t),
    }
end

function Utils.brighten_colour(c, factor)
    factor = factor or 1.2
    return {
        Utils.clamp((c[1] or 0) * factor, 0, 1),
        Utils.clamp((c[2] or 0) * factor, 0, 1),
        Utils.clamp((c[3] or 0) * factor, 0, 1),
        c[4] or 1,
    }
end

function Utils.darken_colour(c, factor)
    factor = factor or 0.8
    return Utils.brighten_colour(c, factor)
end

function Utils.pseudorandom_element(t)
    if not t or #t == 0 then return nil end
    return t[math.random(1, #t)]
end

function Utils.now()
    return love.timer.getTime()
end

function Utils.tlen(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

return Utils
