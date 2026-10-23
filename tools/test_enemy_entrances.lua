local TK = require("tools.testkit")
local M = {}

M.FX_NAMES = { dust = true, snow = true, embers = true, straw = true, shards = true, spores = true, splash = true,
    feathers = true, dark = true, light = true, shake1 = true, shake2 = true, grass = true, gust = true,
    crows = true, lightning = true, rain = true, blizzard = true, fireflies = true, dim = true,
    undim = true, flourish = true, blood = true, ghostfire = true, frost = true }
M.LAST_FRAME_TOL = 0.02
M.LEG_MAX_HALF_S = 10
M.SHADOW_CASES = { { "cursed_scarecrow", 0.85 }, { "cursed_scarecrow", 0.62 }, { "moon_gargoyle", 0.85 } }
M.SHADOW_MIN_PX = 1500
M.HALO_CASES = { { "fallen_angel", 0.85 }, { "ember_imp", 0.65 } }
M.HALO_MARGIN = 0.01
M.AFTER_HANDOFF_S = 2.0

function M.afterHandoff(id)
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EE = require("src.ui.EnemyEntrance")
    local list = Entradas.roster()
    local DT = 1 / 30
    local ctx = Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT })
    Entradas.startEntrance(ctx, DT)
    for _ = 1, 700 do
        GameplayScene.update(DT)
        if not WorldRoad.isTraveling() then break end
    end
    local CP = require("src.systems.CardParticles")
    for _ = 1, math.floor(M.AFTER_HANDOFF_S / DT) do
        GameplayScene.update(DT)
        CP.update(DT)
    end
    local info = {}
    for ps in pairs(EE._spawned) do
        if not ps:isDead() then
            info[#info + 1] = string.format("%d/%s n%d clk%.1f life%.1f", ps.pulsed, tostring(ps.pulse_max), #ps.particles,
                ps.clock, ps.lifespan)
        end
    end
    M._lastInfo = table.concat(info, "; ")
    local wxLeft = 0
    for _, k in ipairs({ "rain", "blizzard", "ff", "dim" }) do wxLeft = wxLeft + EE.wx(k) end
    return {
        active = EE.isActive(),
        wx = wxLeft,
        particles = EE.liveParticles(),
        ffMute = require("engine.WeatherEngine").ffMute or 0,
    }
end

local function luma(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end

function M.battleShadow(id, tod)
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EE = require("src.ui.EnemyEntrance")
    local VW, VH = 1920, 1080
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local list = Entradas.roster()
    local DT = 1 / 30
    local ctx = Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT, tod = tod })
    Entradas.startEntrance(ctx, DT)
    local anchor = EE.state() and EE.state().anchorProp
    for _ = 1, 600 do
        GameplayScene.update(DT)
        if not WorldRoad.isTraveling() then break end
    end
    for _ = 1, 40 do GameplayScene.update(DT) end
    local cv = love.graphics.newCanvas(VW, VH)
    local oGet = love.timer.getTime
    local function shot()
        local t0 = oGet()
        love.timer.getTime = function() return t0 end
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        love.timer.getTime = oGet
        return cv:newImageData()
    end
    shot():release()
    local a = shot()
    local box = nil
    for _, he in ipairs(WorldRoad._hitScene) do
        if he.ref == anchor then box = { he.x1, he.y1, he.x2, he.y2 } end
    end
    local keep = anchor and anchor.grow
    if anchor then anchor.grow = 0 end
    local b = shot()
    if anchor then anchor.grow = keep end
    cv:release()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    local darker = 0
    if box then
        local w = box[3] - box[1]
        for y = math.max(0, math.floor(box[4] - 40)), math.min(VH - 1, math.floor(box[4] + (box[4] - box[2]) * 1.2)) do
            for x = math.max(0, math.floor(box[1] - w * 3)), math.min(VW - 1, math.floor(box[3] + w * 3)) do
                if not (x >= box[1] and x <= box[3] and y >= box[2] and y <= box[4]) then
                    local r1, g1, b1 = a:getPixel(x, y)
                    local r2, g2, b2 = b:getPixel(x, y)
                    if luma(r1, g1, b1) < luma(r2, g2, b2) - 0.03 then darker = darker + 1 end
                end
            end
        end
    end
    a:release(); b:release()
    return box ~= nil, darker
