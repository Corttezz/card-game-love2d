---
name: roadwear_engine
description: Solo do caminho — RoadTiles (tile por bioma, escolha do dono; ato 5 sem tábuas desde a rodada 8), RoadSurface (cache/bake), RoadFork (encruzilhada como um chão só), RoadDecals (folhas sopradas do ato 6)
type: architecture
---

# Solo do caminho (23/Out/2026, estrada final escolhida pelo dono)

O dono escolheu UMA variante por ato na folha `tools/preview_out/estrada_variantes/visao_geral_18_tod65.png`:
ato 1 A trilha gasta, ato 2 A trilha de cascalho, ato 3 A trilha de cinza com rachaduras e brasa,
ato 4 A neve pisada, ato 5 B passarela de tábuas (trocada pela trilha de lama na rodada 8), ato 6 A trilha de folhas. As outras 12 variantes,
`engine/RoadVariants.lua`, `CARDGAME_ROAD`, Home/End no cheat, a chave `cheat.road_variant`, o bake
antigo do `RoadSurface` e o `engine/RoadWear.lua` (catálogo de decalques antigo, já desligado pelas
variantes) foram APAGADOS. Não há mais chave de variante. Provas antes/depois em
`tools/preview_out/estrada_final/atoN/antes_depois_<cena>.png`.

## RoadTiles (engine/RoadTiles.lua)

- Um `PAINT[bid]` por bioma devolve material, altura e valor por texel; `V.bake` aplica sombra
  projetada pela altura na direção da luz (`LIGHT_X`, ato 6 à esquerda), quantiza na paleta do bioma
  (dither leve: limiar ±0,11 + Bayer ±0,06; mais que isso vira chuvisco) e grava a metade borrada
  (crista) à direita. Tile 384x640, 56 texels por meia-largura de estrada.
- `V.VK = 1.35`: texel QUADRADO perto da câmera em 1080p (4,5 x 4,4 px). Com 1,75 o texel era 2:1
  deitado e todo detalhe virava traço horizontal.
- **Nada redondo.** Pedra = polígono convexo de 5 a 7 facetas (`stone`/`stoneAt`, memo por célula):
  topo claro, faceta virada para a luz mais clara, faceta de costas escura, contorno escuro só do
  lado da sombra, altura alta para projetar sombra de 1 texel. A `pebble` elíptica com sombreado
  radial (lia como bolinha) e as `blob` redondas saíram. Cascalho só em aglomerados
  (`gravel`, ruído baixo como máscara), nunca confete uniforme.
- Folha (`leafAt`): lente pontuda orientada, nervura só em folha larga, borda escura do lado da
  sombra, 4 rampas de outono (laranja, vermelha, ocre, marrom seca); camada de folhas grandes e
  camada miúda por baixo, densidade por célula memorizada (`dmemo`, sem isso o bake do ato 6
  levava 1,9 s), amontoada nas bordas e em manchas, pisada e escurecida no centro gasto.
  Achatada em v (`dy * 1.2`) para deitar no chão.
- Neve: pegada oval com parede do fundo escura e borda de perto clara (sem traço no meio), sulco
  com brilho de gelo raro, ondulação de vento nos ombros. A mancha `sl` (fbm escuro) saiu: era a
  bola escura do ato 4.
- Passarela: tábuas de 6 a 8 texels com ponta irregular, veio, nó, rachadura curta, pregos com
  ferrugem, musgo em tufos só nas pontas, tábua caída/quebrada/faltando, longarinas visíveis nas
  frestas e nos buracos, estacas a cada 6 tábuas, água com brilho nas frestas e ao lado.

- Metade borrada (crista): sorteada por segmento com a chance que for MAIOR entre a distância
  (`farT0`..`farT1`) e o passo de v por linha (`farDv`, acima de ~1 texel por faixa a amostra
  pula texel e cintila). Pântano: borrão vertical 13 (tábua/fresta de 7 texels virava listra no
  `test_castle_light`, que mede degrau de brilho no fim da estrada), `farT0 0,2`, `farT1 0,4`,
  `farDv 0,45`; mais que isso borra as tábuas sob o pé do inimigo.

## RoadSurface (engine/RoadSurface.lua)

Só cache: `get(bid, pal, yieldEvery)` assa `RoadTiles.bake` (o pré-aquecimento passa
`yieldEvery = 4`: fatias de ~3 ms), `style(bid)` devolve o estilo (o pântano tem
`platform = true`). Falha avisa uma vez e cacheia `false`; sem tile a estrada sai em cor chapada.

