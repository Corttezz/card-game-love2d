---
name: weather_engine
description: WeatherEngine v1 — clima com profundidade no WorldRoad (neve/chuva/cinza/folhas/sementes em coordenadas de mundo, vento = rajada do GrassField, tempestade com raio multiply-only, árvores inclinando na rajada)
type: architecture
---

# WeatherEngine v1 — clima com profundidade (Out/2026)

**Pedido do dono:** "algo que cause impressão de UAU nos mundos normais, como
foi a grama". A grama mostrou o vento no CHÃO; o clima mostra o MESMO vento
no AR e nas árvores. Arquivo: `engine/WeatherEngine.lua`.

## O que existe
| bioma | clima | extra |
|---|---|---|
| fields | sementes de dente-de-leão (rajada LEVANTA) | — |
| highlands | chuva, ciclo de tempestade 70 s | RAIO + trovão no pico |
| abyss | cinza caindo | brasas SUBINDO (micro-luz) |
| frost | neve 1100 flocos, ciclo de nevasca | rastro horizontal na rajada forte |
| marsh | garoa constante | raio raro |
| dusk | folhas girando (3 poses) | — |

Substituiu as antigas "partículas ambientais" (36 quadradinhos em tela,
sem profundidade nem vento). O campo `ambient` de `src/data/biomes.lua`
ficou sem leitor.

## As decisões que fazem funcionar
1. **Coordenadas de MUNDO** (lateral normalizada, z absoluto, altura): a
   projeção é a do domo (`g.latY`, `g.persp`). Paralaxe vem de graça (neve
   do fundo quase parada, a da frente despenca) e a viagem traz o clima pra
   cima de você.
2. **PIXEL DE ARTE, não pixel de tela.** `u = floor(h/250 + 0.5)` (~3 px em
   768, 4 em 1080). A v1 media em px de tela: 300 flocos desenhados e
   INVISÍVEIS (prova magenta, `WeatherEngine.debugMagenta = true`). Tudo —
   tamanho, posição, coroa da gota — vive nessa grade.
3. **Painter por profundidade (regra do WorldRoad):** `flushTo(relLow)` é
   chamado DENTRO de `flushGrassTo` em drawProps (mesma fatia da grama);
   além da crista desenha antes do domo (`flushTo(REL_CREST)` — some atrás
   da curva); antes do inimigo `flushTo(BATTLE_REL)`; primeiro plano
   (`fg`, rel fictício -100) em `flushAll()` depois dos props.
4. **Vento = `GrassField.windAt`** com o preset de grama do bioma. Árvores
   (tree/pine/deadtree/bush) inclinam por CISALHAMENTO (`kx` no draw, pivô
   no pé — rotação serrilharia o sprite) com a rajada da posição delas, e
   rajada forte arranca folha (`emitLeaf`, cap 28). A frente de rajada
   atravessa capim → árvore → ar.
5. **Raio multiply-only:** tempestade escurece o ambiente (`dark` × storm),
   o clarão leva o ambiente até ~branco via `modulateAmbient` antes do
   `LightEngine.beginFrame`. Nunca passa de 1 (não pinta, só devolve a
   arte — doutrina de luz). O bolt é polilinha de pixels (2px núcleo +
   halo opaco), desenhado ENTRE as nuvens e `drawMountainsFront` (os picos
   cobrem o pé). Trovão `audio/sfx/thunder.mp3` (ElevenLabs) 0.5-1.6 s
   depois; atrasado >1 s não toca.
6. **Acessibilidade:** reducedMotion = densidade 35%, SEM raio/clarão/
   trovão, árvores sem inclinação de rajada. Raio: 2 pulsos, ≥5 s entre
   raios (WCAG 2.3.1 < 3 flashes/s).

## Perf (1920×1080, medido dentro do motor)
1100 flocos: update 0.30 ms + montagem 0.26 ms; ordenação por INSERÇÃO na
própria lista viva (quase ordenada frame a frame) 0.01 ms — `table.sort`
custava 0.40. ~40 draw calls a mais (uma por fatia). Não toca no cache da
grama. Perf_probe antes/depois ficou dentro do ruído da máquina (+0-1 ms).

## Ferramentas
- `love . test_one screenshot_weather <bioma>[:WxH][:storm|:strike|:off|:travel|:dbg]`
  → `weather_<b>[_modo].png` (8 s simulados com draw por frame — a projeção
  precisa do frame; `screenshot_worldroad full<N>` desenha 1 frame só e
  mostra o 1º frame já cheio graças ao prefill do `beginFrame`).
- Trava: `love . test_one test_weather` (presets, densidade, NaN, ordem,
  "todas desenhadas", multiply-only, espaçamento de raio, reducedMotion,
  troca de bioma sem pop, fonte: flush dentro da fatia da grama).

## Se mexer
- Floco pálido no céu pálido some (multiply escurece os dois igual) — ele
  lê contra chão/árvore. Não "resolva" com contorno escuro: suja.
- Sombras de nuvem continuam BANIDAS (ciclo 26 do worldroad_scene) — clima
  não é desculpa pra elas voltarem.
- Bioma novo → preset em `WeatherEngine.PRESETS[id]` (o teste cobra).
