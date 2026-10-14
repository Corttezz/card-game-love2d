---
name: code_notes/src/scenes/GameplayScene.lua
description: Comentários com decisão/regra/histórico colhidos de src/scenes/GameplayScene.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/scenes/GameplayScene.lua`

Origem: `src/scenes/GameplayScene.lua` em `7dbdb60d` (113 de 172 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Config           = require("src.core.Config")`)

> src/scenes/GameplayScene.lua
> Scene do estado "playing": draw/update/input do combate + mão + jokers.
> Extraído de main.lua (era ~400 LOC de drawGame/updateGame/handlers).
>
> ARQUITETURA: recebe deps externas (game, playButton, topBar, gameUI, smokeSystem)
> via init() — armazenadas no módulo. hoverCard é state interno da scene.
>
> Pode sinalizar transições de estado via callback deps.setCurrentState(name)
> passado por main.lua (evita acoplar state machine aqui).

## L27-32 (junto a `local UiScale          = require("src.ui.UiScale")`)

> ESCALA DE UI (Out/2026): a cena é ADOTADA pelo UiScale — mão, HUD, botões,
> quadro de coringas e toasts vivem no espaço virtual (~1280x720, scale k).
> O MUNDO (WorldRoad / salão / inimigo) NÃO: ele já escala com a janela, e
> roda dentro de UiScale.outside com a janela real. Fronteira: o bbox do
> inimigo volta dividido por k pro HUD; o limite do palco vai multiplicado
> por k pro WorldRoad. Ver memory/ui_scale.md.

## L34-36 (junto a `local BossCinematic    = require("src.ui.BossCinematic")`)

> Cinemática do chefe (Out/2026): entrada no salão vazio + morte em câmera
> lenta. A cena pergunta a ela o que esconder (chefe/HUD) e quando os
> espólios podem entrar — ver src/ui/BossCinematic.lua.

## L38-40 (junto a `local HandDeal         = require("src.ui.HandDeal")`)

> Cortina da mão + distribuição das cartas depois de toda cutscene (viagem,
> porta, entrada do chefe): a mão, os botões e o HUD só existem quando há
> luta — ver src/ui/HandDeal.lua.

## L45-46 (em `GameplayScene`, junto a `GameplayScene.SCENE_MODE = "worldroad"`)

> Modo de cenário: "worldroad" (mundo rolante, estilo Path of Kings) ou
> "scene" (SceneLayer com PNG estático por ato — comportamento antigo).

## L55-58 (em `GameplayScene`, junto a `local pendingArrival = false`)

