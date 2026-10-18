# Experimento (b): árvores com tratamento por plano (perto / meio / longe)

Folhas: `folha_*.png` (atual | b | b2); recortes `rec_landmark_arvores_dir_fundo.png` e `rec_fork_arvores_esq_meio.png`.

Mecanismo (`engine/SceneGrade.lua`, família `tree`): `treeDepth = { near, far, sat, bright, fog }` na tabela do bioma. De t = near (cor cheia) até t = far o tom caminha para `sat`, `bright` e para a cor da névoa (`fog` = fração a mais). Fora da família `tree` nada muda.

| versão | valores | veredito |
|---|---|---|
| b | near 0,6, far 0,3, sat 0,55, bright 0,78, fog 0,30 | as árvores do MEIO (t ≈ 0,45) ficaram acinzentadas na linha "dia" (o mesmo defeito que derrubou o shader de volume) |
| b2 (aceita) | near 0,55, far 0,25, sat 0,65, bright 0,80, fog 0,30 | meio ~88 % de saturação; só a crista leva o efeito inteiro |

| pergunta | resposta |
|---|---|
| melhor que o antes? | sim: as árvores da crista recuam para o azul-cinza das montanhas, as do meio perdem um pouco, as de perto ficam cheias; antes todas tinham a mesma cor |
| natural? | sim no meio e no pôr do sol (a faixa real do jogo, tod 0,62 a 1); de dia a crista fica escura contra a montanha clara, aceitável |
| algo do fundo pinta a frente? | não |
| saturação caiu? | só com a distância (é o objetivo); perto medido igual (149 → 148) |
| proporção | n/a |

Não feito: sprite suavizado (meia resolução) para o longe. A cor já separa os planos; fica como próximo passo se o dono quiser menos detalhe na crista.
