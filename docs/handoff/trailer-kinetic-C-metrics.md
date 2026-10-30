# Conceito C (v9 kinetic): render e métricas

_30/10/2026, frente trailer-kinetic. Render com a skill Kinetic Film neste PC, sem Scenario, 0 crédito. Nada publicado._

## Arquivos

| O quê | Caminho |
|---|---|
| **Master 4K** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_trailer_v9_kinetic.mp4` (3840x2160, 60 fps, H.264 High L5.2 + AAC 320k, 64,50 s, 3870 quadros, 0,52 GB) |
| Versão 1080p (do master, pelo `finish.py`) | `...\build\trailer\grimoire_trailer_v9_kinetic_1080p.mp4` (0,15 GB, L4.2) |
| Folha de contato (1 quadro/s, do master) | `...\build\trailer\kinetic\v9_review\contact_sheet.jpg` |
| Métricas brutas | `...\build\trailer\kinetic\v9_review\metrics.json` (cópia: `docs/handoff/trailer-kinetic-C-metrics.json`) |
| Fonte do filme | pasta `E:\dev\_orquestracao\skills-externas\kinetic-film\grimoire_v9`; cópia de `spec.js`, `index.html` e `kscripts/` em `docs/handoff/trailer-kinetic-v9-film/` |
| Medidor | `tools/trailer_kinetic_metrics.py` |

**Tempo do render 4K: 1141 s (19 min 01 s)**: camada de tipografia (4 workers, ~35 s) + composição/encode x264 `slower` CRF 12,4 (1097 s, ~3,5 quadros/s), com outra sessão rodando `lovec` em paralelo. `finish.py` (mux, 1080p, verificações) levou mais ~5 min.

## Como foi montado

O motor Kinetic não tem bloco de vídeo e as regras do Grimoire proíbem motion blur, bloom e vetor liso no texto. Por isso o filme foi dividido em duas camadas:

1. **Tipografia (motor Kinetic):** `spec.js` declara o bloco `PixelType` (subclasse de `Scene`) sobre a grade do Rei-Carniça (95,6 BPM medidos pelo `beat_grid.py`). Grimoire Pixel (`assets/fonts/pixel.ttf`) amostrada na grade nativa de 8 px e desenhada em escala inteira (pixel de fonte = 10 a 16 px de tela em 1080), contorno de tinta de 1 pixel de fonte e sombra dura; entrada palavra a palavra no grave em passos de 15 fps (tamanho +3, +1, final; brilho de 1 passo; chute lateral de meio pixel por 2 passos), saída em dissolução de runa por hash em 4 passos. A última frase (WISHLIST) não dissolve. Captura pelo `render_layer.mjs` (base no `render.mjs` da skill: mesma página, mesmo `__seek`, `browser.mjs` da skill), 1 amostra por quadro, PNG com alfa, só nos quadros com tinta (1271 de 3870).
2. **Imagem (`compose.py`):** os clipes do v8 pela EDL `trailer-kinetic-C-edl.json` (velocidades, glitch_soft, dissolve, flash, zoom, glitch do logo, holds), a camada de texto por cima (vizinho mais próximo 2x no 4K: idêntica ao 1080 ampliado), e a **moldura do CRT (`bezel_ring` + `bezel_mask`) aplicada em todo quadro**: os salões Higgsfield e o `logo_sting`, que no v8 saíam sem moldura no fim, agora ficam dentro da TV.
3. **Som (`mixdown.py`):** `boss-carrion_king.mp3` p 10,05 a 73,55 contínua (fade de 0,6 s no fim) + `sfx_synth` nos tempos da EDL, loudnorm em dois passes para −14 LUFS / −1 dBTP. Ganhos ajustados depois de medir cada efeito contra a música no mesmo instante: os whooshes estavam ~20 dB abaixo do grave (inaudíveis) e subiram 10 a 11 dB; selo do logo +4, glitch +3, impact_1 +2. A EDL não foi alterada; o ganho final de cada efeito fica em `out/mix_sources.json`.

**Itens pendentes da seção 6 do prep resolvidos aqui:**
- **1º quadro preto:** o trailer começa em 0,50 s do v8 (todos os tempos da EDL −0,50; duração 64,5 s) e o **quadro 0 é um pôster** (o quadro de 3,40 s: estrada, castelo e SIX ACTS.). Ele dura 1/60 s antes da TV ligar e é o quadro que a Steam mostra parado antes do play.
- **SFX não ouvidos:** medidos contra a música (tabela acima); os inaudíveis subiram. Ainda vale uma escuta humana.
- **`logo_sting` só em 1080p:** entra ampliado 2x por vizinho mais próximo, dentro da moldura.
- **Não resolvidos (precisam regravar):** grifo, porta vista de fora, fork_a1, mão sendo dada; a luta acaba 0,03 s depois do 3º golpe.

## Os 10 critérios (master 4K)

| # | Critério | Meta | Medido | Resultado |
|---|---|---|---|---|
| 1 | Gameplay até | ≤ 2 s (< 4 s obrigatório) | quadro 0 = captura (pôster); captura contínua a partir de **0,77 s** | PASS |
| 2 | Sem preto | < 3 % de quadros com luminância < 5 % fora da TV ligando e do glitch | **7,8 %**; preto puro (< 2 %): **0 %**. Trechos: 42,03 a 44,42 (salão do Rei no escuro, só os olhos, cena do v8) e 55,00 a 57,52 (abertura roxa escura do `logo_sting`) | **FAIL** (escuro de conteúdo, não preto) |
| 3 | Sincronia nos graves | mediana ≤ 1 quadro, máx ≤ 3 | cortes ancorados: mediana **0,2**, máx **1,8** quadro (9 medidos no vídeo; 4 dissolves pelo tempo nominal); palavras: mediana **0,3**, máx **0,6** | PASS |
| 4 | Legibilidade | ≥ 1 s/13 car., glifo ≥ 64 px, ≤ 30 car./linha, 1 texto por vez | todas as frases passam (a mais justa: YOUR CARDS… 4,97 s para 2,46); glifo mín. **70 px** (1080); maior linha 23 car.; nunca 2 frases juntas. Teste mudo com pessoas: pendente | PASS (teste mudo pendente) |
| 5 | Ritmo | plano médio 2–4 s, ≤ 2 rajadas < 1 s | 18 planos, média **3,57 s**; 1 plano < 1 s (salão de gelo 0,94 s), 1 rajada | PASS |
| 6 | Pico | número de dano maior em 75–82 % | golpe 1 da luta em **52,50 s = 81,4 %**, no grave | PASS |
| 7 | Regra de 3 | gancho 2–3 vezes | chefe-quebra-cabeça 3× (salões no groove, salões lentos + EVERY BOSS IS A PUZZLE, Rei-Carniça entra e luta); deck vivo 2× (cartas do ladino + BUILD A LIVING DECK, mão na luta) | PASS |
| 8 | Fecho | cartão final 3–8 s, nada depois do CTA | WISHLIST ON STEAM. de 60,01 a 64,50 = **4,49 s**, CTA no último quadro | PASS |
| 9 | Conformidade | 0 asset proibido, flashes ≤ 3/s, moldura 100 %, cenários válidos, −14 LUFS | áudio = só `boss-carrion_king.mp3` + 9 arquivos de `sfx_synth`; máx **2 flashes/s**; moldura em **100 %** dos quadros após a TV ligar (diferença média 2,2/255); 14 clipes, todos válidos; **−14,4 LUFS**, pico −0,7 dBFS | PASS |
| 10 | Checklist Daniel | ver abaixo | 11 itens + sem cara de IA + música contínua | 10 ok, 3 parciais |

### Gates da skill (`finish.py`)
Técnicos: quadros 3870/3870, 0,52 GB, nível 5.2, −14,4 LUFS: **PASS** no 4K e no 1080p. Dinamismo: **FAIL** (71 % de quadros parados contra meta de 40 %; parados > 0,6 s em 2,42 / 3,65 / 17,68 / 18,73 s; movimento mediano 0,33 px/quadro contra 2,5). Esses três limites são calibrados para reels de tipografia sobre fundo de motion design; aqui a imagem é captura pixel-art do jogo e os textos ficam parados para cumprir a regra de leitura (critério 4). Não forcei movimento: zoom ou pan contínuo em escala não inteira borraria a pixel art, e foi exatamente isso que o Daniel rejeitou como "cara de IA".

### Checklist Daniel (critério 10)

| Item | v9 |
|---|---|
| 1. TV liga antes da música | ok (TV liga de 0 a 0,75 s, música em 1,00 s) |
| 2. Cenas regravadas no jogo atual | parcial: clipes do v8 (regravação aguarda o OK) |
| 3. Inimigo aparece desde o quadro 0 da entrada | ok (anjo e serpente cortados sem os 0,12 s de transição do v8) |
| 4. Menos gameplay, mais animação | ok (mesma proporção do v8, texto kinetic por cima) |
| 5. Sem o mago | ok (ladino nas cartas, guerreiro no chefe) |
| 6. Porta do castelo audível | parcial: porta sintetizada (rangido + baque) no lugar do som ElevenLabs; a porta vista de fora não tem imagem limpa |
| 7. Chefe entrando inteiro | ok (entrada do v8) |
| 8. Música para e volta sincronizada | ok (pad sem grave de 26,1 a 46,2 s com dissolves; cortes no grave antes e depois) |
| 9. Salões nos acentos | ok (5 salões, 1 por grave, Δ ≤ 0,8 quadro) |
| 10. Sons e sincronia no logo/WISHLIST | ok (flash do logo e selo no grave) |
| 11. Revisão quadro a quadro | parcial: folha de contato + medição de graves; falta a escuta humana dos SFX |
| Sem cara de IA | ok: texto em pixel inteiro, sem blur/bloom/gradiente (salões Higgsfield continuam IA declarada, como no v8) |
| Música contínua, séria, do bioma | ok (Rei-Carniça, um trecho contínuo) |

## O que muda em relação ao v8
- Trilha T4 (sem licença) → Rei-Carniça ACE-Step contínua; nenhum SFX do jogo/ElevenLabs.
- TV de 3 s sem música → 0,75 s, com pôster no quadro 0 e captura contínua em 0,77 s.
- Os 5 textos aprovados viram tipografia kinetic palavra a palavra no grave (Grimoire Pixel inteira); nomes de chefe nos salões e as 2 telas pretas de frase saíram (estrada do ato 2 à noite no lugar).
- Moldura do CRT em 100 % dos quadros (o v8 perdia a moldura no logo).
- 64,5 s (v8: 62,0 s).

## Origem do áudio
| Arquivo | Origem / licença |
|---|---|
| `audio/music/boss-carrion_king.mp3` (p 10,05 a 73,55) | ACE-Step 1.5 local, uso comercial |
| `build/trailer/sfx_synth/{tv_on, whoosh_1, whoosh_2, impact_1, impact_2, impact_heavy, castle_door, glitch, logo_seal}.wav` | síntese local numpy/scipy (`tools/synth_trailer_sfx.py`), sem amostra externa |

Imagem: clipes do v8 (captura do jogo) + salões `ai_4k/hall1..5` (Higgsfield, IA: declarar na Steam) + `logo_sting`. Fonte: Grimoire Pixel (OFL).

## Reproduzir
```
cd E:\dev\_orquestracao\skills-externas\kinetic-film\grimoire_v9
..\venv\Scripts\python.exe kscripts\layer.py . 4
..\venv\Scripts\python.exe kscripts\mixdown.py .
..\venv\Scripts\python.exe kscripts\compose.py . --res 4k
..\venv\Scripts\python.exe C:\Users\corte\.claude\skills\scenario-kinetic-film\scripts\finish.py . --video out\video_4k.mp4 --audio out\mix.wav --no-vertical --dest out\final4k
..\venv\Scripts\python.exe -I E:\dev\projects\card-game-love2d\tools\trailer_kinetic_metrics.py <mp4> --spec spec.js --sources out\mix_sources.json --layer out\layer --json metrics.json --sheet contact_sheet.jpg
```
