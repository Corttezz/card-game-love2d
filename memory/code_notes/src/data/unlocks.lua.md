---
name: code_notes/src/data/unlocks.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/unlocks.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/unlocks.lua`

Origem: `src/data/unlocks.lua` em `7dbdb60d` (5 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local U = {}`)

> src/data/unlocks.lua
> DADOS do sistema de desbloqueio (lógica em src/systems/UnlockSystem.lua).
> Tabelas puras, sem lógica. Ver memory/unlocks.md.
>
> Filosofia (StS "Unlock" por classe + marcos Balatro):
> * Todo card que NÃO aparece aqui vem LIBERADO de fábrica. O núcleo liberado
> de cada classe mantém ~60% do pool por raridade (8 comuns, 8-12 incomuns,
> 5-7 raras) — as ofertas continuam com variedade desde a 1ª run.
> * Cada classe tem 5 NÍVEIS DE MAESTRIA; cada nível libera um pacote
> temático de 3 cartas da própria classe. XP vem do quanto a run andou
> (andares, chefes, vitória) — morrer cedo também conta, só conta menos.
> * As 3 lendárias neutras (joker_001..003) são MARCOS (Balatro): saem de
> feitos, não de XP, e valem pra qualquer classe.
> * Starters (ver CardRegistry:getStarterDeckForClass) e cartas concedidas
> por evento (effect_healing_potion) NUNCA podem entrar aqui — o teste
> test_unlocks trava isso.

## L20-24 (em `U`, junto a `U.LEVEL_COSTS = { 100, 150, 200, 250, 300 }`)

> XP pra passar DO nível N pro N+1 (índice = nível atual). 5 níveis no total:
> 100 → 250 → 450 → 700 → 1000 de XP acumulado. Uma vitória completa (6 atos)
> rende ~490 XP (nível 3); uma morte no ato 2 rende ~85. Maestria completa
> pede ~2 vitórias ou ~10 runs medianas — com 870 por vitória (calibração
> da era de 3 atos) uma run só esvaziava a progressão da classe.

## L36-37 (em `U.XP`, junto a `U.CLASS_BUNDLES = {`)

> Pacotes por classe. bundles[n] = cartas liberadas ao ATINGIR o nível n.
> `theme` é a chave i18n `unlocks.bundle.<classe>_<n>` (nome do pacote no reveal).

## L62-65 (em `rogue`, junto a `U.MILESTONES = {`)

> Marcos (cartas neutras). `kind`:
> act_cleared  — vencer o chefe do ato `n` com qualquer classe
> victory      — vencer uma run
> reach_act    — chegar ao ato `n`

## L72-75 (em `U.MILESTONES`, junto a `U.CLASSES = {`)

> Desbloqueio de CLASSES. Guerreiro sempre liberado.
> mage  — completar o Ato 2 (vencer o chefe do ato 2) com qualquer classe
> rogue — completar o Ato 4 OU vencer uma run
> reqKey/vars: chaves do bloco `unlock.class.*` dos locales (frente classes).

