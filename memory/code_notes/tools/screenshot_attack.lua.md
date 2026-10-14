---
name: code_notes/tools/screenshot_attack.lua
description: Comentários com decisão/regra/histórico colhidos de tools/screenshot_attack.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/screenshot_attack.lua`

Origem: `tools/screenshot_attack.lua` em `7dbdb60d` (2 de 2 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-4 (junto a `local M = {}`)

> tools/screenshot_attack.lua
> Valida a INVESTIDA do inimigo (FX procedural Jul/2026): captura windup,
> apex (impacto — dano aplicado aqui) e recoil, + um frame do tick de veneno.
> love . screenshot_attack

## L35-36 (em `M.run`, junto a `local moments = { 0.16, 0.335, 0.55, 1.2 }`)

> momentos: fim do windup (0.16), apex (0.34), meio do recoil (0.55),
> e depois um frame de veneno (1.2)

