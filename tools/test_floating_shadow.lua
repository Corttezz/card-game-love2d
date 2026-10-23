local TK = require("tools.testkit")
local M = {}

local W, H = 1920, 1080

local function floatingIds()
    local EnemyPoses = require("src.data.enemy_poses")
    local ids = {}
    for id, p in pairs(EnemyPoses.BY_ID) do
        if p.pose == "floating" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

local function bobClock(id, phase, cycles)
    local pose = require("src.data.enemy_poses").get(id)
    local w = pose.bobSpeed
    local base = (cycles or 40) * 2 * math.pi / w
    return base + ((phase == "top") and (math.pi / 2) or (3 * math.pi / 2)) / w
end

function M.run()
    local t = TK.new("sombra de voo: silhueta achatada no chao sob quem flutua")
    TK.bootstrap()
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local FloatShadow = require("src.ui.FloatShadow")
    local ShadowEngine = require("engine.ShadowEngine")
    local GS = require("src.scenes.GameplayScene")

    local savedSettings = _G.gameSettings
    _G.gameSettings = { reducedMotion = false }
    local realTime = love.timer.getTime
    local clock = 100
    love.timer.getTime = function() return clock end
    local canvas = love.graphics.newCanvas(W, H)
    local cx, cy = W / 2, math.floor(H * 0.72)
    local ellipses = 0
    local realEllipse = love.graphics.ellipse
    love.graphics.ellipse = function(...) ellipses = ellipses + 1 return realEllipse(...) end

    local function setScene(scene)
        if scene == "salao" then
            GS.hallShadowFrame({ lightXr = 0.5 }, W)
        elseif scene == "estrada" then
            ShadowEngine.setFrame(cx - 500, W, 0.85, 0.8)
            ShadowEngine.setTint(0.30, 0.26, 0.34)
            ShadowEngine.setAlphaK(1)
        end
    end

    local function render(game, scene, on)
        FloatShadow.ENABLED = on
        setScene(scene)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0.62, 0.58, 0.52, 1)
        love.graphics.setColor(1, 1, 1, 1)
        local drawn = EnemyRenderer.draw(game, cx, cy)
        love.graphics.setCanvas()
        FloatShadow.ENABLED = true
        return canvas:newImageData(), drawn
    end

    local function measure(game, scene)
        local a = render(game, scene, true)
        local last = FloatShadow.getLast()
        local rec = last and { alpha = last.alpha, sizeK = last.sizeK } or nil
        local foot = EnemyRenderer.getLastFoot()
        local b = render(game, scene, false)
        local n, dark, y0, y1, overlap = 0, 0, 1e9, -1e9, 0
        local x0 = math.max(0, math.floor(cx - 520))
        local x1 = math.min(W - 1, math.floor(cx + 520))
        local yy0 = math.max(0, cy - 320)
        local yy1 = math.min(H - 1, cy + 120)
        for y = yy0, yy1 do
            for x = x0, x1 do
                local r1, g1, b1 = a:getPixel(x, y)
                local r2, g2, b2 = b:getPixel(x, y)
                local d = (r2 + g2 + b2 - r1 - g1 - b1) / 3
                if d > 0.01 then
                    n = n + 1
                    dark = dark + d
                    if y < y0 then y0 = y end
                    if y > y1 then y1 = y end
                    if math.abs(r2 - 0.62) + math.abs(g2 - 0.58) + math.abs(b2 - 0.52) > 0.30 then
                        overlap = overlap + 1
                    end
                end
            end
        end
        a:release(); b:release()
        return { n = n, dark = dark, y0 = y0, y1 = y1, overlap = overlap, last = rec,
                 footBottom = foot and foot.footBottom or 0 }
    end

    local ids = floatingIds()
    local fails = { none = {}, floor = {}, gap = {}, breath = {}, depth = {}, ellipse = {} }
    for _, id in ipairs(ids) do
        for _, scene in ipairs({ "estrada", "salao", "sem_frame" }) do
            EnemyRenderer.clearCache()
            EnemyRenderer.resetRun()
            local game = { enemy = { spriteId = id, isBoss = scene == "salao", health = 10 } }
            local cyc = (scene == "sem_frame") and 4000 or 40
            clock = bobClock(id, "top", cyc)
            render(game, scene, true)
            EnemyRenderer.update(0)
            ellipses = 0
            local top = measure(game, scene)
            clock = bobClock(id, "bottom", cyc)
            local bot = measure(game, scene)
            local tag = id .. "@" .. scene
            if ellipses > 0 then fails.ellipse[#fails.ellipse + 1] = tag end
            if bot.n < 150 or not bot.last then
                fails.none[#fails.none + 1] = string.format("%s(%d px)", tag, bot.n)
            else
                if not (bot.y0 <= cy and bot.y1 >= cy - 2) then
                    fails.floor[#fails.floor + 1] = string.format("%s(%d..%d chao %d)", tag, bot.y0, bot.y1, cy)
                end
                if top.y0 <= top.footBottom then
                    fails.gap[#fails.gap + 1] = string.format("%s(sombra %d pe %d)", tag, top.y0, top.footBottom)
                end
                if not (top.last and top.last.alpha < bot.last.alpha and top.last.sizeK < bot.last.sizeK
                        and top.dark < bot.dark) then
                    fails.breath[#fails.breath + 1] = string.format("%s(escuro %.0f/%.0f)", tag, top.dark, bot.dark)
                end
                if scene ~= "salao" and top.overlap + bot.overlap > 2 then
                    fails.depth[#fails.depth + 1] = string.format("%s(%d px sobre o corpo)", tag, top.overlap + bot.overlap)
                end
            end
        end
    end

    local reducedFail = {}
    _G.gameSettings.reducedMotion = true
    for _, id in ipairs(ids) do
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local game = { enemy = { spriteId = id, isBoss = false, health = 10 } }
        clock = bobClock(id, "top")
        local a = measure(game, "estrada")
        clock = bobClock(id, "bottom")
        local b = measure(game, "estrada")
        if not (a.last and b.last and a.n > 150 and math.abs(a.last.alpha - b.last.alpha) < 1e-6
                and math.abs(a.last.sizeK - b.last.sizeK) < 1e-6) then
            reducedFail[#reducedFail + 1] = id
        end
    end
    _G.gameSettings.reducedMotion = false

    local deathFail = {}
    for _, id in ipairs(ids) do
        EnemyRenderer.clearCache()
        EnemyRenderer.resetRun()
        local game = { enemy = { spriteId = id, isBoss = false, health = 10 } }
        render(game, "estrada", true)
        EnemyRenderer.update(0)
        game.enemy.health = 0
        EnemyRenderer.triggerDeath(id)
        local mid = nil
        for i = 1, 240 do
            EnemyRenderer.update(1 / 60)
            clock = clock + 1 / 60
            if i == 6 then render(game, "estrada", true); mid = FloatShadow.getLast() and FloatShadow.getLast().alpha end
        end
        render(game, "estrada", true)
        if FloatShadow.getLast() then deathFail[#deathFail + 1] = id .. "(sombra de voo no cadaver pousado)" end
        local _, drawn = render({ enemy = nil }, "estrada", true)
        if drawn or FloatShadow.getLast() then deathFail[#deathFail + 1] = id .. "(desenhou sem inimigo)" end
        if mid == nil then deathFail[#deathFail + 1] = id .. "(sombra sumiu no comeco da queda)" end
    end

    love.graphics.ellipse = realEllipse
    love.timer.getTime = realTime
    _G.gameSettings = savedSettings
    FloatShadow.ENABLED = true
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()

    t:truthy("flutuantes declarados (" .. #ids .. ")", #ids >= 7)
    t:eq("todo flutuante tem sombra no chao (estrada, salao, sem frame): " .. table.concat(fails.none, " "), #fails.none, 0)
    t:eq("sombra fica na linha do chao: " .. table.concat(fails.floor, " "), #fails.floor, 0)
    t:eq("vao entre o pe e a sombra no topo do bob: " .. table.concat(fails.gap, " "), #fails.gap, 0)
    t:eq("sombra respira: menor e mais clara no alto, maior e mais escura embaixo: " .. table.concat(fails.breath, " "), #fails.breath, 0)
    t:eq("sombra desenhada antes do corpo (nunca por cima dele): " .. table.concat(fails.depth, " "), #fails.depth, 0)
    t:eq("flutuante sem elipse de fallback: " .. table.concat(fails.ellipse, " "), #fails.ellipse, 0)
    t:eq("reducedMotion: sombra fica, sem respirar: " .. table.concat(reducedFail, " "), #reducedFail, 0)
    t:eq("morte: sombra de voo converge no contato e some sem inimigo: " .. table.concat(deathFail, " "), #deathFail, 0)
    t:eq("sem contorno de luz (5ff7d9ad)", EnemyRenderer.RIM.max, 0)
    t:truthy("respiro puro: alto = menor e mais claro",
        select(1, FloatShadow.breath(0.10, 0.08, 0.02)) < select(1, FloatShadow.breath(0.06, 0.08, 0.02))
        and select(2, FloatShadow.breath(0.10, 0.08, 0.02)) < select(2, FloatShadow.breath(0.06, 0.08, 0.02)))
    return t:done()
end

return M
