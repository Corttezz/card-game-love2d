# Julgamento das sombras por sprite (frente sombras-item)

Bancada: `lovec . test_one bancada_sombras <rotulo>[:bioma]`, folhas em `tools/preview_out/sombras_item/<bioma>.png` (depois) e `antes/`, `depois/`. Colunas: perto 0,65 | perto 0,95 | meio 0,65 | meio 0,95 | base 3x perto 0,65 | base 3x perto 0,95.
Trava: `lovec . test_one test_sombras_item` (vão entre o pixel mais baixo da arte e o início da sombra ≤ 1 px; pegada da frente do lado oposto ao sol coberta ≥ 55% para base sólida).
Vão em px de tela (negativo = a sombra começa acima do pé, por trás da base). Cobertura = fração da metade frontal da pegada (lado oposto ao sol) coberta pela sombra.

## fields (reprovados: antes 4, depois 0 de 20)

| sprite | antes vão / cobertura | depois vão / cobertura | veredito | nota |
|---|---|---|---|---|
| fields_bush_0 | -11,-11 / - | -17,-17 / - | OK |  |
| fields_flowers_0 | -9,-9 / - | -9,-9 / - | OK |  |
| fields_lantern_0 | 1,1 / - | -1,-1 / - | OK | poste fino sem base: pivô no pé, igual a antes; a lanterna pendurada projeta só no fim da sombra do poste (sem sombra embaixo dela) |
| fields_rock_0 | -9,-9 / 100%,100% | -11,-11 / 95%,99% | OK |  |
| fields_shrine_0 | -1,-1 / 13%,13% | -9,-9 / 92%,92% | corrigido | base de flores mais larga que o poste: pegada do monte, sombra encosta na base |
| fields_stump_0 | -9,-9 / 68%,69% | -13,-13 / 84%,88% | OK |  |
| fields_tree_0 | -19,-21 / - | -21,-21 / - | OK |  |
| fields_tree_1 | -15,-17 / - | -45,-45 / - | OK |  |
| fields_tree_2 | -17,-21 / - | -23,-23 / - | OK |  |
| fields_tree_3 | -17,-21 / - | -19,-19 / - | OK |  |
| fields_tree_4 | -13,-15 / - | -13,-15 / - | OK |  |
| fields_tree_5 | -17,-19 / - | -31,-31 / - | OK |  |
| fields_tuft_0 | -3,-3 / - | -7,-7 / - | OK |  |
| landmark_battle | -1,-1 / 6%,6% | -15,-15 / 76%,80% | corrigido |  |
| landmark_chest | -23,-23 / 66%,75% | -19,-19 / 70%,81% | OK | pé do baú fica no lado do sol sem sombra, fisicamente certo; métrica mede só o lado oposto ao sol |
| landmark_elite | -11,-11 / 11%,11% | -39,-39 / 91%,90% | corrigido |  |
| landmark_event | -15,-15 / 100%,100% | -11,-11 / 100%,100% | OK |  |
| landmark_miniboss | -1,-1 / 4%,4% | -17,-17 / 79%,76% | corrigido |  |
| landmark_rest | -19,-19 / 74%,74% | -27,-27 / 100%,100% | OK |  |
| landmark_shop | -17,-17 / 57%,60% | -19,-19 / 100%,100% | OK |  |

## highlands (reprovados: antes 5, depois 0 de 22)

