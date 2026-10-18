# Escala humana: medidas (18/Out/2026)

Todas as alturas em px num quadro virtual de 1920x1080 (área do mundo = 1000 px de altura).
Fonte: `lovec . test_one escala_humana <antes|depois>:<cena>`; arquivos brutos em `medidas_raw/`.
Tabela completa (um prop por linha, seis atos) gerada por
`python -I <scratch>/cenario-escala_medidas.py medidas_raw` e resumida abaixo.

## Unidades (conta para o dono decidir o tamanho do inimigo)

Em 1080p o inimigo comum é desenhado com 250 px × `battleSizeK` × `enemyScreenK`:
`enemyScreenK(1000) = 1 + (1000 − 716) / 716 × 1,4 = 1,555` e, com o palco empurrado para
rel 13,19 pela carta levantada, `battleSizeK = (persp(0,385) / persp(0,564))^0,6 = 0,815`;
317 px. O mundo cresce só 1000/716 = 1,40× entre 768p e 1080p, e um prop encolhe com `persp`
inteiro (expoente 1,0, não 0,6). Resultado: o inimigo vale 6,94 unidades de `size` na
profundidade dele em 1080p (5,4 em 768p). Para um poste de 5,0 ser 1,35× o inimigo, o inimigo
teria de valer 3,7 unidades: `ENEMY_SCREEN_GROWTH` 1,4 → 0,0 e `ENEMY_SIZE_PERSP` 0,6 → 1,0
dariam 250 × 0,677 = 169 px (3,7 unidades) em 1080p. Não mexi: decisão de legibilidade.

- `g.scaleAt(size, t, ih)` desenha `size × 143,75 × persp(t)` px, com `persp(t) = 0,14 + 0,86·t^1,65`.
- **Inimigo real:** 317 px em t = 0,385 (rel 13,19; `sizeK` 1,267 = `battleSizeK` 0,815 ×
  `enemyScreenK` 1,555). Na profundidade dele, 1 unidade = 45,7 px, logo o inimigo vale
  **6,94 unidades**. "Inimigo no mesmo t" abaixo = 317 × persp(t) / persp(0,385).
- **Inimigo nominal do brief:** 250 px em rel 9 sem crescimento de tela = 3,7 unidades.
  As razões do brief (poste 1,35×, árvore 1,5×) foram escritas nessa régua.
- 1024x768 (área 688 px): inimigo 173 px em t = 0,298; poste perto 405 px; castelo 174 px;
  as razões por profundidade são as mesmas (tudo escala com a área).

## Tamanhos (dado)

| objeto | antes (`size`) | depois | depois / inimigo nominal (3,7) | depois / inimigo real (6,94) |
|---|---|---|---|---|
| poste de rua (fields, marsh, dusk) | 3,2 / 4,2 / 4,2 | 5,0 | 1,35 | 0,72 (0,68 visível: 68/72 de conteúdo) |
| tree (fields, dusk) | 4,6 | 5,6 | 1,51 | 0,81 (× big 1,0 a 1,45 × sizeK) |
| pine (highlands, frost) | 5,0 | 6,0 | 1,62 | 0,86 |
| deadtree (abyss, marsh) | 4,2 | 5,2 | 1,41 | 0,75 |
| braseiro (highlands / abyss / frost) | 1,5 / 1,6 / 1,5 | 2,4 / 2,5 / 2,4 | 0,65 a 0,68 | 0,35 |
| tocha (abyss) | 1,4 | 2,2 | 0,59 | 0,32 |
| totem (marsh) | 2,0 | 3,0 | 0,81 | 0,43 |
| relicário, pedra rúnica, cristal, cogumelo, fenda, lanterna de mão do gelo | 1,6 / 1,5 / 1,1 / 0,8 / 0,9 / 1,6 | iguais | | |
| fogueira (landmark_rest) | 3,6 | igual | 0,97 | 0,52 |
| cabana da loja (landmark_shop) | 5,2 | igual | 1,41 | 0,75 |
| bandeira (landmark_battle) | 3,4 | igual | 0,92 | 0,49 |
| evento / elite / mini-chefe | 5,0 / 4,4 / 3,8 | iguais | 1,35 / 1,19 / 1,03 | 0,72 / 0,63 / 0,55 |
| castelo em progress 0 | base × 1,0 | base × 1,3 (growth 3,2 → 2,9; no portão igual) | | |
| árvore na crista (t < 0,15) | × 1,0 | × `crestK` 0,70 → 1,0 | | |

## Ato 1 (campos), quadro de batalha, tod 0,65

As tabelas por prop comparam o MESMO sorteio (antes e depois com a cadência antiga de
luminárias, `LUM_STEP` 7), para que cada linha seja o mesmo objeto na mesma profundidade. O
quadro final em `depois/` usa `LUM_STEP` 13, que muda a fila de props (menos postes, outras
árvores); as razões por profundidade são idênticas porque só dependem de `size` e `t`.

