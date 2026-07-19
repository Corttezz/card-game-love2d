local Game = require("src.core.Game")
local CardFrame = require("src.ui.CardFrame")
local Button = require("components.Button")
local Menu = require("components.Menu")
local GameUI = require("components.GameUI")
local CardRewardScreen = require("components.CardRewardScreen")
local ClassSelectionScreen = require("components.ClassSelectionScreen")
local CollectionScreen = require("components.CollectionScreen")
local SettingsMenu = require("components.SettingsMenu")
local TopBar = require("components.TopBar")
local MapScreen = require("components.MapScreen")
local MapManager = require("src.systems.MapManager")
local RestScreen = require("components.RestScreen")
local EventScreen = require("components.EventScreen")
local Events = require("src.data.events")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local BackgroundConfig = require("src.core.BackgroundConfig")
local SmokeSystem = require("src.systems.SmokeSystem")
local SmokeConfig = require("src.config.SmokeConfig")
local ParticleSystem = require("src.systems.ParticleSystem")
local EnemyRenderer = require("src.ui.EnemyRenderer")
local EnemyHud = require("src.ui.EnemyHud")
local SceneLayer = require("src.ui.SceneLayer")
local AudioManager = require("engine.AudioManager")
local SaveManager  = require("engine.SaveManager")
local SceneBackground = require("src.ui.SceneBackground")
local PixelBackground = require("src.ui.PixelBackground")
local CRTShader = require("src.ui.CRTShader")
local I18n = require("src.i18n.I18n")
local Sfx = require("src.systems.Sfx")
local EventManager = require("engine.EventManager")
local Event = require("engine.Event")
local DissolveShader = require("src.ui.DissolveShader")
local FlashShader = require("src.ui.FlashShader")
local BoosterShader = require("src.ui.BoosterShader")
local FoilShader = require("src.ui.FoilShader")
local PolychromeShader = require("src.ui.PolychromeShader")
local NegativeShader = require("src.ui.NegativeShader")
local Debug = require("src.core.Debug")
local PackOpenScreen = require("components.PackOpenScreen")
local BoosterPackSystem = require("src.systems.BoosterPackSystem")
local FloatingText = require("src.ui.FloatingText")
local RoundEvalScreen = require("components.RoundEvalScreen")
local CardParticles = require("src.systems.CardParticles")
local ScreenShake = require("src.systems.ScreenShake")
local EndScreens = require("src.scenes.EndScreens")
local GameplayScene = require("src.scenes.GameplayScene")
local BootScene = require("src.scenes.BootScene")

local game
local menu
local gameUI
local cardRewardScreen
local classSelectionScreen
local collectionScreen
local achievementsScreen
local endTurnButton
local settingsMenu
local pauseMenu
local topBar
local mapScreen
local deckViewerScreen
-- _G.jokerManagerScreen mora em _G (não como upvalue): love.load já está no teto
-- de 60 upvalues do Lua e um a mais estoura o compilador. Segue o padrão dos
-- outros singletons globais do arquivo (_G.togglePauseMenu etc.).
local restScreen
local eventScreen
local packOpenScreen
local roundEvalScreen
-- hoverCard agora é state interno da GameplayScene
local playButton
local currentState = "boot" -- boot (splash), menu, classSelection, playing, gameOver, victory, cardReward, collection, mapSelection, rest, event

-- Screen shake agora vive em src/systems/ScreenShake.lua.
-- _G.triggerShake é registrado em love.load via ScreenShake.install() pra
-- manter back-compat com sistemas que já usam.
local gameBackground -- Cache da imagem de background
local smokeSystem -- Sistema de partículas de smoke
local audioSystem -- Sistema de áudio

-- Função para iniciar o jogo com classe selecionada
local function startGame(classId)
    currentState = "playing"

    -- Flash de transição (Fase 6.5) — passa pra batalha com piscada branca.
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.5, 0.4) end

    -- Inicia corrida com a classe selecionada
    game:startNewRun(classId)

    game:startGame()
    gameUI:show()
    classSelectionScreen:hide()

    -- Aplica smoke do ato 1 assim que a primeira batalha comeca
    if smokeSystem then
        SmokeConfig.applyToSystem(smokeSystem, "act1")
    end
end

