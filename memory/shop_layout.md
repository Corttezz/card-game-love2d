---
name: Loja em tela cheia (layout sem modal)
description: Decisão Out/2026 — a loja deixou de ser um modal sobre o interior pintado e passou a ocupar a área de jogo, zonas separadas por respiro (sem moldura). Variantes testadas, critério de escolha e o que NÃO reintroduzir.
type: project
---

# Loja em tela cheia (Out/2026)

Queixa do dono: "a loja está meio poluída, talvez seja o background de fundo com
o modal na frente". `components/CardRewardScreen.lua`, modo `"shop"`.

## Diagnóstico (medido nas capturas 1024×768 / 1280×720 / 1920×1080)

1. **Cinco retângulos dourados aninhados**: painel com moldura dupla → barra de
   título com contorno duplo → caixa da vitrine → coluna de detalhe → caixa do
   rodapé de ações. Mais a placa de cada relíquia = seis níveis.
2. **Cenário vivo vazando pelas bordas**: o interior pintado (`shop_interior`,
   estantes, lampião, moedas) aparecia só em pedaços em volta do modal — em
   1920 ocupava ~40% da tela competindo com as ofertas.
3. **Informação repetida**: ouro na TopBar E na barra de título ("Ouro: $30" a
   50px do "$30"); etiqueta "◆ RELÍQUIA ◆"/"◆ PACOTE ◆" sob objetos que já
   dizem o que são; "Efeitos: - Ganha 5 de Bloqueio" repetindo a descrição
   logo acima (desde a auditoria descrição = efeito real).

## Variantes testadas (switch temporário + `tools/screenshot_shop.lua`)

- **A** tela cheia, SEM cenário (superfície escura lisa + luz central suave)
- **B** tela cheia com o interior da loja como cenário (véu 0.50), sem caixa
- **C** modal "limpo": uma moldura só, sem sub-painéis, fundo mais escuro

Critérios: ler em 1s o que está à venda e quanto custa; hierarquia cartas >
relíquias/pacotes > ações; menos camadas; coerência com o resto do jogo.
**A venceu.** B: o texto do painel de detalhe ficava ilegível sobre a mesa de
moedas e as garrafas brigavam com os pacotes. C: melhorou, mas ainda era
"caixa sobre cenário" e o fundo continuava vazando nas bordas em 1920. A tem
o mesmo idioma do modo recompensa (banner com filetes + "?", sem painel).

## Como ficou (não regredir)

- `self.panel` = área útil sob a TopBar (margem 12–40px, teto 1560px de
  largura). Continua existindo porque as ZONAS o fatiam e o `validateLayout`
  confere — só não é desenhado.
- Cabeçalho solto (`_drawShopHeader`): título + filetes + "?" das regras. SEM
  ouro (a TopBar mostra).
- Vitrine/rodapé sem caixa; zonas separadas por `colGap` (16–40px). O
  `validateLayout` agora exige vitrine ∩ detalhe = ∅ e rodapé abaixo das duas.
- Sem etiqueta de categoria em relíquia/pacote (chaves `reward.badge_*` e
  `reward.gold_label` removidas dos 5 locales). Cartas mantêm a raridade.
- `CardDetailPanel` só lista em "Efeitos:" o que a descrição ainda NÃO diz.
- Nome de pacote com palavra maior que o slot (DE "Totengräbertuch") vai em
  linha única via TextFit, em vez de o printf cortar a palavra no meio.
- Removidos: `_drawTitleBar`, `_drawActionBar`, `drawCategoryBadge`,
  `drawTitle` (morto), `_drawPanel`. O PNG `shop_interior` ficou sem uso.

## Ferramentas

`SHOP_W/SHOP_H/SHOP_TAG/SHOP_LOCALE/SHOP_SEED` no `screenshot_shop` (seed fixa
4242 por padrão: mesma vitrine em todo tamanho) e a TopBar real desenhada por
cima, como no jogo. `love . screenshot_shop resize` = tortura de resize.
Trava: `test_upgrade_tile` roda a loja nos 5 idiomas × 7 tamanhos (800×600 até
2560×1440) com oferta selecionada.

**Why:** ruído = molduras empilhadas + cenário cortado + informação repetida;
nenhum deles carregava informação. **How to apply:** ao adicionar algo à loja,
coloque numa zona existente e separe por respiro — não por moldura nova. Ver
[[ui_design_system]] e [[ui_layout_invariants]].

## Ambiente (Out/2026, "mais bonita")

Sem voltar ao cenário: `_drawShopAmbience` (luz âmbar em degraus do alto da
vitrine + vinheta lateral, fora do slide) e `_drawShopShelves` (tábua de
madeira sob cada fileira, dentro do slide — entra com as ofertas). Nenhum
texto, nenhuma moldura nova. Seções NÃO ganharam cabeçalho de texto: a
prateleira já separa os dois andares, e rótulo de categoria foi o ruído
removido acima. Teto de largura da vitrine = `max(1560, sh*1.25)` (em 1440p
um terço da tela ficava vazio).

## v3b: o Balcão do Mercador EM PERSPECTIVA (Out/2026)

