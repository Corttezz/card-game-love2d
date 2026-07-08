# Piloto de IA — Achados da 1ª bateria (Jul/2026)

> **Pipeline:** `love . autoplay [runs] [warrior|mage|rogue|all]` →
> `tools/autoplay.lua` joga runs completas pelos MESMOS sistemas do jogador
> (selectCard/playSelectedCards/enemyTurn, escolha de caminho, loja, eventos,
> forja, recompensas) e escreve um diário decisão-a-decisão + métricas em
> `autoplay_report.md` (save dir). Roda com `_G.HEADLESS_TOOL` (perfil real
> intocado).
>
> **Bateria:** 2 runs × 3 classes, política heurística (LETHAL → sobreviver
> ao intent → curar → maximizar dano/mana). **Status: propostas A+B+C
> APLICADAS (Jul/2026) — ver "Bateria 2" no fim.**

## Placar da bateria (pós-rebalance F0-F2)

| Run | Resultado | Score |
|---|---|---|
| warrior #1 | morreu A1-F5 (elite) | 148 |
| warrior #2 | morreu A1-F7 (mini-boss) | 582 |
| mage #1 | morreu A1-F8 (boss) | 997 |
| mage #2 | morreu A1-F7 (mini-boss) | 314 |
| rogue #1 | morreu A1-F7 (mini-boss) | 414 |
| rogue #2 | morreu A1-F8 (boss) | 1089 |

**Ninguém saiu do Ato 1.** Turnos/batalha 3.1–6.6. Decisão real (sobrou
carta pagável não-jogada) em 7–18% dos turnos.

## A. BUGS que o piloto descobriu (jogando)

1. **Muro imortal: armadura do inimigo nunca zera.** O intent DEFEND
   re-encapa +20 de armadura (cap) a cada 2 turnos; o output do jogador
   (~8–16/turno atravessando armadura) não vence o re-cap. Caso real do
   diário: elite com **4 HP ficou imortal por 5 turnos** enquanto a Fúria
   subia o dano dele até 68 e matava o jogador. A armadura do JOGADOR zera
   por turno; a do inimigo, não — assimetria não intencional.
   *Proposta: armadura do inimigo zera no início do turno dele (simetria) —
   defend vira proteção de UM golpe, não muro permanente.*

2. **Dano fracionário.** `attackPattern aggressive` multiplica ×1.5 sem
   floor: HUD e dano mostram "ATTACK 30.5", "19.5". *Proposta: floor no
   Enemy:takeDamage (bloco aggressive) e no getIntentPreview.*

3. **Mana não recarrega no início da batalha.** Quem gasta tudo no último
   turno da batalha anterior começa a próxima com 0–2 de mana (T1 real do
   diário: "mana 0"). *Proposta: restoreMana ao criar batalha (nextPhase/
   startGame já resetam battleTurn — mesmo lugar).*

4. **Fúria + par apertado sufoca o Ato 1.** Toda batalha de 6+ turnos vira
   corrida da morte; com o muro do item 1, virou sentença. *Proposta:
   Fúria começa no turno 8 (era 6) e/ou tem teto (+10 total).*

5. **Suspeita de robustez (validar no jogo real):** `CombatSequence:
   startCombat` re-entrante (active=true) chama `onComplete()` SEM
   processar as cartas — se o jogador conseguir disparar "Jogar Cartas"
   durante a animação, a jogada é engolida em silêncio.

## B. BALANCE (dados da bateria)

- **O pêndulo passou do ponto**: antes do overhaul o spam vencia tudo;
  agora 6/6 runs morrem no Ato 1 (F5–F8). Os assassinos: elite F5 (60 HP /
  11 dmg), mini-boss F7 (98 HP / 11 dmg), boss F8 (140 HP / 14 dmg) contra
  output de ~16–24 dano/turno e defesa de ~15/turno.
  *Propostas: (a) elite/mini-boss/boss do Ato 1 com −20–25% HP;
  (b) consertar o item A1 (que é meio balance também);
  (c) dano dos inimigos F6+ do Ato 1 −15%.*
