local Debug = require("src.core.Debug")

local SpriteAnimation = require("src.ui.SpriteAnimation")
local LightEngine = require("engine.LightEngine")
local SceneGrade = require("engine.SceneGrade")
local EnemyEmissives = require("src.data.enemy_emissives")
local EnemyPoses = require("src.data.enemy_poses")
local BossAura = require("src.ui.BossAura")
local BossTokens = require("src.ui.BossTokens")

local function reducedMotion()
    return (_G.gameSettings and _G.gameSettings.reducedMotion) or false
end

local function submitEmissives(spriteId, sx, sy, iw, ih, scale, z, boost)
    local anchors = EnemyEmissives[spriteId]
    if not anchors or #anchors == 0 then return end
    local t = love.timer.getTime()
    local seed = 0
    for i = 1, #spriteId do seed = (seed + spriteId:byte(i)) % 97 end
    for ai, a in ipairs(anchors) do
        local pulse = 0.90 + 0.10 * math.sin(t * 1.1 + seed + ai * 0.3)
        LightEngine.submitMicro(
            sx + a.xr * iw * scale,
            sy + a.yr * ih * scale,
            a.r * ih * scale,
            a.color,
            (a.intensity or 0.35) * pulse * (boost or 1),
            z)
    end
end

local EnemyRenderer = {}
EnemyRenderer._gradeC = {}

local staticCache = {}
local axisCache = {}
local staticMiss = {}

local currentAnim = nil
local currentEnemyId = nil
local currentAnimName = nil
local hurtTime = 0
local auraId = nil
local poseSink = 0
local fallT = 0
local landT = -1
EnemyRenderer.FALL_DUR = 0.42
EnemyRenderer.FALL_DUR_REDUCED = 0.18
local BOUNCE_DUR = 0.24
local dust = {}
local lastDrawFloating = false
EnemyRenderer.FOOT_SINK = 2
local lastFoot = nil
function EnemyRenderer.getLastFoot() return lastFoot end
function EnemyRenderer._debugSetFrame(i)
    if currentAnim and currentAnim.frames and currentAnim.frames[i] then
        currentAnim.currentFrame = i
        return true
    end
    return false
end
function EnemyRenderer._debugFrameCount()
    return currentAnim and currentAnim.frames and #currentAnim.frames or 0
end

local ambientParticles = {}
local ambientSpawnTimer = 0

local IDLE_FPS = 7
local HURT_FPS = 12
local DEATH_FPS = 10
local ATTACK_FPS = 12

local DIRECTIONS = { "south" }

local AMBIENT_TINTS = {
    grave_slime  = { 0.45, 0.55, 0.30 },
    stone_golem  = { 0.55, 0.50, 0.55 },
    abyss_wraith = { 0.55, 0.30, 0.70 },
}

local function loadStatic(id)
    if not id then return nil end
    if staticCache[id] then return staticCache[id] end
    if staticMiss[id] then return nil end

    local base = "assets/sprites/characters/enemies/" .. id .. "/"
    local sprites = {}
    local found = 0
    for _, dir in ipairs(DIRECTIONS) do
        local path = base .. dir .. ".png"
        if love.filesystem.getInfo(path) then
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                sprites[dir] = img
                found = found + 1
            end
        end
    end
    if found == 0 then staticMiss[id] = true; return nil end
    staticCache[id] = sprites
    return sprites
end

local function idleSpec(enemyId)
    local p = EnemyPoses.BY_ID[enemyId]
    local spec = p and p.idle
    if spec and spec.cycle then
        return spec.fps or IDLE_FPS, { loop = true }
    end
    return IDLE_FPS, { loop = true, pingpong = true }
end
EnemyRenderer._idleSpec = idleSpec

local clipFps = {}
EnemyRenderer._handoff = nil

local function adoptHandoff(enemyId)
    local h = EnemyRenderer._handoff
    if not h or h.enemyId ~= enemyId or not currentAnim or currentAnimName ~= "idle" then return end
    EnemyRenderer._handoff = nil
    if #currentAnim.frames ~= #h.frames then return end
    currentAnim.currentFrame, currentAnim.elapsed, currentAnim._dir = h.currentFrame, h.elapsed, h._dir
end

local function ensureAnim(enemyId, animName)
    if currentAnim and currentEnemyId == enemyId and currentAnimName == animName
       and not currentAnim:isFinished() then
        adoptHandoff(enemyId)
        return currentAnim
    end

    local function backToIdle()
        local ifps, iopts = idleSpec(enemyId)
        currentAnim = SpriteAnimation.new(enemyId, "idle", "south", ifps, iopts)
        currentAnimName = "idle"
    end

    local fps, opts = idleSpec(enemyId)
    if animName == "hurt" then
        fps = HURT_FPS
        opts = { loop = false, onComplete = backToIdle }
    elseif animName == "attack" or animName == "attack_strong" then
        fps = ATTACK_FPS
        opts = { loop = false, onComplete = backToIdle }
    elseif animName == "death" then
        fps = DEATH_FPS
        opts = { loop = false }
    elseif animName ~= "idle" then
        fps = clipFps[animName] or 10
        opts = { loop = false, onComplete = backToIdle }
    end

    local anim = SpriteAnimation.new(enemyId, animName, "south", fps, opts)
    if anim then
        currentAnim = anim
        currentEnemyId = enemyId
        currentAnimName = animName
        adoptHandoff(enemyId)
    end
    return anim
end

function EnemyRenderer.poseOffsetY(spriteId, spriteH, now, sinkK)
    local pose = EnemyPoses.get(spriteId)
    if pose.pose ~= "floating" then return 0, pose end
    local k = pose.hover
    if not reducedMotion() then
        k = k + math.sin((now or 0) * pose.bobSpeed) * pose.bob
    end
    k = k * (1 - math.max(0, math.min(1, sinkK or 0)))
    return -k * (spriteH or 0), pose
end

