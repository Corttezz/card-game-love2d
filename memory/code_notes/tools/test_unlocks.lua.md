---
name: code_notes/tools/test_unlocks.lua
description: Comentários com decisão/regra/histórico colhidos de tools/test_unlocks.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/test_unlocks.lua`

Origem: `tools/test_unlocks.lua` em `7dbdb60d` (4 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local TK = require("tools.testkit")`)

> tools/test_unlocks.lua
> Meta-progressão (src/systems/UnlockSystem.lua + src/data/unlocks.lua):
> regras de classe/carta, XP/maestria, persistência no perfil, migração de
> perfil antigo, ofertas NUNCA rolando carta bloqueada (N seeds, rewards +
> loja + pacotes), override de ferramenta e descoberta.
> love . test_one test_unlocks
>
> Perfil é FALSO (ProfileStats._swapForTests) e o override de ferramenta é
> desligado só aqui dentro — ambos restaurados no fim.

## L58-59 (em `starters`, junto a `for _, classId in ipairs(Data.CLASS_ORDER) do`)

> Núcleo saudável: perfil NOVO tem pool liberada em toda raridade
> que a oferta usa (common/uncommon/rare) pra cada classe.

## L117-118 (em `unlockedEvents`, junto a `local r2 = UnlockSystem.onRunEnded({ classId = "warrior", victory = true,`)

> Vitória: ladino + marco de vitória; contadores próprios (não dependem
> da ordem com ProfileStats.recordVictory).

## L164 (em `cardsSeen`, junto a `local Rng = require("src.systems.Rng")`)

> ===== Ofertas nunca rolam carta bloqueada =====

