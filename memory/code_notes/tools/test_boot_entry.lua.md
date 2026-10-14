---
name: code_notes/tools/test_boot_entry.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_boot_entry.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_boot_entry.lua`

Origem: `tools/test_boot_entry.lua` em `7dbdb60d` (1 de 8 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-19 (junto a `local TK = require("tools.testkit")`)

> tools/test_boot_entry.lua
> ENTRADA v14 (BootScene) + vida ambiente v3 do menu (Out/2026).
>
> Dono: "as cartas entram coordenadas demais, pouco aleatórias" e "muito
> mais detalhe e efeitos especiais" no menu. O redemoinho virou física por
> carta SEMEADA por boot; o menu ganhou feixe da lanterna, poeira no feixe,
> vinheta respirando, página que levanta, velas que reagem e glint no hover.
>
> O que trava aqui:
> • mesma semente → mesmas trajetórias (reprodutível); semente diferente
> → trajetórias diferentes (não é mais uma curva fixa);
> • nascimentos NÃO são um metrônomo (intervalos variam);
> • toda carta é absorvida (nenhuma fica orbitando) e o boot termina;
> • sem NaN nas poses;
> • movimento reduzido no boot: nenhuma carta voa, termina do mesmo jeito;
> • menu em movimento reduzido: dois quadros 0,7 s apart são IDÊNTICOS
> (cena estática) — e com movimento ligado, não são.
>
> love . test_one test_boot_entry

