---
name: counter_jokers
description: Out/2026. Oito coringas CONTRA (incomuns, neutros): Lanterna (névoa e véu), Brasa (Geada do Monarca), cinco imunidades a debuff no jogador (Veneno, Queimadura, Fraco, Frágil, Vulnerável) e Pedra de Amolar (fura RESISTÊNCIA do inimigo, nunca imunidade). Lógica só em src/systems/CounterJokers.lua com um gancho por ameaça; oferta pesa pela ameaça do ato atual/seguinte; piloto troca na bancada no início do ato.
type: project
---

# Coringas contra (24/Out/2026)

Pedido do dono: "coringas, não tão raros, que ajudem a gente: ver através da névoa,
imunidade a veneno, contra o congelamento... que a gente possa equipar e desequipar".

## As 8 cartas (`src/data/cards/basic.lua`, `class = "basic"`, `rarity = "uncommon"`)

| id | nome | efeito | ameaça (atos) |
|---|---|---|---|
| joker_counter_lantern | Lanterna Velha | `counter_sight`: névoa e véu nunca escondem o intent | névoa A4/A6 + véu (Espectro, Lobo, Xamã, sombra, Rainha) |
| joker_counter_brazier | Brasa de Bolso | `counter_frost`: Geada não acumula, nada congela | Monarca do Inverno (A4 chefe) |
| joker_counter_antidote | Frasco Antídoto | `counter_debuff` poison | A1, A5 |
| joker_counter_salamander | Escama Ígnea | `counter_debuff` burn | A3 e outros |
| joker_counter_weak | Chifre do Touro | `counter_debuff` weak | todos |
| joker_counter_frail | Casco de Jabuti | `counter_debuff` frail | quase todos |
| joker_counter_vulnerable | Pele de Pedra | `counter_debuff` vulnerable | vários |
| joker_counter_whetstone | Pedra de Amolar | `counter_pierce`: resistência (×0,5) vira dano normal; imune e fraco não mudam | criaturas com `resist` em `Enemies.RESIST` (todos os atos) |

Situacional por desenho: forte contra a ameaça, NADA fora dela. O que dá o
valor é trocar na bancada (J) entre atos.

## Onde mora

- Lógica: `src/systems/CounterJokers.lua` (`blocksDebuff`, `frostGain`,
  `freezeCount`, `filterVisibility`, `piercesResist`, `notePierce`, `actThreats`, `offerWeight`, `pilotScore`).
- Ganchos (uma linha cada, nada de lógica fora do módulo):
  - `Game:_pushEnemyTurn...` beat `enemy.debuff.*`: `blocksDebuff` antes do `addDebuff`.
  - `BossMechanics.applyIntentStep` (frost_gain) e `BM.onPlayerDraw` (freeze).
  - `IntentVisibility.resolve`: o retorno passa por `filterVisibility` DEPOIS de
    rolar, então o stream "misc" é idêntico com ou sem Lanterna (trava no teste).
    A causa vira `"lantern"`.
  - `CardRegistry:pickRewardCard`: peso × `offerWeight` (`OFFER_WEIGHT` 0,4 se a
    ameaça está no ato atual ou no seguinte, `IDLE_OFFER_WEIGHT` 0,12 se não; com
    1,0/0,35 o mago caiu de 27% para 15% em 60 runs: diluía a loja dele).
  - `Game:new` registra o jogo (`CounterJokers.bind`, tabela fraca); a Lanterna
    acha o jogo pelo inimigo (`gameOf(enemy)`), porque `resolve` só recebe o inimigo.
  - `Resistances.level` (fonte única da frente de imunidades): `resist` vira nil
    com a Pedra ativa, então combate, prévia, piloto e selos do HUD (`entries`)
    mudam juntos. O tique sai só no golpe real: `Enemy:takeDamage` chama
    `notePierce` quando a tabela crua dizia `resist` e o nível saiu nil.
- O intent continua CONGELADO e exato: o Braseiro só tira a Geada que chegaria
  (mecânica só diminui o anunciado); a Lanterna só muda a leitura.
