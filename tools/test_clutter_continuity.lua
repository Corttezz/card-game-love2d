local TK = require("tools.testkit")

local M = {}

M.W, M.H = 1920, 1080
M.STEP = 0.04
M.DIST = 48
M.SLIP_PX = 2

local function stubImg(w, h)
    return { getWidth = function() return w end, getHeight = function() return h end }
end

local function makeEnv(bid, camZ)
    local WorldRoad = require("src.ui.WorldRoad")
    local g = WorldRoad.domeGeom(0, 52, M.W, M.H - 52)
    local imgs = {}
    return {
        g = g, x = 0, w = M.W, camZ = camZ, bid = bid,
        relCrest = 26, band = 9, tPow = 1.35,
        roadHalfK = 0.20, screenK = 1, pixRef = 2,
        getSprite = function(kind, v)
            local k = kind .. v
            imgs[k] = imgs[k] or stubImg(40 + #kind, 24 + v * 3)
            return imgs[k]
        end,
        wobble = function(z) return math.sin(z * 0.3) * 30 end,
        flipToSun = function(_, _, fb) return fb end,
        sunRight = true,
    }
end

local function key(p) return string.format("%s|%.4f|%d", p.bid, p.z, p.side) end

local function walk(t, bid)
    local GC = require("engine.GroundClutter")
    local seen, last = {}, {}
    local born, bornBad, gone, goneBad, slip, alphaBad, crossed = 0, 0, 0, 0, 0, 0, 0
    local front, back = {}, {}
    local env = makeEnv(bid, 0)
    for step = 0, math.floor(M.DIST / M.STEP) do
        env.camZ = step * M.STEP
        for i = #front, 1, -1 do front[i] = nil end
        for i = #back, 1, -1 do back[i] = nil end
        GC.collect(front, env)
        GC.collectBehind(back, env)
        local now = {}
        for _, p in ipairs(back) do
            local iw, ih = p.img:getWidth(), p.img:getHeight()
            local crest = env.g.crestYAt(p.px)
            now[key(p)] = { x = p.px, top = crest + (1 - p.em) * ih * p.s - ih * p.s, a = p.fk, s = p.s,
                w = iw * p.s, behind = true }
        end
        for _, p in ipairs(front) do
            local iw, ih = p.img:getWidth(), p.img:getHeight()
            now[key(p)] = { x = p.px, top = p.py - ih * p.s, a = p.fk, s = p.s, w = iw * p.s, behind = false }
        end
        for k, r in pairs(now) do
            local edge = r.x - r.w * 0.5 < 0 or r.x + r.w * 0.5 > M.W
            local p = last[k]
            if not p and step > 0 then
                born = born + 1
                if not r.behind and not edge then bornBad = bornBad + 1 end
            elseif p then
                if p.behind and not r.behind then
                    crossed = crossed + 1
                    if math.abs(p.x - r.x) > M.SLIP_PX or math.abs(p.s / r.s - 1) > 0.05 then slip = slip + 1 end
                end
                if math.abs((r.a or 1) - (p.a or 1)) > 0.2 then alphaBad = alphaBad + 1 end
            end
            seen[k] = true
        end
        for k, p in pairs(last) do
            if not now[k] then
                gone = gone + 1
                local edge = p.x - p.w * 0.5 < 0 or p.x + p.w * 0.5 > M.W
                if p.top < M.H and not edge then goneBad = goneBad + 1 end
            end
        end
        last = now
    end
    t:truthy(("%s: itens nascem atrás da crista e emergem (%d nascidos, %d brotaram no meio da tela)")
        :format(bid, born, bornBad), born > 20 and bornBad == 0)
    t:truthy(("%s: atravessam a crista sem saltar (%d travessias, %d saltos)"):format(bid, crossed, slip),
        crossed > 20 and slip == 0)
    t:truthy(("%s: saem só pela borda de baixo da tela (%d saíram, %d sumiram na tela)"):format(bid, gone, goneBad),
        gone > 20 and goneBad == 0)
    t:eq(("%s: alfa sem degrau de um passo para o outro"):format(bid), alphaBad, 0)
end

function M.run()
    local t = TK.new("detalhes de chão: nascem atrás da crista, emergem e saem pela borda, sem brotar")
    local GC = require("engine.GroundClutter")
    for bid in pairs(GC.DATA.biomes) do walk(t, bid) end
    do
        local env = makeEnv("fields", 10)
        env.bidPrev, env.bidK = "dusk", 0.3
        local out = {}
        GC.collect(out, env)
        local bad, nOld, nNew = 0, 0, 0
        for _, p in ipairs(out) do
            if p.bid == "dusk" then
                nOld = nOld + 1
                if math.abs(p.fk - 0.7) > 0.01 then bad = bad + 1 end
            else
                nNew = nNew + 1
                if math.abs(p.fk - 0.3) > 0.01 then bad = bad + 1 end
            end
        end
        t:truthy(("troca de bioma: velho e novo juntos (%d e %d)"):format(nOld, nNew), nOld > 5 and nNew > 5)
        t:eq("troca de bioma: o detalhe velho esmaece enquanto o novo surge no mesmo lugar", bad, 0)
    end
    do
        local src = love.filesystem.read("src/data/ground_clutter.lua") or ""
        t:falsy("sem corte por t no meio da tela (tMin saiu)", src:find("tMin", 1, true) ~= nil)
    end
    return t:done()
end

return M
