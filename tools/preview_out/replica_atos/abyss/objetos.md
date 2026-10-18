# Ato 3, abyss: objetos

Escala = altura / altura do inimigo na mesma profundidade (inimigo 279 px em t 0,385, 1080p).

| objeto | escala | contato | oclusão | sombra | cor | veredito | arte |
|---|---|---|---|---|---|---|---|
| tocha de beira de estrada | 0,87x (t 0,81: 573 px), 0,84x (t 0,17) ; era 0,29x | pé de pedra com faixa de contato | tufos | projetada | ferro preto, chama laranja; poça laranja ao entardecer | ok | REGERADA (poste de ferro com gaiola, pé de pedra) + 9 quadros de chama; `size` 2,5 → 5,3, `pool` |
| pilar-braseiro | ~0,8x (era 0,34x) | base larga com contato | tufos | projetada | pedra vulcânica com fendas de brasa | ok, afastado da estrada | REGERADO + 9 quadros; `size` 2,8 → 5,0, `lane` 0,10 a 0,20, `pool` |
| fissura | chão (0,5) | é o próprio chão | n/a | n/a | lava laranja em terra preta | ok | REGERADA (era pedra azul fora da paleta); brilho pulsante |
| árvore morta (6 variantes) | 0,7 a 1,1x no meio | `sink` 8 a 10 | tufos | 3 degraus, galhos no chão | véu do ato 1 | ok | 6 NOVAS (direção diorama, luz à direita) |
| arbusto de espinhos (3) | baixo | sim | sim | sim | carvão com pontas de brasa | ok | 3 NOVOS |
| pedra | inalterada | sim | sim | sim | pintada com luz à esquerda → `lit = -1` | ok | mantida |
| fogueira | inalterada | terra queimada 0,62 | flancos | sim | chama viva | ok | mantida |
| castelo | 2,2x a árvore vizinha da crista | disco | n/a | sem sombra | | ok; atrás do HUD do inimigo na batalha (igual ao ato 1) | mantida |
