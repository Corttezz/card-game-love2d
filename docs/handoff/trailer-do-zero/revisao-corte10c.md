# Revisão independente: corte 10c (trailer-do-zero)

_Revisora, 02/11/2026. Arquivos: `grimoire_zero_corte10c_1080p.mp4` e `_720p.mp4` (Tirano) e `grimoire_zero_corte10c_rei_720p.mp4` (Rei), os três com 64,5 s e 3870 quadros. Base: `revisao-corte10b.md` (a7b3d112), decisão do Lead `E:\dev\_orquestracao\tdz_c10c.txt` (opção 1, regravar a luta) e `corte10c.md` (426872c1). Medi tudo de novo, com scripts próprios:_

- _barra do Rei e painel HERO recortados 1:1 da 1080p, a 10 quadros/s de 38,8 a 50,4 s, nas duas versões;_
- _folhas a 5, 8 e 10 quadros/s da luta, do golpe e do fim;_
- _diferença quadro a quadro contra o 10b de 0 a 39 s;_
- _tempos do logo pelo brilho de cada linha, luma por quadro e `ebur128` (integrado e curto prazo por trecho);_
- _RMS do respiro;_
- _ataque de grave (30 a 160 Hz) e fluxo espectral nas faixas `zero9/music_tirano.wav` e `zero9_rei/music_rei.wav`;_
- _movimento da carta do coringa._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev10c\` (`t_barra.png`, `r_barra.png`, `t_hero.png`, `r_hero.png`, `t_a.png`, `t_b.png`, `t_corvos.png`, `t_golpe.png`). Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: APROVADO nas duas versões

| versão | nota |
|---|---|
| Tirano (1080p e 720p) | **9,3** |
| Rei (720p) | **9,2** |

A regravação fecha a continuidade. Depois do primeiro número na tela, nenhum número do herói ou do Rei muda sem um golpe que se vê. O resto do filme não perdeu nada.

## 1. Continuidade da luta: resolvida

**Barra do Rei** (Tirano e Rei iguais):
- 102/220 no primeiro quadro com HUD;
- Colossus Blow com o "−39" sobre o Rei a 39,5 s;
- Twin Strike "−33" até 30, com "COMBO! Volley +6";
- 30 durante todo o turno inimigo;
- 25 → 23 → 21 com o tique de fogo no corpo (Tirano ~46,9 s, Rei ~47,3 s);
- 21 com a prévia "−21" até o Play;
- no golpe, o "21" grande, que é a vida que o Immolate tira.

**Painel HERO:**
- 41/70 até o primeiro corvo (Tirano ~42,9 s, Rei ~43,2 s);
- depois cai de 4 em 4 até 9 (39/38/37 → 33 → 29 → 25 → 21 → 17 → 13 → 9), cada passo com o painel vermelho e um corvo mergulhando com o risco de corte na tela (`t_corvos.png`);
- 9 até o golpe.

Nenhum dos dois números muda em corte. As duas ressalvas do 10b também saíram: **não há mão na tela** durante a queda do herói, que acontece toda no turno inimigo, e **não há segundo "ENEMY TURN"**. A ordem é a de uma luta real: guerreiro ataca → ENEMY TURN → "Murder of Crows" (~0,9 s legível) → oito corvos → tique no Rei → YOUR TURN, mão nova, "21/21 LETHAL" → golpe.

**Preparo declarado (não reprova):** o primeiro número da luta já é 102/220 para o Rei e 41/70 para o herói. Os dois foram ajustados em quadros que não entram no filme, e o `k_nome` (cartão "CARRION KING") não tem HUD. O espectador vê uma luta em andamento, sem nenhum salto na tela. É o mesmo caso do 178/220 do 10b.

## 2. Golpe, respiro e Q (queda do Rei)

- **Respiro:** imagem parada nas cartas de 49,9 a 50,3 s. RMS do mix −27/−28 → −47 → **−62 a −74 dBFS** (50,0 a 50,3 s) → −11,5 / −6,1 no golpe. Valores iguais nas duas versões.
- **Golpe:** clarão e o **"21"** grande a 50,4 s, segurado com tremor; depois a dessaturação.
- **Queda:** mesma escala dos planos de jogo, sem recuo nem zoom, até "BREAK THEM BACK." nos mesmos tempos do 10b. Q = 9,5.
- **O número do golpe passou de 48 para 21.** É o número verdadeiro do jogo, porque o golpe tira a vida que resta. Fica menos imponente que o 48 que o Grimoire elogiou, mas um 48 sobre um Rei com 21 seria mentira. Registro para o Daniel e não desconto.

## 3. Coringa e fecho

- **Face do coringa legível** de 55,2 a 57,77 s (Tirano) e de 54,6 a 57,77 s (Rei), com "Carrion Crown".
- **Último quadro segurado:** a carta continua se mexendo (diferença média de 0,4 a 2,4 por quadro, parecida com a do 10b), então não lê como imagem congelada. A faixa "COMBO! Volley +6" da tomada nova não aparece.
- **Logo:** GRIMOIRE 58,850 (Rei 58,867, meio quadro) / gênero 59,400 / WISHLIST 61,983 s nas três. **WISHLIST na tela: 2,517 s.** Idêntico ao corte 2.

## 4. Sincronia

| | cortes novos | medida |
|---|---|---|
| Tirano | 38,93 / 41,495 / 42,343 / 47,207 / 48,647 | todos a ≤ 1,6 q de um ataque de grave (+10,3 / +9,6 / +3,0 / +9,0 / +3,7 dB). Colossus −39 a 39,498 (+10 dB, +0,1 q); 1º corvo 42,843 (+5,8 dB, −1,4 q); tique −9 46,873 (+8 dB, −1,4 q) |
| Rei | 38,895 / 41,379 / 42,656 / 47,672 / 48,926 | caem nos tempos fracos da batida, a ~0,6 s antes dos ataques fortes (39,48 / 41,98 / 43,25 / 48,26 / 49,52 s; 4× a 5,4× a mediana). No corte, o fluxo dá 1,3× a 4,2× e o grave não sobe. Os acontecimentos caem nos tempos fortes: Colossus −39 a 39,498 (+40,8 dB) e 1º corvo a 43,23 s (no ataque de 43,25) |

Na Tirano a sincronia fica como no 10b: nota 9. No Rei, os cortes ficam na grade da batida, mas em tempos fracos, enquanto os golpes caem nos fortes. Leio como corte antes da batida, que entrega o golpe no tempo forte, e não como corte fora do tempo: nota 9. **Risco:** o Grimoire, que deu 9,5 ao Rei no corte 9 por cortar em onsets de 6× a 12×, pode ver isso como queda. Se quiser subir, adiantar os cortes do Rei de 41,379 e 42,656 s para 41,98 e 43,25 s não tira nenhum golpe da tela.

## 5. Sem regressão

- **0 a 37,88 s idêntico ao 10b**, quadro a quadro, nas duas versões. O primeiro quadro diferente é o 37,883 s na Tirano, só grão (0,12/255), e o 38,017 s no Rei.
- **0 quadros < 5% de luma** nas três (mínimo de 15,5 no escuro de 34,3 s).
- **Tirano:** −14,2 LUFS, LRA 7,1, pico −1,1 dBFS (a 1080p e a 720p dão o mesmo).
- **Rei:** −14,1 LUFS, LRA 7,3, pico −1,1 dBFS.
- **Margem do clímax em curto prazo:** Tirano −9,5 contra −11,6 (o maior trecho fora, a 47,0 s, os corvos) = **+2,1 dB**; Rei −9,3 contra −11,9 = **+2,6 dB**. Passa no limite de 2 dB. A Tirano caiu de +2,5 para +2,1 porque os corvos subiram o trecho anterior.
- **Sem zoom:** mesma escala em todos os planos novos, tela inteira com o HUD.
- **Textos:** os mesmos oito, exatos.

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| fecho igual ao corte 2 (Daniel 2) | 9,5 | 9,5 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho | 9,5 | 9 |
| sincronia | 9 | 9 |
| continuidade | 9,5 | 9,5 |
| legibilidade (LETHAL, Murder of Crows, 21, carta) | 9 | 9 |
| ritmo (corvos ~4,9 s com o número caindo; silêncio de 30,08 a 36,97 s aceito) | 9 | 9 |
| golpe final / respiro / Q (queda do Rei) | 9,5 | 9,5 |
| salões IA / contorno | 9 | 9 |
| som (−14 LUFS, respiro, margem +2,1 / +2,6, coringa 5,0 / 5,7 dB) | 9 | 9 |
| prende | 9 | 9 |
| **geral** | **9,3** | **9,2** |

Todos os critérios de sempre (C1 a C14, G1 a G7, N1 a N5) e Q ficam ≥ 9 nas duas versões.

## Para o Daniel

- O número do golpe agora é 21, não 48, porque é o dano verdadeiro do Immolate.
- A luta começa com o Rei em 102/220 e o herói em 41/70, ajustados fora dos quadros usados.
- O fundo e o áudio do fecho não são os do corte 2. Os tempos são.
- A ordem "CHAINS. → 42 CREATURES. → FROST." não mudou.
- **Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens.

===CORTE10_PRONTO===
