---
name: code_notes/src/i18n/locales/pt_BR.lua
description: Comentários com decisão/regra/histórico colhidos de src/i18n/locales/pt_BR.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/i18n/locales/pt_BR.lua`

Origem: `src/i18n/locales/pt_BR.lua` em `7dbdb60d` (26 de 58 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-2 (junto a `return {`)

> src/i18n/locales/pt_BR.lua
> Locale base: portugues (BR). Sincronizado com as strings originais do jogo.

## L44 (em `settings`, junto a `tab_audio       = "Áudio",`)

> v3 (Out/2026): abas + controles [<] valor [>]

## L128 (em `pause`, junto a `info_class      = "CLASSE",`)

> v3 (Out/2026): resumo da run + atalhos

## L218 (em `round_eval`, junto a `enemy_moves = {`)

> Nomes dos golpes do inimigo (sobem do sprite quando ele age — StS ShowMoveName)

## L252-253 (em `event`, junto a `shop = {`)

> Ofertas da loja cujo texto mora em ShopSystem (packs + upgrades).
> Loja v3 (Balcão do Mercador): objetos do balcão e oferta do dia.

## L272-275 (em `pack_spectral`, junto a `health_upgrade = {`)

> RELÍQUIAS (upgrades da loja). Quatro camadas de texto, cada uma com
> um trabalho: `name` dá identidade, `effect` é o NÚMERO que cabe no
> chip do tile (curto), `desc` explica
> em uma frase e `flavor` é a linha de grimório do painel de detalhe.

## L294 (em `forge_card`, junto a `remove_card    = {`)

> SERVIÇOS (Set/2026): relíquias que mexem na corrida, não na batalha.

## L333-334 (em `achievements`, junto a `list = {`)

> GERADO por tools/achievement_text.py (texto-fonte dos 5
> idiomas e do painel da Steam). Edite la, nao aqui.

## L400-402 (em `hud`, junto a `orb = {`)

> Rotulos curtos da fileira de orbes (src/ui/OrbRow.lua): o que o orbe FEZ
> ao sair do slot. Evocar e escolha do jogador; expulsar e a fileira cheia
> abrindo vaga -- dois acontecimentos diferentes, dois rotulos.

## L408-409 (em `orb`, junto a `rest = {`)

> Fogueira + picker de cartas (components/RestScreen.lua). O picker serve
> a TRES modos: forjar (fogueira/loja), remover e duplicar (eventos).

## L530-532 (em `reward`, junto a `instructions_shop  = "Passe o mouse pra ler · CLIQUE seleciona · confirme no painel · DIREITO inspeciona",`)

> Split-view da loja: rotulos que antes so existiam como fallback PT
> cravado no CardDetailPanel/CardRewardScreen — em alemao a vitrine
> mostrava "Reliquia" no meio do texto traduzido.

## L552-554 (em `events`, junto a `tokens = {`)

> Vocabulario COMPARTILHADO dos rotulos [+x / -y]. Uma so
> traducao por conceito, usada por todos os eventos: e o que
> impede 'HP' e 'PV' de conviverem na mesma tela.

## L584 (em `tokens`, junto a `espantalho_falante = {`)

> Eventos de bioma (Out/2026)

## L939 (em `victory`, junto a `end_screen = {`)

> Telas finais v2 (Out/2026): botões, resumo da run e Endless.

## L987 (em `enemy`, junto a `unlock_showcase = {`)

> Revelações do menu depois da corrida (UnlockShowcase, estilo Balatro).

## L1020-1023 (em `crash`, junto a `effects = {`)

> ======== EFEITOS (declarados em card.effects) ========
> Chaves simples (effects.<type>) usam placeholders {value}/{stacks}/{target}.
> Chaves compostas (effects.<type>_<value>) cobrem casos onde value é um ID
> (ex: "lightning", "vulnerable"). I18n.effectDesc tenta a composta primeiro.

## L1025-1027 (em `effects`, junto a `damage_multiplier          = "+{pct}% de dano em cartas de ataque",`)

> Auditoria de cartas (Out/2026): linha de efeito do painel de detalhe.
> Mesmo vocabulario das descricoes de carta; {pct} = percentual do
> multiplicador; compostos por orbType/debuffName/value (I18n.effectDesc).

## L1087-1089 (em `effects`, junto a `status = {`)

> ======== STATUS EFFECTS (tooltips na HUD) ========
> name: label curto mostrado no header do tooltip
> desc: explicação da mecânica, suporta interpolação {stacks}/{duration}

## L1124-1125 (em `burn`, junto a `thorn        = { name = "Espinhos",`)

> Estados que mudavam regras sem aparecer na tela (Set/2026).
> `desc_permanent` = fonte é coringa/passiva (não tem duração pra mostrar).

## L1243 (em `messages`, junto a `damage_preview = {`)

> ======== PRÉVIA DE DANO (Out/2026, src/ui/DamagePreviewPanel.lua) ========

## L1258 (em `damage_preview`, junto a `combo_desc  = {`)

> o que cada combo faz (tooltip no painel; {v}/{max} vem da regra)

## L1266-1267 (em `combo_desc`, junto a `combos = {`)

> ======== COMBOS (labels das regras do ComboSystem) ========
> Rebalance v2 (Jul/2026): inclui os novos 'tempestade' e 'zero_absoluto'.

## L1277-1281 (em `cards`, junto a `attack_001              = { name = "A Rocha",          desc = "Causa {atk} de dano." },`)

> AUDITORIA Jul/2026: TODA desc daqui descreve o efeito REAL da carta
> (src/data/cards/*.lua). Nada de texto herdado do Slay the Spire com
> mecanica que nao existe aqui. Regra de ouro: {atk}/{def}/{value}/
> {stacks}/{duration} interpolam do instance (acompanham a forja);
> {value2}/{stacks2}/{duration2} leem o effects[2] (ver I18n.cardVars).

## L1380 (em `rogue_storm_of_steel`, junto a `warrior_plate_mail      = { name = "Cota de Malha",          desc = "Ganha {def} de Bloqueio. Ganha {value} de`)

> ===== NOVAS (2026-04-20): icones orfaos reaproveitados =====

## L1412 (em `joker_combo_pair`, junto a `warrior_taunt           = { name = "Provocar",               desc = "Ganha {def} de Bloqueio. Aplica Fraco por`)

> ===== REBALANCE v2 (Jul/2026): 12 cartas novas =====

## L1427-1428 (em `rogue_toxin_master`, junto a `unlocks = {`)

> Meta-progressão (UnlockSystem — frente progressão, Out/2026).
> NÃO confundir com `unlock.class.*` (requisitos de classe, frente classes).

