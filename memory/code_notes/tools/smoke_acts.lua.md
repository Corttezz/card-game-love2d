---
name: code_notes/tools/smoke_acts.lua
description: Comentários com decisão/regra/histórico colhidos de tools/smoke_acts.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/smoke_acts.lua`

Origem: `tools/smoke_acts.lua` em `7dbdb60d` (7 de 14 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `local ActSystem = require("src.systems.ActSystem")`)

> tools/smoke_acts.lua
> Fase 5: valida curvas de ato, endless scaling, starter deck minimo.

## L19-21 (em `check`, junto a `check("Config.Acts tem um registro por ato de Config.TotalActs",`)

> 1. Config.Acts cobre TODOS os atos declarados. O numero deixou de ser 3
> em Set/2026 (campanha foi pros 6 biomas que ja existiam); cravar a
> contagem aqui so faria a suite brigar com a proxima mudanca de escopo.

## L26-27 (em `check`, junto a `local savedPower, savedByAct = Config.Game.ENEMY_POWER, Config.Game.ENEMY_POWER_BY_ACT`)

> 2. Curva ato 1 (rebalanced): f=1 -> hp 14, f=8 -> hp 56
> curva crua: sem a forca global do inimigo (Config.Game.ENEMY_POWER)

## L46-47 (em `check`, junto a `local primeiroEndless = Config.TotalActs + 1`)

> 5. Endless comeca UM ATO DEPOIS do ultimo, seja ele qual for, e parte
> da curva do ultimo ato da campanha.

## L56 (em `check`, junto a `local w1 = ActSystem.getRarityWeights(1)`)

> 6. Rarity weights do ato 1 sao Slay-early

## L67-69 (em `check`, junto a `local I18n = require("src.i18n.I18n")`)

> 8. Act name — agora vem do i18n (acts.act<N>), não mais do PT cravado em
> Config.Acts. O teste FIXA o locale: antes ele assumia pt_BR sem dizer, e
> passou a falhar sozinho quando a sessão de tool rodava em outro idioma.

## L79-80 (em `check`, junto a `I18n.setLocale("en")`)

> E precisa MUDAR de verdade com o idioma: nome repetido nos 5 locales
> passaria no teste de paridade e continuaria errado na tela.