function EnemyRenderer.poseOffsetX(spriteId, spriteH, now, sinkK)
    local pose = EnemyPoses.get(spriteId)
    if pose.pose ~= "floating" or (pose.drift or 0) == 0 or reducedMotion() then
        return 0
    end
    local k = math.sin((now or 0) * pose.bobSpeed * 0.53) * pose.drift
    k = k * (1 - math.max(0, math.min(1, sinkK or 0)))
    return k * (spriteH or 0)
end

function EnemyRenderer.clearCache()
    axisCache = {}
    staticCache = {}
    staticMiss = {}
    SpriteAnimation.clearCache()
    currentAnim = nil
    currentEnemyId = nil
    currentAnimName = nil
    ambientParticles = {}
    BossAura.reset()
    BossTokens.reset()
    if EnemyRenderer._clearClipMetrics then EnemyRenderer._clearClipMetrics() end
end

function EnemyRenderer.debugState()
    return {
        animName = currentAnimName,
        finished = currentAnim and currentAnim:isFinished() or false,
    }
end

local arrivalT = 0
function EnemyRenderer.triggerArrival(handoffAnim)
    arrivalT = 0.55
    if handoffAnim then EnemyRenderer._handoff = handoffAnim end
end

function EnemyRenderer.getArrivalOffset()
    if arrivalT <= 0 then return 0 end
    local k = arrivalT / 0.55
    return -math.abs(math.sin(k * math.pi * 2.2)) * 14 * k * k
end

local attackFx = nil
local poisonTime = 0
local defendTime = 0
local buffTime = 0
local knockTime = 0
local slashTime = 0
local breath = { t = 0, k = 0 }
EnemyRenderer.BREATH_DUR = 0.55
local buffParticles = {}

local DEFEND_DUR = 0.9
local BUFF_DUR   = 0.9
local SLASH_DUR  = 0.20

local ATK_WINDUP = 0.18
local ATK_LUNGE  = 0.16
local ATK_RECOIL = 0.42
local ATK_TOTAL  = ATK_WINDUP + ATK_LUNGE + ATK_RECOIL

function EnemyRenderer.resetRun()
    EnemyRenderer.setTimeScale(1)
    attackFx = nil
    poisonTime, defendTime, buffTime, knockTime, slashTime = 0, 0, 0, 0, 0
    buffParticles = {}
    hurtTime = 0
    breath.t = 0
    poseSink = 0
    fallT, landT = 0, -1
    dust = {}
    arrivalT = 0
    ambientParticles = {}
    ambientSpawnTimer = 0
    auraId = nil
    BossAura.reset()
    BossTokens.reset()
    currentAnim = nil
    currentEnemyId = nil
    currentAnimName = nil
end

function EnemyRenderer.triggerAttack(kind, onApex, opts)
    local dove = (opts and opts.swarm and auraId
        and BossAura.dive(auraId, ATK_WINDUP + ATK_LUNGE, ATK_RECOIL)) or false
    local struck = (not dove and opts and opts.strike and auraId
        and BossTokens.strike(auraId, opts.strike, ATK_WINDUP + ATK_LUNGE, ATK_RECOIL)) or false
    attackFx = { t = 0, kind = (dove or struck) and "command" or kind or "attack", onApex = onApex,
                 apexFired = false, dove = dove or struck }
    if not dove and currentEnemyId and currentAnimName ~= "death" then
        local clip = nil
        if kind == "strong" and SpriteAnimation.exists(currentEnemyId, "attack_strong", "south") then
            clip = "attack_strong"
        elseif SpriteAnimation.exists(currentEnemyId, "attack", "south") then
            clip = "attack"
        end
        if clip then
            currentAnim = nil
            ensureAnim(currentEnemyId, clip)
        end
    end
end

function EnemyRenderer.hasClip(id, name)
    return id ~= nil and name ~= nil and SpriteAnimation.exists(id, name, "south")
end
function EnemyRenderer.playClip(name, fps)
    if not currentEnemyId or currentAnimName == "death" then return false end
    if not EnemyRenderer.hasClip(currentEnemyId, name) then return false end
    clipFps[name] = fps or 10
    currentAnim = nil
    ensureAnim(currentEnemyId, name)
    return currentAnimName == name
end

function EnemyRenderer.triggerPoison() poisonTime = 0.5 end

function EnemyRenderer.triggerDefend()
    defendTime = DEFEND_DUR
end

function EnemyRenderer.triggerBuff()
    buffTime = BUFF_DUR
    buffParticles = {}
    for _ = 1, 14 do
        table.insert(buffParticles, {
            ox = (love.math.random() - 0.5) * 0.8,
            oy = love.math.random() * 0.7,
            vy = 40 + love.math.random() * 55,
            life = 0.45 + love.math.random() * 0.45,
            maxLife = 0,
            size = 2 + love.math.random(2),
        })
    end
    for _, p in ipairs(buffParticles) do p.maxLife = p.life end
end

function EnemyRenderer.isBusy()
    return attackFx ~= nil or hurtTime > 0 or knockTime > 0
        or (currentAnimName ~= nil and currentAnimName ~= "idle")
end

function EnemyRenderer.musicBreath(power)
    if not currentEnemyId or EnemyRenderer.isBusy() then return false end
    breath.t = EnemyRenderer.BREATH_DUR
    breath.k = math.max(0, math.min(1, power or 0.5))
    return true
end

function EnemyRenderer.breathLift()
    if breath.t <= 0 or EnemyRenderer.isBusy() then return 0 end
    local p = 1 - breath.t / EnemyRenderer.BREATH_DUR
    return math.floor(math.sin(p * math.pi) * (1 + breath.k) + 0.5)
end

function EnemyRenderer.isAttacking()
    return attackFx ~= nil
end

local lastCenterX, lastCenterY = nil, nil
function EnemyRenderer.getLastPos()
    if not lastCenterX then return lastCenterX, lastCenterY end
    local k = require("src.ui.UiScale").k()
    return lastCenterX / k, lastCenterY / k
end

