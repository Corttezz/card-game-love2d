---
name: Balance Curves
description: Números-alvo de HP, dano, economia e raridades por ato/andar
type: project
---

# Curvas de Balance

**Fase 5 + rebalance pós-playtest.** Fontes de verdade: `Config.Acts`, `Config.Endless`, `Config.Game` (`src/core/Config.lua`). Este doc resume as escolhas.

**Princípio:** curvas dimensionadas pro deck real — starter de 2 cartas cresce ~1 carta/andar, então o ato 1 enfrenta deck médio ~3-5 (não 10 como em Slay). HP dos inimigos foi escalado pra baixo proporcional. Meta de turnos/batalha: 2-3 no floor 1 ato 1, 4-5 em floors finais, 6-10 em bosses.

## Jogador (inicial)

- `PLAYER_MAX_HEALTH = 60` (antes 100; pressão maior num deck pequeno)
- `PLAYER_MAX_MANA = 3`
- `PLAYER_MAX_ARMOR = 50` (cap por batalha, zera no `resetTransientStats`)
- `INITIAL_HAND_SIZE = 4` (compensa deck de 2 cartas na run 1)
- `MAX_JOKER_SLOTS = 3`

## Inimigos por ato

Fórmulas em `Config.Acts[N]`:

| Ato | HP(f) | Dmg(f) | f=1 HP/Dmg | f=8 HP/Dmg | Boss HP | Boss Dmg |
|-----|-------|--------|------------|------------|---------|----------|
| 1 Catacumbas | 8 + f*6 | 3 + f*1.2 | 14/4 | 56/12 | 140 | 14 |
| 2 Torre | 60 + f*10 | 9 + f*1.5 | 70/10 | 140/21 | 300 | 22 |
| 3 Abismo | 150 + f*15 | 18 + f*2.5 | 165/20 | 270/38 | 500 | 32 |

**Elite**: HP × 1.6, Dmg × 1.3.
**Mini-boss**: HP = 70% boss, Dmg = 80% boss.
**Endless**: stats do ato 3 * `1.18^floorsInEndless`.

## Cura

- Inter-ato: 30% maxHP ao entrar no ato 2; 40% ao entrar nos atos 3+.
- Rest node: +30% maxHP.
- Events podem curar/dar maxHP.

## Raridade por ato (`rarityWeights`)

| Ato | common | uncommon | rare | legendary |
|-----|--------|----------|------|-----------|
| 1 | 70 | 25 | 5 | 0 |
| 2 | 40 | 45 | 14 | 1 |
| 3 | 15 | 45 | 32 | 8 |
| Endless | 10 | 35 | 45 | 10 |

## Starter cards (2 por classe)

Valores boostados no rebalance pós-playtest — cada carta pesa mais, dado que o starter só tem 2:

| Classe | Attack | Defense |
|---|---|---|
| Warrior | `warrior_strike` 8 | `warrior_defend` 7 |
| Mage | `mage_zap` 5 (+orb lightning 3) | `defense_001` 8 |
| Rogue | `rogue_strike` 7 | `rogue_defend` 6 |

## Tabela-alvo de stats por carta (Fase 7)

| Raridade / Custo | C0 | C1 | C2 | C3 |
|------------------|----|----|----|----|
| Common | 3-4 | 6-8 | 10-12 | — |
| Uncommon | 4-5 | 8-10 | 12-15 | 16-20 |
| Rare | 5-6 | 10-13 | 15-20 | 22-28 |

Cartas com efeito secundário forte recebem -1 a -3 no valor base.

## Economia (auditoria Out/2026 — fontes: Config.Economy, Config.Offers, ShopSystem)

> O bloco antigo daqui ("10 + floor*5", juros 10%, legendary ×5, refresh 2+n)
> estava MORTO havia meses — nenhum desses números existia mais no código.

**Renda** (cash out, `Game:_buildRoundEvalSources`):
- Ouro inicial $10.
- Vitória `5 + 2×(ato-1)` (A1 $5 … A6 $15) · HP cheio +$3 · juros `floor(ouro/5)`,
  teto $5 (+2 por Cofre comprado).
- **Bônus de risco** (Out/2026): elite +1× a vitória do ato, chefe do ato +1×.
  Mini-chefe NÃO paga: é obrigatório, bônus nele é renda fixa disfarçada (a
  1ª versão com mini +1×/chefe +2× subiu o winrate do guerreiro do piloto de
  42% → 83%).
- Pular a loja +$3. Dados do Escriba: EV ~justo, 1 jogada/loja ([[scribe_dice]]).

**Preços** (antes → depois da auditoria):

| item | antes | depois |
|---|---|---|
| carta comum / incomum / rara | $3 / $6 / $9 | igual |
| carta lendária | $30 | **$21** |
| pacote (5 tipos) | $4 | igual |
| reroll | 5, 7, 9… teto 30 | **4, 6, 8…** teto 30 |
| bancada de coringa (2/run) | $30, $60, ~23% das lojas | **$20, $35, FIXA em toda loja** até o teto |
| grimório +1 compra (2/run) | $25, $55 | **$22, $44** |
| cristal +1 mana | $25 | igual |
| elixir +10 vida | $5 | igual |
| forja | 5×1.35ⁿ (teto 60) | igual |
| tesoura (remover) | 8×1.45ⁿ (teto 45) | igual |
| prensa (duplicar) | 12×1.55ⁿ (teto 60) | igual |
| cofre (+2 teto de juros) | 25×1.65ⁿ (teto 150) | igual |

**Medido** (`love . balance_sim 12 <classe> 700000`, piloto v6, MESMO código,
preços antigos via patch × novos — 36 runs de cada lado; o relatório tem a
seção "Economia por ato"):

| | antigo G / M / L | novo G / M / L |
|---|---|---|
| winrate (n=12, ±14pp) | 42% / 8% / 33% | 50% / 33% / 58% |
| renda A1 (ganho/run no ato) | $51 / $57 / $57 | $61 / $67 / $66 |
| gasto A1 | $13 / $13 / $14 | $13 / $17 / $17 |
| renda A4 | $67 / $55 / $68 | $86 / $69 / $72 |
| gasto A4 | $32 / $64 / $44 | $44 / $46 / $52 |
| ouro na porta da loja A1 · A2 · A3 (guerreiro) | $26 · $55 · $121 | $28 · $65 · $140 |
| bancada na vitrine / cabia no bolso (3 classes) | 23% / 88-91% | 23-24% / 96-98% |

