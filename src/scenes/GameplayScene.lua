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
-- v10.4: no BOSS o interior (sala) só existe DEPOIS que a cerimônia da porta
-- terminou. Antes, durante a viagem de aproximação (entering ainda false), o
-- interior já era true → mostrava a sala do boss ANTES da cutscene, depois a
-- porta, depois a sala de novo (ordem quebrada). Este flag segura a sala até
-- o fade da porta completar. Resetado quando um novo andar de boss começa.
local bossEntered = false

-- Coreografia de turno (clareza do ritmo): banner "TURNO DO INIMIGO" →
-- pausa → inimigo age (investida) → banner "SEU TURNO". Estados:
--   nil      = turno do jogador correndo
--   "banner" = anunciando o turno inimigo (timer)
--   "acting" = inimigo agindo (espera a investida terminar)
-- (declarado AQUI no topo pra setGame/resetTurnState enxergarem a local)
local turnStage = nil
local turnStageT = 0

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

-- REBIND do game (bug "abandonei e caí na run antiga", Jul/2026):
-- returnToMenu cria um Game NOVO, mas esta cena capturava deps.game numa
-- local de módulo — a tela continuava desenhando/atualizando o game morto
-- enquanto os botões agiam no novo (mão fantasma, nenhuma carta jogável).
-- Todo rebind passa por aqui, que também zera o estado de turno POR RUN
-- do módulo (turnStage/bossEntered sobreviviam entre runs).
function GameplayScene.setGame(g)
    game = g
    GameplayScene.resetTurnState()
    -- O CENÁRIO também é estado de módulo e sobrevivia ao abandono:
    -- o mundo voltava com bioma/câmera/viagem da run morta, e um attackFx
    -- pendente do inimigo antigo podia disparar o apex dentro da run nova.
    WorldRoad.resetRun()
    EnemyRenderer.resetRun()
end

-- Estado de turno per-run do módulo (usado por setGame e testável isolado).
function GameplayScene.resetTurnState()
    turnStage = nil
    turnStageT = 0
    bossEntered = false
    GameplayScene._endTurnCallout = false
end

-- Introspecção pra testes de regressão (smoke_ui_turn).
function GameplayScene.getGame() return game end

-- ============================================================================
-- INTERNAL: posicionamento
-- ============================================================================

local function updatePlayButtonPosition()
    if not playButton then return end
    local buttonWidth  = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_WIDTH_RATIO, 180, "width")
    local buttonHeight = Config.Utils.getResponsiveSize(Config.UI.PLAY_BUTTON_HEIGHT_RATIO, 60, "height")
    local buttonX = (love.graphics.getWidth() - buttonWidth) / 1.05
    -- Feedback Jul/2026: os botões batiam na mão quando o deck crescia. Foram
    -- SUBIDOS (0.72 → 0.62) e a mão agora é "espremida" numa área que termina
    -- antes deles (ver handLayout) — dupla garantia contra sobreposição.
    local buttonY = love.graphics.getHeight() * 0.62
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

