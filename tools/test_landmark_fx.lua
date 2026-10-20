local TK = require("tools.testkit")
local M = {}

function M.run()
    local t = TK.new("landmarks × terreno: fogueira, bandeira, loja, castelo, evento, elite")
    local LightEngine = require("engine.LightEngine")
    local LuminaireEngine = require("engine.LuminaireEngine")
    local WeatherEngine = require("engine.WeatherEngine")
    local ShadowEngine = require("engine.ShadowEngine")
    local WorldRoad = require("src.ui.WorldRoad")
    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local W, H = love.graphics.getDimensions()

    do
        LightEngine.setEnabled(true)
        LightEngine.beginFrame({ 0.8, 0.8, 0.8 })
        LightEngine.submit({ x = 100, y = 100, radius = 40, sy = 0.35, color = { 1, 0.7, 0.4 },
            intensity = 0.3, dither = true, levels = 6, z = 5 })
        local e = LightEngine._lastEntry()
        t:truthy("LightEngine.submit guarda sy (poça rasa e alongada)", e ~= nil and e.sy == 0.35)
        local okC = pcall(LightEngine.composite, 0, 0, W, H)
        t:truthy("composite desenha poça com sy sem erro", okC)
        LightEngine.setEnabled(nil)
    end

    do
        local n = 0
        local realRect = love.graphics.rectangle
        love.graphics.rectangle = function(...) n = n + 1; return realRect(...) end
        LuminaireEngine.drawEmbersSpec({ color = { 1, 0.6, 0.2 }, count = 4 }, 100, 100, 40, 3)
        local big = n
        n = 0
        LuminaireEngine.drawEmbersSpec({ color = { 1, 0.6, 0.2 }, count = 4 }, 100, 100, 10, 3)
        local small = n
        love.graphics.rectangle = realRect
        t:truthy("drawEmbersSpec: brasas com chama alta (" .. big .. ")", big > 0)
        t:eq("drawEmbersSpec: nada com chama baixa (< 14 px)", small, 0)
        local calls = 0
        local realSpec = LuminaireEngine.drawEmbersSpec
        LuminaireEngine.drawEmbersSpec = function(...) calls = calls + 1; return realSpec(...) end
        LuminaireEngine.drawEmbers("abyss", "brazier", 100, 100, 40, 1)
        LuminaireEngine.drawEmbersSpec = realSpec
        t:eq("drawEmbers delega em drawEmbersSpec", calls, 1)
    end

    do
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._camZ = 5.5
        WorldRoad.update(1 / 30)
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        WorldRoad.draw(0, 52, W, H - 52, 1)
        love.graphics.setCanvas()
        for _ = 1, 40 do
            WeatherEngine.emitDust(0.02, WorldRoad._camZ + 9, 0.6, 0.01, { 0.8, 0.7, 0.5 }, 0.1)
        end
        t:truthy("emitDust respeita o teto (" .. WeatherEngine.dustCount() .. " ≤ 14)",
            WeatherEngine.dustCount() <= 14 and WeatherEngine.dustCount() > 0)
        local P, np = WeatherEngine._particles()
        local inRoad = true
        for i = 1, np do
            if P[i].dust and math.abs(P[i].lx) > 0.2 then inRoad = false end
        end
        t:truthy("poeira fica na faixa da estrada", inRoad)
        for i = 1, 30 * 9 do
            WeatherEngine.update(1 / 30, { biomeId = "fields", camZ = WorldRoad._camZ, time = 7000 + i / 30 })
        end
        t:eq("poeira some sozinha em < 9 s", WeatherEngine.dustCount(), 0)
    end

    local function sceneWith(key, camZ, tod, rm)
        _G.gameSettings = { reducedMotion = rm or false }
        WorldRoad.clearCache()
        WorldRoad.resetRun()
        WorldRoad.setBiome(1)
        WorldRoad._segBase = 0
        WorldRoad._camZ = camZ
        WorldRoad.setTimeOfDay(tod or 1, true)
        for _ = 1, 10 do WorldRoad.update(1 / 30) end
        WorldRoad._blend = nil
        WorldRoad._prevBiomeIndex = nil
        if key then
            WorldRoad._landmark = { key = key, z = WorldRoad._camZ + 9, size = 3.6, phase = 0 }
        end
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        love.graphics.clear(0, 0, 0, 1)
        WorldRoad.draw(0, 52, W, H - 52, 1)
        WorldRoad.drawOverlays(0, 52, W, H - 52)
        love.graphics.setCanvas()
    end

    do
        local emberCalls = 0
        local realSpec = LuminaireEngine.drawEmbersSpec
        LuminaireEngine.drawEmbersSpec = function(...) emberCalls = emberCalls + 1; return realSpec(...) end
        sceneWith(nil, 5.5)
        local base = emberCalls
        emberCalls = 0
        sceneWith("landmark_rest", 5.5)
        local rest = emberCalls
        emberCalls = 0
        sceneWith("landmark_battle", 5.5)
        local battle = emberCalls
        LuminaireEngine.drawEmbersSpec = realSpec
        t:truthy("fogueira: brasas sobem (" .. rest .. " > " .. base .. " das luminárias)", rest > base)
        t:eq("bandeira: sem brasas além das luminárias", battle, base)
    end

    do
        sceneWith("landmark_battle", 5.5, 1, false)
        local kxA = WorldRoad._flagKx
        WorldRoad._time = WorldRoad._time + 0.37
        local cv = love.graphics.newCanvas(W, H)
        love.graphics.setCanvas(cv)
        WorldRoad.draw(0, 52, W, H - 52, 1)
        love.graphics.setCanvas()
        local kxB = WorldRoad._flagKx
        t:truthy("bandeira: pano cisalha com o vento e muda com o tempo",
            kxA ~= nil and kxB ~= nil and kxA ~= kxB)
        sceneWith("landmark_battle", 5.5, 1, true)
        t:eq("reducedMotion: bandeira parada (kx = 0)", WorldRoad._flagKx, 0)
    end

    do
        sceneWith("landmark_shop", 5.5)
        local glow = false
        for i = 1, LightEngine.queued() do
            local e = LightEngine._entryAt(i)
            if e and e.sy and e.sy < 1 then glow = true end
        end
        t:truthy("loja: brilho das janelas no chão (poça com sy < 1)", glow)
    end

    do
        sceneWith(nil, WorldRoad.TRAVEL_DISTANCE * 8 * 0.1)
        local far = WeatherEngine.stats.lowFogBands
        local qFar = ShadowEngine.stats.queued
        sceneWith(nil, WorldRoad.TRAVEL_DISTANCE * 8 * 0.9)
        local near = WeatherEngine.stats.lowFogBands
        t:truthy("castelo perto: névoa baixa própria (" .. near .. " > " .. far .. ")", near > far)
        t:truthy("castelo: sombra pelo sol na fila do ShadowEngine (" .. ShadowEngine.stats.queued .. ")",
            ShadowEngine.stats.queued >= 1 and qFar >= 1)
        local src = love.filesystem.read("src/ui/WorldRoad.lua") or ""
        t:falsy("castelo: as duas elipses fixas saíram",
            src:find("ellipse(\"fill\", cx + shd * iw * s * 0.20", 1, true) ~= nil)
        t:truthy("castelo: sombra do morro em disco na fila de contato (abaixo da crista)",
            src:find("Scene.Contact.queueDisc(cx, crest2 + ry", 1, true) ~= nil)
        t:truthy("WorldRoad lê 'landmarks' da tabela para o castelo",
            src:find('Scene.Grade.cfg("landmarks").castle', 1, true) ~= nil)
        t:truthy("WorldRoad emite poeira pela bandeira", src:find("WeatherEngine.emitDust(", 1, true) ~= nil)
        t:truthy("WorldRoad: fumaça fina da fogueira", src:find('lmk.smoke == "thin"', 1, true) ~= nil)
    end

    do
        local I18n = require("src.i18n.I18n")
        I18n.init()
        local MM = require("src.systems.MapManager")
        local EnemyRenderer = require("src.ui.EnemyRenderer")
        local cv = love.graphics.newCanvas(W, H)
        for _, case in ipairs({ { 1, "battle" }, { 3, "elite" }, { 5, "rest" } }) do
            local bio, ty = case[1], case[2]
            WorldRoad.clearCache()
            WorldRoad.resetRun()
            WorldRoad.setBiome(bio)
            WorldRoad._camZ = 5.5
            for _ = 1, 10 do WorldRoad.update(1 / 30) end
            WorldRoad.showFork({ { type = ty, label = MM.labelFor(ty), desc = MM.descFor(ty) } }, function() end)
            local function frame()
                WorldRoad.update(1 / 30)
                love.graphics.setCanvas(cv)
                WorldRoad.draw(0, 52, W, H - 52, bio)
                love.graphics.setCanvas()
                local lm = WorldRoad._lmMark
                if WorldRoad._landmark and lm and lm.drawn then return lm.a or 0 end
                return 0
            end
            for _ = 1, 20 do frame() end
            local f = WorldRoad._fork
            local b = f and f.markBoxes and f.markBoxes[1]
            if b then WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2) end
            for _ = 1, 80 do frame() end
            WorldRoad.travel({ encounter = EnemyRenderer.getEncounterBillboard({
                spriteId = EnemyRenderer.resolveSpriteId(bio, "battle") }) })
            local prev, worst, seen, gone = 0, 0, false, false
            for _ = 1, 200 do
                local a = frame()
                if a > 0.5 then seen = true end
                if seen and a < 0.01 then gone = true end
                worst = math.max(worst, prev - a)
                prev = a
            end
            t:truthy(string.format("ato %d %s: marco escolhido é visto e depois sai da cena", bio, ty), seen and gone)
            t:truthy(string.format("ato %d %s: marco passa pela câmera sem sumir de uma vez (maior queda %.2f ≤ 0.25)",
                bio, ty, worst), worst <= 0.25)
        end
        cv:release()
    end

    WorldRoad._landmark = nil
    WorldRoad.clearCache()
    WorldRoad.resetRun()
    _G.gameSettings = savedSettings
    return t:done()
end

return M
