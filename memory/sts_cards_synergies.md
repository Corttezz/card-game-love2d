---
name: STS Cards & Synergies
description: Sistema de cartas do Slay the Spire — tipos, campos base/atual, ciclo de vida, cálculo ao vivo na UI, upgrades, pilhas, e 15 sinergias emergentes (sem sistema de combo!). Confronto com nosso ComboSystem.
type: reference
---

# STS — Cartas e sinergias emergentes

Fonte: `slay-the-spire-source/src/com/megacrit/cardcrawl/cards/` (AbstractCard.java 2.566 linhas + ~361 cartas).

## Taxonomia (enums de AbstractCard)

- **CardType**: ATTACK, SKILL, POWER (efeito permanente no combate, some ao jogar), STATUS (lixo temporário), CURSE (lixo permanente no deck).
- **CardRarity**: BASIC (starter), COMMON, UNCOMMON, RARE, SPECIAL (geradas: Shiv...), CURSE.
- **CardTarget**: ENEMY, ALL_ENEMY, SELF, NONE, SELF_AND_ENEMY, ALL.
- **CardColor**: RED/GREEN/BLUE/PURPLE (classe), COLORLESS, CURSE.
- **CardTags**: `STRIKE`, `HEALING`, `STARTER_STRIKE`, `STARTER_DEFEND`, `EMPTY` — **só 5 tags no jogo inteiro!** Usadas por cartas contadoras (Perfected Strike) e filtros (HEALING excluída de ofertas em certos eventos). Nosso TagSystem (30+ tags) é MUITO mais rico — a diferença é que lá as tags são lidas por CARTAS, não por um sistema de combos.

## Padrão "base vs atual" + isModified (o segredo do preview honesto)

Todo número tem par: `baseDamage/damage`, `baseBlock/block`, `baseMagicNumber/magicNumber` + flags `isDamageModified` etc.
- `applyPowers()` (sem alvo) e `calculateCardDamage(monster)` (com alvo) recalculam `damage` a partir de `baseDamage` passando pelo MESMO pipeline do dano real: relíquias → powers do dono (atDamageGive) → stance → powers do ALVO (atDamageReceive) → finais → floor.
- A UI pinta o número de **verde se buffado, vermelho se nerfado** (`isModified` + comparação com base). Descrições usam placeholders `!D!`/`!B!`/`!M!` que renderizam o valor ATUAL.
- Resultado: a carta na mão SEMPRE mostra o dano verdadeiro contra o alvo em hover — zero "surpresa matemática". **Preview e execução compartilham o mesmo código.**

## Campos de comportamento (checklist de mecânicas por carta)

`cost` (-1 = custo X gasta toda energia; -2 = unplayable/sem badge), `costForTurn` (modificável por turno — Confusion/Snecko), `exhaust`, `isEthereal` (exaure se ficar na mão no fim do turno), `isInnate` (começa na mão), `retain`/`selfRetain` (não descarta), `purgeOnUse` (some pra sempre — cartas geradas), `isMultiDamage` (matriz de dano por inimigo), `shuffleBackIntoDrawPile`, `returnToHand`, `dontTriggerOnUseCard`, `freeToPlayOnce`, `misc` (contador salvo no save — Ritual Dagger!), `uuid` (instância), `cardsToPreview` (hover mostra a carta que será gerada — Shiv na Blade Dance), `glowColor` (borda dourada quando condição especial ativa — Grand Finale).

## Ciclo de vida ao jogar

`canUse()` → entra em `cardQueue` → GameActionManager notifica ~7 grupos de listeners (`onPlayCard` em powers do player/monstros, relíquias, stance, blights, cartas na mão/discard/draw!) → `player.useCard` → `card.use(p, m)` gera ACTIONS na fila → `UseCardAction` move a carta (discard/exhaust/purge/power some). Fim de turno: `triggerOnEndOfTurnForPlayingCard` (Burn causa dano, Regret perde HP), ethereal exaure, retain segura.

## Upgrade system

Cada carta implementa `upgrade()` com helpers `upgradeName()` (adiciona "+"), `upgradeDamage/Block/MagicNumber(amt)`, `upgradeBaseCost(n)`. Descrição própria de upgrade (UPGRADE_DESCRIPTION). Só 1 upgrade por carta (exceto Searing Blow). `timesUpgraded` salvo no save. Padrões por cor: RED tende a +dano, GREEN +magicNumber, BLUE −custo.

## CardGroup (pilhas)