| sprite | antes vão / cobertura | depois vão / cobertura | veredito | nota |
|---|---|---|---|---|
| highlands_brazier_0 | -1,-1 / 1%,1% | -23,-23 / 100%,100% | corrigido | base quadrada na diagonal: antes a sombra era o losango espelhado pendurado abaixo da ponta da frente, com vão de chão; agora nasce no centro do losango e sai pelas arestas da frente |
| highlands_bush_0 | -11,-11 / - | -11,-11 / - | OK |  |
| highlands_bush_1 | -11,-11 / - | -11,-11 / - | OK |  |
| highlands_bush_2 | -11,-11 / - | -11,-11 / - | OK |  |
| highlands_deadtree_0 | -9,-9 / - | -23,-23 / - | OK |  |
| highlands_landmark_battle | -1,-1 / - | -7,-7 / - | OK |  |
| highlands_landmark_elite | -11,-11 / 31%,31% | -11,-11 / 100%,100% | corrigido |  |
| highlands_landmark_event | -11,-11 / 100%,100% | -7,-7 / 100%,100% | OK |  |
| highlands_landmark_rest | -21,-21 / - | -19,-19 / - | OK |  |
| highlands_landmark_shop | -23,-25 / 100%,100% | -15,-15 / 100%,100% | OK |  |
| highlands_litter_0 | -1,-1 / - | -3,-3 / - | OK |  |
| highlands_litter_1 | -1,-1 / 0%,0% | -5,-5 / 81%,85% | corrigido |  |
| highlands_pine_0 | -11,-13 / - | -23,-23 / - | OK |  |
| highlands_pine_1 | -11,-11 / - | -11,-13 / - | OK |  |
| highlands_pine_2 | -11,-11 / - | -19,-19 / - | OK |  |
| highlands_pine_3 | -11,-11 / - | -11,-13 / - | OK |  |
| highlands_pine_4 | -11,-11 / - | -11,-11 / - | OK |  |
| highlands_pine_5 | -11,-13 / - | -23,-23 / - | OK |  |
| highlands_rock_0 | -9,-9 / - | -9,-9 / - | OK |  |
| highlands_ruin_0 | -1,-1 / 0%,0% | -23,-23 / 99%,100% | corrigido |  |
| highlands_runestone_0 | -1,1 / - | -1,-1 / - | OK |  |
| highlands_sign_0 | 1,1 / 0%,0% | -9,-9 / 93%,98% | corrigido |  |

## abyss (reprovados: antes 4, depois 0 de 19)

| sprite | antes vão / cobertura | depois vão / cobertura | veredito | nota |
|---|---|---|---|---|
| abyss_brazier_0 | -1,-1 / 1%,1% | -27,-27 / 100%,100% | corrigido | base redonda: antes uma faixa de chão entre o disco e a mancha; agora nasce no centro da elipse |
| abyss_bush_0 | -11,-11 / - | -11,-11 / - | OK |  |
| abyss_bush_1 | -11,-11 / - | -11,-11 / - | OK |  |
| abyss_bush_2 | -11,-11 / - | -11,-11 / - | OK |  |
| abyss_deadtree_0 | -9,-11 / - | -27,-27 / - | OK |  |
| abyss_deadtree_1 | -9,-11 / - | -27,-27 / - | OK |  |
| abyss_deadtree_2 | -9,-11 / - | -33,-33 / - | OK |  |
| abyss_deadtree_3 | -9,-11 / - | -11,-11 / - | OK |  |
| abyss_deadtree_4 | -11,-13 / - | -39,-39 / - | OK |  |
| abyss_deadtree_5 | -9,-11 / - | -27,-27 / - | OK |  |
| abyss_fissure_0 | 1,1 / - | 1,1 / - | OK | plana (riseK 0): sem sombra projetada, por desenho |
| abyss_landmark_battle | -1,-1 / - | -17,-17 / - | OK |  |
| abyss_landmark_elite | -11,-11 / 7%,7% | -53,-53 / 95%,98% | corrigido |  |
| abyss_landmark_event | -5,-5 / - | -7,-7 / - | OK |  |
| abyss_landmark_rest | -37,-37 / 51%,60% | -29,-29 / 100%,100% | OK |  |
| abyss_landmark_shop | -59,-63 / 100%,97% | -35,-35 / 100%,100% | OK |  |
| abyss_rock_0 | -9,-9 / 100%,100% | -9,-9 / 99%,100% | OK |  |
| abyss_ruin_0 | -1,-1 / 1%,1% | -23,-23 / 100%,100% | corrigido |  |
| abyss_torch_0 | -1,-1 / 4%,4% | -13,-13 / 100%,100% | corrigido | pé de pedra largo: pegada do monte |

