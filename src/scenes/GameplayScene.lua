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
local I18n             = require("src.i18n.I18n")
local SceneLayer       = require("src.ui.SceneLayer")
local SceneBackground  = require("src.ui.SceneBackground")
local SceneAnchors     = require("src.data.scene_anchors")
local InteriorFX       = require("src.ui.InteriorFX")
local WorldRoad        = require("src.ui.WorldRoad")
local EnemyRenderer    = require("src.ui.EnemyRenderer")
local EnemyHud         = require("src.ui.EnemyHud")
local TurnBanner       = require("src.ui.TurnBanner")
local ComboBanner      = require("src.ui.ComboBanner")
local DamagePreviewPanel = require("src.ui.DamagePreviewPanel")
local Sfx              = require("src.systems.Sfx")
local SmokeConfig      = require("src.config.SmokeConfig")
local InputFocus       = require("src.ui.InputFocus")
-- ESCALA DE UI (Out/2026): a cena é ADOTADA pelo UiScale — mão, HUD, botões,
-- quadro de coringas e toasts vivem no espaço virtual (~1280x720, scale k).
-- O MUNDO (WorldRoad / salão / inimigo) NÃO: ele já escala com a janela, e
-- roda dentro de UiScale.outside com a janela real. Fronteira: o bbox do
-- inimigo volta dividido por k pro HUD; o limite do palco vai multiplicado
-- por k pro WorldRoad. Ver memory/ui_scale.md.
local UiScale          = require("src.ui.UiScale")
-- Cinemática do chefe (Out/2026): entrada no salão vazio + morte em câmera
-- lenta. A cena pergunta a ela o que esconder (chefe/HUD) e quando os
-- espólios podem entrar — ver src/ui/BossCinematic.lua.
local BossCinematic    = require("src.ui.BossCinematic")
-- Cortina da mão + distribuição das cartas depois de toda cutscene (viagem,
-- porta, entrada do chefe): a mão, os botões e o HUD só existem quando há
-- luta — ver src/ui/HandDeal.lua.
local HandDeal         = require("src.ui.HandDeal")

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
-- cadáver de quem voa cai num chão abaixo do topo da mão (ver deathCy)
local corpseUnderHand = false

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

