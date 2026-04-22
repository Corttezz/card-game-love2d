local Game = require("src.core.Game")
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
local AudioSystem = require("src.systems.AudioSystem")
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
local CardParticles = require("src.systems.CardParticles")
local ScreenShake = require("src.systems.ScreenShake")
local EndScreens = require("src.scenes.EndScreens")
local GameplayScene = require("src.scenes.GameplayScene")

local game
local menu
local gameUI
local cardRewardScreen
local classSelectionScreen
local collectionScreen
local settingsMenu
local topBar
local mapScreen
local restScreen
local eventScreen
-- hoverCard agora é state interno da GameplayScene
local playButton
local currentState = "menu" -- menu, classSelection, playing, gameOver, victory, cardReward, collection, mapSelection

-- Screen shake agora vive em src/systems/ScreenShake.lua.
-- _G.triggerShake é registrado em love.load via ScreenShake.install() pra
-- manter back-compat com sistemas que já usam.
local gameBackground -- Cache da imagem de background
local smokeSystem -- Sistema de partículas de smoke
local audioSystem -- Sistema de áudio

-- Função para iniciar o jogo com classe selecionada
local function startGame(classId)
    currentState = "playing"

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
    game = Game:new() -- Reseta o jogo
    gameUI:hide()
    menu:show()
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
        local ev = Events.roll(game.runManager.currentRun.actNumber or 1)
        if not ev then
            -- Sem evento disponivel: age como batalha comum
            currentState = "playing"
            game:nextPhase()
            return
        end
        currentState = "event"
        eventScreen:show(ev, game, function()
            skipBattleAndShowMap()
        end)

    elseif t == BT.SHOP then
        -- Reusa CardRewardScreen como shop. Atualmente ela ja oferece compra
        -- com gold via ShopSystem.
        mapScreen:hide()
        currentState = "cardReward"
        cardRewardScreen:show(game,
            function(offer)
                print("Shop: comprou", offer.name)
            end,
            function()
                skipBattleAndShowMap()
            end
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
    mapScreen:show(pending, onNodeChosen, "Escolha o proximo caminho")
    currentState = "mapSelection"
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

-- Função para mostrar recompensas de cartas após vitória
local function showCardRewards()
    currentState = "cardReward"

    -- enemyDeath ja tocou em Game:processCardInCombat no instante da morte.
    -- Tocar aqui novamente causava o som duplicado.
    Sfx.play("battleVictory")

    -- Usa a nova interface de loja integrada
    cardRewardScreen:show(game,
        function(offer) -- onCardPurchased
            print("Card purchased:", offer.name)
        end,
        function() -- onSkipped
            continueAfterReward()
        end
    )
end

function love.load(loveArgs)
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

    -- Validacao do catalogo de cartas (Fase 7).
    --   love . validate_cards
    if loveArgs and loveArgs[1] == "validate_cards" then
        local ok = require("tools.validate_cards").run()
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
        local ok = okT and okE and okC and okM and okA and okD
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

    -- Inicializa o sistema de áudio primeiro
    audioSystem = AudioSystem:new()
    audioSystem:printStatus()
    
    -- Torna o sistema de áudio global para outros módulos
    _G.audioSystem = audioSystem

    -- Fila de eventos temporais (engine/EventManager). Sistemas podem
    -- agendar sequências via _G.EventManager.addEvent{...} sem passar ctx.
    _G.EventManager = EventManager
    _G.Event = Event
    
    -- Carrega música de fundo e sons se áudio estiver disponível
    if audioSystem:isAudioAvailable() then
        -- Música de fundo desativada temporariamente — reativar descomentando as 2 linhas:
        -- audioSystem:loadBackgroundMusic("audio/music.mp3")
        -- audioSystem:playBackgroundMusic()

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

    -- Inicializa a interface do jogo
    gameUI = GameUI:new()

    -- Inicializa tela de recompensas
    cardRewardScreen = CardRewardScreen:new()

    -- Inicializa tela de seleção de classe
    classSelectionScreen = ClassSelectionScreen:new()

    -- Inicializa tela de coleção
    collectionScreen = CollectionScreen:new()

    -- Inicializa overlay de configurações
    settingsMenu = SettingsMenu:new()

    -- Inicializa barra superior
    topBar = TopBar:new()

    -- Inicializa tela de escolha de caminho (entre batalhas)
    mapScreen = MapScreen:new()

    -- Telas de no (Fase 6)
    restScreen = RestScreen:new()
    eventScreen = EventScreen:new()

    -- Inicializa o jogo (mas não inicia ainda)
    game = Game:new()

    -- Configura a barra superior com o jogo
    topBar:setGame(game)

    -- Wire: ícone de config na TopBar -> toggle do settingsMenu.
    -- TopBar chama game:toggleMenu() que chama game.onToggleSettings.
    game.onToggleSettings = function() settingsMenu:toggle() end

    -- Pós-processamento CRT (scanlines, wave, aberração cromática). Balatro-style.
    -- Settings → "CRT Shader" liga/desliga via CRTShader.toggle().
    CRTShader.load()

    -- FX pipeline portado do Balatro (ver memory/card_fx_pipeline.md):
    -- Dissolve para exhaust/destroy, Flash pra impactos, Booster pra seals.
    DissolveShader.load()
    FlashShader.load()
    BoosterShader.load()

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
    -- Atualiza texto do botao quando idioma mudar
    I18n.onLocaleChanged(function()
        if playButton and playButton.text ~= nil then
            playButton.text = I18n.t("play_button.label")
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
        topBar        = topBar,
        gameUI        = gameUI,
        smokeSystem   = smokeSystem,
        setCurrentState = function(name) currentState = name end,
        onPhaseCleared  = function()
            if game:isInRunMode() then
                showCardRewards()
            else
                game:nextPhase()
            end
        end,
        onReturnToMenu = function() returnToMenu() end,
    })
