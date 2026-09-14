-- tools/test_resume.lua
-- Regressão do CONTINUAR DENTRO DA LUTA DO CHEFE (bug do dono, Set/2026, com
-- captura): "quando estou em um boss, salvo e tento abrir pelo Continuar, ele
-- abre com o boss no meio do cenário normal".
--
-- Na captura o lich do ato 2 (220/220) está plantado na ESTRADA — grama,
-- pinheiros, castelo ao longe — em vez do salão. O diagnóstico que este
-- arquivo fixa em números:
--
--   1. O NÓ SOBREVIVE ao save. `currentNode` viaja dentro do `currentRun`
--      serializado; depois do loadRun ele volta com `type == "boss"`, e é por
--      isso que o inimigo (sprite e vida) vem CERTO. A hipótese "o nó se
--      perde" é falsa, e o teste a mata explicitamente.
--   2. O que se perde é a CENA: `bossEntered` é estado de módulo do
--      GameplayScene, nasce false e só vira true pela cerimônia da porta —
--      que o Continuar nunca dispara (o mundo já nasce ancorado no andar
--      salvo, então nenhuma viagem acontece). `isInteriorNode("boss", false)`
--      é false ⇒ estrada.
--   3. A MÚSICA é consequência do mesmo nó: com nodeType="boss" o
--      MusicDirector pede `musicBoss`. O "ficou a do menu" tinha causa
--      própria — o espelho `_current` do diretor — corrigida em 7ffc3c8 e
--      coberta aqui de novo, no contexto do chefe.
--
-- A correção mora em `src/systems/ResumeFlow.lua`, chamado pelo
-- setContinueCallback do main.lua.
--   love . test_one test_resume

local TK = require("tools.testkit")

local M = {}

-- Cena de mentira: registra o que o ResumeFlow mandou fazer. É o que torna a
-- decisão mensurável sem contexto gráfico — e o que faz este teste FALHAR se
-- alguém remover a chamada que entrega o salão.
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

    -- ===== 1. Uma run salva DENTRO da luta do chefe do ato 2 ==============
    local gA = TK.newRunGame("warrior")
    local runA = gA.runManager.currentRun
    runA.actNumber = 2
    runA.floorInAct = 8              -- andar do chefe
    runA.pendingNodes = nil          -- nó já escolhido: está em combate
    runA.currentNode = { type = "boss", label = "Chefe", floorInAct = 8, actNumber = 2 }
    gA:checkpointRun()               -- sandbox *.tool.lua (HEADLESS_TOOL)

    -- ===== 2. CONTINUAR: o nó NÃO se perde no save =========================
    local gB = Game:new()
    t:truthy("save do chefe carrega", gB.runManager:loadRun() == true)
    local runB = gB.runManager.currentRun
    t:truthy("currentNode sobreviveu ao save", runB.currentNode ~= nil)
    t:eq("e ainda é o nó de CHEFE", runB.currentNode and runB.currentNode.type, "boss")
    t:eq("ato preservado", runB.actNumber, 2)
    t:eq("andar preservado", runB.floorInAct, 8)

    -- O inimigo vem do nó — é por isso que a captura mostra o chefe certo.
    gB:resumeRun()
    local statsEsperado = ActSystem.getEnemyStats(2, 8, "boss")
    t:truthy("resumeRun montou um inimigo", gB.enemy ~= nil)
    t:eq("vida do chefe do ato 2 (a da captura)", gB.enemy.health, statsEsperado.health)
    t:truthy("marcado como chefe", gB.enemy.isBoss == true)

    -- ===== 3. A CENA: o que realmente estava quebrado ======================
    -- A predicata da cena é pura e é a fonte única (memory/
    -- enemy_pose_and_scene_anchor.md). Com a flag em false — o estado em que
    -- o Continuar deixava o módulo — ela devolve ESTRADA.
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

    -- O gancho que o ResumeFlow chama tem que EXISTIR na cena de verdade:
    -- renomeá-lo sem atualizar o ResumeFlow devolveria a estrada em silêncio.
    t:truthy("GameplayScene expõe o gancho que o ResumeFlow usa",
        type(GameplayScene._debugForceBossEntered) == "function")

    -- ===== 4. ELITE continua na ESTRADA (não trocar um bug por outro) =====
    -- "o hall é o clímax do ato" — elite e mini-boss lutam lá fora de
    -- propósito (memory/enemy_pose_and_scene_anchor.md).
    for _, tipo in ipairs({ "elite", "mini_boss", "battle" }) do
        local planE = ResumeFlow.plan({ currentNode = { type = tipo } })
        t:falsy("nó '" .. tipo .. "' NÃO entra no salão", planE.bossInterior)
        local sceneE = fakeScene()
        ResumeFlow.apply({ runManager = { currentRun = { currentNode = { type = tipo } } } }, sceneE)
        t:eq("nó '" .. tipo .. "': nenhum salão forçado", sceneE.bossEnteredCalls, 0)
        t:eq("nó '" .. tipo .. "': mundo restaurado mesmo assim", sceneE.resumeWorldCalls, 1)
    end

    -- ===== 5. RESÍDUO DA ENCRUZILHADA =====================================
    -- showMapSelection NÃO limpa currentNode: salvar na bifurcação logo depois
    -- de matar o chefe deixa type="boss" como sobra do nó JÁ resolvido. Sem
    -- esta guarda o Continuar na encruzilhada abriria o salão no lugar da
    -- estrada que se bifurca.
    local planFork = ResumeFlow.plan({
        currentNode = { type = "boss" },
        pendingNodes = { { type = "battle" }, { type = "shop" } },
    })
    t:truthy("encruzilhada detectada", planFork.atFork)
    t:falsy("resíduo 'boss' na encruzilhada NÃO abre o salão", planFork.bossInterior)

    -- Run inexistente/save vazio não estoura.
    t:noerror("plan sem run", function() ResumeFlow.plan(nil) end)
    t:falsy("sem run não há salão", ResumeFlow.plan(nil).bossInterior)

    -- ===== 6. A MÚSICA ====================================================
    t:eq("o nó do save pede a trilha do CHEFE",
        MusicDirector.pick("playing", runB, runB.currentNode.type), "musicBoss")
    t:eq("perdido o nó, cairia no tema do ATO (o sintoma do relatório)",
        MusicDirector.pick("playing", runB, nil), "musicAct2")

    -- Fim a fim, com o AudioManager de verdade: menu tocando, espelho do
    -- diretor mentindo, e o Continuar num chefe tem que virar musicBoss.
    local AudioManager = require("engine.AudioManager")
    local audio = AudioManager:new()
    if audio:isAudioAvailable() then
        local prevAudio = _G.audioSystem
        _G.audioSystem = audio
        audio:setGroupVolume("master", 0)   -- teste, não playtest
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

    -- ===== 7. A LIGAÇÃO NO main.lua =======================================
    -- O ResumeFlow só existe se alguém o chamar. Sem esta trava, remover a
    -- linha do setContinueCallback devolveria o bug com a suíte toda verde.
    local src = love.filesystem.read("main.lua") or ""
    t:truthy("setContinueCallback usa o ResumeFlow",
        src:find("ResumeFlow", 1, true) ~= nil)

    gB.runManager:deleteSave()
    return t:done()
end

return M
