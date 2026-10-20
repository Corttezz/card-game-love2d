local M = {}

M.MIN_ALPHA = 0.999
M.VW, M.VH = 1920, 1080
M.TREE_HALF = 0.36
M.NEAR_T = 0.55
M.TREE_TOP = 0.92

local function crossfading(WorldRoad)
    if WorldRoad._blend then return true end
    for _, p in ipairs(WorldRoad._props or {}) do
        if p.swapT or p.ghost then return true end
    end
    return false
end

local function phaseOf(WorldRoad)
    local f = WorldRoad._fork
    if f then return f.converge and "converge" or "fork" end
    if WorldRoad._travel then return "travel" end
    if WorldRoad._castleTop and WorldRoad._castleTop.progress > 0.5 then return "castle" end
    return "stop"
end

function M.capture(act, seed, scenario)
    local WorldRoad = require("src.ui.WorldRoad")
    local PC = WorldRoad.PropCut
    local Cont = require("tools.test_scene_continuity")
    local log = { densO = {}, roadL = {}, near = {}, cover = {}, dens = {}, dframes = {}, frames = 0, low = {}, pops = {}, draws = 0, lowN = 0, minA = 1, phases = {} }
    local frame = 0
    local fade = false
    local seen, prev = {}, {}
    local origDraw = PC.draw
    PC.draw = function(img, kind, ...)
        if PC.kinds[kind] then
            local _, _, _, a = love.graphics.getColor()
            log.draws = log.draws + 1
            if not fade and a < M.MIN_ALPHA then
                log.lowN = log.lowN + 1
                log.minA = math.min(log.minA, a)
                local ph = phaseOf(WorldRoad)
                log.phases[ph] = (log.phases[ph] or 0) + 1
                if #log.low < 12 then
                    log.low[#log.low + 1] = { frame = frame, kind = kind, a = a, phase = ph }
                end
            end
        end
        return origDraw(img, kind, ...)
    end
    local onRoad = {}
    local cover = {}
    local font13 = require("src.ui.FontManager").getFont(13)
    WorldRoad._traceVeg = function(p, a, x, y, w, h, t, src, em)
        local f = WorldRoad._fork
        if f and f.offK and not f.converge and (f.animIn or 0) > 0.5 and a > 0.5 then
            local rel = p.z - WorldRoad._camZ
            local k = math.min(1, math.max(0, (rel - 10) / 7.5))
            k = k * k * (3 - 2 * k)
            local tt = src == "behind" and 0 or t
            local hc = 0.15 * M.VW * (0.30 + 0.70 * (tt ^ 1.15)) * 0.78
            for i = 1, f.n do
                if f.dirs[i] ~= 0 and rel > 8.5 and math.abs(x - (M.VW * 0.5 + f.offK[i] * M.VW * k)) < hc then
                    if not onRoad[p.uid or 0] and #log.roadL < 6 then
                        log.roadL[#log.roadL + 1] = string.format("    ramo f=%d uid=%d %s ramo=%d off=%.3f rel=%.1f x=%.0f %s",
                            frame, p.uid or 0, p.kind, i, f.offK[i], rel, x, src)
                    end
                    onRoad[p.uid or 0] = true
                end
            end
        end
        if f and f._geo and not f.converge and src == "front" and a > 0.02 then
            local relT = p.z - WorldRoad._camZ
            local relM = f.markZ - WorldRoad._camZ
            for i = 1, f.n do
                local geo = f._geo[i]
                if geo and geo.aMul > 0.5 and relT < relM then
                    local label = WorldRoad.forkLabel(f.nodes[i]) or ""
                    local hw = math.max(geo.iw * geo.s * 0.5, (font13:getWidth(label) + 16) * 0.5)
                    local mx1, mx2 = geo.px - hw, geo.px + hw
                    local my1, my2 = geo.py - geo.ih * geo.s - 26, geo.py
                    local tx1, tx2 = x - w * M.TREE_HALF, x + w * M.TREE_HALF
                    local ty1 = y - h * M.TREE_TOP
                    if tx1 < mx2 and tx2 > mx1 and ty1 < my2 and y > my1 and not cover[p.uid or 0] then
                        cover[p.uid or 0] = true
                        log.cover[#log.cover + 1] = { frame = frame, uid = p.uid or 0, kind = p.kind, mark = i,
                            rel = relT, x = x, y = y, phase = phaseOf(WorldRoad) }
                    end
                end
            end
        end
        if a > 0.02 and x + w * 0.5 > 0 and x - w * 0.5 < M.VW and y - h < M.VH then
            local ph = phaseOf(WorldRoad)
            log.dens[ph] = (log.dens[ph] or 0) + 1
            if a >= M.MIN_ALPHA then log.densO[ph] = (log.densO[ph] or 0) + 1 end
            if src == "front" and t > M.NEAR_T then log.near[ph] = (log.near[ph] or 0) + 1 end
        end
        if a > 0.02 then
            seen[p.uid or 0] = { x = x, y = y, w = w, h = h, t = t, src = src, em = em or 1,
                kind = p.kind, a = a }
        end
    end
    local lastPop = WorldRoad._populateFrame
    local origPresent = love.graphics.present
    love.graphics.present = function(...)
        local popF = WorldRoad._populateFrame
        local fresh = popF ~= lastPop
        lastPop = popF
        if frame > 0 and not fade and not fresh then
            for uid, c in pairs(prev) do
                if not seen[uid] then
                    local onScreen = c.x + c.w * 0.5 > 0 and c.x - c.w * 0.5 < M.VW and c.y - c.h < M.VH and c.y < M.VH + 4
                    local emerged = (c.src == "front" and c.t > 0.03) or (c.src == "behind" and c.em > 0.35)
                    if onScreen and emerged and #log.pops < 400 then
                        log.pops[#log.pops + 1] = { frame = frame, uid = uid, kind = c.kind, src = c.src,
                            x = c.x, y = c.y, t = c.t, phase = phaseOf(WorldRoad) }
                    end
                end
            end
        end
        local f = WorldRoad._fork
        if f and f.offK then
            for i = 1, f.n do
                if f.dirs[i] ~= 0 and f.offK[i] then log.offMax = math.max(log.offMax or 0, math.abs(f.offK[i])) end
            end
        end
        local ph = phaseOf(WorldRoad)
        log.dframes[ph] = (log.dframes[ph] or 0) + 1
        prev, seen = seen, {}
        frame = frame + 1
        fade = crossfading(WorldRoad)
        return origPresent(...)
    end
    local ok, res = pcall(Cont.capture, act, seed, scenario)
    PC.draw = origDraw
    WorldRoad._traceVeg = nil
    love.graphics.present = origPresent
    if not ok then error(res) end
    log.frames = frame
    log.onRoad = 0
    for _ in pairs(onRoad) do log.onRoad = log.onRoad + 1 end
    return log
end

function M.run(arg)
    io.stdout:setvbuf("line")
    local acts = { 1, 2, 3, 4, 5, 6 }
    local seeds = { 0xC0FFEE }
    local scenarios = { "path3", "resumefork", "castle" }
    if arg == "all" then
        seeds = { 0xC0FFEE, 7331 }
        scenarios = { "path1", "path3", "lm2", "resumefork", "castle" }
    elseif arg and arg ~= "" then
        local a, s, sc = arg:match("^(%d*):?(%d*):?(%w*)$")
        if a and a ~= "" then acts = { tonumber(a) } end
        if s and s ~= "" then seeds = { tonumber(s) } end
        if sc and sc ~= "" then scenarios = { sc } end
    end
    local bad, total = 0, 0
    for _, act in ipairs(acts) do
        for _, seed in ipairs(seeds) do
            for _, sc in ipairs(scenarios) do
                local log = M.capture(act, seed, sc)
                total = total + 1
                local fail = log.lowN > 0 or #log.pops > 0 or #log.cover > 0
                local dn = {}
                for k, n in pairs(log.dens) do dn[#dn + 1] = string.format("%s=%.1f", k, n / math.max(1, log.dframes[k] or 1)) end
                table.sort(dn)
                local no = {}
                for k, n in pairs(log.dframes) do no[#no + 1] = string.format("%s=%.1f", k, (log.densO[k] or 0) / math.max(1, n)) end
                table.sort(no)
                local nr = {}
                for k, n in pairs(log.dframes) do nr[#nr + 1] = string.format("%s=%.2f", k, (log.near[k] or 0) / math.max(1, n)) end
                table.sort(nr)
                if fail then bad = bad + 1 end
                local ph = {}
                for k, n in pairs(log.phases) do ph[#ph + 1] = k .. "=" .. n end
                table.sort(ph)
                print(string.format("[%s] a%d/%s/%d quadros=%d desenhos=%d translucidos=%d alpha_min=%.3f somem=%d cobre_marco=%d aviso_arvore_no_ramo=%d ramo_max=%.3f densidade %s perto %s opacas %s | %s",
                    fail and "FAIL" or "ok", act, sc, seed, log.frames, log.draws, log.lowN, log.minA,
                    #log.pops, #log.cover, log.onRoad, log.offMax or 0, table.concat(dn, " "), table.concat(nr, " "), table.concat(no, " "), table.concat(ph, " ")))
                for i, l in ipairs(log.low) do
                    if i > 4 then break end
                    print(string.format("    translucido f=%d %s a=%.3f %s", l.frame, l.kind, l.a, l.phase))
                end
                for _, l in ipairs(log.roadL) do print(l) end
                for i, c in ipairs(log.cover) do
                    if i > 6 then break end
                    print(string.format("    cobre f=%d uid=%d %s marco=%d rel=%.1f (%.0f,%.0f) %s",
                        c.frame, c.uid, c.kind, c.mark, c.rel, c.x, c.y, c.phase))
                end
                for i, p in ipairs(log.pops) do
                    if i > 6 then break end
                    print(string.format("    some f=%d uid=%d %s %s t=%.2f (%.0f,%.0f) %s",
                        p.frame, p.uid, p.kind, p.src, p.t, p.x, p.y, p.phase))
                end
            end
        end
    end
    print(string.format("TOTAL %d cenas, %d com vegetacao translucida ou sumindo", total, bad))
    return bad == 0
end

return M
