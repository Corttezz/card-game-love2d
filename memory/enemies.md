---
name: Inimigos — roster por ato, kit de golpes, chefes com mecânica
description: Out/2026. Cada criatura tem KIT próprio (src/data/enemies.lua): golpes nomeados, multi-golpe, perfurante, debuffs NO jogador (Fraco/Frágil/Vulnerável/Veneno/Queimadura), carga, invocação, fases. Roster por ato sorteado no stream "enemy" sem repetir; espólio de coringa raro depois do chefe.
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
| espólio do chefe | `ShopSystem` modo `boss_relic` + `CardRewardScreen` (`bossRelic`, `run.bossRelicPending`) |
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
| 2 | tower_lich | **Escudo de Gelo** a cada 3º turno (bloqueio grande + Frágil); drena (Frágil + cura) |
| 3 | abyss_tyrant | **Reunir Chamas** (carga, a cada 3) força **Fogo Infernal** ×2,4 + Queimadura no turno seguinte |
| 4 | winter_monarch | **Lâmina do Inverno** perfura o Bloqueio; **Inverno Eterno** a cada 3 (Frágil + Fraco) |
| 5 | rot_colossus | Regeneração passiva 2%/turno (`regen`, beat `enemy.regen`); **Nuvem Pestilenta** envenena o jogador |
| 6 | eclipse_queen | abaixo de 50% vira o **ECLIPSE** (beat `enemy.phase`, kit novo, dano ×1,3, abre com Eclipse Total) |

## Espólio do chefe

Fechar a recompensa de carta do CHEFE DO ATO (não o mini-chefe) reabre a mesma
tela como espólio: 1 de 3 coringas raros/lendários da classe ou neutros, que a
run ainda não possui, grátis, pular permitido. A marca `run.bossRelicPending`
viaja no save: Continuar no meio do espólio volta nele (a chave da vitrine no
save é por modo — `boss_relic` — então a carta já escolhida nunca re-sorteia).

## Sprites emprestados (interino)

Até a frente `inimigos-arte` entregar arte nova, cada ato completa o pool com
sprites de outros atos onde o tema casa (ver `ROSTER`). Trocar = editar o
`ROSTER` + escrever o kit do id novo (o teste exige kit, nome nos 5 idiomas e
pasta do sprite).

## Ferramentas

- `love . test_one test_enemies` — trava completa.
- `ENEMY_SCENE_VIRTUAL=1920x1080 ENEMY_SCENE_ID=<id> ENEMY_SCENE_MOVE=<golpe>
  ENEMY_SCENE_DEBUFFS=weak,poison ENEMY_SCENE_HOVER=1 love . screenshot_enemy_scene <ato>_<nó>`
  — captura o intent novo (e o tooltip do golpe).
- `love . balance_sim N <classe> <seed>` — o relatório ganhou a tabela
  **Combate por ato** (turnos/luta, dano sofrido/turno, turnos/chefe).

Ver também: [[combat_beats]] · [[balance_curves]] · [[rng_and_offers]] ·
[[enemy_pose_and_scene_anchor]].
