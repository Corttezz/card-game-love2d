# Ato 6 (dusk): objetos

Régua: inimigo comum em 1080p = 279 px em t = 0,385 (`escala_humana r6v3:b6`).

| Objeto | Escala para o inimigo | Contato | Oclusão | Sombra | Cor | Veredito | Arte |
|--------|----------------------|---------|---------|--------|-----|----------|------|
| Poste com lanterna (`dusk_lantern_0`) | ~0,85x na profundidade do inimigo, igual ao ato 1 (tamanho 6,1: 601 px em t 0,85 contra 605 do poste dos campos) | faixa de contato na base | tufos do motor comum | projetada para a câmera, 3 degraus | madeira uniforme, vidro âmbar | ok | REGERADA (PixelLab `create_image_pro`, 9 candidatas, escolhida `lamp__0`); 9 quadros de cintilação refeitos só no vidro |
| Árvore redonda (`dusk_tree_0`) | 0,9 a 1,3x | contato + disco de copa (perto) | tufos | sim | púrpura, grade do ato 1 | ok | mantida |
| Árvore em patamares (`dusk_tree_1`) | idem | idem | idem | sim | idem | ok | mantida |
| Árvore larga (`dusk_tree_2`) | idem (sizeK 0,9) | idem | idem | sim | idem | ok | mantida |
| Choupo (`dusk_tree_3`) | alta e estreita | idem | idem | sim (sombra fina longa) | ameixa escura | ok | NOVA |
| Carmim de outono (`dusk_tree_4`) | como a redonda | idem | idem | sim | vinho/carmim: quebra o roxo uniforme | ok | NOVA |
| Meio pelada (`dusk_tree_5`) | como a redonda | idem | idem | sim | galhos escuros, tufos roxos | ok | NOVA |
| Chorona (`dusk_tree_6`) | como a redonda | idem | idem | sim | roxa | ok | NOVA |
| Fogueira (`dusk_landmark_rest`) | < 0,6x | terra queimada (scorch 1,7 / 0,55, do ato 1) | tufos | brasa + luz própria (selfLight 0,12 ×2) | | ok | mantida |
| Castelo (`dusk_castle`) | 270 px vs 147 px da maior árvore vizinha da crista = 1,8x (abaixo dos 2x do brief) | disco no topo da colina | névoa baixa | sem projetada (regra do ato 1) | | aceitável; a árvore da crista ao lado é a carmim/redonda grande. Não mexi no tamanho do castelo (motor comum) | mantida |
| Santuário (`dusk_shrine_0`) | pequeno, só no fundo | | | | | ok | mantido |

Gerações PixelLab gastas: 5 chamadas `create_image_pro` = 25 imagens (16 árvores + 9 postes).