-- Função para voltar ao menu
local function returnToMenu()
    if currentState ~= "menu" then Sfx.play("menuClose") end
    currentState = "menu"

    -- Mata TODAS as sequências pendentes do jogo descartado (combate, eases,
    -- transições agendadas). Sem isto, callbacks do game VELHO continuavam
    -- rodando por baixo do menu — re-salvavam a run recém-abandonada e até
    -- puxavam currentState de volta pro jogo ("abandonei, cliquei em Jogar e
    -- caí na run antiga" — playtest Jul/2026). Ordem importa: clear ANTES de
    -- menu:show() (a intro do menu agenda eases novos).
    EventManager.clear()

    -- A run antiga morre NA MEMÓRIA também. deleteSave/saveRun já decidiram o
    -- disco; isto impede qualquer checkpointRun retardatário de ressuscitá-la.
    if game and game.runManager then
        game.runManager.currentRun = nil
        game.runManager.isRunActive = false
    end
    require("src.systems.Rng").clearActive()

    game = Game:new() -- Reseta o jogo (cria novo ShopSystem com pools resetados)
    if cardRewardScreen then cardRewardScreen.shopSystem = game.shopSystem end
    -- Re-vincula a TopBar ao game NOVO (antes ficava apontando pro morto:
    -- ouro/deck congelavam e o clique da engrenagem caía no aviso).
    if topBar then topBar:setGame(game) end
    -- Re-vincula a CENA DE GAMEPLAY ao game novo (bug Jul/2026: a cena
    -- capturava deps.game e seguia desenhando a run ABANDONADA — "abandonei,
    -- escolhi mago e caí na run antiga com tudo bugado"). Também zera o
    -- estado de turno do módulo (turnStage/bossEntered per-run).
    GameplayScene.setGame(game)
    gameUI:hide()
    menu:show()
    if menu.enterWithIntro then menu:enterWithIntro() end
end

-- Forward-declares para mutual recursion map <-> reward
local showMapSelection

-- Aplica o preset de smoke correspondente ao ato atual (tint ambiental por capítulo).
local function applyActSmoke()
    if not smokeSystem or not game or not game.runManager then return end
    local run = game.runManager.currentRun
    if not run then return end
    local preset = "default"
    if run.endlessMode then preset = "act3"
    elseif run.actNumber == 1 then preset = "act1"
    elseif run.actNumber == 2 then preset = "act2"
    elseif run.actNumber >= 3 then preset = "act3" end
    SmokeConfig.applyToSystem(smokeSystem, preset)
end

-- Abre o picker de cartas como OVERLAY de qualquer estado (oferta "Forja" da
-- loja, eventos de deck). Reusa o RestScreen no modo pedido ("forge" |
-- "remove" | "duplicate"): troca temporariamente pro estado "rest" (que já
-- roteia update/draw/input do RestScreen) e restaura o estado anterior ao
-- fechar. onDone roda após a restauração.
_G.openCardPicker = function(mode, onDone)
    local prevState = currentState
    currentState = "rest"
    restScreen:show(game, function()
        currentState = prevState
        if onDone then onDone() end
    end, mode or "forge")
end

-- Atalho legado da oferta "Forja" da loja.
_G.openForgeScreen = function(onDone)
    _G.openCardPicker("forge", onDone)
end

-- Helper: avanca pro proximo map (chamado apos fechar rest/event/shop sem batalha).
local function skipBattleAndShowMap()
    -- Forca advance como se uma batalha tivesse sido vencida sem combate.
    -- Processa exhaust pendente para consistencia.
    game._exhaustedThisBattle = game._exhaustedThisBattle or {}
    -- Nao incrementa currentPhase para nao bagunçar scoring; o floor da run
    -- avança em showMapSelection via advanceFloorInAct.
    showMapSelection()
end

local function onNodeChosen(node, index)
    if not node then return end
    game.runManager:chooseNode(index)

    local t = node.type
    local BT = MapManager.NODE_TYPES

    if t == BT.BATTLE or t == BT.ELITE or t == BT.MINI_BOSS or t == BT.BOSS then
        mapScreen:hide()
        currentState = "playing"
        -- Flash branco na transição mapa → batalha (Fase 6.5). Boss/elite mais forte.
        if FlashShader and FlashShader.trigger then
            local intensity = (t == BT.BOSS or t == BT.MINI_BOSS) and 0.7 or 0.4
            FlashShader.trigger(intensity, 0.45)
        end
        game:nextPhase()
        applyActSmoke()

    elseif t == BT.REST then
        mapScreen:hide()
        currentState = "rest"
        restScreen:show(game, function()
            currentState = "mapSelection" -- nao avanca; volta para gerar proximo map
            -- Note: REST consome o slot do floor (floorInAct ja avancou no showMapSelection).
            -- O proximo showMapSelection vai gerar novos nodes.
            skipBattleAndShowMap()
        end)

    elseif t == BT.EVENT then
        mapScreen:hide()
        -- Sorteio pelo stream "event" com histórico: evento visto não repete
        -- no MESMO ato (Events.roll libera repetição se a pool do ato esgotar).
        local run = game.runManager.currentRun
        run.eventHistory = run.eventHistory or {}
        local ev = Events.roll(run.actNumber or 1, run.eventHistory)
        if not ev then
            -- Sem evento disponivel: age como batalha comum
            currentState = "playing"
            game:nextPhase()
            return
        end
        run.eventHistory[ev.id] = run.actNumber or 1
        currentState = "event"
        eventScreen:show(ev, game, function()
            skipBattleAndShowMap()
        end)

    elseif t == BT.SHOP then
        -- Reusa CardRewardScreen como shop em modo "shop":
        -- 4 cartas + 1 voucher + 2 packs + reroll exponencial + skip +3g.
        mapScreen:hide()
        currentState = "cardReward"
        cardRewardScreen:show(game,
            function(offer)
                Debug.log("Shop: comprou", offer.name)
            end,
            function()
                skipBattleAndShowMap()
            end,
            "shop"
        )
    else
        mapScreen:hide()
        currentState = "playing"
        game:nextPhase()
    end
end

showMapSelection = function()
    -- Se nao ha nos pendentes, avanca o floor e gera novos. Guard contra
    -- duplo-advance (usuario voltar e abrir o mapa de novo).
    if not game.runManager:getPendingNodes() then
        local status = game.runManager:advanceFloorInAct(3)
        if status == "endless_start" then
            game:addMessage("Modo Endless desbloqueado!", "success")
        elseif status == "act_complete" then
            local stats = game.runManager:getCurrentRunStats()
            game:addMessage("Ato completo! Ato " .. ((stats and stats.floor) or "?"), "success")
        end
        game.runManager:generateNextNodes(3)
    end
    local pending = game.runManager:getPendingNodes()
    -- v5 (A Encruzilhada): na estrada, a escolha acontece NO MUNDO — a
    -- estrada se bifurca e cada braço tem um marco. MapScreen vira fallback
    -- (cena não-worldroad ou falha ao montar o fork).
    local GameplayScene = require("src.scenes.GameplayScene")
    local WorldRoad = require("src.ui.WorldRoad")
    if GameplayScene.SCENE_MODE == "worldroad"
       and WorldRoad.showFork(pending, onNodeChosen) then
        currentState = "mapSelection"
    else
        mapScreen:show(pending, onNodeChosen, "Escolha o proximo caminho")
        currentState = "mapSelection"
    end
end

-- Continua o jogo após escolher/pular recompensa.
-- Vitoria agora e disparada por Game:checkVictory (ato 3 boss). Para decidir
-- se mostra o mapa ou nao, apenas checamos se o game ja marcou vitoria.
local function continueAfterReward()
    if game.gameState == "victory" then
        game:endCurrentRun(true)
        currentState = "victory"
    else
        showMapSelection()
    end
end

-- Forward-declares para mutual recursion roundEval ↔ cardReward.
local showRoundEval
local showCardRewards

-- Mostra a tela de Round Eval (cash out estilo Balatro). Triggered após
-- batalha vencida em modo run, antes da loja. Sources construídas por
-- Game:_buildRoundEvalSources. Click "Resgatar" → showCardRewards.
showRoundEval = function()
    currentState = "roundEval"

    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.4, 0.35) end
    Sfx.play("battleVictory")

    local sources = game:_buildRoundEvalSources()
    roundEvalScreen:show(game, sources, function()
        showCardRewards()
    end)
end

-- Função para mostrar recompensas de cartas após vitória
showCardRewards = function()
    currentState = "cardReward"

    -- Flash branco curto pra transição playing → recompensa (Fase 6.5).
    if FlashShader and FlashShader.trigger then FlashShader.trigger(0.4, 0.35) end

    -- F12.2: battleVictory já toca em showRoundEval (antes deste fluxo). Remover
    -- aqui evita som duplicado quando jogador clica Resgatar e abre cardReward.

    -- Modo "rewards" pós-batalha: 3 cartas, sem reroll, skip = continuar.
    cardRewardScreen:show(game,
        function(offer)
            Debug.log("Card purchased:", offer.name)
        end,
        function()
            continueAfterReward()
        end,
        "rewards"
    )
end

function love.load(loveArgs)
    -- QUALQUER execução com argumento é ferramenta/dev (screenshot/smoke/
    -- test/preview/demo/play...) — o jogador de verdade roda `love .` sem
    -- args. A flag manda sistemas persistentes pro SANDBOX: ProfileStats
    -- vira no-op e o SaveManager troca run/settings pra *.tool.lua.
    -- BUG que isso mata (Jul/2026): as tools chamavam startNewRun+startGame
    -- e o checkpointRun SOBRESCREVIA o run.save.lua do JOGADOR — "abandono a
    -- run e ela ressuscita; aparece run que nunca joguei" (o save fantasma
    -- era das capturas de validação, recriado a cada tool rodada).
    local toolArg = loveArgs and loveArgs[1]
    if toolArg then
        _G.HEADLESS_TOOL = true
        print("[sandbox] modo ferramenta (" .. tostring(toolArg)
            .. "): saves em *.tool.lua — o save do jogador não é tocado")
    end

    -- Modo preview: renderiza algumas cartas em PNG e sai.
    --   love . preview_cards
    -- Saida: ~/.local/share/love/card-game/preview_*.png
    if loveArgs and loveArgs[1] == "preview_cards" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_cards").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_fx" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_fx").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_rareglow" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_rareglow").run()
        love.event.quit()
        return
    end

    if loveArgs and loveArgs[1] == "preview_anim" then
        require("src.ui.PixelCanvas").enableNearest()
        I18n.init()
        require("tools.preview_anim").run()
        love.event.quit()
        return
    end

    -- Contact sheet de carta com ícone animado (icons_anim/).
    --   love . preview_card_anim [card_id]
    if loveArgs and loveArgs[1] == "preview_card_anim" then
        require("tools.preview_card_anim").run(loveArgs[2])
        love.event.quit()
        return
    end

    -- Captura screenshot do gameplay (ato 1 warrior) pra debug visual.
    --   love . screenshot_gameplay
    -- Saida: ~/.local/share/love/card-game/gameplay_screenshot.png
    if loveArgs and loveArgs[1] == "screenshot_gameplay" then
        require("tools.screenshot_gameplay").run()
        return
    end

    -- Captura screenshot do MapScreen com 3 nodes mock.
    --   love . screenshot_mapscreen
    if loveArgs and loveArgs[1] == "screenshot_mapscreen" then
        require("tools.screenshot_mapscreen").run()
        return
    end

    -- Captura o WorldRoad (mundo rolante): 3 biomas ou "full" (1 bioma inteiro).
    --   love . screenshot_worldroad [full]
    if loveArgs and loveArgs[1] == "screenshot_worldroad" then
        require("tools.screenshot_worldroad").run(loveArgs[2])
        return
    end

    -- Demo interativo do WorldRoad (SPACE=viagem, 1-6=bioma, E=encounter,
    -- V=vista, R=reset) OU tour automático com keyframes:
    --   love . demo_worldroad          (interativo)
    --   love . demo_worldroad tour     (captura 6 keyframes e sai)
    if loveArgs and loveArgs[1] == "demo_worldroad" then
        require("tools.demo_worldroad").run(loveArgs[2])
        return
    end

    -- Quickstart: pula menu/seleção e cai DIRETO na batalha (validação).
    --   love . play [warrior|mage|rogue]
    local autoPlayClass = nil
    if loveArgs and loveArgs[1] == "play" then
        autoPlayClass = loveArgs[2] or "warrior"
    end

    -- Captura 3 screenshots da animação death (early/mid/late).
    --   love . screenshot_death
    if loveArgs and loveArgs[1] == "screenshot_death" then
        require("tools.screenshot_death").run()
        return
    end

    -- Modo preview do HUD de batalha.
    --   love . preview_battle_hud
    if loveArgs and loveArgs[1] == "preview_battle_hud" then
        require("tools.preview_battle_hud").run()
        love.event.quit()
        return
    end

    -- Modo preview de uma carta em 3 estados (idle/hover/drag) — valida sombra.
    if loveArgs and loveArgs[1] == "preview_card_live" then
        require("tools.preview_card_live").run()
        love.event.quit()
        return
    end

    -- Modo smoke test: roda verificacao do TagSystem e sai com exit code.
    --   love . smoke_tags
    if loveArgs and loveArgs[1] == "smoke_tags" then
        local ok = require("tools.smoke_tags").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Modo smoke test da Fase 2 (efeitos): strength/orbs/poison/etc.
    --   love . smoke_effects
    if loveArgs and loveArgs[1] == "smoke_effects" then
        local ok = require("tools.smoke_effects").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Modo smoke test da Fase 3 (combos).
    --   love . smoke_combos
    if loveArgs and loveArgs[1] == "smoke_combos" then
        local ok = require("tools.smoke_combos").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Modo smoke test da Fase 4 (map/nodes).
    --   love . smoke_map
    if loveArgs and loveArgs[1] == "smoke_map" then
        local ok = require("tools.smoke_map").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Modo teste da entrega STS-improvements v1 (Rng/pity/afinidade/forja/eventos).
    --   love . test_systems
    if loveArgs and loveArgs[1] == "test_systems" then
        local ok = require("tools.test_systems").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Modo smoke test da Fase 5 (acts/endless/curvas).
    --   love . smoke_acts
    if loveArgs and loveArgs[1] == "smoke_acts" then
        local ok = require("tools.smoke_acts").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Smoke test: pilha de descarte + reshuffle.
    --   love . smoke_discard
    if loveArgs and loveArgs[1] == "smoke_discard" then
        local ok = require("tools.smoke_discard").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Smoke test: upgrade pipeline + editions + seals (Fase 3 do refactor Balatro).
    --   love . smoke_upgrades
    if loveArgs and loveArgs[1] == "smoke_upgrades" then
        local ok = require("tools.smoke_upgrades").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Smoke test: ShopSystem modes + booster packs + reroll (Fase 4 do refactor Balatro).
    --   love . smoke_shop
    if loveArgs and loveArgs[1] == "smoke_shop" then
        local ok = require("tools.smoke_shop").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Smoke test: BoosterPackSystem + persistência por cópia (Fase 5).
    --   love . smoke_packs
    if loveArgs and loveArgs[1] == "smoke_packs" then
        local ok = require("tools.smoke_packs").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Screenshot tool: pack opening cinemático (Fase 7). Phase 0..4.
    --   love . screenshot_packopen 4
    if loveArgs and loveArgs[1] == "screenshot_packopen" then
        require("tools.screenshot_packopen").run(loveArgs[2])
        return
    end

    -- Screenshot tool: shop em modo "shop" (Fase 8 do refactor Balatro).
    --   love . screenshot_shop 1
    if loveArgs and loveArgs[1] == "screenshot_shop" then
        require("tools.screenshot_shop").run(loveArgs[2])
        return
    end

    -- Screenshot da coleção (grid + modal inspect da carta alvo).
    --   love . screenshot_collection [card_id]
    if loveArgs and loveArgs[1] == "screenshot_collection" then
        require("tools.screenshot_collection").run(loveArgs[2])
        return
    end

    -- Screenshot tool: round eval / cash out (Fase 9). Phase 0..3.
    --   love . screenshot_round_eval 3
    if loveArgs and loveArgs[1] == "screenshot_round_eval" then
        require("tools.screenshot_round_eval").run(loveArgs[2])
        return
    end

    -- Testa o fluxo de save/abandono/run nova (bug "run antiga ressuscita"):
    --   love . test_saveflow
    if loveArgs and loveArgs[1] == "test_saveflow" then
        require("tools.test_saveflow").run()
        return
    end

    -- Valida o TurnBanner v2 (placa grimório, player + enemy):
    --   love . screenshot_turnbanner
    if loveArgs and loveArgs[1] == "screenshot_turnbanner" then
        require("tools.screenshot_turnbanner").run()
        return
    end

    -- Valida o cursor pixel-art (contexto + ampliado):
    --   love . screenshot_cursor
    if loveArgs and loveArgs[1] == "screenshot_cursor" then
        require("tools.screenshot_cursor").run()
        return
    end

    -- Valida a animação de vela do menu (grid do ciclo de crossfade):
    --   love . screenshot_menuanim
    if loveArgs and loveArgs[1] == "screenshot_menuanim" then
        require("tools.screenshot_menuanim").run()
        return
    end

    -- Telas de UI sem harness próprio (levantamento redesign UI/UX):
    --   love . screenshot_ui menu|class|settings|rest|event|collection|all
    if loveArgs and loveArgs[1] == "screenshot_ui" then
        require("tools.screenshot_ui").run(loveArgs[2])
        return
    end

    -- Valida a identidade CRT (power em 4 estágios).
    if loveArgs and loveArgs[1] == "screenshot_crt" then
        require("tools.screenshot_crt").run()
        return
    end

    -- Valida a investida do inimigo (windup/apex/recoil + veneno).
    if loveArgs and loveArgs[1] == "screenshot_attack" then
        require("tools.screenshot_attack").run()
        return
    end

    -- Piloto de IA: joga runs completas sozinho e escreve diario+metricas.
    --   love . autoplay [runs] [warrior|mage|rogue|all]
    if loveArgs and loveArgs[1] == "autoplay" then
        require("tools.autoplay").run(loveArgs[2], loveArgs[3])
        return
    end

    -- Validacao do catalogo de cartas (Fase 7).
    --   love . validate_cards
    if loveArgs and loveArgs[1] == "validate_cards" then
        local ok = require("tools.validate_cards").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Regressão do caminho do CLIQUE (botões de turno via UI).
    if loveArgs and loveArgs[1] == "smoke_ui_turn" then
        local ok = require("tools.smoke_ui_turn").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Capturas do Menu+Entrada v2 (OSD, sintonia, cascade, settings).
    if loveArgs and loveArgs[1] == "screenshot_menu_v2" then
        require("tools.screenshot_menu_v2").run()
        return
    end

    -- Capturas do Salão dos Heróis (seleção de classe v2).
    if loveArgs and loveArgs[1] == "screenshot_class_select" then
        require("tools.screenshot_class_select").run()
        return
    end

    -- Regressão do mouse através do vidro (domo do CRT vs hit-test).
    if loveArgs and loveArgs[1] == "smoke_crt_mouse" then
        local ok = require("tools.smoke_crt_mouse").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Regressão da ordem do turno (escudo vs apex da investida).
    if loveArgs and loveArgs[1] == "smoke_turn_order" then
        local ok = require("tools.smoke_turn_order").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Roda UM teste isolado por nome (util pra iterar).
    --   love . test_one test_combat
    if loveArgs and loveArgs[1] == "test_one" and loveArgs[2] then
        local ok = require("tools." .. loveArgs[2]).run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Suite COMPLETA (unit + smoke + validacao). Total geral + exit code.
    --   love . test_all
    if loveArgs and loveArgs[1] == "test_all" then
        local ok = require("tools.run_all_tests").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Teste de i18n (chaves/traducoes/interpolacao) isolado.
    --   love . test_i18n
    if loveArgs and loveArgs[1] == "test_i18n" then
        local ok = require("tools.test_i18n").run()
        love.event.quit(ok and 0 or 1)
        return
    end

    -- Roda TODOS os smoke tests em sequencia.
    --   love . smoke_all
    if loveArgs and loveArgs[1] == "smoke_all" then
        local okT = require("tools.smoke_tags").run()
        local okE = require("tools.smoke_effects").run()
        local okC = require("tools.smoke_combos").run()
        local okM = require("tools.smoke_map").run()
        local okA = require("tools.smoke_acts").run()
        local okD = require("tools.smoke_discard").run()
        local okU = require("tools.smoke_upgrades").run()
        local okS = require("tools.smoke_shop").run()
        local okP = require("tools.smoke_packs").run()
        local okO = require("tools.smoke_turn_order").run()
        local okUI = require("tools.smoke_ui_turn").run()
        local okCRT = require("tools.smoke_crt_mouse").run()
        local ok = okT and okE and okC and okM and okA and okD and okU and okS and okP and okO and okUI and okCRT
        print(ok and "\n== ALL GREEN ==" or "\n== SOME FAILED ==")
        love.event.quit(ok and 0 or 1)
        return
    end

    -- I18n primeiro: carrega locale salvo (default pt_BR) antes de qualquer
    -- modulo que use I18n.t na inicializacao (Menu, CardRegistry, etc.)
    I18n.init()

    -- Re-aplica titulo da janela quando idioma mudar
    I18n.onLocaleChanged(function()
        love.window.setTitle(I18n.t("window_title"))
    end)

    -- Carrega settings persistidos (volumes, fullscreen, CRT, locale).
    -- Se nao existir, retorna defaults (DEFAULT_SETTINGS no SaveManager).
    local persistedSettings = SaveManager.loadSettings()

    -- Aplica fullscreen ANTES de inicializar UI (evita reflow desnecessário).
    if persistedSettings.fullscreen then
        love.window.setFullscreen(true)
    end

    -- Inicializa o sistema de áudio com volumes do save.
    audioSystem = AudioManager:new({
        masterVolume = persistedSettings.masterVolume,
        musicVolume  = persistedSettings.musicVolume,
        sfxVolume    = persistedSettings.sfxVolume,
    })
    audioSystem:printStatus()

    -- Torna o sistema de áudio global para outros módulos
    _G.audioSystem = audioSystem
    _G.persistedSettings = persistedSettings

    -- Settings runtime que outros sistemas leem (ScreenShake, Moveable.juice_up,
    -- Card ambient_tilt). Bind direto em persistedSettings: mudanças no
    -- SettingsMenu refletem aqui automaticamente sem proxy.
    _G.gameSettings = persistedSettings

    -- Fila de eventos temporais (engine/EventManager). Sistemas podem
    -- agendar sequências via _G.EventManager.addEvent{...} sem passar ctx.
    _G.EventManager = EventManager
    _G.Event = Event
    
    -- Carrega música de fundo e sons se áudio estiver disponível
    if audioSystem:isAudioAvailable() then
        -- Música do menu (loop, streaming). Tocada via Sfx.playMusic("menuMusic")
        -- após o splash terminar (ver components/Menu.lua:enterWithIntro).
        audioSystem:loadSound("menuMusic", "audio/music.mp3", {
            volume = 0.6,
            group  = "music",
            stream = true,
            loop   = true,
        })

        -- Carrega sons do jogo
        audioSystem:loadSound("hoverCard", "audio/hoverCard.wav", Config.Audio.HOVER_VOLUME)
        audioSystem:loadSound("cardSelect", "audio/clickselect2-92097.mp3", Config.Audio.CLICK_SELECT_VOLUME)
        audioSystem:loadSound("deckStart", "audio/deckStart.mp3", Config.Audio.DECK_START_VOLUME)
        audioSystem:loadSound("swordSound", "audio/sword-sound-260274.mp3", 0.7)
        audioSystem:loadSound("armorSound", "audio/punching-light-armour-87442.mp3", 0.7)

        -- SFX gerados via ElevenLabs (audio/sfx/)
        audioSystem:loadSound("cardPlayAttack", "audio/sfx/card-play-attack.mp3", Config.Audio.CARD_PLAY_ATTACK_VOLUME)
        audioSystem:loadSound("cardPlayDefense", "audio/sfx/card-play-defense.mp3", Config.Audio.CARD_PLAY_DEFENSE_VOLUME)
        audioSystem:loadSound("cardDraw", "audio/sfx/card-draw.mp3", Config.Audio.CARD_DRAW_VOLUME)
        audioSystem:loadSound("cardExhaust", "audio/sfx/card-exhaust.mp3", Config.Audio.CARD_EXHAUST_VOLUME)
        audioSystem:loadSound("comboTrigger", "audio/sfx/combo-trigger.mp3", Config.Audio.COMBO_TRIGGER_VOLUME)
        audioSystem:loadSound("jokerActivate", "audio/sfx/joker-activate.mp3", Config.Audio.JOKER_ACTIVATE_VOLUME)
        audioSystem:loadSound("orbChannel", "audio/sfx/orb-channel.mp3", Config.Audio.ORB_CHANNEL_VOLUME)
        audioSystem:loadSound("orbEvoke", "audio/sfx/orb-evoke.mp3", Config.Audio.ORB_EVOKE_VOLUME)
        audioSystem:loadSound("debuffApplied", "audio/sfx/debuff-applied.mp3", Config.Audio.DEBUFF_APPLIED_VOLUME)
        audioSystem:loadSound("strengthGain", "audio/sfx/strength-gain.mp3", Config.Audio.STRENGTH_GAIN_VOLUME)
        audioSystem:loadSound("poisonTick", "audio/sfx/poison-tick.mp3", Config.Audio.POISON_TICK_VOLUME)
        audioSystem:loadSound("enemyAttack", "audio/sfx/enemy-attack.mp3", Config.Audio.ENEMY_ATTACK_VOLUME)
        audioSystem:loadSound("enemyDeath", "audio/sfx/enemy-death.mp3", Config.Audio.ENEMY_DEATH_VOLUME)
        audioSystem:loadSound("buttonClick", "audio/sfx/button-click.mp3", Config.Audio.BUTTON_CLICK_VOLUME)
        audioSystem:loadSound("menuOpen", "audio/sfx/menu-open.mp3", Config.Audio.MENU_OPEN_VOLUME)
        audioSystem:loadSound("menuClose", "audio/sfx/menu-close.mp3", Config.Audio.MENU_CLOSE_VOLUME)
        audioSystem:loadSound("menuHover", "audio/sfx/menu-hover.mp3", Config.Audio.MENU_HOVER_VOLUME)
        audioSystem:loadSound("collectionFlip", "audio/sfx/collection-flip.mp3", Config.Audio.COLLECTION_FLIP_VOLUME)
        audioSystem:loadSound("purchaseConfirm", "audio/sfx/purchase-confirm.mp3", Config.Audio.PURCHASE_CONFIRM_VOLUME)
        audioSystem:loadSound("purchaseDeny", "audio/sfx/purchase-deny.mp3", Config.Audio.PURCHASE_DENY_VOLUME)
        audioSystem:loadSound("battleVictory", "audio/sfx/battle-victory.mp3", Config.Audio.BATTLE_VICTORY_VOLUME)
        audioSystem:loadSound("goldGain", "audio/sfx/gold-gain.mp3", Config.Audio.GOLD_GAIN_VOLUME)
        audioSystem:loadSound("nodeSelect", "audio/sfx/node-select.mp3", Config.Audio.NODE_SELECT_VOLUME)
        audioSystem:loadSound("restComplete", "audio/sfx/rest-complete.mp3", Config.Audio.REST_COMPLETE_VOLUME)
        audioSystem:loadSound("actComplete", "audio/sfx/act-complete.mp3", Config.Audio.ACT_COMPLETE_VOLUME)
        audioSystem:loadSound("runVictory", "audio/sfx/run-victory.mp3", Config.Audio.RUN_VICTORY_VOLUME)
        audioSystem:loadSound("runDefeat", "audio/sfx/run-defeat.mp3", Config.Audio.RUN_DEFEAT_VOLUME)

        -- F11.4: SFX dedicados pra Round Eval / Pack Open / Shop (substituem
        -- usos repetidos de cardSelect/deckStart/purchaseConfirm).
        audioSystem:loadSound("coinClink",     "audio/sfx/coin-clink.mp3",       0.55)
        audioSystem:loadSound("coinTotalThud", "audio/sfx/coin-total-thud.mp3",  0.65)
        audioSystem:loadSound("cashOutChime",  "audio/sfx/cash-out-chime.mp3",   0.75)
        audioSystem:loadSound("packSealBreak", "audio/sfx/pack-seal-break.mp3",  0.70)
        audioSystem:loadSound("packCardReveal","audio/sfx/pack-card-reveal.mp3", 0.55)
        audioSystem:loadSound("packCardPick",  "audio/sfx/pack-card-pick.mp3",   0.65)
        audioSystem:loadSound("shopOpen",      "audio/sfx/shop-open.mp3",        0.65)
        audioSystem:loadSound("shopReroll",    "audio/sfx/shop-reroll.mp3",      0.60)

        -- v9.6: hover dos LUGARES do fork (WorldRoad) — som por lugar
        -- (v9.7: volumes reduzidos — feedback "estão muito altas")
        audioSystem:loadSound("forkHoverFire",  "audio/sfx/fork-hover-fire.mp3",  0.40)
        audioSystem:loadSound("forkHoverDoor",  "audio/sfx/fork-hover-door.mp3",  0.38)
        audioSystem:loadSound("forkHoverFlag",  "audio/sfx/fork-hover-flag.mp3",  0.36)
        audioSystem:loadSound("forkHoverElite", "audio/sfx/fork-hover-elite.mp3", 0.40)
        audioSystem:loadSound("forkHoverTent",  "audio/sfx/fork-hover-tent.mp3",  0.36)

        -- v9.7: CENÁRIO INTERATIVO (clique em árvore/poste/nuvem/grama etc)
        audioSystem:loadSound("sceneRustle",     "audio/sfx/scene-rustle.mp3",      0.34)
        audioSystem:loadSound("sceneWoodKnock",  "audio/sfx/scene-wood-knock.mp3",  0.36)
        audioSystem:loadSound("sceneLampCreak",  "audio/sfx/scene-lamp-creak.mp3",  0.34)
        audioSystem:loadSound("sceneLampWood",   "audio/sfx/scene-lamp-wood.mp3",   0.34)
        audioSystem:loadSound("sceneStoneThud",  "audio/sfx/scene-stone-thud.mp3",  0.36)
        audioSystem:loadSound("sceneGrassSwish", "audio/sfx/scene-grass-swish.mp3", 0.26)
        audioSystem:loadSound("sceneCloudPoof",  "audio/sfx/scene-cloud-poof.mp3",  0.32)

        -- v10: cerimônia de entrada no castelo (boss) — portão por material
        audioSystem:loadSound("castleGateOpen",  "audio/sfx/castle-gate-open.mp3",  0.62)
        audioSystem:loadSound("castleGateMagic", "audio/sfx/castle-gate-magic.mp3", 0.58)
    end
    
    -- Inicializa o menu
    menu = Menu:new()
    menu:setPlayCallback(function()
        print("Menu: Play button clicked, showing class selection...")
        Sfx.play("menuOpen")
        currentState = "classSelection"
        classSelectionScreen:show(
            function(classId) -- onClassSelected
                print("Main: Class selected: " .. tostring(classId))
                startGame(classId)
            end,
            function() -- onBackToMenu
                print("Main: Back to menu clicked")
                currentState = "menu"
                menu:show()
            end
        )
        menu:hide()
    end)
    -- CONTINUAR (F1 do UI Overhaul): retoma a run salva do disco.
    menu:setContinueCallback(function()
        Sfx.play("menuOpen")
        if not game.runManager:loadRun() then
            print("Continuar: nenhum save válido")
            menu:show()
            return
        end
        currentState = "playing"
        if FlashShader and FlashShader.trigger then FlashShader.trigger(0.5, 0.4) end
        game:resumeRun()
        gameUI:show()
        menu:hide()
        if smokeSystem then
            local act = math.min(3, (game.runManager.currentRun.actNumber or 1))
            SmokeConfig.applyToSystem(smokeSystem, "act" .. act)
        end
    end)
    menu:setCollectionCallback(function()
        Sfx.play("menuOpen")
        currentState = "collection"
        menu:hide()
        collectionScreen:show(function()
            Sfx.play("menuClose")
            currentState = "menu"
            menu:show()
        end)
    end)
    menu:setSettingsCallback(function()
        settingsMenu:toggle()
    end)
    menu:setAchievementsCallback(function()
        currentState = "achievements"
        menu:hide()
        achievementsScreen:show(function()
            currentState = "menu"
            menu:show()
        end)
    end)

    -- Inicializa a interface do jogo
    gameUI = GameUI:new()

    -- Inicializa o jogo primeiro (donos dos sistemas singleton: ShopSystem,
    -- EconomySystem, etc). Telas que dependem deles são criadas depois.
    game = Game:new()

    -- Inicializa tela de recompensas (recebe ShopSystem singleton do Game).
    cardRewardScreen = CardRewardScreen:new(game.shopSystem)

    -- Inicializa tela de seleção de classe
    classSelectionScreen = ClassSelectionScreen:new()

    -- Inicializa tela de coleção
    collectionScreen = CollectionScreen:new()

    -- Galeria de conquistas (F4 gameplay-overhaul)
    achievementsScreen = require("components.AchievementsScreen"):new()

    -- Inicializa overlay de configurações
    settingsMenu = SettingsMenu:new()
    deckViewerScreen = require("components.DeckViewerScreen"):new()
    _G.jokerManagerScreen = require("components.JokerManagerScreen"):new()
    -- Aberto pelo clique no painel de coringas (GameplayScene) OU tecla J.
    _G.toggleJokerManager = function()
        if _G.jokerManagerScreen then _G.jokerManagerScreen:toggle(game) end
    end

    -- Menu de PAUSA (engrenagem da TopBar, padrão StS): Continuar /
    -- Configurações / Salvar e voltar ao menu / Abandonar run (confirmado).
    pauseMenu = require("components.PauseMenu"):new()
    _G.togglePauseMenu = function()
        if pauseMenu:isVisible() then
            pauseMenu:hide()
            return
        end
        pauseMenu:show(game, {
            onOpenSettings = function()
                settingsMenu:show()
            end,
            onSaveQuit = function()
                -- Run ativa fica GUARDADA (save já acontece por nó; garante o
                -- snapshot mais recente antes de sair).
                if game.runManager and game.runManager.hasActiveRun
                    and game.runManager:hasActiveRun() then
                    game.runManager:saveRun()
                end
                returnToMenu()
            end,
            onAbandon = function()
                -- Abandono confirmado: apaga o save e encerra a run.
                if game.runManager then
                    game.runManager:deleteSave()
                end
                returnToMenu()
            end,
        })
    end

    -- Inicializa barra superior
    topBar = TopBar:new()

    -- F5 do UI Overhaul: clique no deck da TopBar abre o Deck Viewer.
    -- (Este wire vivia ANTES do TopBar:new() — topBar era nil e o callback
    -- nunca era registrado; clique no deck da barra não fazia nada.)
    topBar:setDeckClickCallback(function()
        deckViewerScreen:toggle(game)
    end)

    -- Inicializa tela de escolha de caminho (entre batalhas)
    mapScreen = MapScreen:new()

    -- Telas de no (Fase 6)
    restScreen = RestScreen:new()
    eventScreen = EventScreen:new()

    -- Pack opening cinemático (Fase 5 do refactor Balatro). Overlay sobre
    -- cardReward state — não é state próprio.
    packOpenScreen = PackOpenScreen:new()

    -- Round Eval / Cash Out screen (Fase 9 do refactor Balatro). State próprio
    -- "roundEval" entre playing → cardReward em modo run.
    roundEvalScreen = RoundEvalScreen:new()

    -- API global pra ser chamada pela CardRewardScreen quando jogador compra
    -- um booster pack. Padrão Balatro (UI_definitions.lua:1629+): a loja
    -- desliza pra fora da tela enquanto o pack toma o foco. Quando o pack
    -- fecha, a loja volta — sem backdrop preto sobreposto.
    _G.openBoosterPack = function(pack, onComplete)
        if not packOpenScreen or not packOpenScreen.show then return end

        -- 1) Loja sai de cena.
        if cardRewardScreen and cardRewardScreen.slideOut then
            cardRewardScreen:slideOut()
        end

        -- 2) Pack abre passando callback que faz slideIn + onComplete original.
        packOpenScreen:show(pack, function(selected)
            if cardRewardScreen and cardRewardScreen.slideIn then
                cardRewardScreen:slideIn()
            end
            if onComplete then onComplete(selected) end
        end)
    end

    -- Configura a barra superior com o jogo
    topBar:setGame(game)

    -- Wire: ícone de config na TopBar -> toggle do settingsMenu.
    -- TopBar chama game:toggleMenu() que chama game.onToggleSettings.
    game.onToggleSettings = function() settingsMenu:toggle() end

    -- Pós-processamento CRT (scanlines, wave, aberração cromática). Balatro-style.
    -- Settings → "CRT Shader" liga/desliga via CRTShader.toggle().
    CRTShader.load()
    -- Cursor pixel-art próprio (esconde o do SO; desenha no fim do draw,
    -- dentro da cena CRT — sofre o warp do tubo junto com o mundo)
    require("src.ui.CursorManager").load()
    if persistedSettings.crtShader == false then CRTShader.setEnabled(false) end
    -- Identidade CRT: o jogo ABRE como uma TV ligando — ponto → linha
    -- quente → a imagem abre revelando o splash (docs/plan/crt-identity-v1).
    CRTShader.setPower(0)
    CRTShader.powerOn(1.8)   -- v3.6: warm-up tem mais estágios (rolo de sync)

    -- MOUSE ATRAVÉS DO VIDRO: o domo do CRT desloca a imagem perto das
    -- bordas — sem isto, clique/hover perto do topo/base acertam ACIMA de
    -- onde o botão aparece (bug da Coleção). Patch global: todo mundo que
    -- lê love.mouse.getPosition/getX/getY enxerga coordenadas de CONTEÚDO,
    -- na mesma lente do shader. Com CRT desligado é passthrough.
    local rawGetPosition = love.mouse.getPosition
    love.mouse.getPosition = function()
        return CRTShader.screenToContent(rawGetPosition())
    end
    love.mouse.getX = function() return (love.mouse.getPosition()) end
    love.mouse.getY = function()
        local _, my = love.mouse.getPosition()
        return my
    end

    -- FX pipeline (shaders próprios, copyright-safe — Fase 2 do refactor Balatro).
    -- Dissolve: exhaust/destroy. Flash: impactos. Booster: pacotes selados.
    -- Foil/Polychrome/Negative: editions de carta (Fase 3).
    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()
    FoilShader.load()
    PolychromeShader.load()
    NegativeShader.load()

    -- Screen shake como sistema → registra _G.triggerShake pra back-compat.
    ScreenShake.install()
    
    -- Cria o botão de jogar cartas usando Config
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local buttonX = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_X_RATIO, love.graphics.getWidth()) - buttonWidth / 2
    local buttonY = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_Y_RATIO, love.graphics.getHeight()) - buttonHeight / 2
    
    playButton = Button:new(buttonX, buttonY, buttonWidth, buttonHeight, I18n.t("play_button.label"), function()
        if game.turn == "player" then
            game:playSelectedCards()
        end
    end, Theme.Colors.SUCCESS, 18)

    -- TURNO MULTI-JOGADA: jogar cartas não passa mais a vez — este botão sim.
    endTurnButton = Button:new(buttonX, buttonY + buttonHeight + 10,
        buttonWidth, math.floor(buttonHeight * 0.72),
        I18n.t("play_button.end_turn"), function()
        if game.turn == "player" then
            game:endTurn()
        end
    end, Theme.Colors.WARNING, 14)
    endTurnButton:setIcon("arrow_right")

    -- Atualiza texto dos botoes quando idioma mudar
    I18n.onLocaleChanged(function()
        if playButton and playButton.text ~= nil then
            playButton.text = I18n.t("play_button.label")
        end
        if endTurnButton and endTurnButton.text ~= nil then
            endTurnButton.text = I18n.t("play_button.end_turn")
        end
    end)
    
    -- Carrega o background do jogo uma vez
    gameBackground = BackgroundConfig.loadBackground("GAMEPLAY")
    
    -- Inicializa o sistema de smoke
    smokeSystem = SmokeSystem:new()
    
    -- Aplica configuração padrão (sutil)
    SmokeConfig.applyToSystem(smokeSystem, "default")
    
    -- Configura a janela
    love.window.setTitle(I18n.t("window_title"))

    -- Inicializa GameplayScene com deps. Callbacks mutam currentState aqui
    -- (state machine fica em main.lua; scene só sinaliza).
    GameplayScene.init({
        game          = game,
        playButton    = playButton,
        endTurnButton  = endTurnButton,
        topBar        = topBar,
        gameUI        = gameUI,
        smokeSystem   = smokeSystem,
        setCurrentState = function(name)
            -- Identidade CRT: morte/vitória = a TV DESLIGA (colapso em
            -- linha quente) e RELIGA já na tela final. Com CRT off nas
            -- Settings, powerOff/On viram corte seco (acessibilidade).
            if name == "gameOver" or name == "victory" then
                -- v3.6: colapso + ponto de fósforo apagando pedem fôlego
                CRTShader.powerOff(0.9, function()
                    currentState = name
                    CRTShader.powerOn(1.1)
                end)
            else
                currentState = name
            end
        end,
        onPhaseCleared  = function()
            if game:isInRunMode() then
                -- Run mode: passa por Round Eval (cash out) primeiro;
                -- ao Resgatar, cai em showCardRewards.
                showRoundEval()
            else
                game:nextPhase()
            end
        end,
        onReturnToMenu = function() returnToMenu() end,
    })

    -- Inicia BootScene (splash/loading). Quando termina, troca pra menu e
    -- dispara intro animado + música.
    BootScene.init({
        onComplete = function()
            currentState = "menu"
            menu:show()
            if menu.enterWithIntro then menu:enterWithIntro() end
        end,
    })

    -- Quickstart `love . play <classe>`: pula boot/menu e entra na batalha.
    if autoPlayClass then
        print("[quickstart] entrando direto na batalha com " .. autoPlayClass)
        startGame(autoPlayClass)
    end
