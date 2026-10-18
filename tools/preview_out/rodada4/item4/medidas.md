# Item 4: ato 5 (marsh) escuro demais no fim do dia

Medida (luminância do chão e props, linhas 620 a 1000, fora da faixa da mão; batalha 1080p):

| quadro | média | desvio | pixels < 0,05 | mediana |
|---|---|---|---|---|
| antes tod 0,65 | 0,117 | 0,072 | 22,5 % | 0,130 |
| antes tod 0,85 | 0,116 | 0,075 | 23,7 % | 0,124 |
| antes tod 1,0 | 0,111 | 0,073 | 24,9 % | 0,119 |
| depois tod 0,65 | 0,141 | 0,087 | 20,7 % | 0,156 |
| depois tod 0,85 | 0,142 | 0,090 | 20,8 % | 0,153 |
| depois tod 1,0 | 0,138 | 0,088 | 21,3 % | 0,149 |

Leitura: a média do marsh já não era a mais escura (fields 0,100, dusk 0,101 em tod 0,85). O que sumia era o
CONTRASTE: raízes e juncos são quase pretos (arte) sobre um chão oliva também escuro, então viravam uma massa só.
Primeira tentativa (só ambiente e grade, `i4a`) subiu a média 11 % e quase não mudou a leitura. O que resolveu foi
clarear o CHÃO (fundo) mantendo as silhuetas escuras: `grassA` 0,26/0,31/0,15 -> 0,31/0,37/0,18 e `grassB`
0,21/0,26/0,12 -> 0,25/0,31/0,14 (mesmo matiz), mais `lightNight`/`lightAmbient` 0,62/0,70/0,58 -> 0,70/0,77/0,64,
`lightDay` 0,78/0,85/0,72 -> 0,80/0,87/0,74 e o `grade.dusk` 0,90/0,98/0,90 -> 0,98/1,00/0,95 (o grade multiplicava
a arte por 0,90 no fim do dia). Desvio +20 % (raízes voltam a ser silhueta contra o chão), mediana +23 %. O
clima continua de pântano: matiz oliva-esverdeado, névoa e céu intocados.

Folhas: `b5_recorte.png` (primeiro plano 1:1, antes|depois nas três horas) e `b5_batalha.png` (quadro inteiro).
