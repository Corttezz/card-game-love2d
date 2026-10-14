---
name: code_notes/src/ui/AchievementIcons.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/AchievementIcons.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/AchievementIcons.lua`

Origem: `src/ui/AchievementIcons.lua` em `7dbdb60d` (1 de 3 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-7 (junto a `local AchievementIcons = {}`)

> src/ui/AchievementIcons.lua
> Emblemas das conquistas: assets/sprites/achievements/<id>.png (liberada) e
> <id>_locked.png (bloqueada — silhueta escurecida, derivada do emblema por
> tools/achievement_icons.py, a MESMA receita que exporta pra Steam).
>
> Cache por caminho, filtro nearest. Arquivo ausente AVISA (uma vez por id)
> e cai num medalhao procedural — nunca some em silencio.

