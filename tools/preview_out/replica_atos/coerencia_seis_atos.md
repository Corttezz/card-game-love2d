# Coerência entre os seis atos no quadro de batalha 1080p (18/Out/2026, frente replica-6)

Folha: `seis_atos_batalha.png` (linhas: antes 0,65 / depois 0,65 / antes 0,95 / depois 0,95).
"Antes" = `base_antes/` no main `ed2484f1`, antes de qualquer frente de réplica.
"Depois" = main `4d8ba0cd` + o ajuste de tamanho do poste do ato 6. **Quando esta folha foi montada,
as frentes replica-23 (atos 2 e 3) e replica-45 (atos 4 e 5) ainda não tinham commitado nada**, então
as colunas 2 a 5 mostram o estado de antes; as diferenças de props nessas colunas são variação entre
execuções da captura, não mudança de código. Refazer com
`python <scratchpad>/r6/sheet6.py <pasta com b{n}_battle_tod{0.65,0.95}.png>` quando elas entrarem.

## Régua (inimigo = 279 px em t 0,385; `escala_humana coer:b1..b6`)

| Ato | Luminária de estrada | Altura medida | Leitura |
|-----|---------------------|---------------|---------|
| 1 fields | poste 5,6 | 605 px em t 0,85, 129 em t 0,13 | referência: ~0,85x o inimigo na profundidade dele |
| 2 highlands | braseiro 2,7 | 253 px em t 0,81 | objeto baixo (≈ 0,42 do poste), coerente com braseiro de chão |
| 3 abyss | tocha 2,5 / braseiro 2,8 | 243 px em t 0,81 / 150 em t 0,48 | idem |
| 4 frost | lanterna 1,8 | 171 px em t 0,87 | a mais baixa de todas; lanterna de mão no chão, lê pequena ao lado do inimigo (frente replica-45 decide) |
| 5 marsh | poste 5,6 | 334 px em t 0,53 | igual ao ato 1 na mesma profundidade |
| 6 dusk | poste 6,1 (arte nova) | 601 px em t 0,85, 344 em t 0,54 | igual ao ato 1 (ajustado nesta revisão: era 572 com 5,8) |

Castelo na crista: 235 a 299 px em todos os atos (castelo do ato 3 o menor, do ato 4 o maior); a relação
castelo/árvore da crista fica entre 1,8 e 2,5.

## Sombra

Atos 1 e 6: `shadow.alphaK` 2,2, árvores com sombra própria (`tree.alphaK` 1,45) e disco de copa; a sombra
das árvores e dos postes aparece no quadro. Atos 2 a 5 ainda em `alphaK` 1,0 sem `tree`/`canopy`: as
árvores não projetam sombra legível, então o quadro deles parece "sem sombra" perto dos atos 1 e 6. É o
item que as frentes 23 e 45 precisam igualar para a intensidade ficar comparável.

## Luminárias dia/noite

Todas passam pelo mesmo `LuminaireEngine.dayK` (0 até tod 0,45, cheia em 0,85): em 0,65 todas acendem
fracas e em 0,95 cheias, em todos os atos. A chama pintada no PNG fica sempre (decisão do ato 1). Nada
divergente encontrado.

## Atualização com os atos 2 e 4 commitados (e669de1d, 71bf6827)

A folha foi refeita com o main que já tem os atos 2 e 4 (os atos 3 e 5 ainda não tinham entrado).
Régua da luminária de estrada mais perto da câmera, mesma ferramenta:

| Ato | Luminária | Altura | t |
|-----|-----------|--------|---|
| 1 fields | poste | 605 px | 0,85 |
| 2 highlands | pilar-braseiro novo | 573 px | 0,81 |
| 4 frost | poste de ferro novo | 623 px | 0,87 |
| 6 dusk | poste novo | 601 px | 0,85 |

Os quatro atos prontos têm luminária de estrada na mesma régua (±4 % considerando a profundidade).
Sombras: atos 2 e 4 passaram a projetar sombra de árvore como 1 e 6. Pendentes de igualar: atos 3 e 5.
