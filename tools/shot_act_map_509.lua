local M = {}

M.DT = 1 / 60

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end

function M.run()
    local Flow = require("tools.estrada_fluxo")
    local MapManager = require("src.systems.MapManager")
    local W, H = 1920, 1080
    local ok, err = Flow.boot(W, H)
    if not ok then print("[FAIL] boot: " .. tostring(err)) return false end
    local WorldRoad = require("src.ui.WorldRoad")
    local CheatMode = require("src.systems.CheatMode")
    local WE = require("engine.WeatherEngine")
    WE.disabled = true
    local dir = "act_map_509"
    love.filesystem.createDirectory(dir)
    local cv = love.graphics.newCanvas(W, H)

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
        for _ = 1, 30 do love.update(M.DT); love.graphics.present() end
    end

    local drew = false
    local function shoot(name)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()
        love.draw()
        love.graphics.setCanvas()
        love.graphics.present()
        local d = cv:newImageData()
        d:encode("png", dir .. "/" .. name .. ".png")
        d:release()
    end

    local pass = true
    local okRun, errRun = pcall(function()
        CheatMode.rush = false
        CheatMode.goToAct(1, false)
        settle(900)
        local r = api().game().runManager.currentRun
        print("estado: " .. tostring(state()) .. " andar " .. tostring(r.floorInAct))
        shoot("ato1_andar1")
        _G.toggleActMap()
        for _ = 1, 40 do love.update(M.DT); love.graphics.present() end
        shoot("ato1_andar1_mapa")
        _G.toggleActMap()
        local map = r.actMap
        pass = pass and map ~= nil
        if map then
            local best = map.floors[3][1]
            for _, n in ipairs(map.floors[3]) do
                if #(n.mapNext or {}) > #(best.mapNext or {}) then best = n end
            end
            map.path = { [3] = best.mapLane }
            local lane = best.mapLane
            for f = 2, 1, -1 do
                for _, p in ipairs(map.floors[f]) do
                    local hit = false
                    for _, j in ipairs(p.mapNext or {}) do hit = hit or j == lane end
                    if hit then lane = p.mapLane break end
                end
                map.path[f] = lane
            end
            r.currentNode = MapManager.copyNode(best)
            r.floorInAct = 3
            r.currentFloor = (map.baseFloor or 1) + 2
            r.pendingNodes = nil
            WorldRoad._fork = nil
            WorldRoad._landmark = nil
            api().showMapSelection()
            settle(900)
            print("andar 4, opções: " .. #(r.pendingNodes or {}) .. " de " .. #(best.mapNext or {}) .. " filhos")
            pass = pass and #(r.pendingNodes or {}) == #(best.mapNext or {})
            shoot("ato1_andar4")
            _G.toggleActMap()
            for _ = 1, 40 do love.update(M.DT); love.graphics.present() end
            drew = _G.actMapScreen:isVisible()
            shoot("ato1_andar4_mapa")
            _G.toggleActMap()
        end
    end)
    if not okRun then print("[FAIL] " .. tostring(errRun)) pass = false end
    pass = pass and drew
    cv:release()
    Flow.shutdown()
    print((pass and "[ok] " or "[FAIL] ") .. love.filesystem.getSaveDirectory() .. "/" .. dir)
    return pass
end

return M
