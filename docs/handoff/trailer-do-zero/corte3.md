# Corte 3 (trailer-do-zero)

_Diretora, 01/11/2026. Entra: `revisao-grimoire-corte2.md` (NÃO MEXER + 5 correções na ordem), `revisao-corte2.md` (rodada 1, itens 1 a 9, e a análise de mixagem M1 a M5). **Sem 4K, sem Steam, sem push, sem save real. Nenhuma troca de faixa, texto ou salão.**_

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| **principal (Tirano), 1080p** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte3_1080p.mp4` |
| principal, 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte3_720p.mp4` |
| **variante (Rei-Carniça), 720p** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte3_rei_720p.mp4` |

64,5 s, 60 fps. Pipeline: `corte/edl3.py` (`TDZ_MUSIC=tirano|rei`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py` e `medir2.py` (com `TDZ_EDL=edl3`), mais `onsets.py` (ataques reais do áudio). Os cortes 1 e 2 ficaram intactos.

## NÃO MEXER (mantidos)
Quadro 0/pôster (Espantalho inteiro, sem preto), gancho, textos exatos, golpe do 47 (hit-stop, flash, tremor), logo + CTA.

## As 5 correções do Grimoire, na ordem

| # | correção | o que foi feito |
|---|---|---|
| 1 | virada da luta do Rei legível | **Tomada regravada** (headless, 1 `lovec`, `card-game-trailer-v9`): quando o Rei anuncia a Revoada, o modo deus desliga e a vida do herói é encenada para que os golpes de corvo a levem a **9**. Na tela: "Murder of Crows" (×2, Rei) → **HERO 25 → 21 → 17 → 13 → 9** a cada corvo que mergulha, num plano **×3** do painel de vida (45,48–48,27 s) → plano geral com o Rei, os corvos e o 9/70 (1,06 s) → mão ×3 com as cartas grandes (49,33–50,54 s) → **painel "LETHAL" ×3** com o Play Cards sendo apertado (50,54–52,83 s) → golpe do 47. O LETHAL aparece antes do 47. |
| 2 | caminhada ≤ 1,5–2 s ou a porta abrindo | A estrada saiu: resta **um plano ×2 do portão do castelo abrindo, 1,48 s** (Tirano) / 2,14 s (Rei; é o próprio plano da porta abrindo, a alternativa aceita). |
| 3 | salões do Higgsfield com cara de outro jogo | Pixelizados **antes do CRT**: reduzidos a **480×270** (a grade do jogo a 1080p, pixel de 4 px na tela, igual à densidade do salão real), **paleta de 48 cores** tirada do salão real + a chama, ampliados **4× por vizinho mais próximo**. A luminância por percentis e o croma por matiz (§5.10 das ferramentas) continuam. |
| 4 | UI pequena dentro da moldura (145 LIVING CARDS e luta do Rei) | Em vez de zoom digital suave (escala não inteira, "cara de IA", que a revisora proíbe pela regra de câmera do §5.3), **degrau inteiro ×3** nesses planos: com a carta desenhada a 2 px por pixel lógico, o ×3 dá **6 px por pixel**, uniforme. Espólio "145 LIVING CARDS." a ×3 (Poison Dart e a rara Rain of Blades enchendo o quadro); na luta: vida do herói, mão e painel LETHAL a ×3. **PERGUNTA ao Grimoire:** isso atende ao "zoom suave no miolo"? Se ele quiser o movimento de zoom de fato, é preciso aceitar escala não inteira nesses segundos. |
| 5 | mixagem avaliada de verdade | `medir2.py` agora mede, para **cada corte**, a força do ataque da música no stem de música (fluxo espectral, ±30 ms, em múltiplos da mediana), além do curto prazo por segundo do silêncio, do pico e dos eventos únicos. Resultados abaixo, para a revisora conferir de forma independente. |

## Itens da revisora (corte 2, rodada 1) e mixagem M1 a M5

| item | o que foi feito |
|---|---|
| 1 quadros pretos 34,72–35,08 s | **Lift** de +16 (decaindo em 40 quadros) no início do salão escuro: o pior quadro sobe acima de 5% de luma; os olhos continuam no escuro. |
| 2 caminhada | correção 2 do Grimoire. |
| 3 "47" encavalado no banner | "47" desce para y = 208 px: entre o banner do COMBO e a coroa. |
| 4 "FROST." no rosto do Monarca | "FROST." centrado em x = 1500 (terço superior direito, livre). |
| 5 LETHAL e 9/70 no plano do LETAL | correção 1 do Grimoire. |
| 6 espólio fora do grave | O corte do espólio cai no **evento do jogo**: o lacre do pacote rompendo (`packSealBreak`, quadro 29,23 s da tomada), que fica exatamente no corte. Escrito aqui como evento; a faixa do Tirano não tem grave entre 7,48 e 11,69 s. |
| 8 variante: cortes fora do grave | os cortes são encaixados nos **ataques reais da faixa do Rei** (o `_beats.json` erra ataques, como a revisora mostrou): deslizamento até 0,8 s, nunca deixando plano < 1 s ou texto abaixo do tempo de leitura; `e2_gargula`, `ia_hall3` e `ia_hall4` vão ao ataque mais forte em ±0,45 s, medido no áudio (`onsets.py`). |
| M1 salões | os cortes dos salões no ataque mais forte medido; "parede de fogo" e "tempestade de gelo" **9 dB abaixo** e entrando **70 ms depois** do ataque. Na principal, `ia_hall4` e `k_porta` foram ao ataque real. |
| M2 variante, volta do drop | música da variante **+6 dB** a partir da volta (39,44 s). |
| M3 sincronia | M1 + item 8. |
| M4 coringa | a revelação do coringa 6 dB abaixo; a música fica no nível da ponte para o logo. |
| M5 leito do salão IA do Rei | **Decisão: silêncio intencional.** O plano do trono vazio (IA) é o primeiro segundo da entrada do chefe e fica em quase silêncio digital: é o maior contraste do filme, e o leito do salão real entra no corte para o escuro. O leito que estava declarado e não soava foi removido do plano de som. |

## Medidas (`corte/medir2.py`)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA | −14,2 LUFS / −1,1 dBFS / 9,3 LU | −14,1 LUFS / −1,2 dBFS / 7,4 LU |
| silêncio, curto prazo por segundo | −13,5 / −18,0 / −27,7 / **−31,3** / −27,1 / −24,6 | −14,6 / −16,5 / −20,3 / **−32,2** / −28,4 / −25,9 |
| pico (golpe → morte), margem | −8,8, **+3,0 dB** | −9,1, **+3,8 dB** |
| portão do castelo | **mudo** (o plano começa depois do início do som e a regra de não herdar som o cortou; corrigido para o corte 4) | 30,93 s (a variante já saiu com a correção) |
| quadros < 5% de luma | 2 (35,13 e 35,17 s; lift reforçado para o corte 4) | — |
| cortes com subida da música < 10 dB no stem | — | gárgula 4,5, salão do Tirano 7,4, Revoada 8,9, gancho 9,8, logo 5,5 dB |

A principal foi revisada (`revisao-corte3.md`, reprovada); as correções vão para o corte 4 (`instrucao-grimoire-corte4.md`).
