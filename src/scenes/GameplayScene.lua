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
local SceneBackground  = require("src.ui.SceneBackground")
local InteriorFX       = require("src.ui.InteriorFX")
local WorldRoad        = require("src.ui.WorldRoad")
local EnemyRenderer    = require("src.ui.EnemyRenderer")
local EnemyHud         = require("src.ui.EnemyHud")
local TurnBanner       = require("src.ui.TurnBanner")
local Sfx              = require("src.systems.Sfx")
local SmokeConfig      = require("src.config.SmokeConfig")

local GameplayScene = {}

-- Modo de cenário: "worldroad" (mundo rolante, estilo Path of Kings) ou
-- "scene" (SceneLayer com PNG estático por ato — comportamento antigo).
GameplayScene.SCENE_MODE = "worldroad"

-- Refs externas (setadas em init)
local game, playButton, endTurnButton, topBar, gameUI, smokeSystem
local setCurrentState, onPhaseCleared, onReturnToMenu
-- State interno
local hoverCard = nil
local lastFloorKey = nil   -- detecta troca de andar → dispara viagem na estrada
local lastInterior = nil   -- detecta estrada→interior → fade de entrada
local interiorFade = 0     -- alpha do fade preto (1 → 0 em ~0.9s)

function GameplayScene.init(deps)
    game           = deps.game
    playButton     = deps.playButton
    endTurnButton  = deps.endTurnButton
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
    if endTurnButton then
        endTurnButton:setPosition(buttonX, buttonY + buttonHeight + 8)
        endTurnButton.width = buttonWidth
        endTurnButton.height = math.floor(buttonHeight * 0.72)
    end
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
        local layoutX = cardStartX + (i - 1) * cardSpacing
        -- Posição "home" estática: usada pelo bbox de hover (não acompanha o
        -- lift visual de hoverCard pra cardY-130, evitando flicker bistável).
        card.layoutX = layoutX
        card.layoutY = cardY
        card.x = card.renderX ~= 0 and card.renderX or layoutX
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

    -- Partículas (burst de combate, joker, card-attached) são desenhadas
    -- centralmente em main.lua via CardParticles.draw() no fim do frame.
    -- Não chamar daqui — geraria double-draw.

    -- Tooltips (status effects / buffs) por cima de tudo
    require("src.ui.StatusTooltip").draw()
end

-- v5 (Encruzilhada): desenha SÓ o mundo (estrada + fork), sem inimigo, HUD
-- ou mão — usado pelo estado mapSelection quando a escolha acontece in-world.
function GameplayScene.drawWorldOnly()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local topBarHeight = topBar.height or 80
    local currentAct = 1
    local run = game and game.runManager and game.runManager.currentRun
    if run then currentAct = run.actNumber or 1 end
    local biomeIdx = currentAct
    if run and run.endlessMode then
        biomeIdx = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
    end
    WorldRoad.draw(0, topBarHeight, width, height - topBarHeight, biomeIdx)
    -- LightEngine v1: luz + fork overlay (marks/pills DEPOIS do composite —
    -- este é o caminho do estado mapSelection, onde o fork está ativo)
    WorldRoad.drawOverlays(0, topBarHeight, width, height - topBarHeight)
end

