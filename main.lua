local Game = require("src.core.Game")
local Button = require("components.Button")
local Menu = require("components.Menu")
local GameUI = require("components.GameUI")
local CardRewardScreen = require("components.CardRewardScreen")
local ClassSelectionScreen = require("components.ClassSelectionScreen")
local TopBar = require("components.TopBar")
local Config = require("src.core.Config")
local FontManager = require("src.ui.FontManager")
local Theme = require("src.ui.Theme")
local BackgroundConfig = require("src.core.BackgroundConfig")
local SmokeSystem = require("src.systems.SmokeSystem")
local SmokeConfig = require("src.config.SmokeConfig")
local AudioSystem = require("src.systems.AudioSystem")

local game
local menu
local gameUI
local cardRewardScreen
local classSelectionScreen
local topBar
local hoverCard = nil -- Armazena a carta que está em hover
local playButton
local currentState = "menu" -- menu, classSelection, playing, gameOver, victory, cardReward
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
end

-- Função para voltar ao menu
local function returnToMenu()
    currentState = "menu"
    game = Game:new() -- Reseta o jogo
    gameUI:hide()
    menu:show()
end

-- Continua o jogo após escolher/pular recompensa
local function continueAfterReward()
    currentState = "playing"
    
    -- Verifica se deve ir para próxima fase ou terminar corrida
    if game.currentPhase >= Config.Game.VICTORY_PHASES then
        -- Termina corrida com vitória
        local finalStats = game:endCurrentRun(true)
        currentState = "victory"
    else
        -- Vai para próxima fase
        game:nextPhase()
    end
end

-- Função para mostrar recompensas de cartas após vitória
local function showCardRewards()
    currentState = "cardReward"
    
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

function love.load()
    -- Inicializa o sistema de áudio primeiro
    audioSystem = AudioSystem:new()
    audioSystem:printStatus()
    
    -- Torna o sistema de áudio global para outros módulos
    _G.audioSystem = audioSystem
    
    -- Carrega música de fundo e sons se áudio estiver disponível
    if audioSystem:isAudioAvailable() then
        audioSystem:loadBackgroundMusic("audio/music.mp3")
        audioSystem:playBackgroundMusic()
        
        -- Carrega sons do jogo
        audioSystem:loadSound("hoverCard", "audio/hoverCard.wav", Config.Audio.HOVER_VOLUME)
        audioSystem:loadSound("cardSelect", "audio/clickselect2-92097.mp3", Config.Audio.CLICK_SELECT_VOLUME)
        audioSystem:loadSound("deckStart", "audio/deckStart.mp3", Config.Audio.DECK_START_VOLUME)
        audioSystem:loadSound("swordSound", "audio/sword-sound-260274.mp3", 0.7)
        audioSystem:loadSound("armorSound", "audio/punching-light-armour-87442.mp3", 0.7)
    end
    
    -- Inicializa o menu
    menu = Menu:new()
    menu:setPlayCallback(function()
        print("Menu: Play button clicked, showing class selection...")
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
    
    -- Inicializa a interface do jogo
    gameUI = GameUI:new()
    
    -- Inicializa tela de recompensas
    cardRewardScreen = CardRewardScreen:new()
    
    -- Inicializa tela de seleção de classe
    classSelectionScreen = ClassSelectionScreen:new()
    
    -- Inicializa barra superior
    topBar = TopBar:new()
    
    -- Inicializa o jogo (mas não inicia ainda)
    game = Game:new()
    
    -- Configura a barra superior com o jogo
    topBar:setGame(game)
    
    -- Cria o botão de jogar cartas usando Config
    local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local buttonX = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_X_RATIO, love.graphics.getWidth()) - buttonWidth / 2
    local buttonY = Config.Utils.getRelativePosition(Config.UI.PLAY_BUTTON_Y_RATIO, love.graphics.getHeight()) - buttonHeight / 2
    
    playButton = Button:new(buttonX, buttonY, buttonWidth, buttonHeight, "Jogar Cartas", function()
        if game.turn == "player" then
            game:playSelectedCards()
        end
    end, Theme.Colors.SUCCESS, 18)
    
    -- Carrega o background do jogo uma vez
    gameBackground = BackgroundConfig.loadBackground("GAMEPLAY")
    
    -- Inicializa o sistema de smoke
    smokeSystem = SmokeSystem:new()
    
    -- Aplica configuração padrão (sutil)
    SmokeConfig.applyToSystem(smokeSystem, "default")
    
    -- Configura a janela
    love.window.setTitle("Card Game - Um jogo de cartas estratégico")
