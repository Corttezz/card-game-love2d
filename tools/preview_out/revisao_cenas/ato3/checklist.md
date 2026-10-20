# Revisão de cenas, ato 3 (abyss), 20/Out/2026

Mesmo método (`lovec . test_one revisao_cenas 3`). Antes: `recortes/` e `antes/` (PNGs originais); depois: `depois/`.

| Item | Chão e contato | Entorno do bioma | Escala | Luz | Sombra | Profundidade | Estilo | Leitura | Veredito | Prova |
|---|---|---|---|---|---|---|---|---|---|---|
| Marco battle (estandarte vermelho) | ok | ok | ok | ok | ok | ok | ok | vermelho escuro sobre terra escura, quase some; rótulo resolve | obs | recortes/folha_marcos.png |
| Marco elite (torre com espinhos) | entulho escuro com borda inferior reta | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Loja (casa de pedra com braseiro) | ok | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Evento (barraca) | ok | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Fogueira (`abyss_landmark_rest`) | NÃO: chama alta sobre duas pedras-bolha e uma almofada rosa chapada de borda dura | rosa pastel fora da paleta | ok | pedras cinza-lavanda frias | ok | ok | contorno preto grosso, sem volume | ok | regerado: PixelLab `create_image_pro` (style image = arte atual, 2 chamadas, candidata `ab_rest_rc2__4` de 32): anel de basalto com rachaduras em brasa, troncos carbonizados, sem almofada; animação refeita por `tools/bake_luminaire_flicker.py abyss_landmark_rest flame 0.55` | recortes/fogueira_antes_depois.png, recortes/fogueira_marco_antes_depois.png, folhas `folha_ab_rest_rc1.png`, `folha_ab_rest_rc2.png`, `candidata_escolhida_ab_rest_rc2__4.png` |
| Brasas de chão (`abyss_embers_0..3`) | ok | NÃO: lascas pêssego dessaturadas liam pão ou osso, não brasa | ok | - | ok | ok | ok | - | corrigido: três tons pêssego trocados por laranja saturado | recortes/brasas_antes_depois.png |
| Árvores mortas, pedras | ok | ok | ok | ok | ok | ok | ok | - | ok | recortes/folha_viagem.jpg |
| Castelo | ok | ok | ok | ok | - | ok | assinatura | - | ok | ../castelos_seis_atos.png |
| Viagem | correção genérica do marco passando | | | | | | | | corrigido | depois/folha_viagem.jpg |
| Batalha / elite | ok | ok | ok | ok | ok | ok | ok | inimigo escuro sobre fundo escuro (frente de monstros) | obs | ../batalhas_seis_atos.jpg |

## Segunda rodada (20/Out/2026)

| Item | Antes | Veredito | Prova |
|---|---|---|---|
| Estandarte battle | vinho escuro sobre terra escura | corrigido: cinza de cinzas com o cervo dourado | ../estandartes/fork_ato3.png, ../estandartes/chegada_ato3.png |
| Toco (`abyss_stump_0..2`) | caixinha marrom procedural de 8x9 px (sem PNG), 66 ocorrências nas capturas | regerado: PixelLab `create_image_pro`, toco carbonizado com rachaduras em brasa (candidatas 3, 17, 22) | ../arte_base/candidatas/toco_abismo.png, ../catalogo/abyss.png |
| Flores procedurais | pontinhos laranja gerados em código | removidas do sorteio (as brasas de chão cobrem o papel) | ../catalogo/abyss.png |