Leitura: a 1ª bancada ($20) agora cabe na loja do A1 (porta ~$28); a 2ª
($35) no A2. O piloto ENTESOURA do A3 em diante (porta $140+, compra no
máximo 3 itens/loja) — isso é limite da política do bot, não falta de
preço; não há ouro infinito (juros têm teto, bônus é por nó finito, dados
1×/loja com EV ~1).
**Pendente (próximo lever):** ensinar o piloto a GASTAR do A3 em diante (hoje
compra no máx. 3 itens/loja e só pega bancada com coringa parado) — enquanto
ele entesoura, a bateria não mede se os preços do fim de jogo estão certos.
A frequência da bancada quase não mexeu com o peso 1.3 (22→24%), então ela
ganhou VAGA PRÓPRIA (Out/2026): a loja tem 3 relíquias — tesoura e bancada
fixas + 1 sorteada — e 1 pacote (era 2+2; 3+2 encolhia todas as cartas e
cortava os nomes). Fixa indisponível devolve a vaga ao sorteio.
Travas: `test_economy` (alcance dos preços),
`test_economy_acts` (renda por ato + bônus de risco), `smoke_shop` (reroll).

## Smoke tests de balance

- `love . smoke_acts` valida curvas HP/dano + starter deck = 2 + PLAYER_MAX_HEALTH = 60
- `love . validate_cards` lista cartas fora da curva

## Re-baseline pós-Rebalance v2 (Jul/2026, bot v5.17)

Baterias `love . autoplay` com o Piloto v5.17 (prior de defesa pra mago/ladino):

| Bateria | Guerreiro | Mago | Ladino |
|---|---|---|---|
| 15×3 (bot v5, pré-fix de prior) | **12/15 (80%)** — os 15 chegaram ao boss final | 0/15 — morte por chip (decks sem defesa = viés do BOT) | 1/15 (7%) |
| 10×3 (bot v5.17) | 5/10 (50%) | 0/10 (mas muito mais fundo: 4× boss A2, 4× A3) | 1/10 (10%) |
| 10 mago (Conduíte 2 Foco) | — | **3/10 (30%)** + 1 morte no boss final | — |

- **Lição de método**: bot sem afinidade de defesa pra mago/ladino não mede o jogo,
  mede o próprio viés. Corrigir a política do bot ANTES de nerfar o jogo.
- **Levers aplicados**: prior de defesa no bot (v5.17) + Conduíte 1→2 Foco (Game.lua).
- **Banda atual**: 50/30/10 — todas as classes vencem e chegam ao A3. Tripwires formais
  (mago >65%, Muralha >65% → Baluarte 8→6) NÃO dispararam (thorn/turno medido 3-6,
  banda alvo 25-38).
- **Próximos levers monitorados**: conversão do ladino no boss final (morre lá 4/10);
  guerreiro se passar de 60% ("sofrido/turno 0.0" em atos inteiros é o sintoma —
  Onda de Ferro ×4-5 + Escudo de Espinhos + Muralha zera o dano inimigo).

## Kits dos inimigos (Out/2026, ver [[enemies]])

Os inimigos ganharam kit próprio (`src/data/enemies.lua`) — golpe médio ~1,0–1,1×
o dano base contra ~0,76× do kit antigo, mais debuffs no jogador. Calibração:

- `Enemies.DAMAGE_SCALE_BY_ACT = { 1.15, 1.10, 0.92, 0.88, 0.84, 0.84 }` (o começo
  SOBE: atos 1-2 tinham 0,0–0,2 de dano sofrido/turno) e `BOSS_DAMAGE_SCALE = 0.90`.
- Chefes dos atos 4-6: `bossHP/bossDmg` 660/32 → 600/33, 990/38 → 880/38,
  1430/45 → 1200/46 (o do ato 6 era esponja de 11–13 turnos).
- DoT no JOGADOR soma pilhas e fica com a MAIOR duração (somar as duas compunha:
  o Colosso matava pela soma de nuvens).

Baterias `balance_sim` (seed 700000; v6 = 2×15 por classe, seeds 700000+710000):

| | guerreiro | mago | ladino |
|---|---|---|---|
| antes (HEAD 278549b, 20/classe) | 60% | 35% | 30% |
| kits v1 (sem escala) | 15% | 15% | 5% |
| v6 (final) | 73% | ~33–59% (amostra curta) | 47–50% |

| ato | turnos/luta antes → v6 (guerreiro) | dano sofrido/turno | turnos/chefe |
|---|---|---|---|
| 1 | 3,0 → 3,2 | 0,0 → 0,4 | 4,9 → 5,5 |
| 2 | 4,7 → 4,7 | 0,2 → 0,4 | 7,2 → 6,5 |
| 3 | 6,6 → 5,3 | 0,5 → 0,8 | 8,8 → 7,0 |
| 4 | 6,6 → 6,1 | 1,1 → 0,9 | 8,2 → 7,7 |
| 5 | 7,4 → 6,4 | 0,8 → 1,3 | 9,3 → 7,4 |
| 6 | 8,4 → 6,6 | 1,3 → 1,6 | 11,0 → 8,0 |

**Atenção ao ler:** entre v4 e v5 a árvore recebeu mudanças de OUTRAS frentes
(bônus de ouro por elite/chefe, bancada de coringa mais barata, prévia de dano) —
o salto do guerreiro de 25% para 77% veio sobretudo daí. O guerreiro acima de 60%
é questão de CLASSE (já estava em 60% antes dos kits), não de inimigo. Lever
monitorado: o Colosso (A5) concentra as mortes do ladino (regen contra veneno) —
se passar de metade das mortes, baixar `regenPct` 0,02 → 0,015.

## Balanceamento de CLASSE (Out/2026, frente combo/dano) — passivas que crescem na luta

`balance_sim 30 <classe> 720000`, piloto v6, um processo por classe. Base = bateria
v7 do roster novo (0b46c0d, Combo v3 já dentro). Final = HEAD 6485277 + Ímpeto 3 +
Foco inteiro no pulso, com as mudanças de inimigo d0e41d4 (Colosso/Anjo/Tirano) e
b9e677f (DoT ignora armadura) já na árvore.

