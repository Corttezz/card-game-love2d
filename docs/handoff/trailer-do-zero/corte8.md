# Corte 8 (trailer-do-zero)

_Diretora, 01/11/2026. Base: `revisao-grimoire-corte7.md` (commit 816f0997, 7 pontos), as decisões do Grimoire sobre o ponto 2 (22:43 e a definitiva) e a confirmação do Daniel. **Sem 4K, Steam, push ou save real. Um `lovec` por vez, headless. Nenhuma troca de faixa, texto ou salão; nenhuma carta inventada.** Os arquivos do corte 7 ficaram intactos._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| principal (Tirano) 1080p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte8_1080p.mp4` |
| principal 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte8_720p.mp4` |
| variante (Rei-Carniça) 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte8_rei_720p.mp4` |

Pipeline: `corte/edl8.py` (o `edl7.py` + `_c8()`), `build_video.py` (novos: `pan` no ×3, `glint`, `HALL_OUTLINE`), `crt_pass.py`, `mix2.py`, `mux2.py`, `med8.py`, `verificar.py`, `tab_p3p4.py`. Pastas de trabalho `zero8` e `zero8_rei`. Provas em `corte8_provas/`.

**Ratificado pelo Grimoire:** o pouso do Rei 2,7 quadros depois do ataque de 27,585 s fica como está.

## Conferência dos 7 pontos (no corte 7) e resultado

| # | ponto | procede? | prova | o que foi feito no corte 8 |
|---|---|---|---|---|
| 1 | zoom que recua no fim da luta | **Sim, nas duas.** Duas causas: (a) ×2 na vida → **×1** na mão → ×2 no LETHAL (recuo no meio); (b) o golpe usa a câmera da **cinemática de morte do jogo**, mais aberta que a da batalha, então o ×2 do golpe mostrava o Rei menor que o ×2 do LETHAL. | `tirano/p1_zoom_45.6-51.1s_8q.png`, `rei/p1_zoom_45.5-50.9s_8q.png`, `p1_camera_jogo_batalha49.0_morte52.95_53.6.png` | Revoada ×2 → vida ×2 → **um só plano ×2** com o Rei, a mão e o painel "0/48 → 48 LETHAL" (recorte (860,460), sem o ×1 no meio) → golpe **×3** no Rei (câmera da morte, recorte (640,330), hit-stop, flash, tremor, "48") → queda ×3 que **desce 1 px de captura por quadro** de y=330 a 460, acompanhando o corpo. Só degraus que avançam. Provas: `tirano/p1_degraus_so_avancam_45.60-52.20s.png`, `rei/p1_degraus_so_avancam_45.60-52.00s.png`. |
| 2 | carta Murder of Crows não aparece no Tirano | **A carta não existe no jogo.** "Murder of Crows" é o **golpe do Rei-Carniça** (`src/data/enemies.lua:100`, `murder_of_crows`, nome em `enemy_kit`), não carta: nenhuma carta com esse nome em `src/data/cards/`. O **nome do golpe** aparece nas duas versões no corte 7. | `p2_murder_of_crows_nao_e_carta.txt`, `p2_mao_jogador_tomada_35.3-37.7s.png` (a mão sai antes do turno do Rei; nenhuma carta de corvo), `p2_revoada_tirano_x_rei.png` | **Decisão definitiva do Grimoire** (confirmada pelo Daniel): o anúncio do golpe atende, sem criar carta. Nas duas versões, o plano da Revoada passou a ser **×2 no Rei** (recorte (480,200)): ENEMY TURN → o nome "**Murder of Crows**" com o intent **4×4**, com o quadro em que o nome está cheio (tomada 36,95 s) **segurado 0,6 s** (quadros repetidos). Nome legível por **1,0 s** na principal e **0,85 s** no Rei (dentro de 0,8 a 1 s); os cortes não mudaram e os corvos partem no corte da batida. Prova: `p2_anuncio_revoada_c8_tirano_x_rei.png`. |
| 3 | golpe do Rei em ~49,9 s, é o ataque mais forte? | **Não procede.** O golpe da variante está a **50,36 s**. Na **mixagem final** é o ataque mais forte da região (força 11,80, +1 quadro). Na faixa sozinha (sem a automação) o mais forte é 50,782 s, que é o corte da **queda**; o golpe cai no respiro de 0,6 s com a música em −∞, e a volta dela no golpe é o ataque audível. Em 49,865 s há só um onset fraco (1,89). **Não mexido.** | `p3_onsets_golpe_rei.md` (tabela abaixo) | nada |
| 4 | castelo → portão ~1,4 s contra 2,24 s | **Intervalo diferente, explicado.** Nenhum corte nem quadro de castelo existe em 25,9 s. Os 2,24 s são **esporo + pouso do anjo**, do fim da Geada (25,07 s) ao **primeiro quadro do castelo, que é o próprio plano do portão** (27,31 s). | `rei/p4_antes_portao_24.9-27.5s_10qps.png` (tabela abaixo) | nada |
| 5 | fumaça roxa com dithering entre o salão e o Rei | **Não é transição nossa.** Do salão IA para o salão escuro é **corte seco** (33,0 → 33,1 s do Tirano no corte 7). A fumaça roxa pontilhada é a **cinemática do próprio jogo** (olhos no escuro), **idêntica na tomada crua**. **Não mexido**: tirar é apagar arte do jogo. | `tirano/p5_fumaca_31.4-34.6s.png`, `p5_fumaca_tomada_crua13.8_x_corte7_33.9.png` | nada |
| 6 | Carrion Crown congelada chapada 2,8 s | **Sim.** | — | **Brilho na grade de pixel** (faixa diagonal em blocos de 4 px, +38 de luz) passando pela face a cada **1,2 s** durante o quadro segurado; a face continua legível. Um erro do primeiro render (o brilho somava sobre os quadros repetidos e lavava a carta) foi achado e corrigido antes da entrega. Provas: `tirano/p6_brilho_carta_6q.png`, `rei/p6_brilho_carta_6q.png`. |
| 7 | contorno nas silhuetas dos salões IA | **Sim** (pedido de estilo). | — | Contorno escuro de **1 pixel da grade** (5 px na tela), com a cor mais escura da paleta do salão real, no lado escuro das bordas fortes (diferença de luminância > 55), depois da limpeza. Mesmos salões. Prova: `tirano/c8_saloes_contorno_31.0_14.5s.png`. |

## Ponto 3: onsets (librosa) da variante do Rei entre 49,3 e 51,3 s

Faixa montada (`music_rei.wav`, sem automação), p75 = 3,92:

| onset (s) | força | forte | distância ao golpe 50,36 (quadros) |
|---|---|---|---|
| 49,517 | 3,85 | | −50,6 |
| 50,178 | 2,95 | | −10,9 |
| 50,492 | 3,45 | | +7,9 |
| 50,782 | 7,32 | sim (é o corte da queda) | +25,3 |

Mixagem final (`mix.wav`, com o respiro em −∞), p75 = 3,36:

| onset (s) | força | forte | distância ao golpe 50,36 (quadros) |
|---|---|---|---|
| 49,517 | 3,38 | sim | −50,6 |
| 49,865 | 1,89 | | −29,7 |
| 50,213 | 2,15 | | −8,8 |
| **50,376** | **11,80** | **sim (o golpe)** | **+1,0** |
| 50,492 | 3,41 | sim | +7,9 |
| 50,724 | 5,13 | sim | +21,8 |

## Ponto 4: intervalo antes do castelo (variante do Rei)

| trecho | início (s) | fim (s) | duração (s) | contado nos 2,24 s? |
|---|---|---|---|---|
| Geada do Monarca (último plano antes) | 22,25 | 25,07 | 2,82 | não |
| mãe-esporo (ato 5) | 25,07 | 26,31 | 1,24 | **sim** |
| pouso do anjo (ato 6) | 26,31 | 27,31 | 1,00 | **sim** |
| portão do castelo (primeiro quadro com o castelo) | 27,31 | 30,08 | 2,77 | não (é o castelo) |
| **antes do castelo** | **25,07** | **27,31** | **2,24** | — |

Os ~1,4 s do revisor não batem com nenhum limite de plano; o mais próximo é o pouso do anjo (1,00 s) mais parte do esporo.

## Medidas finais (mp4)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA | −14,1 LUFS / −1,1 dBFS / 8,4 LU | −14,1 LUFS / −1,1 dBFS / 8,6 LU |
| margem do pico | +2,5 dB | +3,1 dB |
| coringa: música abaixo do SFX | 4,7 dB | 5,2 dB |
| revelação do coringa | 55,24 s (plano 55,22 s) | 54,92 s (quadro da face) |
| quadros < 5% de luma | 0 | 0 |
| música no fecho | até 64,5 s, com fade | até 64,5 s, com fade |

## O que continua igual
Os 10 pontos do corte 5 e as correções dos cortes 6 e 7: soco de câmera do jogo fora, "48" grande, corpo segurado sem a carta sob "BREAK THEM BACK.", coringa com um giro só, música até o fim, portão no ataque, salões na grade de 5 px, tom de sala na entrada do Rei.