## Desenho (WorldRoad drawRoad) e encruzilhada (engine/RoadFork.lua)

- Cada faixa de 2 px amostra o tile de cima (v maior, mais longe) para baixo
  (`rectSkew(..., -lrow * 3.5 / 2)`). O código antigo amostrava de baixo para cima e cada texel que
  caía no meio de uma faixa saía espelhado: eram os fiapos horizontais de 1 px que "mancham" a
  textura perto da câmera em todos os atos.
- Ramos: o v de cada ramo é INTEGRADO ao longo dele (`va`), passo `L = sqrt(da² + dv²)` em texels,
  e a linha da tela recebe cisalhamento `sh = da / L` por vértice (`QuadMesh:rectSkew`). Densidade
  ao longo do ramo / tronco fica entre 0,99 e 1,44; o mapeamento antigo dava 0,36 a 0,53 (era o
  "esticado" do dono). Sulcos seguem e se dividem em cada ramo.
- `RoadFork.partition`: cada pixel tem UM dono. Ramos ordenados pelo centro; vizinhos dividem a
  sobreposição no meio com transição de `BAND_K * meia-largura` (alfa por vértice); convergindo, o
  escolhido fica inteiro e os outros só pintam fora dele. Antes o último ramo (direita) pintava por
  cima dos outros com outra textura. Borda de dentro (coberta por outro ramo) não ganha contorno nem
  migalha; borda que dá para a cunha só ganha o contorno.
- Pântano: enquanto os ramos estão colados (centros a menos de `DECK_K = 1,45` meias-larguras) a
  passarela vira um DECK único com as tábuas do tronco esticadas na largura da união e uma viga
  escura na ponta; depois cada ramo sai com tábuas perpendiculares a ele.
- Sonda de teste: `WorldRoad._forkSurfaceProbe` (sobreposição e densidade por linha);
  `WorldRoad._armProbe` segue igual para o `test_fork_branch_width`.

## RoadDecals (engine/RoadDecals.lua)

Só o ato 6: poucas folhas (3 carimbos 4-5 px, 4 cores) que o vento leva de lado e assentam,
com sombra. Sem poça, anel, pegada, brasa ou junco (todos eram elipses).

## Vagalume

`WeatherEngine`: a poça de luz no chão do vagalume caiu de `radius * 8 * ps + 10` para
`radius * 2.4 * ps + 4` e intensidade 2,2 → 1,4. O disco grande na estrada lia como bola.

## Travas e ferramentas

- `love . test_one test_road_fork_surface`: partição (sem sobreposição, escolhido inteiro, junta dura),
  6 atos × 2 e 3 opções: sobreposição 0, densidade em [0,55; 1,8], convergência sem sobreposição.
- `test_fork_branch_width`, `test_road_edge_rhythm` (ato 4 cunha 0,26 contra piso 0,25: a cor da
  neve pisada foi afastada da neve do campo para o teste não contar texel da estrada como cunha).
- Capturas `lovec . test_one screenshot_estrada_final "<atos>:<cenas>"` (`fork3`, `fork2`,
  `converge`, `chegada`, `battle`, `continuar`; `ESTRADA_VIRTUAL`, `ESTRADA_TAG`), folhas
  `python tools/estrada_final_folha.py`, perf `lovec . test_one perf_estrada_final` (inclui o tempo
  do bake por ato).
- Perf (1920x1080): trilha 506 a 566 draw calls, encruzilhada 533 a 602; a 9913b64c dava 537 a 610
  (o ato 3 com encruzilhada já passava de 600 antes; o `test_perf_budget` mede a trilha). QuadMesh
  da estrada nasce com 16384 quads para não crescer no meio da encruzilhada.

## Rodada 2 (23/Out/2026, revisão do lead sobre 8b4db32e)

- **Texel fino perto da câmera:** o tile é assado em `V.S = 2` (768x1280 por bloco, FFI, borrão
  separável). As pinturas continuam em unidades de desenho (mesmo tamanho de pedra/tábua/folha),
  amostradas a cada meio texel, e o bake soma GRÃO por material (`V.GRAIN`, ruído de 1 e 2 px).
  Perto da câmera o texel tem ~2,2 px em 1080p, ~4 px em 3440x1440, igual à escala dos props.
  `st.half/cu/far/vk/farDv` já vêm multiplicados por `S`. Bake 0,4 a 2,9 s por bioma (ato 6 o mais
  caro), o pré-aquecimento cede a cada linha (`RoadSurface.get(bid, b, 1)`).