Pedido do dono (referência `docs/plan/shop_reference_gpt.png`, plano §12):
"as coisas na diagonal, o cenário bem parecido com isso pra dar sensação de
profundidade; hoje está preso a um todo plano". A v3 "estante + prateleira
+ balcão tileável" (commits 10b87ff1/d756449f) durou um dia: a loja virou
UMA PINTURA com objetos apoiados nela.

- **A cena é uma pintura**: `assets/sprites/shop/counter_scene.png`
  (688x384, PixelLab `create_image_pro` com a referência do dono como guia
  de composição; `tools/pixellab_shop_props.py scene queue|poll`), desenhada
  em cover-fit (mesma conta do `SceneBackground` dos salões). Balcão em três
  quartos, estantes de frascos atrás, vela e caveira à esquerda, lanterna
  pintada no alto (o pulso de luz usa `ShopProps.lightLevel`; o sprite da
  lanterna NÃO é desenhado), pano vermelho, livros e moedas no canto.
- **Slots em coordenadas da ARTE** (`ShopLayout.ART`): 4 cavaletes na borda
  do fundo (a esquerda é mais perto: escala 1,0 → 0,85) e 4 objetos na mesa
  em diagonal esquerda-frente → direita-fundo; sino e copo de dados à
  esquerda. `layout()` converte arte→tela e `validate()` confere pé dentro
  das MÁSCARAS pintadas (`ledgeMask`/`tableMask`, ponto-no-polígono), placas
  sem se tocar, nada sobre carta/pergaminho/CONTINUAR/placa de título.
  Janela estreita (4:3): o cover-fit corta a esquerda, a diagonal DESLIZA pra
  direita e, se ainda não cabe antes do pergaminho, COMPRIME (espaçamento e
  escala); a ordem e a profundidade nunca mudam. 9 tamanhos x 5 idiomas em
  `test_shop_layout`.
- **Cartas em cavaletes** (`card_stand_N.png`) com perspectiva FIXA do
  `card_perspective.glsl` (uniform `mouse = {0.8, 0}`, amount 0,7: a borda
  direita foge, como a mesa) e **placa de latão** procedural sob cada uma:
  raridade em cima (cor da raridade, escurecida), preço embaixo; selo NOVA
  do `DiscoveryMark` no topo. Hover levanta 8 px + brilho de borda;
  selecionado = brilho firme; sem ouro = preço vermelho e a placa treme.
- **Objetos NOVOS na mesa** (`assets/sprites/shop/objects/<id>.png`, 64 px,
  PixelLab pixen com "no table, no candle": o pixflux desenhava uma vela ao
  lado de tudo): tesoura sobre carta cortada, bancada de coringa, frasco,
  cristal, bigorna, prensa, grimório, arca, 5 fardos (pack_<id>) e o sino.
  Placa: efeito curto (`UpgradeTile.effectLabel`) ou nome do pacote + preço.
  Pacote não voa: abre o PackOpenScreen.
- **Pergaminho à direita** (9-slice + papel liso + `CardDetailPanel`
  `parchment`/`artMaxH`) com o botão **COMPRAR · $N** no rodapé. Clicar no
  objeto SELECIONA (`setSelectedOffer`, sem toggle); a compra é no COMPRAR
  (ou Enter/A nele). A primeira oferta já nasce selecionada e, depois de
  uma compra, o pergaminho passa pra próxima disponível. **CONTINUAR** é o
  `skipButton` visível no canto inferior direito; sino e copo são objetos
  na mesa com placa ("NOVAS OFERTAS $4" / "DADOS"), os Buttons deles são
  hitboxes invisíveis; os dois "?" ficam na placa de título.
- Sino: objetos antigos deslizam pra fora da mesa pela esquerda, os novos
  entram pela direita um a um (stagger 60 ms), tudo por `item.slide.x`
  (tabela, sobrevive ao rebuild do primeiro update).
- O que saiu: tábuas tileáveis, balcão procedural, etiquetas penduradas
  (o dono gostou; voltam como detalhe se sobrar tempo), feixe de luz na
  parede (a pintura já é iluminada).
- Travas: `test_shop_layout` (515 asserts) e `test_shop_scene` (82).
  Capturas fiéis à escala: `love . test_one screenshot_uiscale pt_BR:shop`;
  quadros de compra/sino: `SHOP_W=1280 SHOP_H=720 love . screenshot_shop fx`
  + `python tools/pixellab_shop_props.py sheet <tag>`.

### Fechamento (fase C)

- **Placas**: carta = FAIXA DE TINTA com a raridade na cor (clareada) e o
  preço SÓ na etiqueta pendurada do canto dela, balançando no hover (o latão
  com o mesmo "$3" ao lado era informação repetida; se a etiqueta cairia
  sobre o sino/copo, vai pro canto esquerdo); objeto = placa de latão com efeito
  curto / nome do pacote (quebra em 2 linhas, nunca reticências) + preço.
  Oferta do dia: etiqueta vermelha PRESA à placa (torta no canto) + brilho
  âmbar no objeto. O copo de dados está SEMPRE na mesa (o clique é que
  depende de `_G.openScribeDice`; `screenshot_uiscale` registra um stub).
