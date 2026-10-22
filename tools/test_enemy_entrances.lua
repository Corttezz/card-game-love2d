local TK = require("tools.testkit")
local M = {}

M.FX_NAMES = { dust = true, snow = true, embers = true, straw = true, shards = true, spores = true, splash = true,
    feathers = true, dark = true, light = true, shake1 = true, shake2 = true, grass = true, gust = true,
    crows = true, lightning = true }
M.LAST_FRAME_TOL = 0.02

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
            t:truthy(id .. ": extra <= 3", (spec.extra or 0) <= Data.MAX_EXTRA + 1e-9)
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
                if a and b then
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
        while not done and steps < 2000 do
            tr.t = tr.t + DT
            local k = math.min(1, tr.t / dur)
            WorldRoad._camZ = 20 * (k < 0.5 and 4 * k * k * k or (1 + (2 * k - 2) ^ 3 / 2))
            done = EE.update(DT, tr)
            local pz = EE.pose(enc)
            if pz.alpha < minAlpha then minAlpha = pz.alpha end
            if math.abs(pz.liftK) > maxLift then maxLift = math.abs(pz.liftK) end
            steps = steps + 1
        end
        local pz = EE.pose(enc)
        local endPose = { relOff = pz.relOff, liftK = pz.liftK, hidden = pz.hidden, alpha = pz.alpha, shadowA = pz.shadowA }
        local S = EE.state()
        local endShift = S and (math.abs(S.sideFrac) + math.abs(S.offFrac) + math.abs(S.dxK)) or 0
        local riseK = S and S.riseK or 1
        local handoff = EE.finish()
        local info = EE._last
        WorldRoad._travel = nil
        return { done = done, total = tr.duration + settle, endPose = endPose, endShift = endShift,
            riseK = riseK, handoff = handoff, info = info, steps = steps, dur = dur, settle = settle }
    end

    for _, r in ipairs(list) do
        local id = r.id
        local res = dryRun(id, false)
        t:truthy(id .. ": motor conclui a entrada", res ~= nil and res.done)
        if res then
            t:truthy(string.format("%s: duracao total %.2fs <= %.1fs", id, res.total, Data.BASE + Data.MAX_EXTRA),
                res.total <= Data.BASE + Data.MAX_EXTRA + 1e-6)
            local ep = res.endPose
            t:truthy(id .. ": termina no palco (relOff 0, sem lift, visivel, opaco, sombra cheia, sem deslocamento)",
                math.abs(ep.relOff) < 1e-6 and math.abs(ep.liftK) < 1e-6 and not ep.hidden
                and ep.alpha >= 0.999 and ep.shadowA >= 0.999 and res.endShift < 1e-6 and res.riseK >= 0.999)
            t:truthy(id .. ": handoff devolve um idle", res.handoff ~= nil and res.handoff.animation == "idle")
            if res.info and res.info.endFrame1 then
                t:eq(id .. ": handoff no quadro 0 do idle", res.handoff.currentFrame, 1)
            end
            local spec = Data.BY_ID[id] or Data.DEFAULT
            if spec.anchor and not spec.anchor.veil then
                t:truthy(id .. ": ancora nasce como prop", res.info.anchor ~= nil and res.info.anchor.anchor == true)
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
    return t:done()
end

return M
