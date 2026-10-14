---
name: code_notes/src/ui/CardMesh.lua
description: Comentários com decisão/regra/histórico colhidos de src/ui/CardMesh.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `src/ui/CardMesh.lua`

Origem: `src/ui/CardMesh.lua` em `7dbdb60d` (7 de 20 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-16 (junto a `local CardMesh = {}`)

> src/ui/CardMesh.lua
> Mesh tessellada reutilizável pra cartas + wrapper do vertex shader de warp.
> Estilo Balatro: grid 8×12 vertices sobre o canvas da carta, vertex shader
> deforma cada vertex baseado em mouse/hover/time pra efeito de perspective
> pressando um canto.
>
> Uso:
> local mesh = CardMesh.getMesh(imageWidth, imageHeight)  -- geometria cacheada
> local shader = CardMesh.getShader()                      -- pode ser nil
> mesh:setTexture(image)
> if shader then
> love.graphics.setShader(shader)
> CardMesh.setUniforms(shader, mouseUV, hover, time, image)
> love.graphics.draw(mesh, x, y, rot, sx, sy)
> love.graphics.setShader()
> end

## L31-33 (em `cfg`, junto a `local function buildMesh(w, h)`)

> Gera vertices em grid COLS × ROWS com UV normalizado [0..1] e posição em pixels.
> Triângulos: 2 por célula. Total vertices por célula = 6 (dois triangle com shared verts).
> Usamos triangle-list simples em vez de strip pra evitar gotchas de ordem.

## L78 (em `pointAt`, junto a `function CardMesh.getMesh(width, height)`)

> Retorna mesh compartilhada, reconstruindo só se dimensões mudaram.

## L115-119 (em `CardMesh.getShader`, junto a `function CardMesh.setUniforms(shader, mouseUV, hover, time, image)`)

> Seta uniforms do shader.
> mouseUV: vec2 em [-1, 1] (0,0 = sem press)
> hover: float 0..1
> time: segundos
> image: drawable ativo (pra pegar getWidth/getHeight)

## L125-126 (em `CardMesh.setUniforms`, junto a `shader:send("quadOn", 0)`)

> o modo quadrilátero (loja) é estado do shader COMPARTILHADO: zera aqui
> pra nenhum outro chamador herdar a homografia da última carta da loja

## L131-133 (em `CardMesh.setUniforms`, junto a `function CardMesh.setQuad(shader, r0, r1, r2)`)

> Loja v3c: liga o modo QUADRILÁTERO depois do setUniforms. r0..r2 = linhas
> da homografia (ShopPerspective.homography) em coordenadas do mundo: o mesh
> é desenhado em (0, 0) sem escala e cai exatamente nos 4 cantos.

## L141-142 (em `CardMesh.setQuad`, junto a `function CardMesh.draw(image, drawX, drawY, mouseUV, hover, time)`)

> Helper de draw completo (setShader + uniforms + mesh + setShader nil).
> Assume que caller já aplicou push/translate/rotate/scale no contexto.

