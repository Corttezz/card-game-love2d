---
name: code_notes/tools/test_lifecycle.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_lifecycle.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_lifecycle.lua`

Origem: `tools/test_lifecycle.lua` em `7dbdb60d` (8 de 22 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-6 (junto a `local TK = require("tools.testkit")`)

> tools/test_lifecycle.lua
> Ciclo de vida da RUN: o que o save guarda, o que o Continuar reabre, e as
> portas que deixavam a run num estado impossível. Cada bloco é um defeito
> achado na revisão de lançamento (Out/2026), descrito como o jogador o vê.
>
> love . test_one test_lifecycle

## L34-35 (em `g.runManager.currentRun.currentNode`, junto a `do`)

> 2. "Morri com o menu de pausa aberto, salvei, e o Continuar me trouxe de
> volta com 1 de vida."

## L61-62 (em `run.currentNode`, junto a `do`)

> 4. "Salvei no acampamento/evento/loja e o Continuar abriu uma LUTA."
> "Saí no cash out e refiz a batalha já vencida com o ouro no bolso."

## L135-136 (em `cases`, junto a `do`)

> 7b. "O evento me matou e a run seguiu a 0 HP" / "cliquei numa opção
> sem ouro, ela subiu -$20 e gastou o evento sem cobrar nada".

## L192-193 (em `offer`, junto a `local prev = _G.openCardPicker`)

> A loja abre o picker generico (_G.openCardPicker) e decide o estorno
> pela assinatura do deck: se nada mudou, o jogador saiu pelo Voltar.

## L218-219 (em `_G.openCardPicker`, junto a `local ProfileStats = require("engine.ProfileStats")`)

> Perfil FALSO: o XP acumulado pelas suites anteriores pode ter
> maxado o guerreiro, e no nivel maximo o XP nao cresce mais.

## L233 (em `_G.openCardPicker`, junto a `UnlockSystem.setOverrideAll(true)`)

> todo arg de tool roda com o catalogo inteiro

## L249 (em `_G.openCardPicker`, junto a `do`)

> 9. InputFocus.hideAll fecha toda tela registrada (menu nunca nasce morto).

