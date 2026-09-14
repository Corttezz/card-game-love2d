---
name: Combat Beats — o metrônomo do combate
description: Set/2026. Toda batalha virou uma FILA de beats (CombatBeats): um acontecimento por instante, bloqueando o próximo. Ordem causal, tabela de tempos única, espinhos como ESTADO.
type: project
---

# Combat Beats (Set/2026)

**Pedido do dono, verbatim:** *"quando o inimigo se buffa, ou sofre algum debuff
precisamos deixar isso ser algo bloqueando do turno seguir... sinto que muitas
coisas só saem acontecendo e fica difícil de entender e acompanhar... um exemplo
é o mago com as orbes"*.

O defeito **não era falta de efeito visual** (o game feel v1/v2/v3 já tinha som,
partícula e número pra quase tudo). Era falta de **TEMPO** e de **ORDEM**: dano,
debuff no inimigo, proc de coringa, pulso de orbe e compra de carta caíam todos
no mesmo frame.

## O mecanismo

`src/systems/CombatBeats.lua`. Um **beat** = um acontecimento que ocupa um
instante só dele e SEGURA o próximo. Implementado como evento `trigger="before"`
(roda a função agora, trava a fila por `delay`) numa fila dedicada do
`_G.EventManager` chamada **`"beats"`**.

```lua
CombatBeats.push("enemy.buff", function() ... end, "STATUS")   -- 0.55s
CombatBeats.pushUntil("enemy.attack", start, isLanded, 2.5, "HIT_SETTLE")
CombatBeats.step(sink, "effect.apply_debuff", fn, "STATUS")     -- coleta ou roda já
```

- **`push` SEMPRE joga no FIM da fila**, inclusive chamado de dentro de um beat
  em execução (medido em `tools/test_beats.lua`, não suposto). Por isso toda
  sequência com passos dinâmicos é escrita como **CADEIA**: o beat corrente
  empurra os passos dele e, por último, o elo seguinte. Pré-agendar carta 1 e
  carta 2 juntas jogaria os efeitos da carta 1 pra depois da carta 2.
- **Sem `_G.EventManager` o push roda NA HORA** — a API síncrona antiga continua
  valendo pra quem chama `Game:processCardInCombat` / `applyTriggerEffects`
  direto (testes, autoplay, smoke_upgrades).
- **`CombatSequence:isBlocking()` inclui `CombatBeats.isBusy()`** — main/
  GameplayScene não disparam turno do inimigo, gameOver, victory nem nextPhase
  enquanto houver acontecimento pendente.
- **Sink**: `game._beatSink` (setado pelo `Game` enquanto resolve uma carta) e
  `context.beatSink` (triggers) transformam efeitos em passos sem duplicar
  código. Sink ausente = comportamento síncrono.

## A tabela de tempos (UMA só)

`CombatBeats.HOLD`, em `src/systems/CombatBeats.lua`, com o porquê de cada valor.
`CombatBeats.speed` é o multiplicador global pra afinar o jogo inteiro.

| nome | s | pra quê |
|---|---|---|
| MICRO | 0.10 | passo administrativo (armadura expira, vez volta) |
| JOKER_PROC | 0.16 | tick de coringa em cadeia (era o PROC_TICK do feel v1) |
| DECAY | 0.25 | status caindo / próximo intent |
| SIDE_EFFECT | 0.28 | efeito secundário de carta |
| CARD_GAP | 0.30 | respiro entre cartas |
| CARD_IMPACT | 0.35 | ler a reação física da carta (impactHold v3.1) |
| ENEMY_ACT | 0.35 | assentar depois de defender/buffar |
| HANDOFF | 0.35 | upkeep / compra |
| ORB | 0.40 | canalizar, pulsar, evocar — **um orbe por vez** |
| HIT_SETTLE | 0.40 | depois do golpe aterrissar |
| TELEGRAPH | 0.45 | intent pisca + nome do golpe |
| REFLECT | 0.45 | espinhos (causa e efeito separados) |
| DOT | 0.45 | veneno ticando |
| STATUS | 0.55 | **buff/debuff mudando estado** — o caso citado pelo dono |

