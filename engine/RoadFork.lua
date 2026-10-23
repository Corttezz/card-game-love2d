local RoadFork = {}

RoadFork.BAND_K = 0.22
RoadFork.ALPHA_MIN = 0.02

local order = {}

local function active(a)
    return a.a > RoadFork.ALPHA_MIN and a.xR > a.xL
end

function RoadFork.partition(A, n, chosen, half, hard)
    for i = 1, n do
        local a = A[i]
        a.sL, a.sR, a.band = a.xL, a.xR, 0
        a.on = active(a)
    end
    local m = 0
    for i = 1, n do
        if A[i].on then
            m = m + 1
            order[m] = i
            local k = m
            while k > 1 and A[order[k - 1]].c > A[order[k]].c do
                order[k - 1], order[k] = order[k], order[k - 1]
                k = k - 1
            end
        end
    end
    for i = m + 1, #order do order[i] = nil end
    local ch = chosen and A[chosen] and A[chosen].on and chosen or nil
    if ch then
        local C = A[ch]
        for k = 1, m do
            local i = order[k]
            if i ~= ch then
                local a = A[i]
                if a.c < C.c then a.sR = math.min(a.sR, C.xL) else a.sL = math.max(a.sL, C.xR) end
            end
        end
    end
    local prev = nil
    for k = 1, m do
        local i = order[k]
        if i ~= ch then
            local b = A[i]
            if prev and b.sR > b.sL and prev.sR > b.sL then
                local ov = prev.sR - b.sL
                local mid = (prev.c + b.c) * 0.5
                mid = math.max(b.sL, math.min(prev.sR, mid))
                local bw = hard and 0 or math.min(ov, RoadFork.BAND_K * half)
                prev.sR = math.min(prev.sR, mid + bw * 0.5)
                b.sL = math.max(b.sL, mid - bw * 0.5)
                b.band = math.max(0, prev.sR - b.sL)
            end
            if b.sR > b.sL then prev = b end
        end
    end
    for k = 1, m do
        local a = A[order[k]]
        local dL, dR = true, true
        for q = 1, m do
            local o = A[order[q]]
            if o ~= a then
                if a.xL > o.xL and a.xL < o.xR then dL = false end
                if a.xR > o.xL and a.xR < o.xR then dR = false end
            end
        end
        a.dL, a.dR = dL, dR
    end
    return order, m
end

RoadFork.DECK_K = 1.45

function RoadFork.contiguous(A, ord, m, half)
    if m < 1 then return nil end
    local uL, uR, pa = math.huge, -math.huge, 0
    for k = 1, m do
        local a = A[ord[k]]
        if k > 1 and (a.xL > uR or a.c - A[ord[k - 1]].c > RoadFork.DECK_K * half) then return nil end
        uL, uR = math.min(uL, a.xL), math.max(uR, a.xR)
        pa = math.max(pa, a.a)
    end
    if m < 2 then return nil end
    return uL, uR, pa
end

function RoadFork.probeRow(fp, A, ord, m, arms, k, dv, hs, step)
    fp.rows = (fp.rows or 0) + 1
    fp.overlap = math.max(fp.overlap or 0, RoadFork.overlapPx(A, ord, m))
    for q = 1, m do
        local i = ord[q]
        local arm = arms[i]
        local C = arm.c
        if C[k + 1] and A[i].sR > A[i].sL then
            local dc = C[k + 1] - C[k]
            local along = math.sqrt(dc * dc + step * step)
            local ratio = (arm.L[k] / along) / (dv / step)
            local naive = (dv / along) / (dv / step)
            fp.minRatio = math.min(fp.minRatio or 1e9, ratio)
            fp.maxRatio = math.max(fp.maxRatio or 0, ratio)
            fp.minNaive = math.min(fp.minNaive or 1e9, naive)
            fp.maxSlope = math.max(fp.maxSlope or 0, math.abs(dc) / step)
        end
    end
end

function RoadFork.overlapPx(A, ord, m)
    local worst = 0
    for p = 1, m do
        local a = A[ord[p]]
        if a.sR > a.sL then
            for q = p + 1, m do
                local b = A[ord[q]]
                if b.sR > b.sL then
                    local ov = math.min(a.sR, b.sR) - math.max(a.sL, b.sL)
                    local allowed = math.max(a.band or 0, b.band or 0)
                    worst = math.max(worst, ov - allowed)
                end
            end
        end
    end
    return worst
end

return RoadFork
