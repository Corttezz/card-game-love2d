-- src/scenes/GameplayScene.lua
-- Scene do estado "playing": draw/update/input do combate + mão + jokers.
-- Extraído de main.lua (era ~400 LOC de drawGame/updateGame/handlers).
--
-- ARQUITETURA: recebe deps externas (game, playButton, topBar, gameUI, smokeSystem)
-- via init() — armazenadas no módulo. hoverCard é state interno da scene.
--
-- Pode sinalizar transições de estado via callback deps.setCurrentState(name)
-- passado por main.lua (evita acoplar state machine aqui).

local Config           = require("src.core.Config")
local FontManager      = require("src.ui.FontManager")
local SceneLayer       = require("src.ui.SceneLayer")
local EnemyRenderer    = require("src.ui.EnemyRenderer")
local EnemyHud         = require("src.ui.EnemyHud")
local ParticleSystem   = require("src.systems.ParticleSystem")
local Sfx              = require("src.systems.Sfx")
local SmokeConfig      = require("src.config.SmokeConfig")

local GameplayScene = {}

-- Refs externas (setadas em init)
local game, playButton, topBar, gameUI, smokeSystem
local setCurrentState, onPhaseCleared, onReturnToMenu
-- State interno
local hoverCard = nil

function GameplayScene.init(deps)
    game           = deps.game
    playButton     = deps.playButton
    topBar         = deps.topBar
    gameUI         = deps.gameUI
    smokeSystem    = deps.smokeSystem
    setCurrentState = deps.setCurrentState or function() end
    onPhaseCleared = deps.onPhaseCleared  or function() end
    onReturnToMenu = deps.onReturnToMenu  or function() end
end

-- Seta smokeSystem depois de init (usado quando smoke muda em runtime).
function GameplayScene.setSmokeSystem(s) smokeSystem = s end

-- ============================================================================
-- INTERNAL: posicionamento
-- ============================================================================

local function updatePlayButtonPosition()
    if not playButton then return end
    local buttonWidth  = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local buttonX = (love.graphics.getWidth() - buttonWidth) / 1.05
    local buttonY = love.graphics.getHeight() * 0.72
    playButton:setPosition(buttonX, buttonY)
    playButton.width = buttonWidth
    playButton.height = buttonHeight
end
GameplayScene.updatePlayButtonPosition = updatePlayButtonPosition

local function updateCardPositions()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local cardSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width")
    local currentHandSize = #game.hand
    local totalCardsWidth = cardSpacing * math.max(0, currentHandSize - 1)
    local cardStartX = (width - totalCardsWidth) / 2
    local cardY = height * 0.8

    for i, card in ipairs(game.hand) do
        card.x = card.renderX ~= 0 and card.renderX or (cardStartX + (i - 1) * cardSpacing)
        card.y = card.renderY ~= 0 and card.renderY or cardY
    end
end

-- ============================================================================
-- DRAW
-- ============================================================================

