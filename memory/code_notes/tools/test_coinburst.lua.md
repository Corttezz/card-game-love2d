---
name: code_notes/tools/test_coinburst.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_coinburst.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_coinburst.lua`

Origem: `tools/test_coinburst.lua` em `7dbdb60d` (5 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local TK = require("tools.testkit")`)

> tools/test_coinburst.lua
> As moedas que voam pro contador quando o jogador ganha ouro.
>
> O que se protege aqui não é a beleza da animação — é que ela EXISTA em todo
> ganho e que nunca vaze. O componente é global e roda em todos os estados;
> uma moeda que não converge fica viva para sempre por cima da UI inteira.

## L34-35 (em `M.run`, junto a `CoinBurst.clear()`)

> Convergência: TODA moeda tem que sumir. Este é o teste que importa —
> o componente desenha por cima de tudo, em todos os estados.

## L48-49 (em `M.run`, junto a `CoinBurst.clear()`)

> reducedMotion tira o MOVIMENTO. A informação (o valor) continua vindo
> do FloatingText da TopBar, que não passa por aqui.

## L56-57 (em `M.run`, junto a `CoinBurst.clear()`)

> Entradas ruins não podem estourar: isto roda no funil de ouro, que é
> chamado a cada frame em que o saldo muda.

## L67-71 (em `M.run`, junto a `CoinBurst.clear()`)

> REGRESSAO (Set/2026): a moeda que CHEGOU nao pode continuar se mexendo.
> A primeira versao era fisica livre e so iniciava o fade na chegada: a
> moeda seguia sendo integrada, passava do contador, era puxada de volta e
> ORBITAVA ate sumir. O dono viu e descreveu como "umas particulas de
> moeda ficam meio que rodando e caindo". Fade nao encerra movimento.

