# Ato 6 (dusk, Campos do Crepúsculo): checklist

Capturas: `antes/` e `depois/` (grade de 12 em 1024x768 + batalha 1080p em tod 0,65 e 0,95).
Recortes antes|depois em `recortes/` (lado esquerdo = antes, direito = depois).

## Lista fixa do plano (Tarefa 11)

| # | Item | Antes | Depois | Evidência |
|---|------|-------|--------|-----------|
| 1 | Temperatura âmbar → púrpura, sem esverdear o chão | não: `grade.dusk` 0,78/0,56/0,70 escurecia o sprite 30 a 45 % (lição do ato 1: temperatura é só matiz); copas perto quase pretas (5,1,13 medido) | sim: dia 1/0,95/0,90, pôr 1/0,92/0,98 | `arvores_dir_tod0.65.png`, `arvores_esq_tod0.65.png` |
| 2 | Horizonte alaranjado pela névoa, sem degrau | parcial: névoa 0,72/0,48/0,22 (amarelo, não a cor da base das montanhas) | sim: névoa medida na base das montanhas (0,50/0,26/0,24, pôr 0,44/0,22/0,30), `fogCurve` 2,4 | `castelo_crista_tod0.65.png`, `fork_por.png` |
| 3 | Faixa de contato púrpura escura, coerente com a sombra longa | parcial: contato 0,55, sombra `alphaK` 1,0, sem sombra de árvore | sim: contato 0,65, `shadow` igual ao ato 1 (alphaK 2,2, tree 1,45, disco de copa) com cor de multiplicação púrpura 0,40/0,30/0,42 | `arvores_dir_tod0.65.png` (sombra do choupo no chão), `poste_meio_tod0.95.png` |
| 4 | Tufos médios (`baseCover` 0,10) | sim | sim (inalterado) | `fogueira_por.png` |
| 5 | Névoa baixa dourada e leve (≤ 0,22) | sim (0,20) | sim (0,18) | `castelo_por.png` |
| 6 | Vento mais vivo dos seis (0,034 a 0,040) | sim (0,036) | sim (0,036) | dado |
| 7 | Névoa de intenção do ato 6 manda na `viagem` | sim | sim (nada mexido no `fogHook`) | `depois/b6_*_viagem.png` |

## As 9 lições do dono

| # | Lição | Depois | Evidência |
|---|-------|--------|-----------|
| 1 | Sombra natural, nascendo da base, sem sombra de trás pintando a frente | sim: sombra de árvore e de poste aparece agora (antes não existia), 3 degraus, cai para a câmera (sol atrás do castelo) | `arvores_dir_tod0.65.png`, `poste_meio_tod0.95.png` |
| 2 | Árvore nunca mais clara/enevoada que o chão ao lado | sim: `treeDepth` do ato 1 (véu = curva do chão, sem filtro branco); copa do meio fica escura contra o sol, perto mais saturada | `arvores_esq_tod0.65.png` |
| 3 | Escala pelo inimigo | sim: poste ~0,9x o inimigo na profundidade dele (tamanho 6,1: mesma altura do poste do ato 1 em cada profundidade, 601 px contra 605 em t 0,85); árvore adulta acima do poste; fogueira menor que 0,6x | `objetos.md` |
| 4 | Árvores variadas, sem repetir vizinha | sim: 3 → 7 variantes (choupo estreito, carmim de outono, meio pelada, chorona), `variants.dusk_tree = 7` liga o `makeWall` sem repetir | `recortes/candidatas_arvores.png`, `depois/b6_*_viagem.png` |
| 5 | Lado iluminado para o sol | sim: arte nova pedida com contraluz (só aro quente no topo, lados iguais), por isso sem `lit` e espelho livre | `candidatas_arvores.png` |
| 6 | Luminária apagada de dia, acesa no entardecer | sim: motor comum (`dayK`); o ato 6 vive em tod alto, então acende; a chama pintada fica, como no ato 1 | `poste_meio_tod0.65/0.95.png` |
| 7 | Chão mais escuro e frio no horizonte | sim: `groundFar` 0,62 / `groundReach` 0,85 (ato 1) | `depois/b6_dia_fork.png` |
| 8 | Colagem | corrigido no poste: a arte antiga tinha uma faixa laranja pintada no lado da madeira e uma mão-francesa quadriculada que, ampliada 7x, virava ruído; arte nova (PixelLab `create_image_pro`, referência = poste antigo) com madeira uniforme | `poste_perto_tod0.65.png`, `fogueira_por.png` |
| 9 | Métrica não prova visual | recortes abertos e olhados um a um (lista acima) | `recortes/` |

## Diorama (adendo do dono, 18/Out)

As 7 árvores do bioma foram julgadas a 4x contra `memory/art_direction_diorama.md`: as antigas (0 a 2) e
as primeiras novas (3 a 6) liam como massa roxa de valor único, sem planos e com luz de cima. Todas as 7
foram regeradas (PixelLab `create_image_pro`, referência `dusk_tree_0`, 28 imagens) com copa em três
planos, oclusão do tronco pela folhagem, tronco com face de luz e o sol do bioma à ESQUERDA
(`celestial.xr` 0,30): `world_props.lit = -1` em todas, então `flipToSun` vira o lado claro para o sol.
Escolhidas: `duskd_a__1, b__3, c__3, d__0, e__1, f__1, g__1` (folha `diorama/arvores_antes_depois_4x.png`,
candidatas em `diorama/candidatas_2x.png`). Poste e marcos não foram regerados nesta passada.