**`reducedMotion` NÃO entra aqui, de propósito**: a flag tira MOVIMENTO
(amplitude de hop/juice/bob, em Moveable/Card), nunca INFORMAÇÃO nem ORDEM.

## As duas cadeias

**Resolução de carta** (`CombatSequence:startCombat`) — o VOO continua na fila
`base` em tempo absoluto (animação pura, "mão na mesa"); a RESOLUÇÃO é a cadeia:

```
combat.cards_landed > card.impact.<tipo> > joker.proc × N
  > effect.<tipo> / trigger.<gatilho>.<tipo> × N > card.dissolve
  > card.next > ... > combat.settle > combat.end > combo.once_effects
```

**Turno do inimigo** (`Game:enemyTurn` + `Game:_pushEnemyTurnTail`):

```
enemy.armor_expire > enemy.fury > enemy.telegraph
  > enemy.attack (pushUntil: espera o APEX da investida) | enemy.defend | enemy.buff
  > player.thorn_reflect > enemy.dot > enemy.next_intent
  > player.upkeep > player.draw > trigger.turn_start.* × N > turn.player_ready
```

Guardas preservadas: `_enemyActing` (o turno é UM ato; o gate da cena chama
`enemyTurn()` por frame) e o par `_enemyTurnSeq`/`enemyRef` (passo atrasado vira
no-op se a batalha trocou). Um turno típico dá **~2,4 s**.

## ESPINHOS viraram ESTADO (mudança de regra)

Antes: `on_defend_damage` causava o dano **no instante em que a defesa era
jogada** — o reflexo acontecia mesmo que o inimigo nunca atacasse, e a palavra
"refletir" era mentira. Agora (padrão StS / Flame Barrier):

1. a carta/coringa **ARMA** `player:addBuff("thorn", 1, N)`;
2. quando o inimigo **golpeia**, o beat `player.thorn_reflect` chama
   `EffectSystem:fireThornReflect(game)`;
3. o buff expira no `Player:onTurnStart` seguinte (upkeep).

`Player.NON_CUMULATIVE_DURATION = { thorn = true }`: duas defesas no mesmo turno
somam STACKS, não DURAÇÃO. A regra P2.3 sobreviveu — coringa ARMA 1×/turno,
carta arma por carta jogada: o teto por turno é o mesmo de antes, o que mudou é
**quando** o dano sai.

## ENFURECIDO: o inimigo cruzando os 30% de vida

`Enemy:takeDamage` sempre deu **+50% de dano permanente** abaixo de 30% de vida —
em toda batalha, **sem toast, som, pill nem instante**. Mudava a conta de dano
que o jogador estava fazendo e nada aparecia: o caso mais puro da queixa do dono.

Agora a **virada** do limiar (não cada dano: `wasEnraged` guarda a transição):
1. vira status REAL `enraged` em `enemy.statusEffects` — o `EnemyHud` já estava
   preparado e suprime a pill derivada de `attackPattern == "aggressive"`;
2. levanta `enemy._pendingEnrage`, consumido por
   `Game:announceEnrageIfPending(sink)` → beat `enemy.enraged` / `STATUS` 0,55
   com rugido, aura, shake e nome flutuante.

**O nome é `enraged`, NUNCA `fury`** — `fury` já é o anti-stall do turno 8+
(`Game:enemyTurn`), outra mecânica com pill e tooltip próprios.

**Invariante preservada** (CLAUDE.md §6): `nextIntentDamage` continua congelado
no anúncio, então o golpe já telegrafado **não** fica mais forte — "ele
enfureceu" e "ele bate mais forte" são dois momentos separados, a favor da
leitura. O recálculo `damage = floor(baseDamage * 1.5)` continua rodando a cada
dano de propósito (a Fúria cresce `baseDamage`; mexer nisso seria rebalancear).

