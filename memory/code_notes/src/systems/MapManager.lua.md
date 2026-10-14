---
name: code_notes/src/systems/MapManager.lua
description: Comentários com decisão/regra/histórico colhidos de src/systems/MapManager.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/systems/MapManager.lua`

Origem: `src/systems/MapManager.lua` em `7dbdb60d` (10 de 23 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local MapManager = {}`)

> src/systems/MapManager.lua
> Gera escolhas de nos entre batalhas (MVP sem mapa visual global).
> Cada escolha e uma lista de 2-3 NodeType distintos.
>
> A probabilidade de cada tipo de no e funcao do floorInAct (posicao dentro
> do ato). Fase 5 refinara pesos por ato; por ora, floorsPerAct fixo=8.
>
> Contrato:
> MapManager.generate(floorInAct, actNumber, numNodes, opts) -> { node1, node2, ... }
> Cada node = { type, label, icon, rewardHint, payload }

## L29-34 (em `MapManager.NODE_TYPES`, junto a `MapManager.NODE_META = {`)

> Metadata humana para cada tipo.
> `icon`: fallback 64×64 de assets/sprites/icons/ (IconLoader)
> `sprite`: sprite 96×96 ilustrado de assets/sprites/map_nodes/ (preferencial)
> `label`/`desc`: FALLBACK de dev. O texto exibido vem do i18n
> (`node_type.<tipo>.label` / `.desc`) via MapManager.labelFor/descFor —
> antes o PT saia cravado daqui e a tela de mapa ficava bilingue.

## L50-51 (em `MapManager.NODE_META`, junto a `icon = "skull_horned",`)

> crânio CHIFRUDO (Out/2026, known_gaps #16): antes dividia o
> skull_crowned com o chefe e os dois liam igual no mapa/roteiro.

## L82-84 (em `MapManager.NODE_META`, junto a `function MapManager.labelFor(nodeType)`)

> Texto exibido de um tipo de nó, traduzido. Sempre prefira estes helpers a
> ler `node.label`/`node.desc` direto — um nó SALVO carrega o texto do idioma
> em que foi gerado.

## L99-101 (em `MapManager.descFor`, junto a `local function rollWeighted(weights)`)

> Helper: pesca um tipo dado um vetor { {type=, weight=}, ... }
> Stream "map" do Rng da run: a sequência de nodes é reprodutível por seed
> e independente dos rolls de carta/loja.

## L114-115 (em `rollWeighted`, junto a `function MapManager.weightsFor(floorInAct, actNumber)`)

> Pesos base para um floorInAct dentro de um ato padrao.
> Fase 5 vai permitir override por ato via Config.Acts[N].nodeWeights.

## L149-150 (em `base`, junto a `function MapManager.generate(floorInAct, actNumber, numNodes, opts)`)

> Gera N nos distintos (sem repeticao) para a proxima escolha.
> Boss/mini-boss unicos nunca tem alternativas.

## L155-156 (em `MapManager.generate`, junto a `if opts.eliteMul and opts.eliteMul ~= 1 then`)

> Selo "Cerco" / maldição "Caçada": elite mais frequente (opts.eliteMul,
> injetado pelo RunManager a partir de RunModifiers).

## L195-197 (em `MapManager._makeNode`, junto a `label = MapManager.labelFor(nodeType),`)

> Já traduzidos na criação para que consumidores que leem node.label
> direto (ex: a bifurcação da estrada no WorldRoad) não precisem saber
> do i18n. Quem desenha uma tela nova deve usar MapManager.labelFor.

## L207-208 (em `MapManager._makeNode`, junto a `function MapManager.floorToAct(globalFloor)`)

> Dado um floor global (1, 2, ...), converte para (actNumber, floorInAct).
> Usado pelo Game quando so temos o contador global.

