# Corte 10b (trailer-do-zero)

_Diretora, 02/11/2026. Base: `revisao-corte10.md` (aa991b4e, Tirano 8,8 e Rei 8,9, reprovado na continuidade). Só montagem, mesma tomada `zero_carrion`: nenhuma troca de faixa, texto ou salão, **sem zoom** (escala 1,00). Sem 4K, Steam, push ou save real; um `lovec` por vez, headless. Os masters antigos estão intactos (pastas novas `zero10b` e `zero10b_rei`)._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX** (ElevenLabs free). Música ACE-Step local. Salões do Higgsfield nos acentos (decisão do Daniel).

## Arquivos

| versão | caminho |
|---|---|
| principal (Tirano) 1080p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10b_1080p.mp4` |
| principal 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10b_720p.mp4` |
| variante (Rei) 720p | `E:\dev\projects\card-game-trailer\build\trailer\grimoire_zero_corte10b_rei_720p.mp4` |

Pipeline: `corte/edl10b.py` (importa `edl10.py` e troca o trecho do fim do `k_nome` até o começo do `k_vida`), `build_video.py`, `crt_pass.py`, `mix2.py`, `mux2.py`, `med10b.py`. Provas: `provas10b.py`, `tab10b.py`. A música é a mesma do corte 10 (golpe em 50,36 s).

## O que a tomada tem (lida quadro a quadro, `audio.jsonl` do último passe)

| tomada (s) | o que acontece | barra do Rei | HERO |
|---|---|---|---|
| 24,78 / 25,90 / 27,23 | guerreiro: Twin Strike −24, Iron Wave −18, **Bash −34** (cartas voando e número sobre o Rei) | 220 → 196 → 178 → **144** | 70 |
| 29,75 | **ENEMY TURN** | 144 | 70 |
| 30,4 a 31,8 | "Call of Crows", corvos em volta do Rei | 144 | 70 |
| 31,80 | **−13 no Rei** (tique de fogo, número e clarão no corpo, `impactFire`) | 144 → **131** | 70 |
| 34,4 | YOUR TURN, mão comprada | 131 | 70 |
| 35,233 | marca **`swarm_staged`**: a vida do herói é ajustada para 25 (painel vermelho) | 131 | 70 → **25** |
| 36,0 a 36,8 | ENEMY TURN; 36,9 "Murder of Crows"; 37,7 em diante os corvos batem | 131 | 25 → 21 → 17 → 13 → 9 |
| 40,17 | tique de fogo | 131 → 118 | 9 |
| 44,633 | marca **`lethal_pick`**: a vida do Rei é ajustada para 48, **sem golpe** | 118 → **48** | 9 |

A queda do herói não tem golpe em lugar nenhum da tomada (35,233 s é o turno do jogador, com a mão na tela). Por isso usei a alternativa da revisão: **o turno inimigo com os corvos entra antes da queda**.

## Correções (`revisao-corte10.md`)

| # | ponto | o que foi feito |
|---|---|---|
| 1b | Rei 201 → 131 no corte | O plano do guerreiro agora é o turno que leva o Rei a 144 (Bash −34, na batida) e o 144 → 131 aparece no tique de −13 do turno inimigo. **Tirano:** `k_nome` termina em 38,93 s (o cartão ainda inteiro; legível de ~37,4 a 38,93 s); guerreiro 38,93 a 39,789 s (tomada 26,665; Rei 178, Bash a **39,498 s**, onset de 8,9×, −0,1 quadro); ENEMY TURN 39,789 a 40,358 s; corvos e tique 40,358 a 41,495 s (−13 a **40,926 s**, onset de 11,5×, 0,0). **Rei:** `k_nome` termina em 38,895 s; guerreiro 38,895 a 40,16 s (Bash a 39,498 s, onset de 37×); ENEMY TURN 40,16 a 40,741 s; corvos e tique 40,741 a 41,879 s (−13 a 41,379 s). |
| 1a | dreno sem causa no turno do jogador | Ordem nova: **ENEMY TURN → corvos → −13 no Rei → corte → HERO 70 → 25** (painel vermelho e tremor no onset) → "Murder of Crows" → corvos batendo 25 → … → 9. **Tirano:** dreno 41,495 a 42,064 s (a vida cai a 41,503 s, onset de 6,6×, +0,2 quadro); "Murder of Crows" 42,064 a 43,212 s, na tela de 42,26 a 43,21 s (~0,95 s, 36 quadros de hit-stop no letreiro). **Rei:** dreno 41,879 a 42,42 s (cai a 41,887 s, onset de 6,1×); "Murder of Crows" 42,42 a 43,25 s e continua no `k_vida` (tomada 37,30), ~1,0 s. |
| 3 | prova | `corte10b_provas/<versão>/p1_vida_hero_39.0-50.4s_10qps.png` e `p1_barra_rei_39.0-50.4s_10qps.png` (10 quadros/s). `p3_guerreiro_turno_inimigo_dreno_*.png` (15 quadros/s do trecho novo). |

