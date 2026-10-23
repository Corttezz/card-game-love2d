---
name: roadwear_engine
description: Solo do caminho — RoadTiles (tile por bioma, escolha do dono), RoadSurface (cache/bake), RoadFork (encruzilhada como um chão só), RoadDecals (folhas sopradas do ato 6)
type: architecture
---

# Solo do caminho (23/Out/2026, estrada final escolhida pelo dono)

O dono escolheu UMA variante por ato na folha `tools/preview_out/estrada_variantes/visao_geral_18_tod65.png`:
ato 1 A trilha gasta, ato 2 A trilha de cascalho, ato 3 A trilha de cinza com rachaduras e brasa,
ato 4 A neve pisada, ato 5 B passarela de tábuas, ato 6 A trilha de folhas. As outras 12 variantes,
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
