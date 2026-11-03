# Revisão independente: corte 11, revisão 3 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivos (regravados): `grimoire_trailer_c11_720p.mp4` (Tirano, 65,4 s, 3918 quadros), `grimoire_trailer_c11_rei_720p.mp4` (Rei, 66,9 s, 4007 quadros) e os masters 1080p. Base: minha `revisao-corte11b.md` (6af56085) e `corte11.md`, seção "Revision 3" (472e0f8f). Critérios e referências iguais aos de antes: feedback literal do Daniel, v5, v6, v8 e kinetic_new_som._

_O que medi:_
- _folha a 4 quadros/s da luta (44 a 59 s);_
- _recortes 1:1 da barra do Rei e do painel HERO, a 10 quadros/s e **quadro a quadro dos dois lados de cada corte da luta**, nas duas versões;_
- _folha a 6 quadros/s do golpe final;_
- _quadros escuros, `ebur128`;_
- _onsets dos cortes novos na faixa de cada versão._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev11c\` (`t_luta.png`, `t_hero.png`, `t_barra.png`, `cortes.png`, `f53.png`, `n_51.60.png`, `n_53.30.png`, `r_all.png`, `r55.png`, `kill.png`). Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: FAIL nas duas versões, pela continuidade dos números

O golpe final agora existe e é bom: "21/21 LETHAL", Colossus Blow com **−31** (×1,5) sobre o Rei com 21, e ele cai na morte em câmera lenta do jogo (`kill.png`). Era o que faltava na revisão 2.

Mas o `corte11.md` diz "No number changes across a cut", e **isso é falso**. Os dois cortes novos da luta pulam golpes, e os números saltam em três lugares:

| corte | Tirano | Rei | o que salta | o que ficou fora |
|---|---|---|---|---|
| entrada do plano dos corvos | **51,856 s** | **53,214 s** | HERO **41 → 33** no corte (Rei 30 nos dois lados) | os dois primeiros corvos |
| entrada do LETHAL | **53,574 s** | **55,118 s** | HERO **17 → 9** **e** Rei **30 → 21** no mesmo corte | os dois últimos corvos e o tique de fogo −9 no Rei |

Provas: `n_51.60.png` e `n_53.30.png` (Tirano) e `r_all.png` e `r55.png` (Rei). O mesmo recorte, quadro a quadro, mostra 41/70 até o último quadro antes do corte e 33/70 no primeiro depois. O 30/220 vai a 21/220 entre dois quadros vizinhos, sem número de dano na tela.

Os saltos são menores que o 131 → 48 do corte 10b. Mas o próprio 21 do Rei é a conta que o "21/21 LETHAL" mostra, e o −9 que o leva de 30 a 21 sumiu no corte. Pela régua que reprovou os cortes 9, 10 e 10b ("nenhum corte muda o número sem golpe visível"), isso bloqueia a continuidade.

## A) Nota por ponto do feedback

| # | ponto | Tirano | Rei | por quê |
|---|---|---|---|---|
| 1 | textos | 9 | 9 | Iguais à revisão 2, grandes e legíveis. "ONE HAND CAN BREAK A KING." agora é cumprido. |
| 2 | abertura: seis atos com ambiente calmo | 9 | 9 | Igual à revisão 2. |
| 3 | qualidade de imagem | 9,5 | 9,5 | 720p a 13,7 Mb/s; 1080p a 33,4 / 33,3 Mb/s. A luta nova tem o CRT e a moldura do jogo, igual ao resto do filme. |
| 4 | chefes no ritmo | 9 | 9,5 | Salões iguais à revisão 2. |
| 5 | sensação épica | **9** | **9** | Agora tem a entrada do Rei, um turno de combo, os corvos, o LETHAL, o golpe e a morte em câmera lenta, com arco de som (LRA 10,3 / 9,6). Subiu de 8,5. |
| 6 | jogar cartas satisfatório | 9,5 | 9,5 | Turno 1 com Colossus Blow −39 e Twin Strike −33, contagem até 30 e "COMBO! Volley +6". Último turno com a prévia LETHAL e o golpe −31. É o melhor bloco de cartas de todas as versões. |
| 7 | coleção | 9,5 | 9,5 | Igual à revisão 2. |
| 8 | entradas de criaturas | 9 | 9 | Igual. |
| 9 | final do Grimoire | 10 | 10 | Os 390 quadros inteiros nas duas. |
| 10 | geral contra as referências | **8,5** | **8,5** | Ganha de todas no conteúdo, mas a luta pula números duas vezes em 2 s. |
| — | continuidade de números na luta | **7,5** | **7,5** | Três saltos em dois cortes (acima). |

## B) Lado a lado com as referências

A comparação da revisão 2 continua valendo, e o clímax agora **ganha de todas**. O v5 e o v6 matam o Rei sem mostrar o golpe; o v8 e o kinetic nem matam. O corte 11 é o único com a conta fechando na tela (21/21 LETHAL → −31 → morte). Só não fica **claramente** melhor porque, no trecho mais assistido, a barra do herói e a do Rei pulam em cortes. Quem acompanhou o 30/220 durante os corvos vê o 21 aparecer do nada.

## C) Conferências técnicas

| item | Tirano | Rei |
|---|---|---|
| sem zoom | A prova refeita (`escala_filme_inteiro.txt`) só marca a TV ligando e a transição escura da porta para o rasante (45,4 a 45,7 s / 47,1 s); nas folhas, o rasante é a animação do jogo, sem mudança de enquadramento. Ok. | Ok. |
| cortes da luta nos onsets | 50,718 (grave +15,5 dB), 51,856 (fluxo 4,9×) e **53,574 (fraco: 1,9×, o forte está 0,33 s antes)** | 51,659 (+13,6 dB), 53,214 (4,4×) e **55,118 (fraco: 2,5×, +2,2 dB)** |
| quadros < 5% de luma | 135: TV ligando, fundo do logo e o rabo preto de 0,1 s depois do logo. Ok. | Igual. |
| loudness | **−13,4 LUFS**, pico −0,8 dBFS, LRA 10,3 | −13,8 LUFS, pico −0,8 dBFS, LRA 9,6 |
| bitrate | 13,7 / 33,4 Mb/s | 13,7 / 33,3 Mb/s |

A Tirano está a **−13,4 LUFS**, 0,6 dB acima do alvo e fora da tolerância de ±0,5. O pico de −0,8 dBFS também está no limite.

## O que mudar, em ordem de impacto

1. **Continuidade dos dois cortes da luta** (só montagem, mesma tomada `c11boss`):
   - **Entrada dos corvos:** começar o plano antes do primeiro corvo, com o HERO ainda em 41, ou cortar do turno 1 já no quadro em que o herói está em 33, desde que o corvo que o leva a 33 apareça.
   - **Entrada do LETHAL:** manter na tela os dois últimos corvos (17 → 13 → 9) **e** o tique −9 no Rei (30 → 21, com o número e o "WEAKNESS!"), e só então cortar para o turno do LETHAL. Se faltar tempo, encurte o meio dos corvos, entre dois golpes, num patamar em que os números são iguais dos dois lados do corte.
   - Prova pedida: a folha quadro a quadro dos dois lados de **cada** corte da luta, com os números do HERO e do Rei.
2. **Cortes da luta no tempo forte:** 53,574 s (Tirano) e 55,118 s (Rei) caem em onsets fracos. Ao refazer o item 1, ponha os dois no ataque forte vizinho.
3. **Loudness da Tirano em −14,0 LUFS** (hoje −13,4), com o pico ≤ −1 dBTP.

Mantido e bom: golpe final com a morte, turno 1 em dois cortes, final de 390 quadros, atos, arco de som, chefes, textos, coleção, entradas e qualidade de imagem. Corrigido o item 1, as notas sobem para ≥ 9 em tudo, e o corte fica claramente melhor que as referências.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.
