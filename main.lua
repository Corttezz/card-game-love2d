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
local settingsMenu
local topBar
local mapScreen
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
    game = Game:new() -- Reseta o jogo (cria novo ShopSystem com pools resetados)
    if cardRewardScreen then cardRewardScreen.shopSystem = game.shopSystem end
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

    -- Screenshot tool: round eval / cash out (Fase 9). Phase 0..3.
    --   love . screenshot_round_eval 3
    if loveArgs and loveArgs[1] == "screenshot_round_eval" then
        require("tools.screenshot_round_eval").run(loveArgs[2])
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
        local okU = require("tools.smoke_upgrades").run()
        local okS = require("tools.smoke_shop").run()
        local okP = require("tools.smoke_packs").run()
        local ok = okT and okE and okC and okM and okA and okD and okU and okS and okP
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

    -- Inicializa o jogo primeiro (donos dos sistemas singleton: ShopSystem,
    -- EconomySystem, etc). Telas que dependem deles são criadas depois.
    game = Game:new()

    -- Inicializa tela de recompensas (recebe ShopSystem singleton do Game).
    cardRewardScreen = CardRewardScreen:new(game.shopSystem)

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
    if persistedSettings.crtShader == false then CRTShader.setEnabled(false) end

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
end

-- updatePlayButtonPosition foi pra GameplayScene. Chamado aqui pra resize.
local function updatePlayButtonPosition() GameplayScene.updatePlayButtonPosition() end

function love.update(dt)
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
        cardRewardScreen:update(dt)
        if packOpenScreen and packOpenScreen:isVisible() then
            packOpenScreen:update(dt)
        end
    elseif currentState == "roundEval" then
        roundEvalScreen:update(dt)
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

    -- Pack opening absorve teclas (escape fecha) enquanto visível.
    if packOpenScreen and packOpenScreen:isVisible() then
        if packOpenScreen:keypressed(key) then return end
    end

    -- Round Eval absorve teclas (enter/space = Resgatar) enquanto visível.
    if roundEvalScreen and roundEvalScreen:isVisible() then
        if roundEvalScreen:keypressed(key) then return end
    end

    -- Collection absorve teclas quando visível
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
    end
end

function love.mousepressed(x, y, button)
    -- Boot/splash: clique pula direto pro menu.
    if currentState == "boot" then
        BootScene.mousepressed(x, y, button)
        return
    end

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
        -- Pack overlay tem prioridade — consome cliques se visível.
        if packOpenScreen and packOpenScreen:isVisible() then
            if packOpenScreen:mousepressed(x, y, button) then return end
        end
        cardRewardScreen:mousepressed(x, y, button)
    elseif currentState == "roundEval" then
        roundEvalScreen:mousepressed(x, y, button)
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