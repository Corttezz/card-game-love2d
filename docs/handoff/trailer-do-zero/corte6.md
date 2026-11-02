# Corte 6 (trailer-do-zero)

_Diretora, 01/11/2026. Base: `revisao-grimoire-corte5.md` (commit 09ac75f6, 10 pontos). **Sem 4K, push, Steam ou save real. Um `lovec` por vez, headless. Nenhuma troca de faixa, texto ou salão.** Masters antigos intactos._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| principal (Tirano) 1080p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte6_1080p.mp4` |
| principal 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte6_720p.mp4` |
| variante (Rei-Carniça) 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte6_rei_720p.mp4` |

Pipeline: `corte/edl6.py` (`TDZ_MUSIC=tirano|rei`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py`, `med6.py`, `verificar.py`, `onsets_librosa.py` (com `TDZ_EDL=edl6`). Provas em `docs/handoff/trailer-do-zero/corte6_provas/`.

## Conferência quadro a quadro, antes de mexer (corte 5)

| # | ponto | procede? | prova (PNG, timestamp do corte 5) |
|---|---|---|---|
| 1 | zoom que recua logo após o golpe | **Sim.** Não é o nosso recorte: é o **soco de câmera da cinemática de morte do jogo**, gravado na tomada (de 52,90 a 53,45 s da tomada), dentro do nosso plano ×2. As velas do fundo se aproximam do centro e voltam. | `tirano/p1_golpe_zoom_52.70-54.30s.png`, `tirano/p1_zoom_52.86-53.90s_6q.png` |
| 2 | 6 s antes do castelo, máximo 2 s | **Sim**, nas duas, com valores diferentes: Tirano 4,57 s (esporo 1,33 + anjo 1,53 + pouso 1,71), Rei 5,03 s. | `tirano/p2_antes_castelo_22.00-30.40s.png`, `rei/p2_antes_castelo_22.00-30.40s.png` |
| 3 | portão do Rei parece imagem parada | **Não.** As folhas abrem dentro do plano (fechadas → meio → abertas) e o `castleGateOpen` toca no plano. **Não mexido**; o plano só mudou de posição pelo ponto 2. | `rei/p3_portao_abrindo_30.0_31.4_32.4s.png`, `rei/p3_portao_29.90-32.60s.png` |
| 4 | o 48 só aparece na UI pequena | **Não.** No hit-stop há um "48" grande (fonte do jogo, 192 px) sobre o Rei. **Não mexido.** | `tirano/p4_hitstop_52.86s.png`, `rei/p4_hitstop_52.86s.png` |
| 5 | BREAK THEM BACK. entra durante a queda | **Sim.** Entrava 0,04 s depois do impacto, com a poeira subindo. | `tirano/p5_texto_55.40s.png` |
| 6 | a Carrion Crown fica parada só ~1–1,5 s | **Sim.** O plano do coringa tinha 1,22 s (o 3,09 s medido antes era o espólio). Na tomada, a carta fica parada de ~57,5 a ~59,9 s. | `tirano/p7_coringa_56.90-58.30s.png`, `p6_carta_tomada_57.0-61.0s.png` |
| 7 | só o verso aparece, sem a face | **Não, na letra:** a face aparecia por 1,22 s antes do logo (o verso que os revisores viram é o giro do logo). Ficou resolvido junto com o ponto 6. | `tirano/p7_coringa_56.90-58.30s.png` |
| 8 | "145 LIVING CARDS." sem ponto final | **Não.** O ponto está no quadro. **Não mexido.** | `tirano/p8_texto_10.50s.png` |
| 9 | salões com ruído/paleta fora | **Em parte.** A grade já era a do fundo real (5 px; medido no corte 5). Ruído e pixels soltos procediam. | `tirano/p9_trono_33.60s.png`, `tirano/p9_gelo_21.30s.png` |
| 10 | batidas do Rei nos 5 cortes | Medido com librosa (tabela abaixo). | `onsets_rei_corte6.md` |

## O que mudou

