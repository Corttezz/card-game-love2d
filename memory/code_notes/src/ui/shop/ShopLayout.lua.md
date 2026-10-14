---
name: code_notes/src/ui/shop/ShopLayout.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/shop/ShopLayout.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/shop/ShopLayout.lua`

Origem: `src/ui/shop/ShopLayout.lua` em `7dbdb60d` (32 de 85 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-31 (junto a `local ShopLayout = {}`)

> src/ui/shop/ShopLayout.lua
> GEOMETRIA PURA do Balcão do Mercador (Loja v5; v4 em
> docs/plan/shop-v4-estudo.md; histórico v3b/v3c/reta/v4/v5 em
> memory/shop_layout.md).
>
> A cena é UMA PINTURA (assets/sprites/shop/counter_scene.png, montada por
> tools/shop_v4_compose.py): parede calma em cima e, na frente, DUAS
> superfícies limpas desenhadas na grade com as arestas em 1:8 (o DEGRAU das
> cartas e a MESA dos objetos). Desenhada em cover-fit e TUDO que mora nela é
> posicionado num ESPAÇO DA BANCADA comum (coordenadas da arte):
> u = ao longo do tampo (a coluna x da arte; as retas sobem 1 px a cada 8)
> d = profundidade (a reta y0 - x/8 de cada superfície: maior = mais perto)
> Cartas, cavaletes, plaquinhas, objetos e etiquetas saem desse espaço por
> parâmetros CENTRAIS (SHELF / TABLE / PLAQUE, abaixo), nunca por coordenada
> de tela solta:
> * cartas: um GRUPO de cavaletes com vão constante, centrado na zona da
> vitrine; base de cada carta encaixada no trilho, trilho apoiado no
> tampo do degrau; preço numa plaquinha pregada na FACE do degrau, logo
> abaixo da própria carta (vínculo físico: é o mesmo móvel);
> * mesa: três grupos com intenção (ferramentas do mercador | serviços |
> consumível), profundidades levemente diferentes; preço numa plaquinha
> em pé no tampo, logo À FRENTE do pé do objeto.
> `validate` confere apoio (pé dentro da superfície pintada), vínculo
> (plaquinha colada no dono), nada sobreposto, nada perto demais da borda
> da frente e a coluna da direita (pergaminho, CONTINUAR) livre. Janela
> estreita (4:3): a fileira desliza e, se não cabe, o VÃO cede e só depois a
> escala, nunca a ordem.
>
> Fora da pintura (interface, grade da UI, prioriza leitura): a placa de
> título com os "?", o PERGAMINHO de detalhe à direita (com o COMPRAR) e o
> botão CONTINUAR no canto inferior direito.

## L45-49 (em `rect`, junto a `ShopLayout.CARD_HOVER_SCALE = 1.0`)

> Loja v5 (briefing do dono: "evite que a carta simplesmente suba e pareça
> levitar sobre o suporte"): o hover NÃO levanta nem cresce a carta. O ponto
> de apoio (centro da base, no trilho) fica parado; o que responde ao mouse
> é o tilt 3D (Card.hoverTilt) com a base PRESA (card_perspective.glsl em
> modo quad) e o destaque (contorno + trilho aceso).

## L52-57 (em `rect`, junto a `ShopLayout.RAIL_ART = 6`)

> Trilho do cavalete em px de ARTE e quanto dele cobre a carta: só a borda
> inferior da moldura (o rodapé com tipo e valor é informação, fica à vista).
> v5 r2 (dono: "os suportes parecem lâminas finas"): o cavalete é um
> bloco de madeira de 6 linhas (tampo de 2 + face de 3 + pé) com um
> RESSALTO na frente que segura a carta (cobre 3 px da moldura) e dois
> encostos de 5 px nas pontas.

## L64-68 (em `rect`, junto a `ShopLayout.SHELF = {`)

> ============================================================================
> PARÂMETROS DA VITRINE (Loja v5, item 11 do briefing): tudo que posiciona
> carta, objeto e preço mora AQUI, em px de arte. Mudou a quantidade de
> ofertas ou a janela? A conta abaixo refaz o grupo a partir destes números.
> ============================================================================

## L73-76 (em `ShopLayout.SHELF`, junto a `depthStep = 0.012,`)

> v5 r2 (dono: "a da direita tem que ficar um pouquinho mais pra dentro,
> pela impressão de que está pra trás"): cada carta à direita é 1,2%
> menor que a anterior (3,6% na 4ª: um sopro de profundidade, não
> uma escada de tamanhos)

## L83-90 (em `ShopLayout.TABLE`, junto a `dice = { gap = 0, depth = -1.2, size = 32, diceAt = { { -11, 12 }, { 7, 14 } } },`)

> v5 r2 (dono: "cada produto aparece um pouco mais alto que o anterior"):
> profundidades DESENHADAS, fixas por vaga, que quebram a escada da 1:8:
> copo atrás, sino à frente, relíquias em zigue-zague, pacote recuado.
> Da esquerda pra direita, três grupos: ferramentas do mercador (copo
> de dados, sino), serviços (relíquias) e o consumível (pacote). `gap` =
> distância do pé anterior; o vão ENTRE grupos é maior que o de dentro.
> dados do copo À FRENTE dele ({dx, dy} do pé do dado, relativo ao pé
> do copo): jogados ou o dado de enfeite, longe do sino

## L101-105 (em `relicDepth`, junto a `ShopLayout.TAG_W, ShopLayout.TAG_H = 16, 9`)

> ETIQUETA PENDURADA (v5 r2, gosto do dono): preço dos objetos da mesa e
> do sino, e o selo NOVA das cartas. O cordão sai do objeto, corre pela
> mesa até a aresta da frente (drift pra direita) e CAI pela face da
> bancada; o cartão fica pendurado na face, TAG_DROP linhas abaixo da
> aresta, e balança no hover (px inteiros, sem rotação).

## L107 (em `relicDepth`, junto a `ShopLayout.TAG_DROP = 11`)

> (dono: "muito pertinho da borda")

## L119-133 (em `ShopLayout.PLAQUE`, junto a `ShopLayout.SHADOW = {`)

> SOMBRA PROJETADA dos objetos da mesa (v5 r4, 13/Out/2026, dono: "elas têm
> que pelo menos acompanhar o formato de cada coisa"). A sombra é a SILHUETA
> do sprite deitada no plano da mesa. A luz da cena é a lanterna no ALTO à
> ESQUERDA, atrás do balcão (ambientAt clareia o canto de cima-esquerda; o
> pergaminho sombreia a parede pra direita-baixo): a sombra cai pra DIREITA
> e pra FRENTE (desce na tela, em direção ao jogador). Cada pixel do objeto
> a `h` px de altura cai em (lean*h, (depth - lean/RUN)*h) px de arte a
> partir do ponto da base: o `lean/RUN` é a subida da diagonal 1:8 da
> bancada ao andar pra direita. Um objeto de 60 px projeta ~45 px à direita
> e ~19 px à frente: lê-se a silhueta inteira na mesa, à frente do vizinho
> (que fica mais ao fundo), nunca escondida atrás dele.
> solid = fração da altura com sombra cheia (junto do contato);
> top   = densidade (dither Bayer) na ponta;
> alpha = tinta sobre a madeira; liftFade = quanto clareia a liftRef px
> de altura (objeto flutuando no hover).

## L145-151 (em `ShopLayout.shadowDir`, junto a `ShopLayout.RUN = 8`)

> ============================================================================
> Loja v4: UMA inclinação de pixel art, 1:8 (sobe 1 px de arte a cada 8 px
> pra direita, ~7,1 graus), igual nas duas superfícies e em tudo que mora
> nelas. Inclinação inteira = degraus todos de 8 px. Projeção oblíqua: as
> retas são paralelas e a escala não muda ao longo delas (a 4ª carta tem o
> mesmo tamanho da 1ª: nada encolhe "porque está à direita").
> ============================================================================

## L156-157 (em `ShopLayout.slopeArt`, junto a `function ShopLayout.lineY(y0, x) return y0 - math.floor(x / ShopLayout.RUN) end`)

> y (arte) da reta "y0 - x/8" na coluna x, em DEGRAUS (como a pintura é
> desenhada por tools/shop_v4_compose.py). A contínua difere < 1 px.

## L160-163 (em `ShopLayout.lineY`, junto a `local LINES = {`)

> ============================================================================
> A ARTE: 640x360 (tools/shop_v4_compose.py). Retas "y = y0 - x/8" (y0 =
> altura na coluna 0), espelhadas em G do tools/pixellab_shop_v4.py:
> ============================================================================

## L178-180 (em `ShopLayout.ART`, junto a `w = 640, h = 360,`)

> MIOLO 640x360 (as coordenadas de tudo); o PNG tem `pad` px de pintura
> a mais de cada lado (v5): o cover-fit escolhe escala INTEIRA sempre
> que a pintura inteira cobre a janela (1366x768, 1024x768, 1280x800).

## L192-199 (em `ledgeEdge`, junto a `local function coverTransform(sw, sh, aw, ah, pad)`)

> cover-fit em MÚLTIPLO INTEIRO (v5, item 10 do briefing: pixel da cena
> sempre do mesmo tamanho). Ordem:
> 1. o MAIOR inteiro em que a pintura com margem (miolo + pad) ainda
> cobre a janela: 1366x768 / 1024x768 / 1280x800 virtuais -> 2;
> 2. o inteiro logo acima se o recorte extra é pequeno (<= 20%);
> 3. fracionário (janela de proporção estranha), em vez de cortar meia
> mesa.
> O miolo fica centrado; ox/oy = canto do MIOLO na tela.

## L255-259 (em `bboxOf`, junto a `ShopLayout.AMBIENT = { strength = 0.6, lift = 0.15, warm = { 1.0, 0.96, 0.90 } }`)

> LUZ DA CENA (v5): a mesma queda da pintura (tools/shop_v4_compose.py,
> light(): vela à esquerda, o lado direito cai). Os sprites dos objetos têm
> luz própria; multiplicados por este tom (suavizado, levemente quente)
> eles assentam na mesma luz da mesa e o pacote da ponta direita deixa de
> brilhar mais que a vitrine.

## L268-269 (em `ShopLayout.ambientAt`, junto a `function ShopLayout.stepBox(cv, x0, w, y0, h)`)

> Caixa (px de TELA) de um retângulo em degraus: colunas x0..x0+w-1, topo
> na reta de intercepto y0, h linhas.

## L278-287 (em `ShopLayout.stepBox`, junto a `local function plaque(cv, kind, cx, y0, maxW)`)

> ============================================================================
> PLAQUINHA DE PREÇO (Loja v5). UM tratamento para todo preço da vitrine:
> latão envelhecido com o valor em tinta clara, desenhado na GRADE da arte
> (degraus 1:8 na mesma fase das arestas), texto por cima na grade da UI.
> O vínculo físico é o lugar:
> card   = pregada na FACE do degrau, centrada sob a própria carta
> object = em pé no TAMPO, centrada logo à frente do pé do objeto
> A largura final sai do texto (ShelfItem.plaqueArt); aqui fica a caixa
> MÁXIMA (validação e hit-test) e o eixo (cx).
> ============================================================================

## L299-300 (em `pq`, junto a `local function artTag(cv, cordX, cordY, x0, y0, W)`)

> Etiqueta pendurada: cordão até o furo no meio do topo do cartão (x0,
> topo na reta y0). `box` = cartão + balanço + cordão em px de tela.

## L314-316 (em `T.hole`, junto a `local function objectTag(cv, ax)`)

> Etiqueta de um objeto da mesa: o cordão vai do objeto até a ARESTA DA
> FRENTE (ponto `edge`, CORD_DRIFT à direita do pé) e cai pela face; o
> cartão pende TAG_DROP linhas abaixo da aresta.

## L327-331 (em `T.edge`, junto a `local function cardNewTag(cv, c, side, ceilingY)`)

> Etiqueta NOVA da carta: pendurada ACIMA do topo, puxada pro canto de
> fora da fileira (cartas da esquerda: canto direito; da direita: canto
> esquerdo), SEMPRE dentro da largura da própria carta (a vizinha da
> direita é 7 px mais alta pela 1:8: fora da largura ela cobria o canto da
> vizinha). Cordão curto do canto até o furo.

## L342-344 (em `cardNewTag`, junto a `local T = artTag(cv, hx, math.min(hy - 6, ceilingY or (hy - 6)), x0, y0, W)`)

> (dono: "o NOVA em cima da carta precisa vir do teto"): o cordão desce
> do TETO da cena (alto da pintura visível, `ceilingY` em px de arte)
> até o furo; vermelha, pra não se confundir com as de preço

## L357-362 (em `ShopLayout.frameAtF`, junto a `function ShopLayout.cardQuad(c, hover, lift)`)

> Os 4 cantos da carta (TL, TR, BR, BL), px de tela, no frame da borda:
> base sobre a borda (vb acima dela, dentro do trilho), topo PARALELO à
> base (a mesma reta 1:8: projeção oblíqua, sem ponto de fuga). `hover` e
> `lift` ficam na assinatura por compatibilidade: com CARD_HOVER_SCALE = 1 e
> CARD_LIFT = 0 (v5) a pose do hover é a do repouso; o movimento do hover é
> o tilt do shader, com a base presa.

## L382-383 (em `T`, junto a `function ShopLayout.tableRow(nRelics, withPack)`)

> A fileira da mesa como LISTA (arte, relativa ao 1º pé): grupos e
> profundidades saem de ShopLayout.TABLE. nRelics pode ser 0..n.

## L423-424 (em `ShopLayout.layout`, junto a `local zoneL = math.max(0, (6 - cv.ox) / cv.s) + SH.zonePad`)

> ===== a ZONA da vitrine em px de arte: da borda visível esquerda até o
> pergaminho (4:3 corta a esquerda da pintura: a zona começa depois) =====

## L448-449 (em `cards`, junto a `local x0 = math.floor(zoneL + math.max(0, (zoneR - zoneL - groupW) / 2) + 0.5)`)

> o GRUPO centrado na zona (um conjunto organizado pelo mesmo
> comerciante: vão constante, sem escada de vãos largos)

## L460-462 (em `c`, junto a `c.vb = (ShopLayout.RAIL_ART - ShopLayout.RAIL_COVER_ART) * cv.s`)

> ÂNCORA = centro da base. O trilho (RAIL_ART px de arte) tem a
> quina de baixo da frente SOBRE a aresta; a carta senta nele e
> ele cobre só RAIL_COVER_ART px da moldura: sem fresta.

## L487 (em `c.anchor`, junto a `local ceilingY = math.floor((topBarH - cv.oy) / cv.s)`)

> teto = alto da parede visível (logo abaixo da TopBar), em px de arte

## L508-509 (em `cardsLeft`, junto a `local signBox = { x = margin, y = topBarH + 4, w = math.floor(sw * 0.42), h = 30 }`)

> VERTICAL: a 1:8 sobe a carta da direita; com o selo NOVA ela não pode
> passar da TopBar nem da placa de título. Quem cede é a altura.

## L600-602 (em `art`, junto a `local lx, ly = toScreen(cv, 60, 70)`)

> v5 r2: a mariposa voltou (dono). Sem lanterna pintada, ela ronda um
> ponto de luz INVISÍVEL no alto à esquerda da vitrine (de onde vem a
> luz da cena); ShopProps só precisa do retângulo.

## L619-621 (em `art`, junto a `local function inside(outer, inner, tol)`)

> ============================================================================
> VALIDAÇÃO
> ============================================================================

## L698-699 (em `tableItems`, junto a `if tg.edge.y ~= lineY(LINES.tableEdge, tg.edge.x) - 1 then fail("cordao do %s nao cai pela aresta", name) end`)

> a etiqueta pende da ARESTA: o ponto de queda está na última
> linha do tampo e o cartão fica abaixo dela, na face

## L720-723 (em `tableItems`, junto a `for _, e in ipairs(all) do`)

> mesa x cartas: um objeto da mesa não pode cobrir carta nem cavalete.
> O cavalete termina na reta 1:8 de baixo da plaquinha: compara o topo do
> objeto com essa reta na coluna MAIS BAIXA do trecho em comum (a caixa
> alinhada aos eixos acusaria sobreposição que não existe na diagonal).