| classe | base v7 | fin1 (passivas crescem) | final (+Ímpeto 3, Foco inteiro) |
|---|---|---|---|
| guerreiro | 43% | 67% | 47% |
| mago | 13% | 40% | 43% |
| ladino | 17% | 40% | 50% |

Turnos/luta A1→A6 (final): guerreiro 2,8 · 4,4 · 5,6 · 6,2 · 6,4 · 7,2 ·
mago 2,7 · 5,2 · 8,2 · 9,5 · 13,9 · 14,1 · ladino 2,6 · 4,4 · 5,3 · 6,4 · 7,5 · 8,4.
Mortes (final): guerreiro A3 6 · A4 2 · A5 6 · A6 2; mago A2 1 · A3 2 · A4 5 · A5 4 · A6 5;
ladino A2 1 · A3 5 · A4 2 · A5 5 · A6 2.

O que mudou (lado jogador): Conduíte +1 Foco por turno com 2+ cartas de orbe;
Toxinas +2 (`Game.TOXIN_GROWTH`) por turno com 2+ ataques; Ímpeto pede 3 ataques
(`Game.IMPETUS_ATTACKS`); dano de orbe pelo maior multiplicador de coringa
(`EffectSystem.orbDamageMult`); Foco soma INTEIRO no pulso (depois da divisão);
Punhalada 11→8, Adrenalina custo 1, Veneno Concentrado +4.

**Mago ainda luta 14 turnos no A5-A6 — e é do PILOTO, não da classe.** Testado:
raio pulsando o valor cheio (+dano) deixou o mago em 47% e as lutas MAIS longas
(15-17). O diário (`autoplay 1 mage 720001`, chefe do A5) mostra o piloto passando
o turno com 9-10 de mana e ataques na mão ("vazio 41 x jogar 4 cartas -65"),
jogando cura/defesa contra um chefe que regenera — o mago quase não toma dano
(0,5/turno) e o valor do piloto prefere tartaruga. Próximo passo é do piloto
(`AI.score` subestima dano quando o HP está folgado), não do mago.

### Re-medição pós-f67ebe4 (passiva do mago em toda luta)

O f67ebe4 consertou a passiva do mago (orbe + Foco era apagado pelo
`resetTransientStats` do `nextPhase`: só valia na 1ª luta da run). Os 43% acima
foram medidos COM o defeito. Mesmo HEAD, seed 720000:

| variante (mago, 30 runs) | vitória | turnos/luta A5 · A6 |
|---|---|---|
| f67ebe4 como está (Foco inicial 2/3/4) | 63% | 12,0 · 14,8 |
| Foco inicial 1/2/3 | 77% | — |
| Conduíte pedindo 3 cartas de orbe (parcial 11 runs) | 36% | — |
| sem multiplicador de coringa no orbe (parcial 16 runs) | 75% | — |
| **Foco inicial 0/1/2 (adotado)** | **53%** | 11,6 · 14,2 |

Sanidade 20 runs no mesmo HEAD: guerreiro 50%, ladino 55%. O ruído entre
variantes vizinhas é grande (1/2/3 deu MAIS que 2/3/4) — com 30 runs o erro
padrão é ~9pp. Mortes do mago (adotado): A2 1 · A3 1 · A4 1 · A5 7 · A6 4.

## Combos simples + força do inimigo (Out/2026)

Decisão do dono: combos fortes e não explicados saem; entram Saraivada (+3 por
ataque anterior), Muralha (+5 de Bloqueio por defesa anterior) e Par (+4 por
cópia anterior), bônus plano. `balance_sim 30 <classe> 720000`.

| passo | guerreiro | mago | ladino |
|---|---|---|---|
| antes (f67ebe4 + 06211da, combos por tag) | 50%* | 53% | 55%* |
| só os combos simples (sem compensar) | 0–5% | ~40% (parcial) | 20% |
| + combos 2x, +60% Bloqueio, +20% ataque (só jogador) | 5–20% | — | — |
| + ENEMY_POWER dano x0,8 / vida x0,85 (mago com crescimento) | 53% | 73–90% | 50% |
| **final**: + mago sem crescimento/sem orbe x coringa/Foco dividido | **53%** | **60%** | **50%** |

\* 20 runs. Variantes do mago no inimigo mais fraco: Conduíte pedindo 3
cartas 73%, cap de 3 crescimentos 90% (parcial), sem orbe x coringa 75%, Foco
dividido 75%, os três + 3 cartas 62% (parcial), sem crescimento 47% (30 runs).
O final deu 60% no mesmo pacote (ruído ~9pp).

Final, turnos/luta A1→A6: guerreiro 2,8 · 4,7 · 6,1 · 6,9 · 6,9 · 7,7; mago 2,6 ·
4,8 · 5,9 · 7,3 · 9,8 · 10,8 (era 14 no A6); ladino 2,5 · 4,4 · 5,0 · 5,8 · 6,7 · 7,7.
Mortes: guerreiro A3 4 · A4 3 · A5 7; mago A3 1 · A4 4 · A5 2 · A6 5; ladino A3 2 ·
A5 10 · A6 3 (o chefe do A5 ainda é a parede do ladino). Parte do dano das cartas
que vem de combo: guerreiro 17% (era 37%), mago 20% (era 55%), ladino 31% (era 48%);
Bloqueio de combo 14–21% (era ~50%). Cartas por jogada ~3,2–3,5 (inalterado: a mana
é quem limita).

## Calibração do relógio instantâneo (12/Out/2026, HEAD 50097b7, selo 0)

`python tools/balance.py --runs 30 --pilots expert_full` (= o piloto v6 original:
busca de combate + deck por simulação com 2 replays e todas as candidatas),
MESMAS seeds 720001–720030 da bateria serial de `a113c57`, agora em 15,7 min de
parede (12 processos, ~108 s de CPU por run) em vez de ~2 h por classe:

| classe | serial a113c57 (relógio de quadros) | expert_full instantâneo | IC 95% |
|---|---|---|---|
| guerreiro | 53% | **53%** (16/30) | 36–70% |
| mago | 60% | **57%** (17/30) | 39–73% |
| ladino | 50% | **43%** (13/30) | 27–61% |

