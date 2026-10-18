# Escala humana do quadro de batalha: checklist (18/Out/2026)

Quadro de referência: ato 1, `cursed_scarecrow`, tod 0,65, 1920x1080
(`CARDGAME_HEADLESS=1 CARDGAME_IDENTITY=cenario-escala lovec . test_one escala_humana depois:b1`).
Antes = main `d4cc18cb`. Recortes em `recortes/` (sempre antes à esquerda, depois à direita).
Olhei cada recorte ampliado antes de responder; a métrica está em `medidas.md`.

| pergunta | resposta | evidência |
|---|---|---|
| Poste mais alto que o inimigo? | **Parcial.** No quadro final o poste perto (t 0,85) tem 540 px contra 317 do inimigo; o poste do fundo (t 0,13) tem 115 px. Na MESMA profundidade o poste vale 0,68× o inimigo real (era 0,44×): aceito pelo lead, o lever é o crescimento de tela do inimigo (conta em `medidas.md`). | `recortes/01_poste_frente_inimigo_antes_depois.png`; tabela do ato 1 em `medidas.md` |
| Árvore mais alta que o poste na mesma profundidade? | **Sim**, para toda árvore com `big` ≥ 1: tree 5,6 × big (1,0 a 1,45) × sizeK (0,88 a 1,06) contra poste 5,0 com 68/72 de conteúdo (4,7 unidades visíveis). O menor caso (fields_tree_5, sizeK 0,88, big 1) dá 4,9 unidades, ainda acima dos 4,7 do poste. | `medidas.md`, seção "unidades" |
| Castelo ≥ 2× a árvore da crista? | **Sim.** Castelo / maior árvore da crista (t ≤ 0,06): ato 1 1,73 → 2,25; ato 2 1,76 → 2,39; ato 3 1,69 → 2,47; ato 4 1,77 → 2,43; ato 5 1,71 → 2,33; ato 6 1,75 → 2,52; encruzilhada 1,82 → 2,43. | `recortes/03_crista_castelo_antes_depois.png`, `03b_crista_castelo_fork_antes_depois.png` |
| Árvore nunca mais clara que a grama ao lado? | **Sim.** Copa / grama vizinha em t 0,3 a 0,5: luminância 1,10 → 0,70, saturação 0,92 → 1,84 (no perto, t 0,5 a 0,7, a relação natural é 0,88 / 1,71). Em t 0,15 a 0,30 a luminância relativa caiu de 1,40 para 1,23 e a saturação relativa subiu de 0,69 para 1,55 (lift 0,25). | `recortes/02_arvores_meio_dir_antes_depois.png`, `02b_arvores_meio_esq_antes_depois.png`, `recortes/exp_lift_dir.png` (antes, lift 1,0, 0,5, 0,25, 0) |
| Sombra e contato presentes na batalha? | **Sim, e já estavam**: o diff com `ESCALA_NOSHADOW=1` mostra as duas bandas compostas (55 + 73 sombras, silhueta do inimigo) tanto antes quanto depois. O defeito real era de DIREÇÃO: os postes virados para a estrada projetavam a sombra para o sol (espelho do sprite espelhava o cisalhamento). Depois: as sombras dos postes de t 0,46 e 0,67 caem para baixo-esquerda, cruzando a estrada; a faixa de contato está na base do poste da frente. A sombra projetada do poste mais perto cai abaixo da borda da tela (sol à frente da câmera). | `recortes/05_base_poste_frente_antes_depois.png`, `05b_base_poste_meio_sombra_antes_depois.png`, `05c_poste_t046_sombra_antes_depois.png`, `diag_lantern_only_overlay.png` (magenta = pixels da sombra dos postes, antes) |
| Lanterna apagada de dia e acesa no pôr do sol? | **Sim.** tod 0,30: sem poça nem micro-luz (`dayK` 0); tod 0,65: meia força; tod 1,0: igual ao antes (pixel a pixel na luz). A chama pintada no PNG permanece sempre. | `recortes/04c_lanterna_tod030_sem_gate_vs_depois.png` (esquerda sem gate, direita com), `04_lanterna_tod065_antes_depois.png`, `04b_lanterna_tod100_antes_depois.png` |
| Algo de trás pintando algo da frente? | **Não vi.** A máscara de profundidade continua: a sombra do poste de t 0,46 some atrás do poste de t 0,88 (`diag_poste_t046.png`); as sombras dos postes caem sobre a grama e a estrada, nunca sobre o inimigo ou sobre o poste da frente. | `recortes/05c_poste_t046_sombra_antes_depois.png`, `diag_poste_t046.png` |
| Intensidade natural, nada escrachado? | **Sim.** Os postes maiores lêem como postes de rua (1024x768 e 1080p, nada cobre cartas, botão Jogar nem rótulos da encruzilhada); as sombras continuam sutis (12 a 25 níveis em grama escura); a névoa das árvores ficou verde, não lavanda. A cadência `LUM_STEP` 7 → 13 tirou o empilhamento: batalha do ato 1 com 2 postes (t 0,85 e 0,13, lados opostos), landmark 2 (0,51 e 0,25), viagem 3 (0,06, 0,26 e um saindo pela base), encruzilhada 0; atos 2 a 6 com 2 a 3 luminárias, nunca duas do mesmo lado a menos de 13 unidades, nenhuma cabeça sobre outro poste. | `depois/b1_batalha_1080p.png`, `depois/viagem_1080p.png`, `depois/b2..b6_batalha_1080p.png` |

## O que ainda está feio (leitura honesta)

1. **Poste na profundidade do inimigo ainda é 0,68× dele.** A razão 1,35× pedida só sai com
   poste de 9 unidades (ou árvore de 10), e aí o poste perto teria 1000 px e cobriria a tela.
   O que está fora de escala é o inimigo: em 1080p ele cresce 1,555× (`enemyScreenK`) contra
   1,40× do mundo e encolhe só `persp^0,6` quando o palco o empurra. Não mexi (legibilidade),
   mas é o lever certo se o dono quiser a razão literal.
2. **Sombras continuam discretas.** São corretas e com a direção certa agora, mas em grama
   escura ao pôr do sol valem 12 a 25 níveis; o dono pode não as ver numa captura comprimida.
   Subir `shadow.alphaK` acima de 2,2 foi rejeitado na rodada anterior (borrão sob o inimigo).
3. **Castelo do ato 1 fica atrás do HUD do inimigo** (barra de vida e intenção). Já era assim;
   com o castelo maior fica mais evidente que o topo está escondido.
4. **Fogueira e marcos da encruzilhada não foram mexidos** (só medidos): fogueira 0,52× do
   inimigo real na mesma profundidade (0,97× do inimigo nominal de 3,7 unidades do brief),
   cabana da loja 0,36× real (1,4× nominal), bandeira 0,23× real (0,92× nominal). Pela régua
   nominal do brief a fogueira estaria "fora" (> 0,6×); pela régua real está dentro. Deixei
   como está e reporto.
