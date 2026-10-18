# Ato 2, highlands: objetos

Escala = altura / altura do inimigo na mesma profundidade (inimigo 279 px em t 0,385, 1080p,
`persp(t) = 0,14 + 0,86·t^1,65`).

| objeto | escala | contato | oclusão | sombra | cor | veredito | arte |
|---|---|---|---|---|---|---|---|
| braseiro (pilar de beira de estrada) | 0,87x (t 0,81: 573 px; t 0,14: 133 px); era 0,30x | faixa de contato na base escalonada | tufos na base | projetada pela lua, máscara de profundidade | pedra cinza-azulada; chama azul espectral; poça azul no chão a partir do entardecer | ok | REGERADA (PixelLab `create_image_pro`, ref. braseiro antigo, candidata 3 de 4) + 9 quadros de chama por `tools/bake_luminaire_flicker.py`; `size` 2,70 → 5,30, `radiusK` 1,60 → 0,95, `pool` novo |
| pinheiro (6 variantes) | 0,95 a 1,1x no meio, acima do braseiro | `sink` medido (9/11/7 nas novas) | tufos | 3 degraus + disco de copa | `treeNear`/`treeDepth` do ato 1 | ok | 3 NOVAS (torre fina, topo quebrado, baixo e largo); antigas mantidas |
| árvore morta | 1 variante (cai na _0) | sim | sim | sim | idem | ok, poucas na cena | mantida |
| pedra rúnica | 0,23x (t 0,49: 63 px) | sim | sim | sim | azul saturado com runas acesas | aceitável (objeto mágico que brilha); o único azul puro da cena | mantida |
| fogueira (marco de descanso) | inalterada (mesma régua do ato 1) | terra queimada | tufos nos flancos | sim | chama era salmão pastel; agora laranja/amarelo vivo | ok | RECOLORIDA (mesma arte, base + 9 quadros) |
| castelo | 2,2x a maior árvore da crista vizinha | disco no topo da colina | n/a | sem sombra (regra do ato 1) | grade do bioma | ok | mantida |
| bandeira, loja, evento, elite | inalterados | sim | sim | sim | grade do bioma | ok | mantidas |
