---
name: unlocks
description: Meta-progressão — UnlockSystem (cartas/classes desbloqueáveis, maestria por classe, descoberta), reveal pós-run, Coleção com "?" e a régua de performance da Coleção
type: subsystem
---

# Meta-progressão (UnlockSystem) — Out/2026

Arquivos: `src/systems/UnlockSystem.lua` (lógica), `src/data/unlocks.lua` (dados),
`src/ui/UnlockReveal.lua` (reveal pós-run), `components/CollectionScreen.lua`
(cartas "?"), `tools/test_unlocks.lua`, `tools/screenshot_unlocks.lua`,
`tools/perf_collection.lua`.

## Três conceitos diferentes
- **Desbloqueada** (`isCardUnlocked`) — pode cair em OFERTA. Filtro único em
  `CardRegistry:_poolFor` (rewards + loja + eventos) e `BoosterPackSystem.sortedIds`
  (pacotes). Carta nova de oferta = passar por um desses dois.
- **Descoberta** (`isCardDiscovered`) — o jogador já VIU: ofertada
  (`pickRewardCard`/pacote marcam), possuída (`Game:addCardToRun`) ou no deck
  inicial (`onRunStarted`). Também lê `ProfileStats.cardsSeen` (legado). Só
  descoberta aparece revelada na Coleção; o resto é verso "?" + dica no hover.
- **Classe** — guerreiro sempre; mago = vencer o chefe do Ato 2; ladino = vencer
  o chefe do Ato 4 OU vencer uma run. Metas de ato são CLAMPADAS a
  `Config.TotalActs` (com 3 atos, "Ato 4" = vitória).

## Curva
- Liberado de fábrica: tudo que não está em `src/data/unlocks.lua` (~60% de cada
  classe por raridade: guerreiro 8c/8u/7r, mago 8c/12u/7r, ladino 8c/8u/5r + neutras).
- 5 níveis de MAESTRIA por classe (custos 100/150/200/250/300 = 1000 total), cada
  nível libera um pacote temático de 3 cartas da classe (15 por classe).
- XP da run = 10/andar + 40/ato completo + 150 vitória (+15/andar de endless),
  piso 20. Morte no endless só paga o endless (a vitória já pagou a run).
- Marcos neutros (Balatro): joker_001 = chefe do ato 1; joker_002 = chegar ao ato 4
  (clamp); joker_003 = vencer uma run.

## Estado (ProfileStats → `profile.unlocks`)
`{ version, mastery={classe=XP total}, actsCleared, bestActReached, victories,
cards={id=true}, classes={id=true}, discovered={id=true}, migratedLegacy? }`.
Contadores PRÓPRIOS (actsCleared/bestActReached/victories) de propósito: o perfil
atualiza `wins`/`bestAct` no MESMO frame do fim de run e mascararia o "novo".
Concessões são gravadas em `cards`/`classes` — mudar os dados depois nunca
re-trava o que o jogador já ganhou.

**Migração**: perfil com `runs>0` e sem `unlocks` ganha XP retroativo generoso
(runs×40 + wins×300 + bestAct×40, teto 1000) em TODAS as classes, maestria cheia
nas classes de `winsByClass`, `actsCleared = bestAct-1` (vitória = todos) e
`cardsSeen` vira descoberta. Roda em `UnlockSystem.ensure()` (boot do main.lua e
`Game:startNewRun` ANTES do `recordRunStart`, senão o perfil novo vira "antigo").

## Ganchos
- `Game:startNewRun` → `ensure()` + `onRunStarted(classId, deck)`.
- `Game:_onEnemyDeath` (nó boss) → `onBossDefeated(act, game)`: libera classe/marco
  NA HORA com toast; o reveal do fim repete (pendentes da run).
- `Game:checkGameOver`/`checkVictory` (dentro dos guards de uma-vez) →
  `game.unlockResult = onRunEnded(game:_unlockSummary(victory))`, ANTES de
  `recordDefeat/recordVictory`.
- `EndScreens` desenha `UnlockReveal` numa banda própria quando há resultado;
  instrução desce pro rodapé.

## Ferramentas
- Qualquer `love . <arg>` liga `UnlockSystem.setOverrideAll(true)` (main.lua,
  bloco do sandbox): autoplay/balanceamento/smokes medem o catálogo INTEIRO e as 3
  classes. `isClassUnlockedReal/isCardUnlockedReal` ignoram o override (conquistas).
  `setRevealAll(true)` revela a Coleção toda (régua de perf).
- `test_unlocks` desliga o override e usa perfil falso (`ProfileStats._swapForTests`).

## Performance da Coleção (medido com `love . test_one perf_collection`, 1024×768)
Causas achadas:
1. **1º hover de cada carta** montava o set animado inteiro num frame: 9 PNGs do
   disco + 8 composições completas (~3ms cada) = 8–23ms de engasgo; varrer o grid
   = gagueira contínua.
2. `IconFramesLoader.has()` chamava `get()` — carregava os 9 PNGs de TODA carta
   que entrava na tela (CardAnimationLayer pergunta `has` por carta/frame): pico
   de 23–78ms ao rolar.
3. `animCache` sem teto: toda carta já hoverada seguia sendo blitada no
   `CardFrame.update` pra sempre (fica mais lento quanto mais se olha).
4. ~30 shader switches/frame: o warp roda em carta parada, onde é identidade.

Correções: `has()` só olha o frame 0; `IconFramesLoader.getIncremental` (1 PNG
por chamada) + `CardFrame.liveImage` progressivo (1 composição por chamada; até
lá mostra o estático = frame 0); `update` só blita animação pedida nos últimos
0,35s + teto LRU de 24 sets; carta parada sem shader/mesh. Carta "?" não compõe
canvas.

| cenário | antes (p95 / máx) | depois (p95 / máx) | shader sw/f |
|---|---|---|---|
| idle   | 0.70 / 4.5 ms  | 0.6 / 1.5 ms | 30 → 0 |
| hover  | 8.1 / 11–14 ms | 1.3–3.6 / 3–6.5 ms | 30 → 2 |
| scroll | 6.4 / 23–78 ms | 1.5–2.9 / 2–5.4 ms | 37 → 1.8 |
(Medições com outros agentes rodando na máquina; o ruído é de ±1ms.)