masterDeck (a run), drawPile, hand, discardPile, exhaustPile, limbo (cartas "no ar" durante animação — jogadas duplicadas etc.). Shuffle usa `shuffleRng` dedicado. Checks prontos usados por achievements/score: `highlanderCheck` (sem duplicatas), `pauperCheck` (0 raras), `cursedCheck` (5+ curses), `fullSetCheck` (4+ cópias).

## AS 15 SINERGIAS EMERGENTES (não existe ComboSystem!)

O StS não detecta combos. Sinergia = carta/power que **lê estado que outras cartas produzem**:

| Carta/Power | Lê o quê | Mecanismo (arquivo) |
|---|---|---|
| Perfected Strike | nº de cartas com tag STRIKE em TODAS as pilhas | +2 dano por Strike (PerfectedStrike.java:29-71) |
| Heavy Blade | Strength | Strength conta ×3 (multiplica amount in-place antes do pipeline, HeavyBlade.java:40-61) |
| Body Slam | `player.currentBlock` | dano = block atual (BodySlam.java:28-57); custo 0 upgraded |
| Catalyst | Poison do alvo | dobra/triplica stacks (Catalyst.java) |
| Feel No Pain (power) | evento onExhaust | +3 block por carta exaurida |
| Dark Embrace (power) | onExhaust | +1 draw por exhaust (stacka com FNP: exaurir vira motor) |
| After Image (power) | onUseCard | +1 block POR CARTA jogada |
| A Thousand Cuts (power) | onAfterCardPlayed | 1 dano AoE por carta jogada |
| Envenom (power) | onAttack (dano NORMAL infligido) | +1 poison por hit |
| Rampage | própria instância (uuid) | +5 dano permanente NO COMBATE a cada uso (ModifyDamageAction via uuid) |
| Ritual Dagger / Feed | kill com a carta | +dano/maxHP PERMANENTE NA RUN (salvo em `misc`) |
| Grand Finale | drawPile.size()==0 | 50 dano AoE custo 0, `canUse` bloqueia senão; borda dourada quando pronto |
| Blade Dance + Accuracy | Shivs geradas leem power Accuracy | Shiv baseDamage = 4 + Accuracy no construtor |
| All For One | cartas custo-0 no discard | puxa TODAS de volta pra mão (arquétipo custo-0 do Defect) |
| Claw | outras Claws | toda Claw jogada aumenta dano de TODAS as Claws (escala em cadeia) |

**Padrões de payoff**: contar (Perfected), converter recurso (Body Slam: block→dano), multiplicar DoT (Catalyst), reagir a evento em massa (FNP/After Image/Cuts), crescer permanente (Rampage/Feed), condição de deck (Grand Finale), gerar+buffar tokens (Shiv+Accuracy).

## Status & Curses (poluição de deck como mecânica)

STATUS (temporárias, somem no fim do combate): Burn (2 dano se na mão no fim do turno; upgrade das Hexaghost queima 4), Dazed (ethereal), Wound (inerte), Slimed (custo 1, exhaust — dá pra "pagar pra limpar"), Void (−1 energia AO COMPRAR).
CURSES (permanentes no deck): Clumsy (ethereal), Injury, Pain (1 HP por carta jogada), Decay (2 dano fim do turno), Doubt (Weak no fim), Regret (perde HP = nº cartas na mão), Normality (máx 3 cartas/turno!), Ascender's Bane (A10+, não removível).
Design: cartas-lixo criam decisões (exaurir? comprar mais rápido? Blue Candle joga curse por 1 HP?) e alimentam arquétipos exhaust.

## → Confronto com o nosso jogo

- Nosso **ComboSystem é detection-based** (11 regras sobre tagCounts do turno) — é nossa identidade, mais "Balatro" que StS, e o jogador VÊ o combo anunciado. Manter.
- O que falta é a **outra metade**: cartas/jokers que leem estado (block atual, poison do alvo, nº de exhausts na batalha, cartas jogadas no turno, orbs canalizados). O turnContext já existe; adicionar contadores estilo GameActionManager (cardsPlayedThisTurn/Combat, exhaustedThisCombat, damageReceivedThisTurn) destrava ~10 arquétipos novos sem tocar no ComboSystem.
- **Preview honesto**: nossas descrições são literais (não mostram valor com strength/combo aplicado). O padrão base/atual + isModified é adotável no nosso `computeCardValue` — pintar o número da carta quando buffado é juice barato e informação real.
- Tags: já temos catálogo rico; a evolução é deixar CARTAS lerem tags (ex: "Golpe Perfeito: +2 por carta 'strike' no deck").
