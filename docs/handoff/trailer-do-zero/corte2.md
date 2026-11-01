# Corte 2 (trailer-do-zero)

_Diretora, 01/11/2026. Entra tudo de `revisao-grimoire-corte1.md` (7 pontos), os textos aprovados pelo Daniel (01/11 16:39), as 2 sugestões de `tdz_c2.txt` e as decisões de música de `tdz_c2b.txt`. **Sem 4K, sem Steam, sem push, sem save real.**_

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (SFX do jogo gerados no ElevenLabs free). Música ACE-Step local (uso comercial). Salões do Higgsfield nos acentos (decisão do Daniel; declaração de IA na Steam pendente com ele).

## Arquivos

| versão | caminho |
|---|---|
| **principal, faixa do Tirano, 1080p** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte2_1080p.mp4` |
| principal, 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte2_720p.mp4` |
| **variante, faixa do Rei-Carniça, 720p** | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte2_rei_720p.mp4` |

64,5 s, 60 fps. Os arquivos do corte 1 (`grimoire_zero_corte1_*`) ficaram intactos. Pipeline: `corte/edl2.py` (`TDZ_MUSIC=tirano|rei`), `build_video.py`, `crt_pass.py` (`TDZ_EDL=edl2`), `mix2.py`, `mux2.py`, `medir2.py`.

## Os 7 pontos do Grimoire

| # | ponto | o que mudou |
|---|---|---|
| 1 | quadro 0 preto antes da TV | O liga-TV acontece **antes** do quadro 0 (`TV_SKIP = 240`): o quadro 0 já é o pôster, com a TV aberta e assentada, **a cabeça do Espantalho inteira** no alto e a mão do ladino embaixo (recorte ×2 (480,420)). Nenhum quadro preto. O som de ligar a TV toca sozinho até a música entrar (1,11 s). |
| 2 | 10 s de caminhada | A estrada do ato 1 e a encruzilhada saíram. A única caminhada é a chegada ao castelo do Rei: **2,0 s** de estrada + **2,6 s** de porta, com cortes nos graves. |
| 3 | salões não se leem como salões | O tratamento passou de 400×225 para **960×540** (ampliado 2× inteiro), com a mesma paleta, luminância e croma do salão real. Agora se leem o trono de lava com o crânio de chifres, o salão de gelo e o trono em chamas do Rei. Ficaram **3,2 s** (Tirano), **1,4 s** (Monarca) e **2,2 s** (Rei), cada um no acento da música e antes do chefe dele. |
| 4 | luta do Rei picada pela montagem | **Reordenado:** gancho → espólio → os outros chefes **antes** do arco (6 ACTS. → salão do Tirano + EVERY BOSS / BREAKS THE RULES. → CHAINS. → 42 CREATURES. → salão do Monarca → FROST. → atos 5 e 6) → estrada → porta → silêncio → Rei → luta **sem interrupção** do nome até a morte (39,4 a 56 s: nome, mão, Revoada, 9 de vida, LETHAL, golpe, morte, coringa). |
| 5 | golpe final fraco | Hit-stop de 3 quadros + **flash branco** (5 quadros, 75%) + **tremor** (12 quadros, 12 px, passos pares, vizinho mais próximo) + **"47" grande** (fonte do jogo, 192 px, vermelho com contorno) no quadro congelado, acima da coroa, com o Rei inteiro e sem cartas na frente; só então a queda, acompanhada pela câmera. |
| 6 | LETAL do gancho só na UI | O plano do gancho (2,5 a 4,2 s) agora é ×2 no Espantalho + barra + painel "0/40 → 40/40 LETHAL", e no JOGAR entram **flash** (6 quadros), **tremor** (8 quadros) e o peso do impacto do jogo no som; depois a cascata com o "−13" subindo e o Espantalho caindo a ×2. |
| 7 | textos exatos | Na tela, **exatamente**: "145 LIVING CARDS.", "6 ACTS.", "EVERY BOSS / BREAKS THE RULES.", "CHAINS.", "42 CREATURES.", "FROST.", "BREAK THEM BACK.", "A ROGUELIKE DECKBUILDER" (+ "WISHLIST ON STEAM" no CTA). "FROST." e "CHAINS." separados; "FROST LOCKS YOUR HAND." saiu. |

## Textos na tela (versão principal, `edl2.py`)

| texto | início | fim | plano |
|---|---|---|---|
| 145 LIVING CARDS. | 9,60 | 11,69 | espólio ×2 |
| 6 ACTS. | 11,69 | 13,03 | ato 2 (gárgula) |
| EVERY BOSS / BREAKS THE RULES. | 13,03 (2ª linha 13,65) | 16,24 | salão do Tirano (IA) |
| CHAINS. | 17,24 | 18,54 | corrente rompendo (intent 20 → 10) |
| 42 CREATURES. | 18,54 | 20,82 | serpente de gelo |
| FROST. | 22,97 | 25,20 | mão com 2 cartas congeladas |
| BREAK THEM BACK. | 53,60 | 55,90 | queda do Rei |
| A ROGUELIKE DECKBUILDER | 59,40 | 64,50 | logo |
| WISHLIST ON STEAM | 61,98 | 64,50 | logo |

## Variante do Rei-Carniça: como o buraco de grave foi corrigido

A faixa do Rei tem 20 s sem nenhum grave (35,19 a 55,26 s). Trocar só a faixa deixaria 20 s mornos no meio do filme. Na variante:
1. **Montagem:** a peça é usada em dois trechos dela mesma, e a passagem fica **escondida no silêncio** da entrada do Rei (música a −∞ de 32,55 a 39,44 s). Antes do silêncio toca o groove da faixa (2,57 a 35,1 s); no nome do Rei (39,44 s) a música volta no **drop da própria faixa** (55,54 s), o "para e volta sincronizado" do v4. O trecho sem grave nunca toca. A peça é a mesma, sem emenda de outra faixa.
2. **Cortes nos graves desta faixa:** os mesmos planos, na mesma ordem e com os mesmos textos, mas cada corte e cada entrada de texto desliza até o grave mais próximo do Rei (no máximo 0,45 s). Nenhum plano fica com menos de 1 s, nenhum texto fica abaixo do tempo de leitura, e o golpe mantém o quadro exato da morte.
3. **Sound design:** igual à principal (silêncio, respiro, pico, salões, logo), com as automações calculadas a partir dos tempos da EDL deslizada.

## Medidas (`corte/medir2.py`)

| | principal (Tirano) | variante (Rei) |
|---|---|---|
| loudness / pico / LRA (no mp4) | −14,1 LUFS / −1,1 dBFS / 9,8 LU | −14,1 LUFS / −1,1 dBFS / 9,9 LU |
| groove antes da porta (curto prazo) | −12,8 | −14,0 |
| silêncio da entrada do Rei, curto prazo por segundo | −15,5 / −19,6 / −24,0 / **−31,3** / −25,8 / −23,3 (olhos, rasantes e pouso são os picos) | −16,2 / −20,2 / −24,4 / **−31,7** / −26,2 / −23,7 |
| pico de curto prazo (golpe → morte) e margem sobre o resto | −8,9, **+2,1 dB** | −9,3, **+2,3 dB** |
| portão / pouso / revelação | uma vez cada (30,5 / 38,88 / 39,48 s) | idem |
| clima externo dentro do castelo | nenhum evento | nenhum evento |
| antes da música | só o liga-TV | só o liga-TV |
| quadro 0 | pôster: Espantalho inteiro + mão; nenhum quadro preto | idem |
| menor plano | 1,13 s (`k_volta`); sem rajadas | 1,16 s |
| microtrailer (0,33 a 0,87) | salão de gelo, castelo, trono em chamas, mão do guerreiro, Rei com 47/220, coringa | — |

Ninguém ouviu as mixagens ainda: tudo foi conferido por medida.