end

-- updatePlayButtonPosition foi pra GameplayScene. Chamado aqui pra resize.
local function updatePlayButtonPosition() GameplayScene.updatePlayButtonPosition() end

function love.update(dt)
    -- Infra global (antes do dispatch de estado): event queue, particles,
    -- flash fade, screen shake decay.
    EventManager.update(dt)
    CardParticles.update(dt)
    FlashShader.update(dt)
    ScreenShake.update(dt)

    -- Dispatch por estado.
    if currentState == "menu" then
        menu:update(dt)
    elseif currentState == "playing" then
        GameplayScene.update(dt)
    elseif currentState == "classSelection" then
        classSelectionScreen:update(dt)
    elseif currentState == "cardReward" then
        cardRewardScreen:update(dt)
    elseif currentState == "mapSelection" then
        mapScreen:update(dt)
    elseif currentState == "rest" then
        restScreen:update(dt)
    elseif currentState == "event" then
        eventScreen:update(dt)
    elseif currentState == "collection" then
        collectionScreen:update(dt)
    end

    -- Overlay modal sempre atualiza (mesmo sobre outros states).
    if settingsMenu then settingsMenu:update(dt) end
end

function love.draw()
    -- Abre a cena CRT: tudo que for desenhado até endScene() vai pro canvas
    -- de pós-processamento e depois é redesenhado com o shader aplicado.
    CRTShader.beginScene()

    -- Screen shake (sistema dedicado). Pair com .pop() no fim do love.draw.
    ScreenShake.push()

    if currentState == "menu" then
        menu:draw()
    elseif currentState == "classSelection" then
        classSelectionScreen:draw()
    elseif currentState == "playing" then
        GameplayScene.draw()
    elseif currentState == "cardReward" then
        GameplayScene.draw() -- Desenha o jogo por trás
        cardRewardScreen:draw() -- Overlay da recompensa
    elseif currentState == "mapSelection" then
        GameplayScene.draw()
        mapScreen:draw()
    elseif currentState == "rest" then
        GameplayScene.draw()
        restScreen:draw()
    elseif currentState == "event" then
        GameplayScene.draw()
        eventScreen:draw()
    elseif currentState == "collection" then
        collectionScreen:draw()
    elseif currentState == "gameOver" then
        EndScreens.drawGameOver(game)
    elseif currentState == "victory" then
        EndScreens.drawVictory(game)
    end

    -- Partículas atachadas a cartas (dissolve/materialize/explode).
    -- Desenhadas APÓS as cartas mas DENTRO do shake + CRT scene, assim
    -- seguem o warp do pós-processamento.
    CardParticles.draw()

    -- Flash overlay fullscreen (se FlashShader.trigger foi chamado).
    FlashShader.draw()

    ScreenShake.pop()

    -- Overlay de settings (modal) ainda DENTRO da cena CRT — assim o shader
    -- cobre o overlay também.
    if settingsMenu then settingsMenu:draw() end

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
    if menu and menu.updatePositions then menu:updatePositions() end
    if classSelectionScreen and classSelectionScreen.updatePositions then
        classSelectionScreen:updatePositions()
    end
    if cardRewardScreen and cardRewardScreen.updateLayout then
        cardRewardScreen:updateLayout()
    end
    if mapScreen and mapScreen.resize then mapScreen:resize() end
    if topBar and topBar.resize then topBar:resize() end
    if settingsMenu and settingsMenu.rebuild and settingsMenu.visible then
        settingsMenu:rebuild()
    end
    GameplayScene.updatePlayButtonPosition()
