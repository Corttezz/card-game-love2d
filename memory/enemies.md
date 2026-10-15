---
name: Inimigos — roster por ato, kit de golpes, chefes com mecânica
description: Out/2026. Cada criatura tem KIT próprio (src/data/enemies.lua): golpes nomeados, multi-golpe, perfurante, debuffs NO jogador (Fraco/Frágil/Vulnerável/Veneno/Queimadura), carga, invocação, fases. Roster por ato SÓ do bioma (HOME_BIOME), sorteado no stream "enemy" sem repetir. Sem espólio extra de coringa depois do chefe (decisão do dono).
type: project
---

# Inimigos (Out/2026)

**Auditoria de conteúdo que originou:** (1) todo inimigo jogava igual — UMA
tabela de intents (atacar / forte ×1.6 / defender / +2) dividida pelas 21
criaturas; identidade só no sprite; intents em `math.random` e embaralhamento
em `love.math.random` (a seed não reproduzia o combate). (2) um comum por ato
pra toda batalha, sprite do elite servia de mini-chefe (uma run enfrentou o
Ceifador 5×). (3) chefe = saco de vida (`isBoss` só mudava recompensa e
tamanho). (4) zero tensão: 0–1,6 de dano sofrido por turno. (5) sem escolha de
coringa raro depois do chefe.

## Onde mora

| peça | arquivo |
|---|---|
| dados (roster + kits) | `src/data/enemies.lua` — DADO PURO, cabeçalho documenta todo campo |
| sorteio do roster | `src/systems/EnemyRoster.lua` (`assignNodes`, `resolveNode`, `remember`, `spawn`) |
| rolagem + intent congelado | `src/entities/Enemy.lua` (`setKit`, `rollIntent(player)`, `getIntent`, `intentHitDamage`, `getIncomingDamage`, `forceIntent`, `_checkPhase`) |
| debuffs no jogador | `src/entities/Player.lua` (`addDebuff`, `decayDebuffs`, `tickDebuffDots`, `applyWeakToAttack`, `applyFrailToBlock`, `takeDamage(dmg, pierce)`) |
| execução (beats) | `Game:enemyTurn` + `_pushEnemyTurnTail` + `_announcePhaseIfPending` |
| HUD | `EnemyHud.intentSpec` (fonte única do número, ícones extras e tooltip) |
| textos | `src/i18n/locales/enemy_kit/<loc>.lua`, plugado no locale como `enemy_kit = require(...)` |
| trava | `tools/test_enemies.lua` |

## Regras que não podem quebrar

- **Intent CONGELADO** (CLAUDE.md §6) vale para TODO número do golpe: dano por
  golpe, nº de golpes (inclusive os da revoada), bloqueio, cura, força.
  Vulnerável do jogador só amplia se já estava ativo NO ANÚNCIO (`intent.vuln`).
  A execução lê `Enemy:intentHitDamage(player)` — nunca recalcula do `damage`.
- **A execução lê os CAMPOS do intent, não o `kind`.** `kind` é categoria de
  leitura (ícone). Ordem dos beats: bloqueio > golpe(s) (um `pushUntil` por
  golpe) > espinhos (1×/turno) > debuffs (um beat STATUS por status) > força >
  cura > invocação > carga.
- **Debuff do jogador decai no FIM do turno do inimigo** e pula o turno em que
  foi aplicado (`fresh`, padrão StS justApplied): "Fraco 2" = 2 turnos do
  jogador. Veneno/queimadura no jogador ticam no `player.dot` (upkeep, antes da
  compra), ignoram Bloqueio, contam em `recordDamageTaken`.
- **Fraco/Frágil entram por ÚLTIMO** no pipeline da carta (depois de joker e
  combo), em `Game:_resolveCardInCombat`. O piloto (`balance_ai.cardValue`)
  espelha a mesma conta.
- **Roster**: o inimigo é decidido quando o NÓ nasce (`node.enemyId`, stream
  "enemy"); batalha, prévia do mapa e Continuar leem o mesmo. Nunca repete o
  último enfrentado (`run.recentEnemies`). Mini-chefe ≠ elite do mesmo ato
  (trava em `test_enemies`).
- **Fallback silencioso proibido**: kit desconhecido e modo de vitrine
  desconhecido AVISAM no console e caem no legado (`generic` / `shop`).
