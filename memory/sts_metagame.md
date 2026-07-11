---
name: STS Metagame
description: Menu principal, seleção de personagem, 48 achievements (e como triggeram), unlock progressivo (5 níveis/classe), fórmula completa de score, stats, run history e Daily Climb do Slay the Spire.
type: reference
---

# STS — Metagame (menu, conquistas, unlocks, score, daily)

Fonte: `screens/mainMenu/` (17 classes), `unlock/` (66), `screens/stats|runHistory|charSelect`, `localization/eng/achievements.json` + `score_bonuses.json` + `run_mods.json`.

## Menu principal (MainMenuScreen)

Botões (de baixo pra cima na coluna): **Play/Abandon Run** (troca se há run ativa) → **Resume** (só com save) → **Compendium** (biblioteca de cartas/relíquias/poções) → **Statistics** → **Settings** → **Patch Notes** → **Quit**. Fundo = cena animada (TitleBackground) + som ambiente de vento em loop. Versão do build no canto. Statistics/Compendium só aparecem depois da 1ª run (progressive disclosure).

Fluxo Play: painel de modos (**Standard / Daily Climb / Custom**) → CharSelect: portrait GRANDE por classe + preview de **HP, gold inicial, relíquia inicial e deck inicial** + **seletor de Ascension** (setas ±, nível + descrição do que muda, só até o nível desbloqueado+1) + **input de seed customizada** (base-36) + botão Embark. Daily/Custom desbloqueiam com progresso.

## Achievements — 48, e o MECANISMO importa

Categorias: vitória por classe (4) e "ending" por classe, bosses específicos, **desafios de habilidade** (Shrug It Off: vencer com 1 HP; Perfect: boss sem dano; Minimalist: deck ≤5 embarque; Ninja: 10 Shivs num turno; Infinity: 25 cartas num turno; Jaxxed: 50 Strength; Impervious: 99 block; Catalyst: 99 poison; Adrenaline: 9+ energia; The Pact: exaurir 20 num combate; Come At Me: vencer sem jogar ataque; Purity: ≤3 cartas restantes; Speed Climber: <20min; You Are Nothing: matar boss no turno 1), progressão de Ascension (A0/A10/A20) e **Eternal One** (todas).

**Mecanismo**: `UnlockTracker.unlockAchievement("ID")` chamado **inline no ponto exato do código** — GameActionManager conta 25 cartas (INFINITY) e 10 shivs (NINJA), AbstractCreature checa 99/999 block, PoisonLoseHpAction checa 3 envenenados (PLAGUE), FeedAction checa Donu (OOH DONUT). Não há engine central de conquistas observando estado — cada sistema reporta o seu. Toast in-game (UnlockTextEffect) + Steam. Barato e à prova de falso-positivo. **Nosso AchievementSystem já segue exatamente esse padrão** (onBattleWon/onPoisonApplied/...) — validação da nossa arquitetura.

## Unlock progressivo por classe (retenção)

5 níveis por personagem; score da run acumula numa barra (custo inicial 300, escala). Cada nível libera um **bundle temático de 3 itens** (cartas OU relíquias — ex. Ironclad nível 1: Heavy Blade + Spot Weakness + Limit Break). Tela pós-run mostra a barra enchendo (Interpolation.pow2In) + reveal com som "UNLOCK_WHIR". Cartas locked aparecem no compêndio como silhueta "?". Personagens: Silent/Defect/Watcher desbloqueiam jogando. Progresso em Prefs (fora do save da run).

## Score — fórmula completa (GameOverScreen.calcScore + score_bonuses.json)

Base: `floors×5 + inimigos×2 + elites do ato1×10 / ato2×20 / ato3×30 + bosses (50, depois 100, 150...)`.
Bônus de combate: **Champion** +25 (elite sem dano), **Perfect** +50/boss sem dano (3+ → +200 "Beyond Perfect"), **Overkill** +25 (99+ num hit), **C-c-c-combo** +25 (20 cartas num turno).
Bônus de run: **Speedster** +25 (<60min) / **Light Speed** +50 (<45min), **Highlander** +100 (sem duplicatas), **Shiny** +50 (25+ relíquias), ouro acumulado na run: +25/+50/+75 (1000/2000/3000), **Mystery Machine** +25 (15+ salas "?"), **Collector** +25 por carta com 4+ cópias, **Pauper** +50 (0 raras), **Librarian/Encyclopedian** +25/+50 (35/50+ cartas), **Well Fed/Stuffed** +25/+50 (+15/+30 maxHP), **Curses!** +100 (5+ maldições), **Poopy** −1 (pegou a relíquia cocô).
Multiplicador final: **+5% × nível de Ascension**.
Design: o score PREMIA ESTILOS OPOSTOS (deck mínimo E enciclopédia; pobreza E riqueza) — toda run pontua em algo. Nosso ScoreSystem TINTA×SELO já tem essa alma (eficiência/estilo/risco/flawless); o que o StS adiciona de ideia é o **breakdown nomeado e colecionável** (cada bônus tem nome/identidade que o jogador caça).

## Stats & Run History

- StatsScreen global+por classe: vitórias, mortes, win streak, andares, bosses, playtime, melhor tempo, score máximo.
- **Cada run vira arquivo `.run` (JSON)** na pasta `runs/` — path completo, cartas escolhidas POR ANDAR, HP/gold por andar, compras, escolhas de evento, relíquias, seed, tempo. A RunHistoryScreen desenha a timeline da run (nodes + o que aconteceu). É o "replay mental" + material de balance (a Mega Crit usava as métricas agregadas pra balancear).
- Nosso jogo já tem ProfileStats + metrics parciais; formalizar um `.run` file por corrida seria barato (já salvamos card history com timestamps).

## Daily Climb

Seed derivada da DATA (todos jogam a MESMA run) + personagem sorteado + **3 mods** de um pool de 35 (`run_mods.json` — ex.: Lethality inimigos +3 Str/turno, Terminal +5 block/turno, Midas ouro ×2, Careless mill 1/combate, Diverse limita orbs, Night Terrors descanso cura 100% mas custa). Leaderboard do dia (20/página). Sem save-scum (seed + RNG counters). Custo de implementação baixo quando a run é seedável — ver [[STS Progression & Config]].

## → Confronto com o nosso jogo

Temos: menu com intro stagger + floating cards, 20 conquistas data-driven com triggers inline (mesmo padrão StS ✔), ScoreSystem com recibo legível (RoundEvalScreen ✔ — mais transparente que o StS, que só mostra no fim!), ProfileStats com recorde. **Faltam**: Compendium/biblioteca com locked "?", unlock progressivo (nossas 96 cartas todas disponíveis desde o início — não há cenoura de coleção), run history/timeline, daily com seed compartilhada, breakdown de score com bônus NOMEADOS de fim de run (temos multiplicadores, não "troféus com nome"), win streak. Priorização em [[STS Gap Analysis]].
