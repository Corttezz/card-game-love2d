---
name: weather_engine
description: WeatherEngine v2 + WeatherAudio — clima FINO com profundidade no WorldRoad (densidade pela chegada ao castelo, vagalumes com luz, raio multiply-only) e som de clima sem loop fixo (camas em crossfade de variantes, avulsos, trovão por distância); lista dos sons ElevenLabs a regenerar
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

## Auditoria dos motores existentes (Out/2026, pedido do dono)
| motor | estado | o que mudou | impacto |
|---|---|---|---|
| GrassField | forte, lê bem em 1080p/1440p | `windAt` virou o vento ÚNICO: árvores (cisalhamento) e clima usam a mesma rajada | rajada atravessa capim → árvore → ar |
| LightEngine | poças medidas OK (`measure_lightpool` 1/4/6: delta máx 236-255, médio 14-22) | `modulateAmbient` (tempestade escurece, raio devolve até ~branco); brasas = micro-luz | raio "acende o mundo" sem quebrar multiply-only |
| ShadowEngine | sombras escalam com o dono (ok em tela grande) | nada — já move com sol/horário | — |
| LuminaireEngine | catálogo por bioma, poças passam | nada; partícula que cruza a poça fica acesa DE GRAÇA (lightmap multiplica o clima) | floco/gota brilham perto do poste |
| QuadMesh | base do chão/estrada/grama | reutilizado pelo clima (1 lote, 1 draw por fatia) | custo ~0.6 ms no pior caso |
| CRT | scanline/ruído por `resolution` (escala com a tela) | nada | — |
| holo/foil | só cartas | fora do escopo do mundo | — |

## Inimigo da estrada em tela grande (mesma sessão)
O mundo escala com a altura da área; o EnemyRenderer desenha 250/330 px
FIXOS → em 2560x1440 o monstro ficava ~25% menor que o mundo. Fix no lado
WorldRoad/GameplayScene: `WorldRoad.enemyScreenK(areaH) = clamp(areaH/1030,
1, 1.4)` multiplicado no `sizeK` do inimigo da estrada E nos dois passes do
billboard da viagem (handoff sem pulo). 768 e 1080p (área 1028) = 1.0
exato. Prova: `ENEMY_SCENE_VIRTUAL=2560x1440 love . screenshot_enemy_scene
1_battle` (tela falsificada num canvas — setMode acima do desktop trava).
Trava em `test_enemy_stage`.


## v2 (Out/2026, 2ª rodada do dono: "pixels grandes, chuva grossa, POLUINDO")
- **Fino**: medida em pixel de TELA (`u = floor(h/900)` → 1 px até 1440p).
  Chuva = risco de 1 px, longo (size 34 → ~35 px perto, ~14 no meio), alpha
  0.5-0.6; neve ≤3 px perto e 1 px no resto; cinza/semente/folha 1-2 px.
  Partícula de 1 px num print reduzido SOME — julgue no tamanho nativo
  (crop 1:1) e lembre que em movimento ela lê muito mais que parada.
- **Densidade pela chegada ao castelo**: `intensityFor(progress)` = 0.12 →
  1.0 (progress = caminhado/SEGMENT_LEN, a MESMA conta do castelo crescendo).
  Tempestade/raio só com progress > ~0.6 (`stormFor`). Tools:
  `setProgressOverride`, modos `start`/`castle` do screenshot_weather.
- **Vagalumes** (camada `ff` do preset): 1 px + cruz de halo quando aceso,
  micro-luz no núcleo (devolve a cor cheia no multiply) e POÇA no capim
  (LightEngine.submit, 6 por frame, só perto). Densidade pela NOITE (luma do
  ambiente 0.82→0.55). Estilos: wander (campos, amarelo), wisp (pântano,
  verde), mote (crepúsculo), sparkle (geleira), azul raro nas colinas; abismo
  não tem (brasas). O critter-vagalume antigo de tela fica desligado à noite
  quando o bioma tem `ff` (borboleta de dia segue).
