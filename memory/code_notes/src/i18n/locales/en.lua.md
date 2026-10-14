---
name: code_notes/src/i18n/locales/en.lua
description: Comentários com decisão/regra/histórico colhidos de src/i18n/locales/en.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/i18n/locales/en.lua`

Origem: `src/i18n/locales/en.lua` em `7dbdb60d` (20 de 43 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `return {`)

> src/i18n/locales/en.lua
> English locale (fallback global p/ qualquer chave ausente em outros locales).

## L44 (em `settings`, junto a `tab_audio   = "Audio",`)

> v3 (Oct/2026): tabs + [<] value [>] controls

## L116 (em `pause`, junto a `info_class      = "CLASS",`)

> v3 (Oct/2026): run summary + shortcuts

## L255-257 (em `pack_spectral`, junto a `health_upgrade = {`)

> RELICS (shop upgrades): `effect` is the number that fits the tile
> chip (uppercase), `desc` explains it in one line, `flavor` is the
> grimoire line shown in the detail panel.

## L276 (em `forge_card`, junto a `remove_card    = {`)

> SERVICES (Sep/2026): relics that alter the run, not a single battle.

## L315-316 (em `achievements`, junto a `list = {`)

> GERADO por tools/achievement_text.py (texto-fonte dos 5
> idiomas e do painel da Steam). Edite la, nao aqui.

## L382-384 (em `hud`, junto a `orb = {`)

> Short labels for the orb row (src/ui/OrbRow.lua): what the orb DID when it
> left its slot. Evoking is the player's choice; being pushed out is the
> full row making room -- two different events, two labels.

## L390-391 (em `orb`, junto a `rest = {`)

> Campfire + card picker (components/RestScreen.lua). The picker serves
> THREE modes: forge (campfire/shop), remove and duplicate (events).

## L531-533 (em `events`, junto a `tokens = {`)

> Vocabulario COMPARTILHADO dos rotulos [+x / -y]. Uma so
> traducao por conceito, usada por todos os eventos: e o que
> impede 'HP' e 'PV' de conviverem na mesma tela.

## L563 (em `tokens`, junto a `espantalho_falante = {`)

> Eventos de bioma (Out/2026)

## L918 (em `victory`, junto a `end_screen = {`)

> Telas finais v2 (Out/2026): botões, resumo da run e Endless.

## L966 (em `enemy`, junto a `unlock_showcase = {`)

> Revelações do menu depois da corrida (UnlockShowcase, estilo Balatro).

## L997-999 (em `effects`, junto a `damage_multiplier          = "+{pct}% damage on attack cards",`)

> Auditoria de cartas (Out/2026): linha de efeito do painel de detalhe.
> Mesmo vocabulario das descricoes de carta; {pct} = percentual do
> multiplicador; compostos por orbType/debuffName/value (I18n.effectDesc).

## L1093-1094 (em `burn`, junto a `thorn        = { name = "Thorns",`)

> States that changed the rules without ever showing up on screen.
> `desc_permanent` = source is a joker/passive (no duration to show).

## L1211 (em `messages`, junto a `damage_preview = {`)

> ======== PRÉVIA DE DANO (Out/2026, src/ui/DamagePreviewPanel.lua) ========

## L1226 (em `damage_preview`, junto a `combo_desc  = {`)

> o que cada combo faz (tooltip no painel; {v}/{max} vem da regra)

## L1234-1235 (em `combo_desc`, junto a `combos = {`)

> ======== COMBOS (ComboSystem rule labels) ========
> Rebalance v2 (Jul/2026): includes the new 'tempestade' and 'zero_absoluto'.

## L1336 (em `rogue_storm_of_steel`, junto a `warrior_plate_mail      = { name = "Chain Mail",             desc = "Gain {def} Block. Gain {value} Dexterity.`)

> ===== NEW (2026-04-20): orphan icons repurposed =====

## L1368 (em `joker_combo_pair`, junto a `warrior_taunt           = { name = "Taunt",                  desc = "Gain {def} Block. Apply Weak for {duratio`)

> ===== REBALANCE v2 (Jul/2026): 12 new cards =====

## L1383-1384 (em `rogue_toxin_master`, junto a `unlocks = {`)

> Meta-progressão (UnlockSystem — frente progressão, Out/2026).
> NÃO confundir com `unlock.class.*` (requisitos de classe, frente classes).

