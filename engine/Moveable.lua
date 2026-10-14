local Moveable = {}

function Moveable.initJuice(obj)
    obj.juice = obj.juice or {
        scale = 0,
        r = 0,
        scale_amt = 0,
        r_amt = 0,
        timer = 0,
        duration = 0.4,
    }
end

function Moveable.juice_up(obj, scale_mod, rot_mod)
    Moveable.initJuice(obj)
    if _G.gameSettings and _G.gameSettings.reducedMotion then
        return
    end
    scale_mod = scale_mod or 0.4
    if not rot_mod then
        local dir = (obj.juice._lastDir or 1) * -1
        obj.juice._lastDir = dir
        rot_mod = 0.6 * scale_mod * dir
    end
    obj.juice.scale_amt = scale_mod
    obj.juice.r_amt = rot_mod
    obj.juice.timer = 0
    obj.juice.duration = 0.4

    if obj.VT and obj.VT.scale then
        obj.VT.scale = math.max(0.01, (obj.T and obj.T.scale or 1) - 0.6 * scale_mod)
    end
end

function Moveable.hop_up(obj, px, duration)
    Moveable.initJuice(obj)
    if _G.gameSettings and _G.gameSettings.reducedMotion then return end
    obj.juice.hop_amt = px or 14
    obj.juice.hop_timer = 0
    obj.juice.hop_duration = duration or 0.32
end

function Moveable.swell_up(obj, scale_add, duration)
    Moveable.initJuice(obj)
    if _G.gameSettings and _G.gameSettings.reducedMotion then return end
    obj.juice.swell_amt = scale_add or 0.3
    obj.juice.swell_timer = 0
    obj.juice.swell_duration = duration or 0.45
end

function Moveable.shove_x(obj, px, duration)
    Moveable.initJuice(obj)
    if _G.gameSettings and _G.gameSettings.reducedMotion then return end
    if not px then
        local dir = (obj.juice._lastShoveDir or 1) * -1
        obj.juice._lastShoveDir = dir
        px = 20 * dir
    end
    obj.juice.shove_amt = px
    obj.juice.shove_timer = 0
    obj.juice.shove_duration = duration or 0.55
end

function Moveable.shoveOffset(obj)
    local j = obj.juice
    if not j or not j.shove_duration or not j.shove_timer
        or j.shove_timer >= j.shove_duration then return 0 end
    local t = j.shove_timer / j.shove_duration
    local amt = j.shove_amt or 0
    local k
    if t < 0.14 then
        local u = t / 0.14
        k = 1 - (1 - u) ^ 3
    elseif t < 0.42 then
        k = 1
    else
        local u = (t - 0.42) / 0.58
        k = math.cos(u * math.pi * 1.45) * (1 - u) ^ 1.3
    end
    return amt * k
end

function Moveable.hopOffset(obj)
    local j = obj.juice
    if not j or not j.hop_duration or not j.hop_timer
        or j.hop_timer >= j.hop_duration then return 0 end
    local t = j.hop_timer / j.hop_duration
    local amt = j.hop_amt or 0
    local k
    if t < 0.12 then
        local u = t / 0.12
        k = 1 - (1 - u) ^ 3
    elseif t < 0.45 then
        k = 1
    elseif t < 0.75 then
        local u = (t - 0.45) / 0.30
        k = 1 - u * u
    else
        local u = (t - 0.75) / 0.25
        k = 0.22 * math.sin(math.pi * u)
    end
    return -amt * k
end

function Moveable.swellFactor(obj)
    local j = obj.juice
    if not j or not j.swell_duration or not j.swell_timer
        or j.swell_timer >= j.swell_duration then return 1 end
    local t = j.swell_timer / j.swell_duration
    local env
    if t < 0.08 then
        local u = t / 0.08
        env = 1 - (1 - u) ^ 3
    elseif t < 0.55 then
        env = 1
    else
        env = (1 - (t - 0.55) / 0.45) ^ 2
    end
    return 1 + (j.swell_amt or 0) * env
end

function Moveable.updateJuice(obj, dt)
    local j = obj.juice
    if not j then return end
    if j.hop_duration and j.hop_timer and j.hop_timer < j.hop_duration then
        j.hop_timer = j.hop_timer + dt
    end
    if j.swell_duration and j.swell_timer and j.swell_timer < j.swell_duration then
        j.swell_timer = j.swell_timer + dt
    end
    if j.shove_duration and j.shove_timer and j.shove_timer < j.shove_duration then
        j.shove_timer = j.shove_timer + dt
    end
    if j.duration <= 0 or j.timer >= j.duration then
        j.scale, j.r = 0, 0
        return
    end
    j.timer = j.timer + dt
    local progress = j.timer / j.duration
    if progress >= 1 then
        j.scale, j.r = 0, 0
        return
    end

    local falloff_scale = (1 - progress) ^ 3
    local falloff_rot = (1 - progress) ^ 2

    j.scale = j.scale_amt * math.sin(50.8 * j.timer) * falloff_scale
    j.r = j.r_amt * math.sin(40.8 * j.timer) * falloff_rot
