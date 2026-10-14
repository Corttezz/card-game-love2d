---
name: code_notes/src/i18n/locales/fr.lua
description: Comentários com decisão/regra/histórico colhidos de src/i18n/locales/fr.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/i18n/locales/fr.lua`

Origem: `src/i18n/locales/fr.lua` em `7dbdb60d` (16 de 41 blocos de comentário tinham marcador de decisão/regra/histórico).

## L253-255 (em `pack_spectral`, junto a `health_upgrade = {`)

> RELIQUES (ameliorations de la boutique) : `effect` est le nombre qui
> tient dans la puce du tile, `desc` l explique en une ligne et
> `flavor` est la phrase de grimoire du panneau de detail.

## L274 (em `forge_card`, junto a `remove_card    = {`)

> SERVICES (sept. 2026) : reliques qui touchent la partie, pas un combat.

## L313-314 (em `achievements`, junto a `list = {`)

> GERADO por tools/achievement_text.py (texto-fonte dos 5
> idiomas e do painel da Steam). Edite la, nao aqui.

## L386-388 (em `orb`, junto a `rest = {`)

> Feu de camp + selecteur de cartes (components/RestScreen.lua). Le
> selecteur sert TROIS modes : forger (feu/boutique), retirer et
> dupliquer (evenements).

## L546-548 (em `events`, junto a `tokens = {`)

> Vocabulario COMPARTILHADO dos rotulos [+x / -y]. Uma so
> traducao por conceito, usada por todos os eventos: e o que
> impede 'HP' e 'PV' de conviverem na mesma tela.

## L578 (em `tokens`, junto a `espantalho_falante = {`)

> Eventos de bioma (Out/2026)

## L915 (em `victory`, junto a `end_screen = {`)

> Telas finais v2 (Out/2026): botões, resumo da run e Endless.

## L963 (em `enemy`, junto a `unlock_showcase = {`)

> Revelações do menu depois da corrida (UnlockShowcase, estilo Balatro).

## L994-996 (em `effects`, junto a `damage_multiplier          = "+{pct}% de dégâts sur les cartes d'attaque",`)

> Auditoria de cartas (Out/2026): linha de efeito do painel de detalhe.
> Mesmo vocabulario das descricoes de carta; {pct} = percentual do
> multiplicador; compostos por orbType/debuffName/value (I18n.effectDesc).

## L1090-1091 (em `burn`, junto a `thorn        = { name = "Épines",`)

> Etats qui changeaient les regles sans jamais apparaitre a l'ecran.
> `desc_permanent` = la source est un joker/passif (pas de duree).

## L1208 (em `messages`, junto a `damage_preview = {`)

> ======== PRÉVIA DE DANO (Out/2026, src/ui/DamagePreviewPanel.lua) ========

## L1223 (em `damage_preview`, junto a `combo_desc  = {`)

> o que cada combo faz (tooltip no painel; {v}/{max} vem da regra)

## L1231-1232 (em `combo_desc`, junto a `combos = {`)

> ======== COMBOS (labels des regles du ComboSystem) ========
> Rebalance v2 (Jul/2026): inclut les nouveaux 'tempestade' et 'zero_absoluto'.

## L1333 (em `rogue_storm_of_steel`, junto a `warrior_plate_mail      = { name = "Cotte de Mailles",       desc = "Gagne {def} Blocage. Gagne {value} de Dex`)

> ===== NOUVELLES (2026-04-20) =====

## L1365 (em `joker_combo_pair`, junto a `warrior_taunt           = { name = "Provocation",            desc = "Gagne {def} Blocage. Applique Faible pend`)

> ===== REBALANCE v2 (Jul/2026): 12 nouvelles cartes =====

## L1380-1381 (em `rogue_toxin_master`, junto a `unlocks = {`)

> Meta-progressão (UnlockSystem — frente progressão, Out/2026).
> NÃO confundir com `unlock.class.*` (requisitos de classe, frente classes).

