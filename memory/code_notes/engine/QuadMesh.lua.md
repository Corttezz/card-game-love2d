---
name: code_notes/engine/QuadMesh.lua
description: Comentários com decisão/regra/histórico colhidos de engine/QuadMesh.lua antes da remoção de comentários do código (commit 7dbdb60d, Out/2026). Linhas referem-se a esse commit.
type: reference
---

# Notas colhidas de `engine/QuadMesh.lua`

Origem: `engine/QuadMesh.lua` em `7dbdb60d` (8 de 12 blocos de comentário tinham marcador de decisão/regra/histórico).

## L1-30 (junto a `local ffi = require("ffi")`)

> engine/QuadMesh.lua
> ============================================================================
> QUADMESH — lote de quads escrito por FFI e desenhado como 1 Mesh (Out/2026)
> ============================================================================
> POR QUE EXISTE: o WorldRoad desenhava o chão do domo, a estrada e a grama
> com dezenas de milhares de chamadas C por frame (quad:setViewport +
> love.graphics.draw / rectangle / batch:add / setColor). O custo NÃO era
> a GPU (o LÖVE já juntava tudo em ~800 draw calls) — era a fronteira
> Lua→C: cada chamada custa ~0.2-0.5 µs E aborta o trace do JIT, então o
> laço inteiro rodava no interpretador. Aqui o laço só faz aritmética e
> escreve floats num ByteData via FFI (o JIT compila), e o envio pra GPU é
> 1 setVertices + 1 draw por TRECHO.
>
> MESMOS PIXELS: as fórmulas de vértice/UV/cor replicam as do LÖVE 11
> (Quad::refresh, Matrix4::setTransformation, toColor32) — a prova pixel a
> pixel fica em tools/perf_visual_diff.lua. Ordem de desenho = ordem de
> escrita (painter preservado dentro do lote).
>
> QUAD SEM TEXTURA no meio de quads texturizados (retângulos chapados da
> estrada intercalados com o tile): u = UNTEXTURED; o shader do lote
> devolve só a cor do vértice. Use QuadMesh.untexturedShader() no draw.
>
> USO:
> local qm = QuadMesh.new(1024)
> qm:reset()
> local a = qm.n
> qm:rect(x, y, w, h, u0, v0, u1, v1, r, g, b, a)    -- axis-aligned
> qm:sprite(...)                                       -- ver abaixo
> qm:upload(a, qm.n); qm:draw(a, qm.n - a, texture)
> ============================================================================

## L53-55 (em `FORMAT`, junto a `local function c8(c)`)

> toColor32 do LÖVE 11: clamp [0,1] e arredonda (×255 + 0.5).
> SEM if: desvio em função quente vira saída lateral de trace, e as
> laterais desta cena não compilam (NYICOAL) — min/max são branchless.

## L84-86 (em `QuadMesh.untexturedShader`, junto a `function QuadMesh.new(capQuads, opts)`)

> opts (opcional): { ctype = "<struct>", format = {...} } — vértice
> próprio (ex.: GrassField, com atributos de vento). A struct precisa
> bater byte a byte com o format; o chamador escreve via qm:alloc()/qm.v.

## L120-121 (em `QuadMesh:_grow`, junto a `if oldN > 0 then self:upload(0, oldN) end`)

> o que já foi escrito sobe de novo pro Mesh novo (quem reusa trechos
> gravados — cache da grama/domo — não pode achar buraco depois)

## L129-130 (em `QuadMesh:reset`, junto a `local function alloc(self)`)

> reserva 1 quad e devolve o índice do 1º vértice. ATENÇÃO: pode crescer
> o buffer — releia qm.v DEPOIS de chamar.

## L139-140 (em `alloc`, junto a `function QuadMesh:rect(x, y, w, h, u0, v0, u1, v1, r, g, b, a)`)

> Quad ALINHADO AOS EIXOS: (x,y)-(x+w,y+h), UV (u0,v0)-(u1,v1) normalizados.
> Vértices na ordem do Quad do LÖVE: (0,0) (0,h) (w,0) (w,h).

## L156-159 (em `QuadMesh:rect`, junto a `function QuadMesh:sprite(x, y, sx, sy, ox, oy, kx, qw, qh,`)

> Equivalente de SpriteBatch:add(quad, x, y, 0, sx, sy, ox, oy, kx, 0)
> com o quad de tamanho qw×qh e UV (u0,v0)-(u1,v1); cor JÁ em bytes.
> Matrix4::setTransformation do LÖVE 11 com ângulo 0 e ky 0:
> X = x + sx·(lx − ox) + kx·sx·(ly − oy)      Y = y + sy·(ly − oy)

## L177-178 (em `QuadMesh:sprite`, junto a `function QuadMesh:upload(from, to)`)

> Sobe pro Mesh os quads [from, to). Só o trecho — o resto do buffer
> (trechos já desenhados neste frame) não é tocado.