## frost (reprovados: antes 4, depois 0 de 19)

| sprite | antes vão / cobertura | depois vão / cobertura | veredito | nota |
|---|---|---|---|---|
| frost_brazier_0 | 2,2 / 0%,0% | -10,-10 / 100%,100% | corrigido | aro de neve mais largo que as pedras enganava a medida (pivô no aro); pegada declarada em world_props.footRows = 4 |
| frost_crystal_0 | -6,-6 / - | -6,-6 / - | OK |  |
| frost_deadtree_0 | -9,-11 / - | -13,-13 / - | OK |  |
| frost_drift_0 | -1,-1 / - | -3,-3 / - | OK |  |
| frost_drift_1 | -1,-1 / - | -3,-3 / - | OK |  |
| frost_drift_2 | -1,-1 / - | -3,-3 / - | OK |  |
| frost_landmark_battle | -1,-1 / 3%,3% | -21,-21 / 77%,84% | corrigido |  |
| frost_landmark_elite | -5,-5 / 0%,0% | -43,-43 / 99%,100% | corrigido |  |
| frost_landmark_event | -17,-17 / - | -11,-11 / - | OK |  |
| frost_landmark_rest | -20,-20 / 65%,65% | -30,-30 / 100%,100% | OK |  |
| frost_landmark_shop | -35,-37 / 100%,100% | -21,-21 / 100%,100% | OK |  |
| frost_lantern_0 | 1,1 / 0%,0% | -17,-17 / 53%,56% | corrigido | base redonda de monte de neve (mais larga embaixo): o primeiro passe media só o pé e passava errado; agora a pegada do monte vem da largura (elipse com fundo = metade da largura) e a sombra nasce no centro do monte, saindo pela borda oposta ao sol |
| frost_pine_0 | -7,-7 / - | -7,-9 / - | OK |  |
| frost_pine_1 | -5,-7 / - | -53,-53 / - | OK |  |
| frost_pine_2 | -7,-7 / - | -7,-9 / - | OK |  |
| frost_pine_3 | -5,-7 / - | -23,-23 / - | OK |  |
| frost_pine_4 | -5,-5 / - | -7,-7 / - | OK |  |
| frost_pine_5 | -5,-5 / - | -5,-5 / - | OK |  |
| frost_rock_0 | -9,-9 / 96%,100% | -9,-9 / 93%,96% | OK |  |

## marsh (reprovados: antes 5, depois 0 de 25)

