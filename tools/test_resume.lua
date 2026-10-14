local TK = require("tools.testkit")

local M = {}

local function fakeScene()
    local s = { resumeWorldCalls = 0, bossEnteredCalls = 0 }
    s.resumeWorld = function() s.resumeWorldCalls = s.resumeWorldCalls + 1 end
    s._debugForceBossEntered = function()
        s.bossEnteredCalls = s.bossEnteredCalls + 1
    end
    return s
end

function M.run()
    local t = TK.new("Continuar numa luta de chefe: salão e trilha do chefe")

    TK.bootstrap()
    TK.seedRng(20260914)

    local Game          = require("src.core.Game")
    local ResumeFlow    = require("src.systems.ResumeFlow")
    local MusicDirector = require("src.systems.MusicDirector")
    local GameplayScene = require("src.scenes.GameplayScene")
    local ActSystem     = require("src.systems.ActSystem")

    local gA = TK.newRunGame("warrior")
    local runA = gA.runManager.currentRun
    runA.actNumber = 2
    runA.floorInAct = 8
    runA.pendingNodes = nil
    runA.currentNode = { type = "boss", label = "Chefe", floorInAct = 8, actNumber = 2 }
    gA:checkpointRun()

    local gB = Game:new()
    t:truthy("save do chefe carrega", gB.runManager:loadRun() == true)
    local runB = gB.runManager.currentRun
    t:truthy("currentNode sobreviveu ao save", runB.currentNode ~= nil)
    t:eq("e ainda é o nó de CHEFE", runB.currentNode and runB.currentNode.type, "boss")
    t:eq("ato preservado", runB.actNumber, 2)
    t:eq("andar preservado", runB.floorInAct, 8)

    gB:resumeRun()
    local statsEsperado = ActSystem.getEnemyStats(2, 8, "boss")
    t:truthy("resumeRun montou um inimigo", gB.enemy ~= nil)
    t:eq("vida do chefe do ato 2 (a da captura)", gB.enemy.health, statsEsperado.health)
    t:truthy("marcado como chefe", gB.enemy.isBoss == true)

    t:falsy("sem a cerimônia encenada, o chefe cai na ESTRADA (o defeito)",
        GameplayScene.isInteriorNode("boss", false))
    t:truthy("com o salão já entrado, a cena é INTERIOR",
        GameplayScene.isInteriorNode("boss", true))

    local plan = ResumeFlow.plan(runB)
    t:eq("plano lê o nó do save", plan.nodeType, "boss")
    t:falsy("não está na encruzilhada", plan.atFork)
    t:truthy("plano manda entregar o SALÃO", plan.bossInterior)

    local scene = fakeScene()
    local applied = ResumeFlow.apply(gB, scene)
    t:eq("mundo restaurado uma vez", scene.resumeWorldCalls, 1)
    t:eq("salão entregue uma vez (o cobrador do bug)", scene.bossEnteredCalls, 1)
    t:truthy("apply devolve o plano", applied.bossInterior == true)

    t:truthy("GameplayScene expõe o gancho que o ResumeFlow usa",
        type(GameplayScene._debugForceBossEntered) == "function")

    for _, tipo in ipairs({ "elite", "mini_boss", "battle" }) do
        local planE = ResumeFlow.plan({ currentNode = { type = tipo } })
        t:falsy("nó '" .. tipo .. "' NÃO entra no salão", planE.bossInterior)
        local sceneE = fakeScene()
        ResumeFlow.apply({ runManager = { currentRun = { currentNode = { type = tipo } } } }, sceneE)
        t:eq("nó '" .. tipo .. "': nenhum salão forçado", sceneE.bossEnteredCalls, 0)
        t:eq("nó '" .. tipo .. "': mundo restaurado mesmo assim", sceneE.resumeWorldCalls, 1)
    end

    local planFork = ResumeFlow.plan({
        currentNode = { type = "boss" },
        pendingNodes = { { type = "battle" }, { type = "shop" } },
    })
    t:truthy("encruzilhada detectada", planFork.atFork)
    t:falsy("resíduo 'boss' na encruzilhada NÃO abre o salão", planFork.bossInterior)

    t:noerror("plan sem run", function() ResumeFlow.plan(nil) end)
    t:falsy("sem run não há salão", ResumeFlow.plan(nil).bossInterior)

    t:eq("o nó do save pede a trilha do CHEFE",
        MusicDirector.pick("playing", runB, runB.currentNode.type), "musicBoss")
    t:eq("perdido o nó, cairia no tema do ATO (o sintoma do relatório)",
        MusicDirector.pick("playing", runB, nil), "musicAct2")

    local AudioManager = require("engine.AudioManager")
    local audio = AudioManager:new()
    if audio:isAudioAvailable() then
        local prevAudio = _G.audioSystem
        _G.audioSystem = audio
        audio:setGroupVolume("master", 0)
        MusicDirector.registerTracks(audio)
        audio:loadSound("menuMusic", "audio/music.mp3", {
            volume = 0.6, group = "music", stream = true, loop = true })

        audio:playMusic("menuMusic")
        MusicDirector.markCurrent("menuMusic")
        MusicDirector.apply("playing", runB, runB.currentNode.type)
        t:eq("Continuar num chefe troca a música do menu pela do chefe",
            audio.currentMusic, "musicBoss")

        audio:stopMusic()
        _G.audioSystem = prevAudio
    else
        t:truthy("áudio indisponível: a troca não pode ser medida aqui", true)
    end

    local src = love.filesystem.read("main.lua") or ""
    t:truthy("setContinueCallback usa o ResumeFlow",
        src:find("ResumeFlow", 1, true) ~= nil)

    gB.runManager:deleteSave()
    return t:done()
end

return M
