local M = {}

M.SEED = 0xBEEF

function M.roster()
    local out = {}
    local byAct = require("src.data.enemies").ROSTER
    for act = 1, 6 do
        local a = byAct[act]
        for _, nt in ipairs({ "battle", "elite", "mini_boss", "boss" }) do
            for _, id in ipairs(a[nt] or {}) do out[#out + 1] = { id = id, act = act, node = nt } end
        end
    end
    return out
end

function M.indexOf(list, id)
    for i, r in ipairs(list) do if r.id == id then return i end end
    return nil
end

function M.mount(entry)
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

    local boss = entry.node == "boss"
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = entry.act
    run.floorInAct = boss and 8 or 3
    run.currentNode = { type = entry.node, enemyId = entry.id }
    local stats = ActSystem.getEnemyStats(entry.act, run.floorInAct, entry.node)
    game.enemy = EnemyRoster.spawn(Enemy, entry.id, stats, entry.act)
    game.enemy.isBoss = boss
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
    if boss then GameplayScene._debugForceBossEntered() end
    WorldRoad.setBiome(entry.act)
    WorldRoad.setTimeOfDay(boss and 1 or 0.75, true)
    love.math.setRandomSeed(M.SEED)
    require("src.ui.EnemyLife").prewarmNow(entry.id)
    for _ = 1, 60 do M.step(1 / 30, entry) end
    return { game = game, run = run, entry = entry }
end

function M.step(dt, entry)
    require("src.ui.WorldRoad").update(dt)
    require("src.ui.EnemyRenderer").update(dt)
    if entry and entry.node == "boss" then
        local IFX = require("src.ui.InteriorFX")
        IFX.update(dt, IFX.hallFor(entry.act))
    end
end

function M.label(entry)
    local ER = require("src.ui.EnemyRenderer")
    local EL = require("src.ui.EnemyLife")
    local st = ER.debugState()
    local foot = ER.getLastFoot() or {}
    local _, data = EL.current()
    local nf = data and data.fidgets and #data.fidgets or 0
    local nfx = data and data.fx and #data.fx or 0
    return string.format("%s  ato %d  %s   clip %s  quadro %s/%d   fidgets %d  fx %d (%d vivas%s)  proximo fidget em %.1fs",
        entry.id, entry.act, entry.node, tostring(st.animName), tostring(foot.frame), ER._debugFrameCount(),
        nf, nfx, EL.liveCount(), EL.fxEnabled and "" or ", fx OFF", math.max(0, EL.gapLeft()))
end

function M.run(startId)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    local GameplayScene = require("src.scenes.GameplayScene")
    local FontManager = require("src.ui.FontManager")
    local EnemyLife = require("src.ui.EnemyLife")
    local sw, sh = (os.getenv("VIDA_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end
    require("src.systems.ScreenShake").install()

    local list = M.roster()
    local idx = M.indexOf(list, startId or "") or 1
    local paused = false

    local function mount(i)
        idx = ((i - 1) % #list) + 1
        M.mount(list[idx])
    end
    mount(idx)

    love.update = function(dt)
        if paused then return end
        dt = math.min(dt, 1 / 20)
        if _G.EventManager.update then _G.EventManager.update(dt) end
        M.step(dt, list[idx])
    end

    love.draw = function()
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.draw()
        local l1 = string.format("%d/%d   <- -> criatura   1-9 fidget N   F fx   espaco pausa   R recarrega   ESC sai%s",
            idx, #list, paused and "   [PAUSA]" or "")
        local l2 = M.label(list[idx])
        local font = FontManager.getFont(10)
        love.graphics.setFont(font)
        local lh = font:getHeight() + 4
        local y = 8
        local wmax = math.max(font:getWidth(l1), font:getWidth(l2)) + 24
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, y - 6, wmax, lh * 2 + 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(l1, 12, y)
        love.graphics.print(l2, 12, y + lh)
    end

    love.keypressed = function(key)
        local n = tonumber(key)
        if key == "escape" then
            love.event.quit()
        elseif key == "right" or key == "d" then
            mount(idx + 1)
        elseif key == "left" or key == "a" then
            mount(idx - 1)
        elseif key == "space" then
            paused = not paused
        elseif key == "f" then
            EnemyLife.fxEnabled = not EnemyLife.fxEnabled
        elseif key == "r" then
            require("src.ui.SpriteAnimation").clearCache()
            EnemyLife.clearCache()
            mount(idx)
        elseif n and n >= 1 and n <= 9 then
            EnemyLife.force(n)
        end
    end
    love.mousepressed = function() end
    love.mousereleased = function() end
    love.mousemoved = function() end
    love.resize = function() end
end

return M