function EnemyRenderer.triggerHurt()
    if currentAnimName == "death" then return end
    hurtTime = 0.20
    knockTime = 0.25
    if currentEnemyId and SpriteAnimation.exists(currentEnemyId, "hurt", "south") then
        ensureAnim(currentEnemyId, "hurt")
    end
end

function EnemyRenderer.triggerDeath(enemyId)
    local id = enemyId or currentEnemyId
    if id and SpriteAnimation.exists(id, "death", "south") then
        ensureAnim(id, "death")
    end
end

local function spawnAmbientParticle(cx, cy, tint)
    local angle = love.math.random() * math.pi * 2
    local dist = 20 + love.math.random() * 30
    table.insert(ambientParticles, {
        x = cx + math.cos(angle) * dist,
        y = cy - love.math.random() * 120,
        vx = (love.math.random() - 0.5) * 10,
        vy = -(10 + love.math.random() * 15),
        life = 1.0 + love.math.random() * 0.8,
        maxLife = 1.0,
        size = 1 + love.math.random(0, 1),
        tint = tint or { 0.6, 0.6, 0.6 },
    })
end

local timeScale = 1
function EnemyRenderer.setTimeScale(k) timeScale = math.max(0.02, k or 1) end
function EnemyRenderer.getTimeScale() return timeScale end

function EnemyRenderer.update(dt)
    dt = dt * timeScale
    if currentAnim then currentAnim:update(dt) end
    if currentAnimName == "death" then
        fallT = fallT + dt
        local dur = reducedMotion() and EnemyRenderer.FALL_DUR_REDUCED
            or EnemyRenderer.FALL_DUR
        local k = math.min(1, fallT / dur)
        poseSink = k * k
        if k >= 1 then
            if landT < 0 then
                landT = 0
                if lastDrawFloating and not reducedMotion() then
                    dust = {}
                    for i = 1, 10 do
                        local side = (i % 2 == 0) and 1 or -1
                        dust[i] = { x = side * (0.05 + love.math.random() * 0.25),
                                    vx = side * (0.35 + love.math.random() * 0.55),
                                    y = 0, vy = -(10 + love.math.random() * 18),
                                    life = 0.45 + love.math.random() * 0.3, max = 0 }
                        dust[i].max = dust[i].life
                    end
                end
            else
                landT = landT + dt
            end
        end
    else
        poseSink = 0
        fallT, landT = 0, -1
    end
    for i = #dust, 1, -1 do
        local d = dust[i]
        d.life = d.life - dt
        d.x = d.x + d.vx * dt * 0.4
        d.vx = d.vx * (1 - 2.5 * dt)
        d.y = d.y + d.vy * dt
        d.vy = d.vy + 40 * dt
        if d.y > 0 then d.y, d.vy = 0, 0 end
        if d.life <= 0 then table.remove(dust, i) end
    end
    if hurtTime > 0 then hurtTime = math.max(0, hurtTime - dt) end
    if breath.t > 0 then breath.t = math.max(0, breath.t - dt) end
    if arrivalT > 0 then arrivalT = math.max(0, arrivalT - dt) end
    if poisonTime > 0 then poisonTime = math.max(0, poisonTime - dt) end
    if defendTime > 0 then defendTime = math.max(0, defendTime - dt) end
    if buffTime > 0 then buffTime = math.max(0, buffTime - dt) end
    if knockTime > 0 then knockTime = math.max(0, knockTime - dt) end
    if slashTime > 0 then slashTime = math.max(0, slashTime - dt) end
    BossAura.update(dt, auraId, currentAnimName == "death")
    BossTokens.update(dt, auraId, currentAnimName == "death")

    if #buffParticles > 0 then
        for i = #buffParticles, 1, -1 do
            local p = buffParticles[i]
            p.life = p.life - dt
            p.oy = p.oy - (p.vy * dt) / 100
            if p.life <= 0 then table.remove(buffParticles, i) end
        end
    end

    if attackFx then
        attackFx.t = attackFx.t + dt
        if not attackFx.apexFired and attackFx.t >= ATK_WINDUP + ATK_LUNGE then
            attackFx.apexFired = true
            slashTime = SLASH_DUR
            if not attackFx.dove and auraId then BossAura.hitFeathers(auraId) end
            if attackFx.onApex then attackFx.onApex() end
        end
        if attackFx.t >= ATK_TOTAL then attackFx = nil end
    end

    ambientSpawnTimer = ambientSpawnTimer - dt
    if ambientSpawnTimer <= 0 and currentEnemyId then
        ambientSpawnTimer = 0.28 + love.math.random() * 0.20
    end

    for i = #ambientParticles, 1, -1 do
        local p = ambientParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(ambientParticles, i)
        end
    end
end

