---
name: code_notes/src/i18n/locales/es.lua
description: Comentários com decisão/regra/histórico colhidos de src/i18n/locales/es.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/i18n/locales/es.lua`

Origem: `src/i18n/locales/es.lua` em `7dbdb60d` (16 de 41 blocos de comentário tinham marcador de decisão/regra/histórico).

## L253-255 (em `pack_spectral`, junto a `health_upgrade = {`)

> RELIQUIAS (mejoras de la tienda): `effect` es el numero que cabe en
> el chip del tile, `desc` lo explica en una linea y `flavor` es la
> frase de grimorio del panel de detalle.

## L274 (em `forge_card`, junto a `remove_card    = {`)

> SERVICIOS (Sep/2026): reliquias que tocan la partida, no una batalla.

## L313-314 (em `achievements`, junto a `list = {`)

> GERADO por tools/achievement_text.py (texto-fonte dos 5
> idiomas e do painel da Steam). Edite la, nao aqui.

## L386-387 (em `orb`, junto a `rest = {`)

> Hoguera + selector de cartas (components/RestScreen.lua). El selector
> sirve a TRES modos: forjar (hoguera/tienda), quitar y duplicar (eventos).

## L545-547 (em `events`, junto a `tokens = {`)

> Vocabulario COMPARTILHADO dos rotulos [+x / -y]. Uma so
> traducao por conceito, usada por todos os eventos: e o que
> impede 'HP' e 'PV' de conviverem na mesma tela.

## L577 (em `tokens`, junto a `espantalho_falante = {`)

> Eventos de bioma (Out/2026)

## L914 (em `victory`, junto a `end_screen = {`)

> Telas finais v2 (Out/2026): botões, resumo da run e Endless.

## L962 (em `enemy`, junto a `unlock_showcase = {`)

> Revelações do menu depois da corrida (UnlockShowcase, estilo Balatro).

## L993-995 (em `effects`, junto a `damage_multiplier          = "+{pct}% de daño en cartas de ataque",`)

> Auditoria de cartas (Out/2026): linha de efeito do painel de detalhe.
> Mesmo vocabulario das descricoes de carta; {pct} = percentual do
> multiplicador; compostos por orbType/debuffName/value (I18n.effectDesc).

## L1089-1090 (em `burn`, junto a `thorn        = { name = "Espinas",`)

> Estados que cambiaban las reglas sin aparecer en pantalla.
> `desc_permanent` = la fuente es un comodin/pasiva (sin duracion).

## L1207 (em `messages`, junto a `damage_preview = {`)

> ======== PRÉVIA DE DANO (Out/2026, src/ui/DamagePreviewPanel.lua) ========

## L1222 (em `damage_preview`, junto a `combo_desc  = {`)

> o que cada combo faz (tooltip no painel; {v}/{max} vem da regra)

## L1230-1231 (em `combo_desc`, junto a `combos = {`)

> ======== COMBOS (labels de las reglas del ComboSystem) ========
> Rebalance v2 (Jul/2026): incluye los nuevos 'tempestade' y 'zero_absoluto'.

## L1332 (em `rogue_storm_of_steel`, junto a `warrior_plate_mail      = { name = "Cota de Malla",          desc = "Gana {def} de Bloqueo. Gana {value} de De`)

> ===== NUEVAS (2026-04-20) =====

## L1364 (em `joker_combo_pair`, junto a `warrior_taunt           = { name = "Provocar",               desc = "Gana {def} de Bloqueo. Aplica Débil duran`)

> ===== REBALANCE v2 (Jul/2026): 12 cartas nuevas =====

## L1379-1380 (em `rogue_toxin_master`, junto a `unlocks = {`)

> Meta-progressão (UnlockSystem — frente progressão, Out/2026).
> NÃO confundir com `unlock.class.*` (requisitos de classe, frente classes).