- **Folhas do ato 6 (`fallenLeaf`):** oval pontudo com talo, ~28% enroladas (um lado estreito com
  dobra clara e miolo escuro), 6 tons (laranja, vermelha, ocre, marrom, dourada, carmim), camada
  grande e camada miúda, altura por camada (folha de cima projeta sombra na de baixo e no chão),
  tapete nas bordas e em manchas, espalhadas no centro.
- **Junção como um material:** a faixa de transição não faz mais crossfade; cada pedaço de
  ~3 texels escolhe um dos ramos (rampa + hash estável por linha do mundo), costura irregular,
  `BAND_K = 0,22`. Rachadura do ato 3 mais larga (fenda de 1 px aliasava no cisalhamento).
- **Passarela rígida nos ramos (`WorldRoad._forkPlanks`):** nas linhas de ramo fora do deck o chão
  vem do bloco 3 do tile (`st.bare`, lama e água sem tábua) e cada tábua é um quad
  (`QuadMesh:quad`) reto e de largura constante entre duas bordas de tábua achadas no v integrado
  do ramo (`RoadTiles.planks`), girada pelo cisalhamento do ramo naquele ponto. Sem leque nem
  esticado; na convergência o escolhido termina igual ao tile do tronco.
- **Ato 4:** neve pisada mais escura e azulada no centro (-0,28), berma clara (+0,34).
- Pântano no `test_castle_light`: borrão da crista guarda só 8% do detalhe (`k`) e tom de tábua
  0,32 de faixa: a sobra de listra de tábua no borrão dava "subida" 5,3 contra 4,96.

## Rodada 3 (23/Out/2026): passarela do ato 5, ponta dos ramos, sequência quadro a quadro

- **Ramo termina no marco.** `WorldRoad.forkFarK` apaga cada ramo lateral entre `MARK_REL + 0,4` e
  `+2,8` (`FORK_END`), na estrada e na clareira da grama juntos; o escolhido volta a inteiro com a
  convergência. Era o "retângulo escuro" atrás de Battle/Rest no ato 5 (e a faixa em todos os atos):
  os ramos continuavam até a crista por trás dos marcos. `test_road_edge_rhythm` mede a cunha também
  acima dos marcos; pisos do ato 3/4 recalibrados para 0,82/0,28 do carpete (antes o ramo invisível
  atrás do marco contava como cunha).
- **Passarela do ato 5.** Deck (`RoadFork.deckK`, 0..1, suavizado no tempo por linha) enquanto os
  ramos estão colados ou um ramo está no tronco; fora dele o chão é lama/água (bloco 3) e cada tábua
  é um quad reto de largura constante, perpendicular à direção do ramo NA TELA (pontas
  perpendiculares ao eixo do ramo, encurtamento pela perspectiva), com veio/nó/rachadura e pregos
  (`WorldRoad._board`), estacas nas laterais a cada 6 tábuas, sombra nas bordas do ramo. As tábuas
  são numeradas pelo v integrado do ramo a partir do início do ramo (FORK_REL), não da primeira
  linha visível: antes elas reindexavam quando a câmera andava (teleporte de todas as tábuas).
  Um pixel só pertence a um ramo; tábua perto do limite do dono some aos poucos.
- **Abertura e fechamento contínuos.** `forkOffset` cresce com `animIn` e `forkWobK` leva o
  balanço do ramo de 1 (tronco) a 0,5 (ramo) e de volta no escolhido; o tronco extra que fazia
  crossfade com os ramos na abertura saiu. Na convergência a partição passa ao escolhido em ~0,4 s
  (`partition(..., chosenK)`), sem salto de dono no clique.
- **Coisas que estalavam na sequência** (achadas pelo `tools/estrada_seq.lua`): GroundClutter cortava
  tudo além de rel 8 enquanto a encruzilhada existia e voltava de uma vez (agora some suave pela
  borda da encruzilhada) e sumia ao cruzar rel 0,25 e com o recorte da mão durante a viagem;
  marcos da encruzilhada nasciam opacos (agora com `animIn`); o marco escolhido do andar anterior
  sumia no `showFork`; props reciclados reapareciam dentro da faixa de emergência; folhas sopradas do
  ato 6 sumiam no limite da encruzilhada e mudavam de tamanho em degrau; o tom de viagem (vermelho
  de encontro) ligava em 1 quadro (agora entra/sai em 0,6 s).