- `Enemy:new(hp, dmg)` sem kit = kit `generic` (os 4 intents antigos) — testes
  antigos que escrevem `nextIntent`/`nextIntentDamage` direto continuam valendo
  (`getIntent` sintetiza o golpe legado quando os dois campos foram mexidos).

## Chefes (mecânica-assinatura)

| ato | chefe | regra |
|---|---|---|
| 1 | carrion_king | abre e repete (a cada 4) o **Chamado da Revoada**: +2 `swarm`; a **Revoada** bate 2 + corvos vezes e deixa Fraco |
| 2 | tower_lich | **Runas do Ritual** (15/Out: +1/turno, 4 = Cataclismo Rúnico; 15% da vida num turno quebra runa) + **Escudo de Gelo** a cada 3º turno; drena (Frágil + cura) |
| 3 | abyss_tyrant | **Correntes** (15/Out: rompem a 75/50/25%, cambaleia = golpe anunciado pela metade, +12% de dano) + **Reunir Chamas** (carga, a cada 4) força **Fogo Infernal** ×1,7 + Queimadura 2 |
| 4 | winter_monarch | **Geada** no jogador (15/Out: 4+ na compra congela as 2 cartas mais caras; ataque derrete) + **Lâmina do Inverno** perfura; **Inverno Eterno** a cada 3 (Frágil + Fraco) |
| 5 | rot_colossus | **Raízes** (15/Out: 2 a 4, 0,75%/raiz de cura no beat `enemy.regen`; golpe único de 5% corta; substitui o 1,5% fixo) + **Nuvem Pestilenta** envenena o jogador |
| 6 | eclipse_queen | **Ciclo da Lua** (15/Out: Cheia ×1,5, Nova = Vulnerável) + abaixo de 50% vira o **ECLIPSE** (beat `enemy.phase`, kit novo, abre com Eclipse Total) |

Detalhes, números e visual de cada mecânica: [[boss_mechanics]].

## Sem espólio extra no chefe (decisão do dono, Out/2026)

Existiu por algumas horas um "1 de 3 coringas raros" depois da carta do chefe.
O dono mandou tirar: *"escolher coringa depois do chefe é forte demais; o
objetivo é que montar o deck perfeito seja difícil"*. Chefe paga o normal
(ouro + recompensa de carta). Não reintroduzir.

## Roster = só o bioma do ato

Regra do dono: nenhum monstro fora do bioma em que aparece (o roster interino
emprestava sprites entre atos e isso foi notado jogando). Cada ato: os 3
originais (comum/elite/chefe) + 4 da leva nova da frente `inimigos-arte`
(2 comuns, 1 elite, 1 mini-chefe próprio). `Enemies.HOME_BIOME` declara o
bioma de cada criatura À PARTE do `ROSTER`; `test_enemies` exige que toda
entrada do roster seja do bioma do ato, e que no endless o bioma do inimigo
seja o mesmo que a cena desenha (fórmula `4 + floor((andar-25)/8)` do
GameplayScene, embrulhada em 6). Criatura nova = sprite + `HOME_BIOME` + kit
+ nome dos golpes nos 5 `enemy_kit` locales.

## Ferramentas

- `love . test_one test_enemies` — trava completa.
- `ENEMY_SCENE_VIRTUAL=1920x1080 ENEMY_SCENE_ID=<id> ENEMY_SCENE_MOVE=<golpe>
  ENEMY_SCENE_DEBUFFS=weak,poison ENEMY_SCENE_HOVER=1 love . screenshot_enemy_scene <ato>_<nó>`
  — captura o intent novo (e o tooltip do golpe).
- `love . balance_sim N <classe> <seed>` — o relatório ganhou a tabela
  **Combate por ato** (turnos/luta, dano sofrido/turno, turnos/chefe).

Ver também: [[combat_beats]] · [[balance_curves]] · [[rng_and_offers]] ·
[[enemy_pose_and_scene_anchor]].

## Bateria do roster novo (Out/2026, v7 — só medição, sem ajuste)

`balance_sim 30 <classe> 720000`, um processo por classe, piloto v6, roster só
do bioma (24 criaturas novas), sem coringa extra pós-chefe, Combo v3 já na
árvore (cortou o dano de leva grande — parte da queda vem daí).

| classe | vitória | mortes por ato |
|---|---|---|
| guerreiro | 13/30 (43%) | A3 4 · A4 2 · A5 5 · A6 6 |
| mago | 4/30 (13%) | A2 1 · A3 8 · A4 7 · A5 5 · A6 5 |
| ladino | 5/30 (17%) | A2 1 · A3 8 · A4 4 · A5 11 · A6 1 |