function GameplayScene.draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local topBarHeight = topBar.height or 80

    -- Cenário em camadas (BG_FAR + BG_MID + FG_PROPS) com parallax
    local currentAct = 1
    local run = game and game.runManager and game.runManager.currentRun
    if run then currentAct = run.actNumber or 1 end

    -- PROGRESSÃO DE CENÁRIO (feedback Jul/2026): batalha comum acontece na
    -- ESTRADA (mundo-esfera); boss/mini_boss/elite acontecem DENTRO do
    -- castelo (interior PixelLab por ato) — chegou no marco, entrou.
    local nodeType = run and run.currentNode and run.currentNode.type
    local interior = GameplayScene.SCENE_MODE == "worldroad"
        and (nodeType == "boss" or nodeType == "mini_boss" or nodeType == "elite")

    -- v9.2: no battle da estrada, o inimigo desenha DENTRO do painter do
    -- WorldRoad (no eixo BATTLE_REL) pra que postes/árvores mais próximos
    -- que ele fiquem NA FRENTE. Registra antes do draw; o painter chama e
    -- captura o bbox (usado pelo HUD). traveling/interior seguem o fluxo
    -- antigo (inimigo é billboard ou hall estático).
    local traveling = GameplayScene.SCENE_MODE == "worldroad"
        and not interior and WorldRoad.isTraveling()
    local worldBattle = GameplayScene.SCENE_MODE == "worldroad"
        and not interior and not traveling
    local enemyBbox, enemyCx, enemyCy
    if worldBattle then
        enemyCx, enemyCy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarHeight, width, height - topBarHeight)
        WorldRoad.setBattleEnemyDraw(function()
            enemyBbox = EnemyRenderer.draw(game, enemyCx, enemyCy)
        end, enemyCy)
    end

    if interior then
        local hallAct = math.min(3, currentAct)
        local drawn = SceneBackground.draw("castle_hall_" .. hallAct,
            width, height, 0.15)
        if not drawn then
            -- interior ainda não gerado: cai pro SceneLayer do ato
            SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)
        else
            -- tochas/brasas vivas do hall (glow pulsante + partículas)
            InteriorFX.draw(hallAct)
        end
    elseif GameplayScene.SCENE_MODE == "worldroad" then
        -- Endless: biomas extras (4+) ciclam a cada 8 andares via currentFloor
        local biomeIdx = currentAct
        if run and run.endlessMode then
            biomeIdx = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
        end
        WorldRoad.draw(0, topBarHeight, width, height - topBarHeight, biomeIdx)
    else
        SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)
    end

    topBar:draw()

    -- Inimigo: no battle da estrada já foi desenhado DENTRO do WorldRoad.draw
    -- (callback no eixo BATTLE_REL — props próximos na frente dele). Aqui só
    -- os outros casos: interior (hall estático) e SceneLayer legado. Na
    -- viagem o inimigo é billboard do WorldRoad (não desenha aqui).
    if not traveling and not worldBattle then
        enemyCx = math.floor(width / 2)
        enemyCy = math.floor(height * 0.68)
        enemyBbox = EnemyRenderer.draw(game, enemyCx, enemyCy)
    end

    -- LightEngine v1: composite multiply do lightmap sobre mundo+inimigo,
    -- ANTES de qualquer UI (EnemyHud/gameUI/mão ficam fora da luz). O fork
    -- overlay (pills) vem junto, DEPOIS do composite (revisão F-10).
    if GameplayScene.SCENE_MODE == "worldroad" and not interior then
        WorldRoad.drawOverlays(0, topBarHeight, width, height - topBarHeight)
    end

    if not traveling then
        EnemyHud.draw(game, enemyBbox, enemyCx, enemyCy)
    end

    gameUI:draw(game)

    -- Banner de turno (por cima do HUD, por baixo da mão/tooltips)
    TurnBanner.draw()

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

    -- v7.4.14: fumaça ambiente SÓ nos interiores de castelo — na ESTRADA
    -- aberta os fiapos translúcidos gigantes (escala 2×, cruzando a tela)
    -- liam como "3 linhas subindo e descendo" (feedback; o demo não roda
    -- smoke e ficava bom; CRT on/off não mudava = era isto). Véu
    -- translúcido sobre a cena pixel art é anti-pattern do projeto.
    local roadOutdoor = GameplayScene.SCENE_MODE == "worldroad"
        and not lastInterior
    if smokeSystem and not roadOutdoor then smokeSystem:draw() end
    playButton:draw()
    if endTurnButton then endTurnButton:draw() end

    -- Chamariz do ENCERRAR TURNO (sem mana e nada selecionado): aro dourado
    -- pulsante + seta quicando — "sua próxima ação é aqui".
    if GameplayScene._endTurnCallout and endTurnButton then
        local t = love.timer.getTime()
        local pulse = 0.5 + 0.5 * math.sin(t * 4.2)
        love.graphics.setColor(1, 0.85, 0.30, 0.35 + 0.45 * pulse)
        love.graphics.setLineWidth(2 + pulse * 2)
        love.graphics.rectangle("line", endTurnButton.x - 4, endTurnButton.y - 4,
            endTurnButton.width + 8, endTurnButton.height + 8, 8, 8)
        -- seta quicando apontando pro botão
        local ax = endTurnButton.x - 18 - pulse * 6
        local ay = endTurnButton.y + endTurnButton.height / 2
        love.graphics.setColor(1, 0.85, 0.30, 0.9)
        love.graphics.polygon("fill", ax, ay - 8, ax, ay + 8, ax + 12, ay)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
    if game.messageSystem then game.messageSystem:draw() end

    drawJokersAsCards()

    -- fade de entrada no castelo (estrada→interior): tela revela do preto
    if interiorFade > 0 then
        local a = interiorFade * interiorFade   -- ease-out (rápido no fim)
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ============================================================================
-- UPDATE
-- ============================================================================