- **Detector** `lovec . test_one estrada_seq "<atos>:<planos>"` (`SEQ_RES`, `SEQ_THUMBS`, `SEQ_RAW`,
  `SEQ_RAWF=a-b`, `SEQ_KEY`): 60 fps fixos, do `showFork` ao clique, convergência, viagem, chegada e a
  próxima encruzilhada. Cada elemento (prop, árvore, poste, marco, clutter, tábua, folha) tem id
  estável e é sinalizado quando aparece/some/salta de alfa ou tamanho/teleporta DENTRO da tela fora
  da faixa da crista, CONFIRMADO pelo pixel (mudança na caixa dele maior que 2x a do quadro anterior);
  o chão inteiro é comparado com a mediana local. Trava: `test_fork_sequence` (4 casos).
  Folhas de contato: `python tools/estrada_seq_folha.py` → `tools/preview_out/estrada_seq/<res>/`.
- **Perf.** LightEngine com cache de shader/blend/uniform e a cor/intensidade/semente da luz no
  vértice (`light_dither.glsl` sem uniform por luz): ~20 draw calls a menos. Bake sem lixo
  (closures e tabelas por texel içadas, buffers FFI reaproveitados) e `jit.opt maxtrace/maxmcode`
  maiores no boot (`main.lua`): os 100-370 KB/quadro na encruzilhada eram o LuaJIT abortando traços
  (código interpretado aloca), não o bake.

## Rodada 4 (24/Out/2026): passarela contínua no ato 5, lama viva, sombras em lote

- **Ramo central = continuação da passarela.** Com 3 opções o ramo de `dirs == 0` é desenhado com
  o tile de tábuas do tronco (não lama + tábuas soltas) até o marco, e a partição dá a ele a largura
  inteira (`RoadFork.partition(..., base = central)`); os ramos laterais saem pelos lados dele. Sem
  ramo central (2 opções) o deck por `deckK` continua; com central o deck só entra pelo escolhido
  na convergência.
- **Tábuas dos ramos laterais contínuas.** Alfa da tábua = alfa do ramo × fração da largura que o
  ramo de fato possui naquela linha (0,3 a 0,65 → 0 a 1): nada de tábua por cima do vizinho e a
  passarela lateral começa colada ao central.
- **Escolhido na convergência.** O ramo escolhido (não central) troca tábuas soltas pelo tile de
  tábuas em ~0,3 s da convergência (`tk`): o caminho até a loja/batalha fica inteiro, sem sobras de
  tábua na lama.
- **Lama do pântano viva** (bloco 3 do tile): pedaços de tábua quebrada (30% das fileiras),
  juncos em tufos verticais concentrados nas bordas, brilho d'água em traço, lama mais clara com
  manchas.
- **Sombras em lote.** `ShadowEngine.sprite` cortava cada sombra com `setScissor` (quebra o lote:
  1 draw call por sombra). Agora o corte vira um `Quad` com as linhas de origem equivalentes
  (pool `SH.qp`, zerado no `endFrame`): mesmas sombras (A/B pixel: 0 px diferentes nos atos 1 e 6,
  7 px no ato 3) e ~100 draw calls a menos por quadro. Encruzilhada: 438 a 498 em todos os atos.
- **Tábua quase invisível não desenha.** Tábua solta com alfa < 0,08 sai do lote (era 0,02): na
  convergência em 3440x1440 uma tábua a 3% de alfa do ramo descartado desacelerava com o ramo e o
  `estrada_seq` acusava teleporte. 0,08 fica abaixo do passo de alfa por quadro (0,12), então o
  fade não muda.
- **Raio não é chão mudando.** O `estrada_seq` marca como corte os quadros com
  `WeatherEngine.isStriking()` (e o seguinte): rodando os 6 atos num processo, o relógio do clima
  carrega a tempestade de um ato para o outro e o clarão do ato 4 aparecia como `chao_muda`.
  Sozinho o ato 4 dava 0.

## Rodada 5 (24/Out/2026): ato 5 como obra de carpinteiro

Substitui o deck por `deckK`/`union`, o `_forkPlanks` e o tile de tábuas no ramo central das rodadas 3
e 4 (removidos; as notas acima ficam como histórico). Dono: "pilha de entulho", tábuas em X no meio.

- **Deck quadrado** (`WorldRoad.WALK`, `WorldRoad.deckSpan`): linhas de rel `FORK_REL - deckBack` a
  `FORK_REL + deckLen`, largura `deckW` × a estrada, centro fixo em u (bambeio do tronco em
  `FORK_REL`), tábuas do tile esticadas até a borda (todas paralelas, do mesmo eixo do tronco), beiral
  escuro na frente e atrás e aro lateral. `e = animIn × (1 - convergência)` leva o deck de volta à
  largura e às bordas do tronco: em `e = 0` a linha é idêntica ao tronco (abrir e fechar sem estalo).
