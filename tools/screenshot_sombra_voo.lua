local M = {}

local VW, VH = 1920, 1080
local DT = 1 / 60

M.CASES = {
    { id = "carrion_king",  act = 1, node = "boss" },
    { id = "tower_lich",    act = 2, node = "boss" },
    { id = "abyss_watcher", act = 3, node = "mini_boss" },
    { id = "abyss_wraith",  act = 3, node = "battle" },
    { id = "dusk_shade",    act = 6, node = "battle" },
    { id = "dusk_bat",      act = 6, node = "battle" },
    { id = "eclipse_queen", act = 6, node = "boss" },
    { id = "abyss_tyrant",  act = 3, node = "boss" },
    { id = "winter_monarch", act = 4, node = "boss" },
    { id = "rot_colossus",  act = 5, node = "boss" },
}

local function fakeScreen()
    local real = { love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions,
                   love.mouse.getPosition, love.mouse.getX, love.mouse.getY }
    love.graphics.getWidth = function() return VW end
    love.graphics.getHeight = function() return VH end
    love.graphics.getDimensions = function() return VW, VH end
    love.mouse.getPosition = function() return -500, -500 end
    love.mouse.getX = function() return -500 end
    love.mouse.getY = function() return -500 end
    return function()
        love.graphics.getWidth, love.graphics.getHeight, love.graphics.getDimensions,
            love.mouse.getPosition, love.mouse.getX, love.mouse.getY =
            real[1], real[2], real[3], real[4], real[5], real[6]
    end
end

function M.setupCase(c)
    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    _G.gameSettings = _G.gameSettings or {}
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")
    local BossCinematic = require("src.ui.BossCinematic")
    local InteriorFX = require("src.ui.InteriorFX")
    local CombatBeats = require("src.systems.CombatBeats")
    local isBoss = c.node == "boss"
    _G.EventManager.clear()
    CombatBeats.clear()
    EnemyRenderer.clearCache()
    EnemyRenderer.resetRun()
    if BossCinematic.reset then BossCinematic.reset() end
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = c.act
    run.floorInAct = isBoss and 8 or 5
    run.currentNode = { type = c.node }
    game.enemy = EnemyRoster.spawn(Enemy, c.id, ActSystem.getEnemyStats(c.act, run.floorInAct, c.node))
    game.enemy.isBoss = isBoss
    game.messageSystem = nil
    _G.game = game
    local topBar = TopBar:new()
    topBar:setGame(game)
    GameplayScene.init({ game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(VW * 0.80, VH * 0.80, 150, 46, "Jogar") })
    if isBoss then GameplayScene._debugForceBossEntered() end
    WorldRoad.setBiome(c.act)
    local tod = 0.85
    local function step(secs)
        local n = math.max(1, math.floor(secs / DT + 0.5))
        for _ = 1, n do
            _G.EventManager.update(DT)
            if not isBoss then WorldRoad.update(DT) end
            EnemyRenderer.update(DT)
            if isBoss then InteriorFX.update(DT, InteriorFX.hallFor(c.act)) end
            WorldRoad.setTimeOfDay(tod, true)
        end
    end
    WorldRoad.setTimeOfDay(tod, true)
    step(1.0)
    if not isBoss then
        WorldRoad.travel({
            encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
            onComplete = function() EnemyRenderer.triggerArrival() end,
        })
        local guard = 0
        while WorldRoad._travel and guard < 2400 do step(DT); guard = guard + 1 end
        step(1.0)
    end
    return game, step, GameplayScene
end

function M.bobTime(id, phase)
    local pose = require("src.data.enemy_poses").get(id)
    local w = pose.bobSpeed or 1
    local base = math.floor(love.timer.getTime() * w / (2 * math.pi) + 2) * 2 * math.pi / w
    if phase == "top" then return base + (math.pi / 2) / w end
    return base + (3 * math.pi / 2) / w
end

function M.renderAt(canvas, t, GameplayScene)
    local realTime = love.timer.getTime
    love.timer.getTime = function() return t end
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    GameplayScene.draw()
    love.graphics.setCanvas()
    love.timer.getTime = realTime
    return canvas:newImageData()
