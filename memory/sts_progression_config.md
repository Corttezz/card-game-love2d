---
name: STS Progression & Config
description: Ascension 1-20 exata, 35 daily mods, blights/endless scaling, save system com RNG counters (anti save-scum), seed base-36, settings completos, FAST_MODE e escala responsiva do Slay the Spire.
type: reference
---

# STS — Progressão de dificuldade, save, seed e configurações

Fonte: grep `ascensionLevel` no src, `daily/mods/`, `blights/`, `saveAndContinue/`, `helpers/SeedHelper|AsyncSaver`, `core/Settings.java`, `core/CardCrawlGame.java`.

## Ascension 1-20 (cumulativo — cada nível UMA regra nomeável)

A1 mais elites (×1.6) · A2 inimigos normais mais dano · A3 elites+dano · A4 bosses+dano · A5 cura pós-boss 75% · A6 começa com 90% HP · A7 inimigos normais mais HP · A8 elites mais HP · A9 bosses mais HP · A10 curse **Ascender's Bane** no deck inicial (ethereal, não removível) · A11 −1 slot de poção · A12 metade das cartas upgraded nas rewards · A13 boss dá 75% do ouro · A14 −maxHP inicial (−5; Watcher −9... por classe) · A15 eventos piores (números degradados) · A16 shop +10% · A17 elites com padrões piores · A18 elites deadlier (Lagavulin −2 stats etc.) · A19 bosses com padrões piores · A20 **2 bosses no fim do ato 3**.
Padrão de design: dificuldade **legível e opt-in** — cada degrau muda UMA regra que dá pra explicar numa frase (e a UI mostra a lista no CharSelect). Não é "+10% stats genérico" em tudo.

## Daily mods (35 — modificadores de regra, verificados no código)

Exemplos com números: **Lethality** (inimigos +3 Str/turno) · **Terminal** (inimigos +5 block/turno) · **Colossus** (inimigos HP×1.5) · **Midas** (ouro ×2, preços ×2) · **Careless** (1 carta do deck moída por combate) · **ControlledChaos** (10 cartas aleatórias no fundo do deck a cada combate) · **Diverse** (deck de todas as cores; orbs cap 1 pra não-Defect) · **Night Terrors** (rest cura 100% mas custa 5 maxHP) · **Elite Swarm** (elites ×2.5) · **Binary** (−1 opção de carta) · **Sealed Deck**, **Draft**, **Heirloom** (relíquia rara inicial), **Vintage**, **Hoarder**, **Insanity**, **Uncertain Future** (mapa 1 caminho), **All Star** (cartas de TODAS as classes)...
Estrutura: classe com `ID/NAME/DESC/icon/modifying-flag` + `modAction()` estático chamado nos pontos certos. É um sistema de MUTATORS data-driven — 3 sorteados por daily geram variedade infinita de regra.

## Endless & Blights (14)

Cada "loop" no endless aplica blights escaláveis. Os 2 duros: **Spear** ("DeadlyEnemies": dano inimigo ×2.0, +0.75 por loop) e **Shield** ("ToughEnemies": HP/block ×1.5, +0.5 por loop) — aplicados direto no cálculo (AbstractMonster.java:753, 957). Outros: Durian (−50% maxHP), Hauntings, TimeMaze (limite de cartas por turno), Accursed (+2 curses/loop)... Nosso endless (1.18^floor) é curva única; o modelo blight torna o scaling VISÍVEL e tematizado (cada loop = um "carimbo" novo na barra).

## Save system — a parte GENIAL: RNG counters

`SaveFile` (JSON via GSON): estado do player (HP/gold/deck com `{cardID, timesUpgraded, misc}`/relíquias com counters/poções/keys), posição (`floor_num, act, room_x/y, path_x/y[]`), pools RESTANTES (relíquias por tier, monstros, eventos — o que já saiu não repete), flags (`post_combat, mugged, smoked`), Neow choice, **e o contador de cada um dos 13 RNGs** (`monster_seed_count, card_seed_count...`).
- Load = `new Random(seed, counter)` fast-forward → **o futuro da run é idêntico antes e depois do load** → save-scum inútil.
- Salva em MOMENTOS DE DECISÃO (entrar na sala, pós-reward, pós-boss-relic, pós-Neow) — não a cada frame.
- **AsyncSaver**: thread única com BlockingQueue — I/O fora do main thread (zero hitch).
- Ofuscação: Base64(XOR(json, "key")) — trivial, só desencoraja edição casual.
- **30+ campos `metric_*`**: HP/gold/poções POR ANDAR, path tomado, escolhas de carta (oferecidas vs escolhida!), escolhas de evento, compras, dano por luta. Telemetria pronta pra balance + alimenta a RunHistoryScreen.

## Seed (SeedHelper)

Alfabeto base-36 sem 'O' (input 'O'→'0'), conversão string↔long, exibida no fim da run e compartilhável; `generateUnoffensiveSeed` evita palavrões; run seedada manualmente marca flag (sem achievements). É o alicerce de: daily, replays, bug reports, comunidade de speedrun.

## Settings & escala responsiva

Opções: resolução (lista), fullscreen/borderless, vsync, FPS cap, 3 volumes, **screen shake toggle**, **particle effects toggle**, **FAST_MODE**, upload de métricas, hotkeys visíveis nas cartas, **BIG_TEXT_MODE** (acessibilidade), long-press, controller, 23 idiomas (inclui PTB).
- **FAST_MODE**: as constantes de duração de action (`ACTION_DUR_XFAST 0.1 / FASTER 0.2 / FAST 0.25 / MED 0.5 / LONG 1.0 / XLONG 1.5`) caem ~metade — por isso o action queue deles nunca "cansa" o veterano. Nosso CombatSequence tem timings próprios; um flag global equivalente custaria pouco.
- **Escala**: `scale = min(W/1920, H/1080)` com `xScale/yScale` separados + LETTERBOX automático fora de 4:3–21:9. Tudo na UI multiplica `Settings.scale` (nosso Config.Utils.getResponsiveSize é o análogo).

## Loop do jogo (CardCrawlGame)

GameMode: SPLASH → CHAR_SELECT → DUNGEON_TRANSITION (fade + troca de ato + tip de loading "Did you know") → GAMEPLAY. Música por ato com fade; MetricData agregado enviado (opt-in) no fim.

## → Confronto com o nosso jogo

- **RNG hoje é `love.math.random` sem seed** (RunManager) → sem daily, sem replay, sem seed compartilhável, e save-scum é possível. Adotar: 1 seed por run + N streams com contador (Random do StS tem 30 linhas — trivial em Lua com `love.math.newRandomGenerator(seed)` + contador serializado).
- SaveManager já é atômico com migrations (✔); adicionar contadores de RNG + pools restantes + metrics por andar é incremental.
- Dificuldade: não temos ascension — a escada "1 regra nomeável por nível" é o modelo certo pro nosso pós-vitória (e barata: cada nível é um if).
- Settings: temos música/sfx/master/fullscreen/CRT/lighting/screenshake/reduced-motion/idioma (✔ bom); faltam FAST_MODE e big text.
