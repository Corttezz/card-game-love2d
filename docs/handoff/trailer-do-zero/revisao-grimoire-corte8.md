# Revisão do Grimoire: corte 8b (02/11/2026 00:07)

**Veredito: REPROVADO.** Tirano 8,0 / Rei 7,0 (revisão independente por vídeo). Abrir o corte 9 nas duas versões (saídas `grimoire_zero_corte9_*`, sem sobrescrever masters). Aprovado e mantido: quadro 0, textos exatos, "Murder of Crows" legível, impacto visual do 48 (hit-stop, flash, tremor), contorno nos pilares e arcos.

## Antes de mexer
A diretora confere cada ponto quadro a quadro com o `medir2.py`, com PNG em `corte9_provas/`, e contesta com prova o que for falso (não mexe no que for falso).

## Pontos
1. **Recuo na queda do Rei (as duas):** depois do close apertado do golpe (~0:50-0:51), o plano da queda (~0:51-0:52) aparece mais aberto, mostrando o corpo inteiro. Os dois revisores viram isso como recuo. Manter o enquadramento do golpe ou mais fechado durante a queda (seguir o corpo sem abrir), até "BREAK THEM BACK.".
2. **Contorno ainda nas chamas e na lava (as duas):** pixels escuros ao redor e dentro do fogo da lareira do trono (~0:30-0:31) e na lava do salão (~0:14). Tirar o contorno de toda região de chama, lava e tocha (máscara por cor quente/saturação, além da luminância) e conferir 1:1.
3. **Carrion Crown chapada (as duas):** o sobe e desce no eixo Y com brilho ainda lê como PNG colado. Dar profundidade: inclinação sutil (tilt/escala horizontal leve) e uma sombra projetada na grade de pixel, sem perder a leitura da face.
4. **Coringa (Tirano):** o revisor não viu face de coringa em ~0:55, só o verso girando para revelar o Rei. Conferir se a face do coringa está visível e legível pelo tempo combinado; se não estiver, corrigir.
5. **Respiro esporo/anjo/portão (Rei, ~0:24-0:30):** esporo e anjo com menos de 1 s cada parecem recortes; o portão leva ~2,8 s. Rebalancear (ex.: esporo e anjo ~1,3 s cada, portão mais curto) sem mudar o ataque do portão.
6. **Ritmo antes do castelo (Tirano, ~0:24-0:27):** caminhada de 3-4 s sem ação ainda lida como trecho morto. Encurtar ou cobrir com ação.
7. **Golpe do Rei e o respiro (Rei, ~0:50):** um revisor achou que a música atropela o golpe, sem respiro audível. Medir no `mix.wav` se o respiro de -8 é perceptível; se não for, aprofundar ou alongar o respiro para a volta forte cair no 48. (Ponto a conferir com prova; não mexer se for falso.)
8. **Luta do Rei fragmentada (Rei, ~0:41-0:46):** ataque, herói apanhando e revide parecem mecânicos. Conferir se dá para encadear com cortes na batida sem trocar tomadas.

Manter tudo já confirmado (cortes 5 a 8b).

## Avaliação
A revisora avalia o corte 9 contra esses 8 pontos (real/falso com PNG), além dos critérios de sempre (≥ 9 em todos), em `revisao-corte9.md`, com `===CORTE9_PRONTO===` só com as duas aprovadas. Copiar os 720p para a box como `/workspace/trailers/corte9_720p.mp4` e `corte9_rei_720p.mp4`.

## Regras
Um lovec, headless, sem 4K, Steam ou push, sem sobrescrever masters, sem trocar faixa, texto ou salão (se surgir, parar e reportar). Commits como Daniel Cortez, sem Co-Authored-By.