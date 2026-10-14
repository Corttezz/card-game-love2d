---
name: code_notes/tools/perf_visual_diff.lua
description: Comentários com decisão/regra/histórico colhidos de tools/perf_visual_diff.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/perf_visual_diff.lua`

Origem: `tools/perf_visual_diff.lua` em `7dbdb60d` (4 de 9 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-13 (junto a `local M = {}`)

> tools/perf_visual_diff.lua
> PROVA VISUAL de otimização do WorldRoad: renderiza casos DETERMINÍSTICOS
> (relógio congelado, RNGs semeados) e compara pixel a pixel com uma
> referência gravada ANTES da mudança. Otimização de desenho que muda
> pixel não é otimização, é regressão.
>
> love . test_one perf_visual_diff ref            (grava referência)
> love . test_one perf_visual_diff cmp            (compara; PNG de diff)
> love . test_one perf_visual_diff ref:1920x1080  (idem noutro tamanho)
>
> Saída: <save dir>/perfdiff/<WxH>/{ref,cur,diff}_<caso>.png + resumo no
> console (px diferentes, maior delta por canal). Não roda no test_all:
> a referência é da máquina/driver de quem mede.

## L69-70 (em `M.run`, junto a `love.timer.getTime = function() return 1000 end`)

> relógio de parede congelado: flicker de luminária/brasas usam
> love.timer.getTime (o resto é o relógio do mundo)

## L72-73 (em `love.timer.getTime`, junto a `love.mouse.getPosition = function() return -10000, -10000 end`)

> mouse fora da janela: o hover do fork (fogo acelera, marco
> clareia) lê a posição REAL do cursor de quem roda a ferramenta

## L87-88 (em `love.mouse.getPosition`, junto a `if i % 10 == 0 or i > n - 3 then`)

> frames intermediários desenhados: o motor tem estado por
> frame (cache de fileiras, broto) que só evolui no draw

