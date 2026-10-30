# Conceito A (grimoire_kinetic_hook30): render e métricas

_30/10/2026, frente trailer-kinetic. Mesmo método de duas camadas do C e do B (`trailer-kinetic-C-metrics.md`): tipografia pelo motor Kinetic Film (Grimoire Pixel inteira, fundo transparente, 1 amostra por quadro) + composição e moldura do CRT por script. Faixa: só `boss-abyss_tyrant.mp3` (ACE-Step) + `sfx_synth`. Sem Scenario, 0 crédito, nada publicado, nenhum `lovec`, nenhuma tomada apagada._

## Arquivos

| O quê | Caminho |
|---|---|
| **Master 4K** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_kinetic_hook30.mp4` (3840x2160, 60 fps, H.264 High L5.2 + AAC, **32,30 s**, 1938 quadros, 0,42 GB, −13,9 LUFS) |
| Versão 1080p (do master) | `...\build\trailer\grimoire_kinetic_hook30_1080p.mp4` (0,08 GB) |
| Folha de contato (1 quadro/s) | `...\build\trailer\kinetic\A_review\contact_sheet.jpg` |
| Métricas brutas | `...\build\trailer\kinetic\A_review\metrics.json` (cópia: `docs/handoff/trailer-kinetic-A-metrics.json`); a 1ª versão (antes de tapar os coringas e clarear) em `metrics_v1.json` |
| EDL | `...\build\trailer\kinetic\A_edl.json` (cópia: `docs/handoff/trailer-kinetic-A-edl.json`), gerada por `kscripts/make_edl.py` |
| Fonte do filme | `E:\dev\_orquestracao\skills-externas\kinetic-film\grimoire_a`; cópia em `docs/handoff/trailer-kinetic-A-film/`; patch e clareamento comuns em `docs/handoff/trailer-kinetic-fx/` |

**Tempo do render 4K: 490 s (8 min 10 s)** (camada de texto + mixagem + composição/encode x264 `slower`, ~4 quadros/s). A 1ª versão, sem o patch dos coringas, levou 448 s.

## Corte (t = p − 11,93; graves medidos de `boss-abyss_tyrant_beats.json`)

| t | imagem (tomada: quadros) | âncora | texto |
|---|---|---|---|
| 0,00–7,18 | `deck8` 780→1138: TV liga sintetizada sobre a mão do ladino (0 a 1,0); música entra seca no JOGAR; golpes 2 a 4 nos graves 3,48 / 4,28 / 4,87; termina antes do tooltip "Shadow Dance" (1140) | graves | **PLAY.** (1,45, JOGAR) · **BREAK.** (3,48, golpe com número) |
| 7,18 / 8,82 | `fork_a2` e `fork_a4` (encruzilhadas, castelo ao centro) | graves | **SIX ACTS.** (7,18) · **ONE ROAD / TO THE CASTLE.** (8,82) |
| 10,51–13,55 | `entr_storm_griffin` 560→742 (pouso 661 em 12,19) | grave | **YOUR CARDS** (10,51) · **DECIDE** (10,81) · **WHAT SURVIVES.** (11,19) |
| 13,55–15,01 | `entr_ice_wyrm` 470→558 | grave | — |
| 15,01–17,76 | `boss8` 399→564: porta vista de fora, o portão abre no baque (grave 17,76) | pad / grave | — |
| 17,76–18,00 | `boss8` 745→759: corte seco para os olhos no escuro | grave | — |
| 18,00–18,82 | `boss8` 990→1039: drop, o Rei-Carniça pousa inteiro, o cartão do nome sobe | drop | — |
| 18,82 / 19,73 / 20,31 | salões 4K `hall1_carrion`, `hall2_lich`, `hall3_tyrant` | graves | **EVERY BOSS** (18,82) · **IS A PUZZLE.** (19,73) |
| 22,31–26,89 | `boss8` 1310→1585: luta do guerreiro, JOGAR em 24,18; **golpe de 42 (o maior número) no grave 24,61 = pico**; 33 e 27 + COMBO depois | graves | — |
| 26,89–27,16 | glitch | graves | — |
| 27,16–32,30 | `logo_sting` (de 1,0 s, 1,373x): impacto da arte no grave 28,34 | graves | **WISHLIST ON STEAM.** (29,17, até o fim) |

Pôster no quadro 0: o quadro de 3,90 s (golpe do ladino com BREAK.). A loja não entra no A. A faixa de 30 s foi estendida a 32,3 s para o cartão final ter 3 s depois do WISHLIST (critério 8); o pico continua em 76 %.

## Coringas com rosto e escuro (correção do Grimoire, 30/10)
- **Coringas com rosto:** a faixa "JOKERS 3/3" do HUD de combate mostra rostos (caveira, máscara e elmo no deck do ladino; encapuzado e rosto de mulher no chefe) em `deck8` e `boss8`. A câmera do combate fica parada, então a faixa é trocada pelos mesmos pixels de um quadro limpo do mesmo plano, de antes de o HUD aparecer (`deck8` 580, `boss8` 1195). O ganho é casado numa borda em volta (o HUD escurece o cenário) e a emenda é suavizada. Quando a faixa "COMBO!" passa por cima, ela é reconstruída por linha (razão de escurecimento medida logo ao lado), para não sair cortada. Máscaras: `patches/make_patches.py`; aplicação: `patches/fx.py`.
- **Escuro (critério 2):** gamma adaptativo só dentro da tela (nunca na moldura), até a média chegar a 6,2 % nos quadros abaixo disso. No A foram 95 quadros (olhos no escuro e anel do logo), gamma mínimo 0,864. A TV ligando e o glitch ficam de fora, como na regra do critério.

## Os 10 critérios (master 4K)

| # | Critério | Meta | Medido | Resultado |
|---|---|---|---|---|
| 1 | Gameplay até | ≤ 2 s | quadro 0 = captura (pôster); captura contínua em **0,33 s** | PASS |
| 2 | Sem preto | < 3 % | **0,0 %** fora da TV/glitch (0,77 % no total, todo dentro da TV ligando); antes do clareamento: 4,6 % | PASS |
| 3 | Sincronia nos graves | mediana ≤ 1 quadro, máx ≤ 3 | cortes: mediana **0,2**, máx **0,8** quadro (10 de 11 medidos); palavras: mediana **0,4**, máx **0,8** | PASS |
| 4 | Legibilidade | ≥ 1 s/13 car., glifo ≥ 64 px, ≤ 30 car./linha, 1 texto por vez | 6 frases passam; glifo mín. **70 px**; maior linha 18 car.; uma por vez. Teste mudo pendente | PASS |
| 5 | Ritmo | plano médio 2–4 s, ≤ 2 rajadas < 1 s | 13 planos, média **2,46 s**; 4 planos < 1 s (olhos, pouso, 2 salões) numa única rajada | PASS |
| 6 | Pico | 75–82 % | golpe de 42 em **24,61 s = 76,2 %** | PASS |
| 7 | Regra de 3 | 2–3 vezes | chefe 3× (porta/olhos/pouso, salões + EVERY BOSS IS A PUZZLE, luta); cartas 2× (PLAY. e BREAK.) | PASS |
| 8 | Fecho | 3–8 s, nada depois | **3,13 s** de WISHLIST ON STEAM. até o último quadro | PASS |
| 9 | Conformidade | 0 asset proibido, ≤ 3 flashes/s, moldura 100 %, cenários válidos, −14 LUFS | áudio só Tirano + `sfx_synth`; **1 flash/s**; moldura **100 %**; 10 fontes válidas; **−13,9 LUFS**, pico −0,9 dBFS; nenhum coringa com rosto (conferido na folha de contato e em 1:1) | PASS |
| 10 | Checklist Daniel | ver `trailer-kinetic.md` (Entrega) | 11 ok, 2 parciais (tomadas 2 commits atrás da `main`; escuta dos SFX) | parcial |

`finish.py`: técnicos PASS (quadros, 0,42 GB, nível 5.2, −13,9 LUFS); dinamismo FAIL (78 % parados, movimento mediano 0,29 px/quadro), pelo mesmo motivo de B e C: os limites são de reel de tipografia, e aqui a imagem é captura pixel-art com texto parado para leitura.

## Reproduzir
```
cd E:\dev\_orquestracao\skills-externas\kinetic-film
venv\Scripts\python.exe patches\make_patches.py
cd grimoire_a
..\venv\Scripts\python.exe kscripts\make_edl.py
..\venv\Scripts\python.exe kscripts\layer.py . 4
..\venv\Scripts\python.exe kscripts\mixdown.py .
..\venv\Scripts\python.exe kscripts\compose.py . --res 4k
```
(ou `render_all_4k.sh`, que roda A, B e C um depois do outro com `finish.py` e o medidor)
