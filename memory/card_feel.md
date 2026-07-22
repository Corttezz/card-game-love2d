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

## Feel v2 (mesmo dia): física por tipo + assinatura por joker

- **Moveable ganhou 2 canais novos** (compõem com o juice, tickam no
  updateJuice SEMPRE — não deixar o early-return do juice congelá-los):
  - `hop_up(obj, px, dur)` → pulinho vertical meia-senoide;
    `hopOffset(obj)` somado no totalOffsetY do Card:draw.
  - `swell_up(obj, add, dur)` → crescida SEM oscilação (rise 18% + decay²);
    `swellFactor(obj)` multiplicado no scale do Card:draw.
  - Proxies: `card:hop_up()` / `card:swell_up()`. Respeitam reducedMotion.
- **Reação física por tipo no impacto** (CombatSequence):
  ataque = hop 24px + juice rot −0.18 (investida, lado direito sobe);
  defesa = swell +0.32 (incha, escudo ganhando corpo);
  efeito = hop 12px + juice rot 0.22 (rebolada mística).
- **Joker proc** = hop 16px + juice rot −0.16 (a "puladinha" pedida).
- **Carta de efeito tem 3 CAMADAS sonoras**: effectCast (lançamento) →
  effectChime no impacto (ou som do tema se houver) → effectResolve (+0.16s).
- **Assinatura sonora POR JOKER**: `audio/sfx/joker-sig/<id>.mp3` → main.lua
  REGISTRA POR SCAN do diretório como `jokerSig_<id>` (joker novo = dropar o
  arquivo, zero código). JokerProcFx toca a assinatura (pitch +0.05/elo) com
  fallback `jokerTick` via `Sfx.has()`. 28 assinaturas geradas (ElevenLabs),
  prompts casados com a identidade (Vampiro=drenar sangue, Bobo=guizos,
  Juggernaut=passo blindado, Gema=ping de cristal...).

## Feel v3: TURNOS BEM DEFINIDOS (feedback do dono — "nada sobrepõe")

- **Cartas**: modelo Balatro real — TODAS voam pro centro quase juntas
  (launchStagger 0.08, "mão na mesa"); a RESOLUÇÃO é estritamente sequencial:
  carta 1 impacta → jokers dela ticam → respiro (resolveGap 0.30) → carta 2.
  `resolveAt` acumula `impactHold + procHold + resolveGap` por carta. O
  `timings.cardStagger` antigo não pauta mais a resolução.
- **Turno do inimigo** (`Game:_finishEnemyTurn`): golpe aterrissa → respiro
  0.45s → DoT de veneno tica (som+bolhas+número) → respiro 0.55s → turno do
  jogador (mana/compra/turn_start). Sem veneno visível os respiros caem pra
  0.05/0.10 (não arrasta). Fallback síncrono sem EventManager (headless).
- **Guards obrigatórios** (regressão pega pelo smoke_ui_turn):
  - `Game:enemyTurn` é UM ATO: flag `_enemyActing` bloqueia re-entrância
    (o gate da cena/testes chama enemyTurn POR FRAME enquanto turn=="enemy" —
    sem o guard, o intent re-executava 4x). Limpa em `playerStep` e em
    `endTurn` (stale de batalha abandonada).
  - Token `_enemyTurnSeq` + `enemyRef` invalidam steps agendados se a batalha
    mudou durante os respiros (morte/andar novo/restart).

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
