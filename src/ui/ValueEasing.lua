local ValueEasing = {}

function ValueEasing.tick(disp, key, target, dt, k)
    if not disp[key] then
        disp[key] = target
        return
    end
    k = k or 8
    local ease = 1 - math.exp(-k * dt)
    disp[key] = disp[key] + (target - disp[key]) * ease
    if math.abs(target - disp[key]) < 0.05 then
        disp[key] = target
    end
end

function ValueEasing.get(disp, key, target)
    return math.floor(disp[key] or target or 0)
end

function ValueEasing.snap(disp, key, value)
    disp[key] = value
end

return ValueEasing
