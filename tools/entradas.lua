local M = {}

M.SEED = 0xC0FFEE
M.TOD = 0.85

function M.roster()
    local out = {}
    local byAct = require("src.data.enemies").ROSTER
    for act = 1, 6 do
        local a = byAct[act]
        for _, nt in ipairs({ "battle", "elite", "mini_boss" }) do
            for _, id in ipairs(a[nt] or {}) do out[#out + 1] = { id = id, act = act, node = nt } end
        end
    end
    return out
end

function M.indexOf(list, id)
    for i, r in ipairs(list) do if r.id == id then return i end end
    return nil
end

function M.mount(entry, opts)
    opts = opts or {}
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

    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")
    if _G.EventManager.clear then _G.EventManager.clear() end
    pcall(function() require("engine.ParticlesManager").clear() end)

    local act = entry.act
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = 2
    run.currentNode = { type = entry.node, enemyId = entry.id }
    local stats = ActSystem.getEnemyStats(act, 3, entry.node)
    game.enemy = EnemyRoster.spawn(Enemy, entry.id, stats, act)
    game.enemy.isBoss = false
    if game.messageSystem then game.messageSystem.messages = {} end
    EnemyRenderer.clearCache()
    _G.game = game

    local topBar = TopBar:new()
    topBar:setGame(game)
    local w, h = love.graphics.getDimensions()
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = GameUI:new(),
        playButton = Button:new(w * 0.80, h * 0.80, 150, 46, "Jogar"),
    })
    GameplayScene.setGame(game)
    WorldRoad._lastRect = nil
    WorldRoad.restoreProgress(act, 2)
    WorldRoad._rng:setSeed(opts.seed or M.SEED)
    WorldRoad._props = {}
    WorldRoad.setBiome(act)
    WorldRoad._blend = nil
    WorldRoad._prevBiomeIndex = nil
    WorldRoad._birdTimer = 1e9
    WorldRoad.setTimeOfDay(opts.tod or M.TOD, true)
    love.math.setRandomSeed(opts.seed or M.SEED)
    GameplayScene.update(opts.dt or 1 / 30)
    run.floorInAct = 3
    return { game = game, run = run, entry = entry }
end

function M.startEntrance(ctx, dt)
    ctx.run.floorInAct = 3
    require("src.scenes.GameplayScene").update(dt or 1 / 30)
    ctx.t0 = 0
end

function M.phase()
    local EE = require("src.ui.EnemyEntrance")
    local WorldRoad = require("src.ui.WorldRoad")
    local ER = require("src.ui.EnemyRenderer")
    local HandDeal = require("src.ui.HandDeal")
    local S = EE.state()
    if S then return S.stopped and "assentamento" or "viagem" end
    if WorldRoad.isTraveling() then return "viagem" end
    if ER.isArriving and ER.isArriving() then return "chegada" end
    if HandDeal.isBusy() then return "mao" end
    return "pronto"
end

function M.describe(entry)
    local Data = require("src.data.enemy_entrances")
    local EE = require("src.ui.EnemyEntrance")
    local spec = Data.BY_ID[entry.id] or Data.DEFAULT
    local settle = spec.settle or 0
    local extra = spec.extra or 0
    return string.format("%s  ato %d  %s  +%.1fs (viagem %.1f, assentamento %.1f)  clipes: %s%s",
        entry.id, entry.act, spec.kind, extra, extra - settle, settle,
        EE.describeClips(entry.id), spec.anchor and ("  ancora: " .. tostring(spec.anchor.name)) or "")
end

function M.run(startId)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local GameplayScene = require("src.scenes.GameplayScene")
    local FontManager = require("src.ui.FontManager")
    local Shake = require("src.systems.ScreenShake")
    local CardParticles = require("src.systems.CardParticles")
    local UiScale = require("src.ui.UiScale")

    local sw, sh = (os.getenv("ENTRADAS_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end
    Shake.install()

    local list = M.roster()
    local idx = M.indexOf(list, startId or "") or 1
    local ctx, elapsed, started = nil, 0, false
    local pendingStart = 0

    local function mount(i)
        idx = ((i - 1) % #list) + 1
        ctx = M.mount(list[idx])
        elapsed, started = 0, false
        pendingStart = 2
        print(string.format("[entradas] %d/%d %s", idx, #list, M.describe(list[idx])))
    end
    mount(idx)

    love.update = function(dt)
        dt = math.min(dt, 1 / 20)
        if pendingStart > 0 then
            pendingStart = pendingStart - 1
            if pendingStart == 0 then
                M.startEntrance(ctx, dt)
                started = true
                elapsed = 0
                return
            end
        end
        if _G.EventManager.update then _G.EventManager.update(dt) end
        Shake.update(dt)
        GameplayScene.update(dt)
        CardParticles.update(dt)
        if _G.audioSystem then _G.audioSystem:update(dt) end
        if started then elapsed = elapsed + dt end
    end

    love.draw = function()
        love.graphics.clear(0, 0, 0, 1)
        Shake.push()
        GameplayScene.draw()
        Shake.pop()
        UiScale.begin()
        CardParticles.draw()
        UiScale.finish()
        local entry = list[idx]
        local name = (_G.game and _G.game.enemy and _G.game.enemy.name) or entry.id
        local l1 = string.format("%d/%d  %s   |  <- -> troca  R repete  1-6 ato  ESC sai", idx, #list, tostring(name))
        local l2 = M.describe(entry)
        local l3 = string.format("t = %.2fs   fase: %s", elapsed, M.phase())
        local font = FontManager.getFont(10)
        love.graphics.setFont(font)
        local lh = font:getHeight() + 4
        local y = love.graphics.getHeight() - lh * 3 - 10
        local wmax = math.max(font:getWidth(l1), font:getWidth(l2), font:getWidth(l3)) + 24
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, y - 6, wmax, lh * 3 + 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(l1, 12, y)
        love.graphics.print(l2, 12, y + lh)
        love.graphics.print(l3, 12, y + lh * 2)
    end

    love.keypressed = function(key)
        local n = tonumber(key)
        if key == "escape" then
            love.event.quit()
        elseif key == "right" or key == "d" then
            mount(idx + 1)
        elseif key == "left" or key == "a" then
            mount(idx - 1)
        elseif key == "r" or key == "space" then
            mount(idx)
        elseif n and n >= 1 and n <= 6 then
            for i, r in ipairs(list) do
                if r.act == n then mount(i); break end
            end
        end
    end
    love.mousepressed = function() end
    love.mousereleased = function() end
    love.mousemoved = function() end
    love.resize = function() end
end

return M
