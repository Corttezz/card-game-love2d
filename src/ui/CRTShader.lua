local Debug = require("src.core.Debug")

local CRTShader = {}

local shader
local sceneCanvas
local strength = 0.75
local enabled = true

local power = 1
local powerAnim = nil
local powerDirection = 1

local glitchAmount = 0
local glitchBandY = 0.5
local glitchTimer = 3.0
local glitchActive = 0

local degradeAmount = 0
local degradeTimer = 6.0
local degradeActive = 0
local degradeDur = 1.0
local degradePeak = 1.0
local calmRect = { 0, 0, 0, 0 }
local calmRect2 = { 0, 0, 0, 0 }
local caScale = 1

CRTShader.BEZEL_PX = 16
CRTShader.CURV = { 0.068, 0.089 }

CRTShader.VARIANTS = { "atual", "antigo", "A_bezel_curvatura", "B_mascara_aperture", "C_halation_bloom",
    "D_convergencia_bordas", "E_vinheta_desfoque_bordas", "F_vidro_reflexo", "G_forte_combinado",
    "H_moldura_segue_imagem" }
CRTShader.variant = "atual"

local function pathOf(id)
    if not id or id == "atual" then return "shaders/crt.glsl" end
    return "tools/crt_variants/" .. id .. ".glsl"
end

function CRTShader.useVariant(id)
    local path = pathOf(id)
    if not love.filesystem.getInfo(path) then
        Debug.warn("[CRTShader] variante inexistente: " .. tostring(id))
        return false
    end
    local ok, s = pcall(love.graphics.newShader, path)
    if not ok then
        Debug.warn("[CRTShader] falha ao carregar " .. path .. ": " .. tostring(s))
        return false
    end
    if shader and shader ~= s then shader:release() end
    shader = s
    CRTShader.variant = id or "atual"
    return true
end

function CRTShader.cycleVariant(dir)
    local list, cur = CRTShader.VARIANTS, 1
    for i, id in ipairs(list) do if id == CRTShader.variant then cur = i end end
    local nxt = (cur - 1 + (dir or 1)) % #list + 1
    CRTShader.useVariant(list[nxt])
    return CRTShader.variant
end

local function send(name, v)
    if shader:hasUniform(name) then shader:send(name, v) end
end

function CRTShader.load()
    local ok, s = pcall(love.graphics.newShader, "shaders/crt.glsl")
    if not ok then
        Debug.warn("[CRTShader] falha ao carregar shaders/crt.glsl: " .. tostring(s))
        shader = nil
        return false
    end
    shader = s
    local want = os.getenv("CARDGAME_CRT")
    if want and want ~= "" and require("src.core.Release").isDev() then CRTShader.useVariant(want) end
    sceneCanvas = love.graphics.newCanvas()
    sceneCanvas:setFilter("linear", "linear")
    return true
end

CRTShader.LEVELS = { "off", "low", "normal" }
CRTShader.LEVEL_STRENGTH = { off = 0, low = 0.35, normal = 0.75 }
local level = "normal"

function CRTShader.setLevel(name)
    if not CRTShader.LEVEL_STRENGTH[name] then
        Debug.warn("[CRTShader] nível desconhecido '" .. tostring(name) .. "' — usando normal")
        name = "normal"
    end
    level = name
    enabled = name ~= "off"
    strength = CRTShader.LEVEL_STRENGTH[name]
    return name
end

function CRTShader.getLevel()
    if not enabled then return "off" end
    return level == "off" and "normal" or level
end

