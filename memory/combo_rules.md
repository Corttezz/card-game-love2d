---
name: Combo Rules
description: ComboSystem v3 (Out/2026) — regras de sinergia por jogada, as 3 leis "intencao, nao volume" e a previa de dano que explica o numero
type: project
---

# Combos

`ComboSystem` le `turnContext.tagCounts` (construido em `Game:playSelectedCards`)
e dispara regras que amplificam dano/defesa ou aplicam efeitos extras. Um combo
vale pra UMA JOGADA (leva de cartas), nao pro turno — o turno tem varias jogadas.

## Pipeline

1. `Game:playSelectedCards` → `TagSystem.countAllTags(selectedCards)` → `turnContext.tagCounts`
2. `ComboSystem.detect(turnContext)` → `turnContext.activeCombos`
3. `ComboSystem.announce` → toasts + som (o BANNER sobe no impacto, ver `raiseComboBanner`)
4. Cada carta: `DamagePreview.cardValue` (fonte unica) chama `ComboSystem.cardSteps`
   **depois** de efeitos proprios + Forca e **antes** dos coringas
5. `onCombatAnimationComplete` → beat `combo.once_effects` → `applyOnceEffects`
   (debuff, cura, evoke)

## As 3 leis do combo v3 (Out/2026 — "intencao, nao volume")

Queixa do dono: "o combo de muitas cartas da dano demais; seleciona um milhao
de cartas e pronto, nao precisa pensar". O combo crescia MAIS RAPIDO que o
numero de cartas. Agora:

1. **ALVO** — o bonus vale so pras cartas que FORMAM o combo (`appliesTo`;
   padrao = a `tag` da regra; `"*"` = qualquer carta do tipo certo).
   `ComboSystem.cardIsTarget(rule, card)`.
2. **MAIOR MULTIPLICADOR VENCE** — numa carta so o maior multiplicador de combo
   conta (mesma lei dos coringas, P0.9). Planos somam. Ordem: x maior, depois +planos.
3. **PLANO E POR LEVA** (`bonus.once = true`) — bonus fixo entra UMA vez, na
   PRIMEIRA carta-alvo da leva (ordem de selecao = ordem de resolucao).

Resultado: dano da leva cresce LINEAR com o numero de cartas. 5 golpes de 6:
v2 = 5*(6*1.4+6) = 72 · v3 = 5*6*1.5+10 = 55.

## Regras ativas (`src/systems/ComboSystem.lua:RULES`)

| ID | Condicao | Bonus | Alvo |
|----|----------|-------|------|
| `strike_combo` | 2+ `strike` | x1.5 | cartas strike |
| `defend_wall` | 2+ `defend` | x1.5 defesa | cartas defend |
| `triple_strike` | 3+ `strike` | +10 dano, 1x/leva | 1o strike |
| `armor_tower` | 2+ `armor` | +10 defesa, 1x/leva | 1a carta armor (defesa) |
| `poison_stack` | 2+ `poison` | +2 veneno (2t) no fim | evento |
| `channel_burst` | 3+ `channel` | evoca 1 orbe no fim | evento |
| `cycle_motion` | `draw` + `discard` | +6 dano, 1x/leva | 1o ataque (`*`) |
| `finisher_chain` | `strike` + `finisher` | x1.6 | so a carta finisher |
| `lifesteal_burst` | `strike` + `lifesteal` | cura 4 no fim | evento |
| `magic_focus` | 2+ `magic` | x1.5 | cartas magic |
| `thorn_reflex` | `defend` + `thorn` | +6 defesa, 1x/leva | 1a carta thorn |
| `tempestade` | 2+ `lightning` | +6 dano, 1x/leva | 1o ataque (`*`) |
| `zero_absoluto` | 2+ `ice` | +6 defesa, 1x/leva | 1a defesa (`*`) — nao ha defesa com tag ice |

Tag `combo` na carta (Golpe Rapido, Estilete) faz as DEMAIS tags dela contarem em
dobro na CONTAGEM (`TagSystem.countAllTags`) — liga o combo com menos cartas.
`pair_tags` exige cartas DISTINTAS cobrindo o par (Balance v2).

## Previa de dano (o jogador ve a conta antes de jogar)

`src/systems/DamagePreview.lua` (puro) + `src/ui/DamagePreviewPanel.lua`. Ver
[damage_preview.md](damage_preview.md). Regra: mudou a conta de combo/coringa/
carta? Ela muda nos DOIS lugares de graca — o combate chama `DamagePreview.cardValue`.
Mudou algo que o `simulate` espelha (Enemy:takeDamage, orbes, efeitos)? Atualize o
`simulate`; `love . test_one test_damage_preview` (300 levas reais) acusa.

## Adicionar combo novo

1. Entrada em `ComboSystem.RULES` (`min_count_tag` ou `pair_tags`)
2. Bonus: `damage_multiplier`, `damage_bonus`, `defense_multiplier`,
   `defense_bonus` (com `once` opcional), `apply_debuff`, `heal`, `evoke_on_combo`
3. Defina `appliesTo` se o alvo nao for a `tag` (pares SEMPRE devem declarar)
4. Nome em `combos.<id>` e descricao em `damage_preview.combo_desc.<id>` nos 5
   locales (`{n}` = minCount, `{v}` = valor, `{stacks}`)
5. `love . smoke_combos` + `love . test_one test_damage_preview`