end

function updatePlayButtonPosition()
    -- Atualiza posição do botão "Jogar Cartas" para ficar bem abaixo das cartas
    if playButton then
        local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
        local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
        local buttonX = (love.graphics.getWidth() - buttonWidth) / 1.05 -- Centralizado horizontalmente
        local buttonY = love.graphics.getHeight() * 0.72 -- 92% da altura, bem abaixo das cartas
        
        playButton:setPosition(buttonX, buttonY)
        playButton.width = buttonWidth
        playButton.height = buttonHeight
    end
end

function love.draw()
    if currentState == "menu" then
        menu:draw()
    elseif currentState == "classSelection" then
        classSelectionScreen:draw()
    elseif currentState == "playing" then
        drawGame()
    elseif currentState == "cardReward" then
        drawGame() -- Desenha o jogo por trás
        cardRewardScreen:draw() -- Overlay da recompensa
    elseif currentState == "gameOver" then
        drawGameOver()
    elseif currentState == "victory" then
        drawVictory()
    end
end

function drawGame()
    -- Background do jogo com imagem step1.png
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Usa o sistema de backgrounds configurável
    local bgConfig = BackgroundConfig.getConfig("GAMEPLAY")
    if gameBackground and bgConfig then
        -- Empurra o background para baixo considerando a barra superior
        local topBarHeight = topBar.height or 80
        BackgroundConfig.drawBackground(gameBackground, bgConfig, width, height - topBarHeight, 0, topBarHeight)
    else
        -- Fallback: gradiente original se a imagem não carregar
        local topBarHeight = topBar.height or 80
        local bgColors = Theme.Gradients.BACKGROUND_MAIN(0, topBarHeight, width, height - topBarHeight)
        Theme.Utils.drawVerticalGradient(0, topBarHeight, width, height - topBarHeight, bgColors)
    end
    
    -- Desenha a barra superior
    topBar:draw()
    
    -- Desenha a interface do jogo
    gameUI:draw(game)
    
    -- Desenha as cartas na mão (posicionamento centralizado e bem abaixo dos jokers)
    local cardSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width")
    local currentHandSize = #game.hand
    local totalCardsWidth = cardSpacing * math.max(0, currentHandSize - 1)
    local cardStartX = (width - totalCardsWidth) / 2
    local cardY = height * 0.8 -- Posiciona as cartas bem abaixo para não interferir com os jokers
    
    for i, card in ipairs(game.hand) do
        local offsetY = 0
        if game:isCardSelected(card) then
            offsetY = -50 -- Carta selecionada sobe mais
        end
        if card ~= hoverCard then
            -- Verifica se a carta pode ser jogada para mostrar borda azul
            local canPlay = game:canPlayCard(card)
            card:draw(cardStartX + (i - 1) * cardSpacing, cardY + offsetY, canPlay)
        end
    end

    -- Desenha a carta em hover por cima
    if hoverCard then
        love.graphics.setColor(1, 1, 1, 1)
        local hoverY = cardY - 80 -- Carta em hover sobe muito mais
        -- Verifica se a carta em hover pode ser jogada
        local canPlay = game:canPlayCard(hoverCard)
        hoverCard:draw(cardStartX + (hoverCard.index - 1) * cardSpacing, hoverY, canPlay)
    end

    -- Desenha o sistema de smoke (antes das cartas para ficar atrás)
    if smokeSystem then
        smokeSystem:draw()
    end
    
    -- Desenha o botão de jogar cartas
    playButton:draw()
    
    -- Desenha o sistema de mensagens
    if game.messageSystem then
        game.messageSystem:draw()
    end
    
    -- Desenha os jokers como cartas na parte superior
    drawJokersAsCards()
