# Revisão do Grimoire: corte 8 (02/11/2026 00:06)

**Veredito: REPROVADO.** Tirano 8,0 / Rei 7,8. Elogios: a luta (começo e fim), o golpe do 48 e o espólio. Abrir o corte 9 nas duas versões (saídas `grimoire_zero_corte9_*`, sem sobrescrever masters).

## Antes de mexer
A diretora confere cada ponto quadro a quadro com o `medir2.py`, com PNG em `corte9_provas/`, e contesta com prova o que for falso (não mexe no que for falso).

## Nas duas versões
1. **Salões de IA ainda destoam dos sprites.** No salão do FROST (~0:21 no Rei), a névoa do chão e o fogo azul das piras parecem ter contorno escuro serrilhado: confirmar se o 8b ainda contorna partículas e, se sim, tirar. Fogo e lava (0:13 e trono 0:30) parecem borrados, com blocos de compressão: requantizar só essas regiões na grade de 5 px e 32 cores, com bordas duras, sem trocar os salões.
2. **Brilho da Carrion Crown (~0:56):** os quadrados translúcidos grandes parecem artefato. Usar brilho menor, com 2–3 tons da paleta, pixel de 5 px e opaco.
3. **Escuro de 0:31 a 0:34** (fumaça/corvo, cinemática do jogo, não trocar): encurtar para ≤ 1,5 s se a música deixar.
4. **Virada (0:43–0:46):** três enquadramentos em ~3 s quebram a geografia. Leitura única: dano no herói, vida em 9 (ainda visível) e depois a mão com o LETHAL. No máximo uma mudança de plano, sempre avançando.

## Só no Rei
5. **Entre 25 e 28 s** há três planos em 3 s (esporo, figura alada escura em ~0:26, portão). Confirmar se a figura existe (deve ser o pouso do anjo); se existir, tirar ou dar respiro para a sequência respirar.
6. **~0:51:** depois do impacto em ×3, um corte seco volta para o plano aberto com o Rei caído. Se for verdade, manter a queda em ×3 até os ossos, ou justificar com prova.
7. **Anúncio Murder of Crows** em ~0,85 s: subir para ~1,1 s se a música deixar.

## Nas duas, gancho
8. **0:00–0:02** mostra só o espantalho respirando: avaliar entrar com a interface ou a ação ~1 s antes (o quadro 0 continua não preto, com a cabeça do Espantalho).

Manter tudo o que já está confirmado.

## Avaliação
A revisora avalia o corte 9 contra estes 8 pontos (real/falso com PNG), além dos critérios de sempre (≥ 9 em tudo, inclusive Q), em `revisao-corte9.md`, com `===CORTE9_PRONTO===` só com as duas aprovadas.

## Regras
Um lovec, headless, sem 4K, Steam ou push, sem sobrescrever masters, sem trocar faixa, texto ou salão (se surgir, parar e reportar), sem criar conteúdo que não existe no jogo. Commits como Daniel Cortez, sem Co-Authored-By.