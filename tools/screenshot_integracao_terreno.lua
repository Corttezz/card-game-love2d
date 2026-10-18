local M = {}

local TODS = { { "dia", 0 }, { "meio", 0.5 }, { "por", 1 } }
local SCENES = { "fork", "landmark", "viagem", "castelo" }

local function paintTop(width, topBarH)
    love.graphics.setColor(0.1, 0.08, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, width, topBarH)
    love.graphics.setColor(1, 1, 1, 1)
end

local function setup(bio, scene)
    local WorldRoad = require("src.ui.WorldRoad")
    local width, height = love.graphics.getDimensions()
    local topBarH = 80
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function tick(n, draw)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            if draw then
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
                WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
            end
        end
    end
    if scene == "castelo" then
        WorldRoad._segBase = 0
        WorldRoad._camZ = WorldRoad.TRAVEL_DISTANCE * 8 * 0.85
        tick(30, false)
    elseif scene == "viagem" then
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        WorldRoad._camZ = 5.5
        tick(30, false)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
        })
        tick(70, true)
    else
        WorldRoad._camZ = 5.5
        tick(30, false)
        require("src.i18n.I18n").init()
        require("src.i18n.I18n").setLocale("en", true)
        local MM = require("src.systems.MapManager")
        local nodes = {}
        for i, ty in ipairs({ "battle", "rest", "shop" }) do
            nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
        end
        WorldRoad.showFork(nodes, function() end)
        tick(20, true)
        if scene == "fork" then
            if WorldRoad._fork then WorldRoad._fork.hover = 2 end
        else
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[2]
            if b then
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            tick(85, true)
        end
    end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    return function()
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        paintTop(width, topBarH)
    end
end

function M.run(arg)
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local label, bioArg = tostring(arg or "captura"):match("^([^:]+):?(%d*)$")
    label = label or "captura"
    local bios = {}
    if bioArg and bioArg ~= "" then bios[1] = tonumber(bioArg) else bios[1] = 1 end
    local dir = "integracao_terreno/" .. label
    love.filesystem.createDirectory(dir)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return 100 end
    local saved = {}
    for _, bio in ipairs(bios) do
        for _, scene in ipairs(SCENES) do
            for _, td in ipairs(TODS) do
                local draw = setup(bio, scene)
                WorldRoad.setTimeOfDay(td[2], true)
                WorldRoad.update(1 / 30)
                draw()
                local path = string.format("%s/b%d_%s_%s.png", dir, bio, td[1], scene)
                love.graphics.captureScreenshot(function(imageData)
                    imageData:encode("png", path)
                end)
                love.graphics.present()
                saved[#saved + 1] = love.filesystem.getSaveDirectory() .. "/" .. path
            end
        end
    end
    love.timer.getTime = realTime
    for _, p in ipairs(saved) do print(p) end
    love.event.quit()
    return true
end

return M