Onde é consumido: no caminho de ataque da carta (primeiro passo do sink, logo
depois do dano), nos 6 sites de dano do `EffectSystem` (magia, AoE, evoke de
raio/sombra/fogo, pulso de orbe), no beat do reflexo de espinhos, e num
**checkpoint** (`enemy.enrage_check`, `MICRO`) no começo da cadeia do turno do
inimigo — rede de segurança pra que nenhuma fonte fique muda.

**Fica de fora:** veneno. `Enemy:onTurnEnd` mexe em `health` na aritmética crua,
sem passar por `takeDamage` — um inimigo levado abaixo dos 30% só por DoT não
enfurece. É comportamento pré-existente; corrigir muda balanceamento.

### Passo CONDICIONAL (`extendCurrent` + `mark`)
Evento raro dentro de um beat barato: o checkpoint custa `MICRO` quando não há
nada a anunciar e, quando há, `CombatBeats.extendCurrent("STATUS")` **estende o
beat que está rodando** e `CombatBeats.mark(label)` registra o acontecimento no
trace sem criar uma entrada na fila. Assim o caso comum não paga ar morto e o
caso raro ganha o instante dele.

## ORBES: o beat existia, a MUTAÇÃO não morava dentro dele

Segunda rodada do mesmo pedido (Set/2026), o dono jogando de mago: *"melhorar o
comportamento de canalização... Chuva de Meteoros canaliza muitas ao mesmo
tempo, fica confuso se está dando dano ou se canalizando uma nova"*.

Os beats `orb.channel` / `orb.evoke` **já existiam** — e mesmo assim o defeito
continuava, porque só o SOM e a animação estavam na fila. `player:addOrb` e
`popOldestOrb` rodavam na **COLETA**, dentro do beat de impacto da carta. Então
a fileira ia de 0 a 3 orbes no mesmo frame do número de dano, e os beats
seguintes tocavam efeito em cima de orbes que já estavam lá há um segundo.

**A regra que isso destila:** um beat só vale se o ESTADO mudar dentro dele.
Beat que só carrega feedback de uma mutação já ocorrida é legenda, não
acontecimento.

Hoje (`EffectSystem:_stepChannelOrb` / `:_stepEvokeOrb`, fonte única também do
`channel_per_turn` do coringa Eletrodinâmica):

```
card.impact.attack > orb.make_room > orb.channel > orb.make_room > orb.channel
  > ... > card.dissolve
```

- **`orb.make_room`** (`MICRO` 0,10) é o passo CONDICIONAL: barato quando há
  vaga; quando a fileira está CHEIA ele expulsa o mais antigo, chama
  `CombatBeats.mark("orb.overflow")` + `extendCurrent("ORB")` e vira o terceiro
  acontecimento. Antes o orbe sumia sem instante e sem motivo visível.
- **`orb.channel`** (`ORB` 0,40) é onde `addOrb` roda. Um orbe por beat.

### A linguagem: DIREÇÃO, COR e ALTURA

Dano vai PARA o inimigo; canalizar vem PARA a fileira; evocar SAI dela. Os três
sentidos agora são desenhados (`src/ui/OrbRow.lua`, `_drawFx`):

| momento | gesto | som |
|---|---|---|
| canalizar | cometa da cor do elemento ENTRA do centro do palco até o slot; o slot fica vazio enquanto o orbe voa e só então nasce (pop-in) | `orbChannel`, pitch **subindo com o slot** (1→3): a fileira vira teclado e os orbes são contáveis, como o cash out |
| evocar | fantasma do orbe SAI do slot rumo ao combate, com o ícone do elemento e o rótulo `orb.evoked` | `orbEvoke` grave, **descendo** em lote |
| expulsar (overflow) | mesmo fantasma, âmbar, rótulo `orb.expelled` | `orbEvoke` no pitch mais grave de todos (0,72) |
| pulsar | flash + número saindo DO orbe | `orbEvoke` agudo (meio-evoke), subindo com o slot |

### O pulso também CHEGA em algum lugar

