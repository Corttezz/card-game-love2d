# Fechamento do ato 1: checklist por recorte

O ANTES é sempre `00_antes`.

**Como ler os recortes.** Os recortes com `_3col` (ampliados 2x a 3x) têm três colunas lado a lado:
1. `00_antes`;
2. `08_ajuste` (a rodada que o lead reprovou);
3. `09_final`.

Neles a linha de cima é o dia e a de baixo é o pôr do sol. Os demais recortes no padrão antes|depois estão em `recortes/`. As folhas inteiras ficam em `folha_*.png`, e `medidas.txt` é só complemento.

## 1. Sombras projetadas com forma, nítidas, sem borrão

**O que mudou no motor.**
- Uma cópia só da silhueta, em vez de três deslocadas; era isso que borrava.
- Resolução da sombra de 1/3 para 1/2: a haste fina do poste agora aparece.
- Esmaecimento em 3 degraus de tom, sem gradiente contínuo.
- Composição por multiplicação com a cor de sombra do bioma (`shadow.color = 0.34 / 0.38 / 0.42`). Ela escurece o que está embaixo e não pinta roxo nem cinza por cima.
- Sem franja de dither.

**Trava nova em `test_world_shadows`:** o esmaecimento tem que caber em no máximo 4 tons. Com 64 degraus no lugar de 3, ela falha (24 tons).

| recorte | forma reconhecível? | nítida? | mais forte no pé, em degraus? | cor |
|---|---|---|---|---|
| poste_castelo_sombra_3col | haste e braço projetados | sim | sim | verde escurecido, sem roxo (OK) |
| bandeira_sombra_3col | haste e pano | sim | sim | marrom escurecido (OK) |
| poste_viagem_base_sombra | sim | sim | sim | a mancha roxa da 08 sumiu (OK) |
| arvore_sombra_landmark_3col | sombra de árvore na grama | sem borrão | sim | (OK) |
| fogueira_base / loja | contato e projetada colados na base | sim | sim | (OK) |

A ordem de profundidade continua garantida pela máscara: a trava árvore atrás e poste na frente dá 0 pixels escurecidos.

## 2. Árvores do lado direito do fork

**O que mudou.** O tom verde das árvores perto ficou bem mais leve (`treeNear 0.95 / 1.0 / 0.93`) e o ganho subiu para 0,8.

| recorte | momento | saturação (antes → agora) | brilho (antes → agora) | resultado |
|---|---|---|---|---|
| arvores_fork_dir_3col | dia | 130 → 136 | 62 → 61 | (OK) |
| arvores_fork_dir_3col | meio | 126 → 130 | 48 → 44 | (OK) |
| arvores_fork_dir_3col | pôr do sol | 116 → 117 | 41 → 33 | (OK) |
| arvores_esquerda | — | contraste 34, igual ao antes | — | (OK) |

## Custo

| medida | valor |
|---|---|
| draw calls | 389 |
| KB por quadro | 31,5 |
| 1080p, `perf_probe` | 4,1 ms |
| test_all | 135/135 |
