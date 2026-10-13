-- tools/shot_boss_cinematic.lua
-- PROVA VISUAL da cinemática do chefe (src/ui/BossCinematic) pelo caminho
-- REAL da cena: GameplayScene.update/draw com o salão do ato 1, o rei-carniça
-- e a sequência de entrada + morte tocando, quadro a quadro, num canvas
-- falsificado (nada precisa aparecer na janela — roda com CARDGAME_HEADLESS=1).
--
--   love . test_one shot_boss_cinematic [intro|death|both|arrival|phases]
--     phases = a LUTA por fases do chefe (rainha do eclipse): fase 1, íris
--     olhando, virada pelo funil real de dano, eclipse fechado + halo
--     (pelo test_one: não há entrada própria no dispatcher do main.lua —
--     `love . shot_boss_cinematic` abre o JOGO normal e fica esperando)
--     arrival = o caminho REAL do andar do chefe: a cena caminha até o
--     castelo, a PORTA abre, a entrada toca e as cartas são DADAS (HandDeal)
--     — grava da porta ao fim da distribuição (prova do bug "mão/HUD no
--     meio da cutscene")
--   BOSS_CINE_ACT=3            ato/chefe (default 1 = rei-carniça)
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
    -- também no save dir (shot_log.txt): sem console o print some
    local function log(s)
        print("[shot_boss_cinematic] " .. s)
        pcall(love.filesystem.append, "shot_log.txt", s .. "\n")
    end
    love.filesystem.write("shot_log.txt", "")
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
    local act = tonumber(os.getenv("BOSS_CINE_ACT") or "") or 1
    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    local run = game.runManager.currentRun
    run.actNumber = act
    run.floorInAct = (mode == "arrival") and 7 or 8
    run.currentNode = { type = "boss" }
    local bossId = EnemyRenderer.resolveSpriteId(act, "boss")
    local stats = ActSystem.getEnemyStats(act, 8, "boss")
    local okSp, spawned = pcall(EnemyRoster.spawn, Enemy, bossId, stats)
    if okSp and spawned then
        game.enemy = spawned
    else
        game.enemy = Enemy:new(stats.health, stats.damage)
        if game.enemy.rollNextIntent then pcall(game.enemy.rollNextIntent, game.enemy) end
    end
    game.enemy.spriteId = bossId
    game.enemy.isBoss = true
    game.messageSystem = nil   -- sem toasts de início de run por cima da cena
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
    WorldRoad.setBiome(act)
    WorldRoad.setTimeOfDay(1, true)
    log("prewarm 90")
    local IFX = require("src.ui.InteriorFX")
    local HandDeal = require("src.ui.HandDeal")
    for _ = 1, 90 do
        WorldRoad.update(DT)
        EnemyRenderer.update(DT)
        IFX.update(DT, IFX.hallFor(act))
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
                if not d.seq and WorldRoad.isEntering() then stepName = "door"
                elseif not d.seq and HandDeal.isDealing() then stepName = "deal" end
                lines[#lines + 1] = ("%03d t=%.2f step=%s dark=%.2f hidesBoss=%s hidesHud=%s hand=%d ui=%s"):format(
                    n, simT - t0, stepName, d.dark, tostring(BossCinematic.hidesBoss()),
                    tostring(BossCinematic.hidesHud() or HandDeal.hidesHud()),
                    HandDeal.visibleCount(game), tostring(not HandDeal.hidesUI()))
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

    if mode == "arrival" then
        -- caminho REAL: andar 7 → 8 dispara a caminhada; a câmera chega, a
        -- porta abre (WorldRoad.enterCastle), a entrada toca e as cartas
        -- são dadas. A caminhada (6.5 s) não é gravada; da porta em diante é.
        log("arrival: ancora o andar")
        step()
        run.floorInAct = 8
        step()
        assert(WorldRoad.isTraveling(), "a cena não viajou (andar não mudou?)")
        log("arrival: caminhando até o castelo (não gravado)")
        local guard = 0
        while not WorldRoad.isEntering() and guard < 30 * 20 do
            step(); guard = guard + 1
            if guard % 60 == 0 then log(("arrival: viagem %.1fs"):format(guard / 30)) end
        end
        assert(WorldRoad.isEntering(), "a porta não abriu")
        log("arrival: porta — gravando")
        local sawIntro = false
        record("arrival", function()
            if BossCinematic.isActive() then sawIntro = true end
            return sawIntro and not BossCinematic.isActive() and not HandDeal.isBusy()
        end, 0.6)
        for _, e in ipairs(events) do print("[shot_boss_cinematic] " .. e) end
        print("[shot_boss_cinematic] save dir: " .. saveDir)
        love.event.quit()
        return
    end

    if mode == "phases" then
        -- LUTA por fases (rainha do eclipse, ato 6): salão direto, luta
        -- QUIETA (fase 1), a íris olhando, a VIRADA de fase pelo funil real
        -- de dano (Enemy:_checkPhase marca, BossCinematic observa) e o
        -- eclipse fechado — boss_cine_phases_NNN.png + timeline.
        GameplayScene._debugForceBossEntered()
        for _ = 1, 60 do step() end
        local lines, n = {}, 0
        local function shot(label)
            local path = ("boss_cine_phases_%03d.png"):format(n)
            draw(path)
            lines[#lines + 1] = ("%03d t=%.2f step=%s lvl=%.2f dawn=%.2f"):format(
                n, simT - 100, label, BossCinematic.eclipseLevel(), BossCinematic.eclipseDawn())
            log(path .. " " .. label)
            n = n + 1
        end
        local function run(secs) for _ = 1, math.floor(secs / DT + 0.5) do step() end end
        shot("fase1")
        if BossCinematic._debugGaze then BossCinematic._debugGaze() end
        run(0.7)
        shot("fase1_iris")
        run(1.2)
        -- virada: dano até cruzar a fração da fase (kit intocado: o dado diz onde)
        local e = game.enemy
        local ph = e.kit and e.kit.phases and e.kit.phases[1]
        local at = (ph and ph.at) or 0.5
        e.armor = 0
        e:takeDamage(math.floor(e.maxHealth * (1 - at)) + 1)
        game:settleEnemyDamage(nil)
        run(0.25)
        shot("virada")
        run(0.9)
        shot("virada_fim")
        run(2.5)
        shot("fase2")
        run(1.5)
        shot("fase2_halo")
        love.filesystem.write("boss_cine_phases_timeline.txt", table.concat(lines, "\n"))
        print(("[shot_boss_cinematic] phases: %d quadros (fase do kit = %s)"):format(
            n, tostring(e._phaseIdx)))
        print("[shot_boss_cinematic] save dir: " .. saveDir)
        love.event.quit()
        return
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
        -- o fundo do cash out/espólios do chefe: só o mundo = o SALÃO com o
        -- cadáver (GameplayScene.worldOnlyMode == "hall"), nunca a estrada
        love.graphics.setCanvas(vcanvas)
        love.graphics.clear(0, 0, 0, 1)
        GameplayScene.drawWorldOnly()
        love.graphics.setCanvas()
        vcanvas:newImageData():encode("png", "boss_cine_death_hall.png")
        print("[shot_boss_cinematic] fundo dos espólios: worldOnlyMode="
            .. tostring(GameplayScene.worldOnlyMode()) .. " -> boss_cine_death_hall.png")
        -- as DUAS telas pós-chefe DENTRO do salão, como o main.lua as desenha
        -- (roundEval: GameplayScene.draw + painel; cardReward: drawWorldOnly +
        -- espólios), com a TopBar por cima — boss_cine_{cashout,rewards}_hall.png
        local UiScale = require("src.ui.UiScale")
        _G.topBar = topBar
        local function shotUI(path, world, ui)
            love.graphics.setCanvas(vcanvas)
            love.graphics.clear(0, 0, 0, 1)
            world()
            UiScale.begin(); ui(); topBar:draw(); UiScale.finish()
            love.graphics.setCanvas()
            vcanvas:newImageData():encode("png", path)
            print("[shot_boss_cinematic] " .. path)
        end
        local okRE, RoundEvalScreen = pcall(require, "components.RoundEvalScreen")
        if okRE then
            local re = RoundEvalScreen:new()
            local sources = game:_buildRoundEvalSources()
            re:show(game, sources, function() end)
            -- captura com a CONTAGEM FECHADA (linha a linha + voo das moedas):
            -- a linha do tempo roda na fila do EventManager, que o step() tica
            local guardRE = 0
            repeat
                step(); UiScale.begin(); re:update(DT); UiScale.finish()
                guardRE = guardRE + 1
            until (re.cashOutReady and (re.coinsAccumulated or 0) >= (re.totalDollars or 0))
                or guardRE > 30 * 15
            local expected = 0
            for _, src in ipairs(sources) do expected = expected + (src.dollars or 0) end
            print(("[shot_boss_cinematic] cash out: %d fontes, total $%d (esperado $%d), contagem %s em %.1fs")
                :format(#sources, re.totalDollars or -1, expected,
                    re.cashOutReady and "fechada" or "ABERTA (timeout)", guardRE * DT))
            shotUI("boss_cine_cashout_hall.png", GameplayScene.draw, function() re:draw() end)
        end
        local okCR, CardRewardScreen = pcall(require, "components.CardRewardScreen")
        if okCR then
            local cr = CardRewardScreen:new()
            cr:show(game, function() end, function() end, "rewards")
            for _ = 1, 30 do step(); UiScale.begin(); cr:update(DT); UiScale.finish() end
            shotUI("boss_cine_rewards_hall.png", GameplayScene.drawWorldOnly, function() cr:draw() end)
        end
    end

    for _, e in ipairs(events) do print("[shot_boss_cinematic] " .. e) end
    print("[shot_boss_cinematic] save dir: " .. saveDir)
    love.event.quit()
end

return M
