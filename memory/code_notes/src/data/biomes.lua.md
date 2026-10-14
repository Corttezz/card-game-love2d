---
name: code_notes/src/data/biomes.lua
description: Comentários com decisão/regra/histórico colhidos de src/data/biomes.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/data/biomes.lua`

Origem: `src/data/biomes.lua` em `7dbdb60d` (9 de 46 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-14 (junto a `local biomes = {`)

> src/data/biomes.lua
> DADOS dos biomas do mundo rolante (WorldRoad). Tabela pura, sem lógica.
>
> Técnica estudada do Path of Kings (referência): cada bioma tem cor-assinatura,
> paleta de terreno, props variados e um marco no fim (castelo). Biomas 1-3
> mapeiam pros ATOS da run; 4-6 ciclam no endless.
>
> Arte: WorldRoad procura PNG override em assets/sprites/world/<id>_<prop>_<i>.png
> (futuro PixelLab). Sem PNG, gera sprite procedural com a paleta abaixo.
>
> `grassPattern`/`roadPattern`: nomes de assets/sprites/backgrounds/patterns/
> (os MESMOS 64×64 tileáveis das cartas) — usados como textura modo-7 do chão.
> `propWeights`: kinds disponíveis: tree, pine, deadtree, bush, rock, stump,
> fence, sign, flowers, ruin.

## L38 (em `lightNight`, junto a `lightWindows = { { 0.47, 0.44 }, { 0.61, 0.43 } },`)

> v9.9: âncoras do castelo NOVO (2 janelas góticas acesas)

## L51-58 (em `landmark`, junto a `propWeights = { tree = 3, bush = 3, flowers = 2, rock = 1, stump = 0.8,`)

> v9 LuminaireEngine: 3 luminárias por bioma, rate ↑ ("hoje custa
> aparecer uma") — kinds/luz definidos em engine/LuminaireEngine.lua
> cerca/placa removidas do bioma 1 (pedido do usuário)
> firepit removida de TODOS os biomas (Set/2026, pedido do dono:
> "a pixel art de fogueira de decoração, fora do padrão"). O PNG
> assets/sprites/world/*_firepit_0.png e a entrada no CATALOG do
> LuminaireEngine ficaram órfãos de propósito — sem peso aqui o
> pickKind nunca sorteia. NÃO reintroduzir sem pedido explícito.

## L84 (em `lightNight`, junto a `lightWindows = { { 0.49, 0.64 }, { 0.51, 0.39 }, { 0.38, 0.65 },`)

> v9.9.3: cidadela v6 em camadas — janela-catedral + andares + laterais

## L124 (em `lightNight`, junto a `lightWindows = { { 0.51, 0.85 }, { 0.49, 0.56 }, { 0.26, 0.80 },`)

> v9.9.1: fortaleza v3 — portão em chamas, janelas, veias de brasa

## L163-173 (em `lightAmbient`, junto a `lightDay   = { 0.86, 0.90, 0.98 },   -- dia gelado    (luma 0.897)`)

> P6' (Set/2026): o frost era o ÚNICO bioma fora da curva — luma do
> ambiente 0.887 no andar 1 e 0.826 no boss, contra 0.49-0.76 de
> todos os outros. O motor é MULTIPLY-ONLY (teto 1.0): a luz só
> "devolve" a arte na medida em que o ambiente escureceu. A 83% não
> sobra margem, e por isso braseiro aceso não fazia poça nenhuma no
> chão (medido em enemy4_winter_monarch: dois fogos, chão intacto).
> A causa era o AMBIENTE claro demais, não falta de termo aditivo —
> aditivo no lightmap foi tentado no v6 e removido no v7 (ver
> memory/lighting_engine.md). Rebaixado pra faixa do highlands, que
> é o mais claro dos que funcionam, preservando o viés frio (B>G>R).
> Piso de legibilidade MIN_AMBIENT_LUMA 0.35: folgado.

## L216 (em `lightNight`, junto a `lightWindows = { { 0.51, 0.43 }, { 0.32, 0.50 }, { 0.64, 0.51 },`)

> v9.9.3: cidadela v5 em camadas — 3 janelas + brilho da base

## L257 (em `lightNight`, junto a `lightWindows = { { 0.49, 0.88 }, { 0.49, 0.55 }, { 0.23, 0.51 },`)

> v9.9: castelo novo — portão dourado + janelas central/esq/dir

## L271-272 (em `landmark`, junto a `propWeights = { tree = 3, flowers = 2.5, bush = 2,`)

> cerca removida do Crepúsculo (Out/2026, dono: "cerca estranha que
> não serve para nada"), como já tinha saído dos Campos

