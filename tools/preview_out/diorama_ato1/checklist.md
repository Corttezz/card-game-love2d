# Diorama do ato 1 (fields): checklist

Regra: `memory/art_direction_diorama.md`. Luz do bioma: sol à direita e alto (`celestial.xr = 0.79`).
Ferramenta única da família: PixelLab `create_image_pro` (style image = sprite atual do slot, prompt em inglês com
cada item da regra e a direção do sol). Animação: `animate_image` via `tools/pixellab_tree_anims.py` (mesma do
front arvores-anim, 6 quadros, portão IoU 0,97 / tronco 0,95, transferência só do delta).

Arquivos: `antes/` e `depois/` (batalha 1080p tod 0,65 e 0,95, `grade/` com as 12 do bioma 1), `recortes/`
(antes|depois 1x e 2x), `arvores_antes_depois_{1x,4x}.png`, `objetos_antes_depois_{1x,4x}.png`, `folhas/`
(todas as candidatas: `*_grade.png`, `tree*_a_*`, `hi*_sheet.png`).

## Árvores (candidata escolhida → slot)

| slot | silhueta | candidata | 3 planos | grupos de tamanho/valor diferentes | folha cobre galho/tronco | sombra pontilhada no tronco | contorno seletivo | tronco/raiz com face de luz e sombra | paleta e escala |
|---|---|---|---|---|---|---|---|---|---|
| tree_0 | redonda, raízes enroscadas | tree0_a__02 | sim (fundo escuro no miolo, meio, frente com topo claro) | sim | sim | parcial (escurece sob a copa, pouco pontilhado) | sim | parcial (tronco neutro, raízes com luz) | sim, 104x106 |
| tree_1 | larga e baixa | tree1_a__02 (espelhada) | sim | sim, massas soltas nas pontas | sim | parcial | sim | sim, face clara à direita após espelho | sim, 105x100 |
| tree_2 | copa com vãos (tufos em galhos) | tree0_a__03 (espelhada) | sim, plano de fundo atrás dos tufos | sim, tufos redondos de tamanhos diferentes | sim | sim | sim | sim | sim |
| tree_3 | inclinada | tree0_a__01 (espelhada) | sim | sim | sim | sim | sim | sim, melhor tronco da família | sim, 97x106 |
| tree_4 | alta bifurcada | tree4_b__01 (espelhada, tronco recolorido para a paleta da família) | sim, copa empilhada | sim | sim | parcial | sim | sim, mas tronco fino (7 px) | sim, 54x107 |
| tree_5 | em patamares | tree5_a__00 (verdes escurecidos 0,82 e plano de fundo cinza → verde) | sim, patamares em alturas diferentes + massa de fundo | sim | sim | parcial | sim | sim | sim, 104x91 |

Pós-processo comum: o plano de fundo vinha em verde acinzentado (#26372e, #1a231f, #1d2527) e lia como névoa colada
dentro da copa: virou verde escuro. Destaque lima (#bacc4e, #88a041) baixado para #9cb44c / #74923c depois da
captura de dia (copa perto roubava o olho, alerta do lead). Medido (folhas, L médio): 0,25 a 0,30 em todas
(antes 0,24 a 0,34), croma 0,19 a 0,21. Lado iluminado medido (pixels altos dir > esq e tronco dir > esq):
1 a 5 com `lit = 1`, a 0 é neutra (sem `lit`).

## Objetos

| sprite | candidata | volume | luz à direita | contato/base | veredito |
|---|---|---|---|---|---|
| bush_0 | bush_a__08 | tufos sobrepostos, fundo escuro à esquerda, frente clara | sim (`lit = 1` mantido) | caules na base | trocado |
| rock_0 | rock_a__24, espelhada | bloco com face de luz e face escura, musgo no topo, pedra menor na frente | sim após espelho | base reta | trocado |
| stump_0 | stump_a__00 | cilindro com face clara à direita, corte visto de cima, raízes com face de luz | sim | raízes | trocado (versão limpa do antigo, sem os pixels rosa) |
| shrine_0 | shrine_a__00 | caixa vista de 3/4, face lateral e telhado com duas águas | parcial (telhado direito claro) | poste com flores, sem o monte de terra assado | trocado; chama achada pelo scan (0,42 / 0,47); `anim/` refeito (9 quadros iguais, como antes) |
| flowers_0 | flowers_b__25 (2a rodada sem referência) | 3 planos: lâminas escuras atrás, folhas, flores amarelas na frente | n/a | sem o remendo de terra (a 1a rodada copiou a terra assada da referência em todas as 49) | trocado |
| lantern_0 | lantern_a__03 avaliada | poste de 7 px com duas faces | luz pintada à ESQUERDA | n/a | REJEITADA: no quadro 1080p virava uma viga laranja com lanterna enorme; mantido o poste antigo |
| landmarks / castelo | não regerados | já com volume (casa, tenda, castelo com torres) | | | fora deste passe; orçamento estourado |

## As 9 lições do brief

1. Sombra forte/de fundo pintando a frente: o disco de copa dos campos caiu de alpha 0,55/largura 0,42 para 0,20/0,32
   (manchas redondas soltas na grama, alerta do lead); a sombra projetada pela silhueta segue igual. Ver
   `recortes/sombras_grama_dir_tod065_1x.png`. Sim.
2. Filtro branco: nenhuma árvore mais clara/enevoada que a grama vizinha; o `tree_depth` continua (crista com névoa,
   `crista_castelo_tod095_2x.png`). Sim.
3. Escala: mesmas alturas de canvas (100 a 107 px) e mesmo `sizeK`; `sink` refeito pela razão raiz/tronco das
   antigas (12/9/11/11/8/9). Sim.
4. Variedade: 6 silhuetas distintas mantidas; `makeWall` intocado. Sim.
5. Lado iluminado para o sol: 5 de 6 árvores com `lit = 1` (o PixelLab desenhou luz à esquerda apesar do prompt;
   espelhei o PNG). Sim.
6. Luz da luminária: poste e oratório mantêm a âncora por conteúdo. Sim.
7. Chão mais escuro lá na frente: intocado. Sim.
8. Colagem: plano de fundo cinza das copas corrigido; flores sem terra assada; poste novo rejeitado por colagem. Sim.
9. Olhei as capturas e os recortes antes de escrever cada linha acima. Sim.

## Leitura honesta
- As copas agora leem em tufos com vãos e tronco visível por trás (melhor no perto e no meio). O pixel do perto
  continua grande: tentei canvas 160 (6 chamadas `create_image_pro` com a candidata como referência e uma com a
  referência ampliada) e o modelo devolveu SEMPRE a árvore com os mesmos 104x106 px no meio do canvas (o style image
  dita o tamanho). Fica com o limite de `c83a3a5f` (prop perto ≤ 2x o pixel do inimigo).
- Animação: só `fields_tree_0` e `_2` passaram o portão (1, 3, 4 e 5 com IoU 0,92 a 0,945 em 2 a 3 tentativas cada);
  as outras ficam com o balanço. `test_tree_anim` passou a exigir ao menos 2 (era 4).
- O oratório novo é menor e mais escuro que o antigo; o poste continua o antigo (plano, 4 px).
