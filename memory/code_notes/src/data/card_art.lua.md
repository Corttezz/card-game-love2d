---
name: code_notes/src/data/card_art.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/card_art.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/card_art.lua`

Origem: `src/data/card_art.lua` em `7dbdb60d` (5 de 17 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `return {`)

> src/data/card_art.lua
> Atlas visual: cada ID de carta mapeia para uma composição única.
> Formato de entrada:
> {
> icon       = string,    -- nome em PixelIcons (sword_short, bolt, skull, ...)
> bg         = string,    -- padrão de fundo (ver CardFrame: blood/storm/ice/...)
> accent     = string,    -- cor de destaque (Palette.<NAME>)
> effect     = string?,   -- "glow" | "holo" | nil (auto pela raridade se nil)
> decoration = string?,   -- "sparks" | "dust" | "smoke" | "flash" | nil
> }
>
> Cartas sem entrada recebem fallback derivado de (type, class, rarity).
>
> 2026-04-20: cada carta agora tem ícone único em assets/sprites/icons/<card_id>.png
> geradas via PixelLab MCP. Cartas listadas que mantêm ícones do pool original
> (sword_great, axe, skull_crowned, mask, coin, potion_red, joker_*) já eram únicos.

## L33 (em `joker_004`, junto a `warrior_bastion         = { icon = "warrior_bastion",         bg = "metal",   accent = "AGED_GOLD", effect = "`)

> ===== NOVAS (gameplay-overhaul Jul/2026 — scaling/payoffs) =====

## L119-120 (em `rogue_storm_of_steel`, junto a `warrior_plate_mail      = { icon = "armor_plate",            bg = "metal",   accent = "CYAN",         decorati`)

> ===== NOVAS (2026-04-20): reaproveitando icones do pool original =====
> Warrior

## L151 (em `joker_005`, junto a `joker_combo_volley      = { icon = "combo_volley",           bg = "storm",   accent = "AGED_GOLD",    decorati`)

> coringas de combo (Out/2026): arte PixelLab (combo_volley/wall/pair)

## L156-161 (em `joker_combo_pair`, junto a `warrior_adrenaline_rush = { icon = "warrior_adrenaline_rush", bg = "rage",   accent = "MAGENTA",   decoration `)

> ===== ORFAS (2026-09-12): 12 cartas que nao tinham entrada e caiam no
> fallback por tipo do CardArt.resolve — todas do mesmo tipo dividiam o
> MESMO icone (Adrenalina saia identica a Pocao de Cura, Grito de Comando
> idem; os 3 jokers viravam "skull"; os 3 ataques de ladino, "dagger").
> Arte propria gerada via tools/pixellab_generate_missing_art.py.
> Warrior