end

-- Desenha os jokers como cartas na parte superior (Balatro style)
function drawJokersAsCards()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Título dos jokers
    -- local titleFont = FontManager.getResponsiveFont(0.03, 24, "height")
    -- local titleText = "JOKERS ATIVOS"
    -- local titleWidth = titleFont:getWidth(titleText)
    -- local titleX = (width - titleWidth) / 2
    -- local titleY = Config.Utils.getResponsiveSize(0.02, 20, "height")
    
    -- love.graphics.setColor(1, 0.8, 0.2, 1)
    -- love.graphics.setFont(titleFont)
    -- love.graphics.print(titleText, titleX, titleY)
    
    -- Posiciona os jokers como cartas na parte superior
    local jokerSpacing = Config.Utils.getResponsiveSize(0.15, 150, "width")
    local jokerY = Config.Utils.getResponsiveSize(0.08, 80, "height")
    local totalJokersWidth = jokerSpacing * math.max(0, #game.jokerSlots - 1)
    local jokerStartX = (width - totalJokersWidth) / 2
    
    -- Desenha cada joker como uma carta
    for i, joker in ipairs(game.jokerSlots) do
        if joker then
            -- Atualiza hover do joker
            local mx, my = love.mouse.getPosition()
            local cardWidth = joker:getWidth()
            local cardHeight = joker:getHeight()
            local isHovered = mx >= jokerStartX + (i - 1) * jokerSpacing and 
                             mx <= jokerStartX + (i - 1) * jokerSpacing + cardWidth and
                             my >= jokerY and my <= jokerY + cardHeight
            
            joker:updateMouse(mx, my, love.timer.getDelta(), isHovered)
            
            -- Aplica escala específica para slots ativos
            local originalScale = joker.currentScale
            joker.currentScale = originalScale * Config.Cards.JOKER_SLOT_SCALE
            
            -- Desenha o joker
            joker:draw(jokerStartX + (i - 1) * jokerSpacing, jokerY)
            
            -- Restaura escala original
            joker.currentScale = originalScale
        end
    end
    
    -- Sistema de animação de combate (desenha por cima de tudo)
    game.combatAnimationSystem:draw()
end

function drawGameOver()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Background com gradiente escuro
    local bgColors = {
        {0.3, 0.1, 0.1, 1},
        {0.2, 0.05, 0.05, 1},
        {0.15, 0.02, 0.02, 1}
    }
    Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    
    local centerX = width / 2
    local centerY = height / 2
    
    -- Título
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 48)
    love.graphics.setFont(titleFont)
    local title = "GAME OVER"
    local titleWidth = titleFont:getWidth(title)
    
    love.graphics.setColor(Theme.Colors.ERROR)
    love.graphics.print(title, centerX - titleWidth / 2, centerY - height * 0.167)
    
    -- Pontuação final
    local scoreFont = FontManager.getResponsiveFont(Config.UI.SCORE_FONT_RATIO, 24)
    love.graphics.setFont(scoreFont)
    local scoreText = "Pontuação Final: " .. game.score
    local scoreWidth = scoreFont:getWidth(scoreText)
    
    love.graphics.setColor(Theme.Colors.TEXT_PRIMARY)
    love.graphics.print(scoreText, centerX - scoreWidth / 2, centerY - height * 0.083)
    
    -- Instruções
    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 18)
    love.graphics.setFont(instructionFont)
    local instruction = "Pressione R para tentar novamente ou ESC para voltar ao menu"
    local instructionWidth = instructionFont:getWidth(instruction)
    
    love.graphics.setColor(Theme.Colors.TEXT_SECONDARY)
    love.graphics.print(instruction, centerX - instructionWidth / 2, centerY + height * 0.083)
    
    -- Reseta fonte
    love.graphics.setFont(love.graphics.newFont())
end

