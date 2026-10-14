---
name: code_notes/tools/test_shop_layout.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_shop_layout.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_shop_layout.lua`

Origem: `tools/test_shop_layout.lua` em `7dbdb60d` (13 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_shop_layout.lua
> Trava GEOMÉTRICA do Balcão do Mercador (Loja v4, inclinação única 1:8,
> src/ui/shop/ShopLayout.lua). As arestas são MEDIDAS na pintura.
>
> 1) ShopLayout.validate em 9 tamanhos (800x600 até 2560x1440, mais o Steam
> Deck e o 4:3 a k=0,75): pé de todo cavalete na BORDA DO FUNDO pintada e
> de todo objeto no TAMPO pintado (máscaras em coordenadas da arte),
> nada se sobrepõe (placas, objetos x cartas, pergaminho, CONTINUAR,
> placa de título), nada fora da tela, carta legível.
> 2) A tela REAL (CardRewardScreen em modo shop) nasce e CRESCE/ENCOLHE com
> a janela falsificada, nos 5 idiomas, e continua íntegra: o caminho do
> love.resize (FontManager/CardFrame limpos + updateLayout + rebuild).
> 3) Quando falta largura (4:3), a DIAGONAL se comprime (espaçamento e
> escala cedem), nunca a ordem; passo constante ao longo da reta.
>
> love . test_one test_shop_layout

## L68-73 (em `first`, junto a `local function measureEdge(data, y0)`)

> AS ARESTAS MEDIDAS NA PINTURA (independente das constantes do layout):
> por coluna x, a última linha CLARA do tampo (o realce de 1 px que o
> tools/shop_v4_compose.py desenha) logo antes de uma linha escura, numa
> janela de ±6 px em torno de y0 - x/8. Devolve a reta de mínimos quadrados,
> o MAIOR desvio entre a linha real e lineY() e quantos degraus internos
> não têm 8 px (escadinha irregular).

## L146-147 (em `M.run`, junto a `local function evenStep(list)`)

> projeção oblíqua: escala CONSTANTE ao longo da reta e PASSO constante
> (centro a centro, ±1 px); a fileira sobe pra direita

## L151-152 (em `evenStep`, junto a `if math.abs((list[i] - list[i - 1]) - step) > 2.01 * L.cover.s then return false end`)

> v5 r2: cada carta e 1,2% menor que a anterior: o passo encolhe
> ate 2 px de ARTE por carta (a tela multiplica pelo cover-fit)

## L161 (em `cardsX`, junto a `t:truthy(("%dx%d: cartas quase do mesmo tamanho (4a >= 96%% da 1a)"):format(s[1], s[2]),`)

> v5 r2: a da direita um sopro menor (1,2%/carta), nunca escada

## L164-166 (em `cardsX`, junto a `local vao = L.cards[2].railX0 - L.cards[1].railX1 - 1`)

> v5: GRUPO de cavaletes (vão = SHELF.gap, ou gapMin na janela
> estreita), não uma escada de vãos largos; a subida da fileira
> inteira fica suave

## L173-174 (em `cardsX`, junto a `t:truthy(("%dx%d: copo e sino agrupados na ponta esquerda"):format(s[1], s[2]),`)

> mesa: três grupos com intenção (ferramentas | serviços | pacote),
> vão dentro do grupo menor que entre grupos, profundidades diferentes

## L196-198 (em `cardsX`, junto a `local tag = ("%dx%d: "):format(s[1], s[2])`)

> Loja "reta": UMA reta por carta. Carta (base), trilho e plaquinha
> de preço no MESMO frame; ângulos a <= 0,5 grau entre si e da borda
> MEDIDA na pintura; as 4 bases colineares com a borda.

## L219-220 (em `same`, junto a `for _, p in ipairs({ { rlx, rly }, { rrx, rry } }) do`)

> COLINEAR (não só paralela): a quina de baixo do trilho cai SOBRE a
> reta medida na pintura, nas duas pontas

## L232-233 (em `same`, junto a `local h0, h1, h2, h3, h4, h5, h6, h7 = ShopLayout.cardQuad(c, 1, c.lift)`)

> HOVER (v5): a carta NÃO levanta nem cresce: a pose do hover é a
> do repouso e a âncora (centro da base, no trilho) não se move

## L238-239 (em `same`, junto a `local by = (y2 + y3) / 2`)

> ÂNCORA = centro da base, dentro do trilho (sem fresta): a base da
> carta fica entre o topo do trilho e a aresta

## L245-246 (em `same`, junto a `local pq = c.plaque`)

> PREÇO: plaquinha na FACE do degrau, no eixo da carta, logo abaixo
> da aresta (vínculo físico com o próprio cavalete)

## L285-286 (em `same`, junto a `local aL, aR = ShopLayout.ambientAt(80, 260), ShopLayout.ambientAt(420, 230)`)

> v5: luz da cena nos sprites = a queda da pintura (vela à esquerda):
> mais escuro pra direita, nunca abaixo de 0,7 (o objeto continua legível)

