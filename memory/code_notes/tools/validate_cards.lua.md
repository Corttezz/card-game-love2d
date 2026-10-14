---
name: code_notes/tools/validate_cards.lua
description: Comentários com decisão/regra/histórico colhidos de tools/validate_cards.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `tools/validate_cards.lua`

Origem: `tools/validate_cards.lua` em `7dbdb60d` (13 de 31 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-8 (junto a `local CardDatabase = require("src.systems.CardDatabase")`)

> tools/validate_cards.lua
> Validacao ofline do catalogo de cartas. Roda via:
> love . validate_cards
> Checa:
> Toda carta tem tags (array nao-vazio apos normalizacao) e deriva do tipo
> Todo effect.type e processado pelo EffectSystem (ou e placeholder conhecido)
> Histograma custo x raridade x classe
> Cartas com effects = {} (vazio) sao listadas como debito

## L17-23 (em `M`)

> Trava de arte (2026-09): a arte da carta vem do atlas `src/data/card_art.lua`,
> NAO do campo legado `image`. Carta sem entrada no atlas cai no fallback por
> tipo do CardArt.resolve e passa a dividir o mesmo icone com todas as outras
> cartas do mesmo tipo (foi assim que Adrenalina virou Pocao de Cura).
> Estas checagens falham a suite pra impedir a regressao.

## L25-27 (em `M`, junto a `local function iconExists(name)`)

> Um nome de icone so e valido se existe PNG em assets/sprites/icons OU uma
> matriz real em PixelIcons. PixelIcons.get devolve `question` pra nome
> desconhecido, entao dois icones invalidos renderizariam iguais em silencio.

## L76-77 (em `duplicateIcons`, junto a `local PROCESSED_EFFECT_TYPES = {`)

> Tipos de effect.type que o EffectSystem resolve (fase 2+).
> Mantenha em sync com src/systems/EffectSystem.lua.

## L81-82 (em `PROCESSED_EFFECT_TYPES`, junto a `echo_first_attack = true,`)

> Eco: dobra a PRIMEIRA carta de ataque do turno (mage_echo_form).
> Fica fora do largest-wins — ver EffectSystem:applyJokerEffects.

## L84-85 (em `PROCESSED_EFFECT_TYPES`, junto a `combo_boost = true,`)

> Coringas de combo (Out/2026): dobram Saraivada/Muralha/Par
> (ComboSystem.boostFor).

## L106-107 (em `PROCESSED_EFFECT_TYPES`, junto a `channel_per_turn = true,`)

> P2.1 (Jul/2026, rebalance v2): trigger turn_start que canaliza orbe
> (mage_electrodynamics). Ver EffectSystem:processTriggerEffect.

## L109-110 (em `PROCESSED_EFFECT_TYPES`, junto a `reveal_intent = true,`)

> Névoa de intenção (Out/2026): revela o anúncio do inimigo por N turnos
> (src/systems/IntentVisibility.lua). Ver EffectSystem:processEffectCard.

## L112-114 (em `PROCESSED_EFFECT_TYPES`, junto a `}`)

> Removidos: tag_observer_multiplier / tag_stack_bonus (declarados em
> versão anterior do plano combo-aware mas nunca implementados em
> EffectSystem). Reintroduzir só quando algum joker realmente precisar.

## L192 (em `histogram`, junto a `local missingArt, dupIcons, brokenIcons, deadEntries = auditCardArt(all)`)

> ===== Trava de arte =====

## L213-218 (em `histogram`, junto a `local noAnim, noSig = {}, {}`)

> ===== Trava de CARTA VIVA e de ASSINATURA SONORA (Out/2026) =====
> Doutrina de criação de carta (memory/card_icon_animation.md,
> memory/card_feel.md): toda carta tem ícone ANIMADO (icons_anim/<icon>/
> com frames) e todo coringa tem assinatura em audio/sfx/joker-sig/<id>.
> Os 3 coringas de combo entraram sem nenhum dos dois — nada pegou,
> porque a cobertura (128/128) era só convenção.

## L242-253 (em `histogram`, junto a `local cloneJokers = {}`)

> ===== Trava de CORINGA CLONADO (Set/2026) =====
> O dono achou jogando: "qual a diferenca entre deus do abismo e forma de
> eco? nenhuma, e uma e lendaria a outra rara". Eram dois jokers com
> `damage_multiplier attack 1.5` identico — e, com o largest-wins, ter os
> dois ativos nao somava NADA (max(1.5,1.5)=1.5): o segundo era ouro no
> lixo, com cara de premio.
>
> Carta normal repetir efeito e DESIGN (o ataque e a defesa da carta
> diferenciam, e o custo tambem). Coringa nao tem nem custo nem stats —
> se a assinatura de efeito e igual, nao sobra NENHUMA decisao separando
> os dois. So conta quando a mesma run pode oferecer os dois: coringas de
> classes diferentes sao paridade entre classes, nao clone.

## L279-280 (em `campos`, junto a `for i = 1, #lista do`)

> Co-ofertaveis: mesma classe, ou um dos dois e neutro
> (class="basic" aparece pra todo mundo).