| sprite | antes vão / cobertura | depois vão / cobertura | veredito | nota |
|---|---|---|---|---|
| marsh_bush_0 | -11,-11 / - | -11,-11 / - | OK |  |
| marsh_deadtree_0 | -11,-11 / - | -33,-33 / - | OK |  |
| marsh_deadtree_1 | -13,-15 / - | -31,-31 / - | OK |  |
| marsh_deadtree_2 | -11,-13 / - | -29,-29 / - | OK |  |
| marsh_deadtree_3 | -11,-13 / - | -35,-35 / - | OK |  |
| marsh_deadtree_4 | -15,-17 / - | -29,-29 / - | OK |  |
| marsh_deadtree_5 | -13,-17 / - | -37,-37 / - | OK |  |
| marsh_deadtree_6 | -11,-13 / - | -33,-33 / - | OK |  |
| marsh_deadtree_7 | -13,-13 / - | -37,-37 / - | OK |  |
| marsh_flowers_0 | -9,-9 / - | -9,-9 / - | OK |  |
| marsh_landmark_battle | -1,-1 / 5%,5% | -15,-15 / 80%,78% | corrigido |  |
| marsh_landmark_elite | 0,0 / 0%,0% | -12,-12 / 100%,100% | corrigido |  |
| marsh_landmark_event | -25,-27 / 97%,97% | -17,-17 / 100%,100% | OK |  |
| marsh_landmark_rest | -22,-22 / 90%,90% | -26,-26 / 100%,100% | OK |  |
| marsh_landmark_shop | -17,-17 / - | -13,-13 / - | OK | palafita: o deck mais largo enganava a medida; pegada declarada nos pés das estacas (footRows = 4) |
| marsh_lantern_0 | 1,1 / 0%,0% | -35,-35 / 77%,83% | corrigido | cipó com monte de raízes: pegada do monte |
| marsh_mushroom_0 | -4,-4 / 49%,59% | -6,-6 / 69%,68% | corrigido |  |
| marsh_rock_0 | -9,-9 / 88%,88% | -11,-11 / 97%,100% | OK |  |
| marsh_rock_1 | -9,-9 / 99%,100% | -9,-9 / 100%,100% | OK |  |
| marsh_rock_2 | -9,-9 / 78%,78% | -13,-13 / 95%,96% | OK |  |
| marsh_rock_3 | -9,-9 / 100%,100% | -9,-9 / 100%,100% | OK |  |
| marsh_roots_0 | -1,-1 / - | -1,-1 / - | OK |  |
| marsh_roots_1 | -1,-1 / - | -1,-1 / - | OK |  |
| marsh_roots_2 | -1,-1 / - | -1,-1 / - | OK |  |
| marsh_totem_0 | -1,1 / 3%,0% | -19,-19 / 99%,99% | corrigido | pé largo: pegada do monte |

## dusk (reprovados: antes 6, depois 0 de 16)

| sprite | antes vão / cobertura | depois vão / cobertura | veredito | nota |
|---|---|---|---|---|
| dusk_bush_0 | -11,-11 / - | -11,-11 / - | OK |  |
| dusk_landmark_battle | -1,-1 / - | -23,-23 / - | OK |  |
| dusk_landmark_elite | 0,0 / 0%,0% | -40,-40 / 100%,100% | corrigido |  |
| dusk_landmark_event | -17,-17 / 80%,79% | -13,-13 / 100%,100% | OK |  |
| dusk_landmark_rest | -22,-22 / 44%,44% | -42,-42 / 73%,83% | corrigido |  |
| dusk_landmark_shop | -11,-11 / 33%,33% | -15,-15 / 100%,100% | corrigido |  |
| dusk_lantern_0 | 2,2 / - | 0,0 / - | corrigido | vão de 2 px vinha do arredondamento meia resolução; origem agora alinhada à grade do canvas de sombra |
| dusk_shrine_0 | 1,1 / 0%,0% | -19,-19 / 100%,100% | corrigido |  |
| dusk_sign_0 | 1,1 / 0%,0% | -9,-9 / 87%,94% | corrigido |  |
| dusk_tree_0 | -13,-15 / - | -37,-37 / - | OK |  |
| dusk_tree_1 | -15,-17 / - | -21,-21 / - | OK |  |
| dusk_tree_2 | -13,-15 / - | -27,-27 / - | OK |  |
| dusk_tree_3 | -7,-7 / - | -7,-7 / - | OK |  |
| dusk_tree_4 | -15,-17 / - | -11,-11 / - | OK |  |
| dusk_tree_5 | -11,-13 / - | -51,-51 / - | OK |  |
| dusk_tree_6 | -13,-15 / - | -27,-27 / - | OK |  |

## Sem sombra projetada (por desenho)

- Castelos: ficam na crista, sem sombra projetada pelo motor (não entram na bancada).
- Detalhe de chão não sólido do `ground_clutter` (grama alta, flores do dusk, folhas, brasas, juncos): planos, sem sombra; os sólidos (galhos caídos, montes de neve, raízes, pedras, cogumelo) estão na tabela.
- Inimigo de cada ato: sombra pela silhueta com `shadowBaseK` da pose (fora desta mudança); conferido no quadro de batalha 1080p em `batalha/antes|depois`.
