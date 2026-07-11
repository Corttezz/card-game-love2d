---
name: STS Powers Catalog
description: Sistema completo de buffs/debuffs do Slay the Spire — hooks, matemática dos 15 powers centrais, famílias de design, decay, ApplyPowerAction, prioridades. Referência pra evoluir nosso EffectSystem/statusEffects.
type: reference
---

# STS — Sistema de Powers (buffs/debuffs)

Fonte: `E:\dev\projects\slay-the-spire-source\src\com\megacrit\cardcrawl\powers\` (~124 classes + 27 watcher).
Regra: referência de estrutura/números, zero cópia ([[STS Source Reference]]).

## Arquitetura: power = objeto que ESCUTA eventos

Todo buff/debuff herda de `AbstractPower` e sobrescreve só os hooks que importam. Campos:
`amount` (stacks; -1 = flag passiva sem número), `type` (BUFF/DEBUFF), `isTurnBased` (decai),
`priority` (ordenação), `canGoNegative` (Strength/Focus), `justApplied` (proteção anti-decay no turno em que foi aplicado).

**~50 hooks disponíveis** (AbstractPower.java:198-390). Os que importam:
- Pipeline de dano: `atDamageGive → atDamageReceive → atDamageFinalGive → atDamageFinalReceive`
  (aditivos no Give normal, **multiplicativos no Final** — assim Strength soma antes de Weak multiplicar)
- Pipeline de block: `modifyBlock → modifyBlockLast`
- Turno: `atStartOfTurn`, `atStartOfTurnPostDraw`, `atEndOfTurn(isPlayer)`, `atEndOfTurnPreEndTurnCards`, `atEndOfRound`
- Eventos de carta: `onCardDraw`, `onPlayCard`, `onUseCard`, `onAfterUseCard`, `onAfterCardPlayed`, `onExhaust`, `canPlayCard`
- Eventos de dano: `onAttack`, `onAttacked`, `onAttackedToChangeDamage`, `onInflictDamage`, `wasHPLost`, `onLoseHp`, `onHeal`
- Meta: `onApplyPower`, `onInitialApplication`, `onRemove`, `onDeath`, `onVictory`, `onEnergyRecharge`, `onChannel/onEvokeOrb`, `onChangeStance`, `onGainedBlock`

## Os 15 powers centrais (matemática exata)

| Power | Hook | Matemática | Decay |
|---|---|---|---|
| Strength | atDamageGive | `dano + amount` (flat, ±999, NORMAL only) | não |
| Dexterity | modifyBlock | `block + amount` (clamp ≥0) | não |
| Weak | atDamageGive | `dano × 0.75` (relic Paper Krane: ×0.60) | 1/turno, atEndOfRound |
| Vulnerable | atDamageReceive | `dano × 1.5` (Odd Mushroom no player: ×1.25; Paper Phrog: ×1.75) | 1/turno |
| Frail | modifyBlock | `block × 0.75`, priority 10 | 1/turno |
| Poison | atStartOfTurn | perde `amount` HP, depois amount-1; stacka infinito (cap 9999) | via próprio tick |
| Artifact | onSpecificTrigger | nega 1 debuff por stack (checado ANTES de aplicar, em ApplyPowerAction:125-132) | 1 por debuff negado |
| Thorns | onAttacked | devolve `amount` como DamageType.THORNS (que NÃO re-triggera thorns → anti-recursão) | não |
| Barricade | nenhum (flag -1) | block não zera entre turnos | não |
| Metallicize | atEndOfTurnPreEndTurnCards | +`amount` block todo fim de turno | não |
| Ritual | atEndOfTurn/atEndOfRound | +`amount` Strength por turno (monstro pula 1º trigger via skipFirst) | não |
| Regeneration | atEndOfTurn | cura `amount`/turno | variante player decai |
| Intangible | atDamageFinalReceive | TODO dano vira 1 (priority 75 — roda por último) | 1/turno, justApplied |
| Buffer | onAttackedToChangeDamage | absorve 1 hit inteiro (return 0), -1 stack | por hit |
| Focus | (lido pelos orbs) | ±potência dos orbs, canGoNegative | não |

## 10 famílias de design (o vocabulário completo)

1. **Stat modifiers**: flat (Strength/Dex) vs multiplicativo (Weak/Vuln/Frail). Multiplicativo roda DEPOIS.
2. **Motores por turno**: Poison, Metallicize, Ritual, Regen, Demon Form, Noxious Fumes. Combate longo = bola de neve.
3. **Reatores a evento**: Feel No Pain (block por exhaust), Dark Embrace (draw por exhaust), After Image (block por carta jogada), Thousand Cuts (dano por carta), Envenom (poison por hit), Anger (str por skill), Rage, Juggernaut (dano ao ganhar block).
4. **Bombas/countdown**: The Bomb (explode em amount==1), Combust (custo HP/turno), Amplify (consome ao usar).
5. **Proteções**: Artifact (nega debuff), Intangible (clamp 1), Buffer (absorve hit), Malleable (block escala por hit, reseta no turno).
6. **Flags passivas** (amount=-1, sem número): Barricade, Corruption, Mode Shift, Split.
7. **Auras de monstro**: Mode Shift, Split (slimes), Unawakened, Surrounded — comunicam mecânica do boss como power visível.
8. **Manipulação de custo/mão**: Confusion (custo aleatório 0-3 ao comprar, priority 0), Corruption (skills custam 0 + exhaust), Draw/DrawReduction, NoDraw, Entangle (bloqueia ataques).
9. **Cascatas com threshold**: Mantra ≥10 → muda pra stance Divinity e subtrai 10 (Watcher).
10. **Escalada permanente**: LoseStrength/LoseDexterity (devolvem no fim do turno = "temp stat" implementado como segundo power que reverte!).

## Decay — quem decrementa e quando

- Não há sistema central de decay: **cada power turn-based se decrementa** no próprio hook (`atEndOfRound` ou `atEndOfTurn`) via `ReducePowerAction`; em 0 → `RemoveSpecificPowerAction`.
- `justApplied`: debuff aplicado por monstro no turno do jogador NÃO decai naquele mesmo round (senão "Weak 1" seria inútil). Weak/Frail: `justApplied=true` se source é monstro. Vulnerable: só se `turnHasEnded`.
- Timing assimétrico é intencional: player-Intangible decai atEndOfTurn, variante IntangiblePlayer atEndOfRound.

## ApplyPowerAction — fluxo de aplicação (actions/common/ApplyPowerAction.java:95-184)

1. `onApplyPower` nos powers do source (reações a "alguém aplicou power").
2. Hooks de relíquia (Snake Skull +1 poison, Champion Belt aplica Weak junto de Vuln, Ginger/Turnip IMUNIZAM Weak/Frail no player).
3. **Artifact nega ANTES de aplicar** (consome 1 stack, SFX "NULLIFY", pula aplicação).
4. Se já tem o power → `stackPower(amount)` (fontScale 8 → pop visual do número); senão adiciona + `Collections.sort` por priority + `onInitialApplication`.
5. VFX: PowerBuffEffect (verde) / PowerDebuffEffect (vermelho) + FlashPowerEffect + SFX BUFF_1..3/DEBUFF_1..3 aleatório.
6. FAST_MODE: durações ×~0.5.

## Prioridades (ordem de execução nos hooks)

`compareTo` ascendente: Confusion 0 → Frail 10 → default 5 → Intangible 75 → Weak 99.
Intangible alto = clampa DEPOIS de tudo. Lição: modificadores multiplicativos e clamps precisam de ordem explícita.

## Interações finas (edge cases resolvidos por design)

- **Thorns anti-recursão** via DamageType (THORNS não triggera onAttacked de thorns nem block).
- **HP_LOSS** (poison, cartas de custo-vida) atravessa block e Thorns; Intangible clampa mesmo assim.
- **Strength negativa** = debuff visual (efeito vermelho) mesmo sendo o "mesmo" power.
- **Confusion** randomiza custo NO DRAW (não no uso) — custo fica visível na carta o turno todo.

## → Confronto com o nosso jogo

Nosso `EffectSystem` (processEffect/applyTriggerEffects) é **orientado a pontos fixos**: o Game.lua chama o sistema em momentos hardcoded ("attack", "defend", "turn_start"). O StS **inverte o controle**: o evento é anunciado e cada power decide reagir. Consequências práticas:
- Adicionar "ganhe block ao exaurir carta" no nosso hoje = mexer no Game.lua; no modelo StS = 1 classe/1 tabela com hook `onExhaust`.
- Nossos statusEffects (poison/weak/vulnerable/fury em Enemy.lua, buffs em Player.lua) são structs com campos fixos — equivalem à Família 1+2 apenas. Não temos famílias 3-5 (reatores, bombas, proteções) — é onde mora a profundidade de build do StS.
- Migração incremental possível: manter dados no CardDatabase (`effects = {...}`) e criar um dispatcher de hooks no EffectSystem (`EffectSystem.emit("onExhaust", ctx)`) que percorre jokers + buffs + cartas com trigger. Não precisa de classe por power.
Ver [[STS Gap Analysis]] pra priorização.
