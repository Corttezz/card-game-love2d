local CastleDrift = {}

CastleDrift.SIGN = -1
CastleDrift.STEP = 0.025
CastleDrift.MAX = 0.035
CastleDrift.KEEP = 0.45
CastleDrift.FADE_FROM = 0.45
CastleDrift.FADE_TO = 0.8

local st = { from = 0, to = 0, z0 = 0, len = 1 }

local function smooth(k)
    k = math.min(1, math.max(0, k))
    return k * k * (3 - 2 * k)
end

function CastleDrift.raw(camZ)
    return st.from + (st.to - st.from) * smooth((camZ - st.z0) / st.len)
end

function CastleDrift.target()
    return st.to
end

function CastleDrift.pick(dir, camZ, len, toCenter)
    local cur = CastleDrift.raw(camZ)
    local to = 0
    if not toCenter then
        local d = (dir or 0) > 0 and 1 or ((dir or 0) < 0 and -1 or 0)
        to = math.min(CastleDrift.MAX, math.max(-CastleDrift.MAX,
            cur * CastleDrift.KEEP + CastleDrift.SIGN * d * CastleDrift.STEP))
    end
    st.from, st.to, st.z0, st.len = cur, to, camZ, math.max(1e-3, len or 1)
end

function CastleDrift.reset()
    st.from, st.to, st.z0, st.len = 0, 0, 0, 1
end

function CastleDrift.envelope(progress)
    return 1 - smooth((progress - CastleDrift.FADE_FROM) / (CastleDrift.FADE_TO - CastleDrift.FADE_FROM))
end

function CastleDrift.offset(camZ, progress, w)
    return CastleDrift.raw(camZ) * CastleDrift.envelope(progress) * w
end

return CastleDrift