### Folhas de 39 a 50,4 s, resultado

- **HERO:** 70 do começo até a queda (Tirano 41,5 s; Rei 41,9 s), sempre depois do ENEMY TURN e dos corvos; 25 segurado; 22/21/18/17/14/13/10/9 cada um no quadro do corvo batendo (painel vermelho); 9 até o golpe. **Nenhum corte muda o número do HERO.**
- **Barra do Rei:** 178 no primeiro quadro (a barra não aparece antes: o `k_nome` é a cinemática sem HUD); 178 → 155 → 148 → 144 no Bash; 144 → 136 → 133 → 131 no −13; 131 até 45,80 s.
- **Fica um salto: 131 → 48 no corte de 45,80 s (Tirano) / 45,75 s (Rei), já presente no corte 9 e no corte 10.** Na tomada, a vida do Rei é **ajustada** para 48 pela marca `lethal_pick` (44,633 s), sem golpe nenhum, para o golpe final de 48 fechar a luta. Só montagem não resolve: mostrar a descida 118 → 48 seria outra queda sem golpe, e cortar antes dela deixa o salto no corte. A correção exige regravar a tomada com o Rei chegando a 48 por golpes reais. **Decisão do Daniel; não regravei.**

## Conferências

| item | corte 10b | prova |
|---|---|---|
| sem zoom | Mesma medida do corte 10 (SIFT + afim parcial, filme inteiro): nenhuma mudança > 3% em plano de jogo; os avisos são o escuro de 35,0 a 36,0 s (bit a bit igual ao corte 10), o próprio corte de 8,533 s e o giro do coringa no logo (58,23 a 58,27 s). | `corte10b_provas/escala_filme_inteiro.txt` |
| fecho do corte 2 | GRIMOIRE 58,850 / gênero 59,400 / WISHLIST 61,983 s nas duas, **WISHLIST 2,517 s**. Máscara dourada contra o corte 2 depois de 59 s: Tirano média 0,975 (mín. 0,944), Rei média 0,923. Os quadros de 59,00 a 59,07 s do Rei dão o **mesmo valor no corte 10** (0,077, recalculado agora): o "mínimo 0,943" que escrevi no `corte10.md` para o Rei estava errado; o bloco do logo não mudou do corte 10 para o 10b (diferença por segundo ≤ 1,2/255, só grão do CRT). | `corte10b_provas/p2_tempos_logo.json` |
| o que não mudou | Segundos 0 a 36 **idênticos ao corte 10** (diferença 0,0) nas duas; de 44 s (Tirano) / 46 s (Rei) em diante só o grão do CRT refeito (≤ 2,6/255). | `corte10b_provas/p0_diferenca_corte10_x_corte10b_por_segundo.txt` |
| textos | Os mesmos oito, exatos, nos mesmos tempos. | |
| quadro preto | 0 quadros < 5% de luma nas duas (3870 quadros). | |
| sincronia | Tirano: todos os cortes novos a ≤ 0,6 quadro de um onset; LETHAL do gancho 2,817 s (+0,3 q). Rei: cortes novos ≤ 0,6 q, exceto o "Murder of Crows" (42,42 s, −3,3 q de um onset fraco), que fica dentro do turno inimigo. | `corte10b_provas/onsets_tirano_corte10b.md`, `onsets_rei_corte10b.md` |

## Medidas (mp4)

| | Tirano | Rei |
|---|---|---|
| loudness / pico / LRA | −14,1 LUFS / −1,2 dBTP / 8,0 LU | −14,1 LUFS / −1,3 dBTP / 8,4 LU |
| margem do pico (golpe) | +2,6 dB | +3,1 dB |
| coringa: música abaixo do SFX | 5,0 dB | 5,9 dB |

`mix2.py`: os planos novos entram na lista "dentro do salão" (só o ambiente do salão), e o abaixamento da música do turno inimigo começa no ENEMY TURN (`k_inimigo`), para os corvos e o −13 serem ouvidos.

## Para o Daniel (não mexi)
- O 131 → 48 do Rei no corte de 45,80 s vem da marca `lethal_pick` da tomada (vida ajustada, sem golpe). Corrigir exige regravar `zero_carrion` com o Rei chegando a 48 por golpes reais.
- A queda 70 → 25 do herói é a marca `swarm_staged` (vida ajustada). Agora vem logo depois do turno dos corvos, mas no quadro da queda a mão do jogador está na tela e o intent mostra 4×4. Golpe visível de verdade também exige regravar.
- Ordem "CHAINS. → 42 CREATURES. → FROST." e o fundo do fecho, como antes.
