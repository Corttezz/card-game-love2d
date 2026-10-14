---
name: code_notes/tools/test_perf_budget.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_perf_budget.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_perf_budget.lua`

Origem: `tools/test_perf_budget.lua` em `7dbdb60d` (3 de 15 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local TK = require("tools.testkit")`)

> tools/test_perf_budget.lua
> TRAVA DE REGRESSÃO DE PERFORMANCE do WorldRoad (Out/2026).
>
> Não mede milissegundo (varia por máquina e por carga — numa máquina
> compartilhada o ruído é maior que a regressão). Trava as CAUSAS que a
> otimização removeu, todas determinísticas:
> 1. orçamento de DRAW CALLS por frame (era ~800-1000; hoje ~400);
> 2. câmera PARADA não reconstrói nada: a grama reusa o lote (vento no
> shader) e o chão do domo reusa a malha — 0 sprites escritos pela
> CPU por frame em batalha;
> 3. o cache NÃO fica velho: câmera andando, fork abrindo e troca de
> bioma reconstroem (otimização que congela a cena é bug pior);
> 4. ALOCAÇÃO por frame (GC) abaixo de um teto;
> 5. troca de bioma PRÉ-AQUECIDA: o 1º frame do bioma novo não
> decodifica PNG (era o engasgo de 100-370 ms da troca de ato).
> Medir ms de verdade: love . test_one perf_probe [WxH[:phases|:switch]]

## L114-117 (em `frame`, junto a `local realDraw, lastCtx = GrassField.draw, nil`)

> fork FECHANDO (bug do dono, Out/2026: "rastro liso sem grama onde
> os braços não escolhidos estavam"): a clareira de cada braço tem
> que encolher junto com o fade dele, e a grama reconstrói até
> assentar. Espia o ctx que o WorldRoad entrega ao GrassField.

## L190-191 (em `love.image.newImageData`, junto a `do`)

> 6: seleção de classe aquece o bioma 1 mesmo com o mundo parado
> em outro ato (run anterior terminou no ato 4) ----------------------

