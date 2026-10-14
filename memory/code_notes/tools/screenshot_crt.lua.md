---
name: code_notes/tools/screenshot_crt.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_crt.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_crt.lua`

Origem: `tools/screenshot_crt.lua` em `7dbdb60d` (4 de 13 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-5 (junto a `local M = {}`)

> tools/screenshot_crt.lua
> Valida a identidade CRT v2: renderiza o MENU dentro do tubo com power
> em 4 estágios (linha quente, abertura, assentando, ligado) + strength
> cheio. As demais capturas do projeto continuam SEM CRT (doutrina).
> love . screenshot_crt

## L21-22 (em `M.run`, junto a `local stages = {`)

> v3.6: as DUAS coreografias — ligar (ponto → linha → abre → rolo de
> sync → assenta) e desligar (colapso → linha → ponto de fósforo).

## L35-36 (em `stages`, junto a `local Game = require("src.core.Game")`)

> REVISÃO DE TELAS: HUD de batalha (mana canto inf-dir, vida inf-esq,
> TopBar) através do tubo — nada pode ser escondido pela máscara.

## L80 (em `stages`, junto a `CRTShader.setPower(1, 1)`)

> SURTO no pico (v3.8): vinheta/CA/ruído/hum bar no máximo.

