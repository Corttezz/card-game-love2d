---
name: STS Source Reference
description: Código descompilado do Slay the Spire em E:\dev\projects\slay-the-spire-source — mapa de sistemas, arquivos-chave e regra de uso (referência de estrutura/números, nunca copiar).
type: reference
---

# Slay the Spire — source de referência

**Estudo completo (Jul/2026) destilado em 7 memórias:** [[STS Powers Catalog]] (buffs/debuffs/hooks) ·
[[STS Cards & Synergies]] (tipos, preview vivo, 15 sinergias emergentes) · [[STS TopBar & HUD]] (anatomia
da barra + painéis de combate) · [[STS Metagame]] (menu, 48 achievements, unlocks, score, daily) ·
[[STS Run Economy]] (pity systems, gold, shop, fogueira, Neow, eventos, atos) · [[STS Progression & Config]]
(ascension 1-20, save/RNG counters, seed, settings) · [[STS Gap Analysis]] (confronto com o NOSSO jogo +
sugestões priorizadas — insumo do documento de melhorias).

**Local:** `E:\dev\projects\slay-the-spire-source\`
- `src/com/megacrit/cardcrawl/` — 2.008 arquivos .java descompilados (CFR 0.152 a partir do
  `desktop-1.0.jar` da instalação Steam em `D:\Program Files (x86)\Steam\steamapps\common\SlayTheSpire`).
- `localization/eng/` + `localization/ptb/` — 17 JSONs de dados por idioma (cards, relics, powers,
  events, monsters, keywords, potions, ui...). PT-BR oficial = referência de tom de tradução.

**Regra de uso (mesma do Balatro — ver [[Diretriz Balatro Fidelity]]):** consultar como blueprint
de ESTRUTURA, ALGORITMOS e NÚMEROS de balance. NUNCA copiar código, strings ou assets literalmente.
Fica FORA de qualquer repositório versionado.

## Stack (pra contexto)

Java 8 + libGDX (LWJGL2), Spine (animação esquelética dos monstros), GSON, steamworks4j,
Twirk (Twitch chat), log4j2. RNG = RandomXS128 (xorshift128+). Tudo num jar de 365 MB
(código + 2.621 imagens + 441 áudios + 25 idiomas). Só 6 shaders no jogo inteiro
(grayscale, outline, water, whiteSilhouette, blur, redSilhouette) — o "juice" vem de
lerp/escala/partícula, não de shader.

## Sistemas de ouro (arquivo → o que aprender)

| Sistema | Arquivo (sob src/com/megacrit/cardcrawl/) | Lição |
|---|---|---|
| **Action queue** | `actions/GameActionManager.java` + `actions/AbstractGameAction.java` | TODA mutação de combate é uma action com `duration`+`isDone`, executada UMA por vez (serializa lógica e animação; equivalente nosso: EventManager+CombatSequence). Filas: `actions`, `preTurnActions`, `cardQueue`, `monsterQueue`, `nextCombatActions`. `addToTop`/`addToBottom` = reações furam fila. |
| **Powers/hooks** | `powers/AbstractPower.java` | Buff/debuff = objeto com ~50 hooks virtuais (onPlayCard, atStartOfTurn, onExhaust, onChannel...). Pipeline de dano em 4 estágios: `atDamageGive` → `atDamageReceive` → `atDamageFinalGive` → `atDamageFinalReceive` (aditivos primeiro, multiplicativos no Final — Weak/Vulnerable são Final). `priority` ordena powers. |
| **DamageInfo** | `cards/DamageInfo.java` | Cálculo encapsulado num objeto; flag `isModified` pinta o número da carta de verde/vermelho na UI. Preview de dano usa o MESMO código do dano real (nunca dessincroniza). |
| **RNG determinístico** | `random/Random.java` + `dungeons/AbstractDungeon.generateSeeds()` | 13 streams da MESMA seed (cardRng, monsterRng, mapRng, relicRng, potionRng, aiRng, shuffleRng...), cada um com `counter` de rolls salvo no save → run 100% reprodutível por seed; categorias não contaminam umas às outras. |
| **Geração de mapa** | `map/MapGenerator.java` (256 linhas!) + `map/RoomTypeAssigner.java` | Grade 15×7, 6 caminhos random walk (dx∈{-1,0,1}), anti-degenerescência: 2º caminho não repete início, ancestral comum < 3 linhas força divergir, arestas não cruzam. Salas: shop 5%, rest 12%, event 22%, elite 8%×asc, resto monstro; regras declarativas (sem elite/rest antes da linha 5, sem rest na 13, sem irmão/pai igual); linha 0 = monster, 8 = treasure, 14 = rest. |
| **Intents** | `monsters/AbstractMonster.java` (enum `Intent`, `setMove`, `rollMove`, abstract `getMove(roll)`) | 17 tipos (ATTACK, ATTACK_BUFF, DEFEND, STUN, SLEEP, ESCAPE, UNKNOWN...). IA = `getMove(aiRng.random(99))` — determinística por seed. Intent mostra dano JÁ modificado por powers. |
| **Lerp+snap** | `helpers/MathHelper.java` | Todo movimento de UI = `lerp(cur, target, dt*speed)` + snap no threshold. Velocidades nomeadas: card 6, cardScale 7.5, ui 9, mouse 20, fade 12, slowColor 3. É o segredo da suavidade STS (nosso Moveable/Animation cobre parte). |
| **Keywords/tooltip** | `localization/eng/keywords.json` + `helpers/TipHelper` | Dicionário central: toda keyword tem NAMES (aliases) + DESCRIPTION; descrições auto-linkam tooltips. Markup: `#y`=amarelo, `#b`=azul; templates `!D!`/`!B!`/`!M!` (dano/block/magic) atualizam ao vivo com buffs; `NL` = quebra; `[G]` = ícone de energia. |
| **Turn structure** | `GameActionManager.getNextAction()` (fim do método) | Ordem canônica de início de turno: relics → preDrawCards → cards → powers → orbs → draw → postDrawRelics → postDrawPowers. Fim: relics → prePowers → orbs → hand triggers → stance. Ordem explícita = design. |
| **Métricas de combate** | `GameActionManager` (statics) | `damageReceivedThisTurn/Combat`, `cardsPlayedThisTurn/Combat`, `totalDiscardedThisTurn` etc. alimentam cartas/relíquias condicionais baratas de implementar. |
| **VFX vocabulary** | `AbstractGameAction.AttackEffect` (enum) | 12 tipos de golpe (SLASH_DIAGONAL, BLUNT_HEAVY, FIRE...) — ataque escolhe efeito visual/som de um vocabulário fixo, não VFX ad-hoc. |

## Conteúdo (números pra calibrar escopo)

~361 cartas jogáveis (75 red/Ironclad + 75 green/Silent + 76 blue/Defect + 77 purple/Watcher +
39 colorless + 14 curses + 5 status), 187 relíquias, 124 powers, 44 potions, ~56 eventos,
~70 monstros (exordium 28 / city 20 / beyond 17), 6 orbs, 5 stances, 35 daily mods,
4 atos (Exordium/TheCity/TheBeyond/TheEnding), Neow (bênção inicial), ascension, endless.
Cada carta/relíquia/power/evento = 1 classe Java (data-driven só nos textos) — nosso
CardDatabase data-driven já é mais escalável nesse ponto; a lição do STS está nos HOOKS.

## Como consultar

- Mecânica de carta: grep do nome em `src/com/megacrit/cardcrawl/cards/<cor>/`
- Como power X funciona: `powers/<Nome>Power.java`
- Balance por ato: `dungeons/Exordium.java`, `TheCity.java`, `TheBeyond.java` (HP pools,
  chances de sala, composição de encontros fáceis/fortes/elites)
- Texto PT-BR oficial de qualquer termo: `localization/ptb/*.json`
