local Debug = require("src.core.Debug")

local Easing = {}

function Easing.linear(t) return t end

function Easing.smooth(t)
    return t * t * (3 - 2 * t)
end

function Easing.easeIn(t)  return t * t end
function Easing.easeOut(t) return 1 - (1 - t) * (1 - t) end

function Easing.easeInOut(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - 2 * (1 - t) * (1 - t)
end

function Easing.outQuart(t)
    local u = 1 - t
    return 1 - u * u * u * u
end

function Easing.bounce(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

function Easing.elastic(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) + 1
end

function Easing.backOut(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local u = t - 1
    return 1 + c3 * u * u * u + c1 * u * u
end

local byName = {
    linear = Easing.linear,
    smooth = Easing.smooth,
    lerp = Easing.linear,
    easein = Easing.easeIn,  ease_in = Easing.easeIn,
    easeout = Easing.easeOut, ease_out = Easing.easeOut,
    easeinout = Easing.easeInOut, ease_in_out = Easing.easeInOut,
    outquart = Easing.outQuart, out_quart = Easing.outQuart,
    bounce = Easing.bounce,
    elastic = Easing.elastic,
    backout = Easing.backOut, back_out = Easing.backOut,
}

local warnedNames = {}

function Easing.apply(name, t)
    local fn = byName[name]
    if not fn then
        if name ~= nil and not warnedNames[name] then
            warnedNames[name] = true
            Debug.warn(("[Easing] nome desconhecido '%s' — caindo em smooth. "):format(tostring(name))
                .. "Validos: linear, smooth, lerp, easein, easeout, easeinout, "
                .. "outquart, bounce, elastic, backout (+ variantes com _).")
        end
        fn = Easing.smooth
    end
    return fn(t)
end

return Easing
