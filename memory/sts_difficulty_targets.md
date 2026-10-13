---
name: Bandas-alvo de dificuldade (estudo do Slay the Spire)
description: Out/2026. O que o StS entrega em curva de inimigo, estrutura de run, economia, deck e taxa de vitoria por nivel de jogador (fonte descompilada + dados publicos), traduzido em BANDAS-ALVO por piloto (naive/average/expert) e no mapa 6 atos × 8 andares ↔ 3 atos × 16 do StS. Insumo do sweep (tools/balance_tune.py, tools/balance_targets.json).
type: project
---

# Bandas-alvo de dificuldade — o que o StS faz e o que queremos igualar

Pedido do dono: *"analisar como funciona o Slay the Spire para termos o mesmo
nível de dificuldade para chegar ao fim, algo parecido"*. Estudo SÓ de números
e estrutura (fonte descompilada em `E:\dev\projects\slay-the-spire-source`,
zero cópia) + dados públicos de jogadores. Detalhe por arquivo/linha no estudo
bruto (scratch da sessão); aqui ficam os fatos que calibram o NOSSO jogo.

## 1. O StS em números (A0)

| | ato 1 | ato 2 | ato 3 |
|---|---|---|---|
| vida da luta normal (mediana) | ~50 | ~110 | ~200 |
| dano/turno da luta normal | ~11 | ~20 | ~30 |
| elite: vida / dano por turno | 85–120 / 14–20 | 150–165 / 20–30 | 185–520 / 30–45 |
| chefe: vida / pico num turno | 140–250 / 32–38 | 282–420 / 45 | 456–600 / 40–70 |
| primeiras lutas vêm da pool FRACA | 3 | 2 | 2 |

Vida ×2 por ato, dano ×1,7. Ascensão é **escada de regras**, não multiplicador:
A1 +60% de elites; A2/A3/A4 +1–2 de dano por golpe (normal/elite/chefe);
A7/A8/A9 +3–7% de vida; A5 cura entre atos 75% do que falta; A6 começa com 90%
da vida; A11 −1 poção; A12 metade das cartas forjadas na recompensa.

**Jogador:** 80/70/75/72 de vida, 3 energia, 5 cartas, Bloqueio zera por
turno; **cura TOTAL entre atos (A0–A4)**; fogueira 30%; 99 de ouro.

**Mapa:** 15 linhas + chefe = 16 andares/ato, 48 na run. Por ato: ~8 lutas
normais + 1–2 elites + 1 chefe + 1–2 descansos (1 fixo antes do chefe) + 2–3
eventos + 0–1 loja + 1 baú. Chances: loja 5%, descanso 12%, evento 22%, elite
8% (×1,6 em A1+).

**Economia:** 10–20 de ouro por luta, 25–35 elite, ~100 chefe (≈250–300/ato);
carta 50/75/150, remoção 75 (+25 por uso); recompensa = 3 cartas, rara 3% /
incomum 37% / comum 60% com pity; carta já forjada na recompensa 0% → 25% →
50% por ato.