function drawVictory()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Background com gradiente de vitória
    local bgColors = {
        {0.1, 0.3, 0.1, 1},
        {0.05, 0.2, 0.05, 1},
        {0.02, 0.15, 0.02, 1}
    }
    Theme.Utils.drawVerticalGradient(0, 0, width, height, bgColors)
    
    local centerX = width / 2
    local centerY = height / 2
    
    -- Título
    local titleFont = FontManager.getResponsiveFont(Config.UI.TITLE_FONT_RATIO, 48)
    love.graphics.setFont(titleFont)
    local title = "VITÓRIA!"
    local titleWidth = titleFont:getWidth(title)
    
    love.graphics.setColor(Theme.Colors.SUCCESS)
    love.graphics.print(title, centerX - titleWidth / 2, centerY - height * 0.167)
    
    -- Pontuação final
    local scoreFont = FontManager.getResponsiveFont(Config.UI.SCORE_FONT_RATIO, 24)
    love.graphics.setFont(scoreFont)
    local scoreText = "Pontuação Final: " .. game.score
    local scoreWidth = scoreFont:getWidth(scoreText)
    
    love.graphics.setColor(Theme.Colors.TEXT_PRIMARY)
    love.graphics.print(scoreText, centerX - scoreWidth / 2, centerY - height * 0.083)
    
    -- Instruções
    local instructionFont = FontManager.getResponsiveFont(Config.UI.INSTRUCTION_FONT_RATIO, 18)
    love.graphics.setFont(instructionFont)
    local instruction = "Pressione ESPAÇO para jogar novamente ou ESC para voltar ao menu"
    local instructionWidth = instructionFont:getWidth(instruction)
    
    love.graphics.setColor(Theme.Colors.TEXT_SECONDARY)
    love.graphics.print(instruction, centerX - instructionWidth / 2, centerY + height * 0.083)
    
    -- Reseta fonte
    love.graphics.setFont(love.graphics.newFont())
end

function love.update(dt)
    if currentState == "menu" then
        menu:update(dt)
    elseif currentState == "playing" then
        updateGame(dt)
    elseif currentState == "classSelection" then
        classSelectionScreen:update(dt)
    elseif currentState == "cardReward" then
        cardRewardScreen:update(dt)
    end
end

function updateCardPositions()
    -- Atualiza as posições das cartas para centralização dinâmica
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local cardSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width")
    local currentHandSize = #game.hand
    local totalCardsWidth = cardSpacing * math.max(0, currentHandSize - 1)
    local cardStartX = (width - totalCardsWidth) / 2
    local cardY = height * 0.8
    
    for i, card in ipairs(game.hand) do
        card.x = cardStartX + (i - 1) * cardSpacing
        card.y = cardY
    end
end

function updateGame(dt)
    -- Atualiza posição do botão "Jogar Cartas"
    updatePlayButtonPosition()
    
    -- Atualiza sistema de animação de combate
    game.combatAnimationSystem:update(dt)
    
    -- Verifica game over (apenas se não estiver em animação de combate)
    if game:checkGameOver() and not game.combatAnimationSystem:isBlocking() then
        currentState = "gameOver"
        return
    end
    
    -- Verifica vitória (apenas se não estiver em animação de combate)
    if game:checkVictory() and not game.combatAnimationSystem:isBlocking() then
        currentState = "victory"
        return
    end

    -- Verifica vitória na fase (apenas se não estiver em animação de combate)
    if game:isPhaseCleared() and not game.combatAnimationSystem:isBlocking() then
        -- Se estiver no modo corrida, mostra recompensas
        if game:isInRunMode() then
            showCardRewards()
        else
            -- Modo clássico: vai direto para próxima fase
            game:nextPhase()
        end
    end

    -- Atualiza turno do inimigo (apenas se não estiver em animação de combate)
    if game.turn == "enemy" and not game.combatAnimationSystem:isBlocking() then
        game:enemyTurn()
    end

    -- Atualiza o sistema de smoke
    if smokeSystem then
        smokeSystem:update(dt)
    end

    -- Atualiza posições das cartas para centralização correta
    updateCardPositions()
    
    -- Atualiza posição do mouse e hover das cartas
    local mx, my = love.mouse.getPosition()
    hoverCard = nil

    for i, card in ipairs(game.hand) do
        card.index = i
        card:updateMouse(mx, my, dt, hoverCard == nil)
        if card.isHovered then
            hoverCard = card
        end
    end

    -- Atualiza botão e interface
    playButton:update(dt)
    gameUI:update(dt)
    topBar:update(dt)
    
    -- Atualiza sistema de mensagens
    if game.messageSystem then
        game.messageSystem:update(dt)
    end
    
    -- Atualiza inimigo
    if game.enemy then
        game.enemy:update(dt)
    end
