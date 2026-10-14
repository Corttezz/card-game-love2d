---
name: code_notes/src/ui/shop/ShopPerspective.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/shop/ShopPerspective.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/shop/ShopPerspective.lua`

Origem: `src/ui/shop/ShopPerspective.lua` em `7dbdb60d` (27 de 39 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-22 (junto a `local ShopPerspective = {}`)

> src/ui/shop/ShopPerspective.lua
> A INCLINAÇÃO ÚNICA DA MESA do Balcão do Mercador (Loja v4).
>
> v4 (13/Out/2026, docs/plan/shop-v4-estudo.md): o ponto de fuga da v3c deu
> uma borda a 6,83 graus, que na grade da arte vira escadinha irregular
> (degraus de 8 e 9 px misturados). Agora tudo segue UMA inclinação de pixel
> art, 1:8 (sobe 1 px de arte a cada 8 px pra direita): as arestas das duas
> superfícies (pintadas na grade por tools/shop_v4_compose.py), a carta, o
> cavalete, a plaquinha, a etiqueta, as sombras e os objetos. As verticais
> continuam verticais (projeção oblíqua).
>
> Os objetos são desenhados num canvas na resolução da ARTE (640x360) em
> ESCALA 1 (pixel do sprite = pixel da cena) e sobem pro tamanho da tela com
> nearest, junto da pintura. Arte antiga frontal recebe cisalhamento inteiro
> (1:8 ou 1:16: degraus regulares); a arte nova (elixir, pacotes) já vem
> desenhada na diagonal e não é cisalhada.
>
> SOMBRA (v5 r4): a SILHUETA do sprite projetada no plano da mesa
> (drawCastShadow: shader que lê o alfa do próprio sprite pela inversa da
> projeção, dither Bayer por altura, cortada pela faixa do tampo) + uma
> LINHA DE CONTATO de 1 px sob o contorno de baixo onde o objeto encosta
> (drawContactShadow). Nada de elipse, nada de faixa na reta do pé.

## L36-37 (em `ShopPerspective.slopeArt`, junto a `function ShopPerspective.slopeAt(cv, sx, sy)`)

> slope em coordenadas de TELA (o cover-fit é escala uniforme: o slope é o
> mesmo; só converte o ponto)

## L42-59 (em `ShopPerspective.slopeAt`, junto a `function ShopPerspective.edgeY(ax)`)

> ============================================================================
> FRAME DA BORDA (Loja "reta", 13/Out/2026). Queixa do dono: "as cartas não
> estão seguindo a mesma reta". Antes a carta usava uma homografia própria
> (base girada mais que a borda), o trilho seguia a base, e a faixa de
> raridade/etiqueta outra conta: três ângulos na mesma carta.
>
> Agora TUDO da carta (carta, trilho do cavalete, plaquinha de raridade,
> etiqueta de preço, sombra) mora num frame só:
> origem  = o ponto da BORDA PINTADA (ShopLayout.ART.ledgeEdge, medida na
> pintura) sob o centro da carta, em px de tela;
> k       = inclinação da borda (a MESMA reta para as 4 cartas: as bases
> são colineares com a borda pintada, não só paralelas);
> u, n    = vetor unitário da borda e a perpendicular "pra cima";
> s       = escala do cover-fit (px de tela por px de arte).
> Local (u, v): u = deslocamento horizontal ao longo da borda, v = altura
> pra cima (as verticais da pintura continuam verticais). frameAt(f, u, v)
> = (ox + u, oy + k*u - v): é exatamente translate(origem) + shear(0, k).
> ============================================================================

## L88 (em `ShopPerspective.frameAt`, junto a `function ShopPerspective.angleOf(x0, y0, x1, y1)`)

> Ângulo (graus) do segmento (x0,y0)-(x1,y1): a trava de "uma reta só".

## L93-103 (em `ShopPerspective.angleOf`, junto a `ShopPerspective.POSE = {`)

> ============================================================================
> POSE dos objetos:
> flip  = espelha (sx = -1): a arte vista "da direita" passa a mostrar o
> lado esquerdo, como a mesa (pedido do dono pra bancada de coringa)
> shear = fração da inclinação 1:8 aplicada como cisalhamento: SÓ 1 (1:8),
> 0,5 (1:16) ou 0 (arte já desenhada na diagonal). Fração qualquer
> daria degraus irregulares (o defeito da v3c).
> size  = escala relativa
> A MESMA pose vale em repouso, em hover e no pergaminho (só o pergaminho
> dispensa o cisalhamento: lá a peça é retrato, não está na mesa).
> ============================================================================

## L126-131 (em `ShopPerspective.poseFor`, junto a `local warned = {}`)

> ============================================================================
> SPRITE de um objeto: a arte ANTIGA (vouchers/ e packs/). A animação de
> vouchers_anim/ entra no hover (quadro 0 = o PNG estático, conferido): é a
> MESMA peça na MESMA pose, nunca outra imagem.
> devolve img, srcKey (srcKey = de onde veio: igual em repouso e hover)
> ============================================================================

## L139-141 (em `warnOnce`, junto a `ShopPerspective.V4_DIR = "assets/sprites/shop/v4/"`)

> Arte v4 desenhada NA DIAGONAL da mesa (assets/sprites/shop/v4/): o elixir
> e os pacotes. Quando existe, substitui a antiga na mesa E no pergaminho
> (a mesma peça nos dois lugares).

## L143-144 (em `warnOnce`, junto a `ShopPerspective.V5_DIR = "assets/sprites/shop/v5/"`)

> v5 (Out/2026): capas de pacote refeitas como pacotes de verdade, cristal e
> prensa novos. A v5 vale antes da v4.

## L156-158 (em `v4Art`, junto a `ShopPerspective.V5_ANIM_DIR = "assets/sprites/shop/v5_anim/"`)

> Animação v5 (PixelLab animate_object sobre a arte v5/v4, quadro 0 = o PNG
> estático): assets/sprites/shop/v5_anim/<id>/<i>.png, 8 fps. Só no HOVER
> (regra do dono: animação na interação). Mesmo tamanho de canvas do PNG.

## L175-179 (em `frames`, junto a `local function crisp(img)`)

> (dono, Out/2026: "a qualidade da imagem dos do canto está ruim; no hover
> melhora"): o jogo real NÃO liga o filtro padrão nearest (só os tools),
> então o PNG estático vinha LINEAR e o cisalhamento 1:8/1:16 borrava;
> os quadros animados do hover já eram nearest. Toda imagem da mesa passa
> por aqui antes de desenhar.

## L230-233 (em `ShopPerspective._spriteFor`, junto a `local PROFILES = {}`)

> ============================================================================
> PERFIL da silhueta (ImageData lida uma vez por arquivo): caixa opaca e a
> linha mais baixa de cada coluna (o "pé" real da arte, não o fim do PNG).
> ============================================================================

## L235-237 (em `PROFILES`, junto a `function ShopPerspective.profile(path, img, rect)`)

> rect = { x, y, w, h } opcional: só esse recorte do PNG (quadro de uma
> folha, ex. o copo de dados); as coordenadas do perfil saem RELATIVAS ao
> recorte e o perfil guarda `src = rect` pra sombra amostrar o quadro certo.

## L294-296 (em `p`, junto a `local canvas, canvasW, canvasH`)

> ============================================================================
> CANVAS NA RESOLUÇÃO DA ARTE + passada
> ============================================================================

## L311-313 (em `getCanvas`, junto a `function ShopPerspective.artPass(L, box, fn)`)

> Desenha `fn()` em coordenadas da ARTE e sobe o recorte `box` (arte) pra
> tela pelo cover-fit. Sem canvas (falha de driver), desenha direto na tela
> com a mesma transformação (perde só o pixel quadrado; AVISA).

## L349-351 (em `ShopPerspective.artPass`, junto a `local silShader, silTried`)

> ============================================================================
> SILHUETA (contorno claro de 1 px de arte no hover)
> ============================================================================

## L367-369 (em `silhouette`, junto a `local function applyUpright(fx, fy, s, k, flip, prof)`)

> Transformação de um objeto EM PÉ, em coordenadas da arte:
> pé (fx, fy), escala s (px de arte por px do sprite), slope k já com o
> fator da pose, espelho. O pé da ARTE (perfil) cai exatamente no ponto.

## L379-380 (em `applyUpright`, junto a `function ShopPerspective.drawUpright(o)`)

> Desenha o objeto em pé (+ contorno de hover) no canvas da arte.
> o = { img, prof, fx, fy, s, k, flip, lift, outline (0..1), color, alpha }

## L422-423 (em `ShopPerspective.uprightBox`, junto a `function ShopPerspective.tiePoint(o, frac)`)

> Ponto (arte) na borda DIREITA da silhueta a `frac` da altura (a partir da
> base): onde o cordão da etiqueta de preço se amarra no objeto.

## L442-462 (em `ShopPerspective.tiePoint`, junto a `local BAYER = {`)

> ============================================================================
> SOMBRA (v5 r4, 13/Out/2026). Três rodadas no mesmo dia (82d32ff5, 84fa4789,
> 1324c878) desenharam a sombra como LINHAS na reta do pé: 2 a 4 fileiras de
> pontos, coluna a coluna, variando só a densidade. Qualquer objeto virava
> um traço/retângulo, porque a altura do sprite nunca entrava na conta: a
> sombra era função SÓ do contorno de baixo. O dono: "elas têm que pelo
> menos acompanhar o formato de cada coisa".
>
> Agora a sombra é a SILHUETA INTEIRA do sprite projetada no plano da mesa.
> Um pixel do objeto a `h` px de altura (acima da base, + lift se flutua)
> cai em (lean*h, dy*h) a partir do ponto da base (ShopLayout.shadowDir:
> pra direita e pra FRENTE, longe da lanterna do alto à esquerda). É uma
> transformação afim da silhueta: o shader percorre a caixa da sombra e,
> pra cada pixel de arte, INVERTE a projeção, acha o texel do sprite e lê o
> alfa dele (a máscara é o próprio sprite: nenhuma cópia por quadro, e a
> poção borbulhando projeta o quadro atual). Densidade cheia perto do
> contato e dither Bayer 4x4 (mesma matriz do `dithered`) até a ponta;
> cortada pela faixa do tampo (a MESMA de ShopLayout.ART.tableMask). Tudo
> em pixel inteiro do canvas da arte. Trava: tools/test_shop_shadows.lua
> (referência em Lua pixel a pixel contra o resultado do shader).
> ============================================================================

## L476 (em `dithered`, junto a `ShopPerspective.SHADOW_INK = Palette.darken(Palette.PARCHMENT_DARK, 0.3)`)

> tinta da sombra: madeira escurecida (quente), nunca preto puro

## L533-534 (em `castShadowShader`, junto a `function ShopPerspective.castShadowBox(o)`)

> Caixa (arte) que a sombra projetada ocupa: base do objeto (com o
> cisalhamento da pose) deslocada pelo vetor da sombra vezes a altura.

## L556-557 (em `dir`, junto a `function ShopPerspective.castParams(o)`)

> Parâmetros da projeção de um objeto (fonte única pro shader e pra
> referência em Lua do teste): devolve a tabela U preenchida.

## L612-614 (em `ShopPerspective.drawCastShadow`, junto a `function ShopPerspective.castShadowRef(o, alphaAt)`)

> Referência em Lua da MESMA projeção (pixel a pixel, pro teste e pra
> sonda): alphaAt(sx, sy) lê o alfa do sprite (px do recorte). Devolve
> {x, y, ...} planos dos pixels de arte que o shader pinta.

## L648-651 (em `pts`, junto a `function ShopPerspective.drawContactShadow(o, mask, alpha)`)

> LINHA DE CONTATO: 1 px sólido logo abaixo do contorno de baixo, só nas
> colunas em que o objeto encosta (contorno a <= G da reta do pé). Objeto
> no ar não tem contato (a sombra projetada se separa dele).
> mask = polígono (arte) onde a linha pode cair; nil = sem corte.

## L692-693 (em `ShopPerspective.drawObjectShadow`, junto a `function ShopPerspective.contactPoints(o)`)

> Pontos de contato (arte) de um objeto: usados pelo teste "nada flutua"
> (todo pé de coluna encostado tem que estar DENTRO do tampo).

## L714-717 (em `out`, junto a `function ShopPerspective.homography(x0, y0, x1, y1, x2, y2, x3, y3)`)

> ============================================================================
> HOMOGRAFIA (quadrado unitário → quadrilátero): a carta no cavalete.
> Cantos em ordem TL, TR, BR, BL. Devolve as 3 linhas da matriz.
> ============================================================================

## L738-739 (em `ShopPerspective.homography`, junto a `function ShopPerspective.unmapH(r0, r1, r2, x, y)`)

> Inversa: ponto (x, y) da tela -> (u, v) do quadrado unitário (o mouse no
> espaço da carta, pro tilt do hover). nil se a matriz for singular.