end

M.FOOT_TOL = 2
M.OCC_STEP = 4

function M.flatOcclusion(id, opts)
    opts = opts or {}
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EE = require("src.ui.EnemyEntrance")
    local VW, VH = 1920, 1080
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local list = Entradas.roster()
    local DT = 1 / 30
    local ctx = Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT, tod = opts.tod })
    Entradas.startEntrance(ctx, DT)
    local S0 = EE.state()
    local anchor = S0 and S0.anchorProp
    local V = S0 and getmetatable(S0.view).__index
    local origDraw = V and V.draw
    local solid = nil
    if V then
        V.draw = function(self, x, y, s, tint)
            if solid and tint and not (tint[1] == 1 and tint[2] == 0 and tint[3] == 0) then
                return origDraw(self, x, y, s, solid)
            end
            return origDraw(self, x, y, s, tint)
        end
    end
    local cv = love.graphics.newCanvas(VW, VH)
    local realTime = love.timer.getTime
    local frozenT = 100
    local function shot(bx, by, bw, bh)
        love.math.setRandomSeed(7)
        love.timer.getTime = function() return frozenT end
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
        love.timer.getTime = realTime
        return cv:newImageData(1, 1, bx, by, bw, bh)
    end
    local M1, M2 = { 1, 0, 1, 1 }, { 0, 1, 0, 1 }
    local SA = require("src.ui.SpriteAnimation")
    local origSA = SA.draw
    SA.draw = function(self, x, y, sc, tint)
        if solid and tint and not (tint[1] == 1 and tint[2] == 0 and tint[3] == 0) then
            return origSA(self, x, y, sc, { solid[1], solid[2], solid[3], tint[4] or 1 })
        end
        return origSA(self, x, y, sc, tint)
    end
    local worst, frames, worstAt = 0, 0, nil
    local step = 0
    local res = { samples = 0, battle = 0 }
    local function sample(cxS, gyS, iw, ih, sc, tag)
        local bw = math.min(VW, math.ceil(iw * sc * 1.6) + 16)
        local bh = math.min(VH, math.ceil(ih * sc * 1.3) + 16)
        local bx = math.max(0, math.min(VW - bw, math.floor(cxS - bw / 2)))
        local by = math.max(0, math.min(VH - bh, math.floor(gyS - ih * sc * 1.2)))
        local ground = math.floor(gyS - by)
        local a = shot(bx, by, bw, bh)
        solid = M1
        local m1 = shot(bx, by, bw, bh)
        solid = M2
        local m2 = shot(bx, by, bw, bh)
        solid = nil
        local keep = anchor.grow
        anchor.grow = 0
        local b = shot(bx, by, bw, bh)
        anchor.grow = keep
        local function body(xx, yy)
            if xx < 0 or yy < 0 or xx >= bw or yy >= bh then return false end
            local r1, g1 = m1:getPixel(xx, yy)
            local r2, g2 = m2:getPixel(xx, yy)
            return r1 - r2 > 0.2 and g2 - g1 > 0.2
        end
        local n = 0
        for yy = 0, math.min(bh - 1, ground - M.FOOT_TOL) do
            for xx = 0, bw - 1 do
                if body(xx, yy) and body(xx - 1, yy) and body(xx + 1, yy) and body(xx, yy - 1) and body(xx, yy + 1) then
                    local r1, g1, b1 = a:getPixel(xx, yy)
                    local r2, g2, b2 = b:getPixel(xx, yy)
                    if math.abs(r1 - r2) > 0.012 or math.abs(g1 - g2) > 0.012 or math.abs(b1 - b2) > 0.012 then
                        n = n + 1
                    end
                end
            end
        end
        res.samples = res.samples + 1
        if n > 0 then frames = frames + 1 end
        if os.getenv("OCC_DUMP") == "2" then
            love.filesystem.createDirectory("occ")
            a:encode("png", "occ/" .. id .. "_" .. tag .. "_a.png")
            b:encode("png", "occ/" .. id .. "_" .. tag .. "_b.png")
        end
        if n > worst then
            worst, worstAt = math.max(worst, n), tag
            if os.getenv("OCC_DUMP") == "1" then
                love.filesystem.createDirectory("occ")
                a:encode("png", "occ/" .. id .. "_a.png")
                b:encode("png", "occ/" .. id .. "_b.png")
                m1:encode("png", "occ/" .. id .. "_m.png")
                m2:encode("png", "occ/" .. id .. "_m2.png")
            end
        end
        a:release(); b:release(); m1:release(); m2:release()
    end
    while WorldRoad.isTraveling() and step < 600 do
        GameplayScene.update(DT)
        step = step + 1
        local S = EE.state()
        if S and step % M.OCC_STEP == 0 then
            frozenT = 100 + step * DT
            S.scrX = nil
            shot(0, 0, 1, 1):release()
        end
        local veil = anchor and anchor.mist and (anchor.mistRing or 0) > 0.02 and (anchor.mistRing or 0) < EE.MIST_VEIL_END
        if S and step % M.OCC_STEP == 0 and anchor and not veil and (S.alpha or 1) >= 0.99 and not S.pose.hidden
           and S.scrX and S.scale then
            sample(S.scrX, S.scrY, S.enc.iw, S.enc.ih, S.scale, string.format("%.2f", S.t))
        end
    end
    local ER = require("src.ui.EnemyRenderer")
    for k = 1, 24 do
        GameplayScene.update(DT)
        if anchor and k % 4 == 0 then
            frozenT = 200 + k * DT
            shot(0, 0, 1, 1):release()
            local lf = ER.getLastFoot()
            if lf and lf.scale then
                local ox, oy = 0, 0
                sample(lf.hudCx + ox, lf.groundY + oy, lf.iw, lf.ih, lf.scale, "batalha+" .. k)
                res.battle = res.battle + 1
            end
        end
    end
    SA.draw = origSA
    if V then V.draw = origDraw end
    cv:release()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    res.worst, res.frames, res.worstAt = worst, frames, worstAt
    return res