-- Coreografia de turno (clareza do ritmo): banner "TURNO DO INIMIGO" →
-- pausa → inimigo age (investida) → banner "SEU TURNO". Estados:
--   nil      = turno do jogador correndo
--   "banner" = anunciando o turno inimigo (timer)
--   "acting" = inimigo agindo (espera a investida terminar)
local turnStage = nil
local turnStageT = 0

function GameplayScene.update(dt)
    updatePlayButtonPosition()
    TurnBanner.update(dt)

    game.combatAnimationSystem:update(dt)

    -- Encerrar Turno clicado DURANTE a animação: fica na fila e executa
    -- assim que a jogada termina (antes era engolido em silêncio).
    if game._endTurnQueued and game.turn == "player"
        and not game.combatAnimationSystem:isBlocking() then
        game._endTurnQueued = false
        game:endTurn()
    end

    -- Partículas são tickadas centralmente em main.lua via CardParticles.update.

    EnemyRenderer.update(dt)
    -- FX de interior (tochas) tickam quando o node atual é de castelo;
    -- transição estrada↔interior dispara fade de entrada (portão)
    do
        local runU = game.runManager and game.runManager.currentRun
        local ntU = runU and runU.currentNode and runU.currentNode.type
        local isInt = ntU == "boss" or ntU == "mini_boss" or ntU == "elite"
        if isInt then
            InteriorFX.update(dt, math.min(3, (runU and runU.actNumber) or 1))
        end
        if lastInterior ~= nil and isInt ~= lastInterior then
            interiorFade = 1
            if isInt then InteriorFX.clear() end
        end
        lastInterior = isInt
        if interiorFade > 0 then
            interiorFade = math.max(0, interiorFade - dt / 0.9)
        end
    end
    if GameplayScene.SCENE_MODE == "worldroad" then
        -- F6.1: entardecer progressivo por andar, com PISO 0.5 (feedback:
        -- "o jogo base está sem a iluminação do demo" — tod=0 no andar 1
        -- dava luz ~branca = motor invisível; o demo abre em tod=1). O
        -- mood existe desde o 1º andar (meio-crepúsculo, vagalumes no
        -- limiar) e fecha no anoitecer pleno no boss (o look da
        -- referência). Curva ^1.35: escurece devagar, acelera no fim.
        do
            local runT = game.runManager and game.runManager.currentRun
            local floorIn
            if runT then
                floorIn = runT.floorInAct or 1
            else
                floorIn = ((game.currentPhase or 1) - 1) % 8 + 1
            end
            -- piso 0.62 ("pode começar um pouco mais escuro", Jul/07)
            local prog = math.min(1, math.max(0, (floorIn - 1) / 7)) ^ 1.35
            WorldRoad.setTimeOfDay(0.62 + 0.38 * prog)
        end
        WorldRoad.update(dt)
        -- Troca de andar/fase → herói "anda" até o próximo encontro:
        -- o mundo rola pra frente (técnica Path of Kings)
        local floorKey
        if game.runManager and game.runManager.currentRun then
            local run = game.runManager.currentRun
            floorKey = (run.actNumber or 1) .. ":" .. (run.floorInAct or 1)
        else
            floorKey = "classic:" .. (game.currentPhase or 1)
        end
        if lastFloorKey ~= nil and floorKey ~= lastFloorKey
           and not WorldRoad.isTraveling() then
            -- nodes de interior (boss/elite): sem viagem na estrada — a
            -- batalha começa direto dentro do castelo
            local run2 = game.runManager and game.runManager.currentRun
            local nt = run2 and run2.currentNode and run2.currentNode.type
            if not (nt == "boss" or nt == "mini_boss" or nt == "elite") then
                -- o novo inimigo já existe (nextPhase rodou) → vem lá de trás;
                -- na chegada, quicadas de aterrissagem (juice)
                WorldRoad.travel({
                    encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
                    onComplete = function() EnemyRenderer.triggerArrival() end,
                })
            end
        end
        lastFloorKey = floorKey
    else
        SceneLayer.update(dt)
    end

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
        if turnStage == nil then
            turnStage = "banner"
            turnStageT = 0.75
            TurnBanner.show("enemy")
        elseif turnStage == "banner" then
            turnStageT = turnStageT - dt
            if turnStageT <= 0 then
                game:enemyTurn()   -- seta turn="player" ao fim (lógica);
                turnStage = "acting"  -- visual espera a investida
            end
        end
    elseif turnStage == "acting" then
        -- inimigo terminou de agir (investida no ar conta como agindo)
        local attacking = EnemyRenderer.isAttacking and EnemyRenderer.isAttacking()
        if not attacking then
            turnStage = nil
            if game.enemy:isAlive() and game.player:isAlive() then
                TurnBanner.show("player")
            end
        end
    end

    -- fumaça só ticka onde é desenhada (interior/legacy) — na estrada
    -- partículas acumuladas apareceriam de uma vez ao entrar no castelo
    if smokeSystem and not (GameplayScene.SCENE_MODE == "worldroad"
        and not lastInterior) then
        smokeSystem:update(dt)
    end

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
    if endTurnButton then endTurnButton:update(dt) end

    -- UX do turno multi-jogada (playtest): "joguei e nada aconteceu".
    -- JOGAR CARTAS desabilita quando não há nada selecionado NEM pagável;
    -- ENCERRAR TURNO pulsa quando é a única ação que resta.
    do
        local blocking = game.combatAnimationSystem:isBlocking()
        local hasSelection = #game.selectedCards > 0
        local anyPlayable = false
        for _, c in ipairs(game.hand) do
            if (c.cost or 0) <= game.player.mana then
                anyPlayable = true
                break
            end
        end
        local myTurn = game.turn == "player" and not blocking
        if playButton.setEnabled then
            playButton:setEnabled(myTurn and (hasSelection or anyPlayable))
        end
        if endTurnButton and endTurnButton.setEnabled then
            endTurnButton:setEnabled(myTurn)
        end
        GameplayScene._endTurnCallout = myTurn and not hasSelection
            and not anyPlayable and #game.hand >= 0

        -- AUTO-ENCERRAR (feedback Jul/2026, padrão StS/Balatro): sem
        -- seleção E sem carta pagável = nenhuma ação possível — o turno
        -- passa SOZINHO, praticamente na hora (feedback v2.1: "não precisa
        -- ter delay"; os 0.2s são só pra não flipar no MESMO frame em que
        -- a animação da jogada termina). Guardas: turnStage nil (a
        -- coreografia flipa game.turn cedo — sem isso auto-encerrava
        -- durante a investida do inimigo) e banner fora da tela.
        if GameplayScene._endTurnCallout and turnStage == nil
            and not TurnBanner.isActive() then
            GameplayScene._autoEndT = (GameplayScene._autoEndT or 0) + dt
            if GameplayScene._autoEndT >= 0.2 then
                GameplayScene._autoEndT = 0
                game:endTurn()
            end
        else
            GameplayScene._autoEndT = 0
        end
    end
    gameUI:update(dt, game)
    -- topBar:update movido pro main.lua (ticka em todos os estados)

    if game.messageSystem then game.messageSystem:update(dt) end
    if game.enemy then game.enemy:update(dt) end
end

-- ============================================================================
-- INPUT
-- ============================================================================

function GameplayScene.mousepressed(x, y, button)
    if topBar:mousepressed(x, y, button) then return end

    if button == 1 then
        -- BUG do playtest ("encerro e nada acontece"): os widgets Button
        -- exigem mousepressed pra armar o pressed — o hit-test manual
        -- antigo do Jogar Cartas disparava no press (ignorando disabled)
        -- e o Encerrar Turno nunca recebia o press → onClick NUNCA fired.
        if playButton:mousepressed(x, y, button) then return end
        if endTurnButton and endTurnButton:mousepressed(x, y, button) then
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
        if endTurnButton then endTurnButton:mousereleased(x, y, button) end

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
