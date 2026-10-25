local M = {}

M.DT = 1 / 60
M.ACT = 5
M.FLOOR = 4

local function api() return _G.__cheatApi end
local function state() return api() and api().state() end

local function findSeed(MapManager, Rng, T)
    for s = 1, 400000 do
        Rng.setActive(Rng.new(s))
        local ty = T.legacyGenerate(MapManager, Rng, M.FLOOR, M.ACT, 3)
        if T.hasDup(ty) then return s, ty end
    end
end

local function typesStr(nodes)
    local o = {}
    for i, n in ipairs(nodes or {}) do o[i] = n.type end
    return table.concat(o, ",")
end

function M.run()
    local Flow = require("tools.estrada_fluxo")
    local T = require("tools.test_fork_types")
    local MapManager = require("src.systems.MapManager")
    local Rng = require("src.systems.Rng")
    local W, H = 1920, 1080
    local ok, err = Flow.boot(W, H)
    if not ok then print("[FAIL] boot: " .. tostring(err)) return false end
    local WorldRoad = require("src.ui.WorldRoad")
    local CheatMode = require("src.systems.CheatMode")
    local WE = require("engine.WeatherEngine")
    WE.disabled = true
    local dir = "fork_types"
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

    local function reopen(r, setup)
        r.floorInAct = M.FLOOR - 1
        r.currentFloor = (M.ACT - 1) * MapManager.FLOORS_PER_ACT + r.floorInAct
        r.pendingNodes = nil
        setup(r)
        WorldRoad._fork = nil
        WorldRoad._landmark = nil
        api().showMapSelection()
        settle(900)
    end

    local pass = true
    local okRun, errRun = pcall(function()
        CheatMode.rush = false
        CheatMode.goToAct(M.ACT, false)
        settle(900)
        local seed, legacy = findSeed(MapManager, Rng, T)
        print(("seed %s: regra antiga no ato %d andar %d = %s"):format(tostring(seed), M.ACT, M.FLOOR,
            table.concat(legacy or {}, ",")))
        local r = api().game().runManager.currentRun

        reopen(r, function()
            local nodes = {}
            for i, ty in ipairs(legacy) do nodes[i] = MapManager._makeNode(ty, M.FLOOR, M.ACT) end
            require("src.systems.EnemyRoster").assignNodes(r, nodes)
            r.pendingNodes = nodes
            r.floorInAct = M.FLOOR
            r.currentFloor = r.currentFloor + 1
        end)
        print("antes (regra antiga, forcado): " .. typesStr(r.pendingNodes))
        shoot("ato5_antes_regra_antiga")

        reopen(r, function() Rng.setActive(Rng.new(seed)) end)
        local real = typesStr(r.pendingNodes)
        print("depois (gerador real, mesma seed): " .. real)
        pass = pass and not T.hasDup((function()
            local o = {}
            for i, n in ipairs(r.pendingNodes) do o[i] = n.type end
            return o
        end)())
        shoot("ato5_depois_gerador_real")

        reopen(r, function()
            local nodes = {}
            for i, ty in ipairs({ "shop", "battle", "battle" }) do nodes[i] = MapManager._makeNode(ty, M.FLOOR, M.ACT) end
            require("src.systems.EnemyRoster").assignNodes(r, nodes)
            r.pendingNodes = nodes
            r.floorInAct = M.FLOOR
            r.currentFloor = r.currentFloor + 1
            api().game().runManager:repairPendingNodes()
        end)
        print("save reparado (shop,battle,battle): " .. typesStr(r.pendingNodes))
        shoot("ato5_save_reparado")
    end)
    if not okRun then print("[FAIL] " .. tostring(errRun)) pass = false end
    cv:release()
    Flow.shutdown()
    print((pass and "[ok] " or "[FAIL] ") .. love.filesystem.getSaveDirectory() .. "/" .. dir)
    return pass
end

return M