- Ameaça por ato é DERIVADA dos kits (`src/data/enemies.lua`: debuffs dos
  golpes e fases, `veil`, `mechanic.kind == "frost"`) + `intent_fog.lua`. Kit novo
  com debuff entra sozinho na conta.

## Feedback

- Tique do coringa no slot (`notifyJokerProc`, caminho direto) com rótulo
  `counter_jokers.proc.{immune,frost,thaw,sight,pierce}` nos 5 locales.
- Assinatura sonora = SFX existente copiado para `audio/sfx/joker-sig/`
  (lanterna=scene-lamp-creak, braseiro=fork-hover-fire, antídoto=shop-potion-bubble,
  salamandra=impact-fire, touro=strength-gain, tartaruga=card-play-defense,
  pedra=scene-stone-thud, amolar=shop-anvil-ring). Nenhum gerado; lacuna: sons próprios se o dono pedir.
- Glossário (`src/data/keywords.lua`, no FIM da lista para não roubar vaga das
  3 palavras das cartas antigas): immune, fog, frost, frail, burn, resist.
- Popup do tique preso dentro da tela (`FloatingText` `clampFrac`, usado pelo
  `JokerProcFx`): no slot 1 o "Imune: Veneno" saía cortado pela borda do CRT.

## Arte

`tools/pixellab_counter_jokers.py run|fetch|contact|pick` (create_map_object
64x64, receita dos coringas de combo; 24 gerações, 3 variantes por carta).
Pranchas em `tools/preview_out/coringas_contra/arte/`. Idle: salamandra pelo v3
(chama da cauda, frames 4); as outras ASSADAS em `tools/bake_icon_glint.py`
(v3 da lanterna fazia a névoa sumir e voltar; o do braseiro mexia o rosto do
velho, regra de rosto).

## Piloto

`tools/autoplay.lua` `scoreJokerParts(inst, game)`: efeito contra vale
`CounterJokers.pilotScore(effect, ato)` (0 sem a ameaça no ato), então a
bancada do início do ato (`optimizeJokerBench`) liga e desliga sozinha. O
expert_full escolhe coringa por simulação (`pickBySim`), que já roda o mesmo
código do jogo.

## Travas e provas

- `love . test_one test_counter_jokers` (no test_all): cada contra funciona,
  sem tique quando a ameaça não vem, não protege de outro debuff, stream misc
  intocado, dados/atlas/ícone/anim/som/5 locales/glossário, pesos de oferta e
  do piloto.
- Capturas: `CARDGAME_HEADLESS=1 lovec . test_one screenshot_coringas_contra`
  (`CONTRA_ONLY=lantern,brazier,poison,...,manager`) → save dir
  `coringas_contra/`, cópia em `tools/preview_out/coringas_contra/`.

## Balanço (expert, 30 runs/classe, seeds 720000, --procs 3)

| base | G | M | L | total |
|---|---|---|---|---|
| main 42f99d50 (sem contra) | 47% | 40% | 40% | 42% |
| com os 7 contra (peso 0,4/0,12) | 57% | 37% | 40% | 44% |
| main b277a88c (imunidades, sem contra) | 50% | 23% | 40% | 38% |
| b277a88c + os 8 contra | 57% | 37% | 40% | 44% |

Mago 60 runs (seeds 730000): 27% sem, 15% com peso 1,0/0,35, 23% com 0,4/0,12.
Relatórios em `reports/balance/contra_*`.

## Pendências conhecidas

- O selo do intent mostra o debuff que o coringa vai barrar (o jogador não vê de
  antemão que está protegido; só o tique no golpe).
- O expert_full quase nunca pega um contra (pickBySim simula o ato atual, onde a
  ameaça pode não estar); a bancada troca quando ele os possui.
- `test_card_audit` (mage_meteor_strike) e `test_landmark_fx` (sombra do castelo)
  falham no main b277a88c sem estes coringas: não são desta frente.