end

function love.keypressed(key)
    -- Settings overlay consome teclas primeiro (modal)
    if settingsMenu and settingsMenu.keypressed and settingsMenu:isVisible() then
        if settingsMenu:keypressed(key) then return end
    end

    -- Collection absorve teclas quando visível
    if currentState == "collection" then
        if collectionScreen.keypressed then collectionScreen:keypressed(key) end
        if key == "escape" then
            currentState = "menu"
            collectionScreen:hide()
            menu:show()
        end
        return
    end

    if currentState == "mapSelection" then
        if mapScreen:keypressed(key) then return end
        if key == "escape" then returnToMenu() end
        return
    end

    if currentState == "event" then
        if eventScreen:keypressed(key) then return end
        if key == "escape" then returnToMenu() end
        return
    end

    if currentState == "rest" then
        if restScreen:keypressed(key) then return end
        if key == "escape" then returnToMenu() end
        return
    end

    if currentState == "menu" then
        -- Teclas do menu
        if key == "escape" then
            love.event.quit()
        end
    elseif currentState == "playing" then
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
    -- Settings modal consome primeiro
    if settingsMenu and settingsMenu:isVisible() then
        if settingsMenu:mousereleased(x, y, button) then return end
    end

    if currentState == "menu" then
        menu:mousereleased(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousereleased(x, y, button)
    elseif currentState == "playing" then
        GameplayScene.mousereleased(x, y, button)
    elseif currentState == "cardReward" then
        cardRewardScreen:mousereleased(x, y, button)
    elseif currentState == "mapSelection" then
        mapScreen:mousereleased(x, y, button)
    elseif currentState == "rest" then
        restScreen:mousereleased(x, y, button)
    elseif currentState == "event" then
        eventScreen:mousereleased(x, y, button)
    elseif currentState == "collection" then
        if collectionScreen.mousereleased then collectionScreen:mousereleased(x, y, button) end
    end
end

function love.mousepressed(x, y, button)
    -- Settings modal consome primeiro
    if settingsMenu and settingsMenu:isVisible() then
        if settingsMenu:mousepressed(x, y, button) then return end
    end

    if currentState == "menu" then
        menu:mousepressed(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousepressed(x, y, button)
    elseif currentState == "playing" then
        GameplayScene.mousepressed(x, y, button)
    elseif currentState == "cardReward" then
        cardRewardScreen:mousepressed(x, y, button)
    elseif currentState == "mapSelection" then
        mapScreen:mousepressed(x, y, button)
    elseif currentState == "rest" then
        restScreen:mousepressed(x, y, button)
    elseif currentState == "event" then
        eventScreen:mousepressed(x, y, button)
    elseif currentState == "collection" then
        collectionScreen:mousepressed(x, y, button)
    end
end

function love.wheelmoved(dx, dy)
    if currentState == "collection" and collectionScreen.wheelmoved then
        collectionScreen:wheelmoved(dx, dy)
    end
end

function love.mousemoved(x, y, dx, dy)
    if currentState == "playing" then
        GameplayScene.mousemoved(x, y, dx, dy)
    elseif currentState == "collection" and collectionScreen.mousemoved then
        collectionScreen:mousemoved(x, y, dx, dy)
    end
end

-- handleGameMousePressed / handleGameMouseReleased foram pra GameplayScene.