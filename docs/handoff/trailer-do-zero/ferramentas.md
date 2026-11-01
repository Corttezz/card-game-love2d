# Etapa 2: ferramentas (trailer-do-zero)

_Diretora, 01/11/2026. Base: inventário de 01/11 da frente de som (`docs/handoff/trailer-revisao-som/inventario.md`, ainda válido, não repetido aqui por inteiro), leitura do código das ferramentas e **um teste real** de captura sem CRT + recorte em escala inteira. Regras: 0 crédito, headless, 1 `lovec`, identidade `card-game-trailer-v9`, nada de 4K até liberação._

## 1. Inventário e veredito

| ferramenta | onde | o que acrescenta a ESTE trailer | veredito |
|---|---|---|---|
| **Gravador headless** `tools/trailer_record.lua` | worktree novo `E:\dev\projects\card-game-trailer-zero`, branch `trailer-do-zero` (a partir de `steam-store-v2` 9a00d164) | jogo real quadro a quadro, relógio simulado, 60 fps, áudio do jogo logado em `audio.jsonl`; 39 tomadas prontas (`poweron`, `night`, `entrances`, `deck8`, `boss8`, `bosses`, `eclipse`, `inspect`, `collection2`, `pack`, `reward`, `shop`, `victory`, `fork`...); chaves `TRAILER_CRT=0`, `TRAILER_NOBEZEL=1`, `TRAILER_SIZE`, `TRAILER_PIPE=1` (grava mkv direto, sem TGA) | **USAR: base de toda imagem.** Mudança feita: `TRAILER_OUT=<pasta>` (antes a saída era fixa em `trailer/` e regravar apagava as tomadas dos trailers antigos) |
| **Recorte em escala inteira** (ffmpeg `crop` + `scale=flags=neighbor`) | — | a carta legível (ver §2) e a câmera virtual dentro do jogo | **USAR** |
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
