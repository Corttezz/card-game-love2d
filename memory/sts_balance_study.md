---
name: STS Balance Study (REA + fonte descompilada)
description: Out/2026. Estudo de balanceamento do Slay the Spire (personagens, curva de poder das cartas por raridade, escala de inimigos por ato, motores e limites de combo, equilíbrio entre classes) confrontado com o Grimoire; responde por que o guerreiro vence 20% e o ladino 67% (veneno nosso é CÚBICO, o do StS é no máximo quadrático) e lista 8 propostas medíveis. Inclui o que o REA fez de fato.
type: reference
---

# Estudo de balanceamento do StS e confronto com o Grimoire (14/Out/2026)

Pedido do dono (literal): *"quero que você rode o REA no Slay the Spire para ver
a questão de balanceamento de personagens, de escala de poder, de combos,
entender como funciona tudo"*. Regra de sempre ([[STS Source Reference]]):
estudar ESTRUTURA, ALGORITMOS e NÚMEROS; nada de código, texto ou arte do StS
no jogo. Nomes de cartas do StS aparecem aqui só como referência de estudo.
Nada foi implementado; as propostas (seção 7) são para o dono decidir.

## 1. O que o REA fez (e se valeu a pena)

- Instalado pela via oficial (`npm install --global rea-agents`, v6.5.0).
  `rea setup` NÃO foi aplicado: altera `~/.claude.json` e instala skill, pede
  aprovação. Só o `--dry-run` rodou (plano: registrar o MCP do Claude Code e
  instalar a skill em `~/.claude/skills/reverse-engineer-anything`). **Setup do
  MCP ficou pendente** (decisão do dono).
- `rea doctor`: nenhum motor de análise configurado. O caminho de Java do REA é
  o JADX (`REA_JADX_MCP_JAR` = jadx-headless-mcp 0.7.1, que o REA não baixa) e é
  voltado a APK/DEX; Ghidra/IDA/Hopper também ausentes. Nada foi baixado.
- O que rodou sem motor: `rea inspect-artifact desktop-1.0.jar` (21 s): inventário
  com evidência (SHA-256 do jar `cfad868a…1673`, 11.435 entradas, grafo com
  hash por nó). Contagem de classes por pacote bateu **exatamente** com a fonte
  CFR já descompilada: cartas 75 red / 75 green / 76 blue / 77 purple / 39
  colorless / 14 curses; monstros 28 / 20 / 17 / 3 (exordium / city / beyond /
  ending); 187 relíquias; 124 powers; 7 classes de personagem. Isso prova que a
  descompilação está completa (nenhuma classe de balanceamento faltando).
- Veredito honesto: o REA acrescentou **prova de integridade e inventário
  rastreável**, não números. Para balanceamento, ler o Java descompilado com
  scripts (parser de cartas em Python sobre `cards/<cor>/*.java`) foi muito mais
  rápido. Para um jar Java o REA só vale com o JADX configurado, e mesmo assim o
  ganho sobre o CFR que já temos seria pequeno.

## 2. Personagens do StS (characters/*.java, relics/*.java)

| | vida | energia | deck inicial | relíquia inicial (em números) | motor de escala |
|---|---|---|---|---|---|
| Ironclad | 80 | 3 | 5 ataque 6 · 4 defesa 5 · 1 golpe 8 dmg + 2 Vulnerável (2 E) | cura 6 ao fim de toda luta (≈ +7,5% da vida por luta) | Força (flat por GOLPE) × multigolpe; exaurir |
| Silent | 70 | 3 | 5 · 5 · bloqueio 8 com descarte · ataque 0 E 3 dmg + 1 Fraco | compra +2 cartas no 1º turno | Veneno (decai 1 por tick), lâminas geradas, Destreza |
| Defect | 75 | 3 | 4 · 4 · canaliza Raio · evoca 2× | canaliza 1 Raio no início (3 por turno, 8 ao evocar) | Foco × orbes (3 slots); Raio 3/8, Gelo 2/5, Sombra 6 crescente, Plasma 1/2 energia |
| Watcher | 72 | 3 | 4 · 4 · 9 dmg entra em Ira (2 E) · 8 bloq entra em Calma (2 E) | carta 0 E de +1 energia na mão | posturas: Ira ×2 dano dado e recebido, Calma +2 E ao sair |

