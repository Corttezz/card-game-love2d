---
name: music_reactive
description: Cenário que reage à música do chefe (17/Out/2026). Cues medidos OFFLINE (tools/music_cues.py → src/data/music_cues/<id>.lua: hit/swell/drop), engine/MusicCues lê a posição real da fonte e dispara, MusicReact traduz em tremor leve, detritos do teto (engine/CeilingDebris), pulso das chamas pintadas e respiro do chefe. Opção "Cenário reage à música" na aba Jogo. Trava test_music_react.
type: project
---

# Música reativa no salão do chefe

Pedido do dono (17/Out/2026): "sempre que tinha uma bateria forte, um batuque
forte, um grave forte ou uma parte impactante, a câmera podia tremer um pouco.
Talvez caíssem algumas pedrinhas do céu... ou o boss interagir." A palavra que
manda é **de leve**: a leitura da luta vem primeiro.

## Pipeline

1. **Análise offline** — `python tools/music_cues.py [ids] [--no-png] [--dry]`
   lê `audio/music/boss-<id>.mp3` (e as genéricas `music-boss.mp3` e
   `music-boss-eclipse.mp3`, chave `music_boss` / `music_boss_eclipse`) via
   ffmpeg (mono 12 kHz, quadros de 10 ms) e escreve
   `src/data/music_cues/<chave>.lua`:
   `{ track, duration, cues = { { t, kind, power[, dur] }, ... } }` em segundos
   do ARQUIVO.
   - **hit**: onset na banda 20-150 Hz (Butterworth 4ª ordem): subida de dB em
     30 ms, pico local em ±100 ms, acima de 2,2× a média móvel de 3 s + 1,5 dB e
     com nível grave acima do percentil 45 da faixa. `power` = raiz(onset
     normalizado × nível normalizado). Densidade: intervalo mínimo 0,35 s, no
     máximo 2 em qualquer janela de 2 s, `power` ≥ 0,30, ganham os mais fortes;
     nada nos primeiros 0,25 s (borda do arquivo).
   - **swell**: energia total suavizada em 1 s subindo ≥ 6 dB em 2,5 s, ≥ 60%
     dos quadros subindo, ≥ 1,5 s até o topo. Leva `dur`.
   - **drop**: média dos 0,8 s seguintes ≥ percentil 60 e ≥ 7 dB acima do
     1,5 s anterior; nota = salto + metade do salto GRAVE contra os 4 s
     anteriores (sem isso a volta do "breakdown" do Rei aos 57,8 s perdia para
     um respiro curto aos 62,9 s). Um drop a cada 12 s no máximo; encaixa no
     onset mais forte em ±0,2 s. Hit a menos de 0,35 s de um drop sai.
   - **Validação por medição** (não dá pra ouvir): o tool imprime % dos hits
     no pico de energia grave e o percentil do nível grave no hit, e desenha
     `tools/preview_out/musica_reativa/cues_<chave>.png` (forma de onda, curva
     grave em verde, hits vermelhos, swells azuis, drops amarelos) +
     `_drop.png` com zoom de ±6 s no primeiro drop. OLHE o PNG.
2. **Tempo de jogo** — `engine/MusicCues.lua` (genérico, sem dado do jogo):
   `MusicCues.new(data)`, `tracker:update(pos, fire)`. A primeira leitura só
   posiciona (nunca dispara). Cue com atraso > `LATE_MAX` (0,15 s) é pulado
   em silêncio: pausa, modal, foco perdido ou quadro travado NUNCA geram
   rajada. Posição que volta mais de 0,5 s = volta do loop: dispara a cauda só
   se ainda couber no atraso e recomeça do cue certo (nunca antes do
   `loopStart`). Funciona com loop nativo da fonte ou com seek para um
   `loopStart`: só lê a posição.