-- ============================================================================
-- LAYOUT DA MÃO (fanning + squeeze estilo Balatro)
-- ============================================================================
-- Balatro (cardarea.lua:align_cards) distribui a mão numa ÁREA de largura fixa:
-- o espaçamento vira areaW/(n-1), então quantas mais cartas, mais elas se
-- sobrepõem ("espremem") — nunca estouram a área. A carta em hover sobe e é
-- desenhada por cima das vizinhas (já feito no draw). Portamos a mesma ideia:
-- a mão fica CENTRADA na tela, mas com a largura do leque LIMITADA pra terminar
-- antes dos botões de ação (à direita), com folga de meia-carta.
--
-- Retorna: startX (x TOP-LEFT da 1ª carta), spacing, cardY, n (#mão).
-- IMPORTANTE: Card:draw trata (x,y) como CANTO SUPERIOR-ESQUERDO (o centro é
-- x + imgW/2), então o leque é centrado VISUALMENTE numa área que exclui a
-- coluna dos botões — nunca invade a direita.
local function handLayout()
    local width  = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local n = #game.hand
    local cardY = height * 0.8

    -- largura renderizada aproximada de uma carta (BASE_SCALE do template 96px)
    local cardW = 96 * (Config.Cards.BASE_SCALE or 1.333)
    -- espaçamento "confortável" quando há poucas cartas (comportamento antigo)
    local maxSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width")

    -- Área da mão: da margem esquerda até o início dos botões (com folga). O
    -- leque é centrado NESTA área — fica levemente à esquerda do centro da
    -- tela (natural: os botões de ação ganham a coluna da direita, StS-style).
    local areaLeft  = 30
    local areaRight = (playButton and playButton.x or width * 0.80) - 16
    if areaRight < areaLeft + cardW then areaRight = areaLeft + cardW end
    local areaW = areaRight - areaLeft
    local areaCenter = (areaLeft + areaRight) / 2

    local spacing
    if n > 1 then
        -- squeeze: a largura VISUAL do leque (totalW + cardW) cabe em areaW
        spacing = math.min(maxSpacing, (areaW - cardW) / (n - 1))
    else
        spacing = 0
    end

    local totalW = spacing * math.max(0, n - 1)
    -- startX = top-left da 1ª carta pra que o leque fique centrado na área
    local startX = areaCenter - (totalW + cardW) / 2
    return startX, spacing, cardY, n
end
GameplayScene.handLayout = handLayout

local function updateCardPositions()
    local cardStartX, cardSpacing, cardY = handLayout()

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

-- Geometria do painel de coringas (topo-ESQUERDO). Feedback Jul/2026: os
-- jokers viviam parados centralizados no topo; agora ficam num QUADRO à
-- esquerda, rotulado, com slots fixos (até maxJokerSlots) — visivelmente
-- "cartas diferenciadas". Clicar no quadro abre o Gerenciador de Coringas.
-- Fonte única de geometria (usada por draw E pelo hit-test do clique).
local function jokerFrameGeometry()
    local topBarHeight = (topBar and topBar.height) or 80
    local base = 96 * (Config.Cards.BASE_SCALE or 1.333)
    local slotScale = Config.Cards.JOKER_SLOT_SCALE or 0.7
    local cardW = base * slotScale
    local cardH = 144 * (Config.Cards.BASE_SCALE or 1.333) * slotScale
    local pad, gap, labelH = 8, 8, 18
    local maxSlots = (game and game.maxJokerSlots) or 3
    local frameX = 14
    local frameY = topBarHeight + 8
    local frameW = pad * 2 + maxSlots * cardW + (maxSlots - 1) * gap
    local frameH = pad * 2 + labelH + cardH
    return {
        x = frameX, y = frameY, w = frameW, h = frameH,
        cardW = cardW, cardH = cardH, pad = pad, gap = gap,
        labelH = labelH, maxSlots = maxSlots,
    }
end

-- Rect clicável do quadro de coringas (pra main.lua / mousepressed).
function GameplayScene.jokerFrameRect()
    local g = jokerFrameGeometry()
    return g.x, g.y, g.w, g.h
end

local function drawJokersAsCards()
    local g = jokerFrameGeometry()
    local mx, my = love.mouse.getPosition()
    local frameHot = mx >= g.x and mx <= g.x + g.w and my >= g.y and my <= g.y + g.h

    -- Painel de fundo (zona "cartas especiais") — sutil, dourado.
    local Palette = require("src.ui.Palette")
    love.graphics.setColor(0.06, 0.05, 0.04, 0.55)
    love.graphics.rectangle("fill", g.x, g.y, g.w, g.h, 6, 6)
    love.graphics.setColor(Palette.AGED_GOLD_DARK[1], Palette.AGED_GOLD_DARK[2],
        Palette.AGED_GOLD_DARK[3], frameHot and 0.95 or 0.6)
    love.graphics.setLineWidth(frameHot and 2 or 1)
    love.graphics.rectangle("line", g.x, g.y, g.w, g.h, 6, 6)
    love.graphics.setLineWidth(1)

    -- Rótulo + contagem ativos/teto (+bancada)
    local ownedN = 0
    if game.runManager and game.runManager.currentRun
        and game.runManager.currentRun.jokers then
        ownedN = #game.runManager.currentRun.jokers
    end
    local activeN = #game.jokerSlots
    local benched = math.max(0, ownedN - activeN)
    local lf = FontManager.getFont(8)
    love.graphics.setFont(lf)
    Palette.set(Palette.AGED_GOLD_LIGHT)
    local label = "CORINGAS " .. activeN .. "/" .. g.maxSlots .. "  (J)"
    love.graphics.print(label, g.x + g.pad, g.y + 5)
    if benched > 0 then
        Palette.set(Palette.RUST)
        local bl = "+" .. benched .. " bancada"
        love.graphics.print(bl, g.x + g.w - g.pad - lf:getWidth(bl), g.y + 5)
    end

    -- Slots fixos: joker desenhado OU placeholder vazio.
    local slotY = g.y + g.pad + g.labelH
    for i = 1, g.maxSlots do
        local slotX = g.x + g.pad + (i - 1) * (g.cardW + g.gap)
        local joker = game.jokerSlots[i]
        if joker then
            local isHovered = mx >= slotX and mx <= slotX + g.cardW
                and my >= slotY and my <= slotY + g.cardH
            joker:updateMouse(mx, my, love.timer.getDelta(), isHovered)
            local originalScale = joker.currentScale
            joker.currentScale = originalScale * Config.Cards.JOKER_SLOT_SCALE
            joker:draw(slotX, slotY)
            joker.currentScale = originalScale
        else
            -- placeholder de slot vazio (tracejado sutil + "+")
            love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
                Palette.PARCHMENT_DARK[3], 0.35)
            love.graphics.rectangle("line", slotX, slotY, g.cardW, g.cardH, 4, 4)
            local pf = FontManager.getFont(18)
            love.graphics.setFont(pf)
            love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],
                Palette.PARCHMENT_DARK[3], 0.5)
            love.graphics.print("+", slotX + (g.cardW - pf:getWidth("+")) / 2,
                slotY + (g.cardH - pf:getHeight()) / 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

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

    -- PROGRESSÃO DE CENÁRIO (feedback Jul/2026 + v10.1): batalha comum e
    -- MINI-BOSS acontecem na ESTRADA (mundo-esfera, do lado de fora);
    -- boss/elite acontecem DENTRO do castelo (interior PixelLab por ato).
    local nodeType = run and run.currentNode and run.currentNode.type
    -- v10: enquanto a CERIMÔNIA de entrada toca (porta abrindo), a cena
    -- continua na estrada — o interior só assume depois do fade
    local entering = GameplayScene.SCENE_MODE == "worldroad"
        and WorldRoad.isEntering()
    -- v10.4: elite entra no hall direto; BOSS só vira interior depois da
    -- cutscene da porta (bossEntered). Durante a viagem de aproximação e a
    -- própria cutscene, interior=false → a cena mostra a ESTRADA/exterior
    -- (castelo crescendo, porta abrindo), nunca a sala antes da hora.
    local interior = GameplayScene.SCENE_MODE == "worldroad" and not entering
        and (nodeType == "elite"
             or (nodeType == "boss" and bossEntered))

    -- v9.2: no battle da estrada, o inimigo desenha DENTRO do painter do
    -- WorldRoad (no eixo BATTLE_REL) pra que postes/árvores mais próximos
    -- que ele fiquem NA FRENTE. Registra antes do draw; o painter chama e
    -- captura o bbox (usado pelo HUD). traveling/interior seguem o fluxo
    -- antigo (inimigo é billboard ou hall estático).
    local traveling = GameplayScene.SCENE_MODE == "worldroad"
        and not interior and WorldRoad.isTraveling()
    local worldBattle = GameplayScene.SCENE_MODE == "worldroad"
        and not interior and not traveling and not entering
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
    if not traveling and not worldBattle and not entering then
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

    if not traveling and not entering then
        EnemyHud.draw(game, enemyBbox, enemyCx, enemyCy)
    end

    gameUI:draw(game)

    -- Banner de turno (por cima do HUD, por baixo da mão/tooltips)
    TurnBanner.draw()

    -- Layout da mão (drag + reorder + slot animado) — fanning/squeeze estilo
    -- Balatro (ver handLayout): a mão nunca estoura pra cima dos botões.
    local cardStartX, cardSpacing, cardY, currentHandSize = handLayout()

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
        -- Flag pro Card:draw: carta selecionada anima o ícone (icons_anim)
        card.isSelected = game:isCardSelected(card)
        if card.isSelected then offsetY = -100 end
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
    -- v10: fade da fase "push" da cerimônia (entrando pelo vão da porta —
    -- escurece ATÉ o preto; o interiorFade acima revela do preto depois)
    local ef = WorldRoad.entryFade and WorldRoad.entryFade() or 0
    if ef > 0 then
        love.graphics.setColor(0, 0, 0, ef * ef)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ============================================================================
-- UPDATE
-- ============================================================================

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
        -- v10.4: alinhado com `interior` do draw — elite direto; boss só
        -- depois da cutscene (bossEntered). Guarda `not isEntering` p/ o
        -- frame de transição.
        local isInt = (ntU == "elite"
                       or (ntU == "boss" and bossEntered))
            and not (GameplayScene.SCENE_MODE == "worldroad"
                     and WorldRoad.isEntering())
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
            local run2 = game.runManager and game.runManager.currentRun
            local nt = run2 and run2.currentNode and run2.currentNode.type
            if nt == "boss" then
                -- v10.2/v10.4: BOSS — a esfera anda pra frente (o castelo
                -- cresce naturalmente, como todo andar), SEM inimigo na
                -- estrada (o boss está dentro). Ao CHEGAR, a porta abre +
                -- som; quando o fade completa, bossEntered=true libera a
                -- sala. Até lá interior=false (sem mostrar a sala antes).
                bossEntered = false
                WorldRoad.travel({
                    onComplete = function()
                        WorldRoad.enterCastle({
                            onComplete = function() bossEntered = true end,
                        })
                    end,
                })
            elseif nt ~= "elite" then
                -- batalha comum E MINI-BOSS (v10.1: "do lado de fora do
                -- castelo, sem aquele background"): o inimigo vem lá de
                -- trás pela estrada; na chegada, quicadas de aterrissagem
                WorldRoad.travel({
                    encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
                    onComplete = function() EnemyRenderer.triggerArrival() end,
                })
            end
            -- elite: sem viagem e sem cerimônia — hall direto com o fade
            -- de entrada simples (comportamento pré-v10)
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
    -- v10: cerimônia de entrada no castelo é cinemática — engole cliques
    if GameplayScene.SCENE_MODE == "worldroad" and WorldRoad.isEntering() then
        return true
    end
    -- v9.7.1: retorna se CONSUMIU o clique — o que sobrar vira poke no
    -- cenário do WorldRoad (main.lua → pokeSceneAt, mapa vivo)
    if topBar:mousepressed(x, y, button) then return true end

    -- Clique no quadro de coringas (topo-esquerdo) abre o Gerenciador.
    if button == 1 then
        local jx, jy, jw, jh = GameplayScene.jokerFrameRect()
        if x >= jx and x <= jx + jw and y >= jy and y <= jy + jh then
            if _G.toggleJokerManager then _G.toggleJokerManager() end
            return true
        end
    end

    if button == 1 then
        -- BUG do playtest ("encerro e nada acontece"): os widgets Button
        -- exigem mousepressed pra armar o pressed — o hit-test manual
        -- antigo do Jogar Cartas disparava no press (ignorando disabled)
        -- e o Encerrar Turno nunca recebia o press → onClick NUNCA fired.
        if playButton:mousepressed(x, y, button) then return true end
        if endTurnButton and endTurnButton:mousepressed(x, y, button) then
            return true
        end

        -- Drag-pending em cartas hovered (select vs reorder resolve em release)
        local armed = false
        for _, card in ipairs(game.hand) do
            if card.isHovered then
                card.dragPending = true
                card.dragStartMX = x
                card.dragStartMY = y
                card.dragOffsetX = card.x - x
                card.dragOffsetY = card.y - y
                armed = true
            end
        end
        if armed then return true end
    end
    return false
end

-- Calcula drop-index baseado na posição X do mouse (usa o MESMO layout do draw)
local function computeHandDropIndex(mx, handSize)
    if handSize <= 1 then return 1 end
    local cardStartX, cardSpacing = handLayout()
    if cardSpacing <= 0 then return 1 end
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
