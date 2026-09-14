# Auditoria de feedback de combate — o que acontece sem o jogador perceber

Set/2026. Levantamento **completo e medido** do catálogo (128 cartas, 35 tipos de
efeito em uso) cruzando *o que cada efeito faz* com *o que o jogador ouve/vê no
instante em que acontece*.

Não é impressão: a lista sai de `tools/audit_feedback.lua`, que varre o código
que processa cada efeito e procura chamadas de feedback reais. Ver
[Como conferir](#como-conferir) no fim.

> **Estado da árvore no momento da medição (13/09/2026).** Outros dois agentes
> estavam corrigindo em paralelo. Duas das lacunas abaixo **já mudaram de estado
> durante esta auditoria** e estão marcadas como tal na seção 4 — inclusive uma
> que ficou **meio ligada** e hoje não causa dano nenhum. Rode a ferramenta antes
> de usar a tabela como verdade atual.

**Convenção da tabela:** `toast` (feed lateral) conta **separado** de feedback
percebido. O feed é histórico, não evento — foi exatamente a queixa do dono.

---

## 1. As 5 lacunas mais graves, em ordem

| # | Lacuna | Cartas afetadas | Por que é a mais confusa |
|---|---|---|---|
| 1 | **Espinhos disparam na hora errada** — `on_defend_damage` roda quando você JOGA a defesa, não quando o inimigo ataca ⚠ *correção meio ligada: hoje causa **0** dano, ver [4.2](#42-warrior_flame_barrier-e-os-demais-espinhos-disparam-ao-jogar--confirmado)* | **7** | O feedback existe e está *certo demais*: som metálico + estouro no inimigo + "Reflete 7". Ensina causalidade errada. O jogador conclui "escudo machuca" e nunca entende por que o reflexo some no turno em que ele não joga defesa |
| 2 | **Tudo de uma carta resolve num único frame** | **78 de 128** | `processAdditionalEffects` roda todos os efeitos secundários em UM frame, junto do número de dano, do burst e dos procs de joker. Chuva de Meteoros = 4 coisas simultâneas. É a queixa literal do dono |
| 3 | **Números que mudam sem origem visível** | **8** (+2 já curados) | `strength_scaling`/`dexterity_scaling` (4) e `multi_hit` (4): o valor final muda e nada tica — o jogador vê 24 onde a carta diz 12 e não sabe quem fez. `heal_multiplier` (2) era o terceiro caso e **já foi corrigido em voo** |
| 4 | **Orbes: canalizar/pulsar/evocar sem instante próprio** | **29** | Canaliza no mesmo frame do impacto; pulsa colado no fim do turno sem respiro; `evoke_all_orbs` estoura N orbes no mesmo frame com **um** som e N "EVOCADO!" **todos no slot 1** |
| 5 | **Recursos do jogador mudando só no feed** | **21** | Mana (7), HP próprio (6), Bloqueio (2), mão descartada (6). Nenhum número no painel, nenhum som, nenhum brilho — só uma linha de texto que passa |

---

## 2. Tabela por tipo de efeito

Estado atual, medido. `USOS` = quantas cartas/jokers declaram o tipo.

| Tipo | Usos | Feedback percebido hoje | O que falta |
|---|---|---|---|
| `damage_multiplier` | 2 | proc (hop + "×1.5" + som do joker) | — |
| `defense_multiplier` | 1 | proc | — |
| `damage_bonus` | 8 | proc ("+3") | — |
| `defense_bonus` | 4 | proc ("+3") | — |
| `heal_multiplier` | **2** | proc (corrigido em voo; era **nada — nem toast**) | conferir se tica nos 6 caminhos de cura, não só no `instant_heal` |
| `on_attack_debuff` | 2 | som + burst no inimigo + proc | — |
| `on_defend_damage` | **7** | proc + toast (era som+burst+proc antes da edição em voo) | **momento**: disparava ao jogar a defesa (`Game.lua:903`). Correção **meio ligada** — ver aviso em [4.2](#42-warrior_flame_barrier-e-os-demais-espinhos-disparam-ao-jogar--confirmado). Falta ainda: pill de `thorn` no jogador enquanto o escudo está armado |
| `on_attack_heal` | 3 | som + proc (só se a fonte for joker) + toast | burst/número de cura; em **carta** (`rogue_leech_blade`) não tica nada visual |
| `on_turn_start_draw` | 5 | proc + som/anim das cartas compradas | — |
| `regen_per_turn` | 2 | proc + toast | som, brilho verde e número no painel do jogador |
| `damage_per_turn` | 2 | proc no joker + toast | **o HP do jogador cai sem número, som ou shake** |
| `strength_per_turn` | 1 | proc + toast | burst de buff no jogador (o `gain_strength` de carta tem) |
| `channel_per_turn` | 1 | som + orbe + proc | — |
| `retain_armor` | 1 | proc ("Escudo mantido") | — |
| `instant_heal` | 7 | som `healShimmer` + burst no painel + toast | número flutuante do HP ganho |
| `self_damage` | **2** | **só toast** | número no painel, som, shake — é custo em sangue e passa batido |
| `add_armor` | **2** | **só toast** | não usa o caminho visual da carta de defesa (número + burst) |
| `restore_mana` | **6** | **só toast** | o ManaOrb não reage ao ganho |
| `increase_max_mana` | **1** | **só toast** | idem |
| `draw_cards` | 17 | som `cardDraw` + materialize por carta | acontece no mesmo instante do impacto |
| `discard_cards` | **6** | **só toast** | a carta some da mão sem animação nenhuma |
| `apply_debuff` | 16 | som + burst da cor do status no inimigo | a pill não pisca ao nascer |
| `apply_buff` | **3** | **só toast** | Foco do mago não soa nem brilha; a pill aparece sozinha |
| `gain_strength` | 8 | som + burst + pill | — |
| `gain_dexterity` | 7 | som + burst + pill | — |
| `channel_orb` | 25 | som + pop-in no slot + toast | instante próprio (colado no impacto da carta) |
| `evoke_orb` | 2 | som + flash no slot + burst do elemento | instante próprio |
| `evoke_all_orbs` | **2** | 1 som para o lote inteiro | N toasts + N bursts + N "EVOCADO!" no **mesmo frame** e **sempre no slot 1** |
| `aoe_magic_damage` | 1 | burst "magic" no inimigo + toast | **número de dano, shake e `triggerHurt`** — dano mágico não sacode nada (`mage_blizzard`, 14 de dano) |
| `magic_damage` | 0 no catálogo (só via `mystery`) | burst "magic" + toast | idem acima |
| `multi_hit` | **4** | **nada** | vira 1 número; a descrição promete "2 vezes" |
| `strength_scaling` | **3** | **nada** | o dobro da Força some dentro do número final |
| `dexterity_scaling` | **1** | **nada** | idem, Destreza |
| `damage_bonus_self` | 0 | (sem uso no catálogo) | — |
| `mystery` | 1 | toast + o feedback do sub-efeito sorteado | não mostra **o que** saiu |
| `exhaust` | 11 | som `cardExhaust` + toast (no `Game`, fora do branch) | a carta dissolve igual a qualquer outra — nada diz "essa não volta" |
| `innate` / `retain` | 3 / 1 | nada (flags) | nenhum marcador na mão |

---

## 3. Lista nominal por lacuna

### 3.1 `on_defend_damage` no momento errado (7)

**Cartas** (reflexo por carta jogada):
- `warrior_shield_slam` — Escudo de Espinhos (reflete 3)
- `warrior_flame_barrier` — Barreira de Fogo (reflete 7)
- `rogue_thorn_cloak` — Manto de Espinhos (reflete 3)

**Jokers** (1×/turno por joker, regra P2.3 — e o turno "conta" no momento em que você joga uma defesa):
- `joker_002` — Guardião do Escudo (4)
- `warrior_juggernaut` — Juggernaut (6)
- `warrior_eternal_bulwark` — Baluarte Eterno (8)
- `rogue_caltrops` — Estrepes (3)

### 3.2 `heal_multiplier` silencioso (2)
- `warrior_dark_embrace` — Abraço Sombrio
- `mage_sacred_chalice` — Cálice do Sábio

### 3.3 Número muda sem origem (8)

`multi_hit`: `mage_twin_bolts`, `rogue_shooting_star`, `rogue_twin_fangs`, `warrior_twin_strike`
`strength_scaling`: `warrior_colossus_blow`, `warrior_heavy_blade`, `warrior_twin_strike`
`dexterity_scaling`: `mage_force_field`

### 3.4 Recursos do jogador em silêncio

`restore_mana` (6): `mage_fission`, `rogue_adrenaline`, `rogue_blue_elixir`, `rogue_bullet_time`, `rogue_doppelganger`, `warrior_adrenaline_rush`
`increase_max_mana` (1): `effect_mana_crystal`
`self_damage` (2): `warrior_adrenaline_rush`, `warrior_bloodletting`
`add_armor` (2): `warrior_iron_wave`, `warrior_second_wind`
`discard_cards` (6): `mage_torn_pages`, `rogue_acrobatics`, `rogue_calculated_gamble`, `rogue_survivor`, `warrior_power_through`, `warrior_second_wind`
`apply_buff` (3): `mage_arcane_focus`, `mage_consume`, `mage_primordial_storm`

### 3.5 Exaurir sem marca visual (11)
`effect_healing_potion`, `mage_arcane_sight`, `rogue_adrenaline`, `rogue_backstab`, `rogue_blue_elixir`, `rogue_bullet_time`, `rogue_catalyst`, `rogue_corpse_explosion`, `warrior_feed`, `warrior_ghostly_armor`, `warrior_immolate`

### 3.6 Simultaneidade — cartas que resolvem mais coisa de uma vez

78 de 128 cartas resolvem 2+ coisas no mesmo frame. As piores:

| Efeitos no mesmo instante | Carta |
|---|---|
| 4 | `mage_meteor_strike` — Chuva de Meteoros (dano + 3 orbes de Fogo) |
| 4 | `mage_primordial_storm` — Tempestade Primordial (3 orbes + Foco) |
| 3 | `mage_rainbow` — Arco-íris (3 orbes) |
| 3 | `mage_twin_bolts` — Raios Gêmeos (multi_hit + orbe + dano) |
| 3 | `rogue_bullet_time` — Tempo-bala (draw 3 + mana + Destreza) |
| 3 | `rogue_twin_fangs` — Presas Gêmeas |
| 3 | `warrior_adrenaline_rush` — Adrenalina (HP + mana + draw) |
| 3 | `warrior_bloodletting` — Sangria (HP + Força + draw) |
| 3 | `warrior_twin_strike` — Golpe Duplo |

---

## 4. Os três casos que o dono citou — veredito

### 4.1 `warrior_dark_embrace`: `defense_bonus` tica, `heal_multiplier` não — **CONFIRMADO**

O joker tem dois efeitos e só um existe para os olhos:

- `defense_bonus` passa por `EffectSystem:applyJokerEffects`, que empurra um proc
  (`src/systems/EffectSystem.lua:132-147`) → `JokerProcFx.tick` faz o slot pular,
  solta "+3" e toca a assinatura do joker.
- `heal_multiplier` é processado em `EffectSystem:applyHealMultiplier`
  (`src/systems/EffectSystem.lua:565-577`): multiplica o valor e retorna. **Zero
  chamadas de feedback no caminho inteiro** — nem `addMessage`. A cura sai 50%
  maior e o joker fica mudo.

**Há outro igual:** `mage_sacred_chalice` (Cálice do Sábio), cujo efeito único é
`heal_multiplier`. É um joker **inteiramente invisível**: ele nunca tica, em
nenhuma situação.

Vale notar o agravante: `applyHealMultiplier` é chamado em **6 caminhos**
(`instant_heal`, `on_attack_heal`, `regen_per_turn`, pulso de orbe holy, evoke
holy e o combo `lifesteal_burst`). Nenhum deles distinguia cura amplificada de
cura normal.

> **Já corrigido em voo** (agente `ritmo-combate`, durante esta auditoria):
> `EffectSystem:applyHealMultiplier` ganhou um `procSink` e empurra
> `pushJokerProc` com rótulo `×1.5 PV` quando o valor realmente muda
> (`src/systems/EffectSystem.lua:591-608`). A ferramenta já mede
> `heal_multiplier → proc`. **Conferir:** o Cálice do Sábio precisa ticar nos 6
> caminhos de cura, não só no `instant_heal`.

### 4.2 `warrior_flame_barrier` e os demais espinhos disparam ao JOGAR — **CONFIRMADO**

`Game:processCardInCombat`, ramo `card.type == "defense"`, chama
`applyTriggerEffects(self, "defend", ...)` em **`src/core/Game.lua:903`** — dentro
do impacto da carta. O gatilho `"defend"` **não existe em nenhum outro lugar**:

```
src/core/Game.lua:864  → applyTriggerEffects(self, "attack", ...)
src/core/Game.lua:903  → applyTriggerEffects(self, "defend", ...)
src/core/Game.lua:1253 → applyTriggerEffects(self, "turn_start", ...)
```

Não há hook algum em `Player:takeDamage` (`src/entities/Player.lua:38-44`) nem no
turno do inimigo. Ou seja: **o reflexo nunca acontece quando o inimigo ataca**.

Os 7 afetados estão em [3.1](#31-on_defend_damage-no-momento-errado-7). Repare que
o texto das cartas ("Reflete 7 de dano ao defender") é ambíguo o bastante para
sustentar a implementação antiga, mas a referência (Flame Barrier do StS) reflete
**ao ser atacado**, e é isso que o jogador espera. Se a correção mudar o momento,
os textos das 7 precisam mudar junto.

> ### ⚠ ATENÇÃO — correção MEIO LIGADA na árvore (13/09/2026)
>
> O agente `ritmo-combate` já reescreveu **metade** desta correção e ela está
> incompleta no working tree:
>
> - `src/systems/EffectSystem.lua:745-790` — o gatilho `"defend"` **não causa
>   mais dano**: ele agora ARMA o buff `thorn` no jogador (`addBuff("thorn", 1, v)`)
>   e emite o toast `messages.thorn_ready`.
> - `src/systems/EffectSystem.lua:661` — existe `EffectSystem:fireThornReflect(game)`,
>   que é quem causa o dano (com som `thornReflect`, burst, `ER.triggerHurt` e
>   número flutuante — feedback completo, e no momento certo).
> - **`fireThornReflect` não tem NENHUM chamador.** `grep -rn fireThornReflect src/`
>   só acha a definição e um comentário. `src/core/Game.lua` está intocado
>   (`git diff --stat src/core/Game.lua` vazio) — o `Game:_enemyStrikeChain` que o
>   comentário cita ainda não existe.
>
> **Consequência hoje:** as 7 cartas/jokers de espinhos causam **zero** dano de
> reflexo. É o que derruba 4 asserções em `test_effects_full` (`on_defend_damage
> reflete no alvo`, `trigger de sourceCard também dispara`, `thorn de joker 1x`,
> `thorn de carta por carta`). Não commitar assim.

### 4.3 Orbes do mago: canalizar / pulsar / evocar — **parcialmente cada um tem sinal, nenhum tem INSTANTE**

| Momento | Onde roda | Feedback | Problema |
|---|---|---|---|
| **Canalizar** | `processEffectCard` → chamado por `processAdditionalEffects` (`Game.lua:807-816`) no impacto da carta | toast + `orbChannel` + pop-in no slot (`OrbRow.notifyChannel`) | acontece no **mesmo frame** do número de dano, do burst no inimigo e dos procs de joker. Chuva de Meteoros canaliza 3 orbes nesse único frame |
| **Pulsar** | `EffectSystem:orbPassiveTick`, chamado **síncrono** em `Game:endTurn` (`Game.lua:992-994`) | flash no slot + número saindo do orbe + toast | **sem som**; todos os orbes pulsam no mesmo frame; e logo em seguida `turn = "enemy"` — o pulso é engolido pelo começo do turno do inimigo. Contraste: o DoT de veneno *ganhou* respiros de 0.45s/0.55s em `_finishEnemyTurn` (`Game.lua:1281-1286`), o pulso não |
| **Evocar** | `processEffectCard` (mesmo frame da carta) | `orbEvoke` + flash + burst do elemento no alvo + toast | `evoke_all_orbs` (`EffectSystem.lua:396-408`) esvazia a fila num `while`: N toasts + N bursts + N "EVOCADO!" no mesmo frame, e **um único som para o lote**. Pior: `notifyEvoke` é chamado com índice **fixo `1`** nos 4 pontos (`EffectSystem.lua:375, 391, 400, 664`) — o flash de saída sempre aparece no primeiro slot, mesmo quando o orbe evocado é outro |

Resumo: **canalizar e evocar não têm instante próprio** (vivem dentro do impacto
da carta); **pulsar tem instante mas não tem respiro nem som**.

---

## 5. Achados fora do catálogo (mesma família, encontrados no caminho)

Não são tipos de efeito, então não aparecem na tabela — mas são "coisas que
acontecem sem o jogador perceber" e valem para quem está corrigindo o ritmo.

| O quê | Onde | Estado |
|---|---|---|
| **Inimigo enfurece a 30% de HP**: `damage = baseDamage × 1.5`, permanente | `src/entities/Enemy.lua:101-105` | **totalmente silencioso** — sem toast, sem pill, sem som. O número do intent simplesmente sobe no próximo turno |
| `vulnerable` amplifica o dano recebido em 50% | `src/entities/Enemy.lua:94-96` | o número já sai maior, mas nada indica que foi o Vulnerável |
| `weak` reduz o golpe em 25% | `src/entities/Enemy.lua:148-150` | idem, na direção oposta |
| Bloqueio truncado no cap do ato | `src/core/Game.lua:885-891` | só toast (`armor_capped`) |
| Fúria anti-stall (turno 8+, +2 dano/turno) | `src/core/Game.lua:1051-1056` | toast + pill `fury` — **este está certo**, serve de modelo |
| Pulso de orbe mata o inimigo | `Game.lua:992` roda antes de `turn = "enemy"` | a morte por pulso passa batida no meio da transição de turno |

---

## 6. O que já está bom (para não quebrar ao corrigir)

Serve de referência de "como é um evento bem feito" neste projeto:

- **Procs de joker** (`JokerProcFx.tick`): pulinho + swell + popup do valor +
  som assinatura com pitch crescente, escalonados a 0.16s — é o padrão que os
  tipos mudos deveriam imitar.
- **DoT de veneno no fim do turno inimigo** (`Game:_finishEnemyTurn`): respiro
  0.45s → tica com som, bolhas e número → respiro 0.55s → turno do jogador.
- **Resolução sequencial das cartas** (`CombatSequence`, `resolveGap = 0.30`):
  carta 1 impacta, jokers dela ticam, respiro, carta 2. O que falta é que os
  **efeitos secundários de cada carta** respeitem a mesma lei — hoje eles caem
  todos no instante do impacto.
- **`gain_strength` / `gain_dexterity` / `apply_debuff`**: som + burst temático +
  pill. É o mínimo aceitável para um efeito de carta.

---

## 7. Como conferir

A ferramenta é `tools/audit_feedback.lua`. Ela **varre o código** que processa
cada efeito, procura chamadas de feedback (`Sfx.play`, `FloatingText`,
`CardFeel.burst`, `pushJokerProc`, `notifyOrbUI`, `addMessage`, `juice_up`,
`triggerShake`, `ER.trigger*`), segue um nível de delegação declarada
(ex.: `draw_cards` → `Game:drawCard`) e cruza com o catálogo instanciado.

```sh
# relatório completo (tabela + listas nominais + simultaneidade)
"/c/Program Files/LOVE/lovec.exe" . test_one audit_feedback

# ou dentro da suíte (grupo `valid`)
"/c/Program Files/LOVE/lovec.exe" . test_all
```

### Por que ela passa mesmo com as lacunas abertas

De propósito. As lacunas acima são **conhecidas e em correção** — travar a suíte
por elas deixaria o `test_all` vermelho por dias. O que a ferramenta trava é uma
**catraca**: a tabela `BASELINE_SILENT` lista os tipos mudos de hoje, e o teste
falha se aparecer um tipo mudo **fora** dessa lista — ou seja, se alguém
introduzir um efeito novo sem feedback, ou remover o feedback de um que tinha.

**Ao corrigir uma lacuna, tire o tipo de `BASELINE_SILENT` no mesmo commit.** Se
esquecer, a ferramenta imprime um `[INFO] tipos CURADOS desde a linha de base`
cobrando.

### Limitações declaradas

- Varredura estática por proximidade textual dentro do branch `type == "..."`.
- Função cujo corpo não é um if-chain por tipo entra em `FUNCTION_ATTRIBUTION`
  (hoje só `applyJokerEffects`).
- Feedback que mora fora de qualquer branch por tipo (caso do `exhaust`, cujo
  som está em `if card.exhaust` no `Game`) aparece como mudo e está anotado na
  linha de base.
- A ferramenta mede **existência** de feedback, não **momento**. O problema de
  ritmo (lacunas 1, 2 e 4) foi levantado por leitura de código — as referências
  de arquivo:linha estão na seção 4.
