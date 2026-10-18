# Experimento (c): lado iluminado da copa virado para o sol

Folhas: `folha_*.png` (atual | b2 | c); recortes `rec_viagem_arvores_esq.png`, `rec_fork_arvores_dir_fundo.png`.

Diagnóstico (`01_diag/arvores_4x.png`, medido): `fields_tree_0` é pintada iluminada da direita (+21 %), `fields_tree_2` da esquerda (−20 %), `fields_tree_1` sem lado; o espelho era sorteado, então metade das árvores ficava com a luz contra o sol (`celestial.xr = 0,79`, alto à direita).

Mecanismo: `src/data/world_props.lua` ganha `lit = { sprite = +1 (direita) | -1 (esquerda) }`; `PropCut.flipToSun` escolhe o espelho para que o lado pintado fique virado para o sol; sprite sem `lit` continua com o espelho sorteado (`test_prop_variation` intacto).

| pergunta | resposta |
|---|---|
| melhor que o antes? | sim, luz consistente na cena inteira (regra número um das referências) |
| natural? | sim; a variedade continua pelos 3 sprites, escala e tom |
| algo do fundo pinta a frente? | não |
| saturação caiu? | não |
| proporção | n/a |

Limite honesto: a diferença entre os lados nos sprites atuais é pequena (~20 % de luminância), então o efeito é sutil. Os candidatos novos do PixelLab (`tools/pixellab_trees.py queue fields_sun_*`) pedem lado iluminado mais marcado.
