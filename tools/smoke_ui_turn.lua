local M = {}

function M.run()
    local pass, fail = 0, 0
    local function check(name, cond)
        if cond then pass = pass + 1; print("  [ok] " .. name)
        else fail = fail + 1; print("  [FAIL] " .. name) end
    end

    print("---- smoke: ciclo de turno VIA CLIQUES (UI) ----")

    _G.EventManager = require("engine.EventManager")
    _G.Event = require("engine.Event")
    require("src.i18n.I18n").init()

    local Game = require("src.core.Game")
    local Button = require("components.Button")
    local EnemyRenderer = require("src.ui.EnemyRenderer")

    local game = Game:new()
    game:startNewRun("warrior")
    game:startGame()
    _G.game = game

    local playButton = Button:new(700, 550, 180, 60, "Jogar Cartas", function()
        if game.turn == "player" then game:playSelectedCards() end
    end)
    local endTurnButton = Button:new(700, 620, 180, 44, "Encerrar Turno",
        function()
            if game.turn == "player" then game:endTurn() end
        end)

    local function pump(secs)
        local dt = 1 / 30
        for _ = 1, math.floor(secs * 30) do
            _G.EventManager.update(dt)
            EnemyRenderer.update(dt)
            if game.enemy.update then game.enemy:update(dt) end
            game.combatAnimationSystem:update(dt)
            playButton:update(dt)
            endTurnButton:update(dt)
            if game._endTurnQueued and game.turn == "player"
                and not game.combatAnimationSystem:isBlocking() then
                game._endTurnQueued = false
                game:endTurn()
            end
            if game.turn == "enemy"
                and not game.combatAnimationSystem:isBlocking()
                and game.enemy:isAlive() then
                game:enemyTurn()
            end
        end
    end

    local function click(btn)
        btn.hover = true
        local consumedPress = btn:mousepressed(btn.x + 5, btn.y + 5, 1)
        local firedRelease = btn:mousereleased(btn.x + 5, btn.y + 5, 1)
        return consumedPress, firedRelease
    end

    pump(0.5)

    check("turno inicial é do jogador", game.turn == "player")
    local pressed = select(1, click(endTurnButton))
    check("endTurn: press armou o botão", pressed == true)
    check("endTurn: turno passou pro fluxo inimigo (clique FUNCIONA)",
        game.turn == "enemy" or game._endTurnQueued == true)
    pump(4.0)
    check("inimigo agiu e devolveu o turno", game.turn == "player")

    playButton:setEnabled(false)
    local pressedDisabled = select(1, click(playButton))
    check("botão desabilitado ignora o clique", pressedDisabled == false)
    playButton:setEnabled(true)

    local played = false
    for _, c in ipairs(game.hand) do
        if (c.cost or 0) <= game.player.mana then
            game:selectCard(c)
            played = true
            break
        end
    end
    check("selecionou uma carta pagável", played)
    click(playButton)
    click(endTurnButton)
    local queuedOrDone = game._endTurnQueued or game.turn == "enemy"
    check("endTurn durante animação: enfileirado ou executado", queuedOrDone)
    pump(7.0)
    check("ciclo completo fechou (turno do jogador de novo)",
        game.turn == "player")
    check("mão nova foi comprada", #game.hand > 0)

    local GameplayScene = require("src.scenes.GameplayScene")
    GameplayScene.init({
        game = game,
        playButton = playButton,
        endTurnButton = endTurnButton,
        topBar = { update = function() end },
        gameUI = { update = function() end, show = function() end,
                   hide = function() end },
    })
    check("cena começa vinculada ao game A", GameplayScene.getGame() == game)

    GameplayScene._endTurnCallout = true
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.setBiome(3)
    WorldRoad.travel({ duration = 5 })
    local apexLeaked = false
    EnemyRenderer.triggerAttack("attack", function() apexLeaked = true end)

    _G.EventManager.clear()
    local gameB = Game:new()
    GameplayScene.setGame(gameB)
    gameB:startNewRun("mage")
    gameB:startGame()
    _G.game = gameB

    check("REBIND: cena aponta pro game NOVO", GameplayScene.getGame() == gameB)
    check("REBIND: callout de turno zerado",
        GameplayScene._endTurnCallout == false)
    check("REBIND: mundo voltou pro bioma 1 sem viagem",
        WorldRoad._biomeIndex == 1 and not WorldRoad.isTraveling())
    pump(1.0)
    check("REBIND: apex do inimigo ABANDONADO não vazou pra run nova",
        apexLeaked == false)
    check("run nova é do MAGO (não a abandonada)",
        gameB.runManager and gameB.runManager.currentRun
        and gameB.runManager.currentRun.classId == "mage")
    check("run nova: turno do jogador, mão comprada",
        gameB.turn == "player" and #gameB.hand > 0)
    local playable = false
    for _, c in ipairs(gameB.hand) do
        if (c.cost or 0) <= gameB.player.mana then playable = true break end
    end
    check("run nova: existe carta pagável na mão", playable)

    WorldRoad.restoreProgress(2, 5)
    check("CONTINUAR: bioma do ato 2 restaurado", WorldRoad._biomeIndex == 2)
    check("CONTINUAR: caminhada do andar 5 restaurada (4 viagens)",
        WorldRoad._camZ == 4 * WorldRoad.TRAVEL_DISTANCE)
    check("CONTINUAR: base do trecho no zero (castelo na distância certa)",
        WorldRoad._segBase == 0)
    check("CONTINUAR: sem viagem/entrada pendente",
        not WorldRoad.isTraveling() and not WorldRoad.isEntering())
    check("CONTINUAR: entardecer coerente com o andar (não resetou pro dia 1)",
        WorldRoad._timeOfDay > 0.62 and WorldRoad._timeOfDay < 1)
    WorldRoad.resetRun()

    do
        GameplayScene.updatePlayButtonPosition()
        local startX, spacing, _, n = GameplayScene.handLayout()
        if n and n > 0 then
            local cardW = 96 * (require("src.core.Config").Cards.BASE_SCALE or 1.333)
            local fanCenter = startX + (spacing * (n - 1) + cardW) / 2
            local center = love.graphics.getWidth() / 2
            check(string.format(
                "mão centrada na TELA (centro do leque %.0f vs %.0f)",
                fanCenter, center), math.abs(fanCenter - center) <= 1)
        else
            check("mão centrada: sem cartas pra medir (inesperado)", false)
        end
    end

    local gmA = Game:new()
    gmA:startNewRun("warrior")
    gmA:startGame()
    gmA.runManager:generateNextNodes(3)
    check("encruzilhada: nós pendentes gerados",
        gmA.runManager:getPendingNodes() ~= nil)
    gmA.player.maxHealth = 123
    gmA.player.health = 111
    gmA.player.baseMaxMana = 5
    gmA.scoreSystem.runScore = 777
    gmA:checkpointRun()
    local gmB = Game:new()
    check("encruzilhada: save carrega", gmB.runManager:loadRun() == true)
    local pend = gmB.runManager:getPendingNodes()
    check("encruzilhada: pendentes SOBREVIVEM ao load (roteia pro mapa)",
        pend ~= nil and #pend >= 2)
    gmB:resumeRun()
    check("CONTINUAR: vida máxima do evento sobrevive (123)",
        gmB.player.maxHealth == 123)
    check("CONTINUAR: HP atual sobrevive (111)", gmB.player.health == 111)
    check("CONTINUAR: mana base permanente sobrevive (5)",
        gmB.player.baseMaxMana == 5 and gmB.player.maxMana == 5)
    check("CONTINUAR: pontuação da run sobrevive (777)",
        gmB.scoreSystem.runScore == 777)
    gmB.runManager:deleteSave()

    local gmJ = Game:new()
    gmJ:startNewRun("mage")
    gmJ:startGame()
    _G.game = gmJ
    gmJ:addJokerToRun("mage_machine_learning")
    check("proc-fx: joker de compra extra ativo no slot", #gmJ.jokerSlots >= 1)
    local jk = gmJ.jokerSlots[#gmJ.jokerSlots]
    gmJ.effectSystem:applyTriggerEffects(gmJ, "turn_start", {})
    check("proc-fx: turn_start TICOU o joker (hop no slot)",
        jk.juice ~= nil and jk.juice.hop_amt ~= nil)
    local ok7 = pcall(function()
        gmJ.effectSystem:notifyJokerProc(gmJ, jk, "Escudo mantido", "armor")
    end)
    check("proc-fx: notifyJokerProc público não explode", ok7)

    local gmC = Game:new()
    gmC:startNewRun("warrior")
    gmC:startGame()
    _G.game = gmC
    GameplayScene.setGame(gmC)
    GameplayScene.SCENE_MODE = "worldroad"

    local noop = function() end
    GameplayScene.init({
        game = gmC,
        playButton = playButton,
        endTurnButton = endTurnButton,
        topBar = { update = noop, draw = noop },
        gameUI = { update = noop, draw = noop, show = noop, hide = noop },
    })

    local CardBase = require("src.cards.base.Card")
    local realDraw = CardBase.draw
    local drawCount = 0
    CardBase.draw = function() drawCount = drawCount + 1 end

    local drawErr = nil
    local function countHandDraws()
        drawCount = 0
        local ok, err = pcall(function() GameplayScene.draw() end)
        if not ok then drawErr = err end
        return drawCount
    end

    WorldRoad._entry = nil
    local baseline = countHandDraws()
    if drawErr then print("    [info] GameplayScene.draw erro: " .. tostring(drawErr)) end
    check("mao DESENHA fora da cerimonia (baseline)", baseline > 0)

    WorldRoad._entry = { phase = "door", t = 0, doorK = 0, fade = 0 }
    check("sanity: isEntering() reflete a cerimonia", WorldRoad.isEntering())
    check("mao NAO desenha durante a cerimonia do castelo", countHandDraws() == 0)

    WorldRoad._entry = nil
    check("mao VOLTA quando a cerimonia acaba", countHandDraws() > 0)

    CardBase.draw = realDraw

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
