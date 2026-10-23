local M = {}

M.VW, M.VH = 1920, 1080
M.RING_IN, M.RING_OUT = 2, 6
M.TOL = 2 / 255
M.TRAVEL_LEFT = 0.4

local function luma(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

function M.silhouette(img, lx, ly, s, T)
    T = T or { 0, 0, 1, 1 }
    local cv = love.graphics.newCanvas(M.VW, M.VH)
    love.graphics.push("all")
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    love.graphics.translate(T[1], T[2])
    love.graphics.scale(T[3], T[4])
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, math.floor(lx), math.floor(ly), 0, s, s)
    love.graphics.setCanvas()
    love.graphics.pop()
    local d = cv:newImageData()
    cv:release()
    local x0 = math.max(0, math.floor(T[1] + lx * T[3]) - 4)
    local y0 = math.max(0, math.floor(T[2] + ly * T[4]) - 4)
    local W = math.min(M.VW - x0, math.ceil(img:getWidth() * s * T[3]) + 8)
    local H = math.min(M.VH - y0, math.ceil(img:getHeight() * s * T[4]) + 8)
    local mask = {}
    for y = y0, y0 + H - 1 do
        for x = x0, x0 + W - 1 do
            local _, _, _, a = d:getPixel(x, y)
            if a > 0.1 then mask[y * M.VW + x] = true end
        end
    end
    d:release()
    return mask, x0, y0, W, H
end

function M.ringDiff(a, b, mask, x0, y0, W, H)
    local brighter, ring, maxD = 0, 0, 0
    local R, RI = M.RING_OUT, M.RING_IN
    M.mark = os.getenv("PROBE_SAVE") and {} or nil
    for y = math.max(0, y0 - R), math.min(M.VH - 1, y0 + H + R) do
        for x = math.max(0, x0 - R), math.min(M.VW - 1, x0 + W + R) do
            if not mask[y * M.VW + x] then
                local near = false
                for dy = -R, R do
                    for dx = -R, R do
                        local d2 = dx * dx + dy * dy
                        if not near and d2 <= R * R and d2 >= RI * RI and mask[(y + dy) * M.VW + (x + dx)] then near = true end
                    end
                end
                if near then
                    ring = ring + 1
                    local d = luma(a:getPixel(x, y)) - luma(b:getPixel(x, y))
                    if d > M.TOL then
                        brighter = brighter + 1
                        if M.mark then M.mark[#M.mark + 1] = { x, y } end
                    end
                    if d > maxD then maxD = d end
                end
            end
        end
    end
    return brighter, ring, maxD
end

local function setup(id, tod)
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local list = Entradas.roster()
    local DT = 1 / 30
    local ctx = Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT, tod = tod })
    Entradas.startEntrance(ctx, DT)
    return GameplayScene, DT
end

M.CRT = false

local function shooter()
    local GameplayScene = require("src.scenes.GameplayScene")
    local CRT = require("src.ui.CRTShader")
    local cv = love.graphics.newCanvas(M.VW, M.VH)
    local function shot()
        local wo = GameplayScene.WORLD_ONLY
        GameplayScene.WORLD_ONLY = true
        if M.CRT and CRT.isEnabled() then
            CRT.beginScene()
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            CRT.endScene(cv)
        else
            love.graphics.setCanvas(cv)
            love.graphics.clear(0, 0, 0, 1)
            GameplayScene.draw()
        end
        love.graphics.setCanvas()
        GameplayScene.WORLD_ONLY = wo
        return cv:newImageData()
    end
    return shot, cv
end

function M.lightPair(shotOn, shotOff)
    local LE = require("engine.LightEngine")
    local crt = M.CRT
    local oGet = love.timer.getTime
    local t0 = oGet()
    love.timer.getTime = function() return t0 end
    local a, b = shotOn(), shotOff()
    LE.setEnabled(false)
    local a0, b0 = shotOn(), shotOff()
    LE.setEnabled(nil)
    love.timer.getTime = oGet
    return a, b, a0, b0
end

