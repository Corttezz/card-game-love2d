---
name: code_notes/tools/screenshot_menu_v2.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_menu_v2.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_menu_v2.lua`

Origem: `tools/screenshot_menu_v2.lua` em `7dbdb60d` (1 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local M = {}`)

> tools/screenshot_menu_v2.lua
> Valida o Menu+Entrada v2 (docs/plan/menu-crt-v2.md):
> menu_v2_osd.png       — menu com OSD do aparelho + hover CRT no botão
> menu_v2_boot_tune.png — boot logo após sintonia (chuvisco forte)
> menu_v2_boot_casc.png — boot no auge da cascade espiral + glitch título
> menu_v2_settings.png  — settings com barras de segmento OSD
> Capturas SEM CRT (doutrina — o shader é validado por screenshot_crt).
> love . screenshot_menu_v2