Diferença de 0–2 runs por classe: o relógio instantâneo reproduz a medição
antiga dentro do ruído (o piloto por simulação de deck consulta `love.timer`
pra orçamento, então não é bit-a-bit — a paridade bit-a-bit é do
`test_instant_parity`, com o piloto average). Deck final 13–16; turnos/luta
A1→A6 2,6 · 4,6 · 5,7 · 6,6 · 7,7 · 8,9; mortes A3 8 · A4 7 · A5 21 · A6 8 —
**o Colosso (A5) é 18 das 44 mortes** (12 das 17 do ladino). Duração estimada
67–82 min por run (o StS vence em 35–60).

Os outros pilotos no mesmo HEAD (`s2-head-fast`, 30/classe): naive 0% (morre
A2 80%), average 0–3% (A2 32% · A3 41% · A4 22%), expert_fast 0–3% (A3 53%);
`expert` (deck por simulação com 1 replay e 2 candidatas) 19–25% (n=16). Ou
seja: HEAD está NA BANDA pro melhor piloto (45–60%) e abaixo pra todos os
outros — a diferença é o deck (17–18 cartas contra 13–15) e a qualidade da
jogada, não a seed. Muros dos pilotos rápidos: tower_lich (A2) 38 e
storm_griffin (mini A2) 32 das 270 mortes, abyss_tyrant (A3) 31.

### Sweep A — força global do inimigo × vida do tower_lich (pilotos rápidos)

`python tools/balance_tune.py --runs 30 --pilots naive,average,expert_fast
--enemy-power 0.8,0.85 … 0.55,0.6 --boss-hp-id "" tower_lich=0.8` (12 pontos,
8 min de parede). `average` aqui ainda é o v5 ("pega sempre algo", deck 18–19):

| ENEMY_POWER (dano,vida) | naive G/M/L | average G/M/L | expert_fast G/M/L | onde o average morre |
|---|---|---|---|---|
| 0,80/0,85 (HEAD) | 0/0/0 | 3/0/0 | 3/0/0 | A2 32% · A3 41% |
| 0,75/0,80 | 0/0/0 | 0/0/0 | 10/0/3 | A3 57% |
| 0,70/0,75 | 0/0/0 | 0/0/3 | 17/0/3 | A3 54% |
| 0,65/0,70 | 0/0/0 | 3/0/0 | 23/3/13 | A3 58% |
| 0,60/0,65 | 0/0/0 | 13/0/7 | 37/10/10 | A3 42% · A4 21% |
| 0,55/0,60 | 0/0/0 | 7/3/0 | 37/10/27 | A3 37% · A5 36% |

tower_lich ×0,8 não muda nada mensurável (±1 run). **Baixar o inimigo NÃO
salva o deck gordo**: de 0,8 a 0,55 o `average` sai de 0–3% para 0–13% e só
troca a morte de A2 por A3/A5 — perde 17–20 de vida por luta no A3 em todo
ponto da grade, contra 6,5 do expert_full. Enquanto isso o expert_fast vai a
37% e o expert_full iria muito acima da banda (a 0,75/0,82 o `expert` barato
já dava 30/40/63%, `cc_n5`). O que separa os pilotos é o DECK (expert_full:
6,7 cartas na 8ª batalha, 13 no fim; average: 13,9 na 8ª, 18–19 no fim) e a
QUALIDADE das cartas que entram (expert_fast tem deck de 16–18 e também
morre no A3). Muro dos pilotos rápidos a 0,7/0,75: elites do A3 47 mortes
(`eliteHPMul` 1,7 × base 165 = 280 de vida já no 1º andar do ato, mais que o
chefe do A2), abyss_tyrant 42, abyss_watcher 31, obsidian_sentinel 24.
Leitura do lead: sinal de DESIGN (o jogo pune deck normal mais que o StS), não
defeito de piloto — ver Sweep B.

### Sweep B/C — mão, mana, deck fino e o diagnóstico por luta

Piloto `average` recalibrado 7 vezes na sessão (ver [[balance_pipeline]]): barra
de escolha (76–85% das recompensas em vez de 90–100%), 1 carta por loja (era
até 5 numa loja do A1), score por VALOR em vez de por tag, bônus de cura.
Nenhuma versão passou de 0–7% em HEAD, 0,75/0,8 ou 0,7/0,75; mão 6 e mana 4
(`--hand 6 --mana 4`) deram +0–7 pp no average e +10 pp no expert_fast
guerreiro (43%). Melhor célula do sweep B: 0,7/0,75 + mão 6 + mana 4 →
average 7/3/0, expert_fast 43/10/10, naive 0.

**Diagnóstico por turno** (`battleLog[].diag`, `python <scratch>/diag.py`;
HEAD, A3, média por luta):

| piloto | turnos/luta | dano/turno | golpe anunciado | escudo no golpe | cobriu | furou/golpe | vida/luta | mana sobrando | carta pagável sobrando |
|---|---|---|---|---|---|---|---|---|---|
| naive | 2,7 | 48 | 20,7 | 5,6 | 9% | 15,9 | 19,8 | 0,09 | 0,02 |
| average v5 (tag) | 6,0 | 30 | 21,2 | 23,7 | 59% | 6,0 | 18,8 | 0,15 | 0,11 |
| average v7 (valor) | 3,6 | 59 | 20,2 | 11,2 | 23% | 11,3 | 18,2 | 0,38 | 0,21 |
| expert_fast | 4,1 | 48 | 19,6 | 10,8 | 26% | 10,9 | 14,1 | 0,61 | 0,90 |
| **expert_full** | 5,6 | 40 | 19,8 | 16,3 | 51% | 7,1 | **6,9** | 0,58 | 0,78 |

O average NÃO é cego: lê o intent (cobre 59% dos golpes, mais que o
expert_full) e gasta a mana. Ele perde porque **não se sustenta**: mesma
cobertura, 7 de furo por golpe, e ainda assim 18,8 de vida por luta contra
6,9 — o expert_full escolhe CURA (Gota Curativa 49×, Poção de Cura 33×, Elmo
do Valor 43× em 36 runs), básicas baratas (attack_002, Baluarte, defense_001),
forja 3,5×/run (average 1,3) e SEGURA carta (0,8 pagável não jogada por turno
— só joga o que o plano pede). A composição do deck final é a mesma
(50% ataque · 29% defesa · 20% efeito, valor base até MENOR: 3,6 de
ataque/carta contra 4,1). Quem tenta ser agressivo (average v7, expert_fast,
naive: 48–59 de dano/turno) cobre 9–26% dos golpes e morre no A3 do mesmo
jeito. **Resumo pro dono dos números:** o jogo em HEAD só é vencível com
sustento + forja + escolha por simulação; carta tomada por valor-de-face
perde 100% — no StS quem pega a maioria das cartas ainda vence 10–25%.