end

function M.firstFrames(id)
    local Entradas = require("tools.entradas")
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    local EE = require("src.ui.EnemyEntrance")
    local ER = require("src.ui.EnemyRenderer")
    local VW, VH = 1280, 720
    local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    local list = Entradas.roster()
    local DT = 1 / 30
    local cv = love.graphics.newCanvas(VW, VH)
    local calls = 0
    local origER = ER.draw
    ER.draw = function(...) calls = calls + 1; return origER(...) end
    local function frame()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        love.graphics.setCanvas()
    end
    local res = { before = 0, during = 0, atStage = 0 }
    local ok, err = pcall(function()
        Entradas.mount(list[Entradas.indexOf(list, id)], { dt = DT })
        frame()
        res.before = calls
        GameplayScene.update(DT)
        local _, stageY = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL, 0, 0, VW, VH)
        calls = 0
        for _ = 1, 4 do
            frame()
            local S = EE.state()
            if S and S.scrY and not S.pose.hidden and S.alpha > 0.05 and math.abs(S.scrY - stageY) < 24 then
                res.atStage = res.atStage + 1
            end
            GameplayScene.update(DT)
        end
        res.during = calls
        res.traveling = WorldRoad.isTraveling()
    end)
    ER.draw = origER
    cv:release()
    love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    if not ok then error(err) end
    return res
