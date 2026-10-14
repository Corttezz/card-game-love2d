---
name: code_notes/engine/Easing.lua
description: Comentários com decisão/regra/histórico colhidos de engine/Easing.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/Easing.lua`

Origem: `engine/Easing.lua` em `7dbdb60d` (4 de 6 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-9 (junto a `local Easing = {}`)

> engine/Easing.lua
> Funções de easing reutilizáveis. Formato: f(t in [0,1]) → [0,1].
> Um único namespace pra todos os tweens (Event.ease, Moveable.juice,
> animações ad-hoc). Consolidação do antigo src/ui/Animation.lua:Easing.
>
> Uso:
> local Easing = require("engine.Easing")
> local y = Easing.smooth(progress)
> local y = Easing.apply("smooth", progress)  -- lookup por nome

## L28 (em `Easing.easeInOut`, junto a `function Easing.outQuart(t)`)

> Quad out (padrão do CombatAnimationSystem legado, mantido pra compat).

## L55 (em `Easing.elastic`, junto a `function Easing.backOut(t)`)

> Back-out (carta passa do destino e volta). Feel de "settle" Balatro.

## L77-83 (em `byName`, junto a `local warnedNames = {}`)

> Nomes desconhecidos caem em `smooth` — comportamento mantido de propósito
> (mudar a resolução agora alteraria animações já afinadas no olho sob smooth).
> O que mudou (Set/2026): o fallback deixou de ser MUDO. Um nome errado custou
> caro: `PackOpenScreen` passava "easeOut" em camelCase em 6 lugares e a
> cinemática inteira rodou com `smooth` por rodadas de polish sem ninguém notar.
> byName é case-sensitive e só tem minúsculas (easeout, ease_out, outquart...).
> Avisa UMA vez por nome — Easing.apply roda a cada frame de cada ease.

