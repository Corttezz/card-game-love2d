---
name: code_notes/src/systems/EconomySystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/EconomySystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/EconomySystem.lua`

Origem: `src/systems/EconomySystem.lua` em `7dbdb60d` (10 de 19 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local EconomySystem = {}`)

> src/systems/EconomySystem.lua
> Sistema de economia inspirado no TFT e Balatro

## L15-18 (em `EconomySystem:new`, junto a `instance.interestPer = 5   -- $1 por cada N de ouro`)

> Juros Balatro: $1 a cada $5 guardados, teto $5 (em $25).
> FONTE ÚNICA — TopBar (preview) e RoundEval (pagamento) usam
> calculateInterest(); antes cada um tinha fórmula própria (10% float
> vs floor/5) e o número prometido nunca batia com o pago.

## L20-22 (em `EconomySystem:new`, junto a `instance.baseInterestCap = 5`)

> Teto BASE (o que toda corrida começa tendo). O teto EFETIVO é
> `baseInterestCap + bonusInterestCap`, e o bônus é comprado na loja
> (relíquia "Cofre" — ver setBonusInterestCap abaixo).

## L27 (em `EconomySystem:new`, junto a `instance.purchaseHistory = {}`)

> Histórico de gastos

## L52-58 (em `EconomySystem:spendGold`, junto a `function EconomySystem:refundPurchase(amount, itemType, itemId)`)

> Estorna uma compra que NÃO se concretizou (o jogador pagou pelo serviço da
> loja e fechou o picker de carta sem escolher nada).
>
> Não é `earnGold`: estorno não é RENDA. Somar em totalGoldEarned inflaria o
> "ganho da run" que a tela de fim de corrida mostra e mentiria nas
> estatísticas. Aqui a compra é DESFEITA: o ouro volta, o gasto desce e a
> linha some do histórico.

## L65 (em `EconomySystem:refundPurchase`, junto a `for i = #self.purchaseHistory, 1, -1 do`)

> Remove a ÚLTIMA compra igual do histórico (a que está sendo desfeita).

## L83-84 (em `EconomySystem:canAfford`, junto a `function EconomySystem:earnGold(amount, source)`)

> Ganho avulso (eventos, seal Gold, jokers que dão ouro). Não é battle gold —
> não compõe stats de "ganho por batalha".

## L110-112 (em `self.purchaseHistory`, junto a `self:setBonusInterestCap(0)`)

> Teto de juros comprado é da RUN: corrida nova volta ao base. (O espelho
> é reescrito logo em seguida por Game:syncInterestCap; zerar aqui garante
> que nenhum caminho de reset deixe o bônus da run anterior vazar.)

## L116-126 (em `self.purchaseHistory`, junto a `function EconomySystem:setBonusInterestCap(bonus)`)

> ===== TETO DE JUROS COMPRÁVEL (Set/2026) =====
>
> O teto efetivo é `base + bonus`, e o bônus é DERIVADO do ledger de serviços
> da run (quantas vezes a relíquia "Cofre" foi comprada). Este objeto guarda
> só o espelho: a fonte da verdade é `currentRun.services.interest_cap`, que
> viaja no save. Game:syncInterestCap faz o espelhamento, do mesmo jeito que
> syncArmorCap espelha o cap de armadura por ato.
>
> O espelho existe porque `calculateInterest` é chamado TODO FRAME pela
> TopBar: perguntar ao RunManager ali acoplaria economia a progressão por
> causa de um número que muda uma vez por compra.

## L142 (em `EconomySystem:getInterestCap`, junto a `function EconomySystem:calculateInterest()`)

> Juros da próxima batalha (Balatro: $1 a cada $5, teto comprável). Inteiro.

