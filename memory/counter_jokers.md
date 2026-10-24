---
name: counter_jokers
description: Out/2026. Sete coringas CONTRA (incomuns, neutros): Lanterna (névoa e véu), Braseiro (Geada do Monarca), e cinco imunidades a debuff no jogador (Veneno, Queimadura, Fraco, Frágil, Vulnerável). Lógica só em src/systems/CounterJokers.lua com um gancho por ameaça; oferta pesa pela ameaça do ato atual/seguinte; piloto troca na bancada no início do ato.
type: project
---

# Coringas contra (24/Out/2026)

Pedido do dono: "coringas, não tão raros, que ajudem a gente: ver através da névoa,
imunidade a veneno, contra o congelamento... que a gente possa equipar e desequipar".

## As 7 cartas (`src/data/cards/basic.lua`, `class = "basic"`, `rarity = "uncommon"`)

| id | nome | efeito | ameaça (atos) |
|---|---|---|---|
| joker_counter_lantern | Lanterna Velha | `counter_sight`: névoa e véu nunca escondem o intent | névoa A4/A6 + véu (Espectro, Lobo, Xamã, sombra, Rainha) |
| joker_counter_brazier | Brasa de Bolso | `counter_frost`: Geada não acumula, nada congela | Monarca do Inverno (A4 chefe) |
| joker_counter_antidote | Frasco Antídoto | `counter_debuff` poison | A1, A5 |
| joker_counter_salamander | Escama Ígnea | `counter_debuff` burn | A3 e outros |
| joker_counter_weak | Chifre do Touro | `counter_debuff` weak | todos |
| joker_counter_frail | Casco de Jabuti | `counter_debuff` frail | quase todos |
| joker_counter_vulnerable | Pele de Pedra | `counter_debuff` vulnerable | vários |

Situacional por desenho: forte contra a ameaça, NADA fora dela. O que dá o
valor é trocar na bancada (J) entre atos.

## Onde mora

- Lógica: `src/systems/CounterJokers.lua` (`blocksDebuff`, `frostGain`,
  `freezeCount`, `filterVisibility`, `actThreats`, `offerWeight`, `pilotScore`).
- Ganchos (uma linha cada, nada de lógica fora do módulo):
  - `Game:_pushEnemyTurn...` beat `enemy.debuff.*`: `blocksDebuff` antes do `addDebuff`.
  - `BossMechanics.applyIntentStep` (frost_gain) e `BM.onPlayerDraw` (freeze).
  - `IntentVisibility.resolve`: o retorno passa por `filterVisibility` DEPOIS de
    rolar, então o stream "misc" é idêntico com ou sem Lanterna (trava no teste).
    A causa vira `"lantern"`.
  - `CardRegistry:pickRewardCard`: peso × `offerWeight` (1 se a ameaça está no
    ato atual ou no seguinte, `IDLE_OFFER_WEIGHT` 0,35 se não).
  - `Game:new` registra o jogo (`CounterJokers.bind`, tabela fraca); a Lanterna
    acha o jogo pelo inimigo (`gameOf(enemy)`), porque `resolve` só recebe o inimigo.
- O intent continua CONGELADO e exato: o Braseiro só tira a Geada que chegaria
  (mecânica só diminui o anunciado); a Lanterna só muda a leitura.
- Ameaça por ato é DERIVADA dos kits (`src/data/enemies.lua`: debuffs dos
  golpes e fases, `veil`, `mechanic.kind == "frost"`) + `intent_fog.lua`. Kit novo
  com debuff entra sozinho na conta.

## Feedback

- Tique do coringa no slot (`notifyJokerProc`, caminho direto) com rótulo
  `counter_jokers.proc.{immune,frost,thaw,sight}` nos 5 locales.
- Assinatura sonora = SFX existente copiado para `audio/sfx/joker-sig/`
  (lanterna=scene-lamp-creak, braseiro=fork-hover-fire, antídoto=shop-potion-bubble,
  salamandra=impact-fire, touro=strength-gain, tartaruga=card-play-defense,
  pedra=scene-stone-thud). Nenhum gerado; lacuna: sons próprios se o dono pedir.
- Glossário (`src/data/keywords.lua`, no FIM da lista para não roubar vaga das
  3 palavras das cartas antigas): immune, fog, frost, frail, burn.

## Arte

`tools/pixellab_counter_jokers.py run|fetch|contact|pick` (create_map_object
64x64, receita dos coringas de combo; 21 gerações, 3 variantes por carta).
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

## Imunidades do INIMIGO (frente IMMUNITY)

Não existe ainda coringa que fure resistência de inimigo. Proposta de API para
quando a frente IMMUNITY fechar: efeito `counter_pierce` lido por
`CounterJokers.piercesImmunity(game, kind)` e consultado pelo ponto único onde
a imunidade do inimigo zera o dano/status (EffectSystem e DamagePreview).