- **Perf** (`SHOP_W=2560 SHOP_H=1440 SHOP_FRAMES=400 love . screenshot_shop
  perf`, vsync desligado, k=1): balcão em perspectiva 1,2 a 1,6 ms/quadro
  contra 1,7 a 1,9 da vitrine antiga (b82efa13, mesmo tool numa worktree).
  Meta era ≤ antiga + 1 ms. Com vsync a medida vira 1/Hz do monitor (4,17 ms
  a 240 Hz): o modo perf desliga.
- **Teclado/pad**: cartas registram no draw da cena (chave = instância com
  `shopOffer`), relíquia/pacote em `NavCursor.target("offer:<slot>")`,
  COMPRAR/CONTINUAR são Buttons, sino/copo hitboxes invisíveis; X = sino,
  Y = CONTINUAR, LB = "?" dos dados. `CARDGAME_IDENTITY=<limpa> love .
  nav_flow` atravessa a loja (A na carta seleciona, A no COMPRAR compra,
  CONTINUAR pelo foco): 30/30. Com a identidade `lojacena` (run.tool.lua
  salvo pelas capturas) o fluxo morre na seleção de classe, antes da loja:
  rode com identidade limpa.
- **UiScale**: `components.CardRewardScreen` já estava em `UiScale.SCREENS`;
  as capturas fiéis saem de `love . test_one screenshot_uiscale pt_BR:shop`
  (o `screenshot_shop` captura a k=1: compare layouts, não o tamanho).

## v3c: TUDO na diagonal, nada flutua (13/Out/2026, feedback do dono)

Queixas: objetos novos "estranhos" com elipse de sombra ("voando em cima da
bancada"), hover trocava a imagem (o pergaminho desenhava a arte antiga com
pedestal ao lado do objeto novo da mesa), placa de latão de 2 linhas feia,
cartas "apontadas pra frente", suporte feio e fora da diagonal.

- **Perspectiva única** (`ShopLayout.VP` = ponto de fuga (2187, -58) em px da
  arte, medido nas bordas pintadas: fundo ~6,8°, frente ~11°). A diagonal num
  ponto é a reta até o VP: `ShopLayout.slopeArt(ax, ay)`. Objetos, sombras,
  etiquetas, faixas de raridade, cartas e cavaletes usam esse slope.
- **Artes ANTIGAS** (`vouchers/<id>.png` + `vouchers_anim/` no hover;
  `packs/pack_*.png`) em pé, com pose por id (`ShopPerspective.POSE`: espelho
  pras artes vistas "da direita", ex. bancada de coringa; fração do
  cisalhamento). `shop/objects/` ficou só com o sino.
- **Canvas na resolução da arte** (`ShopPerspective.artPass`): objetos,
  sombras e cavaletes são rasterizados em 688x384 e sobem com nearest junto
  da pintura: o cisalhamento sai em pixel quadrado, na grade do cenário.
- **Sombra de CONTATO** (`drawContactShadow`): perfil da silhueta (base real
  de cada coluna), dither Bayer, cauda curta pra direita (vela à esquerda),
  cortada pelo `tableMask`. Elipse proibida (`test_shop_scene` conta).
- **Hover** = mesmo sprite/pose/espelho/cisalhamento, +5 px e contorno claro
  de 1 px de arte (shader de silhueta). `ShelfItem:pose()` travado no teste.
  O pergaminho usa `CardDetailPanel opts.objectArt` = o mesmo sprite.
- **Rótulos**: preço = etiqueta pendurada (a das cartas) presa ao objeto por
  um cordão até a borda da silhueta (`tiePoint`); nome/efeito = faixa de
  pergaminho na diagonal SÓ no hover. Sino com etiqueta "$N"; copo sem.
- **Cartas**: paralelas à borda do fundo, 4 cantos por `ShopLayout.cardQuad`
  e homografia no `card_perspective.glsl` (`quadOn` + `hRow0..2`;
  `CardMesh.setUniforms` zera `quadOn` sempre: o shader é compartilhado).
  Hover: a direita afunda (encolhe/recua), a esquerda sobe, levanta 8 px.
  Cavalete procedural em px de arte: trilho com face de cima/da frente,
  dois batentes, perna de trás, pés e sombra de contato na borda.
- Capturas por estado: `love . test_one screenshot_shop_diag <loc>`
  (`SHOP_SIZES`, `SHOP_STATES=rest,hovercard,hoverjoker,selectjoker`).

### v3c parte 2: pergaminho coeso + carta girada de verdade

- **Pergaminho** = um rolo procedural no tamanho de pixel da pintura
  (`ShopScene` `buildScroll`, cache por tamanho): o papel sai de DENTRO do
  rolo de cima e entra no de baixo, os dois rolos são cilindros do mesmo
  papel com a mesma largura; só as pontas do bastão (ponteira de latão)
  saem pros lados. Pendurado num cordão em V até o prego (o rolo começa
  `cordH` abaixo do prego). Papel uniforme no miolo (o texto mora ali),
  bordas escurecendo em degraus com dither, lado longe da lanterna um
  degrau mais escuro. `scroll_frame.png` (9-slice) saiu.