- **Passarelas em trechos retos** (`WorldRoad._walkPoints` + `WorldRoad._marshWalks`): por ramo, uma
  polilinha no chão (u, V) calculada analiticamente por rel (mesma conta das linhas). Central: frente
  do deck → acampamento (termina no marco). Laterais: saem da LATERAL do deck (`exit` = 30% do fundo
  para a frente) → marco → além do marco, sumindo por `forkFarK`. Tábua perpendicular ao trecho na
  tela, desenhada por `_board`; nunca curva. Junta entre trechos = viga escura + poste dos dois lados;
  poste a cada `post` tábuas. Todos os ramos (inclusive o central) têm lama por baixo.
- **Sem estalo quadro a quadro.** Passo fixo (`pitch × S`, o mesmo das tábuas do tronco); na
  convergência as tábuas deslizam pelo deslocamento da câmera ACUMULADO quadro a quadro
  (`fork._ws`, componente ao longo do trecho), nunca recalculado do total (o ângulo muda e a tábua
  pulava). Alfa some nas pontas do trecho em 0,45 de passo, limitado a 0,12 por quadro por tábua
  (`R.walk.prev/cur`), e tábuas até 3 passos fora do trecho continuam desenhadas enquanto somem.
- **Convergência.** O ramo escolhido sai do lado do deck em direção ao próprio ramo, endireita junto
  com ele e troca as tábuas pelo tile do tronco só no fim (`walkTk`, k de 0,72 a 0,97), quando já
  está reto.
- **Lama.** Pedaços de tábua quebrada só na lama de fora (|u| de 0,56 a 0,95), 20% das fileiras e
  mais afundados: perto da passarela liam como tábua solta.

## Rodada 6 (24/Out/2026): deck discreto, postes legíveis

O lead viu a rodada 5 como "faixa escura chapada" no lugar onde o dono já recusou um retângulo escuro.

- **Deck no máximo 1,4 × o tronco** (`WALK.deckW`), desenhado por `WorldRoad._deckRow`: bordas com a
  mesma mordida irregular do tronco (offset de `edges`), tábuas do tile esticadas até ~88% da meia
  largura com comprimento variando por tábua (`RoadTiles.plankAt` + `plankJitter`, ±11%); as faltas e
  pontas tortas do próprio tile aparecem. Sem aro escuro lateral.
- **Beirais claros e quebrados** na frente e atrás: trechos de 10 a 28 px em madeira clara com
  frestas (30% com 4 px), sombra de 1 px por baixo, e um poste em cada canto.
- **Postes** (`WorldRoad._post`, largura `WorldRoad.postW` = 2 × arredondado de 1,35·S·hs, mínimo
  4 px = 2 px de arte): contorno escuro, lado claro, lado escuro e topo aceso. Nos cantos do deck,
  nas juntas e a cada 4 tábuas.
- **Passarela do meio presa ao deck**: começa `attach` (0,15 rel) antes da borda de trás do deck, com
  viga de junta, e vai contínua até o acampamento. Largura de tábua igual à das laterais
  (fator 0,62 + 0,24·|ey|).
- **Convergência**: o deck volta à largura do tronco nos primeiros 40% (`WALK.convK`); nenhuma faixa
  mais larga que a passarela que entra na loja.

## Rodada 7 (24/Out/2026): fluxo real, partida do nó, ramos sem continuação e ato 5 sem passarela

Dono: "erros muito, muito graves nas estradas". Substitui o deck, as passarelas, os postes e as vigas das
rodadas 4 a 6 (removidos: `WALK`, `deckSpan`, `walkTk`, `_deckRow`, `_post`, `_walkPoints`, `_marshWalks`,
`_board`, `_corner`, `_bq`; as notas acima ficam como histórico).

