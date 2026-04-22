-- engine/Easing.lua
-- Funções de easing reutilizáveis. Formato: f(t in [0,1]) → [0,1].
-- Um único namespace pra todos os tweens (Event.ease, Moveable.juice,
-- animações ad-hoc). Consolidação do antigo src/ui/Animation.lua:Easing.
--
-- Uso:
--   local Easing = require("engine.Easing")
--   local y = Easing.smooth(progress)
--   local y = Easing.apply("smooth", progress)  -- lookup por nome

local Easing = {}

function Easing.linear(t) return t end

-- Ease-in-out cúbico (alias "smooth"). Suave no começo e no fim.
function Easing.smooth(t)
    return t * t * (3 - 2 * t)
end

function Easing.easeIn(t)  return t * t end
function Easing.easeOut(t) return 1 - (1 - t) * (1 - t) end

function Easing.easeInOut(t)
    if t < 0.5 then return 2 * t * t end
    return 1 - 2 * (1 - t) * (1 - t)
end

-- Quad out (padrão do CombatAnimationSystem legado, mantido pra compat).
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

-- Back-out (carta passa do destino e volta). Feel de "settle" Balatro.
function Easing.backOut(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    local u = t - 1
    return 1 + c3 * u * u * u + c1 * u * u
end

-- Lookup por nome (string). Default: smooth.
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

function Easing.apply(name, t)
    local fn = byName[name] or Easing.smooth
    return fn(t)
end

return Easing