- **COMPRAR** = fita vermelha com selo de cera DENTRO do papel; o Button
  vira hitbox invisível (clique, teclado, pad e NavCursor continuam nele);
  sem ouro a fita desbota.
- **Carta**: em repouso a borda de CIMA acompanha a borda do fundo da mesa e
  a base gira mais (virada pro fundo); no hover o topo inclina pra baixo à
  direita, a direita encolhe e a carta levanta (`h*0.06`, até 12 px).
  O trilho do cavalete segue a base da carta e cobre só 2 px de arte da
  moldura: o rodapé (tipo e valor) fica à vista (`RAIL_ART`/`RAIL_COVER_ART`).
- Copo de dados: sombra de contato na largura do copo; "DADOS" no hover sai
  ABAIXO do copo (acima batia na etiqueta da carta 1).

## Loja "reta" (13/Out/2026, feedback do dono)

Queixa: "as cartas não estão seguindo a mesma reta; o texto COMUM, RARA etc
está feio; o hover das cartas está estranho" (captura com duas retas
vermelhas na diagonal da mesa: base da carta e faixa fora delas).

- **Uma reta por carta**: `ShopPerspective.edgeFrame(slot, cv)` = origem na
  BORDA PINTADA do degrau do fundo sob o centro da carta + inclinação k da
  borda + vetores u/n + escala. Carta (`ShopLayout.cardQuad`), trilho do
  cavalete (`drawStandArt`, em px de arte), plaquinha de raridade, etiqueta,
  sombra no trilho: tudo `frameAt(f, u, v)` = translate(origem)+shear(0, k).
  A borda é `ART.ledgeEdge` (medida na PNG: última linha clara do tampo do
  degrau, 6,83 graus, rms 0,7 px, passa no VP). A quina de baixo do trilho
  fica SOBRE ela; as 4 bases são colineares. O topo da carta foge pro VP
  (a borda direita sai mais curta pela perspectiva, sem CARD_RK inventado).
- **Plaquinha de latão** pregada na frente do trilho (4 tons + 2 pregos),
  raridade em fonte 8 (mín. 7) na cor dela clareada até contraste >= 4,5 com
  o latão (`ShelfItem.rarityInk`). Comum SEM placa (`ShopLayout.PLATE_COMMON
  = false`: prancha `diag_plates_*` mostrou a fileira mais limpa). Etiqueta
  de preço pendurada da ponta direita do trilho com cordão longo o bastante
  pra passar ABAIXO da plaquinha (carta estreita não cabe as duas lado a
  lado; empilhar nunca corta texto).
- **Hover**: mesmo ângulo, sai na PERPENDICULAR da borda 10..14 px
  (`c.lift`), escala 1,06 em torno do centro da base, sombra no trilho
  crescendo. Tempo linear (`ShelfItem.HOVER_TIME` 0,18 s) + smoothstep: ida e
  volta pelo mesmo caminho, sem salto (vale pros objetos também).
- Travas: `test_shop_layout` mede a borda NA PNG e exige base/trilho/placa/
  etiqueta a <= 0,5 grau entre si e da borda, trilho a <= 1 px de arte da
  reta, hover sem deslocamento ao longo da borda; `test_shop_scene` exige
  hover sem torção, passo por quadro <= 15% do lift, caminho simétrico e
  contraste das placas.
- Prova: `SHOP_STATES=rest,hovercard,guides,hoverstrip,plates love . test_one
  screenshot_shop_diag <loc>` (guides = linhas guia só na captura;
  hoverstrip = 8 quadros 1:1).

## v4: inclinação 1:8, cenário simples, tudo na grade (13/Out/2026)

Estudo e prancha: `docs/plan/shop-v4-estudo.md` + `shop_v4_estudo.png`.
Queixa: "suporte com escadinha", "cenário mais simples e mais da arte do
jogo, só duas bancadas", "elixir e pacotes ruins na diagonal", "hover
estranho".

- **Uma inclinação de pixel art, 1:8** (`ShopLayout.K = -1/8`, sem ponto de
  fuga): degrau, mesa, carta, trilho, plaquinha, etiqueta, sombras. Toda
  reta em degraus usa `ShopLayout.lineY(y0, x) = y0 - floor(x/8)` (MESMA
  fase da pintura). Cisalhamento de arte antiga: só 1:8 ou 1:16 (`POSE.shear`
  1 / 0,5 / 0). Fração qualquer = escada irregular (o defeito da v3c).
- **Pintura 640x360** montada por `tools/shop_v4_compose.py`: parede do
  PixelLab (`tools/pixellab_shop_v4.py queue walls`, estilo do
  `castle_hall_1`) + degrau e mesa desenhados na grade (textura reta
  deslocada 1 linha a cada 8 colunas, rampa de 8 tons sépia, realce de 1 px
  na aresta da frente). Nada SOBRE as superfícies. Retas em
  `ShopLayout.LINES` (espelhadas em `G` do tool: mudou uma, mude a outra e
  recomponha). Cover-fit em MÚLTIPLO INTEIRO (2 no virtual 1280x720) quando
  o recorte extra é <= 20%.
