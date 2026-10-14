---
name: code_notes/src/ui/SceneLayer.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/SceneLayer.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/SceneLayer.lua`

Origem: `src/ui/SceneLayer.lua` em `7dbdb60d` (16 de 45 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-10 (junto a `local SceneBackground = require("src.ui.SceneBackground")`)

> src/ui/SceneLayer.lua
> Camadas de cenário animado. Arte rica vem do scene PNG (400×256); animação
> vem de OVERLAYS de código (partículas + flicker + glow pulsante) pra dar
> MUITA vida sem precisar re-gerar arte.
>
> Assets esperados:
> assets/sprites/scenes/<name>.png         — scene full-res (base)
> assets/sprites/map_objects/<name>.png    — props individuais (torch, etc.)
>
> Ver memory/scene_pipeline.md pra pipeline completo.

## L19-23 (em `propMiss`, junto a `local fireEmbers = {}`)

> Partículas locais (gerenciadas aqui, não no ParticleSystem global pra não
> poluir o damage numbers etc):
> fireEmbers[]   — subindo das tochas
> crystalSparks[] — orbitando o cristal
> dustMotes[]    — poeira do chão

## L44-54 (em `loadProp`, junto a `SceneLayer.ACT_CONFIGS = {`)

> ============================================================================
> CONFIG POR ATO
> ============================================================================
> Campos:
> scenePng     : arte base full-res (400×256) com elementos NA PRÓPRIA arte
> fireEmitters : posições (xr, yr) onde partículas de fogo spawn — casam com
> as tochas que foram desenhadas dentro da scene PNG
> dustColor    : tint de partículas ambientes de pó
> parallaxY/X  : drift do scene (cria sensação de "camera viva")
> props        : (vazio por padrão) — só usar se o prop FAÇA SENTIDO na scene
> específica. Props genéricos sobrepostos ficam ruins.

## L64-65 (em `dustColor`, junto a `fireEmitters = {},`)

> Desativado: fireEmitters criavam "partículas soltas no ar" sobre as
> tochas pintadas, ficava visualmente confuso. A arte já tem o fogo.

## L93-96 (em `props`, junto a `SceneLayer.ACT_CONFIGS[4] = SceneLayer.ACT_CONFIGS[1]`)

> Os atos 4-6 (Set/2026) reusam a cena do irmao de clima: este SceneLayer e o
> caminho LEGADO (a estrada de verdade e o WorldRoad, que tem bioma proprio
> pros seis) e so aparece quando o interior do ato ainda nao foi gerado.
> Mesmo pareamento do salao de chefe em GameplayScene.

## L101-102 (em `props`, junto a `function SceneLayer.sceneKeyForAct(act)`)

> Nome da cena PNG que este ato desenha — o chamador precisa saber QUAL
> arte esta na tela pra pedir a linha de chao dela (src/data/scene_anchors).

## L112-114 (em `SceneLayer.sceneKeyForAct`, junto a `local function spawnFireEmber(cx, cy)`)

> ============================================================================
> UPDATE
> ============================================================================

## L197-198 (em `SceneLayer.update`, junto a `local cfg = SceneLayer.ACT_CONFIGS[SceneLayer._currentAct]`)

> Fire emitters: agora spawnam aqui (não em draw) pra independer do estado
> de renderização e funcionarem mesmo em screenshots headless.

## L247-249 (em `SceneLayer.update`, junto a `local function drawFireEmbers()`)

> ============================================================================
> HELPERS DE DRAW
> ============================================================================

## L287-289 (em `drawDustMotes`, junto a `local function drawBgFar(cfg, x, y, w, h)`)

> ============================================================================
> BG FAR: scene PNG com tint + parallax 2D dramático
> ============================================================================

## L298 (em `drawBgFar`, junto a `local parallaxY = (cfg.parallaxY or 0) * math.sin(SceneLayer._time * 0.25)`)

> Parallax 2D mais forte (antes era só Y ±1.5, agora XY)

## L313 (em `drawBgFar`, junto a `local pulse = 0.10 + math.sin(SceneLayer._time * 0.6) * 0.05`)

> Pulse escuro mais forte (antes era ±0.02, agora ±0.05)

## L319-321 (em `drawBgFar`, junto a `local function drawBgMid(cfg, x, y, w, h)`)

> ============================================================================
> BG MID: vinheta + poeira ambiente visível
> ============================================================================

## L335-337 (em `drawBgMid`, junto a `local function drawProp(prop, baseX, baseY, w, h)`)

> ============================================================================
> FG PROPS (tochas com flicker FORTE, cristal com sparks orbitando)
> ============================================================================

## L355 (em `drawProp`, junto a `local flickerMain = math.sin(SceneLayer._time * 17 + prop.xr * 47) * 0.5 + 0.5`)

> FLICKER FORTE: 0.70 a 1.25 (antes era 0.85 a 1.03)

## L410-412 (em `drawProp`, junto a `function SceneLayer.draw(x, y, w, h, actNumber)`)

> ============================================================================
> API PÚBLICA
> ============================================================================

