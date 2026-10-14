---
name: code_notes/tools/test_app_loop.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_app_loop.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_app_loop.lua`

Origem: `tools/test_app_loop.lua` em `7dbdb60d` (3 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local TK = require("tools.testkit")`)

> tools/test_app_loop.lua
> Trava o teto de quadros do laco principal (src/core/AppLoop) e a regra de
> reabrir a janela no monitor salvo (src/core/WindowPlacement).
>
> Origem: auditoria de release (Out/2026). O executavel gastava ~21-29% de
> um nucleo parado no menu, e MAIS minimizado do que com foco (minimizado o
> vsync nao segura o laco). E o jogo abria sempre no monitor 1.

## L24 (em `M.run`, junto a `local cap, skip = AppLoop.frameCap(win())`)

> ===== teto de quadros =====

## L52-53 (em `M.run`, junto a `t:truthy("AppLoop instalado", AppLoop._installed == true)`)

> O laco instalado e o nosso (Release.install chama AppLoop.install
> antes do selftest; fora do selftest love.run == AppLoop.run).