- **Objetos em escala 1** na grade (pixel do sprite = pixel da mesa); a
  etiqueta, a plaquinha e o cavalete são pixel art no canvas da arte
  (`drawPlateArt`, `drawStandArt`); só o texto vai pra UI (`drawPlateText`).
  Etiqueta balança em px inteiros (`swingArt`), sem rotação.
- Sem lanterna pintada: `L.lantern = nil` (sem mariposa nem pulso).
- Travas: `test_shop_layout` MEDE as duas arestas na PNG (desvio 0 de
  `lineY` em toda coluna, degraus todos de 8 px), passo constante de cartas
  e objetos, sino+copo na ponta, bordas laterais da carta iguais.
  Prova: `SHOP_STATES=rest,guides,stand love . test_one screenshot_shop_diag`.
- **Hover da carta com tilt 3D** (v4, commit 2): a pose diagonal é a base;
  `Card.hoverTilt(relX, relY)` (a conta ÚNICA do tilt, extraída do
  `Card:updateMouse`) recebe o mouse levado pro espaço da carta pela INVERSA
  da homografia de repouso (`ShopPerspective.unmapH`) e o
  `card_perspective.glsl` aplica o press antes da homografia (o modo quad já
  compõe). Amortecimento exp (`ShelfItem.TILT_EASE`), parallax de meio
  `MOVE_RANGE`, sombra segue o tilt. reducedMotion zera. Trava em
  `test_shop_scene` (cantos, centro, saída, base sem torção). Prova:
  `SHOP_STATES=tilt,hoverstrip`.
- **Elixir e 5 pacotes desenhados na diagonal** (`assets/sprites/shop/v4/`,
  `tools/shop_v4_items.py` + `pixellab_shop_v4.py queue items`: pro com a
  antiga como identidade + guia cisalhada 1:8). `ShopPerspective.spriteFor`
  prefere a v4 (mesa e pergaminho); POSE.shear = 0 pra elas. Os PNGs antigos
  seguem na abertura do pacote e na coleção. O arcana v4 saiu ~15% mais alto
  que os outros (todas as 16 candidatas); cabe na fileira (validate ok).
  Prova: `SHOP_STATES=items`.

## v5: espaço da bancada, apoio e preço preso no dono (13/Out/2026)

Briefing do dono (12 itens): a vitrine parecia "montagem de elementos
posicionados independentemente sobre uma imagem". Causas confirmadas no
código da v4 (ab572ebc):

| sintoma | causa |
|---|---|
| escada acentuada nas cartas | `ART.cards` com passo FIXO de 98 px de arte para cartas de 52: vão de 46 px e 12 px de subida por carta (36 px na fileira) |
| etiquetas brancas flutuando | `railPlates`: etiqueta pendurada da PONTA DIREITA do trilho, empurrada pra baixo da plaquinha de raridade, caindo no vão escuro entre o degrau e a mesa; objetos com etiqueta deitada à direita-frente presa por um cordão de 1 px quase invisível |
| fila rígida na mesa | `ART.objects` com passo constante de 78 e TODOS os pés na mesma reta (`LINES.objects`) |
| carta "levitando" no hover | `cardQuad(c, hover, lift)` tirava a carta 10-14 px do trilho + escala 1,06; parallax do tilt (`TILT_PARALLAX` 0,5) andava com a carta inteira; o press do `card_perspective.glsl` subia a BASE 3% da altura |
| sino com pixel diferente | `_drawBellArt` com escala `34/45 = 0,755` do sprite, ao lado de objetos em escala 1 |

O que mudou (commit 1, composição/apoio/etiquetas):

- **Parâmetros centrais** em `ShopLayout.SHELF / TABLE / PLAQUE` (px de
  arte): vão entre cavaletes (10, cede até 4 na janela estreita), folga do
  trilho, reta-base da mesa, passo de profundidade, grupos e vãos, altura e
  fonte da plaquinha. Nada de coordenada de tela solta.
- **Cartas = GRUPO** centrado na zona da vitrine (borda visível esquerda até
  o pergaminho): passo = trilho + vão. Subida da fileira 25 px de arte
  (era 36). Âncora = centro da base (`c.anchor`), dentro do trilho.
- **Hover sem levitar**: `CARD_LIFT = 0`, `CARD_HOVER_SCALE = 1`, objetos
  `LIFT = 0`; tilt sem parallax; no shader, modo quad multiplica o
  deslocamento por `(1 - uv.y)` (base PRESA, espelho Lua `ShelfItem.warpUV`).
- **Preço = plaquinha de latão** (um tratamento só): carta = pregada na FACE
  do degrau, centrada sob a carta, com a GEMA da raridade (comum sem gema);
  objeto/sino = em pé no tampo, centrada logo à frente do pé, com topo e
  sombra de contato. Valor gravado em tinta (contraste >= 4,5, travado),
  sem ouro em vermelho escuro, oferta do dia = canto vermelho dobrado,
  selecionado = aro dourado. Plaquinha de raridade e etiqueta pendurada
  SAÍRAM (raridade por extenso fica no pergaminho e no selo da carta).
