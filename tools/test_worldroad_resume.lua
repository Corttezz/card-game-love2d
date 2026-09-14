-- tools/test_worldroad_resume.lua
-- Regressão do CONTINUAR + ENCRUZILHADA (bug do dono, Set/2026:
-- "clico em continuar, clico em batalha e a bandeira não sai da frente do
-- primeiro inimigo").
--
-- A bandeira é o MARCO da bifurcação (assets/sprites/world/landmark_battle.png,
-- um estandarte vermelho). A convergência do fork o planta em ARRIVE_REL 7.5 e
-- quem o leva embora é a CAMINHADA até o próximo encontro — a viagem que
-- GameplayScene dispara quando detecta troca de andar. Retomando do menu, essa
-- detecção nascia zerada (lastFloorKey = nil ⇒ "início de run, não anda") e a
-- viagem NUNCA acontecia: o marco ficava parado à frente do inimigo
-- (BATTLE_REL 9) e, por ser mais perto, desenhado POR CIMA dele.
--
-- O teste percorre o caminho do jogador: salva na encruzilhada, carrega,
-- retoma (GameplayScene.resumeWorld), escolhe o braço de batalha e cobra a
-- caminhada + a saída do marco de cena.
--   love . test_one test_worldroad_resume

local TK = require("tools.testkit")

local M = {}

function M.run()
    local t = TK.new("Continuar na encruzilhada: a caminhada leva o marco embora")

    TK.bootstrap()
    TK.seedRng(20260913)

    local Game           = require("src.core.Game")
    local Button         = require("components.Button")
    local WorldRoad      = require("src.ui.WorldRoad")
    local GameplayScene  = require("src.scenes.GameplayScene")

    -- ===== 1. Uma run que chegou na ENCRUZILHADA e salvou ===================
    -- (espelho do showMapSelection: o andar avança ANTES de montar o fork)
    local gA = TK.newRunGame("warrior")
    gA.runManager:advanceFloorInAct(3)
    gA.runManager:generateNextNodes(3)
    local pendA = gA.runManager:getPendingNodes()
    t:truthy("save montado na encruzilhada (nós pendentes)",
        pendA ~= nil and #pendA >= 2)
    -- todo braço vira BATALHA: o marco em jogo é o landmark_battle (a bandeira)
    for _, n in ipairs(pendA) do n.type = "battle" end
    local savedFloor = gA.runManager.currentRun.floorInAct
    local savedAct   = gA.runManager.currentRun.actNumber
    gA:checkpointRun()

    -- ===== 2. CONTINUAR (espelho de menu:setContinueCallback) ==============
    local gB = Game:new()
    t:truthy("save da encruzilhada carrega", gB.runManager:loadRun() == true)
    gB:resumeRun()
    _G.game = gB

    local noop = function() end
    local playButton = Button:new(700, 550, 180, 60, "Jogar", noop)
    local endTurnButton = Button:new(700, 620, 180, 44, "Encerrar", noop)
    local prevMode = GameplayScene.SCENE_MODE
    GameplayScene.SCENE_MODE = "worldroad"
    -- setGame é o que o menu faz ao criar/trocar o Game — zera lastFloorKey
    GameplayScene.setGame(gB)
    GameplayScene.init({
        game = gB,
        playButton = playButton,
        endTurnButton = endTurnButton,
        topBar = { update = noop, draw = noop },
        gameUI = { update = noop, draw = noop, show = noop, hide = noop },
    })
    t:falsy("antes de retomar, a cena não tem âncora de andar",
        GameplayScene.getFloorAnchor())

    GameplayScene.resumeWorld(gB)

    local pend = gB.runManager:getPendingNodes()
    t:truthy("retoma NA encruzilhada (pendentes sobreviveram)", pend ~= nil)
    t:eq("bioma do ato restaurado", WorldRoad._biomeIndex, savedAct)
    -- O mundo pertence ao andar ANTERIOR: a caminhada até o andar salvo é
    -- justamente o que ainda vai acontecer.
    t:eq("câmera no andar ANTERIOR ao do save (a caminhada ainda falta)",
        WorldRoad._camZ, (savedFloor - 2) * WorldRoad.TRAVEL_DISTANCE)
    local anchor = GameplayScene.getFloorAnchor()
    t:check("âncora de andar EXISTE e difere do andar do save (a viagem vai"
        .. " disparar) — obtida " .. tostring(anchor),
        anchor ~= nil and anchor ~= (savedAct .. ":" .. savedFloor))

    -- ===== 3. A ENCRUZILHADA: escolhe um braço (espelho do clique) =========
    local chosenNode, chosenIdx
    t:truthy("fork montou na estrada", WorldRoad.showFork(pend, function(node, idx)
        chosenNode, chosenIdx = node, idx
        -- espelho de onNodeChosen (ramo BATTLE)
        gB.runManager:chooseNode(idx, {})
        gB:nextPhase()
    end))
    -- markBoxes nascem no draw; headless injetamos a caixa do braço 1
    WorldRoad._fork.markBoxes[1] = { x1 = -1e9, y1 = -1e9, x2 = 1e9, y2 = 1e9 }
    t:truthy("clique no braço 1 foi consumido pelo fork",
        WorldRoad.forkMousePressed(0, 0))
    for _ = 1, 120 do WorldRoad.update(1 / 30) end   -- convergência: 2.4s
    t:truthy("convergência terminou e chamou onChosen", chosenNode ~= nil)
    t:truthy("o marco da bifurcação FOI plantado (sanity do cenário do bug)",
        WorldRoad._landmark ~= nil)

    -- ===== 4. A BATALHA: a cena precisa CAMINHAR até o encontro ============
    GameplayScene.update(1 / 30)
    t:truthy("escolhido o nó, o mundo VIAJA (é a caminhada que tira o marco)",
        WorldRoad.isTraveling())

    for _ = 1, 240 do
        GameplayScene.update(1 / 30)
        if not WorldRoad.isTraveling() then break end
    end
    t:falsy("a caminhada terminou", WorldRoad.isTraveling())

    -- O cobrador do bug: o marco não pode estar plantado na faixa do inimigo.
    -- (drawLandmarkFront só o descarta no desenho, com rel < -3; headless
    -- cobramos a GEOMETRIA, que é o que a tela mostra.)
    local lm = WorldRoad._landmark
    local rel = lm and (lm.z - WorldRoad._camZ) or -math.huge
    t:check(string.format(
        "marco da bifurcação ficou pra trás (rel %.1f < -3), longe do inimigo"
        .. " em BATTLE_REL %.1f", rel, WorldRoad.BATTLE_REL), rel < -3)

    -- ===== 5. Retomar NO MEIO de uma batalha não inventa caminhada =========
    -- (sem pendentes o mundo JÁ está no andar certo: viajar aqui teleportaria
    -- o inimigo pra longe no primeiro frame)
    local gC = TK.newRunGame("warrior")
    gC.runManager.currentRun.pendingNodes = nil
    gC.runManager.currentRun.actNumber = 2
    gC.runManager.currentRun.floorInAct = 5
    GameplayScene.setGame(gC)
    GameplayScene.init({
        game = gC,
        playButton = playButton,
        endTurnButton = endTurnButton,
        topBar = { update = noop, draw = noop },
        gameUI = { update = noop, draw = noop, show = noop, hide = noop },
    })
    _G.game = gC
    GameplayScene.resumeWorld(gC)
    t:eq("sem encruzilhada: câmera no andar do save", WorldRoad._camZ,
        4 * WorldRoad.TRAVEL_DISTANCE)
    t:eq("sem encruzilhada: âncora é o andar do save",
        GameplayScene.getFloorAnchor(), "2:5")
    GameplayScene.update(1 / 30)
    t:falsy("sem encruzilhada: nenhuma viagem espúria no 1º frame",
        WorldRoad.isTraveling())

    -- Não vaza estado de mundo/cena pro resto da suíte.
    WorldRoad.resetRun()
    GameplayScene.SCENE_MODE = prevMode
    gB.runManager:deleteSave()

    return t:done()
end

return M