Turnos por luta / dano sofrido por turno / turnos por chefe (A1 → A6):
- guerreiro: 2,9 · 4,6 · 5,3 · 6,2 · 7,2 · 7,7 / 0,3 · 0,5 · 1,5 · 1,1 · 1,5 · 1,8 / 5,2 · 6,8 · 6,9 · 7,8 · 8,6 · 8,5
- mago: 2,5 · 4,6 · 6,4 · 8,0 · 12,4 · 14,3 / 0,1 · 0,6 · 1,6 · 1,4 · 0,8 · 1,1 / 4,3 · 6,9 · 9,3 · 10,8 · 18,3 · 16,0
- ladino: 2,5 · 4,8 · 5,6 · 7,3 · 7,6 · 8,4 / 0,1 · 0,8 · 1,6 · 1,3 · 1,8 · 1,9 / 4,4 · 7,3 · 7,5 · 9,6 · 8,6 · 10,8

Onde concentra: chefe do A5 (Colosso: 8 das 25 mortes do ladino, 5 do
guerreiro), chefe do A3 (Tirano: 6 do mago, 5 do ladino), mini-chefe do A6
(Anjo Caído: 5 do guerreiro), batalha comum do A4 (5 do mago). Mago no A5-A6
luta 12-18 turnos (dano baixo contra vida de chefe). Candidatos a alavanca,
NÃO aplicados: Colosso regen 2%→1,5%; Anjo Caído (lâmina 1,6, julgamento
perfurante 0,9); dano do mago no fim do jogo (frente de classe).

### Ajuste pós-v7 (Out/2026, pedido do lead — sem bateria cheia, a combinada é da frente combate-clareza)
- Colosso (A5): regen 2% → 1,5%/turno (8 das 25 mortes do ladino).
- Anjo Caído (mini A6): Lâmina Caída 1,6 → 1,35, Julgamento perfurante 0,9 → 0,7,
  Asas Profanas força 0,25 → 0,2 (5 mortes do guerreiro).
- Tirano (A3): carga a cada 4 turnos (era 3), Fogo Infernal 2,0 → 1,7 e
  queimadura 3 → 2. Continua o maior golpe da luta e telegrafado um turno
  inteiro; classes de defesa fraca (mago/ladino) morriam no 2º ciclo.
- DoT NO INIMIGO (veneno/queimadura) passou a IGNORAR a armadura
  (`Enemy:_applyDot`, padrão StS, pedido da frente de classe): o tick cai logo
  depois de o inimigo defender, e a armadura engolia o veneno do ladino.
  Mesma regra do DoT no jogador. Piloto (balance_ai/autoplay) atualizado.

## Força global do inimigo (Out/2026, combos simples)

`Config.Game.ENEMY_POWER = { damage = 0.75, health = 0.8 }` +
`ENEMY_POWER_BY_ACT = { [3] = { damage = 0.9, health = 0.9 } }` (Stage 2,
Out/2026 — eram 0,8/0,85 sem curva por ato), aplicados em
`ActSystem.getEnemyStats` (compõem e arredondam UMA vez; a run inteira, endless
herda o ato 6). O ato 3 ganhou o ×0,9 porque era o degrau mais duro da run:
vida base 150+15f (×2 sobre o fim do A2) com elite ×1,7 → 280 de vida no 1º
andar do ato, mais que o chefe do A2; nas baterias dos pilotos rápidos as
elites do A3 (obsidian_sentinel, pit_brute) + abyss_tyrant + abyss_watcher
eram 47+42+31 das 270 mortes. Com os números novos o expert_full fica em
57/53/53% e morre no A5 (Colosso 18, Mãe dos Esporos 7 de 41 mortes) — ver
[[balance_curves]]. Origem do knob global: a troca dos
13 combos por tag (que davam ~40% do dano e ~50% do Bloqueio das cartas) por
Saraivada/Muralha/Par derrubou o piloto (guerreiro 55% -> 0-5%); compensar só no
jogador não voltou, escalar o inimigo voltou. Os testes de curva (test_progression,
smoke_acts) medem a curva CRUA com o knob desligado e testam o knob à parte.
Detalhes: memory/combo_rules.md e memory/balance_curves.md.
