---
name: code_notes/src/ui/shop/ShopScene.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/shop/ShopScene.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/shop/ShopScene.lua`

Origem: `src/ui/shop/ShopScene.lua` em `7dbdb60d` (31 de 76 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-21 (junto a `local ShopScene = {}`)

> src/ui/shop/ShopScene.lua
> O BALCÃO DO MERCADOR EM PERSPECTIVA (Loja v3b, docs/plan/shop-v3-balcao.md
> §12, referência docs/plan/shop_reference_gpt.png): a CENA da loja.
>
> Camadas, do fundo pra frente:
> a PINTURA (assets/sprites/shop/counter_scene.png em cover-fit, como os
> salões de chefe) → pulso da lanterna pintada (ShopProps.lightLevel) →
> placa de título com os dois "?" → CARTAS nos cavaletes da borda do fundo
> (perspectiva fixa, placa de latão sob cada uma) → OBJETOS sobre a mesa em
> diagonal (relíquias, pacote, sino, copo de dados), ordenados pelo pé
> (mais fundo primeiro), cada um com a placa → marcas de poeira dos
> vendidos → PERGAMINHO de detalhe à direita (CardDetailPanel em tinta
> sobre papel + o botão COMPRAR da tela) → vida de frente (mariposa).
> O CONTINUAR é um Button da tela no canto inferior direito; os objetos
> que VOAM na compra são desenhados pela tela fora do slide (drawFlies).
>
> O que NÃO mora aqui: regra de economia. A cena recebe ofertas e avisos
> (onPurchased/onDenied/reroll/select) e só ANIMA. Geometria: ShopLayout
> (arte→tela), validada por test_shop_layout. Vida ambiente: ShopProps
> (loja-vida), chamado pelo contrato opcional — a lanterna pintada dispensa
> o sprite, então só flameAnchor/lightLevel/drawDiceCup/drawFront/update.

## L199-201 (em `self.flies`, junto a `function ShopScene:_mouseLocal()`)

> ============================================================================
> UPDATE
> ============================================================================

## L253 (em `hoverOf`, junto a `if self.bell.hot and not bellWasHot then playFirst({ "shopBellHover", "hoverRelic" }) end`)

> sininho no hover do sino, chocalho no hover do copo (dono)

## L295-297 (em `hoverOf`, junto a `function ShopScene:_flyTarget(offer, kind)`)

> ============================================================================
> EVENTOS (chamados pela tela)
> ============================================================================

## L321-322 (em `ShopScene:onPurchased`, junto a `playFirst(it:buySfx())`)

> som e FAÍSCAS por objeto (dono: "animação de compra pra cada item"):
> a cor vem do tema da relíquia (UpgradeTile.theme) ou do tipo

## L369-370 (em `ShopScene:onDenied`, junto a `function ShopScene:reroll(newOffers)`)

> Sino: os objetos antigos deslizam pra fora da mesa (esquerda) e os novos
> entram deslizando pela direita, um a um. Dados já trocaram.

## L435-437 (em `ShopScene:itemAt`, junto a `function ShopScene:_drawPainting()`)

> ============================================================================
> DRAW
> ============================================================================

## L487-488 (em `ShopScene:_drawSign`, junto a `local faces = ImageCache.tryGet("assets/sprites/shop/die_faces.png")`)

> v5: o 2º "?" é o dos DADOS do Escriba; sem rótulo ele parecia um "?"
> repetido. Um dado de 16 px à esquerda dele diz de quê é a ajuda.

## L534-536 (em `artBoxOf`, junto a `function ShopScene:_drawCards(list)`)

> Cartas nos cavaletes: carta (homografia, tela) → trilho, batentes, sombra
> de contato, plaquinha e etiqueta (arte, na grade da cena) → texto das
> placas (UI, cisalhado na mesma inclinação).

## L549-550 (em `ShopScene:_drawCards`, junto a `if g and g.newTag then`)

> etiqueta NOVA + cordão até o teto (dono: "a ficha está cortada":
> o recorte da passada só subia 16 px acima da carta)

## L561 (em `ShopScene:_drawCards`, junto a `ShopPerspective.artPass(L, box, function()`)

> sombras das cartas na parede (pixel art, grade da cena) ANTES delas

## L596-598 (em `prof`, junto a `function ShopScene:_drawTable(list)`)

> Tudo que está sobre a mesa, numa passada só na resolução da ARTE,
> ordenado pelo pé (fundo → frente); depois, na grade da UI, as etiquetas,
> o VENDIDO a giz e o nome do objeto em hover (por cima de tudo).

## L613-614 (em `ShopScene:_drawTable`, junto a `local b = pb.box`)

> folga larga: a etiqueta CRESCE no hover (rótulo até 92 px de
> arte) e desce 8 linhas; recorte curto cortava o rótulo

## L635-636 (em `ShopScene:_drawTable`, junto a `for _, e in ipairs(order) do`)

> 1. SOMBRAS de tudo (silhueta projetada + contato), antes de qualquer
> objeto: a sombra do vizinho da esquerda cai atrás do da direita

## L688-692 (em `ShopScene:_bellCost`, junto a `function ShopScene:_bellParams()`)

> Sino: a arte de sempre (objects/bell.png), em pé na diagonal, contato na
> base; sem ouro, apagado. Hover = mesmo sprite + contorno (v5: sem
> levantar). Escala 1 da grade (v5: era 0,755 do sprite: pixel fracionário
> ao lado de objetos em escala 1; um sino de balcão ~ 40% da altura da
> carta, que é o que o sprite dá em escala 1).

## L749-750 (em `ShopScene:_drawBellPlaqueText`, junto a `function ShopScene:_drawDiceArt()`)

> Copo de dados (ShopProps) na resolução da arte, com contato na base e os
> dados jogados ao longo da diagonal.

## L780-782 (em `artRect`, junto a `function ShopScene:_diceShadowParams()`)

> Parâmetros da sombra do copo: o quadro PARADO da folha (dice_cup.png,
> quadro 0) em pé no pé do copo (o DiceCup:draw usa a mesma base: rect.y +
> rect.h = fy + 1, última linha do quadro vazia).

## L807-808 (em `ShopScene:_diceShadowParams`, junto a `function ShopScene:_drawDiceShadowArt()`)

> Sombra do copo: silhueta projetada + contato; os dados à frente só a
> faixa de contato.

## L819-820 (em `ShopScene:_drawDiceShadowArt`, junto a `local lying = st and st.used and st.dice`)

> dados À FRENTE do copo (ShopLayout.TABLE.dice.diceAt): jogados, os
> dois; parado, um de enfeite (o copo sozinho lia como caneca sem preço)

## L829-830 (em `ShopScene:_drawDiceShadowArt`, junto a `function ShopScene:_diceTag()`)

> Copo de dados: não tem preço, mas no hover uma etiqueta "DADOS" pende da
> aresta na frente dele (mesmo objeto físico das outras; some ao sair).

## L855-868 (em `ShopScene:_drawCounterLabels`, junto a `local scrollCache = { key = nil, canvas = nil }`)

> ============================================================================
> PERGAMINHO (Loja v3c, queixa do dono: "o papel parece fora dos rolos; não
> está coeso com o ambiente"). UM rolo só, pixel art procedural no TAMANHO
> DE PIXEL DA PINTURA (cover-fit arredondado):
> * o papel começa ENROLADO no rolo de cima e termina enrolado no de baixo:
> os rolos são cilindros do MESMO papel, com a mesma largura; só as
> pontas do bastão de madeira (com a ponteira) saem pros lados;
> * cordão do prego da parede até as duas pontas do bastão de cima;
> * papel na luz da cena: bordas mais escuras em degraus (dither), a
> lanterna (à esquerda, no alto) aquece o canto de cima-esquerda, o canto
> de baixo-direita cai na sombra; grão fixo;
> * COMPRAR é uma FITA vermelha com selo de cera, no rodapé DO papel.
> Cache por tamanho (o papel é estático: 1 draw por quadro).
> ============================================================================

## L896-897 (em `buildScroll`, junto a `local warm = { 0.93, 0.86, 0.74 }`)

> luz âmbar da cena, um degrau abaixo do papel cru (v5, briefing item
> 8: o pergaminho dominava a tela; o texto em tinta segue >= 7:1)

## L928-929 (em `cell`, junto a `local far = (x - C.x0) / math.max(1, C.x1 - C.x0)`)

> bordas mais escuras em degraus (papel velho); o lado direito,
> longe da lanterna, um degrau a mais

## L1034-1036 (em `ShopScene:_drawScroll`, junto a `local openK = self.scrollOpen or 1`)

> v5 r2 (dono: "o pergaminho pode abrir e fechar ao trocar de carta"):
> openK = quanto do papel está desenrolado; o rolo de baixo SOBE até o
> de cima enquanto o papel some, e o texto é recortado pelo papel visível

## L1072-1073 (em `ShopScene:_drawScroll`, junto a `local okC, CRT = pcall(require, "src.ui.CRTShader")`)

> ZONA DE LEITURA do CRT (v5): o texto miúdo do pergaminho fica sem
> aberração cromática nem surto (a curvatura e as scanlines continuam)

## L1081-1082 (em `ShopScene:_drawScroll`, junto a `if CRT.setChromaScale then CRT.setChromaScale(0.45) end`)

> a loja inteira é leitura miúda (preços, nomes das cartas): a
> aberração cai a 45% (v5 r2); o tubo continua curvo e com scanlines

## L1088-1090 (em `ShopScene:_drawScroll`, junto a `function ShopScene:_drawBuyRibbon()`)

> COMPRAR = fita vermelha atravessada no rodapé do papel, com selo de cera à
> esquerda (o Button da tela vira hitbox invisível: clique, teclado e pad
> continuam nele). Sem ouro: fita desbotada e selo apagado.

## L1094-1095 (em `ShopScene:_drawBuyRibbon`, junto a `if self.screen._refreshBuyButton then self.screen:_refreshBuyButton() end`)

> estado do COMPRAR lido AGORA (ouro pode ter mudado desde o último
> refresh: antes a fita seguia acesa sem ouro até a próxima compra)

## L1146-1148 (em `ShopScene:_drawBuyRibbon`, junto a `local txt = (b and b.text) or I18n.t("reward.detail_buy", nil, "COMPRAR")`)

> texto gravado na fita
> v5 r2 (briefing item 6): apagada, a fita DIZ o motivo (vendido / sem
> ouro) em vez de só desbotar; o preço continua visível

## L1171-1174 (em `ShopScene:_drawBuyRibbon`, junto a `function ShopScene.portrait(payload, x, y, w, h, alpha)`)

> Retrato do objeto no pergaminho: o MESMO sprite (e o mesmo espelho) da
> mesa. A queixa "na bancada está de um jeito e, quando passo o mouse, fica
> de outro" era o pergaminho desenhando a arte com pedestal e halo do
> UpgradeTile ao lado do objeto novo da mesa.

## L1197-1199 (em `ctx`, junto a `self:_drawSign()`)

> a placa de título é INTERFACE: fica por cima da cena (os cordões das
> etiquetas NOVA descem do teto e passam atrás dela); o validate garante
> que nenhuma peça da vitrine invade a placa

