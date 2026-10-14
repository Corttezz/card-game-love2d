---
name: code_notes/tools/intent_fog_report.lua
description: Comentários com decisão/regra/histórico colhidos de tools/intent_fog_report.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/intent_fog_report.lua`

Origem: `tools/intent_fog_report.lua` em `7dbdb60d` (1 de 1 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-12 (junto a `local TK = require("tools.testkit")`)

> tools/intent_fog_report.lua
> RELATÓRIO da névoa de intenção (src/data/intent_fog.lua): fração de
> anúncios full / type_only / hidden por andar de cada bioma com névoa.
> 1. analítico (IntentVisibility.expectedShares);
> 2. medido: N runs simuladas × 8 andares × T anúncios pela resolução REAL
> (Rng stream "misc"), sem véu de criatura.
>
> love . test_one intent_fog_report            (10 runs × 6 anúncios/andar)
> FOG_REPORT_RUNS=30 FOG_REPORT_TURNS=8 love . test_one intent_fog_report
>
> Pra responder "quanto do ato o jogador passa sem ver o tipo?" sem
> adivinhar. Devolve true sempre (é relatório, não trava).

