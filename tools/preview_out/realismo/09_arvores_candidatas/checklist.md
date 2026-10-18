# Experimento (4): sprites novos de árvore pelo PixelLab (REJEITADO nesta rodada, candidatas guardadas)

Geração: `python tools/pixellab_trees.py queue fields_sun_a fields_sun_b fields_sun_c` (`create_image_pro`, referência de estilo `fields_tree_1.png`, 3 chamadas = 12 candidatas, ~45 gerações da assinatura; saldo 5000/ciclo). Prompt pedia luz do ALTO À DIREITA (o sol dos campos), copa com lado claro e lado escuro, parte de baixo escura, raízes visíveis, no máximo 4 verdes.

Folha de contato 3x: `contato_3x.png`. Medidas (`realismo_tree_diag`): PixelLab IGNOROU o lado do sol (todas neutras ou iluminadas da esquerda, k −0,04 a −0,48), mas acertou o volume vertical (topo 60 / embaixo 25 contra 65 / 39 da referência) e a paleta limpa (16 a 21 cores contra 116).

Teste em cena (a_0 → tree_0, c_3 → tree_1, a_2 → tree_2; `folha_*.png`, coluna "novas"; recortes `rec_landmark_arvores_esq.png`, `rec_fork_arvores_dir_fundo.png`):

| pergunta | resposta |
|---|---|
| melhor que o antes? | NÃO como conjunto: a parte de baixo escura das três faz a mata do meio virar uma massa uniforme; as copas claras dos sprites atuais separam cada árvore |
| natural? | cada árvore sozinha sim (raízes, volume); juntas, cerca viva |
| saturação caiu? | sim, a cena ficou mais escura e menos verde |

Decisão: sprites atuais mantidos; as 4 melhores candidatas ficam aqui (`fields_sun_a__0/a__2/c__3/b__0.png`) para o dono olhar. Se ele quiser esta direção, o caminho é UMA candidata nova misturada às atuais (variedade), não a troca das três, e um prompt que peça copa mais clara no topo.
