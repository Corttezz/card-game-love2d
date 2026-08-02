-- tools/smoke_ui_turn.lua
-- Regressão do CAMINHO DO CLIQUE (nasceu do bug "encerro o turno e nada
-- acontece"): testa o ciclo de turno como o JOGADOR faz — mousepressed +
-- mousereleased nos botões reais, via GameplayScene — não só a API do Game.
--   love . smoke_ui_turn

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

    -- Botões REAIS com os MESMOS callbacks do main.lua
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
            -- fila do endTurn (espelho do GameplayScene.update)
            if game._endTurnQueued and game.turn == "player"
                and not game.combatAnimationSystem:isBlocking() then
                game._endTurnQueued = false
                game:endTurn()
            end
            -- gate do turno inimigo (espelho do GameplayScene)
            if game.turn == "enemy"
                and not game.combatAnimationSystem:isBlocking()
                and game.enemy:isAlive() then
                game:enemyTurn()
            end
        end
    end

    -- CLIQUE de verdade: hover (via update com mouse simulado) não dá pra
    -- forçar sem love.mouse — seta hover/pressed pelo caminho dos handlers.
    local function click(btn)
        btn.hover = true                       -- mouse sobre o botão
        local consumedPress = btn:mousepressed(btn.x + 5, btn.y + 5, 1)
        local firedRelease = btn:mousereleased(btn.x + 5, btn.y + 5, 1)
        return consumedPress, firedRelease
    end

    pump(0.5)

    -- ===== 1. clique em ENCERRAR TURNO dispara o onClick =====
    check("turno inicial é do jogador", game.turn == "player")
    local pressed = select(1, click(endTurnButton))
    check("endTurn: press armou o botão", pressed == true)
    check("endTurn: turno passou pro fluxo inimigo (clique FUNCIONA)",
        game.turn == "enemy" or game._endTurnQueued == true)
    pump(2.0)
    check("inimigo agiu e devolveu o turno", game.turn == "player")

    -- ===== 2. JOGAR CARTAS desabilitado NÃO dispara =====
    playButton:setEnabled(false)
    local pressedDisabled = select(1, click(playButton))
    check("botão desabilitado ignora o clique", pressedDisabled == false)
    playButton:setEnabled(true)

    -- ===== 3. jogar carta via clique + endTurn NA ANIMAÇÃO (fila) =====
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
    -- clica encerrar IMEDIATAMENTE (animação no ar) — precisa ENFILEIRAR
    click(endTurnButton)
    local queuedOrDone = game._endTurnQueued or game.turn == "enemy"
    check("endTurn durante animação: enfileirado ou executado", queuedOrDone)
    pump(3.0)
    check("ciclo completo fechou (turno do jogador de novo)",
        game.turn == "player")
    check("mão nova foi comprada", #game.hand > 0)

    -- ===== 4. ABANDONO: a cena REBINDA pro game novo (bug Jul/2026:
    -- GameplayScene capturava deps.game e seguia na run abandonada —
    -- "abandonei, escolhi mago e caí na run antiga, tudo bugado") =====
    local GameplayScene = require("src.scenes.GameplayScene")
    GameplayScene.init({
        game = game,                     -- game A (a run "abandonada")
        playButton = playButton,
        endTurnButton = endTurnButton,
        topBar = { update = function() end },
        gameUI = { update = function() end, show = function() end,
                   hide = function() end },
    })
    check("cena começa vinculada ao game A", GameplayScene.getGame() == game)

    -- estado sujo per-run que precisa morrer no rebind
    GameplayScene._endTurnCallout = true
    -- CENÁRIO sujo da run "abandonada": mundo avançado no bioma 3 com
    -- viagem no ar + attackFx do inimigo com apex PENDENTE (o callback
    -- do game morto não pode disparar na run nova)
    local WorldRoad = require("src.ui.WorldRoad")
    WorldRoad.setBiome(3)
    WorldRoad.travel({ duration = 5 })
    local apexLeaked = false
    EnemyRenderer.triggerAttack("attack", function() apexLeaked = true end)

    -- espelho do returnToMenu + startGame(nova classe)
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
    -- pump: se o attackFx da run morta tivesse sobrevivido, o apex
    -- dispararia aqui dentro da run nova
    pump(1.0)
    check("REBIND: apex do inimigo ABANDONADO não vazou pra run nova",
        apexLeaked == false)
    check("run nova é do MAGO (não a abandonada)",
        gameB.runManager and gameB.runManager.currentRun
        and gameB.runManager.currentRun.classId == "mage")
    check("run nova: turno do jogador, mão comprada",
        gameB.turn == "player" and #gameB.hand > 0)
    -- carta da run nova é jogável (o sintoma era "nenhuma carta joga")
    local playable = false
    for _, c in ipairs(gameB.hand) do
        if (c.cost or 0) <= gameB.player.mana then playable = true break end
    end
    check("run nova: existe carta pagável na mão", playable)

    -- ===== 5. CONTINUAR: o mundo retoma no exato lugar do save =====
    -- (pedido do dono: progresso/proximidade do castelo/cenário — o
    -- progresso é emergente, restoreProgress reconstrói por ato+andar)
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
    WorldRoad.resetRun()   -- não vaza estado pro resto da suíte

    -- ===== 5b. MÃO CENTRALIZADA NA TELA (feedback Jul/2026) =====
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

    -- ===== 6. SAVE NA ENCRUZILHADA: os nós pendentes sobrevivem ao
    -- save/load (bug: 'salvei escolhendo caminho, voltei e apareceu um
    -- inimigo do nada' — o Continuar roteia pro mapa SE há pendentes) =====
    local gmA = Game:new()
    gmA:startNewRun("warrior")
    gmA.runManager:generateNextNodes(3)
    check("encruzilhada: nós pendentes gerados",
        gmA.runManager:getPendingNodes() ~= nil)
    gmA.runManager:saveRun()
    local gmB = Game:new()
    check("encruzilhada: save carrega", gmB.runManager:loadRun() == true)
    local pend = gmB.runManager:getPendingNodes()
    check("encruzilhada: pendentes SOBREVIVEM ao load (roteia pro mapa)",
        pend ~= nil and #pend >= 2)
    gmB.runManager:deleteSave()

    print(string.format("\n  TOTAL: %d pass / %d fail", pass, fail))
    return fail == 0
end

return M