> CHEGADA DA PRIMEIRA LUTA (dono, 13/Out: "quando clica em Jogar a tela já
> é o inimigo na frente com as cartas, sem nenhuma animação"): a run NOVA
> pede a mesma viagem/chegada/cortina de todo andar. Só o `startGame` do
> main.lua liga (Continuar NÃO: resumeWorld ancora o andar e não repete).

## L62-66 (em `GameplayScene`, junto a `local bossEntered = false`)

> v10.4: no BOSS o interior (sala) só existe DEPOIS que a cerimônia da porta
> terminou. Antes, durante a viagem de aproximação (entering ainda false), o
> interior já era true → mostrava a sala do boss ANTES da cutscene, depois a
> porta, depois a sala de novo (ordem quebrada). Este flag segura a sala até
> o fade da porta completar. Resetado quando um novo andar de boss começa.

## L71-76 (em `GameplayScene`, junto a `local turnStage = nil`)

> Coreografia de turno (clareza do ritmo): banner "TURNO DO INIMIGO" →
> pausa → inimigo age (investida) → banner "SEU TURNO". Estados:
> nil      = turno do jogador correndo
> "banner" = anunciando o turno inimigo (timer)
> "acting" = inimigo agindo (espera a investida terminar)
> (declarado AQUI no topo pra setGame/resetTurnState enxergarem a local)

## L92-102 (em `GameplayScene.init`, junto a `function GameplayScene.isInteriorNode(nodeType, entered)`)

> QUEM LUTA DENTRO DO CASTELO — fonte ÚNICA da decisão (draw e update
> perguntam aqui). Só o BOSS, e só depois da cutscene da porta.
>
> v11 (Set/2026, feedback do dono: "elite indo pro mesmo cenário do castelo
> do endgame não faz sentido"): o hall é o CLÍMAX do ato — é o pagamento da
> cerimônia da porta. O elite acontece 2-3x por ato, sem viagem e sem
> porta; mandá-lo pro mesmo salão gastava o clímax antes da hora e
> contradizia o próprio mundo (você nunca entrou em castelo nenhum). A
> estrada já sabe dizer "isto é um elite" (marco landmark_elite com luz
> roxa no fork), e o MINI-BOSS — que usa o MESMO sprite do elite no roster
> — sempre brigou lá fora: ter os dois em cenas diferentes era incoerente.

## L112-114 (em `GameplayScene.inBossRoom`, junto a `function GameplayScene.isQuiet()`)

> A cena está QUIETA? (tutorial: o narrador só fala com tudo parado) —
> sem viagem, sem cerimônia da porta (no chefe, só depois dela), sem banner
> de turno, sem investida nem pouso do inimigo.

## L137-139 (em `GameplayScene.isQuiet`, junto a `function GameplayScene._debugForceBossEntered()`)

> Só pra ferramentas de captura: salta a cerimônia da porta e mostra o
> salão do chefe direto (tools/screenshot_enemy_scene.lua). Nunca chamado
> pelo jogo — a cutscene é parte do clímax.

## L144-147 (em `GameplayScene._debugForceBossEntered`, junto a `function GameplayScene._onBossEntered()`)

> A PORTA TERMINOU DE ABRIR: o salão passa a existir e a ENTRADA do chefe
> toca dentro dele (src/ui/BossCinematic — chefe sem roteiro luta direto).
> Só a cerimônia chama isto; o Continuar usa _debugForceBossEntered, de
> propósito: retomar dentro da luta é retomar NA luta, sem repetir a entrada.

## L153-154 (em `GameplayScene._onBossEntered`, junto a `function GameplayScene._debugStartBossIntro()`)

> Ferramentas/testes: salão aberto E entrada tocando (prova visual da
> cinemática sem passar pela viagem e pela porta).

## L159 (em `GameplayScene._debugStartBossIntro`, junto a `function GameplayScene.setSmokeSystem(s) smokeSystem = s end`)

> Seta smokeSystem depois de init (usado quando smoke muda em runtime).

## L162-167 (em `GameplayScene.setSmokeSystem`, junto a `function GameplayScene.setGame(g)`)

> REBIND do game (bug "abandonei e caí na run antiga", Jul/2026):
> returnToMenu cria um Game NOVO, mas esta cena capturava deps.game numa
> local de módulo — a tela continuava desenhando/atualizando o game morto
> enquanto os botões agiam no novo (mão fantasma, nenhuma carta jogável).
> Todo rebind passa por aqui, que também zera o estado de turno POR RUN
> do módulo (turnStage/bossEntered sobreviviam entre runs).

## L171-173 (em `GameplayScene.setGame`, junto a `WorldRoad.resetRun()`)

> O CENÁRIO também é estado de módulo e sobrevivia ao abandono:
> o mundo voltava com bioma/câmera/viagem da run morta, e um attackFx
> pendente do inimigo antigo podia disparar o apex dentro da run nova.

## L186-187 (em `GameplayScene.resetTurnState`, junto a `lastFloorKey = nil`)

> Sem isto, o 1º frame da run NOVA compararia com o andar da run
> MORTA e dispararia uma viagem/chegada espúria na estrada.

## L191-206 (em `GameplayScene.resetTurnState`, junto a `function GameplayScene.resumeWorld(g)`)

> CONTINUAR uma run salva: devolve o MUNDO ao ponto do save E ancora o
> andar da cena. Mora aqui (e não no main.lua) porque `lastFloorKey` — o
> gatilho da caminhada até o próximo encontro — é estado DESTE módulo:
> restaurar o mundo sem ancorar o andar deixa as duas metades em
> desacordo.
>
> O bug que isto mata (Set/2026, "a bandeira não sai da frente do primeiro
> inimigo"): o save feito NA ENCRUZILHADA guarda o andar JÁ avançado
> (showMapSelection chama advanceFloorInAct ANTES de montar o fork), mas a
> caminhada até esse andar ainda não aconteceu — o mundo pertence ao andar
> ANTERIOR. Como o Continuar vinha do menu (setGame ⇒ lastFloorKey = nil),
> o primeiro andar depois de retomar era lido como "início de run" e
> NENHUMA viagem disparava. Sem a viagem, o marco plantado pela
> convergência do fork (landmark_battle — um estandarte vermelho) ficava
> parado em ARRIVE_REL 7.5, à frente do inimigo em BATTLE_REL 9 e desenhado
> depois dele: a bandeira em cima do monstro, pra sempre.

## L215-217 (em `GameplayScene.resumeWorld`, junto a `lastFloorKey = act .. ":" .. (atFork and (floor - 1) or floor)`)

> Âncora que o detector de troca de andar compara. Na encruzilhada é
> floor-1 DE PROPÓSITO (pode dar 0 quando o ato acabou de virar): o nó
> escolhido sempre lê como troca de andar e a caminhada acontece.

## L222-223 (em `GameplayScene.resumeWorld`, junto a `function GameplayScene.requestArrival() pendingArrival = true end`)

> Run NOVA (main.lua startGame): a primeira luta chega pela estrada como
> qualquer andar (inimigo emerge da curva, quicada, cortina, cartas dadas).

## L227 (em `GameplayScene.hasPendingArrival`, junto a `function GameplayScene.getGame() return game end`)

> Introspecção pra testes de regressão (smoke_ui_turn).

## L231-233 (em `GameplayScene.getFloorAnchor`, junto a `local function updatePlayButtonPosition()`)

> ============================================================================
> INTERNAL: posicionamento
> ============================================================================

## L240-242 (em `updatePlayButtonPosition`, junto a `local buttonY = love.graphics.getHeight() * 0.62`)

> Feedback Jul/2026: os botões batiam na mão quando o deck crescia. Foram
> SUBIDOS (0.72 → 0.62) e a mão agora é "espremida" numa área que termina
> antes deles (ver handLayout) — dupla garantia contra sobreposição.

## L255-270 (em `updatePlayButtonPosition`, junto a `local ENEMY_HAND_CLEARANCE = 12`)

> ============================================================================
> LAYOUT DA MÃO (fanning + squeeze estilo Balatro)
> ============================================================================
> Balatro (cardarea.lua:align_cards) distribui a mão numa ÁREA de largura fixa:
> o espaçamento vira areaW/(n-1), então quantas mais cartas, mais elas se
> sobrepõem ("espremem") — nunca estouram a área. A carta em hover sobe e é
> desenhada por cima das vizinhas (já feito no draw). Portamos a mesma ideia:
> a mão fica CENTRADA na tela, mas com a largura do leque LIMITADA pra terminar
> antes dos botões de ação (à direita), com folga de meia-carta.
>
> Retorna: startX (x TOP-LEFT da 1ª carta), spacing, cardY, n (#mão).
> IMPORTANTE: Card:draw trata (x,y) como CANTO SUPERIOR-ESQUERDO (o centro é
> x + imgW/2), então o leque é centrado VISUALMENTE numa área que exclui a
> coluna dos botões — nunca invade a direita.
> Folga entre o pe do inimigo e o topo da mao. 12px: o bastante pra sombra de
> contato respirar sem o inimigo parecer levitando acima do piso.

## L274-279 (em `updatePlayButtonPosition`, junto a `GameplayScene.HAND_GROWTH = 0.5`)

> ESCALA DA MÃO (Out/2026): a UI inteira escala k (UiScale), mas a mão
> cresce MAIS DEVAGAR — handK = 1 + (k-1)/2 (1.25 em 1080p, 1.5 em 1440p,
> 1.75 em 4K). Com a mão a k cheio, o palco empurrava o inimigo estrada
> adentro e ele lia pequeno em tela cheia (queixa antiga do dono: "o
> inimigo é a estrela da batalha"). Devolve o fator NO ESPAÇO DA UI
> (handK / k): 1 em 1024x768/1366x768.

## L301-306 (em `handLayout`, junto a `local areaLeft  = 30`)

> O leque é centrado NO CENTRO DA TELA (feedback Jul/2026: "as cartas
> não estão ficando centralizadas" — centrar na área útil deixava a
> mão deslocada pra esquerda). Os botões da direita continuam
> protegidos: a MEIA-LARGURA disponível é o menor lado livre a partir
> do centro (esquerda até a margem, direita até os botões) — com
> muitas cartas o leque espreme SIMETRICAMENTE em torno do centro.

## L332-342 (em `handLayout`, junto a `local STAGE_CLEARANCE = 18`)

> PALCO DA BATALHA (Out/2026, dono: "os inimigos param muito na frente da
> tela. Muitas das vezes a descrição da carta ou a carta em si, quando faz
> o hover, fica à frente do inimigo"). Zona da MÃO EM HOVER: o pé do
> inimigo fica pelo menos STAGE_CLEARANCE px acima do topo da carta
> levantada. Na estrada isso vira DISTÂNCIA (WorldRoad.battleRelFor empurra
> o encontro estrada adentro, e a perspectiva encolhe o corpo junto); no
> salão do chefe vira posição na laje, limitada pela borda do piso (ver
> SceneAnchors.backYr). O tooltip da carta foi pro LADO dela pela mesma
> razão (Card.tooltipSide) — acima da carta ele caía exatamente sobre o
> tronco do inimigo, em qualquer distância que ainda fosse estrada.
> Medido por tools/study_enemy_stage; travado por tools/test_enemy_stage.

## L350-351 (em `stageFootLimit`, junto a `local function syncBattleStage()`)

> Recalculado todo frame a partir da janela (como o resto da cena): resize
> e troca de fullscreen reposicionam o palco sem cache nenhum.

## L353-354 (em `syncBattleStage`, junto a `local k = UiScale.activeK()`)

> limite do palco medido no espaço da UI (a mão), convertido pra pixels
> da tela — o WorldRoad vive na janela real (UiScale.outside)

## L381-382 (em `updateCardPositions`, junto a `card.layoutX = layoutX`)

> Posição "home" estática: usada pelo bbox de hover (não acompanha o
> lift visual de hoverCard pra cardY-130, evitando flicker bistável).

## L390-392 (em `updateCardPositions`)

> ============================================================================
> DRAW
> ============================================================================

## L394-398 (em `updateCardPositions`, junto a `local function jokerFrameGeometry()`)

> Geometria do painel de coringas (topo-ESQUERDO). Feedback Jul/2026: os
> jokers viviam parados centralizados no topo; agora ficam num QUADRO à
> esquerda, rotulado, com slots fixos (até maxJokerSlots) — visivelmente
> "cartas diferenciadas". Clicar no quadro abre o Gerenciador de Coringas.
> Fonte única de geometria (usada por draw E pelo hit-test do clique).

## L424-425 (em `GameplayScene.jokerFrameRect`, junto a `function GameplayScene.jokerSlotCenter(i)`)

> Centro do slot `i` de joker (game feel v1: JokerProcFx ancora o popup e a
> faísca do proc AQUI — o feedback nasce no joker que contribuiu).

## L441 (em `drawJokersAsCards`, junto a `local Palette = require("src.ui.Palette")`)

> Painel de fundo (zona "cartas especiais") — sutil, dourado.

## L451 (em `drawJokersAsCards`, junto a `local ownedN = 0`)

> Rótulo + contagem ativos/teto (+bancada)

## L478-479 (em `drawJokersAsCards`, junto a `joker.tooltipBelow = true`)

> Coringas vivem no TOPO: tooltip ABAIXO da carta (acima, o
> clamp cobria o topo dela — feedback Jul/2026)

## L487 (em `drawJokersAsCards`, junto a `love.graphics.setColor(Palette.PARCHMENT_DARK[1], Palette.PARCHMENT_DARK[2],`)

> placeholder de slot vazio (tracejado sutil + "+")

## L504-506 (em `drawJokersAsCards`, junto a `require("src.ui.StatusTooltip").draw()`)

> Partículas (burst de combate, joker, card-attached) são desenhadas
> centralmente em main.lua via CardParticles.draw() no fim do frame.
> Não chamar daqui — geraria double-draw.

## L512-518 (em `drawJokersAsCards`, junto a `function GameplayScene.worldOnlyMode()`)

> v5 (Encruzilhada): desenha SÓ o mundo (estrada + fork), sem inimigo, HUD
> ou mão — usado pelo estado mapSelection quando a escolha acontece in-world.
> O que "só o mundo" significa AGORA: "hall" = o salão do chefe (porta já
> aberta; o cadáver fica lá) ou "road" = a estrada. Decisão pura, testável
> (test_hand_deal): o cash out e os espólios do chefe acontecem DENTRO do
> salão (dono, Out/2026) — a estrada só volta quando o nó é deixado (a
> encruzilhada troca o nó e `isInteriorNode` cai sozinho).

## L523-530 (em `GameplayScene.worldOnlyMode`, junto a `if WorldRoad.isForkActive() then return "road" end`)

> ENCRUZILHADA ATIVA = o nó do chefe já foi deixado: showMapSelection
> avançou andar/ato e abriu o fork, e a escolha acontece NA ESTRADA —
> só lá os marcos existem (WorldRoad.drawOverlays). O nó em si só troca
> quando o jogador ESCOLHE, então esperar por ele aqui deixava o jogador
> preso: salão do ato NOVO (actNumber já virou), cadáver no chão, fork
> invisível (dono, 13/Out: "não foi para a sala correta... não tô
> conseguindo jogar"). Cash out e espólios continuam no salão: o fork
> ainda não existe nessas etapas.

## L540-541 (em `GameplayScene.drawWorldOnly`, junto a `local saved = GameplayScene.WORLD_ONLY`)

> salão + cadáver + clima, sem HUD/mão (WORLD_ONLY corta antes da UI;
> a cortina da mão já está fechada depois da morte do chefe)

## L565-566 (em `GameplayScene._drawWorldOnlyReal`, junto a `WorldRoad.drawOverlays(0, topBarHeight, width, height - topBarHeight)`)

> LightEngine v1: luz + fork overlay (marks/pills DEPOIS do composite —
> este é o caminho do estado mapSelection, onde o fork está ativo)

## L568-569 (em `GameplayScene._drawWorldOnlyReal`, junto a `local f = WorldRoad._fork`)

> encruzilhada: cada marco é alvo do foco de teclado/pad (NavCursor) —
> a hitbox é a mesma do clique (WorldRoad.forkMousePressed)

## L582-590 (em `GameplayScene._drawWorldOnlyReal`, junto a `GameplayScene.HALL_REF_SCALE = 3.7`)

> Tamanho do chefe no salão (Out/2026, dono: "em tela cheia os bosses não
> ficam muito pequenos?"). O chefe tem altura FIXA em pixels (330) e o salão
> cresce com a tela pelo cover-fit: em 1920x1080 ele ocupava ~27% da altura
> e lia pequeno pro clímax do ato; em 2560x1440 pior ainda. O chefe passa a
> crescer na mesma proporção da sala a partir de 3.7 px por pixel da arte —
> 1080p fica 1.3x (escolhido por comparação lado a lado de 1.0/1.2/1.35:
> domina a sala sem a barra de vida colar no topo nem o pé descer na mão),
> 1440p e 4K mantêm a MESMA proporção. Abaixo disso (1024x768, 1366x768)
> nada muda: lá o chefe já ocupa ~43% da altura.

## L601-606 (em `GameplayScene.hallScreenK`, junto a `GameplayScene.BOSS_OVER_COMMON = 1.15`)

> O CHEFE É SEMPRE MAIOR QUE O INIMIGO COMUM (Out/2026). O salão cresce
> pelo cover-fit da arte (hallScreenK) e o chefe ainda encolhe ao recuar na
> laje (depthSizeK); a estrada cresce pelo enemyScreenK. Em 1440p as duas
> curvas se cruzavam e o chefe do ato 5 saía 3px MENOR que o comum mais alto
> (test_enemy_stage). Piso: o chefe tem pelo menos BOSS_OVER_COMMON vezes a
> altura que um comum (250px de arte) teria na mesma área de mundo.

## L625-627 (em `GameplayScene.draw`, junto a `local nodeType = run and run.currentNode and run.currentNode.type`)

> PROGRESSÃO DE CENÁRIO (feedback Jul/2026 + v10.1 + v11): batalha
> comum, ELITE e mini-boss acontecem na ESTRADA (mundo-esfera, do lado
> de fora); só o BOSS entra no castelo — ver isInteriorNode.

## L629-630 (em `GameplayScene.draw`, junto a `local entering = GameplayScene.SCENE_MODE == "worldroad"`)

> v10: enquanto a CERIMÔNIA de entrada toca (porta abrindo), a cena
> continua na estrada — o interior só assume depois do fade

## L633-635 (em `GameplayScene.draw`, junto a `local interior = GameplayScene.SCENE_MODE == "worldroad" and not entering`)

> Durante a viagem de aproximação e a própria cutscene, interior=false
> → a cena mostra a ESTRADA/exterior (castelo crescendo, porta
> abrindo), nunca a sala antes da hora.

## L639-643 (em `GameplayScene.draw`, junto a `local traveling = GameplayScene.SCENE_MODE == "worldroad"`)

> v9.2: no battle da estrada, o inimigo desenha DENTRO do painter do
> WorldRoad (no eixo BATTLE_REL) pra que postes/árvores mais próximos
> que ele fiquem NA FRENTE. Registra antes do draw; o painter chama e
> captura o bbox (usado pelo HUD). traveling/interior seguem o fluxo
> antigo (inimigo é billboard ou hall estático).

## L650 (em `GameplayScene.draw`, junto a `local uiK = UiScale.activeK()`)

> Números do palco medidos na UI (mão) ANTES de sair pro mundo real.

## L663-664 (em `GameplayScene.draw`, junto a `local zk, zcx, zcy = BossCinematic.worldZoom()`)

> soco de zoom do pouso do chefe (BossCinematic.worldZoom): só o MUNDO,
> em volta do ponto de impacto, translação inteira

## L671-672 (em `GameplayScene.draw`, junto a `local topBarHeight = GameplayScene.WORLD_ONLY and 0 or uiTopBarH * uiK`)

> WORLD_ONLY (arte de loja/key art, tools/store_art.py): mundo + inimigo
> em tela cheia, sem top bar nem HUD.

## L677-680 (em `GameplayScene.draw`, junto a `local sizeK = (WorldRoad.battleSizeK and WorldRoad.battleSizeK() or 1)`)

> sizeK: o inimigo encolhe pela MESMA perspectiva do mundo conforme
> a distância de parada (WorldRoad.battleSizeK) — parar mais ao
> fundo sem encolher deixaria um gigante longe, quebrando a escala
> das árvores em volta.

## L689-693 (em `GameplayScene.draw`, junto a `local sceneKey, sceneH = nil, height`)

> Cena de fundo efetivamente desenhada — o inimigo pisa na LINHA DE
> CHÃO dela (src/data/scene_anchors.lua), não numa fração fixa da tela.
> sceneH: o SceneLayer legado desenha a PNG na area util (sem a top
> bar), o hall desenha em tela cheia — a ancora tem que usar a MESMA
> caixa que o desenho usou, senao o pe sai da laje.

## L696-699 (em `GameplayScene.draw`, junto a `local hallAct = InteriorFX.hallFor(currentAct)`)

> Salão do chefe por ato (1..6). A escolha do salão — e o aviso de
> ato sem arte — mora em InteriorFX.hallFor: draw e update perguntam
> ao MESMO lugar (a v1 tickava as brasas com min(3, ato) e desenhava
> o salão real: nos atos 4-6 as brasas saíam da lava do hall 3).

## L710-711 (em `GameplayScene.draw`, junto a `InteriorFX.draw(hallAct)`)

> luz nas chamas pintadas, névoa no chão, vinheta e partículas
> de trás — tudo ATRÁS do chefe (ver InteriorFX)

## L714-715 (em `GameplayScene.draw`, junto a `BossCinematic.drawBack()`)

> entrada do chefe: escuridão, olhos no vão, rasantes com rastro
> (atrás de onde o chefe vai pousar)

## L731-734 (em `GameplayScene.draw`, junto a `if not traveling and not worldBattle and not entering then`)

> Inimigo: no battle da estrada já foi desenhado DENTRO do WorldRoad.draw
> (callback no eixo BATTLE_REL — props próximos na frente dele). Aqui só
> os outros casos: interior (hall estático) e SceneLayer legado. Na
> viagem o inimigo é billboard do WorldRoad (não desenha aqui).

## L736-739 (em `GameplayScene.draw`, junto a `local anchor = SceneAnchors.get(sceneKey)`)

> v11: o pé do inimigo pousa na LAJE da cena, não em height*0.68
> (número fixo herdado do castle_hall_1 — no hall do ato 2 essa
> linha cai na PAREDE e o chefe ficava pairando; defeito reportado
> Set/2026). A cena também diz a força e a direção da sombra.

## L744-748 (em `GameplayScene.draw`, junto a `local _, backY = SceneAnchors.groundAnchor(sceneKey, width, sceneH,`)

> PALCO (ver STAGE_CLEARANCE): o chefe recua na laje até sair de
> trás da carta em hover — mas só até a BORDA DE TRÁS do piso
> (backYr): além dela ele pisaria degrau/parede. Na maioria dos
> salões a laje acaba antes da zona da carta, então o recuo é
> parcial: "um pouquinho mais longe", o que a arte deixa.

## L754-770 (em `GameplayScene.draw`, junto a `local tetoY = math.floor(handTopReal - ENEMY_HAND_CLEARANCE * uiK)`)

> TETO DA MAO: o pe nunca pousa abaixo do topo das cartas.
>
> A linha de chao e dado da ARTE (cada PNG tem o piso onde o artista
> pos), e no `castle_hall_2` a laje so comeca em 83% da altura --
> enquanto a mao comeca em 80% (`handLayout`). O chefe do ato 2
> nascia com o pe 3% ABAIXO do topo das cartas e a metade de baixo
> dele ficava atras delas ("boss 2 esta ficando muito la embaixo, as
> cartas estao na frente dele" -- dono, Set/2026).
>
> Subir o pe e melhor que encolher o inimigo: o chefe perde presenca
> se diminuir, e a laje do hall 2 vai de ~0,78 ate a base da tela, ou
> seja, o pe continua na PEDRA depois do corte. A sombra de contato
> acompanha (e desenhada no mesmo cy), entao a leitura de "esta no
> chao" nao se perde.
>
> Vale pra qualquer cena e qualquer inimigo: e a mao que define ate
> onde o mundo pode descer, e ela e responsiva.

## L773-774 (em `GameplayScene.draw`, junto a `local InteriorDepth = interiorHall and require("src.ui.InteriorDepth")`)

> salão: poça de oclusão em degraus sob os pés (contato com o piso),
> ANTES do chefe (require inline: estado do salão fica no módulo)

## L776-778 (em `GameplayScene.draw`, junto a `local cineHidden = BossCinematic.hidesBoss()`)

> CHEFE AINDA NÃO POUSOU (BossCinematic): nada dele chega à tela —
> o draw roda num canvas descartado só pra MEDIR onde ele vai ficar
> (bbox + canto do sprite), que é onde o rasante final termina.

## L784-787 (em `GameplayScene.draw`, junto a `local deathCy = nil`)

> CHÃO DO CADÁVER (scene_anchors.deathYr): onde quem voa CAI ao
> morrer. No salão 2 a linha do vivo é a faixa estreita colada na
> base da parede — o corpo deitado ali lia "em cima da balaustrada";
> o piso andável fica à frente. Sem deathYr, é a linha do vivo.

## L814-815 (em `drawEnemy`, junto a `BossCinematic.setStage({`)

> palco da cinemática (medido NESTE frame) + poeira/corvos/penas
> na frente do chefe

## L828-830 (em `drawEnemy`, junto a `if GameplayScene.SCENE_MODE == "worldroad" and not interior then`)

> LightEngine v1: composite multiply do lightmap sobre mundo+inimigo,
> ANTES de qualquer UI (EnemyHud/gameUI/mão ficam fora da luz). O fork
> overlay (pills) vem junto, DEPOIS do composite (revisão F-10).

## L838-841 (em `drawEnemy`, junto a `local cineHide = BossCinematic.hidesHud() or HandDeal.hidesHud()`)

> ENTRADA DO CHEFE: o salão abre VAZIO — HUD do inimigo, painel do herói,
> mão, botões e coringas esperam o nome do chefe (BossCinematic.hidesHud).
> No salão o HUD também espera a DISTRIBUIÇÃO das cartas (HandDeal:
> cartas primeiro, botões e HUD depois — ordem de mesa).

## L843-845 (em `drawEnemy`, junto a `local cineHand = BossCinematic.hidesHand() or HandDeal.hidesHand()`)

> mão/botões/coringas/prévia somem na ENTRADA e na MORTE (na morte o
> HUD de vida fica: o corpo caindo é o que se vê, não há o que jogar)
> e atrás da CORTINA (viagem, porta, salão à espera do chefe).

## L851-852 (em `drawEnemy`, junto a `if enemyBbox and uiK ~= 1 then`)

> ===== UI (espaço virtual) =====
> O bbox do inimigo veio em pixels da tela: o HUD dele mora na UI.

## L861-865 (em `enemyBbox`, junto a `local hoverLift = HOVER_LIFT * handScale()`)

> TETO DO HOVER: no salão a laje limita o recuo do chefe, e a carta
> levantada cobria o corpo dele (lich do ato 2). A carta sobe só até
> o pé do inimigo — mas sempre o bastante pra aparecer INTEIRA (o
> leque fica com parte da carta abaixo da tela). Na estrada o palco já
> garante o pé acima do topo da carta, então o teto não morde.

## L899-900 (em `enemyBbox`, junto a `local cardStartX, cardSpacing, cardY, currentHandSize = handLayout()`)

> Layout da mão (drag + reorder + slot animado) — fanning/squeeze estilo
> Balatro (ver handLayout): a mão nunca estoura pra cima dos botões.

## L937-938 (em `renderIdxFor`, junto a `card.deferTooltip = true`)

> tooltip no passe FINAL da cena (acima dos selos +COMBO, da prévia
> e dos toasts) — ver Card.deferTooltip / drawDeferredTooltip

## L946-948 (em `renderIdxFor`, junto a `if corpseUnderHand and game.enemy and not game.enemy:isAlive() then`)

> inimigo morto com o cadáver caindo ATRÁS da mão (chão do cadáver
> abaixo do topo das cartas, salão 2): a mão desce e sai da tela —
> a luta acabou e o corpo no chão é o que se quer ver.

## L967-970 (em `renderIdxFor`, junto a `if not entering and not cineHand then`)

> v10.5: durante a CERIMÔNIA de entrada no castelo (porta abrindo +
> fade) a mão NÃO é desenhada — é cutscene, não turno. Mesma convenção
> do EnemyHud acima. Layout/updateRender continuam rodando de propósito:
> a mão não congela nem salta quando a cerimônia termina.

## L972 (em `renderIdxFor`, junto a `for _, card in ipairs(game.hand) do`)

> Desenha não-dragadas (ordem normal), depois hover, depois dragged por cima

## L994-998 (em `renderIdxFor`, junto a `local roadOutdoor = GameplayScene.SCENE_MODE == "worldroad"`)

> v7.4.14: fumaça ambiente SÓ nos interiores de castelo — na ESTRADA
> aberta os fiapos translúcidos gigantes (escala 2×, cruzando a tela)
> liam como "3 linhas subindo e descendo" (feedback; o demo não roda
> smoke e ficava bom; CRT on/off não mudava = era isto). Véu
> translúcido sobre a cena pixel art é anti-pattern do projeto.

## L1006-1007 (em `renderIdxFor`, junto a `if not uiWait then`)

> Ações de contexto do teclado/pad (NavCursor): Y/E joga a seleção,
> X/Q encerra o turno — o glifo mora no canto do próprio botão.

## L1025-1027 (em `press`, junto a `if not entering and not uiWait then`)

> PREVIA DE DANO (Out/2026): banda de ACAO da coluna direita, colada em
> cima do JOGAR — o numero que o clique vai produzir mora no botao que o
> produz. Selos "+COMBO" ficam NA carta que fecharia o combo.

## L1035-1036 (em `press`, junto a `if GameplayScene._endTurnCallout and endTurnButton and not uiWait then`)

> Chamariz do ENCERRAR TURNO (sem mana e nada selecionado): aro dourado
> pulsante + seta quicando — "sua próxima ação é aqui".

## L1052-1053 (em `press`, junto a `if game.messageSystem and not uiWait then game.messageSystem:draw() end`)

> toasts ficam na FILA durante a cinemática (sem tick, sem desenho):
> "carta desbloqueada" por cima do chefe caindo quebrava a cena

## L1059-1061 (em `press`, junto a `ComboBanner.draw(topBarHeight)`)

> Banner de COMBO: DEPOIS da mão e depois do combatAnimationSystem (que
> drawJokersAsCards desenha no fim) — as cartas do turno passavam por
> cima dele e "não dava nem pra ler" (feedback do dono, Set/2026).

## L1064-1067 (em `press`, junto a `for _, card in ipairs(game.hand) do`)

> PASSE FINAL: o tooltip da carta em hover vem por cima de TUDO da mão
> (selos "+COMBO" das vizinhas, prévia de dano, toasts, quadro de
> coringas) — antes era desenhado junto da própria carta e o que vinha
> depois o cobria. Quadro sem hover: nada pendente.

## L1072-1073 (em `press`, junto a `BossCinematic.drawUI()`)

> cartão com o nome do chefe + dica de pular (por cima da UI, por baixo
> dos fades)

## L1083-1084 (em `press`, junto a `local ef = WorldRoad.entryFade and WorldRoad.entryFade() or 0`)

> v10: fade da fase "push" da cerimônia (entrando pelo vão da porta —
> escurece ATÉ o preto; o interiorFade acima revela do preto depois)

## L1093-1095 (em `press`, junto a `function GameplayScene.update(dt)`)

> ============================================================================
> UPDATE
> ============================================================================

## L1098-1101 (em `GameplayScene.update`, junto a `if not InputFocus.allows(InputFocus.SCENE) then`)

> Um overlay tomou o foco (pausa, deck, coringas...): SOLTA a carta em
> arrasto. Sem isto ela continuaria colada num mouse que, pra esta
> camada, agora lê fora da tela (src/ui/InputFocus) — e sumiria da mão
> enquanto o menu estivesse aberto. Soltar devolve ela ao layout.

## L1115-1116 (em `GameplayScene.update`, junto a `if game._endTurnQueued and game.turn == "player"`)

> Encerrar Turno clicado DURANTE a animação: fica na fila e executa
> assim que a jogada termina (antes era engolido em silêncio).

## L1125-1128 (em `GameplayScene.update`, junto a `do`)

> Cinemática do chefe (entrada/morte): relógio próprio, ANTES do
> EnemyRenderer — a câmera lenta da morte é a escala do dt dele neste
> frame. `inHall` decide se a morte vira cinemática (o mini-boss também
> tem isBoss, mas luta na estrada).

## L1135-1136 (em `GameplayScene.update`, junto a `do`)

> FX de interior (tochas) tickam quando o node atual é de castelo;
> transição estrada↔interior dispara fade de entrada (portão)

## L1140-1141 (em `GameplayScene.update`, junto a `local isInt = GameplayScene.isInteriorNode(ntU, bossEntered)`)

> Mesma fonte que o draw (isInteriorNode). O `not isEntering`
> cobre o frame de transição da cerimônia da porta.

## L1161-1166 (em `GameplayScene.update`, junto a `do`)

> F6.1: entardecer progressivo por andar, com PISO 0.5 (feedback:
> "o jogo base está sem a iluminação do demo" — tod=0 no andar 1
> dava luz ~branca = motor invisível; o demo abre em tod=1). O
> mood existe desde o 1º andar (meio-crepúsculo, vagalumes no
> limiar) e fecha no anoitecer pleno no boss (o look da
> referência). Curva ^1.35: escurece devagar, acelera no fim.

## L1182-1183 (em `GameplayScene.update`, junto a `local floorKey`)

> Troca de andar/fase → herói "anda" até o próximo encontro:
> o mundo rola pra frente (técnica Path of Kings)

## L1198-1202 (em `GameplayScene.update`, junto a `bossEntered = false`)

> v10.2/v10.4: BOSS — a esfera anda pra frente (o castelo
> cresce naturalmente, como todo andar), SEM inimigo na
> estrada (o boss está dentro). Ao CHEGAR, a porta abre +
> som; quando o fade completa, bossEntered=true libera a
> sala. Até lá interior=false (sem mostrar a sala antes).

## L1212-1215 (em `onComplete`, junto a `WorldRoad.travel({`)

> batalha comum, ELITE e MINI-BOSS (v10.1: "do lado de fora
> do castelo, sem aquele background"; v11: o elite entrou
> nesta lista): o inimigo vem lá de trás pela estrada; na
> chegada, quicadas de aterrissagem.

## L1227-1233 (em `onComplete`, junto a `do`)

> CORTINA DA MÃO (Out/2026, bug do dono: mão/botões/HUD apareciam no
> meio da porta e da entrada do chefe). Abaixada em toda cutscene:
> viagem na estrada, cerimônia da porta, salão à espera do chefe,
> entrada/morte do chefe e a quicada de chegada. Quando sobe, as cartas
> são DADAS uma a uma e só depois entram botões e HUD (HandDeal). No
> caminho do castelo (porta + salão) o HUD espera junto. Avaliada
> DEPOIS do gatilho da viagem acima: o andar novo já nasce atrás dela.

## L1249-1252 (em `onComplete`, junto a `game:announceDeathIfPending(nil)`)

> CHECKPOINT DA MORTE (Set/2026): antes de qualquer gate de desfecho, o
> inimigo morto que ainda nao foi encenado vira acontecimento. E a mesma
> rede do `enemy.enrage_check` do turno do inimigo — nenhuma fonte de dano
> pode entregar um cadaver direto pra tela de espolios.

## L1255-1258 (em `onComplete`, junto a `if game._deathPauseTimer and game._deathPauseTimer > 0 then`)

> O relogio da morte corre ANTES dos gates: e ele que segura tanto os
> espolios quanto a VITORIA (queixa do dono: "a tela de vitoria ta
> aparecendo rapido demais, so aparece quando a gente tem a confirmacao
> que ele morreu").

## L1263-1266 (em `onComplete`, junto a `if game:checkGameOver() and not game.combatAnimationSystem:isBlocking() then`)

> Transições de estado (game over / victory). Retorna true se mudou
> (caller deve fazer early return pra não rodar resto do frame).
> Game over NAO espera a morte do inimigo: quem caiu foi o jogador, e o
> respiro dele e a propria TV desligando.

## L1273-1277 (em `onComplete`, junto a `if game:checkVictory() and game:isReadyForEndScreen()`)

> Vitoria (boss do ato final) espera a MESMA coisa que os espolios: a
> criatura cair na tela. `isReadyForEndScreen` = combate parado (inclui a
> fila de beats) E morte assentada. A regra mora no Game pra ser testavel.
> Morte de CHEFE: a cinemática (câmera lenta, rajada, corpo no salão)
> segura espólios e vitória até terminar — BossCinematic.holdsEnd.

## L1305-1309 (em `onComplete`, junto a `local attacking = EnemyRenderer.isAttacking and EnemyRenderer.isAttacking()`)

> inimigo terminou de agir (investida no ar conta como agindo).
> `_enemyActing` (Set/2026): o turno do inimigo virou uma CADEIA de
> beats e `isBlocking()` passa a ser true durante ela — sem este
> check o ramo de cima deixa de rodar e o banner do JOGADOR subia
> antes do inimigo sequer golpear. A flag só cai no beat final.

## L1319-1320 (em `onComplete`, junto a `if smokeSystem and not (GameplayScene.SCENE_MODE == "worldroad"`)

> fumaça só ticka onde é desenhada (interior/legacy) — na estrada
> partículas acumuladas apareceriam de uma vez ao entrar no castelo

## L1328-1329 (em `onComplete`, junto a `local mx, my = love.mouse.getPosition()`)

> Hover tracking: carta sob mouse vira hoverCard; suprime hover em outras
> se qualquer uma está sendo arrastada.

## L1351-1353 (em `onComplete`, junto a `do`)

> UX do turno multi-jogada (playtest): "joguei e nada aconteceu".
> JOGAR CARTAS desabilita quando não há nada selecionado NEM pagável;
> ENCERRAR TURNO pulsa quando é a única ação que resta.

## L1375-1381 (em `onComplete`, junto a `if GameplayScene._endTurnCallout and turnStage == nil`)

> AUTO-ENCERRAR (feedback Jul/2026, padrão StS/Balatro): sem
> seleção E sem carta pagável = nenhuma ação possível — o turno
> passa SOZINHO, praticamente na hora (feedback v2.1: "não precisa
> ter delay"; os 0.2s são só pra não flipar no MESMO frame em que
> a animação da jogada termina). Guardas: turnStage nil (a
> coreografia flipa game.turn cedo — sem isso auto-encerrava
> durante a investida do inimigo) e banner fora da tela.

## L1395 (em `onComplete`, junto a `if game.messageSystem and not BossCinematic.isActive() then`)

> topBar:update movido pro main.lua (ticka em todos os estados)

## L1403-1405 (em `onComplete`, junto a `function GameplayScene.mousepressed(x, y, button)`)

> ============================================================================
> INPUT
> ============================================================================

## L1412-1414 (em `GameplayScene.mousepressed`, junto a `if BossCinematic.lockInput() then`)

> entrada/morte do chefe: clique PULA (depois de 1s) e nada passa. No
> jogo o InputFocus já entrega o clique ao overlay dela; isto cobre
> quem chama a cena direto (ferramentas, testes).

## L1419-1420 (em `GameplayScene.mousepressed`, junto a `if topBar:mousepressed(x, y, button) then return true end`)

> v9.7.1: retorna se CONSUMIU o clique — o que sobrar vira poke no
> cenário do WorldRoad (main.lua → pokeSceneAt, mapa vivo)

## L1423-1425 (em `GameplayScene.mousepressed`, junto a `if HandDeal.isBusy() then return false end`)

> Cortina abaixada ou cartas sendo dadas: não há botão, coringa nem
> carta pra clicar (a carta invisível ainda está na mão lógica — sem
> isto um clique cego a selecionava). O clique segue pro cenário.

## L1438-1441 (em `GameplayScene.mousepressed`, junto a `if playButton:mousepressed(x, y, button) then return true end`)

> BUG do playtest ("encerro e nada acontece"): os widgets Button
> exigem mousepressed pra armar o pressed — o hit-test manual
> antigo do Jogar Cartas disparava no press (ignorando disabled)
> e o Encerrar Turno nunca recebia o press → onClick NUNCA fired.

## L1525-1532 (em `GameplayScene.keypressed`, junto a `if key == "escape" then`)

> Atalhos de DESENVOLVIMENTO (reiniciar batalha, presets de fumaça) só
> existem no modo clássico. Numa RUN eles eram armadilha: "R" rodava
> game:startGame() — player novo (vida/mana máximas perdidas), ouro 10,
> inimigo base do ato 1 no lugar do chefe — e o checkpoint seguinte
> gravava isso. Os números trocavam a fumaça em silêncio. (Revisão de
> lançamento, Out/2026.) O "f" de tela cheia saiu de vez: alternava sem
> love.resize (layout velho) e sem gravar a preferência — o caminho certo
> é Configurações → Tela cheia.

## L1566-1568 (em `GameplayScene.keypressed`, junto a `function GameplayScene._reportTutorialAnchors()`)

> Âncoras das dicas do tutorial (src/systems/Tutorial): mão, JOGAR, ENCERRAR
> TURNO e o quadro de coringas, reportados no MESMO espaço em que acabaram de
> ser desenhados (o Tutorial converte pra pixels reais).

## L1573-1574 (em `GameplayScene._reportTutorialAnchors`, junto a `local channelCards, evokeCards = {}, {}`)

> Mago: a 1ª carta que CANALIZA e a 1ª que EVOCA ganham recorte próprio
> (conversas `channel`/`evoke_card`), união das cartas com o efeito.

