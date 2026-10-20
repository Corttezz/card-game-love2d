# Revisão de cenas, ato 4 (frost), 20/Out/2026

Mesmo método (`lovec . test_one revisao_cenas 4`). Capturas em `recortes/`. Nenhuma arte trocada neste ato.

| Item | Chão e contato | Entorno do bioma | Escala | Luz | Sombra | Profundidade | Estilo | Leitura | Veredito | Prova |
|---|---|---|---|---|---|---|---|---|---|---|
| Marco battle (estandarte branco) | ok, monte de neve na base | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_marcos.png |
| Marco elite (pilar de gelo) | ok, cristais na base | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Loja (cabana nevada) | base reta com faixa fina de neve; sem monte de neve como os outros marcos | aceitável | ok | ok | ok | ok | ok | ok | obs (leve) | recortes/folha_landmarks.png |
| Evento (balcão nevado) | ok, montes de neve | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Fogueira | ok, pedras com neve | ok | ok | ok | ok | ok | ok | ok | ok | recortes/folha_landmarks.png |
| Chão do bioma | tundra de capim seco cinza com montes de neve sob pinheiros muito nevados (no quadro de batalha a neve lê bem) | obs | - | - | - | - | - | - | obs: mexer exige grama nova do bioma, fora do escopo de hoje | recortes/folha_marcos.png |
| Montes de neve, pedras | ok | ok | ok | ok | ok | ok | ok | - | ok | recortes/folha_viagem.jpg |
| Castelo | faixa branca diagonal de neve à esquerda da base é da arte | ok | ok | ok | - | ok | assinatura | - | ok | ../castelos_seis_atos.png |
| Viagem | correção genérica do marco passando (ato 1) | | | | | | | | corrigido | recortes/folha_viagem.jpg (antes) |
| Batalha / elite | ok | ok | ok | ok | ok | ok | ok | ok | ok | ../batalhas_seis_atos.jpg |

## Segunda rodada (20/Out/2026), no rigor dos atos 1 a 3 (cada landmark e cada detalhe de chão a 4x e em cena)

| Item | Antes | Veredito | Prova |
|---|---|---|---|
| Chão do bioma | tapete denso de talos marrons sobre cinza, sem neve | corrigido: `GrassField.PRESETS.frost` carpet 0,40 e dry 0, `grassA/B` claros | chao_fork_cmp.png, chao_fork_antes_depois.jpg, chao_batalha_antes_depois.jpg |
| Loja (cabana) | flutuava 4 px; bloco cinza solto de 4x6 px no canto inferior direito; base reta | corrigido: bloco removido, montes de neve irregulares na base (PNG + 18 quadros) | loja_base_antes_depois.png, loja_marco_antes_depois.png |
| Toco (`frost_stump_0..2`) | caixinha marrom procedural (sem PNG) | regerado: toco com capa de neve e pingentes (candidatas 0, 9, 22) | ../arte_base/candidatas/toco_gelo.png, arvore_seca_toco_cena.png |
| Árvore seca (`frost_deadtree`) | tronco chapado de uma cor, sem face de luz | regerado: 2 variantes com tronco em volume, luz à direita, neve nos galhos e monte de neve no pé (`lit = 1`, `variants = 2`) | ../arte_base/candidatas/arvore_seca_gelo.png |
| Flores procedurais | pontinhos gerados em código | removidas do sorteio | ../catalogo/frost.png |
| Battle, elite, evento, fogueira, braseiro, cristal, montes de neve, pedra | volume, base e paleta ok a 4x | ok | arte/folha_props_3x.png, ../catalogo/frost.png |