end

function M.run(arg)
    local tag = (arg and arg ~= "") and arg or "depois"
    local restore = fakeScreen()
    require("src.i18n.I18n").init()
    require("src.ui.PixelCanvas").enableNearest()
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local ok, FloatShadow = pcall(require, "src.ui.FloatShadow")
    if not ok then FloatShadow = nil end
    local FontManager = require("src.ui.FontManager")
    local font = FontManager.getFont(16)
    local vcanvas = love.graphics.newCanvas(VW, VH)
    local outDir = "sombra_voo"
    love.filesystem.createDirectory(outDir)
    for _, c in ipairs(M.CASES) do
        local game, step, GameplayScene = M.setupCase(c)
        local shots = {}
        for _, phase in ipairs({ "top", "bottom" }) do
            local t = M.bobTime(c.id, phase)
            local data = M.renderAt(vcanvas, t, GameplayScene)
            local foot = EnemyRenderer.getLastFoot()
            local last = FloatShadow and FloatShadow.getLast()
            if FloatShadow and os.getenv("SOMBRA_VOO_MASK") == "1" then
                FloatShadow.ENABLED = false
                local bare = M.renderAt(vcanvas, t, GameplayScene)
                FloatShadow.ENABLED = true
                bare:encode("png", outDir .. "/" .. c.id .. "_" .. tag .. "_" .. phase .. "_sem.png")
                bare:release()
            end
            shots[#shots + 1] = { phase = phase, data = data,
                gx = foot and foot.hudCx or VW / 2, gy = foot and foot.groundY or VH * 0.7,
                fb = foot and foot.footBottom or 0,
                a = last and last.alpha or 0, k = last and last.sizeK or 0 }
            print(string.format("[sombra_voo] %s %-6s %s alpha=%.3f size=%.3f pe=%d chao=%d",
                c.id, phase, tag, shots[#shots].a, shots[#shots].k, shots[#shots].fb, shots[#shots].gy))
        end
        local cropW, cropH = 520, 200
        local fullW, fullH = VW / 2, VH / 2
        local sheet = love.graphics.newCanvas(fullW + cropW * 2 + 12, math.max(fullH, cropH * 2 * 2 + 50) + 24)
        love.graphics.setCanvas(sheet)
        love.graphics.clear(0.12, 0.12, 0.12, 1)
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(c.id .. "  ato " .. c.act .. "  " .. c.node .. "  " .. tag, 4, 2)
        for i, s in ipairs(shots) do
            local img = love.graphics.newImage(s.data)
            img:setFilter("nearest", "nearest")
            if i == 1 then love.graphics.draw(img, 0, 24, 0, 0.5, 0.5) end
            local qx = math.max(0, math.min(VW - cropW, math.floor(s.gx - cropW / 2)))
            local qy = math.max(0, math.min(VH - cropH, math.floor(s.gy - cropH * 0.55)))
            local q = love.graphics.newQuad(qx, qy, cropW, cropH, VW, VH)
            local oy = 24 + (i - 1) * (cropH * 2 + 26)
            love.graphics.draw(img, q, fullW + 12, oy + 20, 0, 2, 2)
            love.graphics.print(string.format("%s  2x  alpha %.2f  tamanho %.2f", s.phase == "top" and "topo do bob" or "base do bob", s.a, s.k),
                fullW + 16, oy)
            q:release()
            img:release()
            local full = outDir .. "/" .. c.id .. "_" .. tag .. "_" .. s.phase .. ".png"
            s.data:encode("png", full)
            s.data:release()
        end
        love.graphics.setCanvas()
        local sd = sheet:newImageData()
        local p = outDir .. "/" .. c.id .. "_" .. tag .. ".png"
        sd:encode("png", p)
        sd:release()
        sheet:release()
        print("[sombra_voo] " .. love.filesystem.getSaveDirectory() .. "/" .. p)
    end
    vcanvas:release()
    restore()
    return true
end

return M