- **Mesa em três grupos** (`ShopLayout.tableRow`): ferramentas (copo, sino)
  | serviços (relíquias em V raso: a do meio 4 px atrás) | pacote. Vão
  dentro do grupo < vão entre grupos (travado). Copo ganhou um dado de
  enfeite À FRENTE (lia como caneca sem preço); os dados jogados também vão
  à frente (antes caíam em cima do sino).
- **Destaque**: hover = anel de pergaminho 1 px de arte (silhueta da carta
  pelo shader, acompanha o tilt) + aresta do trilho clara; selecionado =
  anel dourado com filete de tinta + aresta do trilho e aro da plaquinha em
  ouro. Objetos: mesmo código de cor no contorno.
- Travas novas: `test_shop_layout` (vão, subida, grupos, V raso, âncora
  dentro do trilho, hover sem deslocar nada, plaquinha no eixo/na face/no
  tampo, distância da aresta da frente, CONTINUAR com respiro) e
  `test_shop_scene` (base presa no tilt, sem parallax, sem lift, contraste
  do preço, texto exato da plaquinha). Capturas:
  `SHOP_STATES=rest,hovercard,hoverjoker,selectcard,bought,broke love .
  test_one screenshot_shop_diag <loc>`.

### v5 commit 2: escala inteira, fundo calmo, luz e sombras de pixel

- **Pintura com MARGEM**: `counter_scene.png` agora é 688x408 = miolo
  640x360 + `ART.pad` 24 px de cada lado (parede espelhada nas bordas,
  superfícies e painéis continuam pela conta 1:8). Todas as coordenadas
  continuam no MIOLO. `coverTransform` escolhe o MAIOR inteiro em que a
  pintura com margem cobre a janela: 1366x768, 1024x768 e 1280x800
  (virtuais) caíam em 2,13-2,22 (pixel de 2 e 3 px misturados) e agora são
  2. Trava: `test_shop_layout` (pixel inteiro e cobertura nas 6 resoluções).
  Recompor: `python tools/pixellab_shop_v4.py compose
  tools/preview_out/shop_v4/raw/wall_b.png assets/sprites/shop/counter_scene.png`.
- **Fundo que não disputa** (`calm_wall` no compose): parede com menos
  saturação e contraste e uma POÇA DE LUZ em degraus (dither) sobre a área
  de exposição; frascos/cortina um degrau mais escuros. Sem blur.
- **Luz da cena nos sprites** (`ShopLayout.ambientAt`): objetos e sino
  multiplicados pela mesma queda da pintura (vela à esquerda), suavizada e
  quente, piso 0,7. O pacote da ponta direita deixou de ser o objeto mais
  claro da mesa.
- **Sombra da carta em pixel art** (`ShelfItem:drawCardShadowArt`): faixa
  de 3 px de arte à DIREITA da carta, nascendo no apoio, dither Bayer, numa
  passada da arte ANTES das cartas. O polígono liso deslocado saiu.
- Escala dos objetos: TODOS em escala 1 da grade (sino incluso). Pela
  medida física (carta = 96 px de arte; sino de balcão ~40%, frasco ~60%,
  pacote ~ 2/3 da carta) os sprites já têm tamanhos coerentes; o destaque
  do frasco/pacote foi tratado com a luz da cena, não com escala
  fracionária (que misturaria tamanhos de pixel).

### v5 commit 3: pergaminho, estados, CRT sobre texto, ajuda dos dados

- **Pergaminho medido** (`CardDetailPanel.draw` devolve `{fits,
  contentBottom, artH, font}`): o bloco de texto é medido com as mesmas
  regras do desenho; cede primeiro a ARTE (até 45% do teto), depois um
  degrau de fonte (descrição nunca < 8). `line()` só escreve linha que cabe
  inteira (antes a última podia invadir o COMPRAR). Hierarquia: arte >
  nome (maior, sangue) > legenda tipo · raridade > custo/stats > descrição
  > voz do grimório. O preço saiu da legenda (`opts.priceOnButton`): está
  na fita COMPRAR · $N e na plaquinha. Papel um degrau menos claro
  (`buildScroll` warm 0,93/0,86/0,74); legenda com contraste >= 4,5 no papel
  (`CardDetailPanel.onPaper`: "Comum"/"Relíquia" saíam cinza claro).
  Trava: `test_shop_scene` §9, ofertas + 12 cartas de descrição mais longa
  x 5 idiomas x 4 tamanhos = 400 painéis sem corte.
- **Estados**: sem ouro = plaquinha de latão OXIDADO (`BRASS_DENY`) com o
  valor em vermelho claro (só a cor do texto quase não se distinguia) e a
  arte escurece pouco (0,8, era 0,6); a fita COMPRAR relê o ouro no próprio
  quadro (`_drawBuyRibbon` chama `_refreshBuyButton`: antes ficava acesa
  sem ouro até a próxima compra); VENDIDO a giz NO apoio (era no meio da
  parede).
