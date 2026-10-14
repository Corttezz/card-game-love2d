local M = {}

local WorldRoad = require("src.ui.WorldRoad")
local LightEngine = require("engine.LightEngine")

local function overlays(x, y, w, h)
    WorldRoad.drawOverlays(x, y, w, h)
end

function M.run(mode)
    require("src.ui.PixelCanvas").enableNearest()

    if mode and mode:match("^nolight_") then
        LightEngine.setEnabled(false)
        mode = mode:gsub("^nolight_", "")
    end

    if mode and mode:match("^day_") then
        WorldRoad.setTimeOfDay(0, true)
        mode = mode:gsub("^day_", "")
    elseif mode and mode:match("^mid_") then
        WorldRoad.setTimeOfDay(0.5, true)
        mode = mode:gsub("^mid_", "")
    end

    if mode and mode:match("^dark_") then
        LightEngine.debugAmbientScale = 0.55
        WorldRoad.setTimeOfDay(1, true)
        mode = mode:gsub("^dark_", "")
    end

    if mode and mode:match("^wide_") then
        love.window.setMode(1914, 1011)
        mode = mode:gsub("^wide_", "")
    end

    local biomeOverride = nil
    if mode and mode:match("^b%d_") then
        biomeOverride = tonumber(mode:match("^b(%d)_"))
        mode = mode:gsub("^b%d_", "")
    end

    local width, height = love.graphics.getDimensions()

    love.graphics.clear(0, 0, 0, 1)

    if mode == "interior" or (mode and mode:match("^interior%d$")) then
        local SceneBackground = require("src.ui.SceneBackground")
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local I18n = require("src.i18n.I18n")
        I18n.init()
        local act = tonumber(mode:match("%d")) or 1
        local Game = require("src.core.Game")
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        game.enemy.spriteId = EnemyRenderer.resolveSpriteId(act, "boss")
        game.enemy.isBoss = true
        _G.game = game
        local InteriorFX = require("src.ui.InteriorFX")
        for _ = 1, 40 do
            EnemyRenderer.update(1 / 30)
            InteriorFX.update(1 / 30, act)
        end
        SceneBackground.draw("castle_hall_" .. act, width, height, 0.15)
        InteriorFX.draw(act)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, 80)
        local SceneAnchors = require("src.data.scene_anchors")
        local ax, ay = SceneAnchors.groundAnchor("castle_hall_" .. act,
            width, height)
        EnemyRenderer.draw(game, ax, ay)
    elseif mode == "gate" or (mode and mode:match("^gate%d$")) then
        local topBarH = 80
        local bio = tonumber(mode:match("%d")) or 1
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        local segLen = WorldRoad.TRAVEL_DISTANCE * 8
        WorldRoad._camZ = segLen * 1.0
        WorldRoad._segBase = 0
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^grow%d+$") then
        local topBarH = 80
        local pct = tonumber(mode:match("%d+")) or 50
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._segBase = 0
        WorldRoad._camZ = (WorldRoad.TRAVEL_DISTANCE * 8) * (pct / 100)
        for _ = 1, 4 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^entry%d?$") then
        local topBarH = 80
        local bio = tonumber(mode:match("%d")) or 1
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        local segLen = WorldRoad.TRAVEL_DISTANCE * 8
        WorldRoad._camZ = segLen * 1.0
        WorldRoad._segBase = 0
        WorldRoad._entry = { phase = "door", t = 0,
                             doorK = 0, fade = 0, sound = nil }
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "fork" or mode == "fork2" or mode == "forkhover"
        or mode == "forkb" or mode == "forkmini"
        or (mode and mode:match("^forkfade%d+$")) then
        local topBarH = os.getenv("STORE_NOTOPBAR") == "1" and 0 or 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(biomeOverride or 1)
        WorldRoad._blend = nil
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        require("src.i18n.I18n").init()
        local MM = require("src.systems.MapManager")
        local function nodes(types)
            local out = {}
            for i, t in ipairs(types) do
                out[i] = { type = t, label = MM.labelFor(t), desc = MM.descFor(t) }
            end
            return out
        end
        WorldRoad.showFork(mode == "forkmini" and nodes({ "battle", "mini_boss", "elite" })
            or mode == "forkb" and nodes({ "elite", "event", "battle" })
            or nodes({ "battle", "rest", "shop" }), function() end)
        for _ = 1, 20 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, biomeOverride or 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        if WorldRoad._fork then WorldRoad._fork.hover = 2 end
        if mode == "forkhover" and WorldRoad._fork then
            local f = WorldRoad._fork
            f._hoverK = f._hoverK or {}
            f._hoverK[3] = 1
            f.hover = 3
        end
        local fadeTicks = mode and tonumber(mode:match("^forkfade(%d+)$"))
        if fadeTicks then
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[2]
            if b then
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            for _ = 1, fadeTicks do
                WorldRoad.update(1 / 30)
                WorldRoad.draw(0, topBarH, width, height - topBarH, biomeOverride or 1)
                overlays(0, topBarH, width, height - topBarH)
            end
        end
        if mode == "fork2" then
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[3]
            if b then
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            for _ = 1, 85 do
                WorldRoad.update(1 / 30)
                WorldRoad.draw(0, topBarH, width, height - topBarH, biomeOverride or 1)
                overlays(0, topBarH, width, height - topBarH)
            end
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, biomeOverride or 1)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
        if os.getenv("TUT_TIP") then
            local Tutorial = require("src.systems.Tutorial")
            local conv, line = os.getenv("TUT_TIP"):match("^([%w_]+):?([%w_]*)$")
            Tutorial._show(conv, line ~= "" and line or nil)
            Tutorial.draw()
        end
    elseif mode == "poke" then
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.showFork({
            { type = "battle", label = "Batalha", desc = "x" },
            { type = "rest",   label = "Descanso", desc = "x" },
            { type = "shop",   label = "Loja", desc = "x" },
        }, function() end)
        for _ = 1, 20 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        local hits = 0
        for gy = 0.10, 0.92, 0.08 do
            for gx = 0.05, 0.95, 0.06 do
                if WorldRoad.pokeSceneAt(gx * width,
                    topBarH + gy * (height - topBarH)) then
                    hits = hits + 1
                end
            end
        end
        print("[poke] alvos atingidos na varredura: " .. hits)
        local GrassField = require("engine.GrassField")
        GrassField.pokeAt(0.30, WorldRoad._camZ + 3, WorldRoad._time)
        for _ = 1, 5 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "blend6" then
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(5)
        WorldRoad._camZ = 5 * 7.3
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.setBiome(6)
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
        })
        for _ = 1, 34 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, nil)
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, nil)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "actswap" then
        local panelH = math.floor(height / 3)
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 6.0
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, 0, width, panelH, 1)
        overlays(0, 0, width, panelH)
        WorldRoad.setBiome(2)
        for _ = 1, 18 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, panelH, width, panelH, nil)
        end
        WorldRoad.draw(0, panelH, width, panelH, nil)
        overlays(0, panelH, width, panelH)
        for _ = 1, 60 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, panelH * 2, width, panelH, nil)
        end
        WorldRoad.draw(0, panelH * 2, width, panelH, nil)
        overlays(0, panelH * 2, width, panelH)
    elseif mode == "grassanim" then
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for _ = 1, 90 do
            WorldRoad.update(1 / 30)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        end
        for i = 1, 24 do
            WorldRoad.update(1 / 30)
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            local path = string.format("ga_%02d.png", i)
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", path)
            end)
            love.graphics.present()
        end
        print("[screenshot] 24 frames ga_XX.png salvos")
        love.event.quit()
        return
    elseif mode and mode:match("^lumanim%d$") then
        local LuminaireEngine = require("engine.LuminaireEngine")
        local bio = tonumber(mode:match("%d")) or 1
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.update(1 / 30)
        local kinds = {}
        local bid = require("src.data.biomes")[bio].id
        for kind in pairs(LuminaireEngine.catalog(bid)) do
            kinds[#kinds + 1] = kind
        end
        table.sort(kinds)
        local ki = 0
        for _, p in ipairs(WorldRoad._props) do
            if p.kind ~= "tuft" and p.kind ~= "fence" then
                ki = ki + 1
                p.kind = kinds[(ki % #kinds) + 1]
                p.variant = 0
                p.cluster = nil
                p.big = 1
            end
        end
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        for fi, name in ipairs({ "lum_a.png", "lum_b.png" }) do
            if fi == 2 then
                for _ = 1, 5 do WorldRoad.update(1 / 30) end
            end
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
            overlays(0, topBarH, width, height - topBarH)
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", name)
                print("[screenshot] salvo: " .. name)
            end)
            love.graphics.present()
        end
        love.event.quit()
        return
    elseif mode == "bench" or mode == "bench0" then
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        local GrassField = require("engine.GrassField")
        GrassField.disabled = (mode == "bench0")
        local N = 200
        local tStart = love.timer.getTime()
        for _ = 1, N do
            WorldRoad.update(1 / 60)
            WorldRoad._camZ = WorldRoad._camZ + 0.045
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            overlays(0, topBarH, width, height - topBarH)
        end
        local ms = (love.timer.getTime() - tStart) / N * 1000
        local stats = love.graphics.getStats()
        print(string.format(
            "[bench] %.2f ms/frame CPU (update+draw) | sprites de grama: %d | drawcalls: %d",
            ms, GrassField._lastCount or -1, stats.drawcalls))
        love.event.quit()
        return
    elseif mode == "grass" then
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        for shot = 1, 2 do
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
            love.graphics.setColor(0.1, 0.08, 0.06, 1)
            love.graphics.rectangle("fill", 0, 0, width, topBarH)
            local path = "worldroad_grass" .. shot .. ".png"
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", path)
                print("[screenshot] salvo em save-dir: " .. path)
            end)
            love.graphics.present()
            if shot == 1 then
                for _ = 1, 33 do WorldRoad.update(1 / 30) end
            end
        end
        love.event.quit()
        return
    elseif mode == "all" then
        local topBarH = 80
        for bio = 1, 6 do
            love.graphics.clear(0, 0, 0, 1)
            WorldRoad.clearCache()
            WorldRoad.setBiome(bio)
            WorldRoad._camZ = 5.5
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad._prevBiomeIndex = nil
            WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
            overlays(0, topBarH, width, height - topBarH)
            love.graphics.setColor(0.1, 0.08, 0.06, 1)
            love.graphics.rectangle("fill", 0, 0, width, topBarH)
            local path = "worldroad_full" .. bio .. ".png"
            love.graphics.captureScreenshot(function(imageData)
                imageData:encode("png", path)
                print("[screenshot] salvo em save-dir: " .. path)
            end)
            love.graphics.present()
        end
        love.event.quit()
        return
    elseif mode == "full" or (mode and mode:match("^full%d$")) then
        local topBarH = 80
        local bio = tonumber(mode:match("%d")) or 1
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^postgate%d?") then
        local bio = tonumber(mode:match("%d")) or 1
        local topBarH = 80
        WorldRoad.clearCache(); WorldRoad.setBiome(bio)
        local camZ = 4; WorldRoad._camZ = camZ
        for _ = 1, 30 do WorldRoad.update(1/30) end
        WorldRoad._blend = nil; WorldRoad._prevBiomeIndex = nil
        WorldRoad._props = {}
        local bid = require("src.data.biomes")[bio].id
        local rel = 0.5
        while rel < 30 do
            for side = -1, 1, 2 do
                WorldRoad._props[#WorldRoad._props+1] = {
                    z = camZ + rel, kind = "lantern", side = side,
                    lane = 0, variant = 0, bid = bid, big = 1, jitter = 0,
                }
            end
            rel = rel + 0.7
        end
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode and mode:match("^enemy%d_") then
        local bio = tonumber(mode:match("^enemy(%d)_"))
        local sid = mode:match("^enemy%d_(.+)$")
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local I18n = require("src.i18n.I18n")
        I18n.init()
        local Game = require("src.core.Game")
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        _G.game = game
        game.enemy.spriteId = sid
        game.enemy.isBoss = (sid == "winter_monarch" or sid == "rot_colossus"
            or sid == "eclipse_queen")
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(bio)
        WorldRoad._camZ = 6
        for _ = 1, 30 do
            WorldRoad.update(1 / 30)
            EnemyRenderer.update(1 / 30)
        end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        local cx, cy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarH, width, height - topBarH)
        WorldRoad.setBattleEnemyDraw(function()
            EnemyRenderer.draw(game, cx, cy)
        end, cy)
        WorldRoad.draw(0, topBarH, width, height - topBarH, bio)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "travel" then
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local topBarH = 80
        WorldRoad.clearCache()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        for _ = 1, 30 do WorldRoad.update(1 / 30) end
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard({ spriteId = "cursed_scarecrow" }),
        })
        for _ = 1, 70 do
            WorldRoad.update(1 / 30)
            WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        end
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, topBarH, width, height - topBarH, 1)
        overlays(0, topBarH, width, height - topBarH)
        love.graphics.setColor(0.1, 0.08, 0.06, 1)
        love.graphics.rectangle("fill", 0, 0, width, topBarH)
    elseif mode == "endless" then
        local panelH = math.floor(height / 3)
        for i = 1, 3 do
            local act = i + 3
            WorldRoad.clearCache()
            WorldRoad.setBiome(act)
            WorldRoad._blend = nil
            WorldRoad._camZ = act * 7.3
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            WorldRoad._blend = nil
            WorldRoad.draw(0, (i - 1) * panelH, width, panelH, act)
            overlays(0, (i - 1) * panelH, width, panelH)
        end
    else
        local panelH = math.floor(height / 3)
        for act = 1, 3 do
            WorldRoad.clearCache()
            WorldRoad.setBiome(act)
            WorldRoad._camZ = act * 7.3
            for _ = 1, 30 do WorldRoad.update(1 / 30) end
            if act == 2 then WorldRoad.travel({ distance = 10, duration = 3 }) ; WorldRoad.update(0.5) end

            WorldRoad.draw(0, (act - 1) * panelH, width, panelH, act)
            overlays(0, (act - 1) * panelH, width, panelH)
        end
    end

    love.graphics.captureScreenshot(function(imageData)
        local path = "worldroad_screenshot.png"
        imageData:encode("png", path)
        print("[screenshot] salvo em save-dir: " .. path)
        love.event.quit()
    end)

    love.graphics.present()
end

return M
