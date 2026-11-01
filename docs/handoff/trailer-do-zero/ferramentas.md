# Etapa 2: ferramentas (trailer-do-zero)

_Diretora, 01/11/2026. Base: inventário de 01/11 da frente de som (`docs/handoff/trailer-revisao-som/inventario.md`, ainda válido, não repetido aqui por inteiro), leitura do código das ferramentas e **um teste real** de captura sem CRT + recorte em escala inteira. Regras: 0 crédito, headless, 1 `lovec`, identidade `card-game-trailer-v9`, nada de 4K até liberação._

## 1. Inventário e veredito

| ferramenta | onde | o que acrescenta a ESTE trailer | veredito |
|---|---|---|---|
| **Gravador headless** `tools/trailer_record.lua` | worktree novo `E:\dev\projects\card-game-trailer-zero`, branch `trailer-do-zero` (a partir de `steam-store-v2` 9a00d164) | jogo real quadro a quadro, relógio simulado, 60 fps, áudio do jogo logado em `audio.jsonl`; 39 tomadas prontas (`poweron`, `night`, `entrances`, `deck8`, `boss8`, `bosses`, `eclipse`, `inspect`, `collection2`, `pack`, `reward`, `shop`, `victory`, `fork`...); chaves `TRAILER_CRT=0`, `TRAILER_NOBEZEL=1`, `TRAILER_SIZE`, `TRAILER_PIPE=1` (grava mkv direto, sem TGA) | **USAR: base de toda imagem.** Mudança feita: `TRAILER_OUT=<pasta>` (antes a saída era fixa em `trailer/` e regravar apagava as tomadas dos trailers antigos) |
| **Recorte em escala inteira** (ffmpeg `crop` + `scale=flags=neighbor`) | — | a carta legível (§2, §5.1) e a câmera virtual dentro do jogo (§5.3) | **USAR** (×1 e ×2; ×3 sai, §5.2) |
| **Modo cheat** (`src/systems/CheatMode.lua`, via `_G.__cheatApi` no gravador) | jogo | luta encenada: ir ao ato/chefe, vida, mana, mão, matar/vencer; `forceEnemy` | **USAR** para a luta roteirizada (§3) |
| **Pipeline Kinetic Film local** | `E:\dev\_orquestracao\skills-externas\kinetic-film\` (`grimoire_b` como molde: `make_edl.py`, `compose.py` com OpenCV, `layer.py`/`render_layer.mjs` para o texto, `mixdown.py`; `patches/fx.py` com `JokerPatch` e o `lift` de luminância) | montagem por EDL na grade de beats; tipografia pixel renderizada como camada; moldura `bezel_ring/mask` | **USAR**, num filme novo `grimoire_zero` (cópia do `grimoire_b`, sem tocar nos outros) |
| **Motor de remix de som** | `docs/handoff/trailer-revisao-som/remix_engine.py` + `plan_*.py` | coloca cada SFX real do jogo no quadro certo a partir do `audio.jsonl` e da EDL; automação/ducking da música; ganho linear até −14 LUFS + limitador | **USAR** com um `plan_zero.py`; a automação da música passa a ser de silêncio real (meta §6.2 do diagnóstico) |
| **Batidas** `tools/trailer_beats.py` | worktree | grade de graves da faixa | **USAR** |
| **Métricas** `tools/trailer_kinetic_metrics.py` + `scratchpad\diag\analyze.py` | | luma por plano (regra 2 de continuidade), cortes, R128, microtrailer | **USAR** a cada corte |
| **Faixas ACE-Step 1.5** (MIT, local) | `audio/music/boss-carrion_king.mp3` (95,1 s), `boss-abyss_tyrant.mp3`, `boss-tower_lich.mp3`, `boss-winter_monarch.mp3`; motor em `E:\dev\tools\ace-step\` (RTX 2060 SUPER 8 GB, `gen_boss.py`, `make_loop.py`, `finalize.py`) | trilha séria, contínua, do bioma; o ACE-Step local permite **gerar de graça** uma peça nova em uma geração só (com estrutura interna: calmo → queda → drop → fim) se nenhuma faixa servir | **USAR as faixas existentes no corte 1**; gerar faixa nova só se o roteiro pedir uma estrutura que nenhuma tem, e com amostra para o Daniel (lição de 15/10: peça longa sai de UMA geração, nunca seções coladas) |
| **SFX do jogo** `audio/sfx/**` | repo | o som real de cada momento (liberado pelo Daniel em 01/11 13:00, só para ver) | **USAR**, com a marca "não publicável até trocar ou licenciar os SFX" |
| **Síntese local de SFX** `tools/synth_trailer_sfx.py` (numpy/scipy, semente fixa) e `tools/synth_narrator_blips.py` | repo | whoosh, impacto, glitch, selo do logo, blip; tudo sem terceiros | **USAR** só onde o jogo não tem som (selo, transição) |
| **Salões Higgsfield** `build/trailer/ai_4k/hall1_carrion..hall5_heart.mp4` | worktree antigo | acentos da música (decisão do Daniel, 01/11 14:31) | **USAR nos acentos**, com tratamento de integração (re-pixelizar na grade, cor do salão real do mesmo chefe, CRT por cima). Já existem: 0 crédito |
| **PixelLab MCP** | projeto | `pixelart_workbench` e `vfx_workbench` são **grátis** (editar/desenhar pixel por decisão própria): podem desenhar um elemento de tipografia ou um efeito de transição em pixel art; as ferramentas de geração gastam crédito | **CONSULTAR**: só workbench, se faltar um elemento gráfico; nada de geração |
| Skill `game-trailer-production` | `.agents/skills` | checklist de verdade do gameplay, CTA, mudo, QA de export, proveniência | **USAR** como checklist do corte |
| Skill `audio-design` | projeto | buses em dB, ducking 4:1–8:1, release 300–500 ms, −1 dBTP | **USAR** na mix |
| Skill `game-feel` | projeto | hit-stop + camada de som no impacto: o golpe letal pode congelar 2–3 quadros | **USAR** no pico |
| Skill `camera-systems` | projeto | regras de câmera (zona morta, suavização, shake) para a câmera virtual do recorte | **CONSULTAR** |
| Skill `scenario-kinetic-film` | global | grade de beats, finish (nível 5.2, sem `-shortest`); os passos com Scenario são pagos | **CONSULTAR**; nada de Scenario |
| `ecc:video-editing`, `remotion-video-creation`, `manim-video`, `motion-*` | plugins | montagem genérica; não acrescentam ao pipeline que já temos | NÃO USAR |
| `sound-effects`, `elevenlabs-music-generation` | | geração paga | **PROIBIDO** |
| MCPs `rea`, `chrome-devtools`, `github` e os de outras empresas | | sem relação / isolamento | NÃO USAR |

## 2. Teste de captura sem CRT + recorte em escala inteira (feito)

Comando (worktree `card-game-trailer-zero`, 1 `lovec`, headless, ~40 s de relógio):
```
CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=card-game-trailer-v9 TRAILER_OUT=trailer_zero_teste TRAILER_PIPE=1 \
TRAILER_FPS=60 TRAILER_SIZE=1920x1080 TRAILER_CRT=0 TRAILER_NOBEZEL=1 TRAILER_NOTOPBAR=1 TRAILER_LOCALE=en \
TRAILER_DECK_CLASS=rogue TRAILER_DECK_ENEMY=pit_brute TRAILER_DECK_TURNS=1 TRAILER_DECK_SPEED=0.72 \
lovec . test_one trailer_record deck8
```
Saída: `%APPDATA%\LOVE\card-game-trailer-v9\trailer_zero_teste\deck8.mkv` (1234 quadros, 1920×1080, 60 fps, sem CRT e sem moldura) + `audio.jsonl`. As tomadas antigas em `trailer\` ficaram intactas.

Recortes (`scratchpad\crop\`):
- **×2** (`crop=960:540` → 1920×1080, vizinho mais próximo; `x2_13.png`): carta a ~384 px de altura (36% do quadro). Lê-se o nome ("Leech Blade"), a arte, "ATTACK 6", o tooltip inteiro ("Deal 6 damage. Heal 2 HP.") e o Bruto acima. Pixel nítido, sem serrilhado. **É o plano padrão de gameplay do trailer.**
- **×3** (`crop=640:360`; `x3_13.png`): carta a ~53% do quadro; legível, mas o pixel da carta já mostra a irregularidade da escala 1,333 do jogo (colunas de largura 3 e 4 alternadas). **Só para insert curto** (≤ 1 s) ou para o número de dano.
- Close máximo da carta parada: tomada `inspect` (Coleção, carta inspecionada grande, animada).

Consequências para o roteiro:
1. O CRT sai da captura e entra **por cima do quadro final** (máscara/ring do Kinetic Film + scanline na escala do filme). Assim o recorte não amplia o scanline.
2. A câmera virtual anda em passos de **1 pixel da captura** (2 px na tela a ×2) para não tremer; zoom só por troca de plano (×1 ↔ ×2 ↔ ×3), nunca contínuo (escala não inteira = "cara de IA").
3. O plano aberto ×1 continua existindo para situar (estrada, chegada do inimigo, salão inteiro), mas nunca com a carta como assunto.

## 3. Tomadas que faltam e o que o gravador precisa ganhar

| tomada | para quê (roteiro) | o que existe | o que falta |
|---|---|---|---|
| `zero_hook`: carta viva em ×2 desde o quadro 0, TV ligando | gancho, §6.3 do diagnóstico | `poweron` liga o CRT; `inspect` mostra carta grande | gravar `poweron` **sem** CRT na imagem não serve: a TV vira efeito de pós sobre a tomada `inspect`/mão (o liga-TV é reproduzido no compositor, como o B já faz) |
| `zero_fight`: luta contada (perigo → virada → LETAL → morte) | arco principal | `deck8`/`boss8` com `fastTurns` | função nova: vida do jogador baixa (cheat), mão fixa, hover na carta que dá **LETAL** na prévia, jogar, morte do inimigo; com o chefe da mecânica |
| `zero_monarch`: Geada congelando 2 cartas na mão | prova 2 do gancho | `bossShot(..., 4, ...)` vai ao Monarca | turnos até a Geada ≥ 4 + compra; hover em carta congelada; ataque derretendo uma |
| `zero_tyrant`: corrente rompendo a 75% | prova 3 do gancho | `bossShot(..., 3, ...)` | dano suficiente para cruzar 75% num golpe (mão forte via cheat) |
| `zero_carrion`: entrada + corvos | prova 1 do gancho | `boss_carrion4`/`boss8` | sem CRT, para recortar ×2 no pouso e no cartão do nome |
| `zero_road`: atos 1→6 no **mesmo enquadramento** | regra 1 de continuidade | `night` / `fork` | conferir que o horizonte e o castelo ficam na mesma altura em todos os atos (WorldRoad no mesmo `rel`); se não, compensar no recorte |
| `zero_reward` / `zero_pack`: achado raro | carta viva + coringa | `reward`, `pack` | sem CRT |
| `zero_collection` | número "145 cartas" | `collection2` | sem CRT |

Toda tomada nova: `TRAILER_CRT=0 TRAILER_NOBEZEL=1 TRAILER_PIPE=1 TRAILER_OUT=trailer_zero`, 60 fps, 1920×1080, uma de cada vez, com folha de quadros revisada antes de usar.

## 4. Riscos

- **Tempo de captura**: ~30 quadros/s de relógio; um conjunto de ~8 tomadas de 20–60 s cabe em ~15 min de `lovec`, sempre um por vez.
- **Luta encenada pode não sair no 1º take** (o piloto do gravador escolhe cartas por regra): por isso a luta é escrita com mão fixa via cheat, e cada take é revisto em folha antes de ir para o EDL.
- **Salões de IA saturados** (§7 do diagnóstico): a grade de cor de integração é feita no compositor e medida pela luma (regra 2).
- **Licença**: tudo o que usa SFX do jogo sai com a marca "não publicável até trocar ou licenciar os SFX"; a música ACE-Step e a síntese local são limpas.

## 5. Provas da rodada 2 (resposta a `revisao-ferramentas.md`)

Worktree `card-game-trailer-zero`, commit `7997aaed` (`test_no_comments_no_prints` 9/0). Imagens e vídeos em `C:\Users\corte\AppData\Local\Temp\claude\E--dev-projects-card-game-love2d\7f9e50b0-2a53-4549-9447-d15442060f00\scratchpad\crop\`.

### 5.1 Carta em escala inteira no gravador (item 1)
Novo `TRAILER_CARD_PX=N`: a carta da mão é desenhada com exatamente N px de tela por pixel lógico (`BASE_SCALE = N / (1 + (k-1)·HAND_GROWTH)`, k = `UiScale.k()`; a 1080p o fator do jogo é 1,25, e por isso a carta normal sai a 1,667 px, irregular), o hover não amplia (`HOVER_SCALE_MULT = 1`) e o `Card.hoverTilt` é envolvido para zerar inclinação, rotação e deslocamento. Só no gravador; o jogo não muda.
- Medida: corridas horizontais de cor (limiar 20/255, acima do ruído do mkv) dentro da arte de uma carta **em repouso**. Antes (`full_13.png`, escala do jogo): **55% das corridas com largura ímpar**. Com `TRAILER_CARD_PX=2` (`full2_13.png`, carta Backstab): **0,1%** (4 de 2.828); as corridas são 2, 4, 6, 8... Ampliação 5× em `zoom2.png`: blocos 2×2 uniformes.
- Limite: a carta **selecionada ou em movimento** (Poison Dart levantada, ou durante o `juice_up`) ainda mede 10% ímpares, porque o pulo de escala do juice não é inteiro. Regra do roteiro: close de carta só de carta parada; carta em voo só em ×1 ou num ×2 rápido.
- Layout: a 2 px/pixel a carta tem 192×288 px; a mão de 6 cartas se sobrepõe um pouco mais que no jogo (`full2_13.png`), sem quebrar nem sair da tela. Os coringas do topo crescem junto e continuam no quadro.

### 5.2 ×3 (item 2)
Com a carta a 2 px/pixel, o recorte ×2 já dá 4 px por pixel lógico (carta a 576 px, 53% da altura). **Decisão: o ×3 sai do roteiro.** Planos: ×1 (situar, HUD), ×2 (gameplay, carta legível); close máximo = ×2 centrado numa carta parada, ou Coleção/`inspect`.

### 5.3 Câmera virtual (item 3)
`teste_camera.mp4` (5 s, 1080p): 1 s fixo ×2, 1 s pan a 15 px/s, 1 s a 60 px/s, 1 s a 120 px/s, corte seco ×1 → ×2. Deslocamento medido quadro a quadro (correlação horizontal):
- 15 px/s (de captura): 2 px de tela a cada 4 quadros → **pula** (7,5 degraus/s visíveis);
- 60 px/s (1 px de captura por quadro): **2 px de tela em todos os quadros**, uniforme;
- 120 px/s (2 px/quadro): **4 px em todos os quadros**, uniforme.
- Achado: com `floor(60*t)` no ffmpeg dava 2, 0, 4, 2, 0, 4 (arredondamento do relógio). A posição tem de vir do **número do quadro** (`x = x0 + n*v`).

**Regra**: pan só com 1 ou 2 px de captura por quadro (60 ou 120 px/s), posição por número de quadro; abaixo disso, enquadramento fixo; mudança de escala só por corte seco, no grave.

### 5.4 CRT do jogo aplicado depois (item 4)
`tools/trailer_crt_post.lua` roda **o próprio `shaders/crt.glsl` pelo `CRTShader` do jogo** (mesmo `beginScene/endScene`, força 0,75, mesma moldura, relógio simulado por quadro, semente fixa) sobre uma sequência de PNG e grava mkv. Comparação no mesmo quadro (790) da mesma tomada gravada duas vezes, uma com o CRT do jogo e outra sem CRT + pós (`lado_a_lado.png`, `diff_x8.png`): onde o conteúdo é igual nas duas gravações, a diferença média é **2,4/255** no céu e no chão (p99 = 10), **0,14/255** na moldura e 2,9/255 no inimigo, ou seja, ruído de compressão e do grão do shader. O que difere no `diff_x8.png` é conteúdo (as duas gravações deram coringas e mão diferentes), não CRT. Uso: o filme é composto sem CRT a 1920×1080 e o `trailer_crt_post` passa por cima de tudo no fim (scanline na escala do filme).

### 5.5 Liga-TV (item 5)
`tv_comparacao.png`: em cima, 10 quadros (um a cada 0,2 s) da tomada `poweron` gravada agora com o CRT do jogo; embaixo, o `trailer_crt_post` com `CRT_POWERON=1.8` (o mesmo `CRTShader.powerOn(1.8)` da tomada). As fases coincidem quadro a quadro: preto, ponto, linha, linha cheia, faixa abrindo, imagem rolando, assentada. É a TV do jogo, não uma transição de editor. Para o gancho (§6.3 do diagnóstico) o filme começa no quadro em que a faixa já abriu ~60% (cerca de 1,0 s depois do `powerOn`), via `CRT_SKIP`.

### 5.6 Salões do Higgsfield integrados (item 6)
Método (`integra.py`): (1) recortar o `castle_hall_N.png` real (400×256) para 16:9 (400×225); (2) reduzir o quadro de IA a 400×225 por área; (3) igualar média e desvio de cada canal LAB ao salão real; (4) quantizar na paleta do salão real (k-means, 48 cores); (5) ampliar por vizinho mais próximo a 1920×1080; (6) CRT do jogo por cima. Teste `hall_comparacao.png` (real | IA cru | IA tratado, os três com CRT): luma média 42,5 | 66,8 | **43,1**; saturação 97,7 | 138,1 | **119,2**. O tratado fica na grade e na paleta do jogo e lê como um **plano fechado do trono do mesmo salão** (a câmera do Higgsfield é mais próxima): no roteiro ele entra como corte para dentro (real aberto → IA fechado), nunca no lugar do plano aberto. Ajuste para o corte: a saturação ainda está 22% acima; baixar no passo 3 até ±10%.

### 5.7 HUD no 1º vídeo (item 7)
O roteiro terá, antes de 5 s, um plano ×1 de combate com vida, mana, barra do inimigo e mão (como `full2_13.png`). Sai da mesma tomada do ×2, sem tomada extra.

### 5.8 Tooltip (item 8)
Novo `TRAILER_TOOLTIP=0` (anula `CardInfoDisplay.draw`): mão inteira visível. Quando o texto da carta for a prova, grava-se a mesma ação com o tooltip ligado (padrão) e escolhe-se por plano.

### 5.9 Luta encenada: roteiro técnico (item 9)
Chamadas disponíveis no gravador (`_G.__cheatApi`, `CheatMode`, helpers do `trailer_record`): `freshRun(classe)`, `BUILDS` (deck e coringas fixos), `CheatMode.goToAct(ato, boss)`, `CheatMode.combatReady`, `CheatMode.newHand`, `CheatMode.kill/winInstant`, `playTurn`/`fastTurns`, `moveToContent`/`click`, `forceEnemy`, `closeBattle`. Faltam três funções de tomada, todas no gravador (dono: diretora, etapa 4, antes da montagem):

| tomada | chamadas | estado esperado | prova na folha de quadros |
|---|---|---|---|
| `zero_fight` (LETAL) | `goToAct(1, true)` → `combatReady` → `game.player.health = 9` → `enemy.health` ajustado para a mão fixa matar → hover na carta | a prévia mostra **LETAL** e a vida baixa do jogador; JOGAR; o chefe morre (cinemática de morte) | quadro com "LETAL" no painel; quadro do golpe com o número; quadros da morte |
| `zero_monarch` (Geada) | `goToAct(4, true)` → `combatReady` → `game.player.frost = threshold` (`BossMechanics.frostSpec(game).threshold`) → fim de turno → compra | `BM.onPlayerDraw` congela as 2 cartas mais caras (`card.frozen`); um ataque derrete uma | quadro da mão com 2 cartas congeladas; quadro de uma carta derretendo |
| `zero_tyrant` (Correntes) | `goToAct(3, true)` → `combatReady` → `enemy.health = ceil(0,76·maxHealth)` → jogar ataque ≥ 2% | `BM.onDamaged` cruza 75% e enfileira `chain_break`: a corrente rompe e o golpe anunciado cai pela metade | quadro antes (3 marcas), quadro do rompimento, intent reduzido |