end

-- updatePlayButtonPosition foi pra GameplayScene. Chamado aqui pra resize.
local function updatePlayButtonPosition() GameplayScene.updatePlayButtonPosition() end

function love.update(dt)
    -- Identidade CRT: animador do power (ligar/desligar da TV).
    CRTShader.update(dt)

    -- Cartas com ícone animado (icons_anim/): blita o frame corrente no
    -- canvas vivo de cada carta animada. Roda em TODOS os estados — mão,
    -- loja, coleção, deck viewer e menu animam pela mesma referência.
    CardFrame.update()

    -- TopBar precisa tickar em TODOS os estados onde é desenhada (loja,
    -- roundEval, rest, event, mapa) — o contador eased de ouro congelava
    -- fora do combate ("comprei e o ouro não mudou", playtest Jul/2026).
    if topBar and game then topBar:update(dt, game) end
    -- Infra global (antes do dispatch de estado): event queue, particles,
    -- flash fade, screen shake decay.
    EventManager.update(dt)
    FloatingText.update(dt)
    if audioSystem then audioSystem:update(dt) end
    CardParticles.update(dt)
    FlashShader.update(dt)
    ScreenShake.update(dt)

    -- Dispatch por estado.
    if currentState == "boot" then
        BootScene.update(dt)
    elseif currentState == "menu" then
        menu:update(dt)
    elseif currentState == "playing" then
        GameplayScene.update(dt)
    elseif currentState == "classSelection" then
        classSelectionScreen:update(dt)
    elseif currentState == "cardReward" then
        -- v9.7.1: o mundo continua VIVO atrás das ofertas (anims dos
        -- lugares, vento, nuvens — e o juice dos cliques no cenário)
        if game and game.isRunMode then
            require("src.ui.WorldRoad").update(dt)
        end
        cardRewardScreen:update(dt)
        if packOpenScreen and packOpenScreen:isVisible() then
            packOpenScreen:update(dt)
        end
    elseif currentState == "roundEval" then
        roundEvalScreen:update(dt)
    elseif currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            WorldRoad.update(dt)
        else
            mapScreen:update(dt)
        end
    elseif currentState == "rest" then
        restScreen:update(dt)
    elseif currentState == "event" then
        eventScreen:update(dt)
    elseif currentState == "collection" then
        collectionScreen:update(dt)
    elseif currentState == "achievements" then
        achievementsScreen:update(dt)
    end

    -- Overlay modal sempre atualiza (mesmo sobre outros states).
    if settingsMenu then settingsMenu:update(dt) end
    if pauseMenu then pauseMenu:update(dt) end
