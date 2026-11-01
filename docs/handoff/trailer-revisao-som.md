# Frente: trailer-revisao-som (Grimoire)

## Frente
_Escrita em 01/11/2026. Pedido do Daniel (via Grimoire) depois de assistir ao trailer B (`grimoire_kinetic_new.mp4`); o retorno vale também para A (`grimoire_kinetic_hook30.mp4`) e C (`grimoire_trailer_v9_kinetic.mp4`)._

### Retorno do Daniel
- **(a) Faltam os sons do jogo e o ambiente nos momentos-chave.** Porta abrindo, entrada do chefe, detalhes do final: a trilha engole tudo. Hoje os três trailers só têm a faixa ACE-Step + SFX sintetizados (`build/trailer/sfx_synth`), e nenhum som real do jogo.
- **(b) Em alguns momentos a música tem que sair**, ficando só o som do jogo ou o silêncio, para dar foco; depois ela volta com impacto.
- **(c) Revisão completa** usando as skills e os MCPs novos.

### Escopo
1. Inventário das skills (`~/.claude/skills` e as do projeto) e dos MCPs configurados: quais ajudam e como.
2. Revisor (subagente) quadro a quadro com o áudio em B, A e C: quadros, forma de onda, espectrograma, loudness por janela e o `audio.jsonl` das tomadas. Saída: lista com timestamps de cada momento que pede som do jogo (SFX, ambiente, porta, chefe, cartas, UI) e de cada trecho que pede música baixa/abafada ou silêncio.
3. Remixagem, começando pelo B: SFX reais do jogo em primeiro plano nesses pontos (arquivos de `audio/` posicionados pelo `audio.jsonl` das tomadas, levados ao tempo do filme pela EDL; síntese só onde o jogo não tem o som), ducking da trilha, pausas de silêncio antes do chefe e do clímax, final com detalhe sonoro. Iterar em 1080p, depois master 4K a −14 LUFS e versão 720p. Depois A e C. Nomes novos (`*_som.mp4`); os masters atuais ficam intactos.

### Licença (atenção)
O handoff `trailer-kinetic.md` registra que os SFX do jogo (`audio/sfx/**`, inclusive `castle-gate-open.mp3`) vêm do **ElevenLabs free, sem uso comercial**. Usar os SFX do jogo é decisão do Daniel nesta frente. A Entrega lista a origem de cada som, e toda versão que usa SFX ElevenLabs sai marcada **"não publicável até confirmar licença"**. Nada novo é gerado no ElevenLabs.

**Atualização 01/11/2026 13:00:** o Daniel liberou o uso de **todos** os sons, inclusive os SFX do ElevenLabs free (como `castle-gate-open`). A versão serve para ele ver como fica; depois ele mesmo gera sons novos. Nenhum som deixa de ser usado por causa da licença. Toda versão com som do jogo leva a marca **"não publicável até trocar ou licenciar os SFX"**, e a Entrega anota a origem de cada som.

### Limites
Headless sempre, sem janela visível nem roubo de foco; 1 `lovec` por vez, identidade `card-game-trailer-v9`, save real intocado; nunca matar processo por nome; 0 crédito (sem Scenario, ElevenLabs, PixelLab pago, Higgsfield); nada para Steam/depot; sem push; commits em nome de Daniel Cortez; suíte completa só via `suite_lock.sh`.

