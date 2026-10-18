# Pântano da Podridão (marsh): objetos

Inimigo de referência: `bog_ghoul`, 279 px em t = 0,385 (1080p, tod 0,65). "× inimigo" = altura / (279 ×
persp(t) / persp(0,385)), persp(t) = 0,14 + 0,86·t^1,65.

| objeto | escala × inimigo | contato | oclusão | sombra | cor | veredito | arte |
|---|---|---|---|---|---|---|---|
| poste de lanterna (`lantern`, 5,6) | t 0,09: 117 px = 0,85; t 0,53: 334 = 0,86 | saia de musgo pintada + faixa | tufos densos | nasce no pé, verde-musgo | madeira e trepadeira, vidro verde | bom | não |
| totem (3,4) | ~0,43 (marco baixo) | sim | sim | sim | ok | bom | não |
| cogumelo (0,8) | decorativo | sim | sim | sim | brilho verde | bom | não |
| árvores mortas `marsh_deadtree_0..2` | meio 0,66 a 0,97; perto > poste | `sink` medido | sim | silhueta + disco 0,50 | grade verde | bom | não |
| árvores novas `marsh_deadtree_3..7` | mesmas da espécie (5,9) | `sink` 8 a 10 | sim | idem | mesma paleta | bom; o tronco partido (5) perto lê claro | **novas** (PixelLab `create_image_pro`, 4 jobs × 4 candidatas, ref. `marsh_deadtree_0/1`) |
| arbusto, flores | intocados | sim | sim | sim | ok | bom | não |
| fogueira | intocada | terra queimada 1,3 | sim | sim | `selfLight` 0,12 | bom | não |
| cabana da loja, bandeira, evento, elite | intocados | sim | sim | sim | ok | bom | não |
| castelo | 247 px = 2,1× a maior árvore da crista | disco no topo | névoa baixa | sem projetada | ok | bom | não |
