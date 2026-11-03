# Revisão independente: corte 13 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivo: `grimoire_trailer_c13_720p.mp4` (80,0 s, 4795 quadros). Comparação com `grimoire_trailer_c12_loja_720p.mp4` (a versão que o Daniel viu) e com `grimoire_trailer_c12_720p.mp4`. Pedido: fala do Daniel de 03/11 14:21. Registro: `corte13.md` (f5878721)._

_O que medi:_
- _stem de música `grimoire_trailer_c13_music.f32` com o ganho de +9,2 dB, RMS em janelas de 50 ms a 0,25 s;_
- _mix do 720p, RMS de 0,2 a 0,5 s;_
- _`ebur128=peak=true`;_
- _folhas da loja (5 quadros/s), do portão e da entrada (2,5 quadros/s), do Espantalho (4 quadros/s) e do anjo (10 quadros/s, crop 1:1 na 1080p);_
- _luma por quadro, bitrate._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev13\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: FAIL (8,8), por dois defeitos de som nos dois pontos que o Daniel reclamou

A imagem atende aos cinco pedidos: dissolves na loja, Espantalho novo, anjo batendo as asas, aproximação com a porta e a entrada desde os olhos, e o final no ataque da faixa. O som falha justamente onde ele pediu suavidade:
1. **A música da loja entra com um golpe.**
2. **O plano de aproximação do castelo fica quase mudo**, quando ele pediu que "aparece o som ambiente".

As duas correções são só de mix.

## Os cinco pontos

### 1. Loja (entrada e saída)

**Imagem: suave.**
- Entra por dissolve de 0,5 s (Coleção → estrada da casinha da loja, ~29,4 a 29,9 s).
- A casinha aparece por ~1,1 s, e a passagem do próprio jogo para o interior acontece em ~31,0 s.
- O interior fica ~2,3 s.
- Sai por dissolve de 0,45 s para o Espantalho (~33,4 s).

**Música da entrada: não está suave.** No stem, em janelas de 50 ms:

| t (s) | 29,20 | 29,50 | 29,55 a 29,70 | **29,75** | 29,80 | 30,00 | 30,10 |
|---|---|---|---|---|---|---|---|
| dBFS | −26 | −32 | −37 a −39 | **−14** | **−9** | −19 | −24 |

O Rei sai em ~0,5 s, há um buraco de ~0,2 s, e a música da loja entra **de uma vez, +25 dB em 50 ms**. O mix repete o salto (−36 → −12 dB entre 29,5 e 29,75 s). O crossfade de 1 s do registro existe para o Rei, mas a faixa da loja começa num ataque forte. Na prática, é a mesma "mudança muito abrupta de música" que o Daniel apontou.

**Música da saída: suave.** −19 (32,8) → −29 (33,0) → −38 (33,2) → −30 → −23 (33,6 s): um crossfade de verdade.

### 2. Espantalho, tomada nova

**Há tomada nova, e ela é boa.** De 33,41 a 36,14 s:
- o espantalho de madeira fica no primeiro plano à esquerda;
- a criatura anda pela estrada até o centro, sob "A BESTIARY OF THE CURSED.".

É mais legível que a do corte 12: a criatura fica grande no centro e o texto não a cobre. O salto do poste fica antes do trecho usado, então o espectador vê a caminhada, não o acordar.

### 3. Anjo batendo as asas

**Sim.** Na folha a 10 quadros/s (38,6 a 41,8 s), o anjo entra pelo alto e as asas alternam claramente entre erguidas, abertas e baixadas enquanto desce, até o pouso perto do poste. Antes e depois (`anjo_voo_antes_depois.png`): no corte 12 as asas ficavam abertas e paradas. Resolve o "fica muito durão".

### 4. Portão

| pedido | resultado |
|---|---|
| fade da música ≥ 1,5 s, lendo como "abaixando" | **Feito.** Stem: −8 (48,75) → −17 (49,25) → −27 (49,5) → −23/−26 (50,0 a 50,25) → −40 (50,5) → −51 (50,75) → −68 (51,25). Cerca de 2,3 s, em degraus que acompanham a faixa. Lê como "abaixando". |
| plano de aproximação | **Feito na imagem.** A estrada até o castelo com a bandeira, ~2,4 s (50,18 a 52,58 s). |
| som ambiente aparecendo na aproximação | **Não.** O mix fica em **−44 a −54 dB de 50,6 a 52,0 s** (−48, −47, −54, −47, −51, −53). São ~1,4 s praticamente mudos, a música já saiu e o ambiente quase não se ouve. Só em 52,0 a 52,6 s (−43 → −25) o som volta, com o portão. É um buraco onde o Daniel pediu "ai muda pro cenário, aparece o som ambiente". |
| porta abrindo | **Feito** (52,58 s, com o som do portão). |
| entrada do chefe desde os olhos | **Feito.** O salão escuro em 54,58 s (0,7 s abaixo de 5% de luma, de 54,68 a 55,37 s, intencional), os olhos acendendo em ~55,1 s, os rasantes, o pouso e o cartão "CARRION KING". |
| música < −50 dB do portão ao fim da entrada | **Feito.** De 52,58 a 62,08 s: máx. **−91,6 dBFS**. Desde 51,20 s: máx. −53,0, só na cauda do fade. |

