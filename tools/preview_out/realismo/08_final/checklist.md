# Fechamento da rodada de realismo do ato 1 (18/Out/2026)

Folhas `folha_*.png`: antes (`00_antes`) | atual (`9a418a04`) | final (todos os experimentos aceitos); recortes 3x em `rec_*.png`.

## Aceito (um commit cada)

| experimento | o que mudou | prova |
|---|---|---|
| (a) sombra de copa + sombras mais evidentes | fila honra `alphaK` por entrada; global 2,2, árvore ×1,45 e `lenK` 0,70; disco de copa | `02_sombra_copa` |
| (e) chão em degradê | `groundFar` 0,62, `groundReach` 0,85, `contrastFarDay` 0,85 | `03_chao` |
| (b) árvores por plano | `treeDepth` na família `tree` | `04_arvores_profundidade` |
| (c) lado iluminado para o sol | `world_props.lit` + `PropCut.flipToSun` | `05_lado_sol` |
| (f) fogueira e lanternas emitem luz | poça 0,95/0,85, `selfLight` ×2; lanterna 1,50/0,95 | `06_fogueira_luz` |
| (h) proporção do poste | lanterna `size` 3,2 | `07_poste_proporcao` |

## Rejeitado

| tentativa | motivo |
|---|---|
| `shadow.alphaK` 3,0 global | borrão escuro sob o inimigo da viagem (`06_fogueira_luz/rec_viagem_sombra_estrada_crista.png`) |
| `treeDepth.sat` 0,55 a partir de t 0,6 | acinzentava as árvores do MEIO (mesmo defeito do shader de volume) |
| troca dos 3 sprites por candidatas do PixelLab | mata do meio virou massa escura uniforme (`09_arvores_candidatas`); candidatas guardadas |

## Não feito (fica para o dono decidir)

- Oclusão na raiz / base mais forte (d): a faixa de contato já cobre; raiz de verdade só com sprite novo.
- Sprite suavizado para a crista (b, parte 2): a cor já separa os planos.
- Grama (g): sem melhoria encontrada que não fosse escurecer sob as copas, o que já acontece pela sombra.

## Medidas

| | atual | final |
|---|---|---|
| draw calls (1024×768) | 389 | 389 |
| KB por quadro | 31,5 | 31,1 |
| 1080p `perf_probe` mediana | 4,1 ms | 4,4 ms |
| locais do WorldRoad | 188 | 188 |
| test_all | 135/135 | 135/135 |
