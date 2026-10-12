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
| bancada de coringa (2/run) | $30, $60 | **$20, $35** (peso 0.9 → 1.3) |
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
A frequência da bancada na vitrine quase não mexeu com o peso 1.3 (22→24%):
se o dono ainda sentir falta dela, o próximo passo é vaga própria, não preço.
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