end

function Moveable.scaleFactor(obj)
    local j = obj.juice
    if not j or j.timer >= j.duration or j.duration <= 0 then return 1 end
    return 1 + j.scale
end

function Moveable.rotOffset(obj)
    local j = obj.juice
    if not j or j.timer >= j.duration or j.duration <= 0 then return 0 end
    return j.r
end

function Moveable.initTVT(obj, x, y, scale, rot)
    x = x or 0; y = y or 0; scale = scale or 1; rot = rot or 0
    obj.T = obj.T or { x = x, y = y, scale = scale, r = rot }
    obj.VT = obj.VT or { x = x, y = y, scale = scale, r = rot }
    obj.velocity = obj.velocity or { x = 0, y = 0, scale = 0, r = 0 }
end

local DAMP_XY    = 50
local DAMP_SCALE = 60
local DAMP_R     = 190
local DEFAULT_MAX_VEL_PER_FRAME = 70

function Moveable.updateTVT(obj, dt)
    if not obj.T or not obj.VT then return end
    obj.velocity = obj.velocity or { x = 0, y = 0, scale = 0, r = 0 }

    local exp_xy    = math.exp(-DAMP_XY    * dt)
    local exp_scale = math.exp(-DAMP_SCALE * dt)
    local exp_r     = math.exp(-DAMP_R     * dt)
    local max_vel   = (obj.MAX_VEL or DEFAULT_MAX_VEL_PER_FRAME) * dt * 60

    local dx = obj.T.x - obj.VT.x
    local dy = obj.T.y - obj.VT.y
    if math.abs(dx) > 0.01 or math.abs(dy) > 0.01
       or math.abs(obj.velocity.x) > 0.01 or math.abs(obj.velocity.y) > 0.01 then
        obj.velocity.x = exp_xy * obj.velocity.x + (1 - exp_xy) * dx * 35 * dt
        obj.velocity.y = exp_xy * obj.velocity.y + (1 - exp_xy) * dy * 35 * dt

        local mag2 = obj.velocity.x * obj.velocity.x + obj.velocity.y * obj.velocity.y
        if mag2 > max_vel * max_vel and mag2 > 0 then
            local mag = math.sqrt(mag2)
            obj.velocity.x = max_vel * obj.velocity.x / mag
            obj.velocity.y = max_vel * obj.velocity.y / mag
        end
        obj.VT.x = obj.VT.x + obj.velocity.x
        obj.VT.y = obj.VT.y + obj.velocity.y
    end

    local des_scale = obj.T.scale
    if obj.zoom and obj.states then
        if obj.states.drag and obj.states.drag.is then
            des_scale = des_scale + 0.10
        end
        if obj.states.hover and obj.states.hover.is then
            des_scale = des_scale + 0.05
        end
    end

    local ds = des_scale - obj.VT.scale
    if math.abs(ds) > 0.0005 or math.abs(obj.velocity.scale) > 0.001 then
        obj.velocity.scale = exp_scale * obj.velocity.scale + (1 - exp_scale) * ds
        obj.VT.scale = obj.VT.scale + obj.velocity.scale
    end

    local dr = obj.T.r - obj.VT.r
    if math.abs(dr) > 0.0005 or math.abs(obj.velocity.r) > 0.001 then
        obj.velocity.r = exp_r * obj.velocity.r + (1 - exp_r) * dr
        obj.VT.r = obj.VT.r + obj.velocity.r
    end
end

function Moveable.simpleEaseTVT(obj, dt, k)
    if not obj.T or not obj.VT then return end
    k = k or 12
    local ease = 1 - math.exp(-k * dt)
    obj.VT.x = obj.VT.x + (obj.T.x - obj.VT.x) * ease
    obj.VT.y = obj.VT.y + (obj.T.y - obj.VT.y) * ease
    obj.VT.scale = obj.VT.scale + (obj.T.scale - obj.VT.scale) * ease
    obj.VT.r = obj.VT.r + (obj.T.r - obj.VT.r) * ease
end

function Moveable.snap(obj)
    if obj.T and obj.VT then
        obj.VT.x, obj.VT.y = obj.T.x, obj.T.y
        obj.VT.scale, obj.VT.r = obj.T.scale, obj.T.r
        if obj.velocity then
            obj.velocity.x, obj.velocity.y = 0, 0
            obj.velocity.scale, obj.velocity.r = 0, 0
        end
    end
end

return Moveable
