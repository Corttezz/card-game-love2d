# Instrução do corte 9, mensagem das 00:06 (complementa revisao-grimoire-corte8.md, versão das 00:07)

**Veredito: REPROVADO.** Tirano 8,0 / Rei 7,8. Elogios: a luta (come├ºo e fim), o golpe do 48 e o esp├│lio. Abrir o corte 9 nas duas vers├Áes (sa├¡das `grimoire_zero_corte9_*`, sem sobrescrever masters).

## Antes de mexer
A diretora confere cada ponto quadro a quadro com o `medir2.py`, com PNG em `corte9_provas/`, e contesta com prova o que for falso (n├úo mexe no que for falso).

## Nas duas vers├Áes
1. **Sal├Áes de IA ainda destoam dos sprites.** No sal├úo do FROST (~0:21 no Rei), a n├®voa do ch├úo e o fogo azul das piras parecem ter contorno escuro serrilhado: confirmar se o 8b ainda contorna part├¡culas e, se sim, tirar. Fogo e lava (0:13 e trono 0:30) parecem borrados, com blocos de compress├úo: requantizar s├│ essas regi├Áes na grade de 5 px e 32 cores, com bordas duras, sem trocar os sal├Áes.
2. **Brilho da Carrion Crown (~0:56):** os quadrados transl├║cidos grandes parecem artefato. Usar brilho menor, com 2ÔÇô3 tons da paleta, pixel de 5 px e opaco.
3. **Escuro de 0:31 a 0:34** (fuma├ºa/corvo, cinem├ítica do jogo, n├úo trocar): encurtar para Ôëñ 1,5 s se a m├║sica deixar.
4. **Virada (0:43ÔÇô0:46):** tr├¬s enquadramentos em ~3 s quebram a geografia. Leitura ├║nica: dano no her├│i, vida em 9 (ainda vis├¡vel) e depois a m├úo com o LETHAL. No m├íximo uma mudan├ºa de plano, sempre avan├ºando.

## S├│ no Rei
5. **Entre 25 e 28 s** h├í tr├¬s planos em 3 s (esporo, figura alada escura em ~0:26, port├úo). Confirmar se a figura existe (deve ser o pouso do anjo); se existir, tirar ou dar respiro para a sequ├¬ncia respirar.
6. **~0:51:** depois do impacto em ├ù3, um corte seco volta para o plano aberto com o Rei ca├¡do. Se for verdade, manter a queda em ├ù3 at├® os ossos, ou justificar com prova.
7. **An├║ncio Murder of Crows** em ~0,85 s: subir para ~1,1 s se a m├║sica deixar.

## Nas duas, gancho
8. **0:00ÔÇô0:02** mostra s├│ o espantalho respirando: avaliar entrar com a interface ou a a├º├úo ~1 s antes (o quadro 0 continua n├úo preto, com a cabe├ºa do Espantalho).

Manter tudo o que j├í est├í confirmado.

## Avalia├º├úo
A revisora avalia o corte 9 contra estes 8 pontos (real/falso com PNG), al├®m dos crit├®rios de sempre (ÔëÑ 9 em tudo, inclusive Q), em `revisao-corte9.md`, com `===CORTE9_PRONTO===` s├│ com as duas aprovadas.

## Regras
Um lovec, headless, sem 4K, Steam ou push, sem sobrescrever masters, sem trocar faixa, texto ou sal├úo (se surgir, parar e reportar), sem criar conte├║do que n├úo existe no jogo. Commits como Daniel Cortez, sem Co-Authored-By.