-- QUEM LUTA DENTRO DO CASTELO — fonte ÚNICA da decisão (draw e update
-- perguntam aqui). Só o BOSS, e só depois da cutscene da porta.
--
-- v11 (Set/2026, feedback do dono: "elite indo pro mesmo cenário do castelo
-- do endgame não faz sentido"): o hall é o CLÍMAX do ato — é o pagamento da
-- cerimônia da porta. O elite acontece 2-3x por ato, sem viagem e sem
-- porta; mandá-lo pro mesmo salão gastava o clímax antes da hora e
-- contradizia o próprio mundo (você nunca entrou em castelo nenhum). A
-- estrada já sabe dizer "isto é um elite" (marco landmark_elite com luz
-- roxa no fork), e o MINI-BOSS — que usa o MESMO sprite do elite no roster
-- — sempre brigou lá fora: ter os dois em cenas diferentes era incoerente.
function GameplayScene.isInteriorNode(nodeType, entered)
    return nodeType == "boss" and entered == true
end

-- leitura do estado (PlaceAudio: salão do chefe não toca o clima da estrada)
function GameplayScene.inBossRoom(nodeType)
    return GameplayScene.isInteriorNode(nodeType, bossEntered)
end

-- A cena está QUIETA? (tutorial: o narrador só fala com tudo parado) —
-- sem viagem, sem cerimônia da porta (no chefe, só depois dela), sem banner
-- de turno, sem investida nem pouso do inimigo.
function GameplayScene.isQuiet()
    if turnStage ~= nil or TurnBanner.isActive() then return false end
    if GameplayScene.SCENE_MODE == "worldroad"
        and (WorldRoad.isTraveling() or WorldRoad.isEntering()) then
        return false
    end
    local run = game and game.runManager and game.runManager.currentRun
    local nt = run and run.currentNode and run.currentNode.type
    if nt == "boss" and GameplayScene.SCENE_MODE == "worldroad" and not bossEntered then
        return false
    end
    -- entrada/morte do chefe tocando: o narrador espera a cena terminar
    if BossCinematic.isActive() then return false end
    -- cartas ainda sendo dadas: o narrador espera a mão na mesa
    if HandDeal.isBusy() then return false end
    if EnemyRenderer.isAttacking() then return false end
    if EnemyRenderer.getArrivalOffset and EnemyRenderer.getArrivalOffset() ~= 0 then
        return false
    end
    return true
end

-- Só pra ferramentas de captura: salta a cerimônia da porta e mostra o
-- salão do chefe direto (tools/screenshot_enemy_scene.lua). Nunca chamado
-- pelo jogo — a cutscene é parte do clímax.
function GameplayScene._debugForceBossEntered()
    bossEntered = true
end

-- A PORTA TERMINOU DE ABRIR: o salão passa a existir e a ENTRADA do chefe
-- toca dentro dele (src/ui/BossCinematic — chefe sem roteiro luta direto).
-- Só a cerimônia chama isto; o Continuar usa _debugForceBossEntered, de
-- propósito: retomar dentro da luta é retomar NA luta, sem repetir a entrada.
function GameplayScene._onBossEntered()
    bossEntered = true
    BossCinematic.startIntro(game)
end

-- Ferramentas/testes: salão aberto E entrada tocando (prova visual da
-- cinemática sem passar pela viagem e pela porta).
function GameplayScene._debugStartBossIntro()
    GameplayScene._onBossEntered()
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
    BossCinematic.reset()
    HandDeal.reset()
    GameplayScene._endTurnCallout = false
    -- Sem isto, o 1º frame da run NOVA compararia com o andar da run
    -- MORTA e dispararia uma viagem/chegada espúria na estrada.
    lastFloorKey = nil
end

-- CONTINUAR uma run salva: devolve o MUNDO ao ponto do save E ancora o
-- andar da cena. Mora aqui (e não no main.lua) porque `lastFloorKey` — o
-- gatilho da caminhada até o próximo encontro — é estado DESTE módulo:
-- restaurar o mundo sem ancorar o andar deixa as duas metades em
-- desacordo.
--
-- O bug que isto mata (Set/2026, "a bandeira não sai da frente do primeiro
-- inimigo"): o save feito NA ENCRUZILHADA guarda o andar JÁ avançado
-- (showMapSelection chama advanceFloorInAct ANTES de montar o fork), mas a
-- caminhada até esse andar ainda não aconteceu — o mundo pertence ao andar
-- ANTERIOR. Como o Continuar vinha do menu (setGame ⇒ lastFloorKey = nil),
-- o primeiro andar depois de retomar era lido como "início de run" e
-- NENHUMA viagem disparava. Sem a viagem, o marco plantado pela
-- convergência do fork (landmark_battle — um estandarte vermelho) ficava
-- parado em ARRIVE_REL 7.5, à frente do inimigo em BATTLE_REL 9 e desenhado
-- depois dele: a bandeira em cima do monstro, pra sempre.
function GameplayScene.resumeWorld(g)
    local run = g and g.runManager and g.runManager.currentRun
    local act = (run and run.actNumber) or 1
    local floor = (run and run.floorInAct) or 1
    local pending = run and run.pendingNodes
    local atFork = (pending ~= nil and #pending > 0)
    -- Na encruzilhada o mundo está um andar ATRÁS do que o save diz.
    WorldRoad.restoreProgress(act, atFork and math.max(1, floor - 1) or floor)
    -- Âncora que o detector de troca de andar compara. Na encruzilhada é
    -- floor-1 DE PROPÓSITO (pode dar 0 quando o ato acabou de virar): o nó
    -- escolhido sempre lê como troca de andar e a caminhada acontece.
    lastFloorKey = act .. ":" .. (atFork and (floor - 1) or floor)
end

-- Introspecção pra testes de regressão (smoke_ui_turn).
function GameplayScene.getGame() return game end
function GameplayScene.getFloorAnchor() return lastFloorKey end

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
-- Folga entre o pe do inimigo e o topo da mao. 12px: o bastante pra sombra de
-- contato respirar sem o inimigo parecer levitando acima do piso.
local ENEMY_HAND_CLEARANCE = 12


-- ESCALA DA MÃO (Out/2026): a UI inteira escala k (UiScale), mas a mão
-- cresce MAIS DEVAGAR — handK = 1 + (k-1)/2 (1.25 em 1080p, 1.5 em 1440p,
-- 1.75 em 4K). Com a mão a k cheio, o palco empurrava o inimigo estrada
-- adentro e ele lia pequeno em tela cheia (queixa antiga do dono: "o
-- inimigo é a estrela da batalha"). Devolve o fator NO ESPAÇO DA UI
-- (handK / k): 1 em 1024x768/1366x768.
GameplayScene.HAND_GROWTH = 0.5
local function handScale()
    local k = UiScale.activeK()
    if k <= 1 then return 1 end
    return (1 + (k - 1) * GameplayScene.HAND_GROWTH) / k
end
GameplayScene.handScale = handScale

local function handLayout()
    local width  = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local n = #game.hand
    local hs = handScale()
    -- a faixa da mão visível (20% da altura) encolhe junto com a carta
    local cardY = height - height * 0.2 * hs

    -- largura renderizada aproximada de uma carta (BASE_SCALE do template 96px)
    local cardW = 96 * (Config.Cards.BASE_SCALE or 1.333) * hs
    -- espaçamento "confortável" quando há poucas cartas (comportamento antigo)
    local maxSpacing = Config.Utils.getResponsiveSize(Config.UI.CARD_SPACING_RATIO, 120, "width") * hs

    -- O leque é centrado NO CENTRO DA TELA (feedback Jul/2026: "as cartas
    -- não estão ficando centralizadas" — centrar na área útil deixava a
    -- mão deslocada pra esquerda). Os botões da direita continuam
    -- protegidos: a MEIA-LARGURA disponível é o menor lado livre a partir
    -- do centro (esquerda até a margem, direita até os botões) — com
    -- muitas cartas o leque espreme SIMETRICAMENTE em torno do centro.
    local areaLeft  = 30
    local areaRight = (playButton and playButton.x or width * 0.80) - 16
    if areaRight < areaLeft + cardW then areaRight = areaLeft + cardW end
    local center = width / 2
    local halfW = math.max(cardW / 2,
        math.min(center - areaLeft, areaRight - center))
    local areaW = halfW * 2

    local spacing
    if n > 1 then
        -- squeeze: a largura VISUAL do leque (totalW + cardW) cabe em areaW
        spacing = math.min(maxSpacing, (areaW - cardW) / (n - 1))
    else
        spacing = 0
    end

    local totalW = spacing * math.max(0, n - 1)
    -- startX = top-left da 1ª carta pra que o leque fique centrado na TELA
    local startX = center - (totalW + cardW) / 2
    return startX, spacing, cardY, n
end
GameplayScene.handLayout = handLayout

-- Quanto a carta em hover SOBE em relação à mão em repouso (px de tela).
local HOVER_LIFT = 130
-- PALCO DA BATALHA (Out/2026, dono: "os inimigos param muito na frente da
-- tela. Muitas das vezes a descrição da carta ou a carta em si, quando faz
-- o hover, fica à frente do inimigo"). Zona da MÃO EM HOVER: o pé do
-- inimigo fica pelo menos STAGE_CLEARANCE px acima do topo da carta
-- levantada. Na estrada isso vira DISTÂNCIA (WorldRoad.battleRelFor empurra
-- o encontro estrada adentro, e a perspectiva encolhe o corpo junto); no
-- salão do chefe vira posição na laje, limitada pela borda do piso (ver
-- SceneAnchors.backYr). O tooltip da carta foi pro LADO dela pela mesma
-- razão (Card.tooltipSide) — acima da carta ele caía exatamente sobre o
-- tronco do inimigo, em qualquer distância que ainda fosse estrada.
-- Medido por tools/study_enemy_stage; travado por tools/test_enemy_stage.
local STAGE_CLEARANCE = 18
local function stageFootLimit()
    local _, _, cardY = handLayout()
    return math.floor(cardY - HOVER_LIFT * handScale() - STAGE_CLEARANCE)
end
GameplayScene.stageFootLimit = stageFootLimit

-- Recalculado todo frame a partir da janela (como o resto da cena): resize
-- e troca de fullscreen reposicionam o palco sem cache nenhum.
local function syncBattleStage()
    -- limite do palco medido no espaço da UI (a mão), convertido pra pixels
    -- da tela — o WorldRoad vive na janela real (UiScale.outside)
    local k = UiScale.activeK()
    local limit = stageFootLimit() * k
    local tb = ((topBar and topBar.height) or 80) * k
    UiScale.outside(function()
        local width, height = love.graphics.getWidth(), love.graphics.getHeight()
        WorldRoad.setBattleRel(WorldRoad.battleRelFor(0, tb, width, height - tb, limit))
    end)
end
GameplayScene.syncBattleStage = syncBattleStage

local function updateCardPositions()
    local cardStartX, cardSpacing, cardY = handLayout()
    -- tamanho da carta da mão (ver handScale); o hover multiplica baseScale
    local base = (Config.Cards.BASE_SCALE or 1.333) * handScale()

    for i, card in ipairs(game.hand) do
        if card.baseScale ~= base then
            local wasBase = card.targetScale == card.baseScale
            card.baseScale = base
            if wasBase or not card.isHovered then card.targetScale = base end
            if card.image then
                card.width = card.image:getWidth() * base
                card.height = card.image:getHeight() * base
            end
        end
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

-- Centro do slot `i` de joker (game feel v1: JokerProcFx ancora o popup e a
-- faísca do proc AQUI — o feedback nasce no joker que contribuiu).
function GameplayScene.jokerSlotCenter(i)
    local g = jokerFrameGeometry()
    i = math.max(1, math.min(i or 1, g.maxSlots))
    local slotX = g.x + g.pad + (i - 1) * (g.cardW + g.gap)
    local slotY = g.y + g.pad + g.labelH
    return slotX + g.cardW / 2, slotY + g.cardH / 2
end

local function drawJokersAsCards()
    local g = jokerFrameGeometry()
    -- o quadro abre o Gerenciador de Coringas: alvo do foco (NavCursor)
    require("src.ui.NavCursor").target("jokerFrame", g.x, g.y, g.w, g.h)
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
    local label = I18n.t("hud.jokers_frame", { n = activeN, max = g.maxSlots })
    love.graphics.print(label, g.x + g.pad, g.y + 5)
    if benched > 0 then
        Palette.set(Palette.RUST)
        local bl = I18n.t("hud.jokers_bench", { n = benched })
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
            -- Coringas vivem no TOPO: tooltip ABAIXO da carta (acima, o
            -- clamp cobria o topo dela — feedback Jul/2026)
            joker.tooltipBelow = true
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
    -- mundo puro: janela REAL (a TopBar está no espaço da UI → × k)
    local tbReal = (topBar.height or 80) * UiScale.activeK()
    return UiScale.outside(GameplayScene._drawWorldOnlyReal, tbReal)
end

function GameplayScene._drawWorldOnlyReal(topBarHeight)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
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
    -- encruzilhada: cada marco é alvo do foco de teclado/pad (NavCursor) —
    -- a hitbox é a mesma do clique (WorldRoad.forkMousePressed)
    local f = WorldRoad._fork
    if f and f.markBoxes then
        for i = 1, (f.n or 3) do
            local b = f.markBoxes[i]
            if b then
                require("src.ui.NavCursor").target("fork:" .. i, b.x1, b.y1,
                    b.x2 - b.x1, b.y2 - b.y1)
            end
        end
    end
end

-- Tamanho do chefe no salão (Out/2026, dono: "em tela cheia os bosses não
-- ficam muito pequenos?"). O chefe tem altura FIXA em pixels (330) e o salão
-- cresce com a tela pelo cover-fit: em 1920x1080 ele ocupava ~27% da altura
-- e lia pequeno pro clímax do ato; em 2560x1440 pior ainda. O chefe passa a
-- crescer na mesma proporção da sala a partir de 3.7 px por pixel da arte —
-- 1080p fica 1.3x (escolhido por comparação lado a lado de 1.0/1.2/1.35:
-- domina a sala sem a barra de vida colar no topo nem o pé descer na mão),
-- 1440p e 4K mantêm a MESMA proporção. Abaixo disso (1024x768, 1366x768)
-- nada muda: lá o chefe já ocupa ~43% da altura.
GameplayScene.HALL_REF_SCALE = 3.7
GameplayScene.HALL_MAX_K = 3
function GameplayScene.hallScreenK(sceneKey, w, h)
    if not sceneKey or not sceneKey:find("^castle_hall_") then return 1 end
    local tr = SceneBackground.getCoverTransform(sceneKey, w, h)
    if not tr then return 1 end
    return math.max(1, math.min(GameplayScene.HALL_MAX_K,
        tr.scale / GameplayScene.HALL_REF_SCALE))
end

-- O CHEFE É SEMPRE MAIOR QUE O INIMIGO COMUM (Out/2026). O salão cresce
-- pelo cover-fit da arte (hallScreenK) e o chefe ainda encolhe ao recuar na
-- laje (depthSizeK); a estrada cresce pelo enemyScreenK. Em 1440p as duas
-- curvas se cruzavam e o chefe do ato 5 saía 3px MENOR que o comum mais alto
-- (test_enemy_stage). Piso: o chefe tem pelo menos BOSS_OVER_COMMON vezes a
-- altura que um comum (250px de arte) teria na mesma área de mundo.
GameplayScene.BOSS_OVER_COMMON = 1.15
function GameplayScene.bossSizeK(k, worldAreaH)
    local floorK = GameplayScene.BOSS_OVER_COMMON * (250 / 330)
        * WorldRoad.enemyScreenK(worldAreaH)
    return math.max(k, floorK)
end

function GameplayScene.draw()
    corpseUnderHand = false
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local topBarHeight = topBar.height or 80

    -- Cenário em camadas (BG_FAR + BG_MID + FG_PROPS) com parallax
    local currentAct = 1
    local run = game and game.runManager and game.runManager.currentRun
    if run then currentAct = run.actNumber or 1 end

    -- PROGRESSÃO DE CENÁRIO (feedback Jul/2026 + v10.1 + v11): batalha
    -- comum, ELITE e mini-boss acontecem na ESTRADA (mundo-esfera, do lado
    -- de fora); só o BOSS entra no castelo — ver isInteriorNode.
    local nodeType = run and run.currentNode and run.currentNode.type
    -- v10: enquanto a CERIMÔNIA de entrada toca (porta abrindo), a cena
    -- continua na estrada — o interior só assume depois do fade
    local entering = GameplayScene.SCENE_MODE == "worldroad"
        and WorldRoad.isEntering()
    -- Durante a viagem de aproximação e a própria cutscene, interior=false
    -- → a cena mostra a ESTRADA/exterior (castelo crescendo, porta
    -- abrindo), nunca a sala antes da hora.
    local interior = GameplayScene.SCENE_MODE == "worldroad" and not entering
        and GameplayScene.isInteriorNode(nodeType, bossEntered)

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
    if GameplayScene.SCENE_MODE == "worldroad" then syncBattleStage() end
    -- Números do palco medidos na UI (mão) ANTES de sair pro mundo real.
    local uiK = UiScale.activeK()
    local stageYReal = stageFootLimit() * uiK
    local _, _, handTopV = handLayout()
    local handTopReal = handTopV * uiK
    local uiTopBarH = topBarHeight
    local interiorHall = nil
    -- ===== MUNDO (janela real) =====
    UiScale.outside(function()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    -- morte do chefe: o mundo passa por um canvas e volta dessaturado
    local worldPass = BossCinematic.beginWorldPass()
    -- soco de zoom do pouso do chefe (BossCinematic.worldZoom): só o MUNDO,
    -- em volta do ponto de impacto, translação inteira
    local zk, zcx, zcy = BossCinematic.worldZoom()
    if zk then
        love.graphics.push()
        love.graphics.translate(math.floor(zcx - zcx * zk), math.floor(zcy - zcy * zk))
        love.graphics.scale(zk)
    end
    -- WORLD_ONLY (arte de loja/key art, tools/store_art.py): mundo + inimigo
    -- em tela cheia, sem top bar nem HUD.
    local topBarHeight = GameplayScene.WORLD_ONLY and 0 or uiTopBarH * uiK
    if worldBattle then
        enemyCx, enemyCy = WorldRoad.getRoadAnchor(WorldRoad.BATTLE_REL,
            0, topBarHeight, width, height - topBarHeight)
        -- sizeK: o inimigo encolhe pela MESMA perspectiva do mundo conforme
        -- a distância de parada (WorldRoad.battleSizeK) — parar mais ao
        -- fundo sem encolher deixaria um gigante longe, quebrando a escala
        -- das árvores em volta.
        local sizeK = (WorldRoad.battleSizeK and WorldRoad.battleSizeK() or 1)
            * WorldRoad.enemyScreenK(height - topBarHeight)   -- tela grande: cresce com o mundo
        WorldRoad.setBattleEnemyDraw(function()
            enemyBbox = EnemyRenderer.draw(game, enemyCx, enemyCy,
                { sizeK = sizeK })
        end, enemyCy)
    end

    -- Cena de fundo efetivamente desenhada — o inimigo pisa na LINHA DE
    -- CHÃO dela (src/data/scene_anchors.lua), não numa fração fixa da tela.
    -- sceneH: o SceneLayer legado desenha a PNG na area util (sem a top
    -- bar), o hall desenha em tela cheia — a ancora tem que usar a MESMA
    -- caixa que o desenho usou, senao o pe sai da laje.
    local sceneKey, sceneH = nil, height
    if interior then
        -- Salão do chefe por ato (1..6). A escolha do salão — e o aviso de
        -- ato sem arte — mora em InteriorFX.hallFor: draw e update perguntam
        -- ao MESMO lugar (a v1 tickava as brasas com min(3, ato) e desenhava
        -- o salão real: nos atos 4-6 as brasas saíam da lava do hall 3).
        local hallAct = InteriorFX.hallFor(currentAct)
        local drawn = SceneBackground.draw("castle_hall_" .. hallAct,
            width, height, 0.15)
        sceneKey = "castle_hall_" .. hallAct
        if not drawn then
            -- interior ainda não gerado: cai pro SceneLayer do ato
            sceneKey = SceneLayer.sceneKeyForAct(currentAct)
            sceneH = height - topBarHeight
            SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)
        else
            -- luz nas chamas pintadas, névoa no chão, vinheta e partículas
            -- de trás — tudo ATRÁS do chefe (ver InteriorFX)
            InteriorFX.draw(hallAct)
            interiorHall = hallAct
            -- entrada do chefe: escuridão, olhos no vão, rasantes com rastro
            -- (atrás de onde o chefe vai pousar)
            BossCinematic.drawBack()
        end
    elseif GameplayScene.SCENE_MODE == "worldroad" then
        -- Endless: biomas extras (4+) ciclam a cada 8 andares via currentFloor
        local biomeIdx = currentAct
        if run and run.endlessMode then
            biomeIdx = 4 + math.floor(math.max(0, (run.currentFloor or 25) - 25) / 8)
        end
        WorldRoad.draw(0, topBarHeight, width, height - topBarHeight, biomeIdx)
    else
        sceneKey = SceneLayer.sceneKeyForAct(currentAct)
        sceneH = height - topBarHeight
        SceneLayer.draw(0, topBarHeight, width, height - topBarHeight, currentAct)
    end

    -- Inimigo: no battle da estrada já foi desenhado DENTRO do WorldRoad.draw
    -- (callback no eixo BATTLE_REL — props próximos na frente dele). Aqui só
    -- os outros casos: interior (hall estático) e SceneLayer legado. Na
    -- viagem o inimigo é billboard do WorldRoad (não desenha aqui).
    if not traveling and not worldBattle and not entering then
        -- v11: o pé do inimigo pousa na LAJE da cena, não em height*0.68
        -- (número fixo herdado do castle_hall_1 — no hall do ato 2 essa
        -- linha cai na PAREDE e o chefe ficava pairando; defeito reportado
        -- Set/2026). A cena também diz a força e a direção da sombra.
        local anchor = SceneAnchors.get(sceneKey)
        enemyCx, enemyCy = SceneAnchors.groundAnchor(sceneKey, width, sceneH)
        local artCy = enemyCy

        -- PALCO (ver STAGE_CLEARANCE): o chefe recua na laje até sair de
        -- trás da carta em hover — mas só até a BORDA DE TRÁS do piso
        -- (backYr): além dela ele pisaria degrau/parede. Na maioria dos
        -- salões a laje acaba antes da zona da carta, então o recuo é
        -- parcial: "um pouquinho mais longe", o que a arte deixa.
        local _, backY = SceneAnchors.groundAnchor(sceneKey, width, sceneH,
            anchor.backYr or anchor.yr)
        local stageY = stageYReal
        if enemyCy > stageY then enemyCy = math.max(backY, stageY) end

        -- TETO DA MAO: o pe nunca pousa abaixo do topo das cartas.
        --
        -- A linha de chao e dado da ARTE (cada PNG tem o piso onde o artista
        -- pos), e no `castle_hall_2` a laje so comeca em 83% da altura --
        -- enquanto a mao comeca em 80% (`handLayout`). O chefe do ato 2
        -- nascia com o pe 3% ABAIXO do topo das cartas e a metade de baixo
        -- dele ficava atras delas ("boss 2 esta ficando muito la embaixo, as
        -- cartas estao na frente dele" -- dono, Set/2026).
        --
        -- Subir o pe e melhor que encolher o inimigo: o chefe perde presenca
        -- se diminuir, e a laje do hall 2 vai de ~0,78 ate a base da tela, ou
        -- seja, o pe continua na PEDRA depois do corte. A sombra de contato
        -- acompanha (e desenhada no mesmo cy), entao a leitura de "esta no
        -- chao" nao se perde.
        --
        -- Vale pra qualquer cena e qualquer inimigo: e a mao que define ate
        -- onde o mundo pode descer, e ela e responsiva.
        local tetoY = math.floor(handTopReal - ENEMY_HAND_CLEARANCE * uiK)
        if enemyCy > tetoY then enemyCy = tetoY end
        -- salão: poça de oclusão em degraus sob os pés (contato com o piso),
        -- ANTES do chefe (require inline: estado do salão fica no módulo)
        local InteriorDepth = interiorHall and require("src.ui.InteriorDepth")
        -- CHEFE AINDA NÃO POUSOU (BossCinematic): nada dele chega à tela —
        -- o draw roda num canvas descartado só pra MEDIR onde ele vai ficar
        -- (bbox + canto do sprite), que é onde o rasante final termina.
        local cineHidden = BossCinematic.hidesBoss()
        if InteriorDepth and not cineHidden then
            InteriorDepth.drawContact(interiorHall, game.enemy and game.enemy.spriteId,
                enemyCx, enemyCy)
        end
        -- CHÃO DO CADÁVER (scene_anchors.deathYr): onde quem voa CAI ao
        -- morrer. No salão 2 a linha do vivo é a faixa estreita colada na
        -- base da parede — o corpo deitado ali lia "em cima da balaustrada";
        -- o piso andável fica à frente. Sem deathYr, é a linha do vivo.
        local deathCy = nil
        if anchor.deathYr then
            local _, dy = SceneAnchors.groundAnchor(sceneKey, width, sceneH,
                anchor.deathYr)
            deathCy = math.max(enemyCy, dy)
        end
        corpseUnderHand = deathCy ~= nil and deathCy > tetoY
        local function drawEnemy()
            return EnemyRenderer.draw(game, enemyCx, enemyCy, {
                deathCy = deathCy,
                shadowA = anchor.shadowA,
                lightXr = anchor.lightXr,
                -- quem recuou no piso encolhe pela perspectiva do chão
                sizeK = GameplayScene.bossSizeK(
                    SceneAnchors.depthSizeK(sceneKey, width, sceneH, artCy,
                        enemyCy, WorldRoad.ENEMY_SIZE_PERSP) * GameplayScene.hallScreenK(sceneKey, width, sceneH),
                    height - topBarHeight),
            })
        end
        if cineHidden then
            enemyBbox = BossCinematic.measure(drawEnemy)
        else
            enemyBbox = drawEnemy()
        end
        if InteriorDepth then InteriorDepth.noteBbox(enemyBbox) end
        if interiorHall then
            -- palco da cinemática (medido NESTE frame) + poeira/corvos/penas
            -- na frente do chefe
            BossCinematic.setStage({
                cx = enemyCx, cy = enemyCy, bbox = enemyBbox or nil,
                foot = EnemyRenderer.getLastFoot(), hall = interiorHall,
                w = width, h = height, backY = backY, artCy = artCy,
                tr = SceneBackground.getCoverTransform(sceneKey, width, sceneH),
            })
            BossCinematic.drawFront()
        end
        -- clima mais próximo (neve/cinza/esporos) passa NA FRENTE do chefe
        if interiorHall then InteriorFX.drawFront(interiorHall, topBarHeight) end
    end

    -- LightEngine v1: composite multiply do lightmap sobre mundo+inimigo,
    -- ANTES de qualquer UI (EnemyHud/gameUI/mão ficam fora da luz). O fork
    -- overlay (pills) vem junto, DEPOIS do composite (revisão F-10).
    if GameplayScene.SCENE_MODE == "worldroad" and not interior then
        WorldRoad.drawOverlays(0, topBarHeight, width, height - topBarHeight)
    end
    if zk then love.graphics.pop() end
    if worldPass then BossCinematic.endWorldPass() end
    end)
    if GameplayScene.WORLD_ONLY then return end
    -- ENTRADA DO CHEFE: o salão abre VAZIO — HUD do inimigo, painel do herói,
    -- mão, botões e coringas esperam o nome do chefe (BossCinematic.hidesHud).
    -- No salão o HUD também espera a DISTRIBUIÇÃO das cartas (HandDeal:
    -- cartas primeiro, botões e HUD depois — ordem de mesa).
    local cineHide = BossCinematic.hidesHud() or HandDeal.hidesHud()
    -- mão/botões/coringas/prévia somem na ENTRADA e na MORTE (na morte o
    -- HUD de vida fica: o corpo caindo é o que se vê, não há o que jogar)
    -- e atrás da CORTINA (viagem, porta, salão à espera do chefe).
    local cineHand = BossCinematic.hidesHand() or HandDeal.hidesHand()
    -- botões, coringas, prévia e toasts esperam a última carta ser dada
    local uiWait = cineHand or HandDeal.hidesUI()
    -- pilha do deck: onde as cartas ainda não dadas esperam
    local deckX, deckY = game:getDeckOrigin()
    -- ===== UI (espaço virtual) =====
    -- O bbox do inimigo veio em pixels da tela: o HUD dele mora na UI.
    if enemyBbox and uiK ~= 1 then
        enemyBbox = { cx = enemyBbox.cx / uiK, topY = enemyBbox.topY / uiK,
            bottomY = enemyBbox.bottomY / uiK, width = enemyBbox.width / uiK,
            height = enemyBbox.height / uiK }
    end
    if enemyCx then enemyCx, enemyCy = enemyCx / uiK, enemyCy / uiK end
    topBar:draw()

    -- TETO DO HOVER: no salão a laje limita o recuo do chefe, e a carta
    -- levantada cobria o corpo dele (lich do ato 2). A carta sobe só até
    -- o pé do inimigo — mas sempre o bastante pra aparecer INTEIRA (o
    -- leque fica com parte da carta abaixo da tela). Na estrada o palco já
    -- garante o pé acima do topo da carta, então o teto não morde.
    local hoverLift = HOVER_LIFT * handScale()
    if enemyBbox and not traveling and not entering
        and game.enemy and not game.enemy:isDefeated() then
        local _, _, cardY0 = handLayout()
        local cardH = 144 * (Config.Cards.BASE_SCALE or 1.333) * handScale()
        -- + 8% da carta: o hover cresce a carta (HOVER_SCALE_MULT) a partir do centro
        local minLift = math.max(0, cardY0 + cardH * 1.08 - height) + 6
        local footCap = cardY0 - enemyBbox.bottomY - 6
        hoverLift = math.max(minLift, math.min(hoverLift, footCap))
    end

    if not traveling and not entering and not cineHide then
        EnemyHud.draw(game, enemyBbox, enemyCx, enemyCy)
        -- âncoras do narrador do tutorial: o corpo e a barra de vida
        if enemyBbox and game.enemy and not game.enemy:isDefeated() then
            local T = require("src.systems.Tutorial")
            T.anchor("enemy", enemyBbox.cx - enemyBbox.width / 2, enemyBbox.topY,
                enemyBbox.width, enemyBbox.bottomY - enemyBbox.topY)
            local hp = EnemyHud.hpBarRect(EnemyHud.layout(game, enemyBbox, enemyCx, enemyCy))
            if hp then T.anchor("enemy_hp", hp.x, hp.y, hp.w, hp.h) end
        end
        -- previa: o trecho da vida que a leva selecionada arranca
        if game.enemy and not game.enemy:isDefeated() then
            DamagePreviewPanel.drawEnemyGhost(game,
                EnemyHud.hpBarRect(EnemyHud.layout(game, enemyBbox, enemyCx, enemyCy)))
        end
    end

    if not cineHide then gameUI:draw(game) end

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
        -- descrição AO LADO da carta em hover (ver STAGE_CLEARANCE)
        card.tooltipSide = true
        -- tooltip no passe FINAL da cena (acima dos selos +COMBO, da prévia
        -- e dos toasts) — ver Card.deferTooltip / drawDeferredTooltip
        card.deferTooltip = true
        -- LB/RB do pad andam DENTRO da mão (NavCursor.cycle)
        card.navGroup = "hand"
        if card.isSelected then offsetY = -100 * handScale() end
        local rIdx = renderIdxFor(i)
        local tx = cardStartX + (rIdx - 1) * cardSpacing
        local ty = cardY + offsetY
        -- inimigo morto com o cadáver caindo ATRÁS da mão (chão do cadáver
        -- abaixo do topo das cartas, salão 2): a mão desce e sai da tela —
        -- a luta acabou e o corpo no chão é o que se quer ver.
        if corpseUnderHand and game.enemy and not game.enemy:isAlive() then
            ty = ty + height * 0.5
        end
        if card == hoverCard and not draggingCard then
            ty = cardY - hoverLift
        end
        if HandDeal.holds(card) then
            -- ainda na pilha: espera a vez dela (sai voando da pilha ao ser dada)
            card:setRenderPos(deckX, deckY)
        elseif card.isDragging then
            local mx, my = love.mouse.getPosition()
            card:setRenderPos(mx + card.dragOffsetX, my + card.dragOffsetY)
        else
            card:setTargetPos(tx, ty)
            card:updateRender(dt)
        end
    end

    -- v10.5: durante a CERIMÔNIA de entrada no castelo (porta abrindo +
    -- fade) a mão NÃO é desenhada — é cutscene, não turno. Mesma convenção
    -- do EnemyHud acima. Layout/updateRender continuam rodando de propósito:
    -- a mão não congela nem salta quando a cerimônia termina.
    if not entering and not cineHand then
        -- Desenha não-dragadas (ordem normal), depois hover, depois dragged por cima
        for _, card in ipairs(game.hand) do
            if not card.isDragging and card ~= hoverCard and not HandDeal.holds(card) then
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
    end

    -- v7.4.14: fumaça ambiente SÓ nos interiores de castelo — na ESTRADA
    -- aberta os fiapos translúcidos gigantes (escala 2×, cruzando a tela)
    -- liam como "3 linhas subindo e descendo" (feedback; o demo não roda
    -- smoke e ficava bom; CRT on/off não mudava = era isto). Véu
    -- translúcido sobre a cena pixel art é anti-pattern do projeto.
    local roadOutdoor = GameplayScene.SCENE_MODE == "worldroad"
        and not lastInterior
    if smokeSystem and not roadOutdoor then smokeSystem:draw() end
    if not uiWait then
        playButton:draw()
        if endTurnButton then endTurnButton:draw() end
    end
    -- Ações de contexto do teclado/pad (NavCursor): Y/E joga a seleção,
    -- X/Q encerra o turno — o glifo mora no canto do próprio botão.
    if not uiWait then
        local NavCursor = require("src.ui.NavCursor")
        local function press(btn)
            return function()
                if btn and btn.visible ~= false and not btn.disabled and btn.onClick then
                    btn.onClick()
                end
            end
        end
        NavCursor.action("y", press(playButton), playButton.x, playButton.y,
            playButton.width, playButton.height)
        if endTurnButton then
            NavCursor.action("x", press(endTurnButton), endTurnButton.x, endTurnButton.y,
                endTurnButton.width, endTurnButton.height)
        end
    end

    -- PREVIA DE DANO (Out/2026): banda de ACAO da coluna direita, colada em
    -- cima do JOGAR — o numero que o clique vai produzir mora no botao que o
    -- produz. Selos "+COMBO" ficam NA carta que fecharia o combo.
    if not entering and not uiWait then
        DamagePreviewPanel.drawHandBadges(game)
        DamagePreviewPanel.draw(game,
            { x = playButton.x, y = playButton.y, w = playButton.width },
            topBarHeight + 8)
    end

    -- Chamariz do ENCERRAR TURNO (sem mana e nada selecionado): aro dourado
    -- pulsante + seta quicando — "sua próxima ação é aqui".
    if GameplayScene._endTurnCallout and endTurnButton and not uiWait then
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
    -- toasts ficam na FILA durante a cinemática (sem tick, sem desenho):
    -- "carta desbloqueada" por cima do chefe caindo quebrava a cena
    if game.messageSystem and not uiWait then game.messageSystem:draw() end

    if not uiWait then drawJokersAsCards() end
    GameplayScene._reportTutorialAnchors()

    -- Banner de COMBO: DEPOIS da mão e depois do combatAnimationSystem (que
    -- drawJokersAsCards desenha no fim) — as cartas do turno passavam por
    -- cima dele e "não dava nem pra ler" (feedback do dono, Set/2026).
    ComboBanner.draw(topBarHeight)

    -- PASSE FINAL: o tooltip da carta em hover vem por cima de TUDO da mão
    -- (selos "+COMBO" das vizinhas, prévia de dano, toasts, quadro de
    -- coringas) — antes era desenhado junto da própria carta e o que vinha
    -- depois o cobria. Quadro sem hover: nada pendente.
    for _, card in ipairs(game.hand) do
        if card.drawDeferredTooltip then card:drawDeferredTooltip() end
    end

    -- cartão com o nome do chefe + dica de pular (por cima da UI, por baixo
    -- dos fades)
    BossCinematic.drawUI()

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
    -- Um overlay tomou o foco (pausa, deck, coringas...): SOLTA a carta em
    -- arrasto. Sem isto ela continuaria colada num mouse que, pra esta
    -- camada, agora lê fora da tela (src/ui/InputFocus) — e sumiria da mão
    -- enquanto o menu estivesse aberto. Soltar devolve ela ao layout.
    if not InputFocus.allows(InputFocus.SCENE) then
        for _, card in ipairs((game and game.hand) or {}) do
            card.dragPending = false
            card.isDragging = false
        end
    end

    updatePlayButtonPosition()
    TurnBanner.update(dt)
    ComboBanner.update(dt)

    game.combatAnimationSystem:update(dt)

    -- Encerrar Turno clicado DURANTE a animação: fica na fila e executa
    -- assim que a jogada termina (antes era engolido em silêncio).
    if game._endTurnQueued and game.turn == "player"
        and not game.combatAnimationSystem:isBlocking() then
        game._endTurnQueued = false
        game:endTurn()
    end

    -- Partículas são tickadas centralmente em main.lua via CardParticles.update.

    -- Cinemática do chefe (entrada/morte): relógio próprio, ANTES do
    -- EnemyRenderer — a câmera lenta da morte é a escala do dt dele neste
    -- frame. `inHall` decide se a morte vira cinemática (o mini-boss também
    -- tem isBoss, mas luta na estrada).
    do
        local runC = game.runManager and game.runManager.currentRun
        local ntC = runC and runC.currentNode and runC.currentNode.type
        BossCinematic.update(dt, game, { inHall = GameplayScene.inBossRoom(ntC) })
    end
    UiScale.outside(EnemyRenderer.update, dt)
    -- FX de interior (tochas) tickam quando o node atual é de castelo;
    -- transição estrada↔interior dispara fade de entrada (portão)
    do
        local runU = game.runManager and game.runManager.currentRun
        local ntU = runU and runU.currentNode and runU.currentNode.type
        -- Mesma fonte que o draw (isInteriorNode). O `not isEntering`
        -- cobre o frame de transição da cerimônia da porta.
        local isInt = GameplayScene.isInteriorNode(ntU, bossEntered)
            and not (GameplayScene.SCENE_MODE == "worldroad"
                     and WorldRoad.isEntering())
        if isInt then
            UiScale.outside(InteriorFX.update, dt, InteriorFX.hallFor((runU and runU.actNumber) or 1))
        end
        if lastInterior ~= nil and isInt ~= lastInterior then
            interiorFade = 1
            if isInt then
                InteriorFX.clear()
                require("src.ui.InteriorDepth").reset()
            end
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
        UiScale.outside(WorldRoad.update, dt)
        -- o palco vale ANTES da viagem: o encontro nasce em camZ+dist+palco
        syncBattleStage()
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
                            onComplete = GameplayScene._onBossEntered,
                        })
                    end,
                })
            else
                -- batalha comum, ELITE e MINI-BOSS (v10.1: "do lado de fora
                -- do castelo, sem aquele background"; v11: o elite entrou
                -- nesta lista): o inimigo vem lá de trás pela estrada; na
                -- chegada, quicadas de aterrissagem.
                WorldRoad.travel({
                    encounter = EnemyRenderer.getEncounterBillboard(game.enemy),
                    onComplete = function() EnemyRenderer.triggerArrival() end,
                })
            end
        end
        lastFloorKey = floorKey
    else
        UiScale.outside(SceneLayer.update, dt)
    end

    -- CORTINA DA MÃO (Out/2026, bug do dono: mão/botões/HUD apareciam no
    -- meio da porta e da entrada do chefe). Abaixada em toda cutscene:
    -- viagem na estrada, cerimônia da porta, salão à espera do chefe,
    -- entrada/morte do chefe e a quicada de chegada. Quando sobe, as cartas
    -- são DADAS uma a uma e só depois entram botões e HUD (HandDeal). No
    -- caminho do castelo (porta + salão) o HUD espera junto. Avaliada
    -- DEPOIS do gatilho da viagem acima: o andar novo já nasce atrás dela.
    do
        local runH = game.runManager and game.runManager.currentRun
        local ntH = runH and runH.currentNode and runH.currentNode.type
        local wr = GameplayScene.SCENE_MODE == "worldroad"
        local entering = wr and WorldRoad.isEntering()
        local bossWait = wr and ntH == "boss" and not bossEntered
        local arriving = EnemyRenderer.getArrivalOffset
            and EnemyRenderer.getArrivalOffset() ~= 0
        local down = (wr and WorldRoad.isTraveling()) or entering or bossWait
            or BossCinematic.isActive() or arriving or false
        HandDeal.setCurtain(down, game,
            { hud = entering or GameplayScene.inBossRoom(ntH) })
        HandDeal.update(dt, game)
    end

    -- CHECKPOINT DA MORTE (Set/2026): antes de qualquer gate de desfecho, o
    -- inimigo morto que ainda nao foi encenado vira acontecimento. E a mesma
    -- rede do `enemy.enrage_check` do turno do inimigo — nenhuma fonte de dano
    -- pode entregar um cadaver direto pra tela de espolios.
    game:announceDeathIfPending(nil)

    -- O relogio da morte corre ANTES dos gates: e ele que segura tanto os
    -- espolios quanto a VITORIA (queixa do dono: "a tela de vitoria ta
    -- aparecendo rapido demais, so aparece quando a gente tem a confirmacao
    -- que ele morreu").
    if game._deathPauseTimer and game._deathPauseTimer > 0 then
        game._deathPauseTimer = math.max(0, game._deathPauseTimer - dt)
    end

    -- Transições de estado (game over / victory). Retorna true se mudou
    -- (caller deve fazer early return pra não rodar resto do frame).
    -- Game over NAO espera a morte do inimigo: quem caiu foi o jogador, e o
    -- respiro dele e a propria TV desligando.
    if game:checkGameOver() and not game.combatAnimationSystem:isBlocking() then
        Sfx.play("runDefeat")
        setCurrentState("gameOver")
        return
    end

    -- Vitoria (boss do ato final) espera a MESMA coisa que os espolios: a
    -- criatura cair na tela. `isReadyForEndScreen` = combate parado (inclui a
    -- fila de beats) E morte assentada. A regra mora no Game pra ser testavel.
    -- Morte de CHEFE: a cinemática (câmera lenta, rajada, corpo no salão)
    -- segura espólios e vitória até terminar — BossCinematic.holdsEnd.
    if game:checkVictory() and game:isReadyForEndScreen()
        and not BossCinematic.holdsEnd() then
        Sfx.play("runVictory")
        setCurrentState("victory")
        return
    end

    if game:isPhaseCleared() and game:isReadyForEndScreen()
        and not BossCinematic.holdsEnd() then
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
        -- inimigo terminou de agir (investida no ar conta como agindo).
        -- `_enemyActing` (Set/2026): o turno do inimigo virou uma CADEIA de
        -- beats e `isBlocking()` passa a ser true durante ela — sem este
        -- check o ramo de cima deixa de rodar e o banner do JOGADOR subia
        -- antes do inimigo sequer golpear. A flag só cai no beat final.
        local attacking = EnemyRenderer.isAttacking and EnemyRenderer.isAttacking()
        if not attacking and not game._enemyActing then
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
    -- atrás da cortina / durante a distribuição não há carta pra apontar
    local handClosed = HandDeal.isBusy()
    for i, card in ipairs(game.hand) do
        card.index = i
        local allowHover = (not anyDragging) and (hoverCard == nil) and not handClosed
        card:updateMouse(mx, my, dt, allowHover)
        if card.isHovered then hoverCard = card end
    end

    playButton:update(dt)
    if endTurnButton then endTurnButton:update(dt) end

    -- Previa de dano da selecao (+ carta em hover) — ver DamagePreviewPanel.
    DamagePreviewPanel.update(game, hoverCard, dt)

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
        -- cartas ainda sendo dadas: nada é jogável nem auto-encerra
        local myTurn = game.turn == "player" and not blocking and not handClosed
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
            and not TurnBanner.isActive()
            and not require("src.systems.Tutorial").holdsTurn() then
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

    if game.messageSystem and not BossCinematic.isActive() then
        game.messageSystem:update(dt)
    end
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
    -- entrada/morte do chefe: clique PULA (depois de 1s) e nada passa. No
    -- jogo o InputFocus já entrega o clique ao overlay dela; isto cobre
    -- quem chama a cena direto (ferramentas, testes).
    if BossCinematic.lockInput() then
        if button == 1 then BossCinematic.skip() end
        return true
    end
    -- v9.7.1: retorna se CONSUMIU o clique — o que sobrar vira poke no
    -- cenário do WorldRoad (main.lua → pokeSceneAt, mapa vivo)
    if topBar:mousepressed(x, y, button) then return true end

    -- Cortina abaixada ou cartas sendo dadas: não há botão, coringa nem
    -- carta pra clicar (a carta invisível ainda está na mão lógica — sem
    -- isto um clique cego a selecionava). O clique segue pro cenário.
    if HandDeal.isBusy() then return false end

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
    -- Atalhos de DESENVOLVIMENTO (reiniciar batalha, presets de fumaça) só
    -- existem no modo clássico. Numa RUN eles eram armadilha: "R" rodava
    -- game:startGame() — player novo (vida/mana máximas perdidas), ouro 10,
    -- inimigo base do ato 1 no lugar do chefe — e o checkpoint seguinte
    -- gravava isso. Os números trocavam a fumaça em silêncio. (Revisão de
    -- lançamento, Out/2026.) O "f" de tela cheia saiu de vez: alternava sem
    -- love.resize (layout velho) e sem gravar a preferência — o caminho certo
    -- é Configurações → Tela cheia.
    if key == "escape" then
        onReturnToMenu()
        return
    end
    -- cinemática do chefe: Enter/Espaço pulam, o resto não passa
    if BossCinematic.lockInput() then
        if key == "return" or key == "kpenter" or key == "space" then
            BossCinematic.skip()
        end
        return
    end
    if game and game.isRunMode then return end
    -- Atalhos de DEV (restart e presets de smoke) nao existem no jogo publicado.
    local dev = require("src.core.Release").isDev()
    if not dev and (key == "r" or key == "0" or key == "1" or key == "2"
                    or key == "3" or key == "4") then
        return
    end
    if key == "r" then
        game:startGame()
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
    end
end

-- Âncoras das dicas do tutorial (src/systems/Tutorial): mão, JOGAR, ENCERRAR
-- TURNO e o quadro de coringas, reportados no MESMO espaço em que acabaram de
-- ser desenhados (o Tutorial converte pra pixels reais).
function GameplayScene._reportTutorialAnchors()
    if not game then return end
    local Tutorial = require("src.systems.Tutorial")
    local x1, y1, x2, y2
    for _, c in ipairs(game.hand or {}) do
        if c.renderX and c.renderY then
            local cw = (c.image and c.image.getWidth and c.image:getWidth() or 96)
                * (c.scale or c.baseScale or 1.333)
            local ch = (c.image and c.image.getHeight and c.image:getHeight() or 144)
                * (c.scale or c.baseScale or 1.333)
            x1 = math.min(x1 or c.renderX, c.renderX)
            y1 = math.min(y1 or c.renderY, c.renderY)
            x2 = math.max(x2 or (c.renderX + cw), c.renderX + cw)
            y2 = math.max(y2 or (c.renderY + ch), c.renderY + ch)
        end
    end
    if x1 then Tutorial.anchor("hand", x1, y1, x2 - x1, y2 - y1) end
    if playButton then
        Tutorial.anchor("play", playButton.x, playButton.y, playButton.width, playButton.height)
    end
    if endTurnButton then
        Tutorial.anchor("end_turn", endTurnButton.x, endTurnButton.y,
            endTurnButton.width, endTurnButton.height)
    end
    local g = jokerFrameGeometry()
    if g and g.w and g.w > 0 then Tutorial.anchor("jokers", g.x, g.y, g.w, g.h) end
end

return GameplayScene