end

function love.draw()
    -- Abre a cena CRT: tudo que for desenhado até endScene() vai pro canvas
    -- de pós-processamento e depois é redesenhado com o shader aplicado.
    CRTShader.beginScene()

    -- Screen shake (sistema dedicado). Pair com .pop() no fim do love.draw.
    ScreenShake.push()

    if currentState == "boot" then
        BootScene.draw()
    elseif currentState == "menu" then
        menu:draw()
    elseif currentState == "classSelection" then
        classSelectionScreen:draw()
    elseif currentState == "playing" then
        GameplayScene.draw()
    elseif currentState == "cardReward" then
        GameplayScene.draw() -- Desenha o jogo por trás
        cardRewardScreen:draw() -- Overlay da recompensa
        -- Pack opening (Fase 5) é overlay SOBRE a loja — desenha por último.
        if packOpenScreen and packOpenScreen:isVisible() then
            packOpenScreen:draw()
        end
    elseif currentState == "roundEval" then
        GameplayScene.draw()       -- gameplay congelado por trás
        roundEvalScreen:draw()     -- overlay de cash out
    elseif currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            -- Encruzilhada: só o mundo (sem inimigo morto/mão/HUD de batalha)
            GameplayScene.drawWorldOnly()
        else
            GameplayScene.draw()
            mapScreen:draw()
        end
    elseif currentState == "rest" then
        GameplayScene.draw()
        restScreen:draw()
    elseif currentState == "event" then
        GameplayScene.draw()
        eventScreen:draw()
    elseif currentState == "collection" then
        collectionScreen:draw()
    elseif currentState == "achievements" then
        achievementsScreen:draw()
    elseif currentState == "gameOver" then
        EndScreens.drawGameOver(game)
    elseif currentState == "victory" then
        EndScreens.drawVictory(game)
    end

    -- HUD top bar SEMPRE visível em estados gameplay-adjacentes (Balatro pattern:
    -- moeda + deck count visíveis em loja, mapa, rest, event, roundEval).
    -- Desenhado APÓS overlays pra não ser dimmed pelos backdrops dessas telas.
    -- topBar:draw() já checa self.game e self.visible internamente.
    if topBar and (currentState == "playing"
                   or currentState == "cardReward"
                   or currentState == "roundEval"
                   or currentState == "mapSelection"
                   or currentState == "rest"
                   or currentState == "event") then
        topBar:draw()
    end

    -- Tooltips agendados durante topBar:draw() desenham AQUI, por cima da
    -- barra e no MESMO frame. StatusTooltip.draw() consome o agendamento —
    -- se o GameplayScene já desenhou o tooltip deste frame, isto é no-op.
    require("src.ui.StatusTooltip").draw()

    -- Partículas atachadas a cartas (dissolve/materialize/explode).
    -- Desenhadas APÓS as cartas mas DENTRO do shake + CRT scene, assim
    -- seguem o warp do pós-processamento.
    CardParticles.draw()

    -- Floating text (números de dano/cura/ouro). Acima das partículas, mas
    -- dentro do shake pra acompanhar o jiggle.
    FloatingText.draw()

    -- Flash overlay fullscreen (se FlashShader.trigger foi chamado).
    FlashShader.draw()

    ScreenShake.pop()

    -- Deck Viewer global (F5): overlay em qualquer tela da run
    if deckViewerScreen and deckViewerScreen:isVisible() then
        deckViewerScreen:draw()
    end

    -- Gerenciador de Coringas: overlay em qualquer tela da run
    if _G.jokerManagerScreen and _G.jokerManagerScreen:isVisible() then
        _G.jokerManagerScreen:draw()
    end

    -- Overlay de settings (modal) ainda DENTRO da cena CRT — assim o shader
    -- cobre o overlay também.
    if pauseMenu then pauseMenu:draw() end
    if settingsMenu then settingsMenu:draw() end

    -- Cursor pixel-art por cima de TUDO, mas dentro da cena CRT (warp do
    -- tubo pega o cursor também — coerência Balatro).
    require("src.ui.CursorManager").draw()

    CRTShader.endScene()