### Adotado (Stage 2 final, 12/Out/2026): `ENEMY_POWER` 0,75/0,8 + ato 3 ×0,9

Baterias `s2-ef-075-a3` (expert_full), `s2-sweepC-p02` (naive/expert_fast) e
`s2-final-average` (average, depois do conserto do motor — abaixo), 30 runs
por classe×piloto, seeds 720001–720030, selo 0:

| piloto | banda | guerreiro | mago | ladino | mortes por ato (90 runs) | turnos/luta A1→A6 | min/run (est.) |
|---|---|---|---|---|---|---|---|
| naive | <5% ✓ | 0% | 0% | 0% | A1 1 · A2 52 · A3 35 · A4 2 | 2,3 · 3,2 · 3,6 · — | ~15 |
| average (normal) | 12–25% ✗ | 10% [3–26] | 0% [0–11] | 7% [2–21] | A2 10 · A3 32 · A4 19 · A5 19 · A6 5 | 2,3 · 3,2 · 3,6 · 4,2 · 5,7 | 25–34 |
| expert_fast | 30–50% ✗ | 13% [5–30] | 0% [0–11] | 0% [0–11] | A2 6 · A3 31 · A4 31 · A5 16 · A6 2 | idem | ~35 |
| **expert_full** | 45–60% ✓ | **57% [39–73]** | **53% [36–70]** | **53% [36–70]** | A3 2 · A4 6 · **A5 27** · A6 6 | 2,4 · 4,5 · 5,1 · 6,7 · 7,4 · 9,0 (chefe A6 11,4) | 72 / 81 / 67 (vitória ~84) |

Vida perdida por luta do expert_full A1→A6: 0,4 · 2,6 · 4,1 · 5,1 · 11,1 · 7,5;
deck final 14–15; dano 72% carta · 14% orbe · 12% DoT; valor de ataque
48% base · 24% combo · 18% stat · 10% coringa. Mortes: Colosso (A5 boss) 18,
Mãe dos Esporos (A5 mini) 7 — o A5 é o degrau seguinte a olhar, mas está na
banda de "onde o expert morre" (A5–A6). Pontos abaixo (0,7/0,75 + A3) só
levam o expert_fast a 17/3/7 e o average a 7/0/0 — não vale tirar o
expert_full da banda por isso.

**Conserto do piloto `steps` no fecho (Out/2026):** o banco do
`test_balance_pipeline` flagrou o average perdendo 70 de vida (morte em 9
turnos) no elite A1-F4 em que o naive vence em 2: com o deck inteiro na mão,
`chooseMotorCard` gastava as 3 manas em Grito de Comando (compra 2 do baralho
vazio → a própria carta volta), Força +24 e zero dano. Regra nova: motor de
compra só com algo pra comprar (deck+descarte ≥ 1) e nunca com a ÚLTIMA mana
(custo 0 passa). Só o `average` usa `steps`; a bateria refeita deu 10/0/7
(era 7/0/3 — dentro do ruído, a leitura não muda).

### Propostas pro dono (NÃO aplicadas): abrir 10–25% pro jogador normal

O sweep provou que nenhum knob de inimigo move o average/expert_fast sem
jogar o expert_full pra fora da banda. O que separa os pilotos é SUSTENTO
(18,8 de vida/luta contra 6,9 com a mesma cobertura de intent) e a
qualidade da escolha. As três mudanças menores que atacam isso, em ordem de
custo:

1. **Cura garantida cedo e mais acessível.** Hoje a cura é carta rara de
   achar (o expert_full "caça" Gota Curativa/Poção de Cura/Elmo do Valor).
   Garantir 1 oferta de cura (ou sustento: lifesteal/regen) na recompensa do
   1º elite ou do chefe do A1, e dar peso extra a cartas `heal` na afinidade
   quando o deck tem < 2 fontes — é exatamente o que o average recalibrado
   faz por fora e ainda assim só chega a 7%; se a OFERTA existir, ele
   escolhe sozinho. Medir com `average` antes/depois (knob barato: peso em
   `CardRegistry`/`ShopSystem`).
2. **Descanso que cura mais e/ou consumível de cura.** Rest hoje cura 30%
   da vida máxima (`RestScreen:_healPct`, igual ao StS — mas o StS tem
   poções e relíquias de sustento que aqui não existem); subir pra ~40% OU
   introduzir uma poção consumível (1 slot, cura 20%, cai de elite) dá ao
   jogador que lê o intent a margem que falta no A3–A4 — onde o average
   perde 12–16 de vida por luta e morre em 64 das 90 runs.
3. **Elites do A3–A4 menos punitivas no 1º andar do ato.** `eliteHPMul` 1,7
   logo na entrada do ato (280 de vida no A3) é mais que o chefe anterior;
   escalar o multiplicador de elite pelo andar (1,4 no 1º andar → 1,7 no
   último) ou ligar a elite a uma recompensa de sustento garantida (item 1)
   corta o muro sem tocar a curva do chefe que o expert_full já acha justa.

Alvo de aceite: average 12–25% e expert_fast 30–50% com expert_full ainda
45–60% (`python tools/balance.py --runs 30 --pilots naive,average,expert_fast`
+ `--pilots expert_full`, mesmas seeds). Combos e coringas ficam como estão
([[combo_rules]] — o dono quer o poder vindo deles).

## Decisão (13/Out/2026): sustento garantido ADOTADO; o resto fica atrás de flag

Bateria das propostas (30 runs/classe, seeds 720000+, G/M/L, IC ±17pp;
`reports/balance/sus-*`), medida em `wip/sustain` (7fce337, ANTES da névoa
de intenção), e a baseline da névoa em `f79510a` (`reports/balance/fog-*`):

