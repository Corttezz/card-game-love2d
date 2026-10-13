-- tools/shot_boss_cinematic.lua
-- PROVA VISUAL da cinemática do chefe (src/ui/BossCinematic) pelo caminho
-- REAL da cena: GameplayScene.update/draw com o salão do ato 1, o rei-carniça
-- e a sequência de entrada + morte tocando, quadro a quadro, num canvas
-- falsificado (nada precisa aparecer na janela — roda com CARDGAME_HEADLESS=1).
--
--   love . shot_boss_cinematic [intro|death|both]
--   BOSS_CINE_SIZE=1920x1080   tamanho do canvas (default 1920x1080)
--   BOSS_CINE_FPS=15           quadros gravados por segundo simulado
--   BOSS_CINE_REDUCED=1        versão reducedMotion
--   BOSS_CINE_LOCALE=de        idioma do cartão de nome
--   BOSS_CINE_SKIP=2.0         pula a entrada em t=2.0s (prova do pular)
--
-- Saída: boss_cine_<fase>_NNN.png no save dir (impresso no fim) + um
-- boss_cine_<fase>_timeline.txt com o instante de cada quadro. A prancha e o
-- GIF saem de tools/boss_cinematic_sheet.py.

local M = {}

function M.run(mode)
    mode = mode or "both"
    io.stdout:setvbuf("no")   -- progresso visível mesmo com stdout redirecionado
    local function log(s) print("[shot_boss_cinematic] " .. s) end
    local vw, vh = (os.getenv("BOSS_CINE_SIZE") or "1920x1080"):match("^(%d+)x(%d+)$")
    vw, vh = tonumber(vw) or 1920, tonumber(vh) or 1080
    local fps = tonumber(os.getenv("BOSS_CINE_FPS") or "") or 15
    local skipAt = tonumber(os.getenv("BOSS_CINE_SKIP") or "")
    if os.getenv("BOSS_CINE_REDUCED") == "1" then
        _G.gameSettings = _G.gameSettings or {}
        _G.gameSettings.reducedMotion = true
    end

    log("canvas")
    local vcanvas = love.graphics.newCanvas(vw, vh)
    love.graphics.getWidth = function() return vw end
    love.graphics.getHeight = function() return vh end
    love.graphics.getDimensions = function() return vw, vh end

    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    local I18n = require("src.i18n.I18n")
    if os.getenv("BOSS_CINE_LOCALE") then _G.TOOL_FORCE_LOCALE = os.getenv("BOSS_CINE_LOCALE") end
    I18n.init()
    require("src.ui.PixelCanvas").enableNearest()
    require("src.systems.ScreenShake").install()

    -- relógio SIMULADO: bob, flicker e DynaText leem love.timer.getTime —
    -- quadros reproduzíveis independem da velocidade da máquina. DENTRO de um
    -- quadro o relógio ainda anda em tempo real: laços com orçamento de tempo
    -- (prewarm do WorldRoad) travariam pra sempre com um relógio parado.
    local DT = 1 / 30
    local simT = 100
    local realTime = love.timer.getTime
    local realBase = realTime()
    love.timer.getTime = function() return simT + (realTime() - realBase) end
    love.timer.getDelta = function() return DT end

    log("modulos")
    local Game = require("src.core.Game")
    local GameplayScene = require("src.scenes.GameplayScene")
    local BossCinematic = require("src.ui.BossCinematic")
    local EnemyRenderer = require("src.ui.EnemyRenderer")
    local WorldRoad = require("src.ui.WorldRoad")
    local ScreenShake = require("src.systems.ScreenShake")
    local TopBar = require("components.TopBar")
    local GameUI = require("components.GameUI")
    local Button = require("components.Button")
    local EnemyRoster = require("src.systems.EnemyRoster")
    local ActSystem = require("src.systems.ActSystem")
    local Enemy = require("src.entities.Enemy")

    log("game")
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = 1
    run.floorInAct = 8
    run.currentNode = { type = "boss" }
    game.enemy = EnemyRoster.spawn(Enemy, "carrion_king", ActSystem.getEnemyStats(1, 8, "boss"))
    game.enemy.isBoss = true
    _G.game = game

    log("ui")
    local topBar = TopBar:new()
    topBar:setGame(game)
    local gameUI = GameUI:new()
    local playButton = Button:new(vw * 0.80, vh * 0.80, 150, 46, "Jogar")
    local endTurnButton = Button:new(vw * 0.80, vh * 0.88, 150, 40, "Encerrar")
    local events = {}
    GameplayScene.init({
        game = game, topBar = topBar, gameUI = gameUI,
        playButton = playButton, endTurnButton = endTurnButton,
        setCurrentState = function(s) events[#events + 1] = ("t=%.2f state=%s"):format(simT - 100, s) end,
        onPhaseCleared = function() events[#events + 1] = ("t=%.2f phaseCleared"):format(simT - 100) end,
    })
    log("setGame")
    GameplayScene.setGame(game)
    log("setBiome")
    WorldRoad.setBiome(1)
    WorldRoad.setTimeOfDay(1, true)
    log("prewarm 90")
    local IFX = require("src.ui.InteriorFX")
    for _ = 1, 90 do
        WorldRoad.update(DT)
        EnemyRenderer.update(DT)
        IFX.update(DT, IFX.hallFor(1))
    end

    local saveDir = love.filesystem.getSaveDirectory()
    log("setup pronto; save dir " .. saveDir)
    local function step()
        simT = simT + DT
        realBase = realTime()
        _G.EventManager.update(DT)
        ScreenShake.update(DT)
        GameplayScene.update(DT)
        if game.enemy and game.enemy.update then game.enemy:update(DT) end
    end
    local function draw(path)
        love.graphics.setCanvas(vcanvas)
        love.graphics.clear(0, 0, 0, 1)
        ScreenShake.push()
        GameplayScene.draw()
        ScreenShake.pop()
        love.graphics.setCanvas()
        vcanvas:newImageData():encode("png", path)
    end

    local every = math.max(1, math.floor(30 / fps + 0.5))
    local function record(phase, isDone, tail)
        local n, frame, t0 = 0, 0, simT
        local lines = {}
        local tailLeft = tail or 0.5
        local skipped = false
        while true do
            if frame % every == 0 then
                local path = ("boss_cine_%s_%03d.png"):format(phase, n)
                if n % 10 == 0 then log(("%s quadro %d (t=%.2f)"):format(phase, n, simT - t0)) end
                draw(path)
                local d = BossCinematic._debug()
                local stepName = d.seq and d.seq.steps[d.seq.idx] and d.seq.steps[d.seq.idx].kind or "-"
                lines[#lines + 1] = ("%03d t=%.2f step=%s dark=%.2f hidesBoss=%s hidesHud=%s"):format(
                    n, simT - t0, stepName, d.dark, tostring(BossCinematic.hidesBoss()),
                    tostring(BossCinematic.hidesHud()))
                n = n + 1
            end
            if skipAt and phase == "intro" and not skipped and simT - t0 >= skipAt then
                skipped = true
                lines[#lines + 1] = ("skip() em t=%.2f -> %s"):format(simT - t0, tostring(BossCinematic.skip()))
            end
            step()
            frame = frame + 1
            if isDone() then
                tailLeft = tailLeft - DT
                if tailLeft <= 0 then break end
            end
            if frame > 30 * 40 then lines[#lines + 1] = "TIMEOUT 40s"; break end
        end
        love.filesystem.write(("boss_cine_%s_timeline.txt"):format(phase), table.concat(lines, "\n"))
        print(("[shot_boss_cinematic] %s: %d quadros, %.2fs simulados"):format(phase, n, simT - t0))
        return n
    end

    if mode == "intro" or mode == "both" then
        GameplayScene._debugStartBossIntro()
        assert(BossCinematic.isActive(), "entrada não começou (chefe sem roteiro?)")
        record("intro", function() return not BossCinematic.isActive() end, 0.6)
    else
        GameplayScene._debugForceBossEntered()
        for _ = 1, 40 do step() end
    end

    if mode == "death" or mode == "both" then
        -- 1 turno de respiro pra HUD/mão assentarem, depois o golpe fatal pelo
        -- pipeline (marcação _pendingDeath → beat enemy.death → _onEnemyDeath)
        for _ = 1, 20 do step() end
        game.enemy.armor = 0
        game.enemy.health = 1
        game.enemy:takeDamage(50)
        game:settleEnemyDamage(nil)
        record("death", function()
            return not BossCinematic.isActive() and game:isDeathSettled()
        end, 0.8)
    end

    for _, e in ipairs(events) do print("[shot_boss_cinematic] " .. e) end
    print("[shot_boss_cinematic] save dir: " .. saveDir)
    love.event.quit()
end

return M