end

function love.keypressed(key)
    if currentState == "menu" then
        -- Teclas do menu
        if key == "escape" then
            love.event.quit()
        end
    elseif currentState == "playing" then
        -- Teclas do jogo
        if key == "space" then
            game:drawCard()
            -- Usa o sistema de áudio para tocar som de hover
            if audioSystem then
                audioSystem:playSound("hoverCard")
            end
        elseif key == "r" then
            game:startGame()
        elseif key == "f" then
            -- Alterna entre fullscreen e janela
            local fullscreen = not love.window.getFullscreen()
            love.window.setFullscreen(fullscreen)
            -- Limpa cache de fontes ao mudar resolução
            FontManager.clearCache()
        elseif key == "1" then
            -- Configuração de smoke sutil
            SmokeConfig.applyToSystem(smokeSystem, "subtle")
        elseif key == "2" then
            -- Configuração de smoke padrão
            SmokeConfig.applyToSystem(smokeSystem, "default")
        elseif key == "3" then
            -- Configuração de smoke atmosférico
            SmokeConfig.applyToSystem(smokeSystem, "atmospheric")
        elseif key == "4" then
            -- Configuração de smoke intenso
            SmokeConfig.applyToSystem(smokeSystem, "intense")
        elseif key == "0" then
            -- Desliga o sistema de smoke
            if smokeSystem then
                smokeSystem:clear()
            end
        elseif key == "escape" then
            returnToMenu()
        end
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
    if currentState == "menu" then
        menu:mousereleased(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousereleased(x, y, button)
    elseif currentState == "playing" then
        handleGameMouseReleased(x, y, button)
    elseif currentState == "cardReward" then
        cardRewardScreen:mousereleased(x, y, button)
    end
end

function love.mousepressed(x, y, button)
    if currentState == "menu" then
        menu:mousepressed(x, y, button)
    elseif currentState == "classSelection" then
        classSelectionScreen:mousepressed(x, y, button)
    elseif currentState == "playing" then
        handleGameMousePressed(x, y, button)
    elseif currentState == "cardReward" then
        cardRewardScreen:mousepressed(x, y, button)
    end
end

function handleGameMousePressed(x, y, button)
    -- Verifica clique na barra superior primeiro
    if topBar:mousepressed(x, y, button) then
        return
    end
    
    if button == 1 then
        -- Verifica clique no botão de voltar ao menu
        -- if gameUI:isBackToMenuClicked(x, y) then
        --     returnToMenu()
        --     return
        -- end
        
        -- Verifica clique no botão "Jogar Cartas"
        local buttonWidth = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
        local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
        local buttonX = (love.graphics.getWidth() - buttonWidth) / 1.05 -- Centralizado horizontalmente
        local buttonY = love.graphics.getHeight() * 0.72 -- 72% da altura
        
        if game.turn == "player" and x >= buttonX and x <= buttonX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
            game:playSelectedCards()
            return
        end

        -- Seleciona/desseleciona cartas
        for _, card in ipairs(game.hand) do
            if card.isHovered then
                game:selectCard(card)
            end
        end
    end
end

function handleGameMouseReleased(x, y, button)
    -- Verifica clique na barra superior primeiro
    if topBar:mousereleased(x, y, button) then
        return
    end
    
    if button == 1 then
        playButton:mousereleased(x, y, button)
    end
end