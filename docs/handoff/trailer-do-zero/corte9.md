# Corte 9 (trailer-do-zero)

_Diretora, 02/11/2026. Base: `revisao-grimoire-corte8.md` (00:07, commit 83eea09e), `instrucao-corte9-0006.md`, as exigências do Grimoire na revisão do corte 9 e o **feedback direto do Daniel (00:46), prioridade máxima**: sem nenhum zoom e final igual ao de um corte anterior. Repasse final em `tdz_c9_final.txt` (00:54). **Sem 4K, Steam, push ou save real. Um `lovec` por vez. Nenhuma troca de faixa, texto ou salão; nada criado que não exista no jogo.** Masters antigos intactos._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| principal (Tirano) 1080p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte9_1080p.mp4` |
| principal 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte9_720p.mp4` |
| variante (Rei) 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte9_rei_720p.mp4` |

Pipeline: `corte/edl9.py` (o 8b + `_c9()`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py`, `med9.py`, `folha_queda.py` (escala por quadro), `verificar.py`. Provas em `corte9_provas/`. O render com zoom das 00:51 foi refeito por inteiro sem zoom (as saídas têm os mesmos nomes do corte 9, nenhum master antigo foi tocado).

## Daniel (00:46)

| pedido | resultado |
|---|---|
| tirar todos os zooms | **Todos os planos em tela inteira (×1)** nas duas versões, sem recorte nem pan. O golpe final pesa só com hit-stop, flash, tremor e o "48" grande. Não achei zoom indispensável: a carta da mão está a 2 px por pixel lógico e a vida "9/70" e o "48 LETHAL" leem na tela inteira (`corte9_provas/rei/p3_luta_rei_mesmo_lado_41.00-47.00s.png`). |
| final igual ao de um corte anterior | **FINAL_DO_CORTE=2.** O bloco do logo e do CTA é o mesmo código desde o corte 1. Diferença média no mesmo instante depois do início do logo: os cortes 1 e 2 formam um grupo (1,3 a 3,4/255 entre si); os cortes 4 a 8b, outro (1,1 a 1,3/255 entre si, 3,3 a 4,3/255 do corte 2); o corte 3 fica no meio. O que mudou do corte 2 para a frente foi o WISHLIST entrar 0,34 s antes (+3,87 s) e o fundo. No corte 9 voltaram os **tempos do corte 2**: selo +0,23, GRIMOIRE +0,83, gênero +1,63, **WISHLIST +4,21 s**. O fundo é a mesma sala escura com o corpo, agora em tela inteira (a tomada de 63,20 s do corte 2, sem zoom, mostraria o painel "Round Evaluation" do jogo, por isso o fundo é a tomada de 55,25 s). Nenhum texto nem música trocados. Provas: `final_cortes_1a8b_ultimos_6.5s.png`, `final_corte2_x_corte8b.png`. |

## Pontos do Grimoire (00:07 + 00:06 + exigências do corte 9): real ou falso, com prova

