---
name: code_notes/tools/screenshot_boot_entry.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_boot_entry.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_boot_entry.lua`

Origem: `tools/screenshot_boot_entry.lua` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local M = {}`)

> tools/screenshot_boot_entry.lua
> A ENTRADA do jogo (BootScene, redemoinho v14) SEM JANELA: roda o boot com
> dt fixo numa tela falsificada (canvas W×H, getWidth/getHeight mentindo),
> grava quadros PNG da cascade e uma prancha de contato. O GIF é montado
> fora (PIL) a partir dos quadros — ver scratchpad/ui3_boot_gif.py.
>
> CARDGAME_HEADLESS=1 BOOT_SEED=7 BOOT_W=960 BOOT_H=540 \
> love . test_one screenshot_boot_entry
>
> Saída (save dir): boot_entry/frame_NNN.png (15 fps, do 1º nascimento ao
> flash) + boot_entry_sheet.png (12 instantes lado a lado) + imprime a
> semente e quantas cartas voaram.

