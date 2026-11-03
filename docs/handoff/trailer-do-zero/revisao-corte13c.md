# Revisão independente: corte 13, revisão 3 (trailer)

_Revisora, 03/11/2026. Read-only._

_Arquivo: `grimoire_trailer_c13c_720p.mp4`, com o stem `grimoire_trailer_c13c_music.f32` e o ganho de +8,2 dB. Comparado com `grimoire_trailer_c13_720p.mp4` (rev 2) e `grimoire_trailer_c12_loja_720p.mp4`. Base:_
- _minha `revisao-corte13b.md` (9,2);_
- _a revisão do Lead, `revisao-grimoire-corte13.md` (5b3e8aff, 8,9; bloqueio: a luta ~3 dB abaixo do corte 12 e abaixo dos salões);_
- _`corte13.md`, seção "Revisão 3"._

_O que medi:_
- _RMS do mix em mono a 16 kHz, por seção, com as mesmas janelas nos três arquivos (no c12 loja deslocadas pelos tempos dele; a luta são os 7,1 s antes do golpe letal);_
- _stem em janelas de 20 a 250 ms;_
- _`ebur128=peak=true`;_
- _MD5 do stream de vídeo._

_Scripts em `C:\Users\corte\AppData\Local\Temp\rev13\`. Não ouvi._

> **NÃO PUBLICÁVEL ATÉ TROCAR OU LICENCIAR OS SFX.**

## Veredito: PASS (9,3)

O bloqueio do Lead está resolvido: a luta voltou ao nível do corte 12 e ficou de novo acima dos salões, com a mesma folga. A imagem é a mesma da rev 2 (MD5 do vídeo `0c8fdfa83164ec524292f68d6ac94f55` nos dois arquivos, conferido por mim).

## Níveis por seção (mix, RMS)

| seção | c12 loja | rev 2 | **rev 3** | rev 3 − c12 | rev 3 − rev 2 |
|---|---|---|---|---|---|
| cartas | −16,5 | −14,5 | **−14,9** | +1,6 | −0,4 |
| Coleção | −21,6 | −17,9 | **−18,0** | +3,6 | −0,1 |
| criaturas | −15,7 | −15,7 | **−16,9** | −1,2 | −1,2 |
| salões | −14,1 | −14,0 | **−14,7** | −0,6 | −0,8 |
| **luta** (7,1 s antes do golpe) | −11,7 | −14,4 | **−12,3** | **−0,6** | **+2,1** |

- **Luta acima dos salões:** c12 loja **+2,4 dB**; rev 3 **+2,4 dB** (na rev 2 eram −0,4). O arco do corte 12 voltou.
- **Luta contra o corte 12:** −0,6 dB, dentro do que não se percebe.
- **Cartas e Coleção:** continuam acima do corte 12 (+1,6 / +3,6 dB).
- **Criaturas:** caíram **1,2 dB** contra a rev 2 e o 12, no limite do perceptível. Os salões caíram 0,8 dB. O integrado ficou o mesmo, então o limitador redistribuiu o volume para a luta. É o preço de resolver o bloqueio, e eu aceito. Se o Daniel achar o Espantalho e o anjo mais mansos, subir +1 dB só nas criaturas resolve.

## Golpe letal

Curva do stem a cada 0,25 s antes do golpe (69,916 s):

| antes do golpe (s) | −3,0 | −2,5 | −2,0 | −1,75 | −1,25 | −0,75 | −0,25 |
|---|---|---|---|---|---|---|---|
| rev 2 | −19 | −9 | −19 | −27 | −18 | −29 | −38 |
| **rev 3** | −13 | **−3** | −15 | −26 | −19 | −29 | −40 |

- Só os segundos **antes** da descida ficaram mais altos: a batida a −2,5 s está 6 dB acima.
- A descida que prepara o golpe, de −1,75 s até o impacto, é **igual** à da rev 2.
- O golpe no mix fica em −3,9 dB (pico de 100 ms).

| janela da música (stem) | rev 3 |
|---|---|
| 1,6 a 0,15 s antes (a descida) | **+20,3 dB** |
| 2,5 a 0,5 s antes (a minha janela de sempre) | **+6,9 dB** (rev 2: +12,7) |

**Leitura honesta:** a minha janela larga caiu abaixo de 12 dB porque agora inclui a batida forte da luta, a −2,5 s, que é exatamente o que o Lead pediu para subir. O que a gente ouve como preparo do golpe são os 1,75 s de música descendo até −40 dB, e contra eles o golpe fica +20 dB acima. Considero o critério cumprido pela janela da descida, mas registro a queda da janela larga para quem medir como eu media.

## Demais critérios

| item | resultado |
|---|---|
| loudness / pico real (`ebur128` com peak=true, resumo) | **I −14,1 LUFS, LRA 11,9 LU, Peak −1,3 dBFS** ok |
| música do portão até a luta (52,58 a 62,08 s) | máx. **−93,3 dBFS** |
| música no logo (73,35 a 79,85 s) | máx. **−97,9 dBFS** |
| aproximação, vento 0,5 s antes (mix, 0,2 s) | −23, −28, −34, **−40** (50,7 s), −31, −23, −27, −21 … −25. O vale encolheu para ~0,3 s, e o resto do plano fica em −21 a −31 dB. Melhorou. |
| loja, entrada | mínimo −29,0 dB, maior subida de 50 ms +5,5 dB (igual à rev 2) |
| loja, saída | mínimo −31,9 dB, maior subida de 50 ms **+2,6 dB** (mais suave) |
| imagem | idêntica à rev 2 (MD5): anjo, Espantalho, aproximação, porta, olhos, final, logo e textos já conferidos |

## Notas

| ponto | rev 2 | **rev 3** |
|---|---|---|
| loja / transição | 9,5 | 9,5 |
| Espantalho / criaturas | 9,5 | 9 (−1,2 dB) |
| anjo | 9,5 | 9,5 |
| portão e entrada | 9 | 9,5 (vale menor) |
| luta e final | 8,5 (pela medida do Lead) | **9,5** |
| cartas e Coleção | 9,5 | 9,5 |
| restante | 9,5 | 9,5 |
| **geral** | 9,2 (8,9 pelo Lead) | **9,3** |

## Recomendações (não seguram o PASS)

1. Se quiser a margem de 12 dB também na janela larga: começar a descida da música em ~−2,6 s, antes da batida de −2,5 s, em vez de −1,75 s. Custa um tempo forte da luta.
2. Criaturas +1 dB, se soarem mansas.

**Não publicável até trocar ou licenciar os SFX.** Ninguém ouviu as mixagens, e o julgamento final de gosto é do Daniel.

===CORTE13C_PRONTO===
