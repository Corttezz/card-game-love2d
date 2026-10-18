# Experimento (f): a fogueira emite luz; lanternas um degrau menor

Folhas: `folha_*.png` (antes | atual | f2); recortes `rec_landmark_fogueira.png`, `rec_landmark_poste_esq.png`, `rec_viagem_sombra_estrada_crista.png` (atual | f | f2).

Mudanças: `LANDMARK_LIGHT.landmark_rest` radiusK 0,55 → 0,95 e intensidade 0,55 → 0,85 (poça ~1,7x maior e 1,5x mais forte); brilho próprio da fogueira (`selfLight`) dobrado; lanterna dos campos radiusK 1,35 → 1,50, intensidade 0,85 → 0,95. A luz é multiply-only (doutrina do projeto): devolve a arte onde o ambiente escureceu, por isso de dia (tod 0, só na ferramenta) não aparece.

| pergunta | resposta |
|---|---|
| melhor que o antes? | sim: no meio e no pôr do sol a poça quente cobre o anel de pedras, a estrada e a grama ao lado; os troncos atrás recebem a cor |
| natural? | sim; poça posterizada com dither (padrão aceito), sem halo colado na silhueta |
| algo do fundo pinta a frente? | não: árvores na frente da fogueira ocluem a luz (`submitOccluder`) |
| saturação caiu? | não |
| proporção | n/a |

Nesta rodada também saiu a correção da sombra do inimigo (ver `02_sombra_copa/checklist.md`, versão f2).