local function drawJokersAsCards()
    local width = love.graphics.getWidth()

    local jokerSpacing    = Config.Utils.getResponsiveSize(0.15, 150, "width")
    local jokerY          = Config.Utils.getResponsiveSize(0.08, 80, "height")
    local totalJokersWidth = jokerSpacing * math.max(0, #game.jokerSlots - 1)
    local jokerStartX = (width - totalJokersWidth) / 2

    for i, joker in ipairs(game.jokerSlots) do
        if joker then
            local mx, my = love.mouse.getPosition()
            local cardWidth = joker:getWidth()
            local cardHeight = joker:getHeight()
            local isHovered = mx >= jokerStartX + (i - 1) * jokerSpacing and
                              mx <= jokerStartX + (i - 1) * jokerSpacing + cardWidth and
                              my >= jokerY and my <= jokerY + cardHeight
            joker:updateMouse(mx, my, love.timer.getDelta(), isHovered)

            local originalScale = joker.currentScale
            joker.currentScale = originalScale * Config.Cards.JOKER_SLOT_SCALE
            joker:draw(jokerStartX + (i - 1) * jokerSpacing, jokerY)
            joker.currentScale = originalScale
        end
    end

    -- Sistema de combate desenha por cima
    game.combatAnimationSystem:draw()

    -- Partículas globais (burst de combate, joker ativado)
    if ParticleSystem and ParticleSystem.Manager then
        ParticleSystem.Manager:draw()
    end

    -- Tooltips (status effects / buffs) por cima de tudo
    require("src.ui.StatusTooltip").draw()
end

function GameplayScene.draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local topBarHeight = topBar.height or 80

    -- Cenário em camadas (BG_FAR + BG_MID + FG_PROPS) com parallax
    local currentAct = 1
    if game and game.runManager and game.runManager.currentRun then
        currentAct = game.runManager.currentRun.actNumber or 1
    end
    SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)

    topBar:draw()

    -- Inimigo como sprite + HP bar ancorada
    local enemyCx = math.floor(width / 2)
    local enemyCy = math.floor(height * 0.68)
    local enemyBbox = EnemyRenderer.draw(game, enemyCx, enemyCy)
    EnemyHud.draw(game, enemyBbox, enemyCx, enemyCy)

    gameUI:draw(game)

    -- Layout da mão (drag + reorder + slot animado)
    local cardSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width")
    local currentHandSize = #game.hand
    local totalCardsWidth = cardSpacing * math.max(0, currentHandSize - 1)
    local cardStartX = (width - totalCardsWidth) / 2
    local cardY = height * 0.8

    local draggingCard, draggingIdx
    for i, card in ipairs(game.hand) do
        if card.isDragging then
            draggingCard = card
            draggingIdx = i
            break
        end
    end

    local dropIdx = draggingCard and (function()
        local mx = love.mouse.getX()
        if currentHandSize <= 1 then return 1 end
        local rawIdx = 1 + math.floor((mx - cardStartX + cardSpacing / 2) / cardSpacing)
        return math.max(1, math.min(currentHandSize, rawIdx))
    end)() or nil

    local function renderIdxFor(i)
        if not draggingCard then return i end
        if i == draggingIdx then return i end
        if draggingIdx < dropIdx then
            if i > draggingIdx and i <= dropIdx then return i - 1 end
        else
            if i >= dropIdx and i < draggingIdx then return i + 1 end
        end
        return i
    end

    local dt = love.timer.getDelta()
    for i, card in ipairs(game.hand) do
        local offsetY = 0
        if game:isCardSelected(card) then offsetY = -100 end
        local rIdx = renderIdxFor(i)
        local tx = cardStartX + (rIdx - 1) * cardSpacing
        local ty = cardY + offsetY
        if card == hoverCard and not draggingCard then
            ty = cardY - 130
        end
        if card.isDragging then
            local mx, my = love.mouse.getPosition()
            card:setRenderPos(mx + card.dragOffsetX, my + card.dragOffsetY)
        else
            card:setTargetPos(tx, ty)
            card:updateRender(dt)
        end
    end

    -- Desenha não-dragadas (ordem normal), depois hover, depois dragged por cima
    for _, card in ipairs(game.hand) do
        if not card.isDragging and card ~= hoverCard then
            local canPlay = game:canPlayCard(card)
            card:draw(card.renderX, card.renderY, canPlay)
        end
    end
    if hoverCard and not hoverCard.isDragging then
        love.graphics.setColor(1, 1, 1, 1)
        local canPlay = game:canPlayCard(hoverCard)
        hoverCard:draw(hoverCard.renderX, hoverCard.renderY, canPlay)
    end
    if draggingCard then
        love.graphics.setColor(1, 1, 1, 1)
        local savedScale = draggingCard.targetScale
        draggingCard.targetScale = draggingCard.baseScale + Config.Cards.DRAG_SCALE_BOOST
        local canPlay = game:canPlayCard(draggingCard)
        draggingCard:draw(draggingCard.renderX, draggingCard.renderY, canPlay)
        draggingCard.targetScale = savedScale
    end

    if smokeSystem then smokeSystem:draw() end
    playButton:draw()
    if game.messageSystem then game.messageSystem:draw() end

    drawJokersAsCards()
end

-- ============================================================================
-- UPDATE
-- ============================================================================

