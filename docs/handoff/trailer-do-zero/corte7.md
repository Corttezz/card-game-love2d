# Corte 7 (trailer-do-zero)

_Diretora, 01/11/2026. Base: `revisao-corte6.md` (21:30) e a atualização do Grimoire (21:36): a rodada 6b virou o corte 7. **Sem 4K, push, Steam ou save real. Um `lovec` por vez, headless. Nenhuma troca de faixa, texto ou salão.** Os arquivos do corte 6 (`grimoire_zero_corte6_*`) ficaram intactos._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| principal (Tirano) 1080p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte7_1080p.mp4` |
| principal 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte7_720p.mp4` |
| variante (Rei-Carniça) 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte7_rei_720p.mp4` |

Pipeline: `corte/edl7.py` (igual ao `edl6.py` com `CUT = 'corte7'`; as pastas de trabalho continuam `zero6` e `zero6_rei`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py`, `med7.py`, `verificar.py`, `onsets_librosa.py`. Provas em `corte7_provas/`.

## Versão principal (Tirano)

| ponto | o que foi feito | prova |
|---|---|---|
| 1. música até o fim, WISHLIST sob trilha | A faixa terminava 3,9 s antes do filme porque o trecho depois do castelo já começa no drop. Agora o **respiro de 0,6 s antes do golpe** (em que a música está a −∞) esconde uma segunda passagem **da mesma peça**: o golpe volta no grave de **65,97 s** da faixa, não mais adiante. Com isso a música segue até o fim do filme, debaixo do fade final. Stem da música de 59,5 a 64,5 s (janelas de 0,5 s): −23,0 / −17,7 / −22,7 / −24,9 / −23,1 / −22,3 / −31,0 / −31,7 / −34,9 dB. O **WISHLIST ON STEAM** entra a 62,17 s com a trilha em −22 a −31 dB e o fade termina em 64,5 s. Faixa, textos e salões iguais. | `corte7_provas/tirano/fecho_wishlist_60.00-64.40s.png` |
| 2. corpo caído sem a Carrion Crown | O corpo fica segurado (quadros repetidos) por **1,33 s** depois que a poeira baixa. A tomada para antes de a carta nascer, e o plano da queda termina sem nenhuma carta no quadro. O texto "BREAK THEM BACK." fica de 53,51 a 55,22 s, só sobre o corpo. O coringa entra a 55,22 s com **um giro só** (verso → giro → face) e a face fica parada ~2,7 s. O corte ficou a 55,22 s e não a 54,88 s porque, com a passagem nova da música, 55,22 s cai no ataque do trecho (onset a −0,9 quadro). | `corte7_provas/tirano/texto_sem_carta_53.40-55.60s.png`, `corte7_provas/tirano/coringa_giro_unico_55.20-58.60s.png` |
| margem do pico | **+2,5 dB** (−9,5 no clímax contra −12,0 fora dele). | `med7.py` |
| coringa | Música **4,7 dB abaixo** do SFX (−17,3 / −12,6); revelação no quadro da face (55,24 s, plano 55,22 s). | `med7.py` |

## Variante (Rei-Carniça)

| ponto | o que foi feito | prova |
|---|---|---|
| 1. portão no ataque forte | **Portão a 27,31 s** (número do Grimoire e ataque de grave de 20,8 dB medido pela revisora; o librosa marca um onset a −0,9 quadro). **Pouso do anjo a 26,31 s** (o librosa põe o pico em 26,355 s, +2,7 quadros, que é o deslocamento fixo de ~2 quadros entre os métodos já registrado pela revisora; mover deixaria o plano com 0,96 s). Esporo 25,07 → 26,31 s (1,24 s), pouso 1,0 s: **2,24 s antes do castelo** (pedido: ~2,3 s). Este registro substitui o "2,0 s nas duas" do `corte6.md` para a variante do Rei. | `corte7_provas/rei/antes_castelo_24.90-28.50s.png`, `corte7_provas/onsets_rei_corte7.md` |
| 2. carta sob o texto | Corpo segurado por 0,83 s depois da poeira; o plano da queda termina sem a carta. O texto fica de 53,28 a 54,555 s, só sobre o corpo. | `corte7_provas/rei/texto_sem_carta_53.20-54.80s.png` |
| coringa | Música **4,8 dB abaixo** do SFX; revelação a 54,575 s (plano 54,555 s). Margem do pico **+3,2 dB**. | `med7.py` |

## Tabela de onsets (librosa) do corte 7

Variante do Rei (`corte7_provas/onsets_rei_corte7.md`, p75 = 3,92):

| corte | t (s) | onset mais próximo (s) | dist. (quadros) | força | decisão |
|---|---|---|---|---|---|
| LETHAL do gancho | 2,480 | 2,159 | −19,2 | 3,37 | manter (nenhum ataque forte em ±0,6 s) |
| pouso do anjo | 26,310 | 26,355 | +2,7 | 11,02 (forte) | manter: deslocamento de método (~2 quadros); 26,31 s é o ataque medido pela revisora |
| portão | 27,310 | 27,295 | −0,9 | 3,07 | manter: número do Grimoire e ataque de grave de 20,8 dB |
| Revoada | 42,000 | 41,993 | −0,4 | 3,92 | manter (no ataque) |
| golpe | 50,360 | 50,492 | +7,9 | 3,45 | manter: a música está em −∞ no respiro e volta exatamente neste quadro (o ataque audível é a volta) |
| queda | 50,780 | 50,782 | +0,1 | 7,32 (forte) | manter |
| coringa | 54,555 | 54,555 | 0,0 | 5,43 (forte) | manter |
| logo | 58,300 | 58,317 | +1,0 | 6,60 (forte) | manter |

Principal: `corte7_provas/onsets_tirano_corte7.md` (informativo; o ponto 10 era só do Rei). Queda, coringa e logo ficam a ≤ 2,3 quadros de um onset do trecho novo. O golpe é a volta da música depois do respiro.

## Medidas finais (mp4)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA | −14,1 LUFS / −1,0 dBFS / 8,4 LU | −14,2 LUFS / −1,1 dBFS / 8,5 LU |
| quadros < 5% de luma | 0 | 0 |
| música no fecho | até 64,5 s, com fade | até 64,5 s, com fade |

## O que continua igual (confirmado pela revisora no corte 6)
Zoom só para dentro, sem o soco de câmera do jogo; "48" grande no hit-stop; salões limpos na grade de 5 px; espólio com o ponto final; portão abrindo no plano; texto depois da poeira; revelação no quadro da face; silêncio da entrada do Rei com tom de sala.

## Para o Daniel ouvir
A faixa do Tirano agora tem duas passagens escondidas em silêncios: na entrada do Rei e no respiro de 0,6 s antes do golpe. A peça é a mesma, sem outra faixa. Ninguém ouviu as mixagens ainda.
