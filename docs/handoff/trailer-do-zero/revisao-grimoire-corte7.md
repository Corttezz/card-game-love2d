# Revisão do Grimoire: corte 7 (01/11/2026 22:30)

**Veredito: REPROVADO.** Tirano 8,5 / Rei 7,0. Abrir o corte 8 nas duas versões (saídas `grimoire_zero_corte8_*`, sem sobrescrever masters).

**Ratificado:** o pouso do Rei 2,7 quadros depois do ataque de 27,585 s fica como está.

## Antes de mexer
A diretora confere cada ponto quadro a quadro com o `medir2.py`, com PNG em `corte8_provas/`, e contesta com prova o que for falso (não mexe no que for falso).

## Pontos
1. **Zoom recuando no fim da luta:** no Tirano, recuo brusco em ~0:50 no golpe do 48, depois do zoom de 0:48–0:49; no Rei, recuo brusco em ~47,6 s, depois do zoom na UI em 46,7 s. Se for um corte que volta para ×1, trocar por degrau que só avança ou manter o plano fechado até o 48.
2. **Tirano:** a carta Murder of Crows (Revoada) não aparece por volta de 0:42; os corvos voam e a vida cai sem a carta. No Rei ela aparece. Deixar as duas iguais.
3. **Rei:** o golpe do 48 caiu em ~49,9 s. Confirmar no librosa que é o ataque mais forte da trilha nessa região e gerar tabela.
4. **Rei:** do primeiro quadro do castelo (25,9 s) ao portão (27,3 s) o revisor mediu ~1,4 s, contra os 2,24 s reportados. Medir e explicar qual intervalo foi contado (tabela).
5. **Transição de fumaça roxa com dithering** entre o salão do trono e o Rei (~0:32–0:34) parece filtro barato. Trocar por corte seco na batida ou por transição na grade de pixel do jogo.
6. **Carrion Crown congelada** como imagem chapada por 2,8 s. Pôr flutuação leve (1–2 px na grade, ou um brilho) sem perder a leitura.
7. **Salões do Higgsfield** (ficam, decisão do Daniel): adicionar contorno escuro de 1 px da grade nas silhuetas principais para casar com os sprites, sem trocar o salão.

Manter tudo já confirmado (10 pontos do corte 5, correções dos cortes 6 e 7).

## Avaliação
A revisora avalia o corte 8 contra esses 7 pontos (real/falso com PNG), além dos critérios de sempre (≥ 9 em todos, inclusive Q), em `revisao-corte8.md`, com `===CORTE8_PRONTO===` só com as duas aprovadas.

## Regras
Um lovec, headless, sem 4K, Steam ou push, sem sobrescrever masters, sem trocar faixa, texto ou salão (se surgir, parar e reportar). Commits como Daniel Cortez, sem Co-Authored-By.