-- engine/Utils.lua
-- Helpers genéricos portados/inspirados em balatro-source/functions/misc_functions.lua.
-- Sem dependências do Balatro (G global, etc) — só Lua puro + LÖVE.

local Utils = {}

-- Deep copy. `keep_mt=true` preserva metatables (útil pra clonar objetos OOP).
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

-- Clampa em [lo, hi].
function Utils.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Interpola RGBA. c1/c2 são tables {r,g,b,a}. Alpha default 1.
function Utils.ease_colour(c1, c2, t)
    return {
        Utils.lerp(c1[1] or 0, c2[1] or 0, t),
        Utils.lerp(c1[2] or 0, c2[2] or 0, t),
        Utils.lerp(c1[3] or 0, c2[3] or 0, t),
        Utils.lerp(c1[4] or 1, c2[4] or 1, t),
    }
end

-- factor > 1 brilha; factor < 1 escurece.
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

-- Pega elemento aleatório de array. Retorna nil se vazio.
-- (Sem seed dedicado por enquanto — usa math.random global.)
function Utils.pseudorandom_element(t)
    if not t or #t == 0 then return nil end
    return t[math.random(1, #t)]
end

-- Wall-clock seconds (substitui G.TIMERS.REAL do Balatro).
function Utils.now()
    return love.timer.getTime()
end

-- Comprimento de tabela genérico (não-array). Útil pra sources do AudioManager.
function Utils.tlen(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

return Utils
