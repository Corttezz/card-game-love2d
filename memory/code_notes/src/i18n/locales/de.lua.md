---
name: code_notes/src/i18n/locales/de.lua
description: Comentários com decisão/regra/histórico colhidos de src/i18n/locales/de.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/i18n/locales/de.lua`

Origem: `src/i18n/locales/de.lua` em `7dbdb60d` (17 de 41 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `return {`)

> src/i18n/locales/de.lua
> Deutsch locale. Alguns labels abreviados pra caber no botao pixel.

## L253-255 (em `pack_spectral`, junto a `health_upgrade = {`)

> RELIKTE (Laden-Upgrades): `effect` ist die Zahl fuer den Chip des
> Tiles, `desc` erklaert es in einer Zeile und `flavor` ist die
> Grimoire-Zeile im Detailpanel.

## L274 (em `forge_card`, junto a `remove_card    = {`)

> DIENSTE (Sep/2026): Relikte, die den Lauf aendern, nicht einen Kampf.

## L313-314 (em `achievements`, junto a `list = {`)

> GERADO por tools/achievement_text.py (texto-fonte dos 5
> idiomas e do painel da Steam). Edite la, nao aqui.

## L386-388 (em `orb`, junto a `rest = {`)

> Lagerfeuer + Kartenauswahl (components/RestScreen.lua). Die Auswahl
> bedient DREI Modi: schmieden (Lager/Laden), entfernen und duplizieren
> (Ereignisse).

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

## L994-996 (em `effects`, junto a `damage_multiplier          = "+{pct}% Schaden auf Angriffskarten",`)

> Auditoria de cartas (Out/2026): linha de efeito do painel de detalhe.
> Mesmo vocabulario das descricoes de carta; {pct} = percentual do
> multiplicador; compostos por orbType/debuffName/value (I18n.effectDesc).

## L1090-1091 (em `burn`, junto a `thorn        = { name = "Dornen",`)

> Zustaende, die Regeln aenderten, ohne je auf dem Schirm zu erscheinen.
> `desc_permanent` = Quelle ist ein Joker/Passiv (keine Dauer).

## L1208 (em `messages`, junto a `damage_preview = {`)

> ======== PRÉVIA DE DANO (Out/2026, src/ui/DamagePreviewPanel.lua) ========

## L1223 (em `damage_preview`, junto a `combo_desc  = {`)

> o que cada combo faz (tooltip no painel; {v}/{max} vem da regra)

## L1231-1232 (em `combo_desc`, junto a `combos = {`)

> ======== COMBOS (Labels der ComboSystem-Regeln) ========
> Rebalance v2 (Jul/2026): inkl. der neuen 'tempestade' und 'zero_absoluto'.

## L1333 (em `rogue_storm_of_steel`, junto a `warrior_plate_mail      = { name = "Kettenhemd",             desc = "Erhalte {def} Block. Erhalte {value} Gesc`)

> ===== NEU (2026-04-20) =====

## L1365 (em `joker_combo_pair`, junto a `warrior_taunt           = { name = "Provozieren",            desc = "Erhalte {def} Block. Wende Schwach für {d`)

> ===== REBALANCE v2 (Jul/2026): 12 neue Karten =====

## L1380-1381 (em `rogue_toxin_master`, junto a `unlocks = {`)

> Meta-progressão (UnlockSystem — frente progressão, Out/2026).
> NÃO confundir com `unlock.class.*` (requisitos de classe, frente classes).

