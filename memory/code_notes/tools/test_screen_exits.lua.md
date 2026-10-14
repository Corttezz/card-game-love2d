---
name: code_notes/tools/test_screen_exits.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_screen_exits.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_screen_exits.lua`

Origem: `tools/test_screen_exits.lua` em `7dbdb60d` (10 de 18 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `local M = {}`)

> tools/test_screen_exits.lua
> Regressão do CONTRATO DE SAÍDA das telas que agora saem com animação
> (Set/2026): loja/recompensa (CardRewardScreen) e evento (EventScreen).
>
> O nome é do INVARIANTE, não de uma tela: toda tela cujo fechamento virou
> uma cerimônia com duração passa a ter um evento agendado entre o clique do
> jogador e a continuação da run. Quem adicionar a terceira põe o caso aqui.
>
> A saída deixou de ser `self:hide()` seco e virou uma cerimônia com duração
> (`CardRewardScreen:_exitWithFlourish`): cartas queimam, painel desliza, som
> toca e SÓ ENTÃO o callback do fluxo roda. Isso põe um evento agendado entre
> o clique do jogador e a continuação da run — e evento agendado que não
> vence é soft-lock: a tela fica visível pra sempre e o mapa nunca aparece.
>
> Este teste trava isso pelos dois lados que importam:
> 1. o callback SEMPRE roda, e roda UMA vez só (double-click no Seguir não
> pode avançar dois nós do mapa);
> 2. a tela fica visível DURANTE a cerimônia (senão ela some antes da
> animação, que é o defeito que se foi consertar);
> 3. com reducedMotion o caminho resolve NA HORA — sem depender do
> EventManager — porque a flag remove movimento, não o fluxo.
>
> Roda: love . test_one test_screen_exits

## L36-40 (em `pumpEM`, junto a `local function resetQueues()`)

> A fila `base` fica suja entre os casos (cada TK.newRunGame agenda compra de
> carta, e Card:start_dissolve agenda ease BLOQUEANTE lá — a "pegadinha
> remanescente" de memory/eventmanager_queues.md). A saída da loja roda em
> fila própria justamente pra não depender disso; limpar a base entre casos
> garante que o teste meça a fila CERTA e não o acúmulo do caso anterior.

## L88-90 (em `M.run`, junto a `do`)

> 2b. o BÔNUS de pular a loja paga uma vez só ----------------------
> (revisão de lançamento, Out/2026: o bônus era pago ANTES do guard
> _closing — cada clique na janela da cerimônia pagava de novo.)

## L131-132 (em `M.run`, junto a `local game2 = TK.newRunGame("mage")`)

> Reabrir: o _closing tem que estar limpo, senão a PRÓXIMA saída
> vira no-op e a run trava na loja seguinte.

## L141-146 (em `M.run`, junto a `do`)

> 5. A REGRESSÃO QUE IMPORTA: base SUJA não pode travar a saída ---
> Condição real: o jogador sai da loja logo depois de uma batalha, e o
> rabo do combate ainda ocupa a fila `base` com eventos BLOQUEANTES. Se a
> saída agendar lá (como a primeira versão deste código fazia), o
> callback que devolve o jogador ao mapa fica preso atrás do combate — a
> loja congela na tela. Fila própria = imune.

## L160-165 (em `M.run`, junto a `local EventScreen = require("components.EventScreen")`)

> ======================================================================
> EventScreen: mesmo contrato, mesma armadilha
> ======================================================================
> A saída do evento ganhou fade (`_closeWithFade`). Se o evento agendado
> não vencer, o jogador fica preso na tela de evento — pior que na loja,
> porque ali não sobra nem botão (eles são limpos ao escolher).

## L203 (em `calls`, junto a `resetQueues()`)

> A regressão que importa, de novo: base suja não pode prender a saída.

## L213-216 (em `calls`, junto a `resetQueues()`)

> Input ENGOLIDO durante a animação: o painel é transladado no draw
> mas o Button faz hit-test na posição real. Aceitar clique enquanto
> os dois discordam deixaria o jogador escolher a opção errada numa
> decisão irreversível.

## L224-229 (em `calls`, junto a `local RoundEvalScreen = require("components.RoundEvalScreen")`)

> ======================================================================
> RoundEvalScreen: saída diferida + ouro que só entra no POUSO
> ======================================================================
> Terceira tela com o mesmo contrato, e a de maior risco: aqui o evento
> agendado não move só pixels, ele APLICA O OURO. Se não vencer, o
> jogador não recebe o pagamento da batalha e fica preso na tela.

## L273-274 (em `calls`, junto a `resetQueues()`)

> A armadilha ORIGINAL desta tela: ela abre no frame seguinte à
> vitória, com a base cheia do rabo do combate, e agendava TUDO lá.

