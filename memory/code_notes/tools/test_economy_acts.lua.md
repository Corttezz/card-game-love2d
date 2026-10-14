---
name: code_notes/tools/test_economy_acts.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_economy_acts.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_economy_acts.lua`

Origem: `tools/test_economy_acts.lua` em `7dbdb60d` (6 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-25 (junto a `local TK = require("tools.testkit")`)

> tools/test_economy_acts.lua
> Trava do PAGAMENTO POR BATALHA escalando por ato (Set/2026).
>
> O defeito que isto tranca
>
> A campanha foi de 3 para 6 atos e o pagamento por batalha ficou parado: $5
> de vitoria fixos, $3 de HP cheio fixos, juros no teto de $5. Medido com
> `love . autoplay 16 warrior 901000` (261 batalhas, com a loja exercitada de
> verdade): renda de $9,88 por batalha CONSTANTE do ato 1 ao 6, enquanto todo
> preco de loja escala geometricamente. Resultado medido: 74 compras no ato 1
> e 1 compra no ato 6 — a loja fecha sozinha na metade final da campanha.
>
> A correcao poe a vitoria em `BASE + POR_ATO*(ato-1)`. Este teste garante
> tres coisas que e facil quebrar sem perceber:
>
> 1. o ato 1 continua pagando exatamente o que pagava (nenhuma regressao na
> parte mais tunada do jogo);
> 2. o pagamento CRESCE de fato ato a ato — com o valor fixo de volta, os
> atos 1 e 6 pagam igual e o teste fica vermelho;
> 3. quem paga e o Game de verdade (`_buildRoundEvalSources`), nao so a
> formula do Config. Um teste que so chamasse `Config.Economy.victoryGold`
> passaria com o Game ainda pagando $5 cravado — mediria a coisa errada.
>
> Verificado revertendo a correcao (dollars = 5 fixo em Game.lua) antes de
> commitar: os itens 2 e 3 ficam vermelhos.

## L36 (em `victoryGoldPagoPeloGame`, junto a `return s.dollars or 0`)

> a vitoria e sempre a primeira fonte da folha

## L69-70 (em `M.run`, junto a `t:eq("ato nil cai na base", Config.Economy.victoryGold(nil),`)

> Ato invalido nao pode pagar menos que a base (act 0/nil vindo de um
> caminho classico sem run).

## L78-79 (em `M.run`, junto a `local a1 = victoryGoldPagoPeloGame(game, 1)`)

> HP cheio mudaria a folha; o que se mede aqui e a linha da VITORIA, que e
> sempre a primeira fonte.

## L90-92 (em `M.run`, junto a `local I18n = require("src.i18n.I18n")`)

> ===== 3) bonus de RISCO do no (Out/2026) =====
> Elite e chefe pagam uma linha a mais; luta comum e mini-chefe nao. Medido
> na folha do Game (nao so na formula), pelo rotulo traduzido da linha.

## L105 (em `game.runManager.currentRun.currentNode`, junto a `t:eq("mini-chefe sem bonus (obrigatorio = nao e risco)", bonusPago("mini_boss", 3), 0)`)

> mini-chefe e obrigatorio em todo ato: bonus nele seria renda fixa.