3. **Reação** — `src/systems/MusicReact.lua`, chamado pelo
   `GameplayScene.update` todo quadro com `{ fighting, bossId, hall }`.
   `fighting` = salão do chefe aberto neste andar (`inBossRoom`), sem
   `BossCinematic.phase()` (entrada e morte ficam de fora) e chefe vivo. Além
   disso só age se a faixa tocando (`audioSystem.currentMusic`, sem crossfade
   para outra) é código de chefe (`MusicDirector.isBossCode`) com arquivo de
   cues, e com a opção ligada. Posição = `template:tell("seconds")`. Combate
   congelado por modal não chama o update; ao voltar o salto é pulado.
   Dados por chefe em `src/data/music_reactions.lua` (`BY_BOSS`, `DEFAULT`,
   `STYLES`, `AREA` por salão em coordenadas da ARTE 400×256, `COOLDOWN`):
   - **hit**: tremor SÓ DO SALÃO de 0,8 a 1,6 px por 0,12 s (cooldown 0,45 s,
     respeita o slider de tremor; ver "Tremor só no cenário"); pulso curto das chamas pintadas
     (`InteriorFX.musicPulse`, canal próprio, multiplica chamas e pulsos do
     salão); poucos detritos (cooldown 0,3 s).
   - **drop**: tremor até 3,2 px por 0,3 s (cooldown de drop 4 s), luz mais
     forte, chuva de detritos, e o chefe **respira**: sobe 1-2 px de arte por
     0,55 s (`EnemyRenderer.musicBreath`, recusado se `isBusy()`: atacando,
     tomando dano, empurrão ou clip diferente de idle) + a aura brilha
     (`BossAura.musicPulse`, só os `glows`).
   - **swell**: a luz sobe devagar e cai um fio de detritos pela duração.
   - Detritos (`engine/CeilingDebris.lua`): pool fixo de 160, zero alocação
     por quadro, nascem logo abaixo da barra superior (y 16-40 da arte: o teto
     de verdade fica atrás da TopBar), caem até uma linha de chão sorteada
     (`AREA.floor0/floor1`, dentro da linha de chão do salão). Desenhados logo
     depois de `InteriorFX.draw`: ATRÁS do chefe, do HUD e das cartas. Temas:
     Rei-Carniça poeira clara + penas roxas, Lich poeira + lascas de runa,
     Tirano pedrinhas + brasas, Monarca neve + lascas de gelo, Colosso
     esporos, Rainha partículas de luz. Polish de 18/Out abaixo.
4. **Opção** — `settings.musicReact` (padrão LIGADO, `SaveManager`), linha
   "Cenário reage à música" na aba **Jogo** (`settings.music_react` nos 5
   locales). As abas de Configurações passaram a ter `MAX_ROWS = 6` (estavam
   todas cheias com 5). Desligada: nada. `reducedMotion`: zero tremor, zero
   detrito, chefe parado; fica só o pulso de luz × 0,35.

## Detritos finos (18/Out/2026)

Dono: "ficou legal, só que a tela pode ter um pouquinho mais de movimentação...
essas coisas caindo do céu: ficou meio grande e meio não natural". Folhas
antes/depois e respostas em `tools/preview_out/musica_reativa/polish/checklist.md`.

- **A faixa de nascimento tem que ficar ABAIXO da TopBar**: `AREA.y0/y1`
  = 34 a 62 da arte. Com 16 a 40 (1ª passada) o cover-fit em 1080p
  (`oy = -74`) punha a faixa em y 3 a 118 da tela, atrás da barra de 80 px,
  e a poeira passava o primeiro segundo invisível (o lead viu "meia dúzia
  de pontinhos" no quadro de +0,3 s). Conferir em 1024x768 também (`oy = 0`,
  34 x 3 = 102 px).
