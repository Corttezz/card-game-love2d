local M = {}

local CREATURES = { "plague_rats", "blight_bull", "hollow_farmer" }

local function restKey(bid)
    if bid == "fields" then return "landmark_rest" end
    return bid .. "_landmark_rest"
end

function M.run(tag)
    tag = tag or "antes"
    if tag == "dump" then return M.dump() end
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local biomes = require("src.data.biomes")
    local T0 = 1000
    love.timer.getTime = function() return T0 end
    local width, height = love.graphics.getDimensions()
    local topBarH = 80
    local out = {}

    local function freeze()
        love.math.setRandomSeed(42)
        math.randomseed(42)
        WorldRoad._rng = love.math.newRandomGenerator(0xC0FFEE)
        WorldRoad.clearCache()
        WorldRoad._time = 0
        WorldRoad._birds, WorldRoad._critters, WorldRoad._ambient = {}, {}, {}
        WorldRoad._birdTimer = 1e9
        WorldRoad.setTimeOfDay(0.5, true)
    end

    local function settle(bio, camZ, ticks)
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = camZ
        for _ = 1, ticks or 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
    end

    local ShadowEngine = require("engine.ShadowEngine")
    local origSprite, origQueue, origSil =
        ShadowEngine.sprite, ShadowEngine.queue, ShadowEngine.silhouette
    local function mute(on)
        if on then
            ShadowEngine.sprite = function() return true end
            ShadowEngine.queue = function() return true end
            ShadowEngine.silhouette = function() return true end
        else
            ShadowEngine.sprite, ShadowEngine.queue, ShadowEngine.silhouette =
                origSprite, origQueue, origSil
        end
    end

    local shoot
    shoot = function(name, bio, pre)
        if not name:match("_ns$") then
            mute(true)
            shoot(name .. "_ns", bio, pre)
            mute(false)
        end
        if pre then pre() end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        WorldRoad.drawOverlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
        love.graphics.setColor(1, 1, 1, 1)
        local path = "sombras_" .. tag .. "_" .. name .. ".png"
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", path)
            print("[sombras] salvo " .. path)
        end)
        love.graphics.present()
        out[#out + 1] = path
    end

    for bio = 1, 6 do
        freeze()
        settle(bio, 5.5)
        WorldRoad._landmark = { key = restKey(biomes[bio].id),
            z = WorldRoad._camZ + 4.0, size = 3.6, phase = 0 }
        shoot("rest" .. bio, bio)
    end
    freeze()
    settle(1, 5.5)
    WorldRoad._landmark = { key = "landmark_chest",
        z = WorldRoad._camZ + 4.0, size = 2.6, phase = 0 }
    shoot("chest1", 1)
    WorldRoad._landmark = nil

    for bio = 1, 6 do
        freeze()
        settle(bio, 5.5)
        shoot("props" .. bio, bio)
    end

    freeze()
    settle(2, 5.5)
    WorldRoad.showFork({ { type = "battle" }, { type = "shop" }, { type = "event" } },
        function() end)
    for _ = 1, 40 do WorldRoad.update(1 / 30) end
    shoot("fork", 2)
    WorldRoad._fork = nil

    for i, nodes in ipairs({
        { { type = "battle" }, { type = "shop" }, { type = "event" } },
        { { type = "elite" }, { type = "mini_boss" }, { type = "treasure" } },
        { { type = "rest" }, { type = "battle" }, { type = "rest" } },
    }) do
        freeze()
        settle(2, 5.5)
        WorldRoad._props = {}
        WorldRoad.showFork(nodes, function() end)
        for _ = 1, 40 do WorldRoad.update(1 / 30) end
        shoot("forkclean" .. i, 2)
        WorldRoad._fork = nil
    end

    local I18n = require("src.i18n.I18n")
    I18n.init()
    local Game = require("src.core.Game")
    local function plant(sid, dead, bio)
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        _G.game = game
        game.enemy.spriteId = sid
        game.enemy.isBoss = false
        EnemyRenderer.resetRun()
        freeze()
        settle(bio or 1, 6)
        for _ = 1, 30 do EnemyRenderer.update(1 / 30) end
        if dead then
            game.enemy.health = 0
            EnemyRenderer.triggerDeath(sid)
            for _ = 1, 45 do
                EnemyRenderer.update(1 / 30)
                WorldRoad.update(1 / 30)
            end
        end
        local cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarH, width, height - topBarH)
        return function()
            WorldRoad.setBattleEnemyDraw(function()
                EnemyRenderer.draw(game, cx, cy)
            end, cy)
        end
    end
    for _, sid in ipairs(CREATURES) do
        shoot("up_" .. sid, 1, plant(sid, false, 1))
        shoot("dead_" .. sid, 1, plant(sid, true, 1))
    end
    shoot("float", 6, plant("dusk_shade", false, 6))
    WorldRoad.setBattleEnemyDraw(nil)

    print("[sombras] save dir: " .. love.filesystem.getSaveDirectory())
    print("[sombras] " .. #out .. " capturas (" .. tag .. ")")
    love.event.quit()
    return true
end

function M.dump()
    require("src.ui.PixelCanvas").enableNearest()
    local WorldRoad = require("src.ui.WorldRoad")
    local width, height = love.graphics.getDimensions()
    local n = 0
    for bio = 1, 6 do
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for _ = 1, 3 do
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, 80, width, height - 80, bio)
            WorldRoad._camZ = WorldRoad._camZ + 6
            WorldRoad.update(1 / 30)
        end
        for key, img in pairs(WorldRoad._spriteCache) do
            if img and type(img) ~= "boolean" and img.getWidth then
                local cv = love.graphics.newCanvas(img:getWidth(), img:getHeight())
                love.graphics.setCanvas(cv)
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, 0, 0)
                love.graphics.setCanvas()
                cv:newImageData():encode("png", "sprite_" .. key .. ".png")
                n = n + 1
            end
        end
    end
    print("[sombras] " .. n .. " sprites despejados em " .. love.filesystem.getSaveDirectory())
    love.event.quit()
    return true
end

return M