- **CRT** (`shaders/crt.glsl` `calmRect`/`calmRect2`,
  `CRTShader.setCalmRect/setCalmRect2`, zeradas em `endScene`): no
  pergaminho e no CONTINUAR a aberração cromática e o surto somem (borda
  suave 24 px); curvatura, scanlines e grille continuam. Quem pede passa px
  REAIS (`UiScale.activeK()`). Prova: `SHOP_STATES=crt,crtnocalm`.
- **Os dois "?"**: o 2º é o dos DADOS do Escriba; ganhou um dado de 16 px ao
  lado (sem rótulo parecia um "?" repetido).
- CONTINUAR: visível com respiro >= 8 px em todas as resoluções (trava no
  layout) e sem aberração (zona 2 do CRT).

Validado: `nav_flow` 30/30 (loja pelo teclado: setas, compra, saída).
Sem validação nesta frente: o jogo rodando na janela real (as capturas vêm
do tool com janela falsificada + canvas, CRT incluso) e gamepad físico.

## v5 rodada 2: bancada física, estados e os pedidos de voz (13/Out/2026)

Segundo briefing do dono + três recados de voz. Causas confirmadas no código
(eebf5870): a face do degrau tinha 12 linhas + 13 de vão quase preto
(`G`/`LINES`: 196→208→221); o cavalete era um trilho de 4 linhas sem tampo
nem encostos; todos os objetos tinham o pé na mesma reta (`relicDepth`
{0,-1,0} com passo 4); a sombra de contato só nascia em coluna com base a
≤3 px do pé (livro aberto e cristal viravam tracinhos); a fita COMPRAR
desbotava sem dizer por quê; o `caPx` do CRT valia inteiro em cima de preços
e nomes de carta.

- **Degrau**: face de 8 linhas com MADEIRA à vista (rampa do tampo um tom
  e meio mais escura), vão de 4 linhas de sombra; retas 188/198/206/210/306.
  Mesa 11 px mais funda. Travas: face ≤ 8, vão ≤ 4.
- **Cavalete = bloco** (`RAIL_ART` 6: tampo de 2 linhas + face de 3 + pé),
  ressalto cobrindo 3 px da moldura (`RAIL_COVER_ART`), dois ENCOSTOS de
  3x5 nas pontas (`railPad` 4), sombra da carta no tampo do bloco (linha
  atrás da carta um tom mais escura), sombra de contato do bloco só na base
  (2 linhas, 3 colunas). Só a SELEÇÃO acende a aresta em ouro (hover tem o
  anel na carta).
- **Mesa**: profundidades DESENHADAS por vaga (`TABLE.*depth`, passo 5):
  copo -1,2, sino +1, relíquias +0,6/-1,4/+0,8, pacote -0,6. Pé ≥ 6 px da
  aresta (trava).
- **Sombra de contato contínua** (`drawContactShadow`): segue o contorno de
  baixo coluna a coluna, tolerância 6 px com densidade caindo, buracos de 1
  coluna fechados.
- **Etiquetas** (recado de voz, gosto do dono): objetos e sino voltaram à
  ETIQUETA PENDURADA, agora com o cordão amarrado na BASE do objeto, correndo
  pela mesa até a aresta da frente (`CORD_DRIFT` 7 à direita) e caindo pela
  FACE da bancada (`TAG_DROP` 4); balança no hover e o mouse em cima dela
  empurra o pêndulo. Cartas: plaquinha pregada fica; o selo vermelho NOVA
  virou etiqueta pendurada ACIMA do topo, no canto de fora, dentro da
  largura da carta (`cardNewTag`). `test_shop_layout` trava a queda pela
  aresta e a posição da NOVA.
- **Carta da direita "pra dentro"**: `SHELF.depthStep` 1,2%/carta (4ª = 96,4%).
- **Estados**: fita COMPRAR apagada DIZ o motivo (`reward.buy_sold` /
  `reward.buy_no_gold · $N`, 5 locales); latão oxidado sem ouro; "?" dos
  dados com tooltip `status.scribe_dice_help`.
- **CRT**: `caScale` (shader) = 0,45 na loja inteira
  (`CRTShader.setChromaScale`, volta a 1 em `endScene`).
- **Vida**: mariposa de volta rondando um ponto de luz invisível no alto à
  esquerda (`L.lantern.invisible`); pergaminho ENROLA e desenrola ao trocar
  a oferta (`scrollOpen`, 0,28 s, rolo de baixo sobe, texto recortado);
  pacote/poção/cristal FLUTUAM no hover (`ShelfItem.floats`, +7 px e
  balanço); faíscas de compra na cor do tema + som POR OBJETO
  (`ShelfItem.HOVER_SFX/BUY_SFX`, 15 sons novos em `audio/sfx/shop-*.mp3`,
  registro por scan no main.lua); sininho no hover do sino, sino de verdade
  no reroll, chocalho no copo.