local clipMetricsCache = {}
local FOOT_ALPHA = 0.1
function EnemyRenderer._clearClipMetrics() clipMetricsCache = {} end
local GROUND_T = 5
EnemyRenderer.GROUND_T = GROUND_T
local function groundOf(data)
    local w, h = data:getWidth(), data:getHeight()
    local minX, maxX, low, top = w, -1, -1, h
    local run = {}
    local solidRows = {}
    for x = 0, w - 1 do run[x] = 0 end
    for y = 0, h - 1 do
        local sx = nil
        for x = 0, w - 1 do
            local _, _, _, a = data:getPixel(x, y)
            if a > FOOT_ALPHA then
                run[x] = run[x] + 1
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y < top then top = y end
                low = y
                if run[x] >= GROUND_T then
                    sx = sx or {}
                    sx[#sx + 1] = x
                end
            else
                run[x] = 0
            end
        end
        solidRows[y] = sx
    end
    if low < 0 then return nil end
    local M = math.max(3, math.floor(0.06 * (maxX - minX + 1)))
    local g = low
    for y = h - 1, 0, -1 do
        if solidRows[y] and #solidRows[y] >= M then g = y; break end
    end
    local fl, fr = maxX, minX
    for y = math.max(0, g - 3), g do
        for _, x in ipairs(solidRows[y] or {}) do
            if x < fl then fl = x end
            if x > fr then fr = x end
        end
    end
    if fr < fl then fl, fr = minX, maxX end
    return g, fl, fr, low, top
end
EnemyRenderer._groundOf = groundOf

local function clipMetrics(id, animName)
    animName = animName or "idle"
    local key = id .. "|" .. animName
    local c = clipMetricsCache[key]
    if c ~= nil then return c end

    local m = { off = 0, pad = 0, w = 0, h = 0, cw = 0 }
    local imgPath
    local fdir = "assets/sprites/characters/enemies/" .. id
        .. "/animations/" .. animName .. "/south"
    local info = love.filesystem.getInfo(fdir)
    if info and info.type == "directory" then
        local files = love.filesystem.getDirectoryItems(fdir)
        table.sort(files)
        for _, f in ipairs(files) do
            if f:match("%.png$") then imgPath = fdir .. "/" .. f; break end
        end
    end
    if not imgPath and animName == "idle" then
        local p2 = "assets/sprites/characters/enemies/" .. id .. "/south.png"
        if love.filesystem.getInfo(p2) then imgPath = p2 end
    end
    if imgPath then
        local ok, data = pcall(love.image.newImageData, imgPath)
        if ok and data then
            local wpx, hpx = data:getWidth(), data:getHeight()
            m.w, m.h = wpx, hpx
            local minX, maxX, maxY = wpx, -1, -1
            for yy = 0, hpx - 1 do
                for xx = 0, wpx - 1 do
                    local _, _, _, a = data:getPixel(xx, yy)
                    if a > FOOT_ALPHA then
                        if xx < minX then minX = xx end
                        if xx > maxX then maxX = xx end
                        if yy > maxY then maxY = yy end
                    end
                end
            end
            if maxX >= minX then
                m.off = (minX + maxX) / 2 - wpx / 2
                m.cw = maxX - minX + 1
                m.pad = (hpx - 1) - maxY
                local g, fl, fr = groundOf(data)
                if g then
                    m.pad = (hpx - 1) - g
                    m.footL, m.footR = fl, fr
                end
            end
        end
    end
    m.framePads = {}
    m.frameHeights = {}
    m.frameFeet = {}
    if imgPath and fdir and info and info.type == "directory" then
        local files = love.filesystem.getDirectoryItems(fdir)
        table.sort(files, function(a, b)
            local na, nb = tonumber(a:match("^(%d+)")), tonumber(b:match("^(%d+)"))
            if na and nb then return na < nb end
            return a < b
        end)
        for _, f in ipairs(files) do
            if f:match("%.png$") then
                local ok, data = pcall(love.image.newImageData, fdir .. "/" .. f)
                local pad = m.pad
                local fh = 0
                local feet = false
                if ok and data then
                    local g, fl, fr, _, top = groundOf(data)
                    if g then
                        pad = (data:getHeight() - 1) - g
                        fh = g - top + 1
                        feet = { fl, fr }
                    end
                end
                m.framePads[#m.framePads + 1] = pad
                m.frameHeights[#m.frameHeights + 1] = fh
                m.frameFeet[#m.frameFeet + 1] = feet
            end
        end
    end
    local gr = (EnemyPoses.BY_ID[id] or {}).groundRow
    if gr then
        local idle = (animName == "idle") and m or clipMetrics(id, "idle")
        local autoPad0 = (animName == "idle") and m.pad or idle._autoPad0
        if animName == "idle" then m._autoPad0 = m.pad end
        if autoPad0 and m.h > 0 then
            local delta = ((idle.h - 1) - gr) - autoPad0
            m.pad = m.pad + delta
            for i = 1, #m.framePads do m.framePads[i] = m.framePads[i] + delta end
        end
    end
    clipMetricsCache[key] = m
    return m
end

function EnemyRenderer.bodyAxis(id)
    local over = (EnemyPoses.BY_ID[id] or {}).axisX
    if over then return over, "manual" end
    if axisCache[id] ~= nil then return axisCache[id], "auto" end
    local m = clipMetrics(id, "idle")
    local axis = (m.w > 0) and (m.w / 2 + m.off - 0.5) or 0
    local dir = "assets/sprites/characters/enemies/" .. id .. "/animations/idle/south/0.png"
    if not love.filesystem.getInfo(dir) then
        dir = "assets/sprites/characters/enemies/" .. id .. "/south.png"
    end
    local ok, data = pcall(love.image.newImageData, dir)
    if ok and data then
        local w, h = data:getWidth(), data:getHeight()
        local y0, y1 = nil, nil
        for y = 0, h - 1 do
            for x = 0, w - 1 do
                local _, _, _, a = data:getPixel(x, y)
                if a > FOOT_ALPHA then
                    y0 = y0 or y
                    y1 = y
                    break
                end
            end
        end
        if y0 then
            local H = y1 - y0 + 1
            local centers = {}
            for y = math.floor(y0 + 0.2 * H), math.floor(y0 + 0.8 * H) do
                local bestLen, bestC, runS = 0, nil, nil
                for x = 0, w do
                    local on = false
                    if x < w then
                        local _, _, _, a = data:getPixel(x, y)
                        on = a > FOOT_ALPHA
                    end
                    if on and not runS then runS = x end
                    if not on and runS then
                        if x - runS > bestLen then
                            bestLen, bestC = x - runS, (runS + x - 1) / 2
                        end
                        runS = nil
                    end
                end
                if bestC then centers[#centers + 1] = bestC end
            end
            if #centers > 0 then
                table.sort(centers)
                local n = #centers
                axis = (n % 2 == 1) and centers[(n + 1) / 2]
                    or (centers[n / 2] + centers[n / 2 + 1]) / 2
            end
        end
    else
        Debug.warn("[EnemyRenderer] AVISO: sem quadro 0 do idle pro eixo de " .. tostring(id)
            .. " — usando o centro do bbox")
    end
    axisCache[id] = axis
    return axis, "auto"
end

local function axisOffset(id)
    local m = clipMetrics(id, "idle")
    if m.w <= 0 then return m.off end
    return (EnemyRenderer.bodyAxis(id) + 0.5) - m.w / 2
end

local function contentOffsets(id)
    local m = clipMetrics(id, "idle")
    return axisOffset(id), m.pad
end

function EnemyRenderer.debugClipMetrics(id, animName)
    return clipMetrics(id, animName)
end

local function tickAmbientSpawn(cx, cy, dt_hint)
    if not currentEnemyId then return end
    if #ambientParticles > 18 then return end
    if love.math.random() < 0.08 then
        spawnAmbientParticle(cx, cy, AMBIENT_TINTS[currentEnemyId])
    end
end

EnemyRenderer.SHADOW_LEN = 0.75

function EnemyRenderer.drawFootContact(footCx, footW, shY, scale, sceneShadowA)
    local P = math.max(1, math.floor(scale + 0.5))
    local a = 0.26 * (sceneShadowA or 1)
    local yBase = math.floor(shY - P)
    for i, k in ipairs({ 0.62, 1.0, 0.80 }) do
        local wk = math.floor(footW * 1.06 * k / P + 0.5) * P
        love.graphics.setColor(0, 0, 0, a * ((i == 2) and 1 or 0.7))
        love.graphics.rectangle("fill", math.floor(footCx - wk / 2),
            yBase + (i - 1) * P - P, wk, P)
    end
end

function EnemyRenderer.contactK(floating, animName, sinkK)
    if not floating then return 1 end
    if animName ~= "death" then return 0 end
    local k = math.max(0, math.min(1, sinkK or 0))
    return k * k
end

function EnemyRenderer.shadowProfile(pose, animName, frameH, idleH)
    local baseK = (pose and pose.shadowBaseK) or 0
    local riseK = pose and pose.shadowRiseK or nil
    local lenK = 1 - 1.2 * baseK
    if animName == "death" and frameH and idleH and idleH > 0 then
        local lying = math.max(0, math.min(1, (1 - frameH / idleH) / 0.35))
        if lying > 0 then
            baseK = math.max(baseK, 0.55 * lying)
            lenK = math.min(lenK, 1 - 0.35 * lying)
        end
    end
    return baseK, riseK, lenK
end

function EnemyRenderer.draw(game, cx, cy, opts)
    if not game or not game.enemy or not game.enemy.spriteId then return false end
    local id = game.enemy.spriteId
    if opts and opts.deathCy and currentAnimName == "death"
        and currentEnemyId == id and EnemyPoses.isFloating(id) then
        cy = cy + (opts.deathCy - cy) * poseSink
    end

    local enemyAlive = game.enemy and game.enemy.health > 0
    local stuckOnDeath = currentAnimName == "death"
        and currentAnim and currentAnim:isFinished()
        and enemyAlive
    if currentEnemyId ~= id or currentAnim == nil or stuckOnDeath then
        ensureAnim(id, "idle")
    elseif EnemyRenderer._handoff then
        adoptHandoff(id)
    end

    local iw, ih
    local hasAnim = (currentAnim ~= nil)
    if hasAnim then
        iw, ih = currentAnim:getSize()
    else
        local sprites = loadStatic(id)
        if not sprites then return false end
        local staticImg = sprites.south or sprites.east or sprites.west or sprites.north
        if not staticImg then return false end
        iw, ih = staticImg:getWidth(), staticImg:getHeight()
    end

    local targetHeight = 250
    if game.enemy and game.enemy.isBoss then targetHeight = 330 end
    targetHeight = targetHeight * ((opts and opts.sizeK) or 1)
    local idleM = clipMetrics(id, "idle")
    local refH = (idleM.h > 0) and idleM.h or ih
    local scale = targetHeight / refH
    if refH <= 80 then scale = math.max(4, math.floor(scale)) end

    local curM = hasAnim and clipMetrics(id, currentAnimName or "idle") or idleM
    if curM.h == 0 then curM = idleM end
    local offX = curM.off
    if idleM.w > 0 then
        offX = offX + (axisOffset(id) - idleM.off)
    end
    local bodyCx = cx
    cx = cx - math.floor(offX * scale)

    local hoverY, pose = EnemyRenderer.poseOffsetY(id, ih * scale,
        love.timer.getTime(), poseSink)
    local floating = pose.pose == "floating"
    local driftX = EnemyRenderer.poseOffsetX(id, ih * scale,
        love.timer.getTime(), poseSink)
    auraId = (game.enemy.isBoss and BossAura.has(id)) and id or nil
    if auraId then
        BossAura.setCountFrom(auraId, game.enemy)
        BossTokens.sync(auraId, game.enemy)
    end

    local footPad = curM.pad
    local frameIdx = hasAnim and currentAnim.currentFrame or 1
    if not floating and (currentAnimName or "idle") == "idle"
        and curM.framePads and curM.framePads[frameIdx] then
        footPad = curM.framePads[frameIdx]
    end
    if not floating and currentAnimName == "death"
        and curM.framePads and curM.framePads[frameIdx] then
        footPad = curM.framePads[frameIdx]
    end
    local sink = floating and 0 or EnemyRenderer.FOOT_SINK
    local fallBounce = 0
    lastDrawFloating = floating
    if floating and currentAnimName == "death" then
        local fp = curM.framePads and curM.framePads[frameIdx]
        if fp then footPad = footPad + (fp - footPad) * poseSink end
        sink = EnemyRenderer.FOOT_SINK * poseSink
        if landT >= 0 and landT < BOUNCE_DUR and not reducedMotion() then
            local k = landT / BOUNCE_DUR
            fallBounce = -math.sin(k * math.pi) * (1 - k) * ih * scale * 0.035
        end
    end
    local footY = footPad * scale + sink + fallBounce

    local t = love.timer.getTime()

    tickAmbientSpawn(bodyCx, cy, 0)
    for _, p in ipairs(ambientParticles) do
        local alpha = math.max(0, math.min(1, p.life / (p.maxLife * 2)))
        love.graphics.setColor(p.tint[1], p.tint[2], p.tint[3], alpha * 0.55)
        love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
    end

    local bounce = floating and 0 or (math.sin(t * 1.6) > 0 and 1 or 0)
    local jitter = 0
    if hurtTime > 0 then
        jitter = math.floor(math.sin(t * 41) * 2)
    end

    local atkDX, atkDY = 0, 0
    if attackFx then
        local strong = attackFx.kind == "strong"
        local command = attackFx.kind == "command"
        local lunge = command and 8 or (strong and 70 or 46)
        local drop = command and 3 or (strong and 34 or 24)
        local p = attackFx.t
        if p < ATK_WINDUP then
            local k = p / ATK_WINDUP
            atkDX = 16 * k
            atkDY = -5 * k
        elseif p < ATK_WINDUP + ATK_LUNGE then
            local k = (p - ATK_WINDUP) / ATK_LUNGE
            local kk = k * k
            atkDX = 16 - (16 + lunge) * kk
            atkDY = -5 + (5 + drop) * kk
        else
            local k = math.min(1, (p - ATK_WINDUP - ATK_LUNGE) / ATK_RECOIL)
            local ease = 1 - (1 - k) * (1 - k)
            atkDX = -lunge + lunge * ease
            atkDY = drop - drop * ease
        end
    end
    local knockDX = 0
    if knockTime > 0 then
        knockDX = 14 * (knockTime / 0.25)
    end

    local drawX = cx - (iw * scale) / 2 + jitter + atkDX + knockDX + driftX
    local drawY = cy - ih * scale + bounce + EnemyRenderer.getArrivalOffset()
        + footY + atkDY + hoverY
        - EnemyRenderer.breathLift() * math.max(1, math.floor(scale + 0.5))
    lastFoot = {
        bodyX = drawX + (EnemyRenderer.bodyAxis(id) + 0.5 + (idleM.off - curM.off)) * scale,
        hudCx = bodyCx,
        drawX = drawX,
        groundY = cy,
        footBottom = math.floor(drawY) + (ih - footPad) * scale,
        scale = scale, frame = frameIdx, pad = footPad,
        floating = floating, drawY = drawY, ih = ih, iw = iw,
    }

    lastCenterX = bodyCx + jitter + atkDX + knockDX + driftX
    lastCenterY = drawY + (ih * scale) * 0.35

    do
        local ShadowEngine = require("engine.ShadowEngine")
        local sceneShadowA = (opts and opts.shadowA) or 1
        local sink = math.max(0, math.min(1, poseSink))
        local shK = pose.shadowK + (1 - pose.shadowK) * sink
        local shA = pose.shadowA + (1 - pose.shadowA) * sink

        local shDX, shDY, smearK = 0, 0, 1
        if floating then
            local lift = -hoverY
            smearK = 2.4
            local dirX = ShadowEngine.tipShiftAt(cx)
            if dirX == 0 then
                local lx = (opts and opts.lightXr) or 0.5
                local sw = math.max(1, love.graphics.getWidth())
                dirX = math.max(-1, math.min(1, (cx / sw - lx) * 2))
            end
            shDX = dirX * lift * 0.55
            shDY = lift * 0.16
        end
        local gdx = atkDX + knockDX + driftX
        local shX = cx + jitter * 0.5 + shDX + gdx
        local shY = cy - 1 + sink + shDY + math.max(0, atkDY)

        local sx0 = -(iw * scale) / 2
        local sy0 = -(ih * scale) + footY - sink
        local frameH = curM.frameHeights and curM.frameHeights[frameIdx]
        if not frameH or frameH <= 0 then frameH = ih - footPad end
        local idleH = idleM.frameHeights and idleM.frameHeights[1]
        if not idleH or idleH <= 0 then idleH = idleM.h - idleM.pad end
        local pBaseK, pRiseK, pLenK = EnemyRenderer.shadowProfile(
            pose, currentAnimName, frameH, idleH)
        local drawn = ShadowEngine.silhouette(shX, shY,
            { smear = iw * scale * 0.035 * smearK,
              widthK = shK,
              lenK = shK * pLenK * EnemyRenderer.SHADOW_LEN,
              baseK = pBaseK, riseK = pRiseK,
              contentH = frameH * scale,
              alphaK = shA * sceneShadowA },
            function(tint)
                if hasAnim then
                    currentAnim:draw(sx0, sy0, scale, tint)
                else
                    local sprites = loadStatic(id)
                    local staticImg = sprites and (sprites.south
                        or sprites.east or sprites.west or sprites.north)
                    if staticImg then
                        love.graphics.draw(staticImg, sx0, sy0, 0,
                            scale, scale)
                    end
                end
            end)
        local footW, footCx = nil, nil
        local fL, fR = curM.footL, curM.footR
        local ff = currentAnimName == "death" and curM.frameFeet and curM.frameFeet[frameIdx]
        if ff then fL, fR = ff[1], ff[2] end
        if fL and fR then
            footW = (fR - fL + 1) * scale
            footCx = cx + ((fL + fR + 1) / 2 - curM.w / 2) * scale
                + jitter * 0.5 + gdx
        end
        local contactK = EnemyRenderer.contactK(floating, currentAnimName, poseSink)
        if drawn and footW and contactK > 0 then
            EnemyRenderer.drawFootContact(footCx, footW, shY, scale, sceneShadowA * contactK)
        end
        if not drawn then
            local baseW = footW or (((curM.cw > 0) and curM.cw or iw) * scale)
            shX = (footCx or (bodyCx + jitter * 0.5 + gdx)) + shDX
            local rx = baseW * 0.46 * shK
            local ry = math.max(3, baseW * 0.060 * shK)
            local a = 0.30 * shA * sceneShadowA
            if floating then
                love.graphics.setColor(0, 0, 0, a * 0.5)
                love.graphics.ellipse("fill", shX, shY, rx * 1.45, ry * 1.45)
                love.graphics.setColor(0, 0, 0, a * 0.7)
                love.graphics.ellipse("fill", shX, shY, rx, ry)
            else
                love.graphics.setColor(0, 0, 0, a)
                love.graphics.ellipse("fill", shX, shY, rx, ry)
            end
        end
    end

    if #dust > 0 then
        local P = math.max(1, math.floor(scale + 0.5))
        local wBody = ((curM.cw > 0) and curM.cw or iw) * scale
        for _, d in ipairs(dust) do
            local a = math.max(0, d.life / d.max)
            love.graphics.setColor(0.62, 0.58, 0.52, 0.55 * a)
            local n = (a > 0.5) and 2 or 1
            love.graphics.rectangle("fill",
                math.floor(cx + d.x * wBody), math.floor(cy + d.y - P * n),
                P * n, P * n)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    local auraRect = nil
    if auraId then
        auraRect = { x = drawX, y = drawY, w = iw * scale, h = ih * scale,
                     iw = iw, ih = ih, scale = scale, groundY = cy,
                     cx = bodyCx + driftX, clip = currentAnimName or "idle", frame = frameIdx,
                     hallTr = opts and opts.hallTr }
        BossAura.drawBack(auraId, auraRect)
        BossTokens.drawBack(auraId, auraRect)
    end

    local pulse = 0.94 + (math.sin(t * 1.1) * 0.5 + 0.5) * 0.06
    local tintR, tintG, tintB = pulse, pulse, pulse
    if poisonTime > 0 then
        local k = poisonTime / 0.5
        tintR = pulse * (1 - 0.45 * k)
        tintB = pulse * (1 - 0.45 * k)
    elseif defendTime > 0 then
        local k = defendTime / DEFEND_DUR
        tintR = pulse * (1 - 0.30 * k)
        tintG = pulse * (1 - 0.12 * k)
    elseif buffTime > 0 then
        local k = buffTime / BUFF_DUR
        local throb = 0.5 + math.sin(t * 18) * 0.5
        tintG = pulse * (1 - 0.45 * k * throb)
        tintB = pulse * (1 - 0.45 * k * throb)
    end
    local gradeC = SceneGrade.color("enemy", SceneGrade.depth(), EnemyRenderer._gradeC)
    tintR, tintG, tintB = tintR * gradeC[1], tintG * gradeC[2], tintB * gradeC[3]
    love.graphics.setColor(tintR, tintG, tintB, 1)

    if hasAnim then
        currentAnim:draw(drawX, drawY, scale, { tintR, tintG, tintB, 1 })
    else
        local sprites = loadStatic(id)
        local staticImg = sprites and (sprites.south or sprites.east or sprites.west or sprites.north)
        if staticImg then
            love.graphics.draw(staticImg, drawX, drawY, 0, scale, scale)
        end
    end

    if hurtTime > 0 then
        local a = hurtTime / 0.20
        local offsets = { {-2, 0}, {2, 0}, {0, -2}, {0, 2} }
        love.graphics.setColor(1, 0.2, 0.2, a * 0.35)
        for _, off in ipairs(offsets) do
            if hasAnim then
                currentAnim:draw(drawX + off[1], drawY + off[2], scale)
            else
                local sprites = loadStatic(id)
                local staticImg = sprites and sprites.south
                if staticImg then
                    love.graphics.draw(staticImg, drawX + off[1], drawY + off[2], 0, scale, scale)
                end
            end
        end

        love.graphics.setColor(1, 1, 1, a * 0.55)
        if hasAnim then
            currentAnim:draw(drawX, drawY, scale)
        else
            local sprites = loadStatic(id)
            local staticImg = sprites and sprites.south
            if staticImg then
                love.graphics.draw(staticImg, drawX, drawY, 0, scale, scale)
            end
        end
    end

    if auraRect then
        BossAura.drawFront(auraId, auraRect)
        BossTokens.drawFront(auraId, auraRect)
    end

    if defendTime > 0 then
        local k = 1 - defendTime / DEFEND_DUR
        local ccx = drawX + (iw * scale) / 2
        local ccy = drawY + (ih * scale) * 0.45

        for ring = 0, 1 do
            local rk = k - ring * 0.25
            if rk > 0 and rk < 1 then
                local ringR = 18 + rk * (iw * scale * 0.55)
                love.graphics.setColor(0.62, 0.75, 0.92, (1 - rk) * 0.85)
                love.graphics.setLineWidth(3)
                love.graphics.circle("line", ccx, ccy, ringR)
            end
        end
        love.graphics.setLineWidth(1)

        local IconLoader = require("src.ui.IconLoader")
        local shield = IconLoader.get("armor_shield") or IconLoader.get("shield_round")
        if shield and shield.draw and shield.size then
            local popK = math.min(1, k / 0.22)
            local popScale = 1.25 - 0.25 * (1 - (1 - popK) * (1 - popK))
            local alpha = 1
            if k > 0.65 then alpha = 1 - (k - 0.65) / 0.35 end
            local targetH = math.max(36, ih * scale * 0.38)
            local s = (targetH / shield.size.h) * popScale
            local sw2, sh2 = shield.size.w * s, shield.size.h * s
            love.graphics.setColor(1, 1, 1, alpha * 0.95)
            shield.draw(math.floor(ccx - sw2 / 2), math.floor(ccy - sh2 / 2), s)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if buffTime > 0 then
        local k = 1 - buffTime / BUFF_DUR
        local bodyW = iw * scale
        local bodyH = ih * scale

        for _, p in ipairs(buffParticles) do
            local a = math.max(0, p.life / p.maxLife)
            love.graphics.setColor(1.0, 0.35 + 0.35 * a, 0.20, a * 0.9)
            love.graphics.rectangle("fill",
                math.floor(drawX + bodyW / 2 + p.ox * bodyW / 2),
                math.floor(drawY + bodyH * 0.25 + p.oy * bodyH * 0.6),
                p.size, p.size)
        end

        local IconLoader = require("src.ui.IconLoader")
        local up = IconLoader.get("status_strength")
        if up and up.draw and up.size then
            local popK = math.min(1, k / 0.22)
            local popScale = 1.3 - 0.3 * (1 - (1 - popK) * (1 - popK))
            local alpha = 1
            if k > 0.6 then alpha = 1 - (k - 0.6) / 0.4 end
            local targetH = math.max(30, bodyH * 0.30)
            local s = (targetH / up.size.h) * popScale
            local sw2, sh2 = up.size.w * s, up.size.h * s
            love.graphics.setColor(1, 1, 1, alpha * 0.95)
            local cH = curM.frameHeights and curM.frameHeights[frameIdx]
            if not cH or cH <= 0 then cH = ih - footPad end
            local headY = drawY + (ih - footPad - cH) * scale
            up.draw(math.floor(drawX + bodyW / 2 - sw2 / 2),
                math.floor(headY + cH * scale * 0.30 - sh2 / 2 - k * 10), s)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if slashTime > 0 then
        local k = 1 - slashTime / SLASH_DUR
        local ccx = drawX + (iw * scale) * 0.18
        local ccy = drawY + (ih * scale) * 0.62
        local len = math.max(46, iw * scale * 0.55)
        love.graphics.push()
        love.graphics.translate(ccx, ccy)
        love.graphics.rotate(-0.65)
        for i = -1, 1 do
            local off = i * 9
            local a = (1 - k) * (1 - math.abs(i) * 0.35)
            local sweep = len * (0.35 + 0.65 * k)
            love.graphics.setColor(1, 1, 0.92, a)
            love.graphics.setLineWidth(3 - math.abs(i))
            love.graphics.line(-sweep / 2, off, sweep / 2, off)
        end
        love.graphics.pop()
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end

    if currentAnimName ~= "death" then
        local exT, eyT = love.graphics.transformPoint(drawX, drawY)
        submitEmissives(id, exT, eyT, iw, ih, scale, 9)
    end

    do
        local oxT, oyT = love.graphics.transformPoint(drawX, drawY)
        local animRef = hasAnim and currentAnim or nil
        local staticRef = nil
        if not animRef then
            local sprites = loadStatic(id)
            staticRef = sprites and (sprites.south or sprites.east
                or sprites.west or sprites.north)
        end
        local flatColor = SceneGrade.flatColor("enemy", {})
        if animRef or staticRef then
            LightEngine.submitOccluder({
                z = (((package.loaded["src.ui.WorldRoad"] or {}).BATTLE_REL)
                    or 9) + 6,
                flatColor = flatColor,
                bx = oxT, by = oyT, w = iw * scale, h = ih * scale,
                fn = function()
                    if animRef then
                        local r, g, b = love.graphics.getColor()
                        animRef:draw(oxT, oyT, scale, { r, g, b, 1 })
                    else
                        love.graphics.draw(staticRef, oxT, oyT, 0, scale, scale)
                    end
                end,
            })
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    return {
        cx = bodyCx,
        topY = cy - ih * scale + footY
            - ((pose.pose == "floating") and pose.hover * (1 - math.max(0, math.min(1, poseSink))) * ih * scale or 0),
        bottomY = cy,
        width = iw * scale,
        height = ih * scale,
    }
end

function EnemyRenderer.idleShadow(id)
    local pose = EnemyPoses.get(id)
    local m = clipMetrics(id, "idle")
    local baseK, riseK, lenK = EnemyRenderer.shadowProfile(pose, "idle")
    local floating = EnemyPoses.isFloating(id)
    return {
        widthK = pose.shadowK, alphaK = pose.shadowA,
        lenK = pose.shadowK * lenK * EnemyRenderer.SHADOW_LEN,
        baseK = baseK, riseK = riseK,
        smearK = floating and 2.4 or 1, floating = floating,
        footL = m.footL, footR = m.footR, mw = m.w,
    }
end

function EnemyRenderer.getEncounterBillboard(enemy)
    if not enemy or not enemy.spriteId then return nil end
    local bfps, bopts = idleSpec(enemy.spriteId)
    local anim = SpriteAnimation.new(enemy.spriteId, "idle", "south",
        bfps, bopts)
    local img, iw, ih
    if anim then
        iw, ih = anim:getSize()
    else
        local sprites = loadStatic(enemy.spriteId)
        img = sprites and (sprites.south or sprites.east
            or sprites.west or sprites.north)
        if not img then return nil end
        iw, ih = img:getWidth(), img:getHeight()
    end
    local targetHeight = enemy.isBoss and 330 or 250
    local ts = targetHeight / ih
    if ih <= 80 then ts = math.max(4, math.floor(ts)) end
    local offX, footPad = contentOffsets(enemy.spriteId)
    return {
        anim = anim,
        img = img,
        iw = iw,
        ih = ih,
        targetScale = ts,
        spriteId = enemy.spriteId,
        offX = offX,
        footPad = footPad,
        framePads = (not EnemyPoses.isFloating(enemy.spriteId))
            and clipMetrics(enemy.spriteId, "idle").framePads or nil,
        footSink = EnemyPoses.isFloating(enemy.spriteId) and 0
            or EnemyRenderer.FOOT_SINK,
        shadowBaseK = EnemyPoses.get(enemy.spriteId).shadowBaseK,
        shadowRiseK = EnemyPoses.get(enemy.spriteId).shadowRiseK,
        contentH = clipMetrics(enemy.spriteId, "idle").frameHeights[1],
        shadow = EnemyRenderer.idleShadow(enemy.spriteId),
    }
end

function EnemyRenderer.resolveSpriteId(actNumber, nodeType)
    local effectiveAct = (((actNumber or 1) - 1) % 6) + 1
    local pool = require("src.systems.EnemyRoster").poolFor(effectiveAct, nodeType)
    return pool[1]
end

return EnemyRenderer