end

local function roster()
    local out = {}
    local byAct = require("src.data.enemies").ROSTER
    for act = 1, 6 do
        local a = byAct and byAct[act]
        if a then
            for _, nt in ipairs({ "battle", "elite", "mini_boss" }) do
                for _, id in ipairs(a[nt] or {}) do out[#out + 1] = { id = id, act = act, node = nt } end
            end
        end
    end
    return out
end
M.roster = roster

local function pngSize(path)
    local ok, d = pcall(love.image.newImageData, path)
    if not ok or not d then return nil end
    return d
end

local function diffFrac(a, b)
    local w, h = a:getWidth(), a:getHeight()
    if w ~= b:getWidth() or h ~= b:getHeight() then return 1 end
    local n, tot = 0, 0
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local r1, g1, b1, a1 = a:getPixel(x, y)
            local r2, g2, b2, a2 = b:getPixel(x, y)
            local on = a1 > 0.1 or a2 > 0.1
            if on then
                tot = tot + 1
                if math.abs(r1 - r2) > 0.02 or math.abs(g1 - g2) > 0.02 or math.abs(b1 - b2) > 0.02
                   or math.abs(a1 - a2) > 0.02 then n = n + 1 end
            end
        end
    end
    if tot == 0 then return 0 end
    return n / tot
end

function M.run()
    local t = TK.new("Entradas dos inimigos (dados, clipes e motor)")
    local Data = require("src.data.enemy_entrances")
    local EE = require("src.ui.EnemyEntrance")
    local WorldRoad = require("src.ui.WorldRoad")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local SpriteAnimation = require("src.ui.SpriteAnimation")
    local list = roster()
    t:eq("36 criaturas no roster (sem chefes)", #list, 36)

    for _, r in ipairs(list) do
        local id = r.id
        local spec = Data.BY_ID[id]
        t:truthy("entrada declarada: " .. id, spec ~= nil)
        if spec then
            t:truthy(id .. ": tipo valido (" .. tostring(spec.kind) .. ")", Data.KINDS[spec.kind] == true)
            t:truthy(id .. ": extra <= " .. EE.maxExtra(id), (spec.extra or 0) <= EE.maxExtra(id) + 1e-9)
            t:truthy(id .. ": marquee so em mini-chefe", spec.marquee == nil or EE.isMini(id))
            if EE.isMini(id) then
                t:truthy(id .. ": mini-chefe tem entrada marcante", spec.marquee ~= nil)
                t:eq(id .. ": mini-chefe 15% maior", EE.sizeK(id), Data.MINI_SIZE_K)
            end
            t:truthy(id .. ": settle dentro do extra", (spec.settle or 0) >= 0 and (spec.settle or 0) <= (spec.extra or 0) + 1e-9)
            for _, c in ipairs(spec.clips or {}) do
                t:truthy(id .. ": clipe conhecido " .. c, Data.CLIPS[c] == true)
            end
            if spec.anchor then
                t:truthy(id .. ": ancora com arte reserva (" .. tostring(spec.anchor.name) .. ")",
                    EE.ANCHOR_SIZE[spec.anchor.name] ~= nil)
            end
            for mark, names in pairs(spec.fx or {}) do
                for _, n in ipairs(names) do
                    t:truthy(id .. ": fx conhecido " .. mark .. "/" .. n, M.FX_NAMES[n] == true)
                end
            end
            for mark, codes in pairs(spec.sfx or {}) do
                t:truthy(id .. ": sfx " .. mark .. " e lista", type(codes) == "table" and #codes > 0)
            end
        end
    end

    local idle0 = {}
    local installed = 0
    for _, r in ipairs(list) do
        local id = r.id
        local spec = Data.BY_ID[id] or Data.DEFAULT
        local idlePath = "assets/sprites/characters/enemies/" .. id .. "/animations/idle/south/0.png"
        for _, c in ipairs(spec.clips or {}) do
            if SpriteAnimation.exists(id, c, "south") then
                installed = installed + 1
                local dir = "assets/sprites/characters/enemies/" .. id .. "/animations/" .. c .. "/south"
                local files = love.filesystem.getDirectoryItems(dir)
                local n = 0
                local last = nil
                for _, f in ipairs(files) do
                    local k = tonumber(f:match("^(%d+)%.png$"))
                    if k then n = n + 1; if not last or k > last then last = k end end
                end
                t:truthy(id .. "/" .. c .. ": 2+ quadros", n >= 2)
                local a = idle0[id] or pngSize(idlePath)
                idle0[id] = a
                local b = last and pngSize(dir .. "/" .. last .. ".png")
                local nextClip = nil
                if spec.chain then
                    for ci, cn in ipairs(spec.clips) do
                        if cn == c and spec.clips[ci + 1] then nextClip = spec.clips[ci + 1] end
                    end
                end
                if a and b and nextClip then
                    local ndir = "assets/sprites/characters/enemies/" .. id .. "/animations/" .. nextClip .. "/south"
                    local f0 = pngSize(ndir .. "/0.png")
                    t:truthy(id .. "/" .. c .. ": cadeia segue para " .. nextClip, f0 ~= nil)
                    if f0 then
                        local d = diffFrac(b, f0)
                        t:truthy(string.format("%s/%s -> %s: costura sem pulo (%.1f%% diferente)", id, c, nextClip, d * 100),
                            d <= M.LAST_FRAME_TOL)
                    end
                elseif a and b then
                    t:eq(id .. "/" .. c .. ": mesmo canvas do idle", b:getWidth() .. "x" .. b:getHeight(),
                        a:getWidth() .. "x" .. a:getHeight())
                    local d = diffFrac(a, b)
                    t:truthy(string.format("%s/%s: ultimo quadro = idle 0 (%.1f%% diferente)", id, c, d * 100),
                        d <= M.LAST_FRAME_TOL)
                end
            end
        end
    end
    print(string.format("  clipes de entrada instalados: %d", installed))

    local savedSettings = _G.gameSettings
    local function dryRun(id, reduced)
        _G.gameSettings = { reducedMotion = reduced }
        WorldRoad._props = {}
        WorldRoad._camZ = 0
        local enc = EnemyRenderer.getEncounterBillboard({ spriteId = id })
        if not enc then return nil end
        local dur, settle = EE.begin(enc, { bid = "fields", stopZ = 20 })
        local tr = { t = 0, from = 0, dist = 20, duration = dur, settle = settle }
        WorldRoad._travel = tr
        local DT = 1 / 30
        local steps, done = 0, false
        local minAlpha, maxLift = 1, 0
        local legs, lastF, changes = 0, nil, {}
        while not done and steps < 2000 do
            tr.t = tr.t + DT
            local k = math.min(1, tr.t / dur)
            WorldRoad._camZ = 20 * (k < 0.5 and 4 * k * k * k or (1 + (2 * k - 2) ^ 3 / 2))
            done = EE.update(DT, tr)
            local pz = EE.pose(enc)
            if pz.alpha < minAlpha then minAlpha = pz.alpha end
            if math.abs(pz.liftK) > maxLift then maxLift = math.abs(pz.liftK) end
            steps = steps + 1
            local S0 = EE.state()
            local clip = S0 and (S0.clips.walk or S0.clips.charge)
            if clip then
                local f = clip.currentFrame
                changes[steps] = (lastF ~= nil and f ~= lastF) and 1 or 0
                lastF = f
                local win = 0
                for j = math.max(1, steps - 14), steps do win = win + (changes[j] or 0) end
                if win > legs then legs = win end
            end
        end
        local pz = EE.pose(enc)
        local endPose = { relOff = pz.relOff, liftK = pz.liftK, hidden = pz.hidden, alpha = pz.alpha, shadowA = pz.shadowA }
        local S = EE.state()
        local endShift = S and (math.abs(S.sideFrac) + math.abs(S.offFrac) + math.abs(S.dxK)) or 0
        local riseK = S and S.riseK or 1
        local handoff = EE.finish()
        local info = EE._last
        WorldRoad._travel = nil
        return { legs = legs, done = done, total = tr.duration + settle, endPose = endPose, endShift = endShift,
            riseK = riseK, handoff = handoff, info = info, steps = steps, dur = dur, settle = settle }
    end

    for _, r in ipairs(list) do
        local id = r.id
        local res = dryRun(id, false)
        t:truthy(id .. ": motor conclui a entrada", res ~= nil and res.done)
        if res then
            t:truthy(string.format("%s: duracao total %.2fs <= %.1fs", id, res.total, Data.BASE + EE.maxExtra(id)),
                res.total <= Data.BASE + EE.maxExtra(id) + 1e-6)
            local ep = res.endPose
            t:truthy(id .. ": termina no palco (relOff 0, sem lift, visivel, opaco, sombra cheia, sem deslocamento)",
                math.abs(ep.relOff) < 1e-6 and math.abs(ep.liftK) < 1e-6 and not ep.hidden
                and ep.alpha >= 0.999 and ep.shadowA >= 0.999 and res.endShift < 1e-6 and res.riseK >= 0.999)
            t:truthy(id .. ": handoff devolve um idle", res.handoff ~= nil and res.handoff.animation == "idle")
            t:truthy(string.format("%s: pernas sem rajada (%d quadros em 0,5 s, max %d)", id, res.legs, M.LEG_MAX_HALF_S),
                res.legs <= M.LEG_MAX_HALF_S)
            if res.info and res.info.endFrame1 then
                t:eq(id .. ": handoff no quadro 0 do idle", res.handoff.currentFrame, 1)
            end
            local spec = Data.BY_ID[id] or Data.DEFAULT
            if spec.anchor and not spec.anchor.veil then
                local p = res.info.anchor
                t:truthy(id .. ": ancora nasce como prop", p ~= nil and p.anchor == true)
                if p then
                    p.grow = 1
                    local img = EE.anchorImage(p.entrId, p.name)
                    local SE = require("engine.ShadowEngine")
                    local CS = require("engine.ContactShadow")
                    local oSQ, oQ = SE.queue, CS.queue
                    local silImg, contact = false, false
                    SE.queue = function(im, ...) if im == img then silImg = true end; return true end
                    CS.queue = function(...) local r = oQ(...); if r then contact = true end; return r end
                    local okD, errD = pcall(EE.drawProp, p, WorldRoad.domeGeom(0, 0, 1920, 1080), 0, 1920, 0.5, 9,
                        (p.stopZ or 0) + WorldRoad.BATTLE_REL - 9)
                    EE.flushShadows()
                    SE.queue, CS.queue = oSQ, oQ
                    t:truthy(id .. ": ancora desenha " .. tostring(errD or ""), okD)
                    if EE.TALL_ANCHORS[p.name] then
                        t:truthy(id .. ": ancora alta projeta silhueta com a propria imagem (" .. p.name .. ")", silImg)
                    end
                    if EE.TALL_ANCHORS[p.name] or EE.CONTACT_ANCHORS[p.name] then
                        t:truthy(id .. ": ancora tem faixa de contato (" .. p.name .. ")", contact)
                    end
                end
            end
        end
        local red = dryRun(id, true)
        t:truthy(id .. ": reducedMotion conclui", red ~= nil and red.done)
        if red then
            t:truthy(string.format("%s: reducedMotion curta (%.2fs)", id, red.total),
                red.total <= Data.BASE + EE.REDUCED_SETTLE + 1e-6)
        end
    end
    _G.gameSettings = savedSettings
    WorldRoad._props = {}
    EE.reset()
    for _, c in ipairs(M.SHADOW_CASES) do
        local okS, found, darker = pcall(M.battleShadow, c[1], c[2])
        t:truthy(string.format("%s tod %.2f: ancora na cena da batalha %s", c[1], c[2], okS and "" or tostring(found)),
            okS and found)
        if okS then
            t:truthy(string.format("%s tod %.2f: sombra da ancora escurece %d px na batalha (min %d)",
                c[1], c[2], darker or 0, M.SHADOW_MIN_PX), (darker or 0) >= M.SHADOW_MIN_PX)
        end
    end
    WorldRoad._props = {}
    EE.reset()
    for _, r in ipairs(list) do
        local okF, f = pcall(M.firstFrames, r.id)
        t:truthy(string.format("%s: sem quadro do corpo de batalha antes da entrada (antes %s, primeiros quadros %s, no palco %s)",
            r.id, okF and f.before or tostring(f), okF and f.during or "?", okF and f.atStage or "?"),
            okF and f.before == 0 and f.during == 0 and f.atStage == 0 and f.traveling)
    end
    WorldRoad._props = {}
    EE.reset()
    for _, r in ipairs(list) do
        local spec = Data.BY_ID[r.id]
        local anc = spec and spec.anchor
        local only = os.getenv("OCC_ID")
        if anc and not anc.veil and (anc.at or "stage") == "stage" and EE.FLAT_ANCHORS[anc.name]
           and (not only or only == r.id) then
            local okO, res = pcall(M.flatOcclusion, r.id)
            t:truthy(string.format("%s: ancora chata nunca pinta o corpo acima dos pes (%s, %d amostras, pior %d px em %s quadros, t=%s)",
                r.id, anc.name, okO and res.samples or 0, okO and res.worst or -1, okO and res.frames or -1,
                okO and tostring(res.worstAt) or tostring(res)),
                okO and res.samples >= 5 and res.battle >= 3 and res.worst == 0)
        end
    end
    WorldRoad._props = {}
    EE.reset()
    do
        local Halo = require("tools.probe_enemy_halo")
        local o = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions }
        love.graphics.getWidth = function() return Halo.VW end
        love.graphics.getHeight = function() return Halo.VH end
        love.graphics.getDimensions = function() return Halo.VW, Halo.VH end
        Halo.CRT = false
        for _, c in ipairs(M.HALO_CASES) do
            for _, ph in ipairs({ "entrada", "batalha", "ataque" }) do
                local okH, r = pcall(Halo.case, c[1], c[2], ph)
                t:truthy(string.format("%s tod %.2f %s: sem borrao de luz fora do contorno (%s, margem %.1f%%)", c[1], c[2], ph,
                    okH and r and string.format("anel %.2f%% mais claro com luz, %.2f%% sem luz", r.lit * 100, r.unlit * 100) or tostring(r),
                    M.HALO_MARGIN * 100),
                    okH and r ~= nil and r.ring > 0 and r.lit <= r.unlit + M.HALO_MARGIN)
            end
        end
        for _, id in ipairs({ "fallen_angel", "storm_harpy", "harvest_reaper" }) do
            local okA, r = pcall(M.afterHandoff, id)
            t:truthy(string.format("%s: %.0f s apos o handoff nada da entrada vivo (%s)", id, M.AFTER_HANDOFF_S,
                okA and string.format("ativa=%s clima=%.2f particulas=%d vagalumes=%.2f %s", tostring(r.active), r.wx,
                    r.particles, r.ffMute, r.particles > 0 and M._lastInfo or "") or tostring(r)),
                okA and not r.active and r.wx == 0 and r.particles == 0 and r.ffMute == 0)
        end
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions = o[1], o[2], o[3]
    end
    WorldRoad._props = {}
    EE.reset()
    return t:done()
end

return M