| variante (env) | expert_full | average | expert_fast |
|---|---|---|---|
| base sem névoa | 57 / 63 / 80 | 3 / 0 / 0 | 7 / 3 / 3 |
| **base COM névoa** (f79510a) | **67 / 57 / 50** | 10 / 3 / 7 | 10 / 3 / 3 |
| `BALANCE_SUSTAIN=1` | 53 / 83 / 90 | **20 / 10 / 7** | 13 / 13 / 17 |
| `BALANCE_REST_HEAL=0.4` | 53 / 60 / 80 | 0 / 0 / 3 | 3 / 3 / 3 |
| `BALANCE_POTIONS=1` | 70 / 70 / 77 | 3 / 3 / 3 | 10 / 7 / 7 |
| `BALANCE_ELITE_RAMP=1` | 60 / 53 / 80 | 7 / 0 / 0 | 7 / 0 / 3 |
| sustain + potions | 63 / 80 / 90 | 20 / 7 / 13 | 23 / 10 / 17 |
| as quatro | 70 / 83 / 90 | 7 / 10 / 13 | 27 / 7 / 7 |

Leitura: (1) descanso 40% e elite em rampa não movem nada; (2) a poção só
ajuda o expert (sobe 57→70 no guerreiro) — é lever de quem já lê o jogo;
(3) **sustento garantido é o único que move o jogador mediano** (+10 a
+17pp) e não é carta: é a OFERTA que passa a mostrar cura/lifesteal/regen
cedo (`Config.Offers.SUSTAIN_GUARANTEE/WEIGHT_BONUS`, `CardRegistry.
isSustainCard`, vaga reservada em elite/chefe via `pickRewardCard
requireSustain`); (4) a névoa de intenção já derruba o expert do ladino de
80→50 e do mago de 63→57 nos atos 4/6, o contrapeso natural pro estouro que
o sustento mostrou SEM névoa (83/90). **Adotado:** só `SUSTAIN` (guarantee
+ peso ×2 com < 2 fontes). Potion/rest/ramp continuam atrás dos flags com
default = jogo atual (`test_sustain_knobs` prova que desligados nada muda).

**Pendente de medir** (uma bateria, `python tools/balance.py --runs 30
--classes all --pilots expert_full` + `--pilots naive,average,expert_fast`
no HEAD, sem `--env`): sustento + névoa JUNTOS. Expectativa: expert_full
~55-70 / 65-75 / 55-65. Se mago/ladino passarem de 65%, o ajuste é no
INIMIGO dos atos 5-6 (`ENEMY_POWER_BY_ACT`), nunca em carta. A bateria foi
interrompida a pedido do dono (abria janelas enquanto ele trabalhava) —
rodar só com a máquina livre.

### Sustento + névoa medidos JUNTOS no HEAD (13/Out/2026, `reports/balance/head-sustain-fog-*`)

| HEAD (sustento ON, névoa A4/A6) | expert_full | average | expert_fast |
|---|---|---|---|
| sem env | **60 / 80 / 83** | **13 / 7 / 13** | 20 / 17 / 13 |
| `BALANCE_ENEMY_POWER_ACT=3:0.9,0.9;5:1.1,1.1;6:1.15,1.15` (`head-a56-*`) | 43 / 70 / 73 | 3 / 3 / 3 | 7 / 3 / 3 |

Leitura: o sustento levou o mediano pra banda (12–25) em duas classes e o
expert_fast dobrou; mago/ladino expert ficaram acima do teto (45–60) morrendo
só nos atos 5–6. O candidato de endurecer os atos 5–6 não serve: derruba o
guerreiro expert pra fora da banda (43) enquanto mago/ladino seguem acima, e
DESABA o mediano (13→3) e o expert_fast (20→7), porque quem chega ao A5 no
limite morre lá. **Decisão (lead): HEAD fica como está.** A dificuldade-base
(Selo 0) serve o jogador mediano; o expert tem os Selos 1–10 como escada
(papel da Ascensão no StS, [[endless_and_seals]]). Nota pra depois: a
assimetria de classe no late game (guerreiro mais frágil que mago/ladino nos
atos 5–6) é problema de CLASSE, não de curva de inimigo; se for atacar, é
por kit/passiva do guerreiro ou por Selo, nunca por `ENEMY_POWER` global.

## Dificuldade por ato (14/Out/2026): o jogo estava fácil demais

Pedido do dono (13/Out, literal): *"o jogo está ridiculamente fácil. Eu não
fiz nenhuma escolha pensada e passei por todos os bichos e o boss sem
dificuldade. Aumentar um pouco o dano de cada bicho e duplicar ou triplicar a
vida, para as batalhas durarem mais e quem não escolhe estratégia ser punido
com a vida"*.

**Adotado:** `Config.Game.ENEMY_POWER = { damage = 1.0, health = 1.0 }` e a
curva inteira em `ENEMY_POWER_BY_ACT`:

| ato | 1 | 2 | 3 | 4 | 5 | 6 (e endless) |
|---|---|---|---|---|---|---|
| vida | ×2,0 | ×1,8 | ×1,45 | ×1,15 | ×0,95 | ×0,85 |
| dano | ×1,0 | ×0,95 | ×0,9 | ×0,9 | ×0,85 | ×0,85 |
| antes (0,75/0,8 + A3 ×0,9) | 0,8 / 0,75 | 0,8 / 0,75 | 0,72 / 0,675 | 0,8 / 0,75 | 0,8 / 0,75 | 0,8 / 0,75 |

(linha "antes" = vida / dano efetivos). Comum do andar 1: 11 → 28 de vida;
chefe do A1: 88 → 220; chefe do A6: 960 → 1020.

### Medições (`python tools/balance.py`, seeds 720000+, selo 0, relógio instantâneo)

Pilotos rápidos com 30 runs por classe; expert_full com 15 por classe nos
candidatos e 30 na base e no final. Mortes por ato somam as três classes.

