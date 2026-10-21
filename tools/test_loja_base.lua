local TK = require("tools.testkit")
local M = {}

local function setupFork(WorldRoad, act, types)
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(11 + act)
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad._camZ = 5.5
    for _ = 1, 20 do WorldRoad.update(1 / 30) end
    local MM = require("src.systems.MapManager")
    local nodes = {}
    for i, ty in ipairs(types) do nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) } end
    WorldRoad.showFork(nodes, function() end)
end

function M.run()
    local t = TK.new("base da loja e do evento: conjunto sempre junto do marco, fora do rótulo")
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    local WorldRoad = require("src.ui.WorldRoad")
    local LB = require("src.ui.LandmarkBase")
    local FontManager = require("src.ui.FontManager")
    local W, H = love.graphics.getDimensions()
    local cv = love.graphics.newCanvas(W, H)
    local realUnder, realOver = LB.under, LB.over
    local calls = {}
    LB.under = function(key, ...)
        local ok = realUnder(key, ...)
        if ok then calls[#calls + 1] = { key = key, under = true } end
        return ok
    end
    LB.over = function(key, ...)
        local ok = realOver(key, ...)
        local c = calls[#calls]
        if ok and c and c.key == key then
            c.over, c.x1, c.y1, c.x2, c.y2, c.n = true, LB.box.x1, LB.box.y1, LB.box.x2, LB.box.y2, LB.box.n
        end
        return ok
    end
    local function frame(act)
        for i = #calls, 1, -1 do calls[i] = nil end
        WorldRoad.update(1 / 30)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, 52, W, H - 52, act)
        love.graphics.setCanvas()
    end
    local function find(key)
        for _, c in ipairs(calls) do if c.key == key then return c end end
    end
    local missing, partial, onLabel, lmMiss, frames, lmSeen = {}, {}, {}, {}, 0, 0
    for act = 1, 6 do
        setupFork(WorldRoad, act, { "shop", "battle", "event" })
        for fi = 1, 26 do
            frame(act)
            frames = frames + 1
            local f = WorldRoad._fork
            if f and f._geo then
                local font = FontManager.getFont(13)
                local labels = {}
                for i = 1, f.n do
                    local ge = f._geo[i]
                    if ge then
                        local label = WorldRoad.forkLabel(f.nodes[i])
                        local pw = font:getWidth(label) + 16
                        local pyc = ge.py - ge.ih * ge.s - 26
                        labels[#labels + 1] = { ge.px - pw / 2, pyc, ge.px + pw / 2, pyc + 20 }
                    end
                end
                for i = 1, f.n do
                    local ge = f._geo[i]
                    local ty = f.nodes[i].type
                    if ge and (ty == "shop" or ty == "event") then
                        local key
                        for _, c in ipairs(calls) do
                            if c.key:match("landmark_" .. ty .. "$") then key = c.key end
                        end
                        local c = key and find(key)
                        if not c then
                            missing[#missing + 1] = act .. ":" .. ty .. ":" .. fi
                        elseif not c.over then
                            partial[#partial + 1] = act .. ":" .. ty .. ":" .. fi
                        else
                            for _, L in ipairs(labels) do
                                if c.x1 < L[3] and c.x2 > L[1] and c.y1 < L[4] and c.y2 > L[2] then
                                    onLabel[#onLabel + 1] = string.format("%d:%s:%d y1=%d label=%d", act, ty, fi,
                                        math.floor(c.y1), math.floor(L[4]))
                                end
                            end
                        end
                    end
                end
            end
        end
        local f = WorldRoad._fork
        local b = f and f.markBoxes and f.markBoxes[1]
        if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
        for fi = 1, 110 do
            frame(act)
            local lm = WorldRoad._lmMark
            if lm and lm.drawn and lm.lm and lm.lm == WorldRoad._landmark and lm.a and lm.a > 0.01
               and lm.lm.key:match("shop$") then
                lmSeen = lmSeen + 1
                local c = find(lm.lm.key)
                if not (c and c.over) then lmMiss[#lmMiss + 1] = act .. ":" .. fi end
            end
            if fi == 90 then WorldRoad.travel({}) end
        end
    end
    LB.under, LB.over = realUnder, realOver
    cv:release()
    t:eq("marco da encruzilhada desenhado sem a base (" .. frames .. " quadros): " .. table.concat(missing, " "), #missing, 0)
    t:eq("base sem a camada da frente: " .. table.concat(partial, " "), #partial, 0)
    t:eq("base encostando em rótulo: " .. table.concat(onLabel, " "), #onLabel, 0)
    t:truthy("loja vista na chegada e na partida (" .. lmSeen .. " quadros)", lmSeen > 120)
    t:eq("loja da chegada/partida desenhada sem a base: " .. table.concat(lmMiss, " "), #lmMiss, 0)
    return t:done()
end

return M