- **Unidade = meio pixel da arte**: `u = round(tr.scale / 2)` px de tela
  (2 px em 1080p, 2 em 1024x768, 5 em 4K), posição encaixada na grade de `u`.
  Mesma ideia do clima fino do WeatherEngine (1 px de tela), não da grade da
  PNG. Tamanhos em `u`: poeira/neve/esporo/mote 1 a 2 (`size = {1, 1.9}`
  → 40% 2u), pedrinha 1 a 3 com `big = { 0.08, {4, 5} }` (raras, 8 a 10 px),
  lasca 1 x 2 a 3, pena 4 a 6 x 1 + ponta (8 a 12 px: objeto visível,
  pedido do lead). Nada passa de 10 px em 1080p fora a pena.
- **Física**: `vy` inicial baixo + `gravity` + `vmax` (pedrinha 230 / 330,
  lasca 170 / 260, poeira 38 / 46 = acelera e satura). Pedrinha/lasca/gelo
  têm `bounce` (restituição 0,32 / 0,26 / 0,30, só se `vy > bounceMin`, no
  máximo 2 quiques) e `puff` (3 a 4 partículas `kind = "puff"` de 1u na cor
  `puffColor`, sobem 3 a 11 px/s, freiam, somem em ~0,4 s com `(1 - t)²`).
  `rest` = segundos parado no chão antes do fade de `LAND_FADE` (pedrinha
  2,5, pena 1,5, lasca 0,9; poeira 0).
- **Forma**: `chunk()` desenha o quadrado de `n` u com um canto cortado por
  `var` (0 a 3), que avança a cada `TUMBLE` = 0,11 s em queda (rolar) e vira
  quadrado cheio parado; célula de brilho (cor x 1,45) no canto superior.
  Lasca alterna vertical/horizontal pelo mesmo `var`. Pena: `L = size + 2`
  células; horizontal com espinha escura e ponta do lado do balanço quando
  |seno| > 0,6, senão diagonal com degrau a cada 2 células (zigue-zague
  lento: `sway` 10 a 16, `swayHz` 1,1, `vy` 4 a 8, `vmax` 11).