| curva (vida A1→A6 / dano A1→A6) | expert_full | average | expert_fast | naive (mortes A1/A2) | turnos/luta A1→A6 (expert_full) |
|---|---|---|---|---|---|
| **base** 0,8→0,8 (A3 0,72) / 0,75 (A3 0,675), HEAD 54568be6 | 73% [63-81] (G70 M80 L70), mortes A4 2 · A5 15 · A6 7 | 8% [4-15] | não medido (~17% no HEAD de 13/Out) | 0% (0 / 23) | 2,6 · 4,6 · 5,2 · 6,5 · 7,7 · 8,9 |
| uniforme 2,0 / 1,0 (sem rebaixo) | 8% [3-22] (12/classe) | 0% | n/m | 0% (60 / 30) | 4,1 · 7,3 · 8,6 · 11,1 · 11,7 · 11,9 (chefe A4 15,5) |
| c3: 1,8·1,6·1,2·0,95·0,8·0,8 / 1,0·0,95·0,85·0,8·0,75·0,75 | 78% [64-87] | 7% | 9% | 0% (47 / 42) | comum 2,6 · 4,6 · 6,3 · 6,5 · 7,5 · 7,9 |
| c1: 2,0·1,8·1,4·1,1·0,9·0,85 / idem c3 | 67% [52-79] | 3% | 4% | 0% (60 / 29) | comum 2,7 · 4,7 · 6,3 · 6,5 · 7,3 · 7,7 |
| c4: 2,0·1,8·1,5·1,25·1,05·1,0 / 1,0·0,95·0,9·0,85·0,8·0,8 | 51% [37-65] (mago: chefes A4-A6 em 16-17 turnos) | 1% | 2% | 0% (60 / 29) | comum 2,7 · 4,7 · 6,9 · 8,0 · 9,1 · 10,2 |
| c5: 2,0·1,9·1,6·1,35·1,15·1,1 / idem c4 com A2 1,0 | 36% [23-50] | 1% | 1% | 0% (60 / 30) | comum 2,7 · 5,3 · 6,9 · 7,7 · 8,1 · 10,1 |
| c6: 2,0·1,8·1,45·1,15·0,95·0,9 / 1,0·0,95·0,9·0,9·0,85·0,85 | 51% [37-65] | n/m | n/m | n/m | comum 2,7 · 4,7 · 6,6 · 7,0 · 7,7 · 9,0 |
| **final** = c6 com A6 vida 0,85, HEAD 38fc5a3a | **48% [38-58]** (G20 [10-37] · M57 [39-73] · L67 [49-81]), mortes A1 6 · A2 1 · A3 16 · A4 2 · A5 16 · A6 6 | **2% [1-8]** (G3 M0 L3) | **3% [1-9]** (G3 M0 L7) | **0%** (60 / 29, A3 1) | 4,1 · 6,7 · 7,4 · 7,9 · 8,5 · 8,8; chefe 7,5 · 10,1 · 9,9 · 10,6 · 9,8 · 11,1 |

Relatórios: `reports/balance/{base_atual,probe_ef_10_20,r1_c1,r1_c3,r1e_c1,r1e_c3,r2_c4,r2_c5,r2e_c4,r2e_c5,r3e_c6,final_fast,final_full}`
na worktree `card-game-dificuldade2` (fora do git, ver `reports/balance/README.md`).

**Atos 1 e 2 (o pedido):** luta do A1 (todas as lutas) de 2,5 para 4,1
turnos; a COMUM do A1 de 2,0 para 2,8 a 3,0 (o resto da média é elite e
chefe). Vida perdida por luta no A1: naive 2,2 → 12,0, average 1,2 → 6,5,
expert_full 0,4 → 3,4 (de 60). Vida perdida SOMADA ao longo do A1: naive 96%
(morre), average 52%, expert_fast 47%, expert_full 23%. O chefe do A1
(Rei Carniça) vira o primeiro filtro: 64 das 91 mortes dos pilotos rápidos
no A1 são nele.

**Atos 4 a 6 (o freio):** sem suavizar, o expert_full cai a 8% (curva
uniforme). Com a escada descendo a vida até ×0,85 o expert_full volta a
48% e o chefe mais longo (mago no A6) fica em 13,9 turnos (teto pedido: 15).

**Registrado, não resolvido:** (1) average e expert_fast caem para 2 a 3%.
É o custo direto do pedido ("quem não escolhe estratégia ser punido"): os dois
montam o deck por valor de face. (2) A luta COMUM do A1 não chega a 4 turnos:
vida ×2,4 ou mais no A1 faz o Rei Carniça matar 60 a 67% dos rápidos (bateria
`cand_10_24`); levar a comum a 4 a 6 turnos pede vida separada por tipo de
nó, não `ENEMY_POWER`. (3) Guerreiro expert em 20% contra 57/67 de mago e
ladino: a assimetria de classe do late game já anotada abaixo, agora maior
(morre no A3, 10 de 30, e no A5); conserto por kit/passiva do guerreiro, nunca
pela curva global.

Trava: `love . test_one test_difficulty_floor` (multiplicadores mínimos por
ato, vida que nunca sobe de um ato pro seguinte, chefe de cada ato mais forte
que o anterior, entrada de ato ≥ 75% da comum do fim do anterior, e a 1ª luta
do A1 por classe × inimigo × seed: naive leva ≥ 4/2/3 turnos com G/M/L, nunca
fecha em 1 turno e ninguém morre nela). `love . test_one test_difficulty_floor measure`
imprime a tabela de vida/dano por ato e a 1ª luta.

## Oferta do dia (Loja v3 F4, 13/Out/2026): medida e LIGADA por UX

`Config.Offers.DAILY_SALE` (**true** desde 13/Out/2026, decisão do dono):
1 oferta da vitrine da loja sorteada no stream `shop` sai a −25%
(`offer.saleDiscount`, `basePrice`, `cost = floor(cheio × 0,75)`), reroll
re-sorteia, viaja no save (`ShopSystem:applyDailySale`, trava
`test_shop_sale`). Bateria única em b82efa13 (flag ainda desligada no
default, ligada pelo env): `python tools/balance.py --runs 30 --classes all
--pilots average,expert_full --env BALANCE_SHOP_SALE=1 --label shop-sale
--procs 6` (`reports/balance/shop-sale`, seeds 720000+, 31 min), contra o
HEAD sem env (`head-sustain-fog-full` / `head-sustain-fog-fast`, mesmas
seeds).

