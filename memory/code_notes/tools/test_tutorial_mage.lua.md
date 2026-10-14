---
name: code_notes/tools/test_tutorial_mage.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_tutorial_mage.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_tutorial_mage.lua`

Origem: `tools/test_tutorial_mage.lua` em `7dbdb60d` (9 de 33 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local TK = require("tools.testkit")`)

> tools/test_tutorial_mage.lua
> TRAVA do tutorial do corvo para o MAGO (Out/2026, pedido do dono: "explicar
> tudo do zero, é bem complexo"). As conversas de orbe (Tutorial.MAGE_CONVERSATIONS):
> conduit    Conduíte + fileira + número do pulso (1ª luta, orbe já na fileira)
> channel    canalizar (carta na mão ANTES / orbe criado DEPOIS, falas excludentes)
> pulse      o pulso do fim do turno (só DEPOIS do beat, na hora quieta seguinte)
> evoke_card evocar (carta de Evocar na mão; Evocar todos só se houver)
> overflow   fileira cheia: o mais antigo é EXPULSO e evoca com o valor cheio
> focus      Foco (cartas antes do ato 3; Conduíte a partir dele)
>
> 1. texto: toda fala nos 5 idiomas, {var} resolvida, sem travessão;
> 2. o que o texto PROMETE é o que o código FAZ (pulso, evoke, estouro, Foco);
> 3. a 1ª corrida do mago, na ordem e UMA vez cada, com as falas certas e
> nenhuma no meio de um beat / cena em movimento;
> 4. guerreiro e ladino nunca ouvem conversa de orbe;
> 5. âncoras REAIS: OrbRow reporta fileira/célula do mais antigo; a mão
> reporta a carta que canaliza e a que evoca.
>
> love . test_one test_tutorial_mage

## L49-50 (em `MAGE_SET`, junto a `g.enemy.maxHealth, g.enemy.health = 900, 900`)

> o inimigo do ato 1 morreria no meio do roteiro (pulso + evocações):
> a luta precisa durar o tutorial inteiro

## L163-164 (em `step`, junto a `local CombatBeats = require("src.systems.CombatBeats")`)

> Espera a jogada/fim de turno RESOLVER por inteiro (voo, impacto, beats de
> orbe, dissolve): o mesmo relógio do jogo, até a fila esvaziar.

## L191-192 (em `seen`, junto a `seen()`)

> (a) a apresentação ainda não foi vista: nenhuma conversa de orbe passa
> na frente dela (intro é a 1ª coisa que o jogador ouve)

## L199-201 (em `seen`, junto a `seen("intro", "end_turn", "second_turn")`)

> (b) depois da apresentação: Conduíte primeiro, depois a canalização.
> Os dois gatilhos armam no MESMO quadro (orbe do Conduíte na fileira,
> Descarga na mão): a ordem sai do roteiro, não do acaso.

## L242 (em `seen`, junto a `seen("intro", "end_turn", "second_turn", "conduit", "channel")`)

> (d) o pulso: só depois do beat, e só na hora quieta seguinte

## L276 (em `seen`, junto a `seen("intro", "end_turn", "second_turn", "conduit", "channel", "pulse")`)

> com Evocar TODOS na mão a 3ª fala entra

## L356-357 (em `g.player.orbs`, junto a `seen("intro", "end_turn", "second_turn", "conduit", "channel", "evoke_card", "overflow", "focus")`)

> (i) acontecimento de OUTRA batalha não vale: o pulso da luta passada
> não abre a conversa na luta seguinte (re-arma só no próximo pulso)

## L367 (em `g.player.orbs`, junto a `local leaks = {}`)

> ===== 4. guerreiro e ladino nunca ouvem conversa de orbe =====

