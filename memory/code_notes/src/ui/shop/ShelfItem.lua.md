---
name: code_notes/src/ui/shop/ShelfItem.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/shop/ShelfItem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/shop/ShelfItem.lua`

Origem: `src/ui/shop/ShelfItem.lua` em `7dbdb60d` (48 de 96 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local ShelfItem = {}`)

> src/ui/shop/ShelfItem.lua
> Um OBJETO do Balcão do Mercador em perspectiva (Loja v3c): a oferta do
> ShopSystem + a âncora do PÉ que o ShopLayout lhe deu (coordenadas da arte
> convertidas pra tela) + a etiqueta de preço + o estado de interação.
>
> Três espécies, uma classe:
> card   → a carta num CAVALETE da borda do fundo, PARALELA à borda: os
> 4 cantos saem de ShopLayout.cardQuad e o card_perspective.glsl
> mapeia a carta inteira por homografia (perspectiva de verdade,
> não o "press" de 6-8 graus). Hover: o lado direito afunda, o
> esquerdo sobe e ela levanta um pouco.
> relic  → a arte ANTIGA do voucher (assets/sprites/vouchers/<id>.png; a
> animação de vouchers_anim/ entra no hover) EM PÉ sobre a mesa
> pack   → a arte ANTIGA do pacote (assets/sprites/packs/<id>.png) em pé
>
> Regras (queixa do dono 13/Out/2026, docs/plan/shop-v3-balcao.md §13):
> * TUDO na diagonal da mesa: objeto (cisalhamento pelo slope até o ponto
> de fuga, ShopPerspective), sombra, etiqueta, faixa, carta, cavalete.
> * NADA flutua: o pé real da arte (perfil da silhueta) cai no tampo e a
> sombra é de CONTATO (dither, colada na base), nunca elipse.
> * Hover = o MESMO sprite (mesma pose, mesmo espelho, mesmo cisalhamento)
> levantado 4-6 px com contorno claro de 1 px de arte. Nunca troca de
> imagem (pose() é igual em repouso e hover; test_shop_scene trava).
> * Preço = etiqueta pendurada (a das cartas). Nome/efeito = faixa de
> pergaminho na diagonal SÓ no hover; sempre no pergaminho da direita.
> reducedMotion remove o MOVIMENTO; preço, VENDIDO e foco continuam.

## L50-52 (em `reducedMotion`, junto a `ShelfItem.HOVER_TIME = 0.18`)

> Hover (Loja "reta"): tempo LINEAR + easing simétrico. A volta percorre o
> mesmo caminho da ida, quadro a quadro, sem salto no começo nem no fim (a
> aproximação exponencial antiga saía com o passo maior no primeiro quadro).

## L68-69 (em `deep`, junto a `ShelfItem.OBJECT_SCALE = 1`)

> v4: o objeto entra na grade da cena em ESCALA INTEIRA (1 = pixel do
> sprite = pixel da pintura). Só arte bem maior que o slot cai pra 1/n.

## L194-204 (em `ShelfItem:center`, junto a `ShelfItem.TILT_EASE = 12          -- 1/s (≈ 90% em 0,19 s)`)