function GameplayScene.update(dt)
    updatePlayButtonPosition()

    game.combatAnimationSystem:update(dt)

    if ParticleSystem and ParticleSystem.Manager then
        ParticleSystem.Manager:update(dt)
    end

    EnemyRenderer.update(dt)
    SceneLayer.update(dt)

    -- Transições de estado (game over / victory). Retorna true se mudou
    -- (caller deve fazer early return pra não rodar resto do frame).
    if game:checkGameOver() and not game.combatAnimationSystem:isBlocking() then
        Sfx.play("runDefeat")
        setCurrentState("gameOver")
        return
    end

    if game:checkVictory() and not game.combatAnimationSystem:isBlocking() then
        Sfx.play("runVictory")
        setCurrentState("victory")
        return
    end

    if game._deathPauseTimer and game._deathPauseTimer > 0 then
        game._deathPauseTimer = math.max(0, game._deathPauseTimer - dt)
    end

    if game:isPhaseCleared() and not game.combatAnimationSystem:isBlocking()
       and (not game._deathPauseTimer or game._deathPauseTimer <= 0) then
        onPhaseCleared()
        return
    end

    if game.turn == "enemy" and not game.combatAnimationSystem:isBlocking()
       and game.enemy:isAlive() then
        game:enemyTurn()
    end

    if smokeSystem then smokeSystem:update(dt) end

    updateCardPositions()

    -- Hover tracking: carta sob mouse vira hoverCard; suprime hover em outras
    -- se qualquer uma está sendo arrastada.
    local mx, my = love.mouse.getPosition()
    hoverCard = nil
    local anyDragging = false
    for _, card in ipairs(game.hand) do
        if card.isDragging then anyDragging = true; break end
    end
    for i, card in ipairs(game.hand) do
        card.index = i
        local allowHover = (not anyDragging) and (hoverCard == nil)
        card:updateMouse(mx, my, dt, allowHover)
        if card.isHovered then hoverCard = card end
    end

    playButton:update(dt)
    gameUI:update(dt, game)
    topBar:update(dt, game)

    if game.messageSystem then game.messageSystem:update(dt) end
    if game.enemy then game.enemy:update(dt) end
end

-- ============================================================================
-- INPUT
-- ============================================================================

function GameplayScene.mousepressed(x, y, button)
    if topBar:mousepressed(x, y, button) then return end

    if button == 1 then
        local buttonWidth  = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
        local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
        local buttonX = (love.graphics.getWidth() - buttonWidth) / 1.05
        local buttonY = love.graphics.getHeight() * 0.72

        if game.turn == "player"
           and x >= buttonX and x <= buttonX + buttonWidth
           and y >= buttonY and y <= buttonY + buttonHeight then
            game:playSelectedCards()
            return
        end

        -- Drag-pending em cartas hovered (select vs reorder resolve em release)
        for _, card in ipairs(game.hand) do
            if card.isHovered then
                card.dragPending = true
                card.dragStartMX = x
                card.dragStartMY = y
                card.dragOffsetX = card.x - x
                card.dragOffsetY = card.y - y
            end
        end
    end
end

-- Calcula drop-index baseado na posição X do mouse
local function computeHandDropIndex(mx, handSize)
    if handSize <= 1 then return 1 end
    local cardSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width")
    local totalW = cardSpacing * (handSize - 1)
    local cardStartX = (love.graphics.getWidth() - totalW) / 2
    local rawIdx = 1 + math.floor((mx - cardStartX + cardSpacing / 2) / cardSpacing)
    return math.max(1, math.min(handSize, rawIdx))
end

function GameplayScene.mousereleased(x, y, button)
    if topBar:mousereleased(x, y, button) then return end

    if button == 1 then
        playButton:mousereleased(x, y, button)

        local reorderedCard, fromIdx
        for i, card in ipairs(game.hand) do
            if card.isDragging then
                reorderedCard = card
                fromIdx = i
                break
            end
        end

        if reorderedCard then
            local dropIdx = computeHandDropIndex(x, #game.hand)
            if dropIdx ~= fromIdx then
                table.remove(game.hand, fromIdx)
                table.insert(game.hand, dropIdx, reorderedCard)
                Sfx.play("cardSelect")
            end
        else
            for _, card in ipairs(game.hand) do
                if card.dragPending and card.isHovered then
                    game:selectCard(card)
                end
            end
        end

        for _, card in ipairs(game.hand) do
            card.dragPending = false
            card.isDragging = false
        end
    end
end

function GameplayScene.mousemoved(x, y, dx, dy)
    local threshold = Config.Cards.DRAG_THRESHOLD_PX
    for _, card in ipairs(game.hand) do
        if card.dragPending and not card.isDragging then
            local distX = x - card.dragStartMX
            local distY = y - card.dragStartMY
            if (distX * distX + distY * distY) > (threshold * threshold) then
                card.isDragging = true
            end
        end
    end
end

function GameplayScene.keypressed(key)
    if key == "r" then
        game:startGame()
    elseif key == "f" then
        local fullscreen = not love.window.getFullscreen()
        love.window.setFullscreen(fullscreen)
        FontManager.clearCache()
    elseif key == "1" then
        SmokeConfig.applyToSystem(smokeSystem, "subtle")
    elseif key == "2" then
        SmokeConfig.applyToSystem(smokeSystem, "default")
    elseif key == "3" then
        SmokeConfig.applyToSystem(smokeSystem, "atmospheric")
    elseif key == "4" then
        SmokeConfig.applyToSystem(smokeSystem, "intense")
    elseif key == "0" then
        if smokeSystem then smokeSystem:clear() end
    elseif key == "escape" then
        onReturnToMenu()
    end
end

return GameplayScene