| classe | piloto | HEAD sem env | oferta do dia | dif | IC 95% da dif |
|---|---|---|---|---|---|
| guerreiro | average | 13% [5–30] (4/30) | 13% [5–30] (4/30) | +0 pp | [−17, +17] |
| mago | average | 7% [2–21] (2/30) | 7% [2–21] (2/30) | +0 pp | [−13, +13] |
| ladino | average | 13% [5–30] (4/30) | 3% [1–17] (1/30) | −10 pp | [−24, +4] |
| **todas** | **average** | **11% [6–19] (10/90)** | **8% [4–15] (7/90)** | **−3 pp** | **[−12, +5]** |
| guerreiro | expert_full | 60% [42–75] (18/30) | 67% [49–81] (20/30) | +7 pp | [−18, +31] |
| mago | expert_full | 80% [63–90] (24/30) | 83% [66–93] (25/30) | +3 pp | [−16, +23] |
| ladino | expert_full | 83% [66–93] (25/30) | 77% [59–88] (23/30) | −7 pp | [−27, +14] |
| **todas** | **expert_full** | **74% [65–82] (67/90)** | **76% [66–83] (68/90)** | **+1 pp** | **[−12, +14]** |

Economia (por run, só compras PAGAS): average 18,4 → 17,8 compras, $227 →
$211 gastos, $7,73 → $7,28 por carta; expert_full 17,6 → 18,9 compras,
$234 → $243, 0,94 → 1,01 compras por visita à loja. Mortes por ato e turnos
por luta iguais aos da baseline dentro do ruído.

Leitura: **ruído puro.** Nenhuma diferença sai do IC (±13 a ±17 pp por
classe, ±12 pp no agregado); o expert compra 1 item a mais por run e o
average gasta $16 a menos, que é exatamente o desconto de 1 oferta em ~13
lojas. A oferta do dia não é lever de dificuldade, é textura de loja
(etiqueta vermelha, "hoje vale a pena"). **Decisão (dono, 13/Out/2026):
LIGADA por padrão como UX, sem efeito de dificuldade e sem rebalanceamento.**
Pra medir a variante sem ela: `--env BALANCE_SHOP_SALE=0`. Toda bateria a
partir de 13/Out já inclui a oferta do dia; as baselines `head-sustain-fog-*`
e anteriores foram medidas SEM ela (diferença dentro do ruído, acima).


## Classes equilibradas (14/Out/2026)
Motivo: com a curva por ato o bot experiente vencia guerreiro 20%, mago 60%, ladino 63%. Estudo do Slay the Spire em `sts_balance_study.md`. Bateria `python tools/balance.py --runs 30 --classes ... --pilots average,expert_full`, seeds 720000+, selo 0, relatórios em `reports/balance/bal_*` da worktree card-game-balclasses-dev.

| Bateria | Guerreiro | Mago | Ladino | DoT no dano |
|---|---|---|---|---|
| base | 20% | 60% | 63% | 19% |
| c1 veneno decai | 20% | 57% | 70% | 16% |
| c12 + Ímpeto 2 ataques | 30% | 53% | 70% | |
| c123 + multigolpe barato | 30% | 57% | 70% | 15% |
| c1234 + guerreiro 70 de vida | 53% | | | |
| r1 decai + Toxinas cresce 1 | | | 70% | |
| r2 decai + Toxinas fixa (+1 sobre o tier) | | | 50% | |
| r3 Toxinas cresce 1, sem decair | | | 63% | |
| **final (c1234 sem multigolpe + r2)** | **53%** | **53%** | **50%** | |

Final: expert_full 52% [42 a 62], average 1% (era 2%), IC de cada classe cerca de ±17 pp. A causa do ladino era a Toxinas crescendo na luta: mesmo com o veneno decaindo, o reforço que crescia turno a turno mantinha o dano acumulado subindo rápido demais. O decaimento sozinho quase não mexeu no DoT. O multigolpe barato não mudou o guerreiro e foi descartado. Valores adotados: `Enemy.POISON_DECAY = true`, `Game.TOXIN_GROWTH = 0`, `Game.ROGUE_POISON_OFFSET = 1`, `Game.IMPETUS_ATTACKS = 2`, `Config.Game.CLASS_MAX_HEALTH = { warrior = 70 }`.

## Coringa raro (14/Out/2026): custo aceito, sem compensação

Os coringas de batalha comum carregavam boa parte do poder do bot experiente.
Com a regra nova (`memory/rng_and_offers.md`, comum 4% / elite 40% / mini 40% /
chefe 70%, no máximo 1 por recompensa), bateria 30 runs por classe, seeds
720000+, selo 0, mesmas do `bal_final`:

| Bateria | Guerreiro | Mago | Ladino |
|---|---|---|---|
| bal_final (antes) | 53% | 53% | 50% |
| **regra nova (adotada)** | **37%** | **40%** | **30%** |
| regra no teto das faixas (5/50/50/80) | 37% | 40% | |
| regra + vida do inimigo ×0,9 nos atos 2 a 6 (DESCARTADA) | 43% | 43% | 40% |

expert_full médio 52% → 36%, abaixo da banda 40 a 60; average segue 0 a 3%.
Subir elite e chefe não devolve nada: o poder estava nos coringas de batalha
comum. A compensação no inimigo chegou a entrar no commit 00e45581 e foi
revertida em seguida por decisão do DONO: "tira os coringas dos drops mesmo;
pode seguir com a minha ideia inicial, porque a gente tem a loja; na loja a
pessoa pode ficar rolando para comprar coringas e fazer economia para isso".
Ou seja: o coringa agora vem da loja (rolagem + economia) e a queda do bot é
custo aceito, não defeito a corrigir em `ENEMY_POWER_BY_ACT`. O piloto
experiente provavelmente subestima o jogador aqui, porque não poupa ouro nem
rola a loja atrás de coringa. Outra frente (coringa-chefe) vai somar um
coringa próprio por chefe, o que devolve parte do poder. Relatórios em
`reports/balance/cr*_*` da worktree card-game-coringararo (cr3/cr4 = a
compensação descartada).

## Mecânica própria dos chefes 2-6 (15/Out/2026)

Com as mecânicas de [[boss_mechanics]] (runas, correntes, geada, raízes, lua),
mesma bateria da base (30 runs/classe, seeds 720000, average + expert_full):
expert_full base 37/30/40 (G/M/L, média 36%) → **27/40/47 (média 38%)**;
average 3/0/3 sem mudança. Números finais e mortes por chefe na seção
"Balanceamento" de memory/boss_mechanics.md.