| # | ponto | real/falso | prova | o que foi feito |
|---|---|---|---|---|
| 1 | recuo na queda do Rei | **Real na percepção, falso como zoom** no 8b (escala medida constante; o "abrir" vinha do pan descendo). Sem zoom agora, não existe. | `tirano/p00_queda_50.40-53.40s_8q.png`; **folha de cada quadro com a escala**: `tirano/p1_queda_cada_quadro_semzoom_50.30-55.25s.png` (297 quadros), `rei/p1_queda_cada_quadro_semzoom_50.30-54.58s.png` (257 quadros): **nenhuma mudança de escala acima de 3% entre quadros vizinhos**. O Rei aparece de corpo inteiro o tempo todo, no enquadramento da tela inteira, sem saltos. | tela inteira do golpe até os ossos |
| 2 | contorno nas chamas, lava e tochas | **Real** | `tirano/p1_lava_14.5s_1para1.png`, `tirano/p1_trono_31.0s_1para1.png` (8b) | contorno excluído onde é quente/saturado (matiz ≤ 25, sat ≥ 110, valor ≥ 150) ou muito claro (≥ p82), com 2 px de folga; fogo e lava sem o filtro de suavização (bordas duras na paleta de 32 cores). Depois: `tirano/p2_lava_c9_1para1_14.50s.png`, `tirano/p2_trono_c9_1para1_31.50s.png` |
| 3 | Carrion Crown chapada / brilho artefato | **Real** | `tirano/p2_brilho_57.95s_1para1.png` (8b) | inclinação sutil em degraus de 5 px (até ±10 px), sombra projetada opaca na grade (+15 px) e brilho novo de **2 tons da paleta, opaco, faixa de 5 px**, só sobre áreas claras. `tirano/p3_carta_profundidade_c9_57.40-58.40s.png` |
| 4 | face do coringa no Tirano (~0:55) | **Falso**: face legível de ~55,8 a 58,35 s (2,5 s) | `tirano/p04_face_coringa_55.25-58.0s_corte8b.png` | nada |
| 5 | esporo/anjo/portão (Rei) | **Real** (1,24 / 1,00 / 2,77 s) | `rei/p5_esporo_anjo_portao_24.90-27.60s.png` | esporo **1,29 s** (25,07–26,355, ataque forte 11,0), anjo **1,23 s** (26,355–27,585), portão **2,50 s** no ataque de **27,585 s** (o ratificado), abrindo logo no começo. `rei/p5_esporo_anjo_portao_c9_24.90-30.20s.png` |
| 6 | caminhada antes do castelo (Tirano) | **Real** (portão parado ~0,9 s antes de abrir) | `tirano/p2_antes_castelo_22.00-30.40s.png` | esporo 1,44 s, anjo 1,15 s, **portão 2,11 s** começando na tomada 9,19 s (as folhas abrem em ~0,4 s), cortes nos onsets locais (25,38 / 26,819 / 27,968 s) |
| 7 | respiro antes do 48 | **Real**: no 8b a mixagem ia de −21 para −20 dBFS (os efeitos enchiam) | medida | efeitos −32 dB e ambiente −40 dB no respiro: **Rei −18,3 → −51,3 dBFS (33 dB de queda)**, golpe −4,1; **Tirano −20,1 → −50,8 (30,7 dB)**, golpe −4,3 |
| 8 | luta do Rei fragmentada / Rei pulando de lado | **Real** com zoom (Rei à direita no plano da vida, à esquerda no do LETHAL) | `tirano/p4_virada_42.80-47.00s.png` | sem zoom, o Rei fica **no centro em todos os planos** de 41 a 50 s; cortes da luta nos ataques (vida 43,25 s, ataque 6,46). `rei/p3_luta_rei_mesmo_lado_41.00-47.00s.png` |
| 00:06-3 | escuro de 0:31 a 0:34 ≤ 1,5 s | **Real** (2,6 s de olhos no escuro) | `tirano/p3_escuro_29.90-37.10s.png` | o escuro com os olhos caiu para **1,5 s** (pulo invisível dentro do escuro, da tomada 13,65 para 14,75 s); o 1,1 s foi para o trono do Higgsfield (salão em acento), então nada depois do silêncio mudou de tempo |
| 00:06-7 | anúncio Murder of Crows ~1,1 s (Rei) | **Real** (0,85 s) | `rei/p7_anuncio_41.90-43.40s.png` | nome legível **1,1 s** (quadro do nome segurado 66 quadros); os corvos partem no mesmo corte |
| 00:06-8 | gancho só com o Espantalho respirando | **Falso em parte**: as cartas sobem a partir de 0,6 s | `tirano/p8_gancho_0.00-3.00s.png` | com a tela inteira, o quadro 0 já mostra a mão inteira, o HUD e o Espantalho com a cabeça (`tirano/p8_gancho_c9_0.00-2.60s.png`) |

## Medidas finais (mp4)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA | −14,1 LUFS / −1,0 dBFS / 8,1 LU | −14,1 LUFS / −1,2 dBFS / 8,5 LU |
| margem do pico | +2,4 dB | +3,1 dB |
| coringa: música abaixo do SFX | 4,7 dB | 5,2 dB |
| respiro antes do 48 | 30,7 dB de queda | 33,0 dB de queda |
| quadros < 5% de luma | 0 | 0 |
| mudanças de escala na queda | 0 | 0 |

## Rodada 9b (resposta a `revisao-corte9.md`)

| item | correção | prova |
|---|---|---|
| Rei: "Murder of Crows" não aparecia | **Real** (o quadro segurado era o do "ENEMY TURN", tomada 36,45 s). A tomada do plano agora começa em 36,80 s, e o quadro segurado (a 42,15 s, por 66 quadros) é o da tomada 36,95 s, com o nome cheio, **igual ao da principal**. Nome legível de ~42,1 a 43,25 s (1,1 s); corte de 43,25 s mantido. | `corte9_provas/rei/p7_anuncio_rei_9b_42.00-43.30s.png` |
| Tirano: corte do anjo fora da batida | **Real.** Anjo em **26,552 s** (ataque de 19,7 dB): esporo 1,17 s, anjo 1,42 s, portão 27,968 s sem mudança. | `corte9_provas/tirano/p6_anjo_9b_25.30-28.10s.png` |

Medidas depois da 9b: Tirano −14,1 LUFS, LRA 8,1, margem +2,6 dB, coringa 4,7 dB; Rei −14,1 LUFS, LRA 8,5, margem +3,1 dB, coringa 5,2 dB.