function M.diffMask(a0, b0)
    local mask = {}
    local x1, y1, x2, y2 = M.VW, M.VH, -1, -1
    local W, H = a0:getWidth(), a0:getHeight()
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            local r1, g1, b1 = a0:getPixel(x, y)
            local r2, g2, b2 = b0:getPixel(x, y)
            if math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2) > 0.004 then
                mask[y * M.VW + x] = true
                if x < x1 then x1 = x end
                if y < y1 then y1 = y end
                if x > x2 then x2 = x end
                if y > y2 then y2 = y end
            end
        end
    end
    if x2 < 0 then return nil end
    return mask, x1, y1, x2 - x1 + 1, y2 - y1 + 1
end

function M.case(id, tod, phase)
    local WorldRoad = require("src.ui.WorldRoad")
    local ER = require("src.ui.EnemyRenderer")
    local EE = require("src.ui.EnemyEntrance")
    local SA = require("src.ui.SpriteAnimation")
    local GameplayScene, DT = setup(id, tod)
    if phase == "entrada" then
        WorldRoad.setTimeOfDay(tod, true)
        for _ = 1, 700 do
            GameplayScene.update(DT)
            local tr, S = WorldRoad._travel, EE.state()
            if not tr or not S then break end
            if tr.t >= tr.duration + (tr.settle or 0) - M.TRAVEL_LEFT and (S.pose.alpha or 1) >= 0.999
               and not S.pose.hidden then break end
        end
        if not WorldRoad.isTraveling() then return nil end
    else
        for _ = 1, 700 do
            GameplayScene.update(DT)
            if not WorldRoad.isTraveling() then break end
        end
        for _ = 1, 60 do GameplayScene.update(DT) end
        WorldRoad.setTimeOfDay(tod, true)
        for _ = 1, 5 do GameplayScene.update(DT) end
        if phase == "ataque" then
            ER.triggerAttack("strong", nil, {})
            for _ = 1, 9 do GameplayScene.update(DT) end
        elseif phase == "dano" then
            ER.triggerHurt()
            GameplayScene.update(DT)
        end
    end
    local shot, cv = shooter()
    shot():release()
    local pos, img = nil, nil
    local shotOn, shotOff
    if phase == "entrada" then
        local oTr = WorldRoad._traceEnemy
        shotOn = function()
            WorldRoad._traceEnemy = function(x, y, src, lat, s)
                if src == "encounter" then
                    local tx, ty = love.graphics.transformPoint(0, 0)
                    local ux, uy = love.graphics.transformPoint(1, 1)
                    pos = { x, y, s, { tx, ty, ux - tx, uy - ty } }
                end
            end
            local d = shot()
            WorldRoad._traceEnemy = oTr
            return d
        end
        shotOff = function()
            local e = WorldRoad._encounter
            WorldRoad._encounter = nil
            local d = shot()
            WorldRoad._encounter = e
            return d
        end
    else
        shotOn = shot
        shotOff = function()
            local oDraw = ER.draw
            ER.draw = function() return nil end
            local d = shot()
            ER.draw = oDraw
            return d
        end
    end
    local a, b, a0, b0 = M.lightPair(shotOn, shotOff)
    cv:release()
    local res = nil
    local mask, mx0, my0, W, H = M.diffMask(a0, b0)
    local gimg, glx, gly, gs, gT
    if phase == "entrada" then
        local S = EE.state()
        gimg = S and S.img
        if pos then glx, gly, gs, gT = pos[1], pos[2], pos[3], pos[4] end
    else
        local lf = ER.getLastFoot()
        local st = ER.debugState()
        local fps, opts = ER._idleSpec(id)
        local anim = SA.new(id, st.animName or "idle", "south", fps, opts) or SA.new(id, "idle", "south", fps, opts)
        gimg = anim and anim.frames[lf.frame or 1]
        glx, gly, gs, gT = lf.drawX, lf.drawY, lf.scale, { lf.tx or 0, lf.ty or 0, lf.ux or 1, lf.uy or 1 }
    end
    if phase == "entrada" and gimg and glx and gs then
        mask, mx0, my0, W, H = M.silhouette(gimg, glx, gly, gs, gT)
    elseif mask and gimg and glx and gs and not M.CRT then
        local gm = M.silhouette(gimg, glx, gly, gs, gT)
        for k in pairs(gm) do mask[k] = true end
    end
    if mask then
        local br, ring = M.ringDiff(a, b, mask, mx0, my0, W, H)
        M.save(id, tod, phase, a, mask, mx0, my0, W, H)
        local br0 = M.ringDiff(a0, b0, mask, mx0, my0, W, H)
        res = { lit = br / math.max(1, ring), unlit = br0 / math.max(1, ring), ring = ring }
    end
    a:release(); b:release(); a0:release(); b0:release()
    return res
