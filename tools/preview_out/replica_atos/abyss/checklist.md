# Ato 3, abyss (Estrada do Abismo): checklist (18/Out/2026, frente replica-23)

Antes = main `ed2484f1`. Depois = este commit (`depois/`: grade de 12 em 1024x768 + batalha 1080p em
tod 0,65, 0,75 e 0,95). Recortes em `recortes/` (antes à esquerda). Medidas:
`lovec . test_one escala_humana v1:b3` (1080p, tod 0,65) e
`python tools/escala_humana_sheet.py canopy replica-23 v1 b3_tod65`.

## Lista fixa do plano (Tarefa 8)

| item | sim/não | evidência |
|---|---|---|
| 1. temperatura única, pôr do sol NÃO vira roxo | sim: `grade.dusk` 0,86/0,46/0,36 (escurecia e puxava para o roxo) virou só matiz quente 0,98/0,86/0,82 | `depois/b3_por_*.png` |
| 2. horizonte lavado pela névoa vermelha fina, sem degrau | sim (`fog` = cor medida da base das montanhas, `fogCurve` 2,4) | `depois/b3_dia_fork.png`, `recortes/castelo.png` |
| 3. faixa de contato lê como sombra sobre chão escuro | sim (0,60 → 0,65) | `recortes/tocha_perto.png`, `recortes/braseiro_meio.png` |
| 4. tufos escassos (≤ 4) | sim (2 a 4) | |
| 5. névoa baixa de cinza fraca (≤ 0,18) | sim (0,14) | `depois/b3_por_fork.png` |
| 6. árvores mortas quase paradas (≤ 0,018) | sim (0,016) | |
| 7. terra queimada da fogueira forte (≥ 0,55), brasas visíveis | sim (0,62; `selfLight` 0,20, era 0) | `recortes/fogueira_landmark.png` |

## As 9 lições do dono + revisão do lead (18/Out)

| item | sim/não | evidência |
|---|---|---|
| 1. sombra natural, nascendo da base; árvore morta projeta sombra | sim: antes alphaK 1,0 (sem sombra de árvore visível); agora 2,2, árvore ×1,45, cor de multiplicação 0,40/0,26/0,24; os galhos aparecem no chão para baixo-esquerda (sol à direita e à frente); disco de copa só 0,20 (árvore sem folha) | `recortes/arvores_meio_esq.png`, `recortes/arvores_perto_dir.png` |
| 2. árvore nunca mais clara que o chão vizinho | sim: copa/chão L 0,85 / 0,69 / 0,65 (t 0,15-0,3 / 0,3-0,5 / 0,5-0,7) | canopy |
| 3. escala (lead: tocha ~1/3, braseiro ~0,5x) | tocha 0,84 a 0,87x o inimigo na mesma profundidade (era 0,29x); pilar-braseiro ~0,8x (era 0,34x), em faixa um pouco afastada da estrada (`lane` 0,10 a 0,20); castelo 2,2x a árvore vizinha da crista | `objetos.md`, `recortes/tocha_perto.png` |
| 4. variação de árvore (regra diorama) | 6 variantes novas (`variants.abyss_deadtree = 6`): S retorcido, tronco duplo, toco quebrado inclinado, poste fino espinhoso, baixa e larga, curvada pelo vento; prompt diorama com luz do sol vermelho à direita; arbusto de espinhos regerado (3 variantes) | `../pixellab/folha_da_dead.png`, `../pixellab/folha_da_bush.png` |
| 5. lado iluminado para o sol | sim (`lit = 1` nas novas, `abyss_rock_0 = -1`: a pedra era pintada com luz à esquerda e passa a espelhar para o sol) | |
| 6. luz: acesa ao entardecer; fogo tinge o chão | sim: tocha e pilar com `light.pool` (poça laranja na base) | `recortes/braseiro_meio.png` |
| 7. chão mais escuro ao fundo e com variação no perto (lead: "chapado") | sim: `groundFar` 0,62 / `groundReach` 0,85; `biomes.lua` abyss `grassA/B` com mais contraste (0,22/0,18 → 0,27/0,16 no vermelho) | `depois/b3_batalha_1080p_tod0.75.png` |
| 8. colagem (lead: chamas soltas perto da câmera) | a fissura era um par de pedras azul-acinzentadas (fora da paleta) com luz; virou fenda de lava no chão (PixelLab), `size` 0,9 → 0,5 para manter a densidade de pixel, brilho pulsando em 9 quadros | `../pixellab/cand/ab_fissure__12.png` |
| 9. olhei as capturas e recortes | sim | |
| última passada do lead: árvores mortas do meio enlameadas | brasa das fendas devolvida no PNG das 6 variantes (pixels de brasa ×1,35 em valor) e véu das árvores mais leve no abismo (`treeDepth.lift` 0,25 → 0,12, `sat` 0,85 → 0,95, `satNear` 1,15) | `recortes/arvores_meio_brasa.png`, `final/` |
