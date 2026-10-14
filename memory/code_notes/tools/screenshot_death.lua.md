---
name: code_notes/tools/screenshot_death.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_death.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_death.lua`

Origem: `tools/screenshot_death.lua` em `7dbdb60d` (4 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local M = {}`)

> tools/screenshot_death.lua
> Captura 4 momentos da animação de morte pra validar VISUALMENTE que ela
> acontece na tela.
>
> Dois modos, e o segundo é o que importa (Set/2026):
> love . screenshot_death        -> dispara triggerDeath NA MÃO. Valida o
> CLIPE (o monstro cai?), não o pipeline.
> love . screenshot_death orb    -> mata pelo PIPELINE DE VERDADE, com um
> pulso de orbe no fim do turno. Era essa
> a fonte que zerava a vida sem encenar
> morte nenhuma; aqui ninguém chama
> triggerDeath, o jogo é que tem que
> chamar. Se a correção sumir, as capturas
> mostram o monstro EM PÉ.

## L54-55 (em `M.run`, junto a `game.player.orbs = {}`)

> MATA DE VERDADE: orbe de raio pulsando no fim do turno do jogador.
> Ninguém aqui chama triggerDeath — quem tem que chamar é o jogo.

## L71-73 (em `game.player.orbs`, junto a `game.enemy.health = 0`)

> Dispara death. health=0 é OBRIGATÓRIO: com inimigo "vivo" o draw
> interpreta death terminada como próxima batalha e volta pro idle
> (o 4º frame capturava o monstro ressuscitado em pé).

## L78-80 (em `game.player.orbs`, junto a `local frameTime = 1/30`)

> Captura SEQUENCIAL (padrão screenshot_crt — o encadeamento de
> callbacks aninhados só entregava o 1º frame): 4 momentos cobrindo
> início, meio, fim do clip e a pose final congelada ("cadáver").

