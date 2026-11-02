# Revisão independente: corte 10b (trailer-do-zero)

_Revisora, 02/11/2026. Arquivos: `grimoire_zero_corte10b_1080p.mp4` e `_720p.mp4` (Tirano) e `grimoire_zero_corte10b_rei_720p.mp4` (Rei), os três com 64,5 s e 3870 quadros. Base: `revisao-corte10.md` (aa991b4e) e `corte10b.md` (6afd08c5). Medi tudo de novo, com scripts próprios: folhas a 6, 10 e 12 quadros/s de 38,8 a 46,2 s, recortes 1:1 da barra do Rei e do painel HERO na 1080p, tempos do logo pelo brilho de cada linha, luma por quadro, `ebur128`, ataque de grave (30 a 160 Hz, subida em 30 ms) e fluxo espectral nas faixas `zero9/music_tirano.wav` e `zero9_rei/music_rei.wav`, e md5 dos quadros de 0 a 36 s contra o corte 10. Evidências em `C:\Users\corte\AppData\Local\Temp\rev10b\` (`t_barra.png`, `t_seq.png`, `r_seq.png`, `t_dreno.png`, `t_48.png`). Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: REPROVADO nas duas versões

| versão | nota | bloqueia |
|---|---|---|
| Tirano (1080p e 720p) | **8,9** | continuidade 8 (131 → 48 no corte de 45,80 s) |
| Rei (720p) | **8,9** | continuidade 8 (131 → 48 no corte de 45,75 s) |

As duas correções pedidas no corte 10 estão feitas e conferem. O que segura é o salto da barra do Rei de **131 para 48** no corte para o LETHAL, o ponto que a diretora declarou em aberto. Ele **bloqueia**. Pela regra que já reprovou o HERO 70 → 25 no corte 9 e o Rei 201 → 131 no corte 10 ("nenhum corte muda o número sem golpe visível"), este caso pesa mais que os dois: são **83 pontos**, na barra maior da tela, logo acima do Rei no centro, no plano que pede ao espectador para ler "48 LETHAL". Ele não se resolve na montagem, então a decisão é do Daniel (ver o fim).

**Erro meu:** esse salto já estava no corte 9, que aprovei, e no corte 10, onde só registrei o 201 → 131. Eu devia ter registrado os dois.

## 1. Rei 201 → 131 (correção 1b): resolvido

Barra do Rei a 10 quadros/s e a 6 quadros/s (`t_barra.png`, `t_seq.png`): 178 → 165 → 152 → 147 → **144** no turno do guerreiro, com Twin Strike, Iron Wave e Bash na tela (o "−34" sobre o Rei a 39,5 s). Depois ENEMY TURN em 144 e corvos, então **"WEAKNESS! −13"** no corpo do Rei (Tirano 40,85 a 40,93 s): 144 → 140 → 134 → 132 → **131**. A barra do Rei não muda em nenhum corte de 38,93 a 45,8 s. Na tomada, a barra só aparece com o HUD depois do cartão "CARRION KING", então 178 é o primeiro número na tela.

## 2. Dreno do HERO 70 → 25 (correção 1a): resolvido o bastante

A ordem agora é ENEMY TURN (39,79 s) → corvos (40,36 s) → −13 no Rei (40,93 s) → corte → HERO 58 → 40 → 32 → 28 → 26 → **25** com o painel vermelho e tremor (Tirano 41,50 a 41,9 s; Rei 41,89 s) → ENEMY TURN → "Murder of Crows" → corvos batendo 25 → … → 9. A queda vem logo depois dos corvos, sem nada entre eles, e lê como o golpe da revoada. Nenhum corte muda o número do HERO.

**Ressalva, não bloqueia:** no quadro da queda a mão de 5 cartas entra junto e "Play Cards" fica aceso, e 0,5 s depois aparece um segundo "ENEMY TURN" (Tirano 42,02 s). Quem olhar com atenção vê que a vida cai no turno do jogador, entre dois turnos do inimigo, e o intent continua 4×4. Golpe visível de verdade exige regravar, o que também é decisão do Daniel. Na continuidade, só esta parte valeria 9.

"Murder of Crows": ~0,95 s legível na Tirano (42,26 a 43,21 s) e ~1,0 s no Rei. Fica dentro do critério de 0,8 a 1 s.

## 3. Rei 131 → 48 no corte de 45,80 s / 45,75 s: bloqueia

Recorte 1:1 (`t_48.png`): **131/220** a 45,70 s e **48/220** a 45,78 s, com a mão e o intent 4×4 iguais e nenhum golpe. Concordo com a diretora: na tomada, a vida é ajustada pela marca `lethal_pick` (44,633 s, sem golpe), e qualquer corte de antes para depois dela mostra o salto. Mostrar a descida dentro do plano seria outra queda sem golpe. Não há saída só com montagem.

**Para o Daniel decidir (a diretora não deve tentar mais rodadas de EDL nisso):**
- **(a)** Regravar `zero_carrion` com o Rei chegando a 48 por golpes reais (cartas do guerreiro, veneno ou tique de fogo na tela). Na mesma regravação, de preferência, o herói chega a 25 por um ataque dos corvos no turno inimigo, o que acaba também com a ressalva do item 2.
- **(b)** Aceitar o salto explicitamente como exceção. Nesse caso, eu reavalio a continuidade com essa decisão registrada.

## 4. Fecho, sincronia e o que não mudou

| item | medida minha | resultado |
|---|---|---|
| logo (as três) | GRIMOIRE **58,850**, gênero **59,400**, WISHLIST **61,983** s; WISHLIST na tela **2,517 s** | idêntico ao corte 2 |
| quadro preto | **0 de 3870** abaixo de 5% de luma nas três (mínimo 15,5 no escuro de 34,3 s) | ok |
| loudness | Tirano −14,1 LUFS, LRA 8,1, pico −1,1 dBFS (1080p e 720p iguais); Rei −14,1 LUFS, LRA 8,4, pico −1,2 dBFS | ok |
| 0 a 36 s | md5 dos quadros **idêntico ao corte 10**, nas duas | ok |
| sincronia Tirano, cortes novos | 38,93 (+10,3 dB, −0,6 q), Bash 39,498 (+10,0 dB, +0,1 q), 39,789 (+4,9 dB, −3,5 q), 40,358 (+5,6 dB, +0,1 q), −13 40,926 (+5,8 dB, −2,8 q), dreno 41,50 (+9,6 dB, −1,4 q), 42,064 (+4,4 dB, +1,0 q) | todos a ≤ 3,5 q de um ataque de grave; 9 |
| sincronia Rei, cortes novos | Bash 39,498 (**+40,8 dB**, −2,9 q), corvos 40,741 (**+37,8 dB**, −1,9 q), dreno 41,887 (+9,9 dB, −3,4 q); mas **38,895, 40,16 e 42,42 s não têm ataque ≥ 8 dB a ±0,35 s** (os mais próximos: 40,40 s, +14 q; 41,71 s, +20 q) | caem entre batidas numa faixa esparsa e não brigam com nenhuma; 9 (era 9,5) |
| sem zoom | mesma escala em todos os planos novos, tela inteira com HUD | ok |
| máscara do logo do Rei (correção da diretora) | registrada | sem efeito na nota: os tempos das linhas batem com o corte 2 |

## Notas

| critério | Tirano | Rei |
|---|---|---|
| sem zoom (Daniel 1) | 10 | 10 |
| fecho igual ao corte 2 (Daniel 2) | 9,5 | 9,5 |
| textos exatos (Daniel 3) | 10 | 10 |
| gancho | 9,5 | 9 |
| sincronia | 9 | 9 |
| **continuidade** (Rei 131 → 48 no corte) | **8** (45,80 s) | **8** (45,75 s) |
| legibilidade (LETHAL, Murder of Crows, 48, carta) | 9 | 9 |
| ritmo (silêncio de 30,08 a 36,97 s, aceito) | 9 | 9 |
| golpe final / respiro / Q (queda do Rei) | 9,5 | 9,5 |
| salões IA / contorno | 9 | 9 |
| som | 9 | 9 |
| prende | 9 | 9 |
| **geral** | **8,9** | **8,9** |

Tudo fica ≥ 9 nas duas versões, menos a continuidade. Não marco o corte como pronto. O próximo passo é a decisão do Daniel entre (a) regravar e (b) aceitar o salto.
