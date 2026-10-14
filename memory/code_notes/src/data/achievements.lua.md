---
name: code_notes/src/data/achievements.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/achievements.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/achievements.lua`

Origem: `src/data/achievements.lua` em `7dbdb60d` (2 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-23 (junto a `return {`)

> src/data/achievements.lua
> Catalogo das conquistas. DADOS puros — a logica de unlock vive em
> src/systems/AchievementSystem.lua; a ponte com a Steam em
> src/systems/SteamBridge.lua.
>
> Calibracao herdada de Balatro/StS/Monster Train: ~1/3 cai jogando
> normalmente (JORNADA), ~1/3 exige run dedicada (RESTRICAO + MAESTRIA),
> poucas sao horizonte de dezenas de horas (LEGADO).
>
> CAMPOS
> id       chave do perfil (ProfileStats.achievements[id]) — NUNCA renomear:
> renomear apaga a conquista de quem ja tinha.
> steam    API name do Steamworks — CONGELADO (tools/test_achievements
> guarda a lista). Steam nao deixa renomear depois de publicado.
> tier     natural | build | skill | collection  (categoria da galeria)
> hidden   true = secreta: "???" ate liberar (na galeria E na Steam)
> progress { stat = <nome>, target = N } — conquista com contador; o
> valor atual vem de AchievementSystem.progressOf (fonte unica).
> name/desc FALLBACK DE DEV sem acento (o texto exibido vem do i18n,
> achievements.list.<id>.name/desc nos 5 locales).
>
> Emblema: assets/sprites/achievements/<id>.png (+ <id>_locked.png). Os dois
> sao gerados/derivados por tools/achievement_icons.py; o teste exige ambos.

## L101-102 (em `progress`, junto a `{ id = "ciclo_3",          steam = "ACH_CICLO_3",          tier = "collection",`)

> ===== POS-JOGO (Out/2026): endless em ciclos + Selos do Grimorio =====
> Marcos do endless contam ANDARES (8 por ciclo): o ciclo 3 fecha no 24.

