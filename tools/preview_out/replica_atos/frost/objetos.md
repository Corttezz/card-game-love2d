# Geleira Espectral (frost): objetos

Inimigo de referência: `frost_wight`, 279 px em t = 0,385 (1080p, tod 0,65). "× inimigo" = altura / (279 ×
persp(t) / persp(0,385)), com persp(t) = 0,14 + 0,86·t^1,65.

| objeto | escala × inimigo | contato | oclusão | sombra | cor | veredito | arte |
|---|---|---|---|---|---|---|---|
| poste de luz (`lantern`, size 1,8 → 5,6, `face` 1) | t 0,20: 155 px = 0,88; t 0,56: 361 = 0,88; t 0,87: 623 = 0,86 (antes 0,24) | faixa azul curta na base + monte de neve pintado | tufos raros | nasce no pé, cai para baixo-esquerda, ~0,72 | ferro azul-escuro, neve, chama quente | bom | **nova** (PixelLab `create_image_pro`, 9 candidatas, escolhida a 5ª; 9 quadros de chama tremulando gerados por script a partir dela); poça de luz no chão (`light.pool`) |
| braseiro (`brazier`, 2,7) | ~0,35 (fogo de chão) | sim | sim | sim | quente, ok | bom, intocado | não |
| cristal (`crystal`, 1,1) | pequeno, decorativo | sim | sim | sim | ciano, ok | bom, intocado | não |
| pinheiros `frost_pine_0..2` | meio 0,60 a 1,03; perto > poste | `sink` medido | sim | silhueta + disco de copa 0,45 | grade frio, névoa pela curva do chão | bom | não |
| pinheiros novos `frost_pine_3..5` | mesma espécie (6,7; o jovem com `sizeK` 0,80) | `sink` 3 a 4 | sim | idem | mesma paleta | bom; mais volume que os originais | **novos** (PixelLab `create_image_pro`, 3 jobs × 4 candidatas, prompt diorama, ref. `frost_pine_0/2`) |
| árvore morta `frost_deadtree_0` | crista ~76 px | sim | sim | sim | ok | bom | não |
| pedra `frost_rock_0` | 96 px em t 0,72 | sim | sim | sim | ok | bom | não |
| fogueira (`landmark_rest`) | intocada (3,6) | terra queimada 1,2 | sim | sim | `selfLight` 0,20 | bom; brilho no chão claro é sutil | não |
| loja, bandeira, evento, elite | intocados | sim | sim | sim | ok | bom | não |
| castelo | 299 px = 2,8× a maior árvore da crista (107) | disco no topo da colina | névoa baixa | sem projetada (regra do ato 1) | ok | bom | não |
| chão (`biomes.lua` frost) | | | | | 46/54/75 → ~80/97/134 (neve batida) | corrigido | dado |
