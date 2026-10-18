# Ato 2, highlands (Colinas da Torre): checklist (18/Out/2026, frente replica-23)

Antes = main `ed2484f1`. Depois = este commit. Capturas: `antes/` e `depois/` (grade de 12 em 1024x768 +
batalha 1080p em tod 0,65 e 0,95). Recortes em `recortes/` (antes à esquerda). Medidas:
`lovec . test_one escala_humana depois:b2` (1080p, tod 0,65).

## Lista fixa do plano (Tarefa 7)

| item | sim/não | evidência |
|---|---|---|
| 1. chão, árvores e marco na mesma temperatura (lua fria) | sim. A fogueira era a exceção ao contrário: o PNG tinha chama salmão pastel que a lua acinzentava; a chama foi recolorida para laranja/amarelo vivo (mesma arte, 10 quadros) e agora é o único quente da cena, como fogo deve ser | `recortes/fogueira_landmark.png` |
| 2. horizonte mais lavado e menos saturado, sem degrau | sim (`fogCurve` 2,4, `treeDepth` com véu = curva do chão; crista vira silhueta nítida) | `recortes/arvores_longe_crista.png`, `depois/b2_*_fork.png` |
| 3. faixa de contato lê como sombra, não contorno | sim (`contact.alpha` 0,65; base do pilar e dos pinheiros) | `recortes/braseiro_perto.png`, `recortes/arvores_meio_dir_sombra.png` |
| 4. tufos cobrem a base sem esconder a arte | sim (sem mudança: 2 a 5 tufos) | `recortes/braseiro_perto.png` |
| 5. névoa baixa no pôr do sol, sem muro branco | sim (`lowFog.alpha` 0,26 → 0,22) | `depois/b2_por_fork.png` |
| 6. árvores da parede não repetem silhueta; vento não frenético | sim: 6 variantes de pinheiro (eram 3, duas quase iguais): torre fina com vãos, topo quebrado pela tempestade, baixo e largo; `makeWall` não repete vizinha; sway 0,034 → 0,030 | `recortes/arvores_meio_dir_sombra.png`, `../pixellab/folha_hl_pine.png` |
| 7. à noite nada clareia além da arte | sim (luz só onde há chama; luminária com `dayK`) | `depois/b2_batalha_1080p_tod0.95.png` |

## As 9 lições do dono

| lição | sim/não | evidência |
|---|---|---|
| 1. sombra natural, 3 degraus, nascendo da base, nada de trás pintando a frente | sim. Antes NÃO havia sombra projetada visível (alphaK 1,0); agora alphaK 2,2, árvores ×1,45, disco de copa, cor fria multiplicada. Sombras caem para baixo-esquerda (lua à direita e à frente) e somem atrás do pilar da frente (máscara de profundidade) | `recortes/arvores_meio_dir_sombra.png` |
| 2. árvore nunca mais clara que a grama vizinha | sim: copa/grama L 0,85 (t 0,15 a 0,30) e 0,77 (t 0,30 a 0,50) | `python tools/escala_humana_sheet.py canopy replica-23 depois b2_tod65` |
| 3. escala contra o inimigo | sim: braseiro de beira de estrada 0,87x o inimigo na mesma profundidade (era 0,30x; pilar de 1 m virou coluna de 2,5 m); pinheiros do meio 0,95 a 1,1x; castelo 253 px contra 114 px da maior árvore da crista vizinha (2,2x); fogueira inalterada | `objetos.md`, `recortes/braseiro_perto.png` |
| 4. variação de árvore | sim (6 variantes, `variants.highlands_pine = 6`, `sizeK` 1,05 / 0,72 na torre e no baixo) | `../pixellab/folha_hl_pine.png` |
| 5. lado iluminado para a lua | sim nas novas (prompt com luz da direita, lua em xr 0,74); antigas neutras | folha |
| 6. luminária apagada de dia, acesa ao entardecer; fogo ilumina chão e vizinhos | sim: braseiro com `pool` novo (poça no chão na base, porque a chama agora está no topo de 2,5 m e o círculo antigo não alcançava o chão); fogueira com `selfLight` 0,30 (era 0) | `recortes/braseiro_perto.png` (tod 0,65 meia força, 0,95 cheia) |
| 7. chão mais escuro e frio ao fundo | sim (`groundFar` 0,62, `groundReach` 0,85) | `depois/b2_dia_fork.png` |
| 8. nada de colagem | o braseiro antigo (cubo de tijolo azul saturado, metade da altura de um homem, sem contato) era colagem e foi regerado; a fogueira pastel foi recolorida. Resta a pedra rúnica azul saturada (é mágica, brilha; ficou) | `recortes/braseiro_perto.png`, `recortes/runa_e_base_braseiro.png` |
| 9. olhei as capturas e recortes | sim, todos os arquivos de `recortes/` e as 14 capturas de `depois/` | |