### 5. Final amarrado à música

**Feito.**
- Golpe letal a 69,92 s; a música cede e volta para a morte (stem −40 → −14 de 70,0 a 71,0 s).
- Corte para o preto a 73,05 s, num ataque da faixa, com impacto: o mix sobe a −9 em 73,0 s.
- A música está em **−83 dBFS** já em 73,25 s.
- Logo (73,35 a 79,85 s) só com os sons da animação: stem máx. **−96,1 dBFS**.

## Critérios técnicos

| item | resultado |
|---|---|
| loudness / pico real (`ebur128` com peak=true, resumo) | **I −14,1 LUFS, LRA 8,0 LU, Peak −1,2 dBFS** ok |
| golpe letal | Sobre o stem de música, 2,5 a 0,5 s antes: **+14,1 dB** (registro). Pelo mix inteiro na mesma janela, que inclui os efeitos do turno: +11,3 dB. Passa pelo critério (música). |
| cartas e Coleção contra o 12 | cartas **−14,5** contra −16,5 dB (**+2,0**); Coleção **−18,2** contra −21,6 dB (**+3,4**). Ok. |
| morte nas cartas | +11,3 dB (registro), acima do 11g (+9,6) e do 11f (+3,6). |
| escala | Sem zoom (avisos só no glitch, no pouso do anjo e na cinemática do jogo). |
| logo igual ao 12 | 390 quadros, 0,04/255 (prova da diretora; o preto e o logo nas folhas são iguais). |
| quadros < 5% de luma | 176: TV ligando, o salão escuro antes dos olhos (0,7 s, pedido do Daniel), fundo do logo e o rabo final. |
| textos | Mesmos do corte 12, legíveis ("A BESTIARY OF THE CURSED." sem cobrir a criatura). |
| bitrate 720p | 13,3 Mb/s |

## Notas (corte 12 com loja → corte 13)

| ponto | c12 loja | c13 |
|---|---|---|
| loja / transição | 8 | **8,5** (imagem ok, música entra com golpe) |
| Espantalho | 9 | 9,5 |
| anjo | 8,5 | **9,5** |
| portão e entrada | 9 | **8,5** (aproximação muda) |
| final | 9,5 | 9,5 |
| cartas e Coleção (volume) | 9 | 9,5 |
| restante (atos, salões, luta, logo, textos) | 9,5 | 9,5 |
| **geral** | 8,8 | **8,8** |

O corte 13 é melhor que o 12 na imagem (anjo, Espantalho, aproximação, porta, olhos) e no volume das cartas. Fica abaixo de 9 porque os dois momentos que o Daniel pediu suaves ainda têm problema de som.

## O que corrigir (só mix, sem mexer na imagem)

1. **Entrada da música da loja (29,4 a 30,2 s):** fazer um fade-in de ~0,8 a 1,0 s na faixa da loja, ou começá-la depois do ataque do primeiro tempo, e sobrepor ao fim do Rei sem o buraco de −39 dB. Alvo: nenhum salto maior que ~6 dB em 100 ms no stem entre 29,0 e 30,5 s.
2. **Ambiente na aproximação (50,2 a 52,6 s):** trazer o ambiente do próprio jogo (vento, grilos, tochas, ou o `audio.jsonl` da tomada) para **−24 a −30 dB** de RMS, entrando enquanto a música desce, para o mix não cair abaixo de ~−32 dB em nenhum trecho de 0,2 s. A música continua < −50 dB.
3. **Prova pedida:** a curva do stem a 50 ms em 29,0 a 30,5 s e a curva do mix a 0,2 s em 48,5 a 53 s.

Manter todo o resto: anjo, Espantalho, dissolves, fade do portão, olhos, final, cartas e logo.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE13_FAIL===
1. Música da loja entra com salto de +25 dB em 50 ms (29,75 s): fazer fade-in ou crossfade de verdade.
2. Aproximação do castelo quase muda (mix −44 a −54 dB, 50,6 a 52,0 s): pôr o ambiente a −24/−30 dB.
