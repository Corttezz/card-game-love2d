# Árvores novas do ato 1 (frente arvores-novas, 18/Out/2026)

Pedido do dono: "Toda árvore parece a mesma coisa, perto ou longe. Precisam de tratamento diferente em cada etapa: sombras, distância, raiz e tamanho; proporção real." A frente anterior rejeitou a troca por 3 candidatas porque a base escura virava massa uniforme na mata do meio (`realismo/09_arvores_candidatas/checklist.md`). Esta rodada instala 6 e faz o tratamento por plano.

## Conjunto instalado (das 12 candidatas `fields_sun_*`, zero geração nova)

| sprite | candidata | silhueta | sink | sizeK | luz (terços esq/dir, k) |
|---|---|---|---|---|---|
| fields_tree_0 | a_0 | redonda clássica, tronco único, raízes | 11 | 1.00 | neutra (0,00) |
| fields_tree_1 | c_3 | larga e baixa, copa em tufos, raízes grandes | 11 | 0.92 | neutra (0,00) |
| fields_tree_2 | a_3 | copa com vãos, tronco à vista, bifurcado | 11 | 0.98 | neutra (−0,03) |
| fields_tree_3 | a_1 | assimétrica, inclinada, mais clara | 10 | 0.94 | neutra (+0,01) |
| fields_tree_4 | b_2 | alta e estreita, bifurcada | 9 | 1.06 | neutra (−0,01) |
| fields_tree_5 | c_0 | copa em patamares, baixa | 9 | 0.88 | neutra (+0,06) |

Todas neutras de luz (|k| ≤ 0,06): sem entrada em `world_props.lit`; o espelho sorteado dá variedade. a_2 ficou de fora (mesma silhueta da a_0). Pontinhos brancos do PixelLab (3 pixels em tree_2/tree_4) substituídos pelo vizinho mais claro.

## O que mudou no pipeline

- `shaders/tree_depth.glsl` (só família `tree`, só bioma com `grade.treeDepth`): névoa por PIXEL (`lift` para `treeHaze`, escuros sobem mais que claros), saturação por pixel (`satNear` 1,12 no perto → `sat` 0,82 no fundo), meia resolução NÍTIDA no fundo (`lod`: amostra pontual 2×2, nada de média = nada de blur), volume topo-claro/base-escura (`vol` 0,14). Perto (t ≥ 0,70): pixel-idêntico ao desenho cru fora de `vol`/`satNear` (trava em `test_world_props`).
- `world_props.variants.fields_tree = 6`; `rollProp`/companheiras/`prewarmJobs` leem `PropCut.nvar`; `makeWall` nunca repete a variante da vizinha do mesmo lado.
- `PropVariation.bright` (±16 %) além do tom (±6 %): vizinhas na parede diferem de brilho.
- Sombra de copa no chão e faixa de contato só no perto (`PropCut.nearK`: 0 em t ≤ 0,3, 1 em t ≥ 0,6).
- `treeGain` 0,8 → 0,92 (o 0,8 fora calibrado para o carvalho antigo, mais claro).

## Rodadas (r1 → final)

- r1 (`lift` 0,32 para a cor crua da névoa, `vol` só no perto): meio e fundo cinza-lilás e lavados; clarear a base de TODAS as copas tira o contraste dentro da copa e a mata fica MAIS uniforme. Rejeitado.
- r2 (`lift` 0,26 para névoa ×1,45, `vol` também no meio, brilho por instância 0,16): meio voltou a ter copas separadas; fundo ainda lilás e borrado (média 2×2).
- r3/final: LOD por amostra pontual (nítido), névoa `{1.50, 1.55, 1.32}` (mais verde, menos roxa), `lift` 0,22, `satNear` 1,12, `treeGain` 0,92.

## Checklist por recorte (3×, `antes | atual | novo`)

| recorte | pergunta | resposta |
|---|---|---|
| `rec_landmark_arvores_esq` | variedade visível na mata do meio? | sim: copas claras e escuras alternadas, silhueta larga (tree_1) ao lado da redonda; desvio de luminância 22,7 → 32,7 (dia), 16,1 → 23,2 (meio), 11,7 → 17,8 (pôr) |
| `rec_landmark_arvores_esq` | base escura some com a distância? | sim: no fundo a base sobe para a névoa e a copa vira silhueta de 2 tons; no perto a base continua escura e as raízes aparecem |
| `rec_fork_arvores_dir_fundo` | fundo nítido, sem borrão? | sim depois do LOD pontual; r2 tinha borrão |
| `rec_fork_arvores_dir_fundo` | saturação do fundo | caiu por desenho (0,54 → 0,38 de dia na landmark; 0,56 → 0,56 no fork): é a perspectiva atmosférica pedida na pesquisa (fundo 55 a 65 % do perto) |
| `rec_viagem_arvores_esq` / `folha_viagem` | proporção? | perto 351 a 482 px (t=1, 768p, antes do `big`), meio 173 a 290, parede alta (tree_4) e larga (tree_1) lado a lado; poste 3,2 contra árvore 4,6 (inalterado) |
| `rec_landmark_poste_esq` | nada do fundo pinta a frente? | não: a árvore do fundo fica atrás do poste, sombra nenhuma cruza a haste |
| `rec_landmark_arvores_esq` (perto, canto inferior) | sombra de copa na grama? | sim, disco escuro sob a copa da árvore da frente, inclinado para o lado da sombra do sol; some no meio |
| `folha_landmark` dia/meio/pôr | saturação do perto | 0,60 → 0,52 (dia): a paleta nova é menos saturada que o carvalho antigo (0,69 contra 0,56 a 0,65 nos PNGs); `satNear` 1,12 recupera parte (0,50 → 0,52); no fork o meio subiu (0,56 → 0,59) |
| `parede_arvores_1x_dia` | silhuetas diferentes entre si? | sim: redonda, larga, com vãos, inclinada, alta, em patamares |

## Perf (1080p, `TOOL_WINDOW=1920x1080 lovec . test_one perf_probe phases`)

bioma 1 mediana 5,21 ms (p95 9,35), 401 draw calls, props 4,29 ms; `test_perf_budget`: 403 draw calls, 31,6 KB/quadro, 0 decode no 1º quadro da troca. Locais do `WorldRoad.lua`: 188 (inalterado).

## Pendente / observado

- A paleta nova é mais escura e menos saturada que o carvalho antigo; se o dono quiser a cena mais viva, o knob é `treeNear`/`satNear`, não os PNGs.
- O sprite é um só por árvore (104 px): no perto ele é ampliado 4× e no fundo desenhado ~1:1; o LOD do fundo compensa, o perto continua "pixel grande".