end

-- drawGame / drawJokersAsCards / updateCardPositions / updateGame /
-- handleGameMouse* foram extraídas pra src/scenes/GameplayScene.lua.
-- main.lua agora despacha diretamente via GameplayScene.*.

-- Reposiciona UI e invalida caches quando a janela muda (fullscreen, drag de borda).
-- LÖVE dispara isso sempre que window size muda; se esquecermos, buttons/layout
-- ficam congelados nas dimensões do boot.
function love.resize(w, h)
    FontManager.clearCache()
    -- Cada overlay/menu tem chance de recalcular layout. Padrão obrigatório:
    -- TODA tela com positions cacheadas (cardPositions, button rects, panel
    -- bounds) DEVE expor resize() ou updateLayout() e tratar o caso "ainda
    -- não visível" silenciosamente. Doc: memory/resize_pattern.md.
    if menu and menu.updatePositions then menu:updatePositions() end
    if classSelectionScreen and classSelectionScreen.updatePositions then
        classSelectionScreen:updatePositions()
    end
    if cardRewardScreen and cardRewardScreen.updateLayout then
        cardRewardScreen:updateLayout()
        -- Rebuild buttons pra refletir as novas cardPositions imediatamente
        -- (sem precisar esperar o detector de resize no update()).
        if #(cardRewardScreen.shopOffers or {}) > 0 then
            if cardRewardScreen.createCardInstances then cardRewardScreen:createCardInstances() end
            if cardRewardScreen.createOfferButtons then cardRewardScreen:createOfferButtons() end
        end
    end
    if packOpenScreen and packOpenScreen.resize then packOpenScreen:resize() end
    if restScreen and restScreen.resize then restScreen:resize() end
    if eventScreen and eventScreen.resize then eventScreen:resize() end
    if roundEvalScreen and roundEvalScreen.resize then roundEvalScreen:resize() end
    if collectionScreen and collectionScreen.resize then collectionScreen:resize() end
    if mapScreen and mapScreen.resize then mapScreen:resize() end
    if topBar and topBar.resize then topBar:resize() end
    if settingsMenu and settingsMenu.rebuild and settingsMenu.visible then
        settingsMenu:rebuild()
    end
    if pauseMenu and pauseMenu.resize then pauseMenu:resize() end
    GameplayScene.updatePlayButtonPosition()