- **LightEngine MAX_LIGHTS 16 → 28**: com o castelo perto as janelas lotavam a
  fila e a poça do vagalume (a mais fraca) nunca entrava — provado por diff
  A/B (poças on/off) antes de mexer.

## WeatherAudio (src/systems/WeatherAudio.lua)
- Camas = fila de VOZES sem loop: cada voz toca uma vez, de um ponto
  aleatório (≤35%), pitch ±6%; perto do fim a próxima variante (≠ anterior)
  entra em crossfade de 1.6 s. A emenda do arquivo nunca é ouvida (por isso o
  SALTO do check_loop nas camas não importa). Ganho por cama vem do estado do
  clima (intensidade, tempestade, rajada do capim, noite).
- Precisa de ganho POR INSTÂNCIA: `AudioManager:setInstanceGain(code, src, g)`
  (o update do AudioManager reescrevia o volume de toda instância tocando).
- Avulsos com intervalo/pitch/volume sorteados; trovão por distância do raio
  (perto: near/crack-2; meio: mid/roll; longe: far/roll), atraso
  0.15+2.2·dist s, volume 1−0.55·dist, nunca a mesma variante seguida.
  ElevenLabs gera estéreo → sem pan (Source:setPosition exige mono).
- **Watchdog** no love.update: mundo parou de atualizar (salão, loja, menu,
  pause) → camas somem em fade.
- Registro por SCAN de `audio/sfx/weather/` (código `wx:<nome>`), volume
  `Config.Audio.WEATHER_VOLUME` × categoria. Normalizados com ffmpeg (camas
  −22 dB médio, avulsos/trovão pico −2 dB). `CHECK_LOOP_DIR=audio/sfx/weather
  love . check_loop` mede as camas; `love . check_sfx weather` os envelopes.
- Trava: test_weather §12 (mock de audioSystem: rotação sem repetir, ganho ≤1,
  trovão sem repetir, watchdog, todo nome existe no disco).

## ⚠️ Sons gerados no ElevenLabs FREE (sem uso comercial) — REGENERAR
`audio/sfx/weather/`: rain-light-1/2/3, rain-heavy-1/2, wind-1/2/3,
blizzard-1/2, night-crickets-1/2, marsh-night-1, ember-crackle-1 (camas, 6 s,
loop:true); thunder-near, thunder-crack-2, thunder-mid (era
audio/sfx/thunder.mp3), thunder-roll, thunder-far; drip-1/2, owl-1,
cricket-chirp-1, frog-1, ember-pop-1, ice-tinkle-1, firefly-1/2 (avulsos).
Depois de regenerar: mesmo nome, normalizar (ffmpeg volume + alimiter) e
rodar `love . check_sfx weather`. Custo real medido: ~30 gerações ≈ 1100
créditos. rain-light-1/2 saíram quase mudos na 1ª tentativa (−60 dB) —
pedir "clearly audible, close" no prompt.

## Correções (Out/2026, 3ª rodada)
- **Aposentadoria determinística**: partícula de preset que saiu de cena
  (troca de bioma) esvai em `RETIRE_FADE` = 6 s e toda partícula tem vida
  máxima `MAX_AGE` = 75 s. Antes um floco atrás da crista podia viver >60 s
  conforme o RNG (o teste dependia da sorte).
- **"Bola" no poste do crepúsculo**: NÃO era luz — os quadros 1-7 de
  `assets/sprites/world/anim/dusk_lantern_0/` tinham um blob BRANCO que
  crescia e vazava pelos lados da lanterna (7 → 39 px no quadro 4). Corrigido
  congelando os pixels brancos no desenho do quadro 0 (o vidro ainda pulsa).
  Diagnóstico: capturar em movimento (`screenshot_weather 6:castle:seq`), A/B
  com `:nolight` (o defeito persistiu → arte) e contar pixels brancos por
  quadro. Outras anims com blob variável são fogo/porta (movimento proposital).