**Deck:** 10 iniciais → 25–35 nas vitórias (moda 30; "25–35 = mais da metade
das vitórias", 190 decks em slaythespire.info). ≈ 6–7 cartas pegas por ato de
~11 ofertadas (metade é PULAR), 2–4 remoções na run.

**Tempo:** vitória de 3 atos 35–60 min (Ironclad ~31, outras ~40–43; "no
máximo 1 h"); derrota de novato 20–30 min; ≈ 45–70 s por andar.

## 2. Quem vence o StS (dados públicos)

| métrica | valor | fonte |
|---|---|---|
| taxa de vitória POR RUN em A0, todos os jogadores | **~9%** | Mega Crit, Neowsletter mai/2026 (via 3 fontes secundárias concordantes) |
| idem A20 | ~3% | idem |
| donos na Steam que mataram um chefe do ato 1 / ato 2 / venceram o jogo alguma vez | 85% / 71% / **66%** | conquistas globais Steam (lidas 2026-10-12) |
| venceram o Coração / completaram A10 / A20 | 13% / 15% / 7% | idem |
| veterano em A0 (auto-relato) / elite em A20 | ~85–95% / ~40–70% | fóruns, Manifold |
| onde o intermediário morre (diário de 61 derrotas, Ironclad) | ato 1 28% (quase só chefes) · **ato 2 61%** (elites + Collector) · ato 3 7% · Coração 5% | blog de jogador |

Leitura: **a run média de A0 é derrota (91%)**, mas quase todo mundo que
persiste vence alguma vez (66%). O filtro grande é o ATO 2; o novato morre no
CHEFE do ato 1 (não nas lutas normais); o experiente só morre no ato 3.

## 3. Mapa 6×8 (nosso) ↔ 3×16 (StS)

Mesmos 48 andares. Cada par de atos nosso ≈ um ato do StS: **A1+A2 ↔ Exordium,
A3+A4 ↔ City, A5+A6 ↔ Beyond.** O nosso ato é um "meio-ato" com chefe próprio
(e mini-chefe no andar 7), então temos **6 chefes + 6 mini-chefes** onde o StS
tem 3 chefes — cada chefe nosso deve pesar ~metade de um chefe do StS em tempo
e risco (4–8 turnos, não 10+). Equivalências de ritmo:

| nosso | StS | o que igualar |
|---|---|---|
| A1 (andares 1–8) | 1ª metade do Exordium | pool fraca, luta de 2–3 turnos, quase 0 de dano sofrido; chefe do A1 ≈ elite do ato 1 do StS |
| A2 | 2ª metade do Exordium + chefe | 3–4 turnos; **chefe do A2 = primeiro muro** (StS: Guardian/Hexaghost matam o novato) |
| A3–A4 | City | 4–6 turnos; debuffs no jogador em quase toda luta; **aqui morre o intermediário** |
| A5–A6 | Beyond | 6–8 turnos; escaladas que punem luta longa; só o expert chega |
| vida entre atos | cura total no StS | nós curamos 30–40% a cada ato (6×) ≈ 2 curas totais do StS espalhadas — manter |
| deck | 10 → 30 | **2 → 10–14 (expert) / 17–19 (quem pega sempre)** — nosso andar oferece carta GRÁTIS em toda batalha; o skip é o que separa os pilotos |

## 4. BANDAS-ALVO por piloto (o que o sweep persegue)

Pilotos em `tools/autoplay.lua` (`M.PILOTS`), bandas em
`tools/balance_targets.json` (lidas por `tools/balance_tune.py`).

| piloto | quem representa | vitória (selo 0) | mortes concentradas em | duração |
|---|---|---|---|---|
| **naive** | soca o que der, ignora intent, pega toda carta, loja impulsiva, caminho ao acaso | **< 5%** | A1–A2 (chefe do A1/A2, não as lutas normais) | derrota em 10–20 min |
| **average** | heurística razoável com erros: passos v5 no combate, pega carta por raridade/afinidade, pula só com deck > 18 | **12–25%** | A2–A4, maioria no A3 (= City) | derrota 20–35 min; vitória 55–75 |
| **expert_fast** | busca de combate v6 + deck por "melhora a média" | **30–50%** | A3–A5 | — |
| **expert** | v6 + deck por simulação (joga as próximas lutas com e sem a carta) | **45–60%**, caindo ~5 pp por selo | A5–A6 (chefe final) | vitória 45–70 min |

Por que essas e não as do StS cru: o StS A0 "todos os jogadores" dá 9% por
run, mas inclui a primeira hora de quem nunca jogou um deck-builder; nosso
`average` é um jogador que já entende intent e defesa (o v5 defende contra o
golpe anunciado), por isso a banda sobe para 12–25%. O `expert` fica abaixo do
veterano humano do StS (~90% em A0) de propósito: os selos (1–10) são a escada
para quem quer mais — selo 10 deve levar o expert para ~15–25% (hoje medido
20% no guerreiro, ver [[endless_and_seals]]).

**Regra de leitura:** ruído com 30 runs é ±9 pp (IC 95% Wilson). Comparar
bandas pede ≥ 60 runs por célula; o sweep roda 30–40 por ponto e só as
diferenças > 15 pp são sinal.

## 5. Primeira medição contra as bandas (HEAD de 12/Out/2026, selo 0)

`python tools/balance.py --runs 30 --pilots naive,average,expert_fast` e
`--runs 8 --pilots expert`:

| piloto | vitória | onde morre | deck final |
|---|---|---|---|
| naive | 0/90 | A2 79%, A3 21% | 13–15 |
| average | 0–2% | A2 32–40%, A3 42–44%, A4 9–22% | 17–18 |
| expert_fast | 0/90 | A3 43–49%, A4–A5 25% | 18–19 |
| expert (deck por simulação) | **25%** (6/24) | A3–A6 espalhado | **10–13** |

Veredito: naive e expert_fast estão abaixo da banda; average ESTÁ abaixo
(0–2% contra 12–25%) e morre um ato antes do alvo; o expert está abaixo
(25% contra 45–60%). A diferença entre os pilotos é quase toda o TAMANHO DO
DECK — o jogo está calibrado para quem pula metade das cartas. Alavancas na
mão do dono dos números ([[combo_rules]], [[balance_curves]]): força do
inimigo nos atos 2–3 (muro do tower_lich: 62 das 270 mortes dos pilotos
rápidos), e o custo de inchar o deck (carta média mais forte OU recompensa
que não obriga a pegar). O sweep (`tools/balance_tune.py`) mede a primeira;
a segunda é decisão de design.

## 6. Stage 2 (Out/2026) — o que o sweep decidiu e o que ficou aberto

Medido com o pipeline instantâneo (`memory/balance_curves.md`, seções
"Calibração", "Sweep A", "Sweep B/C"):

| piloto | banda | HEAD (0,8/0,85) | **adotado: 0,75/0,8 + A3 ×0,9** | onde morre |
|---|---|---|---|---|
| naive | <5% | 0 / 0 / 0 | 0 / 0 / 0 | A2–A3 ✓ |
| average (normal) | 12–25% | 0 / 0 / 0 | 10 / 0 / 7 | A3–A5 (alvo A2–A4 ~, taxa ✗) |
| expert_fast | 30–50% | 3 / 0 / 0 | 13 / 0 / 0 | A3–A5 ✓ (taxa ✗) |
| expert_full | 45–60% | 53 / 57 / 43 | **57 / 53 / 53** | A5 (Colosso) ✓ |

(G / M / L, 30 runs por célula, ±17 pp.) Lutas tardias no adotado: A5 7,4
turnos, A6 9,0 (chefe 11,4) — na banda 7–10, chefe do A6 ainda longo.
Duração estimada do expert_full 73 min (vitória 84) contra 45–70 do alvo.

**O que NÃO se resolve no inimigo:** average e expert_fast ficam fora da
banda em toda a grade (0,8 → 0,55; mão 6; mana 4) — o average v5 só troca a
morte de A2 por A3/A5. O diagnóstico por turno mostrou que o average lê o
intent e gasta a mana; perde por falta de SUSTENTO e por escolher carta pelo
valor de face (o expert_full escolhe cura, básicas baratas, forja 3× mais e
segura carta). Ou seja: as bandas 12–25 / 30–50 pedem mudança de DESIGN (cura
mais acessível, forja mais barata/frequente, ou cartas de valor-de-face que
valham o que mostram), não mais nerf de monstro — abaixo de 0,7 o expert_full
sai da banda por cima. Selos continuam sendo a escada pra quem quer mais.
As três propostas concretas (cura garantida cedo, descanso 40% / poção,
elite do 1º andar mais branda) estão em [[balance_curves]] ("Propostas pro
dono") — decisão do dono, nada aplicado.

Ver [[balance_pipeline]] (como medir), [[balance_curves]] (números atuais),
[[sts_run_economy]] / [[sts_progression_config]] (StS em detalhe).