- **O bug do marco parado na frente.** Depois de um nó sem luta (loja, descanso, evento) o `showFork` abria
  a próxima encruzilhada com a câmera parada: o marco visitado (`WorldRoad._landmark`, no meio da estrada a
  rel 7,5) ficava estacionado na frente e cobria o ramo do meio. Na batalha não acontecia porque a viagem de
  20 leva a câmera além dele. A v5.2 limpava o `_landmark` no `showFork`; a rodada 3 tirou isso (o marco
  "sumia") e ninguém testava sair de um nó, porque o `estrada_seq` só cobria encruzilhada → viagem → chegada.
  Correção: `showFork` com um marco visitado na frente (rel entre -1 e `MARK_REL - 1`) não abre a encruzilhada,
  faz a **partida** (`WorldRoad.DEPART`: viagem de 10 em 2,9 s com `WorldRoad.travel`) e abre a encruzilhada
  no fim dela (`WorldRoad._openFork`). Uma viagem nova (`WorldRoad.travel`) cancela a partida pendente; `isDeparting()` só vale com a
  viagem marcada `depart`. O cheat espera a partida acabar para clicar na encruzilhada de verdade (antes o
  `pressFork` escolhia o nó direto e a encruzilhada abria depois por cima do chefe). Durante a partida `isForkActive()` é verdade (o `main.lua` só roda o
  `WorldRoad.update` no `mapSelection` com encruzilhada ativa) e `_fork` é nil (clique não faz nada). O marco
  sai de cena pelo lado do ramo dele (`WorldRoad.landmarkSlide`, lado = `dirs` do ramo; do meio, lado por hash
  do z), deslizando em 62 % da partida, como a estrada contornando o lugar.
- **Ramo lateral termina no marco** (escolha, clique e enquanto se está no nó). `forkFarK` mede o fim pelo z
  do marco no MUNDO (`f.markZ - camZ`), não por `MARK_REL` fixo; o escolhido não volta mais a inteiro na
  convergência. No fim da convergência nasce `WorldRoad._stop = { z, reveal }`: as linhas da estrada e a
  clareira da grama além do marco ficam com o mesmo corte (`WorldRoad.stopFarK`, mesma curva de `FORK_END`).
  Ramo do meio já continua (reveal 1). **Ao sair** o corte corre do marco até a crista em 0,8 s
  (`DEPART.reveal`, smoothstep; com 0,42 s e ease-out o `estrada_fluxo` acusava `chao_muda`) enquanto a partida começa: a continuação "pisca" para frente em vez de
  estalar. Nó de luta num ramo lateral (elite, 2ª batalha) revela já no fim da convergência, junto da viagem.
  O `forkSig` da grama inclui o reveal (sem isso o quadro de grama em cache não abria a clareira).
- **Castelo vende a curva.** `CastleDrift.pick` leva o castelo a `SIGN × dir × MAX` (0,05 da largura, oposto ao
  ramo) só durante a convergência; `WorldRoad.travel` chama `CastleDrift.back` e o desvio volta a 0 ao longo da
  viagem (partida do nó ou caminho da batalha). Não acumula mais (`STEP`/`KEEP` saíram). Ramo do meio: 0.
- **Batalha sempre no meio** (`WorldRoad.forkDirs`): nós que se atravessam andando (`WALK_TYPES`: battle 1,
  elite 2, mini_boss 3, boss 4, a prioridade decide quem fica no meio quando há dois) vão para o ramo do meio;
  os outros saem para a esquerda e a direita na ordem original. 2 opções com luta: luta no meio e a outra do lado
  em que estava na lista (antes da luta = esquerda). Sem luta: 3 opções mantêm o do meio da lista, 2 opções
  ficam esquerda/direita. Os índices dos nós não mudam (`chooseNode(index)` intacto); a ordem é decidida uma vez no
  `showFork` (Continuar recalcula igual, mesma lista).
- **Ato 5: tábuas só no tronco.** Todo ramo (inclusive o do meio) é trilha de pântano com o mesmo sistema de
  ramos dos outros atos (`RoadFork.partition` normal, sem junta dura), chão do bloco 3 do tile repintado por
  `marshTrail` (`RoadTiles`): lama pisada com sulcos e pegadas, turfa escura nas bordas, poças com brilho,
  juncos em touceiras só nas bordas, raízes entrando na trilha, musgo; bloco 4 = metade borrada do bloco 3 para a
  crista (`V.BLOCKS.marsh = 4`). As tábuas do tronco terminam rotas no barro (`WorldRoad._marshRow`): desde
  `FORK_REL - 4,6` até `+0,7` (`PLANK_END`), cada tábua (id = tile × 997 + índice, avaliada no CENTRO da tábua,
  então a ponta é reta por tábua) encurta de um lado mais que do outro, escurece (afundada) e some
  (`fade 0,22`). Tudo vezes `WorldRoad.forkE` (`animIn × (1 - convergência)`): sem encruzilhada o tronco é tábua
  até a crista e a abertura/fechamento dissolve tábua por tábua, sem estalo.
