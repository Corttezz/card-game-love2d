---
name: code_notes/engine/RoadWear.lua
description: Comentários com decisão/regra/histórico colhidos de engine/RoadWear.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/RoadWear.lua`

Origem: `engine/RoadWear.lua` em `7dbdb60d` (8 de 32 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-27 (junto a `local LightEngine = require("engine.LightEngine")`)

> engine/RoadWear.lua
> Motor de IMPERFEIÇÕES DO SOLO do caminho (v10 — Jul/2026): o leito da
> estrada era "plano e padronizado" (textura tileada + pedrinhas 2px).
> Este motor deita DETALHES DETERMINÍSTICOS sobre a terra, por bioma:
>
> fields    — manchas úmidas, pedras encravadas, palha caída, cascos
> highlands — restos de CALÇAMENTO (lajes semi-enterradas), musgo
> abyss     — rachaduras com BRASA viva (micro-luz), chamusco, ossos
> frost     — bancos de neve invadindo, placas de gelo, pegadas
> marsh     — POÇAS refletindo o céu, lama arrastada, raízes
> dusk      — folhas caídas, raízes, pedras
>
> Princípios (mesma família do GrassField/LuminaireEngine):
> · DETERMINÍSTICO: feature = f(worldZ, hash) — nada de estado/spawn;
> a estrada rola e os detalhes rolam junto, sempre os mesmos.
> · Projeção INJETADA: usa a geometria do domo do WorldRoad (t, latY,
> persp, roadCenter/roadHalf) — nunca coordenadas próprias.
> · Stamps em TONS DE CINZA tintados por envColor no draw — o crossfade
> de bioma lerpa as cores de graça (nada "pipoca" na transição).
> · SQUASH vertical (~0.55): o stamp DEITA no chão (foreshortening),
> em vez de parecer adesivo em pé.
> · Fork: além de FORK_REL o leito é área de escolha — sem detalhe novo.
>
> Uso (WorldRoad.draw, logo APÓS drawRoad e ANTES da grama):
> RoadWear.draw(ctx)  com ctx = { geom, x, w, camZ, time, bid, relCrest,
> roadCenter(z,t), roadHalf(t), tint(name) -> {r,g,b},
> forkActive, forkRel }

## L33-36 (em `RoadWear`, junto a `local stamps = nil`)

> STAMPS procedurais (grayscale + alpha, gerados 1x). Valor = luminância a
> tintar; alpha esculpe a forma. Pixel-art: formas duras, dither na borda.

## L116 (em `pts`, junto a `do`)

> RACHADURA 20×6 (linha quebrada; abyss tinta com brasa + micro-luz)

## L224-230 (em `pts`, junto a `local function mul(c, k) return { c[1] * k, c[2] * k, c[3] * k } end`)

> CATÁLOGO por bioma: cada feature = { stamp, cada (unidades de z entre
> instâncias), tint (chave/fórmula de cor), alpha, uMax (fração da meia-
> largura), scaleK, ember (micro-luz abyss) }.
> tint: função (ctx) -> {r,g,b} — derivada do envColor pra lerpar no
> crossfade de bioma.

## L246-248 (em `tint`, junto a `highlands = {`)

> v10.1: os decals de "cobble" saíram — as LAJES agora são ASSADAS na
> superfície (RoadSurface Voronoi); decal de laje solto POR CIMA de
> textura de laje lia como "quadradinhos aleatórios" (feedback).

## L300-306 (em `tint`, junto a `RoadWear.DENSITY = 1.6`)

> DRAW: para cada feature do catálogo, instancia determinística por
> "slot" de z (floor(worldZ / cada) + salt). Projeção pela geometria do
> domo injetada; squash vertical pra deitar no chão.
>
> Knob global de densidade (1 = catálogo cru; subir = mais detalhe).
> Calibrado visualmente: 1.6 preenche sem virar entulho.

## L328 (em `RoadWear.draw`, junto a `local wz = (slot + 0.15 + h1 * 0.7) * cada`)

> jitter de z DENTRO do slot (quebra o ritmo de grade)

## L342-343 (em `RoadWear.draw`, junto a `local sc = (0.70 + 2.6 * t) * (f.scaleK or 1)`)

> escala pela perspectiva (mesma régua dos props) +
> SQUASH vertical: o stamp deita no chão