- **Recompensa pós-batalha é PAGA** (3 ofertas com preço). O bot pulou
  ~40% das recompensas por falta de ouro — o deck não cresce no ritmo da
  curva de inimigos. Em StS a recompensa de batalha é GRÁTIS (escolha 1 de
  3, pagar é só na loja). *Proposta: modo rewards de graça (skip continua
  dando +3g), loja continua paga — progressão de deck destravada sem
  inflar economia.*
- **Curas exauríveis + rest a cada ~4 andares** = atrito de HP acumula sem
  válvula. *Proposta: vitória de batalha cura +3 HP fixo (mini-heal StS-
  like via relíquia? aqui como regra base do Ato 1) OU rest garantido no
  meio do ato.*

## C. EXPERIÊNCIA (game feel observado no diário)

- **Os intents FUNCIONAM**: o bot alternou entre defender no STRONG
  telegrafado e ignorar defesa no DEFEND do inimigo — as "janelas" que o
  overhaul queria existem e mudam a jogada.
- **Decisão real ainda baixa (7–18%)**: com mana 3 e quase tudo custo 1,
  o turno é "jogue 3 de 5" — a escolha é QUAL jogar (bom), mas raramente
  "quanto guardar" (não há guardar: a mão descarta). *Ideias a discutir:
  custos 2–3 mais presentes nos pools, ou 4 de mana com cartas mais caras,
  ou mecânica de "reservar 1 carta" (retain seletivo) por turno.*
- **Score recompensa o jogo certo**: vitórias rápidas + combos renderam
  3–10× mais pontos (F3 visível no diário).

## D. Como rodar a pipeline

```
love . autoplay 2 all       # 2 runs por classe → autoplay_report.md
love . autoplay 5 rogue     # aprofunda uma classe
```
O diário mostra, por turno: HP/armor/mana, intent do inimigo, mão completa,
o que o bot jogou e POR QUÊ, dano causado/sofrido; por batalha: recibo de
score; por andar: caminho escolhido e razão; por run: métricas agregadas.

## Próximos passos sugeridos (aguardando decisão)

1. Consertar A1–A3 (bugs claros: muro de armadura, dano fracionário, mana).
2. Balance pass do Ato 1 (B) + recompensas grátis.
3. Re-rodar a bateria (5×3 runs) e comparar placar — meta: ~40–60% das
   runs do bot chegando ao Ato 2, vitória ocasional.
4. Iterar as ideias de decisão (C) com nova bateria.


---

## Bateria 2 — DEPOIS das correções (A+B+C aplicadas)

Correções: armadura do inimigo expira no turno dele; floor no dano
aggressive; mana cheia ao entrar em batalha; Fúria turno 8+ com teto +10 e
pill visível "Fúria" (tooltip explica); guard de reentrância no
playSelectedCards; boss A1 140→110 HP / 14→12 dmg; elite A1 ×1.6→×1.4;
recompensa pós-batalha GRÁTIS; juros com fonte única Balatro ($1/$5 cap $5,
TopBar = RoundEval); reroll linear 5+2/reroll.

| Run | Bateria 1 (antes) | Bateria 2 (depois) |
|---|---|---|
| warrior #1 | morreu A1-F5 (148) | morreu A2-F7 (1355) |
| warrior #2 | morreu A1-F7 (582) | morreu A2-F3 (2078) |
| mage #1 | morreu A1-F8 (997) | morreu A2-F6 (1595) |
| mage #2 | morreu A1-F7 (314) | morreu A1-F8 (798) |
| rogue #1 | morreu A1-F7 (414) | morreu A1-F8 (1177) |
| rogue #2 | morreu A1-F8 (1089) | morreu A2-F5 (2708) |

- **4/6 runs chegam ao Ato 2** (meta 40-60%: atingida). Boss A1 ainda é
  filtro (2/6 do bot morrem nele — a heurística é um jogador mediano;
  humano joga melhor).
- Decks finais 10-16 cartas (antes 3-10) — recompensas grátis destravaram
  a progressão.
- Próxima calibração candidata: Ato 2 (os 4 que passam morrem em F3-F7).