- **Rótulos dos marcos** somem em 0,25 s depois do clique (antes sumiam no quadro do clique), a dica do
  escolhido junto.
- **Prop que não é vegetação atrás da crista** (ruína, santuário) some/volta com `forkE` em vez de zerar no
  quadro em que a encruzilhada abre/fecha; o do corredor do ramo escolhido usa `(1 - k) × animIn`.
  Na frente da crista (rel de `REL_CREST - 3` à crista) o mesmo `forkE` entra em rampa, senão o prop que cruza
  a crista na convergência saltava de 0,46 para 1 (`test_scene_continuity`, santuário do ato 6).
- **Abertura da encruzilhada continua em 2,2/s.** Com 1,7/s um clique antes de abrir tudo (0,42 s) fazia o
  `test_scene_continuity` acusar pop de luminária: clicar durante a abertura ainda é ponto fraco.
- **Terra sob a mão.** `GroundClutter` não corta mais de uma vez o que fica sob a mão quando ela entra: some em
  0,35 s (`LMG.handK`, `env.handK`). Era o `clutter some` na chegada.
- **Trava e ferramenta do fluxo real.** `lovec . test_one estrada_fluxo "<atos>:<planos>"` dá boot no
  `main.lua` (como o `test_cheat_mode`), modo cheat sem painel, CRT desligado, 60 fps, mouse falso: encruzilhada
  real → clique pelo `love.mousepressed` → convergência → tela do nó (loja/descanso/evento pelo rush do cheat;
  luta vencida pelo `kill`) → saída → partida → próxima encruzilhada. Detector do `estrada_seq` (aparece/some/
  salta/teleporta) + `opcao:coberta` (algo mais perto cobrindo > 22 % de um marco clicável; árvore só se o pé
  cai no miolo do marco) + `landmark:parado_na_frente`. Planos: 3 opções (loja, descanso, batalha, evento, sem
  luta no meio e do lado, elite do lado) e 2 opções (loja, batalha, sem luta). Folhas:
  `CARDGAME_IDENTITY=<id> python tools/estrada_fluxo_folha.py [prefixo]` → `tools/preview_out/estrada_fluxo/`
  (`folha_<tag>.jpg` quadro a quadro, `momentos_<tag>.jpg` encruzilhada/chegou/tela/saiu/saiu+10/próxima).
  Trava: `love . test_one test_fork_flow` (no test_all): ordem dos ramos + 6 fluxos reais com 0 sinais.
  Custo: o `love.graphics.present()` por quadro capturado é obrigatório; sem ele o driver acumula ~2 MB por
  quadro desenhado (12 GB numa varredura e a máquina do dono travou). Leitura das diferenças num canvas
  480x270, ImageData liberada à mão, `log.frames` com janela de 3 quadros, miniaturas só com `SEQ_THUMBS=1`,
  teto `SEQ_MEM_CAP` (4000 MB, aborta a captura). Medido: ato 5 inteiro com pico de 733 MB (antes 1 GB por
  plano). Rode um processo por ato (`estrada_fluxo "5"`), sempre com `CARDGAME_HEADLESS=1`.

## Rodada 8 (24/Out/2026): ato 5 sem tábua nenhuma, ato 3 refeito

Dono: as tábuas do ato 5 "dão muito glitch" ao escolher batalha com três opções; "tira as tábuas em geral, deixa
só um caminho, com poças". E o chão do ato 3 "ainda muito feio, muito estranho".

- **Ato 5 = trilha de pântano em toda parte.** Apagados: `PAINT.marsh` de tábuas, `plankTable`, `V.plankAt`,
  `marshSeed`, o parâmetro `np` da pintura, `V.BLOCKS` (o tile do pântano voltou a 2 blocos), `st.bare`, o
  borrão especial do pântano (vertical 13 e `k` 0,08) e os `farT0/farT1/farDv` dele; no `WorldRoad` saíram
  `PLANK_END`, `plankNeed`, `_marshRow` e o deslocamento `ub` do `span`. Tronco e ramos usam o mesmo
  `span`/`RoadFork.partition` dos atos 1 a 4. As notas das rodadas 2 a 7 sobre passarela/deck/tábuas são
  histórico. `WorldRoad.forkE` continua (props usam).
