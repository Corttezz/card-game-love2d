---
name: code_notes/engine/SaveMigrations.lua
description: Comentários com decisão/regra/histórico colhidos de engine/SaveMigrations.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/SaveMigrations.lua`

Origem: `engine/SaveMigrations.lua` em `7dbdb60d` (4 de 5 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local Migrations = {}`)

> engine/SaveMigrations.lua
> Versionamento de save. Cada migration pega o payload em uma versão e
> transforma in-place para a próxima. Roda em cadeia até CURRENT_VERSION.
>
> Convenção: chave do dicionário é a versão de origem ("1.0"), função
> retorna a nova versão depois de transformar (ou raise em caso de save
> irrecuperável).

## L13-14 (em `Migrations`, junto a `local handlers = {`)

> Cada handler recebe payload (que tem .version, .runData, .savedAt) e
> muta payload.runData / payload.version para a próxima versão.

## L17-18 (em `handlers`, junto a `payload.version = "1.1"`)

> 1.0 → 1.1: nada a transformar nos dados (era a versão anterior
> antes do SaveManager existir). Só registra a bump.

## L22-24 (em `handlers`, junto a `payload.version = "1.2"`)

> 1.1 → 1.2: introduz RNG seedável (runData.rngState) e seed da run.
> Save antigo não tem — RunManager.loadRun tolera nil (gera Rng novo).
> Nada a transformar; registra a bump.

