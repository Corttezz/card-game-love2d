---
name: code_notes/tools/test_castle_gate.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_castle_gate.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_castle_gate.lua`

Origem: `tools/test_castle_gate.lua` em `7dbdb60d` (4 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-48 (junto a `local TK = require("tools.testkit")`)

> tools/test_castle_gate.lua
> A abertura do castelo tem que ser COERENTE com a arte do castelo.
>
> O defeito (Set/2026, palavras do dono):
>
> "no ato 3 ta aparecendo uma porta do nada no castelo que tinha
> porta de fogo"
>
> A fortaleza do abismo não tem porta: tem um arco EM CHAMAS. Os frames da
> cerimônia de entrada, porém, apagavam o fogo e desciam uma laje de pedra
> no vão — uma porta nascendo do nada, exatamente ao contrário de entrar.
>
> Nada no código percebia isso. `WorldRoad.drawCastle` troca a arte base
> pelo frame da anim quando `doorK > 0.02` e desenha o que estiver lá; a
> arte podia mostrar qualquer coisa. Duas travas, as duas medíveis:
>
> 1. A EMENDA — o frame 0 da abertura é a arte base do castelo. A troca
> é seca; qualquer diferença vira um pulo no instante em que doorK
> cruza 0.02.
> 2. O VÃO ABRE, NÃO FECHA.
>
> A regra 2 é a difícil, e a primeira tentativa estava errada: medi "o vão
> clareia" e três biomas reprovaram — com razão deles, não minha. O castelo
> dos campos tem uma porta de madeira DE VERDADE, que abre pra um interior
> escuro; ali escurecer é o certo. Brilho não distingue os dois casos.
>
> O que distingue é MATERIAL. Uma passagem é um BURACO: atrás dela não tem
> parede — tem escuridão (campos, planalto, gelo) ou tem fogo (abismo). Um
> portão fechado é uma SUPERFÍCIE, feita da mesma alvenaria do muro ao
> lado. Então a trava é: a cor do vão não pode CONVERGIR pra cor da parede
> que o ladeia. Porta de madeira abrindo AFASTA (vira vazio escuro); a laje
> de pedra descendo APROXIMA, porque a laje é o muro.
>
> Medido, distância do vão à parede (frame 0 → último frame):
>
> abyss ANTIGO (o defeito)  0,517 → 0,097   sobrou 19% — a pedra fechou
> abyss novo                0,517 → 0,422   sobrou 82% — o arco abre
> fields (porta de madeira) 0,090 → 0,143   SOBE: abriu pro escuro
> frost                     0,048 → 0,169   SOBE
> marsh                     0,114 → 0,384   SOBE
>
> Repare que os biomas de porta de madeira todos SOBEM: a porta some e o
> vazio atrás dela é o que mais destoa do muro. A mesma asserção aprova a
> porta de madeira e reprova a laje de pedra, que é o ponto — o corte em
> 60% da distância inicial fica larguinho entre 19% (defeito) e 82% (o
> caso aprovado mais apertado).
>
> Roda via: love . test_one test_castle_gate

## L57-61 (em `M`, junto a `local VAO      = { x0 = 0.43, x1 = 0.57, y0 = 0.76, y1 = 0.99 }`)

> O VÃO e as PAREDES QUE O LADEIAM, em coordenadas relativas da arte. Todo
> castelo do jogo põe a entrada embaixo, no meio, com alvenaria dos dois
> lados — é o vocabulário da silhueta de castelo, não detalhe de um bioma.
> As janelas são folgadas de propósito: medem o portal e o muro, não um
> pixel específico que a próxima arte pode mover.

## L86-87 (em `corMedia`, junto a `local function distanciaDoMuro(imgData)`)

> Quão LONGE o vão está do material da parede ao lado. Alto = é um buraco
> (vazio escuro ou fogo). Baixo = é alvenaria, ou seja, está fechado.

## L96-99 (em `distanciaDoMuro`, junto a `local function fracaoDiferente(a, b)`)

> Fração de pixels que diferem de forma VISÍVEL entre duas artes do mesmo
> tamanho. Contar pixels (em vez de somar erro) é o que importa aqui: um
> tremular de brasa move muitos pixels MUITO pouco, uma arte diferente move
> alguns pixels MUITO.