function CRTShader.nextLevel(name, dir)
    local idx = 3
    for i, n in ipairs(CRTShader.LEVELS) do if n == name then idx = i end end
    idx = ((idx - 1 + (dir or 1)) % #CRTShader.LEVELS) + 1
    return CRTShader.LEVELS[idx]
end

function CRTShader.levelFromSettings(s)
    s = s or {}
    if s.crtLevel and CRTShader.LEVEL_STRENGTH[s.crtLevel] then return s.crtLevel end
    if s.crtShader == false then return "off" end
    return "normal"
end

function CRTShader.setEnabled(v)
    enabled = v and true or false
    if enabled then
        if level == "off" then level = "normal" end
        strength = CRTShader.LEVEL_STRENGTH[level]
    end
end

function CRTShader.isEnabled()
    return enabled
end

function CRTShader.toggle()
    enabled = not enabled
end

function CRTShader.setPower(p, dir)
    power = math.max(0, math.min(1, p or 1))
    if dir then powerDirection = dir end
end

function CRTShader.getPower() return power end
function CRTShader.isPowering() return powerAnim ~= nil end

local function animatePower(to, dur, cb)
    if not enabled or not shader then
        power = to
        if cb then cb() end
        return
    end
    local turningOff = to <= 0.01
    powerDirection = turningOff and -1 or 1
    powerAnim = { from = power, to = to, dur = math.max(0.05, dur or 0.8),
                  t = 0, cb = cb,
                  ease = turningOff and "outquad" or nil }
end

function CRTShader.powerOn(dur, cb)  animatePower(1, dur or 1.2, cb) end
function CRTShader.powerOff(dur, cb) animatePower(0, dur or 0.6, cb) end

function CRTShader.blip()
    if not enabled or not shader then return end
    powerAnim = { from = 1, to = 0.86, dur = 0.09, t = 0, cb = function()
        powerAnim = { from = 0.86, to = 1, dur = 0.14, t = 0 }
    end }
end

function CRTShader.jolt(dur)
    if not enabled or not shader then return end
    glitchActive = dur or 0.16
    glitchBandY = 0.35 + love.math.random() * 0.3
    glitchAmount = 1.0
end

function CRTShader.update(dt)
    if enabled and shader and power > 0.99 then
        if glitchActive > 0 then
            glitchActive = glitchActive - dt
            glitchAmount = math.max(0, math.min(1, glitchActive / 0.08))
            if glitchActive <= 0 then
                glitchAmount = 0
                glitchTimer = 4.0 + love.math.random() * 5.0
            end
        else
            glitchTimer = glitchTimer - dt
            if glitchTimer <= 0 then
                glitchActive = 0.10 + love.math.random() * 0.14
                glitchBandY = 0.15 + love.math.random() * 0.7
                glitchAmount = 1.0
            end
        end
    else
        glitchAmount = 0
    end

    if enabled and shader and power > 0.99 then
        if degradeActive > 0 then
            degradeActive = degradeActive - dt
            local elapsed = degradeDur - degradeActive
            local env = math.min(1, elapsed / 0.12)
                * math.min(1, math.max(0, degradeActive) / 0.35)
            degradeAmount = degradePeak * math.max(0, math.min(1, env))
            if degradeActive <= 0 then
                degradeAmount = 0
                degradeTimer = 8.0 + love.math.random() * 12.0
            end
        else
            degradeTimer = degradeTimer - dt
            if degradeTimer <= 0 then
                degradeDur = 0.6 + love.math.random() * 1.4
                degradeActive = degradeDur
                degradePeak = 0.55 + love.math.random() * 0.45
                if glitchActive <= 0 and love.math.random() < 0.6 then
                    glitchActive = 0.10 + love.math.random() * 0.14
                    glitchBandY = 0.15 + love.math.random() * 0.7
                    glitchAmount = 1.0
                end
            end
        end
    else
        degradeAmount = 0
    end

    if not powerAnim then return end
    powerAnim.t = powerAnim.t + dt
    local k = math.min(1, powerAnim.t / powerAnim.dur)
    local e = k
    if powerAnim.ease == "outquad" then e = 1 - (1 - k) * (1 - k) end
    power = powerAnim.from + (powerAnim.to - powerAnim.from) * e
    if k >= 1 then
        local cb = powerAnim.cb
        powerAnim = nil
        if cb then cb() end
    end
end

function CRTShader.setCalmRect(x, y, w, h)
    calmRect[1], calmRect[2], calmRect[3], calmRect[4] = x or 0, y or 0, w or 0, h or 0
end
function CRTShader.getCalmRect() return calmRect[1], calmRect[2], calmRect[3], calmRect[4] end
function CRTShader.setCalmRect2(x, y, w, h)
    calmRect2[1], calmRect2[2], calmRect2[3], calmRect2[4] = x or 0, y or 0, w or 0, h or 0
end
function CRTShader.getCalmRect2() return calmRect2[1], calmRect2[2], calmRect2[3], calmRect2[4] end
function CRTShader.setChromaScale(k) caScale = math.max(0, math.min(1, k or 1)) end
function CRTShader.getChromaScale() return caScale end

function CRTShader.setStrength(s)
    strength = math.max(0, math.min(1, s or 0))
end

function CRTShader.setDegrade(v)
    degradeAmount = math.max(0, math.min(1, v or 0))
    degradeActive = 0
end

function CRTShader.getStrength()
    return strength
end

function CRTShader.screenToContent(x, y)
    if not shader or not enabled or strength < 0.01 then return x, y end
    local w, h = love.graphics.getDimensions()
    if w <= 0 or h <= 0 then return x, y end

    local ar = w / h
    local ppx = (x / w - 0.5) * ar
    local ppy = (y / h - 0.5)
    local bezelU = CRTShader.BEZEL_PX / h
    local hex = 0.5 * ar - bezelU
    local hey = 0.5 - bezelU
    if hex <= 0 or hey <= 0 then return x, y end
    local tx = (ppx / hex) * 0.5 + 0.5
    local ty = (ppy / hey) * 0.5 + 0.5
    local cx, cy = tx - 0.5, ty - 0.5
    local r2 = cx * cx + cy * cy
    local kx = CRTShader.CURV[1] * strength
    local ky = CRTShader.CURV[2] * strength
    local g = r2 * 1.6 + r2 * r2 * 9.0
    local sx = tx + cx * kx * g
    local sy = ty + cy * ky * g
    return sx * w, sy * h
end

function CRTShader.renderTube(src, dst)
    if not shader or not src or not dst then return false end
    local w, h = dst:getDimensions()
    love.graphics.push("all")
    love.graphics.setCanvas(dst)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setShader(shader)
    send("time", love.timer.getTime())
    send("resolution", { w, h })
    send("strength", math.max(0.6, strength > 0.01 and strength or 0.75))
    send("power", 1)
    send("powerDir", 1)
    send("glitch", 0)
    send("glitchY", 0.5)
    send("degrade", 0)
    send("calmRect", { 0, 0, 0, 0 })
    send("calmRect2", { 0, 0, 0, 0 })
    send("caScale", 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(src, 0, 0)
    love.graphics.setShader()
    love.graphics.pop()
    return true
end

function CRTShader.beginScene()
    if not shader or not enabled then return end
    local w, h = love.graphics.getDimensions()
    if sceneCanvas:getWidth() ~= w or sceneCanvas:getHeight() ~= h then
        sceneCanvas = love.graphics.newCanvas(w, h)
        sceneCanvas:setFilter("linear", "linear")
    end
    love.graphics.setCanvas(sceneCanvas)
    love.graphics.clear(0, 0, 0, 1)
end

function CRTShader.endScene(target)
    if not shader or not enabled then return end
    love.graphics.setCanvas(target)
    love.graphics.setShader(shader)
    local w, h = love.graphics.getDimensions()
    send("time", love.timer.getTime())
    send("resolution", { w, h })
    send("strength", strength)
    send("power", power)
    send("powerDir", powerDirection)
    send("glitch", glitchAmount)
    send("glitchY", glitchBandY)
    send("degrade", degradeAmount)
    send("calmRect", calmRect)
    send("calmRect2", calmRect2)
    send("caScale", caScale)
    caScale = 1
    calmRect[1], calmRect[2], calmRect[3], calmRect[4] = 0, 0, 0, 0
    calmRect2[1], calmRect2[2], calmRect2[3], calmRect2[4] = 0, 0, 0, 0
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sceneCanvas, 0, 0)
    love.graphics.setShader()
end

return CRTShader
