---
name: code_notes/tools/screenshot_menu_life.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_menu_life.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_menu_life.lua`

Origem: `tools/screenshot_menu_life.lua` em `7dbdb60d` (1 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local M = {}`)

> tools/screenshot_menu_life.lua
> O MENU PRINCIPAL com a vida ambiente v3 (Out/2026), SEM JANELA: tela
> falsificada (canvas W×H), Menu real, intro passada, mouse FALSO em cima
> do JOGAR (hover + glint). Também captura a variante em MOVIMENTO REDUZIDO
> (cena estática) pra conferir que nada some, só o movimento.
>
> CARDGAME_HEADLESS=1 MENU_W=1920 MENU_H=1080 love . test_one screenshot_menu_life
>
> Saída (save dir): menu_life_<W>x<H>.png, menu_life_<W>x<H>_hover.png,
> menu_life_<W>x<H>_reduced.png