> HOVER DA CARTA (Loja v4, pedido do dono: "quando mexer nas pontas, a
> carta ir mexendo junto"). A pose diagonal é a BASE; por cima dela entra o
> tilt 3D da mão e das recompensas (Card.hoverTilt, a mesma conta): o mouse
> vai pro espaço da carta pela inversa da homografia de REPOUSO (o alvo não
> foge do cursor) e o card_perspective.glsl aplica o "press" antes da
> homografia, então a diagonal fica e o canto sob o cursor afunda. Tilt com
> amortecimento exponencial (entra e sai suave); reducedMotion zera.
> v5 (briefing: "mantenha o ponto de apoio estável"): SEM parallax (a carta
> inteira andando junto com o mouse tirava a base do trilho) e, no shader,
> a base fica PRESA no modo quad: o tilt gira a carta em torno do apoio.

## L216-218 (em `ShelfItem:cardMouseUV`, junto a `function ShelfItem.warpUV(u, v, mx, my, hover, t, quad)`)

> Espelho em Lua do vertex shader (shaders/card_perspective.glsl): ponto
> (u, v) do canvas da carta -> (u, v) deformado pelo press/wobble. Com
> `quad` (carta no cavalete) a base fica presa. MANTENHA EM SINCRONIA.

## L248-250 (em `ShelfItem:updateTilt`, junto a `ShelfItem.FLOAT_IDS = { health_upgrade = true, mana_upgrade = true }`)

> Objetos que FLUTUAM no hover (dono: "o pacote tem que levantar e ficar
> meio flutuando; talvez a poção e o cristal também"): sobem FLOAT_LIFT px
> e balançam devagar. Cartas e os outros objetos ficam apoiados.

## L258-259 (em `ShelfItem:floats`, junto a `ShelfItem.HOVER_SFX = {`)

> Som do hover por objeto (registro por scan em main.lua; sem o arquivo
> cai no genérico da espécie)

## L301-302 (em `ShelfItem:update`, junto a `if hovered and mx and not reduced then`)

> "brincar com a etiqueta": com o mouse sobre ela, o movimento lateral
> empurra o pêndulo

## L325-328 (em `ShelfItem:update`, junto a `function ShelfItem:liftPx()`)

> Quanto o objeto está levantado (px de tela). v5: o hover NÃO levanta
> (geom.lift = 0: nada levita sobre o apoio); exceção pedida pelo dono: o
> pacote, a poção e o cristal FLUTUAM no hover (sobem e balançam devagar).
> O pulinho curto da chegada na mesa (juice da entrada/sino) vale pra todos.

## L348-351 (em `ShelfItem:markSold`, junto a `function ShelfItem:pose()`)

> POSE: o que define a aparência do objeto. Igual em repouso e em hover
> (a trava de test_shop_scene compara as duas).

## L401-404 (em `ShelfItem:flyPayload`, junto a `local function withShear(x, y, slope, fn)`)

> TEXTO NA DIAGONAL: tudo que é escrito sobre a mesa é cisalhado pelo mesmo
> slope (as verticais da letra continuam verticais, como na pintura).

## L414-415 (em `withShear`, junto a `function ShelfItem.drawBand(b, text, color, opts)`)

> Faixa (tinta ou pergaminho) cisalhada, com texto centralizado.
> b = { x, y (topo à esquerda), w, h, slope }

## L460-466 (em `ShelfItem.drawBand`, junto a `local function px(c, a, x, y, w, h)`)

> PIXEL ART NA GRADE DA CENA (v4): etiqueta, cordão, plaquinha e cavalete são
> desenhados no canvas da ARTE (dentro de ShopPerspective.artPass) como
> retângulos em DEGRAUS: a coluna x tem o topo em ShopLayout.lineY(y0, x),
> a mesma fase das arestas pintadas (degraus de 8 px, todos iguais). O texto
> sai depois, na grade da UI, cisalhado pela mesma inclinação.

## L474-490 (em `px`, junto a `ShelfItem.BRASS = {`)

> PLAQUINHA DE PREÇO (Loja v5). Queixa do briefing: "as pequenas etiquetas
> brancas deslocadas para baixo e para a direita parecem flutuar". Um
> tratamento só para todo preço da vitrine: latão envelhecido (4 tons) com o
> valor GRAVADO em tinta escura (lê sobre a madeira escura do móvel sem
> branco puro), na GRADE da arte (degraus 1:8, mesma fase das arestas
> pintadas). O VÍNCULO é o lugar (ShopLayout.plaque):
> carta  = pregada na FACE do degrau, sob a própria carta (dois pregos);
> objeto = em pé no TAMPO, logo à frente do pé (topo de 1 px visto de
> cima + sombra de contato no tampo).
> Raridade da carta = uma GEMA na cor dela, à esquerda do preço (comum sem
> gema). O nome da raridade está no pergaminho e no selo da própria carta:
> três placas repetindo a mesma coisa era o ruído que o briefing pede pra
> tirar. Selecionado: o contorno do latão vira OURO (a mesma cor do
> contorno do objeto selecionado). Sem ouro: valor em vermelho legível e a
> plaquinha treme. Oferta do dia: canto vermelho dobrado.

## L497-499 (em `ShelfItem.BRASS`, junto a `ShelfItem.BRASS_DENY = {`)

> SEM OURO: o latão escurece (oxidado) e o valor sai em vermelho CLARO. A
> troca de tom da placa inteira lê de longe; só a cor do texto (vermelho
> escuro sobre latão) ficava quase igual à tinta normal.

## L520-521 (em `ShelfItem.contrast`, junto a `local inkCache = {}`)

> Cor `c` levada até contraste >= 4,6 com a face (escurece no latão claro,
> clareia no latão oxidado do "sem ouro").

## L534-535 (em `ShelfItem.inkOnBrass`, junto a `function ShelfItem.priceInk(afford, sale)`)

> Tinta do valor: normal (tinta), sem ouro (vermelho escuro legível),
> oferta do dia (tinta; o canto vermelho dobrado é que marca).

## L547-548 (em `ShelfItem.showsGem`, junto a `function ShelfItem.plaqueArt(pq, text, rar, cv)`)

> Geometria FINAL (px de arte) + fonte/texto: largura pelo texto, centrada
> no eixo do dono. Pura: o teste mede.

## L568-569 (em `ShelfItem.plaqueBox`, junto a `function ShelfItem.drawPlaqueArt(Q, dx, st)`)

> Latão na grade (dentro do artPass). dx = deslize em px de arte.
> st = { selected, sale, alpha, rar }

## L713-715 (em `ShelfItem.tagStyle`, junto a `function ShelfItem.drawTagArt(tg, dx, dy, afford, sale, a, tie)`)

> Etiqueta (cartão + furo + cordão), px de ARTE. tg = ShopLayout.artTag;
> dx = balanço/deslize (px de arte, inteiro), dy = levantar (px de arte);
> tie = {x, y} de onde o cordão sai (nil = tg.cordX/cordY).

## L722-723 (em `ShelfItem.drawTagArt`, junto a `ShelfItem.drawCordArt(tie[1], tie[2], tg.edge.x, tg.edge.y, a)`)

> v5 r2: o cordão sai do objeto, corre pela MESA até a aresta da
> frente e CAI pela face até o furo (duas direções)

## L727-728 (em `ShelfItem.drawTagArt`, junto a `ShelfItem.drawCordArt(tg.cordX + dx, tg.cordY, holeX, holeY, a)`)

> cordão vertical descendo do TETO da cena até o furo (balança
> junto com o cartão: o pé do cordão acompanha dx)

## L781-784 (em `ShelfItem.drawTagText`, junto a `ShelfItem.LABEL_ROWS = 8`)

> Etiqueta CRESCIDA pro hover (coordenador, Out/2026: "nada flutua", o
> rótulo "+1 SLOT" aparecia solto no ar): a mesma etiqueta pendurada
> ganha uma 2ª linha com o nome/efeito, alargando em torno do MESMO furo e
> descendo pela face da bancada. `k` 0..1 = quanto cresceu.

## L809-810 (em `ShelfItem.swingArt`, junto a `function ShelfItem.newTagFor(tg, cv)`)

> Etiqueta NOVA com a largura do TEXTO do idioma (fr "NOUVELLE" não cabia
> nos 22 px fixos e saía cortada): alarga em torno do mesmo furo.

## L828-830 (em `ShelfItem:isNew`, junto a `function ShelfItem:drawPlateArt(L, ctx)`)

> Placas no canvas da ARTE (dentro do artPass): carta = plaquinha pregada
> (+ etiqueta NOVA pendurada acima do canto); objeto = etiqueta pendurada
> pela aresta da frente (cordão do objeto até a aresta, depois pela face).

## L855-856 (em `ShelfItem:drawPlateArt`, junto a `function ShelfItem:labelK()`)

> quanto a etiqueta cresceu pro rótulo (0..1): segue o hover; selecionado
> fica aberta (o pergaminho já explica, mas a etiqueta diz o que é)

## L889-890 (em `ShelfItem:drawPlateText`, junto a `function ShelfItem.drawHoverName(text, cx, topY, slope, a, maxX, minX)`)

> Rótulo de HOVER: faixa de pergaminho miúda, na diagonal, ancorada acima do
> objeto. Nome/efeito; nada de texto parado em caixa embaixo dos objetos.

## L913-914 (em `ShelfItem:drawHoverLabel`, junto a `if true then return end`)

> v5 r2: o rótulo mora na 2ª linha da etiqueta pendurada (grownTag);
> faixa solta no ar não existe mais (coordenador: "nada flutua")

## L929-938 (em `ShelfItem:drawHoverLabel`, junto a `function ShelfItem:drawStandArt(L, part, alpha)`)

> CAVALETE da carta (v4, queixa do dono: "o suporte tem poucos pixels e faz
> escadinha"). Pixel art própria na GRADE da cena, inclinação 1:8 na mesma
> fase da aresta pintada do degrau (ShopLayout.lineY): degraus de 8 px todos
> iguais. Trilho de madeira de RAIL_ART linhas (aresta clara de 1 px, dois
> tons de face, pé escuro), contorno de tinta, dois batentes curtos nas
> pontas segurando a carta, sombra de contato (dither) à direita no tampo do
> degrau (a luz vem da esquerda). part "back" não desenha nada (a perna de
> trás da v3 era uma diagonal livre: escadinha).

## L948-950 (em `ShelfItem:drawStandArt`, junto a `for i = 1, 3 do`)

> SOMBRA DE CONTATO do bloco no tampo do degrau (v5 r2): nasce na base
> do bloco, só nas 2 linhas de cima da aresta e 3 colunas à direita
> (luz da esquerda), densidade caindo; nada de risco solto acima.

## L960-962 (em `ShelfItem:drawStandArt`, junto a `local edgeC = self.selected and Palette.AGED_GOLD_LIGHT or WOOD.hi`)

> destaque NA BASE do expositor: SÓ a seleção acende a aresta do bloco
> em ouro (o hover tem o anel de pergaminho na carta; dois destaques
> iguais deixavam ambíguo o que o pergaminho mostra). Nada se mexe.

## L972-974 (em `ShelfItem:drawStandArt`, junto a `px(edgeC, a, x, top, 1, 1)`)

> TAMPO do bloco (2 linhas: aresta clara + madeira), depois a
> FACE da frente (dois tons) e o pé de tinta: um bloco, não uma
> lâmina

## L982-983 (em `ShelfItem:drawStandArt`, junto a `for x = x0 + 4, x1 - 4 do`)

> sombra da CARTA sobre o tampo do bloco: a linha do tampo atrás da
> carta (entre os encostos) fica um tom mais escura = encaixe visível

## L988-989 (em `ShelfItem:drawStandArt`, junto a `for _, bx in ipairs({ x0 + 1, x1 - 3 }) do`)

> ENCOSTOS nas pontas (3 colunas, P linhas): pequenos blocos com tampo
> claro e face, em pé sobre o cavalete, segurando a carta pelos lados

## L1002-1005 (em `ShelfItem:drawStandArt`, junto a `ShelfItem.CARD_SHADOW = { w = 3, top = 4, density = { 0.75, 0.5, 0.28 }, alpha = 0.85 }`)

> Sombra da carta na PAREDE atrás (v5, briefing item 6: sombra de pixel
> art, direção de luz única). A luz vem da esquerda: a carta projeta uma
> faixa de 3 px de arte à DIREITA dela, nascendo no apoio (base) e
> abrindo pra cima, em dither Bayer (densidade cai pra longe da carta).

## L1040 (em `ShelfItem:drawCard`, junto a `do`)

> carta no cavalete e VIVA sempre (dono, 13/Out/2026); regra em CardFrame.displayImage

## L1047-1048 (em `ShelfItem:drawCard`, junto a `local CardMesh = require("src.ui.CardMesh")`)

> (a sombra da carta na parede é pixel art na grade: drawCardShadowArt,
> numa passada da arte ANTES das cartas)

## L1051-1053 (em `ShelfItem:drawCard`, junto a `local glowK = self.selected and 0.85 or (self.hover * 0.55)`)

> contorno: SELECIONADO = ouro firme; só HOVER = pergaminho mais fraco
> (as duas coisas ao mesmo tempo: vale a seleção). Mesma regra dos
> objetos da mesa (drawObjectArt).

## L1061-1062 (em `ShelfItem:drawCard`, junto a `local T = self.tilt or { x = 0, y = 0 }`)

> tilt do hover POR CIMA da pose (o press do shader roda no espaço da
> carta, antes da homografia do quadrilátero)

## L1075-1076 (em `ShelfItem:drawCard`, junto a `if self.selected and ri == 2 then`)

> selecionado: ouro POR FORA e um filete de tinta colado na
> carta (separa o anel da moldura dourada da própria carta)

## L1117-1123 (em `self._drawRect`, junto a `function ShelfItem:drawShadowArt(L, ctx)`)

> OBJETO da mesa (no canvas da ARTE): sombra (passada própria, ANTES de
> todos os objetos: a sombra de um cai atrás do vizinho) + sprite em pé.
>
> Sombra projetada (silhueta no plano da mesa) + linha de contato. Usa o
> MESMO sprite/quadro/pose do objeto (poção borbulhando projeta o quadro
> atual; objeto flutuando no hover projeta mais longe e mais claro).

## L1133-1134 (em `ShelfItem:drawShadowArt`, junto a `function ShelfItem:shadowScreenRect(L)`)

> Caixa (px de TELA) que a sombra projetada ocupa: entra no recorte da
> passada da mesa (sem ela a sombra era cortada à direita do objeto).

## L1152-1153 (em `ShelfItem:drawObjectArt`, junto a `local dim = ctx.afford and 1 or 0.8   -- v5: sem ouro escurece pouco (a arte segue legível); o preço vermelho `)

> luz da cena (ShopLayout.ambientAt): o objeto recebe a MESMA queda de
> luz da mesa pintada (vela à esquerda), em vez da luz própria do sprite

## L1158 (em `o.color`, junto a `o.outline = math.max(self.hover * 0.8, self.selected and 1 or 0, sale and 0.7 or 0)`)

> selecionado = ouro firme; hover = pergaminho (a mesma regra da carta)

## L1165-1167 (em `o.color`, junto a `local tx, ty = ShopPerspective.tiePoint(o, 0.06)`)

> onde o cordão da etiqueta se amarra (borda direita da silhueta, 1/3
> da altura); guardado em px de arte SEM o lift (a etiqueta corrige)
> amarrado perto da BASE: o cordão corre curto pela mesa até a aresta

## L1172-1173 (em `self._tieArt`, junto a `function ShelfItem:drawDustArt(L)`)

> Marca de poeira no lugar do objeto (arte, na diagonal) — o "VENDIDO" a giz
> vem depois, na grade da UI (drawSoldText).

## L1200-1201 (em `ShelfItem:drawSoldText`, junto a `local baseY = (self.kind == "card") and (g.foot - 12) or (g.foot - 10)`)

> v5: o VENDIDO fica NO apoio (logo acima do trilho / do pé), não
> solto no meio da parede

## L1217-1218 (em `ShelfItem:drawSoldText`, junto a `function ShelfItem.drawPortrait(kind, offer, x, y, w, h, alpha)`)

> Arte do objeto no PERGAMINHO: o MESMO sprite (mesma animação, mesmo
> espelho), frontal (sem o cisalhamento da mesa), escala inteira.

