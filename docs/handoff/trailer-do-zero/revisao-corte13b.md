# Revisão independente: corte 13, revisão 2 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivo regravado: `grimoire_trailer_c13_720p.mp4` (80,0 s). Stem de música `grimoire_trailer_c13_music.f32` com o ganho de +9,3 dB. Base: minha `revisao-corte13.md` (d3a1141c, 8,8, FAIL) e `corte13.md`, seção "Revisão 2"._

_O que medi:_
- _stem em janelas de 50 e 100 ms (entrada da loja);_
- _mix do 720p em janelas de 0,1 e 0,2 s, mono a 16 kHz (loja, aproximação, cartas, golpe);_
- _`ebur128=peak=true`, luma por quadro, bitrate e detecção de cortes._

_Evidências em `C:\Users\corte\AppData\Local\Temp\rev13\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: PASS (9,2)

O bloqueio 1 está resolvido. O bloqueio 2 melhorou muito, mas não chegou ao alvo que escrevi (ver abaixo): resta um vale curto, que não seguro a nota por ele.

## Bloqueio 1: entrada da música da loja

Stem de 28,5 a 30,6 s, em janelas de 50 ms: −18, −19, −19, −18, −17, −16, −17, −19 … −21, −22, −21, −19, −19, −20, −21, −22, −17, **−12**, −12, −14, −16, −18, −20 … −27, −21, −22, −20 …

| | revisão 1 | **revisão 2** |
|---|---|---|
| mínimo | −39 dB | **−27,1 dB** |
| maior subida em 50 ms | +25 dB | **+5,5 dB** |
| maior subida em 100 ms | — | **+6,7 dB** |

O Rei e a loja agora se sobrepõem, sem buraco. A maior subida fica dentro do alvo (≤ 6 dB em 100 ms, com folga de 0,7 dB). O mix repete a curva (−16 a −21, um pico de −12 no ritmo da faixa da loja, depois −19 a −26). **Resolvido.** Dissolves de imagem iguais aos da revisão 1.

## Bloqueio 2: ambiente na aproximação do castelo

Mix em janelas de 0,2 s:

| t (s) | 50,1 | 50,3 | 50,5 | 50,7 | 50,9 | 51,1 | 51,3 | 51,5 | 51,7 | 51,9 | 52,1 a 52,5 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| revisão 1 | −23 | −33 | −44 | −48 | −47 | −54 | −47 | −51 | −53 | −43 | −35 a −40 |
| **revisão 2** | −21 | −28 | −32 | **−40** | −29 | **−38** | −35 | −24 | −22 | −20 | −19 a −24 |

- Pela minha medida, no plano inteiro (50,18 a 52,58 s): mediana **−30,2 dB**, mínimo **−39 dB**. A diretora mediu mediana −23,5 e mínimo −30,4. A diferença deve ser de janela e método (eu uso mono, 0,2 s).
- O ambiente agora existe e sobe: de 51,5 s até o portão fica em −19 a −24 dB.
- Sobra um **vale de ~0,8 s (50,5 a 51,4 s)** em −32 a −40 dB, na troca entre o fim da música e a chegada do ambiente. O alvo que escrevi era não cair abaixo de ~−32 dB em nenhum trecho de 0,2 s, e esse vale passa disso em três janelas.
- Antes eram 1,4 s mudos a −47/−54 dB; agora são 0,8 s baixos, com ambiente. Não lê mais como "buraco", e sim como a música indo embora antes de o vento entrar.

**Resolvido o bastante.** Recomendação: entrar com o vento ~0,5 s mais cedo (em ~50,4 s) apaga o vale.

## Sem regressão

| item | resultado |
|---|---|
| loudness (`ebur128` com peak=true, resumo) | **I −14,0 LUFS, LRA 7,9 LU, Peak −1,2 dBFS** |
| imagem | Mesma duração (4795 quadros) e mesmos quadros escuros: TV ligando, o salão escuro antes dos olhos (54,68 a 55,37 s), fundo do logo, rabo final. Bitrate 13,3 Mb/s, igual à revisão 1. |
| fade antes do portão | igual: −8 (48,75) → −27 (49,5) → −40 (50,5) → −51 (50,75) → −68 (51,25 s) |
| música do portão ao fim da entrada (52,58 a 62,08 s) | máx. **−91,5 dBFS** |
| música no logo (73,35 a 79,85 s) | máx. **−96,0 dBFS** |
| golpe letal | +12,7 dB sobre o stem de música, 2,5 a 0,5 s antes (registro: +14,1 na janela de 1,6 a 0,15 s) |
| cartas / Coleção | −14,5 / −17,9 dB, contra −16,6 / −21,5 no corte 12 (**+2,1 / +3,6 dB**) |
| anjo, Espantalho, portão, olhos, final, logo, textos | imagem idêntica à revisão 1, já conferida |

## Notas

| ponto | c12 loja | c13 rev 1 | **c13 rev 2** |
|---|---|---|---|
| loja / transição | 8 | 8,5 | **9,5** |
| Espantalho | 9 | 9,5 | 9,5 |
| anjo | 8,5 | 9,5 | 9,5 |
| portão e entrada | 9 | 8,5 | **9** (vale de 0,8 s) |
| final | 9,5 | 9,5 | 9,5 |
| cartas e Coleção | 9 | 9,5 | 9,5 |
| restante | 9,5 | 9,5 | 9,5 |
| **geral** | 8,8 | 8,8 | **9,2** |

Melhor que o corte 12 em todos os pontos que o Daniel apontou às 14:21:
- loja suave na imagem e no som;
- Espantalho novo;
- anjo batendo as asas;
- música abaixando, ambiente, aproximação, porta abrindo e a entrada desde os olhos;
- final amarrado à música.

## Recomendações (não seguram o PASS)

1. Entrar com o vento e os grilos ~0,5 s mais cedo (~50,4 s), para fechar o vale de −38/−40 dB entre 50,5 e 51,4 s.
2. Para o Daniel: "SIX BOSSES." aparece sobre cinco salões.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE13_PRONTO===
