local ScreenShake = {}

local time = 0
local intensity = 0
local duration = 0

local jiggle = 0
local timer = 0

local activePush = false

local JIGGLE_DECAY_RATE = 5.0
local SHAKE_BASE = 1.0
local SHAKE_JIGGLE = 1.0
local CURSOR_PARALLAX = 0.0

local function userScreenshakeAmt()
    if _G.gameSettings and _G.gameSettings.screenshake then
        return _G.gameSettings.screenshake
    end
    return 1
end

function ScreenShake.trigger(i, d)
    intensity = math.max(intensity, i or 6)
    duration = math.max(duration, d or 0.22)
    time = duration
    jiggle = jiggle + math.min(1.0, (i or 6) * 0.12)
end

function ScreenShake.jiggle(amt)
    jiggle = jiggle + (amt or 0.5)
    if jiggle > 4 then jiggle = 4 end
end

function ScreenShake.update(dt)
    timer = timer + dt
    if time > 0 then
        time = math.max(0, time - dt)
        if time == 0 then
            intensity = 0
            duration = 0
        end
    end
    if jiggle > 0 then
        jiggle = jiggle * (1 - JIGGLE_DECAY_RATE * dt)
        if jiggle < 0.01 then jiggle = 0 end
    end
end

function ScreenShake.computeOffsets()
    local userAmt = userScreenshakeAmt()
    if userAmt <= 0 then return 0, 0, 0 end

    local lx, ly = 0, 0
    if time > 0 then
        local t = time / math.max(0.001, duration)
        local mag = intensity * t * userAmt
        lx = (love.math.random() - 0.5) * 2 * mag
        ly = (love.math.random() - 0.5) * 2 * mag
    end

    local shakeAmt = SHAKE_BASE * userAmt
    local jamp = jiggle * SHAKE_JIGGLE * userAmt

    local rot = (0.001 * math.sin(0.3 * timer)
               + 0.002 * jamp * math.sin(39.913 * timer)) * shakeAmt

    local sx = shakeAmt * (
        2.5 * math.sin(0.913 * timer)
      + 1.6 * jamp * math.sin(19.913 * timer)
    )

    local sy = shakeAmt * (
        2.5 * math.sin(0.952 * timer)
      + 1.6 * jamp * math.sin(21.913 * timer)
    )

    return lx + sx, ly + sy, rot
end

function ScreenShake.push()
    local dx, dy, dr = ScreenShake.computeOffsets()
    if dx ~= 0 or dy ~= 0 or dr ~= 0 then
        love.graphics.push()
        local w, h = love.graphics.getDimensions()
        love.graphics.translate(w * 0.5 + dx, h * 0.5 + dy)
        love.graphics.rotate(dr)
        love.graphics.translate(-w * 0.5, -h * 0.5)
        activePush = true
    else
        activePush = false
    end
end

function ScreenShake.pop()
    if activePush then
        love.graphics.pop()
        activePush = false
    end
end

function ScreenShake.isActive()
    return time > 0 or jiggle > 0.01
end

function ScreenShake.getState()
    return { time = time, intensity = intensity, jiggle = jiggle, timer = timer }
end

function ScreenShake.install()
    _G.triggerShake = ScreenShake.trigger
    _G.jiggleScreen = ScreenShake.jiggle
end

return ScreenShake