Segunda parte do mesmo pedido: *"os orbes, quando dão dano ao final do turno,
eles poderiam refletir algo no inimigo visualmente também, cada um de uma forma
sabe, visual e som"*. O pulso já SAÍA do orbe (flash + número no slot); faltava
a outra ponta.

A metade perigosa é a que o pedido não cobre: **gelo dá Bloqueio e sagrado
cura**. Estourar esses dois no inimigo ensinaria que defender fere — o mesmo
defeito dos espinhos ([[defect_doctrine]] §3). Então cada pulso aterrissa onde o
efeito dele realmente acontece (`PULSE_LANDING`, em `EffectSystem`):

| orbe | pulso faz | marca cai em | som |
|---|---|---|---|
| raio | dano | **inimigo** (+ `triggerHurt`) | `impactLightning` |
| fogo | dano | **inimigo** (+ `triggerHurt`) | `impactFire` |
| gelo | Bloqueio | **painel do herói** | `impactIce` |
| sagrado | cura | **painel do herói** | `impactHoly` |
| sombra | engorda o próprio orbe | **o orbe** (`OrbRow.burstAtSlot`) | `impactDark` |

A identidade não é inventada: vem do `CardFeel` (som + paleta + FÍSICA — fogo
sobe, gelo cai, raio é rápido e sem gravidade). O `k` foi **medido** na captura
`lovec . preview_battle_hud pulse`: abaixo de ~0,9 gelo e sombra sumiam contra o
HUD sépia; todos seguem abaixo do impacto de carta (1,1–1,2), que é o que mantém
"pulso < golpe".

**Não há segundo número no alvo.** O valor já sai do orbe; repeti-lo a 0,0s de
distância vira ruído. No alvo cai o IMPACTO (burst + reação), não a conta.

**Removido:** o `evokeFlash` no slot. Quando um orbe sai a fila ANDA, então o
flash acendia o orbe **seguinte** — o `notifyEvoke(1, ...)` de índice fixo era
correto sobre a POSIÇÃO e mentiroso sobre o ORBE. Quem conta a saída é o
fantasma, desenhado de onde o orbe saiu.

Magia e evoke que causam dano ganharam **número no inimigo + `triggerHurt`**
(`showEnemyDamage`): antes a mesma explosão genérica servia para "levou dano" e
para "ganhou um orbe".

Trava: `tools/test_beats.lua` blocos 4b–4e. Verificado revertendo — a mutação de
volta na coleta derruba **4** asserções (a fileira pula de 0 para 3 e `orbsAtImpact`
vem 3); o evoke eager derruba **1**; o overflow sem instante próprio, **2**.

## Efeito que muda um número TEM que ticar

`heal_multiplier` era o último contínuo mudo (Abraço Sombrio tinha
`defense_bonus` ticando e a cura ampliada invisível; Cálice do Sábio era um
coringa inteiramente invisível). `applyHealMultiplier(game, amount, procSink)`
agora empurra proc. Os 14 tipos contínuos de coringa do catálogo ticam.

**Ainda mudo (declarado, não resolvido):** `multi_hit`, `strength_scaling` e
`dexterity_scaling` mudam o valor da CARTA e não têm slot de coringa pra ticar —
precisam de um rótulo ancorado na carta (território de `src/ui`).

## Trava

`tools/test_beats.lua` (em `test_all`). Grava o TRACE de labels executados
(`CombatBeats.startTrace()`) e afere a **ordem causal**, não só "não crashou".
Cada bloco foi verificado revertendo a correção: espinhos na jogada (5 falhas),
heal mudo (2), orbes agregados (2), beat sem bloqueio (3), ordem invertida (1),
enfurecimento mudo (6).

Ver também: [`memory/eventmanager_queues.md`](eventmanager_queues.md),
[`memory/combat_animation.md`](combat_animation.md),
[`memory/card_feel.md`](card_feel.md),
[`docs/auditoria-feedback-combate.md`](../docs/auditoria-feedback-combate.md).