Os números iniciais são quase iguais (6 de dano, 5 de bloqueio por 1 E). O
equilíbrio entre os quatro vem de três alavancas: **vida** (80 a 70), **relíquia
inicial** (sustento × tempo × motor) e o **teto do motor**. O Ironclad tem a
maior vida e a cura por luta porque o motor dele (Força) só rende com
multigolpe e custa tempo; o Silent tem a menor vida e compensa com mão maior.

## 3. Curva de poder das cartas (parser sobre as 288 cartas de classe)

Média de dano por energia (ataques de custo ≥ 1, sem condicionais) e bloqueio
por energia:

| raridade | dano/E | bloqueio/E | upgrade típico | ataques/perícias/poderes por classe |
|---|---|---|---|---|
| básica | 5 a 6 | 4,5 a 6,5 | +37 a 50% | inicial |
| comum | **7,3** | **6,1** | +37 a 43% do dano, +35 a 55% do bloqueio | ~10 / 8 / 0 |
| incomum | **7,5** | **6,2** | +33 a 40% | ~11 / 17 / **8** |
| rara | **9,2** | (poucas) | +28 a 36% | ~4 / 8 / **6** |

- **A rara não vale pelo número**: comum e incomum têm o MESMO dano por energia;
  a rara ganha só +25% no valor de face. Raridade compra MECÂNICA (poderes,
  multiplicadores, motores), não dano bruto. Poderes (efeito para o resto da
  luta) são 0 nas comuns e ~8 nas incomuns de cada classe.
- Upgrade é UMA vez por carta (exceto 1): +2 a +4 de dano, +3 de bloqueio,
  +1 no número mágico, ou −1 de custo em ~13% das cartas (9 a 10 por classe).
- Cartas de custo 0 por classe: 7 a 12; custo X: 1 a 3; exaurir: 13 a 15.

## 4. Escala dos inimigos do StS (monsters/*.java)

Vida / dano em A0 (A7/A8/A9 sobem a vida 3 a 7%; A2/A3/A4 somam 1 a 4 no golpe):

| | ato 1 | ato 2 | ato 3 |
|---|---|---|---|
| comum (ex.) | 40 a 56 · golpe 6 a 12 (um cresce +3 Força/turno) | 75 a 100 · golpe 5×3 a 18 | 48 a 100 por criatura, grupos de 2 a 3 · golpe 8 a 30 |
| elite | 82 a 115 · golpe 14 a 18, Força +2 a +3 | 140 a 172 · 6×N crescente, 21 | 185 a 520 · 30 a 45 |
| chefe | 140 a 250 · pico 32 a 38 | 282 a 440 · 18 a 50 | 250 a 480 · 26 a 40 + escalada |
| coração | | | 750 (máx. 300 de dano por turno) |

- Vida ×2 por ato nas comuns, dano ×1,7; **dentro do ato a vida é PLANA**
  (as 3 primeiras lutas vêm de uma lista fraca, depois lista forte, sem rampa
  andar a andar).
- O que cresce DENTRO da luta é o inimigo: Força por turno (ritual, chefes que
  se fortalecem), bloqueio e fases. A luta longa pune quem não tem motor.
- Turnos por luta deduzidos das contas (saída do deck: ~13/turno no ato 1,
  ~30 no 2, ~50 no 3): **comum 3 a 4 turnos em todos os atos**, elite 4 a 6,
  chefe 8 a 10. A duração das lutas normais NÃO cresce ao longo da run; o deck
  acompanha o degrau de cada ato.

## 5. Motores e limites de combo no StS

