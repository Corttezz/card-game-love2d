---
name: Damage Preview
description: Previa de dano (Out/2026) — conta da carta em fonte unica (DamagePreview.cardValue), simulacao pura da leva, painel no JOGAR, trecho da vida do inimigo, selo +COMBO; trava test_damage_preview
type: project
---

# Previa de dano

Pedido do dono (Out/2026): "nao fica claro quanto de dano vai dar — o jogador
joga as cartas e ve um dano enorme sem entender o que aconteceu".

## Fonte unica da conta

`DamagePreview.cardValue(game, card, ctx, st)` → `(valor, passos, jokerEntries, ecoUsado)`.
Pipeline: `applyCardEffects` (multi-golpe/bonus proprio) → Forca/Destreza POR GOLPE
(scaling = dobro) → `ComboSystem.cardSteps` → `EffectSystem:jokerSteps` (maior x vence
+ planos + Eco) → edicao → selo → Fraco/Fragil (-25%, por ultimo).

`Game:_resolveCardInCombat` chama ESTA funcao e so adiciona os efeitos colaterais
(`_echoFiredThisTurn`, toast + proc dos coringas via `notifyJokerProc(..., sink)`,
`ComboSystem.raiseBanner`). NAO reintroduzir conta de valor no Game.

## Simulacao da leva — `DamagePreview.simulate(game, cards)`

Pura (copias rasas). Espelha a ordem do combate (ordem de selecao):
- Impeto do guerreiro (+1 Forca ANTES das cartas, se 2+ ataques no turno)
- ataque com inimigo morto = pulado inteiro (inclusive efeitos)
- `hitEnemy`: Vulneravel x1.5 floor → Bloqueio absorve e e consumido (espelho de
  `Enemy:takeDamage`)
- gatilhos on_attack/on_defend (coringas, depois a carta), efeitos secundarios na
  ordem de `card.effects`, selo Purple (addOrb SEM evocar no transbordo)
- orbes: canalizar com fileira cheia EVOCA o mais antigo; evoke/evoke_all; Foco
- premio de combo no fim (evoke_on_combo, cura, veneno)
- `mystery` marca `uncertain`

Retorna `damage` (vida perdida), `blocked`, `block`, `heal`, `thorn`, `poison`,
`lethal`, `combos`, `cards[]` (com `steps`), `extras[]` (orbe/magia).

**Trava:** `love . test_one test_damage_preview` — 300 levas aleatorias (coringas,
orbes, edicoes, selos, Vulneravel, Bloqueio do inimigo, Fraco/Fragil, letal) pelo
combate de verdade; diverge em 0. Mexeu em Enemy:takeDamage, orbes ou efeitos de
carta? O teste acusa — atualize `simulate`.

## UI — `src/ui/DamagePreviewPanel.lua`

- **Painel** colado em cima do JOGAR (banda de acao): espada + dano, escudo +
  Bloqueio, LETAL; linhas de combo (dourado) e coringa (violeta) com hover →
  StatusTooltip (`ctx.title/body`, texto de `damage_preview.combo_desc.<id>`
  montado com os numeros da regra); por carta, nome + valor + fichas da conta.
  Falta altura: as linhas de CARTA cedem ("+N cartas"), o total fica.
- **Resolucao**: congela a previa no clique; total corre `dealt/previsto` com os
  combos; some 1,6s depois.
- **Barra do inimigo**: trecho pulsante + "-N" (`EnemyHud.hpBarRect`).
- **Mao**: selo `+COMBO` na carta que fecharia combo NOVO; hover nela → linha
  "+ Carta: total · Combo" no painel.
- Fonte pixel: o "8" da Press Start 2P parece "&" em corpo pequeno — e a fonte.
- Capturas: `PREVIEW_W/H/LOCALE ... love . test_one screenshot_damage_preview`.
