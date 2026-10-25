local CastleDrift = {}

CastleDrift.SIGN = -1
CastleDrift.KEEP_MAX = 0.05
CastleDrift.FADE_FROM = 0.45
CastleDrift.FADE_TO = 0.8
CastleDrift.INSET = 0.3
CastleDrift.MIN_REACH = 0.05
CastleDrift.WALK_K = 0.55
CastleDrift.FULL_TURN = 90
CastleDrift.BACK_P = -2.4
CastleDrift.REDUCED = { reach = 0.12 }

local st = { from = 0, to = 0, z0 = 0, len = 1, back = false }

local function smooth(k)
    k = math.min(1, math.max(0, k))
    return k * k * (3 - 2 * k)
end

local function reduced()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) and true or false
end

local function backCurve(k)
    local p = CastleDrift.BACK_P
    local u = 1 - k
    return 1 - u * u * (1 + p * k)
end

local function progressK(camZ)
    return math.min(1, math.max(0, (camZ - st.z0) / st.len))
end

function CastleDrift.raw(camZ)
    local k = progressK(camZ)
    if st.back then
        local b = reduced() and smooth(k) or backCurve(k)
        return st.from * (1 - b)
    end
    return st.from + (st.to - st.from) * smooth(k)
end

function CastleDrift.target()
    return st.to
end

function CastleDrift.turnK(deg)
    if deg == nil then return 1 end
    return math.min(1, math.max(0, deg / CastleDrift.FULL_TURN))
end

function CastleDrift.pick(dir, camZ, len, toCenter, walk, turnDeg)
    local cur = CastleDrift.raw(camZ)
    local to = 0
    if not toCenter then
        local d = (dir or 0) > 0 and 1 or ((dir or 0) < 0 and -1 or 0)
        to = CastleDrift.SIGN * d * (walk and CastleDrift.WALK_K or 1) * CastleDrift.turnK(turnDeg)
    end
    st.from, st.to, st.z0, st.len, st.back = cur, to, camZ, math.max(1e-3, len or 1), false
end

function CastleDrift.back(camZ, len)
    local cur = CastleDrift.raw(camZ)
    st.from, st.to, st.z0, st.len, st.back = cur, 0, camZ, math.max(1e-3, len or 1), true
end

function CastleDrift.reset()
    st.from, st.to, st.z0, st.len, st.back = 0, 0, 0, 1, false
end

function CastleDrift.envelope(progress)
    return 1 - smooth((progress - CastleDrift.FADE_FROM) / (CastleDrift.FADE_TO - CastleDrift.FADE_FROM))
end

function CastleDrift.reach(w, castleW)
    if reduced() then return CastleDrift.REDUCED.reach * w end
    return math.max(CastleDrift.MIN_REACH * w, w / 2 - CastleDrift.INSET * (castleW or 0))
end

function CastleDrift.offset(camZ, progress, w, castleW)
    local y = CastleDrift.raw(camZ)
    if y == 0 then return 0 end
    local px = y * CastleDrift.envelope(progress) * CastleDrift.reach(w, castleW)
    return px >= 0 and math.floor(px + 0.5) or -math.floor(-px + 0.5)
end

return CastleDrift
