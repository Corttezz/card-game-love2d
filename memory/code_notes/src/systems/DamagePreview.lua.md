---
name: code_notes/src/systems/DamagePreview.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/DamagePreview.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/DamagePreview.lua`

Origem: `src/systems/DamagePreview.lua` em `7dbdb60d` (12 de 28 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-26 (junto a `local EffectSystem = require("src.systems.EffectSystem")`)

> src/systems/DamagePreview.lua
> PREVIA DE DANO (Out/2026, pedido do dono: "o combo de muitas cartas da
> dano demais — o problema nao e o dano, e que NAO FICA CLARO quanto vai dar.
> O jogador seleciona um milhao de cartas e pronto, nao precisa pensar").
>
> Duas pecas, as duas PURAS (nao tocam em game/player/enemy):
>
> DamagePreview.cardValue(game, card, turnContext, st)
> > valor, passos, jokerEntries, ecoUsado
> O valor de UMA carta de ataque/defesa: efeitos proprios -> Forca/
> Destreza (por golpe; scaling = dobro) -> combos -> coringas (maior
> multiplicador vence + planos) -> edicao -> selo -> Fraco/Fragil.
> E a FONTE UNICA: Game:_resolveCardInCombat chama esta mesma funcao e so
> acrescenta os efeitos colaterais (toast, proc de coringa, banner). Previa
> e resultado nao podem divergir porque sao a mesma conta.
>
> DamagePreview.simulate(game, cards)
> > { damage, blocked, block, heal, thorn, lethal, combos, cards = {...},
> extras = {...}, uncertain }
> A leva INTEIRA, carta a carta, na ordem em que o combate resolve
> (ordem de selecao): Impeto do guerreiro antes de tudo, Forca/Foco/
> Vulneravel ganhos no meio da leva valendo pras cartas seguintes, orbes
> canalizando/estourando, armadura do inimigo absorvendo, inimigo morto
> no meio da leva (os ataques seguintes nao saem), premio de combo no fim.
> Trava: tools/test_damage_preview.lua joga centenas de levas aleatorias
> pelo combate de verdade e compara.

## L34-35 (em `DamagePreview`, junto a `DamagePreview.EDITION_FLAT = { foil = 5 }`)

> ===== Edicao e selo (Fase 3.2/3.3) — fonte unica, o Game usa daqui =====
> Foil e plano; Holo/Polychrome multiplicam. (A Negative saiu em Out/2026.)

## L64-68 (em `liveState`, junto a `function DamagePreview.cardValue(game, card, turnContext, st)`)

> Valor de UMA carta attack/defense. `st` = { strength, dexterity, echoFired,
> weak, frail }. Devolve (valor, passos, jokerEntries, ecoUsado).
> Passos (lidos pela UI): { kind, value/delta/mult, after, label? }
> base · effects (multi-golpe/bonus proprio) · stat · combo · joker ·
> edition · seal · weak/frail

## L83-84 (em `steps`, junto a `local stat = isAtk and (st.strength or 0) or (st.dexterity or 0)`)

> 2. Forca/Destreza — por golpe; carta com *_scaling conta o stat em DOBRO
> (auditoria Jul/2026, fonte unica do statBonus).

## L135 (em `steps`, junto a `if isAtk and st.weak then`)

> 7. Fraco (ataque) / Fragil (defesa): por ultimo, como no StS.

## L147-149 (em `steps`, junto a `function DamagePreview.buildContext(cards, game)`)

> ============================================================================
> Simulacao da leva
> ============================================================================

## L186-190 (em `orbs`, junto a `local function previewHeal(game, v)`)

> Cura com os coringas de cura, SEM efeito colateral. A previa roda todo
> quadro (hover/selecao); EffectSystem:applyHealMultiplier sem sink dispara
> o proc DIRETO no JokerProcFx — foi assim que o Calice do Sabio ficou
> soltando "×1.5 PV" do nada enquanto o jogador so passava o mouse (bug do
> dono, Out/2026). O sink descartavel engole o proc; a conta e a mesma.

## L302 (em `one`, junto a `if fromJoker then`)

> coringa arma 1x por turno (P2.3); carta arma por carta

## L322-323 (em `one`, junto a `if game.selectedClass == "warrior" and not game._impetusFiredThisTurn then`)

> Impeto do guerreiro: IMPETUS_ATTACKS (3) ataques no turno (somando levas) = +1 Forca
> ANTES das cartas resolverem (Game:applyClassTurnPassives).

## L334-335 (em `one`, junto a `local toxinsUsed = game._toxinAppliedThisTurn`)

> Toxinas do ladino: o 1o ataque do turno envenena (so informativo); a
> passiva cresce (Game.TOXIN_GROWTH) se esta leva fecha 2+ ataques no turno

## L392-394 (em `entry`)

> ============================================================================
> Dicas de combo (o que a selecao dispara e o que falta pra disparar)
> ============================================================================

## L396-398 (em `entry`, junto a `function DamagePreview.combosAddedBy(selected, card, game)`)

> O que `card` GANHARIA de combo se entrasse agora no fim da selecao:
> lista de { combo = regra, value = bonus } (Saraivada/Muralha/Par). O selo da
> mao e a linha de hover do painel leem daqui.

