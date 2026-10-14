---
name: code_notes/tools/perf_collection.lua
description: Comentários com decisão/regra/histórico colhidos de tools/perf_collection.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/perf_collection.lua`

Origem: `tools/perf_collection.lua` em `7dbdb60d` (3 de 7 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local M = {}`)

> tools/perf_collection.lua
> MEDIÇÃO da Coleção (queixa do dono: "lag na coleção"). Abre a tela, termina
> a instanciação e roda N frames de update+draw+present em 3 cenários
> (idle, hover varrendo o grid, scroll contínuo). Reporta frame time médio/p95
> (CPU do update+draw e total com present, vsync desligado) e os contadores
> de love.graphics.getStats() por frame (drawcalls, canvas/shader switches).
>
> Roda: love . perf_collection [frames]
> Não é teste (não falha): é régua. Números entram no memory/unlocks.md.

## L42-44 (em `results`, junto a `do`)

> AQUECIMENTO (Out/2026, carta visível = viva): quantos quadros até TODA
> carta animada visível estar com o set montado, e o pior quadro (ms)
> enquanto isso — é o custo de abrir a Coleção com a regra nova.

## L48-49 (em `love.mouse.getPosition`, junto a `local worst, lastGrow, visibleAnimated = 0, 0, 0`)

> 2 quadros de aquecimento da TELA (fontes, canvases) ficam de fora
> do pior quadro: o que se mede aqui e a montagem dos sets

