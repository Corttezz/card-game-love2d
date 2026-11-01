# Corte 5 (trailer-do-zero)

_Diretora, 01/11/2026. Base: `revisao-grimoire-corte4.md` (6 pontos), `revisao-corte4.md` (quadro preto a 32,3 s) e a revisão da variante do Rei do corte 3 (fecho, coringa, ataques, LRA). **Sem 4K, sem Steam, sem push, sem save real. Nenhuma troca de faixa, texto ou salão.** NÃO MEXER mantido._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

Pipeline: `corte/edl5.py` (`TDZ_MUSIC=tirano|rei`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py`, `medir2.py` e o novo `corte/verificar.py` (quadros pretos, folhas e quadros por timestamp), com `TDZ_EDL=edl5`. Cortes 1 a 4 intactos.

## Conferência quadro a quadro dos 6 pontos, antes de mexer (no corte 4 Tirano)

Provas em `docs/handoff/trailer-do-zero/corte5_provas/` (nome = o que mostra + timestamp do corte 4).

| # | ponto do Grimoire | procede? | prova |
|---|---|---|---|
| 1 | quadro preto em ~0:32 | **Sim.** 16 quadros abaixo de 5% de luma, de 32,28 a 32,53 s: o plano ×2 do portão ia até o escurecimento do próprio jogo ao atravessar a porta (o escurecimento começa em ~11,4 s da tomada). | `verificar.py` (lista dos quadros); `portao_29.95-32.55s.png` (o último quadro é preto) |
| 2 | o portão não abre | **Sim.** No corte 4 o ×1 mostrava a porta ainda fechada e o ×2 já começava com ela aberta: a abertura caía no corte. Na tomada a porta abre de verdade entre 9,6 e 10,6 s. | `portao_29.95-32.55s.png`; `portao_tomada_9.20-11.80s.png` (as folhas da porta girando na tomada) |
| 3 | pixel dos salões mais fino que os sprites | **Não, pela medida.** Mediana das corridas de cor (pixel lógico na tela): salão IA **4 px**; fundo do salão real do Rei **5 px** (corridas de 4 e 5); sprite do Rei **2 a 3 px**. O salão de IA já tinha pixel **mais grosso** que o sprite e quase igual ao fundo real. Mesmo assim, ajustei para igualar ao **fundo** real: grade 384×216 (pixel de 5 px inteiro) e paleta de 32 cores. | medida no `corte5.md` (script na sessão); `salao_tirano_14.50s.png`, `sprite_rei_40.50s.png` |
| 4 | vida lida como 25, 18, 10 | **Em parte.** A folha a 5 quadros/s mostra **25, 25, 25, 21, 21, 18, 17, 17, 13, 13, 10, 9, 9, 9**: os valores estáveis são 25 → 21 → 17 → 13 → 9; o 18 e o 10 são quadros da **contagem animada do próprio jogo** entre um valor e outro. O olho pular entre ×2/×3 e cantos diferentes **procede**. | `vida_45.40-48.40s.png` |
| 5 | espólio < 2 s | **Procede** (2,09 s; o pedido é +1 s). | EDL do corte 4 |
| 6 | do 48 direto aos ossos | **Não procede.** Entre o "48" (53,6 s) e o corpo no chão (55,4 s) o Rei aparece de pé, ajoelhando e caindo, por ~1,8 s, a ×2 com a câmera acompanhando. As costelas fazem parte do sprite do Rei-Carniça; não são "ossos" do pós-morte. | `queda_53.60s.png`, `queda_54.20s.png`, `queda_54.80s.png`, `queda_55.40s.png`, `queda_53.60-55.40s_folha.png` |

## O que mudou no corte 5

| # | mudança |
|---|---|
| 1 | O plano do portão termina **antes** do escurecimento do jogo (tomada 8,70–11,30 s); corte seco para o salão IA. Zero quadros pretos (conferir em `verificar.py`). |
| 2 | **Um plano ×2 do portão (2,6 s)**: a porta fechada, as folhas abrindo de verdade e a entrada escura, com o `castleGateOpen` do próprio jogo no quadro em que ele toca na tomada, **+6 dB** de propósito. O ×1 parado saiu. |
| 3 | Salões IA na grade de **5 px** (384×216 → ×5) com **32 cores**, igual ao fundo dos salões reais (prova da medida acima). |
| 4 | **Virada num enquadramento só (×1), sem degrau:** "Murder of Crows" → os corvos mergulhando → a vida 25 → 21 → 17 → 13 → 9 com o "Weak" → a mão dada → o painel subindo até **48 LETHAL** → Play Cards, tudo no mesmo quadro (mão embaixo, vida embaixo à esquerda, LETHAL à direita, o Rei no centro). O olho não atravessa a tela por corte. O único degrau é **×1 → ×2 no Rei** no golpe, no mesmo centro. A luta toda antes da virada também fica a ×1 (nome do Rei, mão), para não haver recuo. Os quadros de contagem (18, 10) são do jogo e passam em ~0,1 s. |
| 5 | Espólio **3,09 s** (+1 s); o Espantalho morre no plano anterior (o grito de morte cai dentro dele). "145 LIVING CARDS." numa linha livre. |
| 6 | Mantido (a queda existe, prova acima). |
| variante Rei | o encaixe dos cortes nos ataques passou a usar **a mesma métrica da medição** (subida de RMS da música em ±30 ms, procurando em ±0,45 a ±0,8 s); gárgula, salão do Tirano, salão de gelo e Revoada vão ao maior ataque. Coringa: música 4 a 6 dB abaixo do SFX (ajustado por medida). Fecho ≥ 2 dB abaixo do pico; volta do drop +3 dB (LRA). |

## Rodadas 5b, 5c e 5d (achados da revisora e ajuste do Grimoire ao ponto 6)

| item | o que foi feito |
|---|---|
| virada (5b) | Degraus inteiros no mesmo lugar: ×1 com o Rei ("Murder of Crows") → **×2 no painel de vida** (25 → 21 → 17 → 13 → 9, "Weak") → ×1 com a mão e o painel (o painel sobe de 0 para 48) → **×2 no painel "48 LETHAL"** com a mão e o Play Cards → golpe. |
| portão (5b) | `castleGateOpen` **+3 dB** a mais (agora +9 dB sobre o nível do jogo). |
| pouso do anjo (5b) | sons de entrada do anjo do próprio jogo: a descida (`fallen_angel_start`, com a cabeça aparada) e o pouso (`fallen_angel_stop`) no quadro do pouso. |
| queda do Rei (5c) | (1) golpe ×2 (1,02 s, número **48** e hit-stop) → **degrau ×3 no mesmo centro** (recorte ×2 (480,370) → ×3 (640,460), centro 960×640 da captura nos dois) no quadro em que o Rei começa a ceder; (2) a **ajoelhada segurada 0,5 s** repetindo o mesmo quadro (30 quadros, sem interpolar); (3) no impacto (55,28 s): **tremor vertical** de 9 quadros, **poeira** em pixel de 6 px subindo do chão e o **baque** (`boss_land_impact`) no mesmo quadro; (4) **"BREAK THEM BACK."** de 55,32 a 56,98 s, depois do impacto, sem mudar o texto. Da cedida ao impacto: 1,55 s; a carta do coringa começa a nascer do corpo ainda nesse plano. |
| golpe no quadro (variante Rei) | O início do golpe ficou fixo em 52,83 s nas duas versões (não desliza mais para o ataque da faixa): flash, 48, volta da música, voz do Rei, penas e baque no mesmo quadro. O mix sobe de −25 para −4 dBFS (janela de 20 ms) exatamente em 52,83 s nas duas. |
| coringa (5d) | O som de revelação (`boss_reveal_sting`) e a assinatura do coringa tocam no **quadro da face da carta** (57,00 s, início do plano), não 0,6 s depois. A automação da música no coringa era sobrescrita por um ponto antigo do envelope (volta a 0 dB 4,6 s depois do golpe), por isso a medida não mudava; o ponto foi retirado. |
| dinâmica (5d) | Golpe e queda +2 dB na música e no SFX; LRA de volta a 8,9 (principal) e 8,8 (variante). |
| variante Rei | gárgula/salões e Revoada encaixados pela mesma métrica da medição, com plano mínimo de 1,25 s. |

## Medidas finais (mp4 e stems)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA | −14,2 LUFS / −1,1 dBFS / **8,9 LU** | −14,1 LUFS / −1,2 dBFS / **8,8 LU** |
| pico de curto prazo (golpe → queda) e margem | −9,2, **+2,7 dB** | −8,9, **+3,4 dB** |
| coringa: música / SFX no plano | −13,1 / −8,0 → **música 5,1 dB abaixo** | −14,2 / −8,6 → **música 5,6 dB abaixo** |
| som de revelação do coringa | **presente**, 57,00 s (face da carta, plano começa 56,98 s) | **presente**, 57,00 s |
| golpe: som no quadro do flash (52,83 s) | sim | sim |
| quadros < 5% de luma | **0** | **0** |
| tom de sala no trono vazio | −46 a −51 dBFS | −46 a −51 dBFS |

Provas: `corte5_provas/corte5b/` e `corte5_provas/corte5c/queda_corte5c_52.80-57.30s.png`.

## Rodada 5d: gárgula da variante Rei

Só a variante do Rei foi regravada (`grimoire_zero_corte5_rei_720p.mp4`); a principal não mudou. Faixa, textos e salões iguais.

- **Antes:** o corte para a gárgula estava em 11,82 s, com subida da música de **1,6 dB** no stem (±30 ms), ou seja, sem batida.
- **Busca:** maior ataque da faixa do Rei entre 10,0 e 12,6 s, pela mesma métrica do `medir2.py`: 10,00 s (18,4 dB, deixaria o espólio com 1,2 s) e **12,50 s (16,4 dB)**.
- **Escolha:** o corte foi fixado em **12,50 s** (`REI_FIX` em `corte/edl5.py`). O espólio passou a durar 3,74 s ("145 LIVING CARDS." continua de 8,76 a 11,69 s, dentro do plano). A gárgula dura 1,27 s, acima do mínimo de 1,25 s, e "6 ACTS." fica de 12,50 a 13,70 s, dentro do plano.
- **Medida depois** (`medir2.py`, stem de música): `e2_gargula` **16,4 dB ok**. Os vizinhos também ficaram ok: `espolio` 16,7 dB e `ia_hall3` 25,9 dB. Prova da imagem: `corte5_provas/corte5d/gargula_corte_rei_12.50s.png`.
- **Resto da variante** (conferido de novo): −14,1 LUFS, −1,2 dBFS, LRA 8,8; pico +3,4 dB; coringa com a música 5,6 dB abaixo do SFX e a revelação a 57,00 s; 0 quadros < 5% de luma.
