local M = {}

function M.run(startAct)
    local I18n = require("src.i18n.I18n")
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()

    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local InteriorFX = require("src.ui.InteriorFX")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local Config = require("src.core.Config")
    local FontManager = require("src.ui.FontManager")

    _G.EventManager = _G.EventManager or require("engine.EventManager")
    _G.Event = _G.Event or require("engine.Event")

    local sw, sh = (os.getenv("BOSS_ROOMS_SIZE") or ""):match("^(%d+)x(%d+)$")
    if sw then love.window.setMode(tonumber(sw), tonumber(sh)) end

    local vw, vh = (os.getenv("BOSS_ROOMS_VIRTUAL") or ""):match("^(%d+)x(%d+)$")
    local vcanvas, pendingCap
    if vw then
        vw, vh = tonumber(vw), tonumber(vh)
        vcanvas = love.graphics.newCanvas(vw, vh)
        vcanvas:setFilter("nearest", "nearest")
        love.graphics.getWidth = function() return vw end
        love.graphics.getHeight = function() return vh end
        love.graphics.getDimensions = function() return vw, vh end
        love.graphics.captureScreenshot = function(cb) pendingCap = cb end
    end

    local total = Config.TotalActs or 6
    local shots = (startAct == "shots")
    local act = math.max(1, math.min(total, tonumber(startAct) or 1))
    local frames = 0
    local pendingKey = nil
    local seqN = tonumber(os.getenv("BOSS_ROOMS_SEQ") or "") or 0
    local seqLeft = 0

    local function mount(a)
        act = a
        _G.EventManager.clear()
        require("src.ui.InteriorDepth").reset()
        local game = Game:new()
        game:startNewRun("warrior")
        game:startGame()
        local run = game.runManager.currentRun
        run.actNumber = a
        run.floorInAct = 8
        run.currentNode = { type = "boss" }
        local stats = require("src.systems.ActSystem").getEnemyStats(a, 8, "boss")
        game.enemy = require("src.systems.EnemyRoster").spawn(require("src.entities.Enemy"),
            EnemyRenderer.resolveSpriteId(a, "boss"), stats, a)
        game.messageSystem = nil
        game.enemy.spriteId = EnemyRenderer.resolveSpriteId(a, "boss")
        game.enemy.isBoss = true
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
        GameplayScene._debugForceBossEntered()
        WorldRoad.setBiome(a)
        WorldRoad.setTimeOfDay(1, true)
        run.currentNode.enemyId = game.enemy.spriteId
        print(string.format("[boss_rooms] ato %d  chefe=%s", a,
            tostring(game.enemy.spriteId)))
    end

    require("src.systems.ScreenShake").install()
    mount(act)

    love.update = function(dt)
        dt = math.min(dt, 1 / 20)
        if pendingKey then
            local k = pendingKey
            pendingKey = nil
            love.keypressed(k)
            frames = 0
        end
        if _G.EventManager.update then _G.EventManager.update(dt) end
        require("src.ui.BossCinematic").update(dt, _G.game, { inHall = true })
        do
            local g = _G.game
            local r = g and g.runManager and g.runManager.currentRun
            require("src.systems.MusicDirector").apply("playing", r, "boss")
        end
        if _G.audioSystem then _G.audioSystem:update(dt) end
        require("src.systems.ScreenShake").update(dt)
        WorldRoad.update(dt)
        EnemyRenderer.update(dt)
        InteriorFX.update(dt, InteriorFX.hallFor(act))
        if _G.game and _G.game.update then pcall(_G.game.update, _G.game, dt) end
        frames = frames + 1
    end

    local drawFrame
    love.draw = function()
        if not vcanvas then return drawFrame() end
        love.graphics.setCanvas(vcanvas)
        drawFrame()
        love.graphics.setCanvas()
        if pendingCap then
            local cb = pendingCap
            pendingCap = nil
            cb(vcanvas:newImageData())
        end
        love.graphics.setColor(1, 1, 1, 1)
        local ww, wh = love.window.getMode()
        local k = math.min(ww / vw, wh / vh)
        love.graphics.draw(vcanvas, 0, 0, 0, k, k)
    end
    drawFrame = function()
        love.graphics.clear(0, 0, 0, 1)
        local Shake = require("src.systems.ScreenShake")
        Shake.push()
        GameplayScene.draw()
        Shake.pop()
        local label = string.format("ATO %d/%d  %s   |  1-6 / <- -> troca  I entrada  K morte  C/X contador  G golpe  ENTER pula  H dano  J volta  ESC sai",
            act, total, tostring(_G.game and _G.game.enemy and _G.game.enemy.spriteId))
        local font = FontManager.getFont(10)
        love.graphics.setFont(font)
        local y = love.graphics.getHeight() - font:getHeight() - 8
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, y - 6, font:getWidth(label) + 24, font:getHeight() + 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(label, 12, y)
        if shots and seqLeft > 0 and frames >= 4 then
            frames = -1e9
            local a, k = act, seqN - seqLeft + 1
            love.graphics.captureScreenshot(function(img)
                img:encode("png", ("boss_room_%d_%d.png"):format(a, k))
                seqLeft = seqLeft - 1
                if seqLeft > 0 then frames = 0
                elseif a >= total then love.event.quit() else pendingKey = tostring(a + 1) end
            end)
        elseif shots and seqLeft == 0 and frames >= 120 then
            frames = -1e9
            local a = act
            love.graphics.captureScreenshot(function(img)
                img:encode("png", "boss_room_" .. a .. ".png")
                print("[boss_rooms] salvo boss_room_" .. a .. ".png")
                if seqN > 0 then seqLeft = seqN; frames = 0; return end
                if a >= total then love.event.quit() else pendingKey = tostring(a + 1) end
            end)
        end
    end

    local BM = require("src.systems.BossMechanics")
    local GALLERY_STRIKE = { tower_lich = "rune", abyss_tyrant = "fireball" }
    local function counterName()
        local e = _G.game and _G.game.enemy
        if not e then return nil end
        if e.spriteId == "carrion_king" then return "swarm" end
        local m = BM.spec(e)
        return m and m.status
    end
    local function swarmCount()
        local e = _G.game and _G.game.enemy
        local nm = counterName()
        if not e or not nm then return 0 end
        return BM.stacks(e, nm)
    end
    local function setSwarm(n)
        local e = _G.game and _G.game.enemy
        local nm = counterName()
        if not e or not nm then return end
        BM.setStacks(e, nm, math.max(0, math.min(12, n)))
    end
    local baseMount = mount
    mount = function(a)
        baseMount(a)
        if _G.game and _G.game.enemy and _G.game.enemy.spriteId == "carrion_king" then setSwarm(3) end
    end
    mount(act)

    love.keypressed = function(key)
        local n = tonumber(key)
        if key == "escape" then
            love.event.quit()
        elseif n and n >= 1 and n <= total then
            mount(n)
        elseif key == "right" or key == "d" then
            mount(act % total + 1)
        elseif key == "left" or key == "a" then
            mount((act - 2) % total + 1)
        elseif key == "h" then
            EnemyRenderer.triggerHurt()
        elseif key == "i" then
            mount(act)
            GameplayScene._debugStartBossIntro()
        elseif key == "k" then
            local g = _G.game
            if g.enemy:isAlive() then
                g.enemy.armor = 0
                g.enemy:takeDamage(g.enemy.health + 1)
                g:settleEnemyDamage(nil)
            end
        elseif key == "return" or key == "space" then
            require("src.ui.BossCinematic").skip()
        elseif key == "j" then
            mount(act)
        elseif key == "c" then
            setSwarm(swarmCount() + 1)
        elseif key == "x" then
            setSwarm(swarmCount() - 1)
        elseif key == "g" then
            local strike = _G.game and GALLERY_STRIKE[_G.game.enemy.spriteId]
            if strike then
                local e = _G.game.enemy
                local nm = counterName()
                EnemyRenderer.triggerAttack("multi", function()
                    if strike == "rune" and nm then BM.setStacks(e, nm, BM.stacks(e, nm) - 1) end
                end, { strike = strike })
            elseif swarmCount() > 0 then
                EnemyRenderer.triggerAttack("multi", nil, { swarm = true })
            else
                EnemyRenderer.triggerAttack("attack", nil, {})
            end
        end
    end
    love.mousepressed = function() end
    love.mousereleased = function() end
    love.mousemoved = function() end
    love.resize = function() end
end

return M
