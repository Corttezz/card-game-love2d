---
name: code_notes/tools/screenshot_damage_preview.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_damage_preview.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_damage_preview.lua`

Origem: `tools/screenshot_damage_preview.lua` em `7dbdb60d` (4 de 16 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-15 (junto a `local M = {}`)

> tools/screenshot_damage_preview.lua
> Valida a PREVIA DE DANO na batalha real (GameplayScene, mesma ordem de
> painter do jogo), com 2..5 cartas SELECIONADAS e uma carta em hover.
>
> CARDGAME_IDENTITY=x PREVIEW_W=1920 PREVIEW_H=1080 PREVIEW_LOCALE=de \
> love . test_one screenshot_damage_preview
>
> Saidas (save dir), prefixo dmgprev_<W>x<H>_<locale>_:
> sel2.png      2 golpes (combo de ataques) + hover numa 3a carta
> sel3.png      3 cartas: golpes + defesa (ataque e bloqueio juntos)
> sel5.png      5 cartas com coringa, Forca e armadura no inimigo (RESUMO)
> sel5_details.png  a mesma leva com DETALHES (clique na placa / tecla V)
> combo_tooltip.png  hover numa ficha de combo da placa (o que ele faz)
> lethal.png    leva que mata (rotulo LETAL)
> resolving.png no meio da resolucao (total correndo + combo)

## L19-21 (em `M`, junto a `local vcanvas`)

> Sem janela (CARDGAME_HEADLESS=1, dono jogando): PREVIEW_W/H viram uma
> tela FALSIFICADA — canvas desse tamanho com getWidth/getHeight mentindo
> (mesmo truque de screenshot_enemy_scene) e o PNG sai do canvas.

## L113-115 (em `game.selectedCards`, junto a `local fakeMouse`)

> Sem janela, love.mouse.setPosition nao alcanca nada (janela 1x1 fora da
> tela): o mouse vira um ponto FALSO injetado no portao do InputFocus — e o
> que todo hover do jogo le (love.mouse.getPosition).

## L181-182 (em `game.jokerSlots`, junto a `local Panel = require("src.ui.DamagePreviewPanel")`)

> RESUMO (default) e DETALHES (clique na placa / V) da MESMA leva
> (detalhes primeiro: o lastRect que o hover abaixo mira e o do RESUMO)