- **Filetes em coluna: REMOVIDOS (18/Out/2026, dono: "ficou parecendo cobra ou
  chuva")**. `CeilingDebris.spawnStreak` e o 4º campo `"streak"` saíram; só
  existem `spawn` (espalhado pela faixa do teto) e `"cluster"` (aglomerado de
  6 px em volta de um ponto do teto). Nada de partículas alinhadas em x.
- **Chuva do drop** (`REACT.RAIN = { now = 0.35, spread = 1.0 }`): 35% dos
  contáveis saem no cue, o resto cai distribuído por 1,0 s (`startRain` /
  `rainTick`, cicla as entradas). Contagens: poeira 28 a 44 (Rei) / 24 a 36
  (Lich, Tirano), neve 28 a 40, esporos/motes 20 a 28, pedrinhas 4 a 8 (Rei,
  Lich, Colosso) / 10 a 16 (Tirano), penas 2 a 4, lascas 6 a 10.
- **Hit**: um aglomerado de 6 a 12 (`{ estilo, 6, 12, "cluster" }`) mais 2 a
  5 espalhados (e a pena/lasca ocasional).
- **Cadência entre hits** (`REACT.TRICKLE = { 0.9, 1.9 }`, `r.trickle = {
  estilo, 1, 3 }`): 1 a 3 partículas num aglomerado a cada 0,9 a 1,9 s.
- **Poeira no ar** (`r.ambient = { estilo, máx, intervalo }`,
  `CeilingDebris.spawnFloat(style, area, preLife)`): 12 flutuantes
  `kind = "float"` de 1u (10 na Rainha), alpha 0,52 a 0,55, 1 a 3 px/s com
  balanço lento (`air_*` em `STYLES`; `air_ember` do Tirano sobe), vida 6 a
  10 s com fade nas pontas, `floatingCount()` segura o teto. Na ATIVAÇÃO o
  salão já nasce cheio (`ambientTick(dt, r, true)` com `preLife`, fase de
  vida aleatória para não sumirem juntos). Só com a faixa do chefe tocando.
- Chamas no hit: `LIGHT.hit` 0,35 → 0,45, `hitDur` 0,28 → 0,32. Tremor
  intocado. `reducedMotion`: chuva, filetes, flutuantes e quiques são
  detrito, logo zero (a trava `reducedMotion: zero detrito` cobre tudo).
- Custo (`abyss_tyrant:drop:perf`, 2ª passada): 71 a 78 draw calls com ou
  sem detrito (ruído), 3,3 a 4,2 ms em 1080p headless; pico do pool medido
  116 no quique do Tirano, `CeilingDebris.MAX = 256`.
- Critério do lead para "visível": recorte 1:1 em cue+0,3 s com ≥ 25
  partículas a olho; medido no Rei 102 vivas (≈ 30 a olho), Lich 89, Tirano
  87 (≈ 15 a 20 a olho, pior contraste: tan sobre lava), Colosso 127;
  repouso 12 flutuantes (8 a 10 a olho). Pool vivo por quadro sai no print
  do tool (`detritos vivos: repouso N (flutuantes F) | cue+0,3 s M`).
- Ferramenta: `screenshot_musica_reativa <chefe>:<cue>:seq[:pasta]` grava
  `polish/<pasta>/<chefe>_<cue>_{seq,teto1x,chao2x}.png` (8 quadros de 0,1 s;
  recorte 1:1 do teto; chão a 2x em 1,1 / 1,5 / 2,2 s; `_drop03_1x` e
  `_repouso1x` = salão inteiro 1:1 em cue+0,3 s e 0,6 s antes); `:perf` mede draw
  calls e ms com e sem detritos. Chefe sem faixa própria cai na `musicBoss`.
  Movimento se julga em sequência: o `_seq` a 0,5x prova que nada cruza o
  chefe e nada grande sobrou; o `_teto1x` e o `_chao2x` provam o detalhe.

## Tremor só no cenário (18/Out/2026)

Dono (via lead): o tremor da música mexe SÓ o salão (fundo, chamas,
detritos, chefe), nunca as cartas, os botões, o HUD do jogador nem a barra
do inimigo. `MusicReact` deixou de chamar o `ScreenShake` global: guarda o
próprio envelope (`shake.amp/dur/time`, decai no `update`) e expõe
`MusicReact.shakeOffset()` (aleatório por quadro × envelope × slider
`screenshake`). O `GameplayScene.draw` lê o offset no passe do mundo quando
`interior` e faz `push / translate / scale` em volta de fundo + InteriorFX +
MusicReact.draw + chefe + drawFront, com `pop` antes dos overlays.
**Sem clamp pela folga do cover-fit** (a 1ª versão clampava, e em 1080p a
arte 400x256 encaixa exato na largura, então o tremor horizontal virava 0 e
o dono disse "a câmera parou de mexer"): em vez disso o passe ganha um
zoom de `1 + 2·m/min(w,h)` em volta do centro (m = |offset| máximo, 1 a
5 px), que cobre as bordas e dispensa o clamp. Amplitude (`SHAKE` em
`music_reactions.lua`): hit 2,4 px por 0,14 s, drop 4,6 px por 0,40 s
(eram 1,6 / 3,2; dono pediu "aumentar um pouquinho"); `test_music_react`
exige teto ≤ 5 px. O bbox do chefe sai em coordenadas sem deslocamento,
então `EnemyHud` (barra e intent), TopBar, mão e botões, desenhados fora do
passe, ficam parados. Prova: `screenshot_musica_reativa <chefe>:drop:tremor`
grava `polish/<pasta>/<chefe>_drop_tremor_prova.png` (antes | impacto |
diff: amarelo = mudou), onde o salão e o chefe mudam e a carta da mão não
(a carta "viva" muda de quadro por conta própria). `reducedMotion`:
`doShake` continua sem tremor.

## Drops do Monarca (18/Out/2026)

A faixa do Monarca tem grave contínuo e com `DROP_RISE_DB = 7` não tinha
nenhum drop (o chefe nunca respirava). `tools/music_cues.py` ganhou
`--drop-db N` (só muda o limiar daquela rodada); com `--drop-db 4` saem 3
drops (8,06 s e 33,66 s na introdução, 76,67 s no corpo do loop 57,7 a
108,1 s: esse repete a cada volta), todos em subida de energia depois de
uma vala visível em `cues_winter_monarch.png`. A 6 e 5 dB saía só 1. Faixa
nova com poucos drops: tente `--drop-db` antes de mexer no detector.

## Números (17/Out/2026)

| faixa | duração | hit | swell | drop |
|---|---|---|---|---|
| carrion_king | 85 s | 43 | 4 | 3 (7,5 / 57,8 / 72,8 s) |
| tower_lich (loop 40,1 a 103,7 s) | 110 s | 51 | 8 | 2 |
| winter_monarch (loop 57,7 a 108,1 s) | 114 s | 79 | 2 | 3 (`--drop-db 4`, 18/Out) |
| abyss_tyrant (loop 24,8 a 75,1 s) | 81 s | 38 | 11 | 4 (o de 80 s fica depois do loopEnd e nunca toca) |
| music_boss (genérica) | 20 s | 15 | 1 | 1 |
| music_boss_eclipse | 28 s | 14 | 1 | 0 |

Rei-Carniça: 91% dos hits no pico grave, nível grave médio no percentil 95
(Lich 92%, Tirano 79%, Monarca 82%). O Monarca tem grave contínuo, sem queda
seguida de explosão: com o limiar padrão era zero drop; desde 18/Out os 3
drops a 4 dB fazem o chefe respirar (ver "Drops do Monarca").
Na faixa inteira o tremor ocupa 7% do tempo; menor intervalo entre tremores
0,88 s.

## Travas e ferramentas

- `love . test_one test_music_react` (na suíte): disparo na ordem e no quadro
  certo com posição falsa, volta do loop sem duplicar, salto sem rajada, fora
  da luta/faixa não-chefe/opção desligada = nada, reducedMotion zera tremor e
  detrito e deixa luz ≤ 0,3, cooldown (menor intervalo ≥ 0,34 s, tremor < 1/3
  da faixa), todo `boss-<id>.mp3` instalado tem cues em ordem.
- Capturas: `CARDGAME_HEADLESS=1 lovec . test_one screenshot_musica_reativa
  carrion_king:drop` (ou `:hit`, `:swell`) → quadros antes / impacto / +0,3 s /
  +0,9 s + folha em `tools/preview_out/musica_reativa/`; `:seq[:pasta]` e
  `:perf` na seção "Detritos finos". Use `TOOL_WINDOW=1920x1080` para julgar
  tamanho em px de tela.
- Faixa nova de chefe: rode `python tools/music_cues.py <id>`, olhe o PNG,
  confira `test_music_react`.

## Limites conhecidos

- O tremor da música é só do salão desde 18/Out (seção acima); o teto de
  3,2 px continua. Em 1080p ele é vertical (sem folga horizontal no
  cover-fit).
- Introdução + loop (faixas do Lich, Monarca e Tirano): o `AudioManager` faz
  `seek(loopStart + atraso)` na MESMA fonte quando o `tell` passa de `loopEnd`
  (`src/data/music_loops.lua`, `AudioManager:getLoopPoints(code)`). O tracker
  recebe `loopStart/loopEnd` (`MusicCues.new(data, ls, le)`): cue depois do
  `loopEnd` nunca dispara (a cauda do arquivo é cópia do começo do loop), cue
  da introdução dispara só na primeira passada, o corpo repete a cada volta.
  Sem pontos de loop o loop é o arquivo inteiro.
- O decoder de mp3 da LÖVE e o ffmpeg podem divergir no atraso do encoder
  (~25 ms): imperceptível para tremor.
