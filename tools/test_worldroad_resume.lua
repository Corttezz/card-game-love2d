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

    local gA = TK.newRunGame("warrior")
    gA.runManager:advanceFloorInAct()
    gA.runManager:generateNextNodes(3)
    local pendA = gA.runManager:getPendingNodes()
    t:truthy("save montado na encruzilhada (nós pendentes)",
        pendA ~= nil and #pendA >= 2)
    for _, n in ipairs(pendA) do n.type = "battle" end
    local savedFloor = gA.runManager.currentRun.floorInAct
    local savedAct   = gA.runManager.currentRun.actNumber
    gA:checkpointRun()

    local gB = Game:new()
    t:truthy("save da encruzilhada carrega", gB.runManager:loadRun() == true)
    gB:resumeRun()
    _G.game = gB

    local noop = function() end
    local playButton = Button:new(700, 550, 180, 60, "Jogar", noop)
    local endTurnButton = Button:new(700, 620, 180, 44, "Encerrar", noop)
    local prevMode = GameplayScene.SCENE_MODE
    GameplayScene.SCENE_MODE = "worldroad"
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
    t:eq("câmera no andar ANTERIOR ao do save (a caminhada ainda falta)",
        WorldRoad._camZ, (savedFloor - 2) * WorldRoad.TRAVEL_DISTANCE)
    local anchor = GameplayScene.getFloorAnchor()
    t:check("âncora de andar EXISTE e difere do andar do save (a viagem vai"
        .. " disparar) — obtida " .. tostring(anchor),
        anchor ~= nil and anchor ~= (savedAct .. ":" .. savedFloor))

    local chosenNode, chosenIdx
    t:truthy("fork montou na estrada", WorldRoad.showFork(pend, function(node, idx)
        chosenNode, chosenIdx = node, idx
        gB.runManager:chooseNode(idx, {})
        gB:nextPhase()
    end))
    WorldRoad._fork.markBoxes[1] = { x1 = -1e9, y1 = -1e9, x2 = 1e9, y2 = 1e9 }
    t:truthy("clique no braço 1 foi consumido pelo fork",
        WorldRoad.forkMousePressed(0, 0))
    for _ = 1, 120 do WorldRoad.update(1 / 30) end
    t:truthy("convergência terminou e chamou onChosen", chosenNode ~= nil)
    t:truthy("o marco da bifurcação FOI plantado (sanity do cenário do bug)",
        WorldRoad._landmark ~= nil)

    GameplayScene.update(1 / 30)
    t:truthy("escolhido o nó, o mundo VIAJA (é a caminhada que tira o marco)",
        WorldRoad.isTraveling())

    for _ = 1, 240 do
        GameplayScene.update(1 / 30)
        if not WorldRoad.isTraveling() then break end
    end
    t:falsy("a caminhada terminou", WorldRoad.isTraveling())

    local lm = WorldRoad._landmark
    local rel = lm and (lm.z - WorldRoad._camZ) or -math.huge
    t:check(string.format(
        "marco da bifurcação ficou pra trás (rel %.1f < -3), longe do inimigo"
        .. " em BATTLE_REL %.1f", rel, WorldRoad.BATTLE_REL), rel < -3)

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

    WorldRoad.resetRun()
    GameplayScene.SCENE_MODE = prevMode
    gB.runManager:deleteSave()

    return t:done()
end

return M