end

M.CASES_IDS = { "cursed_scarecrow", "hollow_farmer", "ember_imp", "abyss_acolyte", "mire_hag", "bog_ghoul",
    "fallen_angel", "dullahan" }
M.PHASES = { "entrada", "batalha", "ataque", "dano" }
M.TODS = { 0.65, 0.85, 1.0 }
M.MARGIN = 0.005

function M.save(id, tod, tag, a, mask, x0, y0, W, H)
    if not os.getenv("PROBE_SAVE") then return end
    local cx0, cy0 = math.max(0, x0 - 20), math.max(0, y0 - 20)
    local cw, ch = math.min(M.VW - cx0, W + 40), math.min(M.VH - cy0, H + 40)
    local out = love.image.newImageData(cw * 2, ch)
    out:paste(a, 0, 0, cx0, cy0, cw, ch)
    out:paste(a, cw, 0, cx0, cy0, cw, ch)
    for k in pairs(mask) do
        local mx, my = k % M.VW - cx0, math.floor(k / M.VW) - cy0
        if mx >= 0 and mx < cw and my >= 0 and my < ch then
            local r, g, bb = out:getPixel(cw + mx, my)
            out:setPixel(cw + mx, my, r * 0.4, g * 0.4 + 0.3, bb * 0.4, 1)
        end
    end
    for _, p in ipairs(M.mark or {}) do
        local mx, my = p[1] - cx0, p[2] - cy0
        if mx >= 0 and mx < cw and my >= 0 and my < ch then out:setPixel(cw + mx, my, 1, 0, 0, 1) end
    end
    out:encode("png", string.format("probe_halo_%s_%s_%.2f.png", id, tag, tod))
    out:release()
end

function M.run(arg)
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()
    local rw, rh = (os.getenv("PROBE_RES") or ""):match("^(%d+)x(%d+)$")
    if rw then M.VW, M.VH = tonumber(rw), tonumber(rh) end
    if os.getenv("PROBE_CRT") == "1" then
        local CRT = require("src.ui.CRTShader")
        CRT.load()
        CRT.setEnabled(true)
        CRT.setPower(1, 1)
        M.CRT = true
    end
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return M.VW end
    love.graphics.getHeight = function() return M.VH end
    love.graphics.getDimensions = function() return M.VW, M.VH end
    local ids = M.CASES_IDS
    local phs = os.getenv("PROBE_PHASES")
    if phs and phs ~= "" then
        M.PHASES = {}
        for p in phs:gmatch("[^,]+") do M.PHASES[#M.PHASES + 1] = p end
    end
    if arg and arg ~= "" and arg ~= "all" then ids = { arg } end
    local bad, total = 0, 0
    for _, id in ipairs(ids) do
        for _, tod in ipairs(M.TODS) do
            for _, ph in ipairs(M.PHASES) do
                local r = M.case(id, tod, ph)
                total = total + 1
                local ok = (not r) or (r.lit <= r.unlit + M.MARGIN)
                if not ok then bad = bad + 1 end
                print(string.format("[%s] %-16s tod %.2f %-8s %s", ok and "ok" or "FAIL", id, tod, ph,
                    r and string.format("anel mais claro %4.2f%% com luz, %4.2f%% sem luz (%d px)", r.lit * 100, r.unlit * 100, r.ring) or "sem quadro"))
            end
        end
    end
    print(string.format("TOTAL %d casos, %d com borrao de luz (%dx%d crt=%s)", total, bad, M.VW, M.VH, tostring(M.CRT)))
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    return bad == 0
end

return M