| motor | mecânica | crescimento | freio |
|---|---|---|---|
| Força × multigolpe | +N por GOLPE; 2×5, 3×3, 4×2 a 1 E; pesada conta a Força ×3 (×5) | Força +2 imediata (incomum), +2 por turno (rara, 3 E) → dano acumulado **quadrático** | custo 3 E do poder, multigolpe espalhado nas comuns, Força temporária (perde no fim do turno) |
| Veneno × catalisador | N de veneno tira N e cai para N−1 (total N(N+1)/2); +2/turno com o poder incomum; catalisador dobra (×3 forjado) e exaure | líquido +1 por turno com o poder → acumulado quadrático; picos pelo catalisador | **decai sozinho**, teto 9999, catalisador exaure |
| Foco × orbes | Foco soma no passivo e na evocação de cada orbe; 3 slots | +1 Foco por carta incomum; dobra pela evocação | slots limitados, evocar empurra o mais antigo, consumir Foco tira slot |
| Exaurir × gatilhos | +3 bloqueio e +1 compra por carta exaurida | proporcional a cartas queimadas | a carta queimada some do combate |
| Postura de Ira | ×2 dano dado E recebido | imediato | risco: recebe ×2 |

Contra combo infinito: energia 3 fixa; cartas de energia/compra fortes
EXAUREM; poder de ganho por turno custa 3 E (paga em tempo, no turno em que o
inimigo bate); inimigos que encerram o turno após 12 cartas, que ganham Força
quando você joga poder, que limitam 300 de dano por turno; Força e Destreza
temporárias; upgrade único. **Nenhum motor do StS passa de quadrático no dano
acumulado** e todos exigem investimento de deck.

## 6. Confronto com o Grimoire

Números nossos: `src/core/Config.lua` (`ENEMY_POWER_BY_ACT`), `src/systems/ActSystem.lua`,
`src/core/Game.lua` (passivas), `src/data/cards/*.lua`, bateria `final_full`
de 14/Out (worktree `card-game-dificuldade2`, `reports/balance/final_full`).

### 6.1 Personagens
Todos com 60 de vida, 3 de mana, mão 5, deck inicial de 2 cartas. A única
diferença entre classes é a passiva: guerreiro **Ímpeto** (+1 Força no turno
com 3+ ataques), mago **Conduíte** (Raio 4 + Foco 0/1/2 por par de atos),
ladino **Toxinas** (veneno no 1º ataque do turno, +2 por turno com 2+ ataques).
Divergência: o StS usa vida e relíquia para compensar classe; nós não usamos
nenhuma das duas.

### 6.2 Curva das cartas
Valor por mana (ataque e defesa custo ≥ 1): comum 6,0 a 7,0 · incomum 4,1 a 7,5 ·
rara 7,0 a 9,7. Parecido com o StS no comum. Diferente: a rara de ataque do
guerreiro vale +60% no valor de face (9,7 contra 6,0), o StS dá +25%; e a
forja é infinita e plana (+2 de ataque/defesa ou +1 no efeito por nível,
`Config.Offers.FORGE_*`), o StS forja uma vez só.

### 6.3 Inimigos (vida / golpe base, `ActSystem.getEnemyStats` com a curva atual)

| ato | comum andar 1 → 8 | elite (andar 5) | mini-chefe | chefe |
|---|---|---|---|---|
| 1 | 28 → 112 · 4 → 12 | 106 · 11 | 154 | 220 |
| 2 | 126 → 252 | 316 | 277 | 396 |
| 3 | 239 → 391 | 553 | 426 | 609 |
| 4 | 312 → 489 | 724 | 482 | 690 |
| 5 | 391 → 604 | 923 | 585 | 836 |
| 6 | 514 → 782 | 1234 | 714 | 1020 |

- **Rampa dentro do ato**: a comum quadruplica do andar 1 ao 8 no A1 (28 → 112)
  e dobra no A2; o StS é plano dentro do ato. A elite do andar 5 do A1 (106)
  tem MENOS vida que a comum do andar 8 (112).
- **Escala total**: comum ×18 do 1º andar ao fim (×7 do fim do A1 ao fim do A6),
  chefe ×4,6. No StS: comum ×4, chefe ×2 a 2,5 em 48 andares.