- **Artes v5** (`assets/sprites/shop/v5/`, PixelLab `tools/pixellab_shop_v5.py`):
  5 capas de pacote como PACOTES (envelope grosso, topo serrilhado, lombada,
  estilo do bufão v4), cristal de mana e prensa refeitos (pose sem
  cisalhamento). Animações em `v5_anim/<id>/`: poção borbulhando no hover
  (`ShopPerspective.animFrames`, 8 fps) e os 5 pacotes ABRINDO no
  PackOpenScreen até o estouro (capa v5 em escala inteira).

### v5 r2, acabamento (coordenador + dono, mesmo dia)

- **Rótulo de hover mora na etiqueta** ("nada flutua"): a etiqueta pendurada
  CRESCE no hover (`ShelfItem.grownTag`: alarga em torno do mesmo furo e
  desce `LABEL_ROWS` 8 linhas) e a 2ª linha traz o nome/efeito (+1 SLOT,
  NOVAS OFERTAS...); selecionado fica aberta. O copo, sem preço, ganha uma
  etiqueta "DADOS" só no hover. `drawHoverLabel` e a faixa de pergaminho
  solta saíram.
- **Etiqueta mais baixa**: `TAG_DROP` 11 (o dono não via a queda pela
  aresta com 4).
- **NOVA**: VERMELHA (estilo `sale`), pendurada de um PREGO na parede 6 px
  acima dela (`newTag.nail`), não mais do canto da carta.
- **Sombra sob item levantado** (`drawContactShadow`, `lifted`): fica no
  tampo, CHEIA e sem dither (3 linhas, alpha 0,75); apoiado continua as 2
  linhas de contato em dither.
- **Pacote abre DENTRO da loja**: `_G.openBoosterPack` (main.lua) não desliza
  a loja pra fora no modo shop (mostrava a estrada do bioma atrás do
  pacote); o PackOpenScreen escurece a loja a 0,6 e abre a capa v5 quadro a
  quadro (4x) até o estouro.

### Tutorial do corvo na loja v5 (dono: "ajuste também o tutorial do corvo")

Conversa `shop` do `Tutorial.SCRIPT` ganhou duas falas: `price` (recorte
`shop_prices` = plaquinhas das cartas + etiquetas penduradas dos objetos e do
sino) e `buy` (recorte `shop_scroll` = o pergaminho com a fita COMPRAR);
`offers` passou a descrever cavaletes/balcão e o recorte inclui o cavalete e
a etiqueta de cada peça; `shop_refresh` inclui a etiqueta do sino. Âncoras
em `CardRewardScreen:_drawShop`; textos nos 5 `locales/tutorial/*.lua`;
`test_tutorial` tem os recortes `shop_prices`/`shop_scroll` na mesa falsa.

### v5 r2d: sombra = pegada no plano da mesa; pacote abre em fundo próprio

- `drawContactShadow` (dono: "a sombra ainda está errada"): a sombra é a
  PEGADA da silhueta no plano da mesa (reta 1:8 pelo pé, `yT = fy + k*lx`),
  coluna a coluna na largura inteira; apoiado = 2 linhas (sólida onde a base
  encosta a <= 2 px, dither onde o objeto pende), levantado = 4 linhas
  sólidas + 1 coluna de borda em dither. Seguir o contorno de baixo fazia a
  da poção virar arco e a do item flutuando sumir. Sonda:
  `love . test_one probe_shop_shadow` (36 -> 53 pontos em repouso, 146 no ar).
- PackOpenScreen (dono: a loja escurecida atrás do pacote "fica muito
  poluída"): fundo PRÓPRIO opaco, sépia escuro com poça de luz em 4 degraus
  (dither Bayer nas bordas) centrada no pacote (`sleeveCenter`). A loja
  continua viva atrás (sem slideOut no modo shop) e volta intacta ao fechar.
- `screenshot_shop_diag`: estado `hoverpotion`.

### v5 r2e: nearest de verdade, NOVA do teto, ficha sem corte

- **Qualidade das relíquias "do canto"** (dono: "no hover melhora"): o jogo
  real NÃO liga `setDefaultFilter("nearest")` (só os tools chamam
  `PixelCanvas.enableNearest`), então o PNG estático do voucher era amostrado
  LINEAR sob o cisalhamento 1:8/1:16 (borrão); os quadros do hover
  (IconFramesLoader) já eram nearest. `ShopPerspective.spriteFor` passa toda
  imagem por `crisp()` (setFilter nearest); `ShopScene.art`/`ShelfItem.art`
  idem (pintura, poeira, sino). Capturas nunca mostraram o defeito porque o
  tool liga o nearest: ao caçar borrão, lembre disso.
- **NOVA pende do TETO** (dono): cordão vertical do alto da parede visível
  (`ceilingY`, logo abaixo da TopBar) até o furo; a placa de título passou a
  ser desenhada DEPOIS da cena (cordões passam atrás dela).
- **Ficha cortada**: o recorte da passada das cartas só subia 16 px acima da
  carta; agora inclui a caixa da NOVA e a coluna do cordão até o teto.
- `screenshot_shop_diag`: `SHOP_NEW=1` força a etiqueta NOVA nas 4 cartas.
