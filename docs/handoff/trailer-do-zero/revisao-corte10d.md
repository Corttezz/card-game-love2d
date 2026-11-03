# Revisão independente: corte 10d (trailer-do-zero)

_Revisora, 02/11/2026. Arquivos: `grimoire_zero_corte10d_1080p.mp4` e `_720p.mp4` (Tirano) e `grimoire_zero_corte10d_rei_720p.mp4` (Rei), os três com 64,5 s e 3870 quadros. Base: `revisao-grimoire-corte10c.md` (d857b4b0, Tirano 9,0 e Rei 8,7, reprovado na sincronia), minha `revisao-corte10c.md` (b45089c0) e `corte10d.md` (ce385019). Medi tudo de novo com scripts próprios:_

- _onsets (fluxo espectral e ataque de grave de 30 a 160 Hz) no **`stem_music.wav` de cada versão** (`zero10d/zero10d_tirano/` e `zero10d_rei/zero10d_rei_rei/`);_
- _barra do Rei e painel HERO recortados 1:1, a 10 quadros/s de 38,8 a 50,4 s;_
- _folhas da luta a 4 quadros/s e do golpe a 10 quadros/s (recorte 1:1 da 1080p);_
- _diferença quadro a quadro contra o 10c de 0 a 39 s;_
- _tempos do logo pelo brilho de cada linha, luma por quadro, `ebur128` (integrado e curto prazo por trecho) e RMS do respiro._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev10d\` (`t_barra.png`, `r_barra.png`, `t_hero.png`, `r_hero.png`, `t_luta.png`, `r_luta.png`, `t_golpe.png`). Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: APROVADO nas duas versões

| versão | nota |
|---|---|
| Tirano (1080p e 720p) | **9,3** |
| Rei (720p) | **9,3** |

O bloqueio do Grimoire, os quatro cortes do Rei no contratempo, está resolvido: os quatro caem nos tempos fortes, medidos no stem do próprio Rei. As três recomendações também estão feitas: golpe 33, "Murder of Crows" grande e faixa do combo inteira. A continuidade e o resto não perderam nada.

## 1. Sincronia do Rei: resolvida

Medido no `zero10d_rei/zero10d_rei_rei/stem_music.wav`:

| corte | t | no corte | o mais forte a ±0,6 s |
|---|---|---|---|
| `k_inimigo` | 41,993 | fluxo 4,4×, grave **+12,6 dB** | ele mesmo (41,976 s) |
| `k_vida` | 43,270 | 5,1×, grave **+20,1 dB** | ele mesmo (43,251) |
| `k_letal` | 48,274 | 4,2×, grave **+35,4 dB** | ele mesmo (48,261) |
| `k_letal_b` | 49,528 | 5,5×, grave **+45,8 dB** | ele mesmo (49,516) |
| `k_golpe` | 50,360 | 8,6×, grave +63,8 dB | ele mesmo |
| `k_queda` | 50,780 | 5,4×, grave +33,7 dB | (o golpe a 50,36) |

Os quatro cortes caem no pico mais forte da vizinhança. O desvio do meu fluxo é de −0,7 a −1,2 q, o mesmo viés da minha janela de STFT em toda a faixa, e o grave sobe no próprio corte. No 10c, os mesmos cortes davam 1,3× a 2,5× e grave ≤ +2,2 dB. Nota 9,5.

**Resta um, sem bloquear:** o `k_guerreiro` do Rei (38,895 s, saída do cartão "CARRION KING") continua num tempo fraco (2,1×, grave +0,9 dB; o forte está a 39,48 s). Ele é igual desde o 10b, e o Grimoire não o contou. O "−39" do Colossus Blow cai em 39,498 s, no tempo forte, logo depois.

**Tirano**, no `zero10d/zero10d_tirano/stem_music.wav`: o grave sobe no corte em 38,93 (+10,4 dB), 43,794 (+10,3), 47,498 (+8,6), 48,067 (+15,8) e no golpe 50,36 (+68,8). Ficam fracos 42,343 (fluxo 2,5×, +2,9 dB) e 49,216 (3,1×, +1,4 dB). Numa faixa densa como a da Tirano, o onset mais forte a ±0,6 s desses dois é só 2,6× e 4,1×, então não brigam com nenhum. Nota 9.

## 2. Recomendações do Grimoire

- **Golpe 33.** O overlay "33" fica de 50,4 a 50,9 s no mesmo quadro do "−33" do Immolate, com "×1,5" e "WEAKNESS!" do jogo (`t_golpe.png`). Os dois números agora são iguais, e a conta fecha: 21 de vida, 33 de dano.
- **"Murder of Crows" grande.** Na Tirano, de ~43,0 a 43,8 s; no Rei, de ~42,5 a 43,3 s, sobre "ENEMY TURN", antes do primeiro corvo. Fica ~0,8 s legível nas duas (folhas a 4 quadros/s).
- **"COMBO! Volley +6".** Entra, fica inteira por ~1 s e sai antes do corte nas duas. Não é mais um clarão de texto.
- **Corvos da Tirano.** `k_vida` + `k_vida_b`, com o corte a 47,498 s no patamar herói 9 / Rei 30, os dois iguais dos dois lados do corte. O tique −9 fica inteiro no `k_vida_b`. No Rei, o plano tem 5,0 s porque as duas pontas estão presas aos tempos fortes. Concordo.

## 3. Continuidade: mantida

- **HERO** (as duas): 41/70 do primeiro quadro com HUD até o primeiro corvo, depois a cada mergulho com o painel vermelho até 9 (Tirano 38 → 37 → 36 → 34 → 33 → 31 → 29 → 26 → 25 → 24 → 22 → 21 → 19 → 17 → 14 → 13 → 12 → 10 → 9; o Rei igual, em outro ritmo), e 9 até o golpe.
- **Rei** (as duas): 102 → −39 → contagem do −33 (58 → 41 → 34 → 31 → 30) → 30 nos corvos → tique (28/26 → 24/23 → 22 → 21) → 21 até o golpe.
- Nenhum número muda num corte, inclusive no `k_vida_b` e nos dois cortes do LETHAL. Sem mão durante a queda do herói, sem segundo ENEMY TURN.

## 4. Sem regressão

- **Tirano:** quadro a quadro idêntica ao 10c de 0 a 39 s.
- **Rei:** idêntico ao 10c até 38,067 s. A diferença começa em 38,083 s, porque o guerreiro agora começa mais cedo na tomada.
- **Logo:** GRIMOIRE 58,850 (Rei 58,867) / gênero 59,400 / WISHLIST 61,983 s nas três. **WISHLIST na tela: 2,517 s.**
- **0 quadros < 5% de luma** nas três.
- **Tirano:** −14,1 LUFS, LRA 6,9, pico −1,1 dBFS. **Rei:** −14,2 LUFS, LRA 7,4, pico −1,1.
- **Margem do clímax em curto prazo:** Tirano −9,5 contra −11,7 (48,1 s) = **+2,1 dB**; Rei −9,4 contra −12,0 = **+2,6 dB**.
- **Respiro:** −47 → −62 a −75 dBFS → −6 no golpe, nas duas.
- **Sem zoom:** mesma escala nos planos novos, tela inteira com HUD.
- **Queda e coringa:** iguais ao 10c.

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| fecho igual ao corte 2 (Daniel 2) | 9,5 | 9,5 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho | 9 | 9 |
| sincronia | 9 | **9,5** (era 9 na minha grade e 7,5 na do Grimoire) |
| continuidade | 9,5 | 9,5 |
| legibilidade (LETHAL, Murder of Crows 0,8 s, 33, combo, carta) | 9,5 | 9,5 |
| ritmo | 9 | 9 |
| golpe / respiro / Q (queda do Rei) | 9,5 | 9,5 |
| salões IA / contorno | 9 | 9 |
| som (−14 LUFS, respiro, margem +2,1 / +2,6) | 9 | 9 |
| prende | 9 | 9 |
| **geral** | **9,3** | **9,3** |

Todos os critérios (C1 a C14, G1 a G7, N1 a N5) e Q ficam ≥ 9 nas duas versões.

**Riscos que continuam abertos (recomendações do Grimoire, sem bloqueio):**
- o LETHAL do gancho da Tirano (2,55 s) e o trecho sem jogo de 27,97 a 34,84 s não mudaram;
- o Grimoire deu 8,5 a salões, ritmo e legibilidade no 10c; a legibilidade melhorou, os outros dois não mudaram;
- a margem da Tirano segue colada no limite, em +2,1 dB.

## Para o Daniel

- O número do golpe agora é 33, igual ao dano do jogo.
- A luta começa com o herói em 41/70 e o Rei em 102/220.
- O fundo e o som do fecho não são os do corte 2. Os tempos são.
- A ordem "CHAINS. → 42 CREATURES. → FROST." não mudou.
- **Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens.

===CORTE10_PRONTO===