end

function love.keypressed(key)
    -- Boot/splash: qualquer tecla pula direto pro menu.
    if currentState == "boot" then
        BootScene.keypressed(key)
        return
    end

    -- Settings overlay consome teclas primeiro (modal)
    if settingsMenu and settingsMenu.keypressed and settingsMenu:isVisible() then
        if settingsMenu:keypressed(key) then return end
    end

    -- Pause modal engole teclado enquanto aberto (ESC fecha/desarma confirmação).
    if pauseMenu and pauseMenu:isVisible() then
        if pauseMenu:keypressed(key) then return end
    end

    -- Deck Viewer global consome teclas enquanto aberto (D/ESC fecham)
    if deckViewerScreen and deckViewerScreen:isVisible() then
        if deckViewerScreen:keypressed(key) then return end
    end

    -- Gerenciador de Coringas consome teclas enquanto aberto (J/ESC fecham)
    if _G.jokerManagerScreen and _G.jokerManagerScreen:isVisible() then
        if _G.jokerManagerScreen:keypressed(key) then return end
    end

    -- Pack opening absorve teclas (escape fecha) enquanto visível.
    if packOpenScreen and packOpenScreen:isVisible() then
        if packOpenScreen:keypressed(key) then return end
    end

    -- F5: tecla D abre o deck da run em qualquer tela dela
    if key == "d" and (currentState == "playing"
        or currentState == "cardReward" or currentState == "mapSelection")
        and game and game.isRunMode then
        deckViewerScreen:toggle(game)
        return
    end

    -- Tecla J abre o Gerenciador de Coringas em qualquer tela da run
    if key == "j" and (currentState == "playing"
        or currentState == "cardReward" or currentState == "mapSelection")
        and game and game.isRunMode then
        _G.jokerManagerScreen:toggle(game)
        return
    end

    -- Round Eval absorve teclas (enter/space = Resgatar) enquanto visível.
    if roundEvalScreen and roundEvalScreen:isVisible() then
        if roundEvalScreen:keypressed(key) then return end
    end

    -- Collection absorve teclas quando visível
    if currentState == "achievements" then
        achievementsScreen:keypressed(key)
        return
    end
    if currentState == "collection" then
        if collectionScreen.keypressed then collectionScreen:keypressed(key) end
        if key == "escape" then
            currentState = "menu"
            collectionScreen:hide()
            menu:show()
            if menu.enterWithIntro then menu:enterWithIntro() end
        end
        return
    end

    if currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            -- atalhos 1-3 escolhem o braço (usa o centro da hitbox do marco)
            local n = tonumber(key)
            local f = WorldRoad._fork
            if n and f and f.markBoxes and f.markBoxes[n] then
                local b = f.markBoxes[n]
                WorldRoad.forkMousePressed((b.x1 + b.x2) / 2, (b.y1 + b.y2) / 2)
            end
            -- ESC em estado de run: abre o MENU DE PAUSA (sair/salvar/abandonar
            -- são decisões dele — ESC direto pro menu descartava sem perguntar).
            if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
            return
        end
        if mapScreen:keypressed(key) then return end
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        return
    end

    if currentState == "event" then
        if eventScreen:keypressed(key) then return end
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        return
    end

    if currentState == "rest" then
        if restScreen:keypressed(key) then return end
        if key == "escape" and _G.togglePauseMenu then _G.togglePauseMenu() end
        return
    end

    if currentState == "menu" then
        -- Teclas do menu
        if key == "escape" then
            love.event.quit()
        end
    elseif currentState == "playing" then
        -- ESC no combate: pause (não mais menu direto — a run é preciosa).
        if key == "escape" then
            if _G.togglePauseMenu then _G.togglePauseMenu() end
            return
        end
        GameplayScene.keypressed(key)
    elseif currentState == "gameOver" then
        -- Teclas do game over
        if key == "r" then
            startGame()
        elseif key == "escape" then
            returnToMenu()
        end
    elseif currentState == "victory" then
        -- Teclas da vitória
        if key == "space" then
            startGame()
        elseif key == "escape" then
            returnToMenu()
        end
    end
