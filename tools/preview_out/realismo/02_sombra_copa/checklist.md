# Experimento (a): sombra de copa no chão, mais evidente

Folhas: `folha_*.png` (colunas atual | a2 | a3); recortes 3x em `rec_*.png`; `diff_b1_meio_*.png` = onde a sombra cai (×6).

## Tentativas

| versão | mudança | medida (tod 0,5, pé da sombra) | veredito |
|---|---|---|---|
| a | `alphaK` 1,8 → 2,4; `fade` 0,45 → 0,30 | ×0,86 | fraca demais, não se vê |
| a2 | `alphaK` 3,0; árvore com `lenK` 0,70 (sol mais alto, a copa cai do lado do tronco) | ×0,58 no pé, mediana ×0,79 | árvores OK, mas o inimigo da viagem ganhou um borrão escuro na estrada (`rec_viagem_sombra_estrada_crista.png`, coluna do meio): "escrachado" |
| a3 | + disco de sombra de copa sob cada árvore (`shadow.canopy`: largura 0,42 da árvore, achatado 0,30, deslocado 0,25 para longe do sol, alpha 0,55), em união com a silhueta (nada escurece em dobro) | | a mancha da copa aparece ao lado do tronco nas faixas de grama perto da estrada |
| f2 (aceita) | `alphaK` global 2,2 (um degrau acima do atual, vale para inimigo e marcos); árvores ×1,45 por cima (`shadow.tree.alphaK`, aplicado pela fila: o motor passa a honrar o `alphaK` por entrada) | árvore ×0,55 no pé; inimigo ×0,68 | inimigo e poste "um pouco mais evidentes", árvores evidentes |

## Checklist (f2, recortes 3x)

| pergunta | resposta |
|---|---|
| melhor que o antes? | sim: a sombra tem forma (haste do poste, copa), sem o borrão de 3 cópias |
| natural? | sim; a sombra do inimigo voltou a um degrau acima do atual |
| algo do fundo pinta a frente? | não (máscara de profundidade; trava `test_world_shadows` 195/195) |
| saturação da copa caiu? | não (as árvores não mudam de cor neste experimento) |
| proporção plausível? | sombra de árvore = 0,7 da altura ao meio-dia do jogo |

## Limite honesto

Nas paredes de árvore a sombra de uma cai na copa da vizinha e some; só se lê nas faixas abertas de grama (perto da estrada) e na estrada. Em grama escura o degrau máximo que não vira mancha é ×0,55.