| # | mudança |
|---|---|
| 1 | O hit-stop congela o quadro de antes do soco de câmera (tomada 52,95 s) por todo o plano do golpe: flash, tremor, "48" grande (0,6 s na principal, 0,42 s no Rei). Depois vem o **degrau ×3 no mesmo centro**, a partir de um trecho da tomada em que a câmera do jogo já parou (53,45 s). Os quadros do soco não entram. Só degraus para dentro: ×2 → ×3. |
| 2 | **Antes do castelo: 2,0 s nas duas** (esporo 1,0 s + pouso do anjo a ×2 1,0 s, em ação). A descida parada do anjo saiu. Para isso, o filme depois do castelo andou 2,47 s para trás e **a faixa passa a usar dois trechos dela mesma, com a passagem dentro do silêncio da entrada do Rei** (antes do silêncio, o groove com o deslocamento de antes; o drop volta exatamente no mesmo ponto da faixa, no cartão do nome). É a mesma peça, sem outra faixa, e é a solução que a variante do Rei já usava e o Grimoire aceitou. Registro para o Daniel ouvir. |
| 5 | Impacto → poeira → **corpo caído segurado 0,6 s (quadros repetidos)** → "BREAK THEM BACK." 0,65 s depois do impacto (0,6 s no Rei), com a poeira já baixa, por 1,37 s (1,27 s no Rei), sobre o corpo e sem a carta no quadro. Da cedida ao impacto continua 1,55 s. |
| 6 / 7 | Plano do coringa de **3,42 s** (principal) e **3,75 s** (Rei): a carta termina de subir e **fica parada com a face legível ~2,9 s** (o fim segura quadros), depois o giro para o selo. Revelação e assinatura no quadro em que a face aparece. |
| 9 | Salões IA com limpeza: filtro bilateral antes de quantizar e mediana 3×3 depois, requantizando na mesma paleta de 32 cores do salão real. A grade de 5 px é a mesma. Prova 1:1: `p9_trono_antes_c5_33.6s_depois_c6_31.1s_1para1.png`. |
| 10 | Na variante do Rei, a **queda** foi para 50,78 s e o **coringa** para 54,555 s (os dois sobre ataques fortes). Tabela final abaixo. |
| extra | Na principal, a carta do coringa subia dentro do ×3 da queda e o texto ficava em cima dela: o plano da queda agora acaba antes de a carta entrar no quadro (54,88 s na principal, 54,555 s no Rei, mais o corpo segurado). |

## Ponto 10: tabela de onsets (librosa, variante do Rei)

`onset_strength` + `onset_detect` (hop 256, sr 22,05 kHz) sobre a faixa do Rei já montada (`zero6_rei/music_rei.wav`). "Forte" = acima do percentil 75 dos onsets (3,92). Regra: mover se o corte está a mais de 2 quadros de um ataque forte a até ±0,6 s. Nenhum dos 5 cortes está num silêncio intencional.

**Antes da correção** (cortes do corte 6 inicial):

| corte | t do corte (s) | onset mais próximo (s) | distância (quadros) | força | ação |
|---|---|---|---|---|---|
| LETHAL do gancho | 2,480 | 2,159 | −19,2 | 3,37 | manter (nenhum ataque forte em ±0,6 s) |
| Revoada | 42,000 | 41,993 | −0,4 | 3,92 (forte) | manter |
| queda | 50,960 | 50,782 | −10,7 | 7,32 (forte) | **mover para 50,782** |
| coringa | 54,880 | 54,555 | −19,5 | 5,43 (forte) | **mover para 54,555** |
| logo | 58,300 | 58,317 | +1,0 | 6,60 (forte) | manter |

**Depois** (`corte6_provas/onsets_rei_corte6.md`):

| corte | t do corte (s) | onset mais próximo (s) | distância (quadros) | força | ação |
|---|---|---|---|---|---|
| LETHAL do gancho | 2,480 | 2,159 | −19,2 | 3,37 | manter (nenhum ataque forte em ±0,6 s; o mais forte tem 3,37) |
| Revoada | 42,000 | 41,993 | −0,4 | 3,92 | manter (no ataque forte) |
| queda | 50,780 | 50,782 | +0,1 | 7,32 (forte) | manter (no ataque forte) |
| coringa | 54,555 | 54,555 | +0,0 | 5,43 (forte) | manter (no ataque forte) |
| logo | 58,300 | 58,317 | +1,0 | 6,60 (forte) | manter (no ataque forte) |

## Medidas finais

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA (mp4) | −14,1 LUFS / −1,0 dBFS / 9,2 LU | −14,1 LUFS / −1,2 dBFS / 8,4 LU |
| pico (golpe → queda) e margem | −9,6, +2,5 dB | −9,0, +3,1 dB |
| coringa: música abaixo do SFX | **4,5 dB** | **4,8 dB** |
| revelação do coringa | no quadro da face (54,90 s; plano 54,88 s) | no quadro da face (54,575 s; plano 54,555 s) |
| quadros < 5% de luma | 0 | 0 |
| portão / pouso do anjo / baque no chão | 28,08 / 26,93 / 52,86 s | 28,08 / 26,93 / 52,68 s |

## Para o Daniel ouvir
- Principal (Tirano): a faixa agora tem a mesma passagem escondida no silêncio da entrada do Rei que a variante já tinha (foi o que permitiu tirar 2,5 s antes do castelo sem perder a sincronia do resto). O fim da peça do Tirano chega por volta de 60,6 s, durante o logo, e o filme segue até 64,5 s com o salão, o corvo e a carta.
- Ninguém ouviu as mixagens; tudo foi conferido por medida.
