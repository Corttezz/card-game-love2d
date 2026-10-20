# Revisão de cenas, ato 1 (fields), 20/Out/2026

Capturas 1920x1080: `lovec . test_one revisao_cenas 1` (fork A battle/elite/shop e fork B event/rest/battle em tod 0,30/0,65/0,85; chegada a cada landmark em 0,65/0,85; viagem do clique à chegada; batalha e elite em 0,65/0,85; castelo). Recortes: `python tools/revisao_cenas_recortes.py folhas <save>/revisao_cenas/ato1/<tag> <destino>`.
Antes: `recortes/` (folha_marcos, folha_landmarks, folha_viagem). Depois: `depois/`.
Postes e luminárias de beira de estrada e o layout dos marcos ficaram fora (frente do lead).

Legenda: ok / corrigido / regerado / obs (defeito visto, não corrigido aqui).

| Item | Chão e contato | Entorno do bioma | Escala | Luz | Sombra | Profundidade | Estilo | Leitura | Veredito | Prova |
|---|---|---|---|---|---|---|---|---|---|---|
| Marco battle (bandeira) | ok, pedrinhas e tufos na base | ok | ok | ok | ok | ok | ok | pequeno, rótulo resolve | ok | recortes/folha_marcos.png |
| Marco elite (obelisco) | ok, brilho e tufos | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_marcos.png |
| Marco shop (cabana) | ok, deck de madeira | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_marcos.png |
| Marco event (tenda) | base reta curta | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Fogueira (rest) | ok, anel de pedra | ok | ≤ 0,6x inimigo | fogo ilumina o anel | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Pedra de chão (`fields_rock_0`, clutter e prop) | ok | NÃO: face clara creme L 220 e musgo lima, era o pixel mais claro do primeiro plano e lia adesivo | ok | lado claro sorteado | ok | ok | ok | - | corrigido: paleta escurecida (face 132/124/106, musgo 84/106/40) e `lit = 1` (face clara para o sol à direita) | recortes/pedra_antes_depois.png |
| Tufo, flores, toco | ok | ok | ok | ok | ok | ok | ok | - | ok | depois/folha_landmarks.png |
| Árvores perto/meio | ok (raízes, tufos) | ok | ok | ok | ok | ok | ok | - | ok | recortes/folha_viagem.jpg |
| Castelo (base na crista) | ok | ok | ok | ok | sem sombra (decisão anterior) | ok | assinatura, não mexido | - | ok | ../castelos_seis_atos.png |
| Viagem fork → chegada | - | - | - | - | - | marco escolhido CONGELAVA no pé da tela (t preso em 1) e SUMIA de uma vez ao passar rel -3 | - | - | corrigido (genérico, todos os atos): t segue além de 1 e o marco esmaece entre t 0,88 e 1,08 (`LMG.PASS_FADE`) | depois/folha_viagem.jpg, trava em `test_landmark_fx` |
| Batalha / elite | ok, pé apoiado, sombra curta | ok | ok | ok | ok | ok | ok | ok | ok | ../batalhas_seis_atos.jpg |
