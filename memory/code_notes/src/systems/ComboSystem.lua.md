---
name: code_notes/src/systems/ComboSystem.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/ComboSystem.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/ComboSystem.lua`

Origem: `src/systems/ComboSystem.lua` em `7dbdb60d` (8 de 11 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-29 (junto a `local TagSystem = require("src.systems.TagSystem")`)

> src/systems/ComboSystem.lua
> COMBOS SIMPLES (Out/2026, decisão do dono): "combos no geral estão MUITO
> fortes, de defesa e de ataque, e não são explicados — o jogador só joga
> carta e combo sem saber. Tira e põe combos mais SIMPLES: quanto mais cartas
> de ataque, mais o bônus sobe; o mesmo pra defesa; carta igual vale mais;
> coringas de combo também."
>
> Saem as 13 regras por TAG (Combo de Ataques, Remate, Convergência Arcana...)
> — ninguém sabia que tag cada carta tinha. Ficam TRÊS regras que se leem na
> própria mão, sem lógica escondida:
>
> SARAIVADA (volley) — cada carta de ATAQUE depois da primeira, na mesma
> jogada, ganha +step por ataque anterior (2º +2, 3º +4, 4º+ +6).
> MURALHA (wall)     — o mesmo para cartas de DEFESA, em Bloqueio.
> PAR (pair)         — cada CÓPIA repetida da mesma carta na jogada ganha
> +value por cópia anterior (2ª cópia +3, 3ª +6).
>
> Tudo é bônus PLANO, somado depois da Força e ANTES dos coringas (o
> multiplicador de coringa multiplica a carta já com o bônus). Carta com a tag
> `combo` (Golpe Rápido, Estilete...) conta como DUAS cartas na fila da
> Saraivada/Muralha. Coringas de combo (`combo_boost`) dobram uma das regras.
>
> Contrato (o mesmo de antes — Game, DamagePreview, piloto, tutorial e Guia
> leem daqui):
> ComboSystem.detect(turnContext, game?)          -> activeCombos
> ComboSystem.cardSteps(card, value, ctx, game?)  -> valor, passos  (PURO)
> ComboSystem.applyToCardValue(card, value, ctx)  -> valor (+ banner)
> ComboSystem.applyOnceEffects / announce          (banner + som)
> ComboSystem.RULES — a lista das 3 regras (Guia de combos, i18n)

## L43-45 (em `notifyComboUI`, junto a `local function raiseComboBanner(turnContext)`)

> O banner sobe no IMPACTO (primeira vez que um combo muda um número), não no
> clique — e só no turno de verdade (`_comboAnnounced`): o piloto estima dano
> com contexto sintético, e estimativa não é evento.

## L54-59 (em `raiseComboBanner`, junto a `ComboSystem.RULES = {`)

> ============================================================================
> As três regras (dados) — números escolhidos pela bateria (memory/combo_rules.md)
> ============================================================================
> `kind` = tipo de carta que a regra alcança; `step` = bônus por carta anterior
> na fila; `cap` = teto de cartas anteriores contadas (o bônus para de subir).
> `tag` só ilustra o Guia de combos (exemplos de carta), não decide nada.

## L78-79 (em `queueWeight`, junto a `function ComboSystem.boostFor(game, ruleId)`)

> Multiplicador dos coringas de combo sobre uma regra (combo_boost).
> Maior vence, como todo multiplicador de coringa (P0.9).

## L92-93 (em `ComboSystem.boostFor`, junto a `local function ruleBonusFor(rule, card, cards, game)`)

> Bônus de UMA regra numa carta, dado o contexto da jogada. Devolve 0 quando a
> regra não alcança a carta. `cards` = a jogada em ordem de resolução.

## L120-121 (em `playOf`, junto a `function ComboSystem.detect(turnContext, game)`)

> Combos que a jogada dispara (para banner, prévia, pontuação, conquistas).
> Cada entrada = a regra + `bonus` { type, value = soma dos bônus da jogada }.

## L140-142 (em `bonus`, junto a `function ComboSystem.cardSteps(card, baseValue, turnContext, game)`)

> Versão PURA: (valor, passos). Passo = { combo, op = "add", value, after }.
> A prévia de dano (DamagePreview) mostra estes passos como fichas — a MESMA
> conta do combate.

## L165-167 (em `ComboSystem.applyToCardValue`, junto a `function ComboSystem.applyOnceEffects(_game, turnContext)`)

> Os combos simples não têm prêmio de fim de jogada (debuff/cura/evoke saíram
> com as regras por tag). Mantido pelo contrato: o banner sobe aqui se a
> jogada tiver combo e nenhum número tiver mudado antes.