- **Pintura do pântano** (`PAINT.marsh`): lama pisada (`MUD`, rampa de 7 tons mais clara) com sulcos rasos
  (`rutDepth 0,6`), manchas grandes seca/molhada (`macro`, fbm 3x9) que sobrevivem ao borrão da crista (era o
  "escuro e chapado ao longe"), poças nos sulcos e baixios (`puddle`, limiar `PW 0,63`): borda de turfa escura,
  reflexo escuro da margem de longe, brilho na margem de perto, faixas horizontais de céu (rampa `WATER` vem do
  céu do bioma); lama úmida escurecida em volta com brilho raro; pegadas (algumas cheias d'água); turfa
  fibrosa (`PEAT`) e musgo nas bordas; juncos só na margem (e > 0,8); raízes entrando; gravetos raros (`leafAt`
  fino com `woodPick`); tufos de capim na lama.
- **Ato 3 refeito** (`PAINT.abyss`). Diagnóstico do antes (1:1): asfalto cinza liso e frio sem micro detalhe,
  rede de voronoi de polígonos iguais desenhada como contorno (casco de tartaruga), brasa em manchas
  saturadas sem calor em volta, listras verticais de sulco e de `streak`, cor cinza contra o chão vermelho.
  Agora: cinza vulcânica quente (`ASH` misturado com `rock`), escória em 4 tamanhos de pedra facetada
  (`SCORIA` vermelha e `SOOT` basalto; a menor, `stone` célula 3, dá o grão), placas de lava fria nos
  ombros, fendas angulares e ESPARSAS (`crackNet`: voronoi com a aresta aberta só se o hash do PAR de células
  passar, entrada tremida), poucas fendas com brasa e halo `HEAT` em volta, manchas de cinza soprada,
  sulcos rasos (`rutDepth 0,35`, a rampa do sulco agora respeita `rutDepth` em todos os atos que o declaram).
- Provas: `python tools/chao_v8_folha.py` (identity `road_v8`, capturas `ESTRADA_TAG=antes|depois`) →
  `tools/preview_out/chao_v8/ato{3,5}/<cena>_<res>.png` (batalha, 3 opções, 2 opções, convergência em
  1280x720, 1920x1080, 3440x1440; perto e longe 1:1). `screenshot_estrada_final` agora chama `present()` por
  quadro e libera a ImageData. `estrada_fluxo` atos 3 e 5: 0 sinais; `estrada_seq` ato 3: 0, ato 5: 1
  (`prop:aparece` de árvore morta na viagem do plano 2dir, igual no main 02bd0c2d, só rodando o ato inteiro).
- Perf (`perf_estrada_final`): encruzilhada ato 3 ~500 dc, ato 5 ~445 dc; bake do ato 3 2,6 a 2,9 s (cede no
  pré-aquecimento), ato 5 1 a 1,6 s.

## Rodada 8b (24/Out/2026): ato 3 com detalhe perto da câmera

Lead: o ato 3 da rodada 8 lia como faixa marrom lisa e borrada perto da câmera. Sobre b80f0cc7:
- `stone` devolve também `d` e o `si` da faceta (`return h, val, c, d, si`); `rim` (só no ato 3) acende a borda de
  CIMA da pedra (faceta com `si > 0,25`, y maior = mais longe = acima na tela) e escurece a de baixo, ±0,42.
- Placas de lava fria com borda nítida (`pd > 0,86`: +0,32 em cima, -0,3 embaixo) e corda de pahoehoe mais forte;
  mais placas (`0,55 × (sho + 0,35)`).
- Fendas com brasa mais frequentes e 1,35x mais largas (`hot > 0,47`, `ce < 0,38`, ruído `hot` 4x22) para cair
  uma na frente da câmera; halo `HEAT` até 6 larguras com queda quadrática; o grão miúdo some dentro do halo.
- Grão da cinza em blocos de 1 e 2 texels (±0,15) e manchas de cinza soprada.
- Sulcos de pneu: `OPT.a = { rutW 0,075, rutDepth 0,75, lip 0,26 }` (o lábio de `trail` aceita `o.lip`).
- Contraste local, não brilho: rampas `ASH` (9 tons), `SOOT` (7), `SCORIA` (7) e `HEAT` (5) com pontas mais
  escuras e mais claras; o meio da rampa ficou onde estava.
- Longe continua o borrão de sempre (`k` 0,22). Ponto fraco: na junção da encruzilhada, a meia distância, a rede
  de fendas acesas fica densa (a perspectiva comprime várias fileiras do tile).
- Provas: `tools/preview_out/chao_v8/ato3/` (antes = b80f0cc7). `estrada_fluxo 3` e `estrada_seq 3`: 0 sinais;
  encruzilhada 500 dc, bake 1,7 a 2,9 s.