| objeto | t | antes px | antes / inimigo no mesmo t | depois px | depois / inimigo no mesmo t |
|---|---|---|---|---|---|
| inimigo (espantalho) | 0,385 | 317 | 1,00 | 317 | 1,00 |
| poste | 0,02 | 62 | 0,44 | 96 | 0,68 |
| poste | 0,30 | 112 | 0,44 | 175 | 0,68 |
| poste (à frente do inimigo) | 0,46 | 166 | 0,44 | 259 | 0,69 |
| poste | 0,67 | 252 | 0,43 | 394 | 0,68 |
| poste (mais perto) | 0,88 | 363 | 0,44 | 567 | 0,68 |

Com a cadência final (`LUM_STEP` 13) o quadro de batalha do ato 1 tem só dois postes: t 0,85
com 540 px (0,68) e t 0,13 com 115 px (0,68); a tabela acima é a do mesmo sorteio com a
cadência antiga, útil por cobrir cinco profundidades.
| árvores da crista (t ≤ 0,06) | 0,00 a 0,06 | 81 a 114 | 0,56 a 0,82 | 72 a 114 | 0,51 a 0,77 |
| árvores do meio (0,3 a 0,5) | | 154 a 280 | 0,51 a 0,71 | 188 a 340 | 0,62 a 0,86 |
| árvores perto (0,6 a 0,9) | | 309 a 580 | 0,57 a 0,77 | 376 a 706 | 0,70 a 0,94 |
| castelo (progress 0) | 0 | 197 | 1,73× a maior árvore da crista | 256 | 2,25× |
| relicário | 0,13 | 37 | 0,22 | 37 | 0,22 |

Copa × grama vizinha (média de luminância e saturação HSV, `escala_humana_sheet.py canopy`):

| faixa de t | antes L copa/grama | antes S copa/grama | depois L | depois S |
|---|---|---|---|---|
| 0,15 a 0,30 | 1,40 | 0,69 | 1,23 (lift 0,25, medido no experimento) | 1,55 |
| 0,30 a 0,50 | 1,10 | 0,92 | 0,70 | 1,84 |
| 0,50 a 0,70 (referência, sem shader de névoa) | 0,88 | 1,72 | 0,88 | 1,71 |

Variantes medidas para o `lift` (multiplicador da curva do chão) em t 0,15 a 0,30:
1,0 → L 1,57 / S 1,00 (ainda lavanda); 0,5 → 1,34 / 1,32; **0,25 → 1,23 / 1,55 (adotado)**;
0 → 1,13 / 1,96 (sem recuo nenhum).

## Atos 2 a 6 (quadro de batalha, tod 0,65, resumo)

| ato | luminária | antes / inimigo no mesmo t | depois | árvores do meio (0,3 a 0,5) antes → depois | castelo / maior árvore da crista antes → depois |
|---|---|---|---|---|---|
| 2 highlands | braseiro | 0,19 a 0,20 | 0,30 a 0,32 | pinheiro 0,66 a 0,81 → 0,79 a 0,98 | 1,76 → 2,39 |
| 3 abyss | braseiro / tocha | 0,21 / (tocha 1,4) | 0,34 / tocha 109 px em t 0,45 (0,29) | árvore morta 0,53 a 0,69 → 0,65 a 0,85 | 1,69 → 2,47 |
| 4 frost | braseiro / lanterna de mão | 0,15 / 0,19 | 0,23 / 0,19 (intocada) | pinheiro 0,50 a 0,86 → 0,60 a 1,03 | 1,77 → 2,43 |
| 5 marsh | poste / totem | 0,58 / (totem 2,0) | 0,69 / totem 326 px em t 0,88 (0,39) | árvore morta 0,54 a 0,79 → 0,66 a 0,97 | 1,71 → 2,33 |
| 6 dusk | poste | 0,52 | 0,62 (PNG com 62/72 de conteúdo) | 0,55 a 0,80 → 0,66 a 0,97 | 1,75 → 2,52 |

## Encruzilhada, landmark, castelo (ato 1)

| cena | castelo antes → depois | maior árvore da crista antes → depois | castelo / árvore |
|---|---|---|---|
| encruzilhada (progress 0,03) | 202 → 260 | 111 → 107 | 1,82 → 2,43 |
| landmark (progress 0,10) | 220 → 277 | 102 → 97 | 2,16 → 2,86 |
| castelo (progress 0,85) | 696 → 708 | 123 → 110 | 5,66 → 6,44 |

Marcos (só medidos): bandeira 94 px, fogueira 109 px, cabana 147 px na encruzilhada (t ≈ 0,5;
inimigo no mesmo t = 413 px → 0,23 / 0,26 / 0,36 do inimigo real); fogueira escolhida 281 px em
t 0,63 (inimigo no mesmo t 539 → 0,52). Postes na cena landmark: 192 / 444 / 615 px em
t 0,34 / 0,73 / 0,93, sempre 0,68 do inimigo real no mesmo t.

## Custo

`perf_probe 1920x1080:phases`: bioma 6 mediana 3,51 ms (p95 5,12), 397 draw calls, 6 canvas,
344 shader switches; viagem 8,5 ms mediana; props 2,62 ms; alocação 37,5 KB/quadro com GC
parado. `test_perf_budget`: 403 draw calls (teto 600), 31,8 KB (teto 40). WorldRoad: 188 locais.
