# Experimento (e): chão em degradê, perto claro e longe escuro

Folhas: `folha_*.png` (atual | a3 | e).

Mudança (dados `fields.grade`): `groundFar` 0,80 → 0,62, `groundReach` 0,70 → 0,85 (o escurecimento vai até mais perto, sem degrau), `contrastFarDay` 1,0 → 0,85 (de dia os objetos do fundo também escurecem um pouco).

| pergunta | resposta |
|---|---|
| melhor que o antes? | sim: a estrada e a grama somem no escuro a caminho do castelo; o morro do castelo assenta |
| natural? | sim; é um degradê contínuo por pixel (véu no shader), nenhuma faixa visível em `rec_viagem_estrada_fundo.png` |
| algo do fundo pinta a frente? | não (o véu é por profundidade) |
| saturação caiu? | só no fundo (é a névoa); perto intacto |
| proporção | n/a |

Rejeitado antes de chegar aqui: clarear o perto pelo mesmo véu (o blend premultiplicado só escurece).