### Insumos
- Masters: `E:\dev\projects\card-game-trailer\build\trailer\grimoire_kinetic_new.mp4` (B), `grimoire_kinetic_hook30.mp4` (A), `grimoire_trailer_v9_kinetic.mp4` (C).
- Filmes (vídeo sem áudio `out/video_4k.mp4` / `video_1080.mp4` + `out/mix.wav`): `E:\dev\_orquestracao\skills-externas\kinetic-film\grimoire_a|b|c`.
- EDLs: `E:\dev\projects\card-game-trailer\build\trailer\kinetic\{A,B,C2}_edl.json` (cópias em `docs/handoff/trailer-kinetic-*-edl.json`).
- Tomadas a 60 fps e o log de sons do jogo: `%APPDATA%\LOVE\card-game-trailer-v9\trailer\` (`audio.jsonl` único, com `shot`, quadro `f`, arquivo, volume base, pitch, ganho, grupo).

## Entrega
_01/11/2026. Remixagem dos três trailers com o som do jogo. A imagem é a dos masters aprovados, copiada sem recodificar no 4K e no 1080p; só o áudio é novo. 0 crédito gasto, nenhum `lovec` rodado, nada gerado no ElevenLabs, nada publicado, masters antigos intactos (30/10)._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.** As nove versões abaixo usam SFX do jogo gerados no ElevenLabs free (sem uso comercial), além de três arquivos de origem não documentada (`audio/hoverCard.wav`, `audio/clickselect2-92097.mp3` e `audio/sword-sound-260274.mp3`, os dois últimos com padrão de nome Pixabay). O uso foi liberado pelo Daniel em 01/11 às 13:00 só para ele ver como fica. A música continua sendo a ACE-Step local (uso comercial).

### Arquivos (R = `E:\dev\projects\card-game-trailer\build\trailer`)

| | B: principal | A: gancho | C: v9 |
|---|---|---|---|
| 4K (3840x2160, 60 fps, H.264 L5.2) | `R\grimoire_kinetic_new_som.mp4` (889 MB) | `R\grimoire_kinetic_hook30_som.mp4` (397 MB) | `R\grimoire_trailer_v9_kinetic_som.mp4` (740 MB) |
| 1080p (L4.2) | `R\grimoire_kinetic_new_som_1080p.mp4` (164 MB) | `R\grimoire_kinetic_hook30_som_1080p.mp4` (78 MB) | `R\grimoire_trailer_v9_kinetic_som_1080p.mp4` (157 MB) |
| 720p (L3.2, reescala por área do 1080p) | `R\grimoire_kinetic_new_som_720p.mp4` (47 MB) | `R\grimoire_kinetic_hook30_som_720p.mp4` (24 MB) | `R\grimoire_trailer_v9_kinetic_som_720p.mp4` (48 MB) |
| Duração / quadros | 65,30 s / 3918 | 32,30 s / 1938 | 64,50 s / 3870 |
| Loudness / pico (medidos no mp4) | −14,1 LUFS / −1,1 dBTP | −14,1 LUFS / −1,2 dBTP | −14,1 LUFS / −1,7 dBTP |
| Áudio | AAC 320k, 48 kHz | idem | idem |

Mixagens e stems para conferir ou remixar: `R\som\{A,B,C}\` (`mix.wav`, `stem_music/game_sfx/game_amb/synth.wav`, `mix_pre.wav`, `mix_sources.json` com cada evento, ganho e licença, `stems.png` com a curva de cada stem).

### Como foi feito
- **Motor** (`docs/handoff/trailer-revisao-som/remix_engine.py`): lê a EDL de cada filme, converte cada evento do `audio.jsonl` das tomadas (quadro a 60 fps) para o tempo do filme pelo `map` do clipe e coloca o arquivo real do jogo com o volume e o pitch que o jogo usou. Eventos que começaram antes do trecho entram com a cabeça aparada (ex.: `ice_wyrm_rise`, o ronco dos olhos). Cada som termina com fade curto no corte; sons longos (portão, pouso, revelação, vozes) soam até 1,2 s depois. A música passa por uma automação de volume e abafamento (passa-baixa) e por um ducking por sidechain disparado pelos SFX do jogo (até −6 dB). A normalização é um **ganho linear** até −14 LUFS mais um limitador de pico. O loudnorm em modo dinâmico desfazia os silêncios (o revisor mediu +2 dB no quarto mais baixo), por isso foi trocado.
- **Planos por trailer:** `plan_b.py`, `plan_a.py` e `plan_c.py` trazem os ganhos, a automação da música, os sons extras e os SFX sintetizados mantidos. Saídas: `make_outputs.py`. Conferência: `stem_report.py` (nível de cada stem nos pontos-chave), `limiter_check.py` (quanto o limitador corta) e `sources_table.py` (origem de cada som).
- **Revisão:** o revisor (subagente) analisou quadro a quadro, com forma de onda, espectrograma, RMS por janela e o `audio.jsonl`. Relatório em `trailer-revisao-som/review.md` e `review_{A,B,C}.json`, com imagens no scratchpad da sessão. A remixagem seguiu as cinco prioridades que ele listou para cada trailer.
- **Correções medidas durante as iterações:**
  - SFX quentes demais na 1ª passada: a entrada do chefe chegava a 0 dB RMS, contra −14 dB da música. Os grupos foram rebaixados.
  - Os grilos de fora continuavam tocando dentro do salão escuro (chiado de 8 a 12 kHz de 32,6 a 37,8 s no B). O clima externo agora é cortado no corte para o salão.
  - O ronco dos olhos deixava o silêncio tão alto quanto a música: −9 dB.
  - Picos que o limitador cortava em 5 a 6,6 dB (portão, pouso, JOGAR, corvo, carta do WISHLIST) foram baixados na fonte. Restam no máximo cerca de 4 dB em transientes de 50 ms; o pior é 5,5 dB no rasante de C em 44,05 s.
  - O 720p a 256k passava de 0 dBTP: o áudio passou a 320k em todas as versões, e o teto do limitador de C desceu para −2,0 dB.

### Mudanças por timestamp

**B (65,3 s)**

| t (s) | mudança |
|---|---|
| 0,00 | TV liga com o som do jogo (`boot-tv-power-on`) no lugar do sintetizado |
| 1,00 a 3,49 | música −6 dB na seleção da mão (hover e clique das cartas audíveis) e volta no grave do BUILD |
| 3,49 a 8,52 | JOGAR (`button-click` + `combo-trigger`), cartas voando, golpes com `sword-sound`, `impact-poison`, `card-exhaust` e voz do Bruto (`pit_brute/hurt_*`); brasas e vento ao fundo |
| 9,02 a 10,31 | recompensa: zumbido do cristal, `pack-seal-break` + `card-discovered` na rara (9,76), moedas e assinatura do coringa |
| 11,05 a 20,40 | música −8 dB; cada ato com o próprio ambiente (grilos, chuva, brasas, nevasca, pântano com trovão em 16,92, vento); os whooshes sintéticos dos atos saíram |
| 20,40 a 29,29 | música −7 dB e abafada; stinger de mini-chefe (20,40), parada do grifo (21,72), descida e pouso do anjo (24,85), serpente emergindo (25,0), sopro de gelo (26,38), chegada à loja |
| 29,29 a 32,59 | porta vista de fora: música desce a −14 dB, abafada; noite com grilos e vento; **portão do castelo** (`castle-gate-open`) a partir de 30,41 |
| **32,65 a 37,37** | **música fora**: olhos acendem (32,80), piscadas, três rasantes com corvos (35,24 a 36,07), pouso (36,79), penas e corvos; só o salão (`boss-room`) por baixo |
| 37,40 | **música volta no grave do drop** com o cartão do nome e `boss_reveal_sting` |
| 38,66 a 46,18 | salões IA com som de chefe do jogo: runa e leito do Lich, parede de fogo do Tirano, tempestade de gelo do Monarca, coração e raízes do Colosso, corvo e revoada do Rei |
| 46,35 a 51,20 | música −6 dB na mão dada e na seleção |
| **51,32 a 52,13** | **respiro sem música**: só o JOGAR e as cartas voando |
| 52,15 | **42**: música volta (+1 dB) com `impact-fire` + voz do Rei-Carniça + `card-exhaust` + peso do `boss_land_impact` |
| 53,11 / 53,72 | 33 e 27 + COMBO com espada, voz do Rei e assinatura do coringa |
| **55,05 a 57,16** | **música fora** no glitch e na bússola: dois giros (`boot-card-whoosh`), salão ao fundo e magia subindo (`castle-gate-magic`) |
| 57,18 | flash do logo: música volta no grave, com `forge-reveal`; letras com `pack-card-reveal` (57,60) |
| 60,01 | WISHLIST: `card-discovered` + selo sintetizado, com a música 5 dB abaixo por 0,8 s |
| 62,60 a 65,30 | fim: corvo distante, última carta puxada (63,40), fade da música de 62,6 a 65,25 (antes: 0,64 s, soava como corte) |

**A (32,3 s)**

| t (s) | mudança |
|---|---|
| 0,00 a 1,45 | TV do jogo, brasas e hover do cursor preenchem o buraco antes do PLAY. |
| 1,45 a 7,18 | JOGAR e golpes com os sons do jogo (espada, veneno, voz do Bruto) |
| 7,18 a 10,51 | encruzilhadas com chuva (a2) e nevasca (a4), música −7 dB |
| 10,51 a 15,01 | música −6 a −8 dB e abafada; stinger de mini-chefe, grifo, serpente e sopro de gelo (14,9) |
| 15,30 a 16,60 | porta: música −12 dB, noite e portão subindo |
| **16,80 a 17,97** | **música fora**; baque do portão no corte (17,76), olhos acendem |
| 18,00 | **música volta no drop** com o pouso do Rei e os corvos; revelação no nome (18,42) |
| 18,82 a 22,31 | salões: corvo, runa, parede de fogo |
| 22,45 a 24,18 | música −6 dB na seleção |
| **24,27 a 24,59** | **respiro**; 42 em 24,61 com a música de volta e os sons do golpe |
| **26,95 a 28,32** | **música fora** no glitch e na bússola (giro, salão, magia) |
| 28,34 | clarão com a música de volta; WISHLIST (29,17) com a carta; corvo e carta no fim; fade de 30,6 a 32,25 |

**C (64,5 s)**

| t (s) | mudança |
|---|---|
| 0,00 a 3,51 | TV do jogo; grilos e vento da estrada do ato 1 |
| 3,51 a 5,78 | encruzilhada do ato 1 com o som dela, música −6 dB |
| 5,78 a 10,75 | luta do ladino com os sons do jogo |
| 10,75 a 17,33 | salões no groove, cada um com o som do chefe; o coração explode em raízes (16,5) |
| 17,33 a 22,36 | música −5 dB e abafada; stinger, grifo, anjo, serpente |
| 22,36 a 26,14 | estrada com chuva e o trovão do jogo (24,36), música −8 dB |
| 26,14 a 39,01 | salões lentos com música −6 dB: leito de salão em loop, três runas acendendo, brasas e corrente do Tirano, coluna de fogo (32,85), nevasca, gelo, corvos |
| 39,40 a 41,10 | porta: música −14 dB e abafada |
| **41,30 a 46,18** | **música fora**: baque do portão no corte (41,76), olhos, piscadas, rasantes e pouso |
| 46,21 | **música volta no grave** com o cartão do nome |
| 48,45 a 52,06 | música −6 dB na mão e na seleção (os hovers logo antes do glitch saíram) |
| **52,17 a 52,47** | **respiro**; 42 em 52,49 com a música de volta |
| **55,98 a 58,72** | **música fora** no glitch e na bússola |
| 58,74 | clarão com a música de volta; WISHLIST (60,01); corvo e carta; fade de 62,0 a 64,45 |

### Inventário de skills e MCPs (detalhe em `trailer-revisao-som/inventario.md`)
- **USAR:** skill `audio-design` (grupos de áudio em dB, ducking por sidechain, headroom de −1 dBTP); `game-trailer-production` (SFX reais do jogo, checklist de áudio, proveniência); o pipeline local `skills-externas/kinetic-film` (EDLs, vídeos sem áudio, `mixdown.py` como base).
- **CONSULTAR:** `scenario-kinetic-film` (grade de beats, 4K no nível 5.2, sem `-shortest`; os passos com Scenario são pagos e não foram usados); `game-feel`; `ecc:video-editing`.
- **NÃO USAR:** `sound-effects` e `elevenlabs-music-generation` (geram no ElevenLabs/RunComfy, proibido); MCP `pixellab` (só arte); `rea`, `chrome-devtools`, `github` e os MCPs de outras empresas (isolamento). Não há MCP de Scenario nem de ElevenLabs configurado.

### Origem e licença de cada som
Tabela completa por arquivo, com quantas vezes aparece e em que tempos, para os três trailers: `trailer-revisao-som/sources_tables.md`. Cada evento, com o ganho aplicado, está em `R\som\{A,B,C}\mix_sources.json`. Resumo:

| Origem | Arquivos | Licença |
|---|---|---|
| Música `audio/music/boss-carrion_king.mp3` (B, C) e `boss-abyss_tyrant.mp3` (A) | 1 por trailer | ACE-Step 1.5 local, uso comercial |
| SFX do jogo `audio/sfx/**`: UI, cartas, impactos, vozes, chefe, corvos, entradas, stingers, clima, lugar, boot | B 71, A 58, C 72 arquivos distintos | **ElevenLabs free, SEM uso comercial**; usados com a liberação do Daniel de 01/11 13:00 |
| `audio/clickselect2-92097.mp3`, `audio/sword-sound-260274.mp3` | seleção de carta, espada | padrão de nome Pixabay, origem não documentada |
| `audio/hoverCard.wav` | hover de carta | origem não documentada |
| `build/trailer/sfx_synth/` (`whoosh_1/2`, `glitch`, `impact_heavy`, `impact_1`, `logo_seal`) | transições, glitch, cartão do nome, selo | síntese local, sem terceiros |

### Pendências
1. **Escuta humana.** Ninguém ouviu as mixagens: tudo foi conferido por medida (níveis dos stems nos pontos-chave, espectrograma, limitador, LUFS). O Daniel precisa ouvir os três 1080p, de preferência no fone e na caixa da TV.
2. **Licença:** trocar ou licenciar os SFX do ElevenLabs free e os três arquivos sem origem antes de publicar. O Daniel vai gerar sons novos. Como o motor lê o `audio.jsonl` pelo caminho do arquivo, basta substituir os arquivos em `audio/sfx/` com o mesmo nome e rodar `python plan_X.py` + `python make_outputs.py X`, sem tocar na imagem.
3. A bússola do logo não tem som próprio no jogo; usei o `boot-card-whoosh` (boot do jogo).
4. O limitador ainda corta até 5,5 dB num transiente do rasante de C (44,05 s, 50 ms) e até cerca de 4,5 dB em quatro outros pontos. Se soar abafado, baixar o `crowCine`/`bossWingPass` de C na fonte.
