local M = {}

local VW, VH = (os.getenv("LOJA_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
VW, VH = tonumber(VW) or 1920, tonumber(VH) or 1080
local TOPBAR = 80

local FORKS = {
    shop = { nodes = { "battle", "elite", "shop" }, idx = 3 },
    event = { nodes = { "event", "rest", "battle" }, idx = 1 },
}

local cv
local dir
local saved = 0

local function canvas()
    if cv then return cv end
    cv = love.graphics.newCanvas(VW, VH)
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    return cv
end

local function setup(bio)
    local WorldRoad = require("src.ui.WorldRoad")
    canvas()
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(tonumber(os.getenv("LOJA_SEED") or "") or 7)
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function frame()
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, TOPBAR, VW, VH - TOPBAR, bio)
        WorldRoad.drawOverlays(0, TOPBAR, VW, VH - TOPBAR)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, VW, TOPBAR)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setCanvas()
    end
    local function tick(n, draw)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            if draw then frame() end
        end
    end
    return WorldRoad, frame, tick
end

local function boxOf(WorldRoad, idx)
    local f = WorldRoad._fork
    local ge = f and f._geo and f._geo[idx]
    if ge and ge.ih then
        return ge.px, ge.py, ge.iw * ge.s, ge.ih * ge.s
    end
    local lm = WorldRoad._lmMark
    if lm and lm.h and lm.drawn then return lm.px, lm.py, lm.w, lm.h end
end

local function save(name, WorldRoad, idx, full)
    local data = cv:newImageData()
    if full then data:encode("png", dir .. "/" .. name .. ".png") end
    local px, py, bw, bh = boxOf(WorldRoad, idx)
    if px then
        local x1 = math.max(0, math.floor(px - bw * 0.95))
        local x2 = math.min(VW, math.floor(px + bw * 0.95))
        local y1 = math.max(0, math.floor(py - bh * 1.15))
        local y2 = math.min(VH, math.floor(py + bh * 0.45))
        if x2 - x1 > 4 and y2 - y1 > 4 then
            local crop = love.image.newImageData(x2 - x1, y2 - y1)
            crop:paste(data, 0, 0, x1, y1, x2 - x1, y2 - y1)
            crop:encode("png", dir .. "/" .. name .. "_base.png")
            crop:release()
        end
    end
    data:release()
    saved = saved + 1
end

local function openFork(WorldRoad, tick, kind, seqName, frame)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    I18n.setLocale("en", true)
    local MM = require("src.systems.MapManager")
    local nodes = {}
    for i, ty in ipairs(FORKS[kind].nodes) do
        nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
    end
    WorldRoad._camZ = 5.5
    tick(30, false)
    WorldRoad.showFork(nodes, function() end)
    for i = 1, 20 do
        tick(1, true)
        if seqName and (i == 2 or i == 5 or i == 10) then
            save(string.format("%s_in%02d", seqName, i), WorldRoad, FORKS[kind].idx, false)
        end
    end
end

local function clickMark(WorldRoad, idx)
    local f = WorldRoad._fork
    local b = f and f.markBoxes and f.markBoxes[idx]
    if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
end

local function shot(bio, kind, tod, seq)
    local WorldRoad, frame, tick = setup(bio)
    WorldRoad.setTimeOfDay(tod, true)
    local idx = FORKS[kind].idx
    openFork(WorldRoad, tick, kind, seq and kind, frame)
    if WorldRoad._fork then WorldRoad._fork.hover = nil end
    WorldRoad._blend = nil
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
    frame()
    save(string.format("fork_%s", kind), WorldRoad, idx, true)
    clickMark(WorldRoad, idx)
    for i = 1, 85 do
        tick(1, true)
        if seq and i % 12 == 0 then
            save(string.format("%s_conv%02d", kind, i), WorldRoad, idx, false)
        end
    end
    WorldRoad._blend = nil
    WorldRoad.setTimeOfDay(tod, true)
    WorldRoad.update(1 / 30)
    frame()
    save(string.format("lm_%s", kind), WorldRoad, idx, true)
    if seq then
        WorldRoad.travel({})
        for i = 1, 60 do
            tick(1, true)
            if i % 6 == 0 and WorldRoad._lmMark and WorldRoad._lmMark.drawn then
                save(string.format("%s_out%02d", kind, i), WorldRoad, idx, true)
            end
        end
    end
end

function M.run(arg)
    local act, what = tostring(arg or "1"):match("^(%d)[:]?(.*)$")
    act = tonumber(act) or 1
    dir = string.format("loja_base/%s/ato%d", os.getenv("LOJA_TAG") or "raw", act)
    love.filesystem.createDirectory(dir)
    require("src.ui.PixelCanvas").enableNearest()
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local tod = tonumber(os.getenv("LOJA_TOD") or "") or 0.65
    local seq = os.getenv("LOJA_SEQ") == "1"
    for _, k in ipairs({ "shop", "event" }) do
        if what == "" or what == k then shot(act, k, tod, seq) end
    end
    love.timer.getTime = realTime
    print(love.filesystem.getSaveDirectory() .. "/" .. dir .. " " .. saved)
    love.event.quit()
    return true
end

return M
