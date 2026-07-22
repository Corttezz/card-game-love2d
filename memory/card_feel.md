---
name: card_feel
description: Game feel v1 — identidade audiovisual por tema de carta (CardFeel), procs de joker estilo Balatro (JokerProcFx) e feedback do inimigo
type: project
---

# Game Feel v1 (Jul/2026) — CardFeel + JokerProcFx

Objetivo (pedido do dono): "tudo que acontece o jogador precisa SENTIR — som e
efeito na tela pra cada carta, cada joker ticando um a um como no Balatro,
cada ação do inimigo com identidade". Gameplay pode ficar mais lento pra caber
a leitura dos eventos.

## Arquitetura

```
Game:playSelectedCards
  └─ card._expectedProcs = EffectSystem:predictJokerProcs(game, card)   ← pacing
  └─ CombatSequence:startCombat
       ├─ stagger ACUMULADO: cada carta reserva cardStagger + procHold
       │    (procHold = min(4, _expectedProcs) × PROC_TICK 0.16s)
       ├─ impacto: _playImpactSfx → CardFeel.playImpact (som do TEMA;
       │    fallback sword/armor) + _spawnImpactParticles → CardFeel.burst
       ├─ onCardProcessed → Game:processCardInCombat
       │    └─ computeCardValue → applyJokerEffects retorna (valor, PROCS)
       │    └─ applyTriggerEffects({procSink = result.jokerProcs})
       │         (lifesteal/thorn/on_attack_debuff de joker também ticam)
       ├─ result.jokerProcs → ticks agendados: impacto+0.10 + (k-1)×0.16
       │    └─ JokerProcFx.tick(proc, k): juice no slot + FloatingText
       │         ("×2"/"+3"/"+4 PV") + Sfx jokerTick pitch 1.0+(k-1)×0.08
       │         + faísca JOKER_ACTIVATED no slot
       ├─ _handleResult: dano → CardFeel.burstAtEnemy(tema, k∝dano);
       │    defesa → CardFeel.burstAtPlayer("armor")
       └─ dissolve da carta ESPERA os procs dela (impactHold + procHold)
```

## CardFeel (`src/systems/CardFeel.lua`)

- `themeOf(card)`: resolve por TagSystem, ordem: fire, ice, lightning, dark,
  holy, poison, lifesteal, heal, magic (elemento vence mecânica). Cache weak.
- `THEMES[tema]` = { sfx, colours, gravity, speed, count }. Gravity dá física:
  fogo/holy/veneno sobem, gelo/físico caem, raio explode reto.
- Temas internos (sem tag): `physical` (faísca aço, ataques sem tema no
  inimigo), `armor`, `buff` (fúria vermelha), `weak`, `vulnerable`.
- `burst(tema,x,y,k)`, `burstAtEnemy(tema,k)` (EnemyRenderer.getLastPos),
  `burstAtPlayer(tema,k)` (âncora 120, H-120 = painel do jogador).
- Suporte novo no engine: `Particles` aceita `gravity` (px/s² em vy).

## Procs de joker (Balatro)

- `EffectSystem:applyJokerEffects` → retorna `(finalValue, procs)`;
  procs = `{ slotIndex, joker, label, kind }`. Multiplicador (largest-wins)
  vira "×2" (kind mult), bônus flat "+3" (kind chips).
- Triggers com fonte joker empurram no `context.procSink`:
  on_attack_heal "+N PV" (heal), on_defend_damage "Reflete N" (mult),
  on_attack_debuff nome do status (buff).
- `EffectSystem:predictJokerProcs(game, card)`: contagem barata pra ESTICAR o
  stagger ANTES do combate (previsão errada só muda pacing, nunca valores).
- `JokerProcFx.tick` (src/ui/): pcall em GameplayScene.jokerSlotCenter(i) —
  headless-safe. GameplayScene expõe `jokerSlotCenter(i)` da mesma geometria
  do draw (fonte única jokerFrameGeometry).

## Sons novos (ElevenLabs, audio/sfx/, registrados em main.lua)

impact-fire/ice/lightning/dark/holy/arcane/poison, heal-shimmer, joker-tick,
enemy-buff-roar, thorn-reflect. Volumes 0.48–0.58.

## Inimigo

- buff: `enemyBuffRoar` (NÃO reusar enemyAttack — soava como golpe) + burst
  "buff" subindo do corpo.
- defend: armorSound + burst "armor" no corpo.
- poison tick: poisonTick + burst "poison" borbulhando do sprite.
- apply_debuff (carta OU trigger): burst da cor do status no inimigo.
- Evoke de orbe: burst do elemento no ALVO (dano→inimigo, armor/cura→player).

## Regras a preservar

- Elemento define o SOM do impacto; sem tema → sword/armor (identidade física
  continua o baseline).
- Proc só existe se o joker MUDOU o valor (delta ≠ 0) — joker inerte não tica.
- O tick sonoro sobe de pitch na cadeia (1º grave → 4º agudo). Cap visual de
  pacing em 4 procs por carta (procHold), mas TODOS os procs ticam.
- Dissolve da carta espera os procs DELA — o jogador vê o joker reagir com a
  carta ainda na tela (causalidade Balatro).
- Tudo headless-safe: Sfx no-op, pcall nos requires de UI, partículas só
  spawnam com love.graphics.
