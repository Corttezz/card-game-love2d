local M = {}

M.DT = 1 / 60

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end

function M.run(tag)
    local Flow = require("tools.estrada_fluxo")
    local MapManager = require("src.systems.MapManager")
    local W = tonumber(os.getenv("SHOT_W") or "") or 1920
    local H = tonumber(os.getenv("SHOT_H") or "") or 1080
    local ok, err = Flow.boot(W, H)
    if not ok then print("[FAIL] boot: " .. tostring(err)) return false end
    local WorldRoad = require("src.ui.WorldRoad")
    local CheatMode = require("src.systems.CheatMode")
    require("engine.WeatherEngine").disabled = true
    local dir = "act_map_v4"
    love.filesystem.createDirectory(dir)
    local cv = love.graphics.newCanvas(W, H)
    tag = tag or "depois"

    local function frames(n)
        for _ = 1, n do love.update(M.DT); love.graphics.present() end
    end

    local function settle(maxN)
        for _ = 1, maxN or 900 do
            love.update(M.DT)
            if state() == "mapSelection" then
                CheatMode.rush = false
                CheatMode.pending().forkPick = nil
            end
            local f = WorldRoad._fork
            love.graphics.present()
            if state() == "mapSelection" and f and (f.animIn or 0) >= 1 then break end
        end
        frames(30)
    end

    local function shoot(name)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        love.draw()
        love.graphics.setCanvas()
        love.graphics.present()
        local d = cv:newImageData()
        d:encode("png", ("%s/%s_%dx%d_%s.png"):format(dir, tag, W, H, name))
        d:release()
        print("  foto " .. name)
    end

    local function openMap()
        if not _G.actMapScreen:isVisible() then _G.toggleActMap() end
        frames(40)
    end
    local function closeMap()
        if _G.actMapScreen:isVisible() then _G.toggleActMap() end
        frames(5)
    end

    local function walkTo(r, map, floor)
        local lanes, lane = {}, nil
        for f = 1, floor do
            local row = map.floors[f]
            if not lane then
                lane = 1 + (f % #row)
            else
                local prev = map.floors[f - 1][lanes[f - 1]]
                local kids = prev.mapNext or { 1 }
                lane = kids[1 + (f % #kids)]
            end
            lanes[f] = lane
        end
        map.path = lanes
        local node = map.floors[floor][lanes[floor]]
        r.currentNode = MapManager.copyNode(node)
        r.floorInAct = floor
        r.currentFloor = (map.baseFloor or 1) + floor - 1
        r.pendingNodes = nil
        WorldRoad._fork = nil
        WorldRoad._landmark = nil
        api().showMapSelection()
        settle(900)
        return node
    end

    local pass = true
    local okRun, errRun = pcall(function()
        CheatMode.rush = false
        CheatMode.goToAct(1, false)
        settle(900)
        local r = api().game().runManager.currentRun
        openMap()
        shoot("andar01")
        local hover = os.getenv("SHOT_HOVER") ~= "0"
        closeMap()
        local map = r.actMap
        pass = pass and map ~= nil and #map.floors == MapManager.FLOORS_PER_ACT
        local F = #map.floors
        for _, fl in ipairs({ 6, F }) do
            walkTo(r, map, fl - 1)
            openMap()
            shoot(("andar%02d"):format(fl))
            if hover and fl == 6 and _G.actMapScreen.hoverDemo then
                _G.actMapScreen:hoverDemo()
                frames(10)
                shoot("andar06_tooltip")
            end
            closeMap()
        end
    end)
    if not okRun then print("[FAIL] " .. tostring(errRun)) pass = false end
    cv:release()
    Flow.shutdown()
    print((pass and "[ok] " or "[FAIL] ") .. love.filesystem.getSaveDirectory() .. "/" .. dir)
    return pass
end

return M