- A escada `A1 ×2,0 … A6 ×0,85` não é incoerente com o StS, ela é um
  REMENDO de uma base cuja vida cresce rápido demais: ela achata a ponta, mas o
  resultado continua sendo lutas que alongam a cada ato (turnos/luta 4,1 · 6,7 ·
  7,4 · 7,9 · 8,5 · 8,8; chefes 7,5 a 11,1). No StS a comum dura 3 a 4 turnos
  do começo ao fim. **Luta que alonga a cada ato premia motor por turno e pune
  dano por carta** (ver 6.5).

### 6.4 Combos simples × motores do StS
Saraivada / Muralha / Par dão bônus PLANO por posição dentro da jogada e zeram
no turno seguinte (19% do valor dos ataques no `final_full`). Eles não são
motores: não acumulam entre turnos, não crescem com a luta e não escalam com o
ato. Funcionam como o "conte quantas cartas você jogou" do StS (recompensa de
sequência), papel útil no início; no A5 e A6, com 600+ de vida, +3/+6 por golpe
some. Os motores de verdade no nosso jogo são a Força (guerreiro), o Foco/orbes
(mago) e o veneno (ladino), e só um deles está bem calibrado.

### 6.5 Por que o guerreiro vence 20% e o ladino 67%

1. **O nosso veneno é cúbico.** No StS o veneno decai 1 por tick. No nosso,
   `Enemy:addStatusEffect` SOMA os stacks e SOMA as durações, e `onTurnEnd` tira
   os stacks inteiros todo turno sem reduzir nada: cada carta de veneno vira dano
   permanente pelo resto da luta. A passiva Toxinas aplica `tier + 2k` stacks no
   turno k (com 2+ ataques), duração +2 por aplicação (nunca expira). Stacks no
   turno n: n² + 2n (tier 1) a n² + 4n (tier 3). Dano acumulado só da passiva
   em 7 turnos no A1/A2: **196** (o chefe do A1 tem 220); em 8 turnos no A5/A6:
   **348** (comum do A6: 514 a 782). Tudo ignora o Bloqueio do inimigo (DoT).
   No `final_full`, DoT é 19% de TODO o dano das três classes, praticamente todo
   do ladino (≈ metade do dano dele, estimativa).
2. **O Ímpeto é linear e condicional.** +1 Força por turno SE jogar 3 ataques.
   Com ~3 golpes por turno, extra acumulado em 8 turnos ≈ 3 × (1+…+8) = 108,
   um terço da Toxinas, e falha em todo turno com um ataque de 2 mana (bash,
   heavy_blade, twin_strike, cleave custam 2).
3. **Falta multigolpe barato ao guerreiro.** No StS a Força vale por GOLPE, e
   o Ironclad tem 3 ataques de multigolpe a 1 E nas comuns/incomuns (2×5, 3×3, 2×4) e um de custo X. O nosso
   guerreiro tem UM multigolpe (`warrior_twin_strike`, 2 mana, 7×2); nos
   ataques de custo ≥ 1 ele tem 1 incomum (contra 7 defesas incomuns). Cada
   ponto de Força rende ~2 a 3 de dano por turno, contra 4 a 6 no Ironclad.
4. **Bloqueio e cura dos chefes punem dano por carta.** O que mais mata o
   guerreiro é o A3 (10 de 30) e o `rot_colossus` do A5 (regenera 1,5%/turno,
   cura 5% e ganha Bloqueio 0,8×). Dano plano bate no Bloqueio; o veneno passa.
5. **Sem compensação de classe.** O Ironclad tem 80 de vida e cura 6 por luta
   porque o motor dele é o mais lento; o nosso guerreiro tem os mesmos 60 de
   vida das outras classes.
6. Sinal da bateria: os guerreiros que vencem são os que pegaram motor de
   Força (`warrior_rage` +50 pp, `warrior_demon_form` +38 pp, `warrior_heavy_blade`
   +38 pp, `warrior_bash` +40 pp no corte da batalha 9); sem motor o guerreiro
   não fecha luta longa.

## 7. Propostas priorizadas (nada implementado)

