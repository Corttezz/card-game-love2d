local M = {}

local function virtual()
    local vw, vh = (os.getenv("BORDA_VIRTUAL") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw), tonumber(vh)
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end
    return vw, vh
end

local function setup(WorldRoad, bio, scene, width, height, topBarH, canvas)
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    love.math.setRandomSeed(7)
    math.randomseed(7)
    WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
    WorldRoad._time = 0
    WorldRoad._birds, WorldRoad._critters, WorldRoad._ambient = {}, {}, {}
    WorldRoad.setBiome(bio)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    local function tick(n)
        for _ = 1, n do
            WorldRoad.update(1 / 30)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
            love.graphics.setCanvas()
        end
    end
    WorldRoad._camZ = 5.5
    tick(30)
    if scene == "fork" or scene == "abrindo" then
        require("src.i18n.I18n").init()
        require("src.i18n.I18n").setLocale("en", true)
        local MM = require("src.systems.MapManager")
        local nodes = {}
        for i, ty in ipairs({ "battle", "rest", "shop" }) do
            nodes[i] = { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) }
        end
        WorldRoad.showFork(nodes, function() end)
        tick(scene == "fork" and 60 or 6)
    elseif scene == "viagem" then
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
        })
        tick(40)
    else
        tick(60)
    end
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
end

function M.run(arg)
    local width, height = virtual()
    local canvas = love.graphics.newCanvas(width, height)
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local GrassField = require("engine.GrassField")
    local label, bios, scenes, layer, seq = tostring(arg or "atual"):match("^([^:]+):?([%d,]*):?([%a,]*):?(%a*):?(%d*)$")
    label = label or "atual"
    local bl = {}
    for b in (bios ~= "" and bios or "1,2,3,4,5,6"):gmatch("%d+") do bl[#bl + 1] = tonumber(b) end
    local sl = {}
    for s in (scenes ~= "" and scenes or "fork,tronco"):gmatch("%a+") do sl[#sl + 1] = s end
    layer = (layer ~= "" and layer) or "all"
    local nseq = tonumber(seq) or 1
    local realGrass = GrassField.draw
    if layer == "nograss" then GrassField.draw = function() end end
    local dir = "borda_estrada/" .. label
    love.filesystem.createDirectory(dir)
    local realTime = love.timer.getTime
    local clock = 100
    love.timer.getTime = function() return clock end
    local topBarH = 80
    local tod = tonumber(os.getenv("BORDA_TOD") or "0.85")
    for _, bio in ipairs(bl) do
        for _, scene in ipairs(sl) do
            setup(WorldRoad, bio, scene, width, height, topBarH, canvas)
            WorldRoad.setTimeOfDay(tod, true)
            WorldRoad.update(1 / 30)
            for si = 1, nseq do
                if si > 1 then
                    clock = clock + 1 / 30
                    WorldRoad.update(1 / 30)
                end
                love.graphics.setCanvas(canvas)
                love.graphics.clear(0, 0, 0, 1)
                WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
                WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
                love.graphics.setCanvas()
                local path = string.format("%s/b%d_%s_%s_%dx%d%s.png", dir, bio, scene, layer,
                    width, height, nseq > 1 and string.format("_s%02d", si) or "")
                canvas:newImageData():encode("png", path)
                print(love.filesystem.getSaveDirectory() .. "/" .. path)
            end
        end
    end
    GrassField.draw = realGrass
    love.timer.getTime = realTime
    canvas:release()
    love.event.quit()
    return true
end

return M