end

function love.mousereleased(x, y, button)
    x, y = CRTShader.screenToContent(x, y)
    -- Deck Viewer global consome mouse enquanto aberto
    if deckViewerScreen and deckViewerScreen:isVisible() then
        deckViewerScreen:mousereleased(x, y, button)
        return
    end

    -- Gerenciador de Coringas consome mouse enquanto aberto
    if _G.jokerManagerScreen and _G.jokerManagerScreen:isVisible() then
        _G.jokerManagerScreen:mousereleased(x, y, button)
        return
    end

    -- Settings modal consome primeiro
    if settingsMenu and settingsMenu:isVisible() then
        if settingsMenu:mousereleased(x, y, button) then return end
    end

    if pauseMenu and pauseMenu:isVisible() then
        if pauseMenu:mousereleased(x, y, button) then return end
    end

    if currentState == "menu" then
        menu:mousereleased(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousereleased(x, y, button)
    elseif currentState == "playing" then
        GameplayScene.mousereleased(x, y, button)
    elseif currentState == "cardReward" then
        if packOpenScreen and packOpenScreen:isVisible() then
            if packOpenScreen:mousereleased(x, y, button) then return end
        end
        cardRewardScreen:mousereleased(x, y, button)
    elseif currentState == "roundEval" then
        roundEvalScreen:mousereleased(x, y, button)
    elseif currentState == "mapSelection" then
        mapScreen:mousereleased(x, y, button)
    elseif currentState == "rest" then
        restScreen:mousereleased(x, y, button)
    elseif currentState == "event" then
        eventScreen:mousereleased(x, y, button)
    elseif currentState == "collection" then
        if collectionScreen.mousereleased then collectionScreen:mousereleased(x, y, button) end
    elseif currentState == "achievements" then
        achievementsScreen:mousereleased(x, y, button)
    end
end

function love.mousepressed(x, y, button)
    x, y = CRTShader.screenToContent(x, y)
    -- Boot/splash: clique pula direto pro menu.
    if currentState == "boot" then
        BootScene.mousepressed(x, y, button)
        return
    end

    -- Settings modal consome primeiro
    if settingsMenu and settingsMenu:isVisible() then
        if settingsMenu:mousepressed(x, y, button) then return end
    end

    -- Pause modal consome tudo enquanto aberto
    if pauseMenu and pauseMenu:isVisible() then
        if pauseMenu:mousepressed(x, y, button) then return end
    end

    -- Deck Viewer global consome mouse enquanto aberto
    if deckViewerScreen and deckViewerScreen:isVisible() then
        deckViewerScreen:mousepressed(x, y, button)
        return
    end

    -- Gerenciador de Coringas consome mouse enquanto aberto
    if _G.jokerManagerScreen and _G.jokerManagerScreen:isVisible() then
        _G.jokerManagerScreen:mousepressed(x, y, button)
        return
    end

    -- TopBar consome cliques na faixa superior (engrenagem/deck) em todos os
    -- estados onde é desenhada. (Nunca era roteada — o clique da engrenagem
    -- não funcionava em lugar NENHUM; bug playtest Jul/2026.)
    local topBarStates = {
        playing = true, cardReward = true, roundEval = true,
        mapSelection = true, rest = true, event = true,
    }
    if topBar and topBarStates[currentState] and y <= (topBar.height or 52) then
        if topBar:mousepressed(x, y, button) then return end
    end

    if currentState == "menu" then
        menu:mousepressed(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousepressed(x, y, button)
    elseif currentState == "playing" then
        -- v9.7.1: clique que NENHUM elemento de gameplay consumiu cutuca
        -- o cenário (mapa vivo estilo Hearthstone — árvore/poste/nuvem)
        if not GameplayScene.mousepressed(x, y, button) and button == 1 then
            require("src.ui.WorldRoad").pokeSceneAt(x, y)
        end
    elseif currentState == "cardReward" then
        -- Pack overlay tem prioridade — consome cliques se visível.
        if packOpenScreen and packOpenScreen:isVisible() then
            if packOpenScreen:mousepressed(x, y, button) then return end
        end
        if not cardRewardScreen:mousepressed(x, y, button) and button == 1 then
            -- v9.7.1: clique fora das ofertas cutuca o cenário atrás
            require("src.ui.WorldRoad").pokeSceneAt(x, y)
        end
    elseif currentState == "roundEval" then
        roundEvalScreen:mousepressed(x, y, button)
    elseif currentState == "mapSelection" then
        local WorldRoad = require("src.ui.WorldRoad")
        if WorldRoad.isForkActive() then
            WorldRoad.forkMousePressed(x, y)
        else
            mapScreen:mousepressed(x, y, button)
        end
    elseif currentState == "rest" then
        restScreen:mousepressed(x, y, button)
    elseif currentState == "event" then
        eventScreen:mousepressed(x, y, button)
    elseif currentState == "collection" then
        collectionScreen:mousepressed(x, y, button)
    elseif currentState == "achievements" then
        achievementsScreen:mousepressed(x, y, button)
    end
end

function love.wheelmoved(dx, dy)
    if deckViewerScreen and deckViewerScreen:isVisible() then
        deckViewerScreen:wheelmoved(dx, dy)
        return
    end
    if _G.jokerManagerScreen and _G.jokerManagerScreen:isVisible() then
        _G.jokerManagerScreen:wheelmoved(dx, dy)
        return
    end
    if currentState == "collection" and collectionScreen.wheelmoved then
        collectionScreen:wheelmoved(dx, dy)
    end
end

function love.mousemoved(x, y, dx, dy)
    x, y = CRTShader.screenToContent(x, y)
    if currentState == "playing" then
        GameplayScene.mousemoved(x, y, dx, dy)
    elseif currentState == "collection" and collectionScreen.mousemoved then
        collectionScreen:mousemoved(x, y, dx, dy)
    end
end

-- handleGameMousePressed / handleGameMouseReleased foram pra GameplayScene.