Medir sempre com `python tools/balance.py --runs 30 --classes all --pilots
average,expert_full` (seeds 720000+, selo 0) contra a base `final_full`
(G20 · M57 · L67, average 2%); diferença só é sinal acima de ~15 pp por classe.
Knob novo de env (padrão = jogo atual) antes de cada bateria, como os
`BALANCE_*` existentes.

1. **Veneno com decaimento (fonte: StS)** em `Enemy:onTurnEnd`: após o tick,
   stacks −1 (ou durações não somam: `max` em vez de `+`). Knob
   `BALANCE_POISON_DECAY`. Alvo: ladino expert 67% → 45 a 60%, DoT 19% → ≤ 12%
   do dano total. Se cair demais, compensar com a Toxinas mais forte no início
   (tier +1), nunca devolvendo o crescimento cúbico.
2. **Ímpeto com 2 ataques** (`Game.IMPETUS_ATTACKS` 3 → 2; já medido 67% antes
   dos combos simples, com a curva antiga). Knob `BALANCE_IMPETUS`. Alvo:
   guerreiro expert 20% → 40 a 55%, Força na composição do ataque (16% hoje,
   todas as classes) ≥ 25% no guerreiro.
3. **Multigolpe barato no guerreiro**: `warrior_twin_strike` custo 2 → 1 com
   5×2 (+2 de forja vira +4), e 1 a 2 cartas comuns de 3×2/2×3 a 1 mana no
   lugar de defesas incomuns duplicadas. Alvo: golpes por turno do guerreiro
   ≥ 3 no A3 a A6 (medir no `battleLog`), +10 pp no guerreiro.
4. **Vida por classe como compensação** (padrão StS): guerreiro 70, mago e
   ladino 60 (`Player.new` lendo um mapa por classe; hoje `BALANCE_PLAYER_HP` é
   global). Alternativa equivalente: guerreiro cura 4 ao fim de cada luta. Alvo:
   vida perdida/luta do guerreiro no A3 e no A5 −25%, +5 a +10 pp.
5. **Achatar a rampa dentro do ato** e mover o crescimento para o DEGRAU entre
   atos (`act.enemyHP(floor)` com metade da inclinação e base maior), elite ≥
   1,3× a comum do mesmo andar. Knob por `Config.Acts`. Alvo: comum com 3 a 5
   turnos em TODOS os atos (hoje 4,1 → 8,8), chefe 7 a 10; expert_full e
   average dentro das bandas de [[Bandas-alvo de dificuldade (StS)]].
6. **Combos que acompanham o ato**: passo da Saraivada/Muralha/Par por ato
   (ex. 3 · 4 · 5 · 6 · 7 · 8, ou % do valor da carta) via `BALANCE_COMBO`
   por ato. Alvo: parte "combo" do valor do ataque estável entre A1 e A6
   (pedir ao relatório a quebra por ato).
7. **Rara pela mecânica, não pelo número**: trazer a rara de ataque do
   guerreiro para ~+25% sobre a comum (`warrior_feed` 12 por 1 mana com cura 8 é a mais acima) e gastar a
   diferença em efeito (Força, multigolpe). Alvo: menor distância average ×
   expert (average 2% hoje, banda 12 a 25%), já que o average pega pelo valor
   de face.
8. **Freio de forja em efeito de Força**: forja infinita +1 em `gain_strength`
   (`war_cry` +4 vira +9 em 5 níveis por 1 mana) é o caminho de runaway se o
   guerreiro for consertado pelos itens 2 e 3. Limitar a 1 nível os efeitos de
   ganho de stat, ou custo de forja dobrado neles. Medir: forjas/run e winrate
   do guerreiro com selo 5+ (o abuso aparece com o expert).

Ordem sugerida: 1 e 2 juntos (o desequilíbrio é dos dois lados), depois 4,
depois 5 (mexe em todas as bandas), 3/6/7/8 conforme o resultado.

Ver [[STS Cards & Synergies]], [[STS Powers Catalog]], [[balance_curves]],
[[combo_rules]], [[enemies]].